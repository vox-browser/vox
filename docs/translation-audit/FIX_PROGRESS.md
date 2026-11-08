# Audit fix progress

Tracks implementation against the historical audit of 2026-10-02, upstream `963d46a829f3e1b79f44dba9d02afb70654300fa`. Each completed translation slice receives a focused implementation-and-test commit. Findings stay open until all their stated omissions are addressed; a supporting slice does not close a broad finding.

Current ledger: **32 fixed, 25 partial, 9 open** across 61 core findings and five source boundaries. “Fixed” refers to the stated model or binding scope in the evidence column; it does not certify whole-browser source equivalence. Finding counts are not a percentage of remaining implementation effort.

The earlier audit ran ten assignments in waves with four concurrent agents including the coordinator. Root reviewed and integrated private fixes and ran shared checks. This continuation works in the canonical checkout; the historical assignment table below does not report live workers. Existing untracked work is excluded.

| Assignment | Findings | Status |
| --- | --- | --- |
| 1. Streams, storage and scheduling | WA-05, WA-09, WA-10, WA-13 | First-wave fixes integrated; remaining findings open |
| 2. CSS fonts, matching and observers | SP-05, SP-06, SP-07, SP-08, SP-09, SP-10, SP-12 | First-wave fixes integrated; remaining findings open |
| 3. LibJS intrinsics, primitive references and Math | JS-02, JS-04, JS-06 | First-wave fixes integrated; remaining findings open |
| 4. DOM, forms and events | DN-01, DN-04, DN-05, DN-06, DN-07, DN-11, DN-12, DN-13, DN-19, DN-20, DN-21 | First-wave fixes integrated; remaining findings open |
| 5. Navigation and HTML lifecycle | DN-02, DN-08, DN-09, DN-14, DN-15, DN-16, DN-17, DN-18 | First-wave fixes integrated; remaining findings open |
| 6. Canvas, layout, animations and view transitions | DN-10, SP-01, SP-02, SP-03, SP-04, SP-11, SP-13, SP-14 | Active |
| 7. Fetch, XHR, Page and diagnostics | WA-03, WA-04, WA-06, WA-07, WA-08, WA-16, WA-17, WA-18, EX-05 | Active |
| 8. Crypto and WebGL | WA-01, WA-02, WA-14, WA-15 | Active |
| 9. Wasm, platform and source boundaries | WA-11, WA-12, EX-01, EX-02, EX-03 | First-wave fixes integrated; remaining findings open |
| 10. LibJS execution, remaining builtins and Intl | DN-03, JS-01, JS-03, JS-05, JS-06, JS-07, JS-08, EX-04 | First-wave fixes integrated; remaining findings open |

JS-06 was split: assignment 3 owned Math; assignment 10 owned JSON, Date and Temporal. At that checkpoint the coordinator completed the DN-11/DN-12 checkpoint/rendering findings, DN-17, WA-18 and supporting DN-19 construction state and handled global services and integration. All ten assignments launched in that earlier session.

| Finding | Audit description | State | Evidence |
| --- | --- | --- | --- |
| DN-01 | Raw inline event handlers become inert callbacks (High) | Partial genuine raw Window compilation `7f20bef4`, `0c66f7d5` | The inert callback has been removed. Disabled scripting or an unavailable/unsupported real compiler preserves raw state; syntax errors set the value to null while retaining the activated listener. Actual Window handlers compile lazily in the owning engine global environment, with source parameter lists, relevant settings and creation-context ordering. Native invocation retains ErrorEvent arguments, BeforeUnload reasons, strict cancellation and original exception reporting. Canonical compiler/EventTarget/invocation checks pass 3/3 files with GC disabled. The Source Node overload now reads current-Document settings after adoption (`9a77696a`), correcting the unsupported creation-settings retention in `51f7d87b`. Actual owning Page preference, exact WebUI exemption and sandbox flags are retained; parser/adopted raw-handler regressions exercise the current compiler owner. See [corrected Source mapping](NODE_SCRIPTING_CURRENT_DOCUMENT.md). Actual can-run checks use Document fully-active state separately. The helper/owner/environment/handler batch passes 9/9 files canonically with GC disabled. Source Window virtual dispatch (`822b4965`), all 118 native Window handler accessors (`6e49448f`), complete raw HTMLElement attribute mappings (`269f8847`) and actual Document/Window readiness dispatch (`5ec2f6c6`) now preserve owning handler maps and event identity. Document activity uses the actual Navigable active-document identity (`a70ff720`); static parser-created body handlers start the existing runtime without a synthetic script (`5ee13194`). The initial native readiness and attribute snapshot passes its 14-file canonical GC-disabled batch; later static-startup/activity paths pass the 17-file batch. Source TemporaryExecutionContext now cleans up script execution before callback execution, retaining the outer incumbent during checkpoint jobs (`268dae29`). WindowModel now shares the dispatch record's actual current-event slot (`e78a5f51`). Native Window.event uses that slot and exact event-wrapper identity, Source Replaceable assignment/deletion, receiver checks and the pinned own-global accessor location (`be13fb4f`); nested exceptions and actual shadow-tree rules have passing regressions. See [native current-event binding](NATIVE_WINDOW_CURRENT_EVENT.md). Element document/form/element object environments, full UTF-16 handler source storage and LibJS VM/function ownership remain open. See [raw handler boundaries](RAW_WINDOW_EVENT_HANDLERS.md). |
| DN-02 | Intercepted navigation continues normal navigation and finishes synchronously (High) | Partial actual Window interception `6ce03957` | Source push/replace/reload commits use the actual Window Navigable and session history, stop normal firing, adopt owning callback promises and finish only after all handlers. Original rejection values, abort/supersession, document activity, reentrancy and zero-handler timing retain the source order. Nine actual-history and two native engine cases pass; both new files also pass canonically with codec neighbors. Intercepted traversal, HistoryExecutor/process requests and public Navigation bindings remain open. The pinned transition committed promise remains pending as in source. See [interception boundaries](NAVIGATION_INTERCEPTION.md). |
| DN-03 | Module linking is represented by a boolean after a fetch walk (High) | Open |  |
| DN-04 | Form submission uses a reduced entry-list algorithm (High) | Fixed typed entry construction `f8afc79b`, `d29bf4f6`, `085c8dd7` | Source tree-order associated membership, checked/disabled/datalist gates, select options, real FileList/File identity, named/unnamed image coordinates, custom-element lists/files/null, charset and dirname. A live bubbling FormDataEvent mutates the returned clone while recursive construction returns null/throws in XHR. Submission and credential callers use the nullable operation. Eleven focused/neighbor files and four final scalar/File/submission files pass; four input-file identity/selection/reset files pass. Legacy base-control and array APIs remain explicit typed adapters; compact JavaScript FormData/event object exposure is outside this completed model slice. |
| DN-05 | Form reset bypasses the implemented control reset algorithms (High) | Fixed concrete controls `8e2a5634` | Snapshot associated membership, concrete input/textarea/select/output reset and retained model synchronization; custom reaction runtime tracked under DN-07. |
| DN-06 | Submit events lose their submitter interface (High) | Fixed `afe3779c` | SubmitEvent interface, button/null submitter, cancellation and legacy bypass; existing form tests pass. |
| DN-07 | Form-owner lookup skips an earlier non-form with the same ID (High) | Partial `0f325e2b` | First-ID tree-order/HTML-only lookup fixed with duplicate-ID/live reassociation tests; custom reactions remain open. |
| DN-08 | Image decode omits active-document checks and initial asynchronous ordering (High) | Partial source lifecycle and native capability `f3e6cd39`, `869894f3`, `db235d16`, `31af7adb` | The actual owning HTML request settles one WebIDL capability through its microtask and DOM-task queues, checking document activity and request identity. Native decode now returns the actual engine Promise and retained EncodingError, including detached script-created image records; the resolved-Promise stub is removed. Lifecycle/adoption, five native cases, two main image cases and full main pass with GC disabled. Retained SVG painting cache invalidation (`46fa572c`) passes the real-frame production-path regression; the rebuilt native bundle passes all nine targeted SVG/selection comparisons pixel-exactly. Actual SVG decoded request ownership, asynchronous codecs/transport, weak GC disappearance and full LibJS Promise integration remain open. See [image binding boundaries](../../IMAGE_DECODE_BINDINGS.md). |
| DN-09 | Input pattern compilation substitutes V regex semantics (High) | Fixed source HTML algorithm `96024859` | Actual translated LibRegex C++ wrappers (`42517124`) reuse byte-exact repository-owned copies of the pinned Rust backend (`dc13e926`). Original-pattern compilation precedes UnicodeSets noncapturing anchors; empty/inapplicable states and multiple-email split views follow source. New and existing input files pass with GC disabled, and new input/wrapper files pass with default GC. An assertion-independent production probe also passes. Rust execution reuse is explicit; full V regex VM, LibJS runtime RegExp and arbitrary UTF-16 DOM storage remain outside this slice. See [wrapper translation](../../libregex/PORT_STATUS.md). |
| DN-10 | Canvas path rasterization drops paint-style, blur, filter and stroke semantics (High) | Partial `4e74b8cc`, `722aeb9c`, `024e0071`, `80f3d530`, `43d6238a`, `39333cfc` | Source Canvas/PainterSkia dispatch replaces distance approximations for actual gradients/patterns, curves, stroke caps/joins/dashes, composites, shadows and resolved filters. Nine pixel regressions and existing canvas files pass in canonical integration. Bitmap clearing/drawing now preserves source Skia transforms, clips, filters, sampling and alpha; ImageData converts native premultiplied pixels. Synchronous JSC Canvas host/wrappers now invoke actual HTML records; six focused public-script tests pass and a production `-prod -gc none` executable verifies drawing survives assertion stripping. Native top-down presentation is preserved. Browser integration/screenshots are in progress; non-macOS native Skia linking is not validated. |
| DN-11 | Microtask checkpoints omit their final cleanup steps (High) | Fixed translated checkpoint `107380ea`, `888b5bd8`, `ebe5c6e1` | Related-global rejection notifications after microtask draining; actual owning-loop IndexedDB deactivation/queued commits; bound LibJS VM generation after cleanup. Five focused checkpoint/IDB files pass. JavaScriptCore remains the browser's default backend; this does not claim complete LibJS execution or Promise parity. |
| DN-12 | Rendering uses registration order and drops two document filters (High) | Fixed source rendering and native frame delivery `2eb5d6e2`, `97040ede`, `a0271053`, `5f11f904` | Upstream container-before-child DFS/cache invalidation; actual PageClient rendering opportunity, view-transition suppression and per-stage document loops. Native display grants now reach the Page's actual local-root navigable and queued rendering task. Owning Window animation frames use the source snapshot/cancellation semantics and monotonic response/navigation time origin. Native frame, full main and rendering-order checks pass. See [frame binding boundaries](../../ANIMATION_FRAME_BINDINGS.md). |
| DN-13 | Element client geometry omits root/quirks and inline exceptions (High) | Fixed `0f97f85c` | Standards root/quirks body viewport dimensions, inline/no-box cases and live visible borders; actual layout regressions pass under the default module path. |
| DN-14 | Media seeking and timeupdate use different algorithms (High) | Fixed existing commit `e7ba9673` | Current source exits empty seekable ranges before queuing seeking and throttles queued timeupdate by monotonic wall time. Coordinator verified all three media test files, including empty-range, seek ordering and wall-clock regressions. |
| DN-15 | Navigable scroll promises always resolve after an instant change (High) | Partial actual scrolling and ancestor caller | Source smooth operations, behavior, coalesced promises, replacement, animation samples, snapping, visual-viewport splitting and queued completion use the owning Navigable. The position helper uses committed retained geometry, scroll margins/padding, CSS-pixel arithmetic and the actual VisualViewport (`99eca356`). The complete ancestor caller (`e217b40c`) checks origin, projects/clips the target through inner-to-outer boxes, honors the container stop and adopts actual scroll capabilities. Document-owned Promise contexts preserve the source realm and wait-for-all ordering (`337ec0a6`, `c964fac2`). DOM and Window now share one actual document-owned VisualViewport (`e8fb0465`). Fractional pinch offsets preserve source arithmetic without intermediate rounding (`c2659b7d`); actual affine coefficients, inverse and native point rounding use the source float/integer boundaries (`bab842d5`). Canonical native primitive and viewport transform/fractional/resize/owner checks pass with GC disabled. Focused caller/geometry/ownership checks pass canonically. Compositor transport, user-input settlement and compact JavaScript scroll exposure remain open; pinned source direction/snap and visual-viewport settlement FIXMEs are retained. See [caller](SCROLL_INTO_VIEW_CALLER.md), [Promise ownership](SCROLL_PROMISE_OWNERSHIP.md) and [viewport ownership](VISUAL_VIEWPORT_OWNERSHIP.md). |
| DN-16 | Live local-link media changes do not refresh the installed sheet (High) | Fixed `a3129ce6` | Loaded CSS sheet identity survives media changes and cache hits; CSSOM edits retained. Four focused/existing test files pass. |
| DN-17 | Structured cloning loses resizable ArrayBuffer capacity (High) | Fixed `3cd450b7` | Resizable capacity, byte-copy independence, storage, tracking view identity, malformed records; focused and existing structured clone tests pass. |
| DN-18 | Window.find counts DOM source text without selecting a rendered match (High) | Fixed DOM/Page and native binding `cdf2ee85`, `b37beb41`, `d25d9d68` | Source rendered layout search builds live mapped UTF-16 ranges, excludes hidden/inert/generated content, preserves whitespace/transform/first-letter mapping, and delegates Window.find to Page selection with no wrapping or selection clearing on failure. Four rendered-search and four actual-Window ownership/selection tests pass, with eight neighboring files verified across the test-fixture correction. The native global now exposes the pinned one-argument optional DOMString operation through its actual owning Window/Page (`d25d9d68`), replaying coercion mutations before rendered search and preserving receiver checks and native method metadata. Four native cases pass in both GC modes; the integrated main-file regression passes canonically with GC disabled. Arbitrary lone-surrogate DOM storage remains a wider representation boundary; legacy SearchDocument fixtures retain their separate adapter. See [native source binding](NATIVE_WINDOW_FIND.md). |
| DN-19 | Direct navigation document construction drops supplied sandbox flags (High, entry-point scoped) | Partial `7710ab3a`, `f8d8f5ae` | Flags/about-base/navigation-ID/policy pointer copied; real HTML global registry factory installed and tested. Actual Page ownership is installed before native document initialization and parsing (`9e008b7c`), preserving constructor-time font ownership, final navigation URL and nested context preference. Actual ClassicScript, module-script and compact per-source execution gates are translated (`b170760f`, `bec2f2f3`, `f7abb961`). The canonical Page/Classic/Crypto owner batch passes 11/11 with GC disabled; module and compact gates also pass the subsequent 13-file canonical batch. WindowModel now reads the actual native Window document association (`8b7dd6ca`), including responsible settings and navigation snapshots; reassociation and pre-document construction have focused regressions. UniversalGlobalScope captures that association when queuing microtasks and rejection tasks (`e2ad253d`), while Worker tasks retain no Document. Native and typed activation gates share the actual timestamp, Source infinities and document-relative clock (`bc4cc320`). Trusted event dispatch now timestamps activation with the actual associated Document clock (`c51c1067`); [clock regressions](TRUSTED_ACTIVATION_CLOCK.md) cover cancellation, filtering and reassociation. Actual BrowsingContext and WindowProxy now share the native active-window slot (`6c5efedf`), and activation consumption follows logical Navigable descendants and their actual active Windows (`e91f30df`). Input and select picker gates use current-Document relevant settings, actual Window activation and native consumption in Source order (`724e86e2`, `379ae339`); adopted-node overload and trusted-event regressions are pinned separately (`daa08d06`). See [input ownership](INPUT_PICKER_GLOBAL_OWNERSHIP.md) and [select ownership](SELECT_PICKER_GLOBAL_OWNERSHIP.md). Window cross-site ancestor settings now follow the logical parent Navigable and actual active-document settings/origin (`9915d0ec`); [owner regressions](CROSS_SITE_ANCESTOR_OWNERSHIP.md) cover disagreeing cached contexts and temporary reassociation. Window length/indexed child proxies use the associated Document child-navigable tree (`be62aea8`); top/parent use logical Navigable ancestry and actual active native proxies (`d98d68dd`). Window.closed shares the actual local Navigable closing flag (`c5162dc5`), and Document beforeunload dispatch uses actual Window ownership and the pinned sticky-activation/sandbox/WebDriver prompt decision (`e7af3c96`). Prompted close resets a canceled attempt and appends close steps once (`c270d489`). Phase-2 unload tasks remain runnable with no Document association and skip destroyed/inactive Documents inside the task (`a2099007`). Traversable current/active entries share the actual registered local Navigable owner (`1d11f090`); the bare-host adapter keeps separate slots. The unload-check gate now compares target/current entry identity and exact optional-origin equality (`51ad893b`); phase one queues through the actual active Window/global and re-reads the actual Document and Window Navigation during execution (`fda2a295`). Queue-time associations and handler-driven proxy retargeting have genuine regressions. The Source 15000 ms deadline now uses the actual platform Timer and stops before completion (`e23a5bce`); the full callback retains the initial/final typed prompt-shown state (`ea1d216b`). The core accepts actual native Navigable vectors and captures active Documents at invocation (`1427dd93`); prompted close collects that vector from its current actual Document (`928e715f`). Result-only projection follows the separate Source overload; older Document-list/bare-host adapters remain explicit. The destroyed-state flag now belongs to the same actual native Navigable through retained models and registry removal (`04e5bb4d`); full destruction setter side effects remain open. See [active task owners](UNLOAD_CHECK_ACTIVE_WINDOW_OWNERSHIP.md), [timeout](UNLOAD_CHECK_TIMEOUT_OWNERSHIP.md), [vector](UNLOAD_CHECK_NAVIGABLE_VECTOR.md) and [prompted close](TRAVERSABLE_PROMPTED_CLOSE_OWNERSHIP.md). Full forced-close/HistoryExecutor/UI teardown and policy/realm environment integration remain open. See [task document ownership](UNIVERSAL_SCOPE_DOCUMENT_OWNERSHIP.md), [activation identity](WINDOW_ACTIVATION_IDENTITY.md) and [Page creation](PAGE_DOCUMENT_CREATION_OWNERSHIP.md) and [module gates](MODULE_SCRIPT_SETTINGS_GATES.md). Actual local active-context/proxy/Window getters now follow the current native Document owner (`bc0d0d7d`); an unconditional identity guard survives production builds (`33afd7b8`). The UI close entry queues a null-associated NavigationTraversal task that reads and unloads the current actual Document (`66c87a24`). Source full context construction and UI/group/HistoryExecutor teardown remain separate. See [actual context owners](NAVIGABLE_ACTIVE_CONTEXT_OWNERSHIP.md). |
| DN-20 | Global exception reporting replaces ErrorEvent and changes omitError behavior (High) | Partial `0b0ce715` | Real cancelable ErrorEvent, omitError nulls only the value, active classic-script muting, recursive console fallback and worker PageClient/owner task delivery. Five focused/existing files pass. Full VM/JSC object-and-stack metadata extraction remains an explicit runtime boundary; a realm extraction callback supplies the existing ErrorInformation algorithm. |
| DN-21 | Global service getters return empty facades (Medium, API integration) | Partial `41b4e1ee`, `9df25af3`, `e59b028d`, `16cb5cd1`, `9bd83457`, `18af86da` | IndexedDB, Crypto, CacheStorage, Trusted Types and Performance getters expose actual translated objects with stable per-global identity; owning-loop IDB/Crypto tasks and worker independence pass integration tests. Trusted Types uses live owning CSP and its global default policy reaches real DOM HTML sinks. Performance reads real owning settings and current Window document timing, queues observers and resource-overflow events on the owning loop, preserves native entry identity and shares the actual global buffers. Four actual-global regressions plus six neighbor files pass. Actual Fetch ResourceTiming construction/global buffering now binds through `2683aaf3`; full navigation timing entry construction and JavaScript global bindings, LibJS Promise binding and CacheStorage asynchronous parity remain open. |
| SP-01 | Live view transitions do not populate or render captured elements | Partial live source `8818fc66`, compact binding `f2bcdc46` | Actual DOM/layout capture records and source CSSOM rules now reach compact JSC callbacks, same-object promises, active getters and skip operations. Callback mutations replay into the actual DOM before new capture; arbitrary and cyclic JS rejection identities remain in JSC. Four compact fixtures plus full main and native headless checks pass. Pinned upstream capture is a blank 1x1 image, animation activity is false, and its pseudo tree has no layout/paint consumer; those source TODOs remain explicit. |
| SP-02 | `Animation.cancel()` loses cancel-time capture and invalidation | Fixed `8cb7857b` | Preserves current upstream cancel-time capture order, clears stale capture, and invalidates target/compositor state; animation regressions pass. |
| SP-03 | Finish notification resolves immediately and uses the wrong event time | Fixed `ee2257cb` | DOM-manipulation task completion, notification recheck/de-dup/cancellation and timeline-to-origin event time; three animation test files pass. |
| SP-04 | The Web Animations `KeyframeEffect` drops custom-property keyframes | Fixed V DOM/style path `f8a8d2ac` | Case-sensitive custom keyframes, underlying boundary values, registered-property interpolation and additive live effect stacks; focused/existing animation and generated CSS tests pass. Compact native JavaScript bridge still lacks Element.animate binding. |
| SP-05 | Manually created `FontFace` objects always register a normal slope | Fixed `e2ef1376` | Manual FontFace normal/italic/oblique matching and setter re-keying. |
| SP-06 | URL font loading completes synchronously | Partial actual Fetch, WOFF2 workers and native FontFace bindings | Actual Curl Fetch transport, file/CORS policy and navigation origin precede parsing. FontLoader retains its load-event delay and in-flight guard through MIME/WOFF/WOFF2 dispatch and URL fallback. The source four-worker FIFO returns completion to the owning loop. Actual native constructors, stable loaded/ready Promise wrappers, FontFaceSetLoadEvent frozen arrays and source environment readiness gates are integrated. Typed Document.fonts shares the same actual CSS/EventTarget record (`32909c48`); three getter cases pass with GC disabled. Native EventTarget and font-event integration checks pass five and three cases. See [font source mappings](FONT_LOADING.md). Eager document/owning-realm creation ordering, Worker exposure and full VM/wrapper GC remain open. |
| SP-07 | Font matching mixes installed faces with author family faces | Fixed `95be0742` | Installed Arial versus registered nonexact-weight author face. |
| SP-08 | Dashed CSS function lookup omits layers, origins and enclosing scopes | Fixed lookup `2848d0d0` | Function rules retain source origin/layer metadata in shared style caches. Lookup selects document UA/user/author origins, layer rank and same-rank last definition; shadow lookup walks actual host roots and stops at ordinary detached roots. Nested calls use the calling definition scope through guarded function identities, preserving upstream top-level element-scope FIXME. Three focused live/cached cases plus existing evaluation and stylesheet invalidation files pass; no Rust compiled-function/backend parity claim is made. |
| SP-09 | Quirks-mode class/ID candidate lookup does not fold case | Fixed `8bd4532e` | Quirks bucket/matcher/hash folding and constructed-sheet cache isolation; focused and existing adopted-sheet tests pass. |
| SP-10 | CSS image observation omits cursor/border images and reverses replacement order | Fixed `0ea69936` | Background/mask/cursor/border/list sources, distinct per-slot client identities, register-before-release replacement and actual layout-detach cleanup; focused and existing image/node tests pass. |
| SP-11 | Styled `::first-letter` has no translated layout construction | Fixed `102752aa` | Upstream matching/traversal/placement, styled slices and pseudo ownership, live text/style invalidation, full-source ICU casing/edit mappings through ranges/carets/hit testing. Ten real-layout regressions, two ICU mapping tests and neighboring paint/caret/text/DOM tests pass; native bundle rebuild passes. |
| SP-12 | Computed pseudo custom-property lookup lacks originating-element fallback | Fixed `cf04b760` | Live shadow-slot pseudo custom property inheritance and own override tests pass. |
| SP-13 | Portable shadow replay uses sharp/rectangular approximations | Partial source replay `1108540d` | Rectangle strips and sharp glyph fallbacks are removed. Source Skia commands retain Gaussian blur, elliptical radii, difference paths, transformed rounded/path clips and actual glyph/font identity with one color alpha. Native and layout adapter tests pass. Portable SVG luminance/content masks and group composition remain at the broader isolated-layer pipeline boundary; non-macOS native Skia linking is not validated. |
| SP-14 | View-transition dynamic rules are replaced instead of updated as upstream | Fixed typed source `5d2c5e9f`, `8818fc66` | Standalone and live CSSOM rules retain object identity, update only their selector as upstream, preserve declaration values, refresh retained images and remove owned rules on cleanup. Actual CSSStyleSheet and capture fixtures pass. |
| WA-01 | Upstream cryptographic operations are explicit unavailable-backend stubs | Partial native algorithms, formats and actual script bindings | Registered families reach actual native backends. RSA, EC, Edwards, ML-KEM/ML-DSA, KDFs, HMAC, cSHAKE/KMAC and AES/ChaCha have source-vector/format coverage. Actual native Crypto binds random views, UUID and all 16 pinned SubtleCrypto methods, including all 24 registered generation names, all 29 registered import names, export, ciphers, signatures, derivation, wrapping and KEM; actual CryptoKey records retain their mutable algorithm and frozen usages caches. Source lexical JWK getter/result order and optional dictionary members are preserved through class validation. Canonical focused checks pass; the earlier agent Crypto/WebIDL batch passes 56/56. Full LibJS realm/value integration, native scheduling and the wrapper GC graph stay open; source ML-KEM JWK retains its TODO. See [native binding status](NATIVE_CRYPTO.md) and [Crypto status](../../webcrypto/PORT_STATUS.md). |
| WA-02 | SubtleCrypto Promise/task behavior is replaced with synchronous typed results | Partial owning typed operations and all native method Promises | All 16 pinned methods use the owning service, actual engine capabilities and source crypto settlement tasks. Original getter/conversion exceptions, generated IDL order, separate derivation snapshots, wrapping fallback, JWK parse order, deferred class errors, byte copies and native result identity have focused checks. Full LibJS Promise/TemporaryExecutionContext, source task scheduling and the wrapper GC graph remain open. |
| WA-03 | Shared Fetch omits CSP, mixed-content, and integrity policy gates | Fixed shared Fetch path `895d087a` | Actual HTML client policy projection, source-ordered report/upgrade/block gates, response checks and document-target CSP events. Eight integration regressions and Fetch/CSS/environment/mixed-content tests pass. |
| WA-04 | Shared Fetch does not determine the request referrer | Fixed `c048e4e1`, `428547cd` | Shared Fetch applies the upstream referrer algorithm before dispatch and redirects; unique top-level core resolves default V compiler lookup. Referrer/Fetch tests pass. |
| WA-05 | IndexedDB opens/upgrades bypass connection queue and version-change coordination | Fixed `4798ceb6`, `41b4e1ee`, `9df25af3` | Connection/version-change queues bind to the owning HTML database task source. Actual RequestList completion queues transaction events before open success; tests cover pending requests and complete-listener task ordering. Package and global-binding tests pass. |
| WA-06 | Internals layout-tree dumping returns a marker instead of inspecting layout | Fixed `884f756b` | Internals forces real debugging layout and dumps retained requested subtree, with no-layout handling. Focused layout dump test passes. |
| WA-07 | Page EventHandler DOM pointer/click/activation algorithms are log operations | Partial `db384e24`, `012ae8c0` | Native viewport hit targets route trusted pointer/mouse/click events through actual DOM dispatch, cancellation and retained transform/scroll geometry; source hover batches preserve common ancestors. Five focused/neighbor files and native smoke pass; source no-hit pressed-move delivery preserves captured native resize input, with focused pointer and complete main-file regressions passing. Nested navigable routing, drag/default-selection and compact JSC pointer listener bindings remain open. |
| WA-08 | Page load/reload methods update logs instead of invoking navigation | Partial `a55aebd3` | Actual Page local-root load/load_html/reload callbacks reach HTML NavigableModel with history/resource/navigation-ID and null-source BrowserUI snapshots. Four focused/neighbor files pass. Native BrowserApp asynchronous navigation adoption and complete navigation continuation parity remain open. |
| WA-09 | Streams underlying callbacks cannot remain pending | Partial actual callbacks, owner jobs and native Promise identity | Readable/Writable/Transform factories and readers/writers/controllers use owning records and actual callback values; their generated constructor prototype/dictionary conversion order is corrected. Raw size callbacks reject non-numbers without coercion and retain the same actual RangeError through synchronous throw and reader/writer rejections. Public pipeTo/pipeThrough use actual source records and DOM AbortSignal, preserving default AbortError identity (`1e430b89`). Tee clones before either enqueue and errors both branches before adopting pending source cancellation; the shared cancellation capability begins one-shot native adoption immediately (`2e92db4a`, `115b54e6`). All 35 canonical Streams files pass with GC disabled. Native Count/ByteLength strategies retain source cached callable identity and use actual non-constructible native functions with source name/length metadata (`53c76cee`, `164578ca`). Stream and Abort wrappers preserve ordinary-object tags, source brand checks and generated prototype ordering. Retained source byte read-loop requests and their single pending Promise wrapper (`2d00fb5b`), plus full owning-realm byte controller setup (`62a853e9`), are now translated. Genuine native Uint8Array witnesses reject proxies/spoofs and ignore author slot shadows (`373ad1f7`); the internal byte enqueue path preserves Source empty-chunk behavior (`fd912959`). Blob reading uses the responsible Window/Worker file-reading task and Source execution context (`b58cb21f`), and Blob.text follows the actual pending byte Promise and Source BOM decoder (`152c5a9c`). Native byte aggregation now allocates its owning engine ArrayBuffer before Promise settlement (`841cdd0b`, `560f1de6`), with actual shared-buffer Uint8Array views. Blob stream/read/text carry the explicit actual engine realm (`88c92caa`), and Blob.arrayBuffer copies its raw read-all result into a second owning buffer as Source does (`4bd00540`). Blob.bytes creates its owning Uint8Array over the exact read-all buffer (`4aa9b964`). Actual native Blob records now own Source size/type/slice/stream/text/arrayBuffer/bytes methods (`bcfd56a3`) and exact accessor/method metadata (`e0066741`). The generated constructor preserves Source prototype, sequence, union and dictionary order and actual buffer slots (`4f376a7d`); actual-global exposure ignores author globalThis aliases (`77850e77`), and actual immutable Blob records project through the Source IPC/storage codec into newly owned target records (`5a9dba71`). Actual Blob methods and constructor are installed before native scripts (`7a4cdd27`), and XHR response/send use the cached actual Blob record rather than author-visible metadata (`85000068`). Actual File and its embedded Blob share one wrapper (`db43e871`); generated File construction preserves sequence/name/inherited-dictionary order and delayed buffer copying (`c7f2205d`). File clones classify the actual native record before its Blob base and preserve exact Source IPC/storage payloads (`7fca4653`). Actual File binding/constructor are installed before native scripts (`af164b8f`), with actual embedded Blob ownership, clone payload and three pending read Promises exercised by the startup regression. Actual FileList records retain live indexed properties, cached File identity, Source nonconstructible interface behavior and exact primary clone payloads (`16d5d64a`, `94e9adbc`, `e12f91c5`). Typed input producers preserve actual cached lists, generated nullable setter conversion and picker mutations (`beefdd7e`); the actual interface installs before document scripts (`d365aeed`). Raw drag-store UTF-16 slots (`e017ff20`), Source UTF8/WTF8 byte helpers (`68deba04`), File byte-name construction (`ca9336b6`) and actual DataTransfer File/FileList producers (`58b55b7f`) preserve Source fresh records, mode gates and default File options. Bounded native DataTransfer File/FileList adapters now preserve actual record identity and Source brand conversion (`3764464e`). FileReader tasks capture actual creation-global settings and queue-time associated Documents (`68997338`), with actual loop IDs, affiliated-task removal and event timestamps. Text BOM/replacement decoder, BinaryString code-unit packaging (`892933ce`) and the genuine data-URL record helper (`d08a66e0`) are translated; the full FileReader asynchronous stream/read state, public reader/input/DataTransfer receiver bindings, cross-runtime newTarget fallback and complete Worker/wrapper ownership remain pending. Full native owner graphs remain unfinished; see [read-loop ownership](READ_LOOP_BLOB_SOURCE.md). Public tee needs the actual opaque engine-object serializer; BYOB transfer/views and wrapper GC remain open. See [callback status](STREAMS_PENDING_CALLBACKS.md). |
| WA-10 | WritableStream close sentinel collides with a normal string chunk | Fixed `4b8ca372` | All 12 Streams test files; private sentinel collision regression. |
| WA-11 | WebAssembly validate/compile skip core sections and validation | Partial complete pinned validation and machine foundations | Every core section, all 499 pinned instruction parse cases and all 500 validator specializations dispatch into source bodies. Machine values/stacks, traps/results, actual Store globals/segments/tags/exceptions, caged memory ownership, Module owner tables, machine tables, source numeric/Table64/i64 bindings, exact BigInt extern identities, complete import records/linker, instruction storage and compiled publication records are translated. Actual Configuration owns registered stacks, frames, labels, registers and Store routing. Module compilation coordination (`c22bd999`), cached local counts (`34fd14b4`), compiled-function tables (`f6e43133`), inline arguments/freelists (`48b3ce4a`), frame installation/unwind (`3f686bf8`) and Store call preparation (`6353f74d`) have source regressions. Host calls now borrow the actual writable argument span without copying and retain captured function ownership (`d513a2d3`). Configuration call/execute/compiled-call translate Source trap/result/label ordering through the explicit Interpreter interface (`1abb2982`); focused recording interpreters are test doubles, not production opcode backends. The Source stack-space calculation (`09de70ed`) and BytecodeInterpreter trap/native-stack/visitor state (`9ec83ed2`) are translated. The integrated package passes a clean **80/80 canonical files in each GC mode**. The scalar integer Divide/Modulo and unsigned rotation specializations (`b5ae85be`) match 3,264 exact pinned C++ results in both GC modes; [integer operator mapping](WASM_INTEGER_OPERATORS.md) documents the Source checked arithmetic and corpus tooling. Source numeric helpers preserve actual operand routing, slot writes and error/trap order with supplied concrete Value operator adapters (`9a9aaf30`); see [numeric helper mapping](WASM_NUMERIC_OPERATIONS.md). EqualsZero and all scalar CLZ/CTZ/PopCount specializations (`7d0af709`) match another 1,656 exact native results; see [unary operator mapping](WASM_UNARY_INTEGER_OPERATORS.md). The earlier 80-file canonical sweep predates those three new tests. The subsequent frozen `f28d34eb` worktree passes 83/83 in each GC mode; newer canonical focused checks pass independently. Scalar shifts (`1897fa01`) match another 5,760 exact Source C++ results, and twenty signed/unsigned integer comparison specializations (`38052bee`) match 2,880. Actual helper regressions retain Source operand/result types and slots; see [shifts](WASM_SCALAR_SHIFTS.md) and [comparisons](WASM_INTEGER_COMPARISONS.md). Twelve wrapping-arithmetic/bitwise specializations (`54308045`) match 1,728 exact native results; twelve float/double comparisons (`a1cf813d`) match 3,072, including NaN, signed zeros and subnormals. Actual helper writes retain Source operand and result types. See [arithmetic](WASM_INTEGER_ARITHMETIC.md) and [floating comparisons](WASM_FLOAT_COMPARISONS.md). Eight floating arithmetic specializations (`aa474918`) match 2,048 exact native result-bit cases; six floating extrema/sign-copy specializations (`b10f59ce`) match 1,536. The fourteen floating unary specializations (`ab928857`) match 1,568 exact native result-bit cases across four rounding modes; see [unary mapping](WASM_FLOAT_UNARY.md). Float promotion/demotion (`b191a456`) match 272 exact native cases across four rounding modes; eight wrapping/extension forms (`cd93fa2f`) match 3,216 exact native cases. Four reinterpret forms (`2a00c71d`) preserve 576 exact native bit patterns; eight signed/unsigned integer-to-float forms (`e2f5d37c`) match 8,512 native cases across four rounding modes. See [float width](WASM_FLOAT_WIDTH.md), [integer width](WASM_INTEGER_WIDTH.md), [reinterpret](WASM_SCALAR_REINTERPRET.md) and [casts](WASM_INTEGER_FLOAT_CONVERT.md). Frozen `bbb7d729` passes a clean **90/90 in each GC mode**, using an isolated checkout of that canonical commit; that sweep predates all four new width/reinterpret/cast test files and later changes outside WebAssembly/LibJS. Canonical focused integration passes independently. Full BytecodeInterpreter opcode execution, constant-expression execution, native instruction compilation, complete AbstractMachine instantiation, collector/ref-counted roots and JS realm integration remain open. See [status](../../webassembly/PORT_STATUS.md), [frames](WASM_COMPILATION_AND_FRAMES.md), [calls](WASM_HOST_CALL_AND_EXECUTION.md) and [trap state](WASM_BYTECODE_STATE_AND_STACK.md). Eight SaturatingTruncate forms (`e725f69c`) preserve Source NaN/infinity/limit branches and its i64 edge FIXME, matching 1,312 pinned C++ records across four rounding modes; see [saturation](WASM_SATURATING_TRUNCATE.md). Frozen exact canonical `a7e4319a` now passes 96/96 in each GC mode, including both truncation files, with immutable manifests and scoped dependencies. Eight CheckedTruncate forms (`883d76ba`) preserve original-width classification/truncation and actual AK safe-cast/round-trip checks, matching 328 compiled pinned C++ results/errors. The new 95th file and conversion/helper neighbors pass 3/3 canonical GC-disabled checks. The frozen full 94-file proof predates this file; see [checked truncation](WASM_CHECKED_TRUNCATE.md). |
| WA-12 | WebAssembly instantiation fabricates exports without machine execution | Partial `cb0e85a6`, `69200ef6` | Declared/imported memory allocation, type/limit matching and export alias identity now use real Store instances and caged primitive storage. Realm-specific buffers share bytes and retain source fixed/dynamic growth and detachment behavior; cross-realm imports preserve their actual wrapper. Instance cache misses wrap the requested actual Store address (`4711dfa7`), including uncached memory growth hooks. Full machine linking/initialization and function/global/table execution remain open. |
| WA-13 | WebDriver action tick durations and queue scheduling are omitted | Fixed tick scheduling `16ca55b7` | All five WebDriver test files pass; platform timer/task delay and real pause. Browser input endpoint wiring remains open under WA-07. |
| WA-14 | WebGL has synthetic answers and no real backend dispatch | Partial native backend and public binding, latest `ea36038b`, `790f74ed`, `b2fbb603`, `dfa96b16`, `040d9fb5`, `a12bef14` | Actual ANGLE shader/reflection, uniforms/blocks, buffers/draws/raster state, texture2D/3D/array and compressed byte uploads, multisample storage/blits, framebuffer attachment reads, VAO/queries/samplers/transform feedback and CPU presentation. Native getters preserve source enum/type/count and is-object results. Compact Canvas/WebGL wrappers use real HTML owners, public typed arrays and branded same-context resources. Bitmap-source overloads use source Skia alpha/flip/size/layout conversion and live DOM frames. Actual buffer/view slots ignore shadowed author properties and defer source byte copying until after argument conversion (`520c8b85`); Float16 offsets retain their two-byte element size (`5674cecf`). Nullable uniform reflection and effective overload selection follow pinned source, including exclusion of source [FIXME] overloads and raw-buffer/view distinction. Source context/resource/extension prototypes, labels, lexical attribute dictionaries and driver query/error/program ordering now have actual native regressions. Uniform-location queries return fresh source records, and draw-buffer state changes do not invalidate canvas pixels. Wholly unavailable source [FIXME] methods have absent descriptors (`fb276b33`). The later query/reflection snapshot passes all 58 typed and 29 public/integration files with GC disabled in its isolated worktree. Actual driver shader/program/buffer parameters, fresh vertex-buffer and ActiveInfo records, owner-context selection and source buffer-binding error/state order have focused canonical evidence (`76191fee`, `e7dad6dd`, `cdf50017`, `020511ba`, `3d557d51`, `4cedeaac`). The 87-file sweep is a fixed snapshot. Later source uploads remove fabricated buffer byte caches and invented V binding gates (`de80ec9a`); indexed/VAO bindings preserve pinned retained slots (`9553dbe0`), framebuffer/renderbuffer binds retain actual owner records in source order (`dc66c005`), and textures retain actual source owning slots (`9a22bb0b`). Captured numeric/typed-result intrinsics (`61afc068`), direct renderbuffer storage (`34e3e149`) and texture parameter setters (`f44d0ff4`) remove fabricated resource metadata and preserve actual driver validation. Canonical focused upload/indexed/framebuffer checks pass in the 13-file integration batch; subsequent source texture/storage/intrinsic checks pass in the 22-file canonical batch. Source 2D byte uploads now remove texture geometry mirrors and synthetic dimension/binding gates (`6dc1fc1e`); focused native/public/nullable neighbors also pass in the 14-file canonical GC-disabled batch. Compressed uploads preserve owner/span/driver ordering (`48090ff7`); 3D byte uploads (`d7f9705a`), bitmap failure ordering (`8c30c973`), framebuffer copies (`c9d26796`) and immutable texture storage (`23b9030c`) delegate the source driver validation while removing invented geometry gates. XR compatibility now translates the source deferred selection and separate owning settlement task (`1c321be3`); the synchronous helper is removed (`f67f2e09`) and the actual native Promise binding is installed (`64fe8850`). Five canonical native XR/canvas/context-loss files pass with GC disabled; source device/policy TODOs remain. The later texture/storage snapshot passes **73/73 typed and 43/43 public/mixed files** with GC disabled privately; that 116-file sweep predates later shader/program repairs. Shader/program operations now preserve actual owner/driver ordering (`090281b3`), and six invented status/source/log caches plus eager GL queries have been removed (`32da6846`). Source shader creation retains owned records for native zero names (`7cbf3a40`), and fenceSync retains owned records for native null handles after driver rejection (`65f913e4`), with genuine typed/public regressions. Uniform-location validation compares actual optional parent-program pointers (`c572d3be`); scalar float/signed setters select the owner first and preserve Source null-location zero plus the exact GL operation (`ee01a2a2`). Unsigned scalar setters use exact native ui calls (`9701297f`); vector setters preserve owner selection before early returns (`fe630e2e`). All nine matrix shapes forward transpose to the actual driver in Source order (`c5061fc7`), removing the invented rejection. Native/public regressions pass; the frozen subsequent sweep passes 80/81 typed files and 50/50 public/mixed files, followed by the corrected legacy transpose fixture and matrix neighbor (2/2). This preserves the initial obsolete assertion and is not a claimed fresh clean 81-file sweep. Framebuffer attachments select their actual owner before Source validation and update the retained map after the GL call even on driver error (`51696269`). Attachment queries return the actual retained resource record, including after native deletion (`340fb502`); typed/public integration checks pass 2/2 for each slice. Query begin/end preserve Source retained-slot and driver ordering (`188aff3c`); deletion and returned query records retain actual identity (`25bd9bc0`, `58e11ab1`). Source object handle APIs now return actual GLuint values while compact IDs serve bookkeeping only (`d78363a7`). Attached shaders return actual retained records through the wrapper cache even after deletion or before first exposure (`4a8ceccd`). CURRENT_PROGRAM and WebGL2/OES vertex-array getters now wrap actual retained pointers, including first exposure after native rejection/deletion (`f8bcfba1`, `a1e4803f`). Transform-feedback bodies select the owner first and preserve the Source declared/reset but never-assigned binding slot (`e14d8f3d`), while real GL captures and binding queries continue to run. Sampler binding/deletion/setters and framebufferTextureLayer preserve Source owner, actual driver and retained-state behavior (`574a5773`, `b1e4770b`, `0f6dc26d`). Base/WebGL2 draws preserve actual canvas callback order around GL and omit V-only validation (`7af40344`, `0c3d51b6`); clear invokes the callback before GL (`ac1d5055`). Canvas updates retain display-list commands with Source InvalidateDisplayList::No (`1116713d`). Frozen private `2ad0138f` passes 97/97 typed and 66/66 public/mixed files with GC disabled; canonical implementation/tests match, with dependencies scoped to that private snapshot. The probe identified eager error draining; its Source correction (`a96b438e`) leaves actual ANGLE flags intact until getError, preserving local transport error, driver error and first Source validation-error priority. Nullable/bitmap uploads, activeTexture and readPixels also retain their unconditional Source commands after prior native errors (`b4487c5e`, `48dbeb86`, `8cab105c`). Canonical driver/priority/continuity checks pass 5/5. Frozen private `2355ee46` passes a clean **101/101 typed and 70/70 public/mixed files** with GC disabled; canonical package implementations/tests matched at recording, with outside dependencies scoped to the private snapshot. Subsequent Source Base error-receiver and viewport/scissor, blend, clear, raster enum/float and stencil setters preserve genuine driver calls, owner selection, IDL widths and error ordering. The unused scalar/default map is removed (`54b0317f`); Source client unpack records remain. Pixel-store now follows the exact Source switch and empty Proxy prefix (`ad9bb734`): browser-only/invalid-unpack early returns leave the actual driver owner unchanged, while final GL calls retain driver validation and error ordering. Genuine padded readback uses actual driver pack alignment in the existing native allocation adapter. These later slices have focused canonical evidence and are outside that full sweep. See [WebGL status](../../webgl/PORT_STATUS.md). Remaining overload/transport and full WrapperWorld coverage stay open. Current upstream reset bodies and OffscreenCanvas WebGL getter are empty. Source get_uniform returns number zero with a FIXME; the invented uniform cache and setter writes have been removed (`84f9a39b`), while upload/render fixtures read genuine driver values. Its body selects no current context and performs no resource validation or GL query; public generated nonnullable resource conversion still applies. Frozen private `4ef932b1` passes a clean 109/109 typed and 79/79 public/mixed files with GC disabled and immutable manifests. Its separate inherited-protocol probe exposed another compatibility defect; captured native own-property checks correct it (`995efed4`) with focused real-driver coverage. Source capability mirrors are removed (`a13b32d5`); scalar attributes use exact 1f/2f/3f/4f driver entry points (`30e708a9`). These followups have focused evidence after that frozen sweep; no current full-suite or wrapper-world parity claim follows. |
| WA-15 | WebGL2 sync completion is fabricated | Fixed `0ee6527a`, `65f913e4` | Actual ANGLE Metal EGL context and GLsync lifecycle/wait/query results, flags/timeouts/deletion/foreign ownership. The later creation slice also preserves Source null-handle resource records and driver error/query/delete ordering after invalid fences; native and public creation regressions pass. Native tests and all 22 WebGL files passed at the initial integration. Later sync operations select their owner first and retain the actual GLsync pointer after deletion (`6de659ab`); the Source pointer handle and present-null deletion APIs are distinct from compact IDs (`1f5f1e69`). Canonical native/public focused checks pass independently. |
| WA-16 | XMLHttpRequest send does not start Fetch or schedule a timeout | Fixed native V/JSC path, latest `5f715fd4`, `b527ee53`, `31b32617`, `e0fc6c99` | Actual owning Fetch starts native curl transfers, headers/chunks/errors/EOF reach HTML tasks, and timeout/open/abort cancel the real controller. Compact JSC constructors, handlers, progress events and callback mutations reach actual XHR/DOM records. Bound synchronous XHR uses source parallel queues and native spin. Canonical native regressions and production browser startup pass. Full RequestServer IPC/process/cache/DNS translation stays open under EX-05; non-macOS Timer scheduling remains a host boundary. |
| WA-17 | XMLHttpRequest document responses are strings, without HTML/XML parsing | Fixed `4a04dd0e` | Actual retained HTML/XML document responses with URL/origin/Page/encoding/MIME ownership, inert scripts, malformed XML rejection and cached response/responseXML identity; four focused/existing test files pass. |
| WA-18 | XMLHttpRequest progress dispatch lacks upstream throttling | Fixed `a02f2a92` | Deterministic 50 ms upload/download boundary tests; all four XHR test files pass. |
| JS-01 | Missing creation/suspension instructions and ECMAScript function execution | Open |  |
| JS-02 | Native slices are not connected to the complete production intrinsic graph | Open | ObjectPrototype support `26335b81`; ArrayCreate/list and Uint8Array decoder metadata now survive production assertion elimination (`c68c8bf2`, `fbcccad2`) with focused production tests. The complete intrinsic graph remains open. |
| JS-03 | RegExp and remaining String prototype responsibilities are absent | Open | Supporting source slices `2110fc6c`, `172482b3` preserve actual split result properties and ICU string-property extraction under production compilation. Missing RegExp execution/prototype and String intrinsic integration remain open. |
| JS-04 | Production numeric/string primitive references stop at an InternalError | Open | Source PrimitiveString virtual length/index Reference reads now run through actual VM execution without boxing (`bfc616a2`), including raw UTF-16 units. StringPrototype fallback, private-string boxing, numeric References and complete production intrinsic ownership remain open. See [Source mapping and suite proof](STRING_REFERENCE_SOURCE_PROPERTIES.md). |
| JS-05 | Object private elements, Proxy branches, eval and disposal are not translated | Partial `fa7eb0ef` | Private-element algorithms and private Reference dispatch with focused default/none GC tests; class instructions, Proxy/eval/disposal remain open. |
| JS-06 | Math, JSON, Date and Temporal source units have no runtime counterparts | Partial `6171f757` | Complete Math methods/metadata installed; JSON/Date/Temporal still open. |
| JS-07 | Value.str() substitutes a class label for upstream recursive value inspection | Partial `a66ce7db`, `c891cc64` | Source Print recursive diagnostics connected to runner; seven tests both GC modes and runner probes pass. Specialized absent runtime-object printers remain open. |
| JS-08 | Persistent bytecode-cache materialization is missing | Open |  |
| EX-01 | See [additional source boundaries](additional-sources.md) | Partial source LibWasm parser/type system/validation phase | Every core section/instruction operand decodes; the complete pinned instruction dispatch and module expression validation now run under WA-11. TypeSystem canonicalization/matching, local initialization, constants, indices and signatures have source regressions. Native compiler/call records, machine execution and Cranelift remain open. |
| EX-02 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-03 | See [additional source boundaries](additional-sources.md) | Partial actual LibGC primitive storage | ExternalEntityTable and the complete PrimitiveStorage allocator/public API now use the source tag generations, 4 TiB cage, slab/range algorithms, zero fill, reservations and guarded growth. Wasm memories and LibJS DataBlock/ArrayBuffer allocations use actual handles. All three allocator test files and five focused LibJS buffer files pass in both GC modes; the DataBlock storage regression also passes production with GC disabled. Actual Heap roots/cross-heap collection, automatic cell lifetimes, external-memory accounting and separate codec dependencies remain open. See [storage status](../../libgc/PORT_STATUS.md). |
| EX-04 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-05 | See [additional source boundaries](additional-sources.md) | Open | |

