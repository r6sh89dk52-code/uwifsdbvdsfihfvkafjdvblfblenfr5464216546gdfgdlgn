# Large fictional UI regression — pending actual execution

Source 4daba96, 9648 workers, 1005 saved visits, original premium encrypted draft and complete physical state. Native seeding uses an empty owned Simulator DEMO only. Production App/Core/project sources are unchanged; a fresh diagnostic build includes the large fixture and UI timestamps, not the original binary artifact.

The original two allergy UI tests retain every assertion: empty search, available new worker, result cap, real persisted review, unsaved review cannot authorize treatment, independent autosave, reopen confirmed status. Five form open/close cycles retain XCTest clock/CPU/memory metrics. Add one last-worker search by name with exactly one result and correct selected DNI. Before/after native checks compare full original workers/saved visits/physical state/original draft, allow newly created draft rows, and require the persisted allergy review.

Save/search timestamps are one automation sample each; they include helper/typing/query/idle overhead and are not physical iPhone or pure button latency. No p95 or before/after improvement can be inferred. Passing these three diagnostic UI cases does not approve all 14 mandatory UI tests or an IPA. Existing native large comparison and Instruments remain independent obligations.
