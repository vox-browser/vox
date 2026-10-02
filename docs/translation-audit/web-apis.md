# Large LibWeb Web API translation audit

Audit date: 2026-10-02. Upstream checkout: `/Users/alex/code/3rd/ladybird`, commit `963d46a829f3e1b79f44dba9d02afb70654300fa`. Translation checkout: `/Users/alex/code/vox2`.

This part of the audit covers every production `Libraries/LibWeb/**/*.cpp` with at least 1,000 physical lines outside DOM, HTML, CSS, Layout, Painting, Animations, and ViewTransition. Those directories are covered by the other audit parts. The exact scope is **17 C++ files**. Line counts include comments and blank lines; source references below are to this upstream snapshot and the V files as inspected on the audit date.

The result does **not** meet a requirement of no stubs or untranslated logic. The findings include unavailable cryptographic operations, absent WebAssembly validation/execution, synthetic WebGL answers, and missing runtime integration. Several modules contain substantial real translations alongside those gaps. A matching public name, translated comment, test result, or source inventory is not evidence that every branch matches upstream.

`U:` means a path relative to `/Users/alex/code/3rd/ladybird/Libraries/LibWeb`; `V:` means a path relative to this repository. References include physical line numbers. “Focused” means upstream algorithm bodies and corresponding V bodies were compared for the listed operations, with helper/caller searches; it does not mean every branch of the entire translation unit was verified. No implementation files were changed during this audit.

## Per-file coverage

