# Media completion task and actual DOM event owner

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
EventTarget implementation/tests: `2e994235ee8220e55f48e751f1d06f709a5b9891`.
Completion implementation/tests: `33ffe100911958642896e8b89e436a1720a5fc34`.

Associated HTMLMediaElement models now dispatch through the actual audio/video
DOM node's EventTarget. The native wrapper, model handlers and ancestor capture
listeners therefore observe the same target. Adoption preserves that identity;
standalone models retain separate compatibility targets.

End-of-playback completion now queues one media-element task. The event loop
refreshes cached ended at step 1 before the task dispatches timeupdate. After
listeners return, the task rechecks live has-ended, direction and paused state.
It then sets paused, fires pause, takes/rejects pending play promises when
required, and fires ended. No completion event or pause transition runs
synchronously or at a microtask checkpoint. The existing immediate recorded
loop check and loop-seek branch remain intact.

## Source boundary and caller proof

Pinned HTMLMediaElement inherits its EventTarget from HTMLElement and queues
the non-loop completion body of reached_end_of_media_playback through
queue_a_media_element_task. The translated caller now uses the existing actual
task queue, owning Document, cancellation IDs and execution-time fully-active
guard. Loading one model removes its completion task without canceling another
owner or the separate step-1 cache checks. Listener changes to playback position
prevent the pause/rejection decision while ended still fires, as Source specifies.
The cached ended flag then refreshes at the following boundary.

Two model target cases verify address identity, ancestor capture, event flags,
adoption and independent owners. A JavaScriptCore wrapper case verifies this,
target/currentTarget, Event branding and currentTarget cleanup. Four completion
model cases cover cache/event/promise order, live listener mutation, reload and
loop handling, and actual document/task ownership with inactive delivery.
An actual Page/Document/native script case verifies all three ordered callbacks,
native getters, unrelated-owner isolation and balanced callback/realm state.

The native page installs listeners through EventTarget.prototype.addEventListener
on the actual wrapper. The ordinary compact listener stub remains a separate
boundary. These eight cases do not imply complete native media operations or
decoder execution. Existing play/pause/seek/end/loop fixtures now wait for the
actual queued completion rather than assuming synchronous event delivery.

## Executed verification and retained diagnostics

The initial baseline executes the synchronous completion failures in both
model and native page files. Its target fixtures instead hit optional callback
propagation and optional-ID interpolation errors. Correcting those setups
executes both genuine owner failures: the private target and the lost native
callback. The first owner-focused run passes the native file but exposes V's
structural comparison of pointers in the model fixture; address comparisons
correct the identity assertions. The first completion-focused run passes
three files but exposes direct assignment to the inactive fixture's navigable
field, which leaves Document attached. The existing set_active_document setter
corrects that setup. All failed manifests/logs are retained; none is reported
as passing evidence. Earlier target and inactive fixture versions are retained
under `Build/audit-fixes/media-end-task-diagnostic-fixtures/` with exact hashes
matching their corresponding frozen manifests.

| Run and result | Seconds |
| --- | ---: |
| initial baseline: 4 failures, 2 target setup defects | 352.721 |
| corrected owner baseline: 2 runtime failures | 90.549 |
| owner focused: 1 pass, 1 fixture identity failure | 93.754 |
| owner identity correction: 2/2 pass | 111.355 |
| completion focused: 3 pass, 1 inactive fixture failure | 380.622 |
| inactive fixture correction: 1/1 pass | 101.435 |
| frozen default: 14/14 pass | 1060.014 |
| frozen gc-none: 14/14 pass | 1029.340 |

Commands use `/Users/alex/code/v/v -old-compiler -enable-globals`, VJOBS=2,
with `-gc none` for the second broad batch. Both final batches pass all 14
files on the same unchanged snapshot, including all eight new cases, the
66-case main regression, media seeking/adoption/state, step-1 scheduling and
SourceBuffer task ownership. The 4,878-file snapshot includes tracked files
and selected untracked tests. Those files, six selected Source references and both compiler executables remain
unchanged through each run. Feature hashes match their separate commits.

## Native production verification

The same frozen snapshot builds the production macOS bundle with
`-old-compiler -enable-globals -prod -gc none` in 1157.742 seconds.
Signature verification and --headless-smoke pass. A public MediaSource/state
page additionally installs a native durationchange listener on the actual DOM
wrapper. The viewport becomes green only when the existing seven state checks,
attachment identity and trusted event-owner checks pass. All 480,000 pixels
match the expected viewport with explicit zero tolerances.

All 11 default screenshot cases pass within their existing bounds. Exact
per-case pixel metrics are retained in the consolidated artifact. No tolerance
changes. The earlier 13 SVG mutation pairs are not rerun: main.v, the native
media host and EventTarget bridge are unchanged from the preceding verified
snapshot. This page proves event ownership; it does not prove queued
durationchange timing or that a decoder consumed an entire media resource.

Production retains 29 selected Source inputs,
references and font files, both compilers, artifact hashes and an unchanged
signed binary. Its snapshot matches both GC batches before the completion
commit. Documentation and physical inventory updates follow separately.

Signed binary SHA256: `c6731e6721a883bf77a634463f1c59b1d8569219ae38d5da23c873d89e7302b1`.
Production manifest SHA256: `074d80af26dba62cf45fdf6ca581c4de9a0d401de43b8e20b52bb5c2df44c8ea`.
Default manifest SHA256: `401b069c453577b83c70f26044d4121ad1f8f52a180ead2e4e0dccb289e952fb`.
GC-none manifest SHA256: `c04d3d0c02f0c5b27661b9f9a13b8261253f50c0e46aa3ecaa52bacea57f5412`.

## Evidence and remaining boundaries

Consolidated evidence: `Build/audit-fixes/media-end-task-evidence.json`.
SHA256: `0978ed9fc35fc21beecae11e23dab3c2c30cc01db9ed62936be57621deb733df`.
Private manifests/logs use the media-end-task prefix; screenshots and production
logs are under `Build/audit-fixes/media-end-task-production/`.
The consolidator validates failed and passing logs/manifests, Source/compiler
hashes, feature commits, native artifacts and the refreshed module inventory.

Implementation: [media lifecycle](../../html/html_media_element.v).
Focused tests: [DOM target](../../html/media_event_target_owner_test.v),
[native target](../../browserjs/media_event_target_owner_test.v),
[completion task](../../html/media_end_task_owner_test.v) and
[native page](../../media/main_media_end_task_owner_test.v).
[Step-1 cache evidence](MEDIA_ENDED_STEP_ONE_OWNER.md) records the prerequisite.

The forward has-ended predicate still uses V's duration/position check; Source
requires PlaybackManager's Ended state after actual pipeline consumption.
Pending play promises remain the existing dom.Promise compatibility records
with a string rejection reason. Native JS promises and AbortError DOMExceptions,
ordinary compact listener routing, other media event scheduling, full native
operations, unique task sources, manager/decoder ownership, played/seekable behavior, full element
prototype hierarchy, foreign realms, WrapperWorlds, IPC and physical GC remain
open. The browser uses JavaScriptCore; no full HTML, LibJS or Wasm sweep is claimed.

The refreshed 78-owner physical inventory contains
432,314 implementation / 154,244 test V LOC
across 2,183 owned files. Browser/root support is excluded.
Physical counts do not measure parity; the ledger stays 32 fixed / 25 partial /
9 open.

The subsequent [property-task slice](MEDIA_PROPERTY_TASK_OWNER.md) queues
durationchange and volumechange with separate evidence. The production page
and counts above retain this document's earlier snapshot and scope.
