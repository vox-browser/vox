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

`FileAPI/Blob.cpp:409-419` maps to `html/blob_bytes.v`. The Source fulfillment
reaction constructs a genuine relevant-realm Uint8Array over the exact
read-all ArrayBuffer; it performs no second buffer allocation or copy. This
path requires the actual engine Realm hook, which asserts the ArrayBuffer
class and uses the engine intrinsic view allocator. The focused native test
verifies one buffer allocation, exact `.buffer` identity, shared mutation,
immutable Blob bytes and distinct empty NewObject results even after author
constructor/getter replacement. It passes both GC modes in
`source-blob-bytes-default-final.log` and `source-blob-bytes-gc-none.log`.
Native public Blob/File/FileList methods and complete byte-controller backing
identity remain separate work.

The native `BlobHost` prerequisite maps `Blob.h`'s immutable size/type slots,
`Blob.cpp:238-317` slice/stream and the owning text/arrayBuffer/bytes methods to
genuine wrappers in `browserjs/blob_host*.v`. Wrapper identity is keyed by the
actual V Blob record and retains its owning HTML settings and original
prototype. Type getters return arbitrary raw UTF-16 units; slice arguments use
the Source optional Clamp conversions. Read methods use the actual owner task,
reader and Promise paths above. Promise-returning receiver failures reject
with the real engine exception; stream and ordinary getters throw. The focused
file passes both GC modes in `source-blob-host-{default,gc-none}.log`, covering
actual record/cached wrapper identity, raw type, pending NewObject methods,
genuine stream chunks, slice and forged receiver rejection. The existing XHR
object cannot enter the genuine Blob wrapper table. This prerequisite retains
an internal Source prototype; the public generated constructor and native
clone exposure are separate subsequent slices, with no placeholder constructor.

The follow-up prototype metadata fix uses actual accessor/method descriptor
extraction instead of ordinary constructible functions. Its focused checks
cover `get size`/`get type`, every method's Source name and zero IDL arity,
absence of own `prototype`, failed construction, getter/method descriptor
flags and the Blob tag flags. Metadata plus constructor files pass **2/2** in
both GC modes in `source-blob-metadata-constructor-{default,gc-none}.log`.

`browserjs/blob_constructor_darwin.c.v` translates the pinned Python binding
generator's Blob constructor/argument/sequence/union/dictionary conversions
and calls the existing Source Blob body. The fresh generator was run against
the pinned IDL inputs into the V workspace's ignored
`Build/audit-fixes/blob-source-bindings/{Blob,File,FileList}.cpp` reference
files; older upstream Build constructor outputs use stale String/realm APIs.
The constructor reads `newTarget.prototype` once before conversions, preserves
actual Blob/BufferSource union records, converts other parts to well-formed
USVString, and copies buffer data only after the endings/type option getters.
This retains option mutations and detachment. Shared/resizable concrete view
restrictions follow the generator, and raw SharedArrayBuffer uses the pinned
union's USVString fallback. The direct sequence loop retains original thrown
values and the source absence of IteratorClose on conversion failure.

The native constructor uses a captured construct hook to avoid an ordinary JS
function's extra implicit prototype lookup. It preserves Source constructor,
global and prototype descriptor flags, name/zero IDL arity and the exact
called-without-new error. Invalid EndingType messages retain original raw
UTF-16 units. The focused constructor file passes both modes in
`source-blob-constructor-{default,gc-none}-final.log`, including default/null
handling, copied parts, string conversion, mutations, detachment, raw error
units, Proxy/iterator/property error identity and derived prototypes.
Same-runtime primitive-prototype fallback uses the actual original prototype;
foreign `newTarget` fallback via Source GetFunctionRealm remains open because
this engine ABI does not expose the owning function realm. Native Worker
ReadableStream host construction and public browser installation are separate
work. The compact XHR facade remains outside this actual Blob owner table.

The native Blob clone projection maps Source StructuredSerialize.cpp step 19
(`1510-1527`) and target exposure/allocation (`2030-2044`) to the actual
BlobHost wrapper table and immutable Blob payload record. IPC and storage use
the exact existing primary Blob codec, including arbitrary raw UTF-16 type
units. Deserialization requires the target's actual installed constructor and
original prototype, independent of author globals; insecure Window exposure is
valid for Blob. Output aliases share one newly deserialized target wrapper and
record. Author-own Blob getters and custom properties are not read or copied.
The focused file passes both modes in
`source-native-blob-clone-{default,gc-none}.log`, comparing native payload bytes
with the primary Source codec and checking raw units, aliases, distinct Source
records, forged absent exposure and deleted target globals. XHR compatibility
objects remain outside the actual Blob owner table. File/FileList native
projection and public browser installation remain separate work.

The follow-up constructor exposure fix passes
`JSContextGetGlobalObject(runtime.context)` into the installer explicitly.
It defines Blob on that actual owning global instead of trusting the
author-visible `globalThis` alias, matching Source exposed-interface setup.
The focused fixture replaces `globalThis` with a throwing Proxy before
installation and verifies the actual global's constructor/descriptor and
Source construction. It passes both modes in
`source-blob-global-{default,gc-none}.log`.

