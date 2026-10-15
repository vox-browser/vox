# Native defaultMuted namespace isolation

Native HTML audio/video `defaultMuted` now reads the presence of the actual null-namespace `muted` content attribute. Setting false removes only that attribute. Foreign attributes with the same unprefixed qualified name, and separately prefixed foreign attributes, retain their identity, owner, namespace, prefix and raw values. Setting true already created or normalized the null-namespace slot and retains that behavior.

This deliberately refines the qualified-name `has_attribute`/`remove_attribute` shortcuts emitted by the pinned upstream boolean-reflection generator. It follows the same namespace contract as the translated native `controls` accessors. Upstream reference remains `963d46a829f3e1b79f44dba9d02afb70654300fa`; the upstream checkout is unchanged.

Four new focused cases passed in both GC modes: two native binding cases and two browser-owner cases. They cover audio/video with both duplicate insertion orders, multiple foreign slots, repeated false writes, true normalization, live DOM and replay mutations, original replay exceptions, branding before replay and boolean conversion without author hooks. Browser cases exercise captured reflection synchronization, getter/query/finalization and unrelated dirty writes while retaining foreign Attr pointers and raw values. Controlled runtime mute changes produce their own volume updates and `volumechange` events; `defaultMuted` reflection adds none and leaves runtime muted, playback state and fetching independent. Seeded clocks and manually controlled tasks do not establish physical playback behavior.

Each run has two positive execution rows, an exact 2/2 summary, actual test/supervisor/root zero exits and matching before/after source, index, modes, compiler, native prerequisites, SDK and upstream snapshots. Validation uses the exact committed feature tree with two pinned native prerequisites and no canonical working overrides. Unrelated work and previous evidence remain preserved; historical artifact contents are inherited through authenticated containers without a historical union walk.

Implementation and focused tests are committed as `88439ad17dee6a88f7af887ff6a42e90f1d48d4f`, parent `bdf12eb167a94dabc6c37a7983704f1ca475f665`. The two implementation substitutions have zero net physical LF. Two new test files add 348 LF across three unique feature paths. All three browser/root support paths are excluded by the pinned 78-owner rules, so assigned DOM, HTML and overall file/implementation/test deltas are zero. Global tables and pins remain unchanged; no global recount was performed.

This is fix **4/10** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. Documentation and tooling add no fixes. No broad suite, AST comparison, production build or screenshot run was performed for this slice.

Existing DOM-write and private synchronization ordering is unchanged; this slice adds no synchronization-failure ordering guarantee. Other media attribute namespace paths, widget teardown, synchronous customized-built-in reactions, full media transport/backend and complete interface parity remain open. Browser JavaScript continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-default-muted-namespace-evidence-v1.json`, SHA256 `de92e6754ef69604f695190cd631dffb93404d5b05483e71f8ffc0d2f85f844e`.

Scoped inventory: `Build/audit-fixes/native-media-default-muted-namespace-inventory-scoped-v1.json`, SHA256 `40fa0cb828a505cd5cf5fc1a9436e14b182258de8d5743cae74c1721e316c47c`.

Final local audit and preservation receipts are recorded under `Build/audit-fixes/native-media-default-muted-namespace-final-*`, retaining cadence at 4/10 without resetting or advancing the broad baseline.
