# Source Wasm host calls and interpreter invocation

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04.

`AbstractMachine.h:521-543` maps to `machine_functions.v`. HostFunction retains
the actual callable and receives the actual Configuration plus `Span<Value>`.
`machine_arguments.v::span` borrows the real inline or outline allocation with
its `size_t` length. It allocates no copied argument array. Host writes reach
the caller's argument slots, and the callable retains its captured owner over
repeated calls.

The source `function()` getter returns `AK::Function&`. The V adapter invokes
the retained field directly through `invoke()`: returning a temporary V
closure causes the compatibility compiler to destroy it after invocation.
The focused captured-owner regression reproduced that lifetime bug, and now
checks repeated invocation with both inline and outline arguments, caller
mutation, host mutation and the actual Configuration pointer. No callable is
reconstructed for a subsequent call. Implementation and focused tests are in
`2036a551` (canonical `d513a2d3`).

`Interpreter.h:13-21` maps to `machine_interpreter.v`, including the actual
virtual operations and `AbstractMachine.h::HostVisitOps` callback. The source
visitor has an empty default body; the V base retains that exact default.
There is no default `interpret()` implementation or substitute opcode backend.

`Configuration.cpp:43-50,99-136` maps to `machine_execution.v`:

- `call()` prepares the actual Store function, preserves a missing-address
  Trap, invokes the retained HostFunction directly, or resets IP to zero and
  executes through the supplied interpreter owner.
- `execute()` passes the actual Configuration to the interpreter. Traps return
  before result or label cleanup. Success copies the frame's final result
  slots, shrinks the operand stack, reverses the returned results and shrinks
  labels only when the source frame's label remains present.
- `execute_for_compiled_call()` preserves the original Trap, verifies at most
  one result, takes that result even when its destination pointer is absent,
  and removes only the final label when one remains.

Implementation and tests are in `e460bfb3`. The tests use explicitly named
recording interpreter doubles for this virtual boundary. They exercise real
Configuration/Store/frame/argument/operand/label records, original external
Trap bytes, missing addresses, actual host callables, zero and multiple
results, already-popped labels, nullable compiled-result pointers and actual
CallFrameHandle unwind. They do not execute Wasm bytecode.

Private logs are in assignment 9's worktree:

- `source-host-span-final-recheck-{default,gc-none}.log`: the final captured
  callable regression passes in each GC mode. Neighboring function/preparation
  files passed in the preceding default batch; function/preparation/linker/table
  files passed in the preceding GC-disabled batch. Those batches also retain a
  failed diagnostic for a test assignment requiring a temporary pointer.
- `source-machine-execution-default.log`: all seven focused execution cases pass.
- `source-machine-execution-gc-none.log`: **6/6 files pass**, adding frame,
  preparation, captured callable, value-stack and Trap/result neighbors.

Result storage remains the previously documented V vector adaptation instead
of the source's two-element inline vector. Explicit owner destruction and the
incomplete collector/ref-count graph remain boundaries. BytecodeInterpreter,
native compilation/fault recovery, constant-expression execution, source
instantiation and complete browser realm ownership are unfinished. The browser
still uses its legacy Instance facade.
