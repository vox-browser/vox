# MediaSourceExtensions module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/MediaSourceExtensions`

Translation workspace: `~/code/libweb_v/mediasourceextensions`
Audited: 2026-08-16

All eight upstream `.cpp` implementation units have audited V mappings. Their
headers and IDL are represented by concrete event/event-target types, enum
conversion, constructors, and opaque platform boundaries.

| Upstream implementation unit | V implementation |
| --- | --- |
| `BufferedChangeEvent.cpp` | `buffered_change_event.v` |
| `EventNames.cpp` | `event_names.v` |
| `ManagedMediaSource.cpp` | `managed_media_source.v` |
| `ManagedSourceBuffer.cpp` | `source_buffers.v` |
| `MediaSource.cpp` | `media_source.v` |
| `MediaSourceHandle.cpp` | `media_source.v` |
| `SourceBuffer.cpp` | `source_buffers.v` |
| `SourceBufferList.cpp` | `source_buffers.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `MediaSourceExtensions/` | 8 | 413 | 357 | 110 | Complete |

The port covers all 13 event names, the three WebIDL enum families,
constructible MediaSource and ManagedMediaSource objects, the dedicated-worker
flag, MIME parsing for `isTypeSupported`, all implemented event-handler
attributes with real DOM dispatch, BufferedChangeEvent identity/base init, and
the transferable opaque MediaSourceHandle boundary. Operations and attributes
marked FIXME in upstream IDL—including buffer mutation, lists, ranges, ready
state, duration, and streaming—remain unavailable rather than receiving
invented behavior. BufferedChangeEvent's range getters are likewise upstream
FIXMEs; its current constructor only initializes the Event base, which this
translation preserves.

## Verification

```text
$ /Users/alex/code/v/v test mediasourceextensions
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify mediasourceextensions dom/ui_events.v
(no output; exit status 0)
```