## Integrated fix validation

- `4b8ca372`: Streams queue close identity and ordinary string/undefined/null/byte chunks.
- `e2ef1376`: CSS manual font slope registration.
- `95be0742`: CSS author-family candidate isolation (macOS installed-font check).
- `26335b81`: LibJS ObjectPrototype source-order initializer and tag dispatch. Broad JS-02 remains open.

Agent checks run with `v -old-compiler -enable-globals`. Isolated worktrees use direct compiler argv for each `_test.v`, because the V test runner does not preserve a quoted `-path` containing `|`. Shared integration checks run from the canonical workspace.

- Integrated LibJS suite: `v -old-compiler -enable-globals test libjs` — **222/222 passed**. `-gc none` run also **222/222 passed**. Exact upstream AST corpus `--all`: **100/100 passed**. Root is preserving concurrent user regex work and status documentation.

- Canonical tracked test sweep: **812 passed / 99 failed / 911 total**. 98 compile failures came from the nested referrer-core module lookup and one failure from an outdated synchronous media fixture. After `428547cd` and `a0f83d70`, **all 99 failures plus ten newly tracked files passed (109/109)**. Logs are under `Build/audit-fixes/`; ignored isolated worktrees are excluded from test enumeration.
- Native macOS bundle rebuilt after pointer/Page/first-letter/Crypto integration and passed `--headless-smoke`. `64ccb499` avoids an old V compiler failure in nested optional navigation expressions. This build predates the latest Fetch continuation/WebGL raster state integrations and in-progress Trusted Types binding.
- WebIDL Promise host-job scheduling `9ef3434d`: all six WebIDL files pass, including deferred chained, rejection, observer and late-handler reactions. Crypto's global binding is integrated in `e59b028d`; this dependency alone does not close WA-02.
- IndexedDB checkpoint cleanup `ebe5c6e1`: all five focused checkpoint/global-binding/transaction-completion files pass. Tests exercise actual owning HTML queues and bound LibJS generation ordering.
- Current canonical integration batch: **11/11 test files passed**, covering global CacheStorage/Crypto/error reporting, IndexedDB checkpoints, Page navigation/pointers/hover/geometry, first-letter/image observation and ICU mappings. Current LibJS default/none GC suites both pass 222 files, and the exact AST corpus passes all 100 fixtures.

- Trusted Types global binding `9bd83457`: all three focused/existing HTML files pass; both Trusted Types package files passed before the HTML-only compiler compatibility fix. Selected screenshot conformance passed: both caret reftests and default-ignorable text are pixel-exact; inline-node passes configured max-channel-error 2 tolerance (942 differing pixels).

- `ea1122ab`/`5f2a6de4`: settled font-loader guard and font-loading tasks, two CSS files plus actual-document HTML regressions passed. URL transport remains synchronous.
- `4e74b8cc`/`e2b25835`/`a930cd4b` and native GL/Fetch slices: canonical **10/10** integration files passed. Native macOS bundle rebuilt and headless startup passed after Canvas/Timer/font-task integration.
- XHR Fetch/native timeouts, BrowserJS host functions and GL presentation/transform feedback: canonical **9/9** integration files passed.
- source high-resolution coarsening preserves multiplication/division buckets and nextafter correction; both timing files pass, including repeated-coarsening regressions.
- Complete canonical sweep: **914 passed / 56 failed / 970 tracked files**. One failure was an outdated synchronous download fixture; 55 compilation failures occurred while a coordinator cherry-pick conflict remained unresolved. After resolving it, 52/56 reruns passed; the remaining four were the native resize regression and three media fixtures that used a permanently false spin condition. Source pressed-move delivery (`012ae8c0`) and reachable media-drain fixtures (`2884457d`) now pass all four affected files. Thus each of the 970 tracked files has passing evidence across the sweep and focused corrections; this is not a single clean 970-file run.
- Latest canonical integration: **6/6 files passed** for Performance, synchronous XHR, unique Fetch queues/stream timing, native Canvas bitmap/readback, and actual JSC WebGL host dispatch. Performance additionally passed seven focused/neighbor files before integration. New files committed after the sweep began are covered by their focused checks.
- Further canonical **6/6 integration files passed** for synchronous Canvas/JSC, WebGL parameter/read-view queries and actual Fetch ResourceTiming ownership. Source final network timing uses post-redirect request timestamps (`038ce894`); native Canvas production smoke passed.
- The download fixture correction is `b097c52e`; DOM event-handler identity preservation is `c35962fe`. Native browser build/headless and screenshot results above predate the forthcoming compact Canvas/WebGL wrapper integration.

