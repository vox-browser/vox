# Additional large Ladybird sources and translation boundaries

Audited 2026-10-02 against Ladybird commit
`963d46a829f3e1b79f44dba9d02afb70654300fa`. The inventory covers tracked
`.cpp` files containing at least 1,000 physical lines at that snapshot.
This report inventories **41 production/utility C++ sources outside LibWeb and
LibJS** and the **17 excluded test/harness sources**. Upstream paths are relative
to `/Users/alex/code/3rd/ladybird`; V paths are relative to this repository.

## Review depth

These are responsibility and boundary reviews: source entry points and selected
bodies were read, related V modules were searched, and the build/native browser
execution path was checked. They are not complete algorithm-by-algorithm
comparisons. An absent direct counterpart here is a boundary of the existing
LibWeb/LibJS workspace, not automatically a defective LibWeb translation.

“Related code” below means overlapping behavior, not a verified source port.
The anchor identifies one inspected upstream body. No row is a parity pass.
Qt/Linux-only facilities are explicitly distinguished from this repository's
macOS target.

## Per-source inventory

| Upstream source | Lines | Inspected source anchor/responsibility | Related V or host path; disposition |
| --- | ---: | --- | --- |
| `AK/Format.cpp` | 1,448 | `:969` formatter modes and numeric/string formatting | V formatting and `libjs/error_types.v`; runtime/language adaptation. AK formatter control flow and complete mode behavior not ported/verified. |
| `Libraries/LibDNS/Message.cpp` | 1,344 | `:962` network-order AAAA serialization; message/resource records | Host networking via `main.v:828`; no source-equivalent LibDNS message parser/serializer identified. |
| `Libraries/LibDevTools/Actors/WalkerActor.cpp` | 1,122 | `:849` sibling lookup; actor/node identity and traversal | DOM/dump modules and compact browser script bridge do not provide this DevTools actor protocol. No direct counterpart found. |
| `Libraries/LibGC/Heap.cpp` | 1,516 | `:783` roots, incoming cross-heap members, collection ownership | V allocations/tracing boundaries and `libjs/vm.v` roots; no LibGC heap implementation. Production bundle uses `-gc none`, not the upstream LibGC collector. EX-03. |
| `Libraries/LibGfx/ImageFormats/BMPLoader.cpp` | 1,580 | `:796` BMP V5 DIB/color-profile fields; bitmap decoder | `main.v:1203` uses stbi; platform image hooks are separate. No direct BMP decoder port or format-by-format equivalence established. EX-03. |
| `Libraries/LibMedia/Containers/Matroska/Reader.cpp` | 1,335 | `:725` track iteration; streaming container reader/range scans | MSE WebM parser overlaps append parsing; native playback uses FFmpeg (`native_capture_darwin.m:159`). No full LibMedia Reader counterpart/equivalence established. EX-03. |
| `Libraries/LibSandbox/Seccomp.cpp` | 1,362 | `:910` permitted fd syscalls; `:1340` policy install | Linux-only sandbox implementation; no V Seccomp policy. Outside native macOS functionality and still outside an entire-Ladybird source port. |
| `Libraries/LibUnicode/DateTimeFormat.cpp` | 1,027 | `:198` TR-35 calendar pattern assembly; locale week information | ICU casing/normalization bridges implement other responsibilities. No DateTimeFormat/Intl runtime graph found. EX-04. |
| `Libraries/LibUnicode/NumberFormat.cpp` | 1,004 | `:300` ICU unit/currency width selection; numeric partitions | `libjs/number_locale.v` and `bigint_locale.v` require injected Intl dependencies. Formatting backend/pipeline absent. EX-04. |
| `Libraries/LibWasm/AbstractMachine/AbstractMachine.cpp` | 1,289 | `:504` resolved global store/cache; module instantiation machinery | Initial audit: reduced facade records. Fixes now translate machine values, stacks, trap/results and stable indexed global-store ownership. Instantiation, remaining Store families and execution stay open. EX-01. |
| `Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp` | 8,513 | `:3586` typed SIMD instruction handler; interpreter dispatch | No Wasm interpreter/instruction graph found in V. Callback export tokens do not execute this source's instructions. EX-01. |
| `Libraries/LibWasm/AbstractMachine/Validator.cpp` | 5,187 | `:17` module validation; `:3223` lane/stack validation | Initial audit: no typed validator. Fixes now dispatch all 500 pinned validation specializations and execute source expression/module checks. Compilation half remains open. EX-01. |
| `Libraries/LibWasm/CraneliftBridge.cpp` | 1,641 | `:706` compiled/interpreted direct call; trap/frame bridge | No Cranelift native compilation bridge or matching runtime found. Native YUV Rust helper is unrelated. EX-01. |
| `Libraries/LibWasm/Parser/Parser.cpp` | 1,901 | `:1353` imports; `:1360` function section | Initial audit: skipped core sections. Fixes now decode all core sections and 499 pinned instruction parse cases, retaining operands and expression metadata. EX-01. |
| `Libraries/LibWasm/Printer/Printer.cpp` | 1,433 | `:449` tag-section printing; module/value diagnostics | No source-equivalent Wasm Printer found; record inspection does not serialize these module/instruction structures. |
| `Libraries/LibWasm/WASI/Wasi.cpp` | 1,320 | `:190` preopened-directory ABI serialization; system interface | No WASI memory/descriptor/host ABI implementation found. No corresponding standalone Wasm runtime. |
| `Libraries/LibWebView/Application.cpp` | 3,875 | `:2716` content-blocker update trigger; process/application ownership | `main.v`, `cookie_blocker.v` and native host overlap selected application behavior; no full WebView application/process manager. EX-02. |
| `Libraries/LibWebView/CanonicalTraversable.cpp` | 2,869 | `:1160` unique completion endpoints; canonical history coordination | `html/navigable*.v`, traversable/history modules and Page boundaries overlap logical navigation. Canonical UI-process owner and cross-process job orchestration not established as translated. EX-02. |
| `Libraries/LibWebView/FileDownloader.cpp` | 1,615 | `:1016` segmented download progress | `page/downloads.v`, PageClient download handling and root download helpers overlap basic downloads; not the complete segmented/resumable WebView manager. EX-02. |
| `Libraries/LibWebView/HistoryStore.cpp` | 1,251 | `:753` same-site matching; persisted browsing/omnibox history | `main.v:2727` uses in-memory browser entries; DOM session-history models have a different responsibility. No WebView persisted HistoryStore counterpart. EX-02. |
| `Libraries/LibWebView/SessionHistory.cpp` | 1,020 | `:401` canonical nested history insertion | HTML navigable/session-history records and remote-safe boundaries overlap; no complete mapping of canonical UI-process session history established. EX-02. |
| `Libraries/LibWebView/SessionHistorySnapshotStorage.cpp` | 1,387 | `:450` snapshot text caps; `:1242` database-backed snapshot load | HTML history records do not provide source-equivalent persistence/schema/validation. No snapshot database port found. EX-02. |
| `Libraries/LibWebView/SessionStore.cpp` | 1,913 | `:794` persisted tab snapshots; `:1850` retry/flush dirty state | No matching persisted windows/tabs/closed-unit store found in V browser. In-memory navigation history is narrower. EX-02. |
| `Libraries/LibWebView/Settings.cpp` | 1,185 | `:841` autocomplete setting/observer notification | Browser launch options and Page settings provide selected flags; no equivalent full persisted Settings/observer/configuration record found. |
| `Libraries/LibWebView/ViewImplementation.cpp` | 3,921 | `:1735` grid inspector RPC; view/process callbacks | `main.v`/native view and PageClient hooks supply selected embedding functions, not a verified translation of this complete view/RPC lifecycle. EX-02. |
| `Libraries/LibWebView/WebContentClient.cpp` | 2,500 | `:1563` page-keyed DevTools source completion | Page client abstractions contain related hooks/state. No complete WebContent IPC client/process replacement implementation found. EX-02. |
| `Services/Compositor/CompositorState.cpp` | 1,045 | `:488` context lookup and async-scroll update application | `compositor/async_scroll.v` translates related LibWeb records/algorithms; no source-equivalent compositor service/context scheduler established. |
| `Services/Compositor/ContextState.cpp` | 1,444 | `:855` backing-store invalidation; `:1390` display-list paint | Retained `painting/`, `compositor/` and native Skia replay overlap output responsibilities; compositor-service damage/presentation lifecycle is not certified. |
| `Services/RequestServer/Request.cpp` | 1,849 | `:986` resource substitution; libcurl/cache/DNS/cookie/back-pressure state | `main.v:828`/`:870` use V net.http; Fetch has a separate host boundary. No RequestServer Request state-machine port established. EX-05. |
| `Services/WebContent/ConnectionFromClient.cpp` | 2,834 | `:1712` debugger breakpoint RPC/page routing | Browser script bridge and Page hooks overlap selected requests; no complete service IPC dispatcher/debugger boundary found. |
| `Services/WebContent/PageClient.cpp` | 1,972 | `:1072` prompt IPC plus WebDriver dialog notification | `page/page_client*.v` represent the LibWeb-facing client and hooks; they do not by themselves translate this service's IPC/dialog/process work. See web-API findings. |
| `Services/WebContent/WebDriverConnection.cpp` | 3,010 | `:1461` computed role with open-context/prompt/element checks | `webdriver/` contains protocol and element models, injected script/socket boundaries; live WebContent connection and full DOM command integration not established. |
| `UI/Qt/Application.cpp` | 1,226 | `:753` new private/normal window; download-path UI | Native V/gg/Cocoa application, not a Qt port. Qt application/window behavior outside the declared macOS implementation. EX-02. |
| `UI/Qt/BrowserWindow.cpp` | 1,695 | `:941` window/screen signal lifecycle | Native gg/Cocoa window; no Qt BrowserWindow lifecycle counterpart. Platform-specific boundary, not a newly established macOS screen bug. |
| `UI/Qt/ChromeStyle.cpp` | 1,273 | `:211` palette/accent selection; widget painting | `main.v:5235`/`:5267` draws its own toolbar/content/status chrome. No Qt ChromeStyle algorithm mapping. |
| `UI/Qt/Tab.cpp` | 1,696 | `:1361` tab favicon updates; file-open UI | BrowserApp has a single document/address/history path; no source-equivalent Qt Tab record/lifecycle identified. |
| `UI/Qt/TabBar.cpp` | 2,515 | `:1612` tab insertion; hidden-page sizing | No multi-tab TabBar/TabWidget source port found in native browser. Missing only if entire Qt UI scope is required. |
| `UI/Qt/WebContentView.cpp` | 1,691 | `:844` scaled shared-image painting | Native V content rendering/replay, not Qt shared-image WebContentView. Full input/process/view mapping unverified. |
| `UI/Qt/WebContentViewLinux.cpp` | 1,115 | `:970` deferred Vulkan-to-bitmap fallback | Linux/Vulkan-specific view absent from macOS target. No source port; not evidence that macOS fallback crashes. |
| `Utilities/js.cpp` | 1,155 | `:552` REPL exit; `:1030` utility main/options | `tools/libjs_run.v` is a small standalone runner; no full upstream REPL/debugger/utility option translation. |
| `Utilities/wasm.cpp` | 1,263 | `:302` module parse; `:337` utility main | No corresponding Wasm command-line utility/runtime found. |

