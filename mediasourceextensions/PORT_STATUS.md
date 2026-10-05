# MediaSourceExtensions translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/MediaSourceExtensions`.
Canonical workspace: `~/code/vox2/mediasourceextensions`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

| Upstream implementation unit | V implementation |
| --- | --- |
| `BufferedChangeEvent.cpp` | `buffered_change_event.v` |
| `EventNames.cpp` | `event_names.v` |
| `ISOBMFFByteStreamParser.cpp` | `isobmff_byte_stream_parser.v`; parser records in `byte_stream_parser.v` |
| `ManagedMediaSource.cpp` | `managed_media_source.v` |
| `ManagedSourceBuffer.cpp` | `source_buffers.v` |
| `MediaSource.cpp` | `media_source.v` |
| `MediaSourceHandle.cpp` | `media_source.v` |
| `SourceBuffer.cpp` | `source_buffers.v`; coded-frame path in `source_buffer_processor.v` |
| `SourceBufferList.cpp` | `source_buffers.v` |
| `SourceBufferProcessor.cpp` | `source_buffer_processor.v` |
| `TrackBuffer.cpp` | `track_buffer.v` |
| `TrackBufferDemuxer.cpp` | `track_buffer.v` |
| `WebMByteStreamParser.cpp` | `webm_byte_stream_parser.v` |

The pinned source has 13 physical `.cpp` units and 4,094 lines. The current
module has 4,071 implementation V lines and 1,885 test V lines. These counts
and file mappings describe inventory, not behavioral parity. The previous
August inventory and its “complete” label no longer describe this source.
Browser/root integration is outside these module totals.

The typed records cover MediaSource state, duration, SourceBuffer lists and
mutation, queued events, attachment/detachment, byte-stream parsers, track
buffers and coded-frame processing. These are implemented algorithms, with
focused tests; they are not evidence that every codec, demuxer, playback,
error path or upstream behavior is complete. Actual document media callers
now authorize copied Blob URL entries against current node-document settings
before resolving the live MediaSource. [Actual attachment evidence](../docs/translation-audit/BLOB_URL_MEDIA_ACTUAL_DOCUMENT.md)
records that owner boundary independently of public JavaScript exposure.

Native Window scripts now construct real MediaSource records and pass them to
`URL.createObjectURL`. The native wrapper retains the actual relevant Window
and EventTarget identity, exposes readyState, duration, source event handlers,
endOfStream, isTypeSupported and the dedicated-worker flag, and observes the
same V state used by the media attachment algorithm. Queued source events now
retain the original object pointer instead of copying a mutable receiver;
changed script audio/video src attributes reach the cached media owner.
[Native object-URL evidence](../docs/translation-audit/NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md)
records its focused checks and actual page caller.

Native SourceBuffer/SourceBufferList wrappers and addSourceBuffer exposure,
DedicatedWorker startup, foreign realm/world wrappers, physical GC edges and
IPC remain separate. The worker capability flag is false, as in the pinned
Source; exposing that flag does not establish a worker runtime. Source event
clock integration and complete decoder/playback behavior remain separate.
Upstream IDL FIXMEs for handle, removeSourceBuffer, seekable-range mutation and
ManagedMediaSource streaming are distinct from these translation boundaries.
BufferedChangeEvent range getters likewise remain upstream FIXMEs.

[Frozen e385ac31 production verification](../docs/translation-audit/FROZEN_E385AC31_NATIVE_URL_MEDIA.md)
now covers this wrapper through an actual local-file page and queued native
events, with a pixel-exact viewport and explicit zero-tolerance comparison.
The same bundle passes signature/startup checks and standard smoke screenshots;
the first targeted animation capture fails and a complete nine-case retry is
pixel-exact. No current whole-module sweep is claimed here.
