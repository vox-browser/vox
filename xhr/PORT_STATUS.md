# XHR module V translation status

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
| `XHR/` | 7 | 1,855 | 1,329 | 455 | Historical core mapping; runtime follow-up below |

Associated declarations comprise 8 headers / 512 LOC and 5 IDL files / 99
LOC. Mapping completeness is 7/7 implementation units, 8/8 headers, and 5/5
IDL definitions audited.

The core covers method/header validation, URL and credential parsing,
sync/window restrictions, response types, MIME override and document rules,
response-header combination, progress, abort/network/timeout paths and caching.
Bound requests use their actual HTML settings, Fetch controller, streamed body,
native timers and DOM event targets/listeners/handlers. Document responses retain
actual parsed HTML/XML Documents; Document requests use the actual serializer
and source MIME/charset rules. Blob requests use their real bytes and MIME.

The macOS compact browser now installs an owning-document XMLHttpRequest factory
and an in-process curl socket/timer transport. Asynchronous native callbacks
reach the live DOM replay before painting. This does not establish full
RequestServer, generic browser IDL or GC parity: source IPC/DNS/cache/cookie/lease
states, complete wrappers and non-macOS transport remain open. Upstream Fetch's
upload callback FIXME is retained rather than producing invented progress.
See [native transport follow-up](../docs/translation-audit/NATIVE_XHR_TRANSPORT.md)
for exact source mappings, validation and remaining boundaries.

Historical verification at the original mapping checkpoint:
`v -enable-globals test xhr` passed 3/3. The follow-up includes focused model,
actual loopback transport, compact native host, DOM replay and production-build
smoke checks.
