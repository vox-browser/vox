# Duration and volume event task ownership

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Duration implementation/tests: `3c654b6bdb65e68f3d93951f2d226bc4c3e2c95b`.
Volume implementation/tests: `214de36b39e5ae36b7fe34ece6e470b3bf17487a`.

Known-duration updates now queue durationchange through the existing owning
media-element task. The duration field, end-seek and ended-cache scheduling
remain immediate. Volume and muted changes queue volumechange through the same
boundary while effective-volume hooks and audio state update immediately.
Callbacks read live state; they do not capture a setter's old value.

## Source and actual caller boundary

Pinned HTMLMediaElement.cpp queues durationchange before the optional end-seek,
then installs the duration, schedules cache recomputation and repaints. Its
internal setter queues every non-NaN call, including repeated known values.
MediaSource's separate duration algorithm returns for an unchanged value before
calling the media setter. Both behaviors are preserved. A NaN reset queues no
new duration event; load removes this owner's regular tasks.

The volume/muted caller queues an event only when its value changes. Existing
range validation and repeated-value no-ops remain intact. Page mute refreshes
effective volume without a volumechange event. Changes made by a listener
enqueue another task rather than recursively dispatching a second event.

Both slices use the existing actual task queue, owning Document, cancellation
IDs and execution-time fully-active guard. The actual audio/video DOM node is
the event target. The translated task sources are still shared enum values
with per-owner cancellation IDs; this does not implement Source's complete
unique-task-source or GC ownership model.

Four duration model cases cover microtask/task separation, live repeated values
and the step-1 cache, duration-before-seek ordering, owner-specific load/NaN
cancellation, and actual document/task ownership. The inactive-document case
extracts and directly executes a task only to prove its negative delivery guard;
positive delivery cases use the real event loop. Three volume cases cover
immediate hooks, page mute, validation/no-ops, load cancellation and callback
non-reentrancy. Existing DOM ancestor-capture and native wrapper target cases
now use an actual active Window and wait for the queued volume event.

The native duration case uses an actual Page, navigation Document, object-URL
MediaSource and associated DOM media model. Its sourceopen callback assigns
10, 10, then 20: two duration events arrive after the synchronous body and
Promise microtask, and both read 20. Trusted target/currentTarget, unrelated
owner isolation, attachment identity and balanced realm/VM state are checked.
The full page uses EventTarget.prototype.addEventListener; the ordinary compact
listener stub remains separate. Native volume operations are not exposed by
this slice: its existing wrapper-target test drives the actual V model setter.

## Executed checks and diagnostics

The initial duration model fixture used the wrong Event getter and failed
compilation. The volume and native MediaSource timing assertions executed and
failed. After correcting that getter, all four duration cases executed their
baseline failures. The first duration-focused run passed two files; three
compilations failed because disk space was exhausted. Rebuildable Rust
incremental caches were removed, preserving probe binaries, inputs and evidence.
A retry started before its file-selection edit finished and was stopped; its
owned-process record and partial log are retained separately. The corrected
retry passed all three unfinished files on the unchanged focused snapshot.
The first volume-focused run passed both model files but the native fixture
tried to recreate its navigation Document's existing Window and hit the identity
guard. The next retry exposed a missing optional-return unwrap in the new
associated-document assertion. The corrected fixture unwraps that return,
reuses the actual owner and passes. These diagnostics are retained and are not
reported as passing runs.

| Run and result | Seconds |
| --- | ---: |
| Initial baseline: duration compile defect; volume/native runtime failures | 320.019 |
| Corrected duration baseline: four runtime failures | 140.310 |
| Duration focused: 2 pass; 3 compilations fail on full disk | 278.950 |
| Unfinished duration files: 3/3 pass | 208.629 |
| Volume focused: 2 pass; 1 native Window setup failure | 180.732 |
| Native owner retry: optional-return assertion compile defect | 166.354 |
| Corrected native owner assertion: 1/1 pass | 171.129 |
| Frozen default: 20/20 pass | 933.030 |
| Frozen gc-none: 20/20 pass | 905.360 |

