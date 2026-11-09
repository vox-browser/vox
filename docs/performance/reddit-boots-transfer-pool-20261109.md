# Reddit GPU transfer allocation and queued-upload checks

Commit `3250b00e8` reuses scoped CPU transfer buffers instead of allocating and
releasing large vectors at every GPU canvas boundary. Exact GPU and page checks
pass. Live trials still miss the 16.67 ms budget, and heavy host contention
prevents an isolated speedup claim. The separate queued-upload experiment has
mixed results and remains disabled. The 60 Hz goal without stalls remains open.

## Change and checks

The earlier live profile sampled `madvise` during GPU canvas uploads. Uploads
and readbacks now borrow independent leases from a pool retaining at most
32 MiB across eight slots. Uploads preserve transparent padding. Readbacks keep
their leases until the whole batch completes; failed reads retain the existing
failed-frame path. Explicit and two-second idle purges release cached storage;
generation checks prevent outstanding leases from refilling a purged pool.

Focused pool ownership, move, purge, capacity and concurrent-release checks
pass in optimized and ASan/UBSan builds. The actual GPU bridge passes 54 exact
repeated-transfer cases in each mode, covering full frames, strips, text masks,
CPU barriers and 1/9/49 damage regions. Existing disjoint-damage and failed
read/read-only checks also pass; the optimized partial-readback check passes.
All native test input hashes remain unchanged.

The candidate primary library is
`13a78204a8a842752991e215d441e75c4ada33972077918d5e6fe3d4ad19370e`.
Its actual compiler dependencies and static libraries were pinned before/after
compilation, including an unchanged dependency list. The executable, Metal and
Dawn backends remain those of installed bundle `23d3335d...`. This explicitly
overridden native library validates the new pool code; it is not an installed
bundle acceptance claim.

Four pool on/off fixed-pose captures and four queued-upload on/off captures
are exact against the unchanged frozen-page references at offsets 0 and 850.
These final captures pin the executable, libraries, runtime assets, tools,
fixture and network-denial library throughout. Earlier pool captures with
narrower pins remain archived but are superseded for provenance.

## Matched native scrolling

Every trial uses a fresh process/profile/cache on the requested live Reddit
thread, a 1400×900 document viewport, 112 px chrome, backing scale 2 and zoom
1.25. After the matching title plus 12 seconds of settling, 5,400 precise
native wheel events request 120 Hz, delta 3, reversing every 300 events.
Scripts use the automatic policy; networking uses the existing SOCKS5h route;
OS caches remain warm. All eight unprofiled trials finish with browser/guard
exit 0 and unchanged executable/library/runtime/tool identities under a shared
bundle publication lease. Actual C mode remains one unit, C-O3, V-prod=false.

The endpoint is completed native frame installation, not physical scanout.
Moving FPS uses the complete first-to-last input window. Publications below
include nonmoving installations; FPS and interval statistics count movement.

| Pool trial | Moving FPS | Median / p95 / max (ms) | Over budget | Publications | First / last moving gap (ms) | Actual input Hz |
|---|---:|---|---:|---:|---|---:|
| Control 1 | 98.200 | 9.239 / 16.250 / 188.047 | 4.409% | 5,286 | 64.282 / 0.343 | 100.756 |
| Pool 1 | 110.527 | 8.540 / 12.930 / 116.747 | 1.231% | 5,387 | 48.515 / 3.384 | 111.289 |
| Control 2 | 88.650 | 10.155 / 18.898 / 182.853 | 8.940% | 5,199 | 39.047 / 0.379 | 92.416 |
| Pool 2 | 89.855 | 10.350 / 18.177 / 33.023 | 8.520% | 5,239 | 41.550 / 12.455 | 92.883 |

Controls set `VOX_DISABLE_GPU_CANVAS_TRANSFER_POOL=1`; all other inputs match.
Both pool trials improve throughput, p95, maximum and budget misses against
their preceding controls, but medians regress in the second pair. Host load
varies from 85 to 158 on 18 CPUs, and controls vary substantially. No isolated
FPS improvement is accepted. This comparison isolates retention; both arms
also contain the new readback allocation without redundant zero initialization.

