# Media ended cache at event-loop step 1

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Event-loop prerequisite commit: `82f30d6fb00b41d3a5448c9dda14468203426c30`.
Media implementation/test commit: `1e6de269750e8de5014a9771ac4fa0e46eaf3075`.
Rendering fixture correction: `558d92a73f5b3406cd07563e3dfa04d5752602ae`.

HTMLMediaElement now recomputes its cached ended attribute when the actual
main-thread event loop reaches step 1. Position and duration changes retain the
previous attribute through microtask checkpoints. The boundary callback reads
the live owner, then regular tasks observe its refreshed value. Ready-state
changes now request the same recomputation, including transitions into or out
of HAVE_METADATA. An unchanged ready state requests no additional callback.

## Pinned Source boundary

`HTMLMediaElement::upon_has_ended_playback_possibly_changed()` queues a
GC function through `run_when_event_loop_reaches_step_1()`. The V helper uses
the actual main-thread loop's existing callback queue, without scheduling an
extra turn. The callback computes both has-ended and forward direction when
it runs, rather than capturing an earlier Boolean. The ready-state setter
uses a deferred call corresponding to the Source ScopeGuard.

Source EventLoop::process returns before advancing generation or draining
callbacks when execution is paused. Its unpause path schedules a new turn.
Both missing operations are now translated. The existing callback queue
drains the current batch before invocation: callbacks registered
by that batch wait until the next turn. Per-element regular task IDs remain
separate from step-1 callbacks. Reload resets ended immediately; pending
callbacks subsequently observe the reset owner. Loop checks use the recorded
loop state at the endpoint, including an attribute change made afterward.

The Source forward has-ended predicate requires PlaybackManager's Ended
state after the pipeline consumes actual media data. V still uses its existing
position-equals-duration predicate. This slice fixes cached-attribute timing
and the ready-state trigger; it does not implement the missing manager state
or decoder boundary. The native getter exposes that existing V predicate.

## Focused and caller checks

Four event-loop cases cover paused generation/callback/task preservation,
callbacks registered during a turn, main-loop ownership and microtask isolation,
and automatic native timer resume. Four model cases cover microtask-before-task
ordering, ready-state transitions, latest position plus recorded loop state,
and independent owners through reload and duration changes. One actual
Page/Document/JavaScriptCore case reads the native ended getter through the
real DOM media owner before microtasks, after step 1 and in a queued task.

The baseline executes assertions in all three files: synchronous model/native
ended and paused callback draining fail at runtime. The initial eight-case
focused batch passes. Final review then finds the missing unpause scheduling
prerequisite; preliminary 14-file batches and the production build are stopped
before code changes. Their incomplete logs and six initial focused files are
retained in `Build/audit-fixes/media-step-one-preliminary-stopped.json`.
They are not passing verification evidence. The added native resume regression
passes before the final freeze.

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | 3 files fail at runtime | 278.420 |
| initial focused | 3 files pass, 8 cases | 190.114 |
| resume focused | 1 file passes, 4 event-loop cases | 115.130 |
| frozen default | 15 pass / 1 compile failure, all 9 final cases pass | 1093.021 |
| frozen gc-none | 15 pass / 1 compile failure, all 9 final cases pass | 1050.071 |
| rendering correction default | 1/1 file passes | 83.339 |
| rendering correction gc-none | 1/1 file passes | 79.435 |

The frozen batches expose an existing rendering-order fixture assigning float
pairs to Document's integer viewport cache. The separate correction changes
only those two test literals. Its same unchanged snapshot passes that file in
both GC modes. Every affected file therefore has passing evidence in each
mode across the broad batches and focused correction; this is not a single
clean 16-file run. All implementation bytes remain unchanged.

Commands use `/Users/alex/code/v/v -old-compiler -enable-globals`, `VJOBS=2`,
with `-gc none` in the second final mode. The 16 files include the three new
files, media resources/seek/adoption, event-loop generation/rendering/native
scheduling, native media state host/page, SourceBuffer task ownership, timer
and AbortSignal hosts, and the 66-case main regression. Existing playback and
literal-state fixtures now observe the actual boundary. Potentially-playing
continues to use the cached ended flag, as pinned Source does.

