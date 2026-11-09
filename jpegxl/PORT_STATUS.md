# JPEG XL V decoder port

The browser still uses `native_jpegxl_rust/` and `tools/test_jpegxl.py` still
builds that helper. This package decodes complete modular streams, grouped raw
frames and bounded lossless/opaque VarDCT subsets to final RGBA. It does not replace
the production decoder or remove that final Rust dependency yet.

The reference is the installed, lockfile-pinned `jxl` 0.7.0 crate, checksum
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Translated files retain the JPEG XL authors' BSD-3-Clause license in `LICENSE`.

Completed primitives are LSB-first checked/padded bit reading, bounded section
views, zero-padding validation, selected U32 and variable U64 coding, signed
unpacking, finite half floats, Latin-1 names, extension skipping, image/preview
dimensions, bit-depth validation and hybrid integer configurations/values.
The direct bounded byte reader replaces the source's refill cache. Reads after
an error and cached-reader checkpoints are not a source-state parity claim.
Hybrid bit allocations and integer-coder overflow are checked before shifting
or adding. Nonminimal split exponents above the alphabet log are accepted, as
in the pinned source, and have focused regressions. Half-float decoding
preserves the pinned source's subnormal exponent, which is one below IEEE binary16; it is not advertised as a general
IEEE conversion utility.

`testdata/primitives.tsv` has 75,776 independent reference records: every one of
the 65,536 half-float bit patterns and 2,048 deterministic inputs for each of U64,
image size, preview size, bit depth and hybrid configuration. The temporary
migration oracle called the unchanged, cached pinned crate. Every value and
consumed bit count is exact; error messages are normalized to `err`. The fixture
is frozen, so verification requires V alone. Separate tests cover every bit
offset/read width, section isolation, malformed padding, truncation, maximum
U64, signed extremes, extension payloads and Latin-1 names. Both GC modes pass
under separate 3 GiB guards with current V and `-memory-limit 10G -b c -cc clang`.
The initial compile and half-float mismatches were corrected before this result;
no failed attempt receives execution credit.

Signature probing now preserves incomplete-prefix hints, and a complete-input
container extractor handles mandatory file types, version 0 ordered parts,
version 1 out-of-order parts, extended and terminal sizes, skipped auxiliary
boxes and compressed-metadata type restrictions. Input is bounded at 64 MiB.
Whole streams are borrowed views; split streams are assembled once. Tests cover
all signature prefixes and single-bit corruptions, malformed box sizes and
orders, every truncation of a small container, multiple valid part permutations
and byte-exact extraction of the existing independent RGBA container fixture.
The extractor rejects duplicate whole codestream boxes explicitly; malformed
container error/state parity and the source's streaming API are not claimed.
Container checks pass in both GC modes, including a no-GC run with unavailable
Rust compiler paths.

Huffman prefix decoding is now translated, including selected simple trees,
complex code-length trees, repetitions, varint alphabet sizes, multiple context
tables and single-symbol queries. An eight-bit primary lookup plus a bounded
binary tail replaces the source's two-level lookup representation. The 4,096
frozen source cases compare decoded symbols, errors and consumed bits exactly;
1,049 succeed (456 single-symbol alphabets, 529 simple trees and 64 complex
trees). Separate checks decode the source's known byte histogram, exercise
15-bit codes and reject malformed/incomplete/oversubscribed trees. The tests
pass in both GC modes through the V corpus checker with unavailable Rust
compiler paths. Error strings remain
normalized in the fixtures. This establishes recorded behavior, not decoder
conformance or performance parity.

A further 384 frozen hybrid-integer records compare value expansion, consumed
bits and maximum-bit calculations for eight configurations, varied payloads
and symbols through U32_MAX. They pass in default and no-GC modes, alongside
invalid-configuration and truncated-input checks. Ten translated source/license
files were verified against the checksummed crate archive. The corpus runner
checks all completed module tests using V alone.

