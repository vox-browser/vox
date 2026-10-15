# Native and resource autoplay namespace isolation

The native HTML audio/video `autoplay` getter, both initial model caches and the live media-model query now read only the null-namespace `autoplay` content attribute. Setting false removes only that slot; true retains its existing empty-string normalization. Foreign attributes sharing the qualified name, including separately prefixed attributes, retain their namespace, prefix, raw value, owner and Attr identity. Live DOM changes and adoption remain visible, and ownerless models retain their fallback.

Autoplay eligibility therefore ignores foreign-only presence. Automatic `preload="none"` selection stays deferred even under an allowing policy until a real null-namespace transition qualifies it. The existing policy and sandbox gates, resource notifications and synchronization-before-DOM-write ordering remain intact. A native setter that fetches and reenters JavaScript preserves an inner false write while foreign attributes remain present.

This deliberately refines the qualified-name shortcuts in the pinned upstream boolean-reflection generator and autoplay-eligibility query. It follows the namespace contract already used by translated `controls`, `defaultMuted` and `loop`. Upstream pin remains `963d46a829f3e1b79f44dba9d02afb70654300fa`; the upstream checkout is unchanged.

Six new focused cases passed in both GC modes across three files: two native binding, two HTML owner and two browser-owner cases. They cover both audio/video duplicate orders, unprefixed and prefixed foreign Attr identity, native/model agreement, initial cache isolation, true normalization, repeated false writes, direct DOM and replay mutations, adoption, ownerless fallback, receiver branding and original replay exceptions. Browser cases exercise getter/query/finalization and unrelated dirty replay. Controlled deferred selections check allowed policy with foreign-only presence, blocked policy, sandbox restrictions, exactly one fetch/start after a real allowed transition, and audio fetch reentry that retains inner false and starts no playback. Seeded clocks, controlled responses, playback hooks and manually driven tasks do not establish physical playback/backend behavior.

Each run has three positive execution rows, an exact 3/3 summary, actual test/supervisor/root zero exits and matching before/after source, index, modes, compiler, native prerequisites, SDK and upstream snapshots. Validation uses the exact committed feature tree with two pinned native prerequisites and no canonical working overrides. Unrelated work and previous evidence remain preserved; earlier artifact contents are inherited through authenticated containers without a historical union walk.

Implementation and focused tests are committed as `38ff523fca1d768b6cf8bad816bc772fcfbd41db`, parent `5f21234271ff79243c91086c5fe88de85f0c07d8`. Five substitutions have zero net implementation LF. The three new tests add 543 LF across five unique feature paths. Under the pinned 78-owner rules, HTML gains 178 test LF and one file, with zero implementation LF; DOM deltas are zero. The remaining 365 test LF and two files are excluded browser/root support. Global ownership tables and pins remain unchanged; no full recount was performed.

This is fix **6/10** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. Documentation and tooling add no fixes. No broad suite, AST comparison, production build or screenshot run was performed for this slice.

No new synchronization-failure ordering guarantee is claimed. Other media attribute namespace paths, controls lifecycle, synchronous customized-built-in reactions and full media/interface/backend parity remain open. Browser JavaScript continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-autoplay-namespace-evidence-v1.json`, SHA256 `7b3b1629c06650745c93ba78969cd2b928a5d89d5317d8cbc22698ed903b5216`.

Scoped inventory: `Build/audit-fixes/native-media-autoplay-namespace-inventory-scoped-v1.json`, SHA256 `6772a2e08c6c241d51a4e10e29ae7be5cdfcae92fae175415a6591a3fdf1bb75`.

Final local audit and preservation receipts are recorded under `Build/audit-fixes/native-media-autoplay-namespace-final-*`, retaining cadence at 6/10 without resetting or advancing the broad baseline.
