# Source checked memory loads and scalar reads

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp:6480–6502,6864–6886`,
`BytecodeInterpreter.h:80–81,134–135`, and `AK/Endian.h`.

`machine_memory_load.v` translates the complete `load_and_push` helper for the
existing numeric machine records. The instruction's actual MemoryArgument
selects the current frame's module memory address, which resolves through the
owning Store. Its address operand is borrowed through the existing
Configuration SourceAddressMix routing. Memory32 truncates the stored
sign-extended operand to u32; Memory64 retains u64. Both Checked<u64> additions
(offset and read width) and the memory-size check occur before the memory read
or operand replacement. Failure installs the exact bounds trap and preserves
the address operand. Success leaves an earlier trap unchanged.

Source overwrites that borrowed operand with the loaded Value. It does not
consume a stack operand, push a new result, or write the destination mapping.
All 14 scalar Source ReadType/PushType combinations and the full u128 load are
supported. Signed/unsigned narrow reads and PushType casts retain their source
widths; f32/f64 preserve the actual bit patterns. The existing two-word
BinaryMachineValue represents Source u128 without introducing another vector
or reference format.

The `read_value` lowering uses V's existing standard little-endian primitive
and floating bit-cast functions. Their byte view handles both aligned and
unaligned data, replacing Source's aligned temporary/memcpy and packed
LittleEndian pointer branches. It does not introduce an independent decoding
algorithm. The Source minimum-span VERIFY remains an explicit fatal guard in
production. Source's physical native alignment/temporary layout and the V byte
view are different representations; verification here runs on little-endian
macOS/AArch64 and does not certify every target ABI.

The separately reviewable `tools/source_wasm_memory_read_probe.py` verifies the
upstream pin, exact interpreter contents and clean AK headers. It extracts all
three original `read_value` bodies verbatim, including the two float
specializations. A minimal declaration supplies their enclosing class; the
actual AK Endian/Span/BitCast/UFixedBigInt headers and existing AK build are
used. This exercises those real method bodies, rather than a replacement
reader, and does not instantiate the complete Source interpreter/fault graph.
At both -O0 and -O2, 3,520 observed integer/float/u128 reads match exactly across
20 boundary, sign, infinity and NaN patterns and 16 byte offsets. Actual
short-span native calls abort through VERIFY in both profiles. The checked-in
TSV retains the native observations and Source file hash.

Four focused V cases compare every native observation, exercise all four real
operand modes with swapped module/Store memory indices and distinct destination
slots, distinguish signed/unsigned i32-to-i64 extension, check Memory64 and both
overflow boundaries, preserve stack/IP/trap state, and run a genuine child for
the production minimum-span guard. Default GC passes 1/1
(`source-memory-load-checked-default.log`, 18.58s); the load/store/Configuration
batch passes 3/3 GC-none (`source-memory-load-final-gc-none.log`, 30.02s), and the
final production GC-none file passes 1/1
(`source-memory-load-final-production-gc-none.log`, 35.85s). Native probe
evidence is `source-memory-read-probe-verified.log` with artifacts under
`source-wasm-memory-read-probe/`, all in the private worktree's
`Build/audit-fixes/`.

Initial generic-name/sum narrowing compiler diagnostics and a production test
union-address annotation diagnostic remain retained. The final explicit unsafe
union borrow and concrete MemoryArgument extraction preserve Source's verified
operand contract; no invented validation result replaces it.

The real opcode handlers, interpreter dispatch loop, native fault recovery,
SIMD widening/lane/splat loads, typed stores, complete instantiation and the
collector/realm graph remain separate work. No successful Wasm export result
or partial `interpret()` substitute is supplied. This new 100th test file is
outside the frozen 99-file package proof and requires its own integration
checks.
