# JPEG XL HF entropy, group reconstruction and sRGB output

Eight pure V slices continue the Rust-dependency removal on 2026-11-09. They
add **2,658 independent source records**, bringing the package to **281,553
records and 65 test files**. Production still uses the Rust decoder. These
standalone stages do not establish complete-file VarDCT or browser parity.

| Slice | Commit |
| --- | --- |
| Actual entropy-coded HF channels and progressive accumulation | `201c3ebe4` |
| HFGlobal pass orders, histograms, padding and coefficient width | `58d8d4439` |
| Per-pass/component nonzero prediction maps | `e6beda7b8` |
| Progressive HF group entropy decoding | `a91ea4dfe` |
| HF group pixel reconstruction and subsampled placement | `06aa06adf` |
| XYB to linear RGB | `fb4ec236d` |
| Forward/inverse sRGB transfer | `73c70d269` |
| sRGB/gray output matrix preparation | `4c26e0e8f` |

## Independent references and boundaries

The reference remains `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Original files were byte-verified against that cached archive. Temporary
migration programs use those original functions and cached compiled artifacts;
they never derive expected values from the candidate V implementation. No Cargo
rebuild or network access was used. Frozen developer checks require V alone.

| Original source | SHA-256 |
| --- | --- |
| `frame/group.rs` | `086c0f63f09e4d1d41d4681dc8068c45aca9190f4f41c2f6b43eaa130de6b2a0` |
| `frame/block_context_map.rs` | `cf00ddfb302bdc7d7b57b7a9700b58a7d652e36150874e6e27e1c270050718dc` |
| `frame/decode.rs` | `7c6964276f01b6d8d56661f0357c39bac8097ada88332eeaabfb02b169c4c0e0` |
| `frame/coeff_order.rs` | `92c894de6fa86444ac41b9a549e34feff2b4a477b9ae1619fedebe236abdace6` |
| `headers/permutation.rs` | `b80c880161d6d44a4459ece643a5f734e9447432cec3df7b664b42a417f93d9a` |
| `entropy_coding/decode.rs` | `ff3696293c449ba15074ed0c815ef140d4cc6e85ee7bc0b3c2b1034b943d0b6b` |
| `render/stages/xyb.rs` | `310bf8353968251a2205450e3cedb622d413c148ddba5aaeea6b92d6f9b23fd0` |
| `color/tf.rs` | `55799c01b3ade33f0c35fb7ac600e041befdacfbb88be70e064f281fef25e2e1` |
| `util/rational_poly.rs` | `c6a7d0a1ff01dfaf92a871624d04bfd3e07e353365627777c23c08cecbc3007c` |
| `util/linalg.rs` | `031000c46622182a2ea170fbbefa75dc5b86c052a2986e321fe389feb15f7d39` |
| `api/color.rs` | `706491d983a21cf5b63f28dcf20f5495439b52e1ed08aafedb75f7be5ec3d5fa` |

The cached `jxl`, `jxl_transforms` and `jxl_simd` artifact SHA-256 values are,
respectively, `06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`,
`e1f0257f34d0017dd69860476cb6bee832e0e8952886326d7094b439ce7a6803` and
`8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9`.
The transform crate pin is
`55b9b6a075a5554b5625828c322975372897be79b347d2795de721d27a2ed2b0`.
Reference compilation uses cached dependencies, Rust 1.97.1, edition 2024 and
release-style `-C overflow-checks=off`, under separate 3 GiB guards.

| Frozen file | Records | Compared transcript words | SHA-256 |
| --- | ---: | ---: | --- |
| `hf-channels.tsv` | 1,152 | 803,328 | `07c3711c976642d8ca91dc08cee29623aa17a385a06ecc44463e2c67b41ed7f2` |
| `hf-passes.tsv` | 66 | 53,916,553 | `85cfbcc7e57574c3f139d329583db37e3f495dfacd4864b92ee668a65b767b06` |
| `hf-nonzeros.tsv` | 512 | 6,468,090 | `e4d5bc164f5f56ba45841a3d34f539eaca3927687a174ba0d03c6e61aecf5f0a` |
| `hf-groups.tsv` | 96 | 9,357,424 | `87c5064a30fdfc2ae6f05c8d86334fae647bab8844e1b67b60b9872ffeca59d8` |
| `hf-render.tsv` | 64 | 1,813,760 | `412d02dc9677199c02ceef6bc81fa2f7ac34f0ba65756c6c309b1864028d1df3` |
| `xyb.tsv` | 128 | 100,352 | `961565e5eea88f5c97ec2c6b184a19fee43bde36952d897fd6f4d0dc514cd965` |
| `srgb-transfer.tsv` | 512 | 131,072 | `1e1a848a89ad88540d16989301a9fec8847483e284e667b4f89f399d83de1607` |
| `srgb-output.tsv` | 128 | 2,176 | `5836e61e753dbca145044ebce30bf67ef10c88ebfa83474e9a77c3dbb6d68f83` |

These **72,592,755** words include repeated full state, map/order snapshots,
dimensions and cursors; they are not that many unique decoded coefficients or
pixels. Float and integer buffer hashes cover every little-endian 32-bit word,
without tolerances. Error categories are normalized; error strings are not an
equality claim.

HF channels use the original coefficient loop and storage arithmetic with real
`Histograms`, `SymbolReader` and `Permutation` types. Cases span all 27 shapes,
both storage widths, reordered permutations, prior nonzero coefficients,
Huffman/ANS/LZ77-enabled streams and shifts through 31. Frame shifts remain
limited to the actual two-bit range 0..3. The source cohort has 921 successes,
185 residual-nonzero errors, one parse error and 45 final-entropy errors. Two
source cursors run beyond input; those two cursor equalities are excluded, while
their statuses and entire partially updated buffers still match. All other
channel cursors compare exactly. Histograms are padded to each test channel's
required context extent; these isolated packets do not claim HFGlobal framing.

HF pass references include the original post-matrix portion of
`decode_hf_global`, original coefficient-order and block-context modules, and
cached entropy types. Adapters supply typed group/pass/shift counts. All 39
orders, histogram properties, complete context maps including the global
16-entry padding and single-symbol queries are serialized. There are 34
accepted cases (18 signed16/16 signed32) and 32 rejected prefixes. Natural and
non-natural orders, actual entropy-coded permutations, all four order selectors,
11 passes, LZ-enabled headers and the strict 16-bit storage boundary occur.
Pass histograms in this cohort use Huffman; order streams also exercise ANS/LZ.
Histogram-set counts may exceed non-power-of-two group counts as in the source.
All pass cursors compare exactly. Dequant matrices and frame allocation are
outside this parsing boundary. The current entropy context budget still requires
`sets * block_contexts * 495 + 16 <= 65536`; larger source-supported maps remain
outside the bounded V subset.

Nonzero-map references use the original neighbor predictor and rectangle-update
loop with actual image storage. Each of 512 transcripts performs 64 operations,
covering every transform, ceiling division, all borders and u32 wraparound.
Only visible samples are serialized, with no source image-padding/layout claim.

Group entropy references retain the complete original `decode_vardct_group`,
coefficient storage, pass initialization and channel decoder. Only its final
rendering callee is replaced by a coefficient observer. There are 89 successful
records, six decode errors and one global-header error; 64 use signed16 and 31
signed32. Every transform, all four normalized chroma sampling modes, histogram
selection, LF/QF contexts, channel order `[1,0,2]`, partial/empty pass lists and
11-pass signed16 wraparound occur. Typed adapters supply normalized sampling;
this does not retest frame-header bitstream interpretation. LZ-enabled group
streams take literals, so group-level LZ copy coverage is not claimed. Source
errors in this cohort occur before decoding or during final validation; the
observer does not establish partial-current-block error-buffer parity. All
group cursor words, including two beyond-input EOF cursors, remain inside the
exact output hash. Single-pass scratch is cleared per block; progressive
buffers preserve previous pass values. V stores the active group prefix rather
than the source's fixed-capacity cache.

Rendering references retain the complete source group decoder and actual
dequantization/transform dispatch. A helper seeds its progressive coefficient
cache; the supplied pass list is empty. Inputs supply positive synthetic matrix
weights through a typed lookup adapter using the original transform-to-table
mapping. Existing independent matrix tests cover library/custom matrix generation.
All output samples in the local component planes compare exactly, across all
27 transform kinds, mixed transform layouts, 64px color tiles, all sampling
modes, LF injection, matrix scaling and both storage widths. This cohort has
1,813,376 actual pixel-component words plus 384 geometry words. It is a supplied-
coefficient rendering check, not an end-to-end compressed image test. Full-frame
LF-group placement, restoration and frame composition remain separate.

XYB references retain original parameter construction and SIMD processing.
The 128 cases compare all 16 prepared parameter words and 98,304 RGB words,
including default/custom matrices, signed-zero/subnormal samples, positive and
negative half-representable biases and varied intensity targets. V uses its
pure V binary64 cube root rounded to f32; every recorded source f32 cube root
and output matches exactly. This is not exhaustive parity with every platform's
`cbrtf`. Fused inverse-gamma and matrix operations use the existing V f32 helper.

Transfer references call cached source SIMD functions in both directions.
They compare 131,072 samples, signed zeros, subnormals, dense signed values and
adjacent words around both strict SIMD thresholds. V retains the rational
approximation and fused Horner evaluation, with no output clamp. This matches
the SIMD renderer rather than the source's differently rounded scalar helper.
Output matrix references call cached `OutputColorInfo::from_header`: 128 RGB,
gray and XYB cases compare all opsin/bias words and intensity. Gray premultiplies
the matrix using the source's f64 summation and f32 luminances. XYB requires
perceptual intent. ICC, HDR, other transfer curves and wide-gamut preparation
remain rejected by this bounded output API.

| Temporary oracle source | SHA-256 |
| --- | --- |
| Channels | `214f72dc82c119597767ca8f771da9435ea0b9413a24f1cf3e0ea0978b229edc` |
| Passes | `13d5442eb7b6cc8da62ea8a0b442a8f517794baeebce4f2365dae343badda6b6` |
| Nonzero maps | `a6453e89805e9076a827c63f8d931567887103522fc00f393c09e4beff2609bb` |
| Group entropy | `8101e215ad8b5302150d974c3cdf96aa3902df507395c7d37f4b36f1a308d714` |
| Group rendering | `3191fcc4ece6f23598faef6c8abd2b7ef1d0aefd0d156664bfe2f13dd48621d8` |
| XYB | `6e2362cb6724501147084167811be84e58b65b424b64c7ebdc38cfe84dc3685e` |
| Transfer | `331c9ea51f56beed8fe0dea128f8bb077b19f88fc9e97ec1483a474b15e5e86f` |
| Output color | `04b9d78282f90e26ff616b00f71645b222c1c39bd6df03baef7e3a47d5c6d309` |

## Verification

V is `0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
Tests run from the canonical checkout with `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo`, V flags
`-memory-limit 10G -b c -cc clang`, optional `-gc none`/`-prod`, and unique
memory-guard locks and reports. Each focused guard has a 3 GiB budget. These are
sampled process-tree RSS observations, not kernel allocation limits or performance
claims; unrelated host work was running.