- Input FileList identity (`f8afc79b`): four focused/neighbor files pass. Complete form entry construction (`085c8dd7`) passed eleven initial focused/neighbor files; the final source scalar conversion (`d29bf4f6`), File identity, event reentry and submitted payload checks pass four files.
- Integrated compact Canvas/WebGL bundle built successfully and passed native headless startup. Mixed 2D/WebGL owners and native object-query checks pass two files; compressed GPU blocks and Skia bitmap export pass two files. Native bitmap uploads and resize ownership pass focused checks. The subsequent full main-file check exposed a CSSOM snapshot dirty-flag omission; its correction is under test, so this is not reported as a clean full main run.
- Portable source shadow raster and retained layout adapter pass two canonical files. Canvas screenshot analysis now confirms source maxWidth positioning agrees with the checked-in expected image; the remaining rotated/gradient text raster mismatch is being addressed through the missing source retained-glyph branch. No pixel-exact canvas-text claim is made.

- Latest canonical native regression batch: **11/11 files pass** for full main, repeated CSSOM/canvas ownership, native XHR/JSC transport and events, Document/Blob send bodies, canvas glyph raster, and public WebGL source spans/pixel-pack. The earlier main failure is fixed by `ec8c2025`; heap ProgressEvent identity is `6bb32235`, UTF-8 Document serialization `ff7b050b`, and Blob compiler/bytes correction `50841c7c`.
- Native curl transport (`5f715fd4`, `b527ee53`, `31b32617`) executes actual multi-socket/timer transfers, params-aware Fetch bodies/timings and deferred redirects/cancellation. Production calls execute outside assertions. Compact JSC XHR (`e0fc6c99`) reaches real owner records and DOM callbacks; its asynchronous mutations reach retained layout. See [native transport status](NATIVE_XHR_TRANSPORT.md) for remaining IPC/process, DNS/cache and platform boundaries; EX-05 remains open.
- Retained Canvas glyph branch `f2776baa` uses actual upstream Skia text runs for ordinary fillText; maxWidth/shadow paths retain source outline behavior. Production native bundle rebuilt and headless smoke passed. Canonical canvas-text screenshot now has **1,994 differing pixels / 480,000**, maximum channel error **8**, MAE **0.0038**, RMSE **0.0928** (previous maximum 110, MAE 0.1003). It passes the repository sparse tolerance and is **not pixel-exact**. This build predates live view-transition and subsequent crypto/Streams integration.
- Further actual WebGL source spans/PBO/null texture/extension slices are `c2cc60f9`, `f94c1b21`, `12cda69b`, `b95ce3b4`; agent full 44-file native/public checks pass. Remote ContextProxy consumer/shared surfaces, several numeric pixel-unpack overloads and indexed getters remain open. Current upstream empty reset/OffscreenCanvas WebGL bodies and getUniform FIXME are documented in webgl/PORT_STATUS.md (`382ffc6d`).
- Canonical merged view-transition/smooth-scroll/tee/X448 batch: **5/5 files pass**. Actual pending pipe/X25519/algorithm regression batch: **3/3 pass**. Complete formatting_contexts_test.v passes after updating its obsolete direction-agnostic source expectation. Newer native Promise adoption, transform and Ed448 checks are running; no clean whole-repository or full LibJS parity claim is made.

- Canonical **44/44 Streams, WebIDL and WebCrypto files pass**, including pending transforms, Promise adoption and Ed448. The subsequent Promise self-resolution address comparison (`316696c0`) has agent focused evidence; canonical focused and shared stylesheet-cache neighbor checks are running.

- CSS function shared-cache neighbors and Promise self-resolution correction: **3/3 canonical files pass**. Wasm type-section and retained import descriptors: **8/8 package files pass**; full LibWasm validation/execution remains open.

- Latest LibJS production corrections pass all **227/227 files in each GC mode** (default and `-gc none`). Five ordinary-statement regression files also pass `-prod -gc none`, covering array/list initialization, split branches/UTF-16 units, descriptor field presence/order, decoder read/written metadata, and ICU string extraction. Source operations execute outside removable assertions.
- Canonical compact view-transition/full-main/HTML Stream owner batch: **3/3 pass**. Canonical raw JSC value adapter and actual read capability files pass; FontFaceSet.load plus existing font task/promise neighbors pass **3/3**. The subsequent native observation-root cleanup is under canonical verification.
- Native bundle rebuilt and passed `--headless-smoke` after compact view-transition and Stream owner integration. This build predates raw JSC value/observation bindings, deferred FontFaceSet.load, ML-DSA/RSA and the additional Wasm sections.
- Canonical ML-KEM/actual readable, writable and transform callback batch: **4/4 pass**. ML-DSA and RSA generation focused files pass. RSA OAEP/PSS/PKCS1 operations are under canonical verification.

- Canonical Wasm section/count suite: **21/21 files pass**. The decoder no longer skips any core section; all 499 pinned Instruction::parse cases match the translated case inventory. Full LibWasm validity and execution remain open.
- Canonical ECDSA/ECDH operations, actual writable rejection values and WebIDL thrown completions: **3/3 files pass**. Native navigation origin initialization (`1912ce36`) passes its focused actual-document file; source file/font policy, CSS origin and readable rejection neighbors pass **3/3**. These changes postdate the last native bundle build.

- Current Wasm type/module/control suite: **29/29 files pass**. The process-wide registry also passes focused default and `-gc none` ownership tests. Source instruction dispatch and module expression/constant validation remain open despite the completed supporting handlers.
- Canonical actual JSC capability identity and native HKDF/PBKDF2: **2/2 pass**. Transform original-value errors, EC key formats and native Argon2 optional-input files pass individually. Canonical native HMAC and shared worker pool: **2/2 pass**.
- Source font MIME dispatch and origin-loop callback delivery: **2/2 canonical files pass**. Source WOFF codec and native platform decoder pass; the latter passes with its corrected Brotli rpath and no environment workaround. WOFF2 worker/owning-load-delay checks and a new production native bundle build are running.

- At `5865d48a`, both full LibJS GC-mode suites passed **228/228 files** and the exact AST corpus passed **100/100**. Actual DataBlock integration `c679a29d` passes five focused buffer files in both GC modes and its storage regression under `-prod -gc none`. Current 229-file sweeps passed **226 default-GC / 227 GC-disabled** files; three/two compilation failures explicitly reported **No space left on device**. Every affected file passed its exact rerun after space became available. Thus all 229 files have passing evidence in each mode across sweep/reruns, not a single clean 229-file run. The AST corpus remains **100/100** exact.
- Live Wasm memory integration passes a clean **53/53-file suite in both GC modes**, including actual Store identity, caged byte sharing, fixed/dynamic views, growth and detachment. Earlier copied-vector test access was corrected in `9fd56d7a`.
- Source Window-before-Document construction and the complete main regression file pass together with GC disabled. Native timers pass five source cases; the callback/CSP ordering regression passes separately. Actual QuotaExceededError passes its native subclass test. Native Writable and Crypto pass their two canonical engine test files, and full main plus the focused Crypto installation test pass together with GC disabled. Four native Transform cases pass. Owning native animation frames, their main integration and full main pass **3/3 files** with GC disabled. CryptoKey/digest and genuine-number projection pass **4/4 files**, and raw model stream sizes/writable/transform neighbors pass **4/4**, all with GC disabled.
- The production native bundle built and passed `--headless-smoke` after source document owners, timers and live Wasm memory integration. That build predates native Writable/Transform/Crypto installation and the later LibJS DataBlock change; it does not validate those newer integrations.
- A subsequent production bundle built and passed `--headless-smoke` with actual Readable/Writable/Transform, native Crypto/digest, owning animation-frame delivery and the actual LibJS DataBlock storage. Its snapshot predates raw size completions, CryptoKey and later binding refinements; those have focused canonical checks. Logs are `native-streams-crypto-raf-build.log` and `native-streams-crypto-raf-headless.log` under `Build/audit-fixes/`.
- Native raw size/actual-number checks and SimpleException identity pass focused canonical files; Writable/Readable/Transform plus full main pass **4/4 files** with GC disabled. The complete Streams package passes **33/33** with GC disabled. Public pipes, all 24 registered generateKey families and native typed-error throw checks pass **3/3 canonical files**; actual engine errors and getter exceptions are retained.
- Current source numeric Wasm package passes a clean **57/57 files with default GC and 57/57 with GC disabled**. Actual image capability/lifecycle/adoption passes **3/3 canonical files** with GC disabled.
- Native screenshot checks exposed tree-position reuse and repeated mutation batches across real frames. Their actual-element/one-time delivery correction (`eecd825d`) passes three focused cases plus full main and frame neighbors (**3/3 files**). The original screenshot snapshot passes resource removal, live selection, HTML ID collision, added/animated gradient stops and pattern-transform changes pixel-exactly; SVG image replacement, SVG ID collision and gradient-stop reordering failed in that snapshot. Subsequent retained-paint repair and a rebuilt bundle now pass all nine targeted comparisons pixel-exactly; see the completed verification below. This is a selected comparison set, not whole-engine conformance.

- Native generated constructor ordering and export pass **3/3 canonical files**; lexical JWK result order/bindings and optional import dictionary validation each pass **2/2**. Native key import and image capability pass **2/2**. The full WebIDL package passes **13/13** with GC disabled.
- Actual image installation passes both new main image cases and the complete **65-case main file** with GC disabled. The Wasm i64 regression and existing LibJS BigInt file pass together; the actual engine conversion passes its corrected focused test. The full Wasm package passes **58/58 with default GC and 58/58 with GC disabled**; the complete Streams package after pending cancellation adoption passes **35/35** with GC disabled.
- The production bundle rebuilt successfully from the `e30b9dee` snapshot and passed `--headless-smoke`. All nine targeted comparisons are pixel-exact: `svg-image-source-switch-same-size`, `svg-gradient-in-defs-removed-repaint`, `selection-insert-between-boundaries`, `paint-server-id-collision`, `paint-server-html-id-collision`, `gradient-stop-move-before`, `gradient-stop-added`, `gradient-stop-color-animation` and `pattern-transform-update`. Logs are `image-crypto-frames-{build,headless}.log` and `corrected-source-frame-{screenshot,svg-mutation}-comparisons.log` under `Build/audit-fixes/`; PNG artifacts are in `corrected-frame-comparisons/`. The first comparison invocation passed three cases before reporting six invalid relative paths; the corrected absolute-path invocation passed all six remaining cases. This bundle predates later cipher/signature/derivation/wrapping/KEM, handler and queuing-strategy integration.

- Canonical native cipher/signature files pass together; native derivation, handler invocation and its DOM realm regression pass **3/3 files**. New stream tags, owning queuing-strategy factories, source size getters and native wrapping pass **4/4 files** with GC disabled. The actual Global/cache package passes a clean **60/60 files in each GC mode**. The subsequent KEM and full WebCrypto/WebIDL verification passed as recorded below.

- All current WebCrypto/WebIDL files pass **63/63** with GC disabled. Native KEM and existing Readable/Writable/Transform hosts pass **4/4**, full browser startup passes its complete main file, Abort constructor/public pipe pass **2/2**, Stream constructor metadata and DOM entry points pass **2/2**, and public WebGL effective-overload/host checks pass **2/2**. Table ownership has a clean **61/61-file suite in each GC mode**; subsequent Instance lookup checks pass **3/3 default-GC and 2/2 GC-disabled** files. That batch predates the subsequent native rebuild recorded below.

- The `cd81f662` production snapshot builds and passes `--headless-smoke`, all nine targeted SVG/selection comparisons pixel-exactly, and all eleven configured screenshot smoke cases. Smoke uses its repository tolerances: inline/text rasterization allows channel error 2, and canvas text uses the existing sparse tolerance (577 outliers observed); the complete smoke set is not pixel-exact. Logs are `complete-native-bindings-scroll-{build,headless,comparisons,smoke}.log` and PNG directories have the same comparison/smoke prefixes under `Build/audit-fixes/`. This snapshot includes all sixteen native SubtleCrypto methods, actual stream factories and scroll position geometry; it predates native strategy builtins, unsigned Table64 and later buffer corrections.
- The current WebAssembly package passes a clean **63/63 files in both GC modes** (`table64-complete-full-wasm-{default,gc-none}.log`). Full WebIDL passes **14/14** with GC disabled. Canonical native Table64, native host-function ownership, cached strategy builtins, actual WebGL buffer slots and complete main startup pass **5/5 files** with GC disabled. These are focused canonical checks of changes newer than the production snapshot.
- Comparison of the existing structured-clone codec with pinned `StructuredSerialize` exposed incorrect tag values, absent Int32/BigInt primitive encodings, IPC string/count differences and array/object record ordering. `ca1a15c1` corrects stable tags and Int32 primitive encoding first. Exact IPC primitive and object-family repairs are continuing before native opaque-object projection and public tee exposure; existing model tests alone do not establish source codec parity.

- The latest UTF-16 adapter snapshot passes a clean **229/229 LibJS files in each GC mode** and **100/100 exact AST fixtures**, replacing the earlier disk-limited sweep evidence for that snapshot. The subsequent source inline-ASCII cache fix (`129b860b`) also passes a clean 229/229-file suite in each GC mode and 100/100 exact AST fixtures; logs are `source-short-ascii-libjs-{default-full,none-full,ast-corpus-all}.log` in assignment 7's private `Build/audit-fixes/`.
- Canonical source input/wrapper checks pass **2/2 default-GC files**, source input/existing input pass **2/2 GC-disabled files**, and the assertion-independent regex production probe passes. The offline backend build verifies ten byte-exact pinned sources; the browser script builds it before invoking V. Logs are `input-pattern-{source-gc-none,regex-default}.log` and `source-regex-wrapper-production.log`.
- Canonical WebGL reflection/context/query/resource bindings plus source buffer/Error IPC goldens pass **6/6 GC-disabled files** (`webgl-interfaces-buffer-error-codec-canonical-gc-none.log`). Resource labels reach actual owning V objects with source USV conversion and interface inheritance. Nonconstructible reflection getters, source extension prototypes and empty extension factories also pass their subsequent canonical focused checks.
- Distinct LBSC storage codec (`0cb8f5f0`) preserves source envelope, LEB integer widths, UTF-16 storage construction, fixed doubles and stable Error names. Source IPC decoding and the older strict standalone adapter have separate consumption behavior. Exact storage/common-family checks pass 5/5 files canonically with GC disabled. Actual native primitives, boxes, sparse arrays, objects, Map/Set and Date project through these records (`5de998cb`, `658d65cf`); the native clone and WebGL program/uniform batch passes 8/8 files. Native Error projection (`fd3fb46a`) passes 4/4 canonical Error/Date/collection/IPC files. Actual fixed/resizable ArrayBuffer slots (`7764d19a`) pass 4/4 buffer/Error/codec neighbors, and fixed DataView/all twelve TypedArray families (`e9ee734e`) pass with Date and actual viewport ownership/resize in a 6/6 canonical batch. Original resizable-view slots, native shared ownership, original RegExp metadata, platform SerializableObject payloads and transfers remain open. See [codec boundaries](STRUCTURED_CLONE_SOURCE_CODEC.md).

- The `c330c4f2` production snapshot builds and passes `--headless-smoke` and the complete 66-case main regression file. All eleven configured screenshot smoke cases pass with their repository tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038 and RMSE 0.0928; this smoke set is not pixel-exact. Eight of nine targeted SVG/selection captures were pixel-exact on the first invocation. `paint-server-id-collision` initially captured a red 100×100 rectangle (10,000 differing pixels); its unchanged rerun was pixel-exact. Both results remain recorded, with no claimed explanation or source fix for that intermittent capture. Logs and PNG directories use the `source-regex-codec-webgl-` prefix under `Build/audit-fixes/`. The snapshot predates the newer ancestor caller, viewport identity, native clone projection and subsequent WebGL query/interface repairs.
- The complete ancestor caller, its geometry and Promise ownership prerequisites pass 4/4 canonical files with GC disabled. Later actual VisualViewport ownership, caller/geometry and state-only draw-buffer/framebuffer checks pass 5/5 files; unavailable WebGL properties, mixed effective overloads and assertion-independent presentation setup pass 3/3. Logs are `source-scroll-caller-canonical-gc-none.log`, `source-visual-owner-draw-state-canonical-gc-none.log` and `source-unavailable-properties-canonical-gc-none.log`.

- Native Error/Date/collection/IPC cases pass 4/4 canonical files; native ArrayBuffer/Error/resizable codec cases pass another 4/4. Fixed native views, exact Date reconstruction boundaries and actual viewport resize/owner/global neighbors pass 6/6 canonical files, all with GC disabled. Logs are `source-native-error-date-clone-canonical-gc-none.log`, `source-native-buffer-clone-canonical-gc-none.log` and `source-visual-resize-native-views-canonical-gc-none.log`. Source codec doubles remain unchanged; native Date reconstruction rejects values its constructor would silently TimeClip.
- Complete source import ordering/linker integration passes a clean 67/67-file WebAssembly suite in each GC mode. The owning XR task operation, Crypto task neighbor and initial import-order/parser/tag cases pass 5/5 canonical files with GC disabled (`source-xr-import-order-canonical-gc-none.log`). The later synchronous-helper removal and native XR host binding pass 5/5 canonical native/canvas/context-loss files (`source-native-xr-canvas-canonical-gc-none.log`).

- The `f78c6972` production snapshot builds and passes `--headless-smoke`, the complete 66-case main regression file, all nine targeted SVG/selection comparisons pixel-exactly on their first invocation, and all eleven configured screenshot smoke cases with their repository tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038 and RMSE 0.0928, with 577 sparse-tolerance outliers. Logs use `source-viewport-clone-linker-xr-` under `Build/audit-fixes/`. This later clean selected comparison set does not establish a cause for the earlier intermittent ID-collision capture. The build predates the newer affine/clone/platform/query/Configuration/raw-handler integrations.
- New canonical source checks pass with GC disabled: **23/23** RAB slots/DOMException/WebIDL files, **10/10** driver parameter and viewport primitive/owner files, **9/9** vertex reflection/ActiveInfo/platform codec files, **8/8** handler state/native platform clone/Wasm records files, and **3/3** genuine raw Window compiler/EventTarget/invocation files. Logs are `source-rab-domexception-canonical-gc-none.log`, `source-driver-viewport-canonical-gc-none.log`, `source-reflection-platform-canonical-gc-none.log`, `source-handler-platform-records-canonical-gc-none.log` and `source-window-handler-canonical-gc-none.log`.
- Actual source-deserialized RAB views retain their original constructor/offset/optional-length slots in their owning Runtime (`042ee485`); arbitrary author-created RAB views still cannot recover those slots. Native DOMException and QuotaExceededError use actual cached records, source UTF-16 name/message fields, distinct primary IDs 568/569, target exposure/prototype ownership and source optional-double payloads (`94955c89`, `6c832d5e`, `dfb19bf0`, `2ecc2fab`). The registry generator reproduces the fresh pinned 586-entry intrinsic order byte-for-byte; the stale upstream build header is not its input. Other SerializableObject families, native shared ownership, original RegExp metadata and transfers remain open. The newer Quota constructor/codec/native binding and complete WebIDL batch passes 22/22 files canonically with GC disabled (`source-quota-platform-canonical-gc-none.log`).

- The current Configuration package passes a clean **71/71 canonical files with default GC** (`source-configuration-full-canonical-default-recheck.log`); the identical Configuration implementation passes **71/71 with GC disabled** in assignment 9's isolated worktree (`source-configuration-full-gc-none.log`). The previous canonical default run was interrupted at 65/71 and is retained as incomplete evidence. The successful recheck is a complete fresh run.

- The earlier WebUI helper and scripting-gate snapshot (`d16f96f9`, `51f7d87b`) passed **9/9 canonical files with GC disabled** (`source-scripting-owner-handlers-canonical-gc-none.log`). Its original-settings adoption expectation was later proved incorrect by the pinned DOM::Node overload and replaced in `9a77696a`; that old passing suite is historical evidence, not proof of that ownership assumption. Page-before-parse startup was subsequently integrated in `9e008b7c`.

- The frozen `a9c7b67b` production snapshot builds and passes `--headless-smoke`, nine targeted SVG/selection comparisons pixel-exactly, and all eleven configured screenshot smoke cases with repository tolerances. Canvas text still has 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs use `source-page-script-module-table-` under `Build/audit-fixes/`. This build predates the later Window readiness, active-document, native CryptoKey, stream and texture integrations.
- Clean canonical LibJS validation passes **229/229 in each GC mode**, with **100/100 exact AST fixtures** (`source-utf16-projection-libjs-{default,gc-none,ast}.log`). The module/table Wasm snapshot passes **74/74 canonically in both GC modes**; its later argument/frame/preparation snapshot passes **77/77 privately in both modes**. These checks do not imply an interpreter, instantiation or complete runtime owner graph.
- New canonical GC-disabled integration batches pass **11/11** Page/Classic/Crypto owners, **13/13** module/Crypto/GL/main, **22/22** Wasm frames/Crypto/FileAPI/Window/GL, and **14/14** native readiness/attribute hooks/upload checks. Logs are `source-page-classic-crypto-owners-canonical-gc-none.log`, `source-module-crypto-gl-main-canonical-gc-none.log`, `source-frames-crypto-file-gl-window-canonical-gc-none.log` and `source-native-events-upload-canonical-gc-none.log`. Newer static-handler, active-document, stream and 3D/copy/storage checks are separate pending validation.

- The frozen `d513a2d3` production snapshot builds and passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly**, and **11/11 configured smoke cases** with repository tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs and PNG artifacts use `source-static-window-streams-textures-` under `Build/audit-fixes/`. This build predates Source temporary-context cleanup, Blob reading/text, bytecode state, native Window.find and shader/program corrections; it is not a build claim for current HEAD.
- Subsequent canonical checks with GC disabled pass **17/17** static/readiness/activity/stream/texture files (`source-static-stream-texture-canonical-gc-none.log`) and **3/3** host-span/function/native-byte-witness files (`source-host-span-native-witness-canonical-gc-none.log`). The Source Blob/context/stack/machine batch initially passes 13/14; its sole failure was a worker-Promise fixture expecting one callback frame instead of the Source nested depth of two. The focused fixture correction (`e07a568d`) and native shader/Window.find neighbors pass **3/3** (`source-blob-fixture-shader-find-canonical-gc-none.log`). Together these are passing coverage for all fourteen files, not a single clean fourteen-file run. The mistaken nonexistent-file invocation is retained separately as a runner diagnostic.
- The Source bytecode-state snapshot passes a fresh clean **80/80 canonical WebAssembly files in each GC mode** (`source-bytecode-state-full-canonical-{default,gc-none}.log`). The Source StackInfo snapshot passes **230/230 LibJS files in each GC mode**, privately in assignment 9, plus **100/100 exact AST fixtures** (`source-stack-info-libjs-full-{default,gc-none}.log`, `source-stack-info-libjs-ast.log`). Canonical LibJS additionally exposes the unchanged existing `to_well_formed` function publicly; that visibility change had preceding clean canonical 229-file/100-AST evidence. Focused merged StackInfo/context files pass canonically with GC disabled. Neither suite completes the pending production interpreter/builtin/realm graphs.
- Assignment 8's frozen `13d3c7d3` snapshot passes **73/73 typed WebGL files and 43/43 public/mixed files** with GC disabled. Explicit manifests, per-file logs and exit-code tables live in its private `Build/audit-fixes/webgl-final-13d3c7d3/`. The initial quoted-module-path shell invocation failed before compilation and remains as diagnostic evidence. Later shader/program owner ordering passes two canonical native/public files; actual shader validation also passes in the Blob/Window.find integration rerun. Later creation and mirror-removal regressions have separate private focused proof and do not inherit the earlier 116-file sweep claim.

- The merged shared Window event, real engine ArrayBuffer/read-loop and shader/sync creation slices pass **10/10 canonical files with GC disabled** (`source-event-buffer-resource-canonical-gc-none.log`). This covers actual native buffer/view identity before settlement, genuine native zero/null resource returns, driver query/delete ordering and nested/shadow current-event ownership. Public Window.event and the later Source uniform-getter body are subsequent slices with separate validation.

- The frozen `af33708c` production snapshot builds and passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly**, and **11/11 configured screenshot smoke cases** with existing tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs and artifacts use `source-native-event-buffer-uniform-` under `Build/audit-fixes/`. This bundle includes actual native Window.event, Source uniform getter/mirror/creation corrections and native read-loop ArrayBuffer allocation; it predates the subsequent explicit Blob realm, scalar-uniform and integer-operator integrations.
- Canonical native Window.event/readiness and Source uniform getter checks pass **5/5 files with GC disabled** (`source-window-event-uniform-getter-canonical-gc-none.log`). Explicit actual Blob-realm/read/text ownership passes **3/3** (`source-blob-real-engine-realm-canonical-gc-none.log`). Optional uniform pointers, exact scalar GL calls, independent Blob ArrayBuffer fulfillment and all 3,264 Wasm integer cases pass **5/5** (`source-scalar-uniform-blob-integer-canonical-gc-none.log`). The operator file also passes canonical default GC (`source-integer-operators-canonical-default.log`); regenerating its Source C++ corpus reproduces the checked-in bytes exactly.

- New canonical GC-disabled integration passes **6/6** actual Window document/performance/current-event, Blob.bytes and unsigned scalar-uniform files (`source-document-blob-bytes-unsigned-uniform-canonical-gc-none.log`), **2/2** vector owner files (`source-vector-uniform-owner-canonical-gc-none.log`), and **2/2** numeric helper/integer-oracle files (`source-numeric-operation-canonical-gc-none.log`). Actual Blob host/accessor metadata and Source matrix/legacy uniform regressions pass **5/5** (`source-blob-owner-matrix-canonical-gc-none.log`). The subsequent UniversalGlobalScope document capture, activation identity, existing Window/rejection tasks and native Blob constructor/metadata pass **6/6** (`source-global-task-activation-blob-constructor-canonical-gc-none.log`). These newer slices are not included in the preceding `af33708c` native bundle.

- Trusted activation clock/identity and legacy/new native matrix checks pass **4/4 canonical files with GC disabled** (`source-trusted-activation-legacy-matrix-canonical-gc-none.log`). Actual native Blob IPC/storage projection, platform-clone neighbor and constructor pass **3/3** (`source-native-blob-clone-canonical-gc-none.log`). Unary integer C++ results, actual numeric helper and actual-global Blob installation pass **3/3** (`source-unary-operators-actual-blob-global-canonical-gc-none.log`). Assignment 8's frozen `ea1e2287` typed sweep passes 80/81, with its sole obsolete transpose assertion corrected and verified alongside the source matrix neighbor; public/mixed passes 50/50 with unchanged implementation. Exact manifests, initial failure and per-file results remain in the private `webgl-final-ea1e2287/` artifacts. The framebuffer-owner slice is newer than that sweep.

