# Old Reddit comment-page memory

The requested limit is **500,000,000 bytes** for
`https://old.reddit.com/r/UkraineRussiaReport/comments/1xls5ou/ua_pov_ukraine_hits_10_of_russias_oil_refining/`.
The measured production bundles **exceed this limit**. The latest valid
five-minute observation settles at **329,418,840 B** and peaks at **729,827,464 B**
on executable `c9ff98ac…`. A later 65-second production observation peaks at
**683,903,760 B** and settles at **248,580,136 B** on executable `d69e4a67…`,
using the cache-recovered fixture described below. A twenty-second observation
on `98dfbb7c…` peaks at **639,863,520 B** and settles at **236,554,232 B**;
twelve canonical visual comparisons pass on both builds. An attempted five-minute
attempt is rejected because the executable changes during observation.
The earlier thirteen-case cohort on `590975bd…`
remains separately recorded.
The continuations below record the pinned builds and focused checks.
A later private CPU-rendering experiment observes a 405,834,632 B five-minute
peak, but is not shipped and fails two exact rounded-border comparisons.
The peak investigation below records that distinction and corrects an earlier
private-backend screenshot attribution error.
Committed fixes reduce collection/query
transport, retained paint copies and native raster storage. Focused checks and
native screenshot guards pass; the complete memory cap and live-site validation
remain open. The rendering continuation below records the measured build and
rejects an earlier low-memory run that blocked author scripts.

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

## Rendering storage continuation

Five more memory fixes are committed. These component results do not establish
an attributed whole-browser percentage or the requested peak cap:

- `3c5d0fe1b` retires the inactive GPU backend before its peer creates a context
  on the owning main thread. It preserves reusable CPU pixels and independent
  worker ownership; no Skia objects cross the library boundary. Twelve
  alternating GPU cases retain exact pixels with and without the handoff.
- `46d05ebc1` uses a decoration's original backdrop as its rollback checkpoint,
  transferring the allocation when cropping instead of copying it at begin.
  The 184 existing decoration scenes and four additional storage/rollback
  cases pass. At this viewport and backing scale, the removed initial
  viewport copy alone occupied 26,043,584 B.
- `a5b146097` reserves decoration rollback rows from conservative transformed
  ink bounds. Unknown or invalid bounds preserve the full-viewport fallback;
  final Chromium GPU tile geometry stays unchanged. Three focused cases pass
  normally and with arena poisoning, covering small ink, transforms, viewport
  clipping and fallback.
- `b5577df71` stores an immutable stationary frame as one CGImage, avoiding an
  eager duplicate byte backing. It preserves the ordinary byte-copy path,
  provider-copy fallback and allocation-failure repaint. Native checks pass
  in snapshot and forced-copy modes, including padded rows, scales 1/2,
  invalidation, independent content and representation transitions. The
  removed full-canvas byte duplicate occupied 29,104,320 B here.
- `82b1dd7dd` retires temporary vectors for independent element matching while
  retaining cached selector parsing outside that workspace. Relational and
  control-dependent selectors preserve their ordinary lifetime. Two cases
  pass with preallocation, poisoning and Boehm; 512 callback matches retain
  **0 B**, versus **57,354 B** in the former path. The five-minute production
  bundle below does not contain this last fix; a subsequent 65-second
  production observation includes it.

A separate allocation-stack diagnostic identifies full-canvas stationary,
scroll and effect-layer buffers, plus the decoration checkpoint. It loads the
author scripts successfully, but uses allocation instrumentation and a private
native-library override; it supplies allocation locations, not optimization
acceptance. Isolated GPU diagnostics also show roughly 320 MB charged footprint
after drawing and reading back one rounded rectangle despite less than 5 MB
of device-reported resource allocation. Metal queue depths 1/2/64 do not remove
the large first-draw charge. Deferring the static-buffer submission until the
first draw still reaches 319,423,160 B in an isolated process. Neither queue nor
submission policy changes ship. Additional allocator pressure relief trims at
most about 2 MB per call and likewise supplies no production-policy change.

The GPU handoff uses an alternating, unprofiled 65-second control/candidate
cohort with private GPU libraries and production executable
`759a9af066d214540c1c06b70796a1658b1ed1a1ea14abf53c67662825085f31`.
Each launch keeps its executable, libraries, tools and frozen resources
unchanged; controls disable only the new handoff. Normal author scripts run,
browser/guard exits are zero, and no native windowed visual checks overlap.
The 18-core host is busy, with load averages varying roughly 17–35 and some
focused compilations overlapping the observations. The counts are retained
without attributing all variation to this change.

| Trial | Final two-second median (B) | Launch-to-end peak (B) | Peak after 10 s (B) |
| --- | ---: | ---: | ---: |
| Control 1 | 341,379,184 | 906,070,920 | 800,753,824 |
| Candidate 1 | 339,380,336 | 805,358,496 | 778,324,104 |
| Control 2 | 340,986,016 | 909,888,464 | 785,549,472 |
| Candidate 2 | 340,199,584 | 817,695,696 | 764,692,688 |

The focused GPU tests and nine native SVG/equal-text comparisons are
pixel-exact with those libraries. Full-window thread screenshots differ in
clock-driven timestamp text and the browser's RAM footer (562 and 177 pixels
in the two pairs); they are not whole-page pixel-equivalence acceptance.

### Rejected script-blocking result

An initial five-minute production run appears to settle at **227,985,376 B**,
but its packaged adblock helper fails to evaluate a deferred regex module
containing `export default` as a classic script. All seven external author
scripts are consequently blocked. Its **677,186,272 B** peak, normal exits and
stable executable identity do not make it a valid comparison. That entire
memory result and the similarly affected pressure diagnostic are rejected.

Commit `1a2ca208c` validates classic-script snapshot sources and lowers standalone
module payloads to a classic IIFE at build time. The pinned regex module still
publishes its intended global. All 33 adblock Node tests and the packaged
JavaScriptCore worker check pass after regenerating the assets. With corrected
assets explicitly selected, a fresh 65-second production observation runs the
page scripts, settles at **339,544,224 B** and peaks at **772,574,088 B**. This is
an asset-override observation, with stable identities and zero browser/guard
exits; it is not a stock-bundle acceptance claim. Only the existing badge-fetch
JavaScript diagnostic remains.

