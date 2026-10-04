# Source floating promotion and demotion

Reference: read-only Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This supporting WA-11/WA-12 slice translates `Operators.h:1120-1143`'s
`Promote` and `Demote`, selected by the scalar `f64_promote_f32` and
`f32_demote_f64` handlers in `BytecodeInterpreter.cpp`.

`webassembly/operators_width_float.c.v` preserves Source's width-specific
NaN tests, empty-payload `nan("")` / `nanf("")` calls, demotion's infinity
branch using the same `copysignf` and huge-value builtin, and ordinary numeric
casts. The small C ABI header exposes those existing native operations. No
replacement floating conversion or NaN algorithm is supplied. Source's
canonical-NaN FIXMEs remain; no payload-preserving conversion is substituted
for its canonicalizing NaN branches.

`tools/generate_wasm_integer_operators.py --family float_width` extracts both
complete C++ records verbatim, records their SHA256 hashes and compiles them
against the actual pinned AK headers/library. The fixture has **272 exact
result-bit cases** across nearest/down/up/toward-zero native rounding modes.
Its input sets include signed zeros, finite extremes, subnormals, infinities,
quiet/signaling NaN payloads, half ties, float precision boundaries, the float
overflow midpoint and subnormal underflow midpoint. Tests restore the previous
floating environment. Exact native NaN/cast outputs are macOS evidence, not a
universal result-bit claim for every platform/compiler.

The actual unary-helper regression preserves the selected Source PopType and
PushType, sign-extension of float results in `Value`, cleared high words,
unchanged destination/stack and a retained earlier trap. Private focused
default GC passes **1/1**; width/unary/numeric-helper checks pass **3/3** with GC
disabled. Initial fixture compilation relied on declarations from another
test file; those declarations are now local to the independent fixture.
The original diagnostics remain in `source-floating-width-{default,gc-none}.log`;
clean logs are `source-floating-width-{default,gc-none}-recheck.log` under
assignment 9's private `Build/audit-fixes/`. Regeneration reproduced the width
fixture and the preceding unary fixture byte-for-byte.

Implementation/tests are committed as `9953f022`, the independent generator
as `9a903fed`. The earlier clean 90-file snapshot predates this 91st test file.
These records do not provide production opcode dispatch, module
instantiation/execution or complete collector/realm ownership; both broad
findings remain partial.
