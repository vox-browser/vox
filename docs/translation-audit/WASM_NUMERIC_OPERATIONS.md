# Source numeric operation helpers

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Implementation and focused tests: `9a9aaf30`.

`LibWasm/AbstractMachine/BytecodeInterpreter.cpp:6759–6805` maps to
`webassembly/machine_numeric_operation.v`: `binary_numeric_operation` and
`unary_operation` operate on the actual Configuration, compiled operand
mapping, machine Value records and interpreter trap state.

The binary helper consumes RHS first with `take_source`, then borrows the
actual LHS slot with `source_value`. Its successful result overwrites that
slot, even when the compiled mapping has a separate destination register.
An operator error sets the original error reason as the trap, leaves LHS
unchanged and retains the already-consumed RHS. The unary helper borrows the
selected input slot without popping it; success writes that same slot and
failure preserves it. Success returns false and does not clear an existing
trap, matching Source.

Concrete V function types adapt the C++ PopType/PushType/operator templates
to machine Values and V Result errors. The supplied concrete operator owns
the scalar conversions and result type; the helpers preserve Source operand
routing and error/write order. Focused tests call the translated integer
Divide and Rotate operators through this adapter. This is a callable helper
translation, not an instruction dispatcher or a substitute execution loop.
The pinned generated AK configuration has `WASM_TRACE_DEBUG` disabled.
Enabled operator-name trace formatting remains untranslated.

Four regressions exercise all four operand-address mixes through actual
registers and stack slots, separated destinations, signed division overflow,
RHS consumption on failure, unary input selection, cross-width Value writes,
stack preservation, aliased operands and pre-existing trap preservation.
The file passes default GC privately; it and actual Configuration/bytecode
state neighbors pass **3/3** privately with GC disabled. Canonical numeric
helper and integer-oracle files pass **2/2** with GC disabled
(`Build/audit-fixes/source-numeric-operation-canonical-gc-none.log`).
The earlier fixture compile failures used incorrect API names and are retained
as runner diagnostics; the corrected fixtures use actual StackInfo and Trap
APIs.

The preceding full **80/80** Wasm sweeps predate the integer operator and
numeric helper test files. The package now has 82 files; no complete 82-file
sweep is claimed here. Full scalar/SIMD operator coverage, production opcode
dispatch, constant-expression execution, native compilation/fault recovery,
complete instantiation and collector roots remain open.
