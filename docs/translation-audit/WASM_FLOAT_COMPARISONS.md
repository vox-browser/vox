# Source scalar floating comparisons

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Tooling: `606791b9`; implementation/tests: `a1cf813d`.

The six `Operators.h::DEFINE_BINARY_OPERATOR` comparison records translate
to twelve concrete float/double specializations in
`webassembly/operators_comparison_float.v`. Their argument and result types
follow `AbstractMachine/BytecodeInterpreter.cpp:3433–3533` and the separately
located `f64_ge` handler at lines 871–878: f32/f64 operands, boolean operator
results and i32 numeric-helper writes.

The generator's `--family floating` copies the exact Source macro definition
and six invocation lines, records their SHA-256 hashes and compiles against
the actual AK headers. The fixture contains **3,072 exact native C++ cases**
across both widths, including signed zeros, subnormal/minimum-normal/maximum
finite values, infinities and positive/negative quiet/signaling NaN payloads.
Inputs retain their IEEE bit patterns; predicate results compare exactly.
The preceding arithmetic fixture also regenerates byte-for-byte after this
tooling change.

The new file passes default GC privately. Floating/integer comparison and
numeric-helper neighbors pass **3/3** privately and **3/3** canonically with
GC disabled (`Build/audit-fixes/source-floating-comparison-canonical-gc-none.log`).
Actual Configuration regressions exercise signaling-NaN inequality and
signed-zero equality through the translated numeric helper. Successful writes
use i32 values with cleared high bits, preserving Source RHS/destination,
operand-stack and pre-existing trap state.

This snapshot has 87 Wasm test files; the earlier clean 83-file private sweep
predates these four added operator families. Full opcode dispatch, remaining
scalar/SIMD operators, instantiation and collector/realm roots remain open.
