# Source saturating floating-to-integer truncation

Upstream: `963d46a829f3e1b79f44dba9d02afb70654300fa`, LibWasm
`AbstractMachine/Operators.h:1160-1196`.

`operators_saturating_truncate.c.v` translates all eight Source float/double
to signed/unsigned 32/64-bit specializations. It keeps NaN-to-zero, signed
infinity-to-limit branches, original-width `truncf`/`trunc`, Source lower-limit
comparison, the distinct float/double upper-limit casts, and final conversion.
Concrete integer limits correspond to pinned `AK/NumericLimits.h`.

The upstream i64 edge-value FIXME remains a limitation of these translated
bodies. No corrected specification formula replaces the pinned C++ algorithm.
Unlike CheckedTruncate, saturation returns a value and sets no new trap.

The generator extracts the complete unmodified Source template and compiles
it against actual pinned AK headers. **1,312 exact C++ result records across
all four native rounding modes** match, including quiet/signaling NaNs,
signed infinities and zeros, subnormal and maximum finite values, both sides
of every destination bound, and fractional inputs. The fixture reproduces
byte-for-byte. The earlier checked-truncation fixture also reproduces after
this separate tooling extension.

The initial new test failed to compile because its standalone C rounding
declarations were missing. That diagnostic is retained in
`source-saturating-truncate-default.log`. The corrected file passes default
GC in `source-saturating-truncate-default-recheck.log`; it, checked truncation
and the real numeric-helper neighbor pass **3/3 with GC disabled** in
`source-saturating-truncate-gc-none.log`, under assignment 9's private
`Build/audit-fixes/`. The actual helper preserves unsigned full-width limits,
clears result high bits, writes only the selected operands, and retains the
destination, stack and prior trap.

Tooling and implementation/tests are separate commits. This adds the 96th
WebAssembly test file after the historical frozen 94-file sweep. Production
opcode dispatch, remaining scalar/SIMD operations, complete execution and
instantiation, and collector/realm roots remain unfinished.
