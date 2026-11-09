# JPEG XL V modular streams, 2026-11-09

V now plans and reconstructs modular transform graphs, decodes complete modular
streams and decodes small modular global sections into raw channel planes.
Production still uses Rust JPEG XL. Grouped/tiled decoding, complete frames,
VarDCT, patches/noise/splines, filters, final color/pixel output and integration
remain; the Rust backend and its developer tools cannot yet be removed.

This continuation completes five slices: transform planning (`48b75a565`),
reverse reconstruction (`c75ee3d72`), complete modular streams (`1ac2d9964`), LF
quant factors (`246e19830`) and small raw frames (`aa45b4496`). Formatting
`dabe973b4` changes no behavior. Together with the preceding four slices, this is
**9/10** after the fifteen-file JPEG XL baseline. Only focused checks ran;
unrelated DOM/performance ledgers and historical reports retain their pins.

## Independent reference

The source is `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Planning and entropy/tree/decode source files were verified against the archive.
Temporary oracles included unchanged source algorithms with minimal image-buffer
carriers and source-shaped visibility/logger glue. The stream oracle exercised
the complete source subbitstream decoder, including its specialized branches
and fast paths, rather than the earlier generic-branch-only channel oracle.
The global-section wrapper performed original planning, supplied already planned
buffers/header to that decoder, then ran the original reverse local transforms.
It did not run the complete frame renderer.

Cached source dependencies were reused without Cargo rebuilds or network access.
The final stream/quant/frame oracle source SHA-256 was
`229143a24586603ecc0f97b81dee6e6be84c8a3dbe6515a1a2f8503c96ec94fa`.
Expected results came from the source, never V. Frozen tests need V alone;
temporary sources and binaries are removed under the scratch policy.

| Layer | New cases and exact coverage |
| --- | --- |
| Transform planning | 1,024 cases; 722 accepted. Metadata, coded identities/order, transform steps, automatic squeeze order, weights, palette budget and consumed header bits. |
| Reconstruction | 256 composed source plans in signed 16/32-bit storage. Every output sample; separate singleton/empty-axis and caller-ownership regressions. |
| Complete streams | 303 cases: 128 composed local streams, 128 selection scenarios, 37 every-byte truncations, four all-empty streams and six source fast-lossless RLE cases. All samples/shapes and successful consumed bits match; 234 succeed, 69 fail. Error cursors are diagnostic, not assertions. |
| LF quant factors | 4,096 cases; 2,312 accepted. All six f32 factor/reciprocal words and consumed bits, including rejected finite-half factors. |
| Small global frames | Twelve comparisons: six bare fixtures' first frames in each storage width. All quant words, raw channel samples and successful consumed bits. |

These add **5,691** cases, yielding **196,704** across the package. Existing
case definitions retain whole weighted/property transcripts and individual ANS
alias transitions. No expected outcomes or tolerances changed to obtain a pass.

RGBA is 3x2 with separate straight color/alpha planes, consuming 344 bits of a
43-byte section. Gray is 3x2, consuming 113 bits of 15 bytes. Orientation-6,
animated and wide-gamut fixtures have the same initial RGBA planes; this does not
establish support for their final output policy. Guardian's first modular frame
has three 13x13 raw planes, consuming 3,289 bits of a 412-byte section. It is a
non-visible LF dependency; the next visible VarDCT frame remains untranslated.

Initial oracle compilation failed on missing imports, carrier visibility and
logger macro visibility; only harness glue was corrected. The first V
reconstruction run failed because an allocated empty residual is 0x0 while a
singleton squeeze needs its logical dimensions. Reconstruction now restores
those dimensions from the plan. One interrupted recheck left empty receipts and
gets no execution credit. The first small-frame test failed C compilation on
the known nested fixed-array default issue; explicit restoration constructors
in test inputs fixed it. Source records and algorithm bodies were unchanged.

## Executed checks

Final compiler: `V 0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
All 97 JPEG XL V/testdata files and the compiler hash stayed unchanged across
the final batches. Sorted `path<TAB>SHA256<LF>` manifest SHA-256:
`c371e6bc2651af6eb30e0e17262788d88d8efe3e9cb8f706d88ec11581848994`.

| Final check | Files passed | Test / guard exit | Sampled peak RSS, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 5 | 0 / 0 | 266,911,744 | 14.99 |
| No GC | 5 | 0 / 0 | 263,782,400 | 16.03 |

Both commands used `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo` under separate
3 GiB guards, with a 180-second timeout:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang test \
  jpegxl/modular_plan_test.v jpegxl/modular_reconstruct_test.v \
  jpegxl/modular_stream_test.v jpegxl/lf_quant_test.v \
  jpegxl/small_modular_frame_test.v
```

The second command adds `-gc none` before `test`. Each slice also had its
focused checks before committing. The initial standalone stream no-GC guard
took 37.33 seconds (V reported 7.95 seconds); host contention prevents treating
that difference as codec performance. Final results above supersede earlier
planning checks made with compiler `395d574`. `v fmt -verify jpegxl` and
owned-path `git diff --check` passed. RSS is a sampled process-tree sum, not a
kernel allocation bound or leak proof; no performance parity is claimed.

## Boundaries

Stream channels and total samples are bounded at 65,536 and 67,108,864. Planning
caps buffers at 1,048,576 and computes a shape-dependent channel cap. Zero-area
allocated channels do not inflate that cap. The V tree limit is 131,070 so its
leaf contexts fit the 65,536-entry entropy map. A supplied global header means
its transform metadata was already applied; the decoder must not apply it twice.
All-empty streams return before reading a header or requiring a global tree.
Complete stream decoding does not implement partial recovery or cached-reader
state parity after errors. Caller coded samples are preserved by reconstruction.

Small frames require all coded channels in the global section and reject
grouped channels or patches/noise/splines. Raw planes precede filters, color
conversion, orientation, quantization and frame composition. Existing source
extra-channel geometry uses the main sample depth; that behavior is retained.
These checks do not establish final file/pixel decoding or browser integration.

No separate production build or browser launch was requested. Commits retain
the normal shared rebuild hook; no production-bundle validation is claimed for
these unconnected modules. The two owned `Build/pure-v-jpegxl-streams-*` job
directories, sources, logs, receipts and unlocked guards are removed after this
report is recorded. See [status](../../jpegxl/PORT_STATUS.md),
[the preceding report](JPEGXL_V_MODULAR_SAMPLES.md) and
[the developer guide](../../tools/REFERENCE_CORPORA.md).
