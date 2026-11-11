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

## VarDCT parameters and coefficient orders on 2026-11-09

Four more JPEG XL slices now execute in pure V: quantizer parameters,
color-correlation parameters, block/zero-density contexts, and natural/entropy
coefficient orders. The 17,165 added source cases preserve float words,
threshold wrapping, context identities, complete natural vectors and hashes of
all 39 decoded component orders. The frozen tests need no Rust compiler or
Cargo; temporary migration oracles used unchanged pinned source and cached
dependencies and were removed after recording the results.

The four focused files pass in both GC modes and optimized checks with
unavailable Rust compiler paths. Shared half-float parsing also retains the
preceding exhaustive primitive and bit-reader checks in both modes. The corpus
checker now discovers thirty-nine files and 257,783 frozen source cases. The
preceding full checkpoint covers thirty-five files; this continuation advances
JPEG XL cadence to 4/10 without claiming a new full checkpoint. Unrelated
LibJS/DOM/performance ledgers and historical broad results remain unchanged.

[The VarDCT parameter/order report](JPEGXL_V_VARDCT_PARAMETERS.md) records the
source pins, exact comparison boundaries, commands and corrected harness
failures. VarDCT coefficient reconstruction, quantization matrices, sigma-map
generation, XYB/transfer conversion, frame dependencies and rendering pipeline
assembly remain. Production JPEG XL and its Cargo/CI/native developer tests still
require Rust; removal of all Rust dependencies remains unfinished.

## VarDCT LF processing on 2026-11-09

Six additional pure V slices cover all twenty-seven transform mappings,
adaptive LF smoothing, VarDCT EPF sigma generation, DCT quantization bands,
LF plane/context reconstruction and non-raw quantization encodings. The 9,986 new frozen source cases compare
328,098 smoothing words, 28,581 sigma words, 60,716 reconstructed LF words and
35,781 context indices, along with parsed parameters, mappings and positions.
LF references cover both integer storage widths, chroma subsampling, all extra
precision values and strict threshold buckets. These are standalone decoder
stages; LF entropy/frame assembly and HF reconstruction remain open.

All forty-five test files pass through the V corpus checker in both GC modes
with unavailable Rust compiler paths. Actual tests, inner guards, drivers and
outer guards exit zero. This completes the ten-slice checkpoint and resets JPEG
XL cadence to 0/10. The package has 267,769 source cases; focused optimized
checks also pass. Compiler and selected input hashes remain unchanged, and the
embedded dither table is separately verified against its pinned hash and Git.
Broader unrelated suites and historical ledgers were not changed or rerun.
Temporary migration oracles use pinned source and cached artifacts; frozen
developer checks need V alone.

The LF continuation in [the VarDCT report](JPEGXL_V_VARDCT_PARAMETERS.md) records
the source and adapter boundaries, commands, memory results and harness
corrections. Raw quantization streams, generated matrices, HF coefficients/inverse transforms,
frame dependencies, XYB/transfer conversion and production pipeline integration
remain. Production JPEG XL and its Cargo/CI/native developer tools still depend
on Rust; removal of all Rust dependencies remains unfinished. No
production-browser validation is claimed for these standalone decoder stages.

## Quantization and initial inverse transforms on 2026-11-09

Six additional pure V slices generate all seventeen quantization matrices,
decode raw modular matrix streams and complete matrix sets, dequantize HF
coefficients and reconstruct Hornuss identity/DCT2X2 blocks. Every transform's
matrix lookup is checked. The new 3,136 independent source records include
1,930,368 exact HF dequantization words and 65,536 inverse-transform words.
The package now has 270,905 source records and fifty-one test files.

All six new focused files pass in both GC modes and under `-prod`, with
unavailable Rust compiler paths and 3 GiB guards. The preceding full checkpoint
still covers forty-five files; JPEG XL cadence is now 6/10. Other suites and
historical ledgers are unchanged. [The quantization report](JPEGXL_V_QUANTIZATION.md)
records the original-source oracle boundaries, input identities, harness
corrections and executed checks. Temporary migration references use cached Rust
artifacts, while frozen developer checks execute with V alone.

