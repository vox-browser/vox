# Media pause task, captured promises and AbortError owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and five focused cases: `477996a3cbc79c2d5c46fbae0dcb208172594773`.

Explicit pause now changes paused/can-autoplay state and commits the live clock
immediately, then queues one media-element task for timeupdate, pause and
rejection of the captured pending-play batch. Its two events run before rejection.
Each batch receives one shared actual AbortError record instead of a message string.
Already-paused calls add no task. Existing played-range accounting is preserved.

## Source boundary

HTMLMediaElement.cpp:2717–2745 captures the pending promises after setting paused,
queues the event/rejection body and immediately commits the official position.
The task body is unconditional: resuming playback from a timeupdate listener does
not suppress the following pause event or rejection of the earlier batch.
Promises added by that listener remain in the model's new pending list.

HTMLMediaElement.h:308–315 creates one AbortError in the document's relevant realm.
HTMLMediaElement.cpp:3322–3333 enters TemporaryExecutionContext before rejecting
the list. The new typed helper creates one DOMException record with Source name
AbortError, message Media playback was paused and legacy code 20, retains it through
dom.js_webidl_value and enters the actual current document's temporary execution
context before settling that batch. Standalone models keep their existing
no-document boundary while retaining the typed record. Foreign realms and physical
LibJS/GC exception ownership remain separate boundaries.

The existing media task queue supplies the original Document, active-document
check and per-element cancellation IDs. Reload removes that owner's task without
canceling another owner's task. Pinned load_element step 4 at cpp:797–798 is itself
FIXME: captured promises belonging to canceled tasks remain pending. The fixture
preserves that current Source behavior; it does not implement the specification's
unfinished immediate settlement step. Inactive delivery discards the body and
leaves its captured promise pending.

The helper is used only for explicit pause. Load, completion and unsupported-play
paths retain their existing promise behavior. play() still returns the existing
dom.Promise compatibility record, and the compact JavaScript play stub remains
unchanged. The helper also accepts actual WebIDL-backed capabilities, as exercised
through the existing dom.Promise facade and owning realm/job scheduler. This is
not native play()/JavaScript-Promise parity. Synchronous resource selection,
other media event/promise algorithms, full native methods/prototype hierarchy,
unique task-source representation, manager/clock/decoder/pipeline delivery,
complete media/MSE, foreign realms and physical GC remain open. The browser
still uses JavaScriptCore.

## Focused cases and diagnostics

Four actual-DOM model cases cover immediate state and live-clock commit, task
and Document/source identity, no microtask delivery, ordered trusted events,
shared exception identity and fields, repeated pause, listener resumption without
capturing its new promise, per-owner cancellation, inactive delivery and actual
native-capability job scheduling under the document's execution context.
The capability case checks scheduling depth and balanced script/callback depths;
reactions retain the same exception record through the owning microtask queue.

One native page case invokes the existing native pause method on the actual parsed
video wrapper. Native EventTarget listeners observe the ordered events with the
same this/target/currentTarget, trusted/non-bubbling/non-cancelable flags and cleaned
currentTarget. Its captured model promises retain one typed reason, which the
existing native converter exposes as a genuine DOMException. The page/model
fixture enters playback through the actual V play caller; it does not invent a
JavaScript play implementation.

The first baseline executes the native runtime failure but its model fixture has
three usize/int depth-array compiler diagnostics. The first model-focused run
passes the existing media file while retaining that same fixture failure. Those
failed manifests, logs, initial test bytes and proposed implementation bytes remain
preserved. Correcting the depth arrays and allowing the existing context cleanup
checkpoint produces five runtime baseline failures without compiler errors on the
unchanged old implementation. All final new test bytes match this corrected
baseline's retained copies. The model focused batch passes 2/2 files; the native
page focused batch passes 1/1.

The first no-GC batch passes two files, then fails to create compiler folders
when the system disk fills. The runner also cannot write its manifest. Its raw
log and explicit retrospective disk diagnostic remain preserved; there is no
success or unchanged-snapshot claim for that incomplete attempt. A fresh full
20-file no-GC retry uses isolated RAM-backed VTMP/TMPDIR paths with the same
tracked inputs, Source pin and compiler executables. Its complete before/after
snapshots match the successful default batch.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 27.497 |
| focused-model | 0 | 24.498 |
| focused-native | 0 | 24.877 |
| default | 0 | 267.918 |
| gc-none | 0 | 203.140 |

All 20 affected files pass in both GC modes on clean committed
`477996a3`. The batch includes the 66-case main regression,
completion/step-one cache, duration/rate/volume tasks, seeking, clock-generation,
adoption, prior pause callers, native EventTarget/DOMException/SourceBuffer and
public pause/completion/currentTime integration. Commands use the frozen V
dispatcher with -old-compiler -enable-globals and VJOBS=2; the second batch adds
-gc none. All 4,912 tracked inputs, 20 pinned Source
references and both compilers remain unchanged. No full HTML/LibJS/Wasm sweep
is claimed.

