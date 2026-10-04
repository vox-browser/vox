# Source scalar integer comparisons

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Tooling: `eae0d685`; implementation/tests: `38052bee`.

The six `Operators.h::DEFINE_BINARY_OPERATOR` comparison records translate
to twenty concrete integer specializations in
`webassembly/operators_comparison_integer.v`. Their types follow the actual
`BytecodeInterpreter.cpp:3244–3430` handlers: signed equality/inequality,
signed and unsigned ordering, and i32 results at either operand width.
The operator body returns a boolean; the existing numeric helper's concrete
Value adapter performs the Source PushType conversion to i32.

The generator's `--family comparison` copies the exact Source macro definition
and selected invocation lines, records their SHA-256 hashes and compiles them
against the actual AK headers. **2,880 exact native C++ results** cover all
twenty specializations across signed/unsigned extremes and truncated i32
operands. The existing 3,264-case binary fixture remains byte-exact after this
tooling change, and the comparison fixture regenerates byte-for-byte.

The new file passes default GC privately and canonically. It and shift/helper
neighbors pass **3/3** privately and **3/3** canonically with GC disabled
(`Build/audit-fixes/source-comparison-integer-canonical-{default,gc-none}.log`).
A second regression uses actual Configuration registers and the Source
numeric helper to distinguish signed from unsigned i64 ordering. It verifies
i32 result records with cleared high bits, preserved RHS/destination, empty
operand stack and unchanged pre-existing trap.

These are operator/helper translations, with no substitute instruction
dispatcher. Floating comparisons, remaining scalar/SIMD operations, complete
opcode execution, instantiation and roots stay open. This adds the 85th test
file; the earlier clean 83-file private sweep predates shifts and comparisons.
