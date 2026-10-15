# Media controls layout namespace

Initial controls construction now requires an actual HTML audio/video element and its null-namespace `controls` content attribute. SVG and MathML elements with the same local names do not acquire media UA shadow trees. Existing shadow roots and their children remain untouched. HTML audio visibility uses the same null-namespace check in both style dispatch and the public adjustment entry point, so a foreign-namespace attribute alone cannot reveal an empty audio box, including with author `display:block`.

This intentionally refines the pinned upstream qualified-name shortcuts to agree with the translated native `controls` getter and reflected content-attribute semantics. Actual HTML class ownership is preserved. It does not claim identical behavior for those upstream shortcuts or complete controls lifecycle parity.

Seven focused cases passed once in each GC mode: three layout cases, two CSS cases and two browser-owner cases. They exercise foreign unprefixed and prefixed attributes, HTML/SVG/MathML ownership, audio visibility through null-namespace add/remove transitions, existing-root and widget identity across repeated builds, and the initial native false-to-true transition into closed UA widgets. Model identity, a manually seeded clock and unpaused state remain intact. The browser cases preserve foreign attributes through initial enabling; direct DOM removal is covered by the CSS cases.

Both runs have three positive file rows, exact 3/3 summaries, actual test/supervisor/root zero exits and matching before/after source, index, mode, compiler, native dependency and upstream snapshots. Validation used the exact committed feature tree with two pinned native prerequisites and no canonical working overrides. Concurrent uncommitted work remains preserved and receives no test credit. Earlier evidence is inherited through authenticated containers without walking the historical artifact union.

Implementation: `aabe03d00de756173f19dcc20a121bed94e01ce6`, parent `e210a6956cb41bc76e12218b2f2208c3e7001f8c`. Scoped physical accounting adds 2 implementation LF and 354 test LF across three new test files and five unique paths. Assigned Layout gains 2 implementation LF, 169 test LF and one file; CSS gains 70 test LF and one file. The remaining 115 test LF and one file are excluded root support. Assigned DOM/HTML deltas are zero. Existing global owner tables and upstream pins are unchanged; no global recount was performed.

Cadence is **2/10 fixes** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. Documentation and tooling add no fixes. No broad suite, AST comparison, production build or screenshot suite ran for this slice.

Existing-widget teardown, scripting-disabled fallback, clock-driven widget updates, physical media playback/backend parity and synchronous customized-built-in CEReactions remain open. Compact dirty-snapshot replay still flattens attribute namespaces: removing null-namespace `controls` and replaying the dirty snapshot can delete a remaining foreign attribute with the same unprefixed qualified name. That separate replay boundary is explicitly excluded from this initial-rendering slice. Native JavaScript `play()` Promise bindings were already completed in `58fde80e`; browser JavaScript remains on JavaScriptCore.

Evidence: `Build/audit-fixes/media-controls-layout-namespace-evidence-v1.json`, SHA256 `e245a2a5a53cbb85e6d19104d8dc6174bf9436f6a395ceea0f168e2cd7b97b13`.

Scoped inventory: `Build/audit-fixes/media-controls-layout-namespace-inventory-scoped-v1.json`, SHA256 `eebd1f0e51a50d615a1fe1ffe1a86790bc070a5db044f8daa50a3118be735576`.

Final local audit-commit and preservation receipts are recorded under `Build/audit-fixes/media-controls-layout-namespace-final-*`. They retain cadence at 2/10 without resetting or advancing the broad baseline.
