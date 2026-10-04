# Top-level BrowsingContext and Document return ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalTraversableNavigable.cpp:66–73`.

The V top-level helper returned the BrowsingContextGroup/Document wrapper from
its prerequisite unchanged. Source returns the new group's first actual
BrowsingContext and the same Document.

`create_a_new_top_level_browsing_context_and_document` now returns
`BrowsingContextAndDocument`. It calls the actual group factory, resolves that
group's first native context through its registered real typed identity, and
returns that context with the factory's Document. It creates no additional
context, Window, group, Page or realm. The actual context's group association
retains the existing group owner after the local result wrapper is gone.

Two focused cases in `html/top_level_browsing_context_projection_test.v` use
real Pages. They exercise the returned loaded about:blank, Page scripting
permission, actual Window/proxy/settings identity and the same native/typed
first member. A second call on the same Page creates separate group, context,
Document and Window identities without replacing the first returned owner.
The existing traversable registry and navigation suite is also exercised.

Default verification passed 2/2 files in 51.7 seconds in
`Build/audit-fixes/source-top-level-context-projection-default.log`.
The `-gc none` batch passed 5/5 files in 95.6 seconds, also covering the actual
group construction, existing Window/context suite and active-context identity
regressions, in
`Build/audit-fixes/source-top-level-context-projection-gc-none.log`.

This is the Source two-step return projection through the completed group
construction owner. It does not translate the following full new/fresh
top-level Traversable constructors, complete creator policy/base/opener and
ancestor-origin construction, remote group behavior, automatic Source GC
finalization or complete Traversable/UI teardown. Those boundaries remain
documented in
[`BROWSING_CONTEXT_GROUP_CONSTRUCTION.md`](BROWSING_CONTEXT_GROUP_CONSTRUCTION.md).
