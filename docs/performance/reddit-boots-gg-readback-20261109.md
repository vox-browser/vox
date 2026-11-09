# GG readback ordering: validated candidate, scrolling acceptance pending

The 60 Hz goal without stalls remains open. Commit `e6ef20a8c` connects the
staged Metal helper from `0b92dda32` to the browser's GG module preparation,
adds real GPU/canvas checks and bounds eligibility diagnostics. The joined
reader requires `VOX_GG_JOINED_READBACK=1`; default transfers remain unchanged.
No new scrolling FPS or whole-page pixel acceptance is claimed.

## The extra wait

Slow-input samples from the earlier readback investigation include GG's
`canvas__GpuSurface__read_pixels`. Its Metal transfer first calls
`_sg_v_mtl_flush()`, submitting and waiting for pending rendering, then encodes
the pixel copy in another command buffer and waits again. These are two CPU
wait boundaries for one readback.

The candidate appends the blit to the pending, already enqueued command buffer
after its render encoder has ended. It commits and waits once before copying
pixels to the caller. Without pending rendering it uses a standalone transfer.
It retains the synchronous pixel-ownership contract, existing completion
handler/frame semaphore and uniform-buffer reset after completion. Allocation
or encoder failure leaves pending work and caller pixels untouched. Writes keep
the original implementation. `VOX_GG_SEPARATE_READBACK=1` selects the old reader
for matched controls even when the candidate is enabled.

This removes an extra synchronization boundary, not the remaining GPU wait.
Its effect on the requested Reddit page has not been established.

## Functional checks

All final native checks run with a 3 GiB aggregate RSS guard. Optimized and
ASan/UBSan processes each pass 128 exact comparisons with pending uniform-driven
draws, both retained/unretained Metal resource modes, padded partial readbacks,
upload ownership, invalid destinations, active-pass rejection, injected
allocation/encoder failures and repeated frame-slot reuse without `sg_commit()`.
Each process verifies 130 joined and 130 standalone reads. Diagnostics produce
exactly 128 markers when enabled, then stop.

The actual V GG canvas path compiles with current V, backend `c`,
`-memory-limit 10G`, no compiler fallback, in both `-gc none` and
`-prealloc -gc none` modes. Each guarded runtime passes 64 exact AA/MSAA backdrop
comparisons against the old transfer. Each emits 64 successful joined-path
markers. These are functional fixtures, not scrolling measurements. Native and
the first canvas checks overlap; no timing credit is taken.

Three staging tests and five existing module-preparation tests pass. The
stager preserves the upstream V checkout, rejects unsupported implementations
and modified cached headers, and pins its helper in the cache identity. Final
verification finds all 8 native fixture inputs and 544 canvas/compiler inputs
unchanged. The initial test's nonexistent `RRect.rect_xy` compile error is
retained; `rect_radii` corrects it. Earlier passing phases are superseded by
final checks after the logger and formatting changes.

Reproduction (unique output/lock/report names required):

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/gg-transfer-native-UNIQUE.lock --report Build/gg-transfer-native-UNIQUE.json -- \
  python3 tools/test_gg_metal_transfer.py --v-root "$HOME/code/v" \
  --output Build/gg-transfer-native-UNIQUE
python3 tools/run_memory_bounded.py \
  --lock Build/gg-transfer-canvas-UNIQUE.lock --report Build/gg-transfer-canvas-UNIQUE.json -- \
  python3 tools/test_gg_canvas_transfer.py --compiler "$HOME/code/v/v" \
  --output Build/gg-transfer-canvas-UNIQUE
```

## Production validation remains pending

The completed production executable is still SHA-256
`23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`.
It cannot exercise this change. Recent shared attempts fail FastC-generated C
or reject changed sealed inputs. For example, receipt
`20261109-051154-0f30ca51` exits 1 with undeclared option-binding variables,
channel-field access and closure-generation errors;
`20261109-051724-d89d8a75` rejects a changed build tool. The existing shared
request has since selected backend `c`. No duplicate production build was
submitted by this work.

Before promotion, the completed candidate needs unchanged full-page references
at offsets 0/850, separate input-window eligibility verification using
`VOX_GG_READBACK_DIAGNOSTICS=1`, and alternating unprofiled native-wheel trials
on the requested live thread. Keep full-window throughput, boundary gaps,
p95/max intervals, deadline misses, actual input cadence and host contention.
Native frame installation does not establish physical scanout.

## Local evidence

Commands, all attempts, actual browser-independent check/guard exits, compiler
and source pins, binaries, bounded eligibility output and selected failed
production receipts are retained privately:

- `/tmp/vox-reddit-gg-readback-20261109.tar.gz`
- SHA-256 `e4adc657be3611d5c375180bfcfcff23c8ceadb70655181e247c71f512798325`
- 5,664,818 bytes; 88 file hashes verified; mode 0600.
- Companion `-files.json`, `-report.json` and `-archive-guard.json` remain local.

Generated C, temporary module views and job locks are removed with the job after
archive verification. The shared bundle and content-addressed runtime caches
remain in place. No raw dumps, archives or pixel references are committed.
