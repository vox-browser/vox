# Unload-check phase-two task ownership and validity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:4115–4167`.

The translated phase-two unload check associated each navigation-and-traversal
task with the retained Document. If an actual navigation made that Document
inactive before execution, the task became unrunnable and the check's callback
never completed. Destroying the Document could instead remove the task during
document cleanup. The V callback also omitted Source's execution-time validity
check.

Pinned Source deliberately queues null-document tasks here, then skips a
Document which has been destroyed or is no longer fully active. Both skipped
and dispatched Documents count toward the same remaining-task counter. The V
phase now translates that task owner, validity check and completion order while
retaining the existing check state's single completion guard and shared prompt
shown/final-status fields.

Three cases in `html/unload_check_task_ownership_test.v` use real
navigation-created Pages, Documents, Windows and native Navigables. An actual
replacement navigation preserves the native Navigable but makes the old
Document inactive after enqueue; the null-document task still executes, skips
dispatch and completes once. Destroying a real Document likewise leaves this
task available through the actual Document task-removal path and completes
without dispatch. A three-Document input queues actual null-document tasks,
fires beforeunload on both live Documents, skips the destroyed one, retains the
actual sticky-activation/WebDriver cancellation result, and completes only
after all three tasks. Reprocessing the event loop leaves each completion count
at one.

Default GC passed 3/3 files, including the three focused cases, traversable
history and prompted close, in
`Build/audit-fixes/source-unload-check-task-owner-default.log`.
The GC-none neighbor batch passed six files in
`source-unload-check-task-owner-gc-none.log`, covering actual beforeunload,
prompted close/history, the existing traversal queue and Window/Document
identity. Its seventh file, `html/event_loop_test.v`, exposed the existing
history-state restoration failure at line 344 (`null_` instead of `string`).
The Document deserialization bridge reconstructs a record from data alone,
discarding the storage type after the LBSC storage codec translation; that
independent bridge correction is not included in this task-owner feature.
The complete failure remains in the same log. Commands use
`v -old-compiler -enable-globals test`, with `-gc none` for that batch.

This fixes the retained-document ownership and validity checks in phase two.
The existing V interface still accepts retained Documents rather than Source's
local Navigable vector. Phase one's origin branch and current Window Navigation
owner, the source timeout timer, and the full history-executor/remote-process
protocol remain separate work. The actual Document beforeunload prerequisite
retains pinned Source's interactive prompt and BiDi FIXMEs; this slice does not
claim native JavaScriptCore event bindings or full Window.close parity.
