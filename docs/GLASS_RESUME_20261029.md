# DANPER — exact checkpoint, 2026-10-29

Audit branch only. Completed recovery baseline `409c37149917d5c811229680a3f14d1450b171ed`, run `40806554927`, is preserved and not repeated.

Latest Mac diagnostic source `8909cdbedabc611c2cbe1cd8dda8ba7df33b81c4`, run `40832912495`, job `123310972457`, overall FAILURE: Bio 1/1 PASS, Protected 0/1, zero skips. Compact `12879918256`; Bio `12879422699`; Protected `12880580446`; build `12879264510`. Bio's cancel, no-loop, manual retry and foreground usability assertions all passed. Premium previously passed unchanged immediate keyboard assertions on ARM64 in run `40826603674` at `1e84ae2d2d9a0a7b6caf50ca67b98603ea6271aa`, compact `12877229281`.

Read-only inspection `40835008438` at `1da23f8c209eb22b3f31cce2beaab97a77c68f48` succeeded. It read the existing run-seven logs and exported original screenshot without executing tests. Protected passed initial authentication and real synthetic source creation. Its third policy (after app relaunch, new PID) returned success at 07:18:45.541, then the LAContext deallocated at 07:18:45.572 while CoreAuthUI remained visible. The screenshot proves the Face ID HUD still covers the access view; underlying home has a normal frame. The reported invalid hit point is a consequence of a real blocked UI, not a reason to weaken hittability checks. CoreAuthUI only dismissed on teardown at 07:19:03.9.

This change tests a minimal production lifecycle correction in `native-ios/App/DANPERNativeApp.swift`: retain a completed LAContext while the scene is inactive; invalidate/release it when active, or on the existing background/lock paths. Keep the current auth-cycle check, actual system success/failure, deviceOwnerAuthentication policy, cancellation/retry behavior, foreground reauthentication and privacy cover unchanged. No permission or success is injected. No clinical/Kardex/source/crypto logic or UI test assertion changes. The successful Bio also deallocated contexts, so this is a race hypothesis supported by sequence, not a claimed proven cause or fix before testing.

A Linux-only source-validation request now runs shell/Python syntax checks and the existing premium/glass/build222 guards that read the native app. No simulator tests or builds are requested by this commit. After those pass, the shared App input change invalidates ALL three prior UI input proofs: request exactly the three original affected methods, then only if they pass request all 11 UI. Native 23 must run because its App host changes; Swift 412 must run because architecture differs from the Intel baseline. The final pipeline also runs 62 JS guards/two workbook controls. No final release request or validated IPA exists. Publish unsigned ARM64 IPA + manifest + SHA-256 only after all mandatory checks pass.

The failed display-instance experiment has been removed. Standalone CoreAuthUI launch/termination remains removed; logs preserve only authentication/lifecycle signals (run-seven Bio 789 lines, Protected 853, versus prior 30–37k). Local executor unavailable; GitHub remains usable. Original SwiftUI branch, main, native model/tests, src, clinical data and Kardex v2 have not been modified. See previous detailed checkpoints in `docs/GLASS_TARGETED_DIAGNOSTIC_20261028.md` and git history.

Source-validation run `40835538219` (job `123319318957`) completed SUCCESS: shell/Python syntax and all three existing native premium/glass/build222 guards passed. The next explicit diagnostic request selects exactly the three original UI methods because the shared App input changes; no earlier Premium/Bio approval is substituted for this changed App. Full audit, final all-11 UI and IPA remain blocked pending these genuine verdicts.

Current three-case execution: source `2bb98bf9bf52f35f9711350d40ce00d2db097060`, run `40835749202`, job `123320009569`. Query its actual summaries and conclusion; this checkpoint claims no new UI PASS. Local shell/Python/YAML syntax and whitespace checks passed after synchronizing the published source. This documentation-only update does not request another test run.

## Three-case approval and first final validation request

Run `40835749202` completed SUCCESS at source
`2bb98bf9bf52f35f9711350d40ce00d2db097060`: all three original UI methods
PASS individually (1/1 each), no failures/skips, matching source/build/PASS
SHA markers and the aggregate DIAGNOSED_3 marker. Compact `12881741798`;
raw Bio `12880573559`, Premium `12881775105`, Protected `12881731821`;
build `12880678834`. Local execution of the unchanged strict diagnostic gate
confirmed identical relevant inputs and Xcode 16.4 / ARM64 / iOS 18.5 (22F77).
The original XCTest screenshot after protected-source relaunch now shows the
actual clinical home with no access cover or Face ID HUD. All three real
sensor generations precede their intended events. No test was weakened.

The explicit `.github/glass-final-release-request.json` now requests the
FIRST final 11-UI validation on the corrected code. The pipeline first repeats
the individual approval/input proof in Ubuntu; only then may its Mac job
prepare current controls. Architecture and App-host changes invalidate the
Intel Swift/native baseline equivalence, so 412 Swift and 23 native execute.
All 62 JavaScript guards and both workbook controls execute on this checkout.
All 11 UI methods execute; no prior UI verdict is used for this final stage.
Only matching current-SHA mandatory successes permit the fresh unsigned
ARM64 Release build and publication of IPA, manifests and SHA-256.

This request is not a claim that final validation or IPA packaging succeeded.
Query its associated workflow and preserve its actual results before declaring
an IPA validated. No full audit workflow or main/original SwiftUI change is
requested. The optional simulator cache requires matching complete native
code/resource inputs and never supplies a UI PASS.

