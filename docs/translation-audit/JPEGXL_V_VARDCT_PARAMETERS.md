# JPEG XL V VarDCT parameters and orders, 2026-11-09

This report retains the initial four-slice results. The LF continuation below
records six later slices and their forty-five-file checkpoint.

Four additional slices execute in pure V:

| Slice | Implementation commit |
| --- | --- |
| Quantizer parameters and inverse scales | `91f7da0ef` |
| Color-correlation parameters and factors | `e20d33856` |
| Block maps and coefficient entropy contexts | `5a44b2ad9` |
| Natural and entropy-coded coefficient orders | `32c901c97` |

Focused checks pass in both GC modes and with optimization. JPEG XL cadence is
**4/10** after the preceding full thirty-five-file checkpoint. The corpus
checker discovers thirty-nine files; this continuation does not claim a new
full-package checkpoint. Production JPEG XL still uses Rust.

## Source and comparison boundary

The pinned `jxl` 0.7.0 archive SHA-256 remains
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Quantizer, color-correlation, block-context, coefficient-order and half-float
source files were verified byte-for-byte against that archive. Quantizer and
color references invoke the existing cached crate. Block and coefficient
oracles include the original source files unchanged with cached dependencies,
module reexports, constants and an inert logging macro. Natural orders use the
original transform-type LUT. Its `jxl_transforms` 0.7.0 source was verified
against archive SHA-256
`55b9b6a075a5554b5625828c322975372897be79b347d2795de721d27a2ed2b0`.

The temporary migration oracles linked existing cached artifacts directly;
there was no Cargo rebuild, network access or V-generated expectation. Their
SHA-256 identities were:

| Oracle source | SHA-256 |
| --- | --- |
| Parameters | `de5a96e582d715b247ed8585e1d423a5d6ad68c9a28bbd43c808a548715be1a4` |
| Block contexts | `9f53cf6efe558f33a049c19933a24e5a2ae92d08904f71cfd0347eb871e1e80d` |
| Coefficient orders | `cd4c404276bf682706871c42851ee0c3975451d727e6039519474888ce88d8ac` |

