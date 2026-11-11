# JPEG XL modular RGB and grayscale output

Slice `4e28d3291` extends `decode_rgba` to original-profile modular RGB and gray
images with restoration and image/alpha upsampling. Integers are normalized
before Gaborish/EPF, image upsampling, alpha premultiplication and positional
byte quantization. Gray output repeats the restored gray component. The common
owner now parses the file once and uses an explicit decode mode; the older
opaque APIs retain their XYB/VarDCT contracts. The standalone lossless APIs
retain their narrower contracts.

There are **128 new native file records and 8,564,736 exact straight/paint RGBA
bytes**: RGB/gray, ramp/associated alpha, 33x25/513x31 dimensions, 1x/2x/4x/8x
image/alpha factors, EPF 0–3 and alternating Gaborish. The larger ramp files
also rotate output. Original source headers verify non-XYB modular encoding,
actual restoration settings and alpha/image factors. Previous small-image,
grouped-lossless, preview and opaque references are reused without adding cases.
The package now has **283,061 independent records and 91 test files**.

`jpegxl/testdata/modular-rgb-files.tsv` SHA-256 is
`02bc29a8f97dcb56066f6ae9aa45433debb1b55e3b7ad9305006205c257bf7e4`.
Source/crate, native helper API 1, cached parser artifact and installed encoder
pins follow [the alpha report](JPEGXL_V_VARDCT_ALPHA.md). Native library/tool
identities are verified before/after reference creation; no fresh provenance
is asserted for the cached helper. Expected pixels come exclusively from that
helper, without candidate-derived gold or changed tolerances.

Temporary libjxl 0.11.1 encoder source/executable SHA-256:
`b0593d3d652abe48ef3ebe013cad9a6934a59352a9b2be6d82597e2ee0d84b0f` /
`32f0dff07641a27fcd259eb9b009e9fd265c4d8b83320dbdd67bcdafae89e34f`.
Original parser caller source/executable:
`6940f3d949160aa8d2ad63f57f3bba97fd866e5dd3b18f65d4d35a97c9fb26a4` /
`4a9bd6ac92296622fcc7570a106b0b5135384f1330b68e09d99b2826cee9834c`.
Reference driver:
`03f74f1201b0f23d6a06204d9af9a7fb4ea92fc3ad0c1db92172a10d35ff34d7`.
Encoder/parser compilation and native reference creation exit zero under
separate 3 GiB guards. Reference creation peaks at 38,764,544 sampled RSS bytes
and takes 1.068 seconds. These temporary migration tools do not become permanent
developer dependencies; checked-in verification uses V alone.

Current V is 0.5.2 a5bda29, executable SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Commands use `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler paths,
`VJOBS=1`, no compatibility fallback, separate 3 GiB guards/240-second timeouts.
The focused selection is `modular_rgb_frame_test.v`, `rgba_test.v` and
`opaque_rgba_test.v`. It preserves the earlier 62 opaque image references,
26 grouped-lossless records, six lossless-preview files and 498 small-image
result/rejection records through the common output owner.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 3/3 | 328,335,360 | 103.279 |
| No GC | 3/3 | 955,006,976 | 96.891 |
| Optimized | 3/3 | 461,668,352 | 96.213 |

All tests/guards exit zero. Both snapshots cover 655 unchanged input hashes/
change times, manifest SHA-256
`7eaa2ff15553519f4924157e4668031aaa899e5b6af705a292fb931498f09edd`.
Cadence is **7/10** after the full 84-file checkpoint; no full 91-file run or
performance improvement is claimed. Production still uses Rust; the managed
commit hook requests rebuilding, with no extra manual browser build/launch.
LF original-profile modular output, wider extra channels, wider subsampling,
feature streams, frame composition, larger entropy maps and production/tool
integration remain. Removing all Rust dependencies is unfinished.