| Upstream source | C++ lines | Actual V implementation and supporting paths | Compared algorithms and depth | Result |
|---|---:|---|---|---|
| `ContentSecurityPolicy/Directives/DirectiveOperations.cpp` | 1,138 | `contentsecuritypolicy/directive_operations.v`, `source_expression.v`, `directive.v`; `sri/sri.v` | Entire primary V file read; focused C++/V comparison of scheme/host/port/path matching, URL/source-list matching, inline nonce/hash matching, and integrity hashing helpers. JavaScript string conversion at the bindings boundary was not verified. | No demonstrated difference in the ordinary valid-input samples. This is not complete CSP parity certification. The Fetch integration omission is WA-03. |
| `Crypto/CryptoAlgorithms.cpp` | 10,553 | `webcrypto/crypto_algorithms.v`, `upstream_algorithm_classes.v`, `crypto_protocol.v`, `crypto_key_serialization.v`, plus AES/hash/Ed25519 implementations in `webcrypto/` | All class-operation placeholders in `upstream_algorithm_classes.v` read; focused comparison of RSA-OAEP, ECDSA/ECDH, Ed448, ML-DSA, cSHAKE, KMAC, and AES-OCB operation bodies against dispatch and backend helpers. Available AES/hash/Ed25519 implementations were sampled, not cryptographically certified. | WA-01: implemented upstream families have unavailable V operations. |
| `Crypto/SubtleCrypto.cpp` | 1,781 | `webcrypto/subtle_crypto.v`, `crypto_protocol.v`, `crypto_algorithms.v` | Focused normalization/registration, algorithm/key validation, encrypt/decrypt, sign/verify, generation, and key-format dispatch; compared Promise/deferred-task behavior. Searched production callers and alternate runtime bindings. | WA-01, WA-02. Typed synchronous operations do not implement the browser Promise API. |
| `Editing/Commands.cpp` | 2,942 | `editing/commands.v`, `exec_command.v`, `replace_selection.v`, `editing_history.v` | Command mapping inventoried; focused command bodies for `insertHTML` and `selectAll`, their selection/deletion helpers, and editing undo/redo entry points. Other command bodies were sampled, not exhaustively compared. | No high-confidence defect established in these samples. Upstream already contains the sampled `INTEROP` changes; those comments do not establish V-only logic. |
| `Editing/Internal/Algorithms.cpp` | 4,990 | `editing/internal_algorithms.v`, `internal_algorithms_deletion.v`, `internal_algorithms_structure.v`, `internal_algorithms_values.v` | Focused active-range handling, alignment, boundary canonicalization, whitespace canonicalization, resolved-style lookup, and autolink routines; traced deletion/structure/value helpers. Not every structural-editing branch was compared. | No high-confidence defect established in these samples. No claim that all editing algorithms are exact translations. |
| `Fetch/Fetching/Fetching.cpp` | 2,674 | `fetch/runtime.v`, `runtime_operations.v`, `cors.v`, `preflight_cache.v`, `body.v`, `requests.v`, `responses.v`, `request_response.v` | Focused `main_fetch`, scheme handling, HTTP/network/cache dispatch, redirect, response handover, host-hook boundary, CSP/mixed-content/referrer helper calls. CORS/preflight/body helpers sampled. | WA-03, WA-04: security and referrer algorithms exist elsewhere but are not invoked on this Fetch path. |
| `IndexedDB/Internal/Algorithms.cpp` | 2,724 | `indexeddb/algorithm_operations.v`, `factory.v`, `internal_operations.v`, `transaction.v`, `key.v`, `value.v`, `object_store.v`, `index.v`, `cursor.v`, `records.v`, `request_list.v` | Focused connection queue, open/upgrade/delete, transaction commit/abort, and record mutation; sampled key/value conversion and cursor querying. Reproduced upgrade behavior with an existing connection. | WA-05. Connection/version coordination is replaced with synchronous state changes. |
| `Internals/Internals.cpp` | 2,178 | `internals/internals.v`, `internals_base.v`; actual tree serializers in `dump/dump.v` | Focused tree dumps, XHR construction, synthetic input, wheel/platform state; inventories of asynchronous/compositor testing hooks. Traced actual layout dump helper rather than treating the marker as a host implementation. | WA-06. Some platform/testing hooks are explicit model boundaries; the layout dump has an unconditional marker return. |
| `Page/EventHandler.cpp` | 3,634 | `page/event_handler.v`, `event_entry_points.v`, `mouse_selection_routing.v`, `caret_selection_boundary.v`, `clipboard_actions.v`, `wheel_event_routing.v`, `middle_button_scroll.v`; browser callers in `main.v` | Focused mouse/pointer down/up/move, click/activation, coordinate conversion, chrome-widget capture, input creation; traced browser calls and event logs. Selection/clipboard/wheel implementations sampled. | WA-07. DOM pointer/click dispatch is replaced by event-log entries; real chrome/selection code does not complete that path. |
| `Page/Page.cpp` | 1,537 | `page/page.v`, `page_entry_points.v`, `page_client.v` and related client/boundary modules; `main.v` | Focused navigation/reload, focused-navigable lookup, coordinate/screenshot paths, picker ownership, and history/search entry points. Traced browser navigation and client-event consumers. | WA-08. Page navigation methods log model events while the browser performs navigation separately. Real platform delegates remain in other paths. |
| `Streams/ReadableStreamOperations.cpp` | 2,921 | `streams/readable_operations.v`, `readable_controller_operations.v`, `readable.v`, `readable_byte.v`, `types.v`, `queue.v`, `pipe_tee_transfer.v`, `bindings_glue.v` | Focused default-controller setup/pull/enqueue/close/error, pending read reactions, BYOB enqueue/respond/minimum-fill, and helper traces. Some large BYOB/tee/transfer branches only sampled. | WA-09. Pending read state exists, but pending underlying callback Promises are not representable. |
| `Streams/WritableStreamOperations.cpp` | 1,294 | `streams/writable_operations.v`, `writable.v`, `types.v`, `queue.v` | Focused close sentinel, controller setup, queue advancement, in-flight write/close, error/abort/backpressure; traced callback types. Reproduced a normal-string/close-sentinel collision. | WA-09, WA-10. |
| `WebAssembly/WebAssembly.cpp` | 1,450 | `webassembly/namespace.v`, `cache.v`, `module_instance.v`, `webassembly_module.v`, `value_global.v`, `memory.v`, `table.v` | Focused parse/validate/compile, import/instantiate, export wrapper creation, host-function conversion, and streaming entry points. Searched for an execution/validation backend beyond the module. Reproduced invalid-module acceptance. | WA-11, WA-12. The binary envelope/import/export model omits core validator and machine execution. |
| `WebDriver/Actions.cpp` | 1,697 | `webdriver/action_algorithms.v`, `input_actions.v`, `protocol_algorithms.v`, client/protocol helpers | Focused JSON action parsing/transposition, key/pointer state, wheel scroll, action queues, duration/tick dispatch. Traced callers and timing hooks. | WA-13. Tick waits/task scheduling are absent. PointerCancel/pen/touch unsupported behavior and interpolation TODOs already exist upstream and were not counted as V-specific omissions. |
| `WebGL/WebGL2RenderingContextImpl.cpp` | 1,382 | `webgl/context2.v`, `context.v`, `context_operations.v`, `native_context.v`, `objects.v` | Focused copy-buffer validation, query/sync state, VAO handling, backend dispatch. Not every WebGL2 entry point/overload was compared. | WA-14, WA-15. Sync completion is fabricated; dispatch does not call a GPU backend. |
| `WebGL/WebGLRenderingContextImpl.cpp` | 2,616 | `webgl/context.v`, `context_operations.v`, `native_context.v`, `overload_operations.v`, `context_proxy.v`, `command_list.v`, `objects.v` | Focused shader compile/link, framebuffer status, program reflection/attribute lookup, resource ownership, dispatch and overload readback. Traced proxy/command-list/backend callers. | WA-14. V returns synthetic shader/reflection/framebuffer/readback state instead of corresponding GL results. |
| `XHR/XMLHttpRequest.cpp` | 1,444 | `xhr/xml_http_request.v`, `events.v`, `form_data.v`; constructor caller `internals/internals.v` | Focused open/send/request construction, response callbacks/error/timeout/abort, response/document decoding, progress, and activity roots. Searched host/Fetch/timer/document-parser integration. | WA-16, WA-17, WA-18. State-machine callbacks are substantial, but send does not start a fetch, document responses are text, and progress throttling is omitted. |

