# Structured-clone source codec and native boundary

Source: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/StructuredSerialize.{cpp,h}`, `StructuredSerializeTypes.h`,
`LibIPC/Encoder.cpp`, and `LibCrypto/BigInt/SignedBigInteger.cpp`.

The earlier V codec round-tripped its own records but differed from the pinned
source format. A native clone bridge must use the source serialization pipeline;
pairing an alternate encoder and decoder does not establish source parity.

Completed source slices:

| Source contract | Translation and evidence |
| --- | --- |
| Stable tags | Shared/growable/resizable buffers retain tags 19–23; SerializableObject, Int32Primitive and EndObject retain 24, 25 and 255. |
| Int32 primitive | Actual translated LibJS Value normalization selects Int32; negative zero remains Double. Signed bits use the source IPC integer payload. |
| UTF-16 primitive/boxed String | IPC encodes the ASCII-storage flag, u32 code-unit count and ASCII bytes or little-endian UTF-16 units. Source primitive records retain actual UTF-16 units, including lone surrogates. |
| BigInt primitive/boxed BigInt | The actual arbitrary `libjs.BigInt` record encodes the source signed-magnitude buffer: sign byte then big-endian magnitude. It is never rounded or narrowed through Number/i64. |
| UTF-16 storage metadata | `from_ipc_stream` preserves a false ASCII flag even for long all-ASCII units. Ordinary `from_utf16` construction compresses all-ASCII units, including long strings. Decoded records preserve the original storage flag on reserialization. |
| Collections and properties | Map/Set counts and Array length use source u64 fields. Object/Array properties serialize each value before its UTF-16 key and finish with EndObject. Sparse arrays retain their length without allocating missing elements; aliases, cycles, and the special null-prototype ObjectReference branch survive decoding. |
| Buffers and views | Resizable/growable capacity uses u64. ByteLength uses a true-is-auto boolean followed by a fixed u32 length when present. DataView omits ArrayLength. Nested buffers claim their memory id before their view, and source brand, alignment, slot consistency and bounds checks reject malformed records. |
| Error payloads | IPC retains pinned native type order, including InternalError. Optional message/cause preserve UTF-16 units and storage flags, and distinguish an absent message from a present empty string. RegExp source/flags also retain their original UTF-16 payloads. |
| LBSC storage | The source magic/version/flags envelope, unsigned and signed LEB128 integer codecs, little-endian doubles, length-and-storage-bit string headers, byte buffers, and stable Error names now form a distinct Storage record. Invalid headers, integer overflow, truncation and trailing bytes reject. Storage decoding constructs UTF-16 with `from_utf16`, including ASCII compression, whereas IPC decoding preserves its encoded storage form. |

Focused tag/Int32 and codec/resizable neighbors passed three files with GC
disabled. The source IPC primitive goldens and those two neighbors passed
another three files after the UTF-16 correction. The surrogate regression
initially exposed V string decoding that discarded lone surrogates; retaining
the source UTF-16 record fixes that boundary without treating diagnostic text
as the original JavaScript string.
The explicit storage flag and construction correction passed two focused files.
Collection source goldens plus codec/resizable neighbors passed three files
with GC disabled. The complete LibJS suite passed 229 files in each GC mode,
and the exact AST corpus passed all 100 fixtures without case overrides.
Buffer/view source goldens and three neighbors passed four files with GC
disabled. Error/RegExp payload goldens and two neighbors passed three files.
Storage goldens and three neighbors passed four files; the expanded Storage
case also passed after adding arbitrary BigInts, collection goldens and cycles.

The older strict standalone `structured_deserialize` convenience retains its
full-consumption check. `structured_deserialize_ipc` exposes the source IPC
entrypoint without that check; Storage always requires full consumption.
The common-family DTO codec is source-derived, but actual RegExp construction
and validation, source platform SerializableObject registries/payload versions,
and transferable records remain separate work. The shared DTO tags IPC and
Storage explicitly instead of confusing their distinct source record types.

The source PrimitiveString cache uses the actual pointer-size-minus-one inline
ASCII limit and storage form, with the single-ASCII cache preceding that check.
The earlier 16-code-unit threshold was not in the source. Boundary tests and
the storage neighbor passed two files with GC disabled.
After the actual inline-cache correction, the complete LibJS suite passed
229 files with each GC mode, and the AST corpus passed all 100 exact fixtures.

The native string prerequisite reads the actual JSC UTF-16 span and recreates
an actual engine string from code units. Its source IPC round-trip test preserves
lone surrogates, embedded NUL and surrogate pairs. Non-string values are rejected
before author ToString, and a closed Runtime is rejected before C calls. The
native string and Storage tests passed two files with GC disabled.

The native projection foundation now uses actual primitive, boxed, ordinary
object, Array, Map and Set values. It captures engine intrinsic brand operations
before author scripts, retains actual object-pointer identity and copied Map/Set
lists, and follows source enumerable OwnPropertyKeys/descriptor snapshot followed
by HasOwnProperty/Get/recursive-value/key ordering. Actual getters retain their
original thrown value. Deserialization creates actual owning-realm objects with
source data-property attributes and identity/cycles through the source IPC/LBSC
record, without JSON or an alternate serialization format.

The native collection tests cover sparse arrays, boxed primitives, arbitrary
BigInts, alias/cycle memory, getter deletion/order, mutation during copied-list
serialization, captured intrinsics, forged prototypes and Symbol.toStringTag,
original thrown identity, closed owners, and temporary root release. The five
cases and UTF-16 neighbor passed two files with GC disabled; the final collection
file passed again after adding an explicit exact-Error-brand prerequisite.
Returned values and bridge intrinsics retain actual Runtime roots until released
or Runtime.close; this does not establish full source GC reclamation.

The C API's actual JSArray check matches source concrete JS::Array detection:
Proxy(Array) and an object with Array.prototype remain ordinary-object source
fallbacks, preserving the pinned source's existing exotic-object FIXME.

Native RegExp remains explicit: JSC's public source getter escapes source text
and its flags getter normalizes order. These cannot recover arbitrary original
constructor source/flags, so the bridge uses a captured getter only for a genuine
brand check and rejects that unsupported native family without serializing the
normalized getter values as the source internal records. Original resizable-view
slots, platform registration and source serialization hooks remain subsequent slices;
public native tee still requires those complete source family bindings.

The actual Date projection reads the captured intrinsic Date value, preserves
aliases and invalid-date NaN, and ignores author conversion methods and custom
properties. Reconstruction uses the captured owning-engine Date constructor.
IPC and LBSC goldens include the source double payload. The two Date cases and
the collection neighbor passed two files with GC disabled. Untrusted serialized
Date doubles outside the native constructor's TimeClip domain remain a JSC
record-construction boundary; this evidence covers actual source native Dates.
The native decoder now explicitly rejects fractional, infinite, out-of-range
and negative-zero raw Date slots that JSC would change through TimeClip. The
source DTO codec retains those raw doubles; no different native Date is silently
installed. That boundary test, independent IPC/Storage result bindings, and the
fixed-view neighbor passed two files with GC disabled.

Native Error serialization follows Get(name), the own message descriptor and
its data-value ToString, then the own cause descriptor and its data-value
ToString. Captured String concatenation performs actual ToString with string
hint, including Symbol rejection and original abrupt identity. Accessor
descriptors are skipped. Actual native Error brands and captured constructors
preserve source subtype prototypes; reconstruction defines only present
message/cause fields with writable/configurable, non-enumerable attributes.
IPC/LBSC preserve aliases, lone surrogates and the source cause string rather
than recursively cloning it. Four native Error cases passed with GC disabled;
Date and collection neighbors passed before the final fixture-only correction.
This JSC has no actual InternalError constructor. Source codec records still
support that pinned subtype; native reconstruction explicitly rejects it with
DataCloneError instead of substituting a generic Error with a different name.

Actual fixed/resizable ArrayBuffers now expose their genuine detached,
resizable and maximum-length internal slots through captured intrinsic getters.
The projection copies the real backing span immediately into an owned source
byte block; source IPC/LBSC encode it and its capacity. Reconstruction creates
the captured owning-engine ArrayBuffer, copies the source bytes into its actual
backing block, preserves aliases, and provides an independent allocation that
can grow later when resizable. Author own properties and resize/conversion
methods are ignored. Detached buffers, including zero-byte detached buffers,
reject with DataCloneError. Three native buffer cases and the Error neighbor
passed two files with GC disabled. The V byte-array capacity and the native
constructor's exact Number capacity remain explicit checked limits; untrusted
u64 capacity is never rounded into a different native record. Resizable view
automatic-length slots, SharedArrayBuffer native availability and cross-process
sharing remain separate boundaries.

Fixed-backed native DataView and all twelve source TypedArray constructors now
read genuine view slots through captured intrinsic getters. Their source witness
check rejects detached/out-of-bounds views before serializing the backing buffer;
own buffer/length getters, forged toStringTag and custom properties do not enter
that path. Source records create actual target views with the captured constructor
and retain buffer-before-view identity across aliases and sibling views. The
DataView IPC golden verifies the absent ArrayLength field. Three native view
cases and the buffer neighbor passed two files with GC disabled. Author-created
resizable views still reject explicitly: public getters materialize current
lengths and cannot recover their original automatic/fixed slots, including a
fixed view that temporarily became out of bounds after resize.

Resizable views reconstructed from source records now retain those known
immutable constructor slots beside the actual native view pointer. This owner
belongs to the actual Runtime, so multiple projection bridges in that Runtime
reuse the same original record. Actual fixed/automatic DataView and TypedArray
construction preserves automatic flags during source reprojection after growth;
live witness checks still reject a temporarily out-of-bounds view after shrink,
and regrowth restores its original fixed slots. Source backing bytes reflect
the actual current buffer. Three owning-view cases and the fixed-view neighbor
passed individually with GC disabled. One protected actual view root preserves
the slot record until Runtime.close, where the owner registry clears before the
engine context is released. This is explicit embedding retention, not full
source GC wrapper reclamation. Untracked author-created resizable views remain
unsupported; current getter values are never substituted for original slots.

The DOMException prerequisite now retains actual UTF-16 name/message fields,
including supplied storage metadata, and exposes the source two-field payload
order. Compatibility string updates clear stale UTF-16 fields; value copies keep
the authoritative native record's units. The native constructor performs actual
engine ToString in message-then-name order, copies the true UTF-16 span, and
getters create actual engine strings from those retained units. Lone surrogates,
embedded NUL, pairs, one string-hint conversion, Symbol rejection, original
throws and stable getter root counts are covered. Two typed files and three
native constructor/identity/brand files passed with GC disabled. This retains
the source string fields at the typed embedding boundary; full AK Utf16FlyString
intern-table ownership remains separate. SerializableObject interface ids,
exposure and payload versions are a separate source registry codec boundary.

The SerializableObject DOMException payload now follows the actual source
registry. A reproducible tool imports the pinned source IDL parser/intrinsic
collector without writing upstream bytecode, checks the pin and input diff,
and retains a metadata digest. Fresh source metadata contains 586 intrinsic
interfaces and assigns DOMException id 568 (QuotaExceededError 569). The old
upstream build header contains 553 entries and assigns DOMException 538; that
stale artifact is not the translation reference. The two generated CSS inputs
are only a partial namespace and mixin, so they contribute no interface ordinal;
an independent full source GenerationContext confirmed the same fresh ids.

IPC emits SerializableObject, the source u16 primary interface id, then name
and message UTF-16 fields. LBSC emits the stable interface identifier and source
payload version 1 before those fields. The target's actual exposure callback is
required before platform allocation/payload reading; standalone decoders do not
invent a browser realm. Aliases retain the source object memory, malformed ids,
versions and truncation reject, and an untranslated primary subtype never
silently becomes a base DOMException. Three codec cases and the LBSC neighbor
passed two files with GC disabled. The registry retains all sixteen source
identifiers for validation; other platform payload implementations and actual
native exposure bindings remain explicit subsequent slices.

The native DOMException clone now uses its actual native record/wrapper cache
and original captured platform factory. It serializes internal name/message
fields, ignoring author-shadowed getters and custom properties, and preserves
aliases plus UTF-16 strings through both source record forms. Target exposure
comes from the actual installed binding instead of an author-visible global
property; a fresh unexposed Runtime rejects before creation, and an exposed
target receives a new owning record/wrapper. Codec parse failures become actual
DataCloneError values at this native boundary. Primary QuotaExceededError is
recognized before its genuine DOMException base; its separate source payload
and native factory are now translated as described below. Three native cases and the
Error neighbor passed two files with GC disabled. Actual wrapper caches retain
their native objects until Runtime.close; complete wrapper GC and the other
platform registries/payloads remain separate work.

The native brand classifier captures a genuine SharedArrayBuffer byte-length
getter when the engine exposes it. A shared buffer cannot fall through as an
ordinary empty object, and a shared-backed view rejects before ArrayBuffer-only
slot getters. Both paths retain an explicit DataCloneError boundary while
native isolation/sharing ownership is absent. This CAPI JSC does not expose
SharedArrayBuffer, so the real shared cases are conditional and do not establish
shared transport coverage. Forged tags and the pin's ordinary Promise/WeakMap/
Proxy fallback are tested; source steps 22/23 remain FIXME and are not replaced
with an invented general internal-slot rejection. The shared-boundary file and
fixed-view neighbor passed two files with GC disabled.

The native projection must retain actual JSC object identity and cycle memory,
source key/enumerability/Get order and original completions, and captured
intrinsic brands for each supported JavaScript family. Public native `tee()`
remains absent until that clone hook covers the source JavaScript families.
Unsupported platform objects must use the source DataCloneError boundary.
Full wrapper GC and source LibJS browser execution remain separate work.

QuotaExceededError now preserves the source UTF-16 message at both typed and
native constructor boundaries. The constructor allocates the named base,
assigns each present option in source order and checks requested against quota;
actual native IDL conversion keeps message string-hint ToString before the
quota/requested number conversions and retains original thrown values. The
typed constructor, existing core and native binding files passed three files
with GC disabled, including lone surrogates, NUL, zero and nullable fields.

Its primary serializable interface is fresh pinned-source id 569, distinct from
DOMException 568. The source payload writes DOMException name/message followed
by quota and requested Optional<double>: each has a source bool presence byte,
then a fixed little-endian double when present. Both IPC and LBSC goldens are
covered; storage validates canonical bool bytes. Valid source IPC bool storage
is 0/1; noncanonical raw native bool representations have no portable C++
semantic guarantee, so this adapter does not claim malformed IPC bool parity.
Decoding preserves raw double bits and assigns slots without repeating public
constructor validation. Absent versus zero, signed zero, NaN payload, negative
values, infinity, alias identity, exposure and truncation passed three focused
source/neighbor files with GC disabled.

Native clone projection obtains the actual QuotaExceededError record from its
wrapper cache before testing the embedded DOMException base. It emits the real
primary source payload and recreates the target through the captured native
Quota factory/prototype, preserving aliases, inherited exception behavior and
all extra slots. Shadowed name/message/quota/requested getters and custom own
properties are ignored. Target exposure requires the actual installed Quota
binding even when DOMException is already exposed; author-mutated constructor
globals do not replace the captured factory. Three native Quota clone/DOM clone/
constructor files passed with GC disabled. Source caches still retain wrappers
until Runtime.close; original native RegExp metadata, untracked resizable view
slots and the remaining platform payloads/exposure remain separate boundaries.

Source step 20 now rejects genuine native platform objects before the ordinary
enumerable-property branch. It uses actual EventTarget/Event, stream/controller/
reader/writer, queuing-strategy, Abort, Crypto/SubtleCrypto and FontFace caches;
no prototype chain or author-visible tag establishes a platform brand. The
FontFace lookup retains its installed host per actual Runtime and removes that
ownership at Runtime.close. FontFaceSet and font load events already use the
actual event binding cache. Genuine CryptoKey remains a distinct step 19
SerializableObject whose source payload is a subsequent slice, rather than
being downgraded to an ordinary object or rejected as a nonserializable platform.

The three focused cases cover twenty genuine wrapper variants in IPC and LBSC,
including every currently bound stream controller and the BYOB reader, author
getters that must remain unread, forged prototypes/tags, and host cleanup.
The platform file passed with both GC modes; the FontFace ownership neighbor
also passed with GC disabled. The earlier platform, Quota and DOM clone batch
passed three files. Logs are `native-platform-clone-complete-default.log`,
`native-platform-clone-complete-gc-none.log` and
`native-platform-clone-recovered-gc-none.log` under the assignment 7 private
`Build/audit-fixes/` directory. Compact XHR/Canvas facades without actual cached
platform wrappers and the other unbound platform families remain explicit
binding boundaries; this gate does not establish complete public tee coverage.