### Verified production observation

The subsequent completed stock production executable is SHA-256
`1486289b5013a3b9919e590097cb85620c4a3b0855e8046311fc742e39cb8d22`,
from receipt `20261103-051125-e8810077`. Frozen compiler input confirms the
bounded decoration checkpoint and image-only stationary-frame storage. Its
packaged filter assets match the corrected assets, and its two GPU libraries
export the context-retirement entry points. No library, asset or allocator
override is used in this observation.

A fresh original-origin HTTPS replay completes **300 seconds** with normal
author scripts, unchanged runtime/tool/fixture identities and zero
browser/guard exits. The document is complete, visible and fully active at
**1708 × 953**, with 49 comments, two images, zero native errors and only the
existing badge-fetch diagnostic. It settles at **367,577,224 B** and reaches
**766,380,168 B at 280.63 seconds**. Thus this is a later-refresh peak as well
as a launch-to-end maximum. The maximum sampling gap is 67.21 ms. External
system services and short-lived/unobserved tasks remain excluded, so the
sampled result is a lower bound, distinct from the RSS safety guard.

Nine native SVG/equal-text comparisons are pixel-exact on that measured build.
While verification continues, the shared builder publishes executable
`5775fb14cc09615bf2d0038c2584e5a444ef67311d90159ca8ac588b9f1b8e8c`,
from receipt `20261103-052152-d626bb42`. Frozen input confirms all five fixes,
including independent element matching. A fresh **65-second** stock replay
with normal author scripts settles at **312,936,536 B** and peaks at
**752,601,968 B**. Identities stay unchanged, the complete document audit passes
and browser/guard exits are zero. Intervening shared layout changes are present
too; no whole-page percentage is attributed to element matching. This shorter
run does not establish five-minute behavior of the latest build.

Both SVG paint-server ID-collision comparisons are pixel-exact on this newer
bundle. The asymmetric rounded-border and MSAA rounded-border fixtures also
remain exact against the unchanged Brave references with Chromium rendering
policy. Their first attempt incorrectly selected LibWeb test-font policy and
failed; it remains retained without pass credit. Visual checks follow the
five-minute observation and precede the newer 65-second observation. All use
fresh processes with unchanged pinned input identities.

**The 500,000,000 B peak target remains unmet.** The five-minute run's endpoint
is below it, but its later refresh is above it. A fresh direct request still
returns HTTP 403, so these frozen-page results do not establish a live-site
fix. Longer interactive checks and a five-minute observation of the newest
bundle remain pending. The
[rendering receipt](benchmark-results/reddit-comment-memory-2026-11-03-rendering.json)
records exact counts, every failed/rejected attempt, hashes, commands, guard
exits and private raw artifacts under
`Build/reddit-comment-memory-20261103-rendering/`. Prior receipts and results
are preserved.

## Transport and cosmetic-filter continuation

Six further fixes preserve the ordinary scripted workload:

- `42920db38` retires temporary JavaScript host-input conversion and borrows the
  pending mutation snapshot until its query request finishes. Primitive string
  conversion uses disposable storage; object coercion and its reentrant native
  effects execute with ordinary ownership. Ordinary host callbacks keep their
  existing string ownership.
- `8de0d0d4c` retires asynchronous finalizer text after native replay. JavaScript
  evaluation and object-to-string hooks stay outside temporary storage. Replay
  containers retire after use, while DOM/control values, diagnostics and
  navigation strings keep the document owner.
- `4d01bdfef` decommits empty spare pages and unused suffix pages of layout
  arenas on idle scripted tabs. Live layout, retained scenes, hit testing and
  script-visible state survive. `VOX_KEEP_SCRIPTED_LAYOUT_PAGES=1` restores the
  previous scripted-tab skip for diagnostic controls.
- `fed50c6f9` retires the JSON parser's index and intermediate values when
  decoding cosmetic/scriptlet replies. Its returned strings and arrays remain
  caller-owned. The decoder's type metadata initializes at startup, before a
  worker or disposable parser can publish it from a short-lived owner. Invalid
  replies preserve the codec's concrete error type and message.
- `2987d848b` lets stylesheet refreshes reuse immutable, process-owned CSS from
  the bounded document-filter memo. Refreshes no longer copy unused scriptlets,
  procedural selectors and filter lists. Full filter lookups still return
  independent arrays. Cached CSS counts against the existing 2 MiB memo budget;
  disabled filtering, token/URL distinctions and the memo-disable control retain
  their behavior.
- `75b4dc084` retires the composed source used to compare an unchanged
  stylesheet. Actual replacements receive owned source bytes before stylesheet
  parsing or publication; existing user and procedural rules retain their
  behavior. Across 32 unchanged refreshes of a 172,250 B sheet, the focused
  fixture retains 6,648 B. This case passes in prealloc, poisoned prealloc and
  Boehm modes, including reading a replacement after its workspace retires.
  The two existing identity/enablement cases pass again normally and poisoned.
  The completed production observations below predate this final fix.

| Focused allocation workload | Previous retained bytes | New retained bytes |
| --- | ---: | ---: |
| 32 large temporary host string inputs | 3,934,314 | 693 |
| 32 large asynchronous string results | 3,934,153 | 504 |
| Asynchronous mutation snapshot replay | 504,745 | 7,961 |
| Large cosmetic/scriptlet reply decode | 1,385,242 | 172,281 |
| 32 CSS-only refreshes of a cached reply | 5,512,186 | 2,976 |

These are retained allocations in focused fixtures, not browser RAM percentages.
The query request also retains only 528 B across 16 large borrowed snapshots.
The host, query, evaluated-text, mutation-replay, filter-decoder and CSS-memo
cases pass in prealloc, arena-poisoned prealloc and Boehm modes. Fourteen existing
asynchronous paint cases pass normally and with poisoning. Six browser idle
cleanup cases and two layout-page cases preserve live owners, later script
mutations and refill; `mincore` verifies spare-page decommit. Seven existing
filter-memo cases and two browser stylesheet identity/enablement cases pass,
including poisoned runs. The raw receipts retain actual test and guard exits.

