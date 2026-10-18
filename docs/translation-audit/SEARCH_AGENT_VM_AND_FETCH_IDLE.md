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
The committed checkpoint runtime is frozen under `Build/search-speed/ten-fix`
at `9927de40db10ed693cebf69dee59e29896391e7d`; independently changing canonical
work is excluded from that snapshot.

The canonical production pilot after these two changes still measured 1,152 ms
versus Brave's 697 ms for uncached main responses, with one native win out of
five pairs. Both painted 25 actual result elements with scripts enabled. The
pilot ran while this task's broad compiler workers were at background priority;
it does not isolate either fix's latency effect. Fresh-search parity remains
open. Its full series is retained in `agent-idle-production-pilot-comparison.json`.

## Completed ten-fix checkpoint

Both original 37-file native selections exited 1. Thirty-five files passed;
the idle-worker fixture and the 66-case `main_test.v` file failed. The latter
contained two obsolete assumptions: animation ticks used to refresh paint
immediately, and cached content types used to discard the charset. Fixture
corrections `b79b22e7` and `341ce21d` exercise actual frame preparation, preserve
the original transport charset, and keep the existing rendering/cleanup
assertions. Both corrected files pass in both GC modes. Successful files were
not rerun. The authenticated composite is 35 retained plus two recovered files,
216 cases per GC mode; the earlier seven focused files add 40 disjoint cases.
The total native union is therefore 44 files and 256 cases in each mode.

The earlier full LibJS runs retain all 236 passing files in each GC mode:
`git diff 06fdff11 HEAD -- libjs tools/libjs_ast_corpus.v` is empty at checkpoint
completion. The fresh, unmodified AST driver again matches all 100 upstream
fixtures exactly. This preserves the existing JSC execution/backend boundary.

The signed frozen and canonical production bundles pass headless startup and
strict signing checks. All eleven default smoke comparisons pass: eight are
pixel-exact, three use their existing bounds. All eight SVG guards are exact,
including image source replacement, resource removal, ID collisions, gradient
stop mutation/animation, and pattern transforms. The saved 1024×768 search
viewport is also exactly equal to its control. No bounds changed.

The final five-pair live series uses the actual-DOM, scripted, direct-network
method documented in the preceding audit, excluding one initial navigation:

| Executable / main response | Vox median | Brave median | Vox pair wins |
| --- | ---: | ---: | ---: |
| Frozen checkpoint, ordinary warm cache | 355 ms | 697 ms | 5/5 |
| Frozen checkpoint, uncached | 1,012 ms | 664 ms | 0/5 |
| Canonical production, ordinary warm cache | 453 ms | 648 ms | 5/5 |
| Canonical production, uncached | 1,067 ms | 645 ms | 0/5 |

Both browsers paint 25 actual result elements; native script inputs exceed
1 MB, and uncached rows verify a newly fetched main response in both browsers.
Warm searches are faster in these series. Fresh-search parity remains open.
These measurements precede the outgoing-shell release in `582993bb` and do not
credit that later fix. One private candidate build ran during part of the
checkpoint's live comparison; these are observed wall times under shared host
load, not isolated CPU savings attributable to one change.

Checkpoint completion has actual-zero receipts in
`ten-fix-native-composite.status`, `ten-fix-ast.status`,
`ten-fix-verification.status`, and `ten-fix-verification-v5-runner.status`.
The 35+2 union and original failures are recorded in
`ten-fix-native-composite.json`, both original native logs, and the separate
`ten-fix-{idle,main}-fixture{,-none}` recovery logs/statuses. Binary identities,
all four complete live series, pixels and screenshot results are retained as
`ten-fix-binaries.json`, `ten-fix-*-comparison.json`,
`ten-fix-style-pixels.json`, `ten-fix-smoke.log`, and `ten-fix-svg.log`.

This closes the ten-fix batch at runtime `9927de40` with the two fixture-only
corrections, without claiming broad coverage of later runtime changes. The
cadence resets there; the subsequently implemented `582993bb` is fix 1 in the
next batch. No historical inventories or unrelated broad baselines are changed.
