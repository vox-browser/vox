# JPEG XL V spline dequantization

The next slice reconstructs integer control positions from second differences,
scales color/width DCTs, applies LF color correlation, estimates covered area
and validates adjacent point coincidence. It adds **896 native records**, with
244 successful dequantizations comparing **33,664 float words**, exact U64
area estimates and coincidence results (19 coincident cases). The other cases
reject 479 out-of-range point sequences and 173 excessive distances. These
records count whole calls once, rather than counting their individual floats.

The package has **291,175 records and 99 test files**, cadence **5/10** after
the full 94-file checkpoint. No full 99-file run is claimed. Curve subdivision,
segment caching, Gaussian rasterization and complete feature/reference frames
remain. Production JPEG XL and its native developer test still use Rust.

## Independent reference

The temporary caller constructs public `QuantizedSpline` values and invokes
unchanged `dequantize` and `validate_adjacent_point_coincidence` methods in the
cached `jxl` 0.7.0 rlib. Private result fields are read from original Debug
output: Rust's shortest float strings round-trip through Rust's f32 parser to
their original words, with explicit field-length assertions. No library source
is modified, Cargo refresh is performed, or fresh library build is claimed.

Cases vary starting points around rounding/range boundaries, zero to ten
control deltas, mixed DCT coefficients, positive/negative quantization changes,
both LF correlations and area limits through U64_MAX. Targeted inputs include
I32_MIN/MAX coefficients/adjustments, zero deltas and coincident points. The V
port spells out the source release behavior of I32_MIN absolute value and
saturating float-to-U64 casts, avoiding C signed overflow/out-of-range casts.
Its coordinate checks preserve the inclusive negative dequantized limit,
which differs from the stricter starting-position entropy check.

| Input or artifact | SHA-256 |
| --- | --- |
| `jxl-0.7.0.crate` | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| `features/spline.rs` | `075bf47f34dce228b836b38d2ad3dcedc6f3ae93f1458cf21a86cb5376a96964` |
| `util/log2.rs` | `705f2fdda7d8ca5a88627da00f12d92320bbe35215c0a568315301bc434243f4` |
| Cached rlib | `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8` |
| Caller source | `8f0aa5bbe33ff2753cf1396ddae4dc62e1f06928409430683de1df6ec802fca6` |
| Caller executable | `a20216383cfaffcb1cc76119d825eaedab179ba48c7cbf09beccfb89208d4ace` |
| Native input manifest | `68bd94e19d20795f78f16dcafef4ddf1b331473397b570cb2c3e94a631fb90d7` |
| `spline-dequant.tsv` | `a11e76d786c0f8dd71497e08a9c8c8d36891800f1c0ddd4175d7a0324a2fd149` |

Both cached source files match the archive byte for byte. The native caller and
its 3 GiB guard exit zero, with all selected input hashes/change times
unchanged: 32,768 sampled peak RSS bytes and 0.382 seconds. This short-run
sample is not a total allocation estimate. The fixture was frozen before V
implementation; no expected values were changed to obtain a pass.

## V verification

Final checks run both `spline_dequant_test.v` and `spline_stream_test.v` with
unavailable Rust compiler paths, `VJOBS=1`, no compatibility fallback, separate
3 GiB guards and 180-second timeouts. The command is
`v -memory-limit 10G -b c -cc clang [FLAGS] test
jpegxl/spline_dequant_test.v jpegxl/spline_stream_test.v`.

| Mode | Flags | Passed | Peak RSS, bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default | none | 2/2 | 294,027,264 | 15.738 |
| No GC | `-gc none` | 2/2 | 286,097,408 | 12.632 |
| Optimized | `-prod` | 2/2 | 557,350,912 | 29.404 |

Actual tests and guards exit zero. All **716 selected input hashes/change
times** remain unchanged, manifest SHA-256
`9e1410f4b7cd760f76d28edcf7bd1dfd6dff1a23238c64f9afdf3e910352733f`.
Compiler: V 0.5.2 a5bda29, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 20.016/21.303/33.025 at 16:05:57 UTC, 2026-11-09.
These observations establish correctness, not rendering performance.

Separate checks reject NaN/infinite context before coordinate conversion.
The V API bounds point counts and requires finite context and representable
second differences; behavior for arbitrary malformed public structs, source
panics and allocation failure is not a full parity claim. This slice does not
initialize a draw cache, rasterize a spline, or connect the production codec.
Managed commit hooks request coalesced production rebuilds; an older bundle is
not used to validate these unconnected modules.
