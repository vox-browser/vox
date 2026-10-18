# Search agent VM reuse and navigation idle cleanup

2026-10-18. These are fixes 9 and 10 in the search-task batch after `17328490`,
following [rendering lifetime and HTTP/2](SEARCH_RENDER_LIFETIME_AND_HTTP2.md).
No instruction-count saving is claimed.

`a5169111` gives JavaScriptCore one context group per native agent thread. A
context group owns the reusable VM and parsed-code cache. Each browser Runtime
still creates a new global context with separate globals and intrinsics. A
pthread key owns the group and releases it at thread exit. Key-allocation
failure retains the original independent-context fallback. The thread boundary
also preserves JSC's documented binding of deferred VM work to its creating
thread's run loop. This does not change the translated LibJS backend.

Two new cases verify group reuse, distinct globals, prototype isolation,
survival after another context closes, and separation across live threads.
Four existing runtime, host-JSON, native-value and structured-clone files add
26 cases. All five files and 28 cases pass with default GC and no-GC. A private
C-API interception prototype on the same executable reduced subsequent search
JavaScript setup from roughly 124–127 ms to 80–83 ms. That prototype is phase
diagnosis, not an overall page-latency or committed-executable comparison.

`9927de40` tracks the generation of a running native main-document fetch. The
old pending-navigation field is cleared when the worker starts, so it did not
cover the network wait. Explicit idle collection now waits until the current
response has been consumed and its dependency preloads have finished. A stale
response cannot clear a newer request's generation; history supersession makes
an older fetch irrelevant. Automatic GC remains enabled, and ordinary idle
cleanup is still available afterward.

Three new cases exercise a real gated HTTP request, a buffered response awaiting
UI consumption, stale/current response ordering, history generation changes,
and dependency waiting followed by cleanup. The existing nine memory-maintenance
cases also pass, for 12 cases in both GC modes. A control with the old idle
guard fails the new collection assertions. The first control accidentally
resolved its symlinked test input to the patched source and therefore passed;
that failed control supervisor remains retained without regression-reproduction
credit. The corrected control uses a real test file and explicit Boehm GC.

Focused receipts are private ignored `Build/search-speed/agent-context{,-none}`,
`agent-integration{,-none}`, `fetch-state{,-none}`, and
`fetch-idle-control-corrected`, each with `.log` and `.status`. The original
failed control and pre-runtime verification setup corrections are retained.
The committed checkpoint source is frozen under `Build/search-speed/ten-fix`
at `9927de40db10ed693cebf69dee59e29896391e7d`; independently changing canonical
work is excluded from that snapshot. Broad checkpoint validation and final
live comparisons are still pending, so the ten-fix cadence has not reset.

The canonical production pilot after these two changes still measured 1,152 ms
versus Brave's 697 ms for uncached main responses, with one native win out of
five pairs. Both painted 25 actual result elements with scripts enabled. The
pilot ran while this task's broad compiler workers were at background priority;
it does not isolate either fix's latency effect. Fresh-search parity remains
open. Its full series is retained in `agent-idle-production-pilot-comparison.json`.