- Frozen assignment-9 `f28d34eb` passes a fresh clean **83/83 WebAssembly files in each GC mode** (`source-numeric-operators-full-private-{default,gc-none}.log`), with an explicit manifest and snapshot hash. At integration, canonical WebAssembly implementation/tests were identical and canonical LibJS only added public visibility to the unchanged `to_well_formed` body. The later Source string Reference change is newer than that frozen sweep. Dependencies outside those packages are the private snapshot, so this is private full-suite evidence, with canonical focused proof recorded separately. Actual framebuffer owner/retained map and returned record checks pass **2/2 canonical files per slice with GC disabled** (`source-framebuffer-attachment-{order,record}-canonical-gc-none.log`); both slices postdate the frozen 131-file WebGL sweep.


- The frozen `7a4cdd27` production snapshot builds and passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly**, and **11/11 configured smoke cases** with repository tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs, snapshot hash and PNGs use `source-native-blob-activation-matrix-` under `Build/audit-fixes/`. This bundle includes actual Blob startup/constructor/clone, shared task-document ownership, activation timestamps and scalar/vector/matrix uniform repairs. It predates later WindowProxy/logical consumption, query/sync/GLuint, XHR Blob transport and File integrations; it is not a build claim for current HEAD.
- Later canonical GC-disabled checks pass **9/9** WindowProxy/logical activation/query files (`source-proxy-consumption-query-canonical-gc-none.log`), **4/4** actual XHR Blob/startup files (`source-xhr-actual-blob-canonical-gc-none.log`), **3/3** sync owner/retained pointer files (`source-sync-owner-pointer-retention-canonical-gc-none.log`), and **3/3** actual sync handle/File owner neighbors (`source-sync-handle-file-owner-canonical-gc-none.log`). Native Blob startup and main neighbors independently pass **3/3** (`source-blob-native-startup-canonical-gc-none.log`). Nonexistent-path runner diagnostics are retained separately from production failures.
- The Source primitive-string Reference snapshot `32b8d45e` passes **231/231 LibJS files in each GC mode** and **100/100 exact AST fixtures**, privately in assignment 9, with exact manifest and snapshot hash. Canonical LibJS implementation/tests match that snapshot byte-for-byte; dependencies outside LibJS remain the private snapshot. Logs use `source-string-reference-libjs-` there. The new Reference file and Boolean/string-cell neighbors independently pass **3/3 canonically with GC disabled** (`source-string-reference-canonical-gc-none.log`). This supporting Source fast path does not close JS-04.
- Current canonical picker/adopted-node/trusted-activation and form neighbors pass **6/6** with GC disabled (`source-picker-overload-canonical-gc-none.log`). Actual GLuint/shader retention/sync/File constructor-owner integration passes **7/7** (`source-gluint-shader-file-constructor-canonical-gc-none.log`). The exact signed64 Source numeric probe passes at clang -O0/-O2 (`source-webidl-int64-native-probe-canonical.log`); Source's out-of-range cast at the exact ±2^63 boundary remains explicitly compiler-dependent, with no all-input parity claim.


- Canonical current-Document Node scripting and real raw-handler/parser neighbors pass **6/6** with GC disabled (`source-node-current-scripting-canonical-gc-none.log`); logical cross-site ancestor settings and existing environment/serialized/Window association checks pass **4/4** (`source-cross-site-ancestor-canonical-gc-none.log`). The old original-settings fixture was corrected using the exact Source DOM::Node overload; historical passing evidence is not retained as a correctness claim for that assumption.
- Actual File/Blob clone and current-program records pass **4/4 canonical GC-disabled files** (`source-file-clone-current-program-canonical-gc-none.log`), actual retained vertex arrays pass **2/2** (`source-vertex-array-record-canonical-gc-none.log`), and File/Blob browser startup plus transform-feedback/legacy parameter regressions pass **5/5** (`source-file-startup-transform-feedback-canonical-gc-none.log`). These checks are newer than the `7a4cdd27` bundle.
- Source scalar shifts and integer comparisons each pass **3/3 canonical files with GC disabled**, with comparison default GC passing independently (`source-shift-integer-canonical-gc-none.log`, `source-comparison-integer-canonical-{default,gc-none}.log`). Both native generators produce exact pinned C++ fixtures; the existing binary and unary families were reproduced during shift tooling validation, and binary was reproduced again after macro comparison tooling. The earlier full Wasm83/LibJS231 snapshots remain frozen evidence; no full 85-file Wasm sweep is claimed.


- Frozen `8a7f64ec` production snapshot builds with GC disabled, passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly**, and **11/11 configured screenshot smoke cases** with repository tolerances. Canvas text retains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs, snapshot hash and PNG directories use `source-native-file-proxy-ownership-` under `Build/audit-fixes/`. This bundle includes actual File startup/constructor/clone, corrected current-Document scripting ownership, shared WindowProxy/logical activation and query/sync/GLuint/retained resource corrections. It predates later sampler/draw/clear/repaint, child-tree/closing/beforeunload, FileList and binding native-value integrations; it is not a build claim for current HEAD.
- Canonical sampler/setter/layer checks pass **6/6** with GC disabled (`source-sampler-layer-canonical-gc-none.log`). Window child-tree/logical ancestry and FileList owner/constructor checks pass **5/5** (`source-window-tree-file-list-canonical-gc-none.log`); exact FileList/File clone checks pass **2/2** (`source-file-list-clone-canonical-gc-none.log`). Draw callback/driver and closing/traversable checks pass **6/6** (`source-draw-closing-canonical-gc-none.log`). Nonexistent-file invocations remain separately retained runner diagnostics.
- Native Image/Option conversions and platform descriptor SameValue pass **5/5 canonical files with GC disabled**, including constructor/platform neighbors (`source-bindings-native-value-canonical-gc-none.log`). Source numeric and original exception identities are exercised through actual engine values. Standalone object adapters, mixed native/scalar comparisons, full generated receiver/prototype/realm ownership and UTF-16 Option storage remain open; see [bindings status](../../bindings/PORT_STATUS.md).
- Source canvas invalidation/clear-order and existing presentation neighbors pass **4/4 canonical files with GC disabled** (`source-canvas-clear-canonical-gc-none.log`). Actual typed input FileList producers and main FileList/File/Blob startup pass **4/4** (`source-input-file-list-startup-canonical-gc-none.log`); beforeunload/traversable/WebDriver ownership passes **3/3** (`source-beforeunload-canonical-gc-none.log`). Public input receiver and full native wrapper graphs remain explicit prerequisites.
- Frozen assignment-8 `2ad0138f` passes a fresh clean **97/97 typed WebGL files and 66/66 public/mixed files** with GC disabled. Exact manifests, per-file logs and exit tables live in `Build/audit-fixes/worktrees/08-crypto-webgl/Build/audit-fixes/webgl-final-2ad0138f/`. Canonical WebGL implementation/tests and the canvas repaint implementation/tests match that snapshot byte-for-byte; dependencies outside those files remain private snapshot dependencies. A separate genuine driver probe records pending errors `[1280,1281,0]` versus translated `[1281,0,0]`, exposing an untested eager-draining defect. The complete passing sweep does not close that defect or WA-14.
- Scalar wrapping arithmetic/bitwise and floating-comparison/helper neighbors each pass **3/3 canonical files with GC disabled** (`source-arithmetic-integer-canonical-gc-none.log`, `source-floating-comparison-canonical-gc-none.log`). Their new files also pass default GC privately. The generators produce 1,728 and 3,072 exact pinned C++ cases, with arithmetic reproduced byte-for-byte after floating tooling. The earlier full 83-file Wasm/231-file LibJS snapshots remain frozen evidence; no full 87-file Wasm sweep or production opcode parity is claimed.


- Frozen `5f30e334` production snapshot builds with GC disabled, passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly**, and **11/11 configured screenshot smoke cases** with repository tolerances. Canvas text retains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs, exact snapshot hash and PNG directories use `source-native-file-list-close-draw-` under `Build/audit-fixes/`. This bundle includes native FileList startup/input producers, native binding conversions, Source beforeunload/canceled-close guards and canvas draw/clear/invalidation repairs. It predates later driver error retention/upload/readback, unload-task/shared history ownership, storage-state copy and raw drag/File/LibJS byte-boundary integrations.
- New canonical GC-disabled batches pass **4/4** texture/activeTexture native/public files (`source-texture-active-canonical-gc-none.log`), **6/6** readPixels/drag UTF16/unload task/event-loop files (`source-read-drag-unload-canonical-gc-none.log`), and **5/5** driver error/priority/upload/readback files (`source-driver-error-retention-canonical-gc-none.log`). The driver's real two-error order and prior-error pixels/bytes are exercised directly. This newer implementation does not inherit the old frozen 97/66-file full-sweep claim.
- Actual storage history restoration passes a clean **4/4** canonical GC-disabled recheck (`source-history-storage-owner-canonical-gc-none-recheck.log`); initial new-fixture accessor diagnostics remain retained. Storage defaults and entry/destination/population copies pass **6/6** (`source-history-record-copy-canonical-gc-none.log`). Shared current/active history ownership and close/task/storage neighbors pass **5/5** (`source-history-task-shared-canonical-gc-none.log`). Full target-realm reconstruction and process HistoryExecutor boundaries remain open; see [Source history records](HISTORY_STORAGE_RECORD_OWNERSHIP.md).
- The frozen private `e1f41d8e` Wasm snapshot passes **89/89 files in each GC mode**, with exact manifest/hash/results and `source-floating-extrema-full-private-` logs under assignment 9. Canonical implementation/tests match, while dependencies outside the package remain private snapshot dependencies. It predates `68deba04`'s new explicit LibJS byte helper. Floating arithmetic and extrema/helper integration independently pass **3/3 canonical files each with GC disabled** (`source-floating-{arithmetic,extrema}-canonical-gc-none.log`). No production opcode/instantiation/root parity is inferred.
- Native actual-header WTF8/ASCII probe passes at clang -O0/-O2 (`source-drag-wtf8-probe-canonical.log`). Explicit Source UTF8 byte-boundary/string-reference/primitive-string checks pass **3/3 canonical files with GC disabled** (`source-utf16-byte-boundary-canonical-gc-none-recheck.log`); the initial nonexistent-file invocation is retained as a runner diagnostic. File byte names, actual DataTransfer producers, raw drag-slot/legacy drag and input FileList neighbors pass **5/5** (`source-drag-file-producer-canonical-gc-none.log`). Frozen private `a9338570` passes a clean **232/232 LibJS files in each GC mode and 100/100 exact AST fixtures**. All 485 non-Markdown LibJS files match canonical before and after the sweeps; dependencies outside LibJS remain those of the private snapshot. Exact manifest and log hashes are in [verification evidence](LIBJS_BYTE_BOUNDARY_VERIFICATION.md).

- Actual native DataTransfer File/FileList adapters (`3764464e`), legacy WTF8 drag views (`3b27887a`) and the current-entry/optional-origin navigation gate (`51ad893b`) pass **6/6 canonical integration files with GC disabled** (`source-drag-origin-gate-canonical-gc-none.log`). They retain real File/Blob/list identity and tasks, native brand conversion before applicability, and Source target/current-entry and optional-origin equality. The phase-one actual Window/Navigation task owner, public drag/input wrappers and full graph remain separate work. See [read-loop boundaries](READ_LOOP_BLOB_SOURCE.md) and [navigation gate](UNLOAD_CHECK_CURRENT_ORIGIN_GATE.md).
- The frozen `2355ee46` WebGL snapshot passes **101/101 typed and 70/70 public/mixed files** with GC disabled, with exact manifests/results under assignment 8’s `webgl-final-2355ee46/`. The identical direct-driver and translated error probe now returns `[1280,1281,0]` through both paths. This newer snapshot covers actual driver error retention and does not close unused raster mirrors, the named base helper, wrapper GC or remote transport. Canonical WebGL implementations/tests match; outside dependencies remain scoped to the private snapshot.

- Frozen canonical `f3db5d10` production snapshot builds with GC disabled, passes `--headless-smoke`, **9/9 targeted SVG/selection comparisons pixel-exactly** and **11/11 configured screenshot smoke cases** with repository tolerances. Canvas text retains 1,994 differing pixels, maximum channel error 8, MAE 0.0038, RMSE 0.0928 and 577 sparse outliers. Logs, exact snapshot hash and PNG directories use `source-native-driver-drag-history-` under `Build/audit-fixes/`. This bundle includes actual driver error retention/texture/readback continuity, storage/default/copy/shared history state, raw drag/File producers/native adapters and the target/current-origin gate. It predates the newer active Window task, viewport/scissor, FileReader BOM and floating unary integrations.
- Floating unary/extrema/helper and FileReader text packaging/BOM neighbors pass **6/6 canonical files with GC disabled** (`source-float-unary-reader-bom-canonical-gc-none.log`). Actual Window/global-task/Navigation owners and viewport/scissor/real-driver neighbors pass **7/7** (`source-active-window-viewport-canonical-gc-none.log`). FileReader asynchronous stream/task/result ownership, internal replacement decoder and WebGL named-helper sync-receiver boundaries remain separate work.
- Frozen `bbb7d72944f17772af8f1096bcb3225f4b3d8f88` in assignment 9 passes a fresh clean **90/90 WebAssembly files in each GC mode** (130.9 s default / 130.5 s GC disabled), with no tracked mutations during either run. It is an isolated checkout of that exact canonical commit, including the new Source LibJS byte helper. Manifest, commands, result/log hashes and logs use `source-unary-wasm90-` in that worktree. WebAssembly and LibJS implementation/tests matched at recording; the later float/integer width files and changes outside those packages are not covered by this frozen snapshot. No production opcode/instantiation/collector parity is inferred.


- Canonical timeout, Source error receiver and replacement decoder checks pass **7/7 with GC disabled** (`source-timeout-error-replacement-canonical-gc-none.log`); the native pinned Rust decoder probe passes **2/2 debug and 2/2 release** (`source-replacement-decoder-probe-canonical.log`). Later blend/error-receiver checks pass **3/3** (`source-blend-error-receiver-canonical-gc-none.log`). These cover the real owning sync-query branch; local/loss early returns keep the other driver owner unchanged.
- Float width, typed prompt completion and clear setter checks pass **7/7 canonical files with GC disabled** (`source-width-prompt-clear-canonical-gc-none.log`). Full main plus Source clear-order regressions pass **2/2** (`source-main-clear-receiver-canonical-gc-none.log`), before subsequent enum/reader-owner/vector slices.
- The original four-file FileReader/raster-enum integration records **3 PASS / 1 compile failure** (`source-file-reader-raster-enum-canonical-gc-none.log`): the new reader test used a WindowModel field removed by the earlier shared-association slice. `741a10e0` removes those two obsolete assignments and preserves the genuine association/captured-inactive-task assertions. The later owner/global-task/prompted-close/full-Traversable/stencil/URL batch passes **9/9** (`source-owner-close-stencil-url-canonical-gc-none.log`).
- Native unload-vector/prompt/timeout, BinaryString and actual float-raster integration passes **6/6 canonical files with GC disabled** (`source-native-vector-binary-raster-float-canonical-gc-none.log`). Float/integer width plus actual machine numeric helpers pass **3/3** (`source-integer-floating-width-canonical-gc-none.log`). The new integer-width fixture reproduces byte-for-byte privately; full current WebGL/Wasm package and native-bundle validation are separate from these focused results.


- Frozen canonical `c158a54fe0bf1a26009a1f519d8f594098809a0e` production snapshot builds with GC disabled, passes headless startup, **9/9 targeted comparisons pixel-exactly** and **11/11 configured screenshot smoke cases** within repository tolerances. Canvas text retains 1,994 differing pixels, maximum error 8, MAE 0.0038 and RMSE 0.0928. Exact snapshot, build/headless/logs and PNG artifacts use `source-native-state-owner-width-` under `Build/audit-fixes/`. It includes actual unload vector/prompt/Timer/Window owners, FileReader owner/BOM/replacement/BinaryString/DataURL, float/integer widths, Source error receiver and raster/blend/clear/stencil/map repairs. It predates later pixel-store, destroyed-state, bitcast/cast and fixed-view-length integrations; it is not a native build claim for current HEAD.
- FileReader DataURL/map/real float getter checks pass **3/3 canonical files with GC disabled** (`source-data-url-map-canonical-gc-none.log`). Pixel-store/early-return/padded readback, destroyed-state/prompted-close and reinterpret/cast/numeric-helper checks pass **8/8** (`source-pixel-destroyed-bitcast-convert-canonical-gc-none.log`). Full current Wasm/WebGL sweeps are separate from these focused checks.


- Frozen canonical checkout `e86c54a7b3749a8bbaa6e31a6b10ba0f8d0c7f77` passes a fresh clean **94/94 WebAssembly files in each GC mode** (307.0 s default / 303.7 s GC disabled), without tracked mutations. Its 202 WebAssembly and 485 LibJS non-Markdown files stayed byte-identical and match canonical at recording. Later changes outside those packages are outside this snapshot. Exact commands, manifest/log hashes and remaining runtime boundaries are in [verification evidence](WASM_SCALAR_VERIFICATION.md).
- Actual FileReader stream/Realm/callback owners and fixed typed-array slot/buffer neighbors pass **4/4 canonical files with GC disabled** (`source-file-reader-stream-fixed-view-canonical-gc-none.log`). Wrong-Realm validation survives production assertion stripping through an explicit fatal owner check (`433b210d`); the async Source read-operation and native result/witness/cache graph remain separate pending work.

- Frozen private WebGL `4ef932b1ba72801a4eeec6102ccd97258552bf92` passes **109/109 typed files** (131.6 s) and **79/79 public/mixed files** (713.0 s), with GC disabled, explicit private paths, unchanged tracked state and exact manifests. Artifacts are under assignment 8's `Build/audit-fixes/webgl-final-4ef932b1/`. This snapshot predates the separately reproduced and fixed inherited-discriminator defect, capability mirror removal and exact scalar vertex calls; followup checks retain their own scope.
- Owned FileReader Promise read operations, exact 50 ms progress, genuine Sync ArrayBuffer allocation and corrected native numeric reply discriminators pass **4/4 canonical files with GC disabled** (`source-owned-reader-sync-reply-canonical-gc-none.log`). The actual retained raw UTF16 result, read operation and native Sync buffer neighbors then pass **3/3** (`source-file-reader-raw-sync-canonical-gc-none.log`). The asynchronous operation (`ff850321`) now retains Source default-reader, Promise and callback-task owners; the native Uint8Array witness/public receiver and real per-world weak result cache remain open. See [Source FileReader mapping](FILEREADER_TEXT_SOURCE.md).
- Actual active-context owners, Window neighbors and genuine capability-state checks pass **3/3 canonical files with GC disabled** (`source-active-context-capability-canonical-gc-none.log`). Exact scalar vertex native/public files pass **2/2** (`source-vertex-scalar-canonical-gc-none.log`). Checked truncation and conversion/helper neighbors pass **3/3** (`source-checked-truncate-canonical-gc-none.log`). These checks are subsequent to the historical native c158a54f bundle.

- Frozen exact canonical `a7e4319a7eb3fca6f47d55ff24d47398164b1351` in assignment 9 passes **96/96 WebAssembly files in each GC mode** (177.9 s default /176.2 s GC disabled). Its 209 WebAssembly and 485 LibJS non-Markdown files stayed byte-identical and match canonical at recording. Both new truncation files are included; subsequent dependency changes retain separate scope. Commands, manifest/log hashes and runtime boundaries are in [verification evidence](WASM_SCALAR_VERIFICATION.md).
- Saturating truncation and exact native/public float-vector checks pass **3/3 canonical files with GC disabled** (`source-saturating-vertex-vector-canonical-gc-none.log`). Full main and initial BrowsingContext completion pass **2/2** (`source-main-context-completion-canonical-gc-none.log`). The new constructor tail follows Source ready/populate/default-schemes/make-active/finish-loading order; full group construction and creator/policy/realm dependencies remain separate. See [constructor mapping](INITIAL_BROWSING_CONTEXT_COMPLETION.md).

- Frozen canonical `a7e4319a7eb3fca6f47d55ff24d47398164b1351` production bundle builds with GC disabled, passes headless startup, **9/9 targeted SVG/selection comparisons pixel-exactly** and **11/11 configured screenshot smoke cases** within repository tolerances. Canvas text remains 1,994 differing pixels, maximum channel error 8, MAE 0.0038 and RMSE 0.0928. Exact snapshot, build/headless/comparison/smoke logs and PNG directories use `source-native-reader-context-vertex-` under `Build/audit-fixes/`. This bundle includes owned FileReader read operations and raw string slots, genuine Sync buffers, active context/Window getters and production identity guard, initial context completion, exceptional numeric transport and protected reply discriminators, capability mirror removal, exact float scalar/vector entry points and both Wasm truncation families. It predates Source group construction, native Sync BinaryString, integer attribute calls and later pointer/raw-storage changes; it is a frozen snapshot proof rather than a current HEAD build claim.

- Source unchecked ASCII UTF16 now retains raw bytes and target plain-char code units independently (`b47ae096`), with the actual pinned AK constructor/header probe passing at -O0/-O2. Infra/FileReader DataURL stores that owned record (`a98d3a13`), and native Sync DataURL consumes it in the supplied actual Runtime (`1a72bc52`); MIME remains the explicitly typed compatibility-input boundary. Canonical ASCII/Infra/DataURL/raw-slot/native Sync and integer-pointer/divisor checks pass **10/10 with GC disabled** (`source-ascii-sync-integer-pointer-divisor-canonical-gc-none.log`). The final full LibJS snapshot passes **233/233 in each GC mode and 100/100 exact AST fixtures**, with its complete tracked checkout immutable; exact revisions/manifests are in [verification](LIBJS_UNCHECKED_ASCII_VERIFICATION.md). This proof predates the separate Math entropy change.
- Native browsing-context identity now survives Window construction, both navigation population branches and Document-slot destruction (`c3a7f478`), preserving one actual context/WindowProxy. Auxiliary construction reads the logical top-level traversable's actual active context and copies Source's u64 virtual group ID plus opener-origin snapshot (`d59553f0`). Canonical retained-owner/auxiliary/active-owner and vertex-getter integration passes **5/5 with GC disabled** (`source-context-retention-aux-vertex-getter-canonical-gc-none.log`); private production retained-owner/identity checks also pass **2/2**. See [retained identity](BROWSING_CONTEXT_NATIVE_IDENTITY_RETENTION.md) and [auxiliary ownership](AUXILIARY_BROWSING_CONTEXT_OWNERSHIP.md). Complete creator metadata, legacy constructors, native navigation/realm/GC and teardown remain separate.
- Source WebGL2 integer pointer (`59be3d0f`) and divisor (`409cf65e`) forward genuine driver validation and remove the remaining fabricated attribute-state record. Signed/unsigned integer vectors use exact I4iv/I4uiv pointers with Source short-span gates (`80234bc4`); canonical integer/float vector native/public neighbors pass **4/4** (`source-integer-vector-canonical-gc-none.log`). Vertex (`7f3685d2`), buffer (`dabcd749`) and renderbuffer (`f410ee6f`) getters preserve genuine early errors before native owner selection. These focused changes follow the immutable 109/79 full WebGL snapshot; no later full-suite, remote transport or WrapperWorld parity is claimed.
- Math.random seed initialization now uses Source's two OS CSPRNG draws (`ce231a42`); existing splitmix/xorshift and numeric projection are unchanged. Actual pinned native bodies match **48 exact outputs** and the two-draw byte ABI at both optimization levels. New/existing Math checks pass **2/2 default and 2/2 production GC-none** privately. Platform execution, static initialization and intrinsic-graph limits remain explicit in [Source entropy evidence](MATH_RANDOM_SOURCE_ENTROPY.md). Full checks for the new frozen 234-file package are being recorded separately; finding JS-06 remains partial.

- The new frozen Math entropy snapshot completes clean **234/234 LibJS files in each GC mode and 100/100 exact AST comparisons**, with all 4417 tracked files unchanged and all 490 non-Markdown LibJS files matching canonical. [Exact proof](LIBJS_MATH_ENTROPY_VERIFICATION.md) records revision, manifests, logs and outside-package dependency scope. Canonical buffer/renderbuffer/Math neighbors pass **6/6 GC-none** (`source-buffer-renderbuffer-math-canonical-gc-none.log`); texture getter integration passes **2/2** (`source-texture-getter-canonical-gc-none.log`), and retained-only attached-shader owner/identity checks pass **2/2** (`source-attached-shader-canonical-gc-none.log`). The latter explicitly corrects the earlier unsupported successful-call owner-switch assertion; genuine retained shader identity evidence remains valid.

- Frozen canonical `e93aaa7b72e56a90f71636efb2be6c3c58113b56` production bundle passes build/headless and **11/11 configured screenshot smoke cases**. All nine targeted SVG/selection cases are exact across the initial four-pass/failed-capture run, unchanged one-case retry and remaining four-case run. All 4,444 tracked contents stay unchanged. The original missing-PNG log is retained; no single clean nine-case run is claimed. Canvas text remains 1,994 differing pixels and maximum error 8; two other smoke cases retain their documented small tolerance differences. Exact snapshot, hashes and later-change scope are in [native proof](NATIVE_FROZEN_E93AAA7B.md).
- Frozen exact canonical `e93aaa7b` passes **96/96 WebAssembly files in each GC mode** (130.6 s default /128.5 s GC-none), with all 4,444 tracked contents unchanged. This refresh exercises the unchanged 209-file Wasm package against the newer 490-file LibJS dependency snapshot; production opcode/SIMD/instantiation and collector ownership remain unfinished. See [exact dependency proof](WASM_SCALAR_VERIFICATION.md). The separate frozen WebGL sweep at the same revision passes **120/121 typed and 91/91 public files**, with the sole obsolete owner fixture independently corrected and passing; [full evidence](WEBGL_FROZEN_E93AAA7B.md) retains the failed typed run, copied native-regex dependency and initial missing-archive attempt without claiming a clean 121-file run.
- Exact Source SingleByte decoding tables/replacement loop (`eccd4fca`) and UserDefined raw capacity ownership (`9b3d5690`) pass **9/9 canonical Encoding files with GC disabled** (`source-single-byte-user-defined-canonical-gc-none.log`). Both actual pinned Rust probes pass two debug and two release cases, and all four generated all-byte/raw-capacity JSON fixtures match canonical values exactly. See [decoder boundaries](SINGLE_BYTE_DECODER_SOURCE.md); multibyte compatibility paths and complete streaming lifecycle remain unfinished.
- Genuine concrete Base insertion/removal/attribute dispatch (`85f080dd`) and queued CSP execution-time current-Document targeting (`28d9909e`) pass **7/7 canonical DOM/HTML/parser/creator/CSP files with GC disabled** (`source-base-csp-owner-canonical-gc-none.log`). Source shader type validation (`b9edb903`) and independently migrated query-owner expectations (`3c9701f2`) pass **5/5 native/public/owner files** (`source-shader-type-query-owner-canonical-gc-none.log`). The actual Base CSP gate, obsolete parser replay, lost GL dispatch and proxy/native object distinction remain separate Source work.

