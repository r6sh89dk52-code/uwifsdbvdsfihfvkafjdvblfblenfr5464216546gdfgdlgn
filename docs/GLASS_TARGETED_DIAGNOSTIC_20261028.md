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

## Second diagnostic completed: preserve the real individual outcomes

Run `40814464695` finished FAILURE at its strict aggregate gate. Its individual
summaries (compact artifact `12873476892`) are:
- Biometric: 1 PASS / 0 FAIL / 0 SKIP; raw artifact `12872298883`.
- Premium: 1 PASS / 0 FAIL / 0 SKIP, with the original immediate keyboard check;
  raw artifact `12872468452`. Production and this test remain unchanged next.
- Protected: 0 PASS / 1 FAIL / 0 SKIP; raw artifact `12872759870`.
Build succeeded and compiler cache was saved. The job's continue-on-error step
presentation is NOT treated as a test PASS: its xcresult governs the verdict.

Protected failure moved past authentication: system log 04:28:38.939 reports
successful evaluatePolicy, but the screenshot still has the Face ID window on
top. The setup/manual-worker button exists at y=485..549 yet is not hittable.
The helper correctly refuses to tap through the cover. This is not a clinical
vault or worker-record failure. CoreAuthUI did not deactivate until teardown.
The standalone prelaunch left a User Authentication app scene (visible back link).

Next minimal environment correction terminates the standalone warm-up process
BEFORE any DANPER launch, so real LocalAuthentication owns its later UI. No
active DANPER context is terminated and no success is injected in preparation.
Both biometric tests now additionally require a hittable source/home after
match, preventing an obscured but existing control from counting as success.
All former cancellation/no-loop/retry/foreground and creation/persistence
assertions remain. No production source is changed.

The third request selects ONLY Bio + Protected, whose shared authentication
preparation changed. Keep Premium's individual PASS from `47fa1a9`; its own test,
DEMO application/fixture/resource inputs remain identical. The final gate must
verify individual per-case input identity before aggregating evidence from
multiple diagnostic runs. Never mark the second overall run as successful.

## Third diagnostic checkpoint and independent case provenance

Third diagnostic run: `40818891397`, job `123266422475`, source
`3b17655b3028cad670e3dfc2ab613bc2c06d66cc`. Only Bio + Protected are selected.
Read its actual current status; no PASS is claimed here.

The final gate can aggregate individual diagnostic cases from different runs.
It does not require repeating Premium just to populate a same-run marker.
For EACH case it requires an immutable artifact/run/source SHA, the correct
selected method in the actual xcodebuild log, a one-test PASS/zero-skip summary,
matching build/PASS SHA markers, and identical current application, package,
fixture/resource and OWN interaction-test input trees. Unreviewed external
input changes reject reuse. Toolchain/architecture/runtime must also agree
across the diagnostic cases and with the eventual Mac runner.

Premium's DEMO route never calls LocalAuthentication, so the auth-process
preparation script is not its test input; its entire app/DEMO fixture/own test
source is still compared. The auth preparation and enrollment scripts ARE
mandatory identical inputs for Bio and Protected. Thus the prior Bio pass
cannot be reused after strengthening its assertions or changing the shared
auth preparation, while Premium's unchanged DEMO pass can be preserved.

The final 11 UI cases still always run together on the final checkout; none of
those final UI results are reused. No failed overall diagnostic run is relabeled
as successful. Negative local verification rejects the actual failed Protected
summary and writes no aggregate approval marker.

## Final UI inventory isolation

The final inventory still discovers exactly 11 methods from source. It runs the
two existing N3 DEMO journeys together with their original native fixture seeds,
and the protected-source method on its own fresh, warmed synthetic simulator,
matching its diagnostic prerequisites. This avoids placing genuine system
biometrics after a long DEMO journey with potentially cold system UI services.
No method is omitted or duplicated, and no skip-testing flag is used. The seven
result bundles contain counts 1+1+3+1+2+2+1 = 11; every summary must have zero
failures/skips before sealing. No final UI result is claimed by this change.

Local validation extracted the actual inventory generator from the shell script
and verified all 11 methods/counts and the dedicated protected selector. Shell
syntax, Python parsing and whitespace checks passed.

## Third diagnostic results: event readiness and late TCC permission

Run `40818891397` failed both selected cases (0/2 PASS, no skips). Compact
artifact `12875515283`; raw Bio `12873614666`, raw Protected `12874379170`.
The stricter assertions correctly rejected these results.

Bio no longer has an activation-timeout error. Its real CoreAuthUI exists, but
the old event was posted before matching began: coreauthd only reports sensor
active at `05:00:53.052`, after the capture + two-second event sequence. No
simulateMatching/nomatch reached the active operation. The absence of Cancel
therefore has a proven event-ordering explanation, not a missing enrollment.

Protected also exposes late TCC startup: the five-second optional permission
poll ended before coreauthd requested Face ID permission at `05:13:13.302`.
There was no Allow tap, no sensor-active signal, and no completed authentication.
An app-level “Verificando identidad” label is not a readiness signal for either
TCC or the biometric sensor.

The next two-case request adds test-runner-only coordination:
- Host reads the real simulator log and acknowledges only an observed active
  MechanismPearl sensor for a new DANPER evaluatePolicy generation.
- The UI runner writes a nonce/request in its OWN Documents container, waits for
  that readiness acknowledgement, then posts its original intended event.
- No host code posts match/nomatch and no production code is involved. The
  helper fails closed if readiness, nonce, or new context is missing.
- While waiting, the UI test can tap Allow only on an actual Face ID permission
  alert, covering the late TCC prompt without authorizing clinical access.
