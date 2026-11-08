# Planar YUV conversion

`PlanarImage.to_rgba()` is a pure V implementation of the former `yuv` 0.8.17
dependency. It supports opaque 8-bit YUV420, YUV422 and YUV444, limited/full
range, and BT.709, FCC, BT.470BG, BT.601, SMPTE240 and BT.2020 matrices. Each
plane has its own stride. Odd chroma dimensions round up; the final active row
need not include padding. Invalid dimensions, strides and short views fail
before writing any pixels. The native bridge borrows decoder-owned buffers;
it neither transfers ownership nor allocates output storage.

The scalar mode sums 13-bit fixed-point contributions before rounding. The
other rounding modes reproduce the former library's integer SIMD arithmetic
using V integers. The native browser adapter selects NEON RDM arithmetic on
ARM64 and x86 multiply-high arithmetic on x86. Apple Silicon output has been
compared exactly; x86 and non-RDM output have not been independently validated
on corresponding hardware. This port supplies no scrolling or playback
performance claim.

`testdata/rust-neon-rdm.tsv` contains SHA-256 hashes of 252 complete destination
buffers captured before removing the Rust package. The source was the existing
production-build archive `Build/v/rust-yuv/release/libladybird_v_yuv.a`, SHA-256
`5e1847e0d3088eef45e3c2e98e5e2b85c6edbcfc873d2c707fac2d7fa32f2909`, on
Apple Silicon with `hw.optional.arm.FEAT_RDM=1`. Each row is range, matrix,
sampling, width and hash, tab-separated. All enum values use declaration order.
The test reconstructs the inputs independently of the converter: heights are
three, widths are 1/3/8/17/32/33/65, Y stride is width+3, U stride is ceil-divided
chroma width+2, V stride is U stride+1, and destination stride is width*4+7.
Input byte formulas and the `0xa5` destination padding are in `planar_test.v`.
These hashes cover both paired rows and the unpaired final row, whose green
rounding differs in the old NEON implementation. Future test runs require no
Rust toolchain or archive.

Validation on 2026-11-08:

- Five V test functions pass with default GC and `-gc none`, including all 252
  exact reference hashes, neutral luma/clipping, minimal final rows and invalid
  native metadata. Both runs use `v -memory-limit 10G -b c -cc clang test yuv`
  (with `-gc none` for the second) under separate 3 GiB memory guards.
- `python3 tools/test_yuv.py --output Build/UNIQUE-yuv` builds the actual
  `media/yuv_bridge.v` export and checks its generated prototype against the
  native header. A fresh ASan/UBSan native driver executes the real FFmpeg
  conversion fast path with no fallback API, verifies independently captured
  pixels and padding, and checks rejection of invalid metadata. Final compile,
  prototype, native compile, driver and guard exits are all zero. This command
  needs macOS and the existing FFmpeg SDK, but no Rust compiler.
- The first reference comparison found the two-row green rounding difference;
  the corrected run passes. Initial native-check setup attempts exposed an
  unsuitable forced-header check and V's default dylib install name; the final
  driver checks the exported prototype directly and sets an explicit install
  name before linking.
- Shell syntax and Python compilation checks pass for the modified build tools.

The shared production browser was not rebuilt for these focused checks. They
validate the new module and its native caller, not a newly published browser
bundle. Regex and JPEG XL still require Rust elsewhere in this repository.