## Confirmed broader boundaries

### EX-01 — A WebAssembly facade is not a translated LibWasm runtime

The initial audit found skipped core sections, default-shaped exports and no
typed validator or interpreter. Subsequent fixes translate every core section,
all pinned instruction operands, source type interning/matching and all 500
instruction validation specializations. Module validation executes the actual
expression, constant, initialization, signature and index checks in source order.
Machine value/stack, trap/result and global-store ownership foundations are also
translated. See [current source mappings and checks](../../webassembly/PORT_STATUS.md).

The interpreter, native compilation/Cranelift bridge, remaining Store allocation
families and actual instantiation are still missing dependencies. The existing
WebIDL instance facade continues to manufacture function/global/table exports;
the completed parser/validator does not supply execution for those exports.
The [web API report](web-apis.md) retains detailed LibWeb entry-point comparisons.

### EX-02 — The native bundle implements a narrower embedding than WebView/services/Qt

The build runs V over the repository (`build-prod-browser.sh`) and links native
Skia/FFmpeg/YUV support. It does not compile upstream WebView, WebContent,
RequestServer or Qt sources. `main.v:5678` creates one BrowserApp;
`:2727` navigates in-memory markup history. It does not implement upstream's
database-backed session flush (`Libraries/LibWebView/SessionStore.cpp:1850`)
or snapshot loading (`SessionHistorySnapshotStorage.cpp:1242`).

