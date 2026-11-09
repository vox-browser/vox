# JPEG XL image upsampling in V

Two more slices on 2026-11-09 implement 2×/4×/8× image upsampling and connect it
to opaque VarDCT output and LF saving. `d6a89a82c` adds the kernel stage;
`b79b3169d` adds frame integration. The package now has **282,753 source records
and 80 test files**. Cadence is **6/10** after the
[74-file checkpoint](JPEGXL_V_FRAME_ASSEMBLY.md); no full 80-file run is claimed.
Production still uses Rust.

The stage expands the triangular weight tables into mirrored 5×5 polyphase
kernels, reflects image borders, retains three independent fused binary32
accumulators in source order, and clamps each result to its 5×5 neighborhood's
minimum/maximum. It allocates only the requested output extent, including
cropped final rows/columns, with checked geometry and the existing sample bound.

Frame rendering filters at coded resolution, then upsamples before color
conversion. LF saving happens after this upsampling. The older raw-frame API
retains its unit-upsampled contract; the explicit reference-aware API supports
the additional factors. Constructed checks cover poisoned padded samples,
filter/crop order, invalid factors/budgets and modular LF source-space saving
at the enlarged resolution. Whole-frame chroma sampling, extra channels,
feature streams and wider composition remain unsupported.

## Independent records

The source remains checksummed `jxl` 0.7.0. The following files were verified
byte-for-byte against archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`:

| Source | SHA-256 |
| --- | --- |
| `render/stages/upsample.rs` | `fe54f9a973f4b8f1318b02c7e8073e25446204a585140e6d9621618e0362cb62` |
| `headers/transform_data.rs` | `b7ede43cb3af86ea754f3116d1ba4c61f4a0686f53b9021beb45a98859b7cf27` |

The temporary row oracle uses 13,827 unchanged source bytes: the constructor,
min/max helper, convolution macro and three dispatched row implementations.
An independently authored wrapper supplies mirrored rows and crops output.
It links only the previously pinned cached SIMD artifact, with no Cargo or
network. Its Rust source SHA-256 is
`8e9822a5278c58a02a02f25ec49f4aecaa6f82b5e070a893dc9397482672c173`;
the executable SHA-256 is
`ad8952740c32914017374548cac5903b1903c22e275ade5fd094bbe7b180c94d`.

`upsample-planes.tsv` contains **384 independent cases, 128 per factor**,
comparing all **246,656 output float words exactly**. Cases include 1-pixel
axes, eight geometries, cropped edges, constants, signed nonuniform pixels,
default weights and arbitrary finite custom weights. Input planes remain
unchanged. Manifest SHA-256 is
`d7f48ace1e443fc9e2dac3615acb29d3fcb3154acb5247b99b09a132e5c5d691`.
The compile/reference guards exit zero, peaking at 161,693,696/21,102,592 RSS
bytes in 2.337/0.713 seconds.

Another **15 complete images** compare **1,933,816 RGBA bytes exactly** to
API version 1 of the cached production helper, SHA-256
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`,
verified before/after the reference. Independently authored headers enlarge
the original constant/nonuniform fixtures while preserving their coded
geometry and entropy payloads. They cover all three factors, odd/cropped
dimensions and custom half-float weight tables. Expected output comes solely
from the native decoder. No candidate-derived expectations or pixel tolerances
are used. Manifest `upsampled-files.tsv` SHA-256 is
`4d05e0dc3e3c76f6b678277e1d8b9556701cab33583f3dfbd0b103e806537473`;
the author/reference program SHA-256 is
`b9404c306ef9a34641fd45449081d0973206a2f74afa76bd62c3b424c5cd5a59`.
Its guard exits zero, peaking at 15,613,952 bytes in 0.684 seconds.

The 15 new images have zero HF coefficients. The earlier nonzero-HF Guardian
photo remains an exact regression. Across the two prior whole-image cohorts
and these additions, **40 images compare 3,547,772 native RGBA bytes**, with
80 V straight/premultiplied decodes. Native whole-file LF upsampling is not
newly covered: its composition check uses the independently referenced stages.

## Checks and compiler change

The component initially passed default/no-GC/optimized checks with compiler
SHA-256 `baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
The first invocation preceded fixture installation after a hash-transcription
check failed; that missing-fixture run failed and receives no pass credit.
The frozen reference bytes were installed with their correct hash unchanged.

During a later two-file default regression the shared compiler changed to
V `0.5.2 a5bda29`, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Although its test/guard exits were zero, the input monitor rejected the run;
it supplies no final acceptance credit. The final complete five-file selection
was checked in every mode using the new unchanged compiler:

`frame_upsample_test.v`, `lf_reference_frame_test.v`, `vardct_frame_test.v`,
`upsample_test.v`, `vardct_rgba_test.v`.

| Mode | Test/guard exits | Files | Peak sampled RSS bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Default GC | 0/0 | 5/5 | 352,206,848 | 52.743 |
| No GC | 0/0 | 5/5 | 425,263,104 | 50.237 |
| Optimized | 0/0 | 5/5 | 475,824,128 | 102.784 |

Every run uses `-memory-limit 10G -b c -cc clang`, the selected GC/production
flag, `VJOBS=1`, `V_MACOS_V3_NO_FALLBACK=1` and unavailable Rust compiler paths.
Separate 3 GiB guards have 180-second limits. All 320 input hashes/change times
remain unchanged during these final checks; default and no-GC/optimized input
manifests are identical, SHA-256
`85c5722db9304219576ee79dfaf8dcbd782e102a0e896d9b51b23b092738dc80`.
The host has 18 logical CPUs; a late load reading was 43.34/64.16/51.89.
Elapsed times include contention and provide no performance claim.

Managed post-commit builds remain coalesced. No extra production build or
browser check is used for this unconnected module. Scratch reference programs,
logs and guard reports are removed after their results are recorded and their
locks verified obtainable. Production JPEG XL and the native developer tool
continue to require Rust until the remaining behavior and integration land.
