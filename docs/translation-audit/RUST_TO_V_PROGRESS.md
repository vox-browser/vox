# Rust-to-V migration progress, 2026-11-08

The regex runtime now builds and executes in V. Its Rust source snapshot, native
ABI, archive builder, platform build hooks and panic handoff have been removed.
The owner wrapper, HTML input pattern caller and existing API behavior use the
translated parser, bytecode compiler, VM and high-level engine. Unicode data
still comes through the existing ICU bridge. This does not complete LibJS's
RegExp object integration or replace JavaScriptCore.

The YUV conversion and GB18030 generator were replaced in earlier focused
commits. Forty Rust-dependent encoding/regex reference-refresh scripts have now
been retired; the V corpus checker verifies their existing independent gold
records. Automatic source-gold regeneration is retired, rather than generated
from the candidate implementation. The C++ Wasm/preparation probes remain.
See [the developer-tool guide](../../tools/REFERENCE_CORPORA.md).

JPEG XL remains the production Rust dependency, including its Cargo build and
native test tool. Its V package now covers checked bit reading and integer
encodings, dimensions/depth, signatures, complete container extraction and
Huffman prefix decoding. ANS, image metadata/color headers, modular prediction
and transforms, VarDCT, filters, color conversion, orientation, alpha
quantization and browser integration remain. The Rust implementation is retained
until the V decoder can preserve supported static 8-bit sRGB/gray images and
current rejection/resource limits. This is progress toward removing all Rust,
not a claim that the repository is Rust-free.

## Executed checks

Current V was used with `-memory-limit 10G -b c -cc clang`; LibJS also uses
`-enable-globals`. Every expensive check ran through the process-tree memory
guard. Focused checks used 3 GiB; the two broad LibJS runs and AST comparison
used the default 12 GiB. GC modes were run separately.

| Check | Result |
| --- | --- |
| Frozen regex parser | 3,018 exact AST/error records pass in both GC modes |
| Frozen full regex engine | 26,544 exact result/capture/output records pass in both GC modes |
| Empty Unicode class-string repetition | Bounded regression and capture checks pass in both modes; six patterns independently checked with Node v26.8.1 |
| LibRegex wrapper | Both files execute successfully in both GC modes |
| HTML input-pattern caller | Executes with GC disabled and unavailable Rust compiler paths, together with the two wrapper files |
| Broad `test libjs` | **241 passed, 2 failed, 243 total**, in each GC mode; both commands exit 1 |
| Current upstream AST corpus, `--all` | **100 passed, 0 failed**, exit 0; no case overrides |
| JPEG XL primitives | 75,776 frozen records, including all half-float encodings; default and no-GC pass |
| JPEG XL container | Valid/malformed signatures and boxes, part permutations, bounded sections, exact existing RGBA fixture extraction; default and no-GC pass |
| JPEG XL Huffman | 4,096 frozen parse/symbol/bit-count records plus byte-histogram and 15-bit-code checks; default and no-GC pass |
| JPEG XL hybrid values | 384 frozen value/max-bit/consumption records plus invalid configurations; default and no-GC pass |
| V corpus checker | Compiles; all-suite and JPEG XL dry runs validate; replacement and JPEG XL suites actually execute, the latter with no GC and unavailable Rust compiler paths |
| Build entrypoints | Shell/Python syntax and V build-driver help pass |
| Windows native smoke | MinGW compilation/linking pass with warnings as errors; no Windows execution for this change |

The full-engine migration oracle could not produce ninety `/v`
repeated-empty-class-string records: the unchanged source exceeded its 3 GiB
memory guard. Those cases are excluded, not replaced or overridden. The V
zero-progress fix is tested separately. Successful source records remain exact.

The broad LibJS failures are `regex_matching_corpus_test.v` and
`string_case_test.v`. On this host, the existing ICU default-locale uppercase
path maps U+0386 to U+0391 where the frozen regex fixture expects U+0386, and
uppercases U+0390 differently from the string fixture's expansion. A direct
`libicucore` probe reproduces the U+0386 conversion even after setting
`en_US_POSIX`; explicitly using the root locale retains U+0386. These helper
implementations and expectations were not changed by the runtime port. The
failures are retained and do not count as a passing broad suite. No locale
substitution or golden-data edits were made to obtain a pass.

Sampled peak RSS was 2,403,172,352 bytes for broad default GC and 2,376,679,424
bytes for broad no-GC. The final four-file JPEG XL default run peaked at
233,488,384 bytes; the no-GC checker process tree peaked at 250,658,816 bytes.
These are sampled process-tree sums, not kernel allocation limits or leak
proofs. Raw per-job receipts were kept while checking and then removed under
the Build scratch policy.

