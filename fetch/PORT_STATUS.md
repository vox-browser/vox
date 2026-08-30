# Fetch translation status

Complete audited translation of `Libraries/LibWeb/Fetch`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `Body.cpp` | `body.v`, `upstream_body_entry_points.v` |
| `BodyInit.cpp` | `body.v` |
| `Enums.cpp` | `requests.v`, `request_response.v`, `enums.v` |
| `FetchMethod.cpp` | `requests.v`, `upstream_runtime_entry_points.v` |
| `Fetching/Checks.cpp` | `cors.v`, `runtime.v` |
| `Fetching/FetchedDataReceiver.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Fetching/Fetching.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Fetching/PendingResponse.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Fetching/RefCountedFlag.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Headers.cpp` | `headers.v` |
| `HeadersIterator.cpp` | `headers.v` |
| `Infrastructure/FetchAlgorithms.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Infrastructure/FetchController.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Infrastructure/FetchParams.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Infrastructure/FetchRecord.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Infrastructure/FetchTimingInfo.cpp` | `runtime.v`, `upstream_runtime_entry_points.v` |
| `Infrastructure/HTTP.cpp` | `runtime.v`, `infrastructure.v` |
| `Infrastructure/HTTP/Bodies.cpp` | `body.v`, `upstream_body_entry_points.v` |
| `Infrastructure/HTTP/CORS.cpp` | `cors.v` |
| `Infrastructure/HTTP/MIME.cpp` | `infrastructure.v` |
| `Infrastructure/HTTP/Requests.cpp` | `requests.v`, `upstream_request_entry_points.v` |
| `Infrastructure/HTTP/Responses.cpp` | `responses.v`, `upstream_response_entry_points.v` |
| `Infrastructure/HTTP/Statuses.cpp` | `responses.v` |
| `Infrastructure/IncrementalReadLoopReadRequest.cpp` | `runtime.v` |
| `Infrastructure/MimeTypeBlocking.cpp` | `blocking.v` |
| `Infrastructure/NetworkPartitionKey.cpp` | `runtime.v` |
| `Infrastructure/NoSniffBlocking.cpp` | `blocking.v` |
| `Infrastructure/PortBlocking.cpp` | `blocking.v` |
| `Infrastructure/Task.cpp` | `runtime.v` |
| `Infrastructure/URL.cpp` | `infrastructure.v` |
| `Request.cpp` | `request_response.v`, `upstream_request_entry_points.v` |
| `Response.cpp` | `request_response.v`, `upstream_response_entry_points.v` |

The platform resource loader and event-loop handoff are represented by typed
`FetchHost` and callback boundaries; the HTTP cache has a deterministic
partitioned in-memory implementation. The translated algorithms retain
request/response filtering, redirects, CORS/preflight, body consumption,
headers guards and iteration, data URLs, task/controller state, and the WebIDL
Request/Response surface without depending on Ladybird's C++ networking stack.
The audit also covers filtered-response delegation, opaque timing projection,
network timing conversion, guarded header refilling, stream-body preflights,
UTF-8 body consumers, form decoding and independent body cloning.

- Upstream: 32 `.cpp` files, 7,787 LOC; all 34 adjacent headers and 5 IDLs audited.
- V implementation: 4,531 LOC in 14 files.
- V tests: 1,038 LOC in 11 files (64 test functions).
- Symbol audit: 497 upstream implementation symbols, zero unmatched.
- Verification: `/Users/alex/code/v/v_old -enable-globals test fetch` (11/11 files pass).
