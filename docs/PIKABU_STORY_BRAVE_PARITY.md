# Pikabu story rendering against Brave

Target: https://pikabu.ru/story/otvet_na_post_novyie_blokirovki_youtube_ot_mts_vpn_zapret_14457095

The requested whole-page pixel parity is **not complete**. Comparisons below use
1024 × 768 document pixels at scale 1, excluding browser chrome. The retained
Brave DOM archive bundles assets to separate rendering errors from changing
votes, timestamps, advertisements, and network responses.

## Retained rendering checkpoint

The signed native build at `fc9239f4` has SHA-256
`3d88f22ce3ce5d389978c445850cb06956fcc330ce624dfe1ac59835b1c5d314`.
`Build/pikabu-story-updated.metadata.json` records startup and capture exits.
The guarded production run is `Build/pikabu-story-postmessage-core-job.json`.

- Shadow fixture: 0 differing pixels out of 786,432.
- Bundled story: 24,750 differing pixels (3.1471%), down from 30,595.
  268 pixels exceed three channel levels; maximum channel error is 51.
  Mean absolute error is approximately 0.0224 and RMSE approximately 0.3005.
- The title region and visible photograph are pixel-exact.
- Header, title, badge, text, and photograph rectangles match Brave. The story
  header begins at (101, 281); its content begins at (101, 428), and the image
  begins at (101, 679).
- Remaining retained differences include shadow/compositing rounding, the logo,
  and the cookie notice. No comparison tolerance was changed.

Images and audit files are `Build/pikabu-story-updated-{shadow,bundled,title,live}`;
reference images are `Build/pikabu-story-shadow-brave.png` and
`Build/pikabu-story-brave-bundled.png`. Pixel reports and amplified differences
are retained beside the captures.

## Live startup

The same live capture still reports missing IndexedDB, PerformanceObserver, and
WebSocket interfaces, plus a separate randomized script reference error.
The advertisement reservation and cookie notice do not initialize, moving the
story 200 pixels above the retained Brave layout. The archived page contains no
script elements, so its empty diagnostics cannot establish successful live
initialization.

The IndexedDB binding at `106cb5bb` connects JavaScriptCore to the owning
Window's existing typed factory and database-access task source. It supplies
open/upgrade/delete coordination, real request and transaction event delivery,
store creation, transactions, and asynchronous get/put/add operations. Values
are cloned at call time and request errors can roll back transactions.

This is a bounded browser API slice, not full IndexedDB parity. The existing
catalog remains in memory. The binding does not expose cursor/index operations,
complete request event bubbling, quota, disk persistence, or arbitrary structured
clone graphs. Its current value adapter accepts finite trees of plain objects,
dense arrays, primitive values, dates, and ArrayBuffers; unsupported records fail
with DataCloneError rather than being stored as JSON.

Six new asynchronous core cases and ten existing store/transaction/factory cases
passed with normal GC. Five browser binding cases passed with normal GC and
with the production arena allocator (`-prealloc -gc none`). The guarded report
is `Build/pikabu-story-idb-core-job.json`; its sampled process-tree peak was
3,194,159,104 bytes and child exit was zero. A fresh production capture is pending.

The PerformanceObserver binding at `7d9d986a` connects each observer to its
owning Window's native performance timeline. It supports observation by type
or entry-type list, buffered entries, queued callback delivery, disconnect,
takeRecords, and sorted entry-list queries. Resource observers continue to
receive new entries when the primary resource timing buffer is full. The
callback runs through the owning document's task and script settings.

Five timeline, three entry-list, two native-global, four existing-global, and
four resource-timing cases passed. Three JavaScriptCore binding cases passed
with normal GC and again with `-prealloc -gc none`. Individual exit codes and
log paths are in `Build/pikabu-story-observer-stages.json`; the retained first
binding attempt failed before the successful retry. The later root paint-test
compile hit a mixed-vlib HTTP error; `3dd2d1cf` makes the chrome harness stage
the same compiler-compatible HTTP modules as production builds.

The observer exposes the base PerformanceEntry attributes. ResourceTiming's
additional attributes remain separate work.

The Performance global at `1ff39587` uses the owning Window's native clock,
time origin, entry buffers, and resource-buffer event target. Timeline queries
reuse the same entry wrappers as PerformanceObserver; clearing entries and
resizing the resource buffer update the native timeline. This slice does not
expose JavaScript mark/measure creation or legacy timing/navigation objects.