Cached `libjxl-0f4870c888fc4600.rlib` SHA-256 was
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`;
`libjxl_transforms-a858b76184796a88.rlib` was
`e1f0257f34d0017dd69860476cb6bee832e0e8952886326d7094b439ce7a6803`.
Frozen developer checks execute with V alone. Temporary oracle files and job
output were removed after recording this report.

| Frozen corpus | Cases | Successful source results |
| --- | ---: | ---: |
| Quantizer parameters | 4,096 | 4,096 |
| Color-correlation parameters | 4,096 | 2,525 |
| Block-context transcripts | 512 | 375 |
| Zero-density contexts | 8,192 | 8,192 |
| Complete natural coefficient vectors | 13 | 13 |
| Complete entropy coefficient orders | 256 | 153 |

These add **17,165** source cases, bringing the package to **257,783**. Each
map/query transcript or complete order result counts once, consistent with
earlier whole-plane/row/transcript counts.

Quantizer cases cover every selector pair, endpoint payloads and random words;
inverse global and LF scales compare exact binary32 words. Color cases compare
both base values, LF factors, arbitrary signed factors, output float words and
consumed bits. Signed zeros, source subnormal behavior, finite/range rejection
and consuming both half fields before validation are retained. The shared half
conversion still matches the preceding exhaustive primitive corpus.

Block transcripts compare every threshold, every map entry, context counts,
all thirteen shapes and three channels at sampled LF indices, QF threshold
equality/next values, all nonzero buckets and density offsets. LF threshold
selector 3 retains the source's wrapping cast after adding 65,808. Corpus
errors include oversized maps, holes, excessive distinct contexts and EOF.
Zero-density coverage includes all 7,938 normalized coordinate/previous-bit
combinations, plus 254 scaled cases through the largest 32-by-32-block order.
V rejects invalid public indices, storage and normalization coordinates.

Natural vectors compare all **131,328** source indices across the thirteen
shapes. Decoding compares SHA-256 over all 39 component vectors, each prefixed
by its u32 length, with every word serialized little endian. The source process
streams original words into Python's SHA-256; no candidate output participates.
There are 113 accepted non-natural results and 111 distinct accepted digests.
Coverage includes simple prefix permutations, valid/invalid ANS checksums,
accepted LZ77 headers, high mask bits, zero masks, malformed headers and byte
prefixes. Component arrays are independently owned. V computes natural orders
per invocation rather than sharing the source's lazy global cache; no memory
or performance parity is claimed for that ownership choice.

One block record and sixty coefficient records overread EOF in the cached
source. Their rejection results are compared, but their beyond-input cursors
are excluded from position equality because V's checked reads can stop earlier.
All remaining cursor values compare exactly. This preserves the previously
documented checked-reader boundary rather than claiming source EOF cursor parity.

Corpus SHA-256 values:

| File under `jpegxl/testdata/` | SHA-256 |
| --- | --- |
| `quantizer.tsv` | `d4dde011000c90a6a6858172dd44587a90b2b0b5efa02393b9e8265b63778aec` |
| `color-correlation.tsv` | `5f2cb355f4be62d37e307ab685e0c37f779e979372cb92b725d895ac1f1b38de` |
| `block-context.tsv` | `3f880ee3f69007d88a088270a83f8a54cdae1e4c135480d821dc8107631890b9` |
| `zero-density.tsv` | `d8fc396235c627b2d4d87f24759ef1e2339488d870c3f98933f764f4fa6d50ad` |
| `natural-coefficient-orders.tsv` | `4807eb90ea548578f83f01ceea1e9171b0672ebd90cb894e9289a430ac9f857b` |
| `coefficient-orders.tsv` | `fc1b82ef26a7d90704a662f583aec25db0be3ed155d05de1f6e383b1514f3e2d` |

## Executed checks

Every test command uses current V with `-memory-limit 10G -b c -cc clang`,
`V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`, `RUSTC=/unavailable/rustc` and
`RUST_CARGO=/unavailable/cargo`. Separate default/no-GC jobs execute the four
focused files. Color's half-helper extraction also checks
`primitives_corpus_test.v` and `bit_reader_test.v` in both modes. All expensive
commands use `tools/run_memory_bounded.py` with unique locks/reports, a 3 GiB
process-tree budget and a 180-second timeout.

| Successful job | Files | Sampled RSS peak, bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | ---: | --- |
| Quantizer, default | 1 | 272,285,696 | 3.52 | 0 / 0 |
| Quantizer, no GC | 1 | 262,324,224 | 3.49 | 0 / 0 |
| Color, default recovery | 1 | 271,974,400 | 3.35 | 0 / 0 |
| Color and half readers, no GC | 3 | 265,535,488 | 7.82 | 0 / 0 |
| Block contexts, default | 1 | 281,968,640 | 3.49 | 0 / 0 |
| Block contexts, no GC | 1 | 273,104,896 | 3.52 | 0 / 0 |
| Coefficient orders, default | 1 | 321,683,456 | 44.54 | 0 / 0 |
| Coefficient orders, no GC | 1 | 1,495,875,584 | 38.76 | 0 / 0 |
| All four focused files, `-prod` | 4 | 535,724,032 | 32.36 | 0 / 0 |

The first color selection failed to compile its test's unsupported `u64.bytes()`
helper. Both unchanged primitive/bit-reader files passed in that selection;
their default-mode credit is retained alongside the corrected color-only pass.
The test now uses literal encoded bytes. The failed whole selection earns no
whole-batch pass credit. Source results and implementation semantics did not
change to obtain a pass.

An initial block oracle input generator assumed 64 large-alphabet reference
rows existed; it stopped before writing an oracle, and the following compile
exited 1. The corrected generator reused existing cases with maximum symbols
7 and 255. Its first reference run then exited 101 because its wrapper
asserted source cursors could never overread EOF. Removing that wrapper
assertion retained the original source, including the overread rejection.
Only the complete 512-record final source run receives reference credit.

The compiler is `V 0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
A 168-input manifest covers JPEG XL V files and test data, browser JPEG XL
fixtures, corpus checker and memory guard. Its sorted
`path<TAB>SHA256<LF>` SHA-256 is
`8868519ada4a03e523c0dd4bb0bf26e391114013403b405afa6f64d7e253eec6`.
The compiler and all selected inputs were checked before the final no-GC job,
between it and optimized validation, and after optimized validation. All
identities remained unchanged. Other broad suites and historical ledgers were
not changed or rerun.

