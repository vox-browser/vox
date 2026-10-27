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


## Native ResizeObserver startup binding

The native ResizeObserver bridge is committed in `ec3dd1cc`; its implementation
status and limits are documented in `63c999c2`. The bridge connects JavaScript
observers to committed native layout metrics and the existing rendering-update
observer delivery. It exposes read-only entries, frozen box-size arrays,
argument and receiver validation, callback exception reporting, and runtime
shutdown. Observations and retained snapshots allocate in document storage so
callback/task scratch reclamation cannot invalidate them. The compact DOM is
flushed before observing a target.

Four JavaScript binding cases and five related native/geometry cases pass in
both normal and poisoned arena modes. Eleven core observer cases also pass in
each mode. Compile and runtime exits for all four selections are zero:
`Build/pikabu-story-resize-tests-1793018008591901000/results.json`.
The enclosing source-manifest gate exits one because an independent workflow
changed `html/message_port.v` during the check. No ResizeObserver source changed.
The guard records sampled peak RSS 7,537,197,056 bytes and elapsed time
457.878 seconds in `Build/pikabu-pixel-20261026/focused-guard.json`.

This slice retains the translated upstream device-pixel box calculation and
physical width/height behavior; it does not establish complete ResizeObserver
conformance. JavaScript entry/size wrappers stay rooted until runtime shutdown.
The browser fixture is
`Tests/Browser/Brave/input/resize-observer-startup.html`; a fresh production
comparison is required before crediting it with successful live page startup.

A pinned pre-change bundle still renders the bundled archive with 16,814
changed pixels out of 786,432, including 70 with a channel error above three;
maximum error is 42. The larger errors cluster at avatar and icon edges.
The fresh live baseline loaded a native navigation-error page, so its pixel
comparison is invalid and excluded from acceptance. Raw evidence and the
explicit invalidation are in `Build/pikabu-pixel-20261026/baseline/`.

The first two production attempts fail before launch in independently edited
page-switch code; the first also reports the subsequently corrected favicon
compile error. Their actual nonzero exits are retained in
`Build/pikabu-pixel-20261026/production-guard.json` and
`Build/pikabu-pixel-20261026/production-guard-2.json`. The third queued attempt
was interrupted before acquiring the shared guard. The fourth attempt exits 1
during focused-test compilation: select-control code assigns four immutable
rectangle fields. Constructing a replacement rectangle corrects that compile
blocker, but the failed attempt executes no mask tests or browser acceptance
checks. Its guard records sampled peak RSS 1,698,807,808 bytes and elapsed time
267.398 seconds in `Build/pikabu-pixel-20261026/production-guard-4.json`.

The fifth attempt is queued with
`Build/pikabu-pixel-20261026/production-guard-5.json`. Pending mask tests cover
linear/radial gradients, preservation of opaque and transparent mask groups,
cache identity, and SVG image-document lifetime during temporary paint work.
The prepared visual checks include rounded-mask isolation and full-viewport
circles at both integral and fractional origins. These changes have no runtime
or pixel-conformance credit until the commands execute. Whole-page parity,
the prior three broad screenshot failures, and the mask diagnostic shutdown
crash remain open.

## Legacy radial gradients and the next live startup blocker

Commit `3acf4371` parses the legacy `-webkit-radial-gradient` grammar used by
Pikabu's avatar masks, including its repeating variant. The translated value
retains the legacy prefix, shape and extent through absolutization and
serialization. The exact Pikabu declaration now has Brave's serialized value.
This does not establish general CSSOM serialization parity: explicit center
positions and double-position stops still serialize differently.

Twelve focused parser, prefix and interpolation tests pass in normal and
poisoned arena modes, with compile and runtime exits zero and unchanged tested
sources. Evidence is in
`Build/pikabu-story-webkit-radial-tests-1793031584344259000/results.json`.
The corresponding accepted/rejected syntax and serialization probe from Brave
is `Build/pikabu-story-webkit-brave/parser.json`.

Production attempt seven builds, signs and passes headless startup. The pinned
executable SHA-256 is
`3dfe0d02d85f97f7ca93ca71e58572f1072ace6c189142e2934079d75fcb59a0`;
the bundle and native-library identities, commands and actual exits are under
`Build/pikabu-story-resize-production-1793030624127672000/`. Both browsers load
the requested live URL and story title at 1024 by 768 CSS pixels, scale one.
ResizeObserver startup succeeds; the next application exception is
`t.content.cloneNode is not a function`. The live screenshot differs from Brave
at 482,730 of 786,432 pixels (61.3823%). The header offset, missing blurred
photograph backdrop and missing cookie notice remain visibly different.
Whole-page parity is open.

