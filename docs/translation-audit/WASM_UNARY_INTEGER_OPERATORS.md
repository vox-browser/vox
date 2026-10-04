# Source unary integer operators

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Implementation and focused tests: `7d0af709`.
Independent corpus tooling: `bd231130`.

`LibWasm/AbstractMachine/Operators.h:464–518` maps EqualsZero,
CountLeadingZeros, CountTrailingZeros and PopCount to concrete functions in
`webassembly/operators_unary_integer.c.v`. EqualsZero retains its boolean
return. The count operators return i32 at both scalar input widths; Source
instruction handlers subsequently widen i64 count results, whereas i64
EqualsZero pushes i32. PopCount retains all four supported input widths.
Signed inputs pass through the Source MakeUnsigned conversion before counting.

CLZ/CTZ explicitly return the input bit width for zero before calling the
native primitive. `operators_unary_integer_host.h` translates the actual
AK/BuiltinWrappers branches: compiler builtins prefer unsigned int, then
unsigned long, then unsigned long long according to their widths. Its
fallback loops are transcribed from AK, including the pinned fallback CLZ
return value. No replacement counting algorithm is introduced. The tested
macOS build uses Clang; other compiler fallback branches are not validated by
this native corpus.

`tools/generate_wasm_integer_operators.py --family unary` extracts the four
verbatim pinned records, records their SHA-256 hashes and compiles them with
the real AK BuiltinWrappers headers. **1,656 exact native results** cover zero,
signed/unsigned extremes, every single-bit position and complement, all scalar
widths and all 256 byte population counts. The default binary family still
reproduces its existing 3,264-case fixture byte-for-byte. All generated native
probe inputs/executables stay in this repository's ignored Build directory;
the upstream checkout remains read-only.

The unary file passes default GC privately; unary, numeric helper and binary
integer oracle files pass **3/3** privately with GC disabled. Unary operators,
the actual numeric helper and actual-global Blob exposure also pass **3/3**
canonically with GC disabled
(`Build/audit-fixes/source-unary-operators-actual-blob-global-canonical-gc-none.log`).
The second unary regression writes actual Configuration slots through the
translated helper and verifies i64 count versus i32 predicate result records,
cleared high bits, unchanged separate destinations and no stack consumption.

These are operator/helper translations. Production instruction dispatch and
SIMD execution remain pending. The preceding 80-file full Wasm sweeps predate
all three added integer/helper files in the subsequent **83-file** package.
