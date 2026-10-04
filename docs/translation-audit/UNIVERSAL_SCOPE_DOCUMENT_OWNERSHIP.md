# UniversalGlobalScope queue-time document ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/UniversalGlobalScope.cpp:95–104,198–216`,
`HTML/EventLoop/EventLoop.cpp:774–805`, and `HTML/UniversalGlobalScope.h`.
Feature commit: `74660616`.

The translated mixin retained a document snapshot supplied during construction.
Microtasks and rejected-promise notification tasks consequently kept using the
original document after the actual Window acquired a different associated
document. A special construction-time refresh hid the same divergence for
globals created before their Document.

The snapshot and its constructor argument are removed. Both queue paths now
read the actual event target's source Window identity and its current native
associated-document record when queuing. Worker and other globals supply no
document. The obsolete construction refresh is removed, and the existing
Window/Worker settings and focused fixtures use the source-owned association.
Each queued Task retains the document captured at that moment; later Window
reassociation does not retarget a previously queued microtask.

The existing microtask helper still uses the implied main-thread event loop,
matching the pinned `queue_a_microtask()` implementation. Rejected-promise
notifications retain their actual global's responsible event loop, matching
`queue_global_task()`. The callback, rejection dispatch, cancellation, weak-set
tracking, and exception-reporting paths remain the existing translations.

Four cases in `html/universal_scope_document_owner_test.v` verify:

- Native Window reassociation between two actual documents, queue-time Task
  identity for both microtasks, and execution after the original association is
  restored.
- A real Window global and settings created before its Document, followed by
  document construction and a microtask using the same retained mixin and the
  actual later association.
- A rejected-promise notification queued on the current document, with its
  runnable state following that document's actual logical parent navigable.
  An inactive parent defers the task; restoring the parent's active document
  permits real Window dispatch with the same native current Event, canceled
  exception reporting, and outstanding-rejection tracking.
- Actual WorkerGlobalScope settings, document-less microtasks, document-less
  rejected-promise tasks on the worker loop, and actual exception reporting.

All four cases passed with default GC and `-gc none` using
`v -old-compiler -enable-globals test`:
`Build/audit-fixes/source-universal-scope-document-complete-default.log` and
`source-universal-scope-document-complete-gc-none.log`.
The existing UniversalGlobalScope, event-loop rejection, IndexedDB cleanup,
and cached queuing-strategy callback files also passed the GC-none batch in
`source-universal-scope-document-gc-none.log`; that initial batch's fifth file
was the new fixture before its Worker-close spelling and child navigable flag
were corrected, and the final focused runs above validate those corrections.

This slice translates queue-time document ownership. The existing V microtask
callback representation is still `fn ()`, rather than the complete generated
WebIDL callback invocation and JavaScript `queueMicrotask` binding. Worker agents
remain the translated in-process backend; this change does not claim complete
LibJS agent/VM scheduling or replace the source helper with a new worker
microtask algorithm.
