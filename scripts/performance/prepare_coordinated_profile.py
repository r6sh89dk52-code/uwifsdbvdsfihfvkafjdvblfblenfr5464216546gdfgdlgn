"""Prepare one identical diagnostic UI runner around two original sealed apps."""
import hashlib,json,os,shutil,subprocess
from pathlib import Path
from verify_diagnostic_products import manifest

WORKLOAD='''  overall=0
  for template in 'Time Profiler' 'Allocations'; do
   label="coordinated-${template// /-}"
   fresh "$label"
   run_tests "availability-$label" 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests
   run_tests "seed-$label" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
   launch=$(xcrun simctl launch --terminate-running-process "$SIM_ID" pe.danper.saludmovil.native.iloaderpreview --danper-redesign-demo)
   app_pid=${launch##*: }
   runner_data=$(xcrun simctl get_app_container "$SIM_ID" pe.danper.saludmovil.native.iloaderpreview.interactiontests.xctrunner data)
   ready="$OUT/$label-ready.txt"
   python3 scripts/performance/coordinated_capture.py --sim "$SIM_ID" --pid "$app_pid" --template "$template" --output "$OUT/Instruments/$label" --ready "$ready" --ui-log "$OUT/$label.log" --runner-data "$runner_data" > "$OUT/$label-coordinator.log" 2>&1 & recorder=$!
   ready_status=0
   python3 - "$ready" "$OUT/Instruments/$label/COORDINATED_CAPTURE.json" <<'PYREADY' || ready_status=$?
import json,sys,time
from pathlib import Path
ready,status=map(Path,sys.argv[1:]);deadline=time.monotonic()+200
while time.monotonic()<deadline:
 if ready.exists():break
 if status.exists() and json.loads(status.read_text()).get('successful') is False:raise RuntimeError('Recorder startup failed')
 time.sleep(.25)
else:raise RuntimeError('No actual recorder readiness; UI workload not started')
PYREADY
   ui_status=1
   if test "$ready_status" = 0; then
    ui_status=0
    run_tests "$label" 1 -only-testing:DANPERInteractionTests/N2AllergySaveInteractionTests/testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen || ui_status=$?
   fi
   capture_status=0
   wait "$recorder" || capture_status=$?
   printf '%s ui=%s capture=%s\\n' "$label" "$ui_status" "$capture_status" >> "$OUT/COORDINATED_EXIT.txt"
   if test "$ui_status" != 0 || test "$capture_status" != 0; then overall=1; fi
  done
  test "$overall" = 0
'''

