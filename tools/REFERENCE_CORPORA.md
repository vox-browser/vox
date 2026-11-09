# Checking translated modules without Rust

`check_translation_corpora.v` runs V tests against independently generated,
checked-in reference records. It never writes expected results. The regex
runtime, YUV conversion and GB18030 generator no longer need a Rust compiler.
JPEG XL still uses its Rust decoder and test tool pending a complete V port.

Run from the canonical checkout, with current V:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/reference-driver.lock --report Build/reference-driver.json -- \
  v -memory-limit 10G -b c -cc clang run tools/check_translation_corpora.v \
  --suite regex --gc none
```

Available groups are `all`, `encoding`, `replacement` (one focused encoding
file), `regex`, `yuv`, `gb18030` and `jpegxl` (the V decoder layers completed
so far). `--compiler /path/to/v` selects the test compiler; `V_BIN` also works. `--dry-run` validates input paths and prints the
exact argv without executing tests. `--jobs 1..4` controls compilation jobs,
with one by default. Each test invocation runs under a separate 3 GiB process
tree guard with V's `-memory-limit 10G`. The checker removes its temporary
lock/report; remove the outer driver's lock/report after recording its result.
Do not run broad suites concurrently.

The migration retired forty Python regex/encoding source-refresh scripts that
compiled Rust, including helpers imported indirectly by other probes. Their
independent golden files remain the test authority. Automatic regeneration was
retired, not replaced with a generator that computes expectations from the
candidate V implementation. Refreshing a source reference requires a separately
reviewed, pinned independent oracle and a documented migration. The C++ Wasm
source probes and `libjs_regexp_preparation_corpus.py` remain independent tools.

The GB18030 data generator is a separate pure V tool:
`v -memory-limit 10G run tools/gen_gb18030_data.v --check`, also run through a
memory guard. It reads checksummed official WHATWG indices in
`encoding/indices/` and preserves the existing runtime table bytes apart from
attribution. It does not depend on `encoding_rs` or Cargo.

For the current regex migration, the parser fixture has 3,018 complete AST/error
records and the engine fixture has 26,544 exact matching/capture/bulk records
from Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`. Successful engine
records have no overrides. Ninety `/v` repeated-empty-class-string cases
exceeded the source oracle's 3 GiB memory guard and are excluded. Separate
regressions verify bounded repetition and captures against Node v26.8.1.
See [LibRegex status](../libregex/PORT_STATUS.md) for the remaining runtime and
ownership boundaries.

