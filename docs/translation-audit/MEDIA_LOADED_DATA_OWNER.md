# First decoded-data notification and document delay release

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Implementation and focused tests: `5ea723a0`.
Play-task ordering regression: `d5122e2b`.

The actual HTML media owner now tracks whether first decoded data has been
reported since its last load. Explicit and automatic load entry rearm the flag.
A nonempty-network HAVE_METADATA to HAVE_CURRENT_DATA-or-higher transition
consumes it when queuing loadeddata. Readiness and CSS buffering state commit
immediately; event delivery waits for the owning media task. Later buffering
oscillations do not repeat the event. Reload cancels that owner's old task and
rearms the flag without canceling another element's event.

The same branch releases its current DocumentLoadEventDelayer synchronously,
even when first data was already reported. Adoption transfers that existing
owned delay to the new Document; release does not consume an independent token
left on the old Document. Empty-network changes and a direct jump from
HAVE_NOTHING to data do not enter the branch or release that token.

## Source mapping and boundaries

- HTML/HTMLMediaElement.h:343 initializes the first-data flag to false. The V
  field has the same default; a readiness crossing without a load does not queue
  loadeddata merely because the readiness value changed.
- HTMLMediaElement.cpp:783–785 rearms the flag at load entry, before task
  cancellation and default-rate validation. Both translated public load and
  automatic load_element use this entry.
- cpp:2393–2395 excludes NETWORK_EMPTY. cpp:2407–2428 selects the exact old
  HAVE_METADATA state, checks the new data threshold, consumes the first flag
  before queuing loadeddata, and clears the Document load delay. The release is
  synchronous in the pinned implementation, despite the adjacent specification
  comment referring to event firing.
- The existing translated queue preserves actual task-source and Document
  identity and skips inactive-document delivery. A skipped or canceled event
  does not restore the consumed flag; another load rearms it.
- DOM/DocumentLoadEventDelayer.cpp:11–67 defines owned increment/decrement and
  transfer behavior. V uses the existing explicit finish operation rather than
  C++ destruction. Only this media owner's token is finished.

This completes the selected first-data branch. The full set_ready_state algorithm
remains open: loadedmetadata, canplay, canplaythrough and waiting retain their
prior synchronous behavior, including the existing buffering-drop adapter.
Autoplay/permission behavior, stable-state resource selection, physical decoder
and playback-manager reset, complete load/readiness/seek algorithms and native
play promises are not completed here. Synchronous resource adapters still release
some load delays earlier than Source; this slice verifies readiness-owned release
when a delay remains outstanding, not the entire fetch/delay lifespan.

The browser's own compact addEventListener method still has its prior ready-video
loadeddata/seeked fallback. The native tests and production probe use
EventTarget.prototype.addEventListener to exercise the actual DOM binding and
trusted event delivery. Main/native host code and the fallback are unchanged.
The no-resource play/load CSS fixture is not claimed to pass. The browser still
uses JavaScriptCore; this work does not establish LibJS runtime parity or automatic
weak-node ownership/finalization.

## Focused evidence

Five model cases cover all three new readiness thresholds, live readiness at
delivery, duplicate suppression before and after delivery, no-load/empty-network/
exact-old-state gates, explicit and automatic rearming, cancellation with a
second owner, adopted delay release with an independent old-document token, and
inactive delivery without implicit rearming. A native page case exercises both
actual audio/video owners, native load, actual DOM event identity and trusted
flags, live readyState getters, repeated crossings, task versus microtask timing
and balanced current-document execution contexts.

The two new files compile against unchanged `c7ab96ee` and expose the original
synchronous event and missing guards in all six cases. The inactive-delivery case
ends with missing loadeddata task because that implementation had fired it
synchronously. The baseline's implementation/test bytes, log and input snapshot
are retained. The same six cases pass after the translation.

