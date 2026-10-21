# LibWeb V translation

This repository at `~/code/vox2` is the canonical workspace for the V
translation of Ladybird's LibWeb. The upstream C++ reference is
`~/code/3rd/ladybird/Libraries/LibWeb`.

All translated V implementation code, tests, generated translation assets, and
translation-specific documentation belong in this repository. See
[`PORT_STATUS.md`](PORT_STATUS.md) for the module inventory and LOC table, and
[`ROOT_SUPPORT.md`](ROOT_SUPPORT.md) for the root support-file mapping.

Vox runs on macOS and Linux. On Linux, build with `sh build-prod-browser.sh`
and launch `Build/linux/vox`. See [Linux setup and checks](docs/LINUX.md) for
dependencies, the Skia bootstrap, headless operation, and platform limitations.

The refreshed LibJS frontend lives in [`libjs/`](libjs/PORT_STATUS.md). It exposes
script/module parsing, positioned diagnostics, scope analysis, and retained AST
dumps, plus the translated VM record: execution contexts, environment records,
realms, error objects, job queues, host hooks, and module loader bookkeeping.
The native browser and inline-document layout bridge now prepare page scripts
through this frontend, report positioned syntax errors, and associate execution
with LibJS Script, Realm, and VM records. The translated bytecode generator and
interpreter execute primitive and BigInt expressions, declarations, lexical
scopes, loops, ordinary data/accessor-property operations, string own properties,
native and bound calls and construction, and `instanceof`. Function prototype methods, numeric,
URI, and legacy escaping globals execute through translated native functions.
Boolean and Symbol wrappers, prototypes, and globals retain primitive receiver
identity; Boolean construction and Symbol's registry methods follow upstream.
BigInt constructor/prototype records translate number-hint coercion, asIntN/asUintN,
branded toString/valueOf and locale-call plumbing. Their Object parent and Intl
formatting remain explicit dependencies; production global installation is pending.
Number constructor/prototype records translate noncoercing predicates, exact
BigInt-to-double rounding, branded radix formatting, fixed/scientific precision,
and locale-call plumbing. Object/parse-function intrinsics, AK's Dragonbox decimal
backend, and Intl formatting remain explicit dependencies; global installation
and Number primitive Reference integration are pending.
Host-created Array records implement sparse length/property behavior, and the
runtime provides the upstream sorting helpers. String's complete constructor
record and thirty-nine prototype native bodies now cover character creation,
raw templates, branding, UTF-16 access/slicing/search, concatenation, trimming,
well-formed repair, iterator creation, repetition, padding, all 13 legacy HTML
wrappers, Unicode casing/normalization through ICU, and string replacement/splitting
with symbol dispatch. Its remaining prototype methods, including Intl locale
casing/collation, initialization and production installation remain pending;
dependencies stay explicit. String exotic objects
expose fixed UTF-16 character descriptors.
RegExp preparation translates flag validation, named-group surrogate checks,
Unicode escape normalization and source escaping, with 9,202 exact native
LibJS/AK comparisons. RegExp objects, constructors/prototypes and the regex
compiler/general matcher remain pending.
LibRegex's complete AST and bytecode records, owned cloning and input/capture
primitives are translated, with 36,166 exact native Rust helper comparisons.
Bytecode pattern-hint analysis and literal prefilters add 112,458 exact native
comparisons, covering anchors, branches, suffixes, required literals and searches
that ignore ASCII case.
VM scratch storage, register snapshots, saved choices, modifier/repetition
transitions and directional character traversal add 14,942 exact native
comparisons, including surrogate-pair boundaries and checked position arithmetic.
Legacy/Unicode case canonicalization, builtin character classes, VM literal
matching, word boundaries and numbered/named backreferences add 113,204 exact
native comparisons. They preserve duplicate-name capture priority and retain ICU
for full UTF-8 uppercasing and simple Unicode folding.
UnicodeSet expansion, bounded case closures, inverse-range matching,
character classes and simple-scan membership add 255,240 exact native
comparisons, including every BMP code point and all class flag combinations.
Unicode property resolution, strict aliases, script extensions, case-closed
queries and string-property packing add 129,233 exact native comparisons.
On macOS, property queries use standard ICU 78 to preserve upstream's data.
Simple-match predicates and candidate filters add 389,048 exact native
comparisons. Single-match, greedy and find-all scan execution adds 32,481,
including complete capture buffers and capacity exhaustion.
The regex parser, compiler, backtracking and general VM execution remain pending.
Synchronous iterator operations and String/ordinary-Array iterator records
support stepping, collection, and closing.
Their intrinsic prototypes are supplied explicitly; Array literals and methods,
remaining String prototype methods and the Iterator intrinsic graph remain pending.
ArrayBuffer construction, branded accessors, resize, slice, and both transfer
methods execute in the translated VM. Owned and host-backed byte storage,
detach ownership, species selection, and DataView bounds witnesses follow the
upstream bodies. DataView construction, buffer/length/offset accessors, and all
22 numeric methods execute through translated buffer conversions, including
BigInt and Float16. Host-created TypedArray records support all twelve element
types, integer-indexed exotic properties, fixed/tracking witnesses, buffer-view
initialization and iterator stepping. Concrete constructor behavior additionally
handles scalar lengths, iterables, array-like input and TypedArray copies with
explicit prototype dependencies. Result creation/validation and numeric sorting
comparison follow upstream. Native behavior functions now cover its four branded
accessors, at, @@toStringTag, includes/indexOf/lastIndexOf, reverse and numeric
sort, every/some/forEach, the four predicate searches, reduce/reduceRight and
entries/keys/values, copyWithin, fill, join, toReversed/toSorted/with,
filter/map/set/slice/subarray and toLocaleString. Same-type and species result
creation use explicit intrinsic constructor/prototype dependencies. Primitive
boxing, GetV, GetMethod and Invoke retain explicit Number/BigInt/String dependencies.
Eleven Object prototype native bodies are translated: own/enumerable membership,
prototype membership, valueOf/toLocaleString, legacy getter/setter definition and
lookup, and __proto__ accessors. They retain primitive dependencies explicitly;
ObjectPrototype initialization and toString's complete type-record/IsArray chain
remain pending. Coercibility checks and immutable prototype dispatch follow upstream.
Reflect's complete record and thirteen native methods are translated, preserving
property descriptors, explicit receivers, key ordering, prototype/extensibility
checks, apply/construct validation and boolean mutation failures. Its Object/Array
prototypes remain explicit dependencies; production global installation is pending.
The abstract TypedArray constructor adds from/of/species. Its shared prototype
initializer preserves metadata, Array toString identity and the values/@@iterator
alias through explicit dependencies. All twelve concrete constructor/prototype
records and Uint8Array's six hex/base64 methods are translated, with 16,470 exact
codec comparisons against the pinned upstream dependency. Production builtin
installation, the complete intrinsic graph, Object toString, Number/BigInt locale
formatting and caged storage remain pending.
SharedArrayBuffer construction, three accessors, growth and species-aware slicing
also follow the active upstream bodies, using the existing DataView methods to
read and write their storage. Cross-agent shared-memory ordering remains pending.
The browser selects this supported slice with `--js-engine=libjs`;
JavaScriptCore remains the default, with `--js-engine=javascriptcore` selecting
its existing DOM host explicitly. LibJS mode has no DOM bindings and never falls
back to JavaScriptCore. The status file records the supported boundary, tests,
deviations, and remaining execution, builtin-object, and module-linking work.