ANS entropy decoding now covers single/two-symbol, uniform and complex
histograms, repeated/omitted probabilities, alias maps, state renormalization,
context tables and final-state checks. Frozen comparisons contain 4,096
header/symbol/state cases (2,559 with parsed outputs and explicit validity flags) and 49,152 one-step
transitions spanning every alias position for twelve histograms. Values,
consumed bits and states match exactly; parse error messages are normalized.
Known single/two-symbol examples, truncation and checksum failures also pass.
These focused tests run in both GC modes under separate 3 GiB guards, including
unavailable Rust compiler paths. No source records were changed to obtain a pass.

The combined histogram and symbol reader now translates simple and nested
entropy-coded context maps, inverse move-to-front, contiguous-cluster checks,
Huffman/ANS dispatch, hybrid expansion, signed reads and LZ77. LZ77 preserves
all 120 special distance codes, checked width arithmetic, distance/history
clamping, overlapping copies, the bounded 1,048,576-entry window and deferred
repeat/overflow errors. Its window grows lazily, unlike the source's up-front
reservation. Resizing context maps preserves the original distance cluster.

Frozen comparisons add 5,656 histogram/symbol records (2,105 with parsed outputs and
explicit final validity) and 4,098 context maps (1,618 accepted). They compare metadata,
cluster maps, values, validity and consumed bits exactly. Constructed cases
cover all 128 direct/special distance symbols at six widths, before/after
context padding, first-token repeats and copy-length overflow. The source's
256-cluster map is exercised with and without MTF. Ring wrap and overlapping
copies have separate checks. Both GC modes pass under 3 GiB guards, including
unavailable Rust compiler paths. The source oracle completed without panic;
no successful or error records were overridden. These comparisons also exposed
and corrected early Huffman alphabet-size validation and overly restrictive
hybrid selectors; their regressions are committed separately.

The entropy reader also has bounded checkpoints. It snapshots only the ring
positions that speculative decoding may overwrite, then restores copy counters,
ANS state and deferred errors. Eighty-four frozen source checkpoint/replay
transcripts cover Huffman/ANS, LZ77, padded maps, in-flight copies and error
states. Ring-wrap, bound and type-mismatch checks run separately. Default and
no-GC checks pass; excessive rewinds return an error instead of slicing beyond
the checkpoint. The BitReader cursor remains the caller's separate snapshot.

File headers and metadata now translate extra channels, orientation geometry,
intrinsic/preview sizes, animation timing flags, bit depth, color descriptions,
white-point/primary validation, gamma and tone mapping, extensions, custom
opsin matrices and all three upsampling kernels. Parsing accepts metadata for
unsupported animation/wide-gamut images so the eventual decoder can apply its
existing policy; it does not add pixel support for those formats.

The new header corpus has 6,184 source records (3,420 accepted), including all
seventeen named extra-channel kinds, every custom-weight mask and the seven
existing browser JPEG XL fixtures. Source-public metadata fields are compared
explicitly; complete transform float bit patterns and complete file serializers
are compared by SHA-256 to keep the fixture compact. Names/CFA fields also have
known-input checks. Every record checks consumed bits, and error strings remain
normalized. The RGBA container and bare stream agree, rotated dimensions map
correctly and all eight orientations have pixel/rectangle/row-step checks.
Truncated names and extension payloads now preserve source bit consumption,
with separate focused regressions.

Frame parsing now translates frame types, encoding/flags, JPEG sampling,
upsampling and extra-channel postprocessing, multipass settings, crops,
blending/reference state, animation timing, names and restoration parameters.
Derived dimensions, group/LF-group rectangles, TOC counts, sampling predicates,
visibility and smoothing flags match the source. A constructor supplies fixed
restoration arrays to avoid the current compiler's nested-array-default C issue.