Separate full-length diagnostics confirm 124/128 logged live transfers and
125/128 frozen transfers reuse storage during input. These are bounded samples,
not complete-window totals. Live/frozen diagnostics record 157/206 stack samples
over 241/226 slow callbacks, with no overflow or snapshot failure. GPU waits
remain. The frozen diagnostic retains a 170.912 ms callback sampled in upload
and readback waits, followed by a 63.458 ms callback sampled copying the visible
raster. Diagnostic timing supplies no optimization credit.

These two diagnostic jobs ran concurrently with focused GPU checks, so their
timings can include that contention. The unprofiled cohorts ran after those
checks completed; their timing results are separate.

## Queued uploads remain an experiment

`VOX_GPU_CANVAS_STAGED_UPLOAD=1` replaces the synchronous CPU texture write
with a queued Graphite upload. A separate full-length diagnostic confirms 7,684
uploads during input, with 58 samples over 97 slow callbacks and no snapshot
failure/overflow. Its sampled canvas-upload waits disappear, but GG transfers,
readback and host event servicing remain. This is eligibility evidence only.

Both arms below retain the pool and the same explicit primary library. Only
the candidate enables the existing queued-upload flag.

| Upload trial | Moving FPS | Median / p95 / max (ms) | Over budget | Publications | First / last moving gap (ms) | Actual input Hz |
|---|---:|---|---:|---:|---|---:|
| Control 1 | 100.717 | 9.211 / 15.556 / 54.346 | 3.368% | 5,340 | 30.408 / 0.350 | 102.328 |
| Queued 1 | 94.486 | 9.827 / 16.587 / 42.476 | 4.776% | 5,255 | 60.188 / 0.258 | 97.464 |
| Control 2 | 91.735 | 10.125 / 17.380 / 43.465 | 6.292% | 5,272 | 64.321 / 3.182 | 94.141 |
| Queued 2 | 96.833 | 9.561 / 16.281 / 40.972 | 4.451% | 5,263 | 68.748 / 0.490 | 99.866 |

One candidate regresses throughput, p95 and deadline misses; the other improves.
Host load varies from 21 to 30. No default change or isolated speedup is accepted.
Removing a sampled wait alone does not establish smoother scrolling.

## Production build blocker

Commit `738a12dcc` fixes the staged compiler's capture-header declaration.
V3 expanded `@VEXEROOT` against the project and generated a missing repository
`vlib/os/execute_capture_legacy.h` include. Staging now resolves the real header
path and includes its bytes in the runtime identity. Nine Python tests pass,
and a current staged-compiler program compiles and executes with production
preallocation, GC disabled and fallback prohibited, checking captured output
and exit status. The initial fixture failure comparing `/var` with its resolved
`/private/var` path is retained in the evidence.

The shared builder is already active/queued; no duplicate build was requested.
The available completed bundle remains `23d3335d...`, so installed validation
of the idle-worker fix `e01e931b3` and transfer-pool fix `3250b00e8` is pending.

## Local evidence and cleanup

Raw commands, all attempts, build/source/fixture pins, host records, native
input/frame records, profiles, pixels and actual exits are archived privately:

- `/tmp/vox-reddit-transfer-pool-20261109.tar.gz`
- SHA-256 `871a7c749024bad9b3325668c3d67bbac6421cf343979e7285d638852d33377e`
- 69,876,647 bytes; 4,344 archived file hashes verified; mode 0600.
- Companion `-files.json`, `-report.json` and `-archive-guard.json` files remain
  local. Generated measurement dumps and archives are not committed.

The original-origin frozen replay uses the unchanged 152-response fixture
manifest `407a3da4f736257f4526a203bed15e88b8c42a54b475bc323eb34ce6f1d4a791`
and main body `aaa700ed204e811ce0a5df62465c0273044171bd7a69e6e0113843ecfb4da768`.
External DNS/connect/connectx are denied for replay. The job directory, locks
and temporary drivers are removed after archive verification.
