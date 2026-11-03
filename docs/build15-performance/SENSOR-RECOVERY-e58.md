# Targeted same-source CI recovery, NO IPA approval

Application and compiled native/UI source:e58efd2a398b12ee196568295cb145821ed4639d.
Sealed compile source run41707072055; native30/Core439/JS62/Python37,
official Excel, original14synthetic compatibility, v1/v2/9budgets and
Instruments passed. Original UI failures remain failures, never relabelled.

Biometric job126180672225: actual automatic policy request20:42:22.651;
coreauthd returned -1000 UI activation timed out after5seconds at20:42:28.119;
CoreAuthUI VC appeared20:42:47.848, too late. App correctly remained locked
and displayed Retry. No first nomatch/match was sent. Permission UI case1PASS,
automatic case1FAIL; Native/permission/system-cancel preflights PASS.
Menu job126180672197 failed before its case initialized: Accessibility load
timeout. Not a demonstrated app/menu code defect. Fresh isolated replay keeps
the original case. No new menu product implementation is introduced.

The host observer polled simctl get_app_container every2s even during actual
CoreAuthUI activation; one query can block30s. The corrected host defers that
RPC until a genuine sensor event and resolves once per current generation.
It does not re-poll during activation. A new generation invalidates its path;
an old in-flight lookup cannot resolve another context or overlap a new query.
Resolution timeout is reduced30→5s, within the unchanged20s sensor wait.
No actual readiness, consent, policy, application state or authenticated result
is fabricated. The host observer never posts match/nomatch notifications.

11local bridge tests PASS, including5new races: no RPC before actual sensor,
one resolution/context, new context needs new real sensor, blocked older
lookup cannot supply/overlap new path, timeout/cancellation fail closed.
This validates ordering only. Whether the host contention explains the UI
activation failure is still a hypothesis until the isolated replay completes.

Reuses the existing distribution branch, no new branch. Replays original
Biometric2, Menu1 and protected clinical1 cases with byte-identical sealed e58
native/UI products and exact source. Only the Python host observer differs;
record HOST_ONLY.diff, harness SHA, observer hash and product manifest.
No test or clinical/physical assertion removed, no authentication timeout or
600s limit increased. The primary application source remains e58.

This workflow never packages IPA and cannot replace final mandatory checks
by itself. Current main workflow still must finish its non-replayed clinical
journey/inventory checks. The original distribution guard remains blocked by
its failed mandatory run. Do not bind distribution to a recovery until all
required current-source cases and evidence actually pass and provenance is
explicitly checked; preserve original failures and report source separately
from host harness commit. No old-SHA results or physical iPhone claims.
