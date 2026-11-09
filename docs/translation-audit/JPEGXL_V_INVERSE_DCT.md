# JPEG XL V inverse DCT continuation, 2026-11-09

Four more focused slices extend [the quantization continuation](JPEGXL_V_QUANTIZATION.md):

| Slice | Implementation commit |
| --- | --- |
| 2/4/8/16/32-point inverse DCT kernels | `dfad28dfd` |
| Two-dimensional inverse DCT planes and complete 8x8 DCT | `5885a8516` |
| DCT4X4, DCT4X8 and DCT8X4 block reconstruction | `bf13d6f84` |
| LF injection and complete ordinary DCTs through 32x32 | `dd1d90b94` |

At this checkpoint the V package reconstructs fourteen of the twenty-seven transform kinds.
All eighteen ordinary DCT kinds have LF injection, including the largest
256x256 transform. Large inverse DCT kernels and the four AFV inverse transforms
remain; these stages are still separate from production complete-file output.
The two-slice continuation below subsequently completes all twenty-seven kinds.

The four new files add **5,504** independent source records, bringing the
package to **276,409** records and **55** test files. Together with the preceding
six slices, this is the next ten-slice JPEG XL checkpoint. Its executed full
validation is recorded below. Rust removal remains unfinished.

## Source and reference boundary

The pinned `jxl_transforms` 0.7.0 archive SHA-256 is
`55b9b6a075a5554b5625828c322975372897be79b347d2795de721d27a2ed2b0`.
All twelve additional translated source files were verified byte-for-byte
against it. Source identities under `jxl_transforms/src/` are:

| Source | SHA-256 |
| --- | --- |
| `idct2.rs` | `503fdff4404e1b23e71d652020e1ce726740df142a3b4017817f713c2db5bf4b` |
| `idct4.rs` | `87017cdab3de41297919571643ff0b19e0aad7da13702d02f9e411467608cbea` |
| `idct8.rs` | `74f51aa5228559daf5bcaba2a70388640db997b0859aca5bc6e1cf198f1a65ac` |
| `idct16.rs` | `2ddb6e312d4c5f0fddf75c42bbe5d2878d49e1459e7087a1d91b9b2f9b1f0172` |
| `idct32.rs` | `a603b68484ccf0b274d907f3e5e0d44eff59da27061d2e8b2b07f40412d3316a` |
| `idct2d.rs` | `07e3fe0f7ce85e874206a88665310489444c1d410a39953c2794f116f654f221` |
| `reinterpreting_dct2.rs` | `f8540847f76445421db96dcadef237157101c6d151864c852bdf7ca4688534c1` |
| `reinterpreting_dct4.rs` | `cae1241c7a7f3afaca8d8878624bac437e45aca2b037369239e3c3fe4e192963` |
| `reinterpreting_dct8.rs` | `b8fd4ba2f401357ce2873d585614465f927675eef32dc4443ed252f5fe08efc0` |
| `reinterpreting_dct16.rs` | `f6eaa651bffeb4ba8a6a896bcc3842b07de7ea15d2bac6291877b2536569f339` |
| `reinterpreting_dct32.rs` | `15f9fc63336158914ebbcbdbdf62ca25862ecbb13cbc6f99e7d6fd1ce845c623` |
| `reinterpreting_dct2d.rs` | `4f8711dbb807e2bfbd4dd38c88e1a4a3bbac3c8eccc2159561ee73e1571f54d0` |

The preceding report pins `transform.rs` and the cached `libjxl_transforms` and
`libjxl_simd` artifacts. Temporary source references link those existing
artifacts directly; no Cargo rebuild or network access is involved. The vector
oracle imports original `idct*.rs` modules unchanged and calls their private
kernels. Every SIMD lane receives the same input; kernels operate independently
per lane. Plane, full-transform and LF references call the original cached
public functions. Native Neon is selected, with the source's own scalar dispatch
for 2x2 IDCT and LF transforms having an axis below four.

Straight-line V kernels preserve every source operation and literal, with
unique local names replacing shadowed multiplier bindings. Explicit source
FMA calls use the existing binary32 helper. LF kernels select separate rounded
multiplication/addition when original scalar dispatch requires it. Original
ordinary arithmetic stays unfused. These choices preserve the pinned native
reference's rounding; they do not establish bit parity with every other SIMD
backend or compiler configuration.