## Translation footprint

As of 2026-09-12, tracked V sources contain **340,625 implementation LOC** and
**65,932 test LOC**. The current module-owned translation subset contains
**329,734 implementation LOC** and **62,094 test LOC**; the difference is root
support, browser integration, and translation tooling. See the canonical
current table in [`PORT_STATUS.md`](PORT_STATUS.md).

The counts below preserve the 2026-08-29 checkpoint for historical comparison.
They are physical lines (`wc -l`), including comments and blank lines. Upstream
counts include each module's subdirectories.

| Module | Upstream `.cpp` LOC | Upstream `.cpp` + `.h` LOC | V implementation LOC | V test LOC |
| --- | ---: | ---: | ---: | ---: |
| `ARIA` | 1,876 | 2,623 | 2,523 | 354 |
| `Animations` | 4,381 | 5,457 | 2,217 | 389 |
| `Bindings` | 1,718 | 2,423 | 1,639 | 488 |
| `CSS` | 66,305 | 84,658 | 90,675 | 3,594 |
| `Clipboard` | 892 | 1,088 | 948 | 332 |
| `Compression` | 359 | 467 | 322 | 135 |
| `ContentSecurityPolicy` | 4,653 | 6,042 | 2,404 | 389 |
| `CookieStore` | 900 | 1,036 | 997 | 392 |
| `CredentialManagement` | 369 | 647 | 400 | 293 |
| `Crypto` | 13,297 | 14,720 | 2,303 | 879 |
| `DOM` | 26,465 | 33,101 | 32,188 | 1,494 |
| `DOMURL` | 1,016 | 1,257 | 932 | 270 |
| `Editing` | 7,980 | 8,277 | 2,019 | 660 |
| `Encoding` | 438 | 609 | 668 | 235 |
| `EncryptedMediaExtensions` | 544 | 767 | 572 | 329 |
| `EntriesAPI` | 55 | 94 | 44 | 32 |
| `EventTiming` | 131 | 204 | 170 | 93 |
| `Fetch` | 7,787 | 10,319 | 3,194 | 876 |
| `FileAPI` | 1,359 | 1,750 | 943 | 448 |
| `Fullscreen` | 0 | 0 | 93 | 177 |
| `GPC` | 21 | 40 | 16 | 13 |
| `Gamepad` | 1,382 | 1,796 | 681 | 210 |
| `Geolocation` | 511 | 689 | 391 | 174 |
| `Geometry` | 2,157 | 2,725 | 1,962 | 952 |
| `HTML` | 73,434 | 93,439 | 54,896 | 10,966 |
| `HighResolutionTime` | 521 | 656 | 362 | 181 |
| `IndexedDB` | 6,449 | 8,098 | 2,362 | 523 |
| `Infra` | 405 | 556 | 193 | 61 |
| `Internals` | 951 | 1,287 | 826 | 220 |
| `IntersectionObserver` | 445 | 661 | 376 | 186 |
| `Layout` | 19,592 | 23,711 | 27,672 | 8,384 |
| `Loader` | 887 | 1,289 | 830 | 292 |
| `MathML` | 292 | 469 | 361 | 75 |
| `MediaCapabilitiesAPI` | 247 | 386 | 369 | 99 |
| `MediaSourceExtensions` | 413 | 695 | 357 | 110 |
| `MimeSniff` | 1,357 | 1,530 | 1,035 | 269 |
| `MixedContent` | 121 | 150 | 125 | 105 |
| `NavigationTiming` | 104 | 252 | 264 | 42 |
| `NotificationsAPI` | 249 | 388 | 278 | 68 |
| `Page` | 4,298 | 5,338 | 1,533 | 317 |
| `Painting` | 10,038 | 13,879 | 4,265 | 825 |
| `PerformanceTimeline` | 391 | 672 | 417 | 130 |
| `PermissionsPolicy` | 98 | 152 | 79 | 21 |
| `Platform` | 415 | 603 | 1,014 | 61 |
| `ReferrerPolicy` | 298 | 358 | 239 | 123 |
| `RequestIdleCallback` | 55 | 106 | 36 | 10 |
| `ResizeObserver` | 376 | 587 | 238 | 89 |
| `ResourceTiming` | 340 | 431 | 317 | 71 |
| `SRI` | 191 | 217 | 147 | 95 |
| `SVG` | 9,570 | 13,735 | 3,561 | 726 |
| `SecureContexts` | 88 | 112 | 63 | 13 |
| `Selection` | 744 | 837 | 569 | 96 |
| `Serial` | 381 | 565 | 231 | 33 |
| `ServiceWorker` | 1,365 | 1,842 | 842 | 248 |
| `Speech` | 504 | 1,071 | 596 | 111 |
| `StorageAPI` | 381 | 769 | 342 | 146 |
| `Streams` | 8,784 | 10,923 | 4,683 | 918 |
| `TrustedTypes` | 1,108 | 1,472 | 722 | 168 |
| `UIEvents` | 1,557 | 2,712 | 1,270 | 252 |
| `URLPattern` | 148 | 210 | 300 | 41 |
| `UserTiming` | 164 | 278 | 89 | 29 |
| `ViewTransition` | 1,046 | 1,217 | 567 | 319 |
| `WebAssembly` | 2,157 | 2,606 | 740 | 245 |
| `WebAudio` | 3,649 | 5,305 | 1,660 | 298 |
| `WebDriver` | 5,013 | 6,063 | 2,091 | 423 |
| `WebGL` | 7,163 | 8,997 | 3,006 | 288 |
| `WebIDL` | 2,110 | 3,055 | 1,139 | 279 |
| `WebSockets` | 429 | 515 | 285 | 100 |
| `WebVTT` | 326 | 510 | 445 | 221 |
| `WebXR` | 409 | 565 | 200 | 41 |
| `Worker` | 47 | 87 | 81 | 33 |
| `XHR` | 1,706 | 2,179 | 964 | 274 |
| `XLink` | 16 | 45 | 13 | 10 |
| `XML` | 534 | 617 | 244 | 83 |
| `XPath` | 438 | 626 | 407 | 83 |
| **Total** | **316,400** | **403,612** | **263,954** | **41,167** |

