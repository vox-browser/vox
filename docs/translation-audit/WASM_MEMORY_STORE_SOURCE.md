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

Typed scalar stores, `pop_and_store`, read/load helpers, SIMD lane stores and
the actual opcode interpreter loop remain untranslated consumers. Full module
instantiation, native compilation, JS realm integration and collector roots
remain separate. The historical frozen 96-file proof predates this new 97th
test file and the optional-cache correction.
