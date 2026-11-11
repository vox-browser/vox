# JPEG XL V quantized spline streams

The next slice decodes spline counts, differential starting points,
quantization adjustment, second-difference control points and all four 32-term
DCTs. It finalizes the shared entropy reader, preserving this source check
unlike the patch dictionary. Dequantization, curve subdivision, Gaussian
rendering and whole-frame integration remain. Production JPEG XL and its
native developer test still use Rust.

The frozen corpus adds **3,044 records**, with **536 accepted**. Accepted state
contains 2,505 splines, 6,002 control deltas and 320,640 signed coefficients.
Every accepted record compares consumed bits, adjustment, counts, starting
point float words, control deltas and DCTs exactly, using documented normalized
integer lists and SHA-256 for the larger fields. Errors normalize to `err`;
their text and consumed-bit state are not parity claims.

Inputs cover signed 32-bit extremes for adjustment and coefficients, first and
subsequent start positions, source coordinate/delta limits, zero control points,
the exact aggregate point budget, saturated spline counts, pixel counts through
U32_MAX and every byte prefix of four distinct streams. There are 2,495 EOF
errors, six point-budget failures, four spline-count failures, two excessive
deltas and one excessive starting position. The independent author uses six
constant-symbol prefix contexts with HybridUint residual bits, including token
32 for U32 extremes. Dictionary-level ANS/LZ77 coverage is not newly claimed;
their primitives retain the existing entropy corpus.

## Reference and verification

The temporary caller invokes unchanged public `Splines::read` in the cached
`jxl` 0.7.0 rlib, then serializes its public fields directly. It also verifies
that the native draw cache remains uninitialized. The source matches its
checksummed crate archive byte for byte. No Cargo refresh or fresh reference
library build is claimed.

| Input or artifact | SHA-256 |
| --- | --- |
| `jxl-0.7.0.crate` | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| `features/spline.rs` | `075bf47f34dce228b836b38d2ad3dcedc6f3ae93f1458cf21a86cb5376a96964` |
| Cached rlib | `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8` |
| Caller source | `59be9df0614252c12dc1d50a4f6149087ac683bab5910f3abd7acbd81a04639b` |
| Caller executable | `52bad546db9fc7ae6d2cc54b8a71dc4d69238851a743f14bb61f8c203eab410a` |
| Input author | `f87dff84bc4a73f4832157d16f1c3ddb7602d46683f6789dc50df7c021844eb1` |
| Normalization helper | `9588da5203d716400571600703c058e861a612e6cc5e6dad6d3287e3a968605b` |
| Native input manifest | `fa2dc74427fedab29fc89628486aed0d4195785a5ed963135484cb517ba13acf` |
| `spline-streams.tsv` | `b0710a348291bab8b5277e78f70c50729e3eaa560ca78e785958540c4d8cef41` |

The reference guard/caller exits zero, with selected input hashes/change times
unchanged: 5,586,944 sampled peak RSS bytes and 0.476 seconds under a separate
3 GiB guard. The reference records were frozen before V implementation.

Final V checks use unavailable Rust compiler paths, `VJOBS=1`, no compatibility
fallback, separate 3 GiB guards and 180-second timeouts. The command is
`v -memory-limit 10G -b c -cc clang [FLAGS] test jpegxl/spline_stream_test.v`.

| Mode | Flags | Passed | Peak RSS, bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default | none | 1/1 | 296,927,232 | 3.708 |
| No GC | `-gc none` | 1/1 | 290,848,768 | 3.643 |
| Optimized | `-prod` | 1/1 | 579,911,680 | 8.964 |

Actual tests/guards exit zero. All **713 selected input hashes/change times**
remain unchanged, manifest SHA-256
`a4604c9716bdca109b5799c6cf490fb7a8f075eaa01f3783467cab1e79c1eaa4`.
Compiler: V 0.5.2 a5bda29, executable SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 19.525/20.254/40.622 at 15:58:47 UTC, 2026-11-09.
These are correctness observations, not browser performance results.

The initial V attempt did not compile because primitive mutable parameters
are disallowed. The helper now receives the remaining point budget by value,
which also prevents malformed accumulated-count overflow. That failed attempt
receives no execution credit; the native fixture remains unchanged.

The package has **290,279 records and 98 test files**, with cadence **4/10**
after the full 94-file checkpoint. No full 98-file run is claimed. The parser
does not initialize or render splines, change the production codec, or establish
allocation/panic behavior parity. Managed commit hooks request coalesced
production rebuilds; no duplicate manual build or browser launch is used as
evidence for this unconnected V module.
