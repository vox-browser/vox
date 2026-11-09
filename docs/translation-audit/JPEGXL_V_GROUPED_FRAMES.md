# JPEG XL V grouped lossless frames, 2026-11-09

V now schedules modular global/LF/per-pass channels, decodes group-local streams,
stitches complete coded planes and reverses global transforms. The new
`decode_lossless_rgba` API returns final straight or premultiplied RGBA for grouped
lossless files under the existing static 8-bit sRGB/gray restrictions. The small
API retains its group limit. Production remains on Rust until VarDCT, filters,
broader color/frame services and browser integration preserve its supported set.

Scheduling is commit `f6f7799e4`; formatting-only `471dfaa5a` adds no behavior.
Grouped frame/output decoding is `1cd903dbb`. These two slices bring JPEG XL
cadence to **3/10** after the preceding twenty-five-file checkpoint, including
the prior small-file slice. Unrelated LibJS/DOM/performance counters are unchanged.

## Independent source and fixtures

The source remains `jxl` 0.7.0, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Eight source files for modular classification, frame/section dispatch, stream
IDs, bitstream decoding, quant constants, headers and TOCs were verified against
the archive. The temporary scheduling oracle extracted unchanged classification,
ChannelInfo predicates, grid-rectangle methods and stream-ID arithmetic. It used
the cached source Passes parser/bracket calculation and a minimal geometry
carrier for unshifted, unupsampled frames. Oracle source SHA-256:
`667609ce3084420516adacd18d9a6db4053e9d5d035cc24fca77e0c51ec78eda`.

There are **512** frozen metadata cases. They compare the global prefix and all
LF/HF pass channel lists, first/middle/last tile rectangles and stream IDs across
group shifts 0 through 3, varied per-channel shifts and source pass schedules.
Inverted brackets remain empty. Separate bounds tests reject invalid indices,
geometry and attempts to group metadata; empty tiles preserve source behavior.

Twelve frozen files were independently encoded with the installed C++ libjxl,
using deterministic gray/RGB/RGBA patterns, group sizes 128/256/512, original
profiles, preserved hidden colors, varied group ordering and responsive options.
They include odd dimensions up to 2,051 pixels wide. Encoder source hash:
`320f084c5f2b88a58dfaae20f7410731d22286cbf1ab3c7abc0126615502ba0b`.
The encoder was compiled with `clang++ -std=c++20 -O1`, the installed SDK include
and library paths, `-ljxl` and its runtime search path, then executed under a
separate 3 GiB guard. Recorded installed libjxl hash:
`fc1afc4e35356c46769192d4c306aaeeec99fccb54524e506aa3fbc87d0a50fd`;
encode.h hash: `4be23340032f2410ecbde76be7ec61ed5cb251b77deb2fa237792ae364075c49`.
These are input-generation identities, not performance pins for a comparison.

The responsive encoder outputs still have one pass. A thirteenth input rewrites
frame-1's frame header/TOC to two passes with empty first-pass HF sections and
unchanged coded HF payloads in the final pass. Its original file header, global
and LF data remain. The temporary V constructor only constructs input; the
independent production decoder verifies acceptance and supplies expected pixels.
Constructor/probe source hash:
`16675265d9f6d12ced244bc78b02ddbb1ae194d1539dd6dcdf904bd1f332ab25`.