The photograph itself has the same 625.796875 by 533 CSS-pixel image box in
both browsers. Brave also creates a `canvas.pkb-blured-image-bg` behind it,
with the same displayed dimensions; the native document has no such canvas.
The site's `object-fit: contain` image and separate `object-fit: cover` backdrop
therefore account for the apparent width difference without establishing an
image-sizing defect. Evidence is in the production attempt's
`comparison/live.audit.json` and `comparison/live-brave.rects.json`, with the
page stylesheet saved as `Build/pikabu-pixel-20261026/live-style.css`.

The candidate and baseline native captures of the bundled archive are exactly
equal. Against the baseline Brave reference, the candidate retains the prior
16,814 differing pixels, maximum channel error 42, including 70 pixels above
three. The fresh Brave reference instead contains a gray avatar placeholder;
that image-state difference increases the comparison to 17,098 changed pixels,
maximum error 194. It is not evidence of a native mask regression. Future
captures must verify visible image readiness before recording a reference.

The outer guard exits one, with sampled peak RSS 9,409,052,672 bytes and elapsed
time 1,108.682 seconds:
`Build/pikabu-pixel-20261026/production-guard-7.json`. Gradient-mask visual
checks and the existing three broad screenshot cases still fail. Ten SVG
mutation regression cases and the ResizeObserver browser acceptance fixture
pass. Independently edited sources also changed during the build, so the
whole-checkout source-stability gate fails. Mask tests pass separately, but
their implementation remains uncommitted while the mask-isolation shutdown
crash and pixel differences are investigated. No failed acceptance gate is
relaxed.

## Template fragments, image dimensions, and SVG mask storage

Three additional focused fixes are committed on master:

- `c57ea93c` exposes the native inert fragment through the read-only,
  receiver-checked `HTMLTemplateElement.content` getter. Cloning, insertion,
  nested template contents, selectors, serialization, and saved live child
  collections now use the fragment's actual owner instead of the unrelated
  reflected `content` string attribute.
- `2bca669c` reads HTML image width and height from the native image IDL
  algorithms. CSS content dimensions exclude padding, borders and transforms;
  detached or hidden images retain their attribute fallback. Canvas defaults
  remain 300 by 150. Pikabu uses these values when creating photograph backdrops.
- `310e8e4b` allocates an SVG mask image's retained layout inside that image
  document's storage, then restores the host paint workspace for collecting
  temporary commands. Previously the layout handle could point into a released
  workspace and crash during retirement.

The frozen snapshot in
`Build/pikabu-template-tests-1793046874641855000/results.json` passes all 30
selected bridge/mask tests in normal and poisoned arena modes, plus all 13
selected layout tests in poisoned arena mode. Every compile and runtime exit is
zero; no test is omitted and no frozen input changes. Two unrelated live
prefetch files changed during validation, so the production check builds the
unchanged frozen inputs. These are three completed fixes for the next broad
regression checkpoint; this focused run does not reset the broad-test cadence.

The first production wrapper stops before compilation because its V-library
path is absent. Its nonzero build/guard exits remain recorded in
`Build/pikabu-story-template-production-1793047663883957000/` and
`Build/pikabu-pixel-20261026/template-job-guard-7.json`. This failure executes no
browser acceptance checks. A corrected wrapper compiles the frozen production source successfully, then
fails bundle signing because an old `.Vox.v3cc.*` compiler directory remains
inside the shared bundle. That actual build/guard exit is one, sampled peak RSS
is 10,555,916,288 bytes, and elapsed time is 1,070.573 seconds:
`Build/pikabu-pixel-20261026/template-production-guard-8.json`. No browser check
runs in this failed attempt.

The compiled executable and all three libraries are copied into
`Build/pikabu-story-template-production-1793048177500118000/Vox.app` with
hashes verified before and after copying. The preserved bundle manifest is
`preserved-compiled-bundle.json` beside it. A separate guarded continuation
removes only compiler scratch directories from that copy, signs and verifies
it, and runs the pending browser checks. It reuses the passing frozen tests
and compilation. This continuation has completed:
`Build/pikabu-pixel-20261026/template-production-guard-9.json` records exit one,
494.925 seconds, and sampled peak RSS 5,652,824,064 bytes. All frozen source,
executable, and library identity checks pass. The signed executable SHA-256 is
`a1167c7abc73b8b0ac45f1d3eb0f5ace4f1b44375df75dff3108af46f0de2123`.