Final execution published: source `cb49f7048a8f3bd4a358e4af7c77f1d625432ef4`,
run `40857793155`. Ubuntu diagnostic input gate job `123393051986` completed
SUCCESS. Mac job `123393148502` is queued at this checkpoint; no final core,
11-UI or IPA success is claimed. Checkout is pinned to the immutable source
SHA. This documentation-only commit does not request another run.

Trace qualification after the three-case PASS: do not claim the context was
necessarily retained until the HUD disappeared. In the successful protected
relaunch, policy reply was 07:53:00.626 UTC, LAContext deallocation 00.696,
CoreAuthUI dismissal 01.869 and UIKit removal of deactivation reason 7 at
01.940. The actual code adds explicit invalidation of a completed context
when its observed phase is active, or on subsequent active/background paths.
The trace establishes successful UI cleanup with the corrected source; it
does not isolate a retention duration or prove the exact OS race mechanism.
All original assertions remain; the final all-11 run is still required.

## First final preparation result and precise resume

Run `40857793155` at `cb49f7048a8f3bd4a358e4af7c77f1d625432ef4`
passed the three-case input gate and ALL 62 JavaScript guards. Its preparation
failed with ENOENT for `fixtures/n1r-stock-native.xlsx`: it attempted the
cross-workbook control before the Swift tests that produce the native files.
No Swift, native, final UI or IPA build ran. Core `12891281001`, complete
preparation evidence `12889799915`, diagnostic input proof `12889822901`.
This is an orchestration ordering defect, not a failed clinical calculation.

The corrected order executes (or independently proves reuse of) Swift 412
BEFORE consuming its four native XLSX outputs in the two Node controls.
If full Swift results are reusable in a future equal-architecture environment,
only the four existing workbook-producing tests generate those fresh files.
Missing files still fail. Current ARM64 requires the complete 412-case run.
No generator, clinical logic, model, test or UI assertion is edited.

To avoid duplicating the 62 JavaScript checks, the next request pins the
existing core artifact/run/source SHA and exact actual Node runtime
(v22.23.2, darwin, arm64). Reuse requires every tracked input blob/mode/path
outside the explicitly reviewed pipeline-only edits to match. The unchanged
62-script runner and package locks are included. All 62 old summaries/logs
must exist and pass; their hashes and input digest are recorded. Identity is
executed again to bind this checkout, giving 61 reused outcomes + 1 current
outcome. A failed current identity guard stops preparation; it cannot be
hidden by fallback. Unproven inputs/runtime cause a real 62-check execution.
The two workbook controls always execute on current Swift-produced files.
The manifest records these counts and provenance honestly, without relabeling
the overall failed run as successful.

Local checks verified shell/Python/YAML syntax and producer-before-consumer
ordering. Protocol tests with mocked runtime accepted valid immutable evidence,
rejected a failed verdict, and stopped on failed identity; the actual local
Node 24/Linux runtime was correctly rejected. No mock is accepted by the CI
entry point: it probes the real Node executable. The three UI approvals remain
valid because these pipeline-only changes do not change their inputs. Final
all-11 UI and unsigned IPA are still pending.

Corrected final execution: source `2b76453cd51b2998ac300d9c6d435ec871b56cc1`,
run `40861610616`. Input gate `123405976837` completed SUCCESS; Mac job
`123406070405` is preparing controls. No new suite or IPA PASS is claimed
by this checkpoint. Request provenance retains the original three-case PASS
run and the actual 62-check JavaScript evidence from the failed preparation.
This documentation-only checkpoint does not trigger a second execution.

## Corrected preparation approved; final UI running

Run `40861610616`, source `2b76453cd51b2998ac300d9c6d435ec871b56cc1`,
completed preparation successfully. Core artifact `12893306113`, diagnostic
input artifact `12890594882`. Actual Swift log: 412 passed, zero failures
(242.286 seconds); actual native summary: 23/23 passed, zero failures/skips.
Both current Swift-produced XLSX cross-controls passed. JavaScript JSON
contains 62/62 PASS; reuse proof confirms 61 immutable prior outcomes and one
new current-identity execution on the exact Node v22.23.2/darwin/arm64 runtime.
All Swift/JS/native SHA markers match this immutable run source. No failed
workbook verdict was reused or relabeled.

The simulator cache verifier rejected a changed generated template ZIP byte
sequence and correctly fell back to a real build. No stale binary approval
was forced. The workflow is now executing all 11 UI methods on that rebuilt
checkout. No full-11 verdict, mandatory seal or IPA PASS is claimed here.
This checkpoint changes documentation only and does not request another run.

## All mandatory controls approved; device package building

Run `40861610616`, source `2b76453cd51b2998ac300d9c6d435ec871b56cc1`: all-11 UI step `SUCCESS` (11:18:30–12:13:46 UTC), mandatory seal `SUCCESS` (12:13:46–47 UTC). The strict seal reads all seven result summaries and requires 11 passed, zero failed/skipped, all current-source markers, Swift 412, native 23, JS 62 with explicit reuse provenance and both fresh workbook controls. ARM64 unsigned packaging is in progress; no IPA validation/publication is claimed yet. Query Mac job `123406070405` and verify its actual IPA artifact, manifest and SHA-256 before completion. Do not repeat these completed suites if their inputs remain identical.

The local executor became unavailable again; GitHub Actions continues independently and the connector still reads/writes this audit branch. This documentation-only checkpoint triggers no validation run.
