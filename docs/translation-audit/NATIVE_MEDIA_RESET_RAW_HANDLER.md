# Native media raw abort and emptied handlers

Feature `50d3cd340d1297f4c1ac9bbe195c89af1e15dbd3` extends lazy compilation to raw `onabort` and
`onemptied` attributes on actual owner-local HTML audio/video elements.
The combined compiler and ordered compact content-attribute replay admit
these names through existing HTML namespace, media model, Runtime, Document,
settings and wrapper ownership checks. Existing native media interfaces and
load/reset algorithms supply callbacks; no new public model API is introduced.

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

Actual-owner tests use source-empty parsed video and created audio models.
A fully fresh Empty-state load produces no reset callbacks or position task.
For the reset path, the existing native ongoing algorithm puts video in
loading after its state task, leaving progress pending; actual native
completion puts audio in idle. Controlled native metadata sets duration 20,
current/official playback position 6, seeking true and paused false.
JavaScript load then removes each owner's pending progress/metadata/duration
tasks and queues abort, emptied and the conditional position timeupdate.
Another audio owner's previously queued volume task survives and executes
ahead of the reset callbacks, proving cancellation stays owner-local.

Both raw reset handlers see V's live Empty network state, HAVE_NOTHING
readiness, currentTime zero, empty currentSrc, NaN duration, paused true and
seeking false. The auxiliary ordinary timeupdate listeners observe the same
reset state. Native Event identity/trust, exact false cancellation,
Element -> Document -> Global scopes, cached callback metadata, balanced
owner contexts and retained DOM painting are covered.

Equal raw writes after IDL callbacks preserve handler slots/listeners while
creating fresh callbacks. A raw abort replacement before delivery installs
raw emptied, flushes attribute replay, switches abort to IDL, performs actual
native completion to idle and calls load reentrantly. That load cancels the
old pending emptied/timeupdate tasks and queues a new abort/emptied pair.
The new IDL abort and latest raw emptied run; raw emptied then switches to
IDL. Present removals suppress queued handlers; absent removals preserve
later IDL values for another idle reset.

A closed scripting gate retains raw strings while native warming and
JavaScript load execute. Reopening and loading from idle invokes a strict
raw abort callback whose original thrown object is reported once. A later
abort listener still executes, and raw emptied runs in its separate pending
native task. Realm/context stacks balance and the listener's DOM changes
paint.

The existing selection timing deviation is explicit: upstream exposes
NoSource(3) immediately and schedules resource selection at stable state.
V selects the empty resource synchronously, so these fixtures expose
Empty(0) before and during abort/emptied delivery. This slice preserves that
behavior and does not establish selection scheduling parity. The fresh
Empty-state negative is bounded; comprehensive EMPTY reset behavior, prior
pending play promises, playing/seeking policy, actual network/source fetching,
decoding/backend completion and timer boundaries receive no credit.
Other raw media names remain unsupported, including onerror. Partial
named-property interfaces, anonymous JSC intrinsic source, foreign/weak
ownership, close during active JavaScript and full interface or LibJS/HTML
parity remain open. The browser continues to use JavaScriptCore.

Evidence: `Build/audit-fixes/native-media-reset-raw-handler-evidence-v1.json` (SHA256 `235f19d98b7b2ad932ad94291a0e5893379192919ae323ce078f1005da864e0f`).
One exact detached committed source epoch uses six fresh mode/hash working
overrides, authenticated toolchains and regex prerequisites, actual focused
test terminals with positive per-file runtimes and retained compiler scratch.
All 131,115 prior artifact records, executed helpers and private epochs remain
preserved. Actual failed attempts, if any, retain their terminal/log records
without test-body credit. Final closure and actual terminal receipt are
`native-media-reset-raw-handler-final-closure.json` and `native-media-reset-raw-handler-final-actual-exit.json` under
Build/audit-fixes.

All five feature hashes authenticate the committed/private tested source.
Four current owned implementation/test files match those hashes; two unique
owned main gates remain byte-exact outside every changed Git line range.
Proof phases retain stable full main snapshots, observed committed HEAD
context, foreign commit traces and exact diffs. Runtime credit belongs to the
tested committed feature epoch. Current full main and foreign changes receive
no runtime/build credit; later proof-phase snapshots may differ. The strict
original-six three-way preservation rule remains unchanged.

Physical accounting: `Build/audit-fixes/native-media-reset-raw-handler-inventory-scoped-v1.json`
(SHA256 `92535a67615d288fc4c5b7001fdd34c1a3ddd7c4c9c27cd296e478209b4f9677`). All five browser/root paths remain outside
the sealed 78-owner assigned DOM inventory: zero assigned files,
implementation lines or test lines. Global tables, pins, mappings and
historical ledgers stay preserved; counting provides no behavioral credit.

Production builds, screenshots, full translation suites and LibJS corpus
checks remain deferred under the user's ten-fix cadence. This slice is 8/10
after the aa6f0246 broad unit baseline. Unrelated concurrent working and
committed changes remain preserved.