The JPEG XL reference is `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Ten translated source/license files were byte-verified against that archive.
The source's unusual half-float subnormal exponent is preserved and documented;
this is compatibility evidence, not a general IEEE conversion claim.

No production browser build was scheduled or launched for this change. The
latest successful shared receipt was inspected: input head
`44096ca073b59f1009a8cd16b930abe70b296f62`, executable SHA-256
`f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`.
No production-bundle validation is claimed. New-code evidence comes from the
executed library and HTML caller tests. V-owned regex lifetime now follows GC
or the caller's arena; `destroy()` detaches references and does not claim
immediate native-style reclamation under `-gc none`.

See [LibRegex status](../../libregex/PORT_STATUS.md),
[LibJS status](../../libjs/PORT_STATUS.md) and
[JPEG XL status](../../jpegxl/PORT_STATUS.md) for remaining implementation limits.

## Continuation on 2026-11-09

JPEG XL now also has V ANS decoding, combined histogram/symbol readers, context
maps, LZ77, bounded checkpoints and complete file/metadata/color/transform
headers. The nine-file V suite passes in both GC modes through the corpus
checker with unavailable Rust compiler paths. The package's frozen comparisons
now cover 149,526 source cases, counting individual ANS alias transitions.
[The entropy/header report](JPEGXL_V_ENTROPY_HEADERS.md) records the new evidence.
Frame/pixel decoding and production integration remain, so the Rust JPEG XL
backend, build hooks and native test tool are retained. The LibJS results above
are historical and were not rerun for this independent JPEG XL slice.

## Frame and modular continuation on 2026-11-09

The V JPEG XL package now also parses frame/restoration headers, permutations,
complete/incremental section tables, modular transform headers and decision
trees. All fourteen predictors, weighted predictor error/row state and all
42 reversible color transforms run in V. Six browser fixtures have exact
frame/section-chain checks; no pixels are decoded by these chains yet.

The fifteen-file package passes through the V corpus checker in both GC modes
with unavailable Rust compiler paths. Frozen comparisons now cover 176,133
source cases, including whole weighted transcripts and individual ANS alias
transitions. [The frame/modular report](JPEGXL_V_FRAME_MODULAR.md) records the
source coverage, commands, memory observations and remaining boundaries.

Modular channel reconstruction, palettes/squeeze application, VarDCT, filters,
pixel conversion/output and browser integration still need completion.
`native_jpegxl_rust`, its Cargo/CI hooks and `tools/test_jpegxl.py` remain until
the V path preserves the production decoder's supported images and limits.
This does not claim that all Rust dependencies, including developer tools, have
been removed. Prior LibJS/ICU results above were not rerun for this continuation.

## Modular sample continuation on 2026-11-09

V now computes modular pixel properties, reconstructs selected channels from
entropy residuals and applies complete-image palettes and scalar squeeze
planes. Four focused test files pass in default and no-GC modes with unavailable
Rust compiler paths. The source comparisons now total 191,013 cases, with
stateful property transcripts counted as whole cases. This continuation adds
four implementation slices after the preceding JPEG XL fifteen-file batch;
formatting and documentation do not add implementation credit. Broader suites
and unrelated DOM/performance verification counters were left unchanged.

[The modular sample report](JPEGXL_V_MODULAR_SAMPLES.md) records the exact source
coverage and commands. The oracle checks the source generic channel branch and
scalar squeeze paths; specialized/SIMD performance or parity is not claimed.
Stream selection, transform planning/tiled borders, complete frames, VarDCT,
filters, final color/pixel output and browser integration remain. Production
JPEG XL, its Cargo/CI hooks and its native developer test still require Rust.

## Modular stream continuation on 2026-11-09

V now plans and reverses modular transform graphs, selects local/global trees
for complete modular streams, parses LF quant factors and decodes small global
sections into raw channel planes. Five additional focused files pass in default
and no-GC modes with unavailable Rust compiler paths. These add 5,691 frozen
source cases, bringing the package to 196,704 cases and twenty-four test files.
This is 9/10 implementation slices after the preceding fifteen-file JPEG XL
batch; formatting and documentation add no slice credit. Broader suites and
unrelated DOM/performance counters were not changed.

The raw planes match six existing fixtures in both storage widths. Guardian's
first modular LF frame is a dependency for its pending visible VarDCT frame;
orientation, animation and wide-gamut metadata are not final rendering support.
[The modular stream report](JPEGXL_V_MODULAR_STREAMS.md) records the independent
source, exact coverage, commands and corrected failures. Grouped/tiled decoding,
complete frames, VarDCT, filters and final pixel output remain. Production JPEG
XL, Cargo/CI hooks and its developer test continue to require Rust.

## Output samples and JPEG XL checkpoint on 2026-11-09

V now converts integer rows to f32, premultiplies alpha and quantizes output
with the source's positional blue-noise dither. The 4,926 new source row cases
include every 8-bit color/alpha pair for each RGB channel, all integer depths and
rounding ties. The package now checks 201,630 frozen cases in twenty-five files.

The complete twenty-five-file JPEG XL suite passes through the V corpus checker
in both GC modes with unavailable Rust compiler paths. Compiler and all 110
selected input hashes stayed unchanged across both batches. Both tests, inner
guards, drivers and outer guards exited zero. This resets the JPEG XL cadence
to 0/10 after the ten-slice continuation; unrelated LibJS/DOM/performance
ledgers were not changed or rerun.
[The output sample report](JPEGXL_V_OUTPUT_SAMPLES.md) records the exact native
rounding boundary, attribution, commands and memory observations. Final frame
decoding and production/developer-tool Rust removal remain unfinished.

## Small complete lossless files on 2026-11-09

The new pure V `decode_small_lossless_rgba` entry point now produces final
straight and premultiplied RGBA for its bounded single-frame, single-group,
unfiltered 8-bit sRGB/gray modular subset. Its 498 complete-file comparisons
match the existing pinned production helper exactly: 24 successes and 474
rejections, including all eight orientations, containers, hidden straight colors,
position-dependent alpha quantization and every-byte truncations of four inputs.
The new focused file passes in both GC modes with unavailable Rust compiler
paths. This is 1/10 after the preceding full twenty-five-file JPEG XL checkpoint;
the checker now discovers twenty-six files and 202,128 frozen source cases.

[The small lossless report](JPEGXL_V_SMALL_LOSSLESS.md) records the narrower
acceptance boundary and commands. Guardian's non-visible first LF frame is
rejected by this entry point, rather than substituted for its pending visible
VarDCT frame. Grouped/tiled decoding, filtering, complete static-image support
and browser integration remain. Production JPEG XL, Cargo/CI hooks and its
native developer test still require Rust; all-dependency removal is unfinished.

## Grouped lossless frames on 2026-11-09

V now assigns modular channels to global/LF/per-pass sections, decodes and
stitches grouped coded planes, reverses global transforms and produces final
RGBA for grouped lossless files. The existing small-only API keeps its limit.
New reference coverage adds 512 source scheduling/rectangle/stream-ID records
and 26 complete pixel comparisons from thirteen independent inputs. This
includes actual LF data, squeeze transforms, reordered sections and a two-pass
stream with HF data in the final pass. No expected pixel records changed to
obtain a pass.

Four relevant files pass in both GC modes with unavailable Rust compiler paths:
default credit combines three unchanged passing files with a corrected frame
fixture check, while no-GC runs all four together. This is two additional
implementation slices, 3/10 after the preceding twenty-five-file checkpoint;
the checker discovers twenty-eight files and 202,666 frozen cases. Formatting
and documentation add no slice credit, and unrelated ledgers remain unchanged.

[The grouped frame report](JPEGXL_V_GROUPED_FRAMES.md) records commands, source
pins, corrected failures and limits. VarDCT/frame dependencies, filters, broader
color conversion, streaming/partial rendering and production integration remain.
The production Rust JPEG XL backend and its Cargo/CI/developer tools are still
required; complete Rust dependency removal remains unfinished.

## Floating-point filter/color stages on 2026-11-09

Pure V binary32 FMA, Gaborish filtering, chroma upsampling and YCbCr conversion
now match 36,416 new independent source cases. FMA covers random finite triples,
constructed double-rounding midpoints and special-value combinations; native
stage comparisons check every float word from whole finite-sample planes.
No expected result comes from V. Frozen tests require V alone; migration oracles
are temporary and do not restore a Rust developer-tool dependency.

The four new focused files pass in default GC, no-GC and optimized configurations
with unavailable Rust compiler paths. This is four additional implementation
slices, bringing JPEG XL cadence to 7/10 after the preceding full checkpoint.
The corpus checker discovers thirty-two files and 239,082 frozen source cases.
Unrelated LibJS/DOM/performance ledgers and prior broad results remain unchanged.

[The filter/color stage report](JPEGXL_V_FILTER_COLOR_STAGES.md) records source
pins, arithmetic boundaries, commands, formatting and harness corrections.
These stages still need frame-pipeline integration; existing complete-file
entry points retain their filter/resampling/YCbCr restrictions. EPF, VarDCT,
XYB/transfer conversion, frame dependencies and production integration remain.
The production Rust JPEG XL backend and its Cargo/CI/developer tools are still
required; all-dependency removal remains unfinished.

## EPF and thirty-five-file JPEG XL checkpoint on 2026-11-09

The three pure V EPF passes now match 1,536 independently generated whole-plane
source cases, comparing 229,311 output f32 words exactly. Reflected borders,
channel/patch summation and FMA order, constant/block inverse sigma, block phase,
threshold equality and per-pixel bypass are preserved. Output buffers are
independently owned, and bounded geometry/sigma APIs have focused regressions.

All thirty-five JPEG XL test files pass through the V corpus checker in both
GC modes with unavailable Rust compiler paths. The three focused EPF files also
pass an optimized build. The compiler and all 155 selected input hashes remained
unchanged through these final checks. The package now has 240,618 frozen cases.
This completes ten slices after the preceding twenty-five-file checkpoint and
resets JPEG XL cadence to 0/10. Unrelated LibJS/DOM/performance ledgers and their
historical results were not changed or rerun.

[The EPF report](JPEGXL_V_EPF.md) records source pins, commands, memory results and
the corrected test-literal failure. VarDCT sigma-map generation, frame color and
filter pipeline assembly, VarDCT/frame dependencies, XYB/transfer conversion and
production integration remain. The complete-file APIs retain their existing
filter/YCbCr restrictions. Production JPEG XL, Cargo/CI hooks and native developer
tests still require Rust; complete dependency removal remains unfinished.
