# Source reverse memory chunk invariant in production

Pinned `AbstractMachine.cpp:282–288` returns count immediately for zero count or invalid storage offset, then requires offset >0 before computing the reverse cage band. The V assertion was removed in production. A genuine16-byte allocated buffer accepted offset0/count1 and returned after the invalid offset without touching memory. `Build/audit-fixes/source-memory-contiguous-before-guard-original-production-gc-none.log` preserves1/1 FAIL6.212s and its return marker.

The explicit fatal guard remains after both Source shortcuts and before offset subtraction. Cage masking and min-count calculation are unchanged. Focused subprocesses exercise the production failure. Real empty and allocated owners cover valid shortcut ordering, positive offsets and backward overlapping moves through this helper.

Private production GC-none1/1 PASS10.403s and ordinary GC-none reverse-chunk/move/buffer3/3 PASS11.411s are recorded in `source-memory-contiguous-before-guard-production-gc-none.log` and `source-memory-contiguous-before-guard-gc-none.log`. This adds the112th Wasm test file outside frozen103-file/native evidence; span/cage guards and runtime/collector ownership remain separate work.
