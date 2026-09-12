# XHR module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XHR`

Translation workspace: `~/code/vox2/xhr`
Audited: 2026-09-11

All seven upstream implementation units, eight headers, and five WebIDL files
were audited. The V package represents EventNames, ProgressEvent and inherited
EventInit state, XMLHttpRequestEventTarget/Upload, FormData entries and live
iterators, and the XMLHttpRequest state machine.

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `ProgressEvent.cpp`, `XMLHttpRequestEventTarget.cpp`, `XMLHttpRequestUpload.cpp` | `events.v` |
| `FormData.cpp`, `FormDataIterator.cpp` | `form_data.v` |
| `XMLHttpRequest.cpp` | `xml_http_request.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `XHR/` | 7 | 1,855 | 1,329 | 455 | Complete |

Associated declarations comprise 8 headers / 512 LOC and 5 IDL files / 99
LOC. Mapping completeness is 7/7 implementation units, 8/8 headers, and 5/5
IDL definitions audited.

The port covers method/header validation, URL and credential parsing,
sync/window restrictions, all response types, MIME override and document rules,
response-header combination, request/response/upload progress, abort/network/
timeout paths, response caching, and GC liveness. Fetching, timers, text-codec
selection, and HTML/XML document construction remain explicit host boundaries.
Form construction crosses the translated HTML form model, request and response
chunks enter through typed callbacks, and parsed document content is exposed as
source text. The global boundary owns live-request tracking, timeout state, and
activity roots for requests with relevant event listeners.

Verification: `v -enable-globals test xhr` passes 3/3; scoped diff checks pass.
