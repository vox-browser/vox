# Source MemoryBuffer fill invariants in production

Pinned `AbstractMachine.cpp:326–337` checks offset <= size and count <= size-offset before writing any chunk. Both checks were combined into an ordinary V assertion, which production compilation strips. The actual production witness uses a real empty BinaryMachineMemoryBuffer, offset 1 and count 0: no bytes are touched, but the old helper returns after the Source invariant is violated. `source-memory-fill-guard-original-production-gc-none.log` retains the genuine failure, 1/1 in 12.110 s.

The translation now executes both Source VERIFY predicates explicitly and in the original order, before subtraction and before the unchanged cage-chunk memset loop. The focused file checks both fatal guard categories in compiled subprocesses, a valid empty fill, a zero-length exact-end fill and full/partial/end fills in an actual allocated cage with neighbor bytes preserved.

Private focused evidence: production GC-none 1/1 PASS in 32.024 s (`source-memory-fill-guard-production-gc-none.log`); ordinary GC-none fill/copy guards2/2 PASS in 16.900 s (`source-memory-fill-guard-gc-none.log`). This is a separately committed completed fill-method correction and adds the 106th Wasm test. It postdates frozen 103-file/native evidence; other MemoryBuffer VERIFY methods, runtime dispatch and collector graph remain separate work.
