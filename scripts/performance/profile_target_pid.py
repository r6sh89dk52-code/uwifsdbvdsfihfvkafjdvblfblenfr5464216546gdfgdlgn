"""Select only the explicit UI workload's process on its owned Simulator.

No host-wide process/argument enumeration. libproc checks a candidate's actual
executable path after UIKit reports it on the validated device's log stream.
"""
import ctypes,re
from datetime import datetime,timedelta

BUNDLE='pe.danper.saludmovil.native.iloaderpreview'
CASE='testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen'

def kernel_path(pid):
    if not 0<int(pid)<2**31:return None
    lib=ctypes.CDLL('/usr/lib/libproc.dylib')
    function=lib.proc_pidpath
    function.argtypes=[ctypes.c_int,ctypes.c_void_p,ctypes.c_uint32]
    function.restype=ctypes.c_int
    buffer=ctypes.create_string_buffer(4096)
    if function(int(pid),buffer,len(buffer))<=0:return None
    return buffer.value.decode('utf-8',errors='replace')

def explicit_launch_epoch(ui_log):
    lines=ui_log.splitlines()
    starts=[i for i,line in enumerate(lines) if CASE in line and 'started.' in line]
    if not starts:return None
    text='\n'.join(lines[starts[-1]:])
    start=re.search(r'Start Test at (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)',text)
    launches=re.findall(r't =\s*([\d.]+)s\s+Launch '+re.escape(BUNDLE)+r'\b',text)
    idle=re.search(r'Wait for '+re.escape(BUNDLE)+r' to idle',text)
    if not start or not launches or not idle:return None
    return datetime.fromisoformat(start[1])+timedelta(seconds=float(launches[0]))

def select_owned_pid(ui_log,lifecycle_log,sim,path_for_pid=kernel_path):
    launched=explicit_launch_epoch(ui_log)
    if launched is None:return None
    fragment='/CoreSimulator/Devices/'+sim+'/data/Containers/Bundle/Application/'
    rows=[]
    for line in lifecycle_log.splitlines():
        match=re.match(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+).*?\bDANPERNative\[(\d+):',line)
        if match and datetime.fromisoformat(match[1])>=launched:
            rows.append(int(match[2]))
    checked=set()
    for pid in reversed(rows):
        if pid in checked:continue
        checked.add(pid)
        path=path_for_pid(pid)
        if path and path.startswith('/') and not any(c.isspace() for c in path) and fragment in path and path.endswith('/DANPERNative.app/DANPERNative'):
            return str(pid)
    return None
