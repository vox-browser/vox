# Window settings cross-site ancestor ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Scripting/WindowEnvironmentSettingsObject.cpp:113–132`,
`HTML/LocalNavigable.cpp:1425–1429`, and `HTML/Navigable.h:51`.

The settings record walked its WindowModel's cached BrowsingContext parent
chain and compared locally accessible Documents. That chain can disagree with
the logical parent Navigable, so nested settings and serialized worker startup
settings could report the wrong cross-site ancestor state.

The translated Window branch now follows the source order: obtain the actual
associated Document's Navigable, return false if it has no parent, ask that
parent's `active_document_has_cross_site_ancestor()` first, then compare its
`active_document_origin()` with the current associated Document's origin.
The new Navigable method translates the LocalNavigable implementation and
reaches the actual active Document's HTML settings through the existing
Document lifecycle bridge. Source active-Document/settings preconditions remain
explicit; callers use the Navigable interface rather than requiring local
Document pointers. Worker inheritance and the data-URL branch are unchanged.

Three cases in `html/cross_site_ancestor_owner_test.v` use actual navigation
Documents/Pages/Windows/settings to verify:

- Logical parent changes control the result even when cached BrowsingContext
  parents and container Documents disagree. Both direct settings and serialized
  settings observe the change.
- A same-site leaf inherits its parent's cross-site ancestor state recursively.
  Removing that ancestor changes current Window state while a serialized
  worker environment preserves its outside snapshot.
- A real temporary Window associated-Document swap changes the logical tree
  used by its settings and by the active-document settings interface, then
  restores the prior result.

Default GC passed the three cases in
`Build/audit-fixes/source-cross-site-ancestor-owner-default.log`.
The GC-none batch passed 4/4 files, adding existing environment setup,
serialized settings, and Window/Document identity regressions:
`source-cross-site-ancestor-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, with `-gc none` for
that batch.

The native V Navigable implementation remains local and in process. Actual
remote-process replicated state and transport are separate backend boundaries;
this slice preserves their source interface instead of embedding local access
in the settings algorithm. The broader cached WindowModel BrowsingContext
accessor and full WindowProxy wrapper graph remain separate translation work.