## Confirmed findings

### WA-01 — Upstream cryptographic operations are explicit unavailable-backend stubs

**Impact: high; category: untranslated algorithm/backend operations.** `U:Crypto/CryptoAlgorithms.cpp:827` implements RSA-OAEP encryption, `:917` key generation, `:3943` ECDSA signing, `:4981` ECDH derivation, `:6717` Ed448 signing, `:8302` ML-DSA signing, `:9534` cSHAKE digest, `:9864` AES-OCB encryption, and `:10232` KMAC signing. These are executable upstream bodies, not TODOs.

`V:webcrypto/upstream_algorithm_classes.v:9` returns `NotSupportedError` from `backend_unavailable`. The corresponding RSA-OAEP/RSA-PSS/RSASSA-PKCS1/ECDSA/ECDH/X25519/X448 methods at `:124`, `:132`, `:140`, `:148`, `:156`, `:163`, and `:170` call it. Ed448 generation/sign/verify at `:177` and `:180`, ML-DSA at `:185`, ML-KEM at `:193`, KMAC at `:201`, cSHAKE at `:219`, and AES-OCB at `:223` also call it. Ed448 import/export at `:178` are implemented and must not be described as absent. The SubtleCrypto registry at `V:webcrypto/subtle_crypto.v:193` advertises these families, while sign/verify dispatch at `:297` and `:308` supports only HMAC/Ed25519 and rejects the others.

Helper searches found key serialization and real available AES/hash/Ed25519 implementations, but no alternate callable implementations of the listed unavailable operations. A backend adapter could legitimately call a system cryptography library; a method that immediately returns unavailable does not do that. **Remediation:** translate the current upstream operation bodies and required LibCrypto algorithms, or provide a real compatible backend, then complete parameter/format dispatch in `subtle_crypto.v`; retain upstream validation and error behavior.

### WA-02 — SubtleCrypto Promise/task behavior is replaced with synchronous typed results

**Impact: high for browser API parity; category: missing runtime translation.** `U:Crypto/SubtleCrypto.cpp:159` begins encryption, creates a Promise at `:185`, defers work at `:188`, and settles it using the queued Crypto task path (`:194`, `:220`). `V:webcrypto/subtle_crypto.v:269` instead returns `![]u8` directly; sign/verify/generation and other operation APIs also return synchronous typed results.

The typed APIs implement useful argument/key checks. They cannot express the upstream asynchronous result, rejection timing, Promise identity, or browser task ordering. Repository-wide searches for production `webcrypto` bindings/callers did not find an additional WebIDL/JavaScript layer supplying the missing Promise algorithms. The limitation is acknowledged in `webcrypto/PORT_STATUS.md:51`; acknowledgment is not completion. **Remediation:** translate SubtleCrypto's runtime bindings, normalized-parameter copying, deferred work, and Crypto task settlement, connecting the real backend operations from WA-01.

