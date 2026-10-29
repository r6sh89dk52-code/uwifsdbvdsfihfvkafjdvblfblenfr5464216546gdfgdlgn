# Access composition correction — 2026-10-29

Baseline: audit branch faf7cdb298ee21ab881bbd425c5f6fe5f4622027; last validated IPA code 2b76453cd51b2998ac300d9c6d435ec871b56cc1, run 40861610616 SUCCESS.

User supplied installed-screen and approved-reference images. The installed hero clipped both portrait and red ribbon to its bottom. The ribbon's closing edge was a horizontal line across the screen, separating hero and controls.

Correction: one shared scrolling ZStack composition; same ClinicalPortrait bytes extend 150pt beneath the former boundary and fade through an opacity gradient to the common dark canvas. The red overlay has two curved edges and a separate luminous crest, crosses the former boundary and remains behind controls. A soft red radial overlay integrates the lower area. Native texts, buttons, identities, callbacks and complete app authentication/lifecycle implementation remain unchanged. No clinical or Kardex changes.

Validation scope: existing access light/dark UI method, strengthened with real hittability and horizontal containment checks, plus accessibility XXXL and screenshots before/after scrolling; run only this method on iPhone 16 and iPhone SE 3 with Xcode 16.4 ARM64. One build; no full audit, no authentication injection, no IPA packaging. Existing identity, premium, glass and Build222 source guards pass locally. Real simulator build and visual review PENDING at publication of this checkpoint. This change invalidates the prior IPA as evidence for the new composition; do not present the old IPA as containing this fix.

Manual workflow: .github/workflows/glass-access-visual.yml. A request-file push on the audit branch starts exactly this visual check. Artifacts include raw xcresults, exported screenshots, logs and source/PASS SHA. Resume by reading that workflow's latest run and artifact before repeating any tests.

## Execution checkpoint

Implementation commit: 0ac09a13368a1ca3c83c0b2cbf9c1ab314c2a31f. Workflow environment correction and actual tested source: 5aa09ad20a99eedabd0bbaefd16fbb3d0316f2eb.

Run 40885888717 was rejected before any runner job (job-level runner context); no tests or macOS runner minutes were consumed. Corrected run 40885996370 is active; job 123489737214. Protected-source check PASS. Build/screenshots step in progress. Do not duplicate this run. No new IPA generated.
