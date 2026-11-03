"""Build an identical read-only diagnostic harness around sealed app binaries."""
from pathlib import Path
import hashlib,json,os,subprocess

OBSERVER='''def observe_app():
    # UIKit events from this validated device, after the real XCTest launch.
    # Query only candidate executable paths; never enumerate host command lines.
    ui=Path(os.environ['DANPER_PROFILE_UI_LOG'])
    lifecycle=Path(os.environ['DANPER_PROFILE_LIFECYCLE_LOG'])
    deadline=time.monotonic()+180
    while time.monotonic()<deadline:
        if ui.exists() and lifecycle.exists():
            pid=select_owned_pid(ui.read_text(errors='replace'),
                lifecycle.read_text(errors='replace'),sim)
            if pid:
                entry['selection']='explicit XCTest launch + owned device lifecycle + libproc executable path'
                return pid
        time.sleep(.25)
    return None
'''
SUPERVISOR='''def record_until_workload_done(args,stdout,stderr,timeout):
    done=Path(os.environ['DANPER_PROFILE_WORKLOAD_DONE'])
    child=subprocess.Popen(args,stdout=stdout,stderr=stderr)
    deadline=time.monotonic()+timeout
    try:
        while child.poll() is None:
            if done.exists():
                entry['stoppedAfterWorkload']=True
                child.send_signal(signal.SIGINT)
                child.wait(timeout=90)
                break
            if time.monotonic()>=deadline:
                raise subprocess.TimeoutExpired(args,timeout)
            time.sleep(.25)
        return subprocess.CompletedProcess(args,child.returncode)
    finally:
        if child.poll() is None:
            child.kill();child.wait(timeout=10)
'''
PROBE='''extra_instruments=[]
try:
    probe=subprocess.run(['xcrun','xctrace','list','instruments'],capture_output=True,text=True,timeout=20)
    (out/'xctrace-instruments.txt').write_text(probe.stdout+probe.stderr)
    names={line.strip().strip('"') for line in probe.stdout.splitlines()}
    selected=next((n for n in ['os_signpost','Points of Interest'] if n in names),None)
    if probe.returncode==0 and '--instrument' in (out/'xctrace-record-help.txt').read_text() and selected:
        extra_instruments=['--instrument',selected]
    report['additionalSignpostInstrument']=selected if extra_instruments else None
except (OSError,subprocess.TimeoutExpired) as error:
    report['instrumentProbeLimitation']=str(error)
save()
'''
WORKLOAD='''  for template in 'Time Profiler' 'Allocations'; do
   label="active-${template// /-}"
   fresh "$label"
   run_tests "availability-$label" 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests
   run_tests "seed-$label" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
   xcrun simctl terminate "$SIM_ID" pe.danper.saludmovil.native.iloaderpreview >/dev/null 2>&1 || true
   export DANPER_PROFILE_UI_LOG="$OUT/$label.log"
   export DANPER_PROFILE_LIFECYCLE_LOG="$OUT/$label-lifecycle.log"
   export DANPER_PROFILE_WORKLOAD_DONE="$OUT/$label-workload-done.txt"
   python3 -u scripts/glass-audit/simulator-ready-bridge.py --stream "$SIM_ID" > "$DANPER_PROFILE_LIFECYCLE_LOG" 2>&1 & lifecycle_pid=$!
   (
    trap - EXIT
    result=0
    run_tests "$label" 1 -only-testing:DANPERInteractionTests/N2AllergySaveInteractionTests/testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen || result=$?
    printf '%s\\n' "$result" > "$DANPER_PROFILE_WORKLOAD_DONE"
    exit "$result"
   ) & workload_pid=$!
   DANPER_PROFILE_TEMPLATE="$template" python3 scripts/performance/profile-simulator.py "$SIM_ID" "$OUT/Instruments/$label"
   workload_status=0
   wait "$workload_pid" || workload_status=$?
   kill "$lifecycle_pid" 2>/dev/null || true; wait "$lifecycle_pid" 2>/dev/null || true
   printf '%s %s\\n' "$label" "$workload_status" >> "$OUT/WORKLOAD_EXIT.txt"
  done
'''

