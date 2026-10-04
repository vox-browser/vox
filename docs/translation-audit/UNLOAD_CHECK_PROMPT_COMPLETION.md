# Unload-check prompt state and completion projection

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/ApplyHistoryStep.h:43–46` and
`HTML/LocalNavigable.cpp:3983–4003,4089–4096,4133–4158,4188–4209`.

Source's underlying unload-check callback receives both the result and
UnloadPromptShown. The state constructor retains an initial prompt flag, phase
results update it, and completion delivers that retained value. A separate
Source overload explicitly initializes No and projects the completion pair to
the result alone. The previous V state represented the flag as a bool but
dropped it from every callback and constructor interface.

The state now retains the translated `UnloadPromptShown` No/Yes enum and an
initial flag supplied to its constructor. Its full completion type receives
both values. Phase-two Document beforeunload calls convert Yes to the existing
DOM boolean input, and actual shown prompts update the retained enum to Yes.
Phase one retains Source's explicit false argument for its own beforeunload
call. After the existing completion guard and timer stop, finish delivers the
result and the retained prompt enum together. Deadline completion likewise
returns Continue with the prompt flag reached before the deadline.

The existing result-only check translates Source's projection closure and
initial No. The older local history-step continuation remains an explicit
compatibility projection to that result-only interface. Its underlying
Document-list method now exposes the full prompt completion for the next owner
prerequisite, but this does not fabricate Source's absent UI history job or a
Page HistoryExecutor flag sink.

Five cases in `html/unload_check_prompt_completion_test.v` use actual
navigation-created Pages/Documents/Windows, native Navigables and beforeunload
listeners. They prove actual phase-one canceled-by-beforeunload/Yes completion;
initial Yes suppressing a second phase-two prompt; empty phases retaining both
initial enum values; a partial canceled phase timing out with Continue/Yes and
completing only once after its later task; and the legitimate Source result-only
overload preserving actual cancellation. The existing timeout owner tests are
migrated to the full state callback and typed enum while retaining their timer
ordering and late-event assertions.

Default GC passed the new prompt and existing timeout files, 2/2, in
`Build/audit-fixes/source-unload-check-prompt-completion-default.log`. The GC-none
neighbor batch passed 9/9 files in
`source-unload-check-prompt-completion-gc-none.log`, adding active Window owners,
current-entry/origin gates, phase-two tasks, complete Traversable,
prompted-close, beforeunload and event-loop coverage. Commands use
`v -old-compiler -enable-globals test`, adding `-gc none` for that batch.

The native-Navigable-vector owner is a following feature. Current wrappers
still accept a local Document list, and the older history step gathers only its
translated top-level displayed-document transition. Source instead collects
the active Document of each supplied LocalNavigable before partitioning phases.
The complete UI history job, cross-process vector selection, session-history
graph/current-step protocol, Page history executor and native JavaScriptCore
bindings remain separate boundaries. This prerequisite certifies the state
callback and intentional projection, not full navigation parity.
