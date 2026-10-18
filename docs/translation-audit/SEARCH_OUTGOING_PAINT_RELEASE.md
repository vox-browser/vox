# Outgoing paint ownership during native search navigation

2026-10-18. `582993bb` is fix 1 after the completed
[ten-fix search checkpoint](SEARCH_AGENT_VM_AND_FETCH_IDLE.md), whose runtime
baseline is `9927de40` with fixture-only corrections `b79b22e7` and `341ce21d`.
No instruction-count reduction is claimed.

The inactive Document's backend and computed-style references were already
cleared, but the native shell still held its paint tree, display list and scene
until the replacement layout finished. Additionally, `draw()` retained the old
display-list pointer solely to compare frame activity at the end of the frame.
That local pointer kept the old graph reachable through the expensive new
style/layout pass.

After closing the old script realm, the shell now releases its retired render
ownership before running the new page's scripts and layout. The previously
presented native surface remains on screen during synchronous navigation work.
Frame activity compares a numeric paint generation instead of retaining the
old list. Each successful adoption advances that generation. An active document
is refused by the retirement helper, preserving its tree and paint data.

Five focused files and 26 cases pass with default GC and no-GC. The collection
case holds the shell itself alive while a replacement Document exists but has
not been laid out. The old CSS backing store remains alive before releasing
the shell's old rendering. After release, weak references to that store and
the old layout handle clear. Separate checks retain active rendering, advance
paint generations after real content changes, preserve idle deadlines across
unchanged frames, and cover native frame preparation and computed-style release.
No-GC exercises the functional paths without making collection claims.

Two exploratory probes targeted the older isolated shell and failed compilation
because it predates the current paint-scene API. They receive no runtime credit.
The corrected probe against the current frozen runtime passed, followed by the
committed regression cases. All logs remain under ignored `Build/search-speed/`.

## Direct search transitions

This comparison keeps the current search page visible until the next search
commits. Earlier comparisons inserted a blank document, which reduced the
outgoing rendering work before the measured search. These are different
workloads and their wall-time medians must not be treated as a single cohort.

Brave's returned loader identity must match the committed frame before its
readiness probe can satisfy a new navigation. This prevents the previous page's
ready state from completing a same-URL reload prematurely. Both browsers use
already-open windows, direct networking, identical temporary authentication,
a 1024×768 viewport, JavaScript and normal subresource caches. Native snapshot
reuse is disabled. Every measured pair has 25 actual result elements. Uncached
rows verify newly fetched main responses; native script inputs exceed 1 MB.

Each series excludes one warmup and retains five subsequent pairs in alternating
browser order, separated by two seconds. Native timing is address submission to
the first submitted document frame, including up to 50 ms command delivery.
Brave timing is navigation to visible result geometry, DOMContentLoaded, two
animation frames, and an observed paint entry in the new loader.

| Executable / main response | Vox median | Brave median | Vox pair wins |
| --- | ---: | ---: | ---: |
| Frozen ten-fix control, uncached | 1,179 ms | 685 ms | 0/5 |
| Same frozen runtime plus `582993bb`, uncached | 1,028 ms | 731 ms | 0/5 |
| Rebuilt canonical production, uncached | 1,056 ms | 664 ms | 0/5 |
| Rebuilt canonical production, warm cache | 402 ms | 692 ms | 4/5 |

The control/candidate document-installation medians are 291 and 241 ms. These
sequential live series include network and shared-host variation; the entire
151 ms navigation difference must not be attributed to the ownership fix.
Warm searches have the faster median. Fresh-search parity remains open.

Both final production bundles pass strict signing and headless startup. The
saved search viewport is pixel-exact between the frozen control and candidate,
and `svg-image-source-switch-same-size` remains exact. The previous broad
checkpoint is carried; this fix does not trigger another broad batch.

## Receipts

`early-render-release{,-none}.{log,status}` and
`early-render-release-selection.json` record the focused selection. The
candidate runtime is the `9927de40` archive plus only the six-file implementation
patch from `582993bb` and the two reviewed fixture corrections; its provenance
is `early-render-source.json`. Canonical unrelated work remains preserved.

`early-render-binaries.json` pins the control, candidate and canonical
executables. `early-render-progress.json`, `early-render-verification.status`
and `early-render-verification-runner.status` authenticate completion. All four
complete `search-transition-*-comparison.json` series, matching summaries,
`early-render-pixels.json` and `early-render-svg-guard.log` remain private and
ignored. URLs, queries, cookies and page bodies are excluded from this audit
and Git. The original failed probes are retained without pass credit.
