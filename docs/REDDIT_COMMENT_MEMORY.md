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


## Further continuation: retained paint and replies

Commit `05916442f` borrows text fragments during command recording instead of
making a wide heap copy each time the color bridge takes their address. The
512-fragment check retains 147,443 B of payload; the discarded record copies
alone previously required 647,168 B. Two cases pass with preallocation,
poisoning and Boehm, including whitespace joining and RTL geometry. Existing
phase-storage/snapshot checks pass normally and with poisoning.

Commit `a45bdaef0` keeps the paint projection when the complete unchanged-text
validation succeeds. Fragment grouping now uses the retained layout Text node;
selection, range geometry and hit testing still resolve its fresh DOM owner.
Independent pending paint updates remain intact. Eight focused cases pass
normally and with poisoning, including stable phase payloads, fresh-node hit
results and selection repainting. The 50-refresh fixture retains 423,535 B
versus 5,661,652 B with ordinary layout. On the archived thread, a separate
12-refresh diagnostic lowers the layout-stage document allocations from about
1,745,209 B to 204,081 B per unchanged seven-timestamp refresh. This is a component
allocation result, not a percentage reduction in whole-browser RAM.

Production executable `903ed05bc3aa460f6015fc465e3873a77d70fa601306c7bb46f18fd34aa95aeb`
contains both changes, verified in frozen compiler input. A fresh unprofiled
300-second original-origin replay records **385,779,872 B** at its final
two-second median and **895,290,296 B** at its simultaneous observed peak.
Browser and guard exit zero; runtime, observer and fixture identities remain
unchanged. The endpoint is complete, visible and fully active, with 49 comments,
two images, zero native errors and the existing JavaScript diagnostic. The
observed viewport is **1708 × 953**, reflecting intervening shared browser-chrome
changes; it differs from the earlier 1708 × 941 protocol. These are new
observations, without an attributed whole-page percentage. Nine native
comparisons are pixel-exact on this bundle: the eight SVG guards and the
asynchronous equal-text/control fixture. The preceding 300-second attempt
finishes at 392,546,488 B but changes bundle identity and is rejected.

Commit `243f30862` additionally retires native collection-response buffers after
the script engine copies their strings. The temporary-reply interface also
copies correctly in LibJS, while native mutations, element keys, materialization
flags and lazy control models retain their document lifetime. Tag-collection
metadata and its array share the same temporary response. Four collection cases
and two string-lifetime cases pass with preallocation, poisoning and Boehm.
The 24-query control retains 581,748 B versus 196,605 B with temporary replies.
A separate poisoned replay of the exact thread and its author scripts passes
12 replacement cycles. Production executable
`7b24528621023b8aac571be271b3e31edc63766ea2028b397085f067c8ebf6b1`
contains this change and passes all nine native pixel comparisons. A fresh
300-second replay finishes at **405,915,760 B** and peaks at **909,183,952 B**;
identities remain stable and browser/guard exits are zero. This higher footprint
than the preceding cohort is retained, with no attributed whole-page saving.
Native visual checks ran concurrently during the beginning of this observation;
its startup and endpoint scopes otherwise follow the protocol above.