HF entropy decoding, the remaining inverse transforms, LF/global/frame
assembly, XYB/transfer conversion, frame dependencies and production image-path
integration remain. Production JPEG XL, Cargo/CI hooks and the native developer
test still depend on Rust. Removal of all Rust dependencies remains unfinished;
no production-browser validation is claimed for these standalone stages.

## Inverse DCT and fifty-five-file JPEG XL checkpoint on 2026-11-09

Four more slices translate 2/4/8/16/32-point inverse DCT kernels, thirteen
two-dimensional plane geometries, DCT4X4/DCT4X8/DCT8X4 block reconstruction and
LF injection. Every ordinary DCT kind has LF injection through 256x256;
complete ordinary transforms currently reach 32x32. Together with earlier
Hornuss/DCT2X2 work, fourteen of twenty-seven transform kinds reconstruct.
The added 5,504 records compare 705,728 exact output words. The package now
has 276,409 records and fifty-five test files.

All fifty-five files pass through the V corpus checker in both GC modes with
unavailable Rust compiler paths. Tests, inner guards, drivers and outer guards
exit zero. The four new focused files also pass optimized checks. Compiler and
all 219 selected source/fixture/driver/guard hashes and change times remain
unchanged across the full selections, including the embedded dither table.
This completes the ten-slice continuation after the forty-five-file checkpoint
and resets JPEG XL cadence to 0/10. Other suites and ledgers were not changed
or rerun. [The inverse DCT report](JPEGXL_V_INVERSE_DCT.md) records the source
pins, exact arithmetic/transpose boundaries, harness correction and full checks.

Large inverse DCTs, AFV transforms, HF entropy decoding, LF/global/frame
assembly, XYB/transfer conversion, frame dependencies and production integration
remain. Production JPEG XL and its Cargo/CI/native developer tools still need
Rust. Removing all Rust dependencies remains unfinished, with no
production-browser validation claimed for these standalone stages.

## All JPEG XL inverse-transform kinds on 2026-11-09

Two later slices complete 64/128/256-point inverse DCTs and every AFV
orientation. All twenty-seven transform kinds now reconstruct from typed LF/HF
coefficient inputs, with ordinary DCT output through 256x256. The new 2,486
records compare 1,220,608 exact output words, bringing the package to 278,895
records and fifty-seven test files.