Build the optimized V-native translated-engine browser as a macOS application
bundle with:

```sh
./build-prod-browser.sh
open Build/v/Vox.app
```

The macOS production builder uses `-enable-globals -prealloc -gc none -cflags -O2`, integrates the
upstream Skia text bridge when its release dependencies are available, writes
`Build/v/Vox.app` with the executable `Contents/MacOS/Vox`, and ad-hoc signs the
bundle. `build_ladybird.sh` remains as a compatibility alias for existing tooling.
Scoped arenas own document payloads, paint trees, display-list scenes and
temporary measurement/replay data. Retained snapshots keep their allocation
owners alive. Individual V `free()` calls do nothing under `-prealloc`; reclaiming
memory requires resetting or releasing the owning arena.

Use a current V compiler with bounded arena reallocation, including
`realloc(nil, n)`. The builder checks this requirement; set `V_BIN` to a compatible
compiler when the compiler on `PATH` fails it. `LADYBIRD_V_GC=boehm` selects an
explicit collector build for comparisons, and `LADYBIRD_V_GC=none` selects plain
allocation without scoped arenas. Set `LADYBIRD_DEBUG_TIMING=1` when launching
Vox to report parsing, stylesheet, JavaScript, layout, and first-paint timings.

The application provides tabs with independent page state and history, back/forward,
reload, an editable address/search field, link navigation, loading and console
status, and scrolling. On macOS the window buttons and tabs share a compact top
row, with flat navigation icons below it. The production macOS toolbar and status bar use
UI2 native controls; see [the embedding adapter](tools/ui2/README.md). Enter
submits the address. Cmd+D on macOS (Ctrl+D on Windows/Linux) toggles the
otherwise hidden HTTP/rendering diagnostic row. HTTP(S), local files, external
stylesheets, and classic scripts feed the translated HTML, DOM, CSS, Layout,
hit-testing,
history, and paint-command pipeline. The LibJS frontend validates page scripts
and supplies retained AST and scope metadata. On macOS, JavaScriptCore supplies
ECMAScript evaluation at the browser host boundary; common
`document`, element mutation, location, events, timers, and console operations
are bridged back into the translated DOM before reflow. Each classic script is
a separate global program with a promise checkpoint before the next script;
syntax and runtime errors are logged without stopping later document scripts.