The browser startup installs the actual relevant-realm Blob owner and generated
constructor after its ReadableStream prerequisites and before document scripts.
`main_blob_test.v` uses `run_document_script_sources` to construct a Blob from a
string and a genuine Uint8Array, observes three distinct pending Promise reads,
runs exactly three FileReading tasks owned by the actual document, and verifies
text, genuine bytes/ArrayBuffer objects and live DOM replay. The arrayBuffer
copy is independent of the bytes view's backing buffer. The fixture closes its
Runtime before finalizing the actual document, and both GC modes pass in
`source-main-blob-{default,gc-none}.log`. Native bundle/capture verification is
performed separately by the canonical integration owner. Native Worker
ReadableStream construction and the XHR response facade replacement remain
separate work at this checkpoint.

The subsequent XHR native Blob bridge replaces the frozen response facade with
the actual immutable record created and cached by `XMLHttpRequest::response()`
(`XMLHttpRequest.cpp:269-294`). Blob bytes, size, type and read results no longer
cross the JSON carrier, and the Blob pointer/key lookup map and synchronous
Promise.resolve read facade are removed. The response uses the actual BlobHost
wrapper and original prototype; repeated reads retain that wrapper identity.
Source Blob methods, FileReading tasks and dynamic primary clone payloads now
apply to these actual XHR-produced records too.

`send()` recognizes that same actual Blob owner table before reading any
author-visible metadata and delegates to the existing typed `send_blob` body.
It retains immutable bytes, the Blob Content-Type, author header overrides,
empty type and GET/HEAD body suppression. Forged `__xhrBlobKey` properties do
not establish Blob identity. The existing typed request transport still uses
its byte-body carrier; full `Fetch/BodyInit.cpp` Blob stream/source ownership is
a separate core translation boundary.

The real Curl response fixture checks actual cached record identity, metadata,
three pending genuine read Promises and owning tasks, direct clone payloads,
poisoned own getters and re-sending the received Blob after `open()` resets the
XHR cache. The body fixture checks genuine constructor-produced Blobs, captured
native operation ownership, forged ordinary values and body/header semantics.
The new file plus existing XHR host regressions pass **2/2** in both modes in
`source-xhr-native-blob-{default,gc-none}.log`; the final extended focused file
passes both modes in `source-xhr-native-blob-{default,gc-none}-final.log`.
Native Worker ownership, File/FileList native wrappers and the remaining typed
BodyInit source carrier remain explicit open work.

The File owner prerequisite follows `File.h`'s `File : Blob` and the pinned
generator's `FileWrapper : BlobWrapper`: it registers the actual File together
with its exact embedded Blob base under one wrapper. Inherited Blob methods
therefore use the same immutable byte/type record and owning relevant realm.
The actual File prototype inherits the retained actual Blob prototype and has
Source DOMString name and signed lastModified getters plus the File tag.
Getters retain raw UTF-16 name units and exact native accessor names, zero
arity, nonconstructibility and descriptor flags. Author-created carriers do
not establish File identity.

`source-native-file-owner-{default,gc-none}.log` passes in both modes. Its
focused fixtures check original File/base Blob pointer and wrapper identity,
raw lone surrogate/nul name/type, direct negative timestamp slots, native
getter metadata and rejection of a Blob receiver. Blob construction and
slice read the actual File base without invoking poisoned own properties;
slice creates a Blob, while inherited bytes retains a genuine Uint8Array
Promise result and the actual document's FileReading task. This prerequisite
does not expose a public File constructor. Generated construction, File-before-
Blob dynamic clone classification and browser startup follow separately.

The generated File constructor now converts required sequence parts, then its
USVString filename, then inherited BlobPropertyBag endings/type and derived
optional signed lastModified. Source File::create copies retained buffer parts
after these conversions, preserving filename/option mutation and detachment.
It uses the existing Source MIME/basic-Latin body and actual clock default,
without reading author Date.now. Its constructor/prototype/global descriptor
flags, name/arity two, original Blob constructor inheritance, called-without-
new and required-argument diagnostics follow the fresh pinned generator.
The actual owning global is passed explicitly. Single newTarget.prototype Get
precedes conversion; same-runtime fallback is retained, while foreign
GetFunctionRealm fallback remains explicitly open as for Blob.

Constructor plus owner fixtures pass **2/2** both modes in
`source-native-file-constructor-{default,gc-none}.log`. The final extended
constructor fixture passes both modes in
`source-native-file-constructor-{default,gc-none}-final.log`, including original
Proxy/iterator/name/dictionary/numeric thrown values, absent/null options,
actual object metadata, buffer copy timing and raw malformed EndingType units.
The pinned no-EnforceRange/no-Clamp LongLong helper's small-negative behavior
is confirmed by `tools/source_webidl_int64_probe.py`: it copies the exact
numeric steps 8–12, integer_part and floating JS::modulo and uses actual AK
types/bounds plus a native signed return cast. Both clang -O0 and -O2 produce
-7 to 0 and -4096 to -4096 (`source-webidl-int64-native-probe.log`), while
direct raw File timestamp slots retain negative values independently.

