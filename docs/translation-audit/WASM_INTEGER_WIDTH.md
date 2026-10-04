# Source scalar integer width conversions

Upstream pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`webassembly/operators_width_integer.v` translates the eight concrete scalar
instruction forms of `Operators.h::Wrap` (1048–1056), `Extend` (1087–1095)
and `SignExtend` (1147–1158). Source `BytecodeInterpreter.cpp` uses these forms
at 576–612, 1460 and 1541–1550.

Wrap preserves the unsigned operand bit representation, narrows to the unsigned
result width, then returns the declared signed result. Signed and unsigned
extension retain their original input interpretation. Sign extension follows
all four Source steps: unsigned representation, narrower unsigned conversion,
initial signed interpretation, and conversion back to the original width.
These casts translate the Source operations directly; no new conversion
algorithm or numerical normalization is introduced.

`tools/generate_wasm_integer_operators.py --family integer_width` extracts the
three exact Source templates, hashes their complete text and compiles them
against the pinned AK headers/library. It produces 3,216 exact result-bit cases
covering signed boundaries, all 64 single-bit positions and complements, and
all 256 byte patterns with nonzero upper bits. The fixture includes original
operand bits and sign-extended returned results.

The new focused file passes with default GC; it and the existing integer unary
and actual numeric helper suites pass **3/3 with GC disabled** in the isolated
assignment-9 checkout. Logs use `source-integer-width-` under its
`Build/audit-fixes/`. The initial GC-disabled invocation named a nonexistent
neighbor test and ran no tests; it remains in `source-integer-width-gc-none.log`.
The clean corrected run is `source-integer-width-gc-none-recheck.log`.

Helper regressions retain the Source selected operand slot, result width,
cleared high half, unchanged explicit destination/stack and earlier trap.
These are operator and helper foundations. Production opcode dispatch,
checked/saturating float-to-integer conversions, remaining SIMD records,
constant expressions, machine instantiation and complete collector/realm roots
remain open. The historical 90-file sweep predates both new width test files.
