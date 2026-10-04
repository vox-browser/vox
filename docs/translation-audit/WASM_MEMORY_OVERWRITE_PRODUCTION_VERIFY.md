# Source MemoryBuffer overwrite invariants in production

Pinned `AbstractMachine.cpp:341–350` verifies offset and then count before converting the source pointer and entering the cage-chunk memcpy loop. The V implementation used an ordinary combined assertion, removed by production compilation. A real empty buffer, offset1, null source and count0 safely reproduced the missing fatal invariant: no bytes were accessed, and the old method returned. `Build/audit-fixes/source-memory-overwrite-guard-original-production-gc-none.log` records1/1 FAIL16.196s and the returned marker.

Both Source predicates now execute explicitly in their original order. Pointer conversion and the copy loop remain unchanged. Focused compiled subprocesses verify both fatal categories, including the count guard before null-source or cage access. Actual allocated storage checks empty/exact-end copies, partial writes and untouched neighbors.

Private production GC-none1/1 PASS17.717s and ordinary GC-none focused/existing buffer2/2 PASS10.494s are recorded in `source-memory-overwrite-guard-production-gc-none.log` and `source-memory-overwrite-guard-gc-none.log`. This separately committed method adds the108th Wasm test file and postdates frozen103-file/native evidence. Other invariants and the runtime/collector graph remain separate work.