Frozen comparisons add 4,134 complete raw/postprocessed frame records and
1,024 pass/bracket records. They include all restoration setting combinations
and the six bare browser fixtures. File/preview contexts use their own encoded
sizes and animation/extra-channel metadata. The Guardian fixture begins with a
non-visible modular LF frame; it is preserved as a dependency for later frames.
Errors and consumed bits are compared, with SHA-256 over the documented full
frame serializer. Default and no-GC focused checks pass under separate 3 GiB
guards, including unavailable Rust compiler paths. The initial C compilation
and test-serialization errors were corrected without changing source records.

Permutation and TOC parsing now translate entropy-coded Lehmer ranks, skipped
prefixes, composition, byte alignment, entry-size coders and incremental read
state. A bounded order-statistics tree replaces naive removal. The V entry cap
is 16,777,216; invalid API sizes, ranks and indices return errors. Section views
remain bounded and use local cursors, while the parent advances through the physical payloads;
logical section order follows the source permutation.

Comparisons add 2,424 complete TOCs, 2,424 incremental state transcripts,
576 entropy permutations/compositions and seven fixture frame/section records.
The latter walk all six bare fixtures and both Guardian frames, from its modular
LF frame to the visible VarDCT frame that references it, with exact payload bytes
and parent positions. All checks pass in both GC modes. The source does not
finalize the isolated permutation symbol reader's ANS/deferred-error state;
this behavior is retained, rather than claimed as full bitstream validation.
A separate regression preserves source EOF consumption after section splitting
fails. These TOC checks locate sections rather than establish final pixels.

Modular group headers now parse global-tree selection, weighted-predictor
coefficients, reversible color transforms, palettes and explicit/automatic
squeeze parameters. The 8,289 frozen reference records compare every field,
validation result and consumed bit count, including all RCT selectors and
palette predictor IDs. Empty squeeze lists retain their automatic-transform
meaning. Default and no-GC focused checks pass under separate 3 GiB guards,
including unavailable Rust compiler paths. Tiled application remains separate work.

All fourteen modular predictors now run in V, with source border-neighbor
substitutions, interior-row updates, signed division and selection tie behavior.
The weighted predictor retains its four adaptive error estimates, two-row
buffers, error property, integer reciprocal weights and source row persistence.
Signed 32-bit extremes preserve the release source's wrapped intermediate
product. Invalid coordinates, coefficients and widths above 1,048,576 return
errors; this is a bounded V API rather than unrestricted source API parity.

The predictor corpus adds 4,934 source cases: 4,112 inputs exercise all fourteen
predictors, 702 compare neighbor gathering/updates, and 120 weighted transcripts
compare 11,520 prediction/error steps, 360 saved row buffers and 240 restores.
The exact, archive-verified source file was included unchanged in a temporary
migration oracle; it is not a new runtime or developer-tool dependency.
Default and no-GC focused checks pass, including unavailable Rust compiler paths.
These are predictor comparisons, not complete modular image decoding.

Inverse reversible color transforms now cover all 42 operation/permutation
combinations in signed 16-bit and 32-bit storage, for samples and separate
channel rows. The source's wrapped additions, arithmetic shifts and differing
16-bit/32-bit averaging behavior are retained. A further 2,048 frozen inputs
compare all 84 outputs exactly, including signed extremes; row and invalid-API
checks pass in both GC modes. The independent oracle used unchanged arithmetic
and permutation functions extracted from the archive-verified source with its
scalar SIMD descriptor. There is no SIMD or performance parity claim.

Modular decision trees now parse split/leaf nodes, predictor IDs, offsets,
multipliers and the output entropy histograms. Source breadth-first child and
leaf numbering, inclusive size limits, property-range validation and the
2,048-edge depth limit are preserved. Iterative validation keeps only the
current path's ranges. Tree walking handles threshold ties and rejects invalid
indices, absent properties and cycles. The V reader bounds the caller's size
limit at 131,070 so the resulting entropy map fits its 65,536-context limit.

The 747 frozen tree records compare every node, histogram metadata, eight output
symbols, validity and consumed bits; 488 parse successfully. Predictor/multiplier
errors, empty ranges and caller size limits are included. Separate checks cover
both sides of the depth bound. Default and no-GC checks pass.

