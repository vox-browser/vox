# JPEG XL V entropy and header translation, 2026-11-09

The V package now implements ANS, combined Huffman/ANS symbol decoding, context
maps, LZ77, bounded entropy checkpoints and complete file/metadata/transform
headers. The browser still calls the Rust pixel decoder. No Cargo build hook or
native JPEG XL test tool was removed during this slice, and no pixel-decoding
or production-browser conformance is claimed.

The unchanged reference is lockfile-pinned `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The three entropy sources and seven header/color/matrix sources read for this
slice were verified byte-for-byte against that archive. Temporary probes linked
the cached pinned crate and were removed after recording the results. Frozen
fixtures require V alone; they do not derive expectations from the candidate.

## Completed behavior and evidence

| Layer | Independent source cases and focused checks |
| --- | --- |
| ANS | 4,096 table/symbol/state transcripts, including errors and final-validity flags; 49,152 one-step transitions cover all 4,096 alias positions for twelve histograms. Single/two-symbol, uniform and complex distributions, repetitions, omitted probabilities and state renormalization are exercised. |
| Combined entropy | 5,656 histogram/symbol transcripts compare cluster maps, metadata, values, final-validity flags and consumed bits. The reader dispatches Huffman/ANS, expands hybrid integers and handles LZ77's deferred errors. |
| Context maps | 4,098 simple/nested/MTF records include contiguous-cluster validation and source maps spanning all 256 clusters. |
| LZ77 | Constructed transcripts cover all 128 direct/special distance symbols at six image widths, before and after context padding, first-token repeats and copy-length overflow. Separate tests cover overlapping copies and the 1,048,576-entry ring wrapping. |
| Checkpoints | 84 source transcripts compare warm-up, speculation and replay across Huffman/ANS, LZ77, in-flight copies, padded maps and error states. Separate checks verify wrapped history, bounds, type rejection and unchanged state after an invalid restore. |
| Headers | 6,184 records cover file/metadata/color/extra-channel/transform parsing, all seventeen named extra-channel kinds, every custom-kernel mask and the seven existing browser fixtures. Public metadata fields and consumed bits compare exactly. Complete transform float words and file serializers compare by SHA-256; names/CFA values have known-input checks. |
| Orientation | All eight orientations map explicit pixel grids, rectangles and row steps; the existing orientation-6 fixture maps its encoded 3×2 dimensions to 2×3. |

The new cases total **69,270**, counting individual alias transitions. Together
with the prior primitive, hybrid-value and Huffman records, the V package checks
**149,526** source cases. Parse errors are normalized to `err`; validity flags
remain explicit, so a parsed histogram followed by an invalid ANS checksum does
not count as a valid image. Successful and failing source records have no
candidate-specific overrides or tolerance changes. File/transform digests cover
the documented serializer, not an assertion about untranslated pixel output.

Three foundation corrections were committed separately: retain source-accepted
nonminimal hybrid split selectors; read all Huffman alphabet sizes before
validating them; and consume available truncated name/extension data before
returning the source-compatible bit position. The initial failing comparisons
and test compilation attempt were corrected before final validation and receive
no passing execution credit.

## Verification

Current V (`0.5.2 ccb7729`) used `-memory-limit 10G -b c -cc clang`; the corpus
checker also supplies `-enable-globals`. Each expensive command ran under
`tools/run_memory_bounded.py` with a separate 3 GiB process-tree guard. GC modes
ran sequentially. All nine files passed with exit 0 in each mode; outer guard
peak RSS was 355,516,416 bytes for default GC and 263,864,320 bytes with no GC. Focused checks exercised each completed feature and its
regressions. The final package checks execute all nine test files through:

```sh
check-corpora --suite jpegxl --gc boehm --compiler /Users/alex/code/v/v
check-corpora --suite jpegxl --gc none --compiler /Users/alex/code/v/v
```

`check-corpora` is the temporary binary compiled from the canonical
`tools/check_translation_corpora.v`, also under the guard. Both commands run
with `RUSTC=/nonexistent/rustc` and `RUST_CARGO=/nonexistent/cargo`. Routine
verification needs no Rust compiler or native JPEG XL helper. The temporary
binary, source probes, logs, receipts and locks were removed under the Build
scratch policy after recording the results here. Sampled memory totals are
process-tree observations rather than kernel allocation limits or leak proofs.
No browser build was scheduled or launched; these V modules are not yet wired
into production image decoding. Unrelated LibJS suites were not rerun for this
JPEG XL-only change, so prior ICU casing failures remain historical evidence.

## Boundaries and remaining work

The entropy window grows lazily rather than reserving 4 MiB up front.
Checkpoints save only the caller's bounded overwrite interval and return an
error for excessive rewinds; the caller saves the BitReader cursor separately.
Context counts and nesting have explicit V safety bounds. Cached-reader state
after errors, SIMD layout and performance parity are not claimed.

Metadata records animation and wider color profiles so the eventual image
entrypoint can preserve the current decoder's rejection policy. It does not
render those formats. Frame headers/TOCs, modular prediction and transforms,
VarDCT, filters, pixel color conversion, oriented RGBA output, exact alpha
quantization and browser integration remain. Full streaming is a broader API
parity task; the current browser helper accepts complete inputs. Rust build,
CI and developer-test dependencies must be removed together once the V decoder
preserves supported static 8-bit sRGB/gray images and existing resource limits.

See [JPEG XL status](../../jpegxl/PORT_STATUS.md) and
[the Rust-to-V progress report](RUST_TO_V_PROGRESS.md).
