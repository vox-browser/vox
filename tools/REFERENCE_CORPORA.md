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
The `jpegxl` suite now selects sixty-five test files covering primitives,
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
sRGB/gray output matrices.
Its 281,561 source cases include whole stateful predictor/property/map/order
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
This checks the V layers; the production pixel decoder and its native developer
test still require Rust.