## Production verification

The same snapshot compiles the production macOS bundle with -prod -gc none.
The initial build's final codesign command fails with an internal Code Signing
subsystem error; its unchanged-snapshot manifest and full build log are preserved.
Signing the existing compiled bundle with the normal system TMPDIR succeeds.
The successful retry records that repair and references the initial compilation
manifest, then verifies the signature and passes --headless-smoke. No particular
cause is assigned to the signing failure. A standalone production probe
uses ordinary failure branches independent of V assertions. It loads an actual
DOM video through the existing typed fetch adapter, obtains two pending promises
from the actual V play caller and invokes native pause. It checks immediate state
and clock, deferred task delivery, both event callback layers before rejection,
actual native event identity/flags/order, one shared AbortError, native DOMException
projection, no repeated body on an already-paused call and balanced realm state.

The two prior public pause pages remain pixel-exact against their 800×600
references: 480,000 pixels with zero tolerances. They exercise parsed/created
owners and native binding behavior; the new loaded task/promise path is proved
by the standalone probe and native page test. All 11 canonical smoke screenshots
pass with unchanged bounds. main.v and the native media host are byte-identical
to the baseline, so the separate SVG mutation set is not rerun.

Production retains 43 Source input/reference/font
hashes and all exact probe/pages, logs, captures and artifact hashes. The binary
remains unchanged throughout capture.
Binary SHA256: `aca4fca89a500fea5660d7204e841fc0bd3582d7e850d963f7e0117a183d2d62`.
Production retry manifest SHA256: `80aa9a859b0008568737058aeae931a81429af6e0446f36630b27c83892d6c18`.
Initial production manifest: `Build/audit-fixes/media-pause-task-owner-production-manifest.json`.
SHA256: `41dda14bdc218cd66cec237e02072a8ebb06118bd7f8f21cc27c5f88583a2dcd`.
Default manifest SHA256: `f376228c39994a9b84da9b63a1bdf838ce0e4cc60d6e16997bb16b9884b74428`.
GC-none manifest SHA256: `86e49f13b8f5b31e1112eeb8f41b197234348dccf6b7310ed61bcaae2a0716a1`.
Consolidated evidence: `Build/audit-fixes/media-pause-task-evidence.json`.
SHA256: `3165c0a20c125070eac1e100a211282274945e724158012b0cc523e0abcde500`.
Initial baseline manifest SHA256: `776d34ca4c2f806dabd9abaa6c70d6b112a4fbe92695b004382dc428142b2234`.
Initial model-focused manifest SHA256: `e3a73fba054dafa0c0d29851b4429e89a34fdea23eb0755e143a072db75e76c2`.
Disk diagnostic: `Build/audit-fixes/media-pause-task-gc-none-disk-diagnostic.json`.
SHA256: `9ee1b76d53e76352a1e55102a259057e2b40a8a1446b46f3d12deb1cde3801d0`.
The successful no-GC and production runs record the RAM-backed VTMP/TMPDIR
overrides, with normal system TMPDIR recorded for production signing and signature
verification; temporary compiler storage is separate from retained repository
artifacts. Private artifacts use media-pause-task-owner-frozen (diagnostics),
media-pause-task-owner-corrected-frozen (final baseline/focused/default),
media-pause-task-owner-ram-frozen (successful no-GC) and
media-pause-task-owner-production (initial build/signing diagnostics) and
media-pause-task-owner-production-retry (successful native verification).

## Inventory and audit

The 78-owner inventory contains 432,371 implementation /
155,425 test V LOC across 2,192 owned files.
Only html/html_media_element.v changes among previous owned files, with one HTML
pause-task test added. Browser/root support remains excluded by convention.
All owned hashes match the frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-477996a3.json`.
SHA256: `b89b2cf1072770c9652ec85c1f968f76f78d3c6ba5f9235606c8ac6b63577073`.
Physical LOC does not measure parity. The ledger remains 32 fixed / 25 partial /
9 open; this selected pause task/reason slice does not close the wider findings.

Implementation: [media lifecycle](../../html/html_media_element.v).
Tests: [model task](../../html/media_pause_task_owner_test.v),
[native page](../../media/main_media_pause_task_owner_test.v).
[Prior native pause caller](NATIVE_MEDIA_PAUSE_OWNER.md) retains its earlier
snapshot, baseline, production diagnostics and inventory.

The subsequent [internal-play task slice](MEDIA_PLAY_TASK_OWNER.md) queues play,
waiting, playing and already-playing resolution, captures the starting position
before manager play and enters the current document context for fulfillment.
This document retains its earlier 477996a3 evidence. Native play promises and the
other media algorithm, state and backend boundaries remain separate work.