- Source valid-prefix UTF8 masks (`db0d9e23`) and actual settings-owned Base CSP (`9cebf397`) pass **5/5 canonical GC-none files** (`source-utf8-validity-base-csp-canonical-gc-none.log`). The actual pinned native validity/bridge probe reproduces all three binary assets and the edge JSON exactly in both native profiles; this prerequisite alone does not replace the remaining malformed UTF8 decoder. Genuine full-parser Base insertion now runs once (`203ed64d`), preserving the frozen URL across readiness-handler URL changes and preventing duplicate CSP reports. Its parser/Base/creator plus new Wasm memory/cache/module batch passes **7/7 GC-none** (`source-parser-memory-cache-canonical-gc-none.log`). Meta policy insertion and full Violation reporting remain separate.
- Source lost shader creation suppresses dispatch while preserving generated IDs (`b92779c8`); its native/public regressions pass **2/2 GC-none** (`source-lost-shader-create-canonical-gc-none.log`). Actual GLuint proxy IDs, mapped native names and compact wrapper IDs are now separate (`693397e1`), including the creation-only u32 allocator and raw numeric getter records. Native/public/getter/attached-shader/sampler/VAO/error neighbors pass **10/10 GC-none** (`source-proxy-object-handles-canonical-gc-none-recheck.log`); the initial nonexistent active-info filename is retained as a runner diagnostic. GLsync pointer identity, other lost dispatch, remote mapping and wrapper GC remain separate.
- The Source optional Wasm extern-cache lookup (`6a713b3d`) fixes a reproduced absent-versus-present-undefined mismatch. Checked memory-store helpers (`146b783d`) retain actual frame/Store/storage ownership and both source overflow branches. Canonical memory/cache/module files pass **3/3 production GC-none** (`source-memory-cache-canonical-prod-gc-none.log`), following separate package annotations and fixture guards. Original private production/fixture diagnostics remain retained and scoped in [cache evidence](WASM_EXTERN_CACHE_OPTIONAL.md) and [memory mapping](WASM_MEMORY_STORE_SOURCE.md). The actual opcode interpreter and instantiation/collector graph remain unfinished; the historical 96-file proof predates this new 97th file.
- Frozen exact canonical `b6a80afd0288b09d9fa6db393dd6243a8cb5f626` now passes **97/97 WebAssembly files in each GC mode** (151.6 s default /150.3 s GC-none), with all 4,479 tracked contents unchanged. Its 211 non-Markdown Wasm and 490 LibJS files match canonical at recording. The new checked memory helper and optional extern-cache correction are included; later changes retain separate scope. See [complete proof](WASM_SCALAR_VERIFICATION.md). GLsync now retains generated Source proxy pointers separately from native pointers (`20f01f35`); its native/public/object/lifetime checks pass **4/4 GC-none** (`source-sync-proxy-pointer-canonical-gc-none.log`). Other sync owner/loss/timeout and remote dispatch boundaries remain separate.

- Source sync CPU ownership (`ebb999ba`) and actual generated lost-wait default zero (`b99ba566`) pass **6/6 canonical GC-none files** (`source-sync-owner-lost-canonical-gc-none.log`). The separately translated compositor timeout override zero (`759fc966`) passes **3/3** (`source-sync-host-timeout-canonical-gc-none.log`); its affected legacy state fixture (`1ebe04d1`) also passes (`source-sync-host-timeout-legacy-canonical-gc-none.log`). Public timeout conversion remains observable before body entry. Shader source/compile early gates (`feaeb496`) pass **4/4 native/public/legacy owner files** (`source-shader-command-owner-canonical-gc-none.log`). These later focused checks do not relabel the frozen 120/121 typed WebGL sweep. Other method loss/ownership, actual remote mapping and wrapper GC remain open.
- Document inline CSP and the global Trusted Types factory now read the actual settings container once (`e269a899`), preserving response header policies and avoiding duplicate violations. Canonical policy/Trusted Types/Base/violation/bridge checks pass **5/5 GC-none** (`source-csp-policy-owner-canonical-gc-none.log`). Standalone documents retain their explicit compatibility adapter. See [policy-owner source boundaries](DOCUMENT_CSP_POLICY_OWNER.md); genuine Meta policy insertion, native Document policy storage, complete violations and realm ownership remain separate.
- Source UTF8 retained raw decoder state (`cecf2133`) passes **11/11 Encoding files GC-none** (`source-utf8-decoder-canonical-gc-none.log`); its actual native debug/release probe passes 11,932 sequences, 60 capacity states and 27 fatal short-destination calls, reproducing both canonical JSON fixtures exactly. Whole-input consumer wiring (`a97fa44a`) removes the malformed-prefix ASCII loss and duplicate replacement. All **14 canonical Encoding/FileReader files pass GC-none** (`source-utf8-whole-input-canonical-gc-none.log`); all 903 actual bridge goldens match canonical values in both native profiles (`source-utf8-whole-input-canonical-probe.log`). [Source mapping](UTF8_DECODER_SOURCE.md) distinguishes this completed consumer from pending outer streaming/BOM lifecycle, multibyte, UTF16 destination and native owner work. The frozen native e93 bundle predates these changes.
- Complete Source throw-handler unwind helper (`4cf4a00c`) searches actual current-frame labels, resolves tags through the real module, retains catch order, appends fields/reference as required and preserves branch arity. Default and production GC-none focused checks pass privately; canonical unwind/exception/frame-owner files pass **3/3 GC-none** (`source-exception-unwind-canonical-gc-none.log`). [Mapping and checks](WASM_EXCEPTION_UNWIND_SOURCE.md) retain the original fixture compiler diagnostic and distinguish the helper from its pending opcode/cross-frame execution callers. This 98th file is outside the older frozen 97-file proof; its newer immutable full-sweep evidence is recorded below.

- Frozen exact canonical `221fe60c3b1f6220a23488774f8a0626c3d9d3ad` passes **98/98 WebAssembly files in each GC mode** (328.4 s default /326.2 s GC-none), with all 4,496 tracked contents unchanged. Its 213 non-Markdown Wasm and 490 LibJS files match canonical at recording. This includes the complete current-frame throw-handler helper; actual opcode/cross-frame callers, instantiation and collector ownership remain unfinished. [Full proof](WASM_SCALAR_VERIFICATION.md) records exact manifests, logs and dependency scope.
- Source shader diagnostics (`a80ff856`) pass **2/2 canonical native/public files with GC disabled** (`source-shader-diagnostic-owner-canonical-gc-none.log`), and shader deletion gates (`8ff10cd5`) pass **4/4 new and existing owner files** (`source-shader-delete-owner-canonical-gc-none.log`). Real returned strings, driver state/errors and retained object identity are checked. Other method loss/owner, robust-query ABI and remote/WrapperWorld boundaries remain separate.
- The actual Source UTF8 outer lifecycle (`f25d6354`) passes **13/13 canonical Encoding files with GC disabled** (`source-utf8-outer-canonical-gc-none.log`). The native pinned Rust probe passes **5,000 sequences, 12 observed capacity states and 144 genuine fatal calls** in both profiles; both generated streaming JSON fixtures match canonical values exactly (`source-utf8-outer-canonical-probe.log`). [Mapping](UTF8_DECODER_SOURCE.md) preserves fixed-UTF8 scope, raw versus owned output distinctions, and pending other-label/UTF16/stream-wrapper work. This does not extend the older frozen browser bundle's proof.

- Actual Common UTF8 consumer ownership (`b886b9ba`) passes **15/15 canonical Encoding and native FileReader files with GC disabled** (`source-utf8-common-canonical-final-gc-none.log`). Focused owner tests compare 1,876 actual native owned calls, lifecycle slots, queued outputs/errors and a compiled cold-owner invariant failure. Source language publication extraction (`acd93cad`) passes **3/3 actual retained-layout, inherited-attribute and DOM-layout files** (`source-language-publication-canonical-gc-none.log`). Full Rust publication/pseudo-text and the genuine Meta caller retain separate scope.
- Source shader parameter CPU gates (`20d87431`) pass **4/4 canonical new/existing native/public parameter files with GC disabled** (`source-shader-parameter-owner-canonical-final-gc-none.log`), preserving the genuine eager driver query before Source pname dispatch. The exact robust ANGLE ABI is independently translated in `08539afd`; its canonical checks remain pending. Initial nonexistent-file runner invocations for the Common/parameter batches are retained separately and are not counted as passing runs.

- CSP policy reconstruction now copies the real typed Origin (`f99b9f29`), retaining opaque nonces/file types and explicit tuple ports. Both reproduced pre-fix origin failures are fixed; canonical actual settings-policy/Base/origin checks pass **3/3 GC-none** (`source-csp-origin-projection-canonical-gc-none.log`). [Source mapping](CSP_ORIGIN_COPY_SOURCE.md) keeps native policy storage/violation/realm boundaries explicit. Source Wasm branch-to-label (`c8219046`) passes **3/3 canonical branch/exception/frame-owner files** (`source-branch-to-label-canonical-gc-none.log`); actual opcode callers remain unfinished. The exact robust shader getter (`08539afd`) passes **2/2 canonical native/public files** (`source-shader-parameter-robust-canonical-gc-none.log`).

- Frozen canonical `b7e1b970429055e97046e221e182e93714549cb2` passes production build/headless, **nine targeted comparisons pixel-exactly** across the initial three and corrected six-case run, and **11/11 configured smoke cases**. All 4,528 tracked contents and native binary stay unchanged. The initial wrong-relative-path invocation is retained as coordinator runner evidence. [Native proof](NATIVE_FROZEN_B7E1B970.md) records all hashes, commands, unchanged tolerance residuals and later-change scope. The same exact detached snapshot passes **99/99 WebAssembly files in each GC mode**, with 215 Wasm/490 LibJS package files matching canonical; [full proof](WASM_SCALAR_VERIFICATION.md) keeps actual runtime omissions explicit.
- Actual Meta lifecycle/language/CSP append (`df15dec2`) and real origin owners pass **3/3 canonical Meta/layout/origin files GC-none** (`source-meta-language-origin-canonical-gc-none.log`). Lost shader output suppression (`57f16242`) passes **2/2 canonical native/public files** (`source-shader-query-lost-canonical-gc-none.log`). Decoder flush reset (`261b55b2`) passes **3/3 canonical reset/Common/stream files** (`source-text-decoder-reset-canonical-final-gc-none.log`); actual pinned UTF16 bridge witnesses pass both profiles and match the canonical fixture (`source-text-decoder-reset-canonical-probe.log`). The initial nonexistent decoder-neighbor invocation remains a separate runner diagnostic. These focused slices retain the documented native policy-container, UTF16 destination and remaining WebGL method boundaries.

- The actual UTF8 variant/raw UTF16 destination (`2d864516`) and retained outer UTF16 owner (`610757ee`) pass all **17 canonical Encoding files plus the genuine native SyncText file, 18/18 GC-none** (`source-utf16-owner-canonical-gc-none.log`). The pinned native probe passes both profiles and exactly reproduces all five JSON fixtures and the 655,360-byte prefix fixture (`source-utf8-utf16-owner-canonical-probe.log`): 65,536 byte pairs, 3,024 prefix edges, 11,932 raw/replacement sequences, 5,000 outer sequences, 12 capacity states and 16 real failed nonempty callbacks. TextDecoder now calls that retained UTF16 owner (`2710a633`); its new/Common/reset/stream/SyncText canonical checks pass **5/5 GC-none** (`source-text-decoder-utf16-caller-canonical-gc-none.log`). [Source mapping](UTF8_DECODER_SOURCE.md) retains other-codec, BufferSource/native wrapper, OOM and physical allocation boundaries. These later features are outside the frozen `b7e1b970` bundle proof.
- Source isShader CPU gates (`ee715130`) and its explicit nullable host adapter (`1e0ef302`) pass **4/4 canonical typed/public/aggregate files GC-none** (`source-is-shader-owner-nullable-canonical-gc-none.log`). The separately translated generated Boolean loss default (`fcabf49a`) passes **2/2 canonical actual native/public files** (`source-is-shader-lost-canonical-gc-none.log`). Genuine EGL loss and matching Other native names exercise the driver boundary; these checks do not constitute a new full WebGL sweep. [WebGL scope](../../webgl/PORT_STATUS.md) keeps remaining families, remote transport and wrapper ownership explicit.
- Shared actual policy records and persistent lazy Document ownership (`3006c89b`) pass **five of six initial canonical GC-none files** (`source-document-policy-owner-canonical-gc-none.log`); the sole failure was the independent old history clone assertion expecting a bare IPC tag after Source storage defaults were already translated in `528ae74e`. Source SessionHistoryEntry.cpp constructs StorageSerializationRecords. The separately corrected fixture (`30e5d944`) verifies cloned storage kind, exact copied bytes and decoded null/undefined; it and the existing storage-record neighbor pass **2/2 GC-none** (`source-policy-history-storage-default-canonical-gc-none.log`). The original failure remains retained. [Shared-owner mapping](DOCUMENT_POLICY_CONTAINER_SHARED_RECORDS.md) preserves pending current-settings routing, own-Document consumers and the native PolicyList/GC graph; this prerequisite does not close whole-policy parity.
- Source isProgram CPU gates (`2ff42667`) and explicit nullable host calls (`8dda9ae6`) pass **4/4 canonical typed/public/aggregate files GC-none** (`source-is-program-owner-nullable-canonical-gc-none.log`). The actual UTF16 raw variant (`ccab052b`) passes its canonical focused file with GC disabled (`source-utf16-raw-canonical-gc-none.log`); its pinned native probe reproduces all three canonical artifacts exactly in both profiles: 262,144 exhaustive unit/capacity observations, 15,248 retained sequences and 14 capacity states (`source-utf16-raw-canonical-probe.log`). [Decoder mapping](UTF8_DECODER_SOURCE.md) preserves the still-pending UTF16 outer owner and public caller defect.
- Source Wasm checked load helper (`8c1d625f`) passes **3/3 canonical load/store/Configuration files GC-none** (`source-memory-load-canonical-gc-none.log`). Actual pinned C++ read bodies produce **3,520 exact observations in each optimization profile**, including signed, floating NaN and u128 values at 16 byte offsets; both actual short-span VERIFY calls abort. The canonical native TSV matches exactly (`source-memory-read-canonical-probe.log`). [Mapping](WASM_MEMORY_LOAD_SOURCE.md) retains real opcode/native-dispatch, SIMD, typed-store, instantiation and collector boundaries. The new 100th test file is outside the frozen 99-file package sweep.

- Current Window/Worker settings policy-owner routing (`3df450e2`) passes **4/4 canonical GC-none files** (`source-settings-policy-owner-canonical-gc-none.log`): settings/environment, genuine Meta CSP and actual Fetch security consumers. Subsequent own-Document Meta referrer (`78c8637a`) and CSP initialization (`35b6eca9`) pass their two canonical files (`source-document-initialization-referrer-canonical-gc-none.log`). SourceSnapshot (`9ffc676d`) clones its source Document directly, while Meta CSP intentionally retains current-settings append. [Referrer mapping](META_REFERRER_ACTUAL_DOCUMENT_POLICY.md), [snapshot mapping](SOURCE_SNAPSHOT_OWN_DOCUMENT_POLICY.md), [initialization mapping](DOCUMENT_CSP_INITIALIZATION_OWN_POLICY.md) and [supplemental Meta proof](META_CSP_CURRENT_SETTINGS_REASSOCIATION.md) preserve genuine reassociation/adoption, typed-origin/order and no-effect Source initialization boundaries; native PolicyList/GC graph remains open.
- UTF16 retained outer owner (`7b0ee71b`) and initialized isProgram loss (`f8947c49`) pass **3/3 canonical GC-none files** (`source-utf16-owner-program-loss-canonical-gc-none.log`). The actual native outer probe exactly reproduces all three canonical artifacts in both profiles: 13,840 sequences, 28 capacity states and 32 nonempty failed callbacks (`source-utf16-owner-canonical-probe.log`). The public UTF16 TextDecoder caller (`61390ff6`), separately witnessed BOM-override fixture (`5e046bdc`), native SyncText and program diagnostics pass **5/5 canonical GC-none files** (`source-utf16-caller-diagnostic-canonical-gc-none.log`); the original whole-input UTF8 EOF probe exactly reproduces the canonical eight-case artifact. Initial private 20/21 Encoding failures remain retained; the independent corrected snapshot passes 21/21 in both modes. [Decoder mapping](UTF8_DECODER_SOURCE.md) keeps actual whole-input/common/native representation boundaries distinct.
- Source program creation loss (`c7247418`) passes **2/2 canonical GC-none files** (`source-program-creation-lost-canonical-gc-none.log`). Program diagnostic CPU gates (`b54dbb39`) are in the five-file batch above. Program parameter CPU gates (`d78f0f54`) and genuine Meta referrer pass **4/4** (`source-meta-referrer-program-parameter-canonical-gc-none.log`); exact robust ABI (`1c6e4c5c`) and SourceSnapshot pass **3/3** (`source-program-robust-snapshot-canonical-gc-none.log`). Actual EGL/JSC owner, pending native error and eager query ordering are retained. [WebGL mapping](../../webgl/PORT_STATUS.md) preserves initial stale legacy owner assertion diagnostics and pending other families/remote/GC boundaries.
- The same four-slot UTF16 variant's actual UTF8 destination (`bdf1ecf8`) and initialized regular/robust program-loss outputs (`6688a7e5`) pass **3/3 canonical GC-none files** (`source-utf16-utf8-program-query-lost-canonical-gc-none.log`). Both native profiles exactly reproduce the five raw UTF8 artifacts, including 262,144 unit/capacity records, 15,248 sequences, 14 states, 3,168 prefix edges and 672 mixed destination sequences (`source-utf16-utf8-raw-canonical-probe.log`); the separate actual UTF8 FFI passes 32 EOF scenarios/64 calls. The pending Common/Stream UTF8 caller still reproduces its old EOF defect until its own owner wiring lands. These raw/native checks do not close broader decoder or WebGL parity.
- Actual Wasm typed pop-and-store (`a592d492`) passes **4/4 canonical typed/load/store/Configuration GC-none files** (`source-memory-typed-store-canonical-gc-none.log`). The original C++ ConvertToRaw probe produces 200 exact numeric/float/u128 byte layouts in both profiles and matches canonical TSV; 1,800 actual source-mode writes exercise them. The fixed local temporary follow-up (`2747b573`) passes canonical production GC-none, preserving the rejected private release-candidate diagnostic. Frozen exact `b822d7f4a35a9c95fc512442d46778bf96bf03de` passes **101/101 Wasm files in each GC mode** (357.1s /355.0s), with all 4,593 tracked contents unchanged. [Full proof](WASM_SCALAR_VERIFICATION.md) explicitly predates the later fixed local owner; [store mapping](WASM_MEMORY_STORE_SOURCE.md) records that follow-up's focused checks. Actual execution/dispatch, remaining SIMD, instantiation and collector graph remain open.
- The physical module inventory is refreshed at `ff7d8bff`: **429,810 implementation V LOC and 146,677 test V LOC**, with all 78 owners disjoint and shared Selection/UIEvents DOM files counted once. The retained `Build/audit-fixes/source-current-module-loc-ff7d8bff.json` hashes to `2e9fbf57caf2c95116f1614caed708ee24c3a06a4377bcde2372e98d9be2097f`. Upstream remains 1,193 current-module C++ units/329,970 LOC. Structural mapping counts do not establish behavioral equivalence, and the 32 fixed/25 partial/9 open finding ledger is unchanged.
- Frozen exact `9a749e4ad6c29ef73ce1c83901eb89726df4abcf` passes production build/headless, all **nine targeted comparisons pixel-exactly across initial five and separate remaining four**, and **11/11 smoke cases** (eight exact; unchanged three tolerance residuals). Two native browser launch traps stopped the original comparison invocation; its failed log/initial manifest remain retained, with no cause inferred from the Fontconfig warning. All 4,612 tracked contents and the binary remain unchanged. [Native proof](NATIVE_FROZEN_9A749E4A.md) records exact commands/hashes and later-feature exclusions. The same exact detached revision passes **101/101 Wasm files in each GC mode** (420.9s /414.6s), now including the fixed temporary owner and direct source2 case; [full package proof](WASM_SCALAR_VERIFICATION.md) retains actual runtime omissions. Supplemental Meta current-settings proof passes its canonical corrected GC-none file (`source-meta-current-settings-canonical-corrected-gc-none.log`); the initial nonexistent test-path invocation remains a separate runner diagnostic.

- The next continuation batch passes canonical focused UTF16/Common/whole/BOM **5/5**, shared referrer/header **5/5**, shader loss/program-deletion owners **10/10**, lane-store neighbors **4/4**, genuine redirect/program loss **4/4**, linking owners **4/4**, lane-load/JIS/link-loss **4/4**, and final CSP byte/ASCII neighbors **4/4**, all GC-none. Both native profiles reproduce ten final canonical fixture artifacts exactly; original whole-input UTF16 has 1,504 cases and zero naturally reachable reserve calls. [Exact focused evidence](CONTINUATION_UTF16_REFERRER_SIMD_SHADER_VERIFICATION.md) preserves earlier-batch/current-gate scope and the unchanged **32 fixed/25 partial/9 open** ledger. The 103-file Wasm helpers and these later consumers are outside the frozen `9a749e4a` native/101-file proof.

- Current disjoint physical module inventory at `eea67a65` is **430,862 implementation V LOC /148,372 test V LOC** across 78 owners. Retained proof `Build/audit-fixes/source-current-module-loc-eea67a65.json` SHA256 is `b7aa9edc3f3186ddd0a076cdd95d05a4650284c46b3d2af2650a206a7bf639c8`; upstream pin and structural/behavioral distinctions are unchanged.

- Frozen canonical `a85c3b9224641a439e14b1d6131e9f8b80855a9f` passes production build/headless, **9/9 targeted comparisons pixel-exactly in one invocation**, and **11/11 smoke cases** (eight exact; unchanged three tolerance residuals), with all **4,671 tracked contents and binary unchanged**. [Native proof](NATIVE_FROZEN_A85C3B92.md) records exact hashes/commands and later-feature exclusions. The same exact detached snapshot passes **103/103 Wasm files per GC mode** (673.357s /660.806s), including both Source lane helpers; [full package proof](WASM_SCALAR_VERIFICATION.md) retains actual runtime omissions. Later zero-load/MemoryBuffer guard, Shift_JIS and CSP/WebGL consumers are separate scope.

- Post-freeze actual CSP Response HeaderList/typed URL and separate HTML String adapter pass **2/2 canonical GC-none files** (`source-csp-response-string-canonical-gc-none.log`,39.981s). Program validation CPU/loss/use CPU and both updated aggregate owner files pass **8/8** (`source-program-validate-use-canonical-gc-none.log`,115.771s). Shift_JIS raw/JIS tables/zero load pass **3/3** (`source-shift-jis-raw-zero-load-canonical-gc-none.log`,11.967s); actual retained Shift_JIS owner and useProgram loss pass **3/3** (`source-shift-jis-owner-use-loss-canonical-gc-none.log`,50.755s). Native Source raw/outer/FFI and zero-layout probes reproduce all final canonical fixtures exactly in both profiles, including 524,288 raw records, 1,988 outer sequences and seven genuinely fatal owner witnesses. These focused checks postdate the frozen bundle; Common/public UTF16 callers, native policy/GC and other GL families remain distinct work.

- The genuine empty-owner production `MemoryBuffer::copy_to` witness previously returned after invalid offset1 with zero destination; the unchanged ignored failure log is retained. Source ordered VERIFY guards are now explicit and pass **1/1 canonical production GC-none** (`source-memory-copy-to-guard-canonical-production-gc-none.log`,13.462s), plus private ordinary three-file guard/lane/zero checks. [Production invariant mapping](WASM_MEMORY_COPY_TO_PRODUCTION_VERIFY.md) scopes other MemoryBuffer invariants and the new 105th file outside frozen Wasm103.

- The next continuation completes actual Shift_JIS raw/shared UTF16, Common/direct TextDecoder, whole UTF8 and selected-BOM callers; Source resource/file/blob-entry origin prerequisites and actual CSP self matching; and attach/detach/bind-attrib/uniform-location CPU/lost branches. All24 incremental canonical focused runs pass, including actual FileReaderSync/native primitive checks and the updated GL aggregate owners. Original native profiles reproduce all new canonical Shift_JIS fixtures exactly. Final private Encoding34 passes34/34 in both GC modes with its entire4,174-file snapshot unchanged. [Bounded integration evidence](CONTINUATION_SHIFT_JIS_ORIGINS_WEBGL_MEMORY_VERIFICATION.md) distinguishes those scopes from current canonical whole-checkout and public runtime ownership.

- Every VERIFY site in the translated MemoryBuffer/byte-span file now remains explicit in production. Actual safe pre-fix failures and passing compiled subprocesses cover copy/fill/overwrite/move/resize/reverse-chunk/span predicates; the cage-base guard has reachable real-owner tests but no fabricated null-cage witness. The package has114 test files, outside frozen Wasm103/native evidence. The detailed method documents preserve initial test assumptions/compile diagnostics separately from clean passing checks. PrimitiveStorage/allocator, dispatch and collector work remain open, and the32 fixed/25 partial/9 open ledger is unchanged.

- The October 5 resumed batch integrates the reviewed actual-origin StorageKey and hostless adapter correction (`c25970c8`), retained getParameter driver selection (`c97ca4fb`), and the Source WebGL2 zero-timeout return (`477ea688`), including focused tests. It records the already integrated UTF8 whole Off owner and selected BOM caller evidence. Canonical StorageKey checks pass 6/6 GC-none, parameter owner checks 4/4, and timeout checks 2/2; the original timeout assertion failure is retained separately.
- Frozen canonical `6f1df913da94d2b294fdeadcd29dc7a8cd7f6868` passes **114/114 Wasm, 36/36 Encoding and 4/4 StorageAPI files in each GC mode**, plus the four-file GC-none caller/main batch (including the 66-function main regression). Production build/headless startup, **9/9 targeted pixel-exact comparisons** and **11/11 configured smoke comparisons** pass. Both manifests retain the same **4,789 unchanged tracked files**; the three historical smoke tolerance residuals are unchanged. [Complete resumed-batch proof](FROZEN_6F1DF913_CONTINUATION.md) records commands, hashes, scope and the next string-cache/Blob-partition work. The module inventory is **431,819 implementation V LOC / 152,385 test V LOC** across 78 owners. The ledger remains **32 fixed / 25 partial / 9 open**; these results do not establish complete runtime or source parity.

- The native Source string cache now reaches actual getParameter callers (`b1b05829`). Real two-context regressions reproduce the original warm-query driver switch and cold/lost foreign-string read. Corrected typed/public cache, alias, loss, restore and empty-reply checks pass **6/6 GC-none** and **8/8 default-GC files**, including related Source proxy/query owners. [Source mapping and evidence](WEBGL_PARAMETER_STRING_CACHE.md) keep those focused results separate from the preceding frozen production bundle. Actual Blob-store settings/partition ownership and the full native transport/realm/GC graph remain open; the ledger stays **32 fixed / 25 partial / 9 open**.
- Refreshed disjoint module inventory at `b1b05829`: **431,834 implementation V LOC / 152,487 test V LOC** across 78 owners. Artifact `Build/audit-fixes/source-current-module-loc-b1b05829.json` has SHA256 `c08d4e7ee80b3b28e1ae73e17f80e99305a48ef9709501757ebd5eafb2f8829e`. Physical counts and structural mappings retain their existing scope and do not establish parity.

