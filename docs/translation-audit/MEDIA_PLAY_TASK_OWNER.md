# Internal play tasks, starting position and captured promise resolution

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation, six model cases, one native page case and updated neighboring
fixtures: `fd83fa0a0813b8e5c4d610878e6ecbf1f9371df3`.
Inactive pause-fixture follow-up and verified snapshot: `5a2ec71af20b432806986b576bee9ced21e2fe5d`.

Internal play now queues separate play and waiting events. Playing notification
captures the pending batch and live start position before starting the existing
playback-manager hook. Its task commits that position, fires playing and resolves
only its captured batch to undefined. An already-playing call queues resolution
of its own batch without a second playing event or manager start. Paused state,
poster changes and can-autoplay changes remain immediate. Resolution enters the
actual current document's temporary execution context.

## Source mapping and selected boundary

HTMLMediaElement.cpp:2639–2714 queues the internal play and waiting tasks and the
already-playing resolution task. cpp:2893–2918 takes pending promises and captures
current_playback_position when queuing notification, before manager play starts.
Its body is unconditional: a pause before delivery does not suppress the queued
playing event or change fulfillment of the previously captured batch. A later
play call or one made by a playing listener receives a separate captured batch.
The task explicitly commits the start position so that the playing listener does
not observe an arbitrary later clock sample.

cpp:3308–3319 enters TemporaryExecutionContext for resolution hooks. The translated
helper uses the actual Document's begin/end hooks around the batch, with the old
standalone no-document path retained. Tests also exercise actual WebIDL-backed
capabilities through the existing dom.Promise facade, relevant realm and canonical
job scheduler. Context cleanup follows the existing checkpoint behavior; reactions
are not required to wait until after Task.execute returns.

The existing media queue supplies original Document identity, owner-specific
cancellation IDs and the active-document guard. Pinned load_element step 4 at
cpp:797–798 is still FIXME: canceled tasks' captured batches remain pending.
Inactive delivery similarly discards the body. Neither test nor implementation
invents settlement for those cases.

This slice translates the selected task/position/resolution responsibilities,
not the entire play or notify-about-playing algorithms. Public play permission and
error gates, native JavaScript play Promise creation, Source has-started-playback
and audio/wake-lock state, other ready-state/load/completion event and rejection
algorithms, asynchronous resource selection/fetch, complete native methods and
prototype hierarchy, physical manager/clock/decoder/pipeline delivery, complete
media/MSE, foreign realms and physical GC remain open. The existing V played-range
and audible-state behavior is preserved. main.v and the native media host are
byte-identical to the baseline; the compact JavaScript play method still returns
its existing resolved-Promise stub. JavaScriptCore remains the default backend.

## Focused cases and retained diagnostics

The six actual-DOM model cases check separate ordered play/waiting tasks, no
microtask delivery, immediate flags, trusted target/currentTarget identity,
manager start before event delivery, captured start position, listener-created
and already-playing batches, ready-state notification, unconditional delivery
after pause, owner-specific load cancellation, inactive delivery and actual
capability resolution hooks/reactions under balanced document execution context.

The native page case enters playback through the actual V caller and observes
native EventTarget listeners on the actual parsed video. It checks event order,
receiver/target/currentTarget identity and cleanup, trusted flags, the captured
currentTime rather than the advanced manager clock, separate batch completion,
other-element isolation and balanced realm/VM state. It does not substitute a
JavaScript play implementation.

The initial baseline retains model-fixture option/value-field and scheduler-call
compiler diagnostics alongside the native runtime failure. After correcting
those expressions, all seven focused cases fail at runtime on the old model.
The first implementation-focused run passes the old media file and five new
model cases but finds a fixture panic: the runnable-task selector cannot take an
inactive Document's queued tasks. The final fixture retains both actual tasks
before deactivation, then executes their active-document guards. This corrected
fixture again produces seven runtime baseline failures without compiler errors
on the unchanged old implementation. All final new test bytes match that final
baseline's retained copies; the original manifests, private bytes and failed
focused log remain preserved. The implementation matches its retained proposed
bytes. Existing media lifecycle expectations now wait for fulfillment, and pause
fixtures drain the newly queued start events before asserting the pause task count.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 34.761 |
| focused-model | 0 | 23.957 |
| focused-native | 0 | 35.448 |
| default | 0 | 239.017 |
| gc-none | 0 | 232.846 |

The focused model batch passes 2/2 files and the native page passes 1/1.
All 22 affected files pass in both GC modes on clean committed
`5a2ec71a`. They include the 66-case main regression,
clock/seek/adoption, duration/rate/volume/completion tasks, prior pause tasks and
callers, native media/EventTarget/DOMException/SourceBuffer and public media owners.
Commands use the frozen V dispatcher with -old-compiler -enable-globals and
VJOBS=2; the second batch adds -gc none. VTMP uses an isolated repository-owned
scratch directory. All 4,915 tracked inputs, 20 pinned
Source references and both compiler executables remain unchanged. Default and
no-GC before/after snapshots match exactly. No full HTML/LibJS/Wasm sweep is claimed.

