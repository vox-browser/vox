# Source Wasm SIMD lane-store helper

Upstream is `963d46a829f3e1b79f44dba9d02afb70654300fa`.
`machine_memory_lane_store.v` translates
`BytecodeInterpreter.cpp:6816–6825` directly. Feature `8d941ac7` preserves
MemoryAndLaneArgument extraction before any operand access, then takes the
u128 vector from Any source0, borrows its selected lane, takes address source1
and calls the actual checked store helper. Source's constant N is represented
by the corresponding unsigned lane primitive, with sizeof(T) equal to N/8.
Only the four upstream-instantiated widths 8/16/32/64 are accepted.

The verifier owns lane-index, alignment and memory-index validation, as in
Source. This helper adds no clamping or replacement validation algorithm.
Existing machine Value's two-word u128 and fixed raw temporary provide the
immediate byte view. Source's pointer arithmetic is lowered onto that original
fixed owner. Destination and IP remain untouched; stack vector/address are
consumed in order, including a subsequent checked-store trap. Register and
call-record sources are retained. Actual frame/module/Store ownership,
memory32 narrowing, memory64 width, overflow branches and prior-trap behavior
come from the already translated actual store helper.

Tool `7c5f626a` validates pinned interpreter/Types bytes and clean upstream
AK/LibWasm/Core/Sync sources, copies the original lane-pointer statement, and
compiles it with actual AK u128, BitCast and ReadonlyBytes. MemoryIndex's actual
distinct-ID macro and both original nested argument declarations are extracted
verbatim into a declaration-only enclosing shell. No configuration,
Instruction object or interpreter is replaced by this probe.

An initial full Types.h compilation stopped before execution because this
upstream build lacks generated LibSync/Export.h. That diagnostic remains in
`source-memory-lane-store-probe.log`. The selected original declarations avoid
that unrelated generated-header dependency without changing the pointer body.
Both -O0 and -O2 then pass 600 exact views: twenty u128 patterns, all thirty
valid lane/width combinations, identical bytes in both profiles. The corrected
log is `source-memory-lane-store-probe-corrected.log`, and
`webassembly/fixtures/memory_lane_store.tsv` retains both actual Source hashes.
This verifies native lane layout on the actual AArch64 target, not full Source
class layout, endian ABI on other targets, or interpreter execution.

Focused tests match every native view through all nine actual value/address
source combinations: 5,400 stores with guard bytes, untouched other memory,
nonidentity module-to-Store addresses, real stack consumption and retained
register/call-record/destination/IP/trap state. Memory64 high addresses and both
checked-overflow paths consume operands without touching any memory byte.
An exact-end final high-u64 lane succeeds. A compiled invalid-argument child
uses an empty stack to prove that the fatal argument guard precedes operand
access even in production.

In the private root-source-memory-store checkout, the new file passes default
GC (15.20s). New lane/typed/checked-store/Configuration neighbors pass 4/4
GC-none (30.02s), and the new file passes production GC-none (23.89s).
Logs are `source-memory-lane-store-{default,gc-none,production-gc-none}.log`.
No canonical integration or native browser build is claimed by these private
checks; the new 102nd file is outside the frozen 101-file proofs.

Actual SIMD opcode dispatch, lane/widening/splat/zero loads, remaining SIMD
operators, full execution/instantiation and collector/realm roots remain open.
