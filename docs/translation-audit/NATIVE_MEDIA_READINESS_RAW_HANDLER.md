# Native media raw playing and waiting handlers

Feature `2aab6ba2742b809b644f034c5e668d49d7675bb6` extends lazy compilation to raw `onplaying` and `onwaiting`
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
queue. Waiting callbacks see pending JS/native play promises; later playing
callbacks run before captured promises fulfill. A playing handler can call
pause() without stealing that captured batch. Live replacement before delivery,
equal-text writes, removal ordering, trusted single-Event callbacks, original
exceptions, later listeners and retained DOM painting remain covered.

No production rebuild, screenshot batch, full translation suite or LibJS corpus
comparison is claimed for this slice. These are deferred under the explicit
ten-fix broad-suite cadence; this completed translation slice is 1/10 after the
aa6f0246 broad unit baseline. Previous signed builds, screenshots and evidence
remain preserved.

Evidence: `Build/audit-fixes/native-media-readiness-raw-handler-evidence-v1.json` (SHA256 `2edeaef4933dd5c366f313037301679bef282ffd64d151470fc51f9f49cf4ad8`).
One detached committed source epoch uses the original six exact working
overrides, authenticated toolchains and regex prerequisites. All 83,199 prior
artifact records, fresh source, actual successful/failed execution records,
executed helpers, compiler scratch and scoped Git transactions are retained.
Final closure and actual terminal receipt are `native-media-readiness-raw-handler-final-closure.json` and
`native-media-readiness-raw-handler-final-actual-exit.json` under Build/audit-fixes. Unrelated concurrent working
and committed changes are preserved separately.

Physical accounting: `Build/audit-fixes/native-media-readiness-raw-handler-inventory-scoped-v1.json`
(SHA256 `4a5ddcd1962bb29fa86e50defd18600203d011e90c3fb235276c46b3c3a07858`). All eight owned browser/root implementation and
test paths are outside the sealed 78-owner assigned DOM inventory: zero assigned
files, implementation lines or test lines. Counting gives no behavior credit
and leaves global tables, pins and historical ledgers unchanged.

Boundaries: other raw media names remain unsupported; oncanplay and loadedmetadata
are explicit negative cases. Partial named-property interfaces, anonymous JSC
intrinsic source, foreign/weak ownership, close during active JavaScript and full
interface or LibJS/HTML parity remain open. Existing V readiness loss fires waiting
synchronously, while the pinned upstream leaves that buffering-drop branch a
FIXME; this slice proves only the native play()-queued waiting path. The browser
continues to use JavaScriptCore.