Focused large/AFV checks pass in both GC modes and under `-prod`, with unavailable
Rust compiler paths. The preceding full checkpoint still covers fifty-five
files; cadence is 2/10, with no newer full-package pass claimed. Compiler and
all 225 selected input hashes/change times remain unchanged over final checks.
The continuation in [the inverse DCT report](JPEGXL_V_INVERSE_DCT.md#large-dct-and-afv-continuation)
records source pins, scratch ownership, exact comparisons and memory guards.

HF entropy decoding, LF/global/frame assembly, XYB/transfer conversion, frame
dependencies and production integration remain. Production JPEG XL and its
Cargo/CI/native developer tools still require Rust; removing all Rust
dependencies remains unfinished. No production-browser validation is claimed.

## HF decoding, color output and sixty-five-file checkpoint on 2026-11-09

Eight more pure V slices decode HF channels, HFGlobal passes, nonzero prediction
maps and progressive group coefficients, reconstruct group pixels, convert XYB
to linear RGB, apply both sRGB transfer directions and prepare sRGB/gray output
matrices. All twenty-seven transform kinds, both storage widths, chroma sampling,
per-tile color correlation and progressive accumulation occur in the source
comparisons. The 2,658 added cases bring this checkpoint to 281,553 records and
sixty-five files. Complete state transcripts include 72,592,755 exact words,
including repeated orders/maps and metadata rather than that many unique pixels.

All sixty-five files pass through the V corpus checker in both GC modes, with
unavailable Rust compiler paths. Actual tests, inner guards, drivers and outer
guards exit zero. All eight new files also pass optimized checks. Compiler and
all 249 selected source/data/checker/guard hashes and change times remain
unchanged across these checks. This completes ten slices after the fifty-five-
file checkpoint and resets JPEG XL cadence to 0/10.

A subsequent source diagnostic exposed negative-zero matrix summation. Eight
new independent cases reproduce the difference before the focused fix. The
corrected file passes in both GC modes and under `-prod`; only its three paths
change from the full checkpoint. The package now has **281,561 records and
65 files**, at cadence **1/10**. The full selections precede that correction;
they were not rerun or claimed on changed source. [The HF/color report](JPEGXL_V_HF_ENTROPY.md)
records source pins, adapter/error boundaries, exact comparisons, failures,
commands, input identities and memory results. Temporary Rust migration oracles
are removed; frozen developer checks continue to use V alone.

LF/HF metadata entropy and global/frame assembly, feature streams, frame
dependencies/composition, final resampling and production integration remain.
The entropy context-map bound also remains. Production JPEG XL, its Cargo/CI
hooks and native developer test still require Rust. Removing all Rust dependencies
remains unfinished; these standalone stages do not establish complete-file
VarDCT output or production-browser validation.

## HF metadata and VarDCT LF streams on 2026-11-09

Three further slices reconstruct HF metadata maps and read their modular stream
and the VarDCT LF stream. The 256 additional native cases compare 773,525 exact
map words, including all transform kinds, both storage widths, clamping, group
boundaries and rejected metadata. Constructed packet tests separately verify
composition, stream identities, channel order, sampling, extra precision and
LF contexts; they are not a new native compressed-stream corpus.

The package now has **281,817 source cases and 68 test files**. Its preceding
65-file checkpoint and signed-zero correction keep their recorded identities.
Final focused selection covers the three new files plus modular stream/group
and LF reconstruction regressions, passing both GC modes with unavailable Rust
compiler paths. Cadence is **4/10**, with no full 68-file pass claimed.
[The LF stream report](JPEGXL_V_LF_STREAMS.md) records source/reference boundaries,
optimized checks, guard results and remaining production work.

Global/frame assembly, frame dependencies/composition, feature streams, final
image resampling and production integration remain. The production JPEG XL
decoder and its Cargo/CI/native developer tools still need Rust; removing all
Rust dependencies remains unfinished.

## Complete opaque VarDCT frame assembly on 2026-11-09

Six additional slices connect LFGlobal/HFGlobal state, LF/HF ownership and
cropping, complete frame-plane decoding, restoration and opaque 4:4:4 VarDCT
RGBA output. The new 24 independently decoded files compare **1,575,540 native
RGBA bytes exactly**, with both straight/premultiplied V requests. They include
odd dimensions, multiple HF/LF groups and nonuniform LF patterns that exercise
smoothing and restoration. Their HF coefficients are zero; this is a bounded
complete-file cohort rather than arbitrary image parity.

The package now has **281,841 source records and 74 test files**. All six new
files pass focused checks in both GC modes and optimized builds. All 74 files
pass through the V corpus checker in both GC modes. Actual tests, inner guards,
drivers and outer guards exit zero; all 294 selected input hashes/change times
and the compiler pin remain unchanged. This completes ten slices after the
65-file checkpoint and resets cadence to **0/10**. Previous results and input
identities remain intact. [The frame-assembly report](JPEGXL_V_FRAME_ASSEMBLY.md)
records source and binary pins, fixture construction, exact comparison scopes,
harness corrections, checks and remaining limits.

Production JPEG XL, Cargo/CI hooks and the native developer tool still use Rust.
LF/reference frames, extra channels/alpha, sampling/resampling, feature streams,
broader composition, large entropy maps and production image integration remain.
Removal of all Rust dependencies remains unfinished; no browser validation or
complete production replacement is claimed.

## LF reference frames on 2026-11-09

Four further V slices add modular XYB conversion, shared restoration, explicit
VarDCT LF dependencies and complete-file LF ownership. The Guardian photo now
matches the pinned native decoder's entire 98×98 RGBA image, including nonzero
HF content. All 25 whole-file references compare 1,613,956 native RGBA bytes
exactly. Another 512 conversion cases compare 130,560 complete float words,
bringing the package to 282,354 source records and 78 test files.

The final seven-file focused selection passes both GC modes and `-prod`, with
test/guard exits zero and 299 unchanged inputs. Cadence is 4/10 after the
74-file checkpoint; no full 78-file run is claimed. Source pins, corrected test
attempts, exact coverage and remaining bounds are in
[the LF reference report](JPEGXL_V_LF_REFERENCES.md).

Production JPEG XL and its Cargo/CI/native developer tool still need Rust.
Wider reference composition, alpha/extra channels, sampling/resampling, feature
streams, large entropy maps and production integration remain. Removing every
Rust dependency, including developer tools, remains unfinished.

## JPEG XL upsampling on 2026-11-09

Two further V slices add 2x/4x/8x image upsampling and connect it before color
conversion and LF saving. Native references add 384 complete float-plane cases
and 15 complete images; all 246,656 float words and 1,933,816 RGBA bytes compare
exactly. The package now has 282,753 source records and 80 test files. Across
the whole-file cohorts, 40 images compare 3,547,772 native RGBA bytes exactly.

The final five-file selection passes both GC modes and optimized checks with
320 unchanged inputs and actual test/guard exits zero. A compiler change
invalidated an earlier regression run; the final modes pin its replacement.
Cadence is 6/10, with no full 80-file run claimed.
[The upsampling report](JPEGXL_V_UPSAMPLING.md) records source/oracle pins,
compiler identities, failed/rejected attempts, executed checks and bounds.
Production JPEG XL and its Cargo/CI/native developer tool still use Rust;
wider reference composition, alpha/extra channels, whole-frame chroma sampling,
feature streams, large entropy maps and production integration remain.

## Embedded JPEG XL previews on 2026-11-09

Two further V slices skip visible final previews before VarDCT and lossless
decoding, preserving native default behavior without decoding preview entropy.
Eight independent native file records cover valid/poisoned preview payloads,
alpha in straight/paint output, gray and rotated dimensions. The package now
has 282,761 source records and 82 test files.

Focused default/no-GC/optimized checks pass. The last four-file selection has
333 unchanged inputs and actual test/guard exits zero. Default VarDCT-preview
coverage combines three retained image-file passes and the corrected preview
file's fresh standalone pass; the original failed batch has no whole-run pass
credit. Cadence is 8/10, with no full 82-file run claimed.
[The preview report](JPEGXL_V_PREVIEWS.md) records source and oracle pins,
fixture provenance, the test repair and executed results.

Production JPEG XL, its Cargo/CI integration and native developer test still
need Rust. Non-visible preview dependencies, wider reference composition,
VarDCT extra channels/alpha, whole-frame chroma sampling, feature streams,
large entropy maps and production integration remain unfinished.

## Visible modular XYB output and full checkpoint on 2026-11-09

Two more V slices share modular XYB rendering with LF saving and add complete
opaque VarDCT/modular XYB output. Twenty new native files compare 269,336 RGBA
bytes exactly, including filtering, all image-upsample factors and orientation.
The entry point also preserves 42 prior opaque native image references. The
package now has 282,781 source records and 84 test files.

Focused default/no-GC/optimized checks pass. The full 84-file corpus also passes
through the V checker in both GC modes, with actual tests, inner guards, drivers
and outer guards exiting zero. All 358 selected hashes/change times remain
unchanged. This completes ten slices after the 74-file checkpoint and resets
cadence to 0/10 at `16b9843ac`.
[The modular-output report](JPEGXL_V_MODULAR_OUTPUT.md) records the independent
fixture construction, source/toolchain pins, focused checks and full results.

Production JPEG XL and its Cargo/CI/native developer tool still use Rust.
VarDCT extra channels/alpha, whole-frame chroma sampling, feature streams,
wider reference composition, non-visible preview dependencies, larger entropy
maps and production integration remain. Removing all Rust dependencies remains
unfinished.

## VarDCT JPEG XL alpha on 2026-11-09

Two further V slices share modular state with VarDCT and add a unified RGBA
entry point, including one unscaled 8-bit alpha channel. Twenty independent
native records compare 1,800,640 straight/paint RGBA bytes exactly, including
global/grouped alpha, multiple LF owners, nonzero HF, associated alpha and
orientation. The package has 282,801 source records and 86 test files; reusing
older references adds no records.

Final focused default/no-GC/optimized checks pass with actual test/guard exits
zero and 382 unchanged inputs. An interrupted raw optimized check has no pass
credit and was rerun successfully. Cadence is 2/10 after the full 84-file
checkpoint; no full 86-file run is claimed.
[The alpha report](JPEGXL_V_VARDCT_ALPHA.md) records provenance, failed attempts,
limits and executed results. Wider/resampled alpha, LF alpha dependencies,
modular XYB alpha, whole-frame chroma sampling, feature streams, composition,
larger entropy maps and production integration remain. Production JPEG XL and
its Cargo/native developer tool still use Rust; removing all Rust is unfinished.

## Modular XYB JPEG XL alpha on 2026-11-09

One further slice adds modular XYB alpha to the unified V output path. Twenty
new native files compare 1,800,640 straight/paint RGBA bytes exactly, including
grouped data, associated alpha and orientation. The package has 282,821 source
records and 87 test files. Four focused files pass default/no-GC/optimized
checks with actual exits zero and 404 unchanged inputs. Two test authoring
failures have no whole-run pass credit; native gold remains unchanged.
Cadence is 3/10 after the 84-file checkpoint; no full 87-file run is claimed.
[The modular-alpha report](JPEGXL_V_MODULAR_ALPHA.md) records source/tool pins,
geometry verification, failures and checks. LF alpha dependencies, resampling,
chroma sampling, feature streams, composition and production/tool integration
remain. Production JPEG XL and its native developer tool still require Rust.

## JPEG XL LF alpha on 2026-11-09

One additional slice decodes alpha-bearing progressive LF references without
premultiplying the saved source colors. Twenty new native files compare
1,800,640 straight/paint RGBA bytes exactly, bringing JPEG XL to 282,841 source
records and 88 test files. Three focused files pass default/no-GC/optimized
checks with actual exits zero and 426 unchanged inputs. Cadence is 4/10 after
the 84-file checkpoint; no full 88-file run is claimed.
[The LF-alpha report](JPEGXL_V_LF_ALPHA.md) records source/tool pins, reference
ownership and checks. Resampling, chroma sampling, feature streams, composition,
larger entropy maps and production/tool integration remain; production JPEG XL
and its native developer tool still use Rust.

## JPEG XL alpha upsampling on 2026-11-09

Another V slice normalizes and upsamples 8-bit alpha independently of color,
covering all nine supported factor pairs in VarDCT and modular XYB. Seventy-two
new native records compare 4,817,664 straight/paint RGBA bytes exactly. The
package has 282,913 source records and 89 test files. Five focused files pass
default/no-GC/optimized checks with actual exits zero and 501 unchanged inputs.
Cadence is 5/10 after the 84-file checkpoint; no full 89-file run is claimed.
[The alpha-upsampling report](JPEGXL_V_ALPHA_UPSAMPLING.md) records pins and
checks. Resampled LF alpha, wider extra channels, chroma sampling, feature
streams, composition and production/tool integration remain. Production JPEG XL
and its native developer tool still require Rust.

## JPEG XL subsampled YCbCr frames on 2026-11-09

A further slice preserves component dimensions while stitching LF/HF planes
and expands chroma before restoration. Twenty native JPEG-recompressed files
compare 1,660,864 straight/paint RGBA bytes exactly across four sampling modes.
The package has 282,933 source records and 90 test files. Four focused files
pass default/no-GC/optimized checks with actual exits zero and 524 unchanged
inputs. Cadence is 6/10 after the 84-file checkpoint; no full 90-file run is
claimed. [The chroma-frame report](JPEGXL_V_CHROMA_FRAMES.md) records pins,
limits and checks. Wider chroma combinations, original-profile modular
rendering, extra-channel combinations, feature streams, frame composition and
production/tool integration remain. Production JPEG XL and its native developer
tool still require Rust.

## JPEG XL original-profile modular RGB/gray on 2026-11-09

Another slice adds filtered and upsampled original-profile modular RGB/gray
output, sharing one parsed file owner with VarDCT and XYB. Another 128 native
files compare 8,564,736 straight/paint RGBA bytes exactly, bringing JPEG XL to
283,061 records and 91 test files. Three focused files pass default/no-GC/
optimized checks with actual exits zero and 655 unchanged inputs. Older
unified-image references remain exact. Cadence is 7/10 after the 84-file
checkpoint; no full 91-file run is claimed.
[The modular RGB report](JPEGXL_V_MODULAR_RGB.md) records source/tool pins,
limits and checks. Feature streams, frame composition, wider extra-channel/LF
combinations, larger entropy maps and production/tool integration remain.
Production JPEG XL and its native developer tool still require Rust.

## JPEG XL noise state on 2026-11-09

Another slice translates noise LUT parsing and deterministic random state.
A temporary caller of the cached original crate supplies 1,162 new records,
comparing 8,192 LUT float words and 12,288 RNG u64 words exactly, plus truncation
and bit consumption. The package has 284,223 records and 92 test files. The
focused file passes default/no-GC/optimized checks with actual exits zero and
659 unchanged inputs. Cadence is 8/10 after the 84-file checkpoint; no full
92-file run is claimed. [The noise-state report](JPEGXL_V_NOISE_STATE.md)
records source/artifact pins and checks. Noise rendering, patches/splines,
composition and production/tool integration remain. Production JPEG XL and
its native developer tool still require Rust.

## JPEG XL noise color application on 2026-11-09

Another slice applies noise to source-space color with explicit LUT precision.
The original ARM64 stage supplies 768 records and 73,728 exact float words;
256 exactly representable LUT cases also check full-precision lookup. The
package has 284,991 records and 93 test files. Two focused files pass default/
no-GC/optimized checks with actual exits zero and 662 unchanged inputs. Failed
contraction attempts retain no whole-run pass credit; final source preserves
unfused B rounding without changing gold. Cadence is 9/10 after the 84-file
checkpoint; no full 93-file run is claimed.
[The noise-application report](JPEGXL_V_NOISE_APPLICATION.md) records pins,
precision limits and checks. Fields/convolution, whole-file noise, patches/
splines, composition and production/tool integration remain. Production JPEG XL
and its native developer tool still require Rust.

## Complete JPEG XL VarDCT noise on 2026-11-09

The next slice constructs seeded random fields, convolves them and applies
noise before color conversion. Twenty-eight native files compare 2,477,600
straight/paint RGBA bytes exactly, including controls, alpha, orientation,
permuted TOCs, multiple LF owners and image upsampling. The package has 285,019
records and 94 test files. Whole output fixes the verified BF16 reference
profile; native scalar/AVX full-table output may differ. Noisy LF/modular/non-XYB
frames remain unsupported.

Focused checks pass both GC modes and optimized builds with actual exits zero
and 693 unchanged final inputs. Default coverage combines three retained passes
with the corrected noise file; the original failed batch retains no whole-run
credit. Full 94-file corpus checks now pass both GC modes with actual tests,
inner guards, drivers and outer guards exiting zero, and all 701 selected input
hashes/change times unchanged. The ten-slice checkpoint completes; cadence
resets to 0/10.
[The whole-noise report](JPEGXL_V_NOISE_FRAMES.md) records source/tool pins,
independent header verification, failures and checks. Patches/splines, reference
composition, wider channels/LF combinations and production/tool integration
remain. Production JPEG XL and its native developer tool still require Rust.


## JPEG XL patch primitives and rows on 2026-11-09

Three separately committed slices translate patch dictionaries and ordered row
lookup, color/extra-channel blending, and clipped row application. They add
2,216 native records: 287,235 records and 97 test files total. Dictionaries,
32,640 blend float words and 3,121,152 application float words match exactly;
full rows and irregular chunks agree in both implementations. All three new
files pass default/no-GC/optimized checks with actual test/guard exits zero
and 710 unchanged selected inputs. Cadence is 3/10 after the full 94-file
checkpoint; no full 97-file run is claimed.
[The patch report](JPEGXL_V_PATCHES.md) records pins, checked API limits and
verification. Encoded patch frames, stored references/composition, splines,
wider channel/LF combinations and production/tool integration remain.
Production JPEG XL and its native developer test still require Rust.


## JPEG XL quantized spline streams on 2026-11-09

The spline entropy reader adds 3,044 native records, including 536 accepted
states with exact consumption, metadata, point words and DCT coefficients.
Default/no-GC/optimized checks pass with actual exits zero and 713 unchanged
inputs. The initial declaration-only compile failure receives no execution
credit. The package has 290,279 records and 98 files, cadence 4/10 after the
full 94-file checkpoint; no full 98-file run is claimed.
[The spline-stream report](JPEGXL_V_SPLINE_STREAMS.md) records pins and limits.
Dequantization, subdivision/rendering, feature/reference frame integration and
production/developer-tool replacement remain. Production JPEG XL and its
native developer test still require Rust.


## JPEG XL spline dequantization on 2026-11-09

Control reconstruction, DCT scaling/correlation, area estimation and adjacent
coincidence add 896 native records. The 244 successful cases compare 33,664
float words and exact area/coincidence results; range and distance failures
match. Both spline files pass default/no-GC/optimized checks with actual exits
zero and 716 unchanged inputs. The package has 291,175 records and 99 files,
cadence 5/10 after the full 94-file checkpoint; no full 99-file run is claimed.
[The dequantization report](JPEGXL_V_SPLINE_DEQUANT.md) records source/fixture
pins and checked API limits. Subdivision, caching/rasterization, feature and
reference frames, and production/developer-tool replacement remain.
Production JPEG XL and its native developer test still require Rust.


## JPEG XL spline arithmetic on 2026-11-09

Cosine and Gaussian error-function approximations add 14,361 distinct native
input records. Explicit scalar/NEON calls exercise 135 differing rounding
results. The focused file passes default/no-GC/optimized checks with actual
exits zero and 719 unchanged inputs. JPEG XL has 305,536 records and 100 files,
cadence 6/10 after the full 94-file checkpoint; no full 100-file run is claimed.
[The spline-math report](JPEGXL_V_SPLINE_MATH.md) records source/fixture pins,
profiles and finite-domain coverage. Curve generation, caching/rasterization,
feature/reference frames and production/developer-tool replacement remain.
Production JPEG XL and its native developer test still require Rust.


## JPEG XL spline curve/cache continuation on 2026-11-09

Subdivision, unit spacing, continuous DCTs and row caches add 256 native
records. The 234 accepted caches compare 3,341 segments and 57,792 ordered
in-bounds indices; NaN payloads normalize explicitly. Three focused files pass
default/no-GC/optimized checks with actual exits zero and 723 unchanged inputs.
JPEG XL has 305,792 records and 101 files, cadence 7/10 after the full 94-file
checkpoint; no full 101-file run is claimed.
[The cache report](JPEGXL_V_SPLINE_CACHE.md) records limits and pins. Gaussian
pixel drawing, complete feature/reference frames and production/developer-tool
replacement remain. Production JPEG XL and its native developer test still
require Rust.


## JPEG XL Gaussian spline rows on 2026-11-09

Gaussian drawing adds 512 native records, with 468 successful raw float images
comparing 2,227,200 words. Both implementations preserve full/chunked equality,
negative sigma and signed zero; 340 nonempty images change and 128 empty-cache
controls do not. Three focused files pass default/no-GC/optimized checks with
actual exits zero and 726 unchanged inputs. JPEG XL has 306,304 records and
102 files, cadence 8/10 after the full 94-file checkpoint; no full 102-file run
is claimed. [The Gaussian report](JPEGXL_V_SPLINE_RASTER.md) records pins and
the fixed fused profile. Feature streams, complete frames, reference ownership
and production/developer-tool replacement remain. Production JPEG XL and its
native developer test still require Rust.


## Rust removed from the build on 2026-11-10

The browser now decodes JPEG XL with the V `jpegxl` package inside a thread
scratch scope. `native_jpegxl_rust/`, `native/include/native_jpegxl.h`,
`tools/test_jpegxl.py`, `tools/native_jpegxl_test.cpp`, the Cargo steps in both
build scripts and the CI Rust toolchain setup are removed. The repository has
no Rust sources or Cargo manifests left.

Before the switch, this round added spline frames, patch reference frames
(with alpha), modular XYB noise, large modular channels and trailing-bit
tolerance. A survey of 278 decodes (WPT, jxl crate tests and libjxl 0.11.1
text images) matches the native output byte for byte for all 196 decodes the
native decoder accepted; only one layered multi-frame file is unsupported.
`images/jpegxl_test.v` passes with the production compiler in its default mode
and with `-prealloc -gc none`. The V decoder remains about 5x slower than the
Rust crate on a 2268x1512 photo (7.97 vs 1.37 billion instructions).
See [the JPEG XL status](../../jpegxl/PORT_STATUS.md#production-decoder-2026-11-10).
