# Window user-activation timestamp identity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.h:283–290,373–378`,
`HTML/Window.cpp:770–812,842–864`, `HTML/UserActivation.cpp:31–43`, and
`HighResolutionTime/TimeOrigin.cpp:72–96`.
Feature commit: `20531c1d`.

The translated HTML Window model kept a private last-activation timestamp in
addition to the actual native Window's timestamp. The model used absolute
monotonic milliseconds for activation checks, whereas native Window and
UserActivation used the source document-relative high-resolution clock. Native
activation and typed settings/navigation queries could therefore disagree.

The duplicate timestamp is removed. The typed setter and timestamp getter use
the actual native Window record; sticky and transient checks delegate to its
existing source high-resolution-time implementation. History-action comparison
now reads that same last-activation timestamp. Both the native last-activation
record and the typed history-action timestamp begin at source positive infinity.
The former `1e308` sentinel compared unequal to positive infinity, causing
consumption of a never-activated Window to mark it permanently sticky.

Three cases in `html/window_activation_identity_test.v` use actual
navigation-created Documents, Pages, Windows, and settings to verify native
and typed setter identity, UserActivation getter agreement, settings and source
navigation-snapshot gates, transient expiration, persistent sticky activation,
history-action consumption, and source positive/negative infinity semantics.
Existing snapshot and UserActivation fixtures now supply their timestamps in
the source relative clock instead of assuming absolute monotonic time or zero.

Default GC passed the three focused cases in
`Build/audit-fixes/source-window-activation-identity-default.log`.
The GC-none batch passed 6/6 files, including those cases, source navigation
snapshots, UserActivation, CloseWatcher, native fullscreen eligibility, and the
Window virtual-dispatch override:
`source-window-activation-identity-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
the corresponding batch.

This feature unifies the activation owner and checks. The separate
[trusted activation notification slice](TRUSTED_ACTIVATION_CLOCK.md) fixes the
native EventTarget notification clock. The separate
[logical navigable consumption slice](WINDOW_ACTIVATION_CONSUMPTION.md) replaces
the cached BrowsingContext traversal with the source active-document inclusive
descendant navigables and actual WindowProxy Window lookup. Input and select picker models
also retain explicitly supplied activation/security state. These remaining
paths are not certified by the timestamp-identity regressions.
