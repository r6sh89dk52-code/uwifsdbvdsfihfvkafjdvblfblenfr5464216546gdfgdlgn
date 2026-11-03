import os,subprocess
from pathlib import Path

BLOCK='''  run_tests large-seed 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testSeed9648WorkersAnd1005VisitsInEmptyDemo
  run_tests original-fixtures 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
  run_tests large-invariants-before 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testCaptureCompletePhysicalWorkersAndHistoryBeforeReview
  run_tests large-measured-api 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testMeasureNativeAllergyAndSearchOnLargeDemo
  run_tests large-invariants-after 1 -only-testing:DANPERNativeTests/N2LargeRosterProfileFixture/testVerifyLargeReviewPreservedPhysicalWorkersHistoryAndDraft
'''
if __name__=='__main__':
 workspace=Path(os.environ['GITHUB_WORKSPACE']);current=workspace/'current';harness=Path(__file__).resolve().parents[2]
 original=(current/'scripts/glass-audit/validate-macos.sh').read_text()
 helpers=['scripts/glass-audit/check-xcresult.py','scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/prepare-auth-ui.sh','scripts/performance/installer_failure.py']
 for label,root in [('before',Path(os.environ['RUNNER_TEMP'])/'large-source-before'),('after',current)]:
  for name in helpers:
   p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((current/name).read_bytes())
  for name in ['native-ios/NativeTests/N2LargeRosterProfileFixture.swift','scripts/performance/verify_large_native_products.py']:
   p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((harness/name).read_bytes())
  s=original.replace('python3 scripts/performance/test-products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"','python3 scripts/performance/verify_large_native_products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"')
  start=s.index('  run_tests seed-profile 2 ');end=s.index('  git rev-parse HEAD > "$OUT/PROFILE_SOURCE_SHA.txt"',start)
  s=s[:start]+BLOCK+s[end:]
  p=root/'scripts/glass-audit/validate-macos.sh';p.write_text(s);subprocess.run(['bash','-n',str(p)],check=True)
