# Native and playback loop namespace isolation

The native HTML audio/video `loop` getter and the V media model now read only the null-namespace `loop` content attribute. Setting false removes only that slot; setting true retains its existing empty-string normalization. Foreign attributes with the same qualified name, including separately prefixed attributes, preserve their namespace, prefix, owner, raw value and Attr identity. DOM-associated models read live attributes after direct mutations and adoption; ownerless models retain their boolean fallback.

Playback-end capture uses that live model query. A foreign-only `loop` attribute now follows non-loop completion, while an actual null-namespace attribute selects the existing loop-to-zero path. The paused guard, queued completion timing and captured endpoint decision remain intact when attributes change after reaching the endpoint.

This deliberately refines the qualified-name shortcuts in the pinned upstream boolean-reflection generator and playback-end check. It follows the null-namespace contract already used by translated `controls` and `defaultMuted`. Upstream pin remains `963d46a829f3e1b79f44dba9d02afb70654300fa`; the upstream checkout is unchanged.

Six new focused cases passed in both GC modes across three files: two native binding, two HTML owner and two browser-owner cases. Coverage includes audio/video with both duplicate orders, foreign unprefixed and prefixed Attr identity, native/model getter agreement, true normalization, repeated false writes, direct DOM/replay changes, branding and original replay exceptions. Browser cases cover getter/query/finalization and unrelated dirty writes, late-node hydration, qualified public removal followed by native reflection, and retained node/model/attribute identity through detach/reappend. The endpoint case uses three controlled one-second resources to check foreign-only completion, real looping and paused looping, including mutations after capture. Controlled responses and manually driven tasks do not establish physical playback/backend parity.

Each run has three positive execution rows, an exact 3/3 summary, actual test/supervisor/root zero exits and matching before/after source, index, modes, compiler, native prerequisites, SDK and upstream snapshots. Validation uses the exact committed feature tree with two pinned native prerequisites and no canonical working overrides. Unrelated work and previous evidence remain preserved; earlier artifact contents are inherited through authenticated containers without a historical union walk.

Implementation and focused tests are committed as `45e43ae4a53f998447732cc8a6beddac7555faa0`, parent `ae28ec20da20f4fbe6649651983cf172afd6e36a`. Three substitutions have zero net implementation LF. The three new tests add 468 LF across five unique feature paths. Under the pinned 78-owner rules, HTML gains 159 test LF and one file, with zero implementation LF; DOM deltas are zero. The other 309 test LF and two files are excluded browser/root support. Global ownership tables and pins remain unchanged; no full recount was performed.

This is fix **5/10** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. Documentation and tooling add no fixes. No broad suite, AST comparison, production build or screenshot run was performed for this slice.

Existing DOM-write and private synchronization ordering is unchanged; this slice adds no synchronization-failure ordering guarantee. Other media attribute namespace paths, controls lifecycle, synchronous customized-built-in reactions and full media/interface/backend parity remain open. Browser JavaScript continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-loop-namespace-evidence-v1.json`, SHA256 `37f1290c26b4f19c41e1a61f36e95c08f575c3720fae288328423b59bd29eecd`.

Scoped inventory: `Build/audit-fixes/native-media-loop-namespace-inventory-scoped-v1.json`, SHA256 `4d7f1cadcf7be8b8a88a285736a420f1d052e30d4f821c5cedc5549739f47cbe`.

Final local audit and preservation receipts are recorded under `Build/audit-fixes/native-media-loop-namespace-final-*`, retaining cadence at 5/10 without resetting or advancing the broad baseline.
