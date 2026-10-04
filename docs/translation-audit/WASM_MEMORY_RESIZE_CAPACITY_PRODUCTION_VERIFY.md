# Source MemoryBuffer capacity resize invariants in production

Pinned `AbstractMachine.cpp:253–271` first verifies new_size >= m_size, then new_size <= reserved_capacity, before existing-handle work or the zero-capacity shortcut. The V combined assertion disappeared in production. A genuine empty owner accepted new_size1/capacity0 and returned through that shortcut without allocating anything. `Build/audit-fixes/source-memory-resize-capacity-guard-original-production-gc-none.log` preserves1/1 FAIL13.869s and the returned marker.

Both Source fatal checks are now explicit and ordered before the unchanged allocation/update branches. Subprocesses verify the capacity check and the shrink check's priority when both predicates fail. Real storage covers valid empty calls, a reserved empty owner, equal-size operations and growth with old bytes retained and the new tail zeroed. Storage handle identity survives reallocations; data addresses are not assumed stable.

Private production GC-none1/1 PASS9.368s and ordinary GC-none focused/buffer/resize3/3 PASS are recorded in `source-memory-resize-capacity-guard-production-gc-none.log` and `source-memory-resize-capacity-guard-gc-none.log`. This adds the111th Wasm file outside frozen103-file/native evidence. The remaining span/cage/reverse-chunk checks and full runtime/collector graph require separate review.
