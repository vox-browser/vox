# Source scalar integer shifts

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Tooling: `0e4a83df`; implementation/tests: `1897fa01`.

`LibWasm/AbstractMachine/Operators.h::BitShiftLeft/BitShiftRight` translate to
six concrete functions in `webassembly/operators_shift_integer.v`. Their
argument types follow the actual i32/i64 handlers in
`BytecodeInterpreter.cpp:997–1022,1159–1184`: unsigned left shifts and signed
or unsigned right shifts. The Source modulo count is retained at each width.
For signed right shifts, Source's unsigned `sizeof(lhs) * 8` converts RHS to
`size_t` before `%`; explicit unsigned conversion preserves negative-count
behavior rather than using V's signed remainder.

`tools/generate_wasm_integer_operators.py --family shift` extracts both
verbatim C++ operator records and records their SHA-256 hashes. **5,760 exact
native results** cover every scalar bit position, wrapping counts, negative
signed counts and signed/unsigned operand boundaries. Regenerating both prior
binary and unary families remains byte-exact (3,264 and 1,656 cases).

The new file passes default GC privately. It and binary-operator/numeric-helper
neighbors pass **3/3** privately and **3/3** canonically with GC disabled
(`Build/audit-fixes/source-shift-integer-canonical-gc-none.log`). An initial
test-only old-compiler enum-array inference failure is retained separately;
the corrected fixture qualifies the enum type explicitly. The second test
uses actual Configuration registers and the existing Source numeric helper,
including i32/i64 PushType records, cleared high bits, unchanged separate
destination and unconsumed register sources.

These operator translations add no instruction dispatcher. Full production
opcode execution, remaining scalar/SIMD operations, instantiation and roots
remain open. This file raises the package to 84 test files; the earlier clean
83-file private sweep predates it.
