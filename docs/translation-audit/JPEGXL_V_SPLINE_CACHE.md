# JPEG XL V spline curves and draw caches

The next slice constructs centripetal Catmull–Rom subdivisions, resamples them
at unit distance, evaluates continuous color/width DCTs and builds bounded row
membership for Gaussian segments. A separate immutable draw cache preserves
the source ordering while storing only the in-bounds prefix of its row index
vector. The source's unused offscreen tail is omitted. Gaussian pixel drawing
and complete encoded spline frames remain separate work.

The corpus adds **256 native records**, with **234 accepted caches** containing
3,341 segments and 57,792 ordered in-bounds row entries. All 26,728 segment
float fields, row starts and indices compare exactly, with NaNs normalized
explicitly: 21 NaN fields have no payload/sign parity claim. These arise in
zero-intensity terminal segments; their source row membership is retained.
There are 64 initialized empty caches. Fourteen cases reject coincident
control points and eight reject excessive area.

Cases vary one/two splines, zero to three control deltas, LF correlation,
quantization, large sigma, image dimensions and both precision/level-5 flags.
The checked V cache also rejects invalid image geometry and mismatched source
lists before constructing curves. Subdivision and spacing retain the source's
F32 operation order; recorded norms computed through V math agree with the
reference. This establishes the selected words, not all-input hypot parity.

The package has **305,792 records and 101 test files**, cadence **7/10** after
the full 94-file checkpoint. No full 101-file run is claimed. Gaussian drawing,
feature/reference frame integration and production/tool replacement remain.
Production JPEG XL and its native developer test still require Rust.

## Independent reference and checks

The temporary caller constructs public source `Splines` state and invokes
unchanged `initialize_draw_cache` in the cached `jxl` 0.7.0 rlib. Private
segment and index state comes from original Debug output. Rust float parsing
round-trips its shortest strings; NaNs normalize to one word and field lengths
are asserted. Only indices reachable through the original image-row prefix
are retained for comparison. This does not infer whole-image pixels from a
successful cache construction.

| Input or artifact | SHA-256 |
| --- | --- |
| `jxl-0.7.0.crate` | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| `features/spline.rs` | `075bf47f34dce228b836b38d2ad3dcedc6f3ae93f1458cf21a86cb5376a96964` |
| `util/fast_math.rs` | `22d1831be17fa7de1c451538d9add5574ccd95bf4182acf4a15802683f7805e9` |
| `frame/color_correlation_map.rs` | `26a26a1d72ab7ecbabd4db08a59b281ee3f582fb443b22a943c27d7c689fac79` |
| Cached rlib | `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8` |
| Caller source | `9fe5e4388e12bfe9f4cc6eee55c9463218bd71da55d2f10d3d5302a564708c48` |
| Caller executable | `6c69715b6ec0ecf1b27defe730457d4b06eb63203d205f81e791826e80a73ddb` |
| Native input manifest | `30e21d214130f801afb92a142f62366477ab37d9a575eb5b0b78b1d1208b3b5c` |
| `spline-cache.tsv` | `3244c9301276f3ddb4876c5503d883c0377505f24475954ff05f8ce4e683737d` |

All three cached source files match the checksummed archive byte for byte.
No source modification, Cargo refresh or fresh library build is claimed.
The native caller and its 3 GiB guard exit zero, with selected hashes/change
times unchanged: 32,768 sampled peak RSS bytes and 0.445 seconds. This short-run
sample is not a total allocation estimate. Expected records remain unchanged.

Final V checks select `spline_cache_test.v`, `spline_math_test.v` and
`spline_dequant_test.v`, with unavailable Rust compiler paths, `VJOBS=1`, no
compatibility fallback and separate 3 GiB guards/180-second timeouts. Commands
use `v -memory-limit 10G -b c -cc clang [FLAGS] test` with those three paths.

| Mode | Flags | Passed | Peak RSS, bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default | none | 3/3 | 296,304,640 | 7.619 |
| No GC | `-gc none` | 3/3 | 288,849,920 | 7.471 |
| Optimized | `-prod` | 3/3 | 383,156,224 | 15.459 |

Actual tests/guards exit zero. All **723 selected hashes/change times** remain
unchanged, manifest SHA-256
`a282d0fc90cb372da23e3938752862038f153dabfbf64e5303fc3836d1c8baf3`.
Compiler: V 0.5.2 a5bda29, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 16.875/22.749/28.860 at 16:29:38 UTC, 2026-11-09.
These are correctness observations, without rendering performance credit.

Additional V limits are 65,536 control positions per subdivision, 1,048,576
spaced points/segments, 16,777,216 row entries and the existing 67,108,864-sample
geometry budget. These checked API limits and failure behavior are not full
source allocation/panic parity. Managed hooks request coalesced production
rebuilds; no duplicate manual build or browser launch validates these still
unconnected modules.