### WA-03 — Shared Fetch omits CSP, mixed-content, and integrity policy gates

**Impact: high; category: implemented policy helpers not connected to Fetch.** `U:Fetch/Fetching/Fetching.cpp:423` reports CSP violations, `:429` upgrades applicable mixed-content requests, and `:434` blocks requests based on bad port, mixed content, CSP, or integrity policy. `V:fetch/runtime.v:820` implements `main_fetch`, but its corresponding pre-dispatch block at `:831` checks only local-URLs-only and bad ports before copying the policy-container referrer policy at `:840`.

Standalone algorithms exist at `V:contentsecuritypolicy/blocking_algorithms.v:48` and `V:mixedcontent/abstract_operations.v:73` / `:101`. Their call-site search found no call from the Fetch runtime or its host hook. `V:fetch/runtime.v:671` defines the host as a `perform` callback plus preferred languages, with no policy callback that fills the omission. Real shared Fetch callers include `V:css/fetch_css_api.v:254` and `V:html/local_navigable_downloads.v:354`.

This establishes a gap on the translated shared Fetch route; it does not establish that every independent native-browser route has the same gap. The generic “upgrade request to a potentially trustworthy URL” step at `U:Fetch/Fetching/Fetching.cpp:426` is already an upstream FIXME and is excluded. **Remediation:** translate and invoke the existing upstream pre-Fetch policy sequence, with applicable request environment and policy state, before any host/network dispatch.

### WA-04 — Shared Fetch does not determine the request referrer

**Impact: high for privacy/security policy; category: untranslated integration step.** `U:Fetch/Fetching/Fetching.cpp:448` calls `determine_requests_referrer` at `:454` and installs a reduced URL or no-referrer result. `V:fetch/runtime.v:840` copies the policy string but does not apply it; `:1042` emits the current referrer URL verbatim as the `Referer` header. Redirect policy updates at `:1314` return to the same path.

The algorithm exists at `V:referrerpolicy/referrer_policy.v:131`; a production call-site search did not find Fetch invoking it. Thus a request carrying a full referrer URL and a restrictive policy is not reduced by this runtime. **Remediation:** translate the referrer determination step into `main_fetch` and reapply it across the upstream redirect flow; verify no-referrer, origin reduction, downgrade, and same-origin cases against upstream.

### WA-05 — IndexedDB opens/upgrades bypass connection queue and version-change coordination

**Impact: high; category: behavior-changing replacement.** `U:IndexedDB/Internal/Algorithms.cpp:97` queues an open request. Before upgrading, `:154` gathers existing connections, fires `versionchange` at `:167`, emits `blocked` at `:192` if necessary, and waits for closure at `:205`.

`V:indexeddb/factory.v:78` creates the new connection, immediately upgrades at `:82`, and changes the shared database version at `:89`, without notifying or waiting for old connections. `V:indexeddb/internal_operations.v:161` gives `ConnectionQueueHandler` no queue state; `:167` returns database data directly. A version-change event helper exists at `V:indexeddb/algorithm_operations.v:19`, but `factory.open` does not call it. Delete at `V:indexeddb/factory.v:125` reports `blocked` and relies on an explicit `retry_delete` at `:153` rather than the upstream queued notification/wait/resume sequence.

A runtime probe opening version 1, finishing its upgrade, and opening version 2 while version 1 remains open produced `old_events=[]`, `new_events=['upgradeneeded']`, and old connection shared `version=2`. **Remediation:** translate per-storage-key/name connection request queues, versionchange/blocked dispatch, close waits, and upgrade/delete completion scheduling in `factory.v` and `internal_operations.v`.

### WA-06 — Internals layout-tree dumping returns a marker instead of inspecting layout

**Impact: medium; category: explicit stub.** `U:Internals/Internals.cpp:1063` updates layout, retrieves the node's actual layout node, returns `(no layout node)` if absent, and calls `dump_tree` at `:1072`. `V:internals/internals.v:1420` returns `(layout tree host boundary)` for any non-null DOM node, without layout update or tree lookup.

