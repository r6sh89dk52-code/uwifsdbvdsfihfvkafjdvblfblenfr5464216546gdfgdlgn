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

## Published run checkpoint

Diagnostic source commit: `bd2630578a2fc8098947e903f61853702ffd1407`.
Run: `40807354709`, job `123229369663` (macos-15-intel).
This is the ONLY new execution requested by this continuation. Read its current
status from GitHub; no result is asserted by this checkpoint.

Follow-up infrastructure change: print explicit diagnostic phases and stream
build output into the Actions console. The request file can now select a strict,
nonempty subset of the three allowed case identifiers. This enables repeating
only failures after an individual case passes. No assertions changed, no new
run is requested by this infrastructure commit, and the existing run continues
to execute its original `bd263057` snapshot.

## Diagnostic 40807354709: results and concrete cause

Run reached the job time limit; all three xcresult summaries and attachments
survived in artifact `12870218245` (ZIP SHA-256
`944c32f78ea378322d250539b70f0ce033258008a70ecc753a153859969b159d`).
- Biometric: 0/1 PASS, Cancel absent. System log 02:57:43.643 queues the system
  UI with its fixed 5-second watchdog; 02:57:48.936 coreauthd returns Code=-1000,
  `UI activation timed out after 5 seconds`. CoreAuthUI activates only later,
  then reports `No pending UI mechanism`. The nomatch was posted after that
  mechanism had already failed. This is direct system evidence, not enrollment
  failure and not a successful or bypassed authentication.
- Premium: 1/1 PASS, both keyboard assertions, navigation and persisted deletion
  completed. No production change. Diagnostic attachment was before the first
  keyboard assertion, adding observational delay. Move it AFTER that assertion
  for the next run so the original five-second check remains immediate.
- Protected: 0/1 PASS. Real simulated authentication, manual creation of the
  fictional protected source and initial home display succeeded. Failure is
  on the second launch, line 151: automatic authentication has already failed
  before `Verificando identidad…` is observed. No second match was sent.
  Protected system stream was not collected before job cancellation; inspect
  the next run's live stream for the precise relaunch error.

## Minimal corrections under test (not yet validated)

- Bring the targeted Simulator UI client up and prelaunch only CoreAuthUI before
  DANPER's first LAContext, allowing cold startup outside the system watchdog.
  This is an environment hypothesis grounded in the activation-timeout log.
  It performs NO biometric match, NO app authorization, and NO vault access.
  If simctl refuses the prelaunch, fail before the expensive compilation.
- Find the actual Cancel/Cancelar button across SpringBoard, the app's hosted
  system UI and CoreAuthUI. Still require a real hittable button and tap it;
  preserve cancellation, no-loop, retry, success and foreground assertions.
- Stream authentication logs BEFORE each case; store the relaunch failure even
  if the step later times out. Keep one build and independent isolated devices.
- Separate build/case time limits and publish each case immediately. A final
  strict gate checks every selected summary, zero failures/skips and exact SHA.
- Cache compiler outputs only after successful build; Xcode still validates and
  rebuilds inputs. No successful test result is inferred from that cache.

Next explicit request repeats the three affected methods, since Premium's
instrumentation timing changed too. It does not run any other UI method, the
Swift/JS/native suites, or the IPA stage. App, native tests and DanperCore remain
byte-identical to the recovered baseline; only diagnostic infrastructure and
interaction-test synchronization have changed.

## Second diagnostic and prepared final gate

Second diagnostic source: `47fa1a9fd2be5d3b9d281eda1e2b1fc5c3413cbb`.
Run `40814464695`, job `123252188177`. Check GitHub for its current result;
this checkpoint does not claim it passed.

The final `glass-ui-release.yml` pipeline is prepared but not requested. No
`.github/glass-final-release-request.json` exists yet. Its Ubuntu gate requires
an actual DIAGNOSED_3_SHA marker plus all three one-test PASS summaries, with
zero skips, and identical current app/UI/resource/auth-preparation inputs.
Only after this passes may the Mac runner validate all 11 UI tests and package.

Reuse is now scoped per suite, rather than rejecting every interaction-test
edit as if it changed the Swift package:
- Pin the recovered 412-test Swift log and 23-test native summary by SHA-256.
- Compare Swift package/source/tests, dependency lockfiles, deterministic
  fixture preparation and all conservatively relevant external tracked inputs.
- For native tests also compare App, NativeTests, project and icon scripts.
- Require equal Xcode version and architecture; native reuse also requires the
  identical available iOS runtime version/build. Otherwise rerun that suite.
- Run all 62 JS guards and the two workbook controls on the final checkout.
- Seal source-SHA markers and all 11 current UI summaries before ARM64 Release
  packaging. Publish validation/reuse manifests alongside the IPA checksum.

Local checks: shell syntax, Python compilation, YAML parsing, whitespace and
both existing redesign/Glass static guards passed. The scoped verifier was
exercised against the recovered evidence and baseline environment metadata;
actual CI reuse must repeat these comparisons against its own environment.
No new test result or IPA is asserted by these infrastructure preparations.