The checker was compiled, its complete dry-run path and invalid-suite failure
were checked, and its `replacement` suite actually executed successfully under
the guard. These driver checks do not claim that every selected suite was run
through the driver; individual module checks are recorded with their changes.
The `jpegxl` suite now selects seventy-four test files covering primitives,
containers, Huffman/ANS, context maps, LZ77, checkpoints, file/frame/modular
headers, permutations, section tables, predictors, reversible color transforms
and modular decision trees, pixel properties/channel reconstruction, palettes
and scalar squeeze planes, transform planning/reconstruction, complete modular
streams, LF quant factors, small-frame raw planes, output row conversion and
complete small lossless files, group scheduling and complete grouped lossless
output, fused binary32 arithmetic, Gaborish, chroma upsampling, YCbCr and all
three EPF passes, VarDCT quantizer/color-correlation parameters, block and
zero-density contexts, natural coefficient orders and entropy permutations,
transform metadata, adaptive LF smoothing, VarDCT EPF sigma, DCT quantization
bands, LF reconstruction/context planes, non-raw quantization encodings, complete
quantization matrices and raw modular matrix streams, matrix-set/transform
lookups, HF coefficient dequantization, Hornuss/DCT2X2 inverse transforms, small
inverse DCT kernels/planes, DCT subblocks and LF injection through 256x256.
All twenty-seven inverse-transform kinds now reconstruct, including large DCTs
through 256x256 and every AFV orientation. Further stages decode HF channel and
group entropy, HFGlobal passes and nonzero maps, reconstruct subsampled group
pixels, convert XYB to linear RGB, apply sRGB transfer curves and prepare
sRGB/gray output matrices. It also reconstructs HF metadata maps and reads the
HF metadata and VarDCT LF modular streams, LFGlobal/HFGlobal assembly, group
ownership, complete opaque 4:4:4 VarDCT frames, restoration and RGBA output.
Its 281,841 source cases include whole stateful predictor/property/map/order
transcripts and individual ANS alias transitions.
The prior fifty-five-file checkpoint passed in both GC modes. Ten subsequent
slices pass focused checks in both modes and under `-prod`. The full sixty-five-
file selections pass in both GC modes with unavailable Rust compiler paths.
Tests, inner guards, drivers and outer guards exit zero; the ten-slice checkpoint
resets JPEG XL cadence to 0/10. Results and source
boundaries are recorded in [the HF/color report](../docs/translation-audit/JPEGXL_V_HF_ENTROPY.md)
and [the inverse DCT report](../docs/translation-audit/JPEGXL_V_INVERSE_DCT.md).
That full checkpoint contains 281,553 records. A subsequent grayscale signed-zero
fix adds eight source cases and passes focused default/no-GC/optimized checks,
bringing cadence to 1/10; the prior full selections are not claimed on its three
changed paths.
Three further slices add 256 native metadata cases and constructed LF/metadata
packet checks, with the final six-file focused selection passing both GC modes.
Cadence is now 4/10; no full sixty-eight-file selection is claimed.
[The LF stream report](../docs/translation-audit/JPEGXL_V_LF_STREAMS.md) records
the independent metadata comparisons and narrower stream-composition coverage.
Six later slices add 24 native whole-file pixel references, including nonuniform
LF patterns and multiple LF/HF groups. Their opaque subset is checked exactly
against the pinned production decoder, while wider VarDCT support remains open.
Focused default/no-GC and optimized checks pass. All 74 files also pass through
the V checker in both GC modes, with test, inner-guard, driver and outer-guard
exits zero. All 294 selected input hashes/change times and the compiler pin
remain unchanged, completing the ten-slice checkpoint and resetting cadence
to 0/10. See [the frame report](../docs/translation-audit/JPEGXL_V_FRAME_ASSEMBLY.md).
This checks the V layers; the production pixel decoder and its native developer
test still require Rust.

Four further LF-reference slices add 512 modular XYB cases and the existing
Guardian photo's complete native RGBA hash. The count is 282,354 source records
and 78 test files. All 130,560 new conversion float words and all 38,416 photo
bytes compare exactly. The photo exercises modular LF ownership and nonzero HF
reconstruction; the preceding 24 whole-image references remain exact. The final
seven-file selection passes default/no-GC/optimized checks with unavailable Rust
compiler paths, actual test/guard exits zero and 299 unchanged inputs. Cadence
is 4/10; the full 78-file selection has not run. Frozen verification uses V
alone. Production JPEG XL and its native developer test still use Rust.
See [the LF reference report](../docs/translation-audit/JPEGXL_V_LF_REFERENCES.md).

Image upsampling adds 384 source stage records and 15 complete native image
references: 282,753 source records and 80 test files total. All 246,656 float
words and 1,933,816 new RGBA bytes compare exactly. The final five-file
selection passes default/no-GC/optimized checks with 320 unchanged inputs and
test/guard exits zero. An earlier shared compiler change invalidated one
regression run; all final modes use the new pinned compiler. Cadence is 6/10;
no full 80-file run is claimed. Production and its native developer test still
require Rust. See [the upsampling report](../docs/translation-audit/JPEGXL_V_UPSAMPLING.md).

Embedded preview skipping adds eight native file records, bringing JPEG XL
to 282,761 records and 82 test files. Normal/poisoned previews preserve VarDCT,
lossless alpha, gray and rotated output exactly. Focused checks pass both GC
modes and optimized builds; the last four-file selection has 333 unchanged
inputs and actual test/guard exits zero. One default preview assertion needed
an option unwrap; its corrected standalone pass combines with three retained
image-file passes, without whole-run credit for the failed original batch.
Cadence is 8/10; no full 82-file run is claimed. Production and its native
developer tool still need Rust. See [the preview report](../docs/translation-audit/JPEGXL_V_PREVIEWS.md).

