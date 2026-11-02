# Old Reddit comment-page memory

The requested limit is **500,000,000 bytes** for
`https://old.reddit.com/r/UkraineRussiaReport/comments/1xls5ou/ua_pov_ukraine_hits_10_of_russias_oil_refining/`.
The measured production bundles **exceed this limit**. Committed fixes reduce
collection/query transport allocation, reuse unchanged timestamp geometry and
reclaim reset native arena pages at idle. Focused checks and native screenshot
guards pass; startup peaks and complete longer-run acceptance remain open.

## Reproduction

Both direct access and the configured SOCKS route returned HTTP 403. The
native cache contained the actual requested thread, so the investigation
sealed its original HTML and resources with `tools/page_archive.py capture
--from-cache`, then replayed them through the existing HTTPS archive server.
Account-bearing HTML, screenshots and request logs remain private under
`Build/reddit-comment-memory-20261102/`.

Fresh processes used normal scripted browsing, a private profile/cache and
`VOX_TEST_WINDOW=1`. External `PhysicalTree` sampling recorded simultaneous
browser and observed-descendant physical footprints every 50 ms. Capture and
the DOM audit followed the primary observation interval. The first run had
an empty profile; the longer exploratory run copied history, bookmarks and
zoom into its private profile. Neither changed the user's saved files.

