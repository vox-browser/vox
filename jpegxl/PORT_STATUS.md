# JPEG XL V decoder port

The browser still uses `native_jpegxl_rust/` and `tools/test_jpegxl.py` still
builds that helper. This package decodes complete modular streams, grouped raw
frames and a bounded lossless subset to final RGBA. It does not replace
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
patches/noise/splines, filtering, broader pixel color conversion and browser
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

The corpus checker discovers twenty-eight test files. The preceding twenty-five
file package passed in both GC modes at the ten-slice checkpoint; subsequent
work passes focused checks in both modes with unavailable Rust compiler paths.
JPEG XL cadence is 3/10 after that checkpoint; unrelated broader
suites were not rerun. The package checks 202,666 source cases, counting
individual ANS alias transitions and whole weighted/property/row transcripts.
[The grouped frame report](../docs/translation-audit/JPEGXL_V_GROUPED_FRAMES.md)
records the current scope; [the output sample report](../docs/translation-audit/JPEGXL_V_OUTPUT_SAMPLES.md)
records the preceding full checkpoint.

The V package is not connected to the production image path until
it can preserve that path's supported static 8-bit sRGB/gray behavior, limits
and rejection rules. The Rust decoder and its build/test dependencies must then
be removed together.
