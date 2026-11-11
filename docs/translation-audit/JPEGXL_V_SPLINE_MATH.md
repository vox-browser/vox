# JPEG XL V spline cosine and Gaussian arithmetic

The next slice translates the source cosine approximation and both scalar and
NEON rounding profiles of its error-function approximation. The V routines
retain unfused operations where the source does, and use the existing pure V
exact F32 helper for the four fused NEON polynomial steps. Sign copying
preserves negative zero. These are codec approximations, without a general
trigonometric accuracy or whole-spline rasterization claim.

The frozen corpus contains **14,361 distinct input words**, including a grid
over -16..16, deterministic finite samples within -128..128, sampled spline
DCT arguments, bit neighbors of range-reduction boundaries and signed zeros/
subnormals. Original `fast_cos`, `fast_erff` and explicitly selected scalar
and NEON `fast_erff_simd` outputs are compared as F32 words. The two original
scalar paths agree everywhere; **135 cases differ from NEON**, so both rounding
profiles are exercised. Native scalar descriptor `mul_add` is unfused; native
NEON uses fused instructions. No fallback/dispatch inference supplies this
coverage: both descriptors are called directly.

The package has **305,536 records and 100 test files**, cadence **6/10** after
the full 94-file checkpoint. No full 100-file run is claimed. Curves, draw
caches, Gaussian splats and complete feature/reference frames remain.
Production JPEG XL and its native developer test continue to use Rust.

## Independent source and checks

The temporary caller links the cached `jxl` and `jxl_simd` 0.7.0 rlibs. It uses
public source functions without modifying either library. Both source archives
and all three relevant source files are checked byte for byte before reference
creation; no fresh library build or Cargo refresh is claimed.

| Input or artifact | SHA-256 |
| --- | --- |
| `jxl-0.7.0.crate` | `6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e` |
| `jxl_simd-0.7.0.crate` | `efab4eb62605769d5b919b90331cd1e9c100d0e728fd292b0c39b18a3af712fa` |
| `util/fast_math.rs` | `22d1831be17fa7de1c451538d9add5574ccd95bf4182acf4a15802683f7805e9` |
| `jxl_simd/scalar.rs` | `21c5e3e4176ecb2d4f6f3cad49cc810e34a24ad8c917a9be007d07b0f45008a2` |
| `jxl_simd/aarch64/neon.rs` | `3f552100012767325f88852e19f3a9b974db29f69b157f9f7897e927c3713636` |
| Cached jxl rlib | `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8` |
| Cached SIMD rlib | `8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9` |
| Caller source | `5e0524b7a466b5fa3c0865aeee8daadbbca7029f5dfab20a850ba5df570ffc9d` |
| Caller executable | `b65991296f25f7b826992102eaaecf04c79944dd93e77d2feaffca0c700ed365` |
| Native input manifest | `748b5779258aedf911e294ad74e9e7ec1ce10ccc5b47cdf4c09a99c756805454` |
| `spline-math.tsv` | `a314503fe07b6a0a6324e9f0501202d4af917f78a59c582c823d7815d9dbc19b` |

The native caller/3 GiB guard exits zero with all selected hashes/change times
unchanged: 32,768 sampled peak RSS bytes, 0.587 seconds. This short-run RSS
sample is not a total allocation estimate. The fixture is frozen before V
implementation and remains unchanged throughout verification.

Final checks run `v -memory-limit 10G -b c -cc clang [FLAGS] test
jpegxl/spline_math_test.v` with unavailable Rust compiler paths, `VJOBS=1`,
no compatibility fallback, separate 3 GiB guards and 180-second timeouts.

| Mode | Flags | Passed | Peak RSS, bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default | none | 1/1 | 277,250,048 | 4.812 |
| No GC | `-gc none` | 1/1 | 284,573,696 | 3.557 |
| Optimized | `-prod` | 1/1 | 382,812,160 | 8.968 |

Actual tests/guards exit zero. All **719 selected input hashes/change times**
remain unchanged, manifest SHA-256
`4bcf566d77c2d70bb97ffc3c5d03edf76e449bb640299f6bd5a4a007d3aef2e1`.
Compiler: V 0.5.2 a5bda29, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Host: 18 CPUs, loads 30.265/32.864/35.724 at 16:15:46 UTC, 2026-11-09.
These observations establish recorded arithmetic behavior, not browser speed,
all-input IEEE parity or complete spline rendering. Managed commit hooks
request coalesced production rebuilds; no duplicate manual build is used to
validate this unconnected V code.