def prepare():
    workspace=Path(os.environ['GITHUB_WORKSPACE']);current=workspace/'current';harness=Path(__file__).resolve().parents[2]
    temp=Path(os.environ['RUNNER_TEMP']);before=temp/'coordinated-source-before';baseline='c274140aa631a7e9c262381dbff3f6a1f9a62582'
    subprocess.run(['git','worktree','add','--detach',str(before),baseline],cwd=current,check=True)
    # Clinical UI assertions and fixture sources must match before diagnostic hooks.
    subprocess.run(['git','diff','--exit-code',baseline,'HEAD','--','native-ios/InteractionTests/N2AllergySaveInteractionTests.swift','native-ios/NativeTests/N2PremiumDemoFixtureTests.swift','native-ios/NativeTests/N2SimpleInventoryNativeTests.swift'],cwd=current,check=True)
    subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios/App','native-ios/Sources','native-ios/NativeTests','native-ios/project.yml'],cwd=current,check=True)
    runner=temp/'diagnostic-derived/Build/Products/Debug-iphonesimulator/DANPERInteractionTests-Runner.app'
    assert runner.is_dir()
    generated=(current/'native-ios/InteractionTests/N2AllergySaveInteractionTests.swift').read_bytes()
    original_harness=(current/'scripts/glass-audit/validate-macos.sh').read_text()
    helpers=['scripts/glass-audit/check-xcresult.py','scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/prepare-auth-ui.sh','scripts/performance/installer_failure.py']
    for label,root in [('before',before),('after',current)]:
        products=temp/('coordinated-derived-'+label)/'Build/Products';original=temp/('coordinated-compiled-'+label)/'TEST_PRODUCTS.json'
        # Original same-source hashes/native proof verified BEFORE any overlay.
        subprocess.run(['python3',str(current/'scripts/performance/test-products.py'),'verify',str(products),str(original)],cwd=root,check=True)
        original_data=json.loads(original.read_text());runner_dest=products/'Debug-iphonesimulator/DANPERInteractionTests-Runner.app'
        shutil.rmtree(runner_dest);shutil.copytree(runner,runner_dest,symlinks=True)
        assert manifest(runner_dest)==manifest(runner),'Diagnostic runner copy differs between variants'
        after=manifest(products);prefix='Debug-iphonesimulator/DANPERInteractionTests-Runner.app/'
        assert {k:v for k,v in after.items() if not k.startswith(prefix)}=={k:v for k,v in original_data['files'].items() if not k.startswith(prefix)}
        composite={'sourceSHA':original_data['sourceSHA'],'xcode':original_data['xcode'],'files':after,
          'originalProofPath':str(original),'originalProofSHA256':hashlib.sha256(original.read_bytes()).hexdigest(),
          'diagnosticUIRunnerOnly':True,'appAndNativeBinariesUnmodified':True,'diagnosticUISourceSHA256':hashlib.sha256(generated).hexdigest()}
        proof=temp/('coordinated-proof-'+label+'.json');proof.write_text(json.dumps(composite,indent=2))
        for path in helpers:
            p=root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((current/path).read_bytes())
        for path in ['coordinated_capture.py','profile_target_pid.py','export-allocation-details.py','verify_diagnostic_products.py']:
            p=root/'scripts/performance'/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((harness/'scripts/performance'/path).read_bytes())
        s=original_harness
        s=s.replace('python3 scripts/performance/test-products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"','python3 scripts/performance/verify_diagnostic_products.py "$DD/Build/Products" "$DANPER_TEST_PROOF"')
        assert s.count(' fresh native\n')==1;s=s.replace(' fresh native\n',' if test "$MODE" != b15-profile; then fresh native; fi\n')
        pre=' run_tests biometric-preflight 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests';assert s.count(pre)==1
        s=s.replace(pre,' if test "$MODE" != b15-profile; then'+pre+'; fi')
        start=s.index('  run_tests seed-profile 2 ');end=s.index('  git rev-parse HEAD > "$OUT/PROFILE_SOURCE_SHA.txt"',start)
        s=s[:start]+WORKLOAD+s[end:]
        p=root/'scripts/glass-audit/validate-macos.sh';p.write_text(s);subprocess.run(['bash','-n',str(p)],check=True)
        out=temp/('coordinated-profile-'+label);out.mkdir()
        (out/'DIAGNOSTIC_PRODUCT_PROOF.json').write_text(json.dumps(composite,indent=2))
        (out/'ORCHESTRATION.json').write_text(json.dumps({'sourceSHA':original_data['sourceSHA'],'workflowSHA':os.environ['GITHUB_SHA'],'diagnosticUIRunnerOnly':True,'appAndNativeBinariesUnmodified':True,'diagnosticUISourceSHA256':hashlib.sha256(generated).hexdigest(),'diagnosticUIRunnerSHA256':hashlib.sha256(json.dumps(manifest(runner),sort_keys=True).encode()).hexdigest(),'freshDevicePerTemplate':True,'seedWorkers':2,'IPA':False,'physicalDeviceValidated':False},indent=2))
        (out/'GENERATED_DIAGNOSTIC_UI.swift').write_bytes(generated)
        (out/'HARNESS.diff').write_bytes(subprocess.check_output(['git','diff','--','scripts/glass-audit/validate-macos.sh'],cwd=root))

if __name__=='__main__':prepare()