def prepare():
    current=Path(os.environ['GITHUB_WORKSPACE'])/'current'
    harness=Path(__file__).resolve().parents[2]
    before=Path(os.environ['RUNNER_TEMP'])/'profile-source-before'
    baseline='c274140aa631a7e9c262381dbff3f6a1f9a62582'
    subprocess.run(['git','worktree','add','--detach',str(before),baseline],cwd=current,check=True)
    subprocess.run(['git','diff','--exit-code',baseline,'HEAD','--',
      'native-ios/InteractionTests/N2AllergySaveInteractionTests.swift',
      'native-ios/NativeTests/N2PremiumDemoFixtureTests.swift',
      'native-ios/NativeTests/N2SimpleInventoryNativeTests.swift'],cwd=current,check=True)
    paths=['scripts/glass-audit/validate-macos.sh','scripts/glass-audit/check-xcresult.py',
      'scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/prepare-auth-ui.sh',
      'scripts/glass-audit/simulator-ready-bridge.py','scripts/performance/owned_process.py',
      'scripts/performance/installer_failure.py','scripts/performance/test-products.py',
      'scripts/performance/profile-simulator.py']
    helpers={p:(current/p).read_bytes() for p in paths}
    helper_path='scripts/performance/profile_target_pid.py'
    helpers[helper_path]=(harness/helper_path).read_bytes()
    for label,root in [('before',before),('after',current)]:
        for path,content in helpers.items():
            p=root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
        p=root/'scripts/performance/profile-simulator.py';s=p.read_text()
        s=s.replace('import json,os,subprocess,sys,time,xml.etree.ElementTree as ET','import json,os,signal,subprocess,sys,time,xml.etree.ElementTree as ET')
        s=s.replace('from owned_process import find_owned_app','from profile_target_pid import select_owned_pid')
        start=s.index('def observe_app():');end=s.index('\nfor template,seconds',start)
        s=s[:start]+OBSERVER+'\n'+SUPERVISOR+'\n'+PROBE+s[end:]
        loop="for template,seconds in [('Time Profiler',60),('Allocations',45)]:"
        assert s.count(loop)==1
        s=s.replace(loop,"for template,seconds in [('Time Profiler',600),('Allocations',600)]:\n    if template!=os.environ['DANPER_PROFILE_TEMPLATE']:continue")
        s=s.replace("('time-profile','allocation','os-signpost')","('time-profile','time-sample','runloop-events','potential-hangs','allocation','os-signpost')")
        s=s.replace("p=subprocess.run(['xcrun','xctrace','record','--template',template,", "p=record_until_workload_done(['xcrun','xctrace','record','--template',template]+extra_instruments+[")
        s=s.replace('Separate synthetic Home process; not concurrent with functional UI tests; not physical iPhone latency',
          'Active fictional allergy journey; two workers; same runner; profiler overhead; not physical iPhone latency')
        compile(s,'generated-owned-profiler','exec');assert "['ps'," not in s and 'record_until_workload_done([' in s
        p.write_text(s)
        p=root/'scripts/glass-audit/validate-macos.sh';s=p.read_text()
        assert s.count(' fresh native\n')==1
        s=s.replace(' fresh native\n',' if test "$MODE" != b15-profile; then fresh native; fi\n')
        preflight=' run_tests biometric-preflight 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests'
        assert s.count(preflight)==1;s=s.replace(preflight,' if test "$MODE" != b15-profile; then'+preflight+'; fi')
        seed='  run_tests seed-profile 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests'
        assert s.count(seed)==1;s=s.replace(seed,'  # Fresh owned device and fixture for EACH measured template below.')
        start=s.index('  xcrun simctl launch --terminate-running-process "$SIM_ID" pe.danper.saludmovil.native.iloaderpreview --danper-redesign-demo > "$OUT/profile-owned-launch.log"')
        end=s.index('  git rev-parse HEAD > "$OUT/PROFILE_SOURCE_SHA.txt"',start)
        s=s[:start]+WORKLOAD+s[end:];p.write_text(s)
        subprocess.run(['bash','-n',str(p)],check=True)
        subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios/App','native-ios/Sources',
          'native-ios/NativeTests','native-ios/InteractionTests','native-ios/project.yml'],cwd=root,check=True)
        out=Path(os.environ['RUNNER_TEMP'])/('active-profile-'+label);out.mkdir()
        (out/'HARNESS.diff').write_bytes(subprocess.check_output(['git','diff','--','scripts'],cwd=root))
        (out/'HARNESS_HELPERS_SHA256.json').write_text(json.dumps({k:hashlib.sha256(v).hexdigest() for k,v in helpers.items()},indent=2))
        (out/'GENERATED_HARNESS_SHA256.json').write_text(json.dumps({k:hashlib.sha256((root/k).read_bytes()).hexdigest() for k in helpers},indent=2))
        products=Path(os.environ['RUNNER_TEMP'])/('profile-derived-'+label)/'Build/Products'
        proof=Path(os.environ['RUNNER_TEMP'])/('profile-compiled-'+label)/'TEST_PRODUCTS.json'
        subprocess.run(['python3','scripts/performance/test-products.py','verify',str(products),str(proof)],cwd=root,check=True)
        arch=subprocess.check_output(['lipo','-archs',str(products/'Debug-iphonesimulator/DANPERNative.app/DANPERNative')],text=True).strip()
        assert arch=='x86_64'
        info={'scope':'Same-runner before/after active synthetic UI; NOT release approval',
          'sourceSHA':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
          'workflowSHA':os.environ['GITHUB_SHA'],'runnerArchitecture':arch,'seedWorkers':2,
          'appAndUITestBinariesUnmodified':True,'workloadAndSeedSourcesIdentical':True,
          'processSelection':'explicit UI launch log + owned Simulator lifecycle + libproc executable path',
          'maxSecondsPerTemplate':600,'stopWhenActualWorkloadFinishes':True,'freshDevicePerTemplate':True,
          'profilerOverheadIncluded':True,'physicalDeviceValidated':False,'IPA':False}
        (out/'ORCHESTRATION.json').write_text(json.dumps(info,indent=2))

if __name__=='__main__':prepare()