The Window-owned JavaScriptCore DOM host now exposes native DragEvent
construction and its read-only dataTransfer getter, preserving inherited
MouseEvent/UIEvent fields and actual DOM listener dispatch. A nullable native
DataTransfer wrapper retains its owning implementation identity; its public
constructor, data/item/file operations and physical drag delivery remain
separate work. See [DragEvent
evidence](docs/translation-audit/NATIVE_DRAG_EVENT_OWNER.md).

Window-owned JavaScriptCore runtimes now expose native DataTransfer
construction, dropEffect/effectAllowed, getData/setData/clearData and frozen
types over actual HTML stores. Existing owner-local wrappers gain the public
prototype without changing identity. UTF-16 preserves NUL and lone surrogates;
type arrays cache by native record, revision and runtime. The `b335958e`
source passes nine focused/optimized cases, thirteen selected files in both GC
modes, signed startup, two pixel-exact nonnull-transfer pages and eleven
screenshot smoke cases. Public item/file-list and drag-image surfaces,
physical drag delivery, store transitions/default actions, foreign realms and
weak ownership remain open. See [DataTransfer string-store
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_STRING_OWNER.md).

Window-owned DataTransfer now exposes its native read-only files getter over
existing FileAPI owners. The pinned implementation and generator return fresh
FileList/File snapshots despite the IDL SameObject annotation; old snapshots
retain their bytes after store/mode changes. Native receiver branding precedes
FileAPI dependency lookup. At `b59e211c`, seven new and twelve focused cases
pass, fourteen selected files pass in both GC modes, and seven optimized cases
pass. Signed startup, two pixel-exact genuine empty-list pages and eleven
smoke cases pass. Nonempty files use focused native owner tests. Public items,
drag images, hardware file delivery and weak/foreign ownership remain open.
See [DataTransfer files
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_FILES_OWNER.md).

