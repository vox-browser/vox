# Local Navigable and Traversable destroyed-state ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Navigable.h:36`,
`HTML/LocalNavigable.h:222–223,536`,
`HTML/LocalNavigable.cpp:682–689` and
`HTML/LocalTraversableNavigable.cpp:375–379`.

Source LocalTraversable inherits the LocalNavigable destroyed flag and virtual
query. V's Traversable and local NavigableModel instead stored separate flags.
Traversable destruction set its own flag before removing the local model,
leaving a retained real model reporting live. Source navigation guards could
then disagree with the Traversable after removal from the registry.

The actual native Navigable now owns the one local destroyed-state flag.
Local NavigableModel and Traversable queries read that same native owner.
Their former independent flags are removed. The local setter's flag write and
Traversable destruction's existing early guard/write select that owner;
registry removal cannot erase it. Existing navigation, post-fetch,
cross-document finalization and Traversable history guards now use the shared
query. No missing owner is fabricated: a Traversable query requires its actual
native host, as its existing closing query does.

Four cases in `html/navigable_destroyed_owner_test.v` use actual
navigation-created Pages/Documents/Windows, registered local models and native
hosts. They prove local-model updates reaching the native/Traversable queries;
actual Traversable destruction retaining the destroyed flag on a model held
after registry removal; navigation issuing no fetch or queued work through that
retained destroyed model while history guard callbacks still complete; and
the existing host reassociation adapter selecting another real native flag
without copying a stale Traversable flag over it. Source's single flag remains
observable even when the native active Document is null.

The focused default batch passed 3/3 files: the new owner regressions and the
existing Navigable and Traversable suites. Its log is
`Build/audit-fixes/source-navigable-destroyed-owner-default.log`.
The wider GC-none batch passed 9/9 files in 443.5 seconds, covering these suites
plus prompted close and its real-owner regressions, current-history ownership,
the native unload-check vector, the event loop and actual WindowProxy identity.
Its log is `Build/audit-fixes/source-navigable-destroyed-owner-gc-none.log`.

This is the inherited flag ownership prerequisite. It preserves the older
local setter's existing pending-main-thread-scroll resolution and Navigation
notification, and preserves the current Traversable adapter's early destroyed
write. Neither is a claim of complete Source setter timing or side-effect
parity. Pinned Source cancels its hover timer, destroys its compositor context,
sets the flag, resolves pending async scroll operations and cancels user-scroll
settlement. Those native scroll/compositor/hover owners and the unsupported
Navigation-notification substitution remain separate correction work. Full
local teardown, BrowsingContext removal, PageClient close notification, UI
history executor, forced close and remote destroyed-state replication are also
separate boundaries.
