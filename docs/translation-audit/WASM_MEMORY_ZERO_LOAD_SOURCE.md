# Source SIMD zero loads

`BinaryMachineBytecodeInterpreter.load_and_push_zero_n[T]` directly translates pinned Source `BytecodeInterpreter.cpp:6569–6589` at `963d46a829f3e1b79f44dba9d02afb70654300fa`. Source N=32/64 maps to u32/u64; other instantiations fail compilation.

The Source unsafe_get guard precedes frame/module/Store and operand access. The actual module memory address is resolved before taking address operand0. Memory32 addresses narrow to u32, memory64 retains u64; offset and byte-width Checked additions retain overflow and end-of-memory traps. Both Source and V consume the address before a trap and leave the destination unchanged on failure. On success the fixed 16-byte local starts completely zero, actual translated MemoryBuffer.copy_to replaces only its low N/8 bytes, and actual Configuration.push_to_destination Any writes the destination. A pre-existing trap and the instruction pointer remain unchanged on success.

The fixed byte owner represents Source's `u128 vector = 0;`. Existing Source value-byte reading reconstructs the real BinaryMachineValue pair. No stack-only shortcut, fabricated vector class, alternate memory engine or opcode executor is introduced.

## Native layout evidence

`tools/source_wasm_memory_zero_load_probe.py` verifies clean pinned AK/LibWasm sources and exact C++ bytes, extracts the original zero initializer and verifies the original low-byte copy destination. Actual AK u128/BitCast/Span produce 40 rows: 20 native patterns at each of 32/64 bits. Clang -O0 and -O2 outputs are identical. The probe covers target little-endian vector initialization/layout and actual AK byte copies; it does not execute native MemoryBuffer cages or Source Configuration/interpreter. The real translated MemoryBuffer owner is exercised by V tests. All generated output stays in this repository's ignored build directory.

## Focused checks

The 40 native fixture rows drive 480 actual helper calls across register/stack/call-record sources and destinations, including source aliases. Tests retain an actual frame/module/Store with reordered memories and a high memory32 base, verify zeroed upper bits from all-ones destinations, and check unchanged other slots, memory guards, old trap and instruction pointer. Another test covers 18 memory64 overflow/end failures, consumed stack address, a complete unchanged-memory scan and an exact-end 32-bit load. A compiled subprocess with no frame/operands proves the wrong-argument production guard.

Private `Build/audit-fixes/` evidence:

- `source-memory-zero-load-probe.log`: 40 native rows at both optimization levels PASS.
- `source-memory-zero-load-default.log`: 1/1 PASS, 13.367s.
- `source-memory-zero-load-gc-none.log`: zero load/lane load/Configuration, 3/3 PASS, 28.726s.
- `source-memory-zero-load-production-gc-none.log`: 1/1 PASS, 32.525s.

The new 104th Wasm file is prepared privately after frozen `a85c3b92` and is excluded from that 103-file/native verification. Full opcode dispatch, interpreter loop, other SIMD helpers, instantiation and collector ownership remain pending.