Window-owned DataTransfer now exposes a stable native live items list and
cached indexed item wrappers. Native length/remove/clear and kind/type/getAsFile
preserve the store's access modes, raw UTF-16 metadata and surviving item identity.
Successful file reads return fresh copied Files; the pinned clear implementation
removes text only and preserves files. At `e775be45`, nine new cases and fourteen
focused cases pass, seventeen selected files pass in both GC modes, and nine
optimized cases pass. Signed startup, two pixel-exact genuine text-item pages and
eleven smoke cases pass. Nonempty files and mode gates use native owner tests.
Public add/getAsString/webkitGetAsEntry/setDragImage, hardware delivery and
weak/foreign wrapper ownership remain pending. See [DataTransfer items
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEMS_OWNER.md).

Window-owned DataTransferItemList.add now selects the native File overload for
one argument and converts data then type as raw UTF-16 DOMStrings for two or more.
Zero arguments fail overload resolution before receiver branding; selected calls
convert before the store's mode gate. Added items share the live indexed wrappers,
and duplicate string types throw fresh typed NotSupportedError objects. At
`bbe330a8`, 9 new / 16 focused cases pass;
15 selected files / 52 cases pass in each GC mode,
and 9 optimized cases pass. Signed startup, two pixel-exact
genuine mixed string/File pages and eleven screenshot smoke cases pass. Public
File names use USVString conversion; copied bytes and access modes have native
owner-task coverage. getAsString/webkitGetAsEntry/setDragImage, physical delivery
and default actions, media ondrag handlers and weak/foreign ownership remain open.
See [DataTransfer item-add evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ADD_OWNER.md).

