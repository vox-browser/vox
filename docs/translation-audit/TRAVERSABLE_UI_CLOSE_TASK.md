# Traversable UI close unload task

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalTraversableNavigable.cpp:327–338`.

The actual Source `run_ui_traversable_close_unload_task` entry point was missing
from the V Traversable. The existing in-process close continuation belongs to a
separate compatibility path: it reads an older Document snapshot and performs
its own descendant unload recursion. That continuation does not implement the
Source UI-delivered task.

The new entry point queues a NavigationAndTraversal task with no Document and
no explicitly supplied event loop, matching Source. Its closure reads the
Traversable's inherited actual active Document when it executes, calls that
Document's existing `unload()` operation if present, and then calls the existing
`destroy_top_level_traversable()` helper. It adds no fully-active gate, no
descendant unload recursion, no prompt check and no session-history append.
Source's precondition remains that the UI has already unloaded descendants.

Four cases in `html/traversable_ui_close_task_test.v` use actual navigation-created
Pages, Documents, Windows, native Navigables and registered local models. They
prove asynchronous null-document task metadata, one actual Window unload with
its legacy Document target before the native destroyed flag changes, and no
compatibility history append; actual navigation replacement after queuing,
selecting the replacement while an old Document-owned task remains blocked;
survival of actual Document destruction with a null active Document and final
Traversable destruction without unload dispatch; and no fully-active check on
a native-selected Document whose node Navigable has been detached through its
real setter. No test fabricates a replacement Window or synthetic UI executor.

The focused default file passed in 72.5 seconds, including four genuine owner
cases. Its log is
`Build/audit-fixes/source-traversable-ui-close-task-default.log`.
The wider GC-none batch passed 7/7 files in 412.2 seconds, adding inherited
destroyed-state ownership, the existing Traversable and prompted-close suites,
prompted-close real-owner checks, phase-two unload-task ownership and the event
loop. Its log is `Build/audit-fixes/source-traversable-ui-close-task-gc-none.log`.

The entry point is callable by the actual owner but does not fabricate a UI
transport or HistoryExecutor, and the older compatibility close queue is not
rerouted through it. The existing `Document.unload()` implementation remains its
own translation boundary. The final destruction helper still lacks complete
Source `destroy_local_traversable()` teardown: actual BrowsingContext removal,
owning PageClient close notification, full hover/compositor/async-scroll cleanup
and Source end-of-teardown write order are open. Forced close, abandoned history
operation completion, remote transport and WebDriver BiDi are separate work.
The shared native flag prerequisite is documented in
[`NAVIGABLE_DESTROYED_STATE_OWNERSHIP.md`](NAVIGABLE_DESTROYED_STATE_OWNERSHIP.md).
