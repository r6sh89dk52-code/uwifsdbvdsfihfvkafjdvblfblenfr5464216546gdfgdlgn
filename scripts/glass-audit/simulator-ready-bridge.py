#!/usr/bin/env python3
"""Observe real coreauthd sensor readiness. Never posts biometric events."""
import json,os,plistlib,pty,re,select,signal,subprocess,sys,time,threading
from datetime import datetime,timezone
from pathlib import Path

class SensorReadiness:
 def __init__(self):
  self.generation=0;self.ready=False;self.ready_stamp='';self.begin_stamp='';self.transition=''
 def observe(self,line):
  stamp=line[:23]
  if not re.fullmatch(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}',stamp):return
  if 'DANPERNative[' in line and '[com.apple.LocalAuthentication:Client,Interactive] evaluatePolicy:2 options:' in line and stamp>=self.begin_stamp:
   self.generation+=1;self.begin_stamp=stamp;self.ready=False;self.transition=stamp
   return ('CLIENT_CONTEXT',self.generation,stamp)
  if 'coreauthd[' in line and '[com.apple.LocalAuthentication:Server,Interactive] Mechanism event 5' in line and 'MechanismPearl' in line and stamp>=self.begin_stamp and stamp>=self.transition:
   self.ready=True;self.ready_stamp=stamp;self.transition=stamp
   return ('SENSOR_ACTIVE',self.generation,stamp)
  if 'coreauthd[' in line and ('will stop biometric operation:' in line or 'MechanismUI' in line and 'willFinish' in line) and stamp>=self.transition:
   self.ready=False;self.transition=stamp
 def permits(self,minimum):return self.ready and self.generation>=minimum>0

class AsyncRunnerContainer:
 """Resolve registration off the sensor loop; simctl may stall on cold CI."""
 def __init__(self,lookup,interval=2,once=False):
  self.lookup=lookup;self.interval=interval;self.once=once;self._value=None;self._error=None
  self._lock=threading.Lock();self._stop=threading.Event()
  self._thread=threading.Thread(target=self._run,daemon=True);self._thread.start()
 def _run(self):
  while not self._stop.is_set():
   try:
    value=self.lookup()
    with self._lock:
     if value is not None:self._value=value
     self._error=None
   except (OSError,subprocess.TimeoutExpired) as error:
    with self._lock:self._error=(type(error).__name__,str(error))
   if self.once or self._stop.wait(self.interval):return
 def snapshot(self):
  with self._lock:return self._value,self._error
 def close(self,timeout=0):
  self._stop.set();self._thread.join(timeout)


class SensorGatedRunnerContainer:
 """No simctl registration RPC while CoreAuthUI is activating.

 Resolve once AFTER a genuine current sensor event. Cache only that context's
 registration, never sensor readiness. A new context must resolve again; old
 in-flight lookups cannot provide another generation's path or overlap it.
 """
 def __init__(self,lookup,interval=2,clock=time.monotonic):
  self.lookup=lookup;self.interval=interval;self.clock=clock
  self.worker=None;self.worker_generation=0;self.generation=0
  self.value=None;self.error=None;self.retry_at=0
 def snapshot(self,state):
  if self.worker is not None and (not state.ready or self.worker_generation!=state.generation):
   self.worker.close()
   if self.worker._thread.is_alive():return None,None
   self.worker=None
  if not state.ready or state.generation<=0:return None,None
  if self.generation!=state.generation:
   self.generation=state.generation;self.value=None;self.error=None;self.retry_at=0
  if self.value is not None:return self.value,None
  if self.worker is None and self.clock()>=self.retry_at:
   self.worker_generation=state.generation
   def current_lookup(expected=state.generation):
    if not state.ready or state.generation!=expected:
     raise OSError('Sensor context changed before registration RPC; no query attempted')
    return self.lookup()
   self.worker=AsyncRunnerContainer(current_lookup,once=True)
  if self.worker is not None:
   value,error=self.worker.snapshot()
   if value is not None:
    self.value=value;self.error=None;self.worker.close();self.worker=None
   elif error is not None:
    self.error=error;self.worker.close()
    if not self.worker._thread.is_alive():
     self.worker=None;self.retry_at=self.clock()+self.interval
  return self.value,self.error
 def close(self,timeout=0):
  if self.worker is not None:self.worker.close(timeout)