Pixel property calculation now preserves the static channel/stream IDs, row
gradient history, wrapped signed neighbors, weighted error property and prior
channel references. Residual reconstruction preserves release wrapping.
Comparisons add 4,096 residual/guess cases and 32 stateful property transcripts
covering 1,536 steps and all 256 property slots.

Selected modular channels now decode through the entropy reader, decision tree
and predictors, preserving empty channel numbering, nearest compatible prior
channels and 16-bit storage with untruncated rolling prediction rows. The 952
source comparisons cover all predictors, reference properties, Huffman/LZ77 and
constant ANS streams; 924 succeed and 28 fail the expected final checksum.
The independent oracle exercises the source's generic FullTree branch, with a
minimal image-buffer carrier. Specialized trees, fast lossless paths and
streaming-error state are not parity claims.

Palette expansion now handles explicit entries, all 143 implicit deltas and both
color cubes, bit-depth scaling, extra channels, predictor deltas, weighted error
updates and single-channel partial-index clipping. There are 360 frozen lookup
vectors (217,800 exact values) and 224 complete single-grid expansions in both
storage widths. Tiled borders and auxiliary row handoff remain pending.

Scalar horizontal/vertical squeeze reconstruction now handles monotonic
tendencies, signed rounding, stored-neighbor narrowing and odd trailing samples.
There are 8,192 sample-pair and 1,024 whole-plane source comparisons. The caller
supplies output shift metadata; tiled borders, smooth-squeeze
application and equivalence to the source SIMD paths remain pending.

Transform planning now preserves channel metadata, automatic squeeze ordering,
palette sample budgets, stable buffer identities and reverse reconstruction.
Empty physical buffers retain the logical dimensions needed by singleton
squeeze axes. There are 1,024 frozen planning records (722 accepted) and 256
composed reconstruction cases in both storage widths. Caller samples remain
independently owned.

Complete modular streams now select local/global trees, parse missing headers,
avoid reapplying provided global transforms and validate final entropy state.
All-empty streams consume no header. The 303 frozen stream cases include local
transforms, global selection, every-byte truncations and six source fast-lossless
RLE cases; 234 succeed. Successful consumed bits and samples match exactly;
cached-reader cursor parity after errors is not claimed. The V tree cap remains
131,070 nodes so leaf contexts fit the entropy map.

LF quant factors now parse with exact f32 values and reciprocals in 4,096 source
cases (2,312 accepted). Small modular global sections derive color/extra-channel
geometry, select the optional global tree, decode all coded channels and undo
global transforms. Twelve comparisons check every raw sample from the first
frame of six existing fixtures in both storage widths. Guardian's first frame
is a non-visible 13x13 LF dependency; its visible VarDCT frame remains pending.
Rotated, animated and wide-gamut fixture metadata does not establish support for
their final pixel output.

Remaining work includes partial/tiled rendering, VarDCT and frame dependencies,
patches/noise/splines, XYB/transfer conversion, frame color/filter
pipeline assembly and browser
integration. Container/API streaming
remains a broader parity task.

Output sample conversion now normalizes integer rows, premultiplies alpha and
quantizes floats with the source's positional blue-noise dither. Native
round-to-nearest-even, clamping and RGBA channel offsets are preserved. The
4,926 whole-row comparisons include all 65,536 color/alpha pairs for each RGB
channel, all integer depths and constructed rounding ties. The unchanged dither
table retains its original attribution in `DITHER_NOTICE.md`. Source scalar
fallback tie behavior and final frame output remain separate boundaries.

`decode_small_lossless_rgba` now connects container/file/frame/TOC parsing,
small global planes, sample conversion, alpha and all eight orientations. It
returns owned straight or premultiplied RGBA rows for one full, unfiltered,
single-group 8-bit sRGB/gray modular frame with at most one full-size alpha
channel. It rejects unsupported services explicitly; the production decoder
accepts a broader set of static images. Preview/ICC/XYB/YCbCr, grouped frames,
resampling, filters, extra-channel services, composition and unhandled trailing
payloads are outside this entry point.

