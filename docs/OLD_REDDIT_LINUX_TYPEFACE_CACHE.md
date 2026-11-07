# Old Reddit on Linux: shadow typeface reuse

**The measured workload passes the 10% instruction-reduction target:** median Cachegrind instructions decreased **19.3038%**, and the conservative highest-candidate/lowest-control comparison improved **13.1896%**. All six captures preserve exact reference pixels and audited content. Native tests pass; selected V regression checks pass in both GC modes.

## Change and mechanism

The candidate reuses native Skia typefaces while rasterizing text shadows. Previously, each text-shadow command called `SkFontMgr::makeFromFile`, creating another typeface for the same font file and collection index. That repeated work defeated Skia's per-typeface bounds memoization and its strike-cache identity. The change is limited to [`skia/shadow_raster.cpp`](../skia/shadow_raster.cpp) and the new [`shadow_typeface_cache.h`](../skia/shadow_typeface_cache.h).

The cache owns its path strings and `sk_sp<SkTypeface>` references. Each raster thread has a 32-entry LRU with a 32 MiB budget charged by retained font-file size. This budget bounds retained file bytes, not every decoded Skia or shared strike-cache allocation. Lookup validates the path and face index against device, inode, size, and nanosecond modification/change timestamps. Removal or replacement invalidates entries; failed loads are never cached; a second metadata check prevents publishing an entry when a replacement occurs during loading. Special files bypass retention. The native builder hashes `skia/*.h`, so edits to the new header trigger normal incremental rebuilding. Font size, smoothing, glyphs, positions, transformations, clipping, color and blur remain per draw.

A separate Callgrind diagnostic recorded **7,894,617,541 Ir** overall, with **2,093,599,190 Ir (26.52%)** attributed inclusively to `skia__rasterize_shadow`. It observed 1,264 text-shadow font loads and **894,485,920 Ir (11.33%)** in typeface bounds computation. These figures motivated the change; they are excluded from acceptance statistics and are not a measured candidate improvement. See [profile findings](benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json).

## Workload and measurement boundary

The workload is the repository's frozen **2024-01-01 `old.reddit.com/r/worldnews`** fixture, with scripts removed, rendered on Linux x86-64 at **1280 × 900** and scale 1. It contains 30 ordered post IDs, 34 `img` elements, 10 stylesheets, and no declared webfonts. The observer pins all 72 fixture files, font/configuration identities, executable and library identities, runtime assets, and its own source. Its fixture manifest digest is `55470817acb6f0585c1885746c56b5adf1f34617d61da9cf73669b94efff9f75`. See [environment](benchmark-results/old-reddit-typeface-cache-protocol/environment.json) and [cohort metadata](benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json).

Each observation starts a fresh browser process, profile and XDG cache. OS filesystem caches remain warm as the run progresses. Both variants use software graphics, one Boehm marker, disabled snapshot/shader caches, identical local resources, and the same non-forwarding loopback proxy for HTTP(S). Static resource inventory finds no automatic external HTTP resources; this transport policy is not a kernel network sandbox. Repository builds and tests were paused during the cohort; host-load snapshots are retained.

The endpoint is **program execution through process exit after document PNG capture and native audit**. It includes startup, window/target setup, readiness, rendering, PNG encoding, audit and teardown. Cachegrind counts the main process and its instrumented threads/libraries; children, kernel, GPU and external Xvfb work are outside scope. Hardware PMU access was unavailable. Consequently, the result concerns **software guest instruction references (`Ir`)**, not hardware-retired instructions, native elapsed time or isolated paint cost. Valgrind is 3.22.0. Cachegrind was selected before measurement for acceptance; Callgrind serves diagnostic attribution only.

## Matched build provenance

The control source is upstream `vlang/vox2` commit `4f87e708424edf0ed929d130fdc4ef0002fa23b5`. Toolchain pins include V `8636a8fe6c2d285f6bb60ad5686b6ffda61f9835`, UI2 `96f5924d73f69c0302de3c5c31d9964d4d11f573`, and Skia `ee20d565acb08dece4a32e3f209cdd41119015ca`.

