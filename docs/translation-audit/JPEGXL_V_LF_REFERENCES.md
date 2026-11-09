# JPEG XL LF references in V

Four slices on 2026-11-09 add modular XYB conversion, shared restoration,
explicit VarDCT LF dependencies and complete-file reference ownership.
The existing Guardian photo now matches the pinned native decoder's complete
98×98 RGBA output exactly, including its nonzero HF data. Production still
uses Rust; this is a bounded decoder extension, not production replacement.

| Slice | Commit |
| --- | --- |
| Modular XYB integer-to-float conversion | `4ac2829e8` |
| Shared modular/VarDCT restoration | `29f881603` |
| Explicit VarDCT LF planes | `e9d9ba34c` |
| Complete-file LF ownership and RGBA | `a08498020` |

The package has **282,354 source records and 78 test files**: the preceding
281,841 records plus 512 conversion cases and one complete photo. Reused old
component records and constructed composition checks are not counted again.
Cadence is **4/10** after the [74-file checkpoint](JPEGXL_V_FRAME_ASSEMBLY.md).
No full 78-file run is claimed.

## Behavior and bounds

Modular XYB carries Y, X and a B residual. Normalize the signed integer storage,
convert each value to f32, multiply X and Y by their factors, then compute
`B = (f32(B_residual) + f32(Y)) * B_factor`. Integer addition or independently
scaling Y in the B sum changes source rounding. The 512 frozen cases compare
all **130,560 float words exactly**, covering both storage widths, wrapping,
2^24 boundaries, signed extremes and unequal quantization factors.

Modular restoration uses a constant EPF sigma; VarDCT uses its block maps.
Both crop before filtering and share the Gaborish/EPF stage order. The shared
path retains all 512 native Gaborish records in every channel. One existing
native EPF1 record has a positive, exactly round-tripping metadata sigma,
origin zero and stage scale one, and checks modular composition exactly.
Other EPF component records include values/positions outside that metadata
subset; they remain independently covered by their original tests. Constructed
checks exercise all four iteration settings and reject invalid geometry/sigma.

Reference-aware VarDCT decoding checks reference presence and exact block-plane
geometry before consuming sections. It skips LF entropy, crops cached floats
per LF owner, leaves quant-LF contexts zero and disables adaptive LF smoothing,
as the source does. Existing metadata/HF parsing and complete section-consumption
checks remain. The older no-dependency API preserves its explicit LF rejection.

Complete-file output can consume non-visible LF frames before one final visible
frame. LF level N saves restored source-space floats in slot N−1; VarDCT level
N reads slot N. Saving precedes color conversion and orientation. Modular LF
frames currently require XYB; VarDCT LF levels 1–4 use the same raw/render path.
Constructed checks preserve coded geometry and restored floats at every level,
and exercise interior/edge LF-group crops, missing references and bad storage.
The file loop is bounded to 64 total frames. Unit upsampling, 4:4:4, no extra
channels, full-frame geometry and existing sample limits remain required.
Other reference composition and feature streams remain open.

## Independent references

The `jxl` 0.7.0 archive SHA-256 remains
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Consulted files were verified byte-for-byte against the archive:

| Source | SHA-256 |
| --- | --- |
| `render/stages/convert.rs` | `57a86a7c03938e023c702037a12c9a8318bfc3a98ecb4314b3cbcdc70c62cf18` |
| `frame/decode.rs` | `7c6964276f01b6d8d56661f0357c39bac8097ada88332eeaabfb02b169c4c0e0` |
| `frame/render.rs` | `e9728c0d5f072380e165cd9056524b3327ee0b136e5c8ef902380e6e16f6ca77` |
| `frame/mod.rs` | `f84f7e643436f790166aa66bfd5f86226d3238c52ba5f643a9d3f2cf101f8d05` |

The temporary conversion oracle contains 2,737 unchanged source bytes and uses
cached `jxl_simd` artifact SHA-256
`8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9`.
Its Rust wrapper SHA-256 is
`31d6b37e8133ca9519bfc65615a232d26fb9aa39ed34f5c95ce8cc4d476c5b2f`.
No Cargo build or network is used. The compile/reference guards exit zero,
peaking at 115,032,064/21,479,424 RSS bytes in 0.738/0.548 seconds.

The photo reference comes from API version 1 of the unchanged cached production
helper, SHA-256
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`,
verified before and after decoding. Its guard exits zero, peaking at 14,794,752
bytes in 0.359 seconds. No fresh source-build provenance is asserted for that
cached library. The 38,416 native RGBA bytes have SHA-256
`428db7635a1fc410a1d7d70c2e0e5f7c5f4a5911da74cbb544c8aebdfdd6d09d`;
the input SHA-256 is
`f895a94ea328cf2548fff9d1fd2d1b1bc03d22c0ebd8012c1dc66b25774c7eae`.
The LF frame is unfiltered 13×13 modular data; the final frame is 98×98 VarDCT.
Both V output modes compare the whole opaque image to the native straight RGBA
reference. Including the preceding 24 images, 25 independent images compare
**1,613,956 native RGBA bytes**, with 50 straight/premultiplied V decodes.

| Frozen manifest | SHA-256 |
| --- | --- |
| `modular-xyb.tsv` | `c195f2b84459ab38d6057306030db62b3063b644ff8aad4b10d1381882ab0367` |
| `lf-reference-files.tsv` | `705de2765b3c58ab0f186cd542dd283d34cf698ed5a1313a49b33934dfc5fad2` |

## Executed checks

The final seven-file selection is `modular_xyb`, `modular_restore`,
`vardct_restore`, `vardct_lf_reference`, `vardct_frame`, `lf_reference_frame`
and `vardct_rgba`, each with `_test.v`. It passes default GC, `-gc none` and
`-prod`. Every test and guard exits zero. Commands use current V with
`-memory-limit 10G -b c -cc clang`, `VJOBS=1`,
`V_MACOS_V3_NO_FALLBACK=1`, unavailable `RUSTC`/`RUST_CARGO` and separate
3 GiB guards with 180-second limits.

| Mode | Peak sampled RSS bytes | Guard seconds | Files |
| --- | ---: | ---: | ---: |
| Default GC | 336,281,600 | 40.229 | 7/7 |
| No GC | 425,459,712 | 35.170 | 7/7 |
| Optimized | 479,870,976 | 86.258 | 7/7 |

All 299 input hashes/change times remain unchanged throughout that selection,
including module fixtures, compiler, corpus driver and memory guard. The saved
manifest SHA-256 is
`bfbb42287ae9a5e2309f3c49c986dcfc4c5a9a2435b0b83cf01ec85fe6c7131d`.
Compiler SHA-256 remains
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
The host has 18 logical CPUs; observed load was 20.09/15.21/19.53. These are
correctness checks, not performance evidence.

Earlier failed focused attempts retain no full-run pass credit: the modular
restoration fixture initially selected nonpositive/nonfinite source-stage
sigmas; one reference test used invalid V optional syntax; and one validation
fixture inherited XYB=true while trying to test non-XYB rejection. Those test
repairs preserve every frozen expected record. The final selection above
executes every corrected case. The missing-LF regression retains a byte-aligned
file header and checks the explicit missing-reference error.

The managed post-commit hook requests coalesced production builds. The latest
completed bundle inspected has executable SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`;
it still uses Rust and cannot validate the unconnected V package. No browser
launch, duplicate production build or production parity claim is made. All
job locks were verified obtainable before scratch cleanup.