Window-owned DataTransferItem.getAsString now brands its native receiver before
required-argument and nullable-callable conversion, then snapshots readable text
as raw UTF-16. It queues an asynchronous unspecified task without a Document;
callbacks receive one argument, retain their captured incumbent owner, and keep
the original data after removal or store changes. Return values and throws are
discarded without then access or exception reporting; queued roots are released
and closing the runtime safely skips pending calls. At `e3ff95fd`, 8 new /
15 focused cases pass; 15 selected files /
47 cases pass in each GC mode, and 8 optimized cases pass.
Signed startup, two pixel-exact asynchronous callback pages and eleven screenshot
smoke cases pass (8 exact, 3 at established tolerances). Native owner fixtures
verify video/audio drag dispatch, callbacks with the actual Page scripting gate
disabled, and asynchronous DOM mutations. Foreign function
realms, weak ownership, entries, drag images, physical delivery/default actions
and media ondrag handlers remain open. The browser still uses JavaScriptCore.
See [DataTransfer string-callback evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_STRING_CALLBACK_OWNER.md).

Window-owned DataTransferItem.webkitGetAsEntry now brands its native receiver,
ignores extra arguments, and returns a fresh FileSystemEntry snapshot for readable
file items. Protected, removed, disassociated and text items return null. Entries
expose native readonly isFile/isDirectory/name getters through their owner registry;
raw stored names retain lone surrogates and NUL units through the pinned upstream
round trip. Later public constructor/property changes cannot replace native records.
At `fdc13cca`, 12 new / 21 focused cases pass;
15 selected files / 49 cases pass in each
GC mode, and 12 optimized cases pass. Signed startup, two pixel-exact
entry pages and eleven screenshot smoke cases pass (8 exact, 3 at
established tolerances). Real Page fixtures retain drag identity and cancellation
from parsed video to script-created audio listeners. Upstream FIXME path, filesystem
and parent operations remain absent; generic entry callbacks, directory traversal,
physical/default drag delivery, foreign WindowProxy handling and weak ownership
remain open. The browser still uses JavaScriptCore.
See [DataTransfer entry evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ENTRY_OWNER.md).

Native media ondrag, ondragend, ondragenter, ondragleave, ondragover,
ondragstart and ondrop now use the existing owner-backed event-handler pipeline.
Native receiver checks precede replay; legacy primitive assignments become null,
object callbacks retain identity, replacement keeps the listener position, and
null removal followed by reactivation appends the slot. Only actual boolean false
cancels dispatch. Parsed video and script-created audio handlers receive the real
DragEvent and native DataTransfer/item payload, with fresh File/Entry snapshots,
balanced settings/VM contexts and the actual Page scripting gate. Raw content
handler source stays uncompiled and remains in the attribute after IDL replacement.
At `a503c977`, 6 new / 20 focused cases pass;
15 selected files / 52 cases pass
in each GC mode, and 6 optimized cases pass. Signed startup, two
pixel-exact public drag-handler pages and eleven screenshot smoke cases pass
(8 exact, 3 at established tolerances). Public page dispatch is
untrusted; focused V fixtures also exercise trusted embedding DOM dispatch.
The compact HTMLMediaElement prototype remains a partial flattened surface.
Physical Cocoa/Page drag production, automatic store transitions/default actions,
weak/foreign ownership and the complete HTMLElement handler hierarchy remain open.
Upstream FIXME setDragImage stays absent without an invented public stub.
The browser still uses JavaScriptCore; existing native play() promises remain complete.
Verification and the physical inventory remain pinned to `a503c977`. 3 later independently authored commits are preserved at documentation base `a79d432b`; their CSS/Layout sources and counts are outside this slice's verified source and inventory counter. A later inventory refresh must account for those separate changes under its own pin.
See [media drag-handler evidence](docs/translation-audit/NATIVE_MEDIA_DRAG_HANDLERS_OWNER.md).

