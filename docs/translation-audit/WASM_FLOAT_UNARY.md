# Source scalar floating unary operators

Reference: read-only Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This supporting WA-12 slice translates the fourteen scalar float/double
specializations of seven records in
`Libraries/LibWasm/AbstractMachine/Operators.h`, selected by
`BytecodeInterpreter.cpp:1204-1265` and `1330-1391`.

| Source record | Translation |
| --- | --- |
| `Absolute` | Actual width-specific compiler fabs builtin from runtime `AK::abs` (`AK/StdLibExtras.h:150-164`) |
| `Negate` | Unary minus, preserving the original operand width |
| `Ceil`, `Floor`, `Truncate` | Source type-generic NaN test, canonical `AK::NaN<T>` on that branch, then the exact width-specific native math call |
| `NearbyIntegral` | `nearbyintf` / `nearbyint`, retaining the current native rounding mode |
| `SquareRoot` | `sqrtf` / `sqrt`, with no additional NaN canonicalization |

Implementation is `webassembly/operators_unary_float.c.v`. The small host
header exposes the Source type-generic NaN call at each operand width and the
same compiler fabs builtins through V's C ABI. It supplies no replacement
rounding, square-root or NaN-classification algorithm. Canonical NaN constants
are the bits produced by the Source empty-payload `AK::NaN<T>` specialization.
The Source `NearbyIntegral` body has no local rounding-mode override; this
translation preserves that body rather than adding one.

`tools/generate_wasm_integer_operators.py --family float_unary` extracts the
seven complete Source operator records verbatim, records their SHA256 hashes,
and compiles them against the actual pinned AK headers and native library.
The checked-in fixture has **1,568 exact result-bit rows**: 28 inputs per width,
seven operators, and nearest/down/up/toward-zero native rounding modes. Inputs
include both zeros, infinities, subnormals, finite extremes, positive/negative
half ties, quiet/signaling NaN payloads, and integers at the precision boundary.
The test restores its original floating environment after the corpus. This
is macOS native-result evidence, including native NaN outputs, rather than an
all-platform result-bit claim.

Private assignment-9 focused default-GC recheck passes **1/1** and the
GC-disabled unary/extrema/numeric-helper batch passes **3/3**. The actual
`unary_operation` test selects three real register slots, checks canonical NaN,
retained signaling payload under negation, signed zero under square root,
Source sign-extension of float bits in `Value`, cleared high words, unchanged
destination/stack and retained earlier trap. Its first fixture incorrectly
expected zero-extension for float negative zero; the corrected expectation
comes from `AbstractMachine.h:147-149`. The initial failure remains in
`source-floating-unary-default.log`; clean logs are
`source-floating-unary-default-recheck.log` and
`source-floating-unary-gc-none.log`. Regeneration reproduced both this fixture
and the previous extrema fixture byte-for-byte.

The implementation/test commit is `097d59af`; the independently reviewable
generator commit is `2a90324c`. All private artifacts are under
`Build/audit-fixes/worktrees/09-compiled-records/Build/audit-fixes/`.
The earlier full 89-file package snapshot predates this new file. These
operators and helper tests do not implement the pending production opcode
dispatch, continuation, module instantiation, execution or GC roots. WA-12
remains partial.
