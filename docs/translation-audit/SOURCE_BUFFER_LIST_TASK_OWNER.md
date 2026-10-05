# SourceBufferList additions use queued live owners

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature `a7d2561f8df4d9f333a91d65a1bafac8d4133b47` contains the implementation,
four focused list cases and the existing MediaSource caller's updated timing
assertions.

SourceBufferList.append previously dispatched addsourcebuffer synchronously.
Its original three regressions reproduce a callback before return, intermediate
list lengths instead of the eventual live state, and a lost event when the
handler is installed after append. Append now changes the real vector first,
then queues an unspecified HTML task with no associated Document, as in
SourceBufferList.cpp. The callback uses the original list pointer and reads
its actual parent MediaSource at execution. The existing bare internal-list
adapter continues to create its ordinary event inside that queued task.

The pinned Source has two active-track notifications: SourceBufferList.append's
queued event and an additional explicit task in
SourceBuffer.on_first_initialization_segment_processed. The V caller previously
omitted the latter. It now queues that task with the same real MediaSource
and active list. The fourth original-case baseline observes **one event**
after draining, against the expected **two**. The corrected case verifies
both callbacks' target/currentTarget/receiver identity and live list length.
It creates an actual Page/Document/Window and DOM video, installs a real
TrackBuffer in the buffer's processor, and invokes the actual first-init
notification method. This is a direct algorithm-owner regression, not a new
complete parser/playback or public JavaScript buffer test.

The existing addSourceBuffer caller test now explicitly sees zero events
before the task drain and one afterward. Synchronous vector changes, indexed
item identity and the distinction between source and active lists remain
observable through the existing typed records.

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

SourceBufferList.cpp captures GC::Weak; the V task retains a raw pointer to
its live heap owner. Physical weak-reference disappearance, root tracing and
wrapper-world collection are not translated by this feature and remain open.
The extra active-list task likewise does not establish upstream strong-edge
GC equivalence. Native buffer/list wrappers, Worker startup, foreign realms,
IPC, Source event clocks and full codec/playback behavior remain separate.
The [buffer event-owner fix](SOURCE_BUFFER_EVENT_TASK_OWNER.md) is independently
committed. The [last frozen production bundle](FROZEN_E385AC31_NATIVE_URL_MEDIA.md)
predates these features; no current rebuilt bundle or screenshot verification
is claimed. The audit stays **32 fixed / 25 partial / 9 open**.
