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

## Encoding startup and failed regression checkpoint

`39932d9a` exposes native TextEncoder, including encodeInto's complete-code-point
writes, through the existing encoding implementation and actual JavaScriptCore
typed-array storage. `9b4462ba` exposes TextDecoder's label lookup, streaming
decoder, fatal errors, BOM handling, and BufferSource conversion. Both bindings
preserve receiver brands, original conversion exceptions, captured intrinsics,
and retained storage across temporary allocation scopes. Shared fixed buffers
are supported; resizable and growable BufferSource storage remains rejected.

The three encoder cases and five decoder cases each passed with normal GC and
production `-prealloc -gc none`, including poisoned temporary arenas. Compiler
and runtime exits are zero and source manifests stayed unchanged. Receipts are
`Build/pikabu-story-encoder-tests/{normal,arena}-1.json` and
`Build/pikabu-story-decoder-tests/{normal,arena}-1.json`. The encompassing guard,
`Build/pikabu-story-resume-checks-3-job.json`, exited one because later checks
failed; it is not a passing broad checkpoint.

The production build and headless startup passed. Its preserved bundle is
`Build/pikabu-story-encoder-visual-1792985339052998000/Vox.app`, executable SHA-256
`4d030c8926b28de65a658a5ce10005a8f06c19cc8fafca9b8ecd22c962ebfbf7`.
The capture directory contains source manifests, native-library and Brave
identities, private profiles, audit snapshots, raw logs, and pixel verdicts.
Concurrent IndexedDB and canvas-test edits occurred during compilation, so
these observations do not isolate rendering changes to the encoding bindings.
Executable and library identities remained stable during capture.

At 1024 × 768, scale 1, after eight seconds, the archived Pikabu encoder and
decoder startup fixtures both report PASS and match Brave exactly. The jQuery
fixture also remains exact. Window messaging and BroadcastChannel fixtures
remain pending and fail their pixel comparisons. A native callback exception
is recorded for the channel fixture; absent compact-console diagnostics alone
does not establish successful callback execution. The bundled story still
fails strict pixel equality.

The screenshot-mode live navigation produced a Navigation error page and is
rejected: it has no live parity metric. A separate ordinary window successfully
loaded the requested Pikabu URL and title, was visible and fully active, and
remained interactive at the 20-second observation. Its compact console records
the randomized inline reference error, without the earlier missing TextEncoder
failure. This does not establish completed page initialization or live parity.

The 21-case screenshot checkpoint in
`Build/pikabu-story-broad-visual-1792985239506266000/` also failed. It used the
previous pinned channel bundle, explicit Serenity Sans, and unchanged inputs.
All ten SVG cases are pixel-exact. Four smoke cases fail: inline-node (14,944
pixels), ordered-list (4,900), text-decorations (29,823), and default-ignorable
code points (3,421). The actual inline-node capture selects a system face
instead of the configured layout-test font. The seven other smoke cases pass
their existing criteria, including canvas-text's upstream fuzzy bounds.
Font selection and the failed bridge checkpoint require repair and revalidation;
neither checkpoint resets the broad-check cadence. Whole-page parity remains
open.

## Explicit layout-test font selection

`bb4ae5c5` preserves an explicit `LADYBIRD_LAYOUT_TEST_FONT` when Chromium font
matching is active. Family availability and face selection use the configured
font, including its initial face index, instead of replacing it with a system
match. Ordinary Chromium font matching remains the default when no valid
override exists.

Seven focused font cases passed with normal GC and with `-prealloc -gc none`.
Both compilers and test processes exited zero, and the source manifest stayed
unchanged. The receipt is
`Build/pikabu-story-font-tests-1792993913172551000/results.json`; runtime
receipts are `normal-runtime.json` and `arena-runtime.json` beside it. The
compiler remains current V `1e63d0f`, with the SHA-256 recorded above.

This does not yet repair the failed screenshot checkpoint by evidence: its
21 captures still require a fresh production rerun. Subsequent local checks
also exposed fixture setup errors and a retraced-rectangle acceptance error
in the pending SVG-background candidate. The fourth combined attempt ended
with a memory-guard cleanup `PermissionError` and an empty guard report, so
its termination cause and aggregate memory peak are unestablished. It receives
no production-build, broad-test, or screenshot credit. Raw output remains in
`Build/pikabu-story-libjs-broad-job-4.log`. Whole-page pixel parity and the
broader regression checkpoint remain open.


## Startup callbacks, outlines, and the next production checkpoint

