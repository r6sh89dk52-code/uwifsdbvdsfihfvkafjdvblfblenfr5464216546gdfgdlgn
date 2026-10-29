# Access composition correction — 2026-10-29

Baseline: audit branch faf7cdb298ee21ab881bbd425c5f6fe5f4622027; last validated IPA code 2b76453cd51b2998ac300d9c6d435ec871b56cc1, run 40861610616 SUCCESS.

User supplied installed-screen and approved-reference images. The installed hero clipped both portrait and red ribbon to its bottom. The ribbon's closing edge was a horizontal line across the screen, separating hero and controls.

Correction: one shared scrolling ZStack composition; same ClinicalPortrait bytes extend 150pt beneath the former boundary and fade through an opacity gradient to the common dark canvas. The red overlay has two curved edges and a separate luminous crest, crosses the former boundary and remains behind controls. A soft red radial overlay integrates the lower area. Native texts, buttons, identities, callbacks and complete app authentication/lifecycle implementation remain unchanged. No clinical or Kardex changes.

Validation scope: existing access light/dark UI method, strengthened with real hittability and horizontal containment checks, plus accessibility XXXL and screenshots before/after scrolling; run only this method on iPhone 16 and iPhone SE 3 with Xcode 16.4 ARM64. One build; no full audit, no authentication injection, no IPA packaging. Existing identity, premium, glass and Build222 source guards pass locally. Real simulator build and visual review completed; see final result below. This change invalidates the prior IPA as evidence for the new composition; do not present the old IPA as containing this fix.

Manual workflow: .github/workflows/glass-access-visual.yml. A request-file push on the audit branch starts exactly this visual check. Artifacts include raw xcresults, exported screenshots, logs and source/PASS SHA. Resume by reading that workflow's latest run and artifact before repeating any tests.

## Execution checkpoint

Implementation commit: 0ac09a13368a1ca3c83c0b2cbf9c1ab314c2a31f. Workflow environment correction and actual tested source: 5aa09ad20a99eedabd0bbaefd16fbb3d0316f2eb.

Run 40885888717 was rejected before any runner job (job-level runner context); no tests or macOS runner minutes were consumed. Corrected run 40885996370 completed SUCCESS; job 123489737214. Protected-source check PASS. Build/screenshots step PASS. Do not duplicate this run. No new IPA generated.

## Verified final visual result

Run: https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40885996370 — SUCCESS, completed 2026-10-29 09:09:56 America/Lima (14:09:56 UTC).

Tested source and both SOURCE_SHA / ACCESS_VISUAL_PASS_SHA markers: 5aa09ad20a99eedabd0bbaefd16fbb3d0316f2eb.

- iPhone 16: testAccessLightAndDark 1/1 PASS; zero failures/skips.
- iPhone SE (3rd generation): same method 1/1 PASS; zero failures/skips.
- Each invocation covers dark, light and accessibility XXXL launches, real control hittability/enablement/horizontal bounds, version reachability and before/after-scroll screenshots.
- Build-for-testing succeeded once. Existing identity/premium/glass/Build222 source guards PASS. No clinical/native-core changes; app authentication/lifecycle and access button content/callbacks byte-identical to prior validated code.

Downloaded artifact 12904245907, GLASS_ACCESS_VISUAL_5aa09ad20a99eedabd0bbaefd16fbb3d0316f2eb (37,235,202 bytes); checked source/PASS markers and both xcresult summaries. Reviewed exported actual iPhone 16 / SE normal-size screenshots and accessibility top/bottom samples. The old horizontal black seam is absent; the portrait remains visible beneath the curved red wave and fades into the controls' shared dark background. Small-screen footer and enlarged text remain reachable by scrolling. This is targeted visual verification, not a new all-11 UI/full-suite/physical-device release verdict.

Artifact: https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40885996370/artifacts/12904245907

Selected original attachment files inside artifact:

- iPhone-16-attachments/77F45AE4-7E4F-46C1-9971-54107F239C97.png — normal dark, SHA256 5beb14e13d59f92affe516d0a69cae6d1781b80943673a23531a6b8206841c72.
- iPhone-SE-3rd-generation-attachments/20ABE00E-721D-432D-B077-3D9A4146EE70.png — normal dark, SHA256 8da781e921328ebaae2e251ba1c6cb4b54bac1c166ae3c4420b8489dd52c55d0.

The old published 0.4.2 build 12 IPA does not contain this correction. No replacement IPA has been generated or declared validated. Keep prior mandatory release gates before packaging any replacement; do not silently reuse invalidated app/UI results.
