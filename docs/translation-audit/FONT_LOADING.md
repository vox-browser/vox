# Source font loading translation

Reference: read-only Ladybird revision `963d46a829f3e1b79f44dba9d02afb70654300fa`.

| Upstream implementation | V counterpart |
| --- | --- |
| `LibWeb/CSS/FontComputer.cpp`, `FontLoader` | `css/font_face_values.v`, `css/font_fetch_transport.v` |
| `LibWeb/CSS/FontLoading.cpp` | `css/font_loading.v` |
| `LibWeb/CSS/FontFaceSet.cpp`, `load()` | `css/font_face_values.v`, `css/font_loading_tasks.v`, `html/font_loading_tasks.v` |
| `LibGfx/Font/WOFF/Loader.cpp` | `gfxfont/woff.v` |
| `LibGfx/Font/WOFF2/Loader.cpp` | `gfxfont/woff2.cpp`, `gfxfont/woff2.c.v` |
| `LibGfx/Font/TypefaceSkia.cpp`, `load_from_buffer()` | `skia/font_typeface.cpp` |
| `LibThreading/ThreadPool.cpp` | `threading/thread_pool.v`, `threading/condition_bridge.h` |
| `LibCore/ThreadEventQueue.cpp`, deferred work | `platform/native_deferred.c.v`, `platform/native_deferred_bridge.h` |
| `LibWeb/Fetch/Fetching/Fetching.cpp`, file-font policy | `fetch/runtime.v`, `css/fetch_css_api.v` |
| `LibWeb/DOM/Document.cpp`, navigation initialization | `html/document_parse.v`, `main_navigation_document.v` |

Document font loaders now retain an actual Fetch controller, use source stylesheet/document URL and origin information, request the font destination with CORS, and wait for response-body consumption. Concurrent subscribers share the source loader. An ongoing controller prevents consuming a fallback prematurely. Network, CORS, body and decoder failures advance to the next source; a settled loader keeps its final typeface and unused sources. Fonts requested for rendering retain one document load-event delay, released before subscriber notification. Subscribers publish their complete FontFace descriptors and own cache invalidation.

FontFaceSet loading follows the source deferred-invoke boundary, matches fonts during that deferred step, queues an owning font-loading task, and waits for the retained FontFace status Promises. Its returned Promise uses the document's existing realm and microtask adapter. Empty matches and syntax failures follow their respective source steps.

Font decoding trusts a font MIME declaration and otherwise uses font-context sniffing, including the source null result when no signature matches. Format dispatch follows `FontLoading.cpp`, including `font/x-woff`, the no-MIME decoder order, and WOFF2's MIME-or-signature preparation rule. The former CoreGraphics table reconstruction has been removed. WOFF now follows the source validation, zlib decompression, directory records and offset calculations. WOFF2 uses the source `WOFF2ByteBufferOut` interface and actual `woff2::ConvertWOFF2ToTTF`; it tolerates the upstream incorrect-declared-sfnt-size fixture. Prepared bytes are validated through the actual source Skia font-manager call and retained verbatim for V's file-backed metrics and shaping boundary.

WOFF2 preparation uses the source shared pool: four persistent `Pool/N` workers, eight-MiB stacks, a synchronized FIFO, condition signaling and the one-second idle-collection transition. The callback remains rooted in an origin-owned record while workers receive bytes and an opaque callback identity. Completion is posted to the captured native origin loop; typeface publication, fallback and document tasks run there. Native macOS delivery uses CoreFoundation's run-loop posting and wakeup ABI. Worker-idle allocator collection maps to V's `gc_collect()` entry point; upstream uses mimalloc's `ak_kmalloc_collect()`. With `-gc none`, collection follows V's disabled-collector behavior. Allocator parity is not asserted.

The browser installs one process-owned curl font transport. HTTP response bodies remain streamed; file loading remains deferred. Native initialization failure is reported and terminates startup. An unavailable installed host rejects through Fetch instead of substituting synchronous file loading. Navigation installs the final response origin before parser resource creation. CSS requests preserve typed opaque-origin identity, including the source exception permitting file-document fonts to fetch file URLs.

Response handover also preserves the default transform pull's newly created backpressure-change Promise across the standalone reaction adapter. Without that correction, a first network chunk arriving before handover stalled subsequent chunks and EOF. Buffered and live delivery now reach the owning consume-body callback.

Focused coverage includes real split-chunk HTTP and relative-file font loads; shared and settled loaders; CORS and decoder fallbacks; load-event delay release; stylesheet base/referrer/initiator handling; deferred FontFaceSet matching and owner tasks; upstream WOFF/WOFF2 valid and malformed fixtures; native Skia validation; source pool capacity; callback retention, origin-thread delivery and worker fallback. Pool, native callback and WOFF2 URL tests also run with `-gc none`.

Remaining SP-06 scope: standalone FontFace callers still retain the explicit legacy synchronous adapter. Constructor-time owning-global FontFace status-Promise identity, queued binary-data constructor phases, and compact JavaScriptCore `FontFace`/`document.fonts` bindings require further source slices. The native origin-loop and RequestServer adapters are validated on macOS; no independent non-macOS callback-loop backend is claimed. The curl adapter does not establish parity with RequestServer's separate IPC, cache and DNS process implementation.