The initial frozen runs each pass 31 of 32 affected files in default GC and
`-gc none`, including the 66-case main regression, neighboring media ownership,
cancellation, promise and CSS paths, and three MediaSource caller files. Each
exposes one stale expectation in `html/media_play_task_owner_test.v`: it expects
only a playing task after readiness changes, whereas first-data notification now
queues loadeddata before playing. Both failed runs are retained unchanged.

`d5122e2b` updates that regression to execute loadeddata first and verifies that
the original two pending play promises remain in their previously captured
batch. A third promise created by the loadeddata listener stays pending through
the playing task and resolves only through its own later task. The playing event
retains its captured playback position even after the manager clock changes.
The corrected file passes separately in both GC modes on a private snapshot;
all implementation bytes and the other 31 test files match the initial freeze.
Thus all 32 affected files have passing evidence in both GC modes across the
initial runs and focused reruns. This is composite coverage, not one clean
32-file run.

Every run preserves its before/after tracked input hashes, both compiler hashes,
Source pin/reference hashes and native archive hash. The production build/probe
and captures freeze `5ea723a0`; `d5122e2b` changes only the play regression, with
no implementation differences from the production snapshot.

## Retained verification

| Run | Result | Manifest SHA256 |
| --- | --- | --- |
| Baseline, two new files | 2 files fail after compiling | `2d17bd263927caf64f4ac364a252fd03a2d1ca9c83051624893c474bfeccdd2e` |
| Focused, two new files | 2 files pass | `0252cb0355891c4cc021e529127026035db636ec3677e9c927450d5a1fc9e793` |
| Initial 32 files, default GC | 31 pass, 1 stale fixture fails | `596b149aa09bb47e77a9b391ca5f190955739a1167663d2a3b6160678d8e7d14` |
| Initial 32 files, GC disabled | 31 pass, 1 stale fixture fails | `1468981810bd0dd9ecde48240cdc8df31912fbd08ec4a187f7e6b7c8a775f78f` |
| Corrected play regression, default GC | 1 file passes | `2aa7b2119ca05429cf9c16cbb30472c841767866a801c75deacc7884887086a4` |
| Corrected play regression, GC disabled | 1 file passes | `8dae564e4405bda25a60bb1effb9596131641c40c0e76c0ba7c141f86a774cca` |
| Production build/probe/captures | All steps pass | `54d3bd1aca259e6d53f25cf50bd45aaa4c6915a36a6082df0ba6f04b69b7d683` |

Manifests and their logs are retained under `Build/audit-fixes/`, using the
`media-loaded-data-frozen-*` and `media-loaded-data-production` prefixes. Each
manifest identifies its exact command, duration, environment, log and input
hashes. The retained failed baseline and initial neighbor runs remain part of
the evidence.

The ordinary production probe uses -prod -gc none independently of test branches.
It validates the actual audio/video owners and native load, delayed event
visibility, native target/currentTarget identity and trusted flags, live readiness
at delivery, repeated buffering transitions, cancellation/rearming and balanced
execution contexts. The signed bundle builds and passes non-windowed startup.
The earlier native-load and load-rate-task viewport inputs remain pixel-exact
against their captured green reference; these are native caller regressions,
not screenshot evidence of new physical decoding. All 11 canonical smoke
comparisons pass the existing comparison rules. No new browser launch diagnostic
reports were produced.

Consolidated evidence: `Build/audit-fixes/media-loaded-data-evidence.json`, SHA256
`0db0c15ff02fa6cfaafeff913b0c0f727d4fec9465ff1ffa519e69af8095b18f`.
Production binary SHA256:
`41253f6cdbf153b02652713def3644874b50d82cb7519a17e63f5a741fb65c35`.
Physical inventory: `Build/audit-fixes/source-current-module-loc-d5122e2b.json`,
SHA256 `e950bced50cfb9ee3924edcfb6344b9690d28637d1813fee5f611ea53662e71c`.
Its 78 owners contain 432,759 implementation and 156,900 test V lines across 2,200 assigned files. Root/native support is excluded.
Physical counts do not measure parity; the ledger stays **32 fixed / 25 partial /
9 open**.