The first full default batch passes 21/22 files but catches one further inherited
pause-fixture assumption: the inactive case had not drained its new start events
before selecting the pause task. The follow-up adds only that drain. Both final
GC-mode runs use this clean follow-up snapshot, with the failed 21/22 manifest and
log retained. No implementation changes follow the production compilation.

## Production verification

The original `fd83fa0a` implementation snapshot builds and signs the
macOS bundle with -prod -gc none, verifies
its signature and passes --headless-smoke. A standalone production probe uses
ordinary failure branches independent of V assertions. Actual DOM/fetch/play
callers establish the loaded media and two captured batches. The probe verifies
immediate state and one manager start, deferred event delivery, playing callbacks
before resolution, start-position capture despite the advancing clock, native
identity/flags/currentTarget cleanup, other-owner isolation and balanced realm
state. Native play Promise exposure remains outside this probe.

Both prior public pause pages remain pixel-exact against their 800×600 references
with zero tolerances (480,000 pixels each); these are native-binding compatibility
checks. The new play task path is verified by the model, native page and standalone
production probe. All 11 canonical smoke comparisons pass with unchanged bounds.
The separate SVG mutation set is not repeated because main.v and the native media
host are unchanged.

Its tracked inputs differ from the final verification snapshot only in
html/media_pause_task_owner_test.v. All implementation, native and production
probe/page bytes, Source references and compilers match; this fixture-only change
does not require rebuilding the unchanged production implementation.

Production retains 43 Source input/reference/font hashes,
exact probe/pages, logs, captures and artifact hashes. Its binary remains unchanged
throughout capture.
Binary SHA256: `e5c64ba538db48d96eb0064ba0df2d5b3e7cbf22f84b24c0ec1770ab6d51d0c4`.
Production manifest SHA256: `672b23c1aeb14601a9c033e6c1aeb7a22e0a0be99bd4891923e0d9176563b3da`.
Default manifest SHA256: `03c60e8dcd3135e16f3e64af939ee461fe9647d6d33238ea6929753b2280e447`.
GC-none manifest SHA256: `8edd3e1f38fa4b44868c2d25e69459fa6e66d99f6141e5638220844e0efe96e1`.
Final baseline manifest SHA256: `9ce11300bc4f88f4b8b9a490f4ee702258df08ba919911d976423de668f8ce90`.
Consolidated evidence: `Build/audit-fixes/media-play-task-evidence.json`.
SHA256: `626b0b04ae5138cb4e8d69babdb0fedf4e457b40009275f0e222b804ecea9f39`.
Initial baseline manifest SHA256: `364b99b9c3c95accc32f9a9565d78209a1b6a592b0777703c12047dcf0728646`.
Corrected initial baseline SHA256: `24b1c093842e0aed9ca29dfad2f890535fc71e02bd557f9588d20e97a170e779`.
Inactive-fixture focused manifest SHA256: `ee2dd479c56552ae45ce105dc1f6615330e5622e19b882480185cfe2dc7721c2`.
Initial 21/22 default manifest SHA256: `7c4df0e4482bbb29dccd1fae2964671de609021e74c295aea0fe455b72b6bb96`.

## Inventory and remaining port

The 78-owner inventory contains 432,398 implementation /
155,688 test V LOC across 2,193 owned files.
Only html/html_media_element.v and its two earlier HTML fixtures change among old
owned files, with one new HTML test. Root/native support remains excluded by
convention. All owned hashes match the frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-5a2ec71a.json`.
SHA256: `44718328cde1ee60f690db10c9ac8b7883ac35e0021a3a890ff0b42be8c852f4`.
Physical LOC does not measure parity. The ledger remains 32 fixed / 25 partial /
9 open; the wider findings are not closed by this selected media task slice.

The largest remaining port areas are [LibJS](../../libjs/PORT_STATUS.md) execution,
function/generator/async bytecode, builtins, RegExp, module linking and Intl;
[Wasm](../../webassembly/PORT_STATUS.md) opcode execution, instantiation, real exports,
native compilation and complete ownership; actual browser bindings, realms and
lifecycle integration; and the [broader services](additional-sources.md), networking,
collector and codec boundaries. The Wasm parser and all 500 pinned validator
handlers are already translated. JavaScriptCore's working browser execution does
not establish completion of the V LibJS runtime.

Implementation: [media lifecycle](../../html/html_media_element.v).
Tests: [model tasks](../../html/media_play_task_owner_test.v),
[native page](../../media/main_media_play_task_owner_test.v).
[Prior pause-task evidence](MEDIA_PAUSE_TASK_OWNER.md) retains its earlier snapshot.

The subsequent [started-audio slice](MEDIA_STARTED_AUDIO_OWNER.md) translates
the Source started-playback flag and per-element audible transitions, including
actual owning PageClient notification before Document lifecycle notification.
It retains this historical play-task snapshot and leaves wake locks, actual
Page-wide mute propagation, native play Promise creation and physical playback
as separate work.