V HTML navigation/history algorithms and PageClient hooks are real related
work; their existence does not certify the canonical UI-process algorithms.
Qt replacement is a target choice. If the requirement is a literal port of all
Ladybird source logic, the missing embedding/services/UI are additional work.
The audit does not infer “written from scratch” authorship from the choice
of gg/Cocoa; it establishes that no complete source mapping was found.

### EX-03 — Allocation and codecs are host replacements, with equivalence unverified

Upstream Heap gathers explicit/cross-heap roots and conservative roots
(`Libraries/LibGC/Heap.cpp:783`, `:798`, `:853`). This bundle is built with `-gc none`; the
translated VM tracks roots but does not supply a LibGC collector. Subsequent
fixes directly translate ExternalEntityTable and the full PrimitiveStorage
allocator/public API, including the actual POSIX 4 TiB cage, slab classes,
guarded reservations, source free-range handling and handle generations. Wasm
MemoryBuffer/MemoryInstance use that storage and pass focused ownership and
growth tests in both GC modes. See [storage status](../../libgc/PORT_STATUS.md).
This does not provide Heap roots, cross-heap members or collection. V ownership
adaptation and the complete resource-lifetime/collection audit remain open.

`main.v:1203` uses stbi for image decode. Native video decode calls
`avformat_open_input` (`native_capture_darwin.m:159`). These do not translate
BMP V5 profile handling (`Libraries/LibGfx/ImageFormats/BMPLoader.cpp:796`) or
the complete Matroska streaming reader (`Libraries/LibMedia/Containers/Matroska/Reader.cpp`).
MSE's own WebM append parser has overlapping but narrower responsibility.
Reusing a backend is not automatically a logic defect; complete strict
translation/parity of these libraries has not been established.

