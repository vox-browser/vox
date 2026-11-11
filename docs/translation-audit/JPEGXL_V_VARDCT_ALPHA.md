# JPEG XL VarDCT alpha output

Two slices after the 84-file checkpoint share modular frame state with VarDCT
and add `decode_rgba` for the existing lossless, opaque modular XYB and VarDCT
paths, including one unscaled 8-bit VarDCT alpha channel. Production JPEG XL
and its native developer tool still use Rust.

The raw-plane slice is `919a1909a`. LF modular channels are consumed before HF
metadata; HF modular channels follow each coefficient pass. Global transforms
are reversed after all tiles have been written. The previous opaque frame API
still rejects extra channels. Color and alpha samples share the allocation
budget, and incomplete channel coverage cannot yield zero-filled output.

The RGBA slice (`108b90d3a`) normalizes alpha, converts color to sRGB, multiplies color by
alpha for paint requests, and applies positional byte quantization before
orientation. Associated alpha is not multiplied again; source behavior also
does not unpremultiply associated data for straight requests. Existing opaque
entry points retain their contracts. The unified entry point routes non-XYB
modular files through the existing bounded lossless implementation.

## Independent references

The reference is cached `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
The consulted source was byte-verified against the archive:

| Source | SHA-256 |
| --- | --- |
| `frame/decode.rs` | `7c6964276f01b6d8d56661f0357c39bac8097ada88332eeaabfb02b169c4c0e0` |
| `frame/mod.rs` | `f84f7e643436f790166aa66bfd5f86226d3238c52ba5f643a9d3f2cf101f8d05` |
| `frame/render.rs` | `e9728c0d5f072380e165cd9056524b3327ee0b136e5c8ef902380e6e16f6ca77` |
| `frame/modular/mod.rs` | `8c1e521cd0343d6d55b6f7d8f203c3c5655d5a98eb0229a501b7424f03bab853` |

A temporary C++ encoder uses installed libjxl 0.11.1 to create 20 nonuniform
VarDCT XYB images: 17x13, 33x25, 257x17, 513x31 and 2056x17, each with constant,
binary, ramp or associated alpha. Invisible colors are retained. One image
has orientation 6. Noise, patches and progressive DC are disabled; the original
crate header inspector verifies one pass and no unsupported feature flags.
TOCs have 1, 5, 6 or 13 entries. Four images have two LF owners and nine HF
groups. Both global and grouped modular alpha payloads execute, alongside
nonzero HF coefficients. Five files explicitly declare associated alpha.

The native helper API version is 1, library SHA-256
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`.
Its identity and the cached original parser artifact were verified before and
after reference generation; no fresh build provenance is asserted. The parser
artifact SHA-256 is
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`.
Expected pixels come exclusively from native straight/paint decoding.

`jpegxl/testdata/vardct-alpha-files.tsv` SHA-256 is
`143e0c583d84b8c6d27cb16058f0365b726561f46d034b472d7a153b98beab05`.
Its 20 records compare all **1,800,640 RGBA bytes** across both output requests,
and all **225,080 raw alpha bytes**, exactly. Earlier 12- and 16-file references
were retained unchanged while adding associated-alpha and multiple-LF files.
No candidate pixels, tolerances or gold overrides supply expected results.
These 20 records count once: the package now has **282,801 independent records
and 86 test files**. Reused older references add no records.

Temporary encoder source/executable SHA-256:
`fe19ee34a0621c6fb032d4532c77fa1fc38cd9a054b83cef4269cb6026b4deb8` /
`f57cd3b5df20ac401e93a0aacebc4293561429df51fb63e72bd7b5c5d79ae633`.
Parser caller source/executable:
`0f679d63ba8ae9e6d039915c2f18930996a20c263801aa36fb2dacbf5b8e9734` /
`a70cf362f4a6a19815573cd1283240002042b47979d74e90fb90e914905623b0`.
Reference driver:
`9a45e70c0b7f5c70574dd2204589708db82628bf24fc29171cf4a0e9314f54aa`.
Installed encoder libraries were pinned: libjxl
`fc1afc4e35356c46769192d4c306aaeeec99fccb54524e506aa3fbc87d0a50fd`,
libjxl_cms `4c59805d9b12491ca48409e1d3373631eca437e558603832ebf99cbb7d00571b`,
libhwy `cdad55befa7b39d1c5cb2162fbc2e616a7f50c61b1003350455f405408168bad`,
Brotli decoder `b7616f7a7ed07ee1002c533db0291af054b2c6e03012eeed0f08b2a7e3e5b9c8`
and Brotli common `739887ff9bf51b5ca25410836527873fcc3ec326ce17b584f9a3ebc00cf1209b`.
These are temporary migration references; checked-in verification needs V alone.

## Executed verification

Current V is 0.5.2 a5bda29, executable SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Commands use `-memory-limit 10G -b c -cc clang`, `VJOBS=1`,
`V_MACOS_V3_NO_FALLBACK=1` and unavailable Rust compiler paths. Each focused
batch has its own 3 GiB process-tree guard and 240-second timeout.

| Selection | Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Raw alpha, modular frame, VarDCT frame | Default GC | 3/3 | 323,731,456 | 55.340 |
| Same | No GC | 3/3 | 320,913,408 | 60.355 |
| Same, resumed check | Optimized | 3/3 | 434,372,608 | 105.706 |
| Final unified output and legacy opaque output | Default GC | 2/2 | 337,182,720 | 46.573 |
| Same | No GC | 2/2 | 938,622,976 | 44.838 |
| Same | Optimized | 2/2 | 476,561,408 | 32.939 |

Raw checks cover `vardct_extra_channels_test.v`, `modular_frame_test.v` and
`vardct_frame_test.v`; all 380 input content hashes matched after resumption.
The original optimized check lost its process status and left an empty receipt;
it has no pass credit. Its lock was free before the fresh optimized check ran.
The final unified-output selection uses `rgba_test.v` and `opaque_rgba_test.v`,
with 382 scoped inputs and manifest SHA-256
`aeaf5aebc7f25d9f51ed72a5ee7485f0b4d9266000c6653bbec2add7932393b7`.
It also preserves 62 existing opaque native images, 26 grouped-lossless records,
six lossless-preview files and all 498 small-image result/rejection records.
All completed focused tests and guards exit zero with inputs unchanged.

The first raw-alpha batch failed because the global section contained an empty
entropy stream when all alpha samples were grouped. The bounded unused-section
rule already used by modular decoding fixes it; opaque no-extra sections retain
their stricter validation. The original failed batch has no whole-run credit.
A standalone corrected raw check passed before the final selections. The first
C++ encoder compile referenced an unavailable option; a separate associated
alpha assertion exposed missing explicit extra-channel metadata. Both failed
authoring attempts retain no pass credit. Final native reference creation and
inspection exit zero; the final reference guard peaks at 29,802,496 bytes.

Cadence is **2/10** after the full 84-file checkpoint. No full 86-file run or
performance improvement is claimed. The latest completed production executable
inspected was SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`,
receipt `20261109-112648-d0d016af`; it still uses Rust and cannot validate this
unconnected V package. The managed commit hook requests coalesced rebuilding;
no additional manual production build or browser launch is used for these checks.

Wider/depth/float extra channels, alpha resampling and LF alpha dependencies,
modular XYB alpha, whole-frame chroma sampling, feature streams, composition,
non-visible preview dependencies, larger entropy maps and production/tooling
integration remain. Removing all Rust dependencies is unfinished.