Python constructs inputs and hashes original output bytes. It never computes
gold transforms from the candidate V implementation. Oracle source SHA-256:

| Oracle | SHA-256 |
| --- | --- |
| Vector kernels | `8a853735a2a1e23faa3dd53eadc642c790dff684fccff4963eee9fa03c05a293` |
| Two-dimensional planes | `1fb04cedbaf491a4559e2ddec7d1625449d64d6eff89b6f24bcf63426dce3d03` |
| Complete subblocks | `bbecd2046dbdeb3b3efdee07c666b62cfc7088ecb48ea44a9d2a26a55d5bcceb` |
| LF injection and complete DCTs | `8fa08380ed9b5844d4db274aec84e0e34f75cde481585d9136cf085fba764a05` |

## Exact comparisons

| Frozen corpus | Source records | Complete output f32 words |
| --- | ---: | ---: |
| Small vector kernels | 2,560 | 31,744 |
| Thirteen two-dimensional geometries | 832 | 206,080 |
| Three subblock kinds | 1,536 | 98,304 |
| LF injection into complete coefficient vectors | 64 | 190,912 |
| Nine complete ordinary DCT kinds through 32x32 | 512 | 178,688 |

All records succeed in the original reference. Vector records retain every
output word directly. Other records compare SHA-256 over every output f32 word
in little-endian order, without tolerances or numerical normalization. All
**705,728** words match. Input vectors, LF values and coefficients remain
independently owned and unchanged at the checked V API boundary.

Vectors include positive/negative impulses at every position, negative-zero
vectors, subnormals and dense finite values. Plane records cover every source
geometry from 2x2 to 32x32, including both rectangular orientations. They preserve
axis order, longest-side coefficient storage and the source's output transpose
convention. Complete subblocks additionally compare LF replacement, quadrant
DC construction and horizontal/vertical spatial placement.

LF injection covers all eighteen ordinary DCT kinds, every 1/2/4/8/16/32-block
axis size, both scalar and fused arithmetic, and exact coefficient placement
through 256x256. The 190,912 words are complete coefficient vectors, including
untouched HF positions, rather than that many rewritten LF samples. Complete
small-transform records compare LF/HF assembly through spatial output; large
transform records only establish LF injection. Checked APIs reject unsupported
geometries, nonfinite inputs and malformed storage. Additional rejection checks
do not claim original malformed-input acceptance parity.

| File under `jpegxl/testdata/` | SHA-256 |
| --- | --- |
| `inverse-dct-vectors.tsv` | `9e168e83dba8925f5b39d45319c5a1ad981b351aa95887cf78923702695a1a43` |
| `inverse-dct-planes.tsv` | `87b9567167585dd46daf966d78b2ce217b5e0251a4b47d7939b607a4fa7d05fa` |
| `inverse-dct-subblocks.tsv` | `122bb03d0d9590df732a27b40d0de344c7806a8eac2db632ed792e63e585d9a1` |
| `dct-lf.tsv` | `1c81fb6219dbeb5df93c8e329e6ee4d54eb4104a53b6625a0ce54375d65e4344` |

## Focused validation

