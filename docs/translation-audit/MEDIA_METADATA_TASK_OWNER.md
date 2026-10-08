# Metadata notification from the actual media readiness owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `8691a3b4`.

The exact nonempty-network HAVE_NOTHING to HAVE_METADATA transition now queues
loadedmetadata on the actual media owner's task queue. The synchronous fetch
adapter no longer fires its own metadata event. Metadata, duration and readiness
still commit immediately; listeners run later and read the live media state.
This shared branch covers ordinary fetched responses, direct readiness changes
and MediaSource initialization callbacks without a separate notification path.

## Source mapping and boundaries

HTML/HTMLMediaElement.cpp:2374–2405 defines the unchanged-state return, immediate
state/style update, network gate and exact metadata branch. Source queues a media
task and returns from this branch. The V implementation applies the network and
state guards to this selected branch and retains its existing ended-state,
wake-lock, natural-dimension and style updates. The other readiness branches
still require their own translations; this slice does not apply Source's global
network gate to those remaining adapters.

Source on_metadata_parsed establishes timeline state and duration, then reaches
set_ready_state(HAVE_METADATA). The translated callback likewise sets duration
before readiness. Removing the direct loadedmetadata dispatch from
process_media_response avoids duplicate delivery and lets the same notification
reach the existing MediaSource initialization caller in source_buffers.v.
SourceBuffer.cpp, SourceBufferProcessor.cpp and WebMByteStreamParser.cpp are
included in the frozen reference set for that caller.

Unlike first decoded data, metadata notification has no per-load flag. Unchanged
metadata and transitions back from data do not fire it; a later exact
nothing-to-metadata crossing queues another event. A direct jump from nothing to
a data state does not synthesize loadedmetadata. NETWORK_EMPTY still commits
metadata state without queuing this notification, matching Source's selected
branch gate.

The existing owner queue records its task source and Document. Reload cancels
only that media owner's pending event. Tasks queued after adoption use the new
Document; inactive delivery is discarded, and simply repeating the unchanged
ready state after reactivation does not reschedule it. This does not establish
automatic weak-node ownership or GC finalization.

Canplay/canplaythrough and the buffering-drop waiting adapter retain their prior
synchronous behavior. Full load/readiness/seek algorithms, resource timing,
autoplay/permission behavior, physical playback/decoder reset and native play
promises remain open. Resource fetch and metadata are still modeled by existing
synchronous adapters; these tests do not prove physical decoding. The browser
still uses JavaScriptCore. Native event checks call
EventTarget.prototype.addEventListener, preserving the compact bridge's prior
ready-video fallback and exercising the actual DOM listener binding.

## Focused evidence

Four model cases cover the exact old/new readiness transition across all four
network states, unchanged and direct-jump gates, actual fetched metadata delivery
ordered after durationchange and before first loadeddata, live state at delivery,
trusted target/currentTarget identity and non-bubbling/non-cancelable flags,
owner-specific reload cancellation, repeated exact transitions, adoption and
inactive delivery. A native page case exercises actual audio/video owners,
public load(), live readiness and duration getters, microtask versus task timing,
metadata-before-data ordering, reload and balanced execution contexts.

The sixth case appends a real minimal WebM initialization segment through a
SourceBuffer attached to a concrete DOM video owner. Metadata delivery reaches
that owner with one selected video track. Repeating the initialization segment
without a nothing-to-metadata transition does not repeat loadedmetadata.

The first baseline attempt contained an Option-propagation compile error in the
new model fixture. It is retained separately and is not counted as runtime
regression evidence. After fixing that fixture, the validated baseline compiles
all three selected files against unchanged 4f57b53f and exposes all six new
cases: the fetch/native paths fire synchronously, the direct and MediaSource
paths omit the event, and the inactive model case cannot find the missing task.
All three selected files pass after the translation.

The existing resource-selection fixture now checks zero metadata events before
its task drain and one afterward. The first-data no-load fixture explicitly
drains the legitimate metadata task before testing that its first-data flag has
not been armed. Both fixture updates are committed with the implementation.