The headless smoke check, both poisoned/unpoisoned SVG ownership browser
checks, and all ten SVG mutation regressions pass. The template fixture passes
in fresh ordinary and screenshot processes, with complete, fully active
documents and no JavaScript errors; its Brave comparison is pixel-exact.
Results are in `Build/pikabu-story-template-acceptance-1793051891784472000/`.

The image-dimension browser fixture exposes a remaining compatibility mistake:
Brave rounds fractional rendered content sizes, while the translated native
image getter truncates them. The fixture previously expected truncation and
therefore passed only in Vox. Its Brave title reports failure; the 8,844 changed
pixels are a failed acceptance result. Commit `61f75650` corrects the bridge
and fixture to round rendered content dimensions, including fractional sizes,
border-box subtraction, transforms, detached fallback, and document scale.
Both focused tests compile and execute successfully in normal and poisoned
arena modes, with unchanged frozen inputs:
`Build/pikabu-image-rounding-tests-1793052535602480000/results.json`.
This is the fourth completed fix since the preceding broad checkpoint. Browser
acceptance still needs a bundle containing the correction; the older bundle's
failed comparison supplies no conformance credit for it.

The four gradient/mask fixtures load and exit successfully but still fail exact
pixel comparison. Small rounded masks have 56 changed pixels per case; large
rounded SVG backgrounds inside masks have 488. The main remaining differences
are rounded-edge rasterization. Their raw results remain in
`Build/pikabu-gradient-mask-visual-1793051849540162000/`.

The live requested URL and bundled archive both load and exit successfully at
1024 by 768, scale one. The bundled archive has 17,953 differing pixels (2.2828%),
maximum channel error 42, with 70 pixels above three. The live page has 514,689
differing pixels (65.4461%), maximum error 255. Brave displays a 200px advertising
reservation, a cookie notice, and a Yandex sign-in panel; Vox lacks those live
startup changes. The template clone error is gone. The next observed startup
failure is an unhandled `ReferenceError` for `FormData` in the site's request
option preparation. URL-based canvas SVG filters are also still absent in this
binary. These failures motivate the next focused fixes; neither live parity nor
canvas-filter correctness is established by this run. Commands, captures,
audits, pixel metrics, and actual exits are in the preserved bundle directory's
`resume-results.json` and `comparison/`.

The mask effect-scope correction and native gradient-raster changes remain
uncommitted pending their visual checks. Whole-page pixel parity and the
previously recorded broad screenshot failures remain open.

## Header filtering diagnostic

`Build/pikabu-header-policy-1793059785375573000/results.json` isolates the
advertising reservation in the same frozen Brave document at 1024 by 768,
scale one. Applying the repository's three cosmetic rules for
`.ads-placeholder`, `.external_branding`, and `div[id^="adfox_"]` changes the
header's measured height from 264px to 64px. The browser, document, and filter
list hashes stay unchanged; the diagnostic exits zero. Before and after
screenshots and the exact rules are retained beside the result.

This demonstrates a 200px shift caused by filtering policy in the earlier
comparison. It does not validate the complete uBlock policy or establish live
page parity. The pending FormData, canvas-filter, and mask corrections still
need focused and production-browser validation before receiving conformance
credit.

## Canvas filters and startup validation checkpoint

Commit `c63fad6b` resolves same-document SVG filter URLs for canvas drawing
through the existing live SVG filter graph. The focused selection contains six
new cases and eighteen existing canvas cases. All 24 pass in normal and
poisoned arena modes, with zero compile and runtime exits and unchanged frozen
inputs: `Build/pikabu-canvas-svg-tests-1793060230273941000/results.json`.
This is the fifth completed fix since the preceding broad checkpoint. Browser
acceptance still needs an executable containing the change.

Startup validation attempt 13 exits one after 865.915 seconds, with sampled
peak RSS 7,405,092,864 bytes under the 12 GiB guard. Its four step exits are
`[1, 0, 1, 1]`; no production browser is built or launched. The initial FormData
compile lacks a browserjs header. After repairing the frozen harness's header
links, compilation succeeds, but its normal runtime times out after 180 seconds
and is killed. Arena validation has not run. The failure and repair evidence
remain in `Build/pikabu-form-data-tests-1793054934823159000/`; this is not a
passing FormData result.

The native rounded-mask experiment is pixel-exact at scale one. Scale two has
four differing pixels, each with maximum channel error one, including one in
the unmasked control. The strict zero-difference gate remains failed; native
execution does not establish browser eligibility. Results and unchanged source
and library identities are retained in
`Build/pikabu-rounded-mask-tests-1793060230273941000/results.json`.

