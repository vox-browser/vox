# Reddit native scrolling: installed pacing validation and idle helper shutdown

The 60 Hz goal without stalls remains open. Live measurements of installed
executable `23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`
still miss the 16.67 ms budget. A separate profile identifies an idle ad-block
helper shutdown on the event loop; commit `e01e931b3` moves that shutdown to a
native reaper thread. GPU waits and transfer-buffer allocation also remain in
the samples. No isolated FPS improvement or physical presentation claim is made.

## Installed build and workload

Receipt `20261108-233251-1703525c` contains the cooperative pacing fix
`5598a9b06` and SVG cache lifetime fix `f5d690561`; their sealed source hashes
match the implementation. This resolves their earlier missing installed-build
validation. Actual C mode is one unit, C-O3, V-prod=false, GG adapters and
JavaScriptCore. The bundle does not yet contain `e01e931b3`.

Each trial launches a fresh process and empty private profile/cache on the
[requested live thread](https://old.reddit.com/r/DotA2/comments/1xqhd8i/am_i_the_only_one_who_is_sick_of_10_man_boots_dota/).
The viewport is 1400×900 CSS pixels, chrome 112, backing scale 2, page zoom
1.25. After the matching title and 12 seconds of settling, 5,400 precise
native wheel events request 120 Hz, delta 3, reversing every 300 events.
Scripts use the automatic policy. Networking uses the existing SOCKS5h route;
OS filesystem/shader caches remain warm. Executable, native libraries, runtime
assets and tools stay pinned under a shared bundle publication lease.

## Unprofiled live trials

Only `VOX_RETAIN_COOPERATIVE_YIELD_START_DEADLINE=1` changes between the old
pacing controls and default candidates. FPS uses the complete first-to-last
input window and counts scroll-changing native frame installations. It is
not physical display scanout. Every attempt is retained.

| Trial | Moving FPS | Median / p95 / max interval (ms) | Over 16.67 ms | Publications | First / last moving gap (ms) | Actual input Hz |
|---|---:|---|---:|---:|---|---:|
| Control 1 | 110.076 | 8.508 / 13.375 / 31.844 | 1.646% | 5,374 | 41.350 / 1.957 | 111.167 |
| Default 1 | 102.965 | 8.879 / 15.203 / 29.467 | 2.905% | 5,326 | 30.298 / 2.380 | 104.868 |
| Control 2 | 100.100 | 9.227 / 15.364 / 56.548 | 3.328% | 5,314 | 34.042 / 0.219 | 102.182 |
| Default 2 | 96.514 | 9.633 / 16.094 / 47.307 | 4.024% | 5,288 | 65.601 / 0.382 | 98.895 |

All complete 5,400 inputs with browser and guard exit 0 and unchanged input
identities. Host load varies from roughly 20 to 36 on 18 CPUs. Both default
trials have lower throughput than the preceding controls; this cohort supplies
neither isolated pacing credit nor zero-stall acceptance.

## Separate diagnostics and shutdown fix

The full-length live diagnostic records 293 stack samples across 346 slow
callbacks, with no snapshot failures or overflow. Two gap samples after input
151 enter `vox_adblock_worker_release` at 19.829 and 24.972 ms overdue. That
function waits for quit acknowledgement and child reap on the event loop.
Its graceful shutdown allowance is two seconds, followed by the reap grace.

Idle release now transfers one helper's immutable transport and PID to a
detached native shutdown thread. New requests may immediately start a different
helper. A single retirement slot bounds concurrent helpers; failed thread
creation leaves the current transport intact. Footprint accounting includes
both helpers until lifecycle-protected reap, and explicit release and normal
exit still drain owned children synchronously. The reaper does not hold the
sampling lock across shutdown I/O or its reap polling delay.

The live profile also includes 31 GG readback, 13 GG upload and 68 Graphite
readback/submit stack occurrences, plus 29 `madvise` occurrences. These
overlapping counts are diagnostic observations, not time fractions. The
5,400-input frozen diagnostic has 139 samples over 193 slow callbacks, with
no failures/overflow, and does not capture the idle-release gap. Neither
instrumented trial supplies performance credit.

## Checks and pending browser validation

- Native transport, ownership/publication, normal exit and parent-death checks
  pass. New tests cover ignored quit, immediate replacement, bounded retirement,
  thread-creation failure, memory ownership, descriptors, repeated reap and
  exit with current and retiring children.
- ASan/UBSan and ThreadSanitizer checks pass. Handoff takes 0–1 ms in the focused
  tests while the fake helper ignores quit for two seconds; this is not an FPS
  measurement or a general scheduling bound.
- All 20 focused V tests pass in explicit `-gc none` and production
  `-prealloc -gc none` builds, with current V and fallback disabled.
- Installed controls/defaults remain exact against the unchanged frozen-page
  references at scroll offsets 0 and 850: zero differing pixels in all four
  document captures. These validate installed pacing/cache changes, not the
  unpublished worker fix.

The first native-suite attempt stopped on a stale startup-order assertion
before executing tests. The harness now admits the current explicit metrics
and resource-hook prelude while still rejecting browser heap/font/GUI work
before worker dispatch. The full suite then passes, including a final rerun
after comment-only API clarifications.

Installed validation of `e01e931b3` remains pending. The shared production
builder is already running/retrying; receipt `20261109-013232-e8230e6a` fails
because generated C includes missing `vlib/os/execute_capture_legacy.h`.
No duplicate production build is queued.

## Local evidence

Raw commands, all attempts, identity pins, environment, host load/timestamps,
native input/frame records, stack symbols, pixel diffs, compile/runtime logs
and actual exits are in the private archive
`/tmp/vox-reddit-cooperative-live-20261109.tar.gz`:

- SHA-256 `2a79c9e621c7346056cdcd33b093057b055a1845b8b7414f1cfe89cfd7249b2c`
- 32,511,441 bytes; 2,212 file hashes verified after archiving; mode 0600.
- Companion `-files.json`, `-report.json`, and `-archive-guard.json` files stay
  local in `/tmp`. Generated measurements and archives are not committed.

The unchanged 152-response fixture manifest is
`407a3da4f736257f4526a203bed15e88b8c42a54b475bc323eb34ce6f1d4a791`;
the main body is
`aaa700ed204e811ce0a5df62465c0273044171bd7a69e6e0113843ecfb4da768`.
Frozen diagnostics/captures replay at the original origin with external
DNS/connect/connectx denied. Timing, scripts and document readiness differ
from the fixed-pose pixel checks as recorded above.
