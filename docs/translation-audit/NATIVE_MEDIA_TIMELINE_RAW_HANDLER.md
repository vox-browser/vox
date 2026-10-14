# Native media raw timeupdate and durationchange handlers

Feature `ef218fdfe454458040fafe3ec5ddc1d53db75a12` extends lazy compilation to raw `ontimeupdate` and
`ondurationchange` attributes on actual owner-local HTML audio/video elements.
The combined compiler and ordered compact content-attribute replay admit these
names through existing HTML namespace, media model, Runtime, Document,
settings and wrapper ownership checks. Native interface descriptors retain
duration as read-only; native media algorithms supply the queued events.

FunctionBody parsing precedes lazy wrapper resolution; resolver reentry
rechecks the requested slot and source. Actual Element -> Document -> Global
scope excludes ancestor forms, callback names have no handler self binding,
and equal-text attribute writes replace IDL callbacks. Present attribute
removal clears a callback; absent removal preserves an IDL-only callback.

Six new cases in two files pass in both default and no-GC test modes. Binding
tests cover both names on parsed/created audio/video, native prototype shape,
lazy cache, malformed independent slots, FunctionBody rejection before wrapper
resolution, owner availability and identity, resolver slot mutation, CSP,
foreign adoption, original strict exceptions, scripting gates and runtime close.

Actual-owner tests use parsed video and created audio with source-empty native
models. Native duration calls 20, 20, a fresh normal time-marches request, then
duration 30 queue durationchange, durationchange, timeupdate, durationchange
for each owner. Callbacks see live duration 30 and currentTime zero.
A native NaN duration reset is silent. Replacement before queued delivery
selects the live slot and can append a later duration task without eager
dispatch. A timeupdate callback runs beyond 300ms and its reentrant normal
request is suppressed by the running-handler guard; a request after that
handler returns queues a subsequent task. These checks do not assert the
exact 250ms boundary. Equal raw writes, removal ordering, trusted native Event
identity, exact false cancellation, original thrown-object identity, later
listeners, balanced owner contexts and retained DOM painting are covered.

Production rebuilds, screenshots, full translation suites and LibJS corpus
comparisons remain deferred under the explicit ten-fix broad-suite cadence.
This slice is 5/10 after the aa6f0246 broad unit baseline. Previous production
builds, screenshots, failed attempts, private source epochs and evidence stay
preserved.

Evidence: `Build/audit-fixes/native-media-timeline-raw-handler-evidence-v1.json` (SHA256 `71cdb773641e88fe6e951d87ad493d67e1e4566344c4263f16aaf751b28df08b`).
One detached committed source epoch retains the six fresh exact working
overrides, authenticated toolchains/regex prerequisites, actual test terminals,
compiler scratch and scoped Git transactions. All 114,970 prior records are
authenticated. Final closure and actual terminal receipt are
`native-media-timeline-raw-handler-final-closure.json` and `native-media-timeline-raw-handler-final-actual-exit.json` under Build/audit-fixes.
Foreign working and committed changes remain preserved.

Physical accounting: `Build/audit-fixes/native-media-timeline-raw-handler-inventory-scoped-v1.json`
(SHA256 `956970f14822b2169d7ce285ee59179e20f5a4bf8b26cbdcae57127900d4199c`). Five owned browser/root paths are outside the
sealed 78-owner assigned DOM inventory, adding zero assigned files,
implementation lines or test lines. Global tables, pins and historical ledgers
are preserved; counting supplies no behavioral credit.

Boundaries: other raw media names remain unsupported, including the onerror
negative case. Source fetch, decode, actual playback, play policy, backend
pipeline and exact timer-boundary behavior receive no new credit. Partial
named-property interfaces, anonymous JSC intrinsic source, foreign/weak
ownership, close during active JavaScript and full interface or LibJS/HTML
parity remain open. The browser continues to use JavaScriptCore.
