# JPEG XL subsampled color frames

Slice `517e9fa83` stitches LF/HF components using their individual dimensions
and expands chroma before color restoration. Transform padding is cropped to
the coded document edge before interpolation, preserving replicated borders.
The existing source-matched horizontal/vertical chroma kernels are reused.
The three complete-file V entry points now decode JPEG-recompressed YCbCr
4:4:4, 4:2:2, 4:4:0 and 4:2:0. Subsampled LF references, XYB, RGB and adaptive
LF smoothing remain rejected before reading sections. This cohort has no
Gaborish/EPF; earlier independent restoration records remain exact.

Twenty independent native files compare **1,660,864 straight/paint RGBA bytes
exactly**, with matching legacy V entry-point outputs. Each sampling mode has
five dimensions: 1x1, 17x13, 33x25, 513x31 and 2056x17. Four files have multiple
LF groups. The original parser verifies the actual component shifts, YCbCr,
unit image sampling and disabled smoothing/restoration. Frozen expected pixels
come only from the cached native decoder; no candidate pixels or tolerances
supply gold. New records count once; the package has **282,933 source records
and 90 test files**.

`jpegxl/testdata/jpeg-chroma-files.tsv` SHA-256 is
`88519a00eba9f2774767db8f726ad94b3ea5e5d2e42d16dbc1a8bd294ea04062`.
Source/crate, native helper API 1 and cached parser/encoder pins follow
[the alpha report](JPEGXL_V_VARDCT_ALPHA.md). The additional source
`render/stages/chroma_upsample.rs` was byte-verified against the same archive,
SHA-256 `2e0b5d19d973e501018fba91228f5971dd416d3ae3022f1483afea152f06286f`.

The temporary encoder makes quality-90 JPEGs through installed libjpeg and
passes their coefficients to libjxl 0.11.1 with JPEG reconstruction metadata
disabled, yielding raw JXL codestreams. libjpeg SHA-256 is
`f68ae65710cf6c3d24bc67c837dad133f3ac2fec823c5bbc5297c8797f0c1264`.
All reference inputs remain pinned before/after generation. Encoder
source/executable SHA-256:
`c87ed43f581ac75bb0f268dba11dcf859978e521f59b5e0de69e01456af51a59` /
`315bf31b9de2ea641adc27a5b9e7d430bd3ed2bb3c7ce273420289a0e85ba936`.
Original parser caller source/executable:
`d59a451e0f49e01289dfd1dcf9342e4d3909a3b5db0d8a4b9b400f46229a2aa3` /
`ac70b900a669cfb70ccb9bcf9001bcd5af91cd0f4d6cd3be4279a45d6c2e95e5`.
Reference driver:
`d2e3a87f28c72848245b56b75d001cff8e35a3c7d126023307281ca23092b747`.
Encoder/parser compilation and reference creation exit zero under separate
3 GiB guards; reference creation peaks at 27,721,728 bytes and takes 0.887 seconds.
No fresh build provenance is asserted for the cached native helper.

The compiler/invocation policy follows the alpha report: current V 0.5.2
a5bda29, `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler paths,
`VJOBS=1`, no compatibility fallback, separate 3 GiB guards/240-second timeouts.
Focused selection: `jpeg_chroma_frame_test.v`, `vardct_frame_test.v`,
`vardct_restore_test.v`, `rgba_test.v`.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 4/4 | 338,116,608 | 32.528 |
| No GC | 4/4 | 936,886,272 | 35.333 |
| Optimized | 4/4 | 480,755,712 | 37.096 |

All tests/guards exit zero with 524 unchanged input hashes/change times across
both snapshots, manifest SHA-256
`3ace9261c12ad6b1ca8a603e79b3a3be6e49c370586fcbe763af299baddf57c0`.
Cadence is **6/10** after the 84-file checkpoint. No full 90-file run or
performance improvement is claimed. Production still uses Rust; the managed
commit hook requests rebuilding, with no extra manual browser build/launch.
Wider subsampled combinations, original-profile modular rendering beyond
lossless, wider extra channels, feature streams, composition, larger entropy
maps and production/tool integration remain. Removing all Rust is unfinished.