Three binding cases passed with normal GC and again with the production arena
allocator (`-prealloc -gc none`). They cover entry identity across observers and
queries, native clock bounds, receiver brands and conversion exceptions,
buffer mutation, and queued resource-buffer events with reentrant clearing.
The receipts are in `Build/pikabu-story-latest-v-stages.json`; the compiler is
current V `1e63d0f`, SHA-256
`dfd0ac6c17cd0c10e804be6720f363c13fe242bdaba5d4315f1a6961c06ce607`.

These passing binding tests do not establish successful live Pikabu startup.
Fresh production captures of the live URL and retained archive remain pending
under the shared build guard.

## Adjacent SVG fills and diagnostic capture

`f4e8f816` shares a raster pass between adjacent SVG gradient fills instead of
compositing every path through a separate coverage mask. `bcec0c16` does the
same for eligible solid fills with matching rectangular clips, including nested
SVG display lists. Both paths retain the existing fallback for incompatible
clips and effects. Three gradient-group tests and five solid-group tests passed;
receipts are in `Build/pikabu-story-latest-v-stages.json` and
`Build/pikabu-story-continued-stages.json`. The chained-drop-shadow native check
also passed four cases.

A later diagnostic capture is preserved in
`Build/pikabu-story-early-diagnostic/`, including the actual app bundle, per-file
hashes, fresh Brave references, source fixture hashes, audits, logs, strict pixel
verdicts, and region counts in `results.json`. Its executable SHA-256 is
`a7d1db2fbaa7ce869508a38235078ea69a29ea05abe7a362bb24b0956f89ae41`;
Brave is 156.1.98.60, executable SHA-256
`9d53e182ab59b7c430abea0233088cb452694b96843d62ccccbc6c0902b98fe5`.
This was an existing shared production bundle: its identity was verified before
and after capture, but it has no complete build-start source manifest. These
results are diagnostic evidence, not an isolated attribution to either fix.

All captures used a fresh private profile, 1024 × 768 document pixels at scale
1, and eight seconds of settling. Native and Brave processes exited zero.
Strict comparisons still fail except for the shadow-stack fixture:

| Input | Differing pixels | Pixels with channel error > 3 | Maximum channel error |
| --- | ---: | ---: | ---: |
| Shadow stack | 0 | 0 | 0 |
| Adjacent gradients | 408 | 0 | 1 |
| Adjacent clipped solids | 4,326 | 532 | 94 |
| Avatar fixture | 1,177 | 416 | 20 |
| Drop-shadow chain | 9,428 | 0 | 2 |
| Bundled story | 16,917 | 186 | 43 |
| Live story | 514,947 | 437,491 | 255 |

The bundled story differs at 2.1511% of viewport pixels. The masked avatar and
cookie notice retain larger errors; most remaining header-shadow differences
are one channel level. The title region has three differing pixels with a
maximum channel error of one. No pixels were excluded and no tolerance was
introduced into the pass criterion.

The live URL loads the intended Pikabu document but still fails script startup
at jQuery's `document.implementation.createHTMLDocument("")` probe. The native
DOM already implements this API; the compact JavaScript bridge does not yet
expose it in this captured build. Missing WebSocket and a randomized script
reference error also remain. An ordinary visible, fully active window with a
20-second observation records the same failure, so it is not specific to the
screenshot launch mode. The script-free archive cannot establish live parity.

## Detached HTML document bridge

`27793c48` makes the compact bridge expose the native
`document.implementation.createHTMLDocument()` operation. Detached documents
use their own native tree, fragment parser, selectors, title, and base URL.
Factories and live collections retain document ownership through adoption;
collection caches also distinguish documents with identical mutation counters.
The live `children` wrapper cache is excluded from mutation snapshots to avoid
recursive native queries while flushing an `innerHTML` update.

Five new regression cases and eighteen neighboring compact DOM cases passed
with normal GC and with the production allocator (`-prealloc -gc none`). Each
run also executed Pikabu's archived jQuery 3.6.3 module and its startup validator:
both forms parsed, relative URLs resolved against the detached base, and a node
was adopted into the displayed document. All 24 cases passed in each mode,
without source changes during either check. Exact compiler inputs, source
hashes, and runtime exits are retained in
`Build/pikabu-story-document-tests/normal-8.json` and `arena-1.json`;
the console logs are
`Build/pikabu-story-document-binding-v1-continued-8.log` and
`Build/pikabu-story-document-binding-arena-v1-continued-1.log`.

This is a bounded compact bridge slice, not complete Document or
DOMImplementation conformance. Passing the archived vendor module does not
establish successful live page initialization or whole-page pixel parity.