`de4decfd` gives the window, media-query and IndexedDB event-wrapper providers
separate owners, preserving each provider when the others are installed.
`b23c9c77` preserves IndexedDB clone failures as DOMExceptions and preserves
original exceptions from author getters. `95c4b43a` materializes the optional
FileList reference before projecting its field with current V. `0be72d3f`
requests a browser frame after asynchronous compact-document changes; requests
coalesce, late installation delivers pending work, and close releases the hook.
The 24-file, 76-case bridge selection passed in both normal and arena modes:
`Build/pikabu-story-bridge-regressions/{normal,arena}.json`. Both modes compiled
and executed successfully with unchanged source snapshots. Ordinary-window
and screenshot-mode callback observations also passed on the fresh pinned
production bundle; see
`Build/pikabu-story-async-observation-1792998509939372000/results.json`.

`b42d62a0` keeps the outline fixture's retained display-list lease alive while
replacing its scene. `b79bfc61` paints uniform solid Chromium rounded outlines
with the analytic stroke used for matching borders. Seven layout cases in four
files passed in normal and poisoned arena modes, with unchanged sources:
`Build/pikabu-story-outline-tests-1792997668924263000/results.json`.
The 12-box outline fixture is pixel-exact against Brave; its retained control
has 1,018 differing pixels (maximum channel error 66).

The combined production attempt completed with child exit 1 because the broad
screenshot checkpoint failed. Its default 12 GiB guard recorded a peak of
9,303,654,400 bytes and elapsed time of 1,160.698195 seconds:
`Build/pikabu-story-visual-job-10.json`. Build, signing, preservation, startup,
bridge checks and callback observations succeeded. The pinned executable is
`Build/pikabu-story-font-visual-1792997668532372000/Vox.app`, SHA-256
`3eecb47bb83dcb044ccb704c3603354f062b65e3d1931776058bf8ec84ec7f2c`.
Six native graphics source files changed in another workflow during the build;
this bundle is not isolated evidence attributing a production change to one fix.

The 21-case renderer checkpoint completed all captures in
`Build/pikabu-story-broad-visual-1792998420484769000/`. Three comparisons fail:
inline-node (5,766 differing pixels), ordered-list (4,421), and text-decorations
(31,985). Default-ignorable-code-points is now exact after the explicit font
selection fix. All ten SVG guards, the selection/caret cases and line-clamp are
exact; canvas-text passes its existing fuzzy limits. No tolerances were widened.
The broad checkpoint remains open.

Visual receipts are retained in
`Build/pikabu-story-callback-visual-1792998520697467000/`. The six startup
fixtures and shadow-precision fixture are exact. The bundled story has 16,820
differing pixels, including 72 with channel error above three; it remains
inexact. The pending rounded SVG-background optimization improves transparent
edges but introduces colored-backing fringes, so it has no acceptance credit.
A revised composition is undergoing separate validation.

Both live captures loaded the requested URL and Pikabu title. The live pages
differ by 513,517 pixels (65.2971% of the 1024 by 768 viewport). Their ad-blocking
policies differ: Vox hides the top banner. Vox also lacks the SVG sprite icons,
and both screenshot and ordinary-window diagnostics report missing
`IntersectionObserver` and `WebSocket` globals. Ordinary navigation reached
`complete`, remained visible and fully active, and loaded all three normal
Roboto weights. Successful navigation therefore does not establish successful
application initialization. Whole-page Brave parity remains open.

## Rounded SVG background composition

`9e41f1dc` composes the SVG and its deferred backing color in one native
layer before applying their common rounded boundary. Rectangular internal SVG
clips retain their actual geometry. Curved clips and other unsupported effects
continue through ordinary replay, including the deferred backing color.

All twelve supported panels in
`Tests/Browser/Brave/input/rounded-svg-background-coverage.html` are pixel-exact
against Brave: both 156px and 20px sizes, transparent/gray/red backing colors,
and unclipped/rectangularly clipped SVG content. The two curved-clip fallback
panels are byte-identical to the retained control. Their existing 624 differing
pixels against Brave remain unresolved. Focused SVG tests pass in both normal
and poisoned arena modes:
`Build/pikabu-story-svg-background-tests-1792999467415444000/results.json`.
The backing-color layout case also passed in the earlier seven-case layout
selection recorded above.

The new production bundle built, signed, and passed startup with unchanged
source manifests. Its executable SHA-256 is
`b0d794a2a61d4dfcbc48f7fee86a4a9c791252e5867430dd0ea0ee50d2d13d1b`,
retained at `Build/pikabu-story-svg-layer-visual-1792999466181563000/Vox.app`.
The outer guard completed with child exit zero, sampled peak RSS of
8,234,909,696 bytes and elapsed time 596.318709 seconds:
`Build/pikabu-story-visual-job-11.json`.

Visual evidence is in
`Build/pikabu-story-callback-visual-1792999753634106000/`. The six startup
fixtures, shadow precision and rounded outlines remain exact. The bundled story
has 16,814 differing pixels, including 70 with channel error above three;
maximum channel error falls from 49 to 42. The live comparison still differs
by 514,878 pixels and retains the missing API and policy differences described
above. The visual driver completed successfully while retaining those failed
pixel comparisons; its exit zero is not whole-page parity or a broad-check
cadence reset.


