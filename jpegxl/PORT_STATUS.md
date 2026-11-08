# JPEG XL V decoder port

The browser still uses `native_jpegxl_rust/` and `tools/test_jpegxl.py` still
builds that helper. This package is the tested foundation for replacing it;
it does not decode image pixels or remove that final Rust dependency yet.

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
in the pinned source, and have focused regressions. Half-float decoding preserves the pinned source's subnormal
exponent, which is one below IEEE binary16; it is not advertised as a general
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
The complete three-file module suite passes in both GC modes, including a
no-GC run with unavailable Rust compiler paths.

Huffman prefix decoding is now translated, including selected simple trees,
complex code-length trees, repetitions, varint alphabet sizes, multiple context
tables and single-symbol queries. An eight-bit primary lookup plus a bounded
binary tail replaces the source's two-level lookup representation. The 4,096
frozen source cases compare decoded symbols, errors and consumed bits exactly;
1,049 succeed (456 single-symbol alphabets, 529 simple trees and 64 complex
trees). Separate checks decode the source's known byte histogram, exercise
15-bit codes and reject malformed/incomplete/oversubscribed trees. At the Huffman checkpoint, all four
module test files passed in both GC modes; the no-GC run also passes through the
V corpus checker with unavailable Rust compiler paths. Error strings remain
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
header/symbol/state cases (2,559 accepted by the source) and 49,152 one-step
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

Frozen comparisons add 5,656 histogram/symbol records (2,105 accepted by the
source) and 4,098 context maps (1,618 accepted). They compare metadata,
cluster maps, values, validity and consumed bits exactly. Constructed cases
cover all 128 direct/special distance symbols at six widths, before/after
context padding, first-token repeats and copy-length overflow. The source's
256-cluster map is exercised with and without MTF. Ring wrap and overlapping
copies have separate checks. Both GC modes pass under 3 GiB guards, including
unavailable Rust compiler paths. The source oracle completed without panic;
no successful or error records were overridden. These comparisons also exposed
and corrected early Huffman alphabet-size validation and overly restrictive
hybrid selectors; their regressions are committed separately.

Remaining work includes streaming/checkpoints, metadata/color headers, modular prediction/transforms, VarDCT,
filtering, color conversion, orientation, exact alpha quantization and browser
integration. The V package is not connected to the production image path until
it can preserve that path's supported static 8-bit sRGB/gray behavior, limits
and rejection rules. The Rust decoder and its build/test dependencies must then
be removed together.
