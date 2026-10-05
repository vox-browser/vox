# Changed script media src reaches the cached DOM media owner

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
HTMLMediaElement.cpp loads when a src attribute is set or changed, and does
not load merely because src is removed. The compact script bridge replayed
the DOM attribute but left an already-materialized media model's source stale.
The actual page MediaSource fixture remained closed after an explicit load,
even after its Page-backed retry proved the Document fully active.

Changed audio/video src replay now updates that actual model and invokes its
existing automatic load algorithm. Removal clears the cached source without
automatically detaching; a later explicit load therefore sees the removal.
An isolated baseline retaining the exact prior replay function reproduces
the empty currentSrc for both audio and video. Its first setup omitted the
actual navigation helper and failed only at compilation; the corrected
baseline includes that unchanged helper and executes both failures.
The focused tests materialize each model before mutation, create genuine
MediaSource store objects with actual document settings, and exercise source
replacement, original-source detachment, removal and later explicit load.
A separate native page test constructs its source and URL in author JavaScript
and reaches this same resource-selection caller through live attribute replay.

This is the compact changed-attribute replay boundary. It does not establish
native HTMLMediaElement.load/srcObject exposure or the complete DOM virtual
attribute hook. Existing generic snapshot replay suppresses identical attribute
values; preserving explicit repeated same-value setter calls remains separate.
No arbitrary origin or source ID is fabricated.

Focused feature: `6d23dae1`, implementation and both audio/video cases together.
The corrected fixture passes default GC and GC-none on the unchanged final
snapshot. Its initial Result/Option compiler diagnostic has zero test runtime
and is retained in [Native MediaSource evidence](NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md).
No new production or screenshot proof is claimed. The audit remains
**32 fixed / 25 partial / 9 open**.
