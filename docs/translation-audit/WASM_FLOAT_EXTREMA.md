# Source scalar floating extrema and sign copying

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Tooling: `ebe9af38`; implementation/tests: `b10f59ce`.

Six float/double Minimum, Maximum and CopySign specializations translate
`LibWasm/AbstractMachine/Operators.h:398–465` and the concrete interpreter
handlers at lines 1303–1328 and 1429–1454. Minimum/Maximum keep the Source NaN
check before signed-zero handling, then use the exact AK min/max comparison
branches. NaN results use `AK::NaN<T>`'s empty builtin payload; V's `math.nan()`
has a different payload and is therefore not substituted. CopySign calls the
same width-specific host `copysignf`/`copysign` operations as Source, preserving
signaling payloads without a float-to-double round trip.

The generator's `--family float_extrema` copies all three complete Source
records and compiles with actual AK Math helpers and libm. **1,536 exact native
C++ cases** compare result bits for signed zeros, infinities, finite values,
subnormals and signed quiet/signaling NaNs. No case override or NaN equivalence
relaxes the bit comparisons. The new file passes default GC privately;
extrema/arithmetic/helper files pass **3/3** privately and canonically with GC
disabled (`source-floating-extrema-canonical-gc-none.log`).

Actual Configuration tests verify canonical NaN from minimum, positive zero
from maximum and retained signaling payload/sign from CopySign, through the
translated numeric helper and its Source slot/trap ordering. This snapshot
has 89 test files. Remaining scalar/SIMD operators, production opcode dispatch,
instantiation and collector/realm roots remain open.
