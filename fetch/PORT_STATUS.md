# Fetch translation status

Complete audited translation of `Libraries/LibWeb/Fetch`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `Body.cpp` | `body.v` |
| `BodyInit.cpp` | `body.v` |
| `Enums.cpp` | `requests.v`, `request_response.v` |
| `FetchMethod.cpp` | `requests.v` |
| `Fetching/Checks.cpp` | `cors.v`, `runtime.v` |
| `Fetching/FetchedDataReceiver.cpp` | `runtime.v` |
| `Fetching/Fetching.cpp` | `runtime.v` |
| `Fetching/PendingResponse.cpp` | `runtime.v` |
| `Fetching/RefCountedFlag.cpp` | `runtime.v` |
| `Headers.cpp` | `headers.v` |
| `HeadersIterator.cpp` | `headers.v` |
| `Infrastructure/FetchAlgorithms.cpp` | `runtime.v` |
| `Infrastructure/FetchController.cpp` | `runtime.v` |
| `Infrastructure/FetchParams.cpp` | `runtime.v` |
| `Infrastructure/FetchRecord.cpp` | `runtime.v` |
| `Infrastructure/FetchTimingInfo.cpp` | `runtime.v` |
| `Infrastructure/HTTP.cpp` | `runtime.v`, `infrastructure.v` |
| `Infrastructure/HTTP/Bodies.cpp` | `body.v` |
| `Infrastructure/HTTP/CORS.cpp` | `cors.v` |
| `Infrastructure/HTTP/MIME.cpp` | `infrastructure.v` |
| `Infrastructure/HTTP/Requests.cpp` | `requests.v` |
| `Infrastructure/HTTP/Responses.cpp` | `responses.v` |
| `Infrastructure/HTTP/Statuses.cpp` | `responses.v` |
| `Infrastructure/IncrementalReadLoopReadRequest.cpp` | `runtime.v` |
| `Infrastructure/MimeTypeBlocking.cpp` | `blocking.v` |
| `Infrastructure/NetworkPartitionKey.cpp` | `runtime.v` |
| `Infrastructure/NoSniffBlocking.cpp` | `blocking.v` |
| `Infrastructure/PortBlocking.cpp` | `blocking.v` |
| `Infrastructure/Task.cpp` | `runtime.v` |
| `Infrastructure/URL.cpp` | `infrastructure.v` |
| `Request.cpp` | `request_response.v` |
| `Response.cpp` | `request_response.v` |

The platform resource loader, cache and event-loop handoff are represented by
typed `FetchHost` and callback boundaries. The translated algorithms retain
request/response filtering, redirects, CORS/preflight, body consumption,
headers guards and iteration, data URLs, task/controller state, and the WebIDL
Request/Response surface without depending on Ladybird's C++ networking stack.
The audit also covers constructor fallback/reset behavior, guarded header
refilling, stream-body preflights, UTF-8 body consumers, form decoding and
independent body cloning.

- Upstream: 32 `.cpp` files, 7,787 LOC; all 34 adjacent headers and 5 IDLs audited.
- V implementation: 3,194 LOC in 9 files.
- V tests: 876 LOC in 10 files (58 test functions).
- Verification: `v test fetch` and `v fmt -verify fetch`.