An instrumented allocation stack on production executable `317f313a…` identifies
**16,777,216 B** of arena growth in the old filter-reply decoder during
`poll_javascript_tasks → relayout → refresh_browser_adblock →
install_browser_adblock_styles → document_filters → json2 decoder_for_text`.
That trace supplies allocation attribution, not an unprofiled RAM saving. The
first instrumentation attempt aborts in dyld TLS initialization before browser
startup; a separately built hook using atomic recursion state completes. Only
nonzero retained-owner arena readings are interpreted; zero readings outside
that owner do not prove zero memory use.

A private Metal picture backend preserves its exercised mixed-typeface scene,
then observes a 765,021,016 B peak and 318,195,872 B endpoint over 65 seconds.
Its executable differs from the baseline, so it earns no matched comparison
credit and does not ship. Twelve forced JavaScriptCore collections free at most
32,768 B directly per call; that diagnostic also changes bundle identity and
earns no whole-page comparison credit. No new GC or graphics policy ships.

The scripted-layout-page control sequence retains all four attempts. The first
three complete with stable identities and normal author scripts:

| Trial, 65 seconds | Final two-second median (B) | Observed peak (B) |
| --- | ---: | ---: |
| Control 1 | 304,367,704 | 733,694,808 |
| Candidate 1 | 302,270,552 | 727,796,496 |
| Control 2 | 304,629,848 | 739,101,456 |

Candidate 2 reports a 183,846,856 B endpoint, but its bundle changes and the
script helper fails with `Cannot determine the adblock helper executable (2)`.
**That low-memory run is rejected.** The original outer cohort guard receipt
is empty after a supervisor interruption, so there is no outer-exit credit or
complete-cohort optimization claim. Individual trial receipts and the original
three-row summary remain preserved.

A valid stock-production five-minute observation containing the first two
transport fixes, executable `a630da28…`, settles at **357,107,848 B** and peaks at
**756,533,384 B at 280.66 seconds**. Its identities remain unchanged, browser and
guard exits are zero, author scripts run, and the complete 1708 × 953 document
retains 49 comments and two images. It predates the scripted layout-page trim
and both filter fixes; differences from other shared builds are descriptive.
Nine SVG/equal-text native comparisons on the subsequent `317f313a…` bundle are
pixel-exact.

A newer valid five-minute production observation, executable `82859cf5…`,
contains the first four fixes above. It settles at **347,261,064 B** and peaks
at **748,947,568 B**. Frozen compiler input contains the temporary filter decoder
but predates CSS reuse. Browser/guard exits are zero, all pinned identities
remain unchanged, and the original URL/title, complete visible document,
49 comments, two images and expected author-script diagnostic pass their audit.
The longest sampling gap is 63.83 ms. This is a stock-production observation;
other shared changes prevent attributing its entire difference to these fixes.
All thirteen native comparisons on this same build are pixel-exact: the nine
SVG/equal-text cases, two SVG paint-server ID-collision cases and two existing
Brave rounded-border goldens. Runtime and reference hashes remain unchanged,
and the visual guard exits zero. These launches follow the memory observation.

The next completed production build, executable `49cfad20…`, contains the first
five fixes. Its valid five-minute observation settles at **338,348,192 B** and
peaks at **750,554,016 B**. Browser/guard exits are zero, pinned identities remain
unchanged, and the content/author-script audits pass with the same viewport,
49 comments and two images. The longest sampling gap is 62.38 ms. All thirteen
native comparisons pass pixel-exact afterward on this build as well, with
unchanged references and runtime identity. Clock-driven timestamp changes and
other shared changes prevent assigning its full endpoint difference to CSS
reuse. The repeated graphics spike still exceeds the requested cap.

Direct live access still returns HTTP 403. The **500,000,000 B peak cap remains
open**, including startup and later refreshes. Raw commands, all failed setup
attempts, frozen compiler inputs, native diagnostics, guard exits, samples and
content audits remain in private `Build/reddit-comment-memory-20261103-input/`.
Completed generated C test inputs were losslessly gzip-compressed to recover
workspace disk space; a manifest retains both original and compressed hashes.
No executable or app bundle was copied. The [transport receipt](benchmark-results/reddit-comment-memory-2026-11-03-transport.json)
links the exact artifacts and preserves earlier evidence.


## Initial host metadata and peak investigation

Commit `95715459e` retires the initial compact host's temporary metadata maps,
bridge-key survey, video survey and encoded JSON after JavaScriptCore copies
the transport. Selector caches and lazy input, textarea, image and video models
retain their owning document lifetime. For 256 named elements, identical
229,635-byte JSON retains **8,631 B** instead of **7,045,771 B**. This is a
component allocation result, not a browser RAM percentage. All three focused
cases pass in prealloc, poisoned prealloc and Boehm configurations; four existing
collection cases also pass normally and with arena poisoning. The native case
initializes the complete host and exercises controls, SVG namespaces, lazy
parents and mutation replay after the transport workspace is poisoned.

Completed production executable `ada886d0…`, receipt
`20261103-070539-bea0fd2d`, contains the temporary stylesheet comparison and
initial-state transport fixes in its frozen compiler input. An earlier
five-minute observation of `103ca442…` finishes with normal author scripts and
zero browser/guard exits, but the bundle changes during observation: its
754,764,560 B peak and 345,639,024 B endpoint are **rejected as acceptance**.
No valid later stock-production five-minute observation supersedes the
750,554,016 B result at the top of this report.

Instrumented diagnostics retain their own identities and are excluded from
unprofiled optimization credit. A background mapping probe observes 38 large
anonymous mappings with 15,974,400 B captured residency at its last snapshot;
its recursion guard can miss concurrent mappings and it excludes allocations
below 1 MiB. Those observations do not establish a bound on all worker memory.
Asynchronous `vmmap` snapshots locate approximately 166 MiB dirty untagged
storage, including V arenas, 52 MiB WebKit malloc and 25–53 MiB large malloc.
Snapshot completion is later than its trigger, and a file named `idle-vmmap`
was taken around eight seconds: it does not establish a graphics-idle state.
An isolated rounded-rectangle test of Graphite's avoid-depth option preserves
its pixel hash, but uses 320,602,808 B at submission versus the control's
320,357,048 B. Neither that option nor a worker ownership policy is shipped.

