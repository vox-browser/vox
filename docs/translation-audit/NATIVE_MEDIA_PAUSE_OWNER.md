# Native media pause owner and caller

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Model entry and three focused cases: `f8691ab9fb673d2eec65a615010b42df33f464cd`.
Native operation and six focused cases: `cb4a414eb361c8dbcbf4157da42e8b4d963c85e9`.

`pause()` now invokes resource selection when the actual media model has
NETWORK_EMPTY, then runs its existing internal pause steps. The native
zero-argument method calls that same DOM audio/video owner after replay and
returns JavaScript undefined. Parsed and script-created media keep that owner
and their actual EventTarget across insertion.

## Source and retained boundaries

HTMLMediaElement.idl:65 declares `undefined pause()`. HTMLMediaElement.cpp:643–653
selects the resource on NETWORK_EMPTY before pausing. The V caller now follows
those two steps, using the existing automatic selection entry. It does not
promote `preload="none"` selection to an explicit fetch or resume an already
deferred selection, and a nonempty network state does not reselect its source.

The V resource-selection adapter remains synchronous and Result-returning,
where Source schedules selection asynchronously. As in the existing play
caller, its adapter failure is consumed so the void pause entry still runs the
internal pause steps. The adapter's error state/event and string rejection
remain visible; this slice does not translate them into fabricated native
exceptions or claim asynchronous selection parity.

operations.py:452 onward checks the receiver before invocation. The binding
validates a registered actual media wrapper before replay, including before
Proxy traps. `pause` has native function identity, name pause, length zero and
writable/enumerable/configurable prototype flags. Extra arguments are ignored
without conversion. Original replay exceptions survive, and an exception
prevents the following model mutation.

HTMLMediaElement.cpp:2717–2745 queues timeupdate, pause and actual AbortError
DOMException rejection as one media task. Existing V pause internals still
perform those operations synchronously and reject with a string. Existing
played-range accounting, playback hooks and explicit live-clock position commit
are preserved. Those internals need a separate translation; the new native
method exposes their current behavior. Native play/load/canPlayType/defaultMuted,
complete prototype hierarchy, foreign realms, real manager/clock/decoder/pipeline,
complete media/MSE and physical GC remain open. The browser uses JavaScriptCore.

## Focused and frozen checks

Three actual-DOM model cases cover selection before pause, continuing after
selection failure, empty sources, repeated calls and automatic preload-none
selection without resuming it. Four native cases cover descriptors, receiver
order, ignored arguments, original replay exceptions, empty-resource selection,
loaded playing ownership, live clock commit and repeated calls without refetch
or duplicate manager pause. Two public page cases cover parsed owners, default
start positions, created audio before/after insertion, actual EventTarget
identity, single owner registration and ordinary/SVG receiver rejection.

All nine new cases fail at runtime on the unchanged old implementation. The
retained baseline has no compiler errors, and all final new test bytes match
its private copies. The model and native/public focused batches each pass 2/2
files, with their implementation and tests committed together.

| Run | Exit code | Seconds |
| --- | ---: | ---: |
| baseline | 1 | 150.454 |
| focused-model | 0 | 43.672 |
| focused-native | 0 | 52.866 |
| default | 0 | 427.735 |
| gc-none | 0 | 324.724 |

All 18 affected files pass with default GC and GC disabled on the same clean
committed `cb4a414e` snapshot. They include the 66-case main
regression, existing media model/load/currentTime/seek callers, native
state/ranges/currentTime/fastSeek/getStartDate/EventTarget, MediaSource/SourceBuffer
and public currentTime/fastSeek/getStartDate integrations. Commands use the frozen
V dispatcher with -old-compiler -enable-globals, VJOBS=2 and -gc none for the
second batch. All 4,909 tracked inputs, 18 Source
references and both compiler hashes remain unchanged. This is a selected affected
batch; no complete HTML/LibJS/Wasm sweep is claimed.

## Production verification

The same snapshot builds and signs the macOS bundle with -prod -gc none,
verifies the signature and passes --headless-smoke. An ordinary-branch production
probe, independent of V assertions, verifies the descriptor and brand, ignored
arguments, actual empty-resource selection, loaded playing owner, live clock
commit, repeated calls, preload-none deferral and adapter failure through the
native method.

Two public JavaScript pages use ordinary green/red conditions independent of
V assertions. Each is pixel-exact against its 800×600 reference: 480,000 pixels,
zero tolerances. All 11 canonical smoke cases pass with unchanged bounds.
The compact script bridge in main.v is byte-identical to the baseline; this
batch does not rerun the separate SVG mutation set.

Production preserves 41 Source input/reference/font
hashes, the exact probe and pages, logs, captures and artifact hashes. The bundle
binary remains unchanged throughout the captures.
Binary SHA256: `20f8b2c38a74bf3c1f31b51c15d15d8ca2e350d55ac0bb978000a37b59c2de9b`.
Production manifest SHA256: `9951d206ab681e35e5f4a219c30f1db2d030fee11662cb8fcf3548d73f96d5c7`.
Default manifest SHA256: `bbc844fc09b080e6f7fe69e30347ea33767d8e4d34a5529304124bb96cea3d0a`.
GC-none manifest SHA256: `5651d2a632423daf3751d4b859529a853c5669b21cdbc7158762e40fa62ec4c7`.
Consolidated evidence: `Build/audit-fixes/native-media-pause-evidence.json`.
SHA256: `6924901b16c1ebd14390132e9c6ac9273f191eadc3313953b8938bc8f26a1ab3`.
The first production probe check stopped before building because an unspaced
`&&` expression was parsed as pointer operators by the older compiler. That
fixture diagnostic, its exact probe/pages and log remain under
Build/audit-fixes/native-media-pause-owner-production/. The corrected probe
and successful run use the separate
Build/audit-fixes/native-media-pause-owner-production-corrected/ directory.
The tracked implementation and test snapshot remain unchanged.
Initial probe-check manifest SHA256:
`a9a75bb3626f675320fc5ed4f377fa929b43e0e8bd4b8d9bb7fcf91e8f26f28b`.
Frozen test artifacts are retained under
Build/audit-fixes/native-media-pause-owner-frozen-*.

## Inventory and remaining audit

The refreshed 78-owner inventory contains 432,354
implementation / 155,221 test V LOC across 2,191
owned files. Only the HTML model changes among prior owned files, with one HTML
caller test added. Browser/root support follows the existing exclusion convention.
All owned hashes match the frozen snapshot.
Inventory: `Build/audit-fixes/source-current-module-loc-cb4a414e.json`.
SHA256: `3311fe794df0b27328958547b4152aa70b9d786c85fa5290d5f3f41ee4af0cfa`.
Physical LOC does not measure parity; the ledger stays 32 fixed / 25 partial /
9 open. This selected caller/binding slice does not close the larger runtime or
ownership findings.

Implementation: [model](../../html/html_media_element.v),
[native binding](../../browserjs/media_element_host_darwin.c.v).
Tests: [model caller](../../html/media_pause_caller_test.v),
[native](../../browserjs/media_element_pause_host_test.v),
[public page](../../media/pause_owner_test.v).

The subsequent [pause-task slice](MEDIA_PAUSE_TASK_OWNER.md) queues explicit
pause's timeupdate/pause/rejection body and uses one shared AbortError record
under the actual document execution context. The earlier evidence and remaining
boundaries above retain this document's cb4a414e snapshot. Native play promises,
other rejection paths and synchronous selection remain separate work.
