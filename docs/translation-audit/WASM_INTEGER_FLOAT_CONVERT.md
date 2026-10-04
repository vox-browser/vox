# Source integer-to-floating conversions

Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`webassembly/operators_convert_integer_float.v` translates the eight scalar
forms of `Operators.h::Convert` (1097–1107), used by
`BytecodeInterpreter.cpp` at 1559–1586 and 1604–1631. Source first bit-casts
the operand to its already declared input type, then performs the result-type
cast. With concrete V input types that identity representation is retained;
each body directly performs the original native conversion with its signed
or unsigned interpretation and f32/f64 result width.

`tools/generate_wasm_integer_operators.py --family integer_float` extracts
and hashes the complete exact C++ template and compiles it against pinned AK.
Its 8,512 exact result-bit cases run all eight input/result forms under all
four native rounding modes. They include signed/unsigned bounds and every
64-bit power of two, its adjacent integer values and its complement, covering
f32/f64 precision-loss transitions. Regeneration reproduces the fixture
byte-for-byte.

The focused test passes with default GC. It, the scalar reinterpret and
actual machine numeric-helper suites pass **3/3 with GC disabled** privately.
Logs use `source-integer-float-` under assignment 9's `Build/audit-fixes/`.
Helper regressions preserve the original operand interpretation, selected
slot/result width, high-half cleanup, other operands, destination, stack and
prior trap. Production opcode dispatch, checked/saturating floating-to-integer
conversions, SIMD records, constant-expression execution, full instantiation
and collector/realm roots remain open. The historical 90-file sweep predates
this and the three new width/reinterpret test files.