## Native observer startup bindings

`2dac6be3` exposes native `DOMRectReadOnly` geometry. `04241481` binds
`IntersectionObserver` to translated layout observations and asynchronous HTML
tasks, including native target identity, threshold conversion, callback exception
reporting, and runtime shutdown. Five focused cases pass in normal and poisoned
arena modes with unchanged sources:
`Build/pikabu-story-api-tests-1793000652259797000/results.json`.
Entry construction and visibility reporting retain the upstream implementation's
limits; this does not establish complete IntersectionObserver API parity.

The signed production bundle builds and passes headless startup. Its pinned
executable is `Build/pikabu-story-api-production-1793000650758526000/Vox.app`,
SHA-256 `36f04911d3237a4ac8d6cbae08a5e7e282c8bcc4bc5a3a86382cf110febe29de`.
The compiler is current V `1e63d0f`, executable SHA-256
`dfd0ac6c17cd0c10e804be6720f363c13fe242bdaba5d4315f1a6961c06ce607`.
Twelve files changed in independent workflows during production compilation;
the recorded source manifest prevents attributing this whole bundle to one fix.
The combined guard exits 1, with sampled peak RSS 7,771,635,712 bytes:
`Build/pikabu-story-api-job-2.json`. Its first observer fixture incorrectly
required identical JavaScript objects from repeated `boundingClientRect` reads;
Brave rejects that assertion. The fixture now tests geometry and interface
identity without imposing that unsupported object-identity requirement.

The corrected fixture passes in fresh screenshot and ordinary Vox processes,
with no JavaScript diagnostics or reported native exceptions, and is pixel-exact
against fresh Brave at 1024 by 768. All binary, library, Brave and fixture hashes
remain unchanged. The separate guard exits 0 (sampled peak RSS 966,656,000 bytes):
`Build/pikabu-story-api-job-3.json`. Commands, hashes and zero-difference pixels
are retained in
`Build/pikabu-story-intersection-acceptance-1793001659029448000/results.json`.
All ten SVG regressions also remain exact:
`Build/pikabu-story-svg-regression-1793001437213226000/results.json`.

Live evidence in `Build/pikabu-story-callback-visual-1793001076203847000/`
shows 971 SVG symbols and 103 uses after the observer binding. Both native
capture modes load the requested story and title; application startup next
reports missing `queueMicrotask`. A separate third-party script still reports
missing `WebSocket`. The six earlier startup fixtures, shadow precision, and
rounded outlines remain exact. The live page still differs from Brave by
514,771 pixels (65.4565%); whole-page parity and the earlier three failing
broad screenshot cases remain open. No comparison limits or broad-check
cadence were reset.

## Native microtask startup binding

`1d26bec0` binds `queueMicrotask` to JavaScriptCore's native job queue, using
private captured Promise intrinsics. It preserves callback order, reports thrown
exceptions, ignores returned thenables, and releases rooted callbacks at runtime
shutdown. Five focused microtask cases plus six related callback cases pass in
normal and poisoned arena modes, with unchanged sources:
`Build/pikabu-story-microtask-tests-1793002303020416000/results.json`.

The production build, signing and headless startup pass with unchanged source
manifests. The retained bundle is
`Build/pikabu-story-microtask-production-1793003067169331000/Vox.app`, executable
SHA-256 `a69af7b6fd0be2c138148b0ed3f5d0737d6a261df5f35505e17cc2fbbaea187a`.
Fresh screenshot and ordinary-window processes both pass the microtask fixture
without JavaScript diagnostics or native exceptions; the screenshot is exact
against fresh Brave at 1024 by 768, scale one. Binary, library, Brave and fixture
identities remain stable:
`Build/pikabu-story-microtask-acceptance-1793003324291640000/results.json`.
All ten SVG regressions remain exact:
`Build/pikabu-story-svg-regression-1793003787670194000/results.json`.

The visual checkpoint retains eight exact startup fixtures, exact shadow
precision and rounded outlines. The bundled story remains at 16,814 differing
pixels, including 70 with channel error above three, maximum error 42. Live
navigation in both native modes reaches the requested story and title, but
application startup now reports missing `ResizeObserver`. The live comparison
still differs by 514,794 pixels (65.4594%); policy differences and whole-page
parity remain open. Evidence is in
`Build/pikabu-story-microtask-visual-1793003359268327000/`.

Both attempts at the additional mask-isolation diagnostic crash during shutdown
with exit 139 after writing their images. Those images have diagnostic value
only. The visual driver's exit zero omits this diagnostic from its acceptance
gate; it does not make the entire checkpoint successful. The outer guard also
exits zero, sampled peak RSS 7,651,819,520 bytes, elapsed 767.823791417 seconds:
`Build/pikabu-story-microtask-job-3.json`. The mask crash and prior three broad
screenshot failures remain open; no bounds or verification cadence were reset.
