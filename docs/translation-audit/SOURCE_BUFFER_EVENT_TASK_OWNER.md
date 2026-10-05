# Queued SourceBuffer events retain the original owner

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature `a5b121e958937663e58b2e7b6879c90bf7c11924` includes its implementation and seven
focused cases in `mediasourceextensions/source_buffer_task_owner_test.v`.

Twelve SourceBuffer event closures previously captured the mutable V receiver
by value. Dispatch reached its shared listeners but supplied a copied
EventTarget as event target, currentTarget and callback receiver. The original
seven-case behavioral baseline reproduces those wrong identities for normal
append, abort before the parser task, abort from updatestart, a new append after
abort, range removal, append error and actual media detachment.

A private `queue_buffer_event` helper captures the actual buffer address and
uses the actual MediaSource's associated-event factory. All twelve call sites
now dispatch from that existing EventTarget, matching SourceBuffer.cpp's
`[this]` event captures. The two mutable algorithm captures already preserve
the original generation and range-removal state; they remain unchanged.
Pre-fix cancellation, coded-frame removal and completion assertions already
pass. This feature corrects event ownership and does not claim a newly fixed
append-generation or removal algorithm.

The focused fixture creates a genuine navigation Document, Page and Window
settings, constructs the MediaSource with that actual global EventTarget,
and attaches it to a real DOM video's media model. It checks pointer identity
inside each callback, event order, cancellation and range completion. The
range case uses a real TrackBuffer/demuxer with retained frames; the fatal
case appends a Cluster before an initialization segment.

## Verification and retained evidence

| Run | Result | Seconds |
| --- | --- | ---: |
| baseline | List 3 assertion failures; buffer compiler-only failure | 33.372 |
| baseline-corrected | List 3 failures; buffer identity failures and incorrect error-fixture expectation | 33.596 |
| baseline-final | 10 executed assertion failures; zero compiler errors | 29.909 |
| buffer-focused | 4/4 files PASS | 55.600 |
| baseline-list-final | List 4 executed failures; corrected buffer file PASS | 34.511 |
| default | 18/18 files PASS | 522.518 |
| gc-none | 18/18 files PASS | 500.973 |

Passing final commands use `/Users/alex/code/v/v -old-compiler -enable-globals`
and `VJOBS=2`; GC-none adds `-gc none`. Each runs all **15 MediaSourceExtensions
files**, `browserjs/media_source_host_test.v`,
`main_media_source_object_owner_test.v` and `main_test.v` (**66 cases**).
They use one unchanged final code snapshot, with **4,847 recorded tracked/selected
files**, **nine selected Source references** and both compiler executables
unchanged before/after. The snapshot retains its actual HEAD and dirty tracked
status before the independently committed list feature; it is a file-content
proof, not a clean frozen-commit production run.

The first buffer fixture fails compilation on Option propagation from a
Result-returning helper and finalization through an immutable owner field;
it has zero test runtime. The corrected fixture then uses one byte that the
incremental WebM sniffer treats as incomplete, so its expected error event is
incorrect. The final fixture uses a recognized Cluster before initialization,
which actually enters the append-error algorithm. These fixture corrections
are separate from the implementation changes, and all original logs and
private files remain retained. The final pre-fix baseline executes all seven
buffer and three list assertion failures without compiler errors. The later
list baseline executes four failures while the already corrected buffer file
passes.

Exact argv, environment, exits, timings, logs and private-file hashes are
retained in the seven per-run manifests. Shared evidence
`Build/audit-fixes/source-buffer-task-owner-evidence.json` has SHA256
`1fe6f6815be104cc566c56aa552811dd2d1b8a577c52ea5256214ae6421e88db`. Final default and GC-none manifest SHA256 values are
`b6dc3a099df12f4bcbb4aea1f4f0b59c8dac33759d7588dbb2255fa246246b08` and
`68b1af41887cb24bd7f8e95716d1555d9fa406fe80a86333eff0b24fede4ff2b`, respectively.

The refreshed `a7d2561f` inventory records **432,276 implementation V LOC /
153,754 test V LOC** across 78 owners. The MediaSourceExtensions package has
**4,075 implementation / 2,206 test V lines**. Artifact
`Build/audit-fixes/source-current-module-loc-a7d2561f.json` has SHA256
`2651d60ec90e9af49ca7e99d65e41fcf6df9edc5a71332ce16d27fee58f61497`. Physical counts do not measure parity.

## Remaining boundaries

Native SourceBuffer/SourceBufferList exposure, physical collector edges,
foreign realms/worlds, IPC, Source event-clock integration and complete
codec/playback behavior remain separate. Passing both GC modes proves these
observable checks, not collector equivalence. The
[subsequent list task feature](SOURCE_BUFFER_LIST_TASK_OWNER.md) records its
own ordering correction. The [last frozen production bundle](FROZEN_E385AC31_NATIVE_URL_MEDIA.md)
predates these two task features; no rebuilt production or screenshot proof
is claimed here. The audit stays **32 fixed / 25 partial / 9 open**.
