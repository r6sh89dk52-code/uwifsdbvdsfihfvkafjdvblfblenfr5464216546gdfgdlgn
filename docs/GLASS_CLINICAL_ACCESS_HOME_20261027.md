# Glass Clinical — Access and protected Home

Base: `9bec8e01ccbb3f1a674372cf6e48df049dc4f014` on `feat/build222-native-ui-parity-20261020`.
Repository: `r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn`.
Design branch: `design/glass-clinical-access-home-20261027`.

## Audit before implementation

The real access cover is `DanperAccessView` in `DANPERNativeApp.swift`. After the existing LocalAuthentication flow, `N2ClinicalWorkspaceGateView` verifies the source and presents `N2ClinicalWorkspaceRootView` with the fixed clinical vault environment. `NativeRootView` is the separate demo shell and is not redesigned. The first-run source gate and onboarding are unchanged.

Protected Home inventory, in existing order:

1. Welcome / Department of Health, protected-source status (informational, not a button).
2. Existing optional blue occupational-health campaign when that palette is selected.
3. New attention → existing Registrar tab (tag 1).
4. Real counters: today, week, drafts; drafts → existing drafts dashboard. Missing counts remain “—”.
5. Tools in order: Workers → protected worker directory; Kardex → existing hub; Indicator → verified 10-sheet export; History → protected attention history; Drafts → existing dashboard; Backup → existing encrypted export.
6. Close clinical workspace → existing onClose callback.

Existing tabs: Home (0), Register (1), History (2), Settings (3). Header Settings shortcut still selects tab 3.

Settings retains: source notice, appearance/palette, PERSONAL reconciliation/import, inventory/lots, day-9 cut, nursing Kardex Excel, ambulatory indicator Excel, occupational-vigilance Excel, encrypted backup and close.

## Reference discrepancies resolved before editing

The reference board shows Home/History/Drafts/Settings tabs, only four tools, a named user, a personal portrait, a location and “See all”. The actual code has Home/Register/History/Settings, six tools and no authenticated user-profile or location source. Preserve the implemented tabs, tools (including the already-existing Backup), order, counts and destinations. Use a native anonymous circular avatar; do not add See all, profile or location actions. There are no new clinical modules.

## Visual changes

- `DANPERNativeApp.swift`: only the access view below the App declaration changes. Edge-to-edge portrait/gradient composition, native curved red overlay, authentic asset-based wordmark, native faceid symbol, welcome copy, native-auth controls, error and progress presentation, runtime Bundle version/build.
- `N2ClinicalWorkspaceView.swift`: only the protected Home's layout, local card helpers and Dynamic Type grid adapt. Counters, source gate, tabs, callbacks and Settings are preserved. Existing native TabView remains responsible for the bottom safe area and navigation.
- `GlassClinicalChrome.swift`: isolated visual primitives, adaptive light/dark surfaces and Reduce Transparency support; shared `DanperUITheme.swift` stays unchanged.
- `AccessNurseHero.imageset`: a clean portrait derived with the built-in image tool from the user's supplied composite reference, not an extracted original photo. Reviewed for the male nurse, cap, blue mask, red uniform and stethoscope. No UI or logo is baked into it. Native corporate lettering comes from unchanged BrandLogo.
- `N2GlassClinicalLayoutTests.swift`: captures initial, verifying, retry/error access, protected Home, light/dark, small-screen and accessibility text; layout-only Home initializer avoids vault reads. Screenshot fixtures are not production counts or proof of successful Face ID.
- B11 workflow: include design branch; run existing routing/parity checks, select iPhone 16, retain xcresult and PNG evidence, no archive or IPA.

Both access buttons invoke the exact same existing callback and `.deviceOwnerAuthentication` policy. iOS offers and validates the device-code fallback. The alternative button does not force a separate passcode-only policy. No App authentication/lifecycle code, LAContext handling, Keychain, vault, data model or clinical engine is modified.

## Validation

Local environment: Linux without Swift or Xcode. Existing Node routing and Build222-native parity checks passed. App authentication implementation, clinical source gate, counter refresh, tab actions, Settings and all clinical-core source files are compared against the base before delivery. `git diff --check` passed.

GitHub macOS/Linux execution and final result are recorded in the PR. Rendering attachments require a runner to start; no generated mockup is represented as a simulator screenshot. Real before/after images are unavailable until those builds execute. Existing base run 40210817574 failed before any steps and without a runner assignment; its missing logs do not establish a compiler error or a billing cause.

Pending physical iPhone checks: automatic Face ID, cancel/retry, iOS passcode fallback, background lock/privacy, first-launch/verified source transitions, portrait/status bar/home indicator, light/dark/system selection, Dynamic Type scrolling, all six tools and four tabs against the real user's data. Do not merge or distribute an IPA as part of this change.

## Asset derivation prompt

Built-in image editing mode. Preserve the male nurse from the supplied board: same face, gaze, pose, surgical cap, blue mask, red scrub uniform and stethoscope. Deliver only a clean portrait with a dark blurred clinical background and empty upper-left/lower-left space. Reconstruct obscured background/clothes; remove text, logos, controls, phone and red UI overlays. No different person, woman or added subject. Full prompt is in the work conversation.
