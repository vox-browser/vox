# Source Wasm instruction storage

`3841f91b` translates `InstructionStorage` from the pinned Ladybird `Types.h` and `AbstractMachine/BytecodeInterpreter.cpp:6888–6909`. The upstream checkout was read-only.

Appending uses the source chunk capacity clamp: 8, 8, 16, 32, 64, 128, 256, then 512 per later chunk. Each chunk allocates its fixed slot array once. Returned references keep the actual stored instruction and remain stable while the outer chunk vector grows. Empty slots use the source UINT32_MAX opcode sentinel rather than an independent optional record. Assignment populates one slot, advances its index and total size, then returns that exact slot.

The defaulted C++ move transfers its chunk vector and copies scalar state, leaving the moved-from scalar members intact. V exposes explicit move construction and assignment with that behavior. It cannot enforce the C++ deleted copy operations. V array/variant reclamation and automatic Module destruction remain part of the pending lifetime graph; this slice does not establish source no-GC cleanup of all instruction argument payloads.

Two source cases pass with both GC modes, checking 1,537 actual instruction slots, chunk boundaries, pointer stability and mutation, the exact empty sentinel, and move/assignment alias identity. Frame and binary-instruction neighbors pass with GC disabled. Private logs are `source-instruction-storage-{default,gc-none}.log` under assignment 9's `Build/audit-fixes/`.

This is the actual storage used by the source compiler, not an instruction compiler or executor. Compiled dispatch generation, Configuration, native compilation and interpreter invocation remain open.
