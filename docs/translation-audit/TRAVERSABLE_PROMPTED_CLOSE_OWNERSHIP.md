# Prompted-close native input collection and caller ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalTraversableNavigable.cpp:279–321`,
`HTML/LocalNavigable.cpp:4203–4209` and
`DOM/Document.cpp:5522–5573`.

Prompted close previously collected active Documents starting from the
Traversable's retained adapter Document, then called the older Document-list
check. Real navigation could replace the native active Document while that
snapshot remained old, causing the actual current Document and its descendants
to miss beforeunload. It also allowed the old per-Traversable document hook to
replace actual Source checks.

The actual local owner path now reads the native inherited active Document,
collects its existing inclusive descendant Navigables, and calls the translated
native-vector result-only Source overload. The state owns invocation-time
active-Document selection for those hosts and uses null-document phase-two
tasks, while Source's simpler completion projection initializes No and returns
the result only. The once-append guard, canceled-close reset and outer closing
write order remain unchanged.

Only older bare-host constructors without a local NavigableModel use the
previous Document-list/hook compatibility path. This does not apply that hook
to actual local Window/Page owners or manufacture missing models for bare
records. Source's actual active-Document precondition is retained on the local
path.

Three cases in `html/traversable_prompted_close_owner_test.v` prove actual
replacement-Document beforeunload while the old adapter snapshot and hook
disagree; actual current-document iframe traversal and descendant cancellation;
and the explicitly preserved bare-host hook path. The real fixtures observe
native closing state and Window.closed, actual trusted sticky activation,
WebDriver dismissal, null-document queued tasks, and cancellation leaving the
history queue empty without destroying the current document tree. Existing
prompted-close tests retain cancellation/retry, overlapping checks and one
append/unload behavior.

The focused default file passed in
`Build/audit-fixes/source-traversable-prompted-close-owner-complete-default.log`.
The original default batch's existing Traversable and prompted-close files
passed, but its new child fixture failed before close because chained
`current.body()?.as_node()` mutated a temporary rather than the retained body
Node. The fixture now selects that body into a stable local before mutation,
matching existing proven fixtures, and explicitly asserts real document
ancestry before collection. The original 2-pass/1-fail evidence remains in
`source-traversable-prompted-close-owner-default.log`.

GC-none passed 10/10 files in
`source-traversable-prompted-close-owner-gc-none.log`, adding native-vector checks,
phase-two and timeout ownership, native activation consumption, current child
tree ownership, beforeunload and event-loop coverage. Commands use
`v -old-compiler -enable-globals test`, adding `-gc none` for that batch.

The existing in-process queued unload/destroy continuation remains separate
from Source's Page HistoryExecutor request and UI-delivered close unload task.
Its retained Document reads, forced-close handling, abandoned-operation
completion, UI tab removal, full local teardown and remote transport remain
separate work. This commit translates prompted input collection and its actual
Source check caller, not complete close execution or Window.close bindings.
