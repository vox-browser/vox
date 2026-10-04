# Window activation consumption through logical navigables

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.cpp:806–864,996–1000`,
`HTML/Window.h:286–290,377–378`,
`HTML/LocalNavigable.cpp:1476–1503`, and `DOM/Document.cpp:5523–5573`.
Feature commit: `a6ab0ce8`.

The translated consumption methods walked the Window's cached typed
BrowsingContext tree. This missed actual logical children hosted through
independent local contexts, retained documents that no longer had a navigable,
and took the cached Window instead of each navigable's current WindowProxy slot.

Both methods now delegate to native Window algorithms. They read the actual
associated Document's navigable, preserve the source no-navigable early return,
walk the logical parent chain to the top-level traversable, and obtain that
local top's active Document inclusive descendant navigables in source order.
Each navigable owns its active browsing-context/proxy/Window accessors, following
the source WindowProxy `[[Window]]` slot rather than the Document's retained
Window pointer. The source active-Window list is collected before mutation.
Transient consumption preserves positive infinity and changes other timestamps
to negative infinity; history consumption copies each current activation
timestamp into the same native Window's history timestamp.

The source history timestamp moves from the typed model into the actual native
Window owner. Typed history setter/getter/checks use that native record. The
separate [context/proxy identity prerequisite](BROWSING_CONTEXT_PROXY_IDENTITY.md)
supplies the actual native proxy needed by LocalNavigable's source accessors.

Four cases in `html/window_activation_consumption_test.v` verify:

- A real connected iframe inside an author shadow root, with an actual logical
  parent and a separate cached BrowsingContext, consumes top/child activation
  and history while leaving an unrelated top-level Window untouched.
- Changing the actual native child WindowProxy slot selects that current
  Window for consumption even while `Document.window` retains its original
  Window. Both native and typed history writes share the source owner.
- Clearing the current navigable preserves the source early return despite
  a retained active BrowsingContext; native and typed timestamps remain intact.
- Actual inactive child navigables and disconnected container elements are
  excluded by source active-document inclusive descendant enumeration.

All four cases passed default GC in
`Build/audit-fixes/source-window-activation-consumption-complete-default.log`.
The final GC-none batch passed 5/5 files: consumption, proxy identity,
activation-owner identity, existing CloseWatcher, and existing context/proxy
property tests: `source-window-proxy-consumption-complete-gc-none.log`.
The existing Window, context/proxy, actual navigation/Page-owner, and
associated-document files separately passed 4/4 with GC none in
`source-window-proxy-navigation-neighbors-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
the corresponding batch. Earlier diagnostics remain in their initial logs:
the missing native proxy was fixed by the prerequisite, and the new disconnected
fixture was corrected to remove its node through the existing native algorithm
and insert its siblings under one document element. Existing CloseWatcher
fixtures and source consumption conditions were preserved.

The pinned source explicitly casts the top-level traversable to the local
implementation before reading its active Document. That local active-document
precondition remains explicit; this feature does not invent a remote process
fallback for that cast. Active-Window lookup is exposed through the navigable
interface rather than requiring its callers to dereference local documents.
The in-process backend still does not implement full remote Window/proxy
transport. The separate [input picker owner slice](INPUT_PICKER_GLOBAL_OWNERSHIP.md)
and [select picker owner slice](SELECT_PICKER_GLOBAL_OWNERSHIP.md) use these
native consumption methods. Their reports retain the explicit binding and
embedding boundaries.
