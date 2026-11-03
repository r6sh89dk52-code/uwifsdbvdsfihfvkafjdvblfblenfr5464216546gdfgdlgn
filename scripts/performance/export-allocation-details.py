#!/usr/bin/env python3
"""Export the actual Allocations view details listed by a sealed trace TOC."""
import argparse,json,subprocess,xml.etree.ElementTree as ET
from pathlib import Path

def detail_queries(toc):
    root=ET.fromstring(toc)
    if root.tag!='trace-toc':raise ValueError('Not an actual xctrace TOC')
    queries=[]
    for run in root.findall('run'):
        number=run.get('number','')
        if not number.isdecimal():raise ValueError('Invalid run number')
        for detail in run.findall('./tracks/track[@name="Allocations"]/details/detail'):
            name=detail.get('name')
            if name not in ('Statistics','Allocations List'):continue
            queries.append((name,f'/trace-toc/run[@number="{number}"]/tracks/track[@name="Allocations"]/details/detail[@name="{name}"]'))
    if len(queries)!=2 or {name for name,_ in queries}!={'Statistics','Allocations List'}:
        raise ValueError('Expected one real Statistics and Allocations List detail; no fabricated data fallback')
    return queries

def xml_counts(path):
    # Stream the potentially large list; do not multiply allocation-export RAM.
    counts={}
    for _,element in ET.iterparse(path,events=('end',)):
        counts[element.tag]=counts.get(element.tag,0)+1
        element.clear()
    return counts

def export(trace,out,timeout=180):
    out.mkdir(parents=True,exist_ok=True)
    result={'scope':'Existing current-source Allocations trace, no recording or app modification','input':str(trace),'exports':[],'measurementsInferred':False}
    def command(args,log):
        with log.open('w') as f:
            try:return subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=timeout).returncode
            except subprocess.TimeoutExpired:return 'timeout'
    toc=out/'Allocations-details-toc.xml'
    try:
        result['tocExit']=command(['xcrun','xctrace','export','--input',str(trace),'--toc','--output',str(toc)],out/'toc-export.log')
        if result['tocExit']!=0:raise RuntimeError('TOC export failed')
        for name,query in detail_queries(toc.read_text()):
            target=out/('Allocations-'+name.replace(' ','-')+'.xml')
            row={'detail':name,'xpath':query,'file':target.name};result['exports'].append(row)
            row['exit']=command(['xcrun','xctrace','export','--input',str(trace),'--xpath',query,'--output',str(target)],target.with_suffix('.log'))
            if row['exit']==0 and target.exists():
                row['bytes']=target.stat().st_size
                row['xmlElementCounts']=xml_counts(target)
        result['successful']=len(result['exports'])==2 and all(x['exit']==0 and x.get('xmlElementCounts') for x in result['exports'])
    except Exception as error:result.update(successful=False,error=str(error))
    (out/'ALLOCATION_DETAIL_EXPORT_STATUS.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();r=export(a.input,a.output)
    print(json.dumps(r,indent=2));raise SystemExit(0 if r['successful'] else 1)
