# Native media raw progress and suspend handlers

Feature `739e00b8b34808547c5f69addf09fd6eed3ecaa1` extends lazy compilation to raw `onprogress` and
`onsuspend` attributes on actual owner-local HTML audio/video elements.
The combined compiler and ordered compact content-attribute replay admit
these names through existing HTML namespace, media model, Runtime, Document,
settings and wrapper ownership checks. Existing native media interfaces and
data-processing algorithms supply callbacks; no new public model API is
introduced.

FunctionBody validation precedes lazy wrapper resolution, which rechecks the
requested slot/source after resolver reentry. Scope follows actual
Element -> Document -> Global lookup and excludes ancestor forms. Inferred
names omit a handler self binding. Equal-text raw writes replace IDL
callbacks; present removal clears a callback while absent removal preserves
IDL-only state.

Six focused cases in two new files pass in default and no-GC modes. Binding
tests cover both raw names on parsed/created audio/video, native
getters/prototype, callback cache and identity, independent malformed slots,
early FunctionBody rejection, resolver mutation, CSP, foreign adoption and
unavailable owners, original strict exceptions, scripting gates and close.

Actual-owner tests use fresh source-empty parsed video and created audio
models. The existing native ongoing algorithm queues a task setting
networkState to loading, then its initial progress task. A controlled host
bridge queues the actual completion algorithm through the media-element
task source. Completion dispatches progress, changes networkState to idle,
then dispatches suspend in that single task. Stepwise task execution proves
progress/progress/suspend per owner with live states loading/loading/idle.
Exact false from progress preserves the idle transition and suspend
delivery. ReadyState remains HAVE_NOTHING, currentTime is zero and each
model stays paused. Scope, cached callback metadata, trusted native Event
identity, owner realms and retained DOM painting are covered.

Equal raw writes after IDL callbacks preserve handler slots/listeners while
creating fresh callbacks. A raw replacement before queued progress delivery
installs raw suspend, appends another real completion without eager dispatch,
then switches progress to IDL. The original completion selects IDL progress
and the latest raw suspend; that raw suspend switches to IDL, so the appended
completion selects the latest IDL pair. Present removals suppress queued
handlers; absent removals preserve later IDL values for completion delivery.

A closed scripting gate retains raw strings through fresh ongoing and
completion tasks. Reopening and queueing completion from idle invokes a
strict raw progress callback whose original thrown object is reported once.
A later progress listener and raw suspend still run in that same completion
task. Realm/context stacks balance and the listener's DOM changes paint.

No sleep or 350ms throttle boundary is tested. These direct native processing
hooks do not establish network/source fetching, preload/cancellation,
decoding, backend progress, completion readiness or playback policy parity.
The existing V completion branch still omits upstream's trailing
update_ready_state call; this slice does not change or credit that behavior.
Other raw media names remain unsupported, including onerror. Partial
named-property interfaces, anonymous JSC intrinsic source, foreign/weak
ownership, close during active JavaScript and full interface or LibJS/HTML
parity remain open. The browser continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-progress-raw-handler-evidence-v2.json` (SHA256 `d03fe461c19779ea9b9f9c8827d275912e2adbbf628bcf16cb8bb37498bd4714`).
One exact detached committed source epoch uses six fresh mode/hash working
overrides, authenticated toolchains and regex prerequisites, actual focused
test terminals with positive per-file runtimes and retained compiler scratch.
All 125,684 prior artifact records, executed helpers and private epochs remain
preserved.
The first seal refused its strict original-six AGENTS.md three-way check
while concurrent foreign performance documentation was being committed.
Its actual exit 1 and diagnostic are retained. A later read-only check
against the new committed HEAD matched all six exact original-working
merges. The failed read's canonical bytes were not retained, so a transient
working/HEAD handoff remains an inference. The strict preservation rule
is unchanged; no source epoch changed and no focused test was rerun.
Premature documentation calls were rejected at missing-evidence
preconditions; their failed outputs and empty first audit-proposal
directory remain preserved without ref, index or commit mutations.
 Actual failed attempts, if any, retain their terminal/log records
without test-body credit. Final closure and actual terminal receipt are
`native-media-progress-raw-handler-final-closure.json` and `native-media-progress-raw-handler-final-actual-exit.json` under
Build/audit-fixes.

All five feature hashes authenticate the committed/private tested source.
Four current owned implementation/test files match those hashes; two unique
owned main gates remain byte-exact outside every changed Git line range.
Proof phases retain stable full main snapshots, observed committed HEAD
context, foreign commit traces and exact diffs. Runtime credit belongs to the
tested committed feature epoch. Current full main and foreign changes receive
no runtime/build credit; later proof-phase snapshots may differ.

Physical accounting: `Build/audit-fixes/native-media-progress-raw-handler-inventory-scoped-v1.json`
(SHA256 `07dd77510b5be5d09cafc3b80723e24291f77107a3c3faeb71141d42d9db94bb`). All five browser/root paths remain outside
the sealed 78-owner assigned DOM inventory: zero assigned files,
implementation lines or test lines. Global tables, pins, mappings and
historical ledgers stay preserved; counting provides no behavioral credit.

Production builds, screenshots, full translation suites and LibJS corpus
checks remain deferred under the user's ten-fix cadence. This slice is 7/10
after the aa6f0246 broad unit baseline. Unrelated concurrent working and
committed changes remain preserved.