The final-pixel corpus has 498 complete-file cases from the existing pinned
production helper: 24 accepted outputs and 474 rejections. Every byte, size and
pitch matches, including containers, all orientations, straight hidden colors
and positional premultiplication. Every-byte prefixes of four valid fixtures
are rejected in both output modes. A separate check rejects Guardian's pending
LF/VarDCT chain rather than returning its non-visible first frame.

`plan_modular_sections` now preserves the leading global-channel prefix, LF and
per-pass shift brackets, tile edges, skipped empty tiles and source stream IDs.
Its 512 frozen source records compare channel order, sampled group rectangles
and stream identities across all group-size shifts and varied passes.

`decode_modular_frame` stitches LF/HF coded tiles, applies group-local transforms,
then reverses the global transform graph over complete planes. Every coded
channel must have a unique section and complete sample coverage. Empty section
payloads are ignored when there are no coded pixels, as in the pinned source;
active entropy streams still validate their final state and bounds. Combined
single-group sections remain supported.

`decode_lossless_rgba` extends final RGBA output to grouped and multipass modular
frames under the same static 8-bit sRGB/gray, alpha, sampling and filter limits.
The existing small-only API retains its group limit. Thirteen independent
fixtures have 26 exact whole-output comparisons in both modes, including local
trees, shared global trees, squeeze transforms, LF data, reordered sections,
odd tile edges, gray/RGB/RGBA, all orientations and a two-pass stream with coded
HF data deferred to the final pass. SHA-256 covers every output byte; dimensions
and pitch are compared separately. Production supports additional static images
and continues to use Rust until those paths and integration are complete.

Floating-point stages now have a pure V binary32 fused multiply-add helper. It
uses binary64 for ordinary cases and exact fixed stack limbs at binary32
midpoints, avoiding double rounding without a native FMA call. All 35,008 source
records match, including signed zeros, subnormals, overflow, cancellation and
512 constructed midpoint cases. NaN payloads are normalized to a class check.

Whole-plane Gaborish filtering, horizontal/vertical chroma upsampling and YCbCr
to RGB now preserve native source arithmetic order and fused rounding. Their
512, 384 and 512 frozen plane records compare every f32 output word. Border
replication, doubled extents, Cb/Y/Cr input order and unclipped RGB are retained.
Output samples are independent; shape/weight/size limits have focused checks.
These stages are not connected to the complete-file rendering path yet, and do
not lift its filter, resampling or YCbCr restrictions.

All three EPF passes now preserve reflected borders, five-point SAD ordering,
forward weight sums and pass-specific output accumulation. Constant or 8x8-block
inverse sigma, block-border scales, exact threshold comparisons and per-pixel
bypass match native source outputs. There are 512 frozen planes per pass, with
229,311 output f32 words in total. Modular positive sigma has a checked conversion
helper. VarDCT sigma is now derived from quantization/transform/sharpness maps
as described below. These stages remain separate from complete-file rendering.

VarDCT quantizer and color-correlation parameters now preserve source selectors,
binary32 arithmetic, signed LF factors, half-float behavior and error positions.
Block contexts parse LF/QF thresholds and entropy maps, preserve wrapping LF
threshold encodings and channel ordering, and calculate nonzero/zero-density
contexts. All thirteen natural coefficient orders and their three-component
entropy permutations are translated, with independent owned output arrays.
The four slices add 17,165 frozen source cases, including 131,328 natural indices
and complete hashes of all 39 component orders for each accepted decoding case.
They do not yet decode VarDCT coefficients or enable VarDCT complete-file output.

