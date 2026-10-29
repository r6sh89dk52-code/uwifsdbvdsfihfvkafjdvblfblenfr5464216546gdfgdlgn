# Resumption checkpoint: three recovered UI failures

Verified branch `audit/glass-pro-iloader-20261028` at
`409c37149917d5c811229680a3f14d1450b171ed`.
Recovery run `40806554927` succeeded. No recovery or prior suites were repeated.
Read recovered artifact `12868187797` (RECOVERED_UI_LOGS_9280), including
all three summaries, test logs, attachment manifests and screen recordings.
The three separate xcresult archives remain in the same recovered run.

## Evidence and scope

- Biometric case: line 31, Cancel/Cancelar absent in SpringBoard after nomatch.
  System hierarchy exposes Dynamic Island and app switcher windows, no Cancel.
  Recording still shows “Verificando identidad…”. Enrollment availability PASS
  does not prove that the runner's Darwin event reached an active LA request.
  Root cause not yet proven; inspect CoreAuthUI and simulator auth logs.
- Premium case: line 34, `Siguiente.exists` remains true after on-screen number
  keyboard appears. Recording confirms keyboard. Footer is not visibly drawn
  above it; need hierarchy to distinguish stale/off-screen actions from another
  accessible button. Preserve the original assertion exactly.
- Protected case: line 167, home never appears. After permission Allow and match,
  recording/tree shows “No se pudo verificar tu identidad”. This is before
  source creation: no evidence of a vault/Kardex failure yet.

## Published diagnostic

`glass-ui-diagnostic.yml` runs only the three affected methods, each on a fresh
synthetic iPhone 16. Only Premium needs two fixture seed prerequisites. No Swift,
JavaScript, full native suite, other UI cases or IPA build is executed.
Test assertions and production authentication are unchanged. Added diagnostic
attachments capture app/SpringBoard/CoreAuthUI trees and the final screen; host
collects authentication logs and exports xcresult even after failure.

Manual invocation: workflow_dispatch when available on default-branch workflow
registry, or an explicit edit to `.github/glass-ui-diagnostic-request.json` on
this audit branch. The GitHub connector exposes no dispatch operation; the
request-file push path is an explicit invocation, matching the prior recovery
pattern. Ordinary code corrections do not trigger it. No full-audit trigger
was added.

## Next steps / release gate

1. Read GLASS_UI_DIAGNOSTIC_<SHA> from the targeted run; use the emitted source
   SHA and individual summaries. Do not rerun unchanged successful work.
2. Apply evidence-based minimal correction, then explicitly request only the
   affected cases. Diagnose instead of bypassing authentication or skipping.
3. After three pass, validate all 11 UI cases on the corrected checkout.
4. Assess reuse separately per suite: Swift package inputs may remain equal,
   while JS source guards that inspect UI/test code can be invalidated. Existing
   verify-reuse.py deliberately rejects these test edits; do not remove that
   protection or manufacture VALIDATED_SHA. Native suite must be repeated if
   app/test-host inputs change.
5. Generate unsigned ARM64 IPA only after all mandatory gates pass, with source
   manifest and SHA-256. No IPA is currently validated or published by this step.

Protected branches/main, production app, clinical data, Face ID policy and
DanperCore/Kardex v2 are unchanged in this diagnostic stage.