The initial default-GC neighbor run passes 24 of 34 files. Disk exhaustion
prevents ten files from completing compilation; the failed run and its exact
log remain retained. A separate single-job recovery passes those ten files on
the identical committed implementation and test bytes. Thus all 34 files have
passing default-GC evidence across the initial run and recovery, not one clean
34-file run. The first GC-disabled run was deliberately interrupted as available
disk space fell; its partial log and unchanged snapshot are retained separately.
After recovery, the complete 34-file GC-disabled run passes on its own.

The selected files include the 66-case main regression, neighboring media
ownership, cancellation, promise and CSS tests, both first-data tests and three
MediaSource caller files. The production build/probe and captures freeze the
same implementation and tests. Every completed run preserves its before/after
tracked-tree hashes, Source references, compiler hashes, command and environment.
The interruption and compilation failures are not runtime regression evidence.

## Retained verification

| Run | Result | Manifest SHA256 |
| --- | --- | --- |
| Initial baseline fixture error | New model fixture does not compile | `515bd411ec7db58173e748b579ccf50243a415ed1503453bc263e0d5fbf52399` |
| Validated runtime baseline | 3 files fail after compiling | `7db2a2a6f70fe05d276ad3660a9b4419b1c29b8b0fccaf63ca6f8c564b68c71e` |
| Focused metadata callers | 3 files pass | `b27a273c00ea0597f7c57e47af173c7355b58f90171033a354eef9dae0bc222c` |
| Initial default-GC neighbors | 24 pass; 10 compilation failures | `b67740343ef1d8f6a27c1c3986c70db01a61439e7f6316a71724e6095588ad89` |
| Interrupted GC-disabled neighbors | Stopped for disk pressure | `7845abd2e5489565ef10e6548277d194aed0ee5457dc35d8c321c54e80990020` |
| Complete GC-disabled neighbors | 34 files pass | `378a52a63a92bc5f57e77dff7266fab79a54a35c474a2e83234528af6f842122` |
| Default-GC compiler recovery | 10 files pass | `1a1468ffe8346a384a1b944b44a920e34f603251e61f4e916989bd8b895dd027` |
| Production build/probe/captures | Probe/startup/viewports and 10 smoke cases pass; last capture fails | `77ec94bd8da5975c0aa96731f11bd16277b4c5219f48791ada256faa21be4424` |
| Final smoke capture recovery | Last smoke case passes pixel-exact | `9c5c7f7d2ecb3b12230bec725e321f274fb22688d7948fc3802baa0a16e198e7` |

The ordinary production probe compiles with -prod -gc none independently of test
branches. It validates actual audio/video owners and native load, delayed
metadata delivery before first data, live readiness/duration, actual trusted
wrapper identity, cancellation of both old events by reload, and balanced
execution contexts. The signed native bundle builds and passes non-windowed
startup. The initial smoke command passes ten of its eleven cases, then the final
`default-ignorable-code-points-not-painted` capture produces no image. Its log
and available artifacts are preserved. A separate capture of that case is
pixel-exact on the unchanged binary. All eleven canonical cases therefore have
passing evidence across the original comparisons and the focused recovery;
this is not one clean eleven-case command.

The two captured viewports exercise earlier native-load and load-rate-task
regressions against an exact green reference. They are not screenshots of a new
physical metadata decode. Logs, frozen input/reference hashes, probe source,
compiled probe and comparison artifacts are retained under the
Build/audit-fixes/media-metadata-task prefixes. No new browser launch diagnostic
reports were recorded.

Consolidated evidence: `Build/audit-fixes/media-metadata-task-evidence.json`, SHA256
`302344eecb235f25281fb313f854de83f5f5fc33461457568bc02aa4681a70f9`.
Production binary SHA256: `e8141324618c1dbdbd1831f44c45558a0acc6703d6654686785e66c2d59deac4`.
Physical inventory: `Build/audit-fixes/source-current-module-loc-8691a3b4.json`,
SHA256 `7879c3133f34be0941fe81a37d4f9e684dc20db92e47ce2891c8cc57fa171d98`.
Its 78 owners contain 432,769 implementation and 157,070 test V lines across
2,201 assigned files. The native root caller test is excluded from these package
counts. Physical counts do not measure parity; the historical ledger stays
**32 fixed / 25 partial / 9 open**.