All twenty-seven transform IDs now have source geometry, coefficient shape and
quantization-table mappings. Adaptive LF smoothing preserves scalar rounding,
shared channel gaps and unchanged outer borders. VarDCT EPF sigma generation
uses whole transform coverage, raw quantization and per-block sharpness, and
returns the existing filter stages' inverse-sigma plane without SIMD padding.
The checked V API rejects incomplete/overlapping/out-of-bounds maps.

DCT distance-band parsing retains complete-row validation and the quantization
half converter's nonfinite classes; weight-matrix validation remains a later
step. LF reconstruction accepts already-decoded modular Y/X/B integer channels,
applies source dequantization and extra precision, performs color correlation
only for 4:4:4, and derives full-size LF context buckets for all sampling modes.
These five slices add 5,890 source cases, including 328,098 smoothing words,
28,581 sigma words, 60,716 LF words and 35,781 LF context indices. VarDCT global
and LF stream assembly, HF coefficient decoding/inverse transforms,
quantization matrices and complete-file pipeline integration were still pending
at that checkpoint.

Non-raw quantization encodings now parse library, identity, DCT2, DCT4, DCT4x8,
AFV and DCT modes with source table-size restrictions and per-mode scaling.
Their 4,096 additional source cases compare all seventeen table dimensions,
complete records and cursors. Raw modular quantization streams and matrix
generation were still pending at that checkpoint.

The full forty-five-file checkpoint passed through the V corpus checker in both
GC modes with unavailable Rust compiler paths, completing the next ten-slice
checkpoint and resetting JPEG XL cadence to 0/10 at that point. Focused optimized
checks also covered those new files. Unrelated broader suites were not rerun.
That checkpoint checked 267,769 source cases, counting individual ANS alias transitions and whole stateful/map/order
transcripts as before. [The VarDCT parameter/order report](../docs/translation-audit/JPEGXL_V_VARDCT_PARAMETERS.md)
records current validation and boundaries; [the EPF report](../docs/translation-audit/JPEGXL_V_EPF.md)
retains the preceding full checkpoint.

Quantization matrices now execute entirely in V: all seventeen default
calibrations, distance-band interpolation, identity/DCT2/DCT4/DCT4x8/AFV placement,
raw matrices, local/global modular stream integration and full matrix-set parsing.
All twenty-seven transform lookups return independently owned channel slices.
HF coefficient dequantization preserves signed 16/32-bit storage, quantization
bias, channel scales and fused color correlation. The first inverse-transform
slice reconstructed Hornuss identity and DCT2X2 blocks from LF/HF coefficients.

These six slices add 3,136 independent source records, bringing the package to
270,905 records and fifty-one test files. Every new focused file passes in both
GC modes and under `-prod`, with unavailable Rust compiler paths. This is
6/10 after the forty-five-file checkpoint; no newer full-package checkpoint is
claimed. [The quantization report](../docs/translation-audit/JPEGXL_V_QUANTIZATION.md)
records exact comparison boundaries, source pins and executed checks. HF
entropy decoding, remaining inverse transforms, LF/global/frame assembly,
XYB/transfer conversion, frame dependencies and production integration remained.

Four later slices translate every 2/4/8/16/32-point inverse DCT kernel, all
thirteen source plane geometries, DCT4X4/DCT4X8/DCT8X4 subblock reconstruction,
and LF injection for all eighteen ordinary DCT kinds. At that checkpoint,
complete inverse output covered fourteen transform kinds through 32x32, with
LF coefficient injection through 256x256. Axis order, transpose rules, coefficient placement and
source scalar/fused arithmetic choices are preserved.

These four slices add 5,504 independent records and compare 705,728 exact output
words, bringing the package to 276,409 records and fifty-five test files.
[The inverse DCT report](../docs/translation-audit/JPEGXL_V_INVERSE_DCT.md) records
the focused checks, full checkpoint and remaining production work.
All fifty-five files pass through the V corpus checker in both GC modes with
unavailable Rust compiler paths. Actual tests, inner guards, drivers and outer
guards exit zero, completing the ten-slice continuation and resetting JPEG XL
cadence to 0/10. Focused optimized checks also pass. Compiler and all 219
selected input hashes/change times remain unchanged across the full selections.

