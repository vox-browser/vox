# Native media raw canplay and canplaythrough handlers

Feature `bc80a4b7d5a4802caa145baca2d1cf9c0fef6bac` extends lazy compilation to raw `oncanplay` and `oncanplaythrough`
attributes on actual owner-local HTML audio/video elements. The combined compiler
and compact content-attribute replay admit these names through their existing
HTML namespace, media model, Runtime, Document, settings and wrapper ownership
checks. No new interface descriptors or readiness algorithms are added.

FunctionBody parsing precedes lazy wrapper resolution; resolver reentry rechecks
the requested slot and source. Actual Element -> Document -> Global scopes omit
ancestor forms. Inferred function names preserve the lack of a handler self
binding. Equal-text attribute writes replace IDL callbacks, present removals
clear them, and absent removals preserve IDL-only callbacks.

Validation: six new focused cases plus three changed boundary fixtures,
16 cases in five files, pass in both default and no-GC test modes. Binding tests
cover both names on parsed/created audio/video, lazy cache and native prototype
shape, independent malformed wheel/play slots, syntax before resolution,
reentrant slot replacement/removal, unavailable or mismatched owners, CSP,
foreign adoption, strict exception identity, scripting gates and runtime close.
Actual-owner tests use metadata-only media fetches and the native media task
queue. Metadata-to-enough readiness queues loadeddata, canplay, playing and
canplaythrough in that order. Canplay sees pending JS/native play promises;
playing resolves its captured batch before canplaythrough is delivered. A canplay
handler can call pause() without stealing that already captured batch. Live replacement before delivery,
equal-text writes, removal ordering, trusted single-Event callbacks, original
exceptions, later listeners and retained DOM painting remain covered.

No production rebuild, screenshot batch, full translation suite or LibJS corpus
comparison is claimed for this slice. These are deferred under the explicit
ten-fix broad-suite cadence; this completed translation slice is 2/10 after the
aa6f0246 broad unit baseline. Previous signed builds, screenshots and evidence
remain preserved.

Evidence: `Build/audit-fixes/native-media-canplay-raw-handler-evidence-v1.json` (SHA256 `589221e4b5a8f04299a7f66a4d7bf78f350d5201a85cec65e22f7d325e7861b8`).
One detached committed source epoch uses the original six exact working
overrides, authenticated toolchains and regex prerequisites. All 88,552 prior
artifact records, fresh source, actual successful/failed execution records,
executed helpers, compiler scratch and scoped Git transactions are retained.
Final closure and actual terminal receipt are `native-media-canplay-raw-handler-final-closure.json` and
`native-media-canplay-raw-handler-final-actual-exit.json` under Build/audit-fixes. Unrelated concurrent working
and committed changes are preserved separately.

Physical accounting: `Build/audit-fixes/native-media-canplay-raw-handler-inventory-scoped-v1.json`
(SHA256 `d8a72dad76f60ae0753acfec6ebf6c89280c162ff69d89d209e1cc7c827c2ce5`). All eight owned browser/root implementation and
test paths are outside the sealed 78-owner assigned DOM inventory: zero assigned
files, implementation lines or test lines. Counting gives no behavior credit
and leaves global tables, pins and historical ledgers unchanged.

Boundaries: other raw media names remain unsupported; onerror and loadedmetadata
are explicit negative cases. Partial named-property interfaces, anonymous JSC
intrinsic source, foreign/weak ownership, close during active JavaScript and full
interface or LibJS/HTML parity remain open. The browser
continues to use JavaScriptCore.