There is a real layout serializer at `V:dump/dump.v:107`; no callback/bridge wires it to this Internals method. DOM presence also does not imply the presence of a layout node. **Remediation:** connect the actual retained layout tree and serializer, preserving upstream update/no-layout behavior. A similarly labeled paintable-tree marker was observed, but is not counted as a matched omission from this current C++ source because a corresponding current upstream method was not established.

### WA-07 — Page EventHandler DOM pointer/click/activation algorithms are log operations

**Impact: high; category: untranslated event runtime and altered coordinates.** `U:Page/EventHandler.cpp:630` handles mouseup by routing into nested navigables, dispatching pointerup at `:654`, firing click at `:668`, and running activation at `:681`. Its click routine at `:2172` dispatches actual DOM mouse events. Its coordinate conversion at `:2193` adds navigable viewport scroll, while offset conversion at `:689` accounts for transforms.

`V:page/event_entry_points.v:286` makes hover-capable pointer dispatch a call to `handler.log`; `:302` and `:307` do the same for click and activation. `V:page/event_handler.v:258` stores an `InputDispatch` record, while mouse handlers use target cancellation booleans instead of actual listener return behavior. No event-log consumer providing DOM dispatch was found. `V:page/event_entry_points.v:236` also sets both client and page coordinates to the input position and computes offset by simple origin subtraction.

The browser trace did not fill the gap: `V:main.v:5505` forwards native input to the real chrome-widget callback path, while `:5489` separately replays a compact click on an ancestor with an ID during mousedown. That does not implement the upstream pointer/mouse sequence, listener cancellation, nested routing, or activation algorithm. Chrome-widget capture at `V:page/event_entry_points.v:246` and selection routing have real implementations and were not counted as stubs. **Remediation:** translate the DOM event construction/dispatch, target tracking, capture/hover/activation sequence, navigable routing, and transform/scroll coordinate calculations; connect native input to that path.

### WA-08 — Page load/reload methods update logs instead of invoking navigation

**Impact: high; category: behavior-changing model replacement.** `U:Page/Page.cpp:148` navigates the local root with BrowserUI involvement, history handling, and navigation ID; `:153` navigates an about:srcdoc document resource; `:164` invokes root reload. `V:page/page.v:747` through `:767` set model URL/HTML state and append client events, without invoking the available local navigable.

A search for production consumers of those client events found none. The browser independently loads/parses a document before calling `page_model.load` at `V:main.v:2555`; its reload calls `page_model.reload` at `:2748` and then independently calls `app.navigate` at `:2749`. This keeps some browser navigation working, but does not translate the Page entry points or preserve their upstream contract. Screenshot and picker client delegates elsewhere in `page/` are real platform boundaries; the missing navigation call is separate. **Remediation:** implement the upstream local-root navigation/reload entry points, carrying history/resource/navigation identity, and route the native browser through them without duplicating navigation.

### WA-09 — Streams underlying callbacks cannot remain pending

**Impact: high; category: omitted Promise algorithms.** `U:Streams/ReadableStreamOperations.cpp:1289` holds `pulling` until the pull Promise fulfills (`:1313`, `:1316`, `:1319`). `U:Streams/WritableStreamOperations.cpp:1205` marks the write in flight, reacts to the sink-write Promise at `:1216`, and finishes it on fulfillment at `:1220`.

`V:streams/types.v:548` through `:564` define start/pull/write/close/abort/cancel callbacks as synchronous `!` functions; they cannot return a pending Promise. `V:streams/readable.v:377` calls pull and immediately clears `pulling`; controller setup at `V:streams/readable_controller_operations.v:346` sets `started` immediately after the callback. `V:streams/writable_operations.v:535` completes an in-flight write immediately after synchronous `perform_write`; setup at `:436` similarly completes start inline.

Pending read/write records and pipe/tee state transitions exist; they do not make an underlying source/sink's Promise representable. `streams/PORT_STATUS.md:100` acknowledges synchronous callbacks. **Remediation:** translate WebIDL/JavaScript callback Promise conversion and asynchronous fulfillment/rejection reactions, retaining controller flags and backpressure until settlement, including setup/close/abort/cancel.

