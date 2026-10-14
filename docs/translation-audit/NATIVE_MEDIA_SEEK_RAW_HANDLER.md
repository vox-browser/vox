# Native media raw seeking and seeked handlers

Feature `b864154a10ad8d284ec3a1559ff48eeb7adb6bc9` extends lazy compilation to raw `onseeking` and
`onseeked` attributes on actual owner-local HTML audio/video elements.
The combined compiler and ordered compact content-attribute replay admit
these names through existing HTML namespace, media model, Runtime, Document,
settings and wrapper ownership checks. Existing native media interfaces and
seek algorithms supply the callbacks; no new public model API is introduced.

FunctionBody validation precedes lazy wrapper resolution, which rechecks the
requested slot/source after resolver reentry. Scope follows actual Element ->
Document -> Global lookup and excludes ancestor forms. Inferred names omit a
handler self binding. Equal-text attribute writes replace IDL callbacks;
present removal clears a callback while absent removal preserves IDL-only state.

Six focused cases in two files pass in default and no-GC modes. Binding tests
cover both raw names on parsed/created audio/video, native getters/prototype,
callback cache and identity, malformed independent slots, early FunctionBody
rejection, resolver mutation and owner availability, CSP, foreign adoption,
original exceptions, scripting gates and close.

Actual-owner tests use the existing controlled in-process MediaResourceResponse
adapter with video/mp4 metadata, duration 20 and buffered end 20, establishing
seekable range [0,20]. After setup tasks drain, metadata readiness and controlled
clock/seek hooks move from position 2 to 6. Parsed video uses the native
currentTime setter with accurate mode; created audio uses fastSeek with
fast-after mode. Queued seeking callbacks observe seeking true/currentTime 6.
The existing native finish method, invoked through the controlled host bridge
after seeking delivery, clears seeking immediately and queues timeupdate
before seeked; completion callbacks observe seeking false.

Live replacement before delivery selects the latest raw callback and can issue
an equal-position reentrant fastSeek without eager dispatch. The resulting
IDL seeking callback remains queued; native completion selects the later raw
seeked callback. Equal raw writes preserve slot/listener identity while replacing
the callback. Present removals suppress queued handlers; absent removals preserve
later IDL callbacks. A separate HAVE_NOTHING audio control stores default starting position 5
through currentTime, leaves fastSeek silent, and rejects restricted nonfinite
conversion or preserves the original conversion exception without events.
Configured-video scripting gates preserve raw source; reopened strict seeking
exceptions retain original object identity and allow later listeners plus native
seeked delivery. Native Event identity/trust, exact false cancellation,
balanced owner contexts and retained DOM painting are covered.

These controlled adapters do not establish actual network, decoding, backend
clock/seek completion, cancellation, seeks without a playback manager,
comprehensive seek-range or playback policy parity. Other raw media names remain unsupported, including onerror.
Partial named-property interfaces, anonymous JSC intrinsic source, foreign/weak
ownership, close during active JavaScript and full interface or LibJS/HTML
parity remain open. The browser continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-seek-raw-handler-evidence-v2.json` (SHA256 `5c2bac477c209dee8c8be9ce8c790d0e49a72e2c262828d91ca88d1b51c8fc26`).
The initial seal refused the whole current main.v hash after concurrent foreign
paint changes. Its actual exit 1, exact diagnostic and immutable helpers remain
retained; no focused test was rerun. Fresh proof snapshots retain full observed
main bytes, committed HEAD context and exact Git line diffs. Four current owned
implementation/test files match the feature hashes; the two unique main gates
are byte-exact and excluded from all changed-line ranges. Runtime credit belongs
only to the unchanged tested committed feature epoch. Current full main.v and
foreign paint changes receive no test or build pass credit. Later proof-phase
main snapshots may differ as concurrent work continues.

One exact detached committed source epoch uses six fresh mode/hash working
overrides, authenticated toolchains and regex prerequisites, actual focused
test terminals and retained compiler scratch. All 120,310 prior artifact
records, executed helpers and private epochs are preserved. Final closure and
actual terminal receipt are `native-media-seek-raw-handler-final-closure.json` and
`native-media-seek-raw-handler-final-actual-exit.json` under Build/audit-fixes.

Physical accounting: `Build/audit-fixes/native-media-seek-raw-handler-inventory-scoped-v1.json`
(SHA256 `61d0c1314a40b3bb5b59c183d4d7a49ba71512fbd61063dd0b3d7d773a0e9179`). All five browser/root paths remain outside
the sealed 78-owner assigned DOM inventory: zero assigned files, implementation
lines or test lines. Global tables, pins, mappings and historical ledgers stay
preserved; counting provides no behavioral credit.

Production builds, screenshots, full translation suites and LibJS corpus
checks remain deferred under the user's ten-fix cadence. This slice is 6/10
after the aa6f0246 broad unit baseline. Unrelated concurrent working and
committed changes remain preserved.
