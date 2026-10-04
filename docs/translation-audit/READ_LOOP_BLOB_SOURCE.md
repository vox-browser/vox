# Source read-loop and Blob owner prerequisites

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`
Reviewed: 2026-10-04
Assignment 7 private workspace: `Build/audit-fixes/worktrees/07-fetch-xhr`

`ReadableStreamDefaultReader.cpp:48-106,202-233` maps to
`streams/read_loop_request.v`. Its retained ReadLoopReadRequest owns the realm,
reader, accumulated bytes and success/failure callbacks. Each valid Uint8Array
chunk appends its witness byte span, then recurses through the same actual
request. Close moves the accumulated bytes to success; errors preserve their
original value. No default-reader Promise is allocated for each aggregation
chunk. The deprecated Blob-facing wrapper allocates one relevant-realm WebIDL
Promise, resolves an ArrayBuffer on success and rejects the original failure.

`ReadableStreamOperations.cpp:1202-1241` maps to the actual request entry point.
The source FIFO can now retain both default Promise-backed read requests and
the aggregation request. Public default reads and both controller pull paths
deliver chunk/close/error steps through that interface. A release-lock
TypeError is shared across pending requests, rather than being replaced by
separate strings. This slice is commit `4777144e` with its focused tests.

`ReadableStream.cpp:439-487` maps to `streams/byte_reading_support.v`. Full
byte-reading setup installs the relevant realm, initializes the source stream,
allocates its byte controller and performs the actual start/pull/cancel setup.
Start completion belongs to the realm's microtask queue. Optional pull/cancel
algorithms forward their pending Promises and original error values; absent
algorithms resolve undefined. Source `MUST` failures remain fatal V panic
boundaries. This slice is commit `5b6f84b1` with its focused tests.

Private verification logs under this assignment's `Build/audit-fixes/`:

- `source-read-loop-default.log`: **3/3 PASS** (aggregation, default read
  Promise ownership, native byte enqueue).
- `source-read-loop-gc-none.log`: **10/10 PASS**, adding default/byte readers,
  pending pipe/tee, tee reasons, source entry points and actual native
  ReadableStream host ownership.
- `source-byte-reading-default-final.log`: final setup test **PASS** after
  the preceding default run passed its read-loop neighbor.
- `source-byte-reading-gc-none.log`: **3/3 PASS** (setup, retained read loop,
  byte-reader neighbor).

Native Uint8Array slot/witness projection is implemented separately in commit
`1dad2782`. The actual installed ReadableStream realm captures the engine brand
and typed-array getters before author code runs. Read loops use the real
Uint8Array class, buffer/offset/length and witness validity: author properties,
replaced constructors, clamped arrays, spoofs and Proxy wrappers do not
substitute for those slots. Detached or out-of-bounds genuine Uint8Arrays
produce zero bytes, preserving the source witness behavior. The native focused
file passes both GC modes in `source-native-read-loop-default.log` and
`source-native-read-loop-gc-none-final.log`; the existing native ReadableStream
host neighbor passed the preceding two-file GC-disabled run.

`ReadableStream.cpp:395-435` maps to the internal enqueue adapter in
`streams/readable.v`, commit `1a0778f6`. Byte streams call the abstract
controller operation, preserving the Source empty-chunk behavior used by Blob,
and default streams retain Source's fatal `MUST` boundary. Both abstract
operations preserve the closed-stream no-op gate. The public byte-controller
zero-length rejection remains separate. Default **2/2** and GC-disabled **3/3**
focused files pass in `source-internal-stream-enqueue-{default,gc-none}.log`.
The typed bytes carrier has no backing-store identity; the Source special case
for a chunk sharing the current BYOB view's buffer remains a native boundary
prerequisite. Blob's newly allocated chunk always takes the distinct-buffer
abstract enqueue path translated here.

`FileAPI/Blob.cpp:320-374` maps to `html/blob_operations.v`, commit `8149aa16`.
The owning settings object allocates the actual Source ReadableStream, performs
full byte-reading setup in its realm, and retains a whole-buffer copy in a
FileReading task on that Window or Worker's responsible event loop. Window
tasks retain the responsible document; Worker tasks have no Window document.
The task enters the shared callback-enabled TemporaryExecutionContext, enqueues
the Source chunk even when empty, preserves a thrown value when erroring the
stream, then closes it. `read_all_blob_bytes` obtains the actual default reader
and returns its pending relevant-realm WebIDL aggregation Promise.

The focused owner test passes default, and **4/4 GC-disabled** owner/StreamRealm/
internal-enqueue/read-loop files pass in `source-blob-owner-default-final.log`
and `source-blob-owner-gc-none-final.log`. Cases verify pending ownership before
the task, actual callback realm, copied bytes, empty chunks before close,
independent Worker delivery, cancellation and original error identity. The
shared TemporaryExecutionContext now uses Source cleanup order, commit
`c33d3317`: script cleanup checkpoints microtasks while the outer callback is
still retained, then callback cleanup pops it. The corrected owner fixture,
commit `0a437c78`, expects callback depth 2 for the nested Worker Promise job and
depth 1 for the immediate Blob read-loop steps, then verifies depths return to
zero. Owner/text/context-order **3/3** files pass in both modes in
`source-blob-context-{default,gc-none}.log`.
Native Blob/File/FileList bindings and source host-object GC remain open. The
synchronous standalone Blob accessors and compact XHR facade do not establish
these owner semantics.

`LibTextCodec/Decoder.cpp:382-405` maps to
`encoding/decode_with_bom_override.v`, commit `5c941d64`, for Blob's text decoder
prerequisite. It chooses the supplied fallback encoding unless the first BOM
selects UTF-8, UTF-16LE or UTF-16BE, then consumes that BOM before replacement
decoding. The pinned Rust implementation (`Rust/src/lib.rs:79-112`) invokes
`decode_with_bom_removal`, which removes one further BOM only for the already
selected encoding. The focused tests deliberately preserve the resulting
two-BOM removal, third-BOM retention, and opposing second-BOM behavior instead
of substituting a general second sniff. Default and GC-disabled **3/3** focused
decoder/BOM/TextDecoder files pass in `source-decoder-bom-default-final.log`
and `source-decoder-bom-gc-none.log`.

`FileAPI/Blob.cpp:377-392` maps to `html/blob_text.v`, commit `c9b91f1e`.
Each call obtains a distinct actual owning byte Promise and returns its Source
fulfillment capability. The reaction asserts an ArrayBuffer result, uses UTF-8
fallback with the pinned decoder above, and returns owned UTF-16 primitive
string units. MIME charset parameters do not select this decoder. The existing
synchronous Blob.text adapter now calls the same decoder; its synchronization
does not become the owning native Promise path. Default and GC-disabled **3/3**
Blob text/standalone decoder/codec files pass in
`source-blob-text-{default,gc-none}.log`, covering pending NewObject identity,
Worker ownership, empty and malformed bytes, UTF-16 BOMs and MIME independence.
Blob.arrayBuffer/bytes fulfillment and generated native Blob/File/FileList
methods are tracked separately below.

`LibJS/Runtime/ArrayBuffer.cpp:34-42` and `TypedArray.cpp:486-489` map to the
native buffer ABI in `browserjs/source_array_buffer_darwin.c.v` and its backing
store helper, commit `83bafcde`. The ByteBuffer overload allocates independently
owned storage and copies into it; allocation failure keeps Source's fatal
`MUST` boundary. A real engine ArrayBuffer owns that store and its deallocator.
Source Uint8 creation allocates a genuine view over the exact existing engine
buffer, preserving `view.buffer === buffer` and shared mutations. Slot reads
use the C API and intrinsic engine record allocation, so author byteLength
properties, prototype getters and replaced constructors cannot substitute for
the original slots or constructors. The focused native test passes both GC
modes in `source-native-array-buffer-{default,gc-none}.log`, including distinct
empty records. These helpers cover Source's internal fixed ByteBuffer-backed
buffers; they do not establish the still-open native author Shared/RAB paths.

Commit `3f0cf6ee` wires actual owning-realm ArrayBuffer allocation into
`ReadLoopReadRequest`'s deprecated Promise wrapper before resolution. Installed
native read loops therefore fulfill with the real engine ArrayBuffer record;
its relevant-realm data/view hooks read raw slots and construct a genuine
Uint8Array sharing exactly that buffer. The standalone typed boundary retains
its owned ArrayBuffer descriptor. Uint8Array creation has no copied-view
fallback: it requires the actual engine realm hook. Source ByteBuffer-overload
allocation failures keep their fatal boundary. Native witness tests verify
the actual fulfilled buffer/view identity, including empty detached/OOB input.
Default **2/2** and GC-disabled **4/4** native witness/allocation/native host/
core aggregation files pass in `source-read-loop-array-buffer-default-final.log`
and `source-read-loop-array-buffer-gc-none.log`. The native compilation also
covers the module-relative header correction `de70507b`.

Commit `0e7cfafb` carries that explicit actual relevant engine realm through
Blob get-stream/read-all/text. The stream, default reader and Promise retain
its allocation/data hooks and the owning HTML settings' task/job queue. Native
Promise fulfillment delivers exactly the allocated engine ArrayBuffer, and
text reads its actual slots instead of a projected byte descriptor or author
properties. Native tests exercise a real Source stream/Uint8 read chunk and
BOM-aware text with poisoned ArrayBuffer byteLength getters and constructor.
The final native default file passes after the preceding run passed both HTML
owner/text neighbors; GC-disabled **3/3** native realm/HTML owner/text files pass
in `source-blob-native-realm-default-final.log` and
`source-blob-native-realm-gc-none.log`. Public native Blob constructors and
clone projection remain separate work.

`FileAPI/Blob.cpp:395-406` maps to `html/blob_array_buffer.v`, commit
`696005ac`. Its Source fulfillment reaction asserts the read-all ArrayBuffer,
copies its complete raw data into a second independently owned relevant-realm
ArrayBuffer, and retains Source's fatal `MUST` allocation boundary. The native
test verifies actual engine record identity and independent mutation of the
returned buffer, original read-all buffer and immutable Blob bytes. The focused
file passes both GC modes in `source-blob-array-buffer-{default,gc-none}.log`.
This owning algorithm does not install a native public Blob method by itself.