| Successful focused selection | Peak RSS bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | --- |
| Channels, default | 327,188,480 | 5.149 | 0 / 0 |
| Channels, no GC | 320,274,432 | 5.628 | 0 / 0 |
| Passes + channels + block contexts, default | 328,794,112 | 26.004 | 0 / 0 |
| Same three files, no GC | 945,029,120 | 26.462 | 0 / 0 |
| Nonzero maps, default | 321,323,008 | 6.170 | 0 / 0 |
| Nonzero maps, no GC | 311,820,288 | 5.558 | 0 / 0 |
| Groups, corrected default | 334,446,592 | 9.278 | 0 / 0 |
| Groups, no GC | 723,238,912 | 8.399 | 0 / 0 |
| Rendering, default | 331,071,488 | 6.423 | 0 / 0 |
| Rendering, no GC | 421,199,872 | 6.999 | 0 / 0 |
| XYB, default | 321,601,536 | 5.590 | 0 / 0 |
| XYB, no GC | 315,162,624 | 3.928 | 0 / 0 |
| Transfer, default | 321,617,920 | 4.813 | 0 / 0 |
| Transfer, no GC | 314,146,816 | 4.487 | 0 / 0 |
| Output color, default | 263,733,248 | 3.240 | 0 / 0 |
| Output color, no GC | 254,853,120 | 3.022 | 0 / 0 |
| All eight new files, optimized | 1,618,657,280 | 69.016 | 0 / 0 |

