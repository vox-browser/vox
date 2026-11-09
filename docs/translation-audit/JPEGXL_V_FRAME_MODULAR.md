# JPEG XL V frame and modular translation, 2026-11-09

The V package now reads frame headers, restoration settings, permutations,
section tables, modular group/transform headers and modular decision trees.
It also implements all fourteen modular predictors, weighted error state and
the 42 inverse reversible color transforms. Production still uses the Rust
pixel decoder; this continuation does not finish removing Rust dependencies.

The reference remains lockfile-pinned `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The frame, TOC, permutation, modular-header, predictor, reversible-color and
tree source files used here were byte-verified against that archive.
Temporary oracles called the unchanged cached crate. The predictor oracle
included its verified source file unchanged; the RCT oracle used unchanged
arithmetic/permutation functions and the cached source scalar SIMD descriptor,
with a minimal channel-data carrier for permutation. Those checks establish
numeric output, not the source's image-buffer or transform-dependency graph.
No new Rust runtime/tool dependency is introduced. Frozen fixtures need V alone.

## Source comparisons

| Layer | Frozen cases and compared behavior |
| --- | --- |
| Frames/restoration | 4,134 raw/postprocessed frame records and 1,024 pass/bracket records. Complete frame serializers compare by SHA-256; every consumed bit count is checked. Restoration combinations, extra-channel postprocessing, crops, animation/reference state and derived geometry are included. |
| TOCs/permutations | 2,424 complete TOCs, 2,424 incremental state transcripts and 576 permutations/compositions. Sizes, Lehmer ranks, skipped prefixes, alignment and partial-read state match exactly. |
| Fixture sections | Seven frame/section records walk six bare browser fixtures. Guardian's first modular LF frame and following visible VarDCT frame are both retained, including their dependency. Payload bytes and parent positions are exact; pixels are not decoded. |
| Modular headers | 8,289 weighted, squeeze, RCT, palette and group-header records compare every field, success/error result and consumed bit count. All RCT selectors and palette predictor IDs are exercised; an empty squeeze list means automatic squeeze. |
| Predictors | 4,112 inputs each compare all fourteen scalar predictions and full-row requirements. Another 702 cases compare border-neighbor gathering and interior updates. Signed division, selection ties and signed 32-bit extremes are retained. |
| Weighted predictor | 120 transcripts compare 11,520 prediction/error steps, 360 saved row buffers and 240 restores. They include default, zero, maximum and custom coefficients, narrow/wide rows, raster/arbitrary positions and full signed samples. A transcript counts as one source case. |
| Reversible color | 2,048 inputs each compare all 42 transforms in both signed storage widths: 172,032 triplet outputs. Source wrapping and the differing 16-bit/32-bit averaging rules are exact. Separate channel-row checks use the same independent expected outputs. |
| Modular trees | 747 complete node/histogram/eight-symbol records, 488 parsed. Predictor/multiplier validation, property ranges, breadth-first numbering and inclusive size limits are checked. Separate checks exercise 2,048-edge acceptance, excessive depth, threshold ties and invalid/cyclic API inputs. |

This continuation adds **26,607** source cases, bringing the package total to
**176,133**, counting individual ANS alias transitions from the preceding slice
and whole weighted-predictor transcripts here. Errors are normalized to `err`;
success/error outcomes, values and recorded bit counts have no case overrides.
The source oracles completed without panic or memory-guard termination.

A separate fix makes failed section splitting consume the parent's remaining
bytes, matching the source. Initial frame compilation/serializer failures and
incorrect fixture assumptions were corrected before final checks without
changing source records. Explicit restoration constructors avoid V's nested
fixed-array-default C issue. Initial tree/oracle compilation errors were also
corrected; failed attempts receive no passing execution credit.

Final review also found that an extreme caller coordinate could overflow the
interior-neighbor check before indexing. The guard now compares against the
row length before adding offsets, with an INT64_MAX regression. The fifteen-file
default suite was rerun after this fix; no-GC revalidation selects the changed
predictor test only. The earlier complete no-GC suite and its unchanged files
remain recorded separately below.

## Verification

Current V was `V 0.5.2 395d574`; executable SHA-256
`fa57f9d6b086f86a289a1d312391378cdec2a121ca74fdeda3d8981dbb9f0633`.
The 68 module/testdata input hashes and compiler identity were unchanged across
each recorded check. The final sorted `path<TAB>SHA256<LF>` input manifest has
SHA-256 `3f7c8be9dd6a33e59636501376261ee5826d4f60d76b02e270f8b034e16751ca`.
The initial/final manifests differ only in the reviewed predictor bound and its
regression; no frozen expected data changed.

| Check | Files passed | Test / guard exit | Sampled outer peak RSS, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Initial complete default GC | 15 | 0 / 0 | 366,788,608 | 57.59 |
| Initial complete no GC | 15 | 0 / 0 | 360,022,016 | 74.49 |
| Final complete default GC | 15 | 0 / 0 | 275,333,120 | 52.20 |
| Final predictor no GC | 1 | 0 / 0 | 244,056,064 | 6.67 |

The checker compilation also exited 0, peaking at 310,181,888 bytes.

The canonical `tools/check_translation_corpora.v` was compiled under a separate
3 GiB process-tree guard. Each complete suite ran under its own 3 GiB guard,
sequentially, with `VJOBS=1`, `V_MACOS_V3_NO_FALLBACK=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo`:

```sh
check-corpora --suite jpegxl --gc boehm --compiler /Users/alex/code/v/v
check-corpora --suite jpegxl --gc none --compiler /Users/alex/code/v/v
v -memory-limit 10G -b c -cc clang -gc none test jpegxl/predictor_test.v
```

The checker invokes `v -memory-limit 10G -enable-globals -b c -cc clang` for
each mode. Focused checks also passed for every completed slice; formatting and
owned-path whitespace checks passed. Sampled RSS totals are process-tree
observations, not kernel limits or leak proofs. Other compilation jobs were
active on the shared host; no performance comparison is claimed. Temporary oracle sources,
binaries, logs, receipts and locks were removed under the Build scratch policy
after recording these results. Unrelated LibJS suites were not rerun; the
previously recorded ICU casing failures remain historical evidence.

The available production receipt was checked, with input head
`646535154eedc675df5dd6780755983417ec7fb8` and observed/receipt executable SHA-256
`23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`.
No separate production build was requested and no browser process launched.
Commits keep the normal shared rebuild hook enabled. The V JPEG XL package is
not wired into production image decoding yet, so no bundle validation of these
new modules is claimed.

Eight completed implementation commits belong to this continuation: frame
headers (`b6935a3fa`), section-EOF consumption (`1447cee5a`), TOCs/permutations
(`17e1ddbe2`), modular headers (`b6f7efb21`), predictors (`e57c9cefd`), reversible
color (`40d2e8dcb`), decision trees (`c8dc7e02f`) and the final coordinate guard
(`4d5d25caf`).
Documentation is independent and adds no implementation credit. Global
DOM/performance ledgers and their verification counters are unchanged.

## Boundaries

Section readers use bounded local cursors; source cached-reader absolute state
is not an API parity claim. The source's isolated permutation reader omits
ANS/deferred-error finalization; the V port retains that behavior rather than
claiming complete stream validation. V allocation/API bounds are explicit:
16,777,216 permutation/TOC entries, 1,048,576 weighted-predictor row samples and
a 131,070 tree size limit with at most 65,536 entropy contexts. Invalid caller
coordinates, coefficients, sizes and child indices return errors. Weighted row
persistence saves the source's first error-buffer row, not a general checkpoint
of every predictor field. SIMD layout and performance parity are not claimed.

Modular pixel properties/channel reconstruction, palettes/squeeze application,
VarDCT, filters, pixel color conversion, orientation/alpha output and browser
integration remain. The replacement must preserve supported static 8-bit
sRGB/gray decoding, rejection policy and resource limits before removing
`native_jpegxl_rust`, Cargo build/CI hooks and `tools/test_jpegxl.py` together.
The V corpus checker already verifies the completed layers without Rust.

See [JPEG XL status](../../jpegxl/PORT_STATUS.md),
[the earlier entropy/header report](JPEGXL_V_ENTROPY_HEADERS.md) and
[the developer-tool guide](../../tools/REFERENCE_CORPORA.md).
