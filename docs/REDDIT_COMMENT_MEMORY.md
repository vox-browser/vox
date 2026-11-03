# Old Reddit comment-page memory

The requested limit is **500,000,000 bytes** for
`https://old.reddit.com/r/UkraineRussiaReport/comments/1xls5ou/ua_pov_ukraine_hits_10_of_russias_oil_refining/`.
The measured production bundles **exceed this limit**. The latest valid
five-minute observation settles at **338,348,192 B** and peaks at **750,554,016 B**.
The transport continuation below records its pinned build and focused checks.
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
