# Native media controls reflection

HTML audio/video facades expose native, enumerable and configurable `HTMLMediaElement.prototype.controls` accessors. Reads return the presence of the actual null-namespace content attribute. Setters apply WebIDL boolean conversion, write the empty string for true, and remove that attribute for false. A foreign-namespace attribute with the same local name remains independent.

Receiver branding precedes conversion and compact replay. Conversion invokes no author hooks. The captured private attribute-sync callback runs after replay and before the DOM write, preserving changes through later dirty snapshots without calling author attribute methods or replaceable globals. Replay and synchronization failures preserve their original JavaScript exception identity; synchronization failure prevents the DOM write. Closed bindings reject access and release their protected values.

Both focused files passed once in each GC mode: two files and five cases per mode, with positive execution rows, complete summaries, actual test/supervisor/root zero exits and matching before/after source snapshots. Coverage includes descriptor metadata, forged and proxy receivers, boolean conversion, namespaces, live attributes, dirty replay, poisoned public methods and intrinsics, exception ordering, cleanup, parsed and created elements, and attribute-selector paint. The owner fixture also checks initial UA-shadow controls construction, layout and media-model identity while preserving a manually seeded nonzero clock and unpaused state without fetches or media events. The separate model controls flag is unchanged.

Validation used a fresh detached source at the implementation commit, with six captured branding overrides and pinned compiler/native dependencies. Other concurrent working changes were excluded from that source. Original foreign snapshots remain authenticated; current foreign work is diagnosed without blocking or rewriting it. Pass credit belongs to the tested source, not subsequent canonical changes. The private bootstrap and two media registration gates remain intact.

Implementation: `f99680218a04544adbc35a2804ddab8c03668fcd` (parent `9292a1aa3031e8509ed700589e4e4e0742aca702`). Scoped physical accounting adds 46 implementation LF and 370 test LF across two new test files and three unique paths. All three are excluded browser/root support under the pinned 78-owner rules, so assigned DOM, HTML and overall inventory deltas remain zero. Existing owner tables and upstream pins are unchanged.

This is fix **1/10** after broad baseline `f2e223c9e189004f0694c628535b286ed39a87fd`. Documentation and tooling do not increment the count. No broad suite, AST comparison, production build or screenshot run was performed for this slice; broad validation is deferred until ten fixes.

Controls teardown on removal, layout/UI namespace parity, clock-driven widget updates, native play/backend integration, full media/interface parity and synchronous customized-built-in CEReactions timing remain open. Browser JavaScript continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-controls-host-evidence-v1.json`, SHA256 `ea7617fb7b810d8c8f3a71b39febe8dc2c0ac4ad783b489244ee270cb5cb6679`.

Scoped inventory: `Build/audit-fixes/native-media-controls-host-inventory-scoped-v1.json`, SHA256 `cb122c68866d3244face2de83b9cacdc5d8f9060d50400950d3d7058a94cd3b6`.

The seal inherits the previous authenticated checkpoint and its retained records without walking the historical artifact union. Final local audit-commit and preservation receipts are recorded under `Build/audit-fixes/native-media-controls-host-final-*`; they retain cadence at 1/10 and do not reset or advance the broad baseline.
