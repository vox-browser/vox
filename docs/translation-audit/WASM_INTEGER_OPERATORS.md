# Source scalar integer operator slice

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Implementation and focused tests: `b5ae85be`.
Independent corpus tooling: `62552980`.

`LibWasm/AbstractMachine/Operators.h`'s Divide and Modulo integer
specializations, and unsigned BitRotateLeft/BitRotateRight specializations,
map directly to `webassembly/operators_integer.v`. Concrete 32-bit and 64-bit
functions replace C++ operator templates. The Divide checks translate
`AK/Checked.h::div`: signed minimum divided by minus one fails before the
zero-divisor gate. Both failures retain `Integer division overflow`. Modulo
checks zero first and deliberately returns zero for signed minus one, including
the signed minimum. Negative division truncates toward zero and signed
remainder follows the dividend, as the native source does.

Rotations preserve the Source width mask, unsigned negation and paired shifts.
Zero, full-width, overflowing-width and high-bit shift counts therefore retain
their Source results; no alternate rotation algorithm is supplied.

`tools/generate_wasm_integer_operators.py` verifies the upstream revision and
extracts those four C++ records verbatim. It records their SHA-256 hashes and
compiles them with the actual pinned AK Checked/Error/StringView headers.
The existing upstream macOS build supplies generated AK headers and the AK
library for assertions; operator arithmetic executes the extracted pinned
records, not an independently written oracle. Excerpting the four records
avoids unrelated LibWasm Types/LibSync generated exports. The tool writes its
temporary C++ source and executable only beneath this repository's ignored
Build directory. It never modifies the Ladybird checkout.

The checked-in corpus contains **3,264 exact native cases** across all twelve
specializations. It covers signed/unsigned extremes, zero divisors, signed
overflow, negative operands, and both rotation widths/directions. Focused
tests pass in both GC modes privately; the GC-disabled batch also passes
actual machine Value and bytecode-trap neighbors. Canonical default-GC
verification passes independently, and the GC-disabled integration result is
recorded in the aggregate ledger.

This slice does not supply a production `interpret()` method or a substitute
Wasm execution loop. Floating Divide, other scalar operators, SIMD operators,
full instruction dispatch remain pending. The subsequent
[numeric helper slice](WASM_NUMERIC_OPERATIONS.md) translates operand routing
and trap propagation with a supplied concrete operator adapter.
The preceding clean 80-file Wasm sweep predates this added operator test;
it is not a claimed full sweep of the subsequent 82-file package.