On macOS, production layout uses Arial/Helvetica-compatible metrics to match
the native Cocoa painter. Set `LADYBIRD_BROWSER_FONT` to another TrueType font
path to override it; `LADYBIRD_LAYOUT_TEST_FONT` continues to take precedence
for deterministic layout tests.

Pass a URL, local HTML path, or raw HTML to the bundle executable to open it. A
small non-windowed build/startup check is available as:

```sh
Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke --js-engine=javascriptcore
Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke --js-engine=libjs
```

Wikipedia and its subdomains use HTML and CSS without fetching or parsing page
JavaScript or creating a page runtime. Pass `--disable-javascript` for the same
behavior on other sites, or `--enable-javascript` to override the automatic site
policy. The five-pair Wikipedia comparison measured 859 ms to 694 ms for document
installation through the first submitted frame (19.21% less time); see the
[policy and rendering measurements](docs/WIKIPEDIA_HTML_CSS_PERFORMANCE.md).

`--js-engine javascriptcore` and `--js-engine libjs` are also accepted. The
JavaScriptCore smoke tests DOM mutation and click events; the LibJS smoke tests
bytecode execution and reports that DOM bindings are pending. Run translated
scripts without a browser or JavaScriptCore with:

```sh
v -old-compiler -enable-globals run tools/libjs_run.v -e '6 * 7;'
v -old-compiler -enable-globals run tools/libjs_run.v program.js
```

Compare the V browser against checked-in upstream C++ screenshots of the
confirmed Example Domain, Hacker News, and old Reddit pages with:

```sh
./compare_site_pixels.sh
```

The fixtures, reference provenance, metric ceilings, and per-site invocation
are documented in [`pixel_tests/README.md`](pixel_tests/README.md).

Authenticated Brave session import and the current old Reddit comparison are
documented in [`docs/OLD_REDDIT_BRAVE_PARITY.md`](docs/OLD_REDDIT_BRAVE_PARITY.md).
Exact Brave pixel equality remains open.

This bundle is distinct from `~/code/3rd/ladybird/Build/.../Ladybird.app`, which
is the upstream C++ application. The V-native application does not yet provide
the full generated Web-IDL JavaScript surface, multi-process isolation,
downloads, media playback, or persistent browser profiles.

Run the full translation test suite with:

```sh
v -enable-globals test .
```

## Native media wheel handler

Native HTMLMediaElement.onwheel now uses the existing owner-backed handler registry,
which exposes 40 handler names. Receiver branding precedes replay. Callback identity,
listener-slot replacement/null removal, exact boolean-false cancellation and the actual
Page scripting gate use the shared EventTarget machinery. Parsed video and script-created
audio receive real WheelEvent deltas and native owner identity, with trusted embedding
dispatch and same-wrapper untrusted public redispatch. Raw content source stays uncompiled.
At `0cd374b6`, 6 new / 13 focused cases pass;
8 files / 27 cases pass in each GC mode,
and 6 optimized cases pass at corrected validation `ea533888`.
The separate compatibility commit removes two redundant CSS option defaults with
zero line-count change; CSS semantic tests pass in both GC modes. Original optimized
and production compilation failures remain preserved without passing credit.
Ten physical production stages pass. The original posthoc provenance child fails a
stale GC-branch parser check; its failure remains preserved and receives no full
supervisor credit. A metadata-only supplemental provenance proof completes with
actual exit zero using the same build/screenshots. Signed startup, two pixel-exact public handler
pages and eleven configured smoke cases pass. Only ordinary actual false sets the
canceled flag, including for a noncancelable event; preventDefault retains its own gate.
Physical Cocoa/Page delivery, default scrolling, blocking-wheel subtree/compositor
invalidation, complete HTMLElement handler coverage and weak/foreign ownership remain
open. The browser still uses JavaScriptCore. Existing native play() promises remain complete.
See [media wheel-handler evidence](docs/translation-audit/NATIVE_MEDIA_WHEEL_HANDLER_OWNER.md).
