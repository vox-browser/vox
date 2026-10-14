# Native media raw loadstart handlers

Feature `b4a325cb37afd86d093af09e55870366bc10a8a7` extends lazy compilation to raw `onloadstart`
attributes on actual owner-local HTML audio/video elements. The combined
compiler and ordered compact content-attribute replay admit this name through
existing HTML namespace, media model, Runtime, Document, settings and wrapper
ownership checks. Existing native media interfaces and selection/load
algorithms supply callbacks; no new public model API is introduced.

FunctionBody validation precedes lazy wrapper resolution, which rechecks the
requested slot/source after resolver reentry. Scope follows actual
Element -> Document -> Global lookup and excludes ancestor forms. The inferred
name omits a handler self binding. Equal-text raw writes replace IDL callbacks;
present removal clears a callback while absent removal preserves IDL-only state.

Six focused cases in two new files pass in default and no-GC modes. Binding
tests cover raw onloadstart on parsed/created audio/video, native
getters/prototype, callback cache and identity, independent malformed slots,
early FunctionBody rejection, resolver mutation, CSP, foreign adoption and
unavailable owners, original strict exceptions, scripting gates and close.

Actual-owner tests use parsed video and created audio with the existing
static in-process media-response hook. Fresh source-empty load calls produce
no loadstart callbacks or hook calls. Setting a DOM src and flushing replay
through the paused getter invokes automatic load_element; the subsequent
explicit JavaScript load dispatches a second callback per owner. Each owner
has two native loadstart events and two hooks (four total), with resolved
same-owner URLs and zero range offsets.

Callback probes prove V dispatches while the source/load call is still open,
before its response hook and before native load returns. Callbacks observe
Loading(2), HAVE_NOTHING readiness, empty currentSrc, NaN duration, currentTime
zero and paused true. After response processing each owner has metadata
readiness, resolved currentSrc, duration 20, Idle(1) and no native media error.
Element -> Document -> Global scopes, cached callback metadata, native trusted
Event identity, exact false cancellation, owner realms and retained DOM
painting are covered.

Equal raw writes after IDL preserve the slot/listener while creating a fresh
callback. A controlled native source without a DOM src isolates an owned
media task that invokes JavaScript load. Two raw changes before that task
select the latest body. It switches to IDL and calls load synchronously for
the identical source. Nested events are distinct, window.event returns to
the outer event, and the inner response hook completes before the existing
outer selection resumes and invokes its hook. This check covers the preserved
same-source behavior. Request-generation cancellation receives no credit. Present removal
suppresses a queued load's handler; absent removal preserves later IDL state.

A closed scripting gate retains the raw string through automatic source
replay and explicit load. Reopening and loading invokes a strict raw callback
whose original thrown object is reported once and whose self-clear remains
visible through the live inferred name. A later native listener still runs;
the static response is processed afterward. Realm/context stacks balance and
the listener's DOM changes paint.

The existing timing deviation is explicit: pinned upstream exposes NoSource,
schedules resource selection at stable state, queues loadstart and installs
currentSrc before that queued delivery. V selects and dispatches synchronously
before URL installation and before its response hook. This slice preserves
that boundary without claiming scheduling parity. Request-generation
cancellation, source-switch reentry, JavaScript error interfaces, actual
network/backend/decoding, pending promises and full selection/playback parity
receive no credit. No timer boundary is tested. Other raw media names remain
unsupported, including onerror. Partial named-property interfaces, anonymous
JSC intrinsic source, foreign/weak ownership, close during active JavaScript
and full interface or LibJS/HTML parity remain open. The browser continues to
use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-loadstart-raw-handler-evidence-v1.json` (SHA256 `57d1ff26a71b0631b4f06fe1553ad72877c86f156b486c3ebcaa5d68068c8dc4`).
One exact detached committed source epoch uses six fresh mode/hash working
overrides, authenticated toolchains and regex prerequisites, actual focused
test terminals with positive per-file runtimes and retained compiler scratch.
All 136,496 prior artifact records, executed helpers and private epochs remain
preserved. Actual failed attempts, if any, retain their terminal/log records
without test-body credit. Final closure and actual terminal receipt are
`native-media-loadstart-raw-handler-final-closure.json` and `native-media-loadstart-raw-handler-final-actual-exit.json` under
Build/audit-fixes.

All five feature hashes authenticate the committed/private tested source.
Four current owned implementation/test files match those hashes; two unique
owned main gates include onloadstart and remain byte-exact outside every
changed Git line range. Proof phases retain stable full main snapshots,
observed committed HEAD context, foreign commit traces and exact diffs.
Runtime credit belongs to the tested committed feature epoch. Current full
main and foreign changes receive no runtime/build credit; later proof-phase
snapshots may differ. The strict original-six three-way preservation rule
remains unchanged. Unrelated layout/performance changes, whether working or
committed, stay outside this feature's accounting and receive no independent
pass credit from these focused checks.

Physical accounting: `Build/audit-fixes/native-media-loadstart-raw-handler-inventory-scoped-v1.json`
(SHA256 `8b35cc3810a833155a918c22a226234024c7fe191a877e12e332e94ae8a9b864`). All five browser/root paths remain outside
the sealed 78-owner assigned DOM inventory: zero assigned files,
implementation lines or test lines. Global tables, pins, mappings and
historical ledgers stay preserved; counting provides no behavioral credit.

Production builds, screenshots, full translation suites and LibJS corpus
checks remain deferred under the user's ten-fix cadence. This slice is 9/10
after the aa6f0246 broad unit baseline. Unrelated concurrent working and
committed changes remain preserved.
