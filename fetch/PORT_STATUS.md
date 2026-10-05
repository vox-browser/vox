# Fetch translation status

Audited against `Libraries/LibWeb/Fetch` on 2026-09-04. Every upstream
implementation symbol has a reviewed V implementation or an explicit
language/runtime disposition.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `Body.cpp` | `body.v`, `body_operations.v` |
| `BodyInit.cpp` | `body.v` |
| `Enums.cpp` | `requests.v`, `request_response.v`, `enums.v` |
| `FetchMethod.cpp` | `requests.v`, `runtime_operations.v` |
| `Fetching/Checks.cpp` | `cors.v`, `runtime.v` |
| `Fetching/FetchedDataReceiver.cpp` | `runtime.v`, `runtime_operations.v` |
| `Fetching/Fetching.cpp` | `runtime.v`, `runtime_operations.v` |
| `Fetching/PendingResponse.cpp` | `runtime.v`, `runtime_operations.v` |
| `Fetching/RefCountedFlag.cpp` | `runtime.v`, `runtime_operations.v` |
| `Headers.cpp` | `headers.v` |
| `HeadersIterator.cpp` | `headers.v` |
| `Infrastructure/FetchAlgorithms.cpp` | `runtime.v`, `runtime_operations.v` |
| `Infrastructure/FetchController.cpp` | `runtime.v`, `runtime_operations.v` |
| `Infrastructure/FetchParams.cpp` | `runtime.v`, `runtime_operations.v` |
| `Infrastructure/FetchRecord.cpp` | `runtime.v`, `runtime_operations.v` |
| `Infrastructure/FetchTimingInfo.cpp` | `runtime.v`, `runtime_operations.v` |
| `Infrastructure/HTTP.cpp` | `runtime.v`, `infrastructure.v` |
| `Infrastructure/HTTP/Bodies.cpp` | `body.v`, `body_operations.v` |
| `Infrastructure/HTTP/CORS.cpp` | `cors.v` |
| `Infrastructure/HTTP/MIME.cpp` | `infrastructure.v` |
| `Infrastructure/HTTP/Requests.cpp` | `requests.v`, `request_operations.v` |
| `Infrastructure/HTTP/Responses.cpp` | `responses.v`, `response_operations.v` |
| `Infrastructure/HTTP/Statuses.cpp` | `responses.v` |
| `Infrastructure/IncrementalReadLoopReadRequest.cpp` | `runtime.v` |
| `Infrastructure/MimeTypeBlocking.cpp` | `blocking.v` |
| `Infrastructure/NetworkPartitionKey.cpp` | `runtime.v` |
| `Infrastructure/NoSniffBlocking.cpp` | `blocking.v` |
| `Infrastructure/PortBlocking.cpp` | `blocking.v` |
| `Infrastructure/Task.cpp` | `runtime.v` |
| `Infrastructure/URL.cpp` | `infrastructure.v` |
| `Request.cpp` | `request_response.v`, `request_operations.v` |
| `Response.cpp` | `request_response.v`, `response_operations.v` |

The platform resource loader and event-loop handoff are represented by typed
`FetchHost` and callback boundaries. Reviewed translations currently include
the request/response records and filtered delegation, Web Request/Response
construction, controller/pending-response state, body extraction and
multipart parsing, CORS checks, redirects, response handoff, and the
partitioned HTTP memory-cache lifecycle.

The request and response infrastructure records now own their real `Body`
objects, as in C++. Web-facing objects no longer keep independent byte-copy
shadows. Cloning tees the shared stream; abort cancels/errors that same stream;
content length, filtering, cache extraction, and consume-body callbacks all use
the canonical body. `FetchedDataReceiver` likewise feeds the actual readable
byte stream.

Platform resource loading, event-loop scheduling, policy integration, and
authentication enter through typed host/callback boundaries where the
standalone V module graph cannot import the browser embedding layer directly.

Current strict-audit snapshot: 497 upstream implementation symbols, 364
candidate-name matches, 88 consolidated-name matches, 45 language/runtime
dispositions, and 0 unmatched. No Fetch implementation file remains in audit
quarantine. Verification uses `/Users/alex/code/v/v -enable-globals test fetch`;
all 11 test files pass at this checkpoint.

Actual Blob scheme requests now consume their copied URL entries (`08d65915`)
and query genuine client/reserved Environment owners for partition and
self-fetch (`reserved` priority, current creation URL and logical navigable).
Parsed requests/clones retain independent bytes/type after revocation, while
new parses fail; MediaSource tags do not become Blob responses. The actual
Fetch/media callers pass **2/2 default and 5/5 GC-none** files with existing
MediaSource/settings and main neighbors. [Owner evidence](../docs/translation-audit/BLOB_URL_FETCH_ACTUAL_REQUEST.md)
retains original and diagnostic outcomes. Raw standalone strings keep their
Legacy boundary. Source isomorphic type-header encoding now has a separate
completed slice (`242a95de`), with **3/3 default and 5/5 GC-none** focused
encoder/HTTP/actual Fetch files; [header evidence](../docs/translation-audit/BLOB_URL_HEADER_ISOMORPHIC_ENCODING.md)
records the executed original UTF8-byte mismatch and retained metadata/range
proof.
Native bindings, remote transport, physical allocation and full GC ownership
remain separate. This does not establish complete Fetch parity.
