# FileAPI translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/FileAPI`
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`
Translation workspace: `~/code/vox2/fileapi`
Source records and clone payloads reviewed: 2026-10-04

| Upstream source | V mapping |
| --- | --- |
| `Blob.cpp` | `blob.v`, `utf16_records.v`, `../html/blob_operations.v`, `../html/structured_fileapi_codec.v` |
| `BlobURLStore.cpp` | `blob_url_store.v` |
| `File.cpp` | `file.v`, `utf16_records.v`, `../html/structured_fileapi_codec.v` |
| `FileList.cpp` | `filelist.v`, `../html/structured_fileapi_codec.v` |
| `FileReader.cpp` | `file_reader.v` |
| `FileReaderSync.cpp` | `file_reader.v` |

The existing typed package covers immutable owned Blob bytes, blob parts and
line endings, MIME normalization, slicing, byte streams, BOM-aware decoding, File
state, FileList ordering, blob URL partition checks and environment cleanup,
and reader state transitions. FileReader read generations protect event-driven
abort/replacement at both loadstart and progress. This inventory does not
establish full source runtime or generated WebIDL binding parity.

Blob/File public constructor MIME parsing now retains the source basic-Latin
gate, including non-ASCII quoted parameters, tab and DEL rejection. Internal
ByteBuffer/Utf16String constructors and deserialization preserve arbitrary raw
UTF-16 type/name units, immutable storage flags and independently owned bytes.
Compatibility serialization DTO updates check stale raw metadata before reuse.

HTML IPC/LBSC serialization now implements the exact primary Blob/File/FileList
payloads. Blob writes type then ByteBuffer; File also writes name and signed i64
lastModified. The FileList nested path writes each complete File payload with
its tag/interface/storage version, bypassing general inner object memory and
inner File exposure exactly as pinned upstream. Repeated nested Files therefore
become distinct records. Ordinary outer alias memory and interface exposure
remain intact. SnapshotState retains the source FIXME.

The constructor gate passes three files in both GC modes; raw ownership passes
its final focused file in both modes with Blob/File/FileList neighbors passing
in the preceding runs. Exact IPC/LBSC payload goldens, raw lone UTF-16,
truncation, nested aliases/exposure/version checks and all signed i64 edges pass
the default focused codec test and **5/5 GC-disabled** codec/Blob/File/FileList/
Crypto neighbors. Private logs are under assignment 7's `Build/audit-fixes/`:
`source-fileapi-type-gate-{default,gc-none}.log`,
`source-fileapi-utf16-{default,gc-none}-final.log`, and
`source-fileapi-codec-{default,gc-none}.log`.

Blob's owning HTML path now queues an actual Window/Worker FileReading task
and returns relevant-realm Source ReadableStream/default-reader/WebIDL Promise
records. The retained aggregation request stays pending before delivery,
includes the Source empty chunk, and preserves original error values. Default
focused and **4/4 GC-disabled** owner/StreamRealm/enqueue/read-loop files pass;
source mappings and logs are recorded in
[`READ_LOOP_BLOB_SOURCE.md`](../docs/translation-audit/READ_LOOP_BLOB_SOURCE.md).
Blob.text now returns the Source fulfillment of that owning byte Promise and
uses UTF-8 fallback with the exact pinned BOM override, ignoring MIME charset.
Its Source primitive-string result preserves owned UTF-16 units. The existing
standalone text adapter uses the same decoder; default and GC-disabled **3/3**
focused text/decoder files pass. Owning Blob.arrayBuffer fulfillment copies the
actual read-all buffer into a second independently owned relevant-realm buffer;
its focused native identity/mutation file passes both GC modes. Owning
Blob.bytes fulfillment constructs a genuine Uint8Array over exactly the
read-all buffer without a second buffer allocation; its native identity,
mutation and empty NewObject file passes both GC modes. The standalone
text/array_buffer/bytes facade settles synchronously;
it does not establish the source task/Promise owner path. A genuine native Blob record host
now binds raw getters, slice and owning stream/text/arrayBuffer/bytes methods;
its focused owner/identity/receiver file passes both GC modes. Its public
generated constructor now preserves original records, sequence/USVString and
dictionary conversion order, post-option buffer copies, Source descriptor
flags and original error values. The focused constructor file passes both
modes. Foreign-newTarget prototype fallback, native Worker stream ownership,
public browser installation, native clone projection and File/FileList native
bindings remain open. The compact XHR Blob object is
a separate compatibility facade. FileReader owner tasks, blob URL process
ownership and complete generated bindings still need runtime validation.
