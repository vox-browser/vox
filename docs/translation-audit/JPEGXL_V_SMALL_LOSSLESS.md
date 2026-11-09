# JPEG XL V small complete lossless files, 2026-11-09

`decode_small_lossless_rgba` now connects the translated container, headers,
section table, global modular stream, reverse transforms and output sample
stages to return final owned RGBA rows. Commit `ac47db5dc` is one completed slice
after the [twenty-five-file checkpoint](JPEGXL_V_OUTPUT_SAMPLES.md), making JPEG
XL cadence **1/10**. Production and its developer test still use Rust because
this is a narrower subset than the complete static decoder.

The API accepts a single full regular modular frame, one group and one pass,
without filters, chroma/extra-channel resampling or blending. File metadata must
describe static 8-bit sRGB/gray without a preview, ICC or XYB transform, and at
most one full-size 8-bit alpha channel. It chooses source 16/32-bit storage from
metadata. Straight hidden color values are preserved; requested premultiplication
is skipped when source alpha is already associated. Alpha is not multiplied by
itself. Dither coordinates precede orientation, and RGBA channels retain their
source offsets even for replicated gray. Unhandled trailing section/codestream
payloads are rejected. Input and output limits remain 64 MiB, with dimensions
bounded at 65,536 and RGBA sample count checked before allocation.

These explicit limits prevent an unimplemented path from returning a partial
image. Grouped/tiled channels, LF/VarDCT chains, filtered/lossy frames, upsampling,
patches/noise/splines, frame composition and broader extra-channel services
remain. The production decoder also supports static VarDCT images; replacing it
with this API now would remove supported behavior, so integration is pending.

## Independent complete-file reference

The existing production helper was loaded directly for a temporary independent
reference probe. No Rust compiler or Cargo build was invoked. It uses the same
pinned `jxl` 0.7.0 source as preceding reports, crate SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Helper SHA-256 was
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`,
verified unchanged before/after generation. The temporary probe source hash was
`09971cbdedc82e9b5a718e52196f4016c6feff032f484caa91a9e057f5ad866a`.

Six existing files supplied inputs: RGBA, its container, orientation-6, gray,
wide-gamut and animated. Eight more inputs changed only the three orientation
bits of the existing rotated stream. The probe located those bits using the
format's size/metadata coding. Their expected pixels came exclusively from the
independent complete production decoder, not the V orientation implementation.
Every shorter byte prefix of RGBA, container, orientation-6 and gray was tested.
Each input was decoded in both straight and paint modes.

The resulting **498** records comprise **24 accepted** complete images and
**474 rejections**. Successful cases compare every byte, width, height and pitch.
Errors compare rejection, not error messages/cursors. No record was overridden.
The frozen corpus has SHA-256
`5ab6a12018e1838e1ac62765f60d97a1f28af2f2051ed5013f50732a3c9697bf`;
tests use V alone. The package now contains **202,128** frozen cases and
twenty-six test files. Complete file/output-mode records count as individual
cases, as storage modes did in earlier transform corpora.

A separate test rejects `guardian-photo.jxl` because its first non-visible
modular LF frame is not the requested visible image. It does not compare final
Guardian pixels or claim its pending VarDCT path works. Wide-gamut and animation
rejections agree with current production policy. Additional source-associated
alpha/profile/extra-channel combinations are not established by this fixture set.

## Executed checks

Both focused runs use final formatted code and `V 0.5.2 a3892ac`, SHA-256
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
A 113-input manifest was recorded between the default and no-GC runs and verified
unchanged afterward, including module/testdata/data, the seven original fixtures,
driver and guard. Sorted `path<TAB>SHA256<LF>` manifest hash:
`21eff4b02b781b714552b90cf385169071ab8f43670c5a801b9d4e3be3b45e23`.
No implementation changed between these runs.

| Focused check | Files passed | Test / guard exit | Sampled RSS peak, bytes | Guard seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 1 | 0 / 0 | 279,478,272 | 8.46 |
| No GC | 1 | 0 / 0 | 273,973,248 | 5.31 |

Both used `V_MACOS_V3_NO_FALLBACK=1`, `VJOBS=1`,
`RUSTC=/unavailable/rustc` and `RUST_CARGO=/unavailable/cargo`:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/UNIQUE.lock --report Build/UNIQUE.json \
  --limit-gib 3 --timeout 180 -- \
  /Users/alex/code/v/v -memory-limit 10G -b c -cc clang \
  test jpegxl/small_lossless_test.v
```

The second adds `-gc none` before `test`. `v fmt -verify` on both new V files
and owned-path `git diff --check` passed. There were no failed test attempts for
this slice. The complete package was not repeated after the focused change;
the preceding twenty-five-file checkpoint remains independently recorded.
Unrelated LibJS/DOM/performance counters are unchanged. RSS is a sampled
process-tree sum, not a kernel bound or leak proof. No performance claim is made.

No separate production build or browser launch was requested; normal shared
post-commit rebuild hooks remain. Standalone codec tests do not validate browser
integration. Temporary reference sources/binaries, logs, receipts, frozen-data
staging copies and unlocked guards in the owned output job directory are removed
after recording this report. See [current status](../../jpegxl/PORT_STATUS.md)
and [the tool guide](../../tools/REFERENCE_CORPORA.md).