**2026-10-02 remediation:** the canonical native V Streams records now retain actual WebIDL Promise backends and source callback fulfillment/rejection jobs for readable/default/byte setup and pull, sink write/close/abort, cancellation, pipe shutdown, tee delivery/cancellation, and shared transform startup/transform/flush/cancel. Source WebIDL callback dictionaries preserve their receiver, actual controller identity, and callback realm; owning HTML settings constructors dispatch jobs through their actual Window/Worker event loop. Actual JSC chunks and readable/writable/transform rejection values retain original identity; real callback Promise/thenable Resolve and stable native-capability/JSC Promise wrapping are available as binding prerequisites. The pending omission is corrected at this native boundary. The native browser now exposes actual owning-record default ReadableStream/reader/controller bindings and source callback/script cleanup with actual VM context ordering. Actual DOM signal algorithms/reasons and owning Window/Worker timeout tasks are connected; PipeTo preserves arbitrary original/later action rejection values. Writable/Transform and public AbortSignal/AbortController/EventTarget factories, remaining generated wrapper behavior, opaque clone/iterator and BYOB buffer integration, public tee arbitrary reasons, and GC reclamation remain open. See [`STREAMS_PENDING_CALLBACKS.md`](STREAMS_PENDING_CALLBACKS.md) for source mappings, focused tests, and exact remaining boundaries.

### WA-10 — WritableStream close sentinel collides with a normal string chunk

**Impact: high; category: reproducible behavior-changing replacement.** `U:Streams/WritableStreamOperations.cpp:30` uses `JS::js_special_empty_value()` as an internal close marker that ordinary chunks cannot equal. `V:streams/writable_operations.v:8` uses the ordinary string `__libweb_stream_close_sentinel__`; `:205` creates/tests it as a normal `Value`. Queue advancement at `V:streams/writable.v:295` treats a chunk with that text as close.

Writing that string through a normal writer reproduced `stream=closed, write=pending, written=0`. The sink never receives the chunk, and no genuine close request exists to settle the write. **Remediation:** use a private queue-entry variant/tag for close, distinct from every caller-provided `Value`, and preserve the upstream in-flight request/close ordering.

### WA-11 — WebAssembly validate/compile skip core sections and validation

**Impact: high; category: omitted parser/validator logic.** `U:WebAssembly/WebAssembly.cpp:129` validates a parsed module with the abstract machine, and compilation at `:472` rejects machine validation errors at `:490`. `V:webassembly/namespace.v:18` returns true whenever `compile_a_webassembly_module` succeeds. `V:webassembly/module_instance.v:174` reads an envelope but its section switch at `:202` parses only custom/import/export sections (0/2/7); `:208` skips other section contents wholesale.

There is no alternative core-section decoder or machine validation hook in the traced compile path. A module with bytes `00 61 73 6d 01 00 00 00 05 01 ff` has an invalid memory-section vector payload, but the V `validate` returned true. **Remediation:** translate the actual upstream LibWasm decoder and validation operations (or connect a compatible validator), including section ordering/duplicates, types, code, limits, expressions, and cross-section consistency; do not equate envelope parsing with validity.

### WA-12 — WebAssembly instantiation fabricates exports without machine execution

**Impact: high; category: substituted logic and missing execution backend.** `U:WebAssembly/WebAssembly.cpp:293` resolves imports/types and calls machine instantiate at `:454`. Exported functions are native callables invoking the machine at `:749` / `:774`. `V:webassembly/module_instance.v:383` checks only import names and broad kinds, then creates exports at `:400` from their enumeration order rather than the declared module instances.

Functions become callback-value tokens at `:404`; globals become fresh zero i32 objects at `:407`; memories use an empty/default descriptor at `:412`; tables become default externref tables at `:417`. Export index, declaration type, initial state, imported-resource identity, start/code/data execution, and upstream function invocation are not supplied. `V:webassembly/cache.v:80` gives `AbstractMachine` only counters, and `:87` gives `ExportedWasmFunction` descriptive fields without an invocation callback. Host-function value conversion is implemented, but is not a core Wasm interpreter. Repository-wide backend searches did not find a LibWasm/wasmtime/native execution path completing these calls.

**Remediation:** translate linking, machine instantiation, store/resource identity, initialization, and function invocation; create JS wrappers around real exported addresses/types. Synthetic export construction is observable replacement logic, regardless of whether it was originally generated or handwritten. Its authorship was not established by this audit.

### WA-13 — WebDriver action tick durations and queue scheduling are omitted

