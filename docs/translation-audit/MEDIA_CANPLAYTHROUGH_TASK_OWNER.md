# Canplaythrough notification from the actual media readiness owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `f3c941ee`.

A nonempty-network media owner now queues canplaythrough whenever it enters
HAVE_ENOUGH_DATA. The notification follows any first-data, canplay and
readiness-driven playing tasks from that transition. Readiness commits
immediately, and later listeners read live state rather than a captured value.

## Source mapping and boundaries

HTML/HTMLMediaElement.cpp:2374–2394 commits changed readiness and style state,
installs its ended/wake-lock/natural-dimension guard and applies the network gate.
The enough-data branch at 2449–2468 queues canplaythrough after canplay and
notify_about_playing. An unchanged state returns before that branch. A later
crossing into enough data queues another notification; there is no once-per-load
flag. Future-to-enough requires only canplaythrough, while metadata-to-enough
can also queue first data, canplay and playing.

The V slice replaces the synchronous canplaythrough dispatch with that exact
nonempty-network enough-data notification. It retains existing immediate
readiness, CSS, ended-state, wake-lock and natural-dimension updates. It uses the
actual owner's existing media task queue, task source, Document and active
execution check. Reload cancels only that owner's old task. Tasks queued after
adoption use the adopted Document; inactive delivery is discarded without
rearming an unchanged readiness state.

The enough-data autoplay substeps remain unported here. Existing autoplay still
uses the resource-selection/fetch adapters. The buffering-drop waiting adapter
remains synchronous, and Source's global NETWORK_EMPTY gate is still incomplete
outside the selected metadata/data/canplay/canplaythrough notifications. Complete
load/reset/readiness/seek algorithms, permissions, public native play promises,
physical decoding/playback, weak-node ownership and automatic GC finalization
remain open. The browser continues to use JavaScriptCore.

## Focused evidence

Five model cases cover all four network states and old readiness states, current,
future and enough destinations, unchanged-state suppression, direct jumps,
trusted target/currentTarget identity, non-bubbling/non-cancelable flags, task
source and Document, microtask versus task timing, live readiness at delivery,
repeated crossings, owner-specific reload cancellation, adoption and inactive
delivery. One case takes two pending play promises through an actual waiting
play() call and verifies loadeddata, canplay, playing, canplaythrough order. The
original promises resolve after playing and before canplaythrough; the starting
position remains the captured value despite the manager clock advancing.

The native page case uses actual audio/video owners, public load(), native live
getters and EventTarget.prototype.addEventListener. Both owners report first
data, canplay and canplaythrough in task order, then repeated native reload
cancels the old notifications. Native event wrappers retain actual trusted
identity, and execution contexts balance. The compact bridge's existing own
ready-video listener fallback remains unchanged. Public native play promises
are still supplied by their prior resolved-promise adapter.

The seventh new case attaches a SourceBuffer to a concrete DOM video, appends
real minimal WebM initialization, sets a short finite MediaSource duration and
appends a real coded-frame segment whose buffered range reaches that duration.
The existing buffer-monitoring caller reaches enough data without a direct
ready-state assignment. First data and canplay arrive before canplaythrough;
another append without a readiness crossing does not repeat the notifications.
These demuxing/model checks do not establish physical decoding.

The initial baseline contains an Option/Result mismatch in the new owner
fixture, retained as compiler-error evidence rather than a seven-case runtime
baseline. After correcting that fixture, all three baseline files compile
against unchanged 608cf366 and expose all seven new cases at runtime. The old
implementation dispatches synchronously, precedes the queued first-data/playing
events, fires with NETWORK_EMPTY and leaves no task for cancellation/inactive
checks. The same corrected new test bytes pass after the translation.

Existing first-data/canplay fixtures now account for the legitimate extra task
at enough data. They retain their prior first-data-once and captured play-batch
assertions; a listener-created promise still waits for its own task after the
original playing batch and canplaythrough.

## Retained verification

