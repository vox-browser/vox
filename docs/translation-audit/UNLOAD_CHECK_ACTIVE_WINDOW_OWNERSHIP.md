# Unload-check active Window and global task ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:1381–1386,1476–1502,4040–4094`
and `HTML/EventLoop/EventLoop.cpp:774–786`.

Phase one previously queued a document task using the Traversable's retained
Document snapshot, then dispatched Navigation through a separately supplied
optional object. Source queues a global task using the actual active Window,
reads the active Document when beforeunload executes, and reads the actual
active Window again after beforeunload to select its Navigation API.

The Traversable now exposes its inherited native active Document and active
Window owners. Window lookup follows the existing native Navigable's active
Document, BrowsingContext and WindowProxy, then resolves that proxy's actual
registered WindowModel. A null native active Document remains null rather than
using a stale adapter snapshot. This uses existing native proxy identities;
there is no cast from a bare DOM proxy to a larger model and no fabricated
Window or Navigation object.

The real Window path queues through the existing `queue_global_task()` helper,
which retains the queue-time global's associated Document. At execution it
re-reads the native active Document for beforeunload, preserves the prompt
result and canceled-by-beforeunload return, then re-reads the actual active
Window's Navigation. Source's active Document, active Window and target-entry
preconditions are retained. Canceled traverse events still produce
canceled-by-navigate, and otherwise proceed to the translated phase-two tasks.

Six cases in `html/unload_check_active_window_owner_test.v` use actual
navigation-created Pages, Documents, Windows, local Navigable models and native
WindowProxy records. They prove:

- Actual Navigation selection without supplying the old optional adapter.
- Queue-time global association survives a temporary Document reassociation.
- Native proxy retargeting after queuing selects the replacement Window's
  genuine cancellable Navigation event, ignoring a stale supplied Navigation.
- Beforeunload can retarget the native proxy, and the later traverse event
  selects the replacement Window rather than the original one.
- Real cross-document navigation replacement changes both execution-time
  beforeunload and Navigation owners while a distinct actual queue-time global
  Document keeps that task runnable.
- Removing the native active Document returns null for the inherited Document,
  Document ID and Window owners even while an old adapter snapshot remains.

Default GC passed the focused file and the complete Traversable suite, 2/2
files, in `Build/audit-fixes/source-unload-check-active-window-owner-default.log`.
The GC-none neighbor batch passed 10/10 files in
`source-unload-check-active-window-owner-gc-none.log`, adding current-entry/origin
gates, shared history ownership, phase-two tasks, actual beforeunload, native
proxy identity, navigation-created document registration, complete Window
context and event-loop coverage. Commands use
`v -old-compiler -enable-globals test`, adding `-gc none` for the ownership batch.

The older bare-host Traversable constructors still lack an actual Window/Page
creation path. Their document-task and explicitly named `legacy_navigation_`
adapter are preserved as that boundary; actual Window owners never select it.
Other history/close phases still contain retained Traversable Document slots and
are separate source ownership work. Input remains the translated local
Document list rather than Source's complete native Navigable vector. The
15-second Source timeout, session-history graph/current-step protocol, Page
history executor, remote transport and native JavaScriptCore BeforeUnloadEvent
binding remain separate boundaries. This slice does not claim full traversal
or Window.close parity.
