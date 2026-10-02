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
normalized getter values as the source internal records. Buffers,
platform registration and source serialization hooks remain subsequent slices;
public native tee still requires those complete source family bindings.

The actual Date projection reads the captured intrinsic Date value, preserves
aliases and invalid-date NaN, and ignores author conversion methods and custom
properties. Reconstruction uses the captured owning-engine Date constructor.
IPC and LBSC goldens include the source double payload. The two Date cases and
the collection neighbor passed two files with GC disabled. Untrusted serialized
Date doubles outside the native constructor's TimeClip domain remain a JSC
record-construction boundary; this evidence covers actual source native Dates.

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

The native projection must retain actual JSC object identity and cycle memory,
source key/enumerability/Get order and original completions, and captured
intrinsic brands for each supported JavaScript family. Public native `tee()`
remains absent until that clone hook covers the source JavaScript families.
Unsupported platform objects must use the source DataCloneError boundary.
Full wrapper GC and source LibJS browser execution remain separate work.
