# Bytecode trap state and source stack-space calculation

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04.

`AK/StackInfo.h::size_free` now maps directly to `libjs/stack_info.v` and its
repository-owned frame-address intrinsic bridge. The method subtracts the
retained base from `__builtin_frame_address(0)` with source unsigned width.
The added top/base bounds clamp and approximate alloca marker were removed.
Native Darwin and Linux bound discovery remain their existing constructor
adapters; this slice does not claim the untranslated platforms or full musl
constructor handling. Implementation and tests are in `10d908df`.

The focused thread regression measures a genuine retained stack snapshot on
another actual thread, ensuring this source calculation does not fabricate
zero. The existing execution-context regression checks shrinking free space
through real recursion and actual VM stack ownership. Both files have passing
evidence in each GC mode: the thread test's final runs are
`source-stack-info-final-{default,gc-none}.log`; the execution-context file
passes in the preceding corresponding batch. The initial thread-test batch
retains a compile diagnostic for a reserved variable name. Exact AST corpus
comparison after this slice remains **100/100**.

`BytecodeInterpreter.h:22-49,116-142,153-155` and
`BytecodeInterpreter.cpp:6343-6346` map to `machine_bytecode_state.v`. The record
borrows the actual StackInfo owner and defaults its Trap variant to Empty,
matching `AK::Variant`'s Empty-aware constructor. Trap getters, clearing,
message/record setters and conditional trapping preserve their source branches.
The native-stack guard reads that actual owner's free space, defaults to two
MiB, and retains the exact `STACK-EXHAUSTION` reason.

External-resource visitation passes the actual stored 64-byte external Trap
payload to the host callback. Mutation updates the owned payload; empty,
string and uncaught-exception alternatives do not invoke the callback. The
focused tests prove this pointer identity and mutation, retained StackInfo
identity, exact failure reason and the preservation of an existing Trap when
a conditional check succeeds. Default focused verification passes;
`source-bytecode-state-gc-none.log` passes **3/3 files**, adding actual
Trap/result and interpreter-invocation neighbors.

This record supplies no `interpret()` method. Full opcode dispatch, native
entry/fault recovery, formatted diagnostic overloads, exception unwinding and
complete machine instantiation remain pending. It cannot satisfy the production
Interpreter interface until that actual execution body is translated.

The preceding host-call/invocation snapshot passes **79/79 Wasm files in each
GC mode**, recorded in `source-machine-call-full-{default,gc-none}.log`. That
full run predates this stack-space and bytecode-state slice. Logs are retained
in assignment 9's private worktree.