def stream(sim):
 # Unified log buffers output when its stdout is a regular file. A private PTY
 # keeps the genuine sensor events live, without changing their contents or
 # posting authentication events. Only the owned synthetic device is eligible.
 rows=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
 found=[d for g in rows['devices'].values() for d in g if d['udid']==sim]
 assert len(found)==1 and found[0]['state']=='Booted' and found[0]['name'].startswith('DANPER-SYNTHETIC-')
 master,slave=pty.openpty()
 predicate='subsystem BEGINSWITH "com.apple.LocalAuthentication" OR (process == "coreauthd" AND eventMessage CONTAINS "simulateMatching") OR (process == "DANPERNative" AND subsystem == "com.apple.UIKit" AND category == "Application")'
 child=subprocess.Popen(['xcrun','simctl','spawn',sim,'log','stream','--level','debug','--style','compact','--predicate',predicate],stdout=slave,stderr=slave)
 os.close(slave)
 def stop(*_):raise SystemExit(0)
 signal.signal(signal.SIGTERM,stop)
 signal.signal(signal.SIGINT,stop)
 try:
  while True:
   readable,_,_=select.select([master],[],[],1)
   if readable:
    try:data=os.read(master,65536)
    except OSError:break
    if not data:break
    sys.stdout.buffer.write(data);sys.stdout.buffer.flush()
   elif child.poll() is not None:break
 finally:
  child.terminate()
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  os.close(master)
 if child.returncode not in (0,-signal.SIGTERM):raise SystemExit(child.returncode)

def report(*values):
 print(datetime.now(timezone.utc).isoformat(timespec='milliseconds'),*values,flush=True)

def main():
 sim,log,runner_info=sys.argv[1],Path(sys.argv[2]),Path(sys.argv[3])
 rows=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
 found=[d for g in rows['devices'].values() for d in g if d['udid']==sim]
 assert len(found)==1 and found[0]['state']=='Booted' and found[0]['name'].startswith('DANPER-SYNTHETIC-')
 info=plistlib.loads(runner_info.read_bytes());bundle_id=info['CFBundleIdentifier']
 assert 'interactiontests' in bundle_id.lower() and bundle_id.startswith('pe.danper.saludmovil.native.iloaderpreview.')
 report('RUNNER_BUNDLE',bundle_id)
 def lookup_container():
  report('RUNNER_QUERY_AFTER_REAL_SENSOR',state.generation,state.ready,state.ready_stamp)
  r=subprocess.run(['xcrun','simctl','get_app_container',sim,bundle_id,'data'],capture_output=True,text=True,timeout=5)
  if r.returncode==0 and r.stdout.strip():
   return Path(r.stdout.strip())/'Documents/DANPER_BIOMETRIC_READY'
  raise OSError('Runner container query failed: '+r.stderr.strip())
 resolver=SensorGatedRunnerContainer(lookup_container)
 container=None;offset=0;pending=b'';seen=set();observed=set();last_error=None;probe_error=None;state=SensorReadiness()
 while True:
  if log.exists():
   with log.open('rb') as f:f.seek(offset);pending+=f.read();offset=f.tell()
   lines=pending.split(b'\n');pending=lines.pop()
   for raw in lines:
    event=state.observe(raw.decode('utf-8',errors='replace'))
    if event:report(*event)
  # The old every2s simctl poll ran while CoreAuthUI was activating. In
  # run41707072055, the real service timed out at5s and its VC appeared25s
  # later. Resolve only after a genuine sensor event, once per context; no
  # registration RPC overlaps the critical activation window.
  active,error=resolver.snapshot(state)
  if error!=probe_error:
   probe_error=error
   if error:report('RUNNER_CONTAINER_QUERY_ERROR',*error)
  if active!=container:
   container=active
   if container is not None:report('RUNNER_CONTAINER_ACTIVE',str(container))
  if container is not None:
   try:
    value=json.loads((container/'request.json').read_text());nonce=value['id'];minimum=value['minimumGeneration']
    assert re.fullmatch('[0-9A-Fa-f-]{36}',nonce) and value['event'] in ('match','nomatch') and isinstance(minimum,int) and minimum>0
    last_error=None
    if nonce not in observed:
     observed.add(nonce);report('REQUEST_OBSERVED',nonce,value['event'],minimum)
    if nonce not in seen and state.permits(minimum):
     ack={'id':nonce,'event':value['event'],'ready':True,'generation':state.generation,'sensorActiveAt':state.ready_stamp,'clientContextAt':state.begin_stamp,'noAuthenticationInjected':True}
     tmp=container/'ready.pending';tmp.write_text(json.dumps(ack));tmp.replace(container/'ready.json');seen.add(nonce)
     report('READY_ACK',json.dumps(ack))
   except (OSError,ValueError,KeyError,AssertionError) as error:
    detail=(str(container),type(error).__name__,str(error))
    if detail!=last_error:
     report('REQUEST_NOT_READABLE',*detail);last_error=detail
  time.sleep(0.1)

if __name__=='__main__':
 if sys.argv[1]=='--stream':stream(sys.argv[2])
 else:main()