Two subsequent slices complete the large 64/128/256-point kernels, all nine
large plane geometries and all four AFV orientations. All twenty-seven transform
kinds now reconstruct from typed LF/HF coefficients, including ordinary DCTs
through 256x256. The 2,486 added records compare 1,220,608 output words; the
package now has 278,895 records and fifty-seven test files. Focused checks pass
in both GC modes and under `-prod`. This is 2/10 after the fifty-five-file
checkpoint; no full fifty-seven-file pass is claimed. The continuation in
[the inverse DCT report](../docs/translation-audit/JPEGXL_V_INVERSE_DCT.md#large-dct-and-afv-continuation)
records the source and ownership boundaries, input identities and checks.
At that point, HF entropy decoding, LF/global/frame assembly, XYB/transfer
conversion, frame dependencies and production integration remained.

Eight further slices decode actual HF channel entropy, HFGlobal pass orders and
histograms, nonzero maps and complete progressive group coefficient buffers;
they also reconstruct group pixel planes, convert XYB to linear RGB, apply both
sRGB transfer directions and prepare sRGB/gray output matrices. All twenty-seven
transform kinds, both coefficient widths, normalized chroma modes, partial pass
lists and per-tile color correlation occur in the independent reference cases.

The 2,658 new records bring this checkpoint to 281,553 source records and
sixty-five test files. All eight new files pass focused default/no-GC and
optimized checks with unavailable Rust compiler paths. The full selections pass
all sixty-five files in both GC modes, with actual test, inner guard, driver and
outer guard exits zero. All 249 selected input hashes/change times and the
compiler pin stay unchanged. This completes the ten-slice checkpoint and resets
JPEG XL cadence to 0/10. [The HF/color report](../docs/translation-audit/JPEGXL_V_HF_ENTROPY.md)
records complete transcript comparisons, source adapters, error/EOF boundaries
and the remaining 65,536-entry entropy context budget.

A subsequent signed-zero fix preserves Rust's negative-zero identity in gray
matrix sums. Eight additional source cases leave the original 128 output-color
records unchanged. The corrected file passes both GC modes and `-prod`; all
other full-checkpoint inputs remain unchanged. The package now has 281,561
records and sixty-five files, at cadence 1/10 after that checkpoint. The report
distinguishes the prior full selections from these focused correction checks.

At that checkpoint, LF/HF metadata entropy and global/frame assembly, feature
streams, frame dependencies/composition, final resampling and production
integration remained. Typed-stage reconstruction does not establish complete-file
VarDCT pixels or preserve every source-supported image yet.

Three subsequent slices reconstruct HF metadata and connect its modular stream
and the VarDCT LF stream. Metadata maps preserve transform/QF/color/sharpness
clamping, source storage widths, group boundaries, subsampling restrictions and
unused records. LF reading preserves Y/X/B channel order, extra precision,
sampling, context thresholds and the distinct LF stream identities. The 256 new
source cases add 773,525 exact metadata words; constructed packet checks verify
composition of the already referenced modular and LF stages.

The package now has 281,817 source records and sixty-eight test files. The final
six-file focused selection passes in both GC modes; optimized validation is
recorded in [the LF stream report](../docs/translation-audit/JPEGXL_V_LF_STREAMS.md).
Cadence is 4/10 after the sixty-five-file checkpoint; no full sixty-eight-file
pass is claimed. Global/frame assembly, frame dependencies/composition, feature
streams, final image resampling and production integration remain.

Six more slices connect LFGlobal/HFGlobal state, explicit LF/HF group ownership,
complete VarDCT frame planes, restoration and `decode_vardct_rgba`. The new
complete-file entry point handles opaque 4:4:4 frames with combined or separate
sections, global modular trees, LF reconstruction/smoothing, all progressive
passes, HF reconstruction, cropping, restoration, XYB/sRGB or YCbCr conversion,
dithering and orientation. It rejects unsupported LF references, extra channels,
resampling, feature streams and frame composition; the production caller is
unchanged.

Twenty constant and four nonuniform authored codestreams match every RGBA byte
from the pinned native decoder. They include odd dimensions, multiple HF/LF
groups and actual smoothing/restoration color transitions. HF coefficients in
this new whole-file cohort are zero, so these records do not establish general
whole-file conformance. The source case count is now 281,841 across seventy-four
test files. Focused default/no-GC and optimized checks pass. All seventy-four
files also pass through the V corpus checker in both GC modes, with actual
tests, inner guards, drivers and outer guards exiting zero. Compiler and all
294 selected input hashes/change times stay unchanged. This completes the
ten-slice checkpoint and resets cadence to 0/10.
[The frame-assembly report](../docs/translation-audit/JPEGXL_V_FRAME_ASSEMBLY.md)
records exact coverage, limits, input identities and executed results.

Four later slices add modular XYB conversion, shared restoration, explicit
VarDCT LF plane dependencies and complete-file LF reference ownership. LF level
N saves restored source-space floats in slot N-1; VarDCT level N reads slot N,
skipping LF entropy and smoothing and retaining zero quant-LF contexts. Both
modular XYB and VarDCT LF frames can supply the bounded 4:4:4, unit-upsampled
opaque output path. The existing Guardian photo now matches all 38,416 native
RGBA bytes exactly, including its nonzero HF content. The prior 24 image
references remain exact. Another 512 source cases compare all 130,560 modular
XYB float words exactly, preserving integer storage wrapping and f32 sum order.

The count is now 282,354 source records and seventy-eight test files. The final
seven-file focused selection passes both GC modes and `-prod`, with tests and
3 GiB guards exiting zero and all 299 inputs unchanged. Cadence is 4/10 after
the full seventy-four-file checkpoint; no full seventy-eight-file run is
claimed. See [the LF reference report](../docs/translation-audit/JPEGXL_V_LF_REFERENCES.md).

Two further slices add 2x/4x/8x image upsampling, including source FMA order,
reflected borders, neighborhood clamping and custom kernels. Frame rendering
filters at coded resolution and upsamples before color conversion/LF saving.
Another 384 source cases compare 246,656 complete float words exactly, and 15
native whole-image references compare 1,933,816 RGBA bytes exactly. The count
is now 282,753 source records and eighty test files. The final five-file
selection passes both GC modes and optimized checks with 320 unchanged inputs
and actual test/guard exits zero. A shared compiler change invalidated an
earlier regression run; final checks use the new pinned compiler throughout.
Cadence is 6/10; no full eighty-file run is claimed.
See [the upsampling report](../docs/translation-audit/JPEGXL_V_UPSAMPLING.md).

Two additional slices skip one visible final embedded preview before VarDCT
or lossless output, matching the native API's default policy. Header/TOC and
sample bounds are checked while preview entropy remains undecoded. Eight new
native files cover valid/poisoned preview payloads, straight/premultiplied alpha,
gray and orientation. The count is now 282,761 source records and eighty-two
test files. Focused checks pass both GC modes and optimized builds. The final
lossless four-file selection has 333 unchanged inputs and test/guard exits
zero. A corrected option assertion contributes a fresh default preview-file
pass to the three retained image-file passes; the original failed default
batch receives no whole-run pass credit. Cadence is 8/10, with no full
eighty-two-file run claimed.
See [the preview report](../docs/translation-audit/JPEGXL_V_PREVIEWS.md).

Non-visible preview dependencies, wider reference composition, extra channels/
alpha in VarDCT, whole-frame chroma sampling, feature streams, large entropy
maps and production integration remain.

The V package is not connected to the production image path until
it can preserve that path's supported static 8-bit sRGB/gray behavior, limits
and rejection rules. The Rust decoder and its build/test dependencies must then
be removed together.
