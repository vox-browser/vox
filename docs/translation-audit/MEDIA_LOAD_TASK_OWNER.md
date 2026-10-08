# Media load reset tasks and native caller

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reset implementation and focused tests: `5fd0c862`.
Native binding and actual compact caller tests: `3961abe6`.
Owner-specific cancellation fixture correction: `e9133c7e`.

`load()` now queues abort, emptied and reset timeupdate through the actual
media owner's task source. Reset state and the validated default playback rate
commit before those tasks run. Canceling old tasks leaves another element's
queue intact. Pending play promises still owned by an unpaused, nonempty-network
media element reject synchronously with one shared AbortError DOMException
(`Media playback was aborted`, legacy code 20), under the actual Document's
temporary execution context.

The native JavaScript operation validates the actual DOM audio/video receiver
before mutation replay, ignores extra arguments, returns undefined and calls
the same model. Its prototype descriptor is writable, enumerable and
configurable, with native function name load and length zero. Proxies and
prototype-only objects fail the brand check without invoking author traps.
Original mutation-replay exceptions retain identity. A default-rate validation
failure becomes an actual native NotSupportedError DOMException before fetch.
Parsed and script-created audio/video wrappers share this binding.

## Source mapping and remaining boundaries

- HTML/HTMLMediaElement.idl:38 declares the argument-free operation. The pinned
  binding operations/argument generators define receiver validation and unused
  argument behavior.
- HTMLMediaElement.cpp:783–890 load steps 5, 6, 7.1 and 7.8 remove the owner's old
  tasks and queue abort, emptied and position-reset timeupdate respectively.
  The translated existing task wrapper preserves document and task-source
  identity, discards inactive-document delivery and supports later cancellation.
- cpp:843–850 step 7.6 commits paused state and takes the current promise batch.
  h:306–315 creates one realm exception for that batch. cpp:3322–3335 enters a
  temporary execution context around rejection. The existing typed AbortError
  helper is now used by load as well as explicit pause.
- cpp:878–888 validates the default playback-rate reset before resource
  selection. cpp:485–498 promotes explicit load after load_element, before
  Source's stable-state task. The V selection adapter remains synchronous and
  retains its earlier promotion-before-load workaround.

This is a completed reset-event/rejection slice and native caller, not a full
load or media translation. Stable-state resource selection, loadstart, readiness
and fetch failures still use synchronous adapters; selected new reset events
therefore do not establish the complete Source event sequence around a new
resource. Existing unconditional empty-network clock/duration resets remain a
compatibility boundary, whereas Source groups those resets inside step 7.
The first-data-load flag, physical playback-manager reset, permissions/error
paths, defaultMuted initialization, complete readiness/seek behavior, native
play promises and automatic ownership/finalization remain open. Native play
still uses the compact resolved-Promise stub; the promise tests enter the actual
V play caller or a real Document-bound WebIDL promise context.

Source load step 4 is itself FIXME: a promise batch already captured by a
canceled playing/pause task remains pending. The corrected tests preserve that
behavior. The original no-resource play/load CSS fixture is not claimed to pass.
Closing the rejection context when no author script is on the stack may perform
a microtask checkpoint before load returns. The new reset events remain queued
until task delivery.

## Focused failures and corrections

The finalized four model cases fail on unchanged `df287222` in an isolated
checkout: synchronous abort observes pre-reset state, rejection scheduling
observes execution depth zero instead of one, and reload exposes no queued reset
events to cancel. Empty-network and already-paused promise guards stay intact.
The two native test files also compile and fail before the operation exists.
The finalized three new files then pass all nine cases.

The initial model fixture had Result/Option constructor errors, and an
intermediate promise test incorrectly assumed context cleanup could never run
reactions before return. Those failed runs are retained separately. Neither is
counted as implementation evidence. The final old-code baseline uses the exact
final model test bytes and completes without that intermediate callback panic.

Both frozen 33-file runs expose one cancellation-fixture failure. The pause test
uses a global loop drain for the new load tasks, which also consumes the second
owner's pause task before its later manual take. The correction manually takes
only the first owner's tasks and asserts the second queue is unchanged. The
neighboring play test uses the same explicit owner boundary. An intermediate
private edit used invalid V while syntax and failed compilation; its manifests
and source bytes are retained. Final corrected fixture checks pass in both GC
modes without implementation changes.