For example, the optimized command under the shared environment above is:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/pure-v-jpegxl-vardct-20261109-09/vardct-optimized.lock \
  --report Build/pure-v-jpegxl-vardct-20261109-09/vardct-optimized.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang -prod test \
  jpegxl/quantizer_test.v jpegxl/color_correlation_test.v \
  jpegxl/block_context_map_test.v jpegxl/coefficient_order_test.v
```

Default/no-GC commands select the relevant focused file, omit `-prod`, and add
`-gc none` for ownership checks. The no-GC color command additionally selects
the two half-reader files named above. Temporary job locks/reports were released
and removed after these checks. Each focused implementation commit requested
the managed, coalesced production rebuild; no separate browser build was queued.
Standalone codec tests supply this validation, without a production-browser
execution claim.

## Dependency work after the initial four slices

VarDCT coefficient reconstruction and transforms, quantization matrices,
VarDCT EPF sigma generation, XYB/transfer conversion, frame dependencies and
rendering pipeline assembly remain. The complete-file V APIs keep their
existing bounded lossless subset. Broader partial/streaming rendering and
production integration remain open.

The tracked Rust source/manifests are still under `native_jpegxl_rust/`.
`images/jpegxl.v` calls the native decoder, `build-prod-browser.sh` builds its
Cargo helper, `tools/test_jpegxl.py` rebuilds that helper for native testing,
and CI still checks the Rust toolchain. Those dependencies must be removed
together after V preserves the production static 8-bit sRGB/gray contract.

## LF continuation and non-raw quantization headers

Six more slices follow the initial 4/10 continuation:

| Slice | Commit | Source cases |
| --- | --- | ---: |
| Twenty-seven transform mappings | `609362130` | 258 |
| Adaptive LF smoothing | `8f2a074a9` | 512 |
| VarDCT EPF sigma maps | `16e446290` | 512 |
| DCT distance-band parameters | `8e4d3e6a7` | 4,096 |
| LF dequantization, sampling and context planes | `161049e7d` | 512 |
| Non-raw quantization encodings | `22b090115` | 4,096 |

The **9,986** additional cases bring the package to **267,769** and forty-five
test files. Each complete plane, transcript or encoding counts once, as before.
All forty-five test files pass in both GC modes, completing the ten-slice
checkpoint and resetting JPEG XL cadence to **0/10**.

### Source boundary

The archive pins above remain unchanged. Adaptive LF smoothing, EPF sigma,
quantization weights, half conversion, modular LF reconstruction and transform
mapping source were verified byte-for-byte against their cached source
archives. Cached `jxl`/`jxl_transforms` artifact hashes still match the identities
recorded above. The temporary reference programs use Rust 1.97.1 with those
cached dependencies directly; they do not build with Cargo or supply a lasting
developer-tool dependency.

Transform references call the original twenty-seven-value enum, geometry and
shape functions, plus the unchanged private quantization-table enum/mapping
extracted from `quant_weights.rs`. Every valid mapping and IDs -2 through 255
are checked. Invalid signed IDs are rejected at the V API boundary.

LF smoothing references execute the unchanged source constants,
`compute_pixel_channel` helper and original scalar interior calculation, with
cached Image rows. The wrapper supplies outer-border copies and whole-plane
iteration. It does not test the source's parallel runner or group scheduler.
All **328,098** output words match, including signed zeros, shared per-pixel
channel gaps, varied positive LF scales, impulses, high contrast and constant
planes. There are sixteen planes wider than 256 blocks, including one 257-by-257
plane. V preserves scalar unfused rounding with separate operations; smoothing
is independent of its invocation's tiling and leaves outer borders unchanged.

Sigma references include the original `features/epf.rs` unchanged. Thin metadata
adapters supply the fields read by that source constructor; cached Image,
QuantizerParams, transform lookup and Arc implementations remain in use. All
twenty-seven transforms occur in complete, nonoverlapping maps. The **28,581**
visible inverse-sigma words match, including 674 negative zeros, finite custom
scales/LUTs, ignored follower-block values and the `inf * 0` minimum-cutoff case.
V excludes the source's two unused SIMD padding columns. It additionally rejects
invalid public storage, anchor quantization, sharpness indices, overlap, holes
and out-of-bounds coverage; malformed-map acceptance parity is not claimed.

DCT-band references execute the original parameter struct and implementation.
There are **1,163** accepted records and **2,933** source rejections, comparing
every parameter and cursor. Row-zero validation follows reading the whole row,
then the initial weight is multiplied by 64. Quantization uses `util::f16`,
which retains infinities and quiet NaNs; 656 accepted records contain NaNs.
Finite/Inf words compare exactly, while NaN payloads compare by class. Ordinary
metadata's finite-only half reader keeps its separate rejection behavior.
Parsing these values does not establish that a later weight matrix is valid.

LF reconstruction references execute the unchanged generic `dequant_lf_impl`
from `frame/modular/mod.rs`, source SHA-256
`8c1e521cd0343d6d55b6f7d8f203c3c5655d5a98eb0229a501b7424f03bab853`.
The wrapper provides typed output buffers and sampling/context metadata; source
ImageRect, integer conversions, quantizer and color-correlation types are used.
The cohort has 256 i16 and 256 i32 groups, including 109 with 4:4:4 and 403 with
subsampling. Every one of **60,716** float words and **35,781** LF context indices
matches. Encoded Y/X/B channel order, precision shifts, strict threshold
comparisons and X/B/Y bucket strides are retained. The source divides by the
rounded product of global scale and LF quantization here; its general inverse
LF helper instead performs two divisions. Color correlation is unfused and
applies only to 4:4:4. V checks aligned geometry, metadata bounds and complete
source planes before allocating output.

Non-raw encoding references execute the original enum and decoder for modes
0–6. Raw-mode dependencies are inert stubs and guarded against execution;
mode 7 is excluded from source comparisons and rejected by the bounded V API.
All seventeen table dimensions, complete weights/parameters and consumed bits
match. Accepted counts are 586 library, 481 identity, 475 DCT2, 89 DCT4, 88
DCT4x8, 20 AFV and 106 DCT; **2,251** records reject. There are no source cursor
overreads. Source per-mode size restrictions, multiplier checks, AFV's first six
scaled weights and both AFV band sets are preserved. These are encoding records,
not generated or validated dequantization matrices.

Final oracle and frozen corpus identities:

| Oracle | SHA-256 |
| --- | --- |
| Transform mappings | `82273fb6e103752e4c69cbe911b99c4701ffb0ea45eefdfe55975ee225b0efda` |
| LF smoothing | `0b1f57bb7bfa832e63c0ae351172e70b7db1f9db88f4cf462cf284bc5fab9639` |
| EPF sigma | `a4daaba9573e2766a15e349fad61b900eef3c378c48b0fe26b6f389e4531b9aa` |
| DCT bands | `ddf23805b31093f86a31af95ecea6631da4b3a55c4288c5e62d10e75766b6baf` |
| LF reconstruction | `92262cc645e66e53ea169f79898d5800af33c443989c23e7d331dadf7479912a` |
| Non-raw encodings | `03817ffb0828d262013f59d3a7565c05271e3c9177a852161e8302eb60746301` |

| File under `jpegxl/testdata/` | SHA-256 |
| --- | --- |
| `hf-transform.tsv` | `49dfce5be45602665479c868204b8ed5ef18a9015fd8463b8ae1f3d5a6a29183` |
| `lf-smoothing.tsv` | `89bbffab2b4e90ac9e8c12e90cee844d03af3cc94f952a33762a2dc2e266a951` |
| `epf-sigma.tsv` | `91156d4e216343a193acf6ec664f9d3d0ab20d18db4ecb9f1de050fd0896b33f` |
| `quant-bands.tsv` | `01bf27e31b59fe6542aba1678a44a5c09670c8763718c673c79471ec2d58113c` |
| `vardct-lf.tsv` | `5db7664ddf0790af1df9e3fa093a3cdd30f6d6891cf6fad2d3b908752ade0e4a` |
| `quant-encoding.tsv` | `0e03e256bf419616759f83c88d6d5ab47cc3815fb012ac7de49e1fe922719b5e` |

### LF validation

The six new focused files pass in default GC and no GC. Optimized evidence is
the unchanged five-file LF selection followed by the additional encoding file.
All actual tests and guards exit zero. Each uses the environment and 3 GiB
memory guard described above, with unavailable Rust compiler paths and current
V's C/Clang backend. The complete checkpoint is selected through the V corpus
checker, not a list that can silently omit new files.

| Focused default / no-GC job | Default RSS peak, bytes | No-GC RSS peak, bytes |
| --- | ---: | ---: |
| Transform mapping | 249,544,704 | 232,357,888 |
| LF smoothing | 276,365,312 | 268,288,000 |
| EPF sigma | 254,459,904 | 249,151,488 |
| DCT bands | 276,611,072 | 267,747,328 |
| LF reconstruction | 276,561,920 | 271,695,872 |
| Non-raw encoding | 328,810,496 | 333,070,336 |

The optimized five-file job peaks at 637,992,960 bytes and takes 39.00 seconds;
the encoding-only job peaks at 455,163,904 bytes and takes 9.07 seconds. These
are guarded test measurements, not performance comparisons or browser builds.

| Full checkpoint | Files passed | Test / inner guard / driver / outer guard exit | Outer sampled RSS peak, bytes | Outer seconds |
| --- | ---: | --- | ---: | ---: |
| Boehm | 45 | 0 / 0 / 0 / 0 | 590,086,144 | 216.88 |
| No GC | 45 | 0 / 0 / 0 / 0 | 1,750,450,176 | 165.58 |

Inner guards peak at 332,169,216 and 1,494,237,184 bytes, taking 213.14 and
162.18 seconds. Both complete selections report 45 passed and 45 total; no
compile-only result or retained subset supplies full-checkpoint credit.

The compiler remains `V 0.5.2 a3892ac`, SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
The intermediate 183-input manifest before the final LF no-GC and optimized
five-file checks is
`1de71a0ddda82fd5843949538317b494037af3ef8551d57994298449d08010d0`;
those identities stayed unchanged. Adding encoding source, test and corpus
produces a 186-input checkpoint manifest:
`dd2c93dbb1b5787c333430d2e302c09f27ce043a4432170c85d4b206b190ebd7`.
It covers the same path categories as the preceding manifests.
All 186 selected files and the compiler were checked before, between and after
the complete selections and remained unchanged. The manifest excludes
`jpegxl/data/dither_32x32.bin`; that embedded input is verified separately
against its pinned source hash and Git bytes:
`6247b14297fdc698d699d1e1fa2331e4da69215d852e2493af27009b9effc93e`.
Its inode change time, 1794192268030376430 ns since the epoch, predates both
full-run logs and is unchanged after the no-GC run. This separate identity
check is not represented as an entry in the 186-file manifest.

The first smoothing oracle compile exited 1 because cached output-row methods
are private and FrameHeader has no public default constructor. Its replacement
uses the original scalar helper/interior excerpt with a whole-plane wrapper;
no candidate output or expected result changed. A later receipt collector tried
to read a running job's empty JSON report and exited 1; receipt collection was
deferred until completion. No test pass was credited from that failed collector.
The encoding oracle was extended before V comparisons to include all seventeen
source table dimensions; both reference runs exited zero. All frozen candidate
comparisons passed on their first run.

The full checkpoint commands use the shared environment above and separate
outer 3 GiB guards with 900-second timeouts:

```sh
/Users/alex/code/v/v -memory-limit 10G -b c -cc clang run \
  tools/check_translation_corpora.v --suite jpegxl --gc boehm \
  --compiler /Users/alex/code/v/v --jobs 1
# The second command replaces boehm with none after the first job completes.
```

The checker creates its own 3 GiB inner guard and reports its actual test exit;
outer logs retain both guard receipts while the job runs. Every implementation
commit requests the shared coalesced production rebuild. No manual browser build
or production-browser validation is claimed. Unrelated broad suites and
LibJS/DOM/performance ledgers remain unchanged.

All temporary oracle inputs, programs, logs, lock files and guard receipts were
removed after their final exits and this report were recorded. No frozen result
was changed to obtain a passing candidate comparison.

LF global/entropy assembly, raw quantization streams and matrix generation,
HF entropy coefficients/inverse transforms, frame dependencies, XYB/transfer
conversion and rendering pipeline integration remain. Complete-file V APIs keep
their existing lossless limits. The production Rust JPEG XL helper and its
Cargo/CI/native developer tests remain until the complete supported contract
can be preserved by V.
