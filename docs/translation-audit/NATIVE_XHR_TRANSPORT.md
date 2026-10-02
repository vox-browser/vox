# Native XMLHttpRequest and transport follow-up

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This closes concrete runtime connections in WA-16. It does **not** close EX-05
or establish complete RequestServer or browser IDL parity.

## Source mappings

| Source responsibility | V implementation |
| --- | --- |
| `Services/RequestServer/ConnectionFromClient.cpp`: curl multi configuration, socket readiness, requested due-at single-shot timeout, completion draining | `requestserver/curl_connection.v`, CoreFoundation socket ABI in `curl_bridge.h` |
| `Services/RequestServer/Request.cpp`: uncached easy-handle configuration, method/body/headers, reason phrase, body callbacks, completion, timing acquisition, detach/free | `requestserver/curl_request.v` |
| `Services/RequestServer/CURL.cpp` and `LibRequests/NetworkError.h`: initialization and curl error mapping | `requestserver/curl_connection.v`, `curl_request.v` |
| `LibRequests/RequestClient`/`Request`: asynchronous start/stop delivery boundary | native adapter deferred registration/removal; real handles retained by Fetch controller and response |
| `Fetch/Fetching/Fetching.cpp`: ResourceLoader headers/data/completion callbacks and shared controller/timing/receiver | params-aware `FetchHost` callback; actual `PendingResponse`, `FetchedDataReceiver`, stream, network handle and final-hop timing |
| `XHR/XMLHttpRequest.idl`, `XMLHttpRequestEventTarget.cpp` | `browserjs/xhr_host.v`, `xhr_bootstrap.v`, actual owning settings/XHR/DOM listener records |
| `XHR/XMLHttpRequest.cpp`: Document request serialization and MIME/charset rules | `xhr/document_request.v`; existing real DOM fragment serializers |
| `XHR/ProgressEvent.cpp`: independently retained event objects | heap event allocation in `xhr/events.v`; JS callbacks retain the same native event identity |

JavaScriptCore remains the native browser execution engine. The compact factory
calls the translated XHR model for method/header validation, request setup,
Fetch, timeout/abort transitions and responses. It registers actual DOM
listeners and event handlers, including removal, capture, once and passive
options. Native callbacks publish their real event payload and can call native
event cancellation/propagation methods. Async callback mutations enter the
existing compact DOM replay before retained painting.

Response text and JSON use the XHR model; ArrayBuffer byte contents come from
the same response. Blob text decoding uses the actual FileAPI Blob operation.
Document responses retain the actual parsed Document, with native URL/title/
MIME, document element, ID lookup and selector/text/attribute operations.
Document and Blob request bodies invoke the actual XHR body operations.

The transport performs real HTTP(S) through curl multi socket readiness and
native timers, with Fetch performing redirects and CORS decisions. No successful
network result is manufactured. Start/stop operations retain the deferred
RequestClient boundary so redirect callbacks cannot recursively mutate a curl
multi handle. Native mutations execute outside V `assert` expressions, which
optimized V builds remove.

## Remaining boundaries

- This is an **in-process, macOS transport adapter**. LibRequests IPC endpoints,
  RequestPipe/ResponseData file transfer, RequestServer ownership/transfer leases
  and process death/reconnection are still unported. Native response handles
  have no genuine RequestServer client ID or transferable lease.
- The adapter starts the uncached Fetch state with libcurl/OS DNS resolution.
  It does not translate RequestServer's full Init/DNS/cache/cookie/substitution/
  revalidation state machine, configured resolver/address selection, alternate
  service cache, retry/AIA policy or source TLS context customization.
- Fetch's translated memory cache remains separate from the unported disk cache.
  The native adapter does not implement the source cookie lookup/storage policy.
- Pause/resume crosses the adapter into libcurl receive suspension; it does not
  reproduce RequestPipe and LibRequests read-notifier/file-backed delivery.
- Older macOS SDK libcurl lacks `CURLINFO_QUEUE_TIME_T`; its unavailable queue
  offset remains zero. Other final-hop timings come from real curl getinfo.
- Upstream Fetch currently leaves upload byte/completion callbacks unimplemented.
  No upload progress is invented from received response bytes.
- The compact browser still lacks complete generic DOM/WebIDL wrapper identity,
  generic Event/ProgressEvent constructors and dispatchEvent/AbortSignal binding,
  full response Document/Blob interfaces, and compact FormData body binding.
  Existing supported XHR response interfaces call real records; this is not a
  claim of complete browser IDL coverage.
- Native BrowserApp navigation and ordinary resource preloads still use their
  separate V HTTP path. WA-08 and the full RequestServer source boundary remain
  open. Native socket scheduling on non-macOS hosts remains an explicit adapter.

## Validation

Focused native tests exercise a loopback server's separate body chunks, actual
HTTP headers, a body-bearing redirect, real cancellation, JSON/UTF-8 responses,
listener identity/removal, native timeout, reentrant abort and callback DOM
replay. XHR Document request tests cover actual HTML/XML serialization, default
MIME, author charset rewriting, GET body omission and state validation. Blob
request tests cover binary bytes and typed/untyped MIME extraction. Existing
Fetch and XHR binding neighbors are also exercised.

`tools/native_xhr_transport_smoke.v` is an ordinary executable with explicit
failure checks; compiling and running it with `-prod` verifies that curl work
and owning XHR DOM event delivery survive optimized builds. Native bundle build
and `--headless-smoke` provide the browser glue/startup checks.

Confirmed on 2026-10-02: the three native transport regressions, three compact
host regressions, live-DOM callback replay, four Document request regressions,
Blob request regression, retained DOM event suite and Fetch/XHR neighbors pass.
The ordinary production executable passes, the macOS production bundle builds,
and its JavaScriptCore and selected-LibJS headless startup checks pass. The LibJS
startup output continues to state that DOM bindings are pending.
