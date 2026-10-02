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

Remaining source codec work is explicit: ArrayBuffer/View nested memory
registration and byte-length-slot encoding,
u64 buffer capacity, source Error type/optional payloads, and the distinct
LBSC storage writer/reader. The existing structured DTO provides standalone
object identity and cycles; it still needs the actual engine projection.

The native projection must retain actual JSC object identity and cycle memory,
source key/enumerability/Get order and original completions, and captured
intrinsic brands for each supported JavaScript family. Public native `tee()`
remains absent until that clone hook covers the source JavaScript families.
Unsupported platform objects must use the source DataCloneError boundary.
Full wrapper GC and source LibJS browser execution remain separate work.