Visible modular XYB output adds twenty complete native files and 269,336 exact
RGBA bytes, bringing JPEG XL to 282,781 source records and 84 test files. The
shared frame renderer also retains the previous conversion references without
counting them again. The new opaque entry point preserves all 42 prior native
opaque image references. Focused default/no-GC/optimized checks pass. All 84
files also pass through this V driver in both GC modes, with tests, inner guards,
drivers and outer guards exiting zero and 358 unchanged selected inputs. The
ten-slice checkpoint resets cadence to 0/10 at `16b9843ac`.
See [the modular-output report](../docs/translation-audit/JPEGXL_V_MODULAR_OUTPUT.md).
Production JPEG XL and its native developer tool still require Rust.

VarDCT alpha adds twenty independent native files, bringing JPEG XL to 282,801
source records and 86 test files. Shared modular state preserves alpha through
LF/HF sections; unified `decode_rgba` output compares 1,800,640 straight/paint
RGBA bytes exactly, including associated alpha and orientation. It also
preserves 62 opaque references, 26 grouped-lossless records, six preview files
and 498 small-image records. Final focused default/no-GC/optimized checks pass
with actual test/guard exits zero and 382 unchanged inputs. The interrupted
raw optimized check has no pass credit; a fresh check passes. Cadence is 2/10
after the 84-file checkpoint, with no full 86-file run claimed. Production and
its native developer tool still require Rust.
See [the alpha report](../docs/translation-audit/JPEGXL_V_VARDCT_ALPHA.md).

Modular XYB alpha adds twenty native records and 1,800,640 exact straight/paint
RGBA bytes, bringing JPEG XL to 282,821 records and 87 test files. The final
four-file selection passes default/no-GC/optimized checks, with actual
exits zero and 404 unchanged inputs. Test authoring failures retain no
whole-run pass credit; native gold remains unchanged. Cadence is 3/10, with
no full 87-file run claimed. Production and its native tool still use Rust.
See [the modular-alpha report](../docs/translation-audit/JPEGXL_V_MODULAR_ALPHA.md).

LF alpha adds twenty progressive native records and 1,800,640 exact
straight/paint RGBA bytes: 282,841 records and 88 JPEG XL test files total.
The three-file focused selection passes default/no-GC/optimized checks with
actual exits zero and 426 unchanged inputs. Cadence is 4/10; no full 88-file
run is claimed. Production and its native developer tool still require Rust.
See [the LF-alpha report](../docs/translation-audit/JPEGXL_V_LF_ALPHA.md).

Alpha upsampling adds 72 native records and 4,817,664 exact straight/paint
RGBA bytes: 282,913 records and 89 JPEG XL test files total. The five-file
selection passes default/no-GC/optimized checks with actual exits zero and
501 unchanged inputs. Cadence is 5/10; no full 89-file run is claimed.
Production and its native developer tool still use Rust.
See [the alpha-upsampling report](../docs/translation-audit/JPEGXL_V_ALPHA_UPSAMPLING.md).

Subsampled YCbCr assembly adds twenty native JPEG-recompressed records and
1,660,864 exact straight/paint RGBA bytes: 282,933 records and 90 test files
total. Four focused files pass default/no-GC/optimized checks with actual
exits zero and 524 unchanged inputs. Cadence is 6/10; no full 90-file run is
claimed. Production and its native developer tool still use Rust.
See [the chroma-frame report](../docs/translation-audit/JPEGXL_V_CHROMA_FRAMES.md).

Original-profile modular RGB/gray output adds 128 native records and 8,564,736
exact straight/paint RGBA bytes: 283,061 records and 91 JPEG XL test files
total. Three focused files pass default/no-GC/optimized checks with actual
exits zero and 655 unchanged inputs, retaining prior unified output references.
Cadence is 7/10; no full 91-file run is claimed. Production and its native
developer tool still use Rust.
See [the modular RGB report](../docs/translation-audit/JPEGXL_V_MODULAR_RGB.md).

Noise LUT/random-state translation adds 1,162 original source records:
284,223 records and 92 JPEG XL test files total. All 8,192 LUT float words and
12,288 RNG u64 words compare exactly, alongside truncation/consumption checks.
The focused file passes default/no-GC/optimized checks with actual exits zero
and 659 unchanged inputs. Cadence is 8/10; no full 92-file run is claimed.
Checked-in verification uses V alone; whole-file noise and production/native
developer-tool replacement remain unfinished.
See [the noise-state report](../docs/translation-audit/JPEGXL_V_NOISE_STATE.md).

