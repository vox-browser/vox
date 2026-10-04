# Source scalar floating arithmetic

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Tooling: `5ab129c2`; implementation/tests: `aa474918`.

Eight float/double Add, Subtract, Multiply and Divide specializations follow
the exact operator macro bodies and Divide's floating branch in
`LibWasm/AbstractMachine/Operators.h`. The corresponding interpreter handlers
at lines 1267–1301 and 1393–1427 use the same floating operand/result width.
Floating division forwards zero divisors to the arithmetic operation; it does
not inherit the integer checked-division trap.

The generator's `--family float_arithmetic` compiles the verbatim macro,
three invocation lines and complete Divide record against actual AK headers.
**2,048 exact native C++ cases** compare IEEE result bits, including NaN
payloads, signed zero, infinities, subnormals and finite overflow. The fixture
regenerates byte-for-byte, and the existing floating-comparison fixture stays
byte-exact after the tooling change. This evidence uses the current macOS
host's floating implementation; it does not prescribe cross-platform NaN
payload behavior beyond the Source implementation.

The new file passes default GC privately. Arithmetic/comparison/helper checks
pass **3/3** privately and canonically with GC disabled
(`source-floating-arithmetic-canonical-gc-none.log`). Actual Configuration
tests exercise positive/negative infinity from division by signed zero and a
double result. Writes clear unused high bits, preserve Source operand routing
and leave prior trap/destination/stack state unchanged.

This arithmetic snapshot has 88 test files. It adds concrete operator/helper
behavior; production opcode dispatch, remaining scalar/SIMD operators,
instantiation and collector/realm ownership remain open.