Final source-reference runs all exit zero. Channel/pass/nonzero/group/render/XYB/
transfer/output-color guards peak at 97,288,192 / 296,337,408 / 20,709,376 /
52,396,032 / 97,271,808 / 17,137,664 / 21,856,256 / 18,153,472 bytes, respectively.
Their elapsed times are 11.148 / 3.403 / 0.704 / 6.750 / 3.434 / 0.588 / 0.503 /
0.502 seconds. All final oracle compiles also exit zero.

Harness failures remain part of the record: the first channel compile tried a
private module; the group harness had authoring/missing-file failures, private
sampling access, ambiguous `powf` receivers and moved mutable references.
Adapters/imports were corrected while original decoding arithmetic stayed
unchanged. The first V group test used a nonexistent helper name (exit 1,
147,390,464-byte peak, 5.484 seconds); its corrected test passes unchanged gold.
The rendering generator first searched for a public enum that is private. The
first XYB compile attempted a struct literal with a private field, then used the
source default constructor and public setters. The first output-color source run
panicked on a constructed XYB header with relative intent (source child 101,
wrapper/guard 1); the adapter now supplies required perceptual intent, which the
V API also enforces. Failed source attempts produced no authoritative frozen
cohort; none receives passing credit. No expected source result was overridden.

Full checks run serially through the V corpus checker, with its inner 3 GiB
guard and a default 12 GiB outer guard:

