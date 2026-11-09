# JPEG XL V floating-point filter/color stages, 2026-11-09

V now implements binary32 fused multiply-add, whole-plane Gaborish filtering,
horizontal/vertical chroma upsampling and YCbCr to RGB conversion. The four
slices are `391ecaf60`, `d6e559656`, `e00fd6fc2` and `904974c5f` respectively.
JPEG XL cadence is **7/10** after the preceding twenty-five-file full checkpoint;
formatting/documentation add no slice credit. These stages are not integrated
into complete-file rendering yet. Production and its developer tools still
require Rust for the supported paths that remain untranslated.

## Arithmetic and API boundaries

The FMA helper performs one binary32 rounding. A binary64 product/addition is
sufficient except when the rounded binary64 sum is a binary32 midpoint. Those
cases use nine fixed stack limbs, representing the exact product and addend in
units of 2^-298, then round once with ties to even. This handles subnormal
results, signed zeros, cancellation and overflow without heap big integers,
native FMA calls or Rust. NaN results are canonicalized; payload/sign parity for
NaNs is not claimed. A separate exact finite implementation is checked against
the same source records as the ordinary path.

Gaborish preserves the source's weight normalization, ordered cross/corner sums
and two fused operations. The one-pixel source border replicates the edge pixel.
Chroma upsampling computes 0.75 times the current sample, then fuses 0.25 times
each neighbor. Its full doubled extent is returned; a frame caller must crop
to the final coded image extent. YCbCr input is stored as Cb/Y/Cr and output as
R/G/B, with the original 128/255 offset and nested fused operations. Output is
unclipped, including negative/headroom values.

Plane APIs validate flat sample shapes, dimensions through 1,048,576 and sample
counts through 67,108,864, using the existing codec limits. Gaborish rejects
nonfinite/singular weights. Output buffers are independently owned, and input
samples are preserved. Empty planes and malformed dimensions/depths have focused
checks. These bounded APIs are not unrestricted source API parity. The stage
corpora use finite samples; special-value coverage belongs to the FMA corpus,
not a claim about every native SIMD exceptional-value behavior.

## Independent references

The stage reference remains `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The three complete stage files, channel accessors and stage traits were verified
byte-for-byte against that archive. A temporary oracle included the unchanged
files and original traits/accessors, using cached utilities and native SIMD
dispatch on arm64. Its harness supplied padded rows with replicated one-pixel
borders. Expectations came exclusively from those original stages.

FMA expectations came from the unmodified Rust standard-library `f32::mul_add`
operation, with NaN payloads normalized to `nan`. The reference toolchain observed
here is `rustc 1.97.1 (8bab26f4f 2026-07-14)`. Oracle source hashes:

- FMA: `f5c76be3e9bc86a41e80129a84eee0cf6f14488ca96a28556feff7851ec09250`.
- Native stages: `66b4b8c4c9b883838648b9ea9cd30a78cbfd3b1db324fcc31794eec853b99db5`.

No Cargo rebuild or network access was used. These temporary probes do not
become runtime or developer-tool dependencies. Frozen TSV tests execute with
V alone and do not compute expected outputs from V.

| Corpus | New source cases and exact comparisons |
| --- | --- |
| FMA | 35,008 triples: 32,768 deterministic finite inputs, 512 constructed midpoint cases and all 1,728 combinations of twelve special/edge words. Finite outputs, infinities and signed zeros compare by bits; NaNs compare by class. Both the ordinary and exact finite paths are checked. |
| Gaborish | 512 complete planes, widths 1–19 and heights 1–7, with default, zero, negative and small custom weights. Every output word matches. |
| Chroma | 384 complete planes: 128 horizontal, 128 vertical and 128 horizontal-then-vertical cases. Dimensions, borders, input preservation and every output word match. |
| YCbCr | 512 three-channel planes, widths 1–19 and heights 1–5. Every R/G/B word and unchanged input word matches. |

These add **36,416** cases, for **239,082** across the package. Whole planes
count as cases, not individual float samples. Previous row/vector/transcript
and ANS-transition counting remains unchanged. Corpus SHA-256 values:

- float-fma.tsv: `1657c193bfc10f897bbfe927b27d6a3709a7a2958c059f7bee62026d96c3e507`.
- gaborish.tsv: `727a83c8f1106c7d11f9f08b2d81519f7cd65529e791a20f964d84a0404d466a`.
- chroma.tsv: `bf34af8fbcebde607e05fe6fe05d172d0c23739ecf6be2649602caf807b7cc6d`.
- ycbcr.tsv: `897a15b66641ab7b91e48716f02f080caf402748004f798f674c4f30034b78f0`.

No expected records, successful cases or tolerances were changed to obtain a
pass. The first stage-oracle compile needed an explicit f32 annotation in its
weight-generation harness; source algorithm bodies were untouched. All V test
runs passed. V fmt required a second pass on the YCbCr result-array literal;
this was formatting-only and happened between the final default and no-GC runs.

## Executed checks

Each slice passed focused checks before committing. The final four-file checks
also passed in default GC, no-GC and optimized configurations:

| Configuration | Files passed | Test / guard exit | Sampled peak RSS, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 4 | 0 / 0 | 260,669,440 | 13.35 |
| No GC | 4 | 0 / 0 | 249,675,776 | 33.32 |
| Optimized, default GC | 4 | 0 / 0 | 456,818,688 | 92.35 |

Current V is `V 0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
A 143-input manifest covers JPEG XL V/testdata/data and original browser
fixtures. The compiler and all those hashes stayed unchanged across the final
no-GC and optimized checks. Before the default run, the manifest differed only
in YCbCr's subsequently formatted source file; no arithmetic changed. Sorted
final `path<TAB>SHA256<LF>` manifest hash:
`12fa0733a7e6c7655006120b426c75965c8229a5ff841dd2b4ce0d721c7496e0`.

All final commands used `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo`, under distinct
3 GiB guards with a 180-second timeout:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang test \
  jpegxl/float_math_test.v jpegxl/gaborish_test.v \
  jpegxl/chroma_upsample_test.v jpegxl/ycbcr_test.v
```

The second adds `-gc none` before `test`; the optimized run adds `-prod`.
Optimized execution checks rounding under compiler optimization; it is not a
production browser build or a performance measurement. Its guard includes
building the optimized V test driver. Formatting verification on owned files
and `git diff --check` pass. The full thirty-two-file package was not repeated
at 7/10. Prior LibJS/DOM/performance results and counters are unchanged.
RSS is a sampled process-tree sum, not a kernel bound or leak proof. Variable
shared-host activity makes these compile/guard durations unsuitable as codec
performance comparisons.

EPF, VarDCT, XYB/transfer conversion, frame dependencies, pipeline assembly and
production integration remain. Existing complete-file APIs still reject
filters, resampling and YCbCr. No separate production browser build or launch
was requested; normal shared post-commit rebuild hooks remain. Standalone stage
checks do not validate browser integration. Temporary oracle sources/binaries,
logs, receipts and unlocked guards are removed from the owned Build job after
recording this report. See [status](../../jpegxl/PORT_STATUS.md) and
[the preceding grouped-frame report](JPEGXL_V_GROUPED_FRAMES.md).