A private pair of native libraries disables the Metal leaf context and
rasterizes serialized pictures with Skia CPU surfaces. The app bundle is
unchanged. A separate direct-launch diagnostic records dyld loading both
private libraries and actual CPU picture/leaf calls. With those diagnostic
markers disabled, a fresh `ada886d0…` process observes:

| Private CPU prototype, 300 seconds | Bytes |
| --- | ---: |
| Simultaneous observed peak from fresh launch | 405,834,632 |
| Observed peak after ten seconds | 403,409,008 |
| Final two-second median | 339,036,200 |

The longest sampling gap is 71.23 ms. Browser and guard exits are zero, pinned
executable/library/fixture identities remain unchanged, and the endpoint audit
retains normal author scripts, the original URL/title, a complete visible and
fully active 1708 × 953 document at backing scale two, 49 comments and two
images. The existing badge-fetch diagnostic remains; there are zero native
errors. Memory is sampled browser/observed-descendant physical footprint,
including startup and later refreshes, before the endpoint audit and PNG.
The separate safety guard measures aggregate RSS. Short spikes, short-lived
helpers and external services may be omitted by sampling. Filesystem/font/shader
caches are retained. No native visual checks overlap the observation; host load
and overlapping focused compiler work are recorded. This is one unprofiled
five-minute observation on a private renderer, not a matched stock-production
cohort, scrolling result or verified permanent bound. The trace still grows
while idle. Direct live Reddit validation remains blocked by HTTP 403.

### Correction to private-backend visual attribution

The first thirteen allegedly private CPU comparisons passed only
`DYLD_LIBRARY_PATH` through `sh capture_screenshot.sh`. macOS removes that
variable when launching the protected shell, so those captures actually use
the **stock renderer**. Library hashes recorded by the wrapper do not prove
that a library was loaded. The original thirteen zero-difference results remain
preserved and receive no private-CPU correctness credit. Earlier private
context/Metal-picture screenshot wrappers using that same mechanism have the
same limitation. Their direct `dlopen` functional checks and direct Python
browser memory observations are unaffected. Later explicitly stock-production
SVG/rounded-border comparisons remain valid under their recorded identities.

Commit `8b2af2b62` fixes the canonical screenshot tool's explicit override with
`SCREENSHOT_GRAPHICS_LIBRARY_DIR`: the shell resolves it and exports
`DYLD_LIBRARY_PATH` itself. Optional `SCREENSHOT_BROWSER_LOG_DIR` preserves
browser logs. A stock rounded-border capture remains pixel-exact without CPU
markers. An explicitly overridden capture logs CPU picture execution and
reveals 64 differing edge pixels, maximum channel error 42. A subsequent full
private-CPU check on executable `d5414c4a…` records the actual backend in retained
browser logs: all eleven SVG, same-size image, text and paint-server ID cases
are exact, while **both existing rounded-border goldens differ by 64 of
786,432 pixels each**. The exact-visual guard correctly exits one. References
and tolerances are unchanged; the default diff tool's fuzzy exit zero is not
treated as pixel equality.

The CPU path is a reviewable experiment, with source patches, compiler input
hashes, libraries, commands, captures and actual guard exits retained under
`Build/reddit-comment-memory-20261103-peak/`. No CPU-default or CPU-opt-in
renderer policy has shipped. A verified caller trace on the replayed thread
includes image, SVG-path, rounded-part and general-shape draws, so routing only
trivial rectangles through software is not demonstrated to solve this page.
The first caller-probe attempt resolved a symlink into the older private CPU
directory and captured no caller markers; it receives no attribution credit.
The thirteen focused visual cases also do not establish whole-page CPU/GPU
pixel equality on Reddit. The default production peak cap, persistent idle
growth, longer navigation/interactive checks and live-site validation remain
open. The [peak investigation receipt](benchmark-results/reddit-comment-memory-2026-11-03-peak.json)
retains the exact identities, failed attempts, raw artifact hashes and focused
checks. Completed generated C inputs were losslessly compressed; their
manifest records original and compressed hashes.


## Reusing the native text-validation index

Commit `011993bfe` moves the private equal-text validation index from a replaced
native layout result to its successor and refills the same vector. Previously
every full relayout allocated another page-wide vector in the document arena.
Only the current result consumes this index; published geometry, retained paint
scenes, DOM identities and live ranges keep their existing ownership. A
geometry-only tree-dump result continues to have no text-reuse index.

For a 256-comment fixture, sixteen index refills retain **0 B** with reuse versus
**6,295,545 B** with the old discard/rebuild behavior. These are component
allocations, not whole-browser RAM savings. Three focused cases pass normally
and with full arena poisoning. They check the retention budget, a real changed
text relayout followed by equal-text reuse, retention of the previous published
scene, and invalidation for a geometry-only result. Eight existing equal-text
cases pass normally and with poisoning, preserving text-node/range/paint
identity, connection state and fallback after real content/style/viewport
changes. The first fixture failures omitted the explicit scene and presented
projection leases required by native snapshots; those failed runs remain
preserved, and the corrected fixtures retain the original snapshot assertions.

A fresh pre-change stock-production observation on executable `73c98de0…`,
65 seconds, peaks at **735,431,488 B** and settles at **290,080,904 B**. Its
identities remain unchanged, browser/guard exits are zero and the complete
original-origin replay passes the normal author-script and content audits.
An 80-second instrumented arena observation on the same executable peaks at
730,860,376 B and settles at 290,203,736 B. Zero arena readings when no retained
owner is entered do not establish zero document allocation; the asynchronous
mapping stacks are diagnostics, not optimization credit.

A completed production build containing the cache fix, executable
`2cd7a620…`, receipt `20261103-075630-018eebea`, completes a five-minute
observation with a **307,120,240 B** final two-second median and a
**728,435,544 B** simultaneous observed peak. Frozen compiler input confirms
both the cache move and vector refill. Browser and guard exits are zero;
executable, native-library, filter-resource and fixture identities remain
unchanged. The original URL/title, complete visible fully active 1708 × 953
document, 49 comments, two images, zero native errors and expected badge-fetch
JavaScript diagnostic pass the audit. The longest sampling gap is 66.28 ms.
Host load is high: 49.64/24.55/14.45 on 18 CPUs at launch, with other sessions
active. Shared native/CSS changes, clock-driven content and host contention
prevent attributing the whole-browser difference to index reuse. The startup
spike still exceeds the target; a later refresh also reaches **707,135,600 B**
at 280.65 seconds, and idle growth continues. After the observation, all
thirteen native SVG, same-size image, equal-text, ID-collision and rounded-border
comparisons are pixel-exact on this same executable. Runtime, tool and reference
hashes remain unchanged; the visual guard exits zero. No references or
tolerances change.