### EX-04 — Intl formatting pipelines remain dependencies, not implementations

LibUnicode contains date/calendar pattern construction and numeric formatter
configuration (`DateTimeFormat.cpp:198`, `NumberFormat.cpp:300`). V's
`libjs/number_locale.v:8` and `libjs/bigint_locale.v:8` retain externally supplied
NumberFormat constructor/format callbacks. The production realm does not
initialize Intl in the translated LibJS realm. The default browser uses
JavaScriptCore, whose own Intl objects are separate from this V translation.
ICU case-mapping and normalization bridges cannot supply these formatting
responsibilities merely because both use ICU.

### EX-05 — V HTTP calls replace the RequestServer pipeline

`Services/RequestServer/Request.cpp:441` creates a Fetch Request with disk-cache,
credentials, resolver, transfer lease and curl-multi dependencies. The source
handles request lifecycle, wire timing, substitution and back pressure.
`main.v:828` and `:870` call `vhttp.fetch`; these calls explicitly disable
HTTP/2 and impose local timeouts. Other root transport helpers and `fetch/`
models exist, but no source-equivalent RequestServer Request state machine
was found. This is a confirmed backend/architecture replacement, not a claim
that every V HTTP request fails or every policy is absent. The web API report
separately checks policy integration in the actual translated Fetch path.

## Excluded tests and harnesses

The following large C++ sources are inventoried for completeness and **were
not audited for faithful test/harness translation**. Their absence as V tests
is not counted as an omitted production algorithm. The repository has focused
V tests and upstream corpus/screenshot tools; those are not a one-to-one
translation of every upstream harness.

<!-- The exact tracked test inventory follows. -->

| Upstream test/harness source | Lines |
| --- | ---: |
| `Tests/AK/TestString.cpp` | 1,634 |
| `Tests/AK/TestTime.cpp` | 1,038 |
| `Tests/AK/TestUtf16String.cpp` | 1,318 |
| `Tests/Compositor/TestContextState.cpp` | 1,529 |
| `Tests/LibDevTools/TestDevToolsProtocol.cpp` | 5,393 |
| `Tests/LibGfx/TestImageDecoder.cpp` | 1,078 |
| `Tests/LibJS/test-bytecode-cache.cpp` | 1,157 |
| `Tests/LibJS/test-debugger.cpp` | 1,012 |
| `Tests/LibMedia/TestCodecConfigurations.cpp` | 1,074 |
| `Tests/LibMedia/TestParseMatroska.cpp` | 1,155 |
| `Tests/LibWeb/TestStyleValueEquality.cpp` | 2,457 |
| `Tests/LibWeb/TestWrapperWorld.cpp` | 1,056 |
| `Tests/LibWeb/test-web/main.cpp` | 1,447 |
| `Tests/LibWebView/TestOmnibox.cpp` | 1,153 |
| `Tests/LibWebView/TestSessionHistory.cpp` | 1,348 |
| `Tests/LibWebView/TestSessionHistorySnapshotStorage.cpp` | 1,324 |
| `Tests/LibWebView/TestSessionStore.cpp` | 1,411 |
