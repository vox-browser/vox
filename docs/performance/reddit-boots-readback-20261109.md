# Reddit readback correctness and rejected transport experiments

The 60 Hz goal without stalls remains open. Commit `20d2a9a69` fixes colors
in the opt-in direct-frame reader; `35e0f9875` adds bounded eligibility logging.
Direct-to-frame timings are mixed. Both pooled-buffer-reader trials regress,
so that prototype is removed. Default readback behavior is unchanged.

## Overlapping damage corrupted colors

The direct-frame reader writes BGRA into the CPU frame, then converts each
rectangle to RGBA in place. Overlap converts some pixels twice. An actual GPU
regression reproduces the wrong output and aborts on byte equality before the
fix. The unprotected Reddit capture at offset 850 changes 616 pixels, with
maximum channel error 38; offset 0 remains exact. Failures are retained and
supply no performance credit.

Direct-frame reads now require disjoint destination rectangles. Overlap retains
independent staging buffers and ordered last-writer RGBA copies. Disjoint damage
remains eligible. Actual compiler-dependency hashes show that the guarded
component differs from the original pool component in only the GPU canvas header.

Optimized and ASan/UBSan GPU checks pass overlap, disjoint eligibility, transfer
reuse, damage, failed read/read-only and fallback cases. Final retained code is
rebuilt and checked again in both modes, including the bounded logger; all 135
listed fixture inputs remain unchanged. Final controls/direct-frame candidates
at offsets 0 and 850 have zero differing pixels against unchanged references.

## Unprofiled direct-frame comparison

Every trial uses a fresh process/profile/cache on the requested live thread,
the installed `23d3335d...` executable/Metal/Dawn and a pinned candidate primary
library. Actual C mode is single unit, C-O3, V-prod=false. Viewport 1400×900,
chrome 112, backing scale 2 and zoom 1.25 match earlier work. After the matching
title plus 12 seconds, 5,400 precise native wheel events request 120 Hz, delta
3, reversing every 300. Scripts use the automatic policy; live networking uses
the existing SOCKS5h route; OS caches remain warm. All eight unprofiled trials
finish with browser/guard exit 0 and unchanged executable/library/runtime/tool
identities under a shared bundle publication lease.

Moving FPS uses the entire first-to-last input period. The endpoint is completed
native frame installation, not physical scanout. Publication totals also include
nonmoving installations; interval and FPS statistics count movement.

| Trial | Moving FPS | Median / p95 / max (ms) | Over 16.67 ms | Publications | First / last moving gap (ms) | Actual input Hz |
|---|---:|---|---:|---:|---|---:|
| Control 1 | 104.233 | 8.799 / 14.925 / 30.299 | 2.587% | 5,356 | 47.977 / 0.744 | 105.484 |
| Direct 1 | 98.798 | 9.347 / 16.089 / 39.693 | 4.099% | 5,288 | 51.917 / 0.405 | 101.216 |
| Control 2 | 106.588 | 8.714 / 14.181 / 44.720 | 2.163% | 5,343 | 63.813 / 2.570 | 108.232 |
| Direct 2 | 116.116 | 8.369 / 10.907 / 26.764 | 0.990% | 5,397 | 39.343 / 3.516 | 117.157 |

Only candidates enable `VOX_GPU_CANVAS_DIRECT_READBACK=1`. One pair regresses
and one improves while load varies roughly 30–138 on 18 CPUs. The path remains
opt-in. No isolated gain or stall-free result is accepted.

## A diagnostic stall came from logging

The initial direct-frame diagnostic observes 5,330 direct reads during input.
Its 456.780 ms callback has 88 snapshots in `fprintf`/`__write_nocancel` inside
the general GPU end-of-frame dump. This is blocked diagnostic output, not a
comparable unprofiled application stall. The wheel/frame probe already buffers
its own input/publication records until input ends.

`VOX_GPU_CANVAS_READBACK_DIAGNOSTICS=1` now limits output to 128 markers and
uses the probe clock to skip startup. It avoids the general per-frame GPU dump.
Final primary `5400ba79d76c51abfa36c13a6e139eb1238182c65b3d4913f47f17433f015c71`
produces 128 markers during a separate 5,400-input diagnostic. That run has one
sampled slow callback, no overflow/failure, maximum moving interval 27.805 ms
and 0.732% budget misses. These instrumented observations supply no performance
credit and do not establish the user's scrolling FPS.

## Pooled-buffer reader rejected

The prototype fills independent pooled BGRA buffers through the backend direct
reader, preserving ordered RGBA copies and overlap behavior while avoiding a
backend-owned allocation/copy. Batches larger than eight retain the established
blit reader. Twenty-four actual GPU cases pass in each optimized/ASan mode,
including overlap, full/strip damage, eligibility and failed-direct fallback.
All four frozen captures are exact. A separate bounded diagnostic observes 128
input-window fast-path markers.

Both arms below use the same prototype component and transfer pool; only
candidates enable the temporary buffered-reader flag.

| Trial | Moving FPS | Median / p95 / max (ms) | Over 16.67 ms | Publications | First / last moving gap (ms) | Actual input Hz |
|---|---:|---|---:|---:|---|---:|
| Control 1 | 104.728 | 8.798 / 15.083 / 39.842 | 2.956% | 5,336 | 27.319 / 0.297 | 106.444 |
| Buffered 1 | 99.976 | 9.178 / 15.973 / 41.887 | 3.685% | 5,288 | 59.420 / 0.268 | 102.520 |
| Control 2 | 100.078 | 9.224 / 16.066 / 36.630 | 4.102% | 5,315 | 45.571 / 1.831 | 102.140 |
| Buffered 2 | 96.944 | 9.412 / 17.049 / 39.778 | 5.561% | 5,306 | 53.275 / 0.213 | 98.998 |

Load varies roughly 33–49. Both candidates regress throughput and deadline
statistics. The prototype and its test-only mode are removed from canonical
source. Its patch against `20d2a9a69`, binaries, checks, exact pixels and failing
timings remain archived. No default transport changes.

## Pending validation and local evidence

The completed production bundle remains `23d3335d...`. Installed validation
of default worker/pool fixes `e01e931b3`/`3250b00e8` awaits the already active/
queued shared build. Private native checks cannot validate unpublished V worker
integration. GPU waits remain; the 60 Hz goal remains open.

Raw commands, all attempts, pins, patches, host records, input/frame records,
samples, pixels and actual exits are archived privately:

- `/tmp/vox-reddit-direct-reader-20261109.tar.gz`
- SHA-256 `b13df59a2edbb0f25462c064719f1e820ea5c27ca5cb374efea2bde871a555fc`
- 92,092,198 bytes; 5,040 file hashes verified; mode 0600.
- Companion `-files.json`, `-report.json` and `-archive-guard.json` remain local.

Frozen captures retain original manifest
`407a3da4f736257f4526a203bed15e88b8c42a54b475bc323eb34ce6f1d4a791`
and body `aaa700ed204e811ce0a5df62465c0273044171bd7a69e6e0113843ecfb4da768`,
replayed at the original origin with external DNS/connect/connectx denied.
References and tolerances stay unchanged. The job, locks and temporary drivers
are removed after archive verification; generated dumps/archives are not committed.
