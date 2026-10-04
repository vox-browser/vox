# Auxiliary BrowsingContext logical owner and metadata

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContext.cpp:90–120,325–331`,
`HTML/BrowsingContext.h:61,110–111,125–126`,
`HTML/LocalNavigable.cpp:1476–1502`.

The V auxiliary factory selected a top-level context through cached typed
context ancestry. Source uses the opener's active Document's logical
top-level traversable and that traversable's actual active BrowsingContext.
V also represented the virtual group ID as a string derived from a group's
address and omitted the opener origin at creation.

Auxiliary creation now reads the actual opener Document and its native node
navigable, walks the existing logical top-level boundary and resolves that
owner's active native context through its registered typed identity. Its
actual group supplies Source's explicit append. Missing initialized native
owners do not select a cached typed root. Invalid/uninitialized calls retain
the V result-error adapter; Source assumes these owners exist.

The actual native BrowsingContext owns the Source `u64` virtual group ID,
initialized to zero, and optional opener origin at creation. Typed metadata
queries read that retained native owner. After appending and setting the
opener, the factory copies the active top-level context's ID and snapshots
the opener's active Document origin in Source order. The DOM report-only group
switch fixture now uses Source's numeric field type and continues to prove
that Source's corresponding FIXME does not mutate it.

Three focused cases in `html/auxiliary_browsing_context_owner_test.v` use
actual Pages, Documents and Windows. They prove logical parent ownership when
typed ancestry points at another genuine context; Source-width ID copying,
origin snapshot retention after an opener origin change and real Document
destruction; execution-time active top-level Document replacement and no
cached fallback when it becomes absent; and direct metadata reads from the
same retained native owner with Source's zero default. The existing auxiliary
fixture attaches its actual created native host to the existing Traversable
adapter instead of inventing a second group's document.

The clean default batch passed 3/3 files in 78.0 seconds in
`Build/audit-fixes/source-context-retention-auxiliary-focused-default.log`.
The final `-gc none` batch passed 10/10 files in 302.4 seconds in
`Build/audit-fixes/source-context-retention-auxiliary-gc-none.log`, covering the
focused files, full Window/navigation/traversable suites, group and retained
native identity, active-context and navigation registration, DOM group-switch
neighbors and execution-time unload ownership. The initial fixture setter
compile diagnostic and the valid navigation path exposed by
the new identity invariant remain in
`Build/audit-fixes/source-auxiliary-context-owner-default.log`; the prerequisite
owner correction is documented in
[`BROWSING_CONTEXT_NATIVE_IDENTITY_RETENTION.md`](BROWSING_CONTEXT_NATIVE_IDENTITY_RETENTION.md).

This closes the bounded Source auxiliary active owner selection and steps 8–9
metadata. Creator-construction ID/base/policy copying is separate. The existing
typed top-level Traversable cache, auxiliary cache assignment and old new/fresh
Traversable construction adapters remain incomplete; genuine selection does
not depend on them. Complete realm/wrapper-world construction, remote owner
transport, automatic GC lifetime and full Traversable/UI teardown remain open.