The exact ±2^63 numeric boundary is a separate Source limitation: its rounded
double comparison permits an out-of-range signed cast. A supplementary native
probe gives different results with -O0/-O2, so compiler-dependent behavior at
that boundary is not claimed as parity with V's defined conversion. Actual
File clone projection, main browser File exposure and native Worker/FileList
ownership remain separate work.

The native clone projection now discriminates genuine File before its genuine
Blob base, matching Source primary SerializablePlatformObject identity and
File's virtual serialization override. It passes the actual File to the
existing exact primary IPC/storage codec. Target reconstruction requires the
actual installed File interface and uses its retained prototype/owner, without
reading the author-visible File global. Raw UTF-16 type/name and signed raw
timestamp fields survive, output aliases share one newly deserialized File,
and the wrapper's inherited Blob owner aliases that same embedded base.

File plus Blob clone fixtures pass **2/2** in both modes in
`source-native-file-clone-{default,gc-none}.log`. They compare native wire bytes
with the primary Source encoder, preserve raw lone/nul units and negative raw
time, ignore throwing author fields and changed prototypes, and verify that a
genuine Blob with File.prototype remains a Blob. An ordinary author object
with File.prototype remains ordinary. Forged absent File exposure rejects,
while deleted target globals and insecure Window exposure retain the actual
installed factory. Public main startup and FileList/native Worker ownership
remain separate work.

The following main startup feature installs the actual File owner and generated
constructor after their actual Blob prerequisites, before document scripts.
`main_file_test.v` calls `run_document_script_sources` with genuine File parts,
USVString name and options; it checks actual File/Blob base pointer identity,
native primary File cloning, three pending read Promises and precisely three
owning-document FileReading tasks. Genuine Uint8Array and independent copied
ArrayBuffer results reach the live document through the real browser task
poll/replay. Main File plus Blob startup fixtures pass **2/2** both modes in
`source-main-file-{default,gc-none}.log`. The fixture closes the actual Runtime
before document finalization. Canonical native bundle/capture verification is
root-owned; FileList/native Worker and the previously recorded Source limits
remain open.

### Actual FileList owner and live indexed properties

`FileListHost` now retains the genuine ordered `FileAPI::FileList` and uses the
same relevant-realm File owner for each indexed value. The fresh pinned Python
generator's `FileListWrapper`, `FileListPrototype::length_getter` and `item`
map directly to the native owner, generated getter/method metadata and existing
WebIDL unsigned-long conversion. Indexed-key classification reuses the existing
LibJS `PropertyName.from_utf16` translation, preserving the actual raw key.

The captured native Proxy implements precisely FileList's indexed-only branches
of Source `Bindings/PlatformObject.cpp`: get-own-property at line 171, set at
321, define at 360, delete at 429, prevent-extensions at 508 and own-keys at 526.
Its hidden engine target retains ordinary properties and prototype behavior;
the Proxy obtains every indexed File from the live actual owner. There is no
snapshot of the indexed values. Supported indices have read-only, enumerable,
configurable descriptors; all index definitions fail without an IDL setter,
supported index deletion fails, and prevent-extensions always fails. Ordinary
receiver/prototype handling remains with the engine's captured Reflect methods.
The iterator is the original realm's actual `Array.prototype.values` function.

The owner fixture passes **1/1** both modes in
`source-native-file-list-owner-{default,gc-none}.log`. It exercises live append
through an already-created iterator, exact File identity, native metadata and
descriptor flags, chronological strings followed by symbols, strict assignment,
unsupported indices and prototype setters, derived receivers, freeze failure,
original numeric-conversion exceptions, receiver branding before conversion,
and poisoned author intrinsics. No public FileList interface constructor is
installed by this prerequisite. Its exact throwing interface constructor,
native primary clone projection, actual DOM producer exposure and Worker startup
remain separate work. Importing the older `bindings` package also exposed its
existing non-exhaustive DOM-runtime-value matches; this slice avoids that
unrelated package and does not claim to fix those older matches.

The separate generated FileList interface constructor now follows fresh
`FileListConstructor::initialize/construct` and
`Bindings/InterfaceObject.cpp::InterfaceConstructor::call` (lines 61–70).
It has the Source name/arity/descriptors and is a genuine constructible
interface object: calling it without new throws the Source constructor-without-
new error, while its own construction always throws `FileList is not a
constructor`. The latter performs no `newTarget.prototype` read or argument
conversion. Existing actual FileLists acquire this retained interface's
prototype without author construction. Installation targets the actual engine
global, even when the author-visible globalThis alias is poisoned.

Constructor plus owner fixtures pass **2/2** both modes in
`source-native-file-list-constructor-{default,gc-none}.log`, including exact
interface/prototype/global flags, own keys, call/new errors, subclass failure,
Proxy newTarget getter suppression, use as a valid newTarget for another
constructor, repeated installation, and forged global independence. Actual DOM
FileList producers, native clone projection and main/Worker startup remain open.
