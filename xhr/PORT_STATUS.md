# XHR module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XHR`

Translation workspace: `~/code/libweb_v/xhr`
Audited: 2026-08-17

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
| `XHR/` | 7 | 1,706 | 964 | 274 | Complete |

Associated declarations comprise 8 headers / 473 LOC and 5 IDL files / 122
LOC. Mapping completeness is 7/7 implementation units, 8/8 headers, and 5/5
IDL definitions audited.

The port covers method/header validation, URL and credential parsing,
sync/window restrictions, all response types, MIME override and document rules,
response-header combination, request/response/upload progress, abort/network/
timeout paths, response caching, and GC liveness. Fetching, timers, text-codec
selection, and HTML/XML document construction remain explicit host boundaries;
request and response chunks enter through typed callbacks, while parsed document
content is exposed as source text.

Verification: `v test xhr` passes 3/3; formatting and scoped diff checks pass.