- Actual Blob URL creator settings and live objects now reach the Source store and DOMURL parser (`6756a0cf`). Fresh parsed URLs copy Blob bytes/type or the MediaSource tag and retain the actual current settings Origin; previously parsed snapshots survive reassociation and removal. Real Document unload compares settings identity, so colliding textual IDs cannot remove another owner's entries. The executed original missing-entry failure and initial fixture diagnostic are retained; final checks pass **6/6 default and 8/8 GC-none** files. [Source ownership evidence](BLOB_URL_SETTINGS_SNAPSHOT_OWNER.md) distinguishes the preserved Legacy store/callers and pending typed partition/revoke/request-URL integration. The ledger stays **32 fixed / 25 partial / 9 open**.

- Copied Blob URL entries now authorize using non-storage StorageKeys from actual requesting settings/Environment owners (`02226729`). Opaque and file-origin nonce identity, base creation URL versus settings selection, reassociation, copied object return, top-level bypasses and actual current-context DOMURL revoke pass **5/5 files in each GC mode**. [Partition and revoke evidence](BLOB_URL_PARTITION_ACTUAL_ENVIRONMENT.md) retains the initial V interface/sum-type compiler diagnostics and Source fragment behavior. Compact DOM URL caches, actual Fetch/media callers, native public exposure, IPC and complete GC ownership remain separate. The ledger stays **32 fixed / 25 partial / 9 open**.

- Refreshed disjoint module inventory after the Blob owner/partition batch at `316e3d5b`: **432,055 implementation V LOC / 152,777 test V LOC** across 78 owners. Artifact `Build/audit-fixes/source-current-module-loc-316e3d5b.json` has SHA256 `bbbf06df6a9888b97104cd52aa538909a7dbfb9acb4c0cba7217c9f91b7b5fdc`. Counts retain their physical/module-owned scope and do not measure parity.

- Actual owned DOM URL parsing (`d1531756`) retains genuine settings/store snapshots instead of sharing entries by serialized cache key. Final canonical checks pass **3/3 default and 4/4 GC-none**, including the 66-case main regression; the original missing-entry assertion and initial old-V navigation code-generation diagnostics are retained. [Owner evidence](BLOB_URL_DOM_RECORD_OWNER.md) records the required 509 named-literal changes, unchanged final file hashes and explicit Fetch/media/public-binding boundaries. No new production or screenshot proof is claimed.

- Actual Blob scheme Request/Environment ownership (`08d65915`) consumes retained snapshots, selects real reserved/client origins and checks the actual client Window's logical navigable. Final Fetch/media caller checks pass **2/2 default and 5/5 GC-none**, including the 66-case main regression. [Fetch evidence](BLOB_URL_FETCH_ACTUAL_REQUEST.md) retains the executed original network-error failure, compiler/import diagnostics and corrected self-fetch fixture; isomorphic HTTP type encoding is a separate follow-up.

- Actual node-document MediaSource URL authorization/attachment (`a0f60763`) checks copied origins and current relevant settings before resolving the real live MediaSource. Creation URL and logical parents control self-fetch; denial/Blob tags preserve remote fall-through. [Media evidence](BLOB_URL_MEDIA_ACTUAL_DOCUMENT.md) records the executed original attachment failure and the same unchanged **2/2 default / 5/5 GC-none** caller snapshot. Native public bindings, transport and full GC ownership remain separate; no new bundle proof or audit finding closure is claimed.

- Source isomorphic Encoding/HTTP/Blob type headers (`242a95de`) correct the actual UTF8-byte mismatch: Aéÿ now emits `41 E9 FF`. Full/ranged responses retain copied type/data after mutation and revocation; Source pairs/lone surrogates and truncation diagnostics are preserved. [Header evidence](BLOB_URL_HEADER_ISOMORPHIC_ENCODING.md) records the original executed failure, corrected earlier UTF8 fixture expectation and **3/3 default / 5/5 GC-none** final focused files. Legacy response behavior remains separate; the previous main proof predates this follow-up.

- Refreshed physical inventory after the owned DOM URL, actual Fetch/media caller and isomorphic header slices: **432,257 implementation V LOC / 153,283 test V LOC** across **78 owners** at `339274d8`. Artifact `Build/audit-fixes/source-current-module-loc-339274d8.json`, SHA256 `6e5ced7c80544dca349a6fdf17cbc9196cd7010193f0b00789fb2f828fb1a90d`, matches the module totals and preserved counting convention. Root/browser and external support remain outside those package totals. Counts and structural mappings do not measure parity; the ledger remains **32 fixed / 25 partial / 9 open**.

- DOM compatibility-cache value copies (`f273f1ef`) prevent both first-parse and cached-record path mutation from changing a URL or its actual Document base. The original probe executes both failures; final checks pass **3/3 default and 5/5 GC-none** files, including the main regression. [Copy-owner evidence](DOM_URL_CACHE_COPY_OWNER.md) records seven unchanged scoped code/test hashes and preserves the original failure. This supporting slice leaves the ledger at **32 fixed / 25 partial / 9 open**.

- DOMURL constructor value ownership (`c1e5845d`) prevents supplied-record path mutations from changing either direct or initialized platform URLs. The actual two-case regression reproduces both original failures. All three module files pass in both GC modes, and the actual Blob DOM owner passes its corrected private retry; the mixed-run support failure is retained explicitly. [Constructor evidence](DOMURL_CONSTRUCTOR_COPY_OWNER.md) records exact hashes and the fact that this feature postdates frozen `f273f1ef` production verification.

- Frozen `f273f1ef` verifies **47/47 Encoding/HTTP/DOMURL files in each GC mode**, a signed production build and headless startup, **9/9 targeted pixel-exact comparisons**, and **11/11 configured smoke comparisons** in a complete retry on the same binary. The first smoke attempt retains its two launch traps after one passing case; all three manifests preserve **4,812 unchanged tracked files**, and the historical three tolerance residuals are unchanged. [Frozen Blob continuation proof](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md) scopes this bundle separately from the subsequent constructor fix. The ledger remains **32 fixed / 25 partial / 9 open**.

- URL-encoded tuple parsing (`554c7759`) now preserves leading U+FEFF in each name/value through the actual DOMURL query owner. Both original BOM-loss cases execute and fail; all four DOMURL files pass with default GC and those four plus the Common UTF-8 owner pass with GC disabled. [BOM caller evidence](URLENCODED_BOM_OWNER.md) retains the separate invalid test-path diagnostic. This caller correction postdates the frozen browser bundle and does not change the audit counts.

- Native URLSearchParams exposure (`6f92c2ca`) now routes the public constructor, operations and live iteration/callbacks to actual V records through real page-script startup. Final default coverage passes three files across two commands; the combined GC-none batch passes **6/6**, including the **66-case** browser regression. Both unmodified Source sort fixtures match exactly in each GC mode. [Native query evidence](NATIVE_URLSEARCHPARAMS_OWNER.md) retains the absent-constructor baseline and three corrected fixture failures, with 3,162 code/native-helper files and 12 Source references unchanged during the recorded continuation checks. Public URL, foreign realms, Worker startup, generated diagnostics and full GC ownership remain separate; the ledger stays **32 fixed / 25 partial / 9 open**.

- The final `e4c10496` 78-owner inventory records **432,260 implementation V LOC / 153,334 test V LOC**. `Build/audit-fixes/source-current-module-loc-e4c10496.json` has SHA256 `cdad571376f1569bebf41a77ef646cbda251f071499318bbc2645832f61b4d16`; root/browser/external support stays excluded. These physical counts and structural mappings do not measure parity, and the ledger remains **32 fixed / 25 partial / 9 open**.

- The resumed `80a87cb9` inventory records **432,264 implementation V LOC / 153,358 test V LOC** across the same 78 owners. `Build/audit-fixes/source-current-module-loc-80a87cb9.json` has SHA256 `ca638210a9b93c36eb396c975c4bd78cade0677cc99b1297a6c64d5cad7e9e9a`. Native browser/root binding support remains outside this count. The physical inventory does not measure parity, and the ledger stays **32 fixed / 25 partial / 9 open**.

- Literal leading question marks in actual lazy DOMURL query owners (`4bdb79ab`) now survive initialization and writeback. The original first case panics on its missing literal name; final checks pass **5/5 default and 6/6 GC-none** files, including the native query binding neighbor. [Owner evidence](DOMURL_LITERAL_QUERY_OWNER.md) distinguishes that original executed failure from the second case's final replacement/identity checks. Public URL binding integration follows separately; the audit remains **32 fixed / 25 partial / 9 open**.

- Native URL core exposure (`a893f4ec`) now routes constructor, parse/canParse, all attributes, stringification and toJSON through genuine V DOMURL records in actual page-script startup. The shared query host preserves SameObject ownership, live iteration and writeback. Final checks pass **3/3 default and 6/6 GC-none files**, including the 66-case main regression; both unmodified Source fixtures reproduce all 377 expected lines exactly in each mode. [Native core evidence](NATIVE_URL_CORE_OWNER.md) retains the executed missing-global baseline and separate zero-runtime compiler failure, with 3,168 code/helper files, 23 selected Source references and two compiler executables unchanged through the passing runs. Object-URL statics, native MediaSource, foreign realms, Worker startup, full GC/IPC and current production verification remain separate. The ledger stays **32 fixed / 25 partial / 9 open**.

- Refreshed inventory at `4cd72e73`: **432,266 implementation V LOC / 153,384 test V LOC** across 78 owners. Artifact `Build/audit-fixes/source-current-module-loc-4cd72e73.json` has SHA256 `1b6d697d02b1ed067b195f1c31285ea25e0eb533bbc42a7ecc678bea0b628d1d`. Browser/root bindings remain outside these module counts. Physical LOC and structural mappings do not establish parity; the ledger stays **32 fixed / 25 partial / 9 open**.

- Native Blob/File object-URL methods (`4e83907a`) now use genuine wrapper objects and actual current HTML settings for creation/revocation. The actual page/Fetch caller retains copied bytes/type after revocation; reassociation, opaque partition identity, DOMString conversion, union brands, metadata and Document unload are verified. Final default coverage passes four files across three commands; the final unchanged GC-none batch passes **7/7**, including the 66-case main regression and two exact upstream URL outputs. [Native object-URL evidence](NATIVE_URL_BLOB_OBJECT_OWNER.md) distinguishes the absent-method baseline, interrupted reserved-keyword compiler run, private-field compiler failure and executed opaque-origin caller-fixture mismatch. All 3,170 code/helper files, 34 selected Source references and two compilers are unchanged through the corrected page retry and GC-none batch. Native MediaSource and the remaining realm/GC/IPC/production boundaries stay open; the ledger remains **32 fixed / 25 partial / 9 open**.

- The refreshed `4e83907a` inventory retains **432,266 implementation V LOC / 153,384 test V LOC** across 78 owners. Browser/root-only object-URL integration remains outside those counts. Artifact `Build/audit-fixes/source-current-module-loc-4e83907a.json` has SHA256 `af2f82659045167ef53acc3c0d4515a0c5325fcd121e2f838b2ed935669b068d`. Physical counts and structural mappings do not measure parity.


- Native MediaSource object URLs (`0ea70c17`) now retain genuine source/settings
  objects and reach the actual document media caller through changed script
  src replay. Supporting commits preserve queued-event target identity
  (`d397f279`) and update the cached audio/video source (`6d23dae1`), each with
  its own tests. The native duration conversion rejects BigInt correctly.
  Final coverage passes **eight default files across two commands** and
  **10/10 GC-none files**, including the **66-case** main regression; both
  unmodified URL outputs remain exact in each mode.
  [Native MediaSource evidence](NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md) preserves
  executed target/BigInt/attachment baselines, compiler-only fixture errors and
  the interrupted diagnostic separately. The final **3,176 code/helper files**,
  **42 selected Source references** and two compiler executables are unchanged.
  Native buffer wrappers, worker/foreign-world/physical GC/IPC ownership and
  updated production verification remain separate. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- The refreshed `0ea70c17` inventory contains **432,272 implementation V LOC /
  153,433 test V LOC** across 78 owners. Artifact
  `Build/audit-fixes/source-current-module-loc-0ea70c17.json` has SHA256
  `658656d07641cecbfa8bbcc605608b0574f8d1bddd1c3a922be0fb257e1496f8`.
  The six module implementation lines and 49 test lines belong to the queued
  source-event fix; browser/root integration remains outside those totals.
  Physical counts and structural mappings do not establish parity.

- Frozen `e385ac31` verification passes **119/119 Wasm/DOMURL files in each
  GC mode**, a signed production build and headless startup, and a pixel-exact
  native public URL/Blob/File/MediaSource page with explicit zero tolerances.
  The standard smoke set passes **11/11** with its three historical residuals.
  The first targeted animation capture fails with 10,000 differing pixels;
  the complete unchanged-binary retry passes **9/9 pixel-exact**. Five
  manifests preserve **4,844 unchanged tracked files**, upstream state and
  both compiler hashes. [Frozen native verification](FROZEN_E385AC31_NATIVE_URL_MEDIA.md)
  retains the initial failure and separate reporting/strict diff commands.
  Module inventory and the **32 fixed / 25 partial / 9 open** ledger are unchanged.

- Queued SourceBuffer event ownership (`a5b121e9`) now keeps the original
  EventTarget for twelve event sites. Seven actual Page/Document/media cases
  reproduce the original copied targets; cancellation and range-state
  algorithms already work and remain unchanged. SourceBufferList task
  ordering (`a7d2561f`) now queues additions with a live list and preserves
  both pinned active-track notifications. Four original list cases reproduce
  synchronous/intermediate/lost delivery and the missing second event.
  Final checks pass **18/18 files in each GC mode**, covering all **15 module
  files**, native host/page neighbors and the **66-case** main regression.
  [Buffer evidence](SOURCE_BUFFER_EVENT_TASK_OWNER.md) and
  [list evidence](SOURCE_BUFFER_LIST_TASK_OWNER.md) retain compiler-only and
  incorrect incremental-input fixture failures separately from the executed
  baselines. The final **4,847 tracked/selected files**, nine selected Source
  references and two compiler executables stay unchanged. Native wrappers,
  physical weak/strong GC equivalence and updated production verification
  remain separate; the ledger stays **32 fixed / 25 partial / 9 open**.

- Refreshed `a7d2561f` inventory: **432,276 implementation V LOC / 153,754
  test V LOC** across 78 owners. The module changes add four implementation
  and 321 test lines overall. Artifact
  `Build/audit-fixes/source-current-module-loc-a7d2561f.json` has SHA256
  `2651d60ec90e9af49ca7e99d65e41fcf6df9edc5a71332ce16d27fee58f61497`.
  Physical counts and structural mappings do not establish parity.

- Native MediaSource buffer owners (`1b436216`) now expose source/active lists,
  live indexed buffers, addSourceBuffer and core buffer operations through the
  actual Window and DOM media. Seven host cases and a real sourceopen page
  caller pass. A separate shared copier correction (`5846bfd3`) captures the
  intrinsic TypeError brand check; its original Crypto counter baseline records
  one author hook call, and corrected Crypto/SourceBuffer checks record zero.
  [Native buffer evidence](NATIVE_MEDIA_SOURCE_BUFFER_OWNER.md) and
  [error-brand evidence](BUFFER_SOURCE_ERROR_BRAND_OWNER.md) distinguish the
  **23/23 files in each GC mode before the brand fix** from the final affected
  **4/4 files in each mode afterward**. Unrelated Crypto formatting is restored
  with identical non-whitespace tokens and string literals. The signed frozen
  `1b436216` bundle passes startup and its public append/remove page matches
  **480,000 pixels exactly**, using explicit zero tolerances. The production
  snapshot records **4,853 files**, 16 selected Source references and two
  compiler executables unchanged. No current full screenshot/Wasm/LibJS sweep
  is claimed. Caller-realm TimeRanges and physical GC ownership remain open;
  the ledger stays **32 fixed / 25 partial / 9 open**. The refreshed module
  inventory remains **432,276 implementation / 153,754 test V LOC** across 78
  owners because these additions belong to browser/root support.

- Native TimeRanges and SourceBuffer.buffered (`35a7fa38`) now expose actual
  V range snapshots through the Window Runtime, with native metadata,
  unsigned-long index conversion and IndexSizeError DOMExceptions. Five host
  cases and an actual page append/remove callback preserve empty and populated
  snapshots after later mutation and detachment. [TimeRanges evidence](NATIVE_TIME_RANGES_OWNER.md)
  retains the executed absent-interface baseline separately from the
  compiler-only closure failure and corrected private fixture details.
  Final checks pass **22/22 files in each GC mode**, including all **15 MSE
  files**, the **66-case** main regression and binding/HTML neighbors. Both
  modes retain the same **4,859-file snapshot**, 12 selected Source references
  and two compiler hashes; a supplemental caller-realm policy hash is recorded
  separately. The existing removed-buffer guard remains a documented pinned
  Source deviation. Foreign realms, WrapperWorlds and physical GC ownership
  remain open, and this feature postdates the last production bundle.
  Module inventory is unchanged at **432,276 implementation / 153,754 test
  V LOC** across 78 owners. The ledger stays **32 fixed / 25 partial / 9 open**.

- Media buffered cache removal (`cc9b1e78`) now refreshes the actual owner before
  ready-state evaluation and queued updateend callbacks, preserving earlier
  snapshots and the append-only progress path. [Removal evidence](MEDIA_REMOVAL_RANGES_OWNER.md)
  retains a separate compatibility-compiler failure and corrected runtime
  baseline. Both affected files pass in both GC modes before and after
  unrelated formatting restoration. This corrects the existing per-buffer
  fallback; complete manager/aggregation and physical GC ownership stay open.

- Native HTML media buffered (`5f567830`) now returns the actual DOM owner's
  TimeRanges snapshots with native metadata and branding before replay.
  Created media reuse one native node; SVG namesakes remain unbranded.
  [Native evidence](NATIVE_MEDIA_ELEMENT_BUFFERED_OWNER.md) records four host
  cases, two page callers and **8/8 files in each GC mode**, including the
  **66-case** main regression. The final scoped two-file checks also pass in
  both modes after formatting restoration. The frozen signed production
  bundle passes startup and the public media page's **480,000 pixels exactly**;
  all **13 selected SVG pairs** are exact and **11 smoke cases** pass their
  existing bounds. The initial SVG comparator compile failure is retained
  separately; corrected comparisons reuse its captures and unchanged binary.
  Production snapshots retain **4,865 files**, 25 selected Source references
  and two compiler hashes. No new Wasm/LibJS sweep or full element hierarchy,
  foreign-realm, playback or physical-GC parity is claimed.

- Refreshed `5f567830` inventory: **432,292 implementation V LOC / 153,795
  test V LOC** across **78 owners**, with browser/root support excluded.
  Artifact `Build/audit-fixes/source-current-module-loc-5f567830.json` has
  SHA256 `a62f66f303cfab776748d45daac377beef970469e097adc2af7dec27de4b63ee`.
  Physical counts do not measure parity; the ledger stays **32 fixed /
  25 partial / 9 open**.

- Native HTML media state (`a699f872`) now exposes actual DOM-owner currentSrc,
  networkState, readyState, seeking, duration, paused and ended, with native
  readonly metadata and branding before replay. The compact readyState shadow
  is removed only for HTML media. [State evidence](NATIVE_MEDIA_ELEMENT_STATE_OWNER.md)
  records the executed missing-getter baseline, five final cases and **9/9
  files in each GC mode**, including the **66-case** main regression. The same
  unchanged **4,869-file** snapshot builds and signs successfully, passes
  startup, matches the public media-state page's **480,000 pixels exactly**,
  preserves **13 exact SVG pairs** and passes all **11 configured smoke cases**.
  Production retains 26 selected Source references and two compiler hashes;
  feature bytes match the subsequent commit. Module inventory is unchanged.
  Source ended scheduling, complete native media operations/events, playback,
  element hierarchy, foreign realms and physical GC remain open; the ledger
  stays **32 fixed / 25 partial / 9 open**.
- Media cached ended now recomputes at actual main-loop step 1 (`1e6de269`), including
  ready-state transitions and live owner state after seek, loop and reload.
  The independent event-loop prerequisite (`82f30d6f`) preserves paused callbacks,
  tasks and generation, and schedules native resume on unpause.
  [Boundary evidence](MEDIA_ENDED_STEP_ONE_OWNER.md) retains three executed
  baseline file failures, the stopped preliminary runs and nine final cases.
  Both frozen GC modes pass **15/16 files**, including the **66-case** main
  regression and real timer/AbortSignal pause callers, on the same unchanged
  **4,873-file** snapshot. The remaining file fails on existing
  float literals assigned to Document's integer viewport cache; the separate
  test-only correction (`558d92a7`) passes **1/1 file
  in each GC mode**. All 16 files have passing evidence across these runs,
  rather than one clean 16-file run. The same production snapshot builds,
  signs, passes startup, matches the existing media-state page's **480,000 pixels
  exactly** and passes all **11 configured smoke cases** within their existing
  bounds. The consolidated `Build/audit-fixes/media-step-one-evidence.json`
  has SHA256 `544b8a4e52fcea5d5b119ee083778d6564926d30e73a3709c7e66d1297e6dce6`.
  The actual Source manager/decoder Ended predicate,
  queued native media events/operations, full playback and prototype ownership,
  nested pause/spin behavior, realms and physical GC remain open. This is a
  selected lifecycle fix; the ledger stays **32 fixed / 25 partial / 9 open**.

- Media event target ownership (`2e994235`) now reuses the actual
  audio/video DOM target; completion timing (`33ffe100`) queues
  timeupdate, live pause/promise handling and ended as one media-element task
  after the step-1 cache refresh. [Completion evidence](MEDIA_END_TASK_DOM_OWNER.md)
  retains both genuine baseline failures and the separate test setup/identity/
  inactive-fixture diagnostics. All eight final cases and **14/14 files in each
  GC mode** pass, including the **66-case** main regression, on the same
  unchanged **4,878-file** snapshot. Its signed production build
  passes startup, the public media state/native event-owner viewport matches
  **480,000 pixels exactly**, and all **11 configured smoke cases** pass within
  existing bounds. The consolidated `Build/audit-fixes/media-end-task-evidence.json`
  has SHA256 `0978ed9fc35fc21beecae11e23dab3c2c30cc01db9ed62936be57621deb733df`. The refreshed 78-owner inventory contains
  **432,314 implementation / 154,244 test V LOC**
  across **2,183 owned files**, excluding browser/root support.
  Actual manager/decoder Ended state, native play promises, ordinary compact
  listener routing, other event scheduling and complete runtime/GC ownership
  remain open; the ledger stays **32 fixed / 25 partial / 9 open**.

- Duration event scheduling (`3c654b6b`) and volume/mute
  event scheduling (`214de36b`) now use their owning media task,
  preserving immediate duration/seek and effective-volume updates. The actual
  MediaSource caller suppresses unchanged duration values before the internal
  setter; listener mutations queue another task without reentrant delivery.
  [Property-task evidence](MEDIA_PROPERTY_TASK_OWNER.md) retains baseline,
  fixture and full-disk diagnostics. The final committed snapshot passes
  **20/20 selected files in each GC mode**, including eight new cases and the
  **66-case** main regression. Its signed production build passes startup,
  the public task-timing viewport matches **480,000 pixels exactly**, and all
  **11 configured smoke cases** pass within existing bounds. Consolidated
  evidence `Build/audit-fixes/media-property-tasks-evidence.json`
  is retained with SHA256 `bc5d3bcc93d3b48f195b6b3cc8fa3d4e0853abcac43e229b42ae603ebd003e0b`. The 78-owner inventory contains
  **432,322 implementation /
  154,501 test V LOC** across
  **2,185 owned files**, excluding browser/root support.
  Autoplay-policy pause, muted-style invalidation, native volume operations,
  complete media/MSE runtime and GC ownership remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Media rate setters (`96a8c005`) now queue ratechange and preserve signed-zero
  field assignment. The current-rate setter validates Source's finite 0–64 range.
  The separate load caller (`9dbdb6f5`) resets through that setter,
  canceling old owner tasks and propagating unsupported defaults before
  resource selection. [Rate/load evidence](MEDIA_RATE_TASK_LOAD_OWNER.md)
  retains both genuine runtime baselines and ten new cases. The same clean
  committed snapshot passes **23/23 selected files in each GC mode**, including
  the **66-case** main regression. Its signed production build and ordinary
  failure-branch rate probe pass with assertions stripped. The existing public
  duration-task viewport matches **480,000 pixels exactly**, and all **11 smoke
  cases** pass with identical residuals and no tolerance changes. Consolidated
  evidence `Build/audit-fixes/media-rate-tasks-evidence.json` has SHA256
  `d92b1af6e20570600088ed2dd8e5f0c4f7ec74bf984494cc8438abcda4802992`. The 78-owner inventory contains
  **432,331 implementation /
  154,721 test V LOC** across
  **2,187 owned files**, excluding browser/root support.
  Actual PlaybackManager rate/clock/pipeline delivery, native rate operations,
  complete media/MSE runtime and GC ownership remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Native playback-rate properties (`1ac087a6`) now read/write the actual
  DOM media owner, validate the receiver before restricted-double conversion
  and replay, preserve original thrown values and expose genuine
  NotSupportedError DOMExceptions. Successful writes retain queued live events
  and signed zero. [Native rate evidence](NATIVE_MEDIA_RATE_PROPERTY_OWNER.md)
  records six new cases, the corrected runtime baseline and intermediate
  compilation diagnostics. The same frozen committed snapshot passes **11/11
  affected files in each GC mode**, including the **66-case** main regression.
  Its signed production bundle passes startup, two public rate and created-audio
  viewports match **480,000 pixels each exactly**, all **13 SVG pairs** are
  exact, and all **11 smoke cases** pass within unchanged bounds and residuals.
  Evidence `Build/audit-fixes/native-media-rate-evidence-final.json` has SHA256
  `31686443d9e4233c73d9812620a867daf0953bd5fe8b878a0f903fb093974c6e`. Module-owned file hashes and physical counts remain unchanged;
  browser/root support is excluded from that inventory. Actual PlaybackManager
  rate/clock/pipeline delivery, complete media/MSE, other native operations and
  GC ownership remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Native volume/muted properties (`c2e279e5`) now reach the actual DOM media
  owner, check the receiver before required number/boolean conversion and
  replay, and preserve original thrown values. Range errors expose a genuine
  IndexSizeError with Source's exact message; writes retain immediate effective
  volume and queued live owner events. [Volume/mute evidence](NATIVE_MEDIA_VOLUME_PROPERTY_OWNER.md)
  records seven focused cases and the unchanged runtime baseline. The same
  frozen committed snapshot passes **14/14 affected files in each GC mode**,
  including the **66-case** main regression. Its signed production bundle
  passes startup, two public viewports match **480,000 pixels each exactly**,
  all **13 SVG pairs** are exact, and all **11 smoke cases** pass with unchanged
  bounds and residuals. Consolidated evidence
  `Build/audit-fixes/native-media-volume-evidence.json` has SHA256
  `029b4d0e1e55ef8532e6a5aaeb22cb2ae87f099f42b0e03fccee416dbab59a47`. The 78-owner inventory contains
  **432,331 implementation / 154,733 test V LOC** across **2,187 owned files**;
  browser/root support is excluded. Autoplay-policy pause, muted-style
  invalidation, actual manager/pipeline delivery, other media operations,
  complete media/MSE and physical GC remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Media currentTime generation caching (`a160812b`) now uses nonzero default
  precedence and one existing-clock sample per actual main-loop generation.
  Explicit seek/pause/metadata/load commits stamp the same counter, and clock
  notifications retain a stable same-turn value. [Generation evidence](MEDIA_CURRENT_TIME_GENERATION_OWNER.md)
  retains compile/setup diagnostics, all eight final runtime baseline failures,
  **6/6 focused** and **21/21 affected files in each GC mode**, including the
  **66-case** main regression. The signed production bundle, ordinary-branch
  real-loop/DOM probe, two exact adjacent volume viewports and all **11 smoke
  cases** pass. Consolidated evidence `Build/audit-fixes/media-position-generation-evidence.json`
  has SHA256 `e25b963b6cc92bc6b85383c8daa8e137b8649c0801e05436e38fbb8a38db0304`. The 78-owner inventory contains
  **432,348 implementation /
  154,939 test V LOC** across **2,188 owned files**.
  Native currentTime, physical manager clock/reset, remaining seek/play/pause/load,
  complete media/MSE, realms and physical GC stay open. The ledger remains
  **32 fixed / 25 partial / 9 open**.