Two further private GPU experiments do not ship. Limiting Metal command queues
to four or eight pending buffers preserves the isolated rounded-rectangle hash,
but the observed submission footprint stays around 319 MB. A Ganesh/Metal
experiment using the installed upstream Skia library reaches 352,453,280 B at
submission and produces a different region hash from the Graphite control.
Its different Skia/backend inputs prevent matched attribution; it demonstrates
neither the required memory reduction nor identical rendering.

A fresh direct live request still returns **HTTP 403**. Renderer policy is
unchanged. The CPU renderer remains experimental, with its known edge differences and
longer-run limitations recorded above.
The default-production **500,000,000 B peak target remains open**. All commands,
samples, actual guard/test exits and failed fixtures for this continuation are
retained under `Build/reddit-comment-memory-20261103-retained/`. A new compression
manifest maps completed generated C inputs to losslessly verified gzip files;
no source tree, repository tool or browser bundle was copied.

The [retained-index receipt](benchmark-results/reddit-comment-memory-2026-11-03-retained.json)
pins the feature, frozen production input, focused checks, all observation and
visual artifacts, GPU experiments and fresh live-access result.


## Metal transport and sparse opacity canvases

Four more independently tested fixes are committed. The overall
**500,000,000 B peak cap remains open**; the component results below cannot be
added together as whole-browser savings.

| Commit | Change | Focused control → candidate |
| --- | --- | ---: |
| `698524ed2` | Upload immutable Metal meshes through host-visible buffers | 118,079,488 → 32,768 B graphics growth at recorder snap |
| `7319dd632` | Use shared-memory Metal leaf uploads, backdrops and readback | 340,492,288 → 188,989,440 B graphics growth through rendering/readback |
| `6baeb3c38` | Retire physical pages of large idle opacity canvases | 29,147,136 → 16,384 B footprint growth after returning a viewport canvas |
| `7a2a336e8` | Avoid reading never-backed pages during opacity ink scans | 29,098,008 → 0 B footprint growth during a sparse viewport scan |

The static-mesh patch authenticates the original and patched pinned Skia source
and verifies staged bytes before installation. Its three patch-preparation tests cover
idempotence and rejection without partial installation. The negative runtime
control fails its allocation assertion and the candidate preserves the exact
rounded-rectangle pixel hash. It changes only Metal; other backends retain
their transfer path.

The Metal leaf path uses the device belonging to the recorder, checks unified
memory and texture limits, and retains Skia's existing path for unsupported
formats, alpha/color conversion, scaling and mipmaps. CPU backdrop replacement
first snaps and completes pending clears/draws. CPU readback waits for queued
GPU writes and returns independently owned bytes. Targets export CPU pixels,
not GPU snapshots. The bridge now explicitly uses the release layouts of its
pinned Skia archive, which is necessary for the private recorder/device records.
The focused test checks padded partial writes, image-source ownership, target
reuse, bounds, conversion/scaling fallbacks and result lifetime after teardown.
The memory-negative control passes its preceding pixel assertions before
failing the 230 MiB graphics-growth budget. Native shader rendering stays on
the GPU; the production picture renderer remains Dawn.

Against the previous native leaf, 6,984 shape and 1,928 path comparisons are
exact. Eight additional GPU checks pass: 1,344 image-tile comparisons, 32
independent mipmapped-picture comparisons, 512 SVG-region cases, 384 mixed
reused-target cases, 96 recorder failure/teardown replays, 4,718 raster replays,
2,112 image-region cases, and 24 SVG-pattern cases plus 120 unchanged-failure
checks. These cover cold/warm caches, source/backdrop changes, profiles, overlap,
MSAA, clipping and row padding. All thirteen native SVG/image/text/ID-collision
and rounded-border pixel checks pass with the explicit private leaf override.
A separate stock-production run also passes all thirteen on executable
`c9ff98ac…`, receipt `20261103-091717-6b3a184e`, containing the leaf change.
Runtime/tool/reference identities remain unchanged. No references or tolerances
change.

Two alternating eight-second stock/private-leaf pairs use the same executable
`e9deac23…`, installed Dawn backend, fixture, viewport and normal author scripts:

| Pair | Stock observed peak | Shared leaf observed peak |
| --- | ---: | ---: |
| 1 | 742,984,536 B | 711,052,096 B |
| 2 | 729,058,088 B | 728,582,952 B |

Every browser/guard exit is zero; identities and fixture remain unchanged and
content/author-script audits pass. These short startup observations still fail
the cap. Their variation does not justify a whole-browser percentage claim.
They precede the two opacity fixes and do not validate those fixes in the
browser. Host load and per-task kernel lifetime peaks are retained separately
in the receipt; sampled simultaneous peaks remain lower bounds.

The opacity pool now gives buffers of at least 1 MiB dedicated anonymous
mappings. Returning an idle canvas replaces its owned mapping with zero-fill
pages, preserving its address, virtual capacity and CGContext state while
releasing physical memory. Small buffers keep the original allocation and
clip-clearing path. The 2,304 existing pool comparisons pass, including nested
ownership, color spaces, state reset, eviction, budgets and snapshots. A new
large-canvas test verifies the 16 KiB return cost, transparent reuse at the same
address, full-size snapshot immutability and actual mapping teardown.

Scanning a transparent mapping can itself fault in an entire viewport. A
rejected experiment skipped writes to zero chunks, yet still charged
29,147,136 B just by reading them; its failing memory check and patch remain
preserved. The shipped scan consults page dispositions only for the pool's own
anonymous mappings. A page with no backing is still zero-fill. Nonzero
compressed, resident or unknown flags keep the byte scan, as do failed/short
queries and small buffers. This interpretation follows the VM object/shadow
walk and compressor handling in Apple's
[page-info implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/vm/vm_map.c)
and [range-query implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/vm/vm_user.c).
There are 1,500 exact clipped comparisons across page/row boundaries, with
simulated compressed/unknown dispositions and query failures, plus sparse
allocation and empty-reuse checks. Existing opacity tests also preserve
134,217,728 exhaustive composite pixels and 33,280 ink-bound comparisons.