The full-filter Brave capture fails before launch because the extension path
pinned by its prepared profile no longer exists. The newly installed extension
has a different content hash, so its bytes cannot replace the old validated
input. A separate immutable extension copy and fresh profile preparation are
queued. Existing captures and hashes remain intact. Live story parity,
FormData startup, canvas browser acceptance, and the rounded-mask gate remain
open.


## FormData completion and image negotiation checkpoint

Commit `875ade4e` implements native FormData bindings and binary multipart
request bodies for Fetch and XMLHttpRequest. The startup fixture exercises the
page's constructor and form initialization path. The focused selection passes
all 15 cases in both normal and poisoned arena modes, with unchanged frozen
sources and binary identities. The final direct-network guard exits zero after
98.118 seconds. Results are retained in
`Build/pikabu-form-data-tests-1793054934823159000/results.json` and
`direct-guard.json`. The earlier timeout remains separately recorded: an ambient
proxy sent a loopback XMLHttpRequest through a route that stalled its worker
join. The successful retry removes ambient proxy variables and uses an empty
private profile. This is the sixth completed fix since the broad checkpoint;
production-browser acceptance remains pending.

A fresh full-filter Brave capture now succeeds after preparing a separate
profile with an immutable copy of the installed extension. Its inputs and
successful capture remain in
`Build/pikabu-matched-filter-brave-1793064011487232000/`. Comparing this capture
with an older Vox capture is diagnostic only because the live responses were
captured at different times. The article text region has zero differing pixels;
the photo region still differs substantially. Neither region result establishes
matched whole-page parity.

The photo format difference originates in the navigation response, before image
decoding. Two direct requests with identical user agents but different Accept
headers demonstrate that Pikabu emits JPEG image URLs for the existing generic
document header and WebP URLs when `image/webp,image/apng` is included. Both
responses are HTTP 200; their raw bodies and hashes are preserved in
`Build/pikabu-image-negotiation-1793067015516962000/`. A macOS navigation-header
change and a local-server regression covering redirects and child frames await
focused validation in
`Build/pikabu-navigation-negotiation-tests-1793067155909619000/`. This header is a
compatibility deviation from the upstream generic document header.

The latest completed shared bundle checked at this checkpoint has executable
SHA-256 `d0b28fb544c7ac9befb56b43402ed9c090f05651a2a2c1936df64f8793498d93`.
It contains the FormData changes, but lacks the new navigation header and
rounded-mask implementation. Fresh applicable checks will reuse a preserved
copy before any replacement build. A native rounded-mask preflight with this
bundle's newer libraries is queued separately; the earlier scale-two
four-pixel failure remains unresolved. The production diagnostic waits outside
the memory lock for the navigation tests and retains strict zero-difference
gates. Canvas browser acceptance, rounded masks, page startup, and matched live
whole-page parity remain open.

## Navigation negotiation validation

Commit `12d3fa0d` advertises WebP and APNG on macOS document navigations. The
six-case focused selection, including HTML image selection across a redirect
and a child-frame request, passes in normal and poisoned arena modes. Frozen
sources and compiler identities remain unchanged. The outer guard exits zero
after 69.395 seconds, with a sampled peak RSS of 2,854,649,856 bytes. Raw
commands, both runtime receipts, and results are retained in
`Build/pikabu-navigation-negotiation-tests-1793068460999426000/`. This is the
seventh completed fix since the broad checkpoint. Fresh production-browser
acceptance is queued; these focused tests do not establish live page parity.

The earlier navigation attempts remain recorded. Two exposed invalid `err`
references in Option fallbacks, which the final test source corrects. The next
attempt reached native compilation but lacked the frozen workspace's external
`3rd` dependency link for the WOFF2 headers. Restoring that link, without an
implementation change, produced the passing result above.

The native rounded-mask preflight with the newer shared libraries reproduces
the existing result: all eight scenes are exact at scale one, while scale two
has four differing pixels with maximum channel error one. Results are in
`Build/pikabu-rounded-mask-shared-libraries-1793067424798498000/`. A separate
temporary-surface precision probe tests 8-bit, 16-bit floating-point, and 32-bit
floating-point contexts. The 8-bit and 32-bit variants retain the same four
differences; 16-bit introduces additional differences. This does not support
changing the temporary surface precision. The probe changes no tracked source;
its inputs and all six runs remain in
`Build/pikabu-mask-compositing-precision-probe-1793068045837897000/`.
The strict rounded-mask gate remains failed.

## Live DOM and Canvas filter checkpoint

The startup replay exposed missing compact-script APIs used by Pikabu's image
initialization. Commits `7f349f0f`, `45e263b0`, and `7746a640` connect
`before()`, `after()`, and `replaceWith()` to the native ChildNode algorithms,
expose the native `DocumentFragment` constructor, and expose
`document.referrer`. Tests cover node moves, fragments, text, invalid
arguments, and document ownership. Commit `ec6e254f` flushes live SVG filter
mutations before Canvas drawing, including filter state restored by `restore()`.