Tests use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo`, and current V with
`-memory-limit 10G -b c -cc clang`. Every job uses
`tools/run_memory_bounded.py` with a unique lock/report,
`--limit-gib 3 --timeout 180`. Default commands end with `test jpegxl/FILE_test.v`;
no-GC adds `-gc none`, optimized adds `-prod`.

| Successful job | Files | Sampled peak RSS, bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | ---: | --- |
| Vector kernels, default | 1 | 260,227,072 | 4.16 | 0 / 0 |
| Vector kernels, no GC | 1 | 253,116,416 | 3.32 | 0 / 0 |
| Plane-only default recovery | 1 | 319,782,912 | 4.88 | 0 / 0 |
| Plane + Hornuss + DCT2X2, no GC | 3 | 312,115,200 | 10.56 | 0 / 0 |
| Subblocks, default | 1 | 320,782,336 | 4.22 | 0 / 0 |
| Subblocks, no GC | 1 | 312,033,280 | 4.57 | 0 / 0 |
| LF, final default | 1 | 323,944,448 | 5.11 | 0 / 0 |
| LF, no GC | 1 | 316,751,872 | 4.72 | 0 / 0 |
| Four new files, optimized | 4 | 663,666,688 | 26.92 | 0 / 0 |

The initial three-file plane selection exited 1: every plane digest matched,
but the test's manually calculated total was 212,480 rather than 206,080 words.
Only that bookkeeping assertion changed; implementation and gold records did
not. Both unchanged Hornuss and DCT2X2 files passed in that selection, supplying
their retained focused default credit. Only the corrected plane-only job
receives plane pass credit, and no whole-batch pass is claimed for the initial
selection. An initial LF default pass preceded removal of one unused boolean
parameter from the two-point helper. Final LF checks use the final source.

Reference runs all exit zero. Their sampled RSS peaks are 17,743,872;
19,218,432; 16,187,392; and 32,407,552 bytes, with wall times 0.52, 1.02, 0.79
and 1.34 seconds. Short sampled runs can miss a process's peak. Concurrent
unrelated host jobs existed; these timings do not support performance claims.

The compiler remains V `0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
A 219-input sorted `path<TAB>SHA256<LF>` manifest covers all JPEG XL V files,
recursive test data, embedded dither data, browser JPEG XL fixtures, the corpus
checker and memory guard. Its SHA-256 is
`016f02570ee8abaeddc5735a1c62290a3230dd45fb80fd3037d3611ed85ea857`.
The final identity checks include content hashes and inode change times.

## Fifty-five-file checkpoint

Both complete selections run through the V corpus checker, which discovers the
whole `jpegxl` package. Outer commands use the environment above, the default
12 GiB guard and `--timeout 600`, then execute:

```sh
/Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
  run tools/check_translation_corpora.v \
  --suite jpegxl --gc boehm --compiler /Users/alex/code/v/v --jobs 1
```

The second selection replaces `--gc boehm` with `--gc none`. Each checker
launches its actual V tests under a separate 3 GiB inner guard. No compile-only
run or retained subset supplies full-checkpoint credit.

| Full checkpoint | Files passed | Test / inner guard / driver / outer guard exit | Outer sampled peak RSS, bytes | Outer seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 55 | 0 / 0 / 0 / 0 | 592,953,344 | 239.19 |
| No GC | 55 | 0 / 0 / 0 / 0 | 1,746,452,480 | 229.81 |

Inner guards peak at 335,003,648 and 1,493,942,272 bytes, with wall times 236.08
and 226.38 seconds. Both actual selections report 55 passed and 55 total.
The compiler hash and every one of the 219 selected content hashes/change
times were checked before, between and after these complete selections and
remained unchanged. The embedded dither table is included directly. This
completes the ten-slice continuation after the forty-five-file baseline and
resets JPEG XL cadence to **0/10**. Other broad suites and their ledgers were
not changed or rerun.

## Remaining work at the checkpoint

Large inverse DCTs, AFV inverse transforms, HF entropy decoding,
LF/global/frame assembly, XYB/transfer conversion, frame dependencies and
production integration remain. Complete-file V output retains its preceding
bounded lossless subset. Production Rust decoding, Cargo manifests/build hooks,
CI toolchain steps and the native JPEG XL developer tool remain until the V
decoder preserves the supported static 8-bit sRGB/gray behavior and limits.
No production-browser validation is claimed for these standalone stages.
Feature commits request the shared managed production rebuild; no duplicate
manual build was queued or awaited. Unrelated suites and historical ledgers
were not changed or rerun. Temporary reference inputs, sources, binaries,
logs, locks and guard receipts were removed after recording this report.

## Large DCT and AFV continuation

Two subsequent focused commits complete inverse-transform coverage:

| Slice | Commit |
| --- | --- |
| 64/128/256-point kernels and all nine large DCT geometries | `1478c03b8` |
| All four AFV orientations | `6976a9242` |

All **27** transform kinds now reconstruct from typed LF/HF coefficient input.
Ordinary DCT output reaches 256x256. This does not decode frame entropy or enable
production complete-file VarDCT output. The two new files add **2,486** source
records and **1,220,608** exact output words, bringing the package to **278,895**
records and **57** test files. JPEG XL cadence is **2/10** after the fifty-five-file
checkpoint; no newer full-package checkpoint is claimed.

