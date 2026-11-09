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