Capture auditing also needed an arena lifetime fix. Commit `7447f455` replaces
the metadata-caching encoder with an encoder that does not retain allocations
from a temporary arena. Its cold-start optional-field regression passes.
Commit `64229a46` adds opt-in native script error details to capture audits.
All 35 focused DOM, Canvas, and audit cases pass in normal and poisoned arena
modes with unchanged frozen sources. The outer guard exits zero after
439.8 seconds, with sampled peak RSS 8,067,907,584 bytes; both runtime checks
remain below their separate 3 GiB limits. Commands and receipts are retained in
`Build/pikabu-dom-storage-tests-1793082603533734000/`.

Commit `b9dc8a64` draws Chromium Canvas images through the GPU path and applies
image filters in a separate compositing layer. Opacity uses an alpha lookup
table, matching Chromium's filter graph. Unsupported inputs and backend
failures retain the CPU fallback. The native regression covers sampling,
clipping, transforms, alpha, compositing, and preservation of existing pixels.
The plain image, SVG backdrop filter, and CSS blur screenshots each have zero
differing pixels against Brave. Direct `getImageData()` comparisons remain
failed: the backdrop differs in 52 pixels and CSS blur in 74 pixels, each by
at most one channel value. The plain image readback is exact. Retained results:
`Build/pikabu-canvas-filter-tests-1793075380390797000/results.json`.

These focused results do not establish whole-page parity. A diagnostic
production build containing these changes and a fresh live/frozen-page
comparison are in progress. The strict page, readback, and Retina rounded-mask
gates remain open.

## Fresh browser comparison after DOM and Canvas fixes

The diagnostic production build completed successfully and passed strict bundle
signing and a fresh headless startup check. Its executable SHA-256 is
`e10853851e59334a646337d36dce1d4f4fc9e21ae0fc4ffd150bc858ee8a5160`.
The build and preserved bundle are in
`Build/pikabu-dom-canvas-production-1793083416732516000/`; the guard recorded
1,001.6 seconds and a sampled peak RSS of approximately 7.18 GiB. This bundle
contains the committed DOM and Canvas fixes above, but does not contain the
subsequent fragment element-accessor work.

Fresh browser captures retain this executable and native-library identity,
empty private profiles, a 1024 by 768 document viewport, and scale one.
The bundled page comparison fails with 17,858 differing pixels, maximum channel
error 42. Independent live loads also fail, with 98,442 differing pixels
(12.52 percent), maximum channel error 226. Their article-text region is exact,
but the photo backdrop and missing cookie notice remain substantial failures.
The backdrop canvas is now created; its side bands still differ from Brave.
Changing live counters can contribute additional differences. Raw captures,
audits, commands, and pixel reports are retained in
`Build/pikabu-dom-canvas-visual-1793083853339213000/`. Neither comparison passes
the zero-difference gate.

The browser Canvas fixture passes all eleven image/filter regions with zero
differing screenshot pixels. This covers ordinary scaling, SVG and CSS filters,
cropping, relative filter URLs, merge inputs, alpha, live mutations, and filter
color spaces. Direct RGBA readback still differs. A separate Brave GPU diagnostic
confirms Graphite/Dawn/Metal and retrieves premultiplied Canvas pixels: all three
native plain-image, SVG-filter, and CSS-filter buffers match those bytes exactly.
The remaining readback discrepancy occurs during conversion to straight-alpha
RGBA, rather than in those fixture's filtered premultiplied output. This does
not establish that the larger, cropped live-photo filter is exact. Diagnostic
inputs and results are in
`Build/pikabu-brave-canvas-gpu-diagnostic-1793084670326151000/`.

The broad screenshot checkpoint passes 18 of 21 cases, including all ten SVG
mutation and mask guards. `inline-node`, `ordered-list`, and `text-decorations`
fail against their upstream expectations. A comparison with the earlier
shared bundle confirms the same failures: 5,766, 4,421, and 31,985 pixels,
respectively. Baseline results are retained in
`Build/pikabu-baseline-three-1793088284787546000/`. Results remain in
`Build/pikabu-story-broad-visual-1793085045442418000/`.

An archived-startup diagnostic with temporary fragment-accessor shims clears
the prior HTML-parsing error, but still produces no cookie notice. This is
diagnostic evidence only and does not validate the native accessor implementation.
Remaining analytics errors include `PerformanceResourceTiming` and a blocked
advertising initializer. The startup diagnostic is retained in
`Build/pikabu-fragment-startup-diagnostic-1793085248796138000/`.
Whole-page, Canvas readback, and Retina rounded-mask parity remain unresolved.

