# Compact attribute namespace replay

Compact browser snapshots now retain an ordered list of attribute records with namespace URI, local name, prefix, qualified name and raw value. The public qualified-name view exposes the first matching attribute. Public set/remove mutations replay in order against that attribute, preserving its identity and revealing any later duplicate after removal. Newly created null-namespace qualified names keep their entire name as the local name.

Native media reflection synchronizes only its null-namespace slot through the captured private callback. Removing `controls` therefore preserves foreign attributes with the same qualified name through getters, queries, finalization and unrelated dirty writes. Ordered-record states no longer reconcile a flattened map or replay stale class/style/src mirrors. Initial capture, lazy query hydration and created-node materialization share the record representation. Existing legacy flat payloads retain their compatibility path.

Nine focused cases passed in each GC mode on exact committed source `60b9d59201da462ab6dfdc748fe108e571be5ef3`: four shared helper cases, three general browser-owner cases and two media browser-owner cases. Coverage includes both duplicate insertion orders, actual Attr identity and owner removal, qualified remove/set sequencing, SVG case and genuine XLink versus null-namespace qualified names, lazy and created nodes, detach/reappend/reorder, native controls, poisoned intrinsics and one controlled preload reentry. Raw NUL and lone-surrogate record checks do not imply full DOMString binding parity.

Each fresh run has three positive execution rows, an exact 3/3 summary, actual test/supervisor/root zero exits and identical before/after source, index, modes, compiler, native dependency, SDK and upstream snapshots. Sources contain the tested commits and their recorded concurrent committed ancestors, plus two pinned native prerequisites; canonical uncommitted work is excluded and preserved.

The original feature is `231951ff11920963a76709441571d126756941f5`, parent `dabc4fb3026012813bee75082da105afcd40f477`. Its first selections failed to compile both owner files because the helper used `json2` while its consumers use `x.json2`. Commit `83e8f7591187a214202e8933a14bbe18df18cc4c` corrects those two imports. The second selections failed the media file because poison-fixture cleanup deleted the facade's own attribute methods. Commit `60b9d592` restores their original descriptors without changing assertions or implementation. Both failed attempts, logs, source checkouts and compiler artifacts remain retained. No earlier passing subset is carried into the final result; all nine cases ran again in both modes.

Scoped physical accounting is 109 net implementation LF and 516 test LF, with three new test files, four new files and seven unique feature paths. Both repairs have zero net LF and add no cases or fixes. All seven browser/root support paths are excluded by the pinned 78-owner rules, giving zero assigned DOM, HTML and overall inventory deltas. Global owner tables and upstream pin `963d46a829f3e1b79f44dba9d02afb70654300fa` remain unchanged.

Cadence is **3/10 fixes** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. No broad suite, AST comparison, production build or screenshot run was performed for this slice.

This closes the dirty-replay namespace gap recorded in [the preceding controls layout audit](MEDIA_CONTROLS_LAYOUT_NAMESPACE.md). It adds no JavaScript namespace attribute APIs or complete DOM binding parity. External mutation of already-known facades, the independent legacy DocumentBridge path, custom-element reaction timing, widget teardown and physical media/backend parity remain outside this slice. Browser JavaScript remains on JavaScriptCore; native `play()` Promise bindings were completed earlier in `58fde80e`.

Evidence: `Build/audit-fixes/media-compact-attribute-namespace-evidence-v3.json`, SHA256 `b7d54e6bed2a837f8f04d8274ad7c40cba73712cad29708913f4a2ef5d955328`.

Scoped inventory: `Build/audit-fixes/media-compact-attribute-namespace-inventory-scoped-v3.json`, SHA256 `e8035e1b56ec855b40216824ca87a2faa6816b209abe3294d15f358bc7dc3dca`.

Final local audit-commit and preservation receipts are recorded under `Build/audit-fixes/media-compact-attribute-namespace-final-*`. Prior evidence is inherited through authenticated containers without walking its historical artifact union. Cadence remains 3/10 without resetting or advancing the broad baseline.