**Impact: high for action semantics; category: synchronous replacement.** `U:WebDriver/Actions.cpp:1368` processes ticks using computed tick duration at `:1382`, dispatch at `:1386`, and a timer/task handoff at `:1401`. `V:webdriver/action_algorithms.v:565` replaces the queue wait with an assertion that its token is alone. `:573` dispatches every tick in an immediate loop; pause actions at `V:webdriver/input_actions.v:579` merely continue. `compute_tick_duration` exists at `V:webdriver/action_algorithms.v:508` but is not called by that dispatch loop.

Returned event records do not supply the missing intertick event-loop waits, and no scheduling/host dispatcher was found completing this flow. Upstream's fine-grained pointer interpolation still has TODOs around `U:WebDriver/Actions.cpp:1208`; those are not counted here. Current upstream scroll is implemented and the V scroll action is present, so older status text saying scroll is unsupported is not evidence of a current omission. **Remediation:** translate action queue arbitration and duration-based tick scheduling, deliver events through the browser input boundary, and preserve the current upstream limitations separately.

### WA-14 — WebGL has synthetic answers and no real backend dispatch

**Impact: high; category: missing renderer/backend plus behavior-changing replacements.** `U:WebGL/WebGLRenderingContextImpl.cpp:376` returns the actual framebuffer status, `:414` compiles through GL, `:891` obtains the actual attribute location, and `:2233` links the actual program. `V:webgl/context.v:523` considers any nonempty shader source compiled; `:597` treats attached shaders' booleans as link status. `V:webgl/context_operations.v:409` always returns framebuffer complete; `:1004` returns invented `attribute_${index}`/`uniform_${index}` descriptions; `:1012` hashes names into attribute locations.

The nominal backend at `V:webgl/native_context.v:168` makes the context current, updates viewport bookkeeping, optionally records calls, and marks content changed. It does not dispatch any GPU calls, and tracing proxy/command-list helpers found no implementation supplying them. The inspected readback helper at `V:webgl/overload_operations.v:105` returns a zero-filled buffer rather than rendered pixels. Both large WebGL translation units call this same absent backend.

A native graphics API adapter is a legitimate translation choice when it produces equivalent operations and results. These fixed/hash answers cannot be justified by an OS adapter. **Remediation:** translate or wire the real GL backend and return its status/reflection/results, preserving upstream validation/object ownership; remove fabricated successful outputs. The authorship/provenance of those replacements was not established.

### WA-15 — WebGL2 sync completion is fabricated

**Impact: high; category: behavior-changing replacement.** `U:WebGL/WebGL2RenderingContextImpl.cpp:939` validates ownership, then returns the backend's wait result at `:950`. `V:webgl/context2.v:290` rejects every nonzero flag, reports timeout for zero timeout, and for any nonzero timeout sets `sync.signaled_ = true` at `:305` and returns condition-satisfied. `wait_sync` at `:310` also sets the signaled bit directly at `:319`.

The dispatch called afterward is the bookkeeping-only backend from WA-14, so no GPU completion observation can justify either result. **Remediation:** translate the backend fence/wait/query behavior and valid flag handling, leaving completion state to real synchronization. This is separate from platform choice: it claims completion without waiting for work.

### WA-16 — XMLHttpRequest send does not start Fetch or schedule a timeout

**Impact: high; category: missing runtime integration.** `U:XHR/XMLHttpRequest.cpp:688` constructs request state; `:1012` calls Fetch with upload/response hooks; `:1030` installs the asynchronous timeout and terminates the fetch if necessary. The synchronous branch also fetches/spins through the body (`:1065`). `V:xhr/xml_http_request.v:347` initializes body/flags/logged loadstart events and returns at `:381`. `:373` only sets a `timeout_timer_active` boolean.

The typed receive callbacks implement meaningful subsequent state transitions, but `send` does not invoke them through a Fetch host. No production Fetch/timer integration was found for this XHR object; the only traced non-test constructor was `V:internals/internals.v:251`. Its global environment fields at `V:xhr/xml_http_request.v:38` supply no host/timer callback completing send. **Remediation:** translate request construction into the shared Fetch API, connect upload/body/completion callbacks, implement timeout/abort cancellation, and translate synchronous request event-loop behavior where upstream supports it.

### WA-17 — XMLHttpRequest document responses are strings, without HTML/XML parsing