The final default-GC and GC-disabled runs each pass the same 19 selected files
in one clean, single-job run on unchanged `f3c941ee` code and test bytes. Coverage
includes the new notification, prior canplay/first-data/metadata owners and
native callers, play/load promises and cancellation, adoption, wake-lock,
actual MediaSource callers, and the 66-case main regression file. This is
selected neighbor coverage, not the complete repository suite.

| Run | Result | Retained manifest under Build/audit-fixes | SHA256 |
| --- | --- | --- | --- |
| Initial fixture/compiler baseline | 3 failed files; fixture compile error retained | `media-canplaythrough-task-frozen-baseline-manifest.json` | `aeb9b13fafa9c383481f93ac70f13facabe41d85c8f29136757f0402c4f10576` |
| Validated runtime baseline | 3 failed files; seven new runtime cases exposed | `media-canplaythrough-task-frozen-baseline-validated-manifest.json` | `fee66ce10bb89bc15fa05f9cee190bd909097e62603264557eb6cecf57c0755c` |
| Focused implementation and fixture run | 5/5 files passed | `media-canplaythrough-task-frozen-focused-manifest.json` | `e8d70e6f4d6c3d65c8639d13171d0fdd6a0145b5290eb61681d6d0f69fe06837` |
| Default-GC selected neighbors | 19/19 files passed | `media-canplaythrough-task-frozen-default-manifest.json` | `43dc81c2969ba130ed2d895e3870058331dcca414d486931f47f033e0fa105d9` |
| GC-disabled selected neighbors | 19/19 files passed | `media-canplaythrough-task-frozen-gc-none-manifest.json` | `de15298fc9e6ee03b4c1f29d64685f94729ad2796f85a0aac274060f8aea402d` |
| Native production verification | 12 steps passed; 11 screenshot cases passed | `media-canplaythrough-task-production-manifest.json` | `071be2765ee9b8fa98b360d11ed1ff853da48e5d9641a64ee539e55d990c709a` |

The production bundle builds and passes strict code-signature verification and
headless startup. Both earlier native-load regression viewports are pixel-exact
against the green reference, and all 11 canonical screenshot smoke cases pass
with their existing case tolerances. Every production step uses an unchanged
binary, SHA256 `62b359c8fa9acbcf08d77f73ea110566af90d6b9837986ba16da35c4cf78d01a`. All
51 production artifacts and 17 command logs remain available; no launch report
was generated. The initial compiler-error baseline and corrected failing runtime
baseline are retained separately. Source pin, reference files, compiler binaries,
native archive, selected file bytes, commands and environment overrides are
recorded in the manifests.

The production probe is ordinary code compiled with -prod -gc none independently
of test branches. It exercises actual native audio/video load and listeners,
video future-to-enough and audio metadata-to-enough, live readiness/duration,
trusted wrapper identity, delayed delivery, reload cancellation and balanced
contexts. Synthetic readiness/fetch responses in this probe do not prove physical
media decoding. The two captured viewports are earlier native-load and
load-rate-task regression pages against their green reference.

Consolidated evidence: `Build/audit-fixes/media-canplaythrough-task-evidence.json`,
SHA256 `0305149edce6527dbaa4f2f97b9229d82418aba8cae7c10cc2818b3afbc8daa6`.
Its helper and manifest hashes preserve all baseline, focused, neighbor and
production evidence. The prior canplay evidence,
helpers, manifests, logs, artifacts and inventory remain unchanged. Compiler
scratch can be removed after verification; source snapshots, probe, logs,
executables and images are retained.

Physical inventory: `Build/audit-fixes/source-current-module-loc-f3c941ee.json`,
SHA256 `ae5722fa6d391ca279af81c88e055a1371129ff11fd5f5ef4fcb067a6299364a`.
Its 78 owners contain 432,783 implementation and 157,572 test V lines across
2,203 assigned files. The root native caller test is excluded from these package
counts. Physical counts do not measure parity; the historical ledger remains
**32 fixed / 25 partial / 9 open**.