All thirteen inputs were decoded in straight and paint modes by the unchanged
existing Rust helper, hash
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`.
Its hash and fixture hashes stayed unchanged across reference generation. No
Cargo rebuild was invoked for pixels. Probe source hash:
`702b29a4a14007a77d09454eadb0d96897e741b9ee1e2d47819812074ea475a7`.
The **26** comparisons check dimensions, pitch and SHA-256 of every output byte.
The original twelve inputs/24 comparisons were retained when adding the explicit
two-pass case. No source output was replaced with V-computed expectations.

Coverage assertions establish 24 multi-group outputs, 14 permuted outputs, two
two-pass outputs and six outputs spanning multiple LF groups. Two input files
carry coded LF channels, four use global trees, and four use global squeeze
transforms. The cohort also includes a combined single-group section. A missing
TOC section is rejected before incomplete planes can become zero-filled output.
This is a frozen codec cohort, not a live browser/rendering measurement.

Corpus hashes: modular-groups.tsv
`3ea7567fd38a2fe8904e1144c788a0e5e0567c7cda2881219d1f24c9c25c03a7`;
grouped-pixels.tsv
`b10ca9afd5303ebc341a00cf6e44c1be4ab05d96cda1e10b6b6f585885b78792`.
These add **538** source cases, bringing the package to **202,666** cases and
twenty-eight test files. Row/vector/transcript counting remains unchanged.

## Checks and corrected attempts

Scheduling passed its focused default/no-GC runs before committing. The first
oracle compile lacked the source JxlHeader trait import; harness glue was fixed.
V fmt required a second pass for a nested struct literal, committed separately.
The first frame check failed to compile because SHA-256's string API received
bytes; it now uses the byte API. The next attempts rejected a valid empty global
entropy payload. Source with_buffers/subbitstream code confirms no-pixel sections
are ignored, so bounded unused section payloads now follow that behavior.
Active streams retain final-state, shape and complete-coverage checks.

Two cohort assertions were initially wrong: one responsive input has a single
group, and responsive libjxl does not produce multiple passes. The single-group
case remains, and a separately source-verified two-pass input was added. No
input or expected output was removed to obtain a pass. The original four-file
default batch exited 1: frame pixel comparisons completed but its coverage
assertion failed, while the three other files passed. Those three passing files
are retained with unchanged dependencies; only the corrected frame test was
rerun. The original whole batch receives no wholesale pass credit.

| Check | Files passing | Test / guard exit | Sampled peak RSS, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Default original batch | 3 passed, 1 failed | 1 / 1 | 285,163,520 | 63.21 |
| Default corrected frame file | 1 | 0 / 0 | 284,704,768 | 17.72 |
| No GC final batch | 4 | 0 / 0 | 279,085,056 | 30.51 |

The default composite covers the same four relevant files as the no-GC batch.
Current V is `V 0.5.2 a3892ac`, executable hash
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
The final compiler and all 130 module/testdata/data/fixture input hashes stayed
unchanged across the corrected frame and no-GC checks. Sorted
`path<TAB>SHA256<LF>` manifest hash:
`cd2f673144ecbdbc6fdf6ab0f66a2465c2afa656d4cb03d45c001f8980d013f9`.

All focused commands use `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc`, `RUST_CARGO=/unavailable/cargo`, a unique 3 GiB guard,
and a 180-second timeout:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang -gc none test \
  jpegxl/modular_groups_test.v jpegxl/modular_frame_test.v \
  jpegxl/small_lossless_test.v jpegxl/small_modular_frame_test.v
```

The default original command omits `-gc none`; the corrected default command
selects only modular_frame_test.v. Owned-file formatting verification and
`git diff --check` pass. The full package was not repeated at 3/10. RSS is a
sampled process-tree sum, not a kernel allocation bound or leak proof. Shared
host activity varied; no codec performance or SIMD parity is claimed.

Whole coded planes replace the source's tiled inverse-transform dependency and
border machinery. This checks final full-frame output on the cohort; partial
rendering, streaming recovery, auxiliary tile handoff/lifetime parity and
production resource behavior remain separate. Only seventeen reserved quant
stream identities are implemented here, not VarDCT quant-table decoding.
VarDCT/frame dependencies, filters, XYB/YCbCr output, upsampling, broader extra
channels and production integration remain. Production Rust and developer
build/test dependencies must still be retained.

No separate production browser build or launch was requested. Normal shared
rebuild hooks remain; standalone tests do not validate browser integration.
Temporary canonical constructor/probe files were removed. The owned Build job's
oracles, encoder, logs, receipts and unlocked guards are removed after recording
this report. The frozen compressed test inputs remain intentional test assets.