## Compact startup interface checkpoint

Further startup diagnostics exposed missing interfaces used by Pikabu's UI
libraries. Commits `dce69c2e`, `6c25ffee`, `21fdb617`, `efcaca0e`, and `6d30510d`
add live fragment element collections, `Document.createComment()`, SVG element
classification, TreeWalker/NodeFilter, and the common Node prototype hierarchy.
The Node tests cover parsed and created nodes, fragment ownership, interface
constants and descriptors, illegal construction, and the `instanceof` checks
used by Floating UI. These changes do not implement the full Web IDL surface.

All 45 focused DOM, Canvas, and audit cases pass in normal and poisoned arena
modes with unchanged frozen sources. The guard exits zero after 207 seconds,
with sampled peak RSS 8,624,439,296 bytes. Commands, source identities, compiler
and runtime exit codes are retained in
`Build/pikabu-node-interface-retry-1793094009125392000/results.json` and
`Build/pikabu-node-interface-retry-4434.json`.

These focused results do not validate Pikabu startup in the browser. A fresh
bundle containing these interfaces is pending. Whole-page, Canvas readback,
and Retina rounded-mask pixel equality remain unresolved.


## Native insertion and cookie notice checkpoint

Commit `ca390cb2` fixes compact `insertBefore()` before text and comment anchors.
The queued insertion previously captured the operations array before a reference
getter flushed and replaced it, losing the operation. Insertions now use native
pre-insertion, preserving mixed-node ordering, moves, fragment contents, and
validation. All 46 focused DOM, Canvas, and audit cases pass in normal and
poisoned arena modes with unchanged frozen sources. The guard exits zero after
215.48 seconds, with sampled peak RSS 8,631,042,048 bytes. Receipts are in
`Build/pikabu-anchored-insertion-retry-1793097480194628000/` and
`Build/pikabu-anchored-insertion-headers-4434.json`.

A fresh diagnostic bundle contains this fix, passes strict signature verification
and headless startup, and retains executable SHA-256
`c9d0e500c77a047182bdd891ef1a922f8f866e2c6816069a1d99b191e1edb955`.
The bundle and source/library identities are retained in
`Build/pikabu-anchored-insertion-browser-1793097548710087000/`.
The native Vue fixture now produces the expected mixed-node order and complete
cookie popup. Its fresh browser comparison is retained in
`Build/pikabu-anchored-insertion-vue-1793097629911540000/`.

Fresh 1024 by 768, scale-one page captures confirm that Pikabu now displays its
cookie notice. The live notice has the expected text and a 352 by 120 CSS-pixel
rectangle at (648, 624). Pixel equality still fails: the frozen page has 17,858
differing pixels (maximum channel error 42), and independent live loads have
71,874 differing pixels (maximum channel error 92). Both browsers exit zero;
executable, library, fixture, and filter identities remain unchanged. Raw
captures and audits are retained in
`Build/pikabu-insertion-page-comparison-1793098256222705000/story/`.
The aggregate validation job exits one because the strict pixel gates fail.
Live counters and independently timed startup can also affect this comparison.

The first archived startup replay in
`Build/pikabu-anchored-cookie-trace-1793097629911540000/` is invalid: two proxy
mappings referenced nonexistent application scripts. A corrected replay serves
those scripts from a pinned completed cache snapshot and uses a fresh browser
profile and cache. It confirms the native cookie notice without DOM shims.
Its logging also shows the photo backdrop drawing before the SVG filter is
installed: draw at 1793099176930 ms, sprite XHR load at 1793099178759 ms.
This is diagnostic timing evidence, not a complete explanation of the task
ordering difference. Corrected inputs, proxy requests, and the successful guard
are retained in
`Build/pikabu-anchored-cookie-trace-corrected-1793099148644848000/` and
`Build/pikabu-anchored-cookie-corrected-4434.json`.

The backdrop remains sharp where Brave blurs it. CSS shadow and rounded-edge
pixels, direct Canvas RGBA readback, and Retina masks remain open. These checks
do not establish whole-page pixel parity.


## GPU CSS shadow and transparent-padding checkpoint

Commit `07ad08c2` replays Chromium CSS drop-shadow chains on the shared GPU
backend, preserving premultiplied source and backdrop pixels. The filter input
is cropped to its nontransparent bounds before replay: transparent Cocoa chrome
otherwise changes Skia's blur downsampling grid. CPU fallback remains available.