Noise color application adds 768 original stage records and 73,728 exact float
words: 284,991 records and 93 JPEG XL test files total. Two focused files pass
default/no-GC/optimized checks with actual exits zero and 662 unchanged inputs.
Two failed attempts expose C contraction; final source keeps the unfused B
operation, with native gold unchanged. Cadence is 9/10; no full 93-file run is
claimed. Whole-file noise and production/native developer-tool replacement
remain unfinished.
See [the noise-application report](../docs/translation-audit/JPEGXL_V_NOISE_APPLICATION.md).

Complete VarDCT noise adds 28 native files and 2,477,600 exact straight/paint
RGBA bytes: 285,019 records and 94 JPEG XL test files total. The original parser
verifies independently rewritten headers/TOCs; zero controls retain base pixels
and every nonzero-LUT file changes its native image. Focused default/no-GC/
optimized checks pass with actual exits zero and 693 unchanged final inputs;
the original failed default batch retains no whole-run credit. This reaches
10/10 after the 84-file checkpoint. Full 94-file checks now pass both GC modes,
with actual tests/inner guards/drivers/outer guards exiting zero and all 701
selected input hashes/change times unchanged. Cadence resets to 0/10.
Production and its native tool still use Rust.
See [the whole-noise report](../docs/translation-audit/JPEGXL_V_NOISE_FRAMES.md).


Patch dictionaries, blending and row application add 2,216 frozen native
records, bringing JPEG XL to 287,235 records and 97 test files. All three new
files pass default/no-GC/optimized checks with unavailable Rust compiler paths,
actual test/guard exits zero and 710 unchanged selected inputs. Native metadata,
32,640 blend float words and 3,121,152 application words compare exactly,
including full/irregular chunk equality. Cadence is 3/10 after the full 94-file
checkpoint; a full 97-file run has not been performed. Encoded patch frames
and production/native developer-tool replacement remain unfinished.
See [the patch report](../docs/translation-audit/JPEGXL_V_PATCHES.md).


The spline entropy corpus adds 3,044 native records (536 accepted), bringing
JPEG XL to 290,279 records and 98 test files. The focused file passes default,
no-GC and optimized checks with unavailable Rust compiler paths, actual exits
zero and 713 unchanged inputs. The initial compile-only failure has no execution
credit. Cadence is 4/10 after the full 94-file checkpoint; no full 98-file run is
claimed. Spline rendering, frame integration and production/native tool
replacement remain.
See [the spline-stream report](../docs/translation-audit/JPEGXL_V_SPLINE_STREAMS.md).


Spline dequantization adds 896 native records, including 244 successful calls
comparing 33,664 float words plus exact U64 area/coincidence results. Both
spline files pass default/no-GC/optimized checks with unavailable Rust compiler
paths, actual exits zero and 716 unchanged inputs. JPEG XL totals 291,175
records and 99 test files, cadence 5/10 after the full 94-file checkpoint;
no full 99-file run is claimed. Spline rasterization, frame integration and
production/native tool replacement remain.
See [the dequantization report](../docs/translation-audit/JPEGXL_V_SPLINE_DEQUANT.md).


Spline cosine/error-function arithmetic adds 14,361 distinct native inputs,
including 135 scalar/NEON rounding differences. The focused file passes
default/no-GC/optimized checks with unavailable Rust compiler paths, actual
exits zero and 719 unchanged selected inputs. JPEG XL totals 305,536 records
and 100 test files, cadence 6/10 after the full 94-file checkpoint; no full
100-file run is claimed. Curve/raster work, frame integration and production/
native tool replacement remain.
See [the spline-math report](../docs/translation-audit/JPEGXL_V_SPLINE_MATH.md).


Spline subdivision/DCT/cache construction adds 256 native records, including
234 accepted caches with 3,341 segments and 57,792 ordered in-bounds row
entries. NaN payloads normalize explicitly. Three focused files pass default,
no-GC and optimized checks with unavailable Rust compiler paths, actual exits
zero and 723 unchanged inputs. JPEG XL has 305,792 records and 101 test files,
cadence 7/10 after the full 94-file checkpoint; no full 101-file run is claimed.
Gaussian drawing, frame integration and production/native tool replacement
remain. See [the cache report](../docs/translation-audit/JPEGXL_V_SPLINE_CACHE.md).
