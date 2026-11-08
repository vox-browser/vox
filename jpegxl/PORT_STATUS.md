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
Invalid hybrid split selectors and integer-coder overflow are rejected before
shifting or adding. Half-float decoding preserves the pinned source's subnormal
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

Remaining work includes streaming/checkpoints, metadata/color headers, prefix/ANS
entropy decoding and context maps, modular prediction/transforms, VarDCT,
filtering, color conversion, orientation, exact alpha quantization and browser
integration. The V package is not connected to the production image path until
it can preserve that path's supported static 8-bit sRGB/gray behavior, limits
and rejection rules. The Rust decoder and its build/test dependencies must then
be removed together.
