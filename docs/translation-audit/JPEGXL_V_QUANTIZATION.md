# JPEG XL V quantization and initial inverse transforms, 2026-11-09

[The subsequent inverse DCT continuation](JPEGXL_V_INVERSE_DCT.md) records four
later slices and their fifty-five-file checkpoint. This report retains the
preceding six-slice evidence.

Six more decoder slices execute in pure V:

| Slice | Implementation commit |
| --- | --- |
| All seventeen quantization matrices and default calibrations | `53c8c59e4` |
| Raw modular quantization streams | `c0fc46a98` |
| Complete matrix sets and all transform lookups | `121919971` |
| HF coefficient dequantization | `3cb2e3fb4` |
| Hornuss identity inverse transform | `9850879b0` |
| DCT2X2 inverse transform | `3e6f59576` |

Every new focused file passes with default GC, no GC and `-prod`, with Rust
compiler paths unavailable. The package has **270,905** frozen source records
and **51** test files. These six slices add **3,136** records. JPEG XL cadence is
**6/10** after [the forty-five-file checkpoint](JPEGXL_V_VARDCT_PARAMETERS.md#lf-validation);
no new full-package checkpoint is claimed. Production JPEG XL still uses Rust.

## Independent reference boundary

The pinned `jxl` 0.7.0 archive SHA-256 is
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The `jxl_transforms` 0.7.0 archive SHA-256 is
`55b9b6a075a5554b5625828c322975372897be79b347d2795de721d27a2ed2b0`.
Translated source files were verified byte-for-byte against those archives:

| Source | SHA-256 |
| --- | --- |
| `frame/quant_weights.rs` | `d64d4c4a81be4505113fa5af0c221130877af0fb1d436ee73271408deba7be69` |
| `frame/group.rs` | `086c0f63f09e4d1d41d4681dc8068c45aca9190f4f41c2f6b43eaa130de6b2a0` |
| `jxl_transforms/src/transform.rs` | `477937cc290c4d078cdbe15ef41cce55ff71eed725f3cf033cdded143d062af5` |

Temporary migration references linked existing cached Rust artifacts directly;
there was no Cargo rebuild or network access. Cached `libjxl` SHA-256 was
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`,
and cached `libjxl_transforms` was
`e1f0257f34d0017dd69860476cb6bee832e0e8952886326d7094b439ce7a6803`.
The cached `libjxl_simd` SHA-256 was
`8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9`;
its 0.7.0 archive SHA-256 is
`efab4eb62605769d5b919b90331cd1e9c100d0e728fd292b0c39b18a3af712fa`.
Reference arithmetic comes from the original implementation. Python only
constructs inputs, frames binary output and hashes original output words;
candidate V output never supplies expectations. Frozen developer checks use V
alone. Temporary oracle source, binaries, input files, locks and receipts were
removed after recording this report.

| Oracle source | SHA-256 |
| --- | --- |
| Matrix generation | `9ad72ac62936d2c3165bc701298d430b20d5a61077963a4d5b9958c109d866e6` |
| Raw stream reader | `884bbe24a05656f2effb55659170ba513809c78971cc62658f99d0780b7ababd` |
| Complete matrix sets | `5e5fac4698538ebf7e21ad4c3dc225ecd276f40eea89a0f31662843dc01e0131` |
| HF dequantization | `7c864ea693cb43dccc141291a57856bd24d847750fe0b454c8d1624ef1c88c81` |
| Inverse transforms | `bbecd2046dbdeb3b3efdee07c666b62cfc7088ecb48ea44a9d2a26a55d5bcceb` |

The matrix oracle includes the original `quant_weights.rs` unchanged. Inert
raw-decoder adapters cannot run in this oracle; it constructs the source's
encoding records and calls its original matrix builder directly. All seventeen
default calibration records were extracted as exact binary32 constants into
`quant_library.v`, SHA-256
`29b16a27bae5cfefc75732177f7c9caf85f0b1e4e81dab3d759cfd1499bbd6d8`.
Gold matrices execute the original arithmetic independently of this V data.

The raw and matrix-set references include original entropy reader, predictor,
decision-tree and modular decoding source. Thin channel/storage and scratch-row
adapters expose the inaccessible internal API, and the original raw-table
decoder feeds the original matrix builder. These new cohorts use supplied
global trees and empty local-transform lists. Their local-transform branch is
an unreachable adapter; they do **not** establish new local-transform reference
coverage. The preceding 303-record modular-stream corpus separately covers
local/global trees and transforms. The V raw reader delegates to that existing
stream implementation, including its transforms and bounded tree/context limits.

The HF oracle executes the original `adjust_quant_bias`, `CoeffStorage`
implementations and `dequant_lane` with the cached native Neon descriptor.
It supplies original library matrices and the source's group/block scaling
expressions. The inverse-transform oracle calls the cached original
`transform_to_pixels_impl` directly with that descriptor.

## Exact comparisons

| Corpus | Cases | Accepted source results |
| --- | ---: | ---: |
| Matrix generation | 1,024 | 458 |
| Raw quantization streams | 512 | 100 |
| Complete matrix sets | 64 | 52 |
| HF dequantization blocks | 512 | 512 |
| Hornuss identity blocks | 512 | 512 |
| DCT2X2 blocks | 512 | 512 |

Matrix cases cover every default and raw table shape, scaled calibration
records, one through seventeen distance bands, malformed raw lengths and
nonfinite/range failures. Band interpolation, AFV placement, source coefficient
ordering, inclusive final weight bounds and reciprocal rounding compare exact
binary32 words. The low-level raw builder preserves the source's acceptance of
a negative denominator paired with negative samples when their product is valid;
the stream reader separately rejects nonpositive decoded samples.

Raw streams compare stream IDs, both signed integer storage widths, global
decision trees, all fourteen predictors, stream-index/channel/pixel properties,
positive-sample validation, final matrices and exact consumed-bit positions.
The stream ID is `1 + 3 * num_lf_groups + table_index`. Matrix channels use the
source's explicit zero shift. Complete-set cases interleave library, custom DCT
and raw streams at unaligned bit positions, including absent global trees and
invalid samples. All seventeen table geometries and full tables are hashed,
followed by all **27 x 3** bounded transform/channel slices. No source EOF
overreads require cursor exclusions in these cohorts. Public channel results
are independent copies; V computes owned defaults instead of borrowing the
source's lazy cache. No cache, memory or performance parity is claimed.

HF blocks compare all **1,930,368** output words, with all twenty-seven transform
kinds, both storage widths, scale endpoints, arbitrary positive u32 raw
quantization, signed correlation factors, default/custom finite biases and
integer conversion boundaries. Signed-16 narrowing and the SIMD wrapping
absolute value of `i32::MIN` are preserved. Ordinary multiplication/division
rounding stays separate; color correlation uses the existing exact binary32 FMA
helper. Outputs remain flat coefficient vectors, before LF replacement and
spatial placement. New whole-block references use library matrices; custom/raw
matrix arithmetic has its independent preceding coverage.

Hornuss and DCT2X2 compare **65,536** spatial output words. Each cohort includes
positive/negative coefficient impulses, explicit LF replacement, dense finite
values, subnormals and signed zeros. Hornuss retains source residual summation
order and quadrant placement; DCT2X2 retains all three staged top-block passes.
Both return independently owned 8-by-8 planes. The checked public API additionally
rejects malformed lengths, nonfinite inputs and unsupported transform kinds;
malformed-input acceptance parity is not claimed.

All matrix/block hashes serialize complete output f32 words little endian.
Matrix-set hashes additionally prefix geometry, lengths, transform and channel
IDs as u32 words. No numerical tolerances or changed expectations obtain a pass.

| File under `jpegxl/testdata/` | SHA-256 |
| --- | --- |
| `quant-matrices.tsv` | `2a7feff5b5ee469a34a402cff6f2f557b53e133fe39aa429816b2bd02294c72f` |
| `raw-quant-streams.tsv` | `29229c805a580a68b2d1f0fce1cdda98e7b3f784e00dd3bbf9aaf08f10f94b1b` |
| `quant-matrix-sets.tsv` | `fd58db15099ede889db951b3d90c98cd76b28ee33111da2318786dc70c2b9f43` |
| `hf-dequant.tsv` | `dd06c5a0e58cdffabee522a6c4e7fe2fd5d9bcc29a21bc7f6d3bde5470b209ad` |
| `inverse-identity.tsv` | `6d7bc7a2b34cba0232a457f98d2eb66cf8de61cbb304e014d35de60e579a7eac` |
| `inverse-dct2.tsv` | `9e3529882854f618e4a6de6b5ea50fa3666ef27628d24ece960870d5a9e4902e` |

## Executed validation

All test jobs use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo`, current V with
`-memory-limit 10G -b c -cc clang`, and `tools/run_memory_bounded.py` with
separate locks/reports, `--limit-gib 3 --timeout 180`. Default commands end
with `test jpegxl/FILE_test.v`; no-GC adds `-gc none`, optimized adds `-prod`.
Multiple-file rows select exactly the named focused files. Actual tests and
guards exit zero for every successful row:

| Job | Files | Sampled RSS peak, bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | ---: | --- |
| Matrix generation, default | 1 | 329,564,160 | 10.67 | 0 / 0 |
| Matrix generation, no GC | 1 | 322,256,896 | 9.27 | 0 / 0 |
| Matrix generation, optimized | 1 | 886,226,944 | 14.18 | 0 / 0 |
| Raw reader, default recovery | 1 | 341,442,560 | 12.55 | 0 / 0 |
| Raw reader, no GC | 1 | 335,822,848 | 20.53 | 0 / 0 |
| Matrix sets, default | 1 | 341,688,320 | 25.13 | 0 / 0 |
| Matrix sets, no GC | 1 | 479,756,288 | 24.76 | 0 / 0 |
| HF dequantization, default | 1 | 332,480,512 | 7.72 | 0 / 0 |
| HF dequantization, no GC | 1 | 323,043,328 | 5.65 | 0 / 0 |
| Raw reader + sets + HF, optimized | 3 | 1,462,042,624 | 41.53 | 0 / 0 |
| Hornuss, default | 1 | 314,556,416 | 4.53 | 0 / 0 |
| Hornuss, no GC | 1 | 308,772,864 | 4.07 | 0 / 0 |
| Hornuss + DCT2X2, default | 2 | 315,195,392 | 8.33 | 0 / 0 |
| Hornuss + DCT2X2, no GC | 2 | 308,772,864 | 6.91 | 0 / 0 |
| Hornuss + DCT2X2, optimized | 2 | 367,788,032 | 13.94 | 0 / 0 |

Original reference runs all exit zero. Their sampled RSS peaks, in corpus-table
order, are 48,939,008; 23,379,968; 39,043,072; 77,840,384; 14,696,448; and
245,760 bytes. Short sampled runs can miss a process's peak; these figures are
not allocation bounds. Reference wall times are 1.49, 2.05, 2.72, 2.63, 0.55 and
0.31 seconds. Concurrent unrelated host jobs existed; none of these test times
supports a performance comparison.

The first raw oracle compilation exited 1 because cached internal entropy
accessors and the quantization half helper were inaccessible. A second exited
1 for a missing macro dependency. The corrected wrapper includes original
entropy source, links the cached macro crate and supplies inert logging macros;
original algorithms and expectations remain unchanged. The first V raw test
compile exited 1 because current V emitted invalid C initializers for an
implicit nested fixed-array default. Test FrameHeader literals now explicitly
provide `RestorationFilter.default()`. The corrected test passes; no initial
failed job receives pass credit.

V is `0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
Before inverse-transform additions, a 200-input sorted
`path<TAB>SHA256<LF>` manifest was
`265e80c3f228e0d2c8062edefeb43bcded22ff6ce7e7b489cfb9cd771c6d09b5`;
its inputs were unchanged after the four matrix/HF optimized checks.
The final 206-input manifest is
`a0b8becd7cac0cab66cd512d3042bac566ac7889ef456c5093561f9bf7d054b0`.
It includes every JPEG XL V source/test, recursive test data, the embedded
dither table, browser JPEG XL fixtures, corpus checker and memory guard.
Its content hashes and inode change times were recorded during the final no-GC
inverse-transform job and checked unchanged after optimized validation; the
compiler hash also remained unchanged. The manifest extends the preceding checkpoint's separate dither
identity check by including that file directly.

## Remaining production work

HF entropy decoding, other inverse transforms, LF/global/frame assembly,
XYB/transfer conversion, frame dependencies and complete-file integration remain.
The bounded lossless decoder's supported output subset is unchanged. The
production Rust decoder, Cargo manifests, CI toolchain steps and
`tools/test_jpegxl.py` remain until the V decoder preserves the production
static 8-bit sRGB/gray behavior, limits and rejection rules.

These standalone stages are not imported by the production browser yet. No
manual production build or browser launch supplies validation here. The latest
successful shared receipt inspected records input head
`ec1ffcd4a6f9024c02309b626d1654d70ac0fd35` and executable SHA-256
`f14f71f6be464c11fa14ade78d458c28ef4a837524bc004ec9d1f9cdba1d7c53`.
Feature commits request coalesced production builds through the managed hook;
the ongoing shared builds were not duplicated or awaited. Other suites and
historical ledgers were not changed or rerun. Removing all Rust dependencies,
including developer tools, remains unfinished.