Commit `6c4a24e00` retires the JSON containers decoded for a compact query's
pending mutation snapshot. Replay still runs in document storage; string values
installed in DOM/control records and logs are copied before the decoder retires.
The attribute-write boundary owns map-key names too. Two cases pass with
preallocation, poisoning and Boehm, including created SVG elements, qualified
namespaced attributes, stable wrapper identity and Unicode strings used after
retirement. The decoder stress control retains **508,875 B**, versus **8,008 B**
with the workspace. The archived seven-timestamp diagnostic lowers script-stage
document allocation from 281,631 B to 105,887 B per refresh and passes all 12
cycles normally and with poisoning. Production executable
`d9ac8f02f93515ca33b5fee082d265e8cb794741c44d1fac6a201e8811bc7481`
contains this change in frozen input and passes all nine native pixel guards.
Its first longer observation exits normally after 225 seconds without the
scheduled audit/capture, for an unknown reason; it is incomplete and rejected.
The next attempt completes 300 seconds at 377,636,976 B, but changes bundle
identity and is also rejected. A subsequent 90-second attempt also changes
identity and is rejected. The following **90-second** observation, on executable
`ac089f6e9ee05ca73fad9393a5bf7b5cf4f2a5f676cb280da0763b113a7bde59`,
is complete with unchanged identities and zero browser/guard exits. It settles
at **349,948,016 B** and peaks at **905,120,696 B**. Its peak after the first ten
seconds is **804,849,848 B at 40.50 seconds**. The viewport remains 1708 × 953
with 49 comments and two images; the document is complete, visible and fully
active with zero native errors. This shorter observation supplies no five-minute
acceptance for the snapshot fix. Two SVG paint-server ID-collision reftests also
remain pixel-exact on this bundle. They overlap the final part of this observation;
the first 40 seconds have no concurrent visual checks.

The investigation also tested an IOSurface readback prototype, the existing
Boehm mode and an opaque-text CPU raster prototype. None demonstrated the
requested whole-page startup cap; no allocator or graphics-policy change ships
from these experiments. The text prototype passes its forced-GPU pixel controls
but still observes an approximately 893 MB page peak, because rounded decoration
recording initializes the GPU as well. Its source changes were reverted. An
instrumented stack confirms that first picture use in
`draw_chromium_rounded_background_pair`; diagnostic traces do not supply memory
optimization credit. Early setup/compile failures and the rejected prototypes
remain retained in the raw evidence.

A final picture-cache experiment (`791aad04e`, reverted by `5b24f8c69`) retains
at most 8 MiB of exact picture inputs and outputs across idle GPU retirement.
Ownership/limit checks and 24 GPU replay cases pass, including a separate shared
image-token retirement check. Diagnostic traces show cache hits on the archived
thread, but change bundle/source identities and receive no performance credit.
Two subsequent unprofiled alternating control/candidate pairs keep every input
identity unchanged. Each observation runs for **65 seconds**, using executable
`a1157f457afdfb4266c3743f9c0fbe6f4f64257fbc93b4ff827dc7318790db9a`
with a private native-library override
`55cfbf13567ce0e8ece6dd0b8d42c407e6c947ad8bd1bfcae47bf60377ff3477`.
Controls disable only the new cache. These are experimental-library observations,
not validation of a published production cache. Browser and guard exits are zero;
no visual checks overlap these four observations. The 18-core host's recorded
load varies across trials, and other sessions continue working.

| Trial | Settled footprint (B) | Launch peak (B) | Peak after 10 s (B) |
| --- | ---: | ---: | ---: |
| Control 1 | 339,544,200 | 904,743,888 | 792,889,504 |
| Candidate 1 | 339,806,320 | 907,676,552 | 802,162,848 |
| Control 2 | 340,297,840 | 890,309,560 | 810,338,488 |
| Candidate 2 | 341,592,152 | 888,867,696 | 791,005,272 |

The experiment does not demonstrate a whole-page memory improvement or the
requested cap. It is reverted rather than retaining extra cache storage without
a demonstrated workload benefit. Its source commit, revert, failed setup/check
attempts, successful focused controls and every observation remain recorded.

**The complete 500 MB limit remains unmet.** Successful five-minute endpoints
are below it, but both startup and later refresh spikes exceed it. The valid
paint-reuse cohort reaches **839,141,584 B at 180.45 seconds** after excluding the
first ten seconds; the temporary-reply cohort reaches **849,742,056 B at 280.54
seconds**. GPU-context recreation during later painting therefore remains a
problem as well as startup. Residual refresh allocations also remain.
Longer and interactive validation, and live-site validation remain open. A fresh
direct request in this continuation again returns HTTP 403. The
[further-continuation receipt](benchmark-results/reddit-comment-memory-2026-11-03-continuation.json)
links private raw evidence under
`Build/reddit-comment-memory-20261103-continuation/` without committing cached
account-bearing page data.
