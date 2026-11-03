"""Capture an already-launched owned DEMO app; synchronize only diagnostic UI."""
import argparse,hashlib,json,os,re,signal,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
from profile_target_pid import kernel_path

BUNDLE='pe.danper.saludmovil.native.iloaderpreview'
def owned_executable(path,sim):
    return bool(path and path.startswith('/') and not any(c.isspace() for c in path)
      and '/CoreSimulator/Devices/'+sim+'/data/Containers/Bundle/Application/' in path
      and path.endswith('/DANPERNative.app/DANPERNative'))

def completion_path(log,runner_data):
    paths=re.findall(r'^DANPER_PROFILE_COMPLETED_ACK (.+)$',log,re.M)
    if not paths:return None
    if len(set(paths))!=1:raise ValueError('Ambiguous completion paths')
    p=Path(paths[0])
    if not p.is_absolute() or '..' in p.parts:raise ValueError('Unsafe acknowledgment path')
    if not re.fullmatch(r'danper-profile-[0-9A-Fa-f-]{36}\.json',p.name):raise ValueError('Unexpected acknowledgment name')
    if (runner_data/'tmp').is_symlink():raise ValueError('Owned temporary directory was substituted')
    if p.parent.resolve()!=(runner_data/'tmp').resolve():raise ValueError('Not the owned UI runner temporary directory')
    return p

def write_ack(path,exit_code):
    # Never replace any existing file or follow an injected symlink.
    with path.open('x') as f:json.dump({'recorderExit':exit_code},f)

def activated_pid(log):
    ids=set(re.findall(r'^DANPER_PROFILE_ACTIVATED_APPLICATION .*?\bpid: (\d+)',log,re.M))
    if len(ids)>1:raise ValueError('Workload replaced the profiled process')
    return int(next(iter(ids))) if ids else None

def command(args,log,timeout):
    with log.open('w') as f:
        try:return subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=timeout).returncode
        except subprocess.TimeoutExpired:return 'timeout'