The subsequent native capture does run that archived jQuery startup fixture
successfully and matches Brave exactly. The fresh production executable has
SHA-256 `dd79a7f37a79bd5b32459e07dce644f31716fe2b0a67e9397c76bfdd183aa7e6`;
`Build/pikabu-story-idb.metadata.json` records the source manifest, compiler,
native libraries, profiles, and capture exits. Its bundle is retained at
`Build/pikabu-story-document-verified.app`. A concurrent edit to
`native_rounded_single_border.h` occurred during this build, so rendering
differences cannot be attributed to the document bridge alone. The executable,
native libraries, and Brave identity remained stable throughout the captures.

All ten SVG regression comparisons in that run are pixel-exact. At 1024 × 768
and scale 1, the bundled story still has 16,934 differing pixels (199 with
channel error above 3, maximum 43). The intended live document loads in both
browsers, but has 514,959 differing pixels. An ordinary visible, fully active
20-second observation confirms that the jQuery failure is gone and startup
now fails at a missing `MessageChannel` in Pikabu's BroadcastChannel polyfill.
Missing WebSocket and the randomized inline reference error remain. Brave's
passive exception log contains network/CORS failures but neither missing API
exception. No live parity is established.

The bundled page also fails strict comparisons at verified scroll positions
512, 1024, and 1536: respectively 17,736, 104,299, and 74,110 differing pixels.
These are screenshot checks, not scrolling performance measurements. Raw
captures, identity records, exits, and pixel metrics use the
`Build/pikabu-story-idb-` prefix; the outer check is
`Build/pikabu-story-document-and-visual-retry-9-20261026.json`.

## Native message channels and Window event targets

`32736ea4` fires posted Window message events with the Window itself as the
target. It retains the separate legacy Document target override used by
Window's virtual dispatch path. Native assertions check the retained event's
target and cleared currentTarget; the JavaScript regression checks the actual
Window wrapper. Standalone HTTPS test documents now explicitly install their
URL origins, matching navigation-created documents rather than relying on the
constructor's default opaque origin.

`6c315f1d` exposes MessageChannel and MessagePort in browser JavaScript through
the existing native channel entanglement, port queues, structured serializer,
posted-message task source, EventTarget, and MessageEvent. The binding covers
clone-at-send-time delivery, queue activation, onmessage handlers, start/close,
receiver brands, interface identity, argument conversion, and runtime shutdown.
Retained ports, queued records and delivered event data allocate outside
caller/task scratch regions. The existing process port registry still retains
closed native ports; this slice does not add port garbage collection.

Nonempty transfer lists explicitly fail with DataCloneError: JavaScript
transferable projection and nonempty MessageEvent.ports are not implemented.
The existing native transfer model remains unchanged. This is not complete
MessagePort or BroadcastChannel conformance.

Five new binding cases, two existing Window message cases, and the actual
archived Pikabu BroadcastChannel module 89800 passed in each allocation mode:
normal GC and production `-prealloc -gc none`. The poisoned arena run includes
sending and delivering from separate temporary allocation regions, then reading
retained non-ASCII event data after collection. The eight-case receipts are
`Build/pikabu-story-channel-tests/normal-4.json` and `arena-1.json`;
outer guards are `Build/pikabu-story-channel-normal-job-5.json` and
`Build/pikabu-story-channel-arena-job-1.json`. Their source manifests remained
unchanged during validation.

All sixteen native cases from `html/window_post_message_test.v` and
`html/messaging_test.v` also passed in both modes. Receipts are
`Build/pikabu-story-native-message-tests/normal-2.json` and `arena-1.json`,
with the outer actual-zero receipt at
`Build/pikabu-story-native-message-both-job-3.json`. The first staged native
attempt failed before tests because its embedded stylesheet was missing; the
preserved runtime retry then exposed the opaque-origin fixture assumptions.
Neither failed attempt receives pass credit. The staged resource and fixture
repairs preserve the tested behavior and original origin assertions.

The Pikabu parity sequence now contains ten completed behavioral slices:
Window messaging (`fc9239f4`), IndexedDB (`106cb5bb`), PerformanceObserver
(`7d9d986a`), empty observer-array ownership (`8453ff2a`), Performance
(`1ff39587`), adjacent SVG gradients (`f4e8f816`), adjacent solid fills
(`bcec0c16`), detached HTML documents (`27793c48`), posted-message targets
(`32736ea4`), and native channel bindings (`6c315f1d`). A broader regression
checkpoint is pending under the ten-fix cadence; no cadence reset or unrelated
workflow's broad credit is claimed. Fresh production startup and live pixel
comparisons are queued. Whole-page parity remains open.
