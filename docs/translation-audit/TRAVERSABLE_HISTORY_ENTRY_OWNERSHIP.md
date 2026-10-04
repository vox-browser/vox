# Local Traversable inherited current and active history entries

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:841–858,1116–1135`,
`HTML/LocalNavigable.h:96–99,488–491`, and
`HTML/LocalTraversableNavigable.cpp:37–43,117`.

Source initializes current and active session-history entries to one entry on
LocalNavigable. They remain distinct fields thereafter, inherited by
LocalTraversableNavigable. The V NavigableModel already translated both slots,
but the separate Traversable record read its own active snapshot and exposed no
current-entry accessor. That substituted a different owner after an actual
native Navigable had a registered local model.

Traversable current and active getters/setters now use the existing registered
NavigableModel belonging to their actual native host. A null entry from that
owner stays null; a stale Traversable slot cannot supply a replacement. Host
reassociation changes the owner selected by the accessors. Production active
entry reads use that getter, and the existing current-entry assignment in the
history application's start phase goes through the shared setter. Actual model
activation retains its previous save-old-persisted-state order before changing
the active entry.

Four cases in `html/traversable_history_owner_test.v` use real initialized
navigation Document/Page/native Navigable/local model identities for the first
three cases. They prove initial current/active identity, distinct pending
current and active entries, bidirectional typed/model updates, nullable slots
without stale fallback, and changing/restoring the actual native host owner.
The fourth case explicitly verifies the bounded bare-host adapter: it initializes
both entries together and changes them independently. The existing fresh
navigation protection fixture now captures its active entry after local model
registration, since that registration establishes the actual initialized owner.
It retains its completed traversal and fresh-navigation preservation checks.
The earlier fixture identity failure remains in
`Build/audit-fixes/source-traversable-history-owner-default.log`.

Default GC passed 3/3 files in
`source-traversable-history-owner-complete-default.log`, covering the four focused
cases, complete traversable/history tests and prompted close. The GC-none
neighbor batch passed 8/8 files in `source-traversable-history-owner-gc-none.log`,
adding actual local Navigable history, unload-check tasks, traversal queue,
event-loop and storage-state restoration coverage. Commands use
`v -old-compiler -enable-globals test`, with `-gc none` for that batch. Root's
independent storage-deserialization bridge correction `1da658c0` is present for
the latter coverage; it is a separate feature.

Older bare-host Traversable constructors still build Documents without a real
Window/Page/local model. Their active slot remains the existing adapter, and
their explicitly named legacy current slot now stays independent. Registering
an actual local model makes its initialized entries authoritative, without
copying these snapshots over that owner. Full Source Traversable/Page creation,
the session-history graph and Page history-executor protocol remain separate
boundaries. This prerequisite does not change or certify phase one's optional
origin equality/current-entry branch, current Window Navigation selection,
source timeout timer, native JavaScriptCore binding or remote-process protocol.
