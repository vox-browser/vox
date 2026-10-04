# BrowsingContextGroup construction and actual membership ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContextGroup.cpp:44–69`,
`HTML/BrowsingContext.cpp:90–120,134–184`.

The group factory previously returned an empty `dom.Document` and a bare native
BrowsingContext. It did not construct the actual Window/global/settings, HTML
document tree, owning Page or initial loading state. Native and typed group
member lists were also independent, so an actual context could be visible to
one group interface and absent from the other.

The factory now creates the actual BrowsingContext/Document through the
existing real constructor using its Source Page, null creator and null
embedder, then appends that Document's real native context at Source step 4.
The context constructor now takes Source's Page/creator/embedder arguments and
does not append a group internally. The auxiliary caller performs Source's
explicit group append after setting is-auxiliary and before setting the opener.
Direct constructor tests likewise append through their actual caller instead
of relying on the removed hidden side effect.

The native context set owns initialized membership. Typed member queries
resolve its actual native identity handles instead of reading another actual
member list. Native append synchronizes the typed context's group association.
The existing typed append surface delegates to the native set for initialized
owners. A narrowly named pending list preserves the older pre-native typed
assembly path; actual Window/native identity registration promotes its member
into the native set and removes the pending entry. No missing Window, context,
Page, group or realm is fabricated for that adapter.

The current context-removal and explicit group-finalization adapters release
the same actual native membership, even after Document destruction clears its
browsing-context slot. Their remaining Source algorithm and GC lifetime
differences are not claimed closed. This change does not clear or replace the
logical native parent.

Four focused cases in `html/browsing_context_group_owner_test.v` use actual
Pages, contexts, Windows and Documents. They prove a populated and completely
loaded initial about:blank with real Page/settings/proxy identity, scripting
permission and one native member owner; no constructor-side append and removal
after the real Document loses its context slot; explicit pre-native adapter
promotion without duplicate membership; and genuine auxiliary creation using
the actual group and opener. The existing navigation-observer membership suite
also passed. Default verification passed 2/2 files in 47.6 seconds in
`Build/audit-fixes/source-browsing-context-group-owner-default.log`.
The wider `-gc none` batch passed 8/8 files in 198.6 seconds in
`Build/audit-fixes/source-browsing-context-group-owner-gc-none.log`, covering
the focused cases, navigation observers, existing Window/context and Page
ownership, initial completion, native navigation, traversables and cross-origin
neighbors.

This is Source group construction, caller append ordering and local membership
ownership. The top-level helper's return projection is a separate correction.
Legacy new/fresh Traversable constructors remain separate bare-document
adapters and are not routed through a fabricated Page. Complete context
creation, creator policy/base/opener/ancestor-origin fields, automatic Source
GC finalization, exact BrowsingContext removal, remote groups and complete
Traversable/UI teardown remain open. Initial context completion is documented
in [`INITIAL_BROWSING_CONTEXT_COMPLETION.md`](INITIAL_BROWSING_CONTEXT_COMPLETION.md).
