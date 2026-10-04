# Source scalar reinterpret operators

Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`webassembly/operators_reinterpret.v` translates the four scalar equal-width
forms of `Operators.h::Reinterpret` (1109–1117), used by
`BytecodeInterpreter.cpp` at 567 and 1649–1667. The Source body is exactly a
`bit_cast` to the declared result. Existing native V floating-bit primitives
perform that same representation conversion; signed integer casts retain the
same bits. No numerical conversion, NaN canonicalization or zero normalization
is added.

`tools/generate_wasm_integer_operators.py --family reinterpret` extracts and
hashes the complete pinned C++ template and compiles it against the actual AK
headers/library. Its 576 exact result-bit cases include both signed zeros,
subnormal boundaries, infinities, quiet/signaling NaN payloads of both signs,
all 64 single-bit positions and their complements. Integer results preserve
the Source returned sign extension; floating results preserve their exact
native width. Regeneration reproduces both this fixture and the earlier
integer-width fixture byte-for-byte.

The focused file passes with default GC. It, the integer-width fixture and
actual numeric-helper suite pass **3/3 with GC disabled** in assignment 9's
isolated checkout; logs use `source-reinterpret-` under `Build/audit-fixes/`.
Genuine helper regressions preserve signaling NaN payloads, Source selected
slot/result representation, high-half cleanup, untouched destination/stack
and the previous trap. These are Source operator/helper foundations, without
production opcode dispatch, constant-expression or full AbstractMachine
instantiation/collector/realm parity. The historical 90-file package sweep
predates all three new width/reinterpret test files.
