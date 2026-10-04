# Source SIMD lane loads

The translated `BinaryMachineBytecodeInterpreter.load_and_push_lane_n[T]` follows pinned `BytecodeInterpreter.cpp:6542–6565` at Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`. Source N maps to the corresponding unsigned V primitive width: u8/u16/u32/u64. This is an actual helper translation; the opcode execution loop and native dispatch remain pending.

| Source operation | V counterpart |
| --- | --- |
| unsafe_get MemoryAndLaneArgument | explicit production panic before frame/operand access |
| module memory index → Store unsafe_get | actual frame/module memory-address list and Store memory instance |
| take_source Any vector0, address1 | same existing Configuration operations, in Source order |
| memory_base_address and Checked u64 additions | memory32 narrowing, memory64 full address, offset and width overflow branches |
| native u128 vector destination lane | fixed 16-byte local owner using existing Source value byte conversion; only the selected lane is borrowed |
| MemoryBuffer::copy_to | actual translated chunk-copy helper, corresponding to AbstractMachine.cpp:291–302 |
| push_to_destination Any | actual register/stack/call-record destination, including operand aliases |

Both operands are consumed before a memory-bounds trap. A trap does not write the destination. Success retains an existing interpreter trap and leaves the instruction pointer unchanged, matching this helper's Source body. Source verification owns lane validity, alignment and module index validity; no new clamping is introduced.

## Exact native byte-view evidence

`tools/source_wasm_memory_lane_load_probe.py` verifies the pin, clean Source headers and original C++/Types bytes, then extracts the actual `auto dst = bit_cast<u8*>(&vector) + memarg_and_lane.lane * N / 8;` statement. It uses actual AK u128, BitCast, Span and the two verbatim nested memory-argument declarations, inside a declaration-only enclosure. Actual AK byte copying writes into that destination, and actual AK u128 low/high accessors produce the fixture. The 20 vector patterns cover all 30 valid width/lane combinations, including sign bits, floating special-value payloads and both halves.

The tool passes 600 exact rows at clang -O0 and -O2, with identical fixture contents. It probes native little-endian vector layout and byte copying. It does not execute the Source MemoryBuffer cage, Configuration, verifier or interpreter. No replacement Source executor is supplied. Full Types.h still depends on an unavailable generated LibSync export, as documented by the preceding lane-store tooling diagnostic. All ignored probe output remains in this repository, never in the upstream checkout.

## Focused translated-owner tests

`machine_memory_lane_load_test.v` performs 21,600 real translated helper calls against the 600 native rows: all nine register/stack/call-record source pairs and four destination choices, including aliases of the vector operand. It uses an actual frame/module/Store with reordered memories and a high memory32 address, checking unchanged non-destination registers/call records, stack consumption, untouched memory bytes, old trap and instruction pointer. Another test covers 270 memory64 offset/end-overflow/bounds traps and the exact final 64-bit lane read. A subprocess with neither frame nor operands proves the argument invariant survives production compilation.

Private logs under `Build/audit-fixes/`:

- `source-memory-lane-load-probe.log`: clang -O0/-O2, 600 rows each PASS.
- `source-memory-lane-load-default.log`: 1/1 PASS, 4.151s.
- `source-memory-lane-load-gc-none.log`: new lane load, lane store, checked scalar load and Configuration, 4/4 PASS, 15.486s.
- `source-memory-lane-load-production-gc-none.log`: 1/1 PASS, 10.552s.

This adds the 103rd Wasm test file after the frozen 101-file verification. Full opcode/interpreter execution, SIMD widening/splat/zero consumers, instantiation and collector graph remain open. The private focused checks do not extend the earlier frozen package or native bundle evidence.
