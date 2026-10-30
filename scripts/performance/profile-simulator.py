#!/usr/bin/env python3
"""Observe ONLY a newly created synthetic Simulator. No auth events or PII logs."""
import json,subprocess,sys,time
from pathlib import Path

sim,out=sys.argv[1],Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
rows=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','-j']))
devices=[d for group in rows['devices'].values() for d in group if d['udid']==sim]
assert len(devices)==1 and devices[0]['name'].startswith('DANPER-SYNTHETIC-') and devices[0]['state']=='Booted'
bundle='pe.danper.saludmovil.native.iloaderpreview'
report={'syntheticSimulatorOnly':True,'containsPatientIdentifiers':False,'captures':[]}
def save(): (out/'profiling-status.json').write_text(json.dumps(report,indent=2))
save()
subprocess.run(['xcrun','xctrace','help','record'],stdout=(out/'xctrace-record-help.txt').open('w'),stderr=subprocess.STDOUT,timeout=20)
pid=None
for _ in range(180):
    p=subprocess.run(['xcrun','simctl','spawn',sim,'launchctl','list'],capture_output=True,text=True,timeout=15)
    for line in p.stdout.splitlines():
        fields=line.split()
        if fields and fields[0].isdigit() and 'UIKitApplication:'+bundle+'[' in line:
            pid=fields[0];break
    if pid:break
    time.sleep(1)
if not pid:
    report['limitation']='No application process was observed before the bounded wait expired.';save();sys.exit(0)
for template,seconds in [('Time Profiler',60),('Allocations',45)]:
    name=template.replace(' ','-');trace=out/(name+'.trace')
    entry={'template':template,'captured':False}
    report['captures'].append(entry);save()
    try:
        with (out/(name+'.log')).open('w') as log:
            p=subprocess.run(['xcrun','xctrace','record','--template',template,'--device',sim,
                '--attach',pid,'--time-limit',str(seconds)+'s','--output',str(trace)],
                stdout=log,stderr=subprocess.STDOUT,timeout=seconds+45)
        entry['exit']=p.returncode
        entry['captured']=p.returncode==0 and trace.exists()
        if entry['captured']:
            toc=out/(name+'-toc.xml')
            e=subprocess.run(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(toc)],
                capture_output=True,text=True,timeout=30)
            entry['tocExported']=e.returncode==0
        else:entry['limitation']='Recording did not succeed; inspect the actual tool log. No metric is inferred.'
    except subprocess.TimeoutExpired:
        entry['limitation']='Instruments recording exceeded its bounded collection interval.'
    save()