- Native currentTime (`16f4c31c`) now reads/writes its actual audio/video
  model through native accessors. Receiver checking precedes restricted-double
  conversion/replay; original exceptions and assignment results survive. The
  compact page's independent currentTime shadow is removed. [Native time evidence](NATIVE_MEDIA_CURRENT_TIME_PROPERTY_OWNER.md)
  retains fixture/stop diagnostics and seven final runtime baseline failures,
  **4/4 focused** and **16/16 affected files across each GC mode**, including the
  **66-case** main regression. The initial no-GC disk and production linker I/O
  failures remain recorded; both failed test files and the build pass on sequential
  retries without changing frozen inputs. The signed production bundle/startup, two exact
  public time viewports, **13 exact SVG pairs** and all **11 smoke cases** pass.
  Consolidated `Build/audit-fixes/native-media-current-time-evidence.json` has
  SHA256 `733407c09f48dad861e951fc0becea8e510c2bf8a00fcb14a3f742569cd2c459`. The 78-owner inventory remains **432,348 implementation /
  154,939 test V LOC** across **2,188 owned files**; all owned hashes match and
  new browser/root support is excluded. Physical manager/clock/decoder/pipeline,
  remaining media operations, complete media/MSE, realms and physical GC remain
  open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Fast seek model/native (`a870b6b8` / `335564fd`) now clear the poster
  before HAVE_NOTHING, use each live clock comparison before queuing seeking,
  and expose fastSeek through its actual audio/video DOM owner. Receiver, arity
  and restricted-double conversion precede replay; original exceptions survive.
  [Fast seek evidence](NATIVE_MEDIA_FAST_SEEK_OWNER.md) retains nine runtime
  baseline failures, **3/3 model**, **4/4 native focused** and **20/20 affected
  files in each GC mode**, including the **66-case** main regression. Signed
  production startup, the ordinary-branch DOM model probe, two exact public
  viewports, **13 exact SVG pairs** and all **11 smoke cases** pass. Consolidated
  `Build/audit-fixes/native-media-fast-seek-evidence.json` has SHA256 `24eedb495add4c8f149d9fcc9af6c2db5e40810cae91c205b940fdea1d8720f3`.
  The refreshed 78-owner inventory has **432,347
  implementation / 155,053 test V LOC** across **2,189 owned
  files**; browser/root support stays excluded. Remaining seek algorithms,
  physical manager/clock/decoder, complete media/MSE, defaultMuted, realms and
  physical GC stay open. The ledger remains **32 fixed / 25 partial / 9 open**.

- Start-date model/native (`7ea057ff` / `5b86ed38`) now round Source timeline
  milliseconds away from zero and return fresh built-in Dates from the actual
  DOM audio/video owner after replay, with the compact timestamp copy removed.
  [Start-date evidence](NATIVE_MEDIA_START_DATE_OWNER.md) retains the initial
  fixture/compiler diagnostic and ten final runtime baseline failures, both
  **2/2 focused** batches and **23/23 affected files in each GC mode**, including
  the **66-case** main regression. Signed production startup, an ordinary-branch
  native DOM probe, two exact public viewports, **13 exact SVG pairs** and all
  **11 smoke cases** pass; the final SVG capture launch traps and its bounded
  retry on the unchanged binary remain recorded. Consolidated evidence SHA256:
  `44dcd0c5f43fe66a3f29e88172fa30cdea6535c95eecff2ad24f48bf996e1389`.
  The 78-owner inventory is **432,351 implementation /
  155,129 test V LOC** across **2,190 owned files**;
  browser/root support is excluded. Unrepresentable native Date values explicitly
  reject; that engine deviation, finer/physical metadata, realms, full media/MSE,
  defaultMuted and physical GC remain open. The ledger stays **32 fixed /
  25 partial / 9 open**.

- Pause caller/native (`f8691ab9` / `cb4a414e`) now
  select an empty resource before pausing and expose the zero-argument operation
  through the actual DOM audio/video owner. [Pause evidence](NATIVE_MEDIA_PAUSE_OWNER.md)
  retains nine runtime baseline failures, both **2/2 focused** batches and
  **18/18 affected files in each GC mode**, including the **66-case** main
  regression. Signed production startup, the ordinary-branch native probe,
  two exact public viewports and all **11 smoke cases** pass. Consolidated
  evidence SHA256: `6924901b16c1ebd14390132e9c6ac9273f191eadc3313953b8938bc8f26a1ab3`. The refreshed 78-owner inventory has
  **432,354 implementation / 155,221
  test V LOC** across **2,191 owned files**; browser/root support is
  excluded. Internal pause task/promise semantics, synchronous selection,
  remaining native methods, physical playback delivery, realms and complete
  media/MSE remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Explicit pause task/reason (`477996a3`) now changes state/clock
  immediately and queues timeupdate, pause and captured-batch rejection with one
  shared actual AbortError under the owning document context. [Pause-task evidence](MEDIA_PAUSE_TASK_OWNER.md)
  retains the initial depth-array fixture diagnostics, five corrected runtime
  baseline failures, **2/2 model** and **1/1 native page** focused files and
  **20/20 affected files in each GC mode**, including the **66-case** main
  regression. Signed production startup, the ordinary-branch native task/promise
  probe, two exact prior public pause viewports and all **11 smoke cases** pass.
  Consolidated evidence SHA256: `3165c0a20c125070eac1e100a211282274945e724158012b0cc523e0abcde500`. The 78-owner inventory is
  **432,371 implementation / 155,425 test V LOC**
  across **2,192 owned files**; browser/root support is excluded.
  Current Source's canceled-task settlement FIXME is preserved. Other promise
  paths, native play promises, synchronous selection, physical playback and
  complete media/MSE remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Internal play task/resolution (`fd83fa0a`) now queues play,
  waiting, playing and already-playing fulfillment. Playing commits the captured
  start position and fires before its batch resolves under the actual Document
  context. [Evidence](MEDIA_PLAY_TASK_OWNER.md) retains seven runtime baseline
  failures, final **2/2 model** and **1/1 native page** focused files, initial fixture
  diagnostics, the corrected inactive-task retrieval and the subsequent inactive
  pause-fixture drain (`5a2ec71a`). Frozen **22/22 affected
  files in each GC mode**, including the **66-case** main regression, signed
  production startup/probe, two exact prior pause viewports and all **11 smoke
  cases** pass. Consolidated evidence SHA256: `626b0b04ae5138cb4e8d69babdb0fedf4e457b40009275f0e222b804ecea9f39`.
  The 78-owner physical inventory is **432,398 implementation /
  155,688 test V LOC** across **2,193 owned files**;
  root/native support is excluded. Native play promises, public permission/error
  gates, started-playback/audio/wake-lock state, other media algorithms and actual
  manager/decoder delivery remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Started media audio state (`ee1714cc`) now follows Source's started-playback
  flag, enabled audio tracks and effective volume. Waiting/unpaused media stays
  silent; manager play/pause hooks precede owning PageClient and Document
  notifications, and queued playing events do not restart audio after pause.
  [Evidence](MEDIA_STARTED_AUDIO_OWNER.md) retains seven runtime baseline failures,
  initial fixture diagnostics, a clean three-file focused batch and frozen
  **27/27 affected files in each GC mode**, including the **66-case** main
  regression, real hidden-document timers and Page/PageClient neighbors. Signed
  production startup/probe, two exact prior public pause viewports and all
  **11 smoke cases** pass. Consolidated evidence SHA256:
  `393176a04cc6898b9ac90eb4764ff141ce9f327577832c1a4e2cbe03e7e17dc6`.
  The 78-owner inventory is **432,419 implementation / 155,923 test V LOC**
  across **2,194 owned files**; root/native support remains excluded. Actual
  Page-wide mute propagation, wake locks, native play promises, permission/error
  gates, full media algorithms and physical manager/decoder delivery remain open.
  The ledger stays **32 fixed / 25 partial / 9 open**.

- Media screen wake locks (`ca0036d2`) now retain the actual owning Page handle
  for potentially-playing video with selected video and enabled audio tracks,
  independent of volume/mute. Readiness, ended state and track callbacks update
  eligibility; pause, resource reset, adoption and explicit finalization release
  the correct owner without dropping another owner's lock. [Evidence](MEDIA_SCREEN_WAKE_LOCK_OWNER.md)
  retains six old-implementation runtime failures, the corrected acquisition-
  order fixture and a clean three-file focused batch. Frozen **31/31 affected
  files pass in each GC mode**, including the **66-case** main regression.
  Signed production startup/probe and two exact prior pause viewports pass.
  The initial smoke run's two Metal initialization traps remain recorded;
  a separate run on the unchanged snapshot/binary passes all **11 smoke cases**.
  Consolidated evidence SHA256:
  `3c1f42f55ea82829adde174f240c8f5f1be847c74663b4d0b783e69dd7e37ac1`.
  The 78-owner inventory is **432,494 implementation / 156,144 test V LOC**
  across **2,195 owned files**; root/native support is excluded. Actual Page-wide
  mute propagation, native play promises, permission/error gates, full media
  algorithms, physical manager/decoder delivery, native power-management
  transport and automatic GC finalization remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Page mute (`72210f57`) now dispatches through registered concrete media owners,
  queries each owner's current Document Page for effective volume and updates
  actual manager-volume, audible-state, PageClient and Document timer paths.
  Unchanged assignments suppress callbacks; public properties, playback state,
  volumechange and video wake locks stay intact. A separate correction
  (`b80844bb`) preserves the legacy media-record timer adapter and excludes
  unrelated attached documents. [Evidence](MEDIA_PAGE_MUTE_OWNER.md) retains
  six final old-implementation runtime failures, the initial heap annotation
  diagnostic, corrected focused checks and the initial 35/36 timer failures.
  Final frozen **36/36 affected files pass in each GC mode**, including the
  **66-case** main regression. Signed production startup/probe and two exact
  prior pause viewports pass. **Native smoke verification remains incomplete**:
  the initial run completes three comparisons before graphics startup traps;
  an unchanged-binary recovery completes zero. Five matching semaphore-disposal
  crash reports are retained, with the startup trigger unresolved. Consolidated
  evidence SHA256:
  `ac4faffd6f10c5baf9a7e36ab9d71d1dedb04326153630d4dbb7eb205adfe1d9`.
  The 78-owner inventory is **432,614 implementation / 156,375 test V LOC**
  across **2,196 owned files**; root/native support is excluded. Physical
  weak-node lookup, automatic GC finalization, general cross-Page registry
  integration, native play promises, permission/error gates, complete media
  algorithms, physical playback and native power transport remain open. The
  ledger stays **32 fixed / 25 partial / 9 open**.

- Actual media CSS states (`32139bfc`) now query the concrete HTML audio/video
  owner for paused/playing, element mute, seeking and blocked readiness. State
  changes refresh sibling, `:has()` ancestor and pseudo-element styles through
  typed invalidation plans, including adoption and shadow scopes. Production
  verification exposed stale tag-qualified `:has()` descendants; `728faa99`
  applies the ancestor walk's queued plans before computing styles, with an
  audio/video regression. The expanded checks also reproduced an older inactive
  document-timeline fixture on unchanged implementation; `9101b5b7` attaches the
  actual active Navigable and verifies inactivity after detachment. [Evidence](MEDIA_CSS_STATE_OWNER.md)
  retains eight original baseline runtime failures, the failed production probe,
  the tag-qualified regression and both initial **29/30** neighbor runs. Final
  frozen **30/30 affected files pass in each GC mode**, including the **66-case**
  main regression. Signed production startup/probe, both exact media-state
  viewports and all **11 native smoke cases** pass. Consolidated evidence SHA256:
  `3bdd41d899120c909a7da9ae8569ca08abbd1f579b59613b4818a0464c7a5e24`.
  The 78-owner physical inventory is **432,731 implementation /
  156,527 test V LOC** across **2,198 owned files**; root/native support is excluded.
  Native play promises, full resource/readiness/seek algorithms, defaultMuted
  initialization, Source Rust style-engine journal, physical playback and automatic
  GC ownership remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Media load reset events (`5fd0c862`) now queue abort, emptied and reset
  timeupdate on the actual owner, while its current unpaused pending play batch
  rejects synchronously with one AbortError under the Document context. Native
  `load()` (`3961abe6`) validates the actual DOM receiver before mutation replay,
  ignores extra arguments and propagates real exceptions. The initial frozen
  33-file runs each pass 32 files and expose one shared-loop drain assumption in
  the pause cancellation fixture. `e9133c7e` takes only the intended owner's
  tasks and checks the untouched second queue in pause/play fixtures; both pass
  in each GC mode. Thus all 33 affected files have passing evidence across the
  initial runs and focused reruns, including the 66-case main regression.
  Signed production startup, an ordinary production probe, both exact load
  viewports and all 11 smoke cases pass on unchanged implementation. [Evidence](MEDIA_LOAD_TASK_OWNER.md)
  preserves every failed run and the composite coverage distinction; SHA256:
  `6717783d05de0012592ec0e403a4f9b4cd90c359ad6e7ed63d41dd56bed6dc8d`.
  Stable-state selection, complete load/readiness/seek algorithms, native play
  promises, physical playback and automatic ownership remain open. The ledger
  stays **32 fixed / 25 partial / 9 open**.

- First decoded-data notification (`5ea723a0`) now queues loadeddata once per
  load on the actual media owner and releases its current Document load-delay
  token synchronously. Explicit and automatic load entry rearm the flag;
  repeated buffering transitions do not repeat the event. Six new model/native
  cases expose the old behavior on unchanged implementation and pass afterward.
  The initial 32-file runs each pass 31 files and expose one stale playing-task
  expectation. `d5122e2b` verifies loadeddata-before-playing delivery and keeps a
  listener-created promise outside the original captured batch; the corrected
  file passes in each GC mode. All 32 affected files therefore have passing
  evidence across the initial runs and focused reruns, including the 66-case
  main regression. Signed production startup, an ordinary audio/video probe,
  both earlier native-load regression viewports and all 11 smoke cases pass on
  unchanged implementation. [Evidence](MEDIA_LOADED_DATA_OWNER.md) preserves
  the failed runs and composite coverage distinction; SHA256:
  `0db0c15ff02fa6cfaafeff913b0c0f727d4fec9465ff1ffa519e69af8095b18f`.
  Other readiness events, full resource timing, native play promises, physical
  decoding and automatic ownership remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Metadata notification (`8691a3b4`) now queues loadedmetadata from the actual
  owner's exact nonempty-network nothing-to-metadata readiness transition.
  Fetched metadata and actual MediaSource initialization share that branch;
  native audio/video listeners observe live state before the later first-data
  event. Six new cases expose the original behavior in a validated runtime
  baseline and pass afterward. The initial default-GC neighbor run passes 24
  files before disk exhaustion prevents ten compilation results; all ten pass
  in a single-job recovery on identical bytes. Thus all 34 affected files have
  passing default-GC evidence across both runs. The first GC-disabled batch is
  interrupted for disk pressure; a complete later batch passes 34/34 files.
  Signed production startup, the ordinary native probe and both prior load
  regression viewports pass. Ten of eleven smoke cases pass initially; the
  final no-image capture passes pixel-exact separately on the same binary.
  [Evidence](MEDIA_METADATA_TASK_OWNER.md) retains all failed/interrupted runs
  and the composite coverage distinctions; SHA256:
  `302344eecb235f25281fb313f854de83f5f5fc33461457568bc02aa4681a70f9`.
  Canplay/canplaythrough, complete resource/readiness/seek behavior, native play
  promises, physical decoding and automatic ownership remain open. The ledger
  stays **32 fixed / 25 partial / 9 open**.

- Canplay notification (`f3fde94f`) now queues at the actual owner's exact
  nonempty-network current-or-less to future/enough readiness crossing. First
  data arrives before canplay; readiness-driven playing captures its original
  pending promise batch and start position before listeners can call play().
  Manager start stays immediate. Seven new model/native/MediaSource cases
  expose the old behavior in a compiled runtime baseline and pass afterward.
  Both final frozen neighbor runs pass **36/36 files**, including the **66-case**
  main regression; each is one complete run. Signed production startup, the
  ordinary native audio/video probe, both prior load regression viewports and
  all **11 smoke cases** pass on the unchanged binary. [Evidence](MEDIA_CANPLAY_TASK_OWNER.md)
  retains the baseline failures, frozen inputs, commands and artifacts; SHA256:
  `7e897a58d775946503d6000bee28e47e16e1973f9f9acdacf59d9561a78f5616`.
  Canplaythrough, full resource/readiness/seek and autoplay behavior, native play
  promises, physical decoding and automatic ownership remain open. The ledger
  stays **32 fixed / 25 partial / 9 open**.

- Canplaythrough notification (`f3c941ee`) now queues on the actual owner's
  changed nonempty-network transition into enough data, after any first-data,
  canplay and captured-batch playing task. The original play promises resolve
  before canplaythrough; future-to-enough queues only this notification.
  Seven new model/native/MediaSource cases expose the previous synchronous
  behavior in a compiled runtime baseline and pass afterward. The initial
  fixture compiler error is retained separately. Both final frozen selected
  neighbor runs pass **19/19 files**, including the **66-case** main regression;
  each is one complete single-job run. Signed production startup, the ordinary
  native audio/video probe, both exact prior load regression viewports and all
  **11 smoke cases** pass on the unchanged binary. [Evidence](MEDIA_CANPLAYTHROUGH_TASK_OWNER.md)
  retains all baseline failures, frozen inputs, commands and artifacts; SHA256:
  `0305149edce6527dbaa4f2f97b9229d82418aba8cae7c10cc2818b3afbc8daa6`.
  Enough-data autoplay substeps, buffering-drop waiting, complete
  resource/readiness/seek, native play promises, physical decoding and automatic
  ownership remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Autoplay sandbox eligibility (`6099af96`) now checks the automatic-features
  flag on the actual media owner's live Document. Both audio/video automatic
  preload-none selections remain deferred; explicit load fetches without
  automatically playing. Adoption and flag changes use current ownership.
  Four new model/native cases fail in a compiled baseline and pass afterward.
  The first default-GC run stops after three observed passes without a final
  manifest. A complete recovery and the GC-disabled run each pass **11/11
  selected files**, including the **66-case** main regression. The corrected
  ordinary production probe, signed startup,
  both exact prior load viewports and all **11 smoke cases** pass. The initial
  standalone probe's compiler error is retained separately before any build.
  [Evidence](MEDIA_AUTOPLAY_SANDBOX_OWNER.md) preserves every run; SHA256:
  `63a3600780fae90ae45098431582088a4e7cf0d249b7bacae1f278b940c88208`.
  Full Permissions Policy, playback-policy integration, enough-data autoplay,
  complete resource/readiness/seek, native play promises, physical decoding and
  automatic ownership remain open. The ledger stays **32 fixed / 25 partial / 9 open**.

- Resource autoplay playback permission (`066d31b8`) now follows the actual
  owner's live Document origin, sticky Window activation and effective volume.
  Consumed transient activation remains sticky; adoption discards the old
  Window/origin permission. Blocked preload-none selection stays deferred;
  explicit load fetches without autoplaying. Four new model/native cases fail
  in a compiled runtime baseline and pass afterward; the focused batch passes
  **3/3 files**. Both final frozen selected runs pass **14/14 files**, including
  the **66-case** main regression. The ordinary production probe, signed startup
  and both exact prior load viewports pass. The initial smoke capture stops
  after inline-node; a complete same-binary recovery passes **11/11 smoke cases**.
  [Evidence](MEDIA_PLAYBACK_POLICY_OWNER.md) retains every run; SHA256:
  `8080d5159a9ab2e67eaa4d46d3e41014ec22d6c147dff6550e4e8c03434aa87f`.
  Public play permission rejection, volume-change policy pause, full Permissions
  Policy, enough-data autoplay timing, complete resource/readiness/seek, native
  play promises, physical decoding and automatic ownership remain open. The
  ledger stays **32 fixed / 25 partial / 9 open**.

- Public V model play permission (`6520f81a`) now rejects with typed
  NotAllowedError before unsupported media, pending-promise insertion or
  internal play. Denial preserves earlier requests and performs no fetch or
  play-task scheduling. The corrected new tests compile against the parent and
  fail at runtime; all **five model/native cases** pass afterward. Thirty-five
  existing cases explicitly allow playback while preserving their assertions;
  the missed removal prerequisite is added in `d624b8d3`. Both complete frozen
  recovery runs pass **25/25 files**, including the **66-case** main regression.
  Earlier fixture/compiler failures and partial runs are retained separately.
  The signed production bundle, corrected ordinary probe, startup, both exact
  prior load viewports and all **11 smoke cases** pass with unchanged
  implementation bytes. [Evidence](MEDIA_PLAY_PERMISSION_OWNER.md), SHA256:
  `dc6997bc35a5b114304b5f0c8fa3f285505f1b58c919bbaf67d8c3a936bc2f46`.
  Native JavaScript play promises, volume-change policy pause, the existing
  unsupported-source string adapter, full Permissions Policy, enough-data
  autoplay timing, full resource/readiness/seek, physical decoding and automatic
  ownership remain open. The ledger stays **32 fixed / 25 partial / 9 open**.
- Volume/muted playback policy (`46701a87`) now checks the live owner after
  queuing volumechange, then enters internal pause before effective-volume
  update when permission is denied. Already-paused blocked owners disable
  autoplay without fetching; Page-wide mute remains update-only. Four model
  assertions and the corrected native paused-getter assertion fail against
  unchanged parent code. All six corrected cases pass. A test-only follow-up
  (`1221f3da`) grants the allowed-policy prerequisite for the older audibility
  fixture and keeps its assertions intact. The initial batch passes 20/21.
  Both complete frozen selected runs pass **21/21 files**, including the
  **66-case** main regression. Two existing native volume-property files also
  pass in both GC modes on the same snapshot. The
  signed production build/probe, startup, both exact prior load viewports and
  all **11 smoke cases** pass. Initial fixture/compiler failures and an
  interrupted focused run are retained separately.
  [Evidence](MEDIA_VOLUME_POLICY_OWNER.md), SHA256:
  `8b80b01f7c52dbb98984adc54736e27aa281f63431fdd34afd76ba76299e1c39`.
  Native JavaScript play promises, typed unsupported-source rejection, full
  Permissions Policy, enough-data autoplay timing, complete resource/readiness/
  seek, physical decoding/manager and automatic ownership remain open. The
  historical ledger stays **32 fixed / 25 partial / 9 open**.
- Unsupported V play rejection (`aa9a5e27`) now uses a fresh typed NotSupportedError
  with the current MediaError message after permission succeeds. It preserves
  older requests and owner state without fetching or entering internal play.
  Two model and one native typed-value assertions fail on unchanged parent;
  all four new cases and existing permission precedence pass afterward.
  The focused batch passes **3/3 files**; both frozen selected runs pass
  **15/15 files**, including the **66-case** main regression. The ordinary
  production probe, signed startup, both exact prior load viewports and all
  **11 smoke cases** pass. [Evidence](MEDIA_PLAY_SOURCE_ERROR_OWNER.md), SHA256:
  `2380b97f5370aaec4238c8cb356fa3e0174c0937247a96a6f342017ca309ba4f`.
  Native JavaScript play promises, remaining source-failure/ended adapters,
  raw UTF16 MediaError slots, full resource/readiness/seek, physical decoding
  and automatic ownership remain open. The ledger stays
  **32 fixed / 25 partial / 9 open**.

- Native media play promise ownership (`58fde80e`, 2026-10-11) now connects
  parsed/created DOM media to real JavaScriptCore Promises backed by the same
  model WebIDL capability. The generic fulfilled stub is removed. Brand checks
  precede replay, binding errors preserve their original reason, and waiting,
  playing, pause, load and ended paths retain captured-batch ordering. Selection,
  MediaSource and ended string sinks now use typed DOMExceptions under the
  current Document execution context. The final parent baseline compiles all
  three new files and fails all three at runtime; its model panic prevents the
  final two model cases from running on the parent. All **17 new cases** pass
  within both unchanged **24/24-file** selected runs, including the **66-case**
  main regression. Signed production build/startup, the ordinary native probe,
  **two exact play viewports**, **14 exact SVG pairs** and all **11 configured
  smoke cases** pass (eight smoke cases exact). All 104 production artifact
  hashes verify; all 81 earlier source-error artifacts are unchanged. Initial
  compiler/integration diagnostics and the interrupted production attempt remain
  separate. [Evidence](NATIVE_MEDIA_PLAY_PROMISE_OWNER.md), consolidated SHA256:
  `4b58d16d0aed341fb1d416bd029fa481254b8010c3c822b23d02d73bb339ce1b`.
  Load's pinned canceled-task/captured-batch FIXME remains pending. Full
  resource/readiness/seek/MSE, enough-data autoplay, Permissions Policy, ordinary
  compact listener routing, physical decoding, foreign engine realms, raw UTF16
  MediaError storage and automatic ownership remain open. Earlier entries retain
  their contemporaneous verification scope; the historical ledger stays
  **32 fixed / 25 partial / 9 open**.

- Ordinary compact media listener ownership (`4ef8e6e5`, 2026-10-13) removes the
  generic own addEventListener only after successful HTML audio/video binding.
  Ordinary add/remove/dispatch now share actual DOM EventTarget records, with
  trusted queued playback/readiness delivery, identity, capture, once and object
  callbacks. Late registration on a seeded current-data frame creates no fake
  loadeddata/seeked callback. Actual Page pointer release delivers one trusted
  media click before compact replay and preserves native cancellation; generic
  image/object/SVG compact behavior remains covered. Both new files compile on
  unchanged parent `7cc68c1e`, and all **six new cases** fail at runtime without
  compiler errors or panics. The same test bytes pass afterward. Both unchanged
  committed selected runs pass **19/19 files**, including the **66-case** main
  regression. The signed production build/startup, active ordinary probe,
  **two exact listener viewports**, **14 exact SVG pairs** and all **11 smoke
  cases** pass (eight smoke cases exact). All 99 production artifacts verify;
  all 236 previous evidence artifacts remain unchanged. The initial probe API
  precheck failure and formatter-version disagreement remain separate diagnostics.
  [Evidence](NATIVE_MEDIA_EVENT_LISTENER_OWNER.md), consolidated SHA256:
  `75028b97d12dfa3d4937d145ec36368222bbc10abc77f56388e69da31fc4e0b9`.
  Package inventory counts are unchanged because this slice is root browser
  support. The pinned load captured-task FIXME, general nonmedia EventTarget,
  handler attributes, full media interfaces, Cocoa/input hit testing, physical
  playback and other recorded boundaries remain open. Earlier entries retain
  their contemporaneous scope; the ledger stays **32 fixed / 25 partial / 9 open**.

