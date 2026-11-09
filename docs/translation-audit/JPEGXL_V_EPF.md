# JPEG XL V edge-preserving filter, 2026-11-09

All three EPF passes now run in V: final pass 2 (`dcf9e80a4`), middle pass 1
(`3900ee4b7`) and wide pass 0 (`e888478e2`). These are three completed slices
after the preceding 7/10 continuation. The resulting ten-slice checkpoint
passes the full thirty-five-file JPEG XL suite in both GC modes, resetting JPEG
XL cadence to **0/10**. These standalone stages do not yet enable filtered
file decoding or remove production/developer-tool Rust dependencies.

## Implementation and independent source

The pinned source remains `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Nine source files were verified byte-for-byte: the three EPF stages, common
sigma/border helpers, sigma-source definitions, channel accessors, stage traits,
mirror helper and root constants. The temporary oracle includes the original
stage/common/accessor/trait code unchanged, uses the original sigma-source enum
with cached source Image buffers, and runs native SIMD dispatch on arm64.
Its padding uses the source mirror function. No Cargo rebuild, network access
or V-computed expectation was used.

Oracle SHA-256: `f642cef9f0f164b80ead8e180a0c11c81f635267711b7bdd1abb959874c57f97`.
The frozen corpora execute with V alone; the temporary migration oracle is not
a new runtime or developer-tool dependency.

Pass 2 combines four neighboring pixels with one color-weighted SAD each.
Pass 1 compares five-point patches at four neighbors, and pass 0 compares those
patches at twelve neighbors. Generic reflected sampling replaces the source's
cached neighborhood differences. Patch summation and channel FMA order are
preserved. Weight sums run forward; passes 0/1 accumulate output neighbors in
reverse source order while pass 2 runs forward. FMA uses the preceding pure V
binary32 helper.

`EpfSigma` accepts a constant inverse sigma or a block plane indexed at global
coordinates divided by eight. `EpfSigma.modular()` converts positive modular
metadata sigma into the source inverse value. The exact MIN_SIGMA comparison,
per-pixel bypass, border multiplier, and block phase are retained. Source SIMD
lane-wide early exits are represented by equivalent per-pixel bypasses. The
input origin affects block/sigma lookup; reflected sample borders belong to the
supplied complete plane.

| Reference corpus | Cases | Compared output f32 words |
| --- | ---: | ---: |
| EPF pass 0 | 512 | 76,437 |
| EPF pass 1 | 512 | 76,437 |
| EPF pass 2 | 512 | 76,437 |

Every output word and unchanged input word matches. Cohorts cover widths 1–19,
heights 1–9, origins across all eight-pixel block phases, constant and variable
sigma, threshold equality/adjacent words, signed zero, positive sigma inputs,
mixed bypass lanes, default/zero/custom channel scales, custom border/pass
scales, constant planes, gradients, alternating high contrast and random small
samples. Each pass has 19,947 active pixel positions and 5,532 bypass positions;
2,730 positions equal the threshold exactly. These counts follow the frozen
sigma inputs, independent of candidate outputs. Sigma-map padding only supplies source SIMD overreads; it does not
contribute expected visible pixels.

These add **1,536** whole-plane source cases and **229,311** output words,
bringing the package to **240,618** source cases and thirty-five test files.
Whole-plane/row/transcript and earlier ANS-transition counting is unchanged.
Corpus SHA-256 values:

- epf0.tsv: `ee76d2debce765c1a2fc1d172debf2f4aa2373d121b3c29870b8df18c31c6931`.
- epf1.tsv: `6a69dfd3e04581ba1d3b9f20e3a909e7b8de9ae70b8f9b186c56bf5c345d8a0f`.
- epf2.tsv: `ed72355d0c2b2404705130d437a914f0f16849a0ff7bf24497659dd200ce8356`.

No expected TSV record or tolerance changed. The first additional modular-sigma
unit check had a mistyped expected word; it failed, then was corrected to the
unchanged source corpus's `3205887514`. That failed expanded test run receives
no whole-file pass credit. Original frozen-plane comparisons were already exact.
The shared kernel was rechecked against prior passes after each slice.

## Validation

Focused tests pass in both GC modes, and all three pass an optimized build.
The optimized guard peaked at 433,127,424 bytes and took 36.90 seconds, with test
and guard exits zero. It uses final source bytes and checks arithmetic under
optimization; it is not a production browser build or a performance benchmark.

| Full checkpoint | Files passed | Test / inner guard / driver / outer guard exit | Outer sampled RSS peak, bytes | Outer seconds |
| --- | ---: | --- | ---: | ---: |
| Boehm | 35 | 0 / 0 / 0 / 0 | 543,145,984 | 258.68 |
| No GC | 35 | 0 / 0 / 0 / 0 | 538,460,160 | 258.22 |

Inner test guards peaked at 286,523,392 and 283,312,128 bytes, taking 253.14
and 248.15 seconds respectively. The outer sums include driver compilation.
Both batches completed with successful actual tests, supervisors and drivers;
compile-only checks are not counted as execution.

The final compiler is `V 0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
The final 155-input manifest covers JPEG XL V/TSV/data, the original browser
fixtures, corpus checker and memory guard. Sorted
`path<TAB>SHA256<LF>` manifest SHA-256:
`0791cb9800f9cc9a6aa12bcdd4f72fb0f7b1cbe48d6df38cda725cab8598f7a3`.
The compiler and those inputs remained unchanged across optimized and full
checkpoint checks, verified before, between and after the batches.

Commands use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo` with unique 3 GiB
guards. Focused checks use a 180-second timeout:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang test \
  jpegxl/epf0_test.v jpegxl/epf1_test.v jpegxl/epf2_test.v
```

The second adds `-gc none`; optimized execution adds `-prod` and uses a
240-second timeout. Full checkpoint commands use a 600-second outer timeout:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 600 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
  run tools/check_translation_corpora.v --suite jpegxl \
  --compiler /Users/alex/code/v/v
```

The second full command adds `--gc none`. The checker applies its own 3 GiB
guard and `-enable-globals`, with one compilation job. Formatting verification and owned-path `git diff --check`
pass. RSS is a sampled process-tree sum, not a kernel allocation bound or leak
proof. Shared host activity varies, and no performance or SIMD speed claim is
made. Unrelated LibJS/DOM/performance ledgers are unchanged.

## Remaining boundaries

EPF requires three equal-sized planes. Total color samples are bounded at
67,108,864, using the existing dimension limit of 1,048,576. Configuration values
must be finite; block sigma must cover the requested global extent, and derived
scale/modular inverse overflow is rejected. Output samples are independently
owned. Shape errors, invalid sigma, empty planes and bypass ownership have
focused checks. This is a bounded API, not unrestricted source API parity;
exceptional sample/NaN payload behavior is not established by the finite corpus.

The VarDCT quantization/transform/sharpness-to-sigma map builder remains pending.
Pass sequencing with other filters, complete frame color/filter assembly,
VarDCT/frame dependencies, XYB/transfer conversion, partial rendering and browser
integration remain. Existing complete-file APIs still reject filters and YCbCr.
Production Rust JPEG XL and its Cargo/CI/developer tools are retained until their
supported paths can be preserved.

No separate production browser build or launch was requested. Normal shared
post-commit rebuild hooks remain. The temporary oracle sources/binary, logs,
receipts and unlocked guards in the owned Build job are removed after recording
the completed report. See [status](../../jpegxl/PORT_STATUS.md) and
[the preceding filter/color report](JPEGXL_V_FILTER_COLOR_STAGES.md).