All 12 focused native checks pass, including actual GPU backend availability,
shadow order, scale one and two, and padding invariance for opaque and translucent
inputs. Eight CPU fallback checks also pass with the GPU library unavailable.
Guards exit zero; receipts are `Build/pikabu-shadow-crop-native-final-4434.json`
and `Build/pikabu-shadow-cpu-fallback-4434.json`, with corresponding logs. The
new padding regression fails against the previous uncropped implementation
(3,402 differing channels at scale one), as retained in
`Build/pikabu-shadow-crop-regression-4434/` and its nonzero guard receipt.

A fresh diagnostic bundle clones the completed browser and replaces only the
native Skia library. Strict signing verification and headless startup pass.
After signing, executable SHA-256 is
`ccbcd0ddd7e3280e5d0b94255399e34b7b8744b74b6d1c0e6b4931f60868a652`;
native Skia SHA-256 is
`ae293ddfb55ddbc1df4a03a2aa24320348877d6c31585db68941026b09b80242`.
The static cookie-shadow fixture improves from 7,860 differing pixels with
maximum channel error two to eight pixels with maximum error one. Those eight
pixels still fail strict equality. Captures, frozen source, identities, native
checks and build commands are retained in
`Build/pikabu-cropped-drop-shadow-1793112129505739000/`. Its aggregate guard
exits one because the pixel gate fails.

Fresh 1024 by 768, scale-one whole-page captures reduce the frozen-page
difference from 17,858 to 10,204 pixels (maximum channel error remains 42).
Independent live loads differ in 66,473 pixels (maximum channel error 92).
Both browser runs exit zero, the requested document loads, and executable,
libraries, fixtures and filter identities remain unchanged. Receipts and raw
captures are in
`Build/pikabu-cropped-shadow-page-1793112183551907000/story/`; the aggregate
guard `Build/pikabu-cropped-shadow-page-4434.json` exits one for failed strict
pixel gates. Live counter changes can contribute to the live difference.

The corrected XHR progress replay at
`Build/pikabu-xhr-progress-corrected-1793111406098582000/` confirms that the
archive proxy finishes sending the sprite body before the canvas draw, while
JavaScript receives its XHR headers and load afterward. Native receive timing
is still being investigated; proxy send completion alone does not establish
when the browser processes the bytes. Whole-page equality, late filter
availability, Canvas RGBA readback and Retina mask equality remain open.


## Native fetch continuation and blurred backdrop checkpoint

Pending fetch continuations now enter the platform's deferred queue before the
HTML networking handover, matching upstream's `PendingResponse` scheduling.
The responsible document's persistent owner survives these continuations;
networking callbacks retain their existing task source and cancellation rules.
The unique task-source registry also grows in persistent storage. Fourteen
focused fetch, parallel-queue, font-loading and task-source cases pass in normal
and poisoned arena modes. Logs and compiler/source identities are retained in
`Build/pikabu-native-fetch-continuation-1793113160688826000/`; final validation
receipt `Build/pikabu-native-fetch-continuation-validation-4434.json` exits zero.
These implementations were incorporated into shared commit `ac3c7b67`; the
additional task-source arena regression is committed as `fe8d27bc`.

A fresh diagnostic browser contains these fixes and passes strict signature
verification and headless startup. Its executable SHA-256 is
`f62ba7f1f4de1ab0d16fe47d2eaaff77535f212f96137b4bab4feb4dc3334b60`.
Frozen source, build commands and native-library identities are retained in
`Build/pikabu-native-fetch-browser-1793113218368866000/`; the successful guard is
`Build/pikabu-native-fetch-browser-complete-4434.json`.

The instrumented archived startup replay now receives the sprite XHR load at
1793114338516 ms, before the backdrop canvas draw at 1793114345778 ms. At the
draw, the SVG filter is installed and the filter value is `url("#pkb-blur")
opacity(.9)`. Logging instruments the application's existing calls without DOM
shims. Inputs, proxy responses, timing and fresh-process identities are in
`Build/pikabu-native-fetch-startup-1793113569139143000/`; its guard exits zero.

Fresh scale-one 1024 by 768 captures show the blurred backdrop on the live page.
Independent live loads now differ in 3,902 pixels (0.4962%, maximum channel
error 61); the frozen page remains at 10,204 pixels (maximum error 42).
Both browsers exit zero and load the requested document. Executable, libraries,
fixtures and filter identities remain unchanged. Captures, audits and commands
are in `Build/pikabu-native-fetch-page-1793114499067433000/story/`; guard
`Build/pikabu-native-fetch-page-4434.json` exits one for failed strict pixel
gates. Live counters and independent timing remain possible contributors.