The executable was SHA-256
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`.
Executable, native-library and filter-snapshot identities remained unchanged.
The browser and guard exited zero in both baseline observations.

| Baseline observation | Endpoint viewport | Observed peak | Final two-second median |
| --- | --- | ---: | ---: |
| Approximately 55 seconds | 1024 × 768 | 921,455,280 B | 409,454,488 B |
| Approximately 300 seconds | 1708 × 941 | 937,708,280 B | 522,913,760 B |

These different viewport/profile conditions are exploratory observations,
not a matched optimization comparison. Both endpoint audits retain the exact
URL/title, a complete, visible, fully active document, 49 comment containers
and two images. One existing compact-JavaScript diagnostic remains. The longer
trace grows by roughly 9 MB every 20 seconds after settling. An independent
mapping trace identifies repeated layout work during Reddit's timestamp refresh
and large temporary DOM collection serialization graphs. The source reduction
below does not establish that repeated layout allocation is bounded.

Physical footprint measures macOS charged process memory. It is distinct from
RSS and from the guard's aggregate RSS safety reading. Sampling can miss short
spikes and short-lived children; external system services are excluded. An
existing user's browser process was inspected read-only and showed a 2.2 GiB
historical peak, but it is not a controlled trial of this URL.

## Implemented reduction

Commit `27cc9c860` streams native collection replies one element at a time.
Temporary attribute maps, metadata objects and JSON encoder work retire after
their bytes enter the reply. Bridge-key maps, materialization flags, lazy
input/textarea/video models and the final reply keep their owning lifetime.
Tag collections, class collections, selector lists and full-state collection
snapshots share this implementation. General adapters preserve their ordinary
allocation behavior.

The 256-element control executes the previous array-of-maps implementation.
Both implementations produce byte-identical JSON:

| Retained allocation | Bytes |
| --- | ---: |
| Previous collection serialization | 6,058,179 |
| Streamed collection serialization | 740,934 |

This is an **87.77% reduction in the focused serialization allocation**, not
a percentage reduction in whole-browser RAM. All three focused cases pass in
prealloc, arena-poisoned prealloc and default Boehm modes. They cover exact JSON,
stable wrapper identities, live membership after mutations, class/selector
collection replies, control-model lifetimes and SVG namespaces. Explicit runtime
checks use separate 3 GiB guards. Early compiler setup and poisoned-lifetime
failures remain in the raw directory; the final runs select the staged runtime
and pass with actual test and guard exits zero.

## Remaining validation

The original investigation ended while the shared production build was running.
The continuation below uses a completed canonical bundle containing
`27cc9c860`; that original build blocker is resolved.

Whole-page acceptance, complete longer idle and interactive checks, and
successful live-URL validation remain open. Native screenshot guards pass as
recorded in the continuation below. The 500 MB
target stays open until measurements establish it.

The [durable receipt](benchmark-results/reddit-comment-memory-2026-11-02.json)
pins raw samples, audit/capture hashes, runtime identities, focused guards,
source hashes, exact byte values and pending work. `probe.py`, `compile.py`,
commands, logs, invalid diagnostic attempts and actual exits remain in the
private raw directory above.

## Continuation on November 3

A fresh process using completed production executable SHA-256
`1bcbbb5cca048906caf2151070018fb7ec0618b5af140b465700ba31a9cd1d75`
replayed the same sealed thread with normal author scripts, a private empty
profile/cache and a 1708 × 941 document viewport. Frozen compiler input confirms
that this bundle contains the streamed collection implementation. The complete,
visible, fully active endpoint document still contains 49 comments and two
images, with zero native errors and the existing one JavaScript diagnostic.

| Observation | Simultaneous observed peak | Final two-second median |
| --- | ---: | ---: |
| Streamed collection bundle, 300 seconds | 942,164,080 B | 494,143,576 B |
| Query-decoder bundle, 300 seconds | 910,396,176 B | 465,340,384 B |

Runtime identities and the fixture manifest remained unchanged. The replay
server verifies each response body against its sealed hash before serving it.
Browser and guard exits were zero. This is a new baseline, not an attributed
comparison with the earlier build: other rendering/filtering changes landed
between them, and the earlier long run also used copied profile data. The
observed footprint rises from about 360 MB at 20 seconds to 494 MB at five
minutes, roughly 10 MB per 20-second timestamp refresh. A short observation
below 500 MB therefore cannot establish the requested limit.

Separate mapping and VM diagnostics locate repeated layout-tree, committed
geometry and line-buffer allocations during those refreshes. The startup
snapshot also shows substantial charged graphics memory. Native experiments
with per-draw autorelease pools and an eight-command-buffer queue did not reduce
the approximately 330 MB initial native graphics footprint. Both experiments
were reverted; their failed results and matching native pixel checksums remain
in the raw evidence. No optimization credit is assigned to them.

Commit `fe706a29c` additionally retires the temporary JSON graph decoded for each
compact DOM query. Only owned action, selector, key and replay-snapshot strings
survive the decoder. Replay and DOM writes retain their ordinary document
lifetime. Two focused cases pass in prealloc, poisoned prealloc and Boehm modes,
including DOM writes and UTF-8 strings used after the decoder workspace retires.
An allocation control containing 256 unused structured values retains 186,287 B
with the previous decoder versus 106 B for the selected request fields. This
transport stress case is not a whole-page RAM reduction.

The query-decoder observation uses executable SHA-256
`9cd7a4070b1721ba7a3ce41772dd35102b5b913aa1fab6990dc03af0a0169d6a`.
Its frozen C contains the decoder fix; bundle/fixture identities stayed stable,
and browser/guard exits were zero. Other native rendering and filter-resource
changes landed between these bundles, so the difference is not an attributed
whole-page saving. Eight required SVG image/paint-server mutation reftests are
pixel-exact on this bundle, including the same-size image-source replacement.
The existing collection cases also pass again in prealloc and poisoned prealloc.

### Unchanged timestamp geometry

Commit `30f441fa1` avoids constructing a new native layout graph when an ordinary
HTML `span` or `time` replaces its sole text child with identical nonempty text.
The DOM still creates a new Text node, queues mutation records and adjusts live
ranges. The layout mirror is rebound only after validating the complete set of
layout styles, DOM computed styles, text, connection states, dirty nodes,
viewport, coordinate scale, font generation and style environment. Paint-tree
rebasing publishes the fresh Text identity. Changed text, styles, structure,
controls or viewport use ordinary layout. Editable/shadow/SVG replacements and
first-letter/source-range replacements remain ineligible.

The original DOM style snapshot is separate from viewport-adjusted used styles;
synthetic form-control owners retain their original connection state. These
safeguards avoid mistaking unchanged internal control nodes for removed DOM.
Validation uses disposable scratch storage, while font/content caches retain
their owning lifetime.

Six focused cases pass in explicit prealloc and arena-poisoned prealloc runs,
covering DOM identity, ranges, mutation records, paint commands and fresh text-run
IDs, fallbacks, generated content, viewport overflow and synthetic controls.
The 50-refresh fixture retains **889,145 B**, versus **6,937,602 B** with ordinary
layout (only this reuse cache disabled in the control). This component result
is not whole-browser memory. A separate non-windowed diagnostic loads the sealed
thread's HTML, CSS and eight author-script sources, runs Reddit's actual visible
timestamp selector, and confirms reuse for **16 replacements** after initial
style/viewport stabilization. Earlier attempts that updated all 50 timestamps,
including hidden timestamps, remain retained as invalid workload diagnostics.

Production executable SHA-256
`f8618e0dd1854b53833106b154f9354dab0646d2e30069302a1c83163da33b60`
contains the fix. A fresh, separately instrumented 90-second observation records
real timer reuse at 20.45, 60.45 and 80.45 seconds; the initial update and a
40-second update correctly fall back when text changes. Its footprint is
426,412,216 B at the endpoint but peaks at 978,521,064 B. Nine native comparisons
are pixel-exact: the eight SVG mutation guards and an asynchronous identical-text
fixture beside an input, textarea and first-letter content. This does not show
that later real text changes have bounded allocations.

The first unprofiled 300-second follow-up observes 481,675,496 B at its endpoint
and a 980,634,624 B peak, but a shared bundle replacement changes its pinned
identity, invalidating that run. The second attempt crashes in
`Document.set_hovered_node_with_data` during native mouse exit. Its observer then
raises `StatisticsError` for an absent final sample window before persisting
counter samples/result, so its browser exit code and raw counters are unavailable.
The signal-11 stacks, guard exit 1, original commands, request log and 10-second
progress readings remain preserved; it supplies no memory acceptance evidence.
The observer has been corrected to persist samples and actual exits before
validating a complete interval. The hover/input ownership failure remains unresolved. A separate native
navigation/hover test passes normally and with arena poisoning; it does not
reproduce the windowed failure or establish its cause. No speculative input
change is shipped. A run named `private-thread-diagnostic8-poison` did not
actually enable poisoning because its environment cleaner removed the flag;
the final six-case poisoning evidence comes from `equal-arena-poison12`.
A later explicit `private-thread8-real-poison` run correctly enables poisoning
and passes the archived-page replacement check as well.
The separate `equal-poison12` run used an ineffective flag and is likewise not
counted as poisoning evidence.

### Scripted idle reclamation

Commit `d7dd67624` extends prealloc idle cleanup to scripted native documents.
It retires only empty replay-arena pages and detached thread recycle-cache
payloads; live DOM/JavaScript allocations stay owned, and the extra static-page
layout/font-cache policy keeps its existing eligibility. Navigation, background
resource work, active frame preparation and document readiness still guard
cleanup. All five focused cases pass normally and with arena poisoning,
including OS page-residency checks and surviving JavaScript closures, DOM wrapper
identity and later Unicode DOM writes. A private headless-page diagnostic does
not reach cleanup eligibility and fails its pending-work assertion; it establishes
no whole-page saving. A completed production bundle containing this change, executable SHA-256
`b4cf7612dfb00323187096ef34bf06af34cbcb7ed16d92185dac8b6db025fbb9`,
completes a fresh 90-second replay at **426,641,592 B**, with an observed peak
of **977,636,352 B**. Browser/guard exits are zero; executable, native-library,
filter, fixture and observer/helper source identities stay stable. The endpoint
is complete, visible, fully active, 1708 × 941, with 49 comments, two images,
zero native errors and the existing one JavaScript diagnostic. This separately
logged diagnostic confirms execution and continued growth, not an attributed
whole-page saving. All nine native screenshot comparisons are pixel-exact on
this bundle as well. The requested cap and complete longer unprofiled validation
remain open.

### Startup investigation

An injected diagnostic around the real dynamically resolved GPU bridge functions
on executable `f4c522c4364b68ba5638b51122e7153ca1a214b351e190caf5e0400270d48a39`
records the first picture draw increasing browser footprint from 369,117,272 B
to 713,705,560 B. The injection is verified by binding logs naming the real native
library paths. This diagnostic is separate from unprofiled observations and
provides no optimization credit. A standalone eight-pixel shape shows only small
public Metal buffer/texture allocations but a large transient footprint during
rendering; a plain Metal queue/empty command buffer stays around 4.5 MB. This
narrows the remaining investigation to GPU rendering/driver work rather than
queue count alone. No new graphics policy is shipped from these experiments.

Direct live access still redirects to HTTP 403, so these remain frozen-thread
observations. The 500 MB target stays open, including startup peaks.

The [continuation receipt](benchmark-results/reddit-comment-memory-2026-11-03.json)
retains the raw commands, identities, sampling gaps, focused checks, rejected
experiments and outstanding work under private
`Build/reddit-comment-memory-20261103/`. The earlier receipt remains unchanged.