Commands use `/Users/alex/code/v/v -old-compiler -enable-globals`, VJOBS=2;
the second broad batch adds `-gc none`. Both final batches pass all 20 selected
files on the same clean, committed `214de36b` snapshot,
including the eight new cases, native target/completion/state neighbors,
the 66-case main regression, adoption, seeking, step-1 scheduling and
MediaSource/SourceBuffer neighbors. All 4,882 tracked files,
eight Source references and both compiler executables stay unchanged through
each test run. Feature hashes match their separate commits. This is a selected
affected-file batch; no full HTML, LibJS or Wasm sweep is claimed.

## Native production verification

The same snapshot builds the production macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 788.136 seconds.
Signature verification and --headless-smoke pass. A public MediaSource page
turns green only after its two trusted, correctly targeted duration events
read the latest duration following the synchronous and microtask checks.
The expected viewport matches all 480,000 pixels with zero tolerances.
This proves the selected event timing and DOM owner through the production
path; it does not prove decoder consumption or native volume setters.

All 11 configured smoke screenshots pass within existing bounds; eight are
pixel-exact. The existing residuals are unchanged: inline-node differs at 13
pixels (maximum channel error 1), text-decorations at 1,341 (2), and canvas-text
at 1,994 (8). No tolerance changes. The earlier 13 SVG mutation pairs are not
rerun because main.v,
the native media host and the EventTarget bridge remain unchanged from the
previous verified snapshot. Production retains 31
Source inputs/references/font files, both compiler hashes, generated page and
screenshot/log hashes, and an unchanged signed binary.

Binary SHA256: `5ff50081a1a2ef82f1f9f6d02b8c680f82ba8c90feac02fc184a4bb1bf88969b`.
Production manifest SHA256: `ed2b13c63c15ae21419b919cf77399e8368441b2c7824e3549b55901a8c27393`.
Default manifest SHA256: `4e759e1396a0183851da938d1e72dc01665a0e8c002ba8c05079b050578d88b5`.
GC-none manifest SHA256: `a3b2fc64a71ca7c4acfbfd2bdf248998f55b30f5bb9895f2a0b08778617ce06b`.
Consolidated evidence: `Build/audit-fixes/media-property-tasks-evidence.json`.
SHA256: `bc5d3bcc93d3b48f195b6b3cc8fa3d4e0853abcac43e229b42ae603ebd003e0b`.
Private manifests/logs use the media-property-tasks prefix. Production
artifacts are under Build/audit-fixes/media-property-tasks-production/.

## Remaining scope

Source's volume/mute autoplay-policy pause and muted-style invalidation are
still missing. No synthetic is-allowed-to-play flag or policy was introduced.
Native volume/muted property operations, WebIDL conversion/exception fidelity,
other media event scheduling and playback-rate support (at this snapshot V
accepts only 1 while Source supports finite rates from 0 to 64), the MSE
duration-clamping Source FIXME/Worker mirror, actual PlaybackManager/decoder
Ended state, native play
promises, ordinary compact listeners, unique task sources, full prototypes, foreign realms,
WrapperWorlds, IPC and physical GC remain open. The browser uses JavaScriptCore.

Implementation: [media lifecycle](../../html/html_media_element.v).
Focused tests: [duration](../../html/media_duration_task_owner_test.v),
[volume](../../html/media_volume_task_owner_test.v),
[native MediaSource](../../media/main_media_duration_task_owner_test.v).
[Completion and DOM target evidence](MEDIA_END_TASK_DOM_OWNER.md) records the
prerequisite slice and its historical snapshot.

At this snapshot, the 78-owner physical inventory contains 432,322 implementation /
154,501 test V LOC across 2,185 owned files. Browser/root support is excluded.
Counts do not measure parity; the ledger remains 32 fixed / 25 partial / 9 open.

The subsequent [rate/load slice](MEDIA_RATE_TASK_LOAD_OWNER.md) queues
ratechange, translates the setter range and fixes the load reset caller. Its
evidence is separate; actual manager/clock/pipeline propagation remains open.