The remaining visible differences include SVG icon and rounded-button edges,
header shadows and a few cookie-popup edges. A reduced fixture isolates a
compositor-layer raster-policy problem: a transformed surface without an SVG
inherits sampling triggered by SVG content in other surfaces. Plain fractional
rounded rectangles without those surfaces match exactly. Whole-page equality,
Canvas RGBA readback and Retina mask equality remain open.


## Local compositor picture checkpoint (`c1c176a1`)

Supported CSS compositor surfaces now retain their full transformed border-box
bounds and replay their complete SVG picture in local layer coordinates.
Rectangular SVG viewport batches can participate; unsupported clips, effects,
images and failed backends retain the existing leaf result. Selecting the root
layer repeatedly preserves its already recorded page background.

The reduced `compositor-shared-recording` fixture matches fresh Brave captures
with zero differing pixels at both backing scales one and two (1024 by 768).
All ten SVG mutation and viewport regressions also match exactly, including
`svg-image-source-switch-same-size`. The native check covers 144 local-picture
combinations, root background preservation at both scales, and blocked fallback.
The focused V checks execute 19 raster-layer and seven recording cases in each
of normal and poisoned arena modes: 52 successful cases total.

Receipts, commands and immutable inputs are retained in:

- `Build/pikabu-clipped-shared-1793125609481490000/retry3/results.json`
  (focused V checks; its guard exits zero).
- `Build/pikabu-root-background-1793126845979058000/native-results.json`,
  `visual-results.json` and `svg/results.json` (native and capture guards all
  exit zero; source, executable, libraries and inputs remain unchanged).

The signed diagnostic executable SHA-256 is
`53274560795e8e1a2105c50d9700e7b324552697b067d05f2ce80c2fa769b5f4`;
the native bridge SHA-256 is
`6ef5578f8eca3990b176a7f083ba374d8256c886c0bf61e925e156d9ce22b41c`.
This diagnostic contains the new code; the shared production bundle was reused
as its base and was not replaced.

Fresh full-page captures still fail strict equality: the frozen page has
12,381 differing pixels (maximum channel error 42), and the independent live
loads have 9,015 (maximum error 61). All four browser captures exit zero and
load the intended document; both pixel checks and the overall guard exit one.
These are current results, not evidence of improvement over differently timed
live loads. Raw captures, audits, identities and failed gates are in
`Build/pikabu-root-background-1793126845979058000/story/` and
`story-guard.json`. Whole-page equality, Canvas RGBA readback and Retina mask
equality remain open. The next diagnostic checks whether the full page's
controls qualify for the corrected compositor path.


## Rectangular SVG clip checkpoint (`5086e28d`)

Rectangular SVG clip scopes can now share the paths' sample coverage in a
compositor picture. Both clip-transform composition and conversion back to path
coordinates preserve the local translation before rounding to Skia floats. This
prevents page offsets from moving coincident clip edges inward. Incomplete
scopes, differing owners, strokes, effects and unsupported clip geometry retain
the ordinary replay path.

The new `svg-rectangular-clip-local-transform` fixture matches fresh Brave
references at scales one and two with zero differing pixels. It covers the VK
symbol's half-pixel rectangular clip at five page positions. All ten SVG
mutation and viewport comparisons also remain exact. The focused mask,
recording, clip-conversion and layout checks compile and execute successfully
in normal and poisoned arena modes. The separately corrected CSS ownership
checks also pass both modes.

Evidence and immutable inputs are in
`Build/pikabu-rectangular-mask-1793128123792884000/`: `results.json`,
`css-results-v3.json`, `build-results.json`, `visual-results.json` and
`svg/results.json`. Their successful guards are `tests-v10-guard.json`,
`css-tests-v3-guard.json`, `build-v4-guard.json`, `visual-v4-guard.json` and
`svg-v4-guard.json`; commands and individual exit codes remain in
those receipts. The signed diagnostic executable SHA-256 is
`81c9b2fb9c2307dfe8aec3f7746eb68bb7056b0f14397a650818f004cdd8f125`.
The shared production bundle was not replaced.

Fresh 1024-by-768 scale-one captures still fail strict equality: the frozen
page differs in 7,309 pixels (maximum channel error 42), and independent live
loads differ in 6,828 pixels (maximum error 26). All four capture processes exit
zero and load the intended document; both pixel checks and the overall guard
exit one. Browser, native libraries, fixtures and filter inputs remain unchanged.
The raw captures, audits and failed gates are in `story/`, with the memory
receipt in `story-v4-guard.json`. These results do not establish whole-page
parity or a controlled improvement in independently timed live content. Header
shadows, Canvas RGBA readback and Retina mask equality remain open.
