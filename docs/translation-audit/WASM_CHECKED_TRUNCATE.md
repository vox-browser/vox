# Source checked floating-to-integer truncation

Upstream: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`operators_checked_truncate.c.v` translates the eight float/double to
signed/unsigned 32/64-bit specializations of LibWasm
`AbstractMachine/Operators.h:1058-1084`. It preserves original-width
`isnan`/`isinf`, `truncf`/`trunc`, the two exact Source error strings, the
range check before conversion, and the final destination cast.

The four concrete bounds checkers follow the floating Source specializations
in `AK/Checked.h:59-103`: compute an exact power of two with the Source
multiply loop, test the safe signed or unsigned cast window, then compare the
converted integer's round trip. Source promotes the already truncated
float/double value to `long double`. V uses `f64` at this bounded boundary:
promotion from `f32` is exact, an original `f64` is unchanged, and the finite
integer-valued input and power-of-two bounds remain exactly representable.
An accepted integer converts back to that same original floating value. This
argument applies to these original-width truncated inputs; it does not claim
a general translation of arbitrary AK long-double range checks. The upstream
operator's FIXME is retained as an upstream limitation.

`generate_wasm_integer_operators.py --family float_truncate` extracts and
compiles the complete unmodified Source operator against the actual pinned
AK headers. The fixture records the operator and full `AK/Checked.h` hashes.
All **328 exact native C++ results/errors** match, including both signs of
quiet/signaling NaNs and infinity, signed zero, subnormals, maximum finite
values, neighbors of all destination bounds, and fractional values whose
original-width truncation can enter the safe window. The fixture reproduces
byte-for-byte; the existing 8,512-case integer-to-float fixture also reproduces
after the generator extension.

The new file passes default GC. It and the integer-to-float and real machine
numeric-helper neighbors pass **3/3 with GC disabled** in the isolated
assignment-9 checkout. Logs use `source-checked-truncate-` under its
`Build/audit-fixes/`. The actual unary-helper regression replaces an existing
trap on either failure without changing its operand and retains Source
selected-slot, destination, stack and prior-trap behavior on success.

Tooling and implementation/tests are separate commits. This is the 95th
WebAssembly test file and follows the historical frozen 94-file sweep.
Production opcode dispatch, remaining scalar/SIMD operators, complete
execution/instantiation and collector/realm roots remain unfinished.