Passing evidence covers all 33 affected files in each GC mode as a composite:
the initial runs each pass 32 files, and the corrected pause/play fixtures pass
two files each. This is not a single clean rerun of all 33 files. The ordinary
production probe and browser checks freeze implementation `3961abe6`; only the
two test fixtures differ at the final correction commit. Evidence checks every
implementation byte and uses the corrected fixture hashes for final coverage.
The main regression includes 66 cases.

## Retained verification

All manifests record argv, environment overrides, timings, log SHA256, Source
reference hashes, compiler hashes and matching before/after input snapshots.
Tests use the retained V 0.5.2 fallback via -old-compiler, -enable-globals and
both default and disabled GC. Production builds use -prod -gc none.

| Run | Result / seconds | Manifest SHA256 |
| --- | --- | --- |
| Initial model fixture compile | 1 failed, 1 total / 12.984 | `b394342ac4a8a328ae9d3cf9daff53393cc442110dc5d7d02dcd8f126f69dc96` |
| Intermediate old-code model | 1 failed, 1 total / 12.488 | `4350ca0efa6c8e8eb2afe2fefc541f598f9c695f9143a230191905edc4df3465` |
| Final old-code model baseline | 1 failed, 1 total / 17.656 | `6b4e9edba10832956445551d9a04ca3cba88464e0bb536065fdfc452a4aece80` |
| Native operation baseline | 2 failed, 2 total / 34.859 | `66ede34f11386d3e0a4b7467f19ef45c861b8f8226ce0415323f6c61bc87b4e5` |
| Intermediate model assumption | 1 failed, 1 total / 13.029 | `a6de9ee33e284eccb2a223424d534aa16b23c17153e0b38da009d77398068c94` |
| Final new files | 3 passed, 3 total / 44.600 | `6cd326d7393c9ac741da460a9c29a187052650322b6315f3f46e9c6cba1dddbe` |
| Default GC neighbors | 1 failed, 32 passed, 33 total / 310.447 | `4c85edc102a3a96f2d736723665e50158b955acf6ea7a8f0a8a651b7b646d489` |
| GC disabled neighbors | 1 failed, 32 passed, 33 total / 403.515 | `1dcf951cfda7fe9374729f767f09b8e25d574f9c0aaec9efc01a130f7643f55a` |
| Private fixture syntax/default | 2 failed, 2 total / 1.763 | `e3b566cfe492175fae23f1aa614abd1e62e08ff910b3546462739e85bdd52209` |
| Private fixture syntax/no GC | 2 failed, 2 total / 1.671 | `4c2d936fbceece13015ea1623a5c502fc7d85b7e30ae0db9aded0418e90e834d` |
| Corrected fixtures/default | 2 passed, 2 total / 94.245 | `5f6341b0feb37d50e9a387ad52d1052d144772861ff7a606c333caef93ed9888` |
| Corrected fixtures/no GC | 2 passed, 2 total / 92.441 | `60aea30bb951394bfb52b3c32157094a39f0b7875f9155fb2126b700d6485607` |
| Production | all steps pass / 279.811 | `324df533b776dbab73e6974a4ef4312468ce77ff8d7dc29ce7ec2d08dc99f40a` |

The production probe verifies native branding and unused arguments, synchronous
clock/rate reset, shared rejection identity and JavaScript DOMException conversion,
owner-specific cancellation, deferred event ordering and balanced actual
execution contexts. The root test additionally exercises real compact DOM src
removal replay and a script-created audio element. Native-load and load-rate-task
viewports are pixel-exact against their captured green reference. All 11
canonical smoke comparisons pass the existing comparison rules. No new Ladybird
launch reports were observed.

Consolidated evidence: `Build/audit-fixes/media-load-task-evidence.json`, SHA256
`6717783d05de0012592ec0e403a4f9b4cd90c359ad6e7ed63d41dd56bed6dc8d`. Production binary SHA256: `af65f3c17646acb506b15a80869abf1b3f2e0cb179905924eb02d0d826f9af0d`.
Physical inventory: `Build/audit-fixes/source-current-module-loc-e9133c7e.json`, SHA256 `ca34629ff1875436ef275203e37afc967aec35c022280020d03143447b7e159e`.
The 78-owner inventory includes `432,741` implementation and `156,716`
test V lines across `2,199` assigned files. Root/native support is excluded;
physical counts do not measure parity. The ledger remains **32 fixed / 25 partial /
9 open**.
