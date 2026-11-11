# JPEG XL V Gaussian spline rows

The next slice rasterizes cached Gaussian segments into three disjoint color
rows, preserving clipping, signed zero and the verified fused source profile.
Distance, error-function arguments and color accumulation retain the source's
F32 FMA boundaries. Extra channels remain outside this operation. This adds
**512 native records**, with **468 successful float images** comparing
**2,227,200 output words** by SHA-256 over explicit little-endian F32 data.

Every native and V image also requires bit-exact equality between full rows
and irregular 1–11-sample chunks. Both positive and negative width DCTs run
over deterministic backgrounds that include negative zero. There are 618,988
changed words; all 340 nonempty images change, while 128 empty-cache controls
remain unchanged. Forty-four records preserve the cache-construction failures.
These are raw color-plane images, not complete JPEG XL/RGBA or browser captures.

The package has **306,304 records and 102 test files**, cadence **8/10** after
the full 94-file checkpoint. No full 102-file run is claimed. Feature streams,
complete spline frames, reference composition and production/tool replacement
remain. Production JPEG XL and its native developer test still use Rust.

## Independent reference

The temporary caller reads only the input columns of the existing frozen cache
fixture, constructs original public `Splines`, negates sigma for the second
variant, calls original `initialize_draw_cache` and invokes `draw_segments`.
Expected words come directly from those rows. Source cache status is checked,
and full/chunked native output must agree before freezing its digest. No V
result, changed tolerance or expected-output override supplies reference data.

| Input or artifact | SHA-256 |
| --- | --- |
| Cache input fixture | `3244c9301276f3ddb4876c5503d883c0377505f24475954ff05f8ce4e683737d` |
| `jxl-0.7.0.crate` | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| `jxl_simd-0.7.0.crate` | `efab4eb62605769d5b919b90331cd1e9c100d0e728fd292b0c39b18a3af712fa` |
| `features/spline.rs` | `075bf47f34dce228b836b38d2ad3dcedc6f3ae93f1458cf21a86cb5376a96964` |
| `util/fast_math.rs` | `22d1831be17fa7de1c451538d9add5574ccd95bf4182acf4a15802683f7805e9` |
| `jxl_simd/aarch64/neon.rs` | `3f552100012767325f88852e19f3a9b974db29f69b157f9f7897e927c3713636` |
| Cached jxl rlib | `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8` |
| Cached SIMD rlib | `8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9` |
| Caller source | `067cb16df4bb84ec95473507c4e5e1f8b1e460cbb651786d10f8a3a60d113a24` |
| Caller executable | `a2509cbce2feed4a923e7e987e53b7d050f1fdebcfdc8a37dcb3dac045e7d6bd` |
| Native input manifest | `19b311c3d6a4eb98e57247bd10d499420ec3f0924ed88bc1f72e680722dd7afd` |
| `spline-raster.tsv` | `bebe79f6f19160de6f479a4915a7f87c23cfe2e6feeccf8adde8364ea978c5da` |

The cached original libraries are reused without source modification, Cargo
refresh or a fresh library build. The native caller and 3 GiB guard exit zero,
with selected input hashes/change times unchanged: 32,768 sampled peak RSS
bytes and 0.348 seconds. The short-run sample is not an allocation estimate.
This executes the AArch64 source renderer; scalar/SSE whole-row execution and
all-host byte equivalence are not claimed. The V operation fixes the verified
fused profile, independently of the scalar approximation API.

## V checks

Final checks select `spline_raster_test.v`, `spline_cache_test.v` and
`spline_math_test.v`, with unavailable Rust compiler paths, `VJOBS=1`, no
compatibility fallback and separate 3 GiB guards/180-second timeouts. Commands
use `v -memory-limit 10G -b c -cc clang [FLAGS] test` with those three paths.

| Mode | Flags | Passed | Peak RSS, bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default | none | 3/3 | 297,156,608 | 11.375 |
| No GC | `-gc none` | 3/3 | 289,800,192 | 10.388 |
| Optimized | `-prod` | 3/3 | 372,555,776 | 15.265 |

Actual tests/guards exit zero. All **726 selected hashes/change times** remain
unchanged, manifest SHA-256
`853fea5d1675a95b9f6cd5ed59eccf0a206f13a0136a4fc63a7e428ed13a602b`.
Compiler: V 0.5.2 a5bda29, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 20.551/23.091/23.986 at 16:47:28 UTC, 2026-11-09.
These observations establish recorded float output, without rendering-speed
or browser credit. Separate row checks cover bounds and initialized empty
caches. The checked API rejects malformed contexts and nonfinite backgrounds;
source panic behavior is not a parity claim. Managed hooks request coalesced
production rebuilds; no duplicate manual browser build validates these still
unconnected V modules.
