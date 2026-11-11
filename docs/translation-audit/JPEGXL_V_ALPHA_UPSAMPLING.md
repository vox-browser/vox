# JPEG XL alpha upsampling

Slice `9479181d4` normalizes modular alpha samples to floats, expands them through
the existing source-matched 2x/4x/8x kernels, and quantizes only at final RGBA
output. VarDCT and modular XYB color retain their own restoration/upsampling
stages. Alpha uses neither color restoration nor color conversion. Matching
color/alpha factors and independently sampled alpha therefore preserve the
native ordering for this feature-free subset. LF alpha frames retain their
existing unit-sampling restriction. Legacy opaque entry points remain opaque.

There are **72 new native file records and 4,817,664 exact straight/paint RGBA
bytes**. Both VarDCT and modular XYB have 36 records, covering all nine legal
(color, alpha) factor pairs with alpha above 1, 33x25 and 513x31 images, ramp
and associated alpha, and orientation. The original parser verifies the actual
factors. The native pipeline uses matching
nonunit factors for 24 files and independent alpha expansion for 48 files. Expected alpha hashes are retained as
well as whole RGBA hashes. These records count once; the package now has
**282,913 independent records and 89 test files**.

`jpegxl/testdata/alpha-upsample-files.tsv` SHA-256 is
`ab874b5071a693b22c9f735fa2e0064cf8ecaf78f0d2ff2009053e0ee76261e3`.
Source/crate, native helper API version 1, cached original parser and encoder
library pins follow [the VarDCT alpha report](JPEGXL_V_VARDCT_ALPHA.md).
Expected pixels come only from native decoding, with identities verified
before/after generation. No fresh build provenance is asserted for the cached
helper. Source `frame/render.rs` normalizes extra channels before upsampling
and premultiplies color after sRGB transfer. Existing independent kernel and
integer-normalization records are reused without adding source cases.

Temporary encoder source/executable SHA-256:
`002fd827c9d509340e780265728513e92d5b1da37cf0ecf5e6174da236fcc9b9` /
`6cbc8127962e21645f3f3836b31e795e4a07ef64bac53c88cafa3922d1ea0442`.
Original parser caller source/executable:
`6b9e68590b27553af63ba42a1e12ff8fdfd5757ce0e14c0a00895a860d59d5db` /
`f95d2f77cfd48e2b84afee3f43b7b85586465fa7fe97cddf2cddfb8d632ae1fa`.
Reference driver:
`4fe5679784efd3578279d448bf9219c83b57e0bfed22eaef2011d4784796959c`.
Encoder/parser compilation and native references exit zero under 3 GiB guards.
The parser compile has an unused-import warning. Native reference creation
peaks at 52,363,264 sampled RSS bytes and takes 1.465 seconds. No candidate
pixels, changed reference hashes or tolerances supply expected results.

The compiler/invocation policy matches the earlier alpha report: current V
0.5.2 a5bda29, `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler
paths, `VJOBS=1`, no compatibility fallback, separate 3 GiB guards and 240-second
timeouts. The five-file focused selection is `alpha_upsample_test.v`,
`rgba_test.v`, `modular_alpha_rgba_test.v`, `lf_alpha_rgba_test.v` and
`vardct_extra_channels_test.v`. Older output records and channel-validation
contracts are preserved; invalid-factor fixtures now use factor 3 because
factor 2 is supported.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 5/5 | 342,851,584 | 66.225 |
| No GC | 5/5 | 749,092,864 | 69.256 |
| Optimized | 5/5 | 485,785,600 | 73.603 |

All tests/guards exit zero. Both snapshots cover 501 unchanged input hashes/
change times, manifest SHA-256
`06dfa1a21debd53507a6fd69a507267c53b91953bb1fe65bc4b7d8e6804f8a04`.
Cadence is **5/10** after the full 84-file checkpoint; no full 89-file run or
performance gain is claimed. Production still uses Rust. The managed commit
hook requests rebuilding; no extra manual browser build or launch is used to
validate the unconnected V package. Wider/dimension-shifted extra channels,
resampled LF alpha, chroma sampling, feature streams, frame composition, larger
entropy maps and production/tool integration remain. Removing all Rust remains
unfinished.