Additional private GPU experiments remain unshipped. Bare Metal probes on this
machine charge approximately 181 MB for the render engine and 118 MB for the
transfer engine, even at 160 × 64. Shared CPU-visible target/image transfer
preserves all thirteen native pixel checks and four mixed-typeface GPU picture
comparisons. Private CPU atlas uploads remove the observed blit-encoder calls,
but sampled page peaks remain about 608 MB and kernel lifetime spikes can be
higher. Per-call autorelease pools observe about 595 MB in one diagnostic.
Earlier recycle-page trimming, malloc pressure relief, inline-buffer trimming
and public JSC collection do not establish a passing cap. These runs use
different evolving executables and diagnostic settings; they supply no matched
optimization percentage or production acceptance. The argument-buffer toggle
that produces transparent output is rejected. Failed compilation/setup attempts
are retained alongside successful checks.

A fresh direct live request again returns HTTP 403. Shared production builds
initially retain the previous bundle after input changes during preprocessing
and an unrelated ECDSA link failure. A later successful build resolves that
validation gap. Executable `89526286…`, receipt `20261103-093652-b9f00af8`,
contains both opacity changes in its frozen compiler input and passes all
thirteen exact visual comparisons. A twenty-second original-origin replay
peaks at **686,689,136 B** and settles at **277,301,312 B**. Normal author-script
and content audits pass, identities remain unchanged and browser/guard exits
are zero. No separate production build is queued by this investigation.

The actual-page diagnostic then shows why the sparse scan alone does not
reclaim its full component saving: an earlier compositor-prefix scan already
reads all 1,777 zero-fill pages before the final ink scan. Commit `a3e50e460`
uses the same page-aware scan at that earlier boundary. The native adapter
explicitly registers pool-owned mappings with capability value two; legacy and
speculative contexts do not acquire that ownership assumption. Registration
is cleared at frame boundaries and on unregister. Fractional origin, real
prefix pixels, failure signaling and speculative/forced recording retain their
existing behavior. The isolated prefix control charges **29,147,160 B** versus
**16,384 B** with the change; 44 deferred-layer GPU scenes remain pixel-exact.
An actual-page diagnostic confirms 1,737 of the 1,777 pages remain unbacked
after recording, where the earlier path left none. Private compatibility
libraries exercise this protocol on an older executable through an unshipped
caller-identity shim; production passes the capability directly.

Completed production executable `590975bd…`, receipt
`20261103-102143-9974fe73`, contains all five graphics changes and again passes
all thirteen exact visual cases without reference or tolerance changes. Its
fresh twenty-second replay peaks at **681,282,296 B** and settles at
**275,662,888 B**, with unchanged identities, complete content and normal script
audits, and zero browser/guard exits. The maximum sampling gap is 58.15 ms.
These short observations establish neither a permanent bound nor an isolated
percentage improvement across evolving shared builds. A private GPU picture
and CPU-atlas prototype with the prefix change still peaks at **581,913,360 B**;
it remains unshipped and fails the requested limit.

A fresh five-minute stock-production observation of `c9ff98ac…` completes
with a **729,827,464 B** simultaneous observed peak and **329,418,840 B** final
two-second median. The separate sum of per-task kernel lifetime maxima is
**765,512,560 B**; it is an auxiliary envelope, not a simultaneous measurement.
The maximum sampling gap is 59.55 ms. Browser and guard exits are zero, all
runtime and fixture identities remain unchanged, and the normal author-script
and content audit passes. The document remains complete, visible and fully
active at 1708 × 953 and backing scale two, with 49 comments, two images, zero
native errors and the expected badge-fetch diagnostic. Host load at launch is
3.67/3.81/3.99 on 18 CPUs, with a shared production compiler active. This
supersedes the earlier stock five-minute observation for the pinned leaf build;
it predates the later opacity commits. Memory continues to rise during idle.
Startup and longer browsing therefore still need investigation.

Separate retained-allocation diagnostics use an O0, non-inlined executable
generated from a completed canonical compiler input. The allocation hook
samples base storage and the currently entered main-thread document arena,
excluding resettable workspaces. The flat diagnostic executable uses the
self-executable filter-worker fallback rather than the app-path helper.
These runs supply allocation attribution, not performance or cap acceptance.
The idle trace samples **10.8 MB** over approximately fifty seconds after its
trigger; the startup trace samples **158.5 MB** through its twenty-second
observation and final audit. Layout reconstruction, paint templates, HTTP
buffering, selector probes and invalidation graphs appear in those stacks.
The final audit can itself request layout, so the aggregate is not a pure idle
allocation rate. The existing five-minute stock trace has approximately 9 MB
steps around thirty seconds and then every minute, alongside smaller growth.
It does not establish bounded long-term allocation.

The [graphics receipt](benchmark-results/reddit-comment-memory-2026-11-03-graphics.json)
records exact identities, commands, actual exits, host contention, sampled
observations, separate kernel lifetime envelopes and artifact hashes. Raw
account-bearing fixtures, logs and page captures stay private under
`Build/reddit-comment-memory-20261103-graphics/`. No browser bundle, source tree
or repository tool is copied.

## Selector probes and initial viewport

Commit `a6d7fdf17` retires temporary work in general DOM selector queries,
static user-style subject matching and stylesheet anchor checks. Parsed
selectors retain their document ownership; each synchronous probe publishes
only its boolean. Relational matching contexts, one-shot `:has()` memoization
and converted invalidation-property vectors now use disposable storage.
Five hundred and twelve repeated general matches retain **0 B** versus
**57,356 B** for direct unscoped matching. Two new focused cases pass in
prealloc, fully poisoned prealloc and Boehm configurations. Sixty-one cases
also pass together with full arena poisoning, covering live relational reads,
query scope, user-style changes, stylesheet invalidation and shared `:has()`
cache behavior. Initial separate-file attempts fail because of the compiler's
native bridge and omitted cross-file fixtures; the successful matrix uses
explicit Clang and the canonical test files through `-file-list`.