Both final modes and the resume-focused run retain the identical unchanged
4,873-file snapshot, six selected Source files and two compiler
executables. Formatting checks cover the new files; the scoped diff passes
whitespace checks. Broader nested-pause depth, nested spinning/execution-context
handling and physical callback/collector ownership remain separate.

## Native production regression

`./build_ladybird.sh` passes with the compatibility compiler,
`-enable-globals -prod -gc none`, Skia, FFmpeg and Rust YUV bridges in
1122.877 seconds. Ad-hoc signature verification and
`--headless-smoke` pass. The existing public media-state callback page matches
all 480,000 viewport pixels with explicit zero tolerances. It exercises the
native state-getter and MediaSource callback regression; it does not prove a
real decoder has consumed an entire resource.

All 11 default screenshot smoke cases pass with their existing bounds.
The retained per-case metrics are in the consolidated evidence. No screenshot
tolerance changes. This batch does not rerun the preceding 13 SVG mutation
pairs: compact script replay and image/paint invalidation are unchanged.

Production verifies the same uncommitted 4,873-file snapshot as the
final GC batches before both feature commits. Its before/after records retain
29 selected Source inputs/references/font files and two
compiler hashes. All six implementation/test hashes subsequently match the
two feature commits. The rendering correction follows as a test-only commit;
documentation and inventory changes follow separately. Production is not rebuilt for the two
fixture literals, which are excluded from the browser build.

Signed binary SHA256:
`e9247eb4e38ecf0105ae657c61c5bdec9a287aca6615d68748d6018080cc2a3c`.
Production manifest SHA256:
`4bace4660477c2795561493e11cb4b6b294491b0d0c2dd4f050dc4f96dee078f`.

## Evidence and remaining work

The consolidated artifact is `Build/audit-fixes/media-step-one-evidence.json`.
Its SHA256 is recorded in the audit progress ledger. It validates baseline and
final manifest/log/artifact hashes, the stopped-run record, Source references,
compilers, feature bytes, signed binary and the refreshed module inventory.
Baseline and initial focused artifacts use the `media-step-one-` prefix;
final runs use `media-step-one-final-`. Production artifacts are under
`Build/audit-fixes/media-step-one-final-production/`.

Default manifest SHA256:
`6c4d1319e6d1aef53aaa6d2cb38b0ab700d971e0c259169d2b4f8a6384c04a78`.
GC-none manifest SHA256:
`2fe65439d67d452f31e963d00f4172ff679cd365ebf8f601e201089a1ad8644a`.

Implementation: [event loop](../../html/event_loop.v) and
[media lifecycle](../../html/html_media_element.v).
Focused tests: [step-1 queue](../../html/event_loop_step_one_test.v),
[media cache](../../html/media_ended_step_one_test.v) and
[native page owner](../../media/ended_step_one_owner_test.v).
[Native state-owner evidence](NATIVE_MEDIA_ELEMENT_STATE_OWNER.md) records
its separate generated-getter/DOM-owner prerequisite.

The subsequent [completion-task owner slice](MEDIA_END_TASK_DOM_OWNER.md)
queues the selected end-of-playback caller and reuses the actual DOM EventTarget.
Other event scheduling and ordinary compact listener routing remain separate.
Complete manager/decoder aggregation, native media operations, played/seekable
differences, the full HTMLElement/audio/video
prototype hierarchy, foreign realms, WrapperWorlds, IPC and physical GC
ownership remain open. The browser still uses JavaScriptCore. No new full
HTML, LibJS or Wasm sweep is claimed.

The refreshed 78-owner physical inventory contains
432,305 implementation / 154,028 test V LOC
across 2,181 owned files. Browser/root support remains excluded.
Physical counts do not measure parity; the ledger stays 32 fixed / 25 partial
/ 9 open.