- Bundle identity is read from the compiled UI runner's Info.plist, not guessed.

Local replay against the actual failed Bio log permits no event before the
observed sensor-active record and resets on stop. Replay against the earlier
passing Bio log identifies three distinct contexts (initial, retry, foreground)
and their three actual sensor-active signals. These are parser checks, not new
claims that the UI cases passed.

Optional final simulator-binary reuse now requires the complete native input
tree (all UI methods included), external resources, exact compiler cache key,
SDK/architecture and valid simulator bundle signatures. Actual binary hashes
and origin SHA are recorded. Any missing proof falls back to compilation.
All 11 final UI tests still execute; ARM64 Release still builds independently.
No UI verdict is obtained from the compiler cache.

## Fourth diagnostic execution

Source `21c44e8cab81320cc4bcbf8fe841904911466b20`, run `40823214523`,
job `123280210625`. Only Bio + Protected. Query GitHub for its current results;
no success is claimed in this checkpoint. The readiness parser's local trace
checks passed, and the production App/NativeTests/DanperCore trees still match
`409c371` exactly.

Before reusing a simulator binary, the optional cache verifier also compares
actual generated App resources and native synthetic fixtures byte-for-byte
against the restored bundles, because those generated files are ignored by
Git. Missing or different resources require an actual rebuild. Cached binaries
never supply UI PASS verdicts, and the unsigned ARM64 build is still separate.

## Fourth result and architecture-specific fifth diagnostic

Run `40823214523` completed FAILURE: Bio 0/1, Protected 0/1, no skips.
Compact artifact `12876867077`; raw Protected `12877260147`; raw Bio
`12876366635`; build checkpoint `12876097801`. Both actual summaries fail
waiting for sensor readiness. The bridge observed each new DANPER context,
but no active sensor. Both real system logs show LocalAuthentication -1000
“UI activation timed out after 5 seconds”, then “No pending UI mechanism”.
The bridge did not acknowledge or inject an event into an inactive sensor.

The fifth diagnostic changes the runner to native ARM64 `macos-15`, explicitly
pinning Xcode 16.4 and its iOS 18.5 runtime. This tests whether the repeatedly
observed Intel system-UI startup watchdog is environment-specific. It is an
experiment, not a claim of success. Cache keys now include the actual runner
architecture; Intel binaries/results are not treated as ARM64 equivalents.
The diagnostic runs only the three original selected UI methods, plus the
existing one-test native Face ID availability preflight (no authentication).
Premium is included again because the architecture changes its inputs too.
The final gate requires matching architecture/Xcode/runtime across all three
approvals. Swift and native baseline reuse must fail on architecture mismatch,
so their affected suites will execute during final validation.

No production App, NativeTests, clinical data or Kardex logic changes are made.
No Face ID bypass, timeout suppression or weakened assertions are introduced.
No full audit, final 11-case UI run or IPA is requested at this stage.

Fifth execution published at source
`1e84ae2d2d9a0a7b6caf50ca67b98603ea6271aa`, tree
`902f86bbba6912fd73a9e9f7c67ebbd394ba5a2f`: run `40826603674`,
job `123290972911`, label `macos-15`. Setup verified actual ARM64 and selected
Xcode 16.4. Consult this run's summaries/artifacts before taking the next step;
no UI pass is claimed by this checkpoint. The final release request file does
not exist yet. This documentation-only commit does not request another run.

## ARM64 diagnostic result and targeted display correction

Run `40826603674` completed FAILURE overall, with Bio 1/1 PASS, Premium 1/1
PASS and Protected 0/1, zero skips. Availability preflight 1/1 and Premium seeds
2/2 PASS. Compact `12877229281`; raw Bio `12877311802`, Premium `12877946637`,
Protected `12877692763`; build `12876818161`. All are bound to source
`1e84ae2d2d9a0a7b6caf50ca67b98603ea6271aa`.

Bio's trace proves three sensor-active generations before nomatch/retry/
foreground events; its final XCTest screenshot shows accessible source setup.
Premium preserves the immediate five-second keyboard assertion and passes.
Its hierarchy contains the focused DNI field and onscreen keyboard, no
Siguiente. The original Premium timeout's exact underlying cause remains
unproven; no product fix or causal certainty is claimed for that failure.

Protected now reaches sensor active at 06:27:53.453 and genuine policy success
at 06:28:00.169, but the OS Face ID HUD remains visible and the application
remains inactive. The screenshot and CoreAuthUI hierarchy confirm the stuck
HUD, not an authentication rejection. It disappears only at test teardown.
The application's privacy cover correctly refuses interaction while inactive.
Do not remove that cover, force taps, suppress the assertion or inject success.

A concrete harness defect was identified: `open -a Simulator --args
-CurrentDeviceUDID` does not select a new device if Simulator is already
running (also documented in Expo's own simulator launcher source:
https://github.com/expo/eas-cli/blob/main/packages/eas-cli/src/run/ios/simulator.ts).
Bio was the first visible device; Protected ran after other fresh devices.
The next experiment attaches a new selected-Xcode Simulator GUI instance with
`open -n` to EACH biometric device, and records a real process bound to that
exact synthetic UDID. No animation setting, app authorization, OS permission,
success event, production code or clinical state is changed by this helper.
The link between the missing display and stuck HUD is a hypothesis to test.

Only Bio and Protected are selected because their shared display preparation
changes; their diagnostic gate also compares the new helper. Premium keeps
its unchanged DEMO preparation and input trees, so its individual ARM64 PASS
can be retained despite the overall run failure. Final all-11 UI and IPA remain
blocked. Shell/Python/YAML/whitespace and unchanged-product checks passed
before publication.
