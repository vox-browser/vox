# Source reverse memory chunk invariant in production

Pinned `AbstractMachine.cpp:282–288` returns count immediately for zero count or invalid storage offset, then requires offset >0 before computing the reverse cage band. The V assertion was removed in production. A genuine16-byte allocated buffer accepted offset 0/count 1 and returned after the invalid offset without touching memory. `Build/audit-fixes/source-memory-contiguous-before-guard-original-production-gc-none.log` preserves 1/1 FAIL in 6.212 s and its return marker.

The explicit fatal guard remains after both Source shortcuts and before offset subtraction. Cage masking and min-count calculation are unchanged. Focused subprocesses exercise the production failure. Real empty and allocated owners cover valid shortcut ordering, positive offsets and backward overlapping moves through this helper.

Private production GC-none 1/1 PASS in 10.403 s and ordinary GC-none reverse-chunk/move/buffer3/3 PASS in 11.411 s are recorded in `source-memory-contiguous-before-guard-production-gc-none.log` and `source-memory-contiguous-before-guard-gc-none.log`. This adds the 112th Wasm test file outside frozen 103-file/native evidence; span/cage guards and runtime/collector ownership remain separate work.
