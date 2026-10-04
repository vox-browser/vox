# Source branch-to-label helper

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWasm/AbstractMachine/BytecodeInterpreter.cpp:6420–6435`,
`BytecodeInterpreter.h:77–78`, and `Types.h:93`.

`branch_to_label<NeedsStackAdjustment>` now has its complete translated V
body in `machine_branch_to_label.v`. The template selection is an explicit
boolean. The helper trims actual labels by the relative index only when the
branch is selected, reads the retained target, optionally removes operands
between its saved stack height and result arity, and returns continuation
minus one. An unselected branch returns the caller's current IP. The concrete
Source instruction pointer is u32, including wrapping subtraction.

Three focused cases use real Configuration, mapped ValueStack, Label and
BytecodeInterpreter records. They cover adjustment on/off, two-valued arity,
raw NaN payload/reference preservation, real frame/module/register/trap
ownership, untaken branches in both modes, zero arity, same-label branches,
and continuation-zero wrapping. The helper neither removes a frame nor
updates configuration IP; those operations remain caller-owned.

Default focused **1/1** passes in 10.4s, focused plus existing exception/frame
GC-none **3/3** in 22.9s, and production GC-none focused **1/1** in 26.3s.
Logs are `source-branch-to-label-default.log`, `source-branch-to-label-gc-none.log`
and `source-branch-to-label-production-gc-none.log` under the private
`Build/audit-fixes/worktrees/root-source-memory-store/Build/audit-fixes/`.
These are V owner tests against the directly read source body; no native C++
differential execution is claimed.

Actual branch opcode handlers, complete instruction dispatch, compiled entry
and fault recovery, cross-frame execution and collector/realm ownership
remain unfinished. This new 99th test file is outside the historical frozen
98-file proof and does not establish a working Wasm execution backend.
