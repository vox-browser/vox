# Source Wasm throw-handler unwinding

Feature `63e8a413` translates the complete
`BytecodeInterpreter::unwind_to_throw_handler` body in
`Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp:6437–6477`, pinned to
Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The V helper reads the actual exception from Store and searches the actual
current frame's labels from innermost to outermost, excluding the frame's root
label. It skips ordinary labels, compares tagged catches through the current
module's tag-address map, and retains source catch order. A matching handler
shrinks the operand stack to its saved height, adds fields only for a tagged
catch, optionally adds the actual exception reference, removes the handler and
inner labels, resolves the catch's relative branch target, preserves its arity,
and returns its continuation. No match removes only the current frame's labels
and returns none. Neither branch removes the frame, changes IP, nor overwrites
the interpreter's earlier trap.

`BinaryCatch.tag_index`, `label_index`, and `capture_reference` directly lower
Source's `matching_tag_index()`, `target_label()`, and `is_ref()`. V array trim
lowers the source label-vector shrink; labels own only scalar and borrowed
instruction fields. The existing source-derived ValueStack performs the actual
operand shrink, append, and remove operations. An absent stored exception is a
fatal violated precondition; Source also dereferences its required lookup.
Verified instruction arguments and relative label targets retain their source
preconditions rather than introducing recovery policies.

Three focused tests use real Store, exception, module, frame, label, and operand
stack records. They cover four tagged/catch-all/reference combinations,
reordered module tag addresses, first matching catch order, preserved signed,
reference and NaN payload bits, nonzero exception addresses, inner-handler
precedence, ordinary-label skipping, branch target arity, and a nonmatching
callee whose caller has a matching catch. The latter preserves the caller's
labels and all operands for the subsequent source caller unwind.

In `Build/audit-fixes/worktrees/root-source-memory-store`, the final focused
file passes default GC (`source-exception-unwind-three-case-default.log`) and
production GC-none (`source-exception-unwind-final-production-gc-none.log`).
The new file and existing exception/frame-owner neighbors pass **3/3 GC-none**
(`source-exception-unwind-final-gc-none.log`). The initial fixture helper used
an option propagation operator without an optional return; that compilation
diagnostic remains in `source-exception-unwind-focused-default.log`. It was
corrected before execution. Earlier two-case checks remain separate from the
final expanded fixture.

This is a direct source-body and actual V-owner check, without a native C++
interpreter or differential executable claim. The throw/rethrow opcode callers,
cross-frame re-dispatch, interpreter loop, full instantiation, compiled execution,
and collector/realm roots remain open. This 98th test file is outside the frozen
97-file verification.
