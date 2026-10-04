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
| `FileReader.cpp` | `file_reader.v`, `file_reader_global_context.v`, `file_reader_stream_operation.v`, `../html/file_reader_operations.v` |
| `FileReaderSync.cpp` | `file_reader.v`, `../browserjs/file_reader_sync_array_buffer_darwin.c.v` |

The existing typed package covers immutable owned Blob bytes, blob parts and
line endings, MIME normalization, slicing, byte streams, BOM-aware decoding, File
state, FileList ordering, blob URL partition checks and environment cleanup,
and reader state transitions. Standalone FileReader read generations protect
its compatibility abort/replacement adapter at loadstart and progress. Actual
Window/Worker readers preserve Source's shared abort Boolean instead. This inventory does not
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
public browser installation and File/FileList native bindings remain open.
Native Blob clone projection/exposure now uses actual source/target records,
the exact primary codec and retained target factory; its focused file passes
both modes. The compact XHR Blob object is
a separate compatibility facade. FileReader owner tasks, blob URL process
ownership and complete generated bindings still need runtime validation.


The File byte-name compatibility boundary now uses the explicit Source
`Utf16String::from_utf8_without_validation` adapter instead of V's scalar
string iterator. This maps the `File.h` line 23 String-name overload before the
actual UTF16 core constructor. Direct raw names/types and parts-based File
construction retain lone surrogates, null and supplementary pairs; malformed
input follows the pinned AK iterator's exact replacement and advance rules.
The focused new File boundary, existing raw File records, actual DataTransfer
producers and neighbors pass **5/5** both modes in
`source-data-transfer-fileapi-{default,gc-none}.log`. Native actual-header
-O0/-O2 decoder evidence is in `tools/source_drag_wtf8_probe.py` and the audit
source mapping. This does not broaden the generic LibJS scalar string adapter.

FileReader's typed Text packaging now applies Source's given-decoder BOM
override after explicit-label/MIME/default selection. Focused packaging,
existing reader and decoder files pass **3/3 in both GC modes**. Pinned repeated
BOM behavior, source mapping and actual FileReader owner boundaries are recorded in
[`FILEREADER_TEXT_SOURCE.md`](../docs/translation-audit/FILEREADER_TEXT_SOURCE.md).

The bounded native FileReaderSync ArrayBuffer body now copies through its
actual implementation and allocates a genuine fresh ArrayBuffer in the supplied
Runtime's actual target Realm. Identity, mutation, empty, two-Realm and poisoned
author alias/constructor checks pass **2/2 focused files in both GC modes**.
DedicatedWorker/SharedWorker public receiver/constructor exposure remains open;
no Window interface is installed.

BinaryString and Text results now retain their actual immutable Source UTF16
records through clone/set/access, including raw lone units and storage form.
Text uses Source's actual String-to-UTF16 constructor path. Stale compatibility
DTOs, loading/abort/null/bytes and the unresolved unchecked-ASCII DataURL arm
do not expose a raw record. New result/BinaryString/Text BOM/actual owner
files pass **4/4 in both GC modes**. LibJS implementation and its frozen full
suite/corpus proof are unchanged; native primitive/world-cache work remains open.
The separate internal replacement decoder now preserves Source's empty-input,
single-U+FFFD and Unicode-BOM override behavior for FileReader labels, while
public TextDecoder retains its required rejection. **5/5** focused files pass
in both GC modes; actual Source Rust bridge probes pass **2/2** debug and release.

The separate FileReader global context now retains actual creation Window/Worker
settings, relevant agent/Realm and EventTarget. Its FileReading tasks capture
the associated Document at queue time, track actual TaskIDs through callback
return/abort, and create trusted events using the actual global-relative clock.
Actual owner/standalone reader/owning Blob files pass **3/3 in both GC modes**.
This owner prerequisite was committed before the Source read-operation body
below. Native FileReader wrappers and its per-world result cache remain open.

BinaryString packaging now follows Source's byte-to-UTF16-code-unit builder
through the existing owned Source string record, replacing the independent
UTF8 byte encoder. Every byte 0–255, embedded NULs, verbatim BOM bytes, storage
and synchronous packaging pass **2/2 focused files in both GC modes**. Native
result wrappers/caching remain separate.

DataURL packaging now follows Source's genuine `url.create_with_data` opaque
record, existing URL serializer and Infra compatibility projection instead of
constructing the final URL directly. Literal supplied MIME and raw serialized
WTF8/non-ASCII/NUL compatibility bytes remain unchanged. The Source unchecked
ASCII string metadata/native primitive boundary remains open. Focused DataURL,
existing reader and genuine URL helper files pass **3/3 in both GC modes**.

The FileReader owner context now also retains the actual creation StreamRealm,
existing settings-owned Blob stream supplier and Source temporary execution
context runner. Its realm identity is checked against the actual settings;
explicit native allocation/data hooks can be retained without changing owner
task/microtask routing. This separate prerequisite does not yet replace the
asynchronous compatibility body or supply native read-result wrappers.

Actual Window/Worker readers now use Source `ReadOperationState` with a real
Blob stream/default reader, per-chunk retained WebIDL Promise reactions, empty
byte accumulation, first-chunk flag and monotonic progress timer. The initial
setup task is untracked; loadstart/progress/completion/error tasks use the
reader's actual affiliated TaskIDs. Abort preserves Source's shared Boolean
and task-removal semantics. Completion and rejection retain Source's two error
setter FIXMEs and reentrant loadend suppression. The old manual pending-byte
path is limited to standalone compatibility construction. Streams' typed
result-object/Uint8Array projection, genuine native witnesses and FileReader
result wrappers remain separate runtime boundaries.

New read-operation, existing owner-task, monotonic-threshold and standalone
reader files pass **4/4 in both GC modes**, including all package types, empty
chunks, immutable Blob snapshot, actual InvalidStateError record, Worker
ownership, early/late abort, reentrant loadend and the pinned shared-abort flag
edge. Source mappings and explicit native boundaries are in
[`FILEREADER_TEXT_SOURCE.md`](../docs/translation-audit/FILEREADER_TEXT_SOURCE.md).
