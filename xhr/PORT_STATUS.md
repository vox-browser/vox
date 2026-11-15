# XHR module V translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XHR`

Translation workspace: `~/code/vox/xhr`
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

Native FormData worker exposure and serialization (2026-11-09): `9755deb9a`
installs the existing native FormData owner after File/FileList in classic and
module dedicated/shared worker globals. Fetch multipart bodies and formData()
consume those native records. `9a6928e18` preserves existing CRLF pairs while
normalizing field names/values; file bytes remain unchanged. `af8181c46`
preserves unpaired UTF-16 units across private compact queries/replay and text
control replies, with scalar conversion deferred to FormData entry creation.
`34c9d0c64` uses the existing canonical number formatter for range sanitization,
matching numeric setters and form-data entries.

The current **35-variant FormData/upload selection passes 213/213 assertions**
(**86/86 Worker, 127/127 Window**) in normal native Page checks and with the
prepared preallocation runtime. The previous 211/213 result and both image
failures remain in the evidence history. `d6022fcd0` connects image input
requests and decoded providers to native sizing/paint; `0156dc34e` selects
content-relative coordinates for dispatched mouse events while preserving
coordinate-free `.click()` activation. `5296d2e1d` supplies an opt-in native Page
pointer backend at WPT's standard vendor extension point; test assertions and
harness behavior stay unchanged.

Together with the unchanged 30 FileReader variants, **65 focused variants pass
328/328 assertions with strict exits 0 in both final memory configurations**.
A plain preallocation attempt reported 328 passing assertions but failed later
with a closure-map arena panic; it remains failed. The final rerun uses the
existing production runtime preparation, with detached closure metadata and
bounded realloc. Twelve behavioral integration checks pass per mode, alongside
the native worker/navigation entry points, three Python adapter checks and the
closure metadata arena regression.

Production validation and the required 11 unchanged SVG pixel comparisons are
pending a source-matching completed shared build. These focused results do not
establish full XHR, FormData or WPT parity; see the
[WPT progress report](../docs/WPT_CONFORMANCE_PROGRESS.md) for evidence and
remaining scope.

The 2026-11-16 native LibJS bridge in libjsdom now exposes FormData construction
from native forms/submitters, append/set/delete/get/getAll/has, live iteration
and forEach, actual File entry wrappers and FormDataEvent. Native form-entry
construction dispatches its trusted event; the JS formData getter binds the
same mutable native entry owner, so handler changes reach the constructor's
result. Fetch bodies use the native multipart serializer, and Request/Response
formData methods use native multipart or URL-encoded parsing. These additions
use LibJS and typed owners without a JavaScriptCore adapter.

The new regression source is uncompiled and unexecuted under the user's hold.
Final normal and production/preallocation compiler-only checks pass. Native
LibJS XMLHttpRequest, full form-control property bindings, foreign-realm rules,
native collection and inherited parser/serializer limits remain separate;
GitHub execution and Brave pixels are unverified. See the
[File/FormData continuation](../docs/LIBJS_GITHUB_RUNTIME_20261115.md#native-file-formdata-and-fetch-continuation).

The following native LibJS control/form slice connects live input/textarea
values, checkedness and select/option selection to the same owners read by
FormData construction. Explicit empty checked values remain empty during
submission. Form reset, requestSubmit, native SubmitEvent.submitter and
submitter overrides now use the HTML owners; the browser embedding routes
completed form submissions through its existing body/target navigation path.
Thirty-five new cases remain uncompiled/unexecuted under the user's hold;
compiler-only checks do not establish browser or XHR conformance. Full control
IDL, collections, FileList, native LibJS XMLHttpRequest and broader runtime/
rendering behavior remain open. See the
[control/form-action continuation](../docs/LIBJS_GITHUB_RUNTIME_20261115.md#native-control-state-and-form-action-continuation).
