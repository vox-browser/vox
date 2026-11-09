# JPEG XL V output sample conversion, 2026-11-09

V now normalizes modular integer rows to f32, multiplies straight color rows by
alpha and converts f32 rows to bytes with the source's positional blue-noise
dither. This is the tenth slice after the preceding fifteen-file JPEG XL
baseline, committed as `3486953e4`. It does not replace production JPEG XL or
its developer tools yet.

## Source and coverage

The reference remains `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The complete conversion and premultiplication stage files, channel accessors,
stage traits, dither source and binary table were byte-verified against it.
The temporary oracle included those unchanged stages with their original traits
and channel accessors, a minimal LF-quant record and cached source utilities.
It exercised native SIMD dispatch on arm64. No Cargo rebuild or network access
was needed, and no V output supplied expectations.
The temporary oracle source SHA-256 was
`c09ad0285feac593ef9e8de6ef054d51942a23ecbe916de102460277a8aeffe0`.

The 1,024-byte dither table is unchanged and retains its original DZgas CC BY
attribution in [the notice](../../jpegxl/DITHER_NOTICE.md). It is static data;
V implements conversion without Rust, native libraries or generated goldens.

| Cases | Exact comparisons |
| --- | --- |
| 62 integer rows | Both storage widths at every integer depth 1 through 31; 128 samples each, including signed extrema and narrowing. All f32 words match. |
| 4,096 quantized rows | 32 samples each; bit depths 1 through 8, translated/wrapping coordinates, all RGBA channel offsets, clamping, infinities, NaNs and constructed rounding ties. Every byte matches native source dispatch. |
| 768 premultiplied rows | All 65,536 8-bit color/alpha pairs for each RGB channel, at varied dither rows. Every f32 product and quantized byte matches. |

These are **4,926** additional whole-row cases and **335,616** compared sample
positions, bringing the package to **201,630** source cases and twenty-five test
files. Counts retain the earlier transcript/vector/ANS-transition definitions.
The frozen output corpus SHA-256 is
`5bee34ca24e09b2b3e78f089eaa02c8026920519828af6be34b50fec0760832c`.
No expected records or tolerances were changed.

Integer normalization preserves separate f32 reciprocal/multiply operations.
Quantization applies channel offsets `(23*c, 13*c)` modulo 32, scales first,
adds dither, clamps, and rounds to nearest with ties to even. This matches the
native SIMD dispatch exercised here; the source scalar fallback rounds ties
away and is not a parity claim. NaNs map to zero, infinities clamp. Coordinates
use widened arithmetic so valid API values cannot overflow. Rows are bounded
at 1,048,576 samples. Separate checks cover empty rows, invalid depths, unequal
alpha lengths and chunked/wrapping positions.

## Validation

The focused output file passed in both GC modes with unavailable Rust compiler
paths before the full twenty-five-file checkpoint. Sampled process-tree peaks
were 242,565,120 bytes (default, 7.21 seconds) and 218,710,016 bytes (no GC, 5.10
seconds). Formatting followed these checks; the checkpoint checks final bytes.
All twenty-five files passed in both GC modes through the V corpus checker.
The compiler was `V 0.5.2 a3892ac`, SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
Its hash and all 110 selected inputs stayed unchanged across both final batches:
JPEG XL V sources, TSV corpora, dither data, seven original JPEG XL fixtures,
the corpus checker and memory guard. Sorted `path<TAB>SHA256<LF>` manifest hash:
`dd8e5dbd688ead6e0054b4bfd4d9e1c63ad1b6c2caa491da0e932aaf5d58dd82`.

| Full checkpoint | Files passed | Test / inner guard / driver / outer guard exit | Outer sampled RSS peak, bytes | Outer seconds |
| --- | ---: | --- | ---: | ---: |
| Boehm | 25 | 0 / 0 / 0 / 0 | 639,221,760 | 258.46 |
| No GC | 25 | 0 / 0 / 0 / 0 | 607,977,472 | 235.40 |

The inner test guards peaked at 372,146,176 and 376,012,800 bytes, taking
247.47 and 221.77 seconds respectively. The outer sums include compilation of
the V driver. Both levels used 3 GiB guards. Results are sampled process-tree
sums, not kernel allocation limits or leak proofs. Host contention affected
compilation times; no performance comparison is claimed.

Both final commands used `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo`:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 300 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
  run tools/check_translation_corpora.v --suite jpegxl \
  --compiler /Users/alex/code/v/v
```

The second command adds `--gc none` and uses a 360-second outer timeout. The
driver executes `v -memory-limit 10G -enable-globals -b c -cc clang -gc MODE
test jpegxl` under its own guard. Both processes and supervisors exited zero.
Owned-file `v fmt -verify` and `git diff --check` passed. The JPEG XL cadence
resets to **0/10** at this checkpoint; unrelated LibJS/DOM/performance results
and counters are unchanged. No failed test attempt is omitted for this slice.

These are standalone module checks. Final frame color transforms, filters,
oriented pixel assembly, VarDCT and production integration remain. Normal shared
post-commit rebuild hooks are preserved; no separate browser build or launch
was requested and no browser validation is claimed.