The original `idct_large.rs` is byte-verified against the same pinned archive;
its SHA-256 is
`8cd6d49703f56265443abaa2430dd43fac4266589551fa9d341a0609786af600`.
AFV translates the previously pinned `transform.rs`, source SHA-256
`477937cc290c4d078cdbe15ef41cce55ff71eed725f3cf033cdded143d062af5`.
The large oracle includes the original constants and recursive vector routine
unchanged, and imports the original 32-point kernel. Cached native public
functions produce the plane and complete-transform expectations. AFV calls the
original cached `transform_to_pixels_impl` directly. Cached artifacts and archive
pins remain those above. No Cargo rebuild, network access or candidate-generated
expectation is involved. Reference checks run under the same 3 GiB guards.

| Reference | Records | Complete output words |
| --- | ---: | ---: |
| Large vector kernels | 384 | 57,344 |
| Nine large plane geometries | 27 | 516,096 |
| Nine complete large LF/HF transforms | 27 | 516,096 |
| Four complete AFV orientations | 2,048 | 131,072 |

Large kernels retain recursive even/odd splitting, reverse prefix sums, exact
Wang-Chen weights and fused output combination. Disjoint scratch slices borrow
their allocation throughout recursion; the public input remains unchanged.
Positive/negative impulses, signed zeros, subnormals and dense finite vectors
compare bit-for-bit. Plane and complete-transform records cover every large
orientation, with complete LF injection and spatial placement compared separately.
AFV retains the complete 256-value basis, deliberately unfused dot-product order,
three DC constructions, corner flips and both constituent DCT placements. Every
coefficient impulse and all four orientations occur in its reference cohort.
All hashes serialize every output f32 word little endian, without tolerances.

| Oracle / frozen corpus | SHA-256 |
| --- | --- |
| Large oracle source | `93d2433d45888221337cad4fa18edd47036abdeb0d3f00bda48041c19b8c6d6b` |
| AFV oracle source | `bbecd2046dbdeb3b3efdee07c666b62cfc7088ecb48ea44a9d2a26a55d5bcceb` |
| `inverse-dct-large.tsv` | `0389dad607407fa8860bcacb86be961b90ec2f80b73c3402a92acbd67b907353` |
| `inverse-afv.tsv` | `784f77de0a6daecce14cb3950f6de5f3df27579f86a59a181dfed2b78f195f91` |

The large and AFV reference runs peak at 44,187,648 and 19,103,744 sampled RSS
bytes and take 1.47 and 0.72 seconds. Both actual source runs and guards exit zero.
Focused V checks use the environment, compiler flags and guard described above:

| Successful job | Files | Sampled peak RSS, bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | ---: | --- |
| Large + vector + plane + LF, initial default | 4 | 325,271,552 | 14.57 | 0 / 0 |
| Same selection, initial no GC | 4 | 317,177,856 | 15.09 | 0 / 0 |
| Large, final default | 1 | 325,353,472 | 5.50 | 0 / 0 |
| Large, final no GC | 1 | 316,653,568 | 5.33 | 0 / 0 |
| AFV + Hornuss, default | 2 | 324,567,040 | 7.69 | 0 / 0 |
| AFV + Hornuss, no GC | 2 | 317,849,600 | 7.91 | 0 / 0 |
| Large + AFV + Hornuss, optimized | 3 | 800,784,384 | 30.07 | 0 / 0 |

The initial four-file large selections passed before an implicit scratch-slice
copy was replaced with an explicit disjoint borrow. The corrected source is
covered by the final large-only checks and optimized selection; unchanged
vector/plane/LF regression credit is retained. No gold data changed. All actual
tests and guards exit zero. These are correctness checks, not performance or
allocation-limit claims. Concurrent unrelated host work existed.

V and its executable hash remain unchanged. A final **225-input** sorted
`path<TAB>SHA256<LF>` manifest, with the same recursive source/data categories,
has SHA-256
`3795c63cdf8d2088e1a352a0a48022fb45c950be8e7b10f58eefa3a829fffd71`.
All content hashes and change times, and the compiler hash, remain unchanged
before the final AFV no-GC check and after optimized validation. Temporary
oracle sources, binaries, input files, locks and guard receipts were removed
after recording these results.

HF entropy decoding, LF/global/frame assembly, XYB/transfer conversion, frame
dependencies and production integration remain. The Rust decoder, Cargo/CI
hooks and native JPEG XL developer tool remain until the V path preserves the
production behavior and limits. The shared managed build hook runs on each
commit; no separate manual production build or browser validation is claimed.
