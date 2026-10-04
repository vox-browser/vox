# Source Wasm checked memory stores

`machine_memory_operation.v` translates the raw-byte store overloads and
address projection in pinned `LibWasm/AbstractMachine/BytecodeInterpreter.cpp`.
Upstream remains `963d46a829f3e1b79f44dba9d02afb70654300fa`.

| Source | V |
| --- | --- |
| `memory_base_address`, lines 348–356 | `binary_machine_memory_base_address` reads Value's low u64, narrows only memory32 operands to u32, and retains the complete memory64 address. |
| `store_to_memory(Configuration&, MemoryArgument, ReadonlyBytes, Value)`, lines 6827–6840 | `store_to_memory` resolves the current frame's module memory index through the actual Store, checks base-plus-offset overflow and forwards the original byte span. |
| `store_to_memory(MemoryInstance&, u64, T)`, raw `ReadonlyBytes` specialization, lines 6842–6862 | `store_to_memory_instance` checks address-plus-byte-count overflow and the actual used memory size before the existing live MemoryBuffer overwrite. |

Source `Checked<u64>` additions are lowered to explicit overflow predicates.
Both failing branches install the original `Memory access out of bounds` trap
and return true before writing. Successful stores return false and retain any
preexisting trap. Zero bytes at the used-memory end are valid; zero bytes beyond
that end still trap. The original source/destination pointer and usize byte
count are retained, including zero bytes at an empty memory. No native Source
interpreter executable or C++ differential fixture is claimed for this slice.

Three focused cases exercise real primitive storage, Store and frame owners:
embedded NUL/high bytes at both memory edges, growth, unchanged prior traps,
zero-sized memory, end overflow, complete unchanged bytes after rejected writes,
module indices differing from Store addresses, memory32 sign-extension undo,
memory64 high-address rejection without truncation, offset overflow and
unchanged IP/value-stack state.

In `Build/audit-fixes/worktrees/root-source-memory-store`, the new file passes
default GC (`source-memory-store-private-default.log`). It and existing memory
and frame neighbors pass **3/3 GC-none**
(`source-memory-store-private-gc-none.log`). An initial production batch failed
at four existing package compilation diagnostics before execution
(`source-memory-store-private-prod-gc-none.log`). Separately committed safe
allocation/import annotations and the corrected optional cache lookup remove
those package blockers. The subsequent six-file production GC-none batch
records **4 pass /2 fixture compilation failures**: the new store file,
arguments, memory and frames all pass; existing cache/module test map accesses
needed explicit guards. Those test-only guards subsequently pass **2/2**
(`source-cache-module-private-prod-gc-none-recheck.log`). The original failed
logs are retained; this is passing evidence across runs, rather than a single
clean six-file production invocation.

At this raw-helper snapshot, typed scalar stores, `pop_and_store`, read/load
helpers, SIMD lane stores and the actual opcode loop remained pending. Full module
instantiation, native compilation, JS realm integration and collector roots
remain separate. The historical frozen 96-file proof predates this new 97th
test file and the optional-cache correction.

## Actual typed pop-and-store helpers

Feature `82a8d43f` translates Source `ConvertToRaw` (lines 330–348),
`pop_and_store` (6798–6805), and `store_value` (6807–6814) in
`machine_memory_typed_store.v`. All ten Source-instantiated combinations are
retained: i32/i64 full stores, f32/f64, i32 to i8/i16, i64 to i8/i16/i32,
and u128. Source extracts the PopT operand before narrowing it to StoreT,
then consumes the address operand with Any routing. Both stack operands are
consumed even when the subsequent checked memory helper traps. Register and
call-record operands remain in place; no destination write or IP change occurs.

The StoreT temporary's raw byte view delegates directly to the actual checked
helper above. Existing V endian and float-bit primitives lower Source
LittleEndian and bit_cast temporaries; the existing two-word machine Value
represents u128. This byte-array boundary differs physically from a C++ local
temporary. No allocation/OOM or big-endian native ABI equivalence is implied,
and no replacement memory engine or independent encoding algorithm is added.
The MemoryArgument unsafe_get guard remains fatal in production.

Tool `15033545` validates the exact pinned interpreter bytes and clean AK
headers, extracts all three original ConvertToRaw bodies verbatim, and compiles
them with real AK Endian/BitCast/UFixedBigInt headers and liblagom-ak.
Both -O0 and -O2 pass 200 observations with identical temporary bytes, including
signed narrowing, infinities, quiet/signaling NaN payloads and u128 high words.
`webassembly/fixtures/memory_store.tsv` retains the actual source pin/hash and
native bytes. This is a native conversion probe, not a full Source interpreter
execution or lifetime probe.

The focused file runs all 200 observations through actual Configuration,
frame, module and Store owners using all nine value/address register, stack and
call-record combinations (1,800 writes). Module indices deliberately differ
from Store addresses. Guard bytes, unchanged other memory, memory32 narrowing,
actual operand consumption, untouched registers/call records/destination/IP and
prior trap preservation are checked. Rejected memory64 high addresses and both
overflow branches leave every memory byte unchanged while consuming operands.
Exact-end stores remain valid after actual memory growth.

Default focused checks pass 1/1 (5.42 seconds), and the new/load/checked-store/
Configuration neighbor batch passes 4/4 GC-none (17.23 seconds). After adding
the compiled fatal-argument child, the final focused file passes 1/1 default
(6.77 seconds) and 1/1 production GC-none (11.05 seconds). Logs are
`source-memory-typed-store-{default,gc-none,final-default,production-gc-none}.log`
in the private root-source-memory-store checkout. The native probe log is
`source-memory-typed-store-probe.log`. The broader frozen 99-file proof predates
this new 101st file and the separately translated 100th load file.

Actual opcode/native dispatch, SIMD lane stores, complete module instantiation,
JS realm integration and collector roots remain unfinished. The typed helpers
do not establish a working complete Wasm interpreter.