**Impact: high; category: untranslated document response logic.** `U:XHR/XMLHttpRequest.cpp:407` builds a Document, performs HTML encoding prescan at `:443`, parses HTML at `:456` or XML at `:465`, and handles parser failure. `V:xhr/xml_http_request.v:697` caches decoded text under `.document`; `:714` returns a text-only `XHRDocumentResult`. `response_xml` at `:744` returns raw byte-to-string text at `:759`, without parsing or the same decoding route.

There is no connected HTML/XML document-parser callback in this response path. Consequently malformed XML can return text instead of the upstream null document, and the object lacks upstream document DOM/encoding/origin semantics. Treating zero received bytes as no body at `:698` / `:735` also conflates an empty body with null. The upstream XML text-encoding TODO around `U:XHR/XMLHttpRequest.cpp:388` is excluded; actual document parsing is already implemented upstream. **Remediation:** translate document construction, encoding/prescan, parser failure handling, and document response identity with the available HTML/XML parsers, returning real document objects.

### WA-18 — XMLHttpRequest progress dispatch lacks upstream throttling

**Impact: medium; category: omitted timing logic.** `U:XHR/XMLHttpRequest.cpp:885` throttles upload progress with a 50 ms timestamp check; `:970` similarly throttles download LOADING/readystatechange/progress work. `V:xhr/xml_http_request.v:404` fires progress on each upload callback, and `:461` fires readystatechange/progress on every received chunk. Its state has no corresponding last-progress timestamps.

This changes listener count/timing and permits event volume proportional to chunking rather than upstream's throttle. It remains a mismatch even when a future Fetch integration supplies the receive callbacks. **Remediation:** translate the upload/download timestamp checks and event ordering, including final progress/completion events, using the owning event-loop clock.

## Validation evidence and limits

Three isolated V probes were executed outside the repository using `/Users/alex/code/v/v -old-compiler -enable-globals -path '/Users/alex/code/vox2|@vlib|@vmodules' run /tmp/vox2-web-api-audit.PGVLra/probe.v`. The compiler used its installed fallback, and execution completed successfully. These were audit reproductions, not committed product tests:

```text
sentinel: stream=closed, write=pending, written=0
invalid memory section validation=true
upgrade with previous connection open: old_events=[], new_events=['upgradeneeded'], version=2
```

The writable probe constructed an ordinary `WritableStream`, acquired a writer, and wrote `string_value('__libweb_stream_close_sentinel__')`. The Wasm probe passed the invalid eleven-byte memory-section module listed in WA-11. The IndexedDB probe opened version 1, finished its upgrade, kept that connection open, then opened version 2 using the same factory/storage key.

The complete probe source was:

```v
module main

import streams
import webassembly
import webidl
import indexeddb

fn main() {
	mut stream := streams.WritableStream.construct_impl(streams.UnderlyingSink{},
		streams.QueuingStrategy{})!
	mut writer := stream.get_writer()!
	promise := writer.write(streams.string_value('__libweb_stream_close_sentinel__'))
	println('sentinel: stream=${stream.state()}, write=${promise.state()}, written=${stream.written_values().len}')
	bytes := [u8(0), 97, 115, 109, 1, 0, 0, 0, 5, 1, 255]
	println('invalid memory section validation=${webassembly.validate(webidl.BufferSource.array_buffer(bytes))}')
	mut factory := indexeddb.IDBFactory.create('audit-isolated-storage')!
	mut first := factory.open('db', u64(1))!
	first.finish_upgrade()!
	second := factory.open('db', u64(2))!
	println('upgrade with previous connection open: old_events=${first.connection.events}, new_events=${second.request.events}, version=${first.connection.data.version}')
}
```

The audit did not run the full repository test suite, upstream WPT/WebGL suites, cryptographic known-answer/conformance suites, or a browser-integrated API exercise. It did not establish the authorship of replacement algorithms. Confirmed substituted bodies are reported by their executable difference, rather than assumed to have been written “from scratch.” Full provenance would require commit/history analysis and a complete operation-level comparison. CSP scalar-value-string conversion, full editing algorithms, large BYOB/tee/transfer branches, all WebGL overloads, and asynchronous browser bindings remain comparison limits, not verified parity.

The observations are sufficient to reject an assertion of no stubs/untranslated logic. They are not sufficient to assert that every unreported algorithm is translated correctly.