```sh
env V_MACOS_V3_NO_FALLBACK=1 VJOBS=1 \
  RUSTC=/unavailable/rustc RUST_CARGO=/unavailable/cargo \
  python3 tools/run_memory_bounded.py \
    --lock Build/JOB/full-MODE.lock --report Build/JOB/full-MODE.json \
    --timeout 1200 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
    run tools/check_translation_corpora.v --suite jpegxl \
    --compiler /Users/alex/code/v/v --gc MODE --jobs 1
```

Both full selections pass all **65 files**. The `boehm` tests and inner guard
exit zero, with 339,820,544-byte peak and 256.775 seconds; driver and outer guard
exit zero, with 596,492,288-byte peak and 259.482 seconds. The no-GC tests and
inner guard exit zero, with 1,496,350,720-byte peak and 285.782 seconds; driver
and outer guard exit zero, with 1,742,389,248-byte peak and 288.710 seconds.
This completes the ten slices after the fifty-five-file checkpoint and resets
JPEG XL cadence to **0/10** at the pre-correction state of `4c26e0e8f`.
Unrelated broad suites and historical ledgers were not changed or rerun.

The sorted **249-input** `path<TAB>SHA256<LF>` manifest has SHA-256
`cc04d5c9574a3c085b11b1ed025b5b87b6251ea8381f0f486c515c039af6f521`.
It includes all package V files, recursive test/data inputs (including grouped
fixtures and dither), all seven browser JPEG XL resources, the corpus checker
and memory guard. All content/change-time and compiler pins remain unchanged
through optimized checks and both full selections, authenticated before the
separate signed-zero correction below.

## Signed-zero correction after the checkpoint

A separate source diagnostic exposed Rust's negative-zero identity for floating
iterator summation. An all-negative-zero grayscale matrix produced negative-zero
columns in the source and positive-zero columns in V. Eight independently
generated matrix cases were appended without changing the original 128 records.
The new test failed at record 129 (test/guard 1, 252,018,688-byte peak, 2.769
seconds), then passed after starting the f64 accumulator at negative zero.
Commit `51698c410` contains the fix and regressions.

The resulting `srgb-output.tsv` has **136 cases**, SHA-256
`6ccdaed43b810b5ef0d002edeeea9581fa30c37b289748167f1dac5f3585bad8`.
The eight appended source records have SHA-256
`5a5db5f41d686e9361c98f4f26370c6c169a81d139836f355ed55a5a29fad3fc`;
their source/guard exits are zero (3,604,480-byte peak, 0.315 seconds).
This adds 136 exact transcript words and brings the package to **281,561
records**, still **65 files**. Cadence is **1/10** after the full checkpoint.

| Corrected output-color file | Peak RSS bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | --- |
| Default GC | 263,667,712 | 2.449 | 0 / 0 |
| No GC | 241,582,080 | 2.117 | 0 / 0 |
| Optimized | 319,586,304 | 4.967 | 0 / 0 |

Only the correction's implementation, test and corpus change from the full
checkpoint inputs. The final 249-input manifest SHA-256 is
`9e7d1bf93b663c0582ef052d83be1e4bfc9f6e29a46ca31e65497fa2acf7472e`.
Every other input retains its full-checkpoint content and change time. All final
input/change-time and compiler pins remain unchanged across the three correction
checks. The broad passing selections above precede this fix; they were not
repeated or represented as full runs on the corrected source.

Temporary reference programs, binaries, generated inputs, logs, locks and guard
receipts in `Build/pure-v-jpegxl-hf-20261109-14` are removed after authenticating
completed receipts and unlocked locks. No shared build artifacts are removed.

## Remaining production work

LF/HF metadata entropy and global/frame assembly, feature streams (patches,
splines/noise), frame dependencies/composition, final image resampling and
production image-path integration remain. The HF context-map bound still needs
review for large streams. Output/profile rejection and resource limits must
preserve the production decoder's supported static 8-bit sRGB/gray behavior
before replacing it. These typed-stage checks do not establish complete-file
pixels, allocation/performance parity, or browser validation.

The production Rust decoder, its Cargo/CI hooks and `tools/test_jpegxl.py` remain.
Removing all Rust dependencies, including developer tools, is unfinished. Every
commit requests the managed production rebuild. The existing successful bundle
and receipt were checked; their older executable identity cannot validate these
unconnected V stages. No duplicate manual build or browser launch was performed.