- Native media handler attributes (`60ef4bb2`, 2026-10-13) install the selected
  23 native on* accessors on the partial media prototype, backed by the actual
  DOM audio/video owner. Shared legacy conversion accepts noncallable objects
  by identity and silently skips invocation before callback contexts or
  handleEvent reads; primitives clear the handler. Replacement preserves
  listener order, and trusted play/pause/readiness events retain their Promise
  settlement order. All ten cases compile and fail on the unchanged corrected
  baseline, then pass with identical tests within 24/24 files in both GC modes.
  Initial fixture diagnostics remain retained. Signed startup, the active
  production probe, two exact viewports, 14 exact SVG pairs and all 11 smoke
  cases pass. Raw inline element compilation, onclick/general HTMLElement
  handlers, full prototype placement, foreign realms, weak ownership, the
  pinned load captured-task FIXME and complete/physical media remain open.
  Ledger stays 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MEDIA_EVENT_HANDLER_OWNER.md), consolidated SHA256:
  `4903a7137ef0c2364ebbd35e82e588097f3de62aa575e7746337d4548a0f030e`.

- Native media press/release handlers (`9ee0685b`, 2026-10-13) add four native
  onpointerdown/onpointerup/onmousedown/onmouseup accessors backed by actual
  HTML audio/video owners. Existing descriptor, legacy conversion and handler
  slot algorithms are reused. Actual Page tests preserve trusted press/release
  order, pointerdown compatibility suppression, mouseup/click independence and
  compact replay without duplicate delivery. The final parent baseline compiles
  both files and fails all five functions; identical final bytes pass afterward
  within 18/18 selected files in both GC modes, including the 66-case main
  regression. Two native fixture faults and initial/intermediate runs remain
  diagnostic provenance. Signed build/startup, the active ordinary probe, two
  exact pages, 14 exact SVG pairs and all 11 smoke cases pass (eight exact).
  All 102 current and 592 previous artifact hashes verify.
  Explicit-target Page fixtures do not establish Cocoa transport, hit testing,
  full input interfaces or raw inline/onclick parity. Other handlers, full
  prototypes, realms, weak ownership, the pinned load FIXME and full/physical
  media remain open. Earlier evidence retains its original scope. The ledger
  stays 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MEDIA_POINTER_HANDLER_OWNER.md), consolidated SHA256:
  `731e05084351bfaf02fb971d45af92d992890d2b989420bcbb7dfbbcb267e2d7`.

- Native media onclick (`8c567b08`, 2026-10-13) reaches actual audio/video
  handler slots with existing descriptor, legacy conversion, listener ordering
  and cancellation rules. Private Event/Page replay receipts preserve outer
  clicks through nested dispatch and prevent stale raw replay after callback
  mutation. Current raw DOM text is passed by stable bridge key; the retained
  Function/plain-Event fallback remains approximate. The native/main parent
  baseline compiles two files and fails six functions; Page's two new-API tests
  are unexecuted on that baseline. All eight focused cases pass with identical
  bytes, then 22/22 selected files pass in both GC modes. Signed startup,
  the active optimized probe, two exact pages, 14 exact SVG pairs and all 11
  smoke cases pass (eight exact). All 104 current and 851 previous artifact
  hashes verify. Real inline compilation, full prototypes, other handlers,
  Cocoa/hit testing, full input interfaces, realms, weak ownership, full/physical
  media and the pinned load FIXME remain open. Historical evidence retains its
  original scope; ledger stays 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MEDIA_CLICK_HANDLER_OWNER.md), consolidated SHA256:
  `b6cfaa3945616335650fee936b7c09ae1fb09ae7677e1d41bf54702ea8de5bf8`.

- Native media auxiliary/double-click handlers (`5ba4d87c`, 2026-10-13) add
  two native attributes through the existing owner/handler algorithms.
  Trusted Page tests preserve primary/double cancellation independence,
  middle/right auxclick false versus zero, self-mutation, thrown reason identity
  and the earlier outer primary receipt. Both parent files compile and fail
  five initial descriptor guards; identical final bytes pass focused retry and
  ordinary optimized tests, then 25/25 files in both GC modes. Initial focused
  disk exhaustion executed no tests and has no persisted full snapshot proof;
  its log/diagnostic remains separate. Signed startup, two exact synthetic-Event
  pages and all 11 smoke cases pass (eight exact). All 51 current and 964 prior
  artifact hashes verify.
  Main/Page/dispatcher/bootstrap and all 2,210 assigned package bytes/counts
  remain unchanged. Explicit targets/counts do not establish physical input,
  full interfaces/prototypes or raw inline compilation; realms, weak ownership,
  full media/physical playback and the load FIXME remain open. Ledger remains
  32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MEDIA_AUXILIARY_HANDLER_OWNER.md), consolidated SHA256:
  `55b95fa856b311d5bad0e32d8b14089bf3289afa54ecf79e89ea1af01c50b63d`.

- Native media movement handlers (`e5ae9afb`, 2026-10-13) add two native
  attributes through existing owner/handler algorithms. Trusted Page cases
  prove pointermove/mousemove cancellation independence, compatibility
  suppression through release, parsed/created identity, self-mutation,
  thrown-object reporting, DOM polling and no duplicate compact click. Both
  parent files compile and fail five initial descriptor guards; identical
  final bytes pass focused and ordinary optimized tests, then 27/27 files in
  both GC modes. Preparation-only ENOSPC interrupted writes before tests;
  no partial main fixture remained. VJOBS=1 and a dedicated RAM volume hold
  compiler scratch while persistent source/logs/snapshots stay in this repo.
  The guarded cleanup detaches only that owned RAM image after validation;
  persistent source and evidence remain intact.
  Signed startup, two exact synthetic-Event pages and all 11 smoke cases pass
  (eight exact). All 51 current and 1,038 prior artifact hashes verify.
  Main/Page/dispatcher/bootstrap and all 2,210 assigned package bytes/counts
  remain unchanged. Base Event/explicit-target coverage leaves full input
  fields/default actions, Cocoa/hit testing, prototypes, raw compilation,
  realms, weak ownership, full/physical media and the load FIXME open. Ledger
  remains 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MEDIA_MOVEMENT_HANDLER_OWNER.md), consolidated SHA256:
  `a128c77fe22cb36ba39c5a1f06112a32802fd015c8d052f4ec1896f8a3e2c122`.

- Native inherited UIEvent binding (`d1b86d81`, 2026-10-13) exposes the actual
  owner-local constructor/view/detail/which/initializer with native getter and
  method metadata. All ten UI families retain actual records; late attachment
  preserves original parent/global identity. Both parent files compile and
  six initial availability guards fail; final bytes pass focused and ordinary
  optimized cases plus 12/12 files in both GC modes. Signed startup, two exact
  synthetic UIEvent pages and all 11 smoke cases pass (eight exact), preserving
  51 current and 1,117 prior artifact hashes.
  Checker/syntax and ENOSPC compiler diagnostics remain separate; the owned
  RAM scratch is detached after validation with persistent evidence retained.
  Main/Page dispatch and assigned-package counts remain unchanged. This proves
  native-record exposure, leaving foreign-view support, concrete subclass,
  move-field construction, physical input/default actions, raw inline element
  compilation, realms, weak ownership and full media/load limitations explicit. Ledger
  remains 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_UI_EVENT_OWNER.md), consolidated SHA256:
  `edc1a8b4e7c47dd09e1fa1580566b69098585e40f67df3eef2660848eebdb228`.

- Canonical mouse-family related targets (`dd0cc2d5`, 2026-10-13) remove
  the duplicate MouseEvent slot and use the dispatch-owned base Event state.
  Constructors, typed getters, legacy initialization, clones and trusted hover
  agree on per-listener shadow retargeting, suppression and clear-target cleanup;
  DragEvent inherits the corrected path. Both final parent files compile and
  all six cases fail actual assertions; identical bytes pass focused and
  ordinary optimized runs plus 12/12 files in both GC modes. Signed startup
  and all 11 configured smoke cases pass (eight exact), preserving
  38 current and 1,225 prior artifact hashes.
  Earlier checker and reused-export fixture diagnostics remain separate.
  Guarded cleanup detaches only the owned RAM disk6; persistent evidence stays.
  The 78-owner recount assigns 2,211 files and changes only DOM/UIEvents:
  432,871 implementation / 159,242 test V LOC. Main, dispatcher and native
  browser binding implementation remain unchanged. The private owner observer
  establishes native-state fidelity; public JavaScript MouseEvent interfaces,
  concrete prototypes, full input construction, physical input/default actions,
  realms, weak ownership and broader media/load work remain open. Ledger stays
  32 fixed / 25 partial / 9 open.
  [Evidence](MOUSE_EVENT_RELATED_TARGET.md), consolidated SHA256:
  `7ba7b929b6c7b0ef1ab33ad1f828db8b5ee23f250cbde7ad35d175d7b4605e1d`.

- Owner-local Window MouseEvent (`db342c95`, 2026-10-13) exposes the public
  constructor, nineteen native getters and getModifierState/initMouseEvent.
  Source dictionary/legacy conversion, a single newTarget prototype read,
  concrete PointerEvent coordinate overrides and public canonical relatedTarget use
  actual native records and the retained UIEvent/Event chain. The two parent
  files compile and six initial availability/prototype guards fail; later
  parent assertions are unexecuted. Six final focused and ordinary optimized
  cases pass at the implementation bytes, and signed production passes ten
  stages, two exact synthetic untrusted pages and all 11 smoke cases (eight
  exact), preserving 51 current / 1,331 prior hashes.
  Final 14/14 batches in both GC modes run at the separately committed fixture
  correction a03691e5. It changes only one existing Runtime pointer capture;
  implementation and six new test bytes remain identical. Original default
  13/14 failure, GC-none pass and seven ignored diagnostic runs are preserved.
  Labels prove the wrong pointer/context, without a host-GC/nil-context claim.
  Guarded cleanup detaches owned RAM disk7 with persistent evidence retained.
  All 78 owners / 2,211 assigned hashes/newlines and 432,871 implementation /
  159,242 test V LOC remain unchanged; root/browser support stays excluded.
  Concrete Pointer/Wheel/Drag interfaces, foreign views/realms, weak ownership,
  full Page/physical input and broader media/load work remain open. Historical
  ledger remains 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_MOUSE_EVENT_OWNER.md), consolidated SHA256:
  `7500513853bce4ff63746bf055c3123cf2c3eb00c56755ab23907d34d0409c88`.

- Owner-local Window PointerEvent (`c9dc0da2`, 2026-10-13) exposes the public
  constructor, thirteen native getters and predicted sequences; coalesced
  sequences are exposed only by secure owning settings. Its retained native
  prototype inherits MouseEvent/UIEvent/Event, preserving native child identity,
  fresh output Arrays, exact forty-three-member conversion order, restricted
  floats/doubles and independent angle/tilt defaults. Abrupt sequence conversion
  preserves the pinned generator's missing IteratorClose path. Five native and
  two actual Page-owner cases use identical bytes across ancestral focused and
  integrated optimized proof. Both parent files compile and seven initial
  availability guards fail at feb97f38; later assertions are unexecuted there.
  All 17 selected files pass in both GC modes. The feature commit changes
  only nine root/browser paths and preserves preceding CSS commit 7c3576ec;
  its 106-line CSS regression is included in both 17-file batches. Final private
  production passes ten stages at c9dc0da2, with two pixel-exact untrusted
  Pointer pages and all 11 smoke cases (eight exact), retaining
  66 current / 1,859 prior artifacts, including its
  private signed image and Skia dylib. Earlier Rust-PATH and post-run shared
  image overwrite observations are preserved as separate diagnostics.
  Historical diagnostic symlinks were materialized as the same
  bytes before this slice, preserving all 412 old sealed entries. Cleanup and
  independent final proof: owned RAM disk5 detached; the proof repeated after
  cleanup matches the canonical report byte for byte. The verified inventory
  isolates preceding CSS deltas and leaves root/browser support excluded;
  aggregate reference changes belong to a separate commit. Later canonical
  Layout work is preserved outside the pinned validation source. Element
  pointer capture, hardware/coalescing/prediction generation, Wheel/Drag public
  interfaces, foreign realms/views, weak ownership and full Page/physical input
  remain open. Historical ledger remains 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_POINTER_EVENT_OWNER.md), consolidated SHA256:
  `4a8392c1a326542d3d395ad6da9dfc8b3d87935a0d74776dd754d33d32a191a4`.

- Owner-local Window WheelEvent (`813dd838`, 2026-10-13).
  Window-owned runtimes now expose WheelEvent's constructor, seven native
  getters and three delta-mode constants over actual records, inheriting
  MouseEvent/UIEvent/Event. Thirty-four dictionary members convert in
  inherited lexical order; restricted doubles, wrapped integers and native
  round-to-even legacy fallback preserve the pinned source. Initial/late
  owner exposure, wrapper identity, relatedTarget and inherited initializers
  remain live. Five native and two owner cases pass focused and optimized;
  all 20 selected files pass in both GC modes at 813dd838. Final production
  exits nine steps, with eight fresh checks and ten logical checks including
  the explicitly verified retained -prod -gc none build: strict signing/startup,
  two exact pages and 11 smoke cases (eight exact). The failed media
  onwheel probe preserves 43 artifacts. That failed page receives no pass
  credit; final native listener pages use the same frozen private signed image.
  The closure retains 102 current / 1,960 prior hashes. Factory/DOM
  owner dispatch establishes synthetic native bindings; physical Cocoa/Page
  wheel delivery/default scrolling and compact media onwheel remain open,
  alongside DragEvent, foreign realms and weak ownership. Later concurrent
  canonical work remains outside the isolated source pin.
  Both new files compile on parent 368ef4c7 and seven initial exposure
  guards fail; later parent assertions are unexecuted. Exact new-test
  bytes remain identical through final focused/optimized validation.
  Independent proof verifies every committed isolated input; owned RAM
  cleanup retains persistent image/source/evidence. The inventory
  attributes all assigned deltas to preceding Layout/CSS commits;
  table/reference updates belong to a separate commit. Historical ledger
  remains 32 fixed / 25 partial / 9 open.
  [Evidence](NATIVE_WHEEL_EVENT_OWNER.md), consolidated SHA256:
  `62acadfa4802e481055569c6beb3cb11c001c4543453c909740d60378ff990a4`.

- Owner-local Window DragEvent (`682a7827`, 2026-10-13).
  Window-owned runtimes now expose DragEvent's constructor and sole native
  dataTransfer getter over actual HTML records, inheriting
  MouseEvent/UIEvent/Event. Twenty-nine dictionary members convert in inherited
  lexical order. Null defaults and genuine owner-local DataTransfer brands
  preserve native identity without inspecting author properties or Proxies. The
  separately committed bounded identity prerequisite is 6296e27c; it adds no
  public DataTransfer constructor or operations. The HTML constructor now
  creates an untrusted record; internal create behavior, dispatch and inherited
  initializer preservation remain intact.

  9 focused and optimized DragEvent cases pass; 3 identity cases pass in both GC
  modes. All 21 selected files pass in both GC modes at 682a7827. Private
  production completes 10 stages: signed startup, two pixel-exact null-transfer
  pages and all 11 screenshot smoke cases. Genuine nonnull transfer identity is
  established by the focused native/actual-owner tests. Interrupted initial test
  and production attempts remain preserved without pass credit; detached
  supervisors record the completed terminal exits. A separately archived
  verification-only dispatcher-path correction changes no implementation or test
  result. The verified closure retains 70 current / 2,087 prior artifacts.

  This completes the pinned owner-local DragEvent interface. Public DataTransfer
  operations, DataTransferItem/List/file exposure, media ondrag handlers,
  physical Page/Cocoa drag generation, store-mode transitions and default
  actions remain open, alongside foreign views/realms and weak ownership.
  JavaScriptCore remains the browser engine. The frozen production source uses
  its historical Ladybird bundle name; current Vox branding and later concurrent
  work are outside that validation pin.

  [DragEvent evidence](NATIVE_DRAG_EVENT_OWNER.md).
  Separate identity prerequisite: `6296e27c`.
  Baseline: three files compile; seven availability guards and one constructor
  trust assertion fail; the preservation case passes. Later failing-case
  assertions are unexecuted on the parent. Inventory updates belong to a
  separate commit. Historical ledger remains 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `4d25a5a50607546dc653b9c4faabd55a5b87b444524f9e6d58f9b158cad6d2c8`.

- Native Window DataTransfer string store (`b335958e`, 2026-10-13).
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
  evidence](NATIVE_DATA_TRANSFER_STRING_OWNER.md).
  Parent baseline compiles two files; seven initial availability guards fail.
  Original JS option comparisons failed compilation and earn no pass credit;
  only those two fixture comparisons were corrected. Core UTF-16/revision
  API cases are first exercised after implementation. Inventory changes
  belong to a separate commit. Ledger remains 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `1f0e60d7a96ed1734a5d2d5c8b2765e9b914bf6d364b73a583d46104b128ef22`.

- Native Window DataTransfer.files (`b59e211c`, 2026-10-13).
  Window-owned DataTransfer now exposes its native read-only files getter over
  existing FileAPI owners. The pinned implementation and generator return fresh
  FileList/File snapshots despite the IDL SameObject annotation; old snapshots
  retain their bytes after store/mode changes. Native receiver branding precedes
  FileAPI dependency lookup. At `b59e211c`, seven new and twelve focused cases
  pass, fourteen selected files pass in both GC modes, and seven optimized cases
  pass. Signed startup, two pixel-exact genuine empty-list pages and eleven
  smoke cases pass. Nonempty files use focused native owner tests. Public items,
  drag images, hardware file delivery and weak/foreign ownership remain open.
  See [DataTransfer files evidence](NATIVE_DATA_TRANSFER_FILES_OWNER.md).
  Follows pinned fresh snapshot implementation despite IDL SameObject.
  Initial JS compile failure earns no pass credit; exactly three fixture
  expressions change before the corrected seven-guard parent baseline.
  Core HTML/FileAPI algorithms and physical inventory remain unchanged.
  Historical ledger remains 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `63a99a822705b4b2eda68dbac9c2e6518e1c18255c6adb036272051e8b3ca492`.

- Native Window DataTransfer items (`e775be45`, 2026-10-13).
  Stable native live list/item identities, indexed reflection, removal/clearing,
  raw UTF-16 metadata and fresh File conversion are implemented over actual owners.
  Nine new / fourteen focused cases, seventeen selected files in both GC modes,
  nine optimized cases, signed startup, two exact text-item pages and eleven
  screenshot smoke cases pass. Source clear remains text-only; file payload/mode
  coverage belongs to native V owner fixtures. The parent baseline fails only
  two initial MAIN guards. Initial File value-comparison and Node-model failures
  remain preserved with no successful batch/native-model credit.
  See [DataTransfer items evidence](NATIVE_DATA_TRANSFER_ITEMS_OWNER.md).
  Assigned HTML feature delta is +10 implementation / +74 test lines and one
  test file; the independent physical recount is pinned separately to the code.
  Historical ledger remains 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `96744137979d0e5726bc5816628aac05a14790a39a667b2e0d8cfe93f8b6cfbe`.

- Native Window DataTransferItemList.add (`bbe330a8`, 2026-10-13).
  Generated count selection, native File branding, raw DOMString addition,
  fresh typed duplicate failures and live indexed item identity are implemented.
  9 new / 16 focused cases, 15 selected files /
  52 cases in each GC mode, 9 optimized cases, signed startup,
  two exact genuine mixed-item pages and eleven screenshot smoke cases pass.
  The parent compiles two fixture files and fails seven initial availability
  guards; later assertions earn no baseline credit. Initial browser literal
  compilation and focused fixture failures remain preserved with no batch pass
  credit. Only test fixtures change after the initial implementation freeze.
  Public File names undergo USVString conversion; raw text/type and typed native
  File names retain code units. File byte promises execute owning-document tasks
  in native V fixtures; the production pages verify File metadata.
  See [DataTransfer item-add evidence](NATIVE_DATA_TRANSFER_ITEM_ADD_OWNER.md).
  Assigned HTML delta is +15 implementation / +55 test lines and one test file;
  six browser/root feature paths remain excluded from the package inventory.
  Physical recount: 78 owners / 2,224 files, 433,231
  implementation / 160,272 test V LOC, pinned separately to the code.
  Historical ledger remains 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `dab3d2b8c3e5dc1e7a21f047c86d530a39ba48195398c45b1bb6d211ed7afad3`.

- Native Window DataTransferItem.getAsString (`e3ff95fd`, 2026-10-13).
  Receiver branding, required nullable callable conversion, raw UTF-16 snapshots,
  asynchronous unspecified/documentless tasks and captured callback ownership
  are implemented. Original throws/results are discarded without then access
  or reporting. Repeated abrupt completions release their roots; pending close
  is safe. 8 new / 15 focused cases, 15 selected files /
  47 cases in each GC mode and 8 optimized cases pass.
  Signed startup, two exact actual asynchronous pages and eleven smoke cases
  pass (8 exact, 3 retaining established tolerance residuals).
  Parent baseline: 2 files compile and 6 availability guards fail;
  later assertions earn no baseline credit. Original compilation failures
  (`baseline-v1`, `baseline-v2`) remain preserved with no passing batch credit.
  Original focused-v4 passes 5 files and fails 1 owner file, with no passing
  batch credit: its realm.can_run flag does not disable real Page-owned settings.
  The corrected owner fixture uses Page.set_is_scripting_enabled(false), restores
  that preference and leaves all implementation hashes unchanged.
  The public JSC diagnostic for non-callable objects uses [object Object]
  rather than upstream native-class names. Foreign realms, weak ownership,
  entries, drag images, physical/default drag actions and media ondrag remain open.
  See [DataTransfer string-callback evidence](NATIVE_DATA_TRANSFER_ITEM_STRING_CALLBACK_OWNER.md).
  Assigned HTML delta: +11 implementation / +41 test lines and one added file;
  7 browser/root feature paths remain excluded. Physical recount records
  78 owners / 2,225 files, 433,242 implementation /
  160,313 test V LOC. Historical ledger stays 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `e4f63178cdce85059971b77f5cd8b591dcf18356b72f93f05ddeb35910fdcd81`.

- Native Window DataTransferItem.webkitGetAsEntry / FileSystemEntry (`fdc13cca`, 2026-10-13).
  Native receiver branding, ignored extra arguments, readable file-kind gating,
  fresh entry snapshots and owner-local readonly metadata are implemented.
  Raw names retain lone surrogates/NUL units through the pinned source round trip;
  existing public File construction still converts its input filename separately.
  Typed file/directory entries keep stable wrappers per actual record; successive
  DataTransfer reads create distinct file records. Spoof/proxy/foreign wrappers
  reject without author property access, and close clears native maps and JS roots.
  12 new / 21 focused cases, 15 selected files /
  49 cases in each GC mode and 12 optimized cases pass.
  Signed startup, two exact actual entry pages and eleven smoke cases pass
  (8 exact, 3 retaining established tolerance residuals).
  Parent baseline: 2 files compile and 6 availability guards fail;
  later assertions earn no baseline credit. Retained failed test batches: `focused-v1`; no failed batch or later assertion earns passing credit.
  Final implementation hashes match the earliest captured implementation freeze. Changed owned paths across the initial/final freezes: `browserjs/file_system_entry_binding_test.v`.
  Upstream FIXME fullPath/filesystem/getParent stay absent from public JS;
  generic entry callbacks, directory/path traversal, physical/default drag delivery,
  media ondrag, foreign WindowProxy/function-realm handling and weak ownership remain open.
  See [DataTransfer entry evidence](NATIVE_DATA_TRANSFER_ITEM_ENTRY_OWNER.md).
  Assigned feature delta: EntriesAPI +21 implementation /
  +27 test lines and one new test file; HTML
  +0 implementation / +53 test lines and one new test file.
  The 9 root/browser feature paths remain excluded. Physical recount records
  78 owners / 2,227 files, 433,263 implementation /
  160,393 test V LOC. Historical ledger stays 32 fixed / 25 partial / 9 open.
  Consolidated evidence SHA256: `d2fb80d3298f1714ab42ecdee1feccaee2ab06bf8979c28cef7a0a35cb8cb99f`.

- Native media drag/drop event-handler attributes (`a503c977`, 2026-10-14).
  The seven ondrag/ondragend/ondragenter/ondragleave/ondragover/ondragstart/ondrop
  attributes extend the existing native owner registry and generic callback route.
  Exact receiver branding precedes replay; LegacyTreatNonObjectAsNull preserves
  object identity and maps primitive assignments to null without conversion.
  Replacement retains listener order, null removes the listener, and reactivation
  appends it. Noncallable objects do not trigger handleEvent reads; callable proxy
  handlers use their actual call behavior. Only actual boolean false cancels.
  Relevant/incumbent callback contexts, currentTarget and actual payload identity,
  live Page scripting gates, raw uncompiled content attributes and post-close
  dispatch are covered without a physical drag/default-action claim.
  6 new / 20 focused cases, 15 selected files /
  52 cases in each GC mode and 6 optimized cases pass.
  Signed startup, two exact public handler pages and eleven smoke cases pass
  (8 exact, 3 retaining established tolerance residuals).
  Parent baseline: 2 files compile and 6 availability guards fail;
  later assertions earn no baseline credit. Retained failed test batches: `focused-v1`; no failed batch or later assertion earns passing credit.
  The original completed production attempt fails at drag-handlers-defaults-pixel; its partial stage and child exit receipts remain preserved without full-run or later-stage pass credit. A separate immutable retry completes all ten stages.
  Final implementation hashes match the earliest captured implementation freeze. Changed owned paths across the initial/final freezes: `browserjs/media_element_drag_handler_host_test.v`.
  Public page dispatch is untrusted; V owner fixtures include trusted embedding DOM
  dispatch. Upstream FIXME setDragImage remains absent with no invented stub.
  Physical Cocoa/Page producers, automatic store transitions/default actions, weak
  and foreign ownership, and the complete HTMLElement handler hierarchy remain open.
  See [media drag-handler evidence](NATIVE_MEDIA_DRAG_HANDLERS_OWNER.md).
  All three feature paths are excluded root/browser support: +1 registry
  implementation line and 595 new test lines confer no assigned LOC delta.
  Independent physical recount preserves 78 owners / 2,227 files,
  433,263 implementation / 160,393 test V LOC and
  every assigned hash/newline count at the prior entry pin. Historical ledger stays
  32 fixed / 25 partial / 9 open. Existing native play() promises stay complete.
  Verification and the physical inventory remain pinned to `a503c977`. 3 later independently authored commits are preserved at documentation base `a79d432b`; their CSS/Layout sources and counts are outside this slice's verified source and inventory counter. A later inventory refresh must account for those separate changes under its own pin.
  Consolidated evidence SHA256: `9af390887fee838c6b470e7194e122cfc9aeedcab5ab17f6bc9b2f7cfbe5a2f7`.

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
