# JPEG XL VarDCT frame assembly and RGBA output

Six pure V slices on 2026-11-09 connect the completed decoder stages into
complete-file output for an opaque 4:4:4 VarDCT subset. The package now has
**281,841 independent source records and 74 test files**. The new 24 complete
codestreams match the pinned native decoder's entire RGBA output exactly.
Production still uses Rust; this bounded entry point is not its replacement.

| Slice | Commit |
| --- | --- |
| LFGlobal state and modular planning | `d380137e8` |
| HFGlobal matrices and pass state | `b73b2ff27` |
| Selecting HF groups from their LF owners | `702ccad52` |
| Complete VarDCT frame planes | `a112987fa` |
| Frame restoration and boundary cropping | `ff1a47cb7` |
| Complete-file opaque VarDCT RGBA | `716f630e9` |

These are six slices after the prior four post-checkpoint changes, reaching
10/10 after the [65-file checkpoint](JPEGXL_V_HF_ENTROPY.md). All 74 files now
pass both GC modes, completing the checkpoint and resetting cadence to **0/10**.

## Connected behavior

`read_lf_global` parses LF quantization, VarDCT quantizer/block/color parameters,
optional global trees and modular transform plans. VarDCT contributes no modular
color planes; extra channels retain their output identities. With no modular
channels, no modular global header is consumed. The channel-info helper is
shared with the older modular decoder, whose decoded results remain covered by
existing native references. Tree allocation retains the existing 131,070-node
bound rather than the source's larger internal budget.

`read_hf_global` reads all dequantization matrices and progressive pass state,
including independent modular/HF storage widths. Coefficient buffers and sigma
maps are allocated by their owner when needed. The existing 65,536-entry entropy
context budget remains; allocation/cache layout and unrestricted source API
parity are not claimed.

`select_vardct_group` checks LF ownership and crops quantization, transform,
sharpness, LF-context and color-tile maps. It selects component LF planes with
the source's normalized sampling offsets. Constructed tests cover all four
sampling modes, interior/edge groups across a 3x2 LF-owner grid, map strides,
color tiles and incorrect owners/incomplete storage.

`decode_vardct_frame` consumes combined or separate logical sections, reconstructs
LF groups and metadata, stitches LF planes before adaptive smoothing, reads
HFGlobal and decodes every progressive pass for each HF group. Group planes are
placed into the padded frame. Per-section padding and complete consumption are
checked. This first frame owner requires 4:4:4, no LF reference, no extra
channels and unit upsampling, with a 64 Mi-sample three-plane budget. The group
selector supports sampling modes that this first whole-frame owner still rejects.

`restore_vardct_frame` crops to the actual image extent before filtering, then
runs Gaborish and the selected EPF 0/1/2 stages in source order. It derives sigma
from the reconstructed quantization/transform/sharpness maps. Padded samples
must not become filter neighbors beyond the actual frame edge.

`decode_vardct_rgba` adds complete input/container parsing, a single full visible
frame, supported output-profile validation, XYB/sRGB or YCbCr conversion,
positional dithering, orientation and opaque RGBA packing. Straight and
premultiplied output coincide for this opaque subset. Input and RGBA output
retain the production 64 MiB bounds and 65,536 dimension limits. Animation,
previews, ICC/wide gamut/unsupported HDR transfer profiles and unsupported frame services are rejected. The
old complete lossless entry points and production caller remain unchanged.

## Independent references

The source remains cached `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
All six consulted files below were byte-verified against that archive.

| Original source | SHA-256 |
| --- | --- |
| `frame/decode.rs` | `7c6964276f01b6d8d56661f0357c39bac8097ada88332eeaabfb02b169c4c0e0` |
| `frame/mod.rs` | `f84f7e643436f790166aa66bfd5f86226d3238c52ba5f643a9d3f2cf101f8d05` |
| `frame/render.rs` | `e9728c0d5f072380e165cd9056524b3327ee0b136e5c8ef902380e6e16f6ca77` |
| `frame/group.rs` | `086c0f63f09e4d1d41d4681dc8068c45aca9190f4f41c2f6b43eaa130de6b2a0` |
| `frame/modular/mod.rs` | `8c1e521cd0343d6d55b6f7d8f203c3c5655d5a98eb0229a501b7424f03bab853` |
| `frame/adaptive_lf_smoothing.rs` | `3c2adb68266b88f4e92ebf78cdec343b707f8c5355a811dc6614e1cf6e7b52ae` |

LFGlobal composition checks reuse all twelve existing native raw-plane records,
including original complete output and consumed bits. Constructed packets test
empty/alpha-only modular plans and the following field boundary. HFGlobal
composition checks reuse all 66 frozen native pass records: 34 accepted and
32 rejected, comparing every pass snapshot and cursor after the matrix prefix.
The old independent records are not counted again as new source cases.

The complete-file fixtures are small independently authored codestreams. Their
expected pixels come exclusively from API version 1 of the cached production
decoder `Build/v/rust-jpegxl/release/libvox_jpegxl.dylib`, SHA-256
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`.
Its hash is verified before/after each reference run. The current Rust bridge
source hash is `ae1877e80ca05917cd21fa3547b0030837d190daaeaf6899510cb768f3abb382`;
this does not assert that the cached binary was freshly compiled from that source.
No Cargo build, network access or browser launch is used for the reference.

