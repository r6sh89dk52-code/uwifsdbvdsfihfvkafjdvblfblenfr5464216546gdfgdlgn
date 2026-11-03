# Current trace allocation detail export — no new app approval

The source0cdc idle Instruments artifact13194438610 contains an actual Allocations trace with Statistics and Allocations List details in its TOC. Its data tables have no allocation schema. The existing exporter scans only data schemas, so its successful trace recording did not quantify allocations. Zero signpost rows are not zero allocations.

Apple's Xcode13 release notes explicitly added xctrace export of Allocations/Leaks/VMTracker table data: https://developer.apple.com/documentation/xcode-release-notes/xcode-13-release-notes . The recorded TOC, rather than an assumed schema or a third-party parser, selects each actual view detail. The separate analysis workflow attempts those exports on Xcode16.4 using the already-recorded exact0cdc trace. It does not rebuild, launch, change or profile the app again and cannot generate an IPA.

Five local tests cover real TOC selection, unrelated/missing/ambiguous details, invalid run IDs and streamed XML counts. They do not certify xctrace execution or allocation measurements. Export exit/status/XML are retained. Successful export is distinct from finding usable numerical rows; unavailable metrics remain No medido. Existing before/after active captures will require the same real detail analysis if recording succeeds. Source/workload/host conditions must remain explicit.
