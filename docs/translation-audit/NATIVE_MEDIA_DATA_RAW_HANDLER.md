# Native media raw loadedmetadata and loadeddata handlers

Feature `f9ec154f63992b69251f7717878910f234dc37a7` extends lazy compilation to raw `onloadedmetadata` and
`onloadeddata` attributes on actual owner-local HTML audio/video elements.
The combined compiler and compact content-attribute replay admit these names
through their existing HTML namespace, media model, Runtime, Document,
settings and wrapper ownership checks. The existing interface descriptors and
readiness algorithms supply actual native delivery.

FunctionBody parsing precedes lazy wrapper resolution; resolver reentry
rechecks the requested slot and source. Actual Element -> Document -> Global
scopes omit ancestor forms. Inferred function names preserve the lack of a
handler self binding. Equal-text attribute writes replace IDL callbacks,
present removals clear them, and absent removals preserve IDL-only callbacks.

Validation: six new focused cases plus two changed binding boundary fixtures,
12 cases in four files, pass in both default and no-GC test modes. Binding
tests cover both names on parsed/created audio/video, lazy cache and native
prototype shape, independent malformed wheel/play slots, syntax before
resolution, reentrant slot replacement/removal, unavailable or mismatched
owners, CSP, foreign adoption, strict exception identity, scripting gates
and runtime close. Actual-owner tests exercise metadata-only fetches and the
native media task queue: loadedmetadata precedes the first loadeddata
notification, readiness transitions preserve pending play-promise ordering,
and load() resets the first-data notification gate. Live replacement before
delivery, equal-text writes, removal ordering, trusted single-Event callbacks,
original exceptions, later listeners and retained DOM painting remain covered.

Production rebuilds, screenshot batches, full translation suites and LibJS
corpus comparisons are deferred under the explicit ten-fix broad-suite
cadence. This completed translation slice is 3/10 after the aa6f0246 broad unit
baseline. Previous signed builds, screenshots and evidence remain preserved.

Evidence: `Build/audit-fixes/native-media-data-raw-handler-evidence-v1.json` (SHA256 `8401b6cea2d28ce8c643c49e2ea23ef86d90a6f403740789ac6cc1dab727a831`).
One detached committed source epoch uses the original six exact working
overrides, authenticated toolchains and regex prerequisites. All 93,883 prior
artifact records, fresh source, actual successful/failed execution records,
executed helpers, compiler scratch and scoped Git transactions are retained.
Final closure and actual terminal receipt are `native-media-data-raw-handler-final-closure.json` and
`native-media-data-raw-handler-final-actual-exit.json` under Build/audit-fixes. Unrelated concurrent
working and committed changes are preserved separately.

Physical accounting: `Build/audit-fixes/native-media-data-raw-handler-inventory-scoped-v1.json`
(SHA256 `347a64f0ce1cf3a34bdbfd5645693321965b25bc2df0dd4d2979c6e9b46df767`). All seven owned browser/root implementation
and test paths are outside the sealed 78-owner assigned DOM inventory: zero
assigned files, implementation lines or test lines. Counting gives no behavior
credit and leaves global tables, pins and historical ledgers unchanged.

Boundaries: other raw media names remain unsupported; onerror is an explicit
negative case. Partial named-property interfaces, anonymous JSC intrinsic
source, foreign/weak ownership, close during active JavaScript and full
interface or LibJS/HTML parity remain open. The browser continues to use
JavaScriptCore.