| Frozen manifest | Images | Native RGBA bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `vardct-files.tsv` | 20 | 1,391,504 | `943f2375e25f0900839d88fee46c9b1c6adbfa7c1064b62ba72efc3ce9cb26ea` |
| `vardct-patterns.tsv` | 4 | 184,036 | `effc5ff0ed1efdf171fb2163149699f5f6ff60fa0dc79ab6eedc42de57618e4f` |

Each manifest retains the compressed input hash and native whole-image RGBA
hash. All **1,575,540 output bytes** compare exactly, with no pixel tolerances.
V checks both straight and premultiplied requests: 48 decodes against the 24
opaque source images. Source creation and decoding are independent of V.

Twenty constant-LF images cover 8x8, odd 33x25, 256x256, 512x8 and 2056x8,
with four nonzero/zero LF levels and DCT/Hornuss/DCT2X2/DCT4X4 kinds. Four
nonuniform y-property trees generate 33x25, 64x64, 512x16 and 2056x16 patterns.
They exercise smoothing, nonuniform sigma, restoration and visible color
transitions. Complete fixtures include combined sections, multiple HF groups,
multiple LF groups and empty HF entropy sections with genuine zero-symbol
histograms. HF coefficients in this new complete-file cohort are zero; it does
not establish new whole-file coverage for nonzero HF symbols, all transforms,
local modular transforms, chroma, progressive files, alpha or reference frames.
Those component stages retain their separately documented source comparisons.

The raw-frame test uses an analytical constant-LF check with a 1e-7 float bound
to allow smoothing/transform rounding. That diagnostic is distinct from the
complete-file native pixel comparisons, which remain exact. The restoration
test reuses all 512 native Gaborish records in every channel and poisons padded
samples to verify cropping. No old expected record or pixel allowance changes.

Temporary fixture-authoring programs have SHA-256
`9b03d6f06c9d94a8c5011d121def41896914d2ac48df94fa55589b71bdf5eecb`
(constant files) and
`3a6a74fdc3698427b77f27c17ba3290cfed3023c7f68538b29b2782f34ccdd03`
(nonuniform files). They are migration references, not new developer tools.
Frozen tests execute through V alone. The native reference guards exit zero:
the final twenty-file run peaks at 3,440,640 RSS bytes in 0.239 seconds and the
four-pattern run at 16,449,536 bytes in 0.409 seconds. An earlier four-image
black diagnostic also exits zero (15,155,200 bytes, 0.376 seconds) and is not
counted again in the frozen 24-image cohort.

## Focused verification