def capture(a):
    out=a.output;out.mkdir(parents=True,exist_ok=True)
    result={'template':a.template,'recorded':False,'readyBeforeUI':False,'uiRunnerModifiedForSynchronization':True,
      'appBinaryUnmodified':True,'physicalDeviceValidated':False,'scope':'Already-running synthetic Home, then full allergy UI assertions; two workers; recorder overhead'}
    def save():
        p=out/'COORDINATED_CAPTURE.json';temporary=p.with_suffix('.tmp')
        temporary.write_text(json.dumps(result,indent=2)+'\n');temporary.replace(p)
    save();child=None;ack=None
    try:
        devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
        own=[d for rows in devices['devices'].values() for d in rows if d['udid']==a.sim]
        assert len(own)==1 and own[0]['name'].startswith('DANPER-SYNTHETIC-') and own[0]['state']=='Booted'
        assert owned_executable(kernel_path(a.pid),a.sim)
        result.update(pid=a.pid,simulator=a.sim)
        # Time Profiler needs the actual public os_signpost instrument for
        # complete Danper spans; probe before launching the timed UI workload.
        help_file=out/'record-help.log';probe_file=out/'instruments.log'
        assert command(['xcrun','xctrace','help','record'],help_file,60)==0
        assert command(['xcrun','xctrace','list','instruments'],probe_file,60)==0
        assert '--instrument' in help_file.read_text() and 'os_signpost' in probe_file.read_text()
        trace=out/(a.template.replace(' ','-')+'.trace');log=out/'record.log'
        args=['xcrun','xctrace','record','--template',a.template,'--instrument','os_signpost',
          '--device',a.sim,'--no-prompt','--attach',str(a.pid),'--time-limit','600s','--output',str(trace)]
        with log.open('w') as f:
            child=subprocess.Popen(args,stdout=f,stderr=subprocess.STDOUT)
            startup=time.monotonic()+180;started=None;stop_deadline=None
            while child.poll() is None:
                now=time.monotonic();rec=log.read_text(errors='replace')
                if started is None and 'Starting recording with' in rec:started=now
                if not result['readyBeforeUI'] and started is not None and now-started>=5:
                    assert owned_executable(kernel_path(a.pid),a.sim)
                    result['readyBeforeUI']=True;save();a.ready.write_text(str(a.pid))
                if not result['readyBeforeUI'] and now>=startup:raise TimeoutError('Recorder never announced actual attachment')
                ui=a.ui_log.read_text(errors='replace') if a.ui_log.exists() else ''
                pid=activated_pid(ui)
                if pid is not None:assert pid==a.pid,'XCTest launched a replacement process'
                candidate=completion_path(ui,a.runner_data)
                if candidate is not None and ack is None:
                    assert result['readyBeforeUI'] and pid==a.pid
                    assert owned_executable(kernel_path(a.pid),a.sim),'App exited before coordinated stop'
                    ack=candidate;result['completedAllClinicalAssertionsBeforeStop']=True
                    result['singleStopRequested']=True;save()
                    child.send_signal(signal.SIGINT);stop_deadline=now+180
                if stop_deadline is not None and now>=stop_deadline:raise TimeoutError('Recorder failed to finalize while app remained alive')
                if now>=startup+600:raise TimeoutError('Bounded full recording exceeded')
                time.sleep(.25)
        result['recorderExit']=child.returncode
        assert ack is not None,'Trace ended before workload completed; not a valid comparison'
        write_ack(ack,child.returncode)
        assert child.returncode==0 and trace.exists()
        result['recorded']=True;save()
        toc=out/'trace-toc.xml'
        assert command(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(toc)],out/'toc.log',120)==0
        root=ET.parse(toc).getroot();result['tocExported']=True;result['exports']=[]
        schemas={t.get('schema') for t in root.iter('table')}
        desired=['time-profile','os-signpost-interval','potential-hangs','runloop-events'] if a.template=='Time Profiler' else ['os-signpost-interval']
        for schema in desired:
            row={'schema':schema,'exported':False};result['exports'].append(row)
            if schema not in schemas:continue
            target=out/(schema+'.xml')
            code=command(['xcrun','xctrace','export','--input',str(trace),'--xpath',f'/trace-toc/run/data/table[@schema="{schema}"]','--output',str(target)],out/(schema+'.log'),300)
            row.update(exit=code,exported=code==0,file=target.name)
            if code==0:row['rows']=sum(1 for _,e in ET.iterparse(target,events=('end',)) if e.tag=='row')
            save()
        if a.template=='Allocations':
            import runpy
            details=runpy.run_path(str(Path(__file__).with_name('export-allocation-details.py')))['export'](trace,out/'details',180)
            result['allocationDetails']=details;assert details['successful']
            stats=ET.parse(out/'details/Allocations-Statistics.xml')
            totals=[r.attrib for r in stats.iter('row') if r.get('category')=='All Heap & Anonymous VM']
            assert len(totals)==1 and int(totals[0]['count-total'])>0
            result['allocationTotals']=totals[0]
        else:
            assert all(x['exported'] and x.get('rows',0)>0 for x in result['exports'] if x['schema'] in ['time-profile','os-signpost-interval'])
            spans=ET.parse(out/'os-signpost-interval.xml').getroot();ids={e.get('id'):e for e in spans.iter() if e.get('id')}
            durations=[]
            for row in spans.iter('row'):
                cells=[ids[e.get('ref')] if e.get('ref') else e for e in row]
                if len(cells)>8 and cells[3].text=='Confirmed allergy save' and cells[5].text=='pe.danper.saludmovil.performance' and cells[8].tag!='sentinel':durations.append(int(cells[1].text)/1e6)
            assert 1<=len(durations)<=2,'Missing/ambiguous allergy attempt spans; no target latency inferred'
            result['confirmedAllergySaveMS']=durations
        intervals=re.findall(r'^DANPER_PROFILE_SAVE_INTERVAL_MS ([0-9.]+)$',a.ui_log.read_text(errors='replace'),re.M)
        assert len(intervals)==1 and float(intervals[0])>0,'No actual tap-to-confirmation automation interval'
        result['automatedSaveConfirmationIntervalMS']=float(intervals[0])
        result['intervalLimitation']='Includes XCTest tap helper, scrolling/query/idle overhead; not physical iPhone or pure app latency'
        result['successful']=True
    except Exception as error:
        result.update(successful=False,error=type(error).__name__+': '+str(error))
        if ack is not None and not ack.exists():write_ack(ack,1)
    finally:
        if child is not None and child.poll() is None:child.kill();child.wait(timeout=10)
        save()
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--sim',required=True);p.add_argument('--pid',type=int,required=True)
    p.add_argument('--template',choices=['Time Profiler','Allocations'],required=True)
    for name in ['output','ready','ui-log','runner-data']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();r=capture(a);print(json.dumps(r,indent=2));raise SystemExit(0 if r['successful'] else 1)
