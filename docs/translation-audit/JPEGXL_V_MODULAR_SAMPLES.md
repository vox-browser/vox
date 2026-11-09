# JPEG XL V modular samples, 2026-11-09

The V package now reconstructs selected modular channels and complete palette
and scalar squeeze planes. Production still uses Rust JPEG XL decoding. Stream
selection, transform planning/tiled borders, frame assembly, VarDCT, filters,
final color/pixel output and browser integration remain. The native developer
test and Cargo/CI hooks remain until the replacement preserves supported images.

This continuation completes four implementation slices after the preceding
JPEG XL fifteen-file batch: pixel properties/residual reconstruction
(`450e11210`), channel decoding (`bdea7b97a`), palettes (`653aa08d9`) and scalar
squeeze (`36be68159`). A formatting follow-up changes no behavior. This is
**4/10** for the next JPEG XL broad-check cadence; unrelated DOM/performance
ledgers are unchanged. Only relevant focused tests were run this time.

## Independent reference

The reference remains `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Seven predictor/tree/channel/buffer/palette/squeeze source files were verified
byte-for-byte against that archive. Temporary oracles included unchanged source
functions, with minimal image-buffer carriers and the cached pinned crate's
image/entropy implementation. They did not compute expectations from V.

The channel oracle exercises the unchanged FullTree branch. Its specialized
branch traps if reached, and none of the final cases reaches it. Palette checks
use the unchanged one-grid step without neighboring tiles or auxiliary rows.
Squeeze checks use the unchanged scalar functions in both storage widths;
native SIMD equivalence is not claimed. All temporary probes are removed after
recording these results. The frozen fixtures require V alone.

| Layer | New source cases and exact comparisons |
| --- | --- |
| Pixel reconstruction | 4,096 residual/multiplier/guess inputs, including signed extrema and release wrapping. |
| Pixel properties | 32 whole transcripts, containing 1,536 steps. All 256 slots, static channel/stream IDs, row-gradient history, wrapped absolute values, reference slots and weighted predictions are compared. |
| Channels | 952 complete cases compare all stored samples, consumed bits and validity. There are 924 successes and 28 expected final-ANS-checksum failures. Cases cover all predictors, offsets/multipliers, stable empty-channel numbering, nearest compatible prior channels and full-width rolling rows for 16-bit output. |
| Palette lookup | 360 vectors compare 217,800 entries: all implicit deltas and their wrap, both cubes, explicit entries, bit depths through the 24-bit clamp and extra channels, in both storage widths. |
| Palette expansion | 224 complete single-grid images compare every output sample for all predictors, weighted state, explicit/implicit deltas and single-channel partial-index clipping. |
| Squeeze | 8,192 scalar pairs include all 256 combinations of four extreme inputs; 1,024 horizontal/vertical planes cover both storage widths, odd tails and stored-neighbor narrowing. Separate checks cover empty and single-tail planes. |

These add **14,880** source cases, for **191,013** across the package. Whole
stateful property transcripts count as one case each, as weighted transcripts
did previously; individual ANS alias transitions retain their earlier definition.
Palette vectors count as whole cases, not individual lookup values.

Channel inputs include 32 existing Huffman and 32 existing LZ77 vectors in both
storage widths, plus constant ANS streams with valid and invalid final states.
Selection uses the previous independent reference's validity/context/length
fields, never candidate outcomes. No successful/failing expectations were
overridden and no tolerances were introduced.

The initial property harness accessed a row of a zero-width source image and
panicked (exit 101); the partial fixture then failed its required case count.
The harness was corrected to omit that unused access, and regenerated the full
independent corpus without excluding cases. Initial V array-rotation/integer
API compilation failures and a table-extraction assertion were corrected before
passing checks. These failed attempts receive no execution credit. Source
algorithm bodies and frozen expected values were not patched to obtain passes.

## Executed checks

Current V was `V 0.5.2 395d574`, executable SHA-256
`fa57f9d6b086f86a289a1d312391378cdec2a121ca74fdeda3d8981dbb9f0633`.
The compiler and all 82 module/testdata hashes stayed unchanged across both final
batches. The sorted `path<TAB>SHA256<LF>` manifest has SHA-256
`e913443da5c7656b4edc6caf324389ad62673ffeabce882dc9a754b6266a43c6`.

| Final check | Files passed | Test / guard exit | Sampled peak RSS, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 4 | 0 / 0 | 262,897,664 | 17.42 |
| No GC | 4 | 0 / 0 | 256,212,992 | 13.46 |


Both final commands use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo`, each under a
separate 3 GiB `tools/run_memory_bounded.py` process-tree guard:

```sh
v -memory-limit 10G -b c -cc clang test \
  jpegxl/modular_prediction_test.v jpegxl/modular_decode_test.v \
  jpegxl/palette_test.v jpegxl/squeeze_test.v
v -memory-limit 10G -b c -cc clang -gc none test \
  jpegxl/modular_prediction_test.v jpegxl/modular_decode_test.v \
  jpegxl/palette_test.v jpegxl/squeeze_test.v
```

Each feature also passed its focused checks before committing. `v fmt -verify
jpegxl` and owned-path `git diff --check` passed. RSS values are sampled
process-tree sums, not allocation limits or leak proofs. No performance result
is claimed. No separate production build or browser process was requested;
commits retain the normal shared rebuild hook. These standalone modules are not
wired into browser image decoding, so no production-bundle validation is claimed.
Temporary sources, binaries, logs, receipts and locks were removed under the
Build scratch policy after this report was written.

## API and remaining boundaries

Channel buffers are flat signed samples with explicit 16-bit storage conversion.
The V API bounds channel dimensions at 1,048,576, total samples and reference
scratch at 67,108,864, and channel count at 65,536. It rejects malformed buffer
shapes, missing trees, invalid contexts and excessive requests. Reference scratch
and the three prediction rows are reused; no-GC checks do not establish lifetime
or leak parity with the source allocator.

Channel decoding receives an already selected tree and transformed buffers.
Local/global tree selection, transform metadata/reverse scheduling and partial
stream recovery remain separate. Cached-reader state after errors is not a
general source-state parity claim. The corpus tests generic channel decoding,
not specialized-tree or fast-lossless paths.

Palette expansion is for complete images; auxiliary state handoff and neighboring
tiles remain pending. Squeeze callers supply output shift metadata. Its scalar
arithmetic is the reference here; source SIMD paths, smooth-squeeze application
and tile continuation remain broader work. These components do not establish
complete JPEG XL file decoding or final oriented/quantized RGBA output.

See [JPEG XL status](../../jpegxl/PORT_STATUS.md),
[the preceding frame/modular report](JPEGXL_V_FRAME_MODULAR.md),
[migration progress](RUST_TO_V_PROGRESS.md) and
[the developer-tool guide](../../tools/REFERENCE_CORPORA.md).