The implementation and focused regression tests are in commit [`7cad7157ef41c62dac10d78e5975e2a368897203`](https://github.com/vlang/vox2/commit/7cad7157ef41c62dac10d78e5975e2a368897203).

The original monolithic build was killed with exit 137. Supported V C-project generation and native compilation were then run sequentially under separate guards, preserving Linux production `-O2`, Boehm/dynamic-Boehm, OpenSSL and explicit glibc settings. The measured mode was current V `-new-compiler -glibc -memory-limit 10G` with native `-O2`, without V `-prod`, matching the Linux recipe. Browser C used Clang 18.1.3; the native bridge retained its original GCC 13.3.0 and `-std=c++20 -O2 -fPIC` flags. See [build receipt](benchmark-results/old-reddit-typeface-cache-protocol/baseline-build-summary.json).

Both variants link the identical compiled browser C object. Relinking the preserved original native archive produced a **byte-identical original control executable**. Of the four native Skia archive members, only `shadow_raster.o` changed. This controls for compiler, generated-C and unrelated native changes. Exact commands and hashes are in [relink evidence](benchmark-results/old-reddit-typeface-cache-protocol/relink-variants.json) and [archive comparison](benchmark-results/old-reddit-typeface-cache-protocol/native-archive-comparison.json).

| Artifact | SHA-256 |
|---|---|
| Control executable | `e74376514dbb0b55828ac26e8a9a355b9adb8b2a3c565f344f141ead793ecd54` |
| Candidate executable | `9c2ac167c046be1f5e8f7fed2f261ea8fd60e7d2fe525df87dd6c9cc426a6c07` |
| Fixed reference decoded RGBA | `297eaf3dc7316f9469b91059b650688659f387144faef693537f5f9d9b8e786c` |

## Observer corrections and retained attempts

Two prospective corrections were made **before any candidate instruction count**. Neither changed the native browser, fixture, measurement endpoint, underlying driver, strict counter parser, or pixel reference.

First, the observer initially rejected the diagnostic capture because its `javascript_diagnostics` field contained 12 copies of `Shadow replay: Empty shadow bounds`. Source inspection established that this exact message comes from native shadow replay, stored in the shared message channel. The correction classified only that source-proven message and initially required its exact 12-entry list. All other messages and native reported errors remained forbidden. The original failed wrapper evidence was retained. See [correction 1](benchmark-results/old-reddit-typeface-cache-protocol/observer-correction-01/provenance.json).

Second, the first unmodified Cachegrind control produced six copies of the same message while matching every other raw audit field and all pixels. Cohort 01 remains invalid. Correction 2 preserves raw lists/counts and canonicalizes only repetitions of that exact message for document comparison; empty/missing lists or any other message text still fail. Actual frame counts were not measured and must not be inferred from message counts. Both corrections have negative validation cases. See [correction 2](benchmark-results/old-reddit-typeface-cache-protocol/observer-correction-02/provenance.json).

The retained unmodified control's strict-parsed count, **6,842,705,460 Ir**, is a mandatory additional constraint. It never enters final paired medians. See [supplementary control](benchmark-results/old-reddit-typeface-cache-protocol/supplementary-control.json).

## Acceptance results

All three predefined alternating pairs completed, with no retries, discarded attempts or replacement observations. Every capture matched the original PNG and preserved body text, all ordered posts, image states, geometry, 958 paint commands and the canonical native audit. All visible images were decoded. Execution order was control/candidate, candidate/control, control/candidate.

| Pair | Control Ir | Candidate Ir | Saved Ir | Reduction | Pixel/content/geometry |
|---|---:|---:|---:|---:|---|
| 1 | 7,181,886,789 | 5,794,954,378 | 1,386,932,411 | 19.3115% | Exact |
| 2 | 7,181,198,185 | 5,938,311,142 | 1,242,887,043 | 17.3075% | Exact |
| 3 | 6,840,551,361 | 5,793,881,588 | 1,046,669,773 | 15.3010% | Exact |
| Median | 7,181,198,185 | 5,794,954,378 | — | 19.3038%¹ | — |

¹ The 19.3038% figure compares the two medians; the median of the three paired percentages is 17.3075%. Both conservative integer gates pass:

```text
10 × max(candidate) = 59,383,111,420
9 × min(final controls) = 61,564,962,249
9 × min(final controls ∪ {6,842,705,460}) = 61,564,962,249
59,383,111,420 ≤ 61,564,962,249: PASS
```

The lowest final control, **6,840,551,361 Ir**, is lower than the retained **6,842,705,460-Ir** control, so both gates yield the same **13.1896%** conservative reduction. Raw native-message counts remain recorded: controls `[9, 9, 6]`, candidates `[9, 6, 9]`. All six driver/browser exits and the outer guard exit were zero. The guard completed in 333.05 seconds with 981.8 MiB sampled peak aggregate RSS. The [independent audit](benchmark-results/old-reddit-typeface-cache-protocol/independent-acceptance-audit.json) verified all six profile totals and 477 pinned files. This is a Vox control-versus-candidate experiment.

## Correctness and reproduction

Focused native tests passed **1,152 byte-for-byte RGBA comparisons**, covering two fonts, both TTC faces, repeated draws, sizes, smoothing inputs, blur, rounded clips, fractional translations and concurrent raster threads. They also check typeface reuse, key ownership, LRU and byte-budget eviction, deletion/recreation, failed loads, same-size replacements with restored mtime, atomic rename, and replacement during loading. Both an extracted original control object and a durable uncached adapter passed. The final adapter run used 296 MiB sampled peak RSS under a 3 GiB runtime guard. See [test result](benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json). Selected Skia, portable-shadow layout and platform-font V checks also pass with Boehm and no GC: 29 registered functions per mode, one known macOS-only early return per mode, and **[56 active Linux invocations](benchmark-results/old-reddit-typeface-cache-protocol/font-validation-summary.json)**. All compiler/runtime guards exited zero with unchanged inputs. The initial setup failure is preserved; this does not claim every repository test ran.

From the repository root, using new output names:

```sh
python3 tools/run_memory_bounded.py --lock Build/shadow-check.lock \
  --report Build/shadow-check.guard.json -- \
  python3 tools/test_shadow_typeface_cache.py \
    --font-a /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
    --font-b /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf
```

The test requires C++20, pkg-config Skia and fontTools, or an explicit two-face `--collection`. The historical measurement command below requires the restored protocol/evidence and matching binaries in the original workspace:

```sh
python3 tools/run_memory_bounded.py --lock Build/reddit-repeat.lock \
  --report Build/reddit-repeat.guard.json --timeout 12000 -- \
  python3 Build/reddit-optimization/compare.py \
    --baseline Build/reddit-optimization/baseline-c/vox2 \
    --candidate Build/reddit-optimization/candidate-c/vox2 \
    --counter-backend cachegrind --pairs 3 \
    --reference-capture-report Build/reddit-optimization/baseline-callgrind-01/capture.run-1.json \
    --output Build/reddit-repeat
```

The [durable protocol snapshots](benchmark-results/old-reddit-typeface-cache-protocol/README.md) and [compressed raw evidence](benchmark-results/old-reddit-linux-typeface-cache-2026-11-02-evidence.tar.gz) accompany the [tracked ledger](benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json). Scripts expect their original `Build/reddit-optimization` location; historical contracts contain absolute paths. A different checkout requires prospectively repinning paths/build identities and sealing a fresh control reference before measuring candidates. The protocol README explains restoration and verification; copied scripts are not a path-independent replay. The copied scripts were removed from the tree on 2026-11-07 (recover them from commit `adbe53812`), and the compressed raw evidence archive was removed from git history; it is kept only locally.

## Limits on the conclusion

The fixed control screenshot has pre-existing blank areas in the thumbnail column and some sprite/icon areas; their cause is unisolated. Its audit nevertheless reports all 34 image resources complete and all 11 viewport-visible image nodes decoded. Missing dormant CSS resources and the empty-shadow-bounds diagnostic also remain baseline limitations. Exact pixel preservation establishes no new rendering regression against this control, not full Reddit visual conformance. This result applies to this frozen, script-free Linux workload and endpoint; current live Reddit, author-script execution, other platforms, scrolling and native wall-clock speed require separate evidence.