Completed executable `eb67ec4b…`, receipt `20261103-104416-7d5f3c3f`, contains
the three new workspaces in its frozen input. A twenty-second stock replay
observes **671,304,440 B** peak and **262,588,408 B** final median. Identities
remain unchanged, normal author-script/content audits pass, and browser/guard
exits are zero. Shared changes between builds prevent attributing a percentage
to this component fix. A separate 65-second diagnostic still observes genuine
timestamp-text changes requiring layout; later equal-text updates reuse seven
replacements. The continued memory steps do not establish bounded allocation.

Commit `1942d8358` resolves the initial viewport after bookmark preferences
load. The old startup value subtracts only 84 pixels of chrome, while a visible
bookmark bar requires 112: navigation initially lays out at 1708 × 981, then
the first frame rebuilds at 1708 × 953. The new ordering starts at the final
viewport. Four cases pass with full arena poisoning, including the two
existing scripted viewport tests, bookmark/debug visibility, explicit screenshot
height, very small windows and unchanged layout generation at the first native
frame. A separate 256-section allocation fixture performs two alternating
control/candidate pairs under full arena poisoning: the old two-pass startup
retains 17,827,331 / 17,813,465 B, versus 9,840,870 / 9,850,495 B for one pass.
These are component allocations, not browser RAM percentages. Existing viewport
tests are preserved in their original file. The
initial compile attempt lacked the prepared UI2 module path; the successful
check uses the same canonical prepared UI2 adapter as production.

Further private experiments remain unshipped. The first cropping and tiling
probes incorrectly follow a symlink when the driver chooses the dynamic-library
directory; dyld logs show the prior helper. Their receipts retain this
attribution error and grant no candidate validation or savings credit. New
wrappers select the actual candidate file. The corrected diagnostic records
95 picture-region calls, all smaller than the proposed 1024-pixel tile size;
its observed peak is **567,446,312 B** and still fails the cap. The multi-tile
path therefore supplies no workload benefit or correctness claim. Replacing
the CPU prototype's native shape fallback with Skia raster shapes leaves the
same 64 rounded-border differences; the capture logs only picture calls, so
that experiment does not support the CoreGraphics-fallback hypothesis. The
CPU rendering policy remains unchanged.

An external cleanup removes the older private rendering-artifact directory
during this work. The observation wrapper is restored byte-for-byte and matches
its previously pinned SHA-256 before further use. Deleted historical raw
artifacts are not reconstructed or assigned new validation credit; published
receipts and the current graphics evidence remain available.

The cleanup later removes the original archive and base private driver too.
All 24 response bodies served in the preceding valid 65-second observation
survive in that run's browser cache and match their recorded replay SHA-256s.
A new sealed fixture recovers this previously served subset, its 23 resource
header sets and the main-frame Content-Type fallback used by canonical
`--from-cache` capture. Its manifest differs from the deleted archive; it is a
new pinned cohort, with no cross-fixture causal percentage or full original
header-envelope equivalence claim. A new private observation driver uses the
canonical replay server, physical-memory sampler and identity helpers directly.
It verifies all body hashes, original URL/title, complete/visible/fully-active
state, 1708 × 953 viewport, 49 comments, two images, zero native errors and the
same expected badge-fetch diagnostic.

Completed production executable `406aaa0e…`, receipt
`20261103-110455-30b1ed31`, contains the initial-viewport call and selector
workspaces in its frozen compiler input. A fresh twenty-second run of the
recovered fixture observes **661,572,368 B** peak and **239,831,104 B** final
two-second median. The separate sum of per-task kernel lifetime peaks is
**667,110,184 B**; the largest sampling gap is 55.67 ms. Identities remain
unchanged, the content/script audit passes, and browser/guard exits are zero.
The new cohort does not independently sample display backing scale: an initial
raw annotation inferred it from the PNG/requested-width ratio, which only
records capture resolution. The receipt retains and corrects that annotation;
the memory observations are unchanged.
The private GPU override on the same executable still observes
**545,360,680 B** peak, **242,550,824 B** settled and a separate
**553,700,160 B** lifetime-peak envelope. It remains unshipped and fails the cap.
These short observations do not establish bounded long-term allocation.

All twelve surviving canonical SVG mutation, image-source, paint-server
ID-collision and rounded-border cases are pixel-exact on `406aaa0e…`, with
unchanged executable, tool, source and reference hashes. The former private
equal-native-input fixture is removed by the cleanup and is not silently
replaced or counted as a new pass. The canonical pixel-diff tool is rebuilt
from its repository source after its older binary is removed. No reference or
tolerance changes. A fresh direct live request again returns HTTP 403.
**The 500,000,000 B peak limit and live-site validation remain open.**

The [follow-up receipt](benchmark-results/reddit-comment-memory-2026-11-03-followup.json)
records the two fixes, focused checks, corrected experiment attribution, cache
recovery provenance, new observations and artifact hashes.

## Shared element accessors and production follow-up

Commit `a1cc0600e` shares the getters and setters for fifteen compact element
properties across a JavaScript realm. Each wrapper retains its own descriptor;
protected WeakMap records select the actual receiver. Captured, bound WeakMap
intrinsics avoid creating an argument array for each property read. Legacy
facade records remain separate from the Element brand. Borrowed accessors use
their registered receiver, reject forged receivers before value conversion,
and preserve conversion exceptions and native DOM/control writes.

Separate instrumented page probes retain 2,644 state records and 2,643 wrapper
objects while distinct own `id` getters change from **2,639 to one**. Those
probes use different pinned executables and establish the sharing mechanism,
not an attributed browser-memory percentage. Four new cases and nineteen
existing content, parent, control, reflected-attribute, fragment, image and SVG
cases pass in both Boehm and preallocation modes; the latter runs with full
arena poisoning. Early fixture failures and a legacy-property negative control
remain in the private evidence. The control reproduces the pre-existing mixed
text/markup replay failure; the final tests use independent content owners and
explicit element lookup.

Frozen compiler input for production `98dfbb7c…`, receipt
`20261103-120605-b5e5859e`, contains the final bound-intrinsic implementation.
All twelve canonical image-source, SVG mutation, paint-server ID-collision and
rounded-border comparisons are pixel-exact, with unchanged inputs, references,
tolerances and runtime identity. Normal author-script replay also passes the
complete/visible/fully-active document, URL/title, 1708 × 953 viewport,
49-comment/two-image and native-error audits.

