# JPEG XL noise color application

Slice `d42997e69` applies convolved random planes to source-space color, retaining
LUT interpolation, strength clamping, correlated red/green noise and the source
color-correlation parameters. LUT precision is explicit: NEON/SSE use truncated
BF16 entries; scalar/AVX source implementations retain full table precision.
The V arithmetic does not depend on compiler multiply/add contraction. Inputs
remain unchanged and malformed geometry/nonfinite parameters are rejected.

There are **768 independent source records and 73,728 exact output float
words** from the original public `AddNoiseStage`. The first 512 use ten-bit
LUT values, varied finite color/random rows and custom correlations. A further
256 use exactly representable BF16 LUTs: both V precision choices match those
native results. This does not establish native scalar/AVX execution or a
full-precision non-BF16 cohort. Reusing those 256 records in both modes adds
no source cases. The package has **284,991 records and 93 test files**.

The original crate/cached artifact pins follow
[the noise-state report](JPEGXL_V_NOISE_STATE.md). The additional `jxl_simd`
0.7.0 archive SHA-256 is
`efab4eb62605769d5b919b90331cd1e9c100d0e728fd292b0c39b18a3af712fa`;
its cached artifact SHA-256 is
`8ffcd29bf561942e5875d775514e131ab594cb1f0e209a0c2f6e1fcc35ad71b9`.
All consulted files were byte-verified against their archives:

| Source | SHA-256 |
| --- | --- |
| `jxl/render/stages/noise.rs` | `ae42298b48bc66bb88fb76eb4201b023042fbb3aee2fb835641f12b25bbd58b4` |
| `jxl_simd/aarch64/neon.rs` | `3f552100012767325f88852e19f3a9b974db29f69b157f9f7897e927c3713636` |
| `jxl_simd/scalar.rs` | `21c5e3e4176ecb2d4f6f3cad49cc810e34a24ad8c917a9be007d07b0f45008a2` |

A temporary Rust caller invokes the unchanged original stage on ARM64, including
its native SIMD dispatch. It checks that the three random rows remain unchanged.
No candidate code supplies expected words. Artifact/source identities are pinned
before/after generation, with no fresh crate build provenance asserted.
Final producer source/executable SHA-256:
`2462bc8441bfb69b3b0d9830e9462da65ebd6d6f67243fae5b82adb0d8194b8b` /
`0ba5a85512b2c0f61226ec3a2b49ff82a955c23d5019ecc7805cd67eeb0510e3`.
Reference driver SHA-256:
`0f9979376a735f665795ff862819609fc82b304fb5fbcba43e60c0c2abbeec71`.
`jpegxl/testdata/noise-application.tsv` SHA-256:
`09c535d21da70ecab8fb144c528ae65067809fb9f06ebc7f41913984661bcf3f`.
The first 512 expected records remain unchanged when the exact-LUT cohort is
appended. Final producer/reference guards exit zero under 3 GiB caps, peaking
at 99,368,960 / 30,228,480 bytes in 0.953 / 0.731 seconds.

Current V and invocation policy follow the noise-state report: compiler
0.5.2 a5bda29 with the same pin, `-memory-limit 10G -b c -cc clang`, unavailable
Rust compiler paths, `VJOBS=1`, no compatibility fallback and separate 3 GiB
process-tree guards/240-second timeouts. Selection: `noise_apply_test.v` and
`noise_test.v`.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 2/2 | 290,914,304 | 10.717 |
| No GC | 2/2 | 284,966,912 | 11.265 |
| Optimized | 2/2 | 535,920,640 | 22.353 |

All final tests/guards exit zero with 662 unchanged input hashes/change times,
manifest SHA-256
`cf8cd5339f09d35b1e71aaaf1e4eb81637f35bc4ee2e35db62b975d6b4f0e561`.
The first default batch failed by one ULP in blue; an attempted explicit fused
operation did not fix it. Both failed batches retain no whole-run pass credit.
A direct original-correlation probe and a libSystem float-arithmetic diagnostic
identify the source's unfused multiply/add. Case 2's first blue word must be
`0xbfb517c8`; a fused result is `0xbfb517c7`. Separate expressions prevent C
contraction and preserve the two source roundings in every final mode. Expected
words and tolerances are unchanged.

Cadence is **9/10** after the full 84-file checkpoint; no full 93-file run or
performance improvement is claimed. This translates color application only:
random-field construction, convolution and whole-file noise integration remain.
Production JPEG XL and its native developer tool still use Rust. Patches/splines,
composition, wider channel/LF combinations and production/tool integration also
remain. The managed hook requests rebuilding; no extra manual browser build or
launch is used to validate this unconnected V package.
