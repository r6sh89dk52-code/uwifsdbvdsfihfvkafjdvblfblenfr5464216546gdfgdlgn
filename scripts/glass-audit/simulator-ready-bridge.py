#!/usr/bin/env python3
"""Observe real coreauthd sensor readiness. Never posts biometric events."""
import json,plistlib,re,subprocess,sys,time
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

def main():
 sim,log,runner_info=sys.argv[1],Path(sys.argv[2]),Path(sys.argv[3])
 rows=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
 found=[d for g in rows['devices'].values() for d in g if d['udid']==sim]
 assert len(found)==1 and found[0]['state']=='Booted' and found[0]['name'].startswith('DANPER-SYNTHETIC-')
 info=plistlib.loads(runner_info.read_bytes());bundle_id=info['CFBundleIdentifier']
 assert 'interactiontests' in bundle_id.lower() and bundle_id.startswith('pe.danper.saludmovil.native.iloaderpreview.')
 print('RUNNER_BUNDLE',bundle_id,flush=True)
 container=None;probe=0;offset=0;pending=b'';seen=set();state=SensorReadiness()
 while True:
  if log.exists():
   with log.open('rb') as f:f.seek(offset);pending+=f.read();offset=f.tell()
   lines=pending.split(b'\n');pending=lines.pop()
   for raw in lines:
    event=state.observe(raw.decode('utf-8',errors='replace'))
    if event:print(*event,flush=True)
  now=time.monotonic()
  if container is None and now>=probe:
   probe=now+2
   r=subprocess.run(['xcrun','simctl','get_app_container',sim,bundle_id,'data'],capture_output=True,text=True)
   if r.returncode==0:
    container=Path(r.stdout.strip())/'Documents/DANPER_BIOMETRIC_READY'
    print('RUNNER_CONTAINER_FOUND',flush=True)
  if container is not None and state.ready:
   try:
    value=json.loads((container/'request.json').read_text());nonce=value['id'];minimum=value['minimumGeneration']
    assert re.fullmatch('[0-9A-Fa-f-]{36}',nonce) and value['event'] in ('match','nomatch') and isinstance(minimum,int) and minimum>0
    if nonce not in seen and state.permits(minimum):
     ack={'id':nonce,'event':value['event'],'ready':True,'generation':state.generation,'sensorActiveAt':state.ready_stamp,'clientContextAt':state.begin_stamp,'noAuthenticationInjected':True}
     tmp=container/'ready.pending';tmp.write_text(json.dumps(ack));tmp.replace(container/'ready.json');seen.add(nonce)
     print('READY_ACK',json.dumps(ack),flush=True)
   except (OSError,ValueError,KeyError,AssertionError):pass
  time.sleep(0.1)

if __name__=='__main__':main()