| Valid stock-production observation | Observed simultaneous peak (B) | Final two-second median (B) |
| --- | ---: | ---: |
| `98dfbb7c…`, 20 seconds | 639,863,520 | 236,554,232 |
| `0b745ee9…`, 65 seconds | 655,657,696 | 245,671,976 |

The corresponding auxiliary sums of observed per-task kernel lifetime peaks
are 662,850,296 B and 673,139,424 B. These are non-simultaneous envelopes for
observed tasks, not complete process-coverage bounds. Physical-footprint polling
can miss short spikes and helpers; the aggregate-RSS safety guard measures a
different metric. Capture and the endpoint audit follow the primary interval.
Backing scale is not independently sampled. Shared-checkout changes and host
contention prevent assigning cross-build RAM differences to this feature.

A 300-second attempt on `98dfbb7c…` records 651,200,576 B peak and
281,512,000 B endpoint but is **rejected**: the canonical executable changes to
`6d0d5725…` during observation. Browser exit zero does not restore its validity.
It supplies no new five-minute acceptance result or evidence of bounded idle
memory. Every attempt remains recorded.

Two alternating instrumented control/candidate pairs with count logging disabled
show no startup-peak improvement: controls peak at 641,927,904/643,484,480 B,
and candidates at 642,910,992/651,578,176 B. Their settled medians are roughly
237.6/237.8 MB and 236.4/236.9 MB. Launch load averages are approximately 51–62
on eighteen CPUs. Per-call native autorelease pools likewise establish no peak
gain. A private stock-renderer 8 MiB GPU-cache trial still peaks at 645,466,848 B.

Further private shared-Metal/CPU-upload trials retain 536,398,584 B peak with an
8 MiB context budget and 529,877,704 B with 64 MiB. Loaded-image observations
confirm the selected private libraries. An earlier 8 MiB attempt is rejected
after another executable replacement. This small diagnostic cohort supplies
neither acceptance nor smaller-cache optimization credit; the native upload
prototype and cache policy remain unshipped. A separate comparison of actual
page pictures finds differing CPU/GPU pixels in all 95 observations, including
repeated draws: 32–175 channels differ per comparison, with maximum channel
error 29. Only the original GPU output is published. This rules out treating the
CPU prototype as a pixel-preserving fix for the requested page.

A fresh direct live request returns HTTP 403. **The 500,000,000 B peak cap,
bounded longer-term memory and live-site validation remain open.** The
[accessor follow-up receipt](benchmark-results/reddit-comment-memory-2026-11-03-dom-wrappers.json)
pins the implementation, test exits, production identities, all accepted and
rejected observations, failed experiments and private artifact hashes. Raw page
bytes, screenshots and account-bearing logs remain private under
`Build/reddit-comment-memory-20261103-dom-wrappers/`.

## Reclaimable HTTP response accumulation

Commit `a32aa1aad` replaces the HTTP/1 receive loop's growing V byte accumulator
with request-local native storage. Reallocation frees old capacities, and the
final bytes enter the caller's builder once before the native buffer is freed.
Publication allocates the exact final capacity when necessary and preserves an
already sufficient caller buffer. Seeded content and partial bytes on an error
retain their previous behavior. Callbacks, errors, pooled connections and TLS
objects keep their ordinary owners; the network operation never enters a
temporary allocation arena.

An 8 MiB binary response with 4,093-byte input chunks retains **8,402,507 B**
instead of **33,550,744 B** with the former Builder accumulator, a **74.96%**
reduction in this focused allocation. Both outputs match every input byte. The
control covers accumulator growth with matching bytes and chunking, not the
complete former HTTP implementation or whole-browser physical memory.

Three new cases and nine upstream receive/framing cases pass in both Boehm and
preallocation modes, including chunked limits, compressed bodies, partial errors,
callback data and retained responses. The retention assertion runs in preallocation
mode. The same twelve cases pass AddressSanitizer with leak detection disabled;
five browser-network progress and filtering/redirect cases also pass under full
arena poisoning. Eight Python staging/patch tests pass. The current compiler
accepts a TAP selector without emitting TAP, so an intermediate verifier rejects
that run despite native exit zero. The final driver verifies all twelve calls in
retained generated C before executing each binary. Earlier fixture and verifier
failures remain recorded.

Completed production `d69e4a67…`, receipt `20261103-124638-4d084d66`, contains the
final publication code in its frozen input. A separate native allocation probe
records 52 buffer-growth calls, all within the validated
`VoxHTTPReceiveBuffer.write_ptr` symbol range, with largest requested capacity
1,048,576 B. It selects the actual Mach-O executable header rather than dyld
image zero. This proves execution on the replayed thread; its instrumented RAM
numbers supply no optimization credit.

A fresh, uninstrumented 65-second stock run observes **683,903,760 B** peak and
**248,580,136 B** final two-second median. The auxiliary sum of observed task
lifetime peaks is **691,981,096 B**. Input identities stay unchanged, browser and
guard exit zero, and the normal script/content audit passes: original URL/title,
complete/visible/fully-active state, 1708 × 953 viewport, 49 comments, two images,
zero native errors and the same expected badge-fetch diagnostic. All twelve
canonical visual comparisons are pixel-exact on this executable. This new peak
exceeds earlier observations; unrelated shared-checkout changes prevent a causal
cross-build comparison. No whole-page reduction is assigned to the buffer fix.
Polling remains a lower bound and no display backing scale or new five-minute
bound is established.

The compiler-root probe now passes the required `-memory-limit 10G` in separate
tooling commit `d2d677221`. Staged request/helper/header hashes remain identical
after that tooling change. A fresh direct live request still returns HTTP 403.
**The 500,000,000 B peak cap and bounded idle growth remain open.** The
[HTTP buffer receipt](benchmark-results/reddit-comment-memory-2026-11-03-http-buffer.json)
records exact component counts, registered tests and exits, sanitization,
production identities, path eligibility, failed attempts and private artifact
hashes under `Build/reddit-comment-memory-20261103-http-buffer/`.
