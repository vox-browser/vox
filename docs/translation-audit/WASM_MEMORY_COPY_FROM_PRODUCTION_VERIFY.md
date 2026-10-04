# Source MemoryBuffer copy_from invariants in production

Pinned `AbstractMachine.cpp:306–322` executes four VERIFY checks in order: source offset, source count, destination offset, then destination count. All precede the actual-owner alias shortcut and the cage-chunk copy loop. The V implementation combined them into ordinary assertions, which production compilation strips.

The genuine pre-fix production witness uses actual empty source and destination buffers, source offset1 and count0. It touches no bytes, but incorrectly returns after violating the Source invariant. `Build/audit-fixes/source-memory-copy-from-guard-original-production-gc-none.log` records 1/1 FAIL in12.730s and the returned marker. The repaired implementation preserves each Source predicate and its ordering with explicit fatal guards; the alias dispatch and chunk loop are unchanged.

The focused tests exercise all four compiled fatal categories, including the source-offset check before self-alias dispatch, valid empty and exact-end copies, separate real cage owners, untouched neighbors, and forward/backward overlapping copies through the actual alias path. Private production GC-none1/1 PASS20.518s and ordinary GC-none focused/existing buffer2/2 PASS11.810s are recorded in `source-memory-copy-from-guard-production-gc-none.log` and `source-memory-copy-from-guard-gc-none.log`.

This completed method adds the107th Wasm test file. It postdates the frozen103-file Wasm/native proof; remaining MemoryBuffer invariants, runtime dispatch and collector ownership still require their own review and evidence.
