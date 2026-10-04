# Source MemoryBuffer copy invariants in production

Pinned `AbstractMachine.cpp:291–302` verifies offset <= size and destination.size <= size-offset before any MemoryBuffer cage read. The previous V translation used one ordinary assert; the actual old compiler strips such assertions in production. This omitted both Source VERIFY operations in the production browser.

A compiled GC-disabled baseline safely demonstrates the missing offset VERIFY using an empty real BinaryMachineMemoryBuffer, invalid offset1 and zero-size destination. No pointer is dereferenced, but the old production helper returns and prints `SOURCE_COPY_RETURNED_AFTER_INVALID_OFFSET`. The focused test fails as expected; `source-memory-copy-to-guard-original-production-gc-none.log` is retained (1/1 failure, 7.376s). No simulated memory owner or fake native executor is involved.

The fix replaces that ordinary assert with the two Source checks in their original order, using explicit fatal panic branches. Offset is checked before subtracting it, and the destination length is checked before the original unchanged chunk-copy loop. Source verification cannot be lost through production optimization.

The completed tests compile both missing-invariant cases as subprocesses, require their exact guard category before cage access, preserve valid zero-size copies at an empty owner, and use a real allocated cage for exact-end 16-byte/four-byte copies and destination guard bytes. Production GC-none passes 1/1 in 8.903s (`source-memory-copy-to-guard-production-gc-none.log`); ordinary GC-none copy guard/zero load/lane load passes 3/3 in 10.462s (`source-memory-copy-to-guard-gc-none.log`).

This is the 105th Wasm file and follows the frozen `a85c3b92` 103-file/native verification, so it has only the focused evidence above. Other MemoryBuffer methods still need the same Source VERIFY production review; opcode/dispatch/instantiation/collector parity remains separate.
