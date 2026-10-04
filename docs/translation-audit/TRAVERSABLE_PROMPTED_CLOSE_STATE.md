# Prompted traversable close cancellation and append guard

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalTraversableNavigable.cpp:260–320` and
`HTML/LocalTraversableNavigable.h:48–53,84`.

A canceled prompted close previously left the actual Navigable's closing flag
set permanently. The V definitely-close method also set that flag itself,
although Source assigns it only in the outer close method. No append guard
prevented overlapping definitely-close checks from adding duplicate destruction
steps.

The translated local Traversable now owns Source's initially false
`m_close_steps_have_been_appended`. Its supported prompted-close callback clears
the actual native closing flag after cancellation only while no close steps have
been appended. A later close can therefore be attempted again. Continuing
checks test and set the guard before appending through the existing translated
session-history traversal queue. A later canceled overlapping check leaves a
previously appended close intact. The outer close retains its re-entrancy guard
and closing assignment; definitely-close now retains Source's top-level
precondition and performs no invented closing assignment.

Three cases in `html/traversable_prompted_close_test.v` attach the existing
translated local Traversable record to actual navigation-created
Page/Document/Window/Navigable/history identities. They dispatch actual trusted
activation, actual beforeunload IDL handlers and the actual WebDriver prompt
policy. No synthetic beforeunload hook supplies their results. They verify a
dismissed prompt restoring the native/typed/Window closing state and preserving
the live document, a later accepted retry queuing and unloading once, concurrent
direct definitely-close calls adding one entry without changing the outer
closing owner, ordinary outer close re-entrancy, and a later canceled check
preserving an already appended close. Existing document unload and destruction
remain the backend executed by that queue.

Default GC passed 2/2 files, including the three new cases and the existing
traversable/history suite, in
`Build/audit-fixes/source-traversable-prompted-close-default.log`.
The GC-none neighbor batch passed 6/6 files in
`source-traversable-prompted-close-complete-gc-none.log` and covers actual beforeunload,
Window closing ownership, the traversal queue, Navigable history and Document
unload. Commands use `v -old-compiler -enable-globals test`, with `-gc none` for
that batch.

This slice translates Source's prompted callback reset and append guard against
the existing in-process traversal queue. Pinned Source instead requests a close
operation through Page.history_executor and resets both fields if that operation
is abandoned before reaching its queue position. That executor/completion path,
PromptToUnload::No forced-close supersession, and UI-process descendant unload
and final unload/destroy tasks remain untranslated boundaries. The existing V
destruction backend is not certified as full Source local teardown/PageClient
parity. Checking-if-unloading-is-canceled's task ownership and timeout behavior
remain separate work, and the Document prerequisite retains pinned Source's
interactive-prompt and BiDi FIXMEs. Full Window.close incumbent/sandbox/global
task and native JavaScriptCore WindowProxy bindings remain separate.
