#!/usr/bin/env python3
"""Observe ONLY a newly created synthetic Simulator. No auth events or PII logs."""
import json,subprocess,sys,time,xml.etree.ElementTree as ET
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
def observe_app():
    deadline=time.monotonic()+180
    while time.monotonic()<deadline:
        p=subprocess.run(['xcrun','simctl','spawn',sim,'launchctl','list'],capture_output=True,text=True,timeout=15)
        for line in p.stdout.splitlines():
            fields=line.split()
            if fields and fields[0].isdigit() and 'UIKitApplication:'+bundle+'[' in line:
                return fields[0]
        time.sleep(1)
    return None
for template,seconds in [('Time Profiler',60),('Allocations',45)]:
    name=template.replace(' ','-');trace=out/(name+'.trace')
    entry={'template':template,'captured':False}
    report['captures'].append(entry);save()
    try:
        # XCUIApplication.launch can replace the process between test methods.
        # Never reuse the previous capture's PID for the next template.
        pid=observe_app()
        if not pid:
            entry['limitation']='No application process was observed before the bounded wait expired.';save();continue
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
            if e.returncode==0:
                schemas=sorted({t.attrib.get('schema','') for t in ET.parse(toc).iter('table')})
                entry['availableSchemas']=schemas;entry['dataExports']=[]
                for schema in schemas:
                    if not any(key in schema for key in ('time-profile','allocation','os-signpost')):continue
                    # Use schemas actually exposed by this trace, not assumed
                    # data. Raw rows permit CPU/allocation analysis off macOS.
                    safe=''.join(c if c.isalnum() or c in '-_' else '_' for c in schema)
                    target=out/(name+'-'+safe+'.xml')
                    exported=subprocess.run(['xcrun','xctrace','export','--input',str(trace),
                        '--xpath','/trace-toc/run/data/table[@schema="'+schema+'"]','--output',str(target)],
                        capture_output=True,text=True,timeout=45)
                    entry['dataExports'].append({'schema':schema,'exported':exported.returncode==0,'file':target.name})
                    (out/(name+'-'+safe+'-export.log')).write_text(exported.stdout+exported.stderr)
        else:entry['limitation']='Recording did not succeed; inspect the actual tool log. No metric is inferred.'
    except subprocess.TimeoutExpired:
        entry['limitation']='Instruments recording exceeded its bounded collection interval.'
    except (ET.ParseError,OSError) as error:
        entry['limitation']='Trace inspection failed: '+str(error)
    save()