V remains `0.5.2 a3892ac`, executable SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
V checks use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo`, flags
`-memory-limit 10G -b c -cc clang`, optional `-gc none`/`-prod`, and separate
3 GiB process-tree guards. GC modes run separately. RSS is sampled and shared
pages can be counted twice; these are correctness checks, not allocation-limit
or performance claims. Unrelated host work was running.

| Successful focused check | Peak RSS bytes | Seconds | Test / guard exit |
| --- | ---: | ---: | --- |
| LFGlobal + small modular, default | 305,020,928 | 5.114 | 0 / 0 |
| Same + grouped modular, no GC | 299,548,672 | 15.300 | 0 / 0 |
| HFGlobal, corrected default | 351,535,104 | 24.517 | 0 / 0 |
| HFGlobal, no GC | 1,643,184,128 | 23.421 | 0 / 0 |
| Both global files, optimized | 426,950,656 | 25.185 | 0 / 0 |
| Group selection, default | 283,656,192 | 3.961 | 0 / 0 |
| Raw frames, default | 330,596,352 | 7.343 | 0 / 0 |
| Group selection + raw frames, no GC | 324,255,744 | 8.458 | 0 / 0 |
| Restoration + initial 20-image RGBA, default | 323,698,688 | 19.612 | 0 / 0 |
| Final 24-image RGBA, default | 333,512,704 | 13.263 | 0 / 0 |
| Restoration + final RGBA, no GC | 424,296,448 | 14.439 | 0 / 0 |
| Group/frame/restoration/final RGBA, optimized | 455,393,280 | 34.310 | 0 / 0 |

The first HFGlobal test accidentally added seven available padding bits to
truncated header fixtures, so the EOF cursor differed at record 34 (test/guard
exit 1, 349,323,264-byte peak, 21.008 seconds). Its corrected framing starts the
matrix bit at bit 7 and preserves each original header's exact byte extent.
All original records and cursor expectations remain unchanged. The failed
selection receives no wholesale pass credit. An immutable-array assignment
notice in the initial RGBA check was removed with explicit branch results;
final default/no-GC/optimized checks cover that corrected source.

The final **294-input** sorted `path<TAB>SHA256<LF>` manifest has SHA-256
`956769dfc2139f6d67cfcc999e026626a3d33f6d6b1f47890b62b9c299ce2675`.
It includes every package V file, recursive fixtures/data (including the new
complete files and dither table), all seven existing browser JPEG XL resources,
the V corpus checker and memory guard. Input hashes/change times and the
compiler pin are checked throughout final validation. Full results follow.

## Full checkpoint

Full selections run serially through the unchanged V corpus checker, with its
inner 3 GiB guard and a default 12 GiB outer guard:

```sh
env V_MACOS_V3_NO_FALLBACK=1 VJOBS=1 \
  RUSTC=/unavailable/rustc RUST_CARGO=/unavailable/cargo \
  python3 tools/run_memory_bounded.py \
    --lock Build/JOB/full-MODE.lock --report Build/JOB/full-MODE.json \
    --timeout 1500 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
    run tools/check_translation_corpora.v --suite jpegxl \
    --compiler /Users/alex/code/v/v --gc MODE --jobs 1
```

Both full selections pass all **74 files**. The `boehm` tests and inner guard exit
zero, at 342,884,352-byte peak RSS in 449.676 seconds; driver and outer guard
exit zero, at 604,061,696 bytes in 453.071 seconds. The no-GC tests and inner
guard exit zero, at 1,638,793,216-byte peak in 377.942 seconds; driver and outer
guard exit zero, at 1,894,940,672 bytes in 381.425 seconds. All 294 input content
hashes/change times and the compiler pin remain unchanged across both full
selections and final focused checks. This completes the ten-slice checkpoint
and resets JPEG XL cadence to **0/10**. Unrelated suites and historical ledgers
were not changed or rerun. Host contention was substantial: a late default-run sample observed
18 CPUs and load averages 102.50 / 68.77 / 38.86. Elapsed times are diagnostic
receipts, not evidence of decoder performance.

A separate bounded diagnostic traced the existing 98x98 Guardian fixture. It
contains a non-visible modular LF frame (level 1, 13x13, six sections), then a
visible 98x98 VarDCT frame with LF-reference flag 32. The V modular decoder
returned three 13x13 raw channels and LFGlobal parsing completed for both frames
(514 and 333 bits). This is diagnostic execution, not an independent raw/pixel
comparison or a passing whole-file photo result. Its guard/test process exits
zero at 287,506,432-byte peak in 4.348 seconds. The temporary canonical V probe
was removed after execution. LF reference conversion/ownership is a concrete
remaining dependency for that existing fixture.

Temporary authoring programs, diagnostic inputs/logs, reference binaries, locks
and guard receipts under `Build/pure-v-jpegxl-assembly-20261109-16` are deleted
after authenticating completed receipts and unlocked locks. The canonical
temporary probe was also removed; shared bundles and cached libraries remain.

## Remaining work

The production Rust decoder, Cargo/CI integration and native JPEG XL developer
test remain until the V path preserves supported static 8-bit sRGB/gray behavior
and rejection/resource rules. LF/reference frames, extra channels/alpha,
subsampling/frame resampling, feature streams (patches, splines, noise), broader
frame composition and large entropy context maps remain. Complete-file coverage
for arbitrary source-supported images is not claimed by these 24 authored files.
No browser validation or duplicate manual production build is performed; the
managed post-commit hook requests a shared production rebuild for every commit.
