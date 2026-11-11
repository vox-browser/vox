# JPEG XL noise tables and random state

Slice `845d394cd` translates the eight-entry noise LUT parser and the original
Xorshift128+ generator. Both seed constructors retain the source's distinct
lane initialization and wrapping u64 operations. Successive eight-word batches
preserve lane order. This supplies state for a later rendering stage: noise
convolution, color application and whole-file noise remain unsupported, and
LFGlobal still rejects noise-bearing frames.

The independent references contain **1,034 LUT/truncation records and 128 RNG
records**. They compare all 8,192 accepted LUT float words, 80-bit consumption,
all ten byte-prefix truncations, both constructors and 12 successive batches
per RNG case: **12,288 exact u64 words**. The first LUT component covers all
1,024 possible ten-bit values. Inputs are unique within each cohort. These
1,162 new records bring the package to **284,223 source records and 92 test
files**; reused image references add no cases.

The original `jxl` 0.7.0 crate/archive and cached artifact pins follow
[the alpha report](JPEGXL_V_VARDCT_ALPHA.md). The consulted source was
byte-verified against the same archive:

| Source | SHA-256 |
| --- | --- |
| `features/noise.rs` | `6fb377cd28d7bcf42c413d3b2ed0d881aff64547c88fdcbb48569f4d30f35c80` |
| `util/xorshift128plus.rs` | `d27e42f128865ed929d0b9a7a46febd20fb7cfe156236fa9dcb94e591ffa21a4` |

A temporary Rust caller invokes the unchanged cached original `Noise::read`
and both `Xorshift128Plus` constructors/`fill` directly, without Cargo or network.
Expected values never come from V. Source/artifact identities are pinned
before/after reference creation; no fresh crate build provenance is asserted.
The frozen producer's source/executable SHA-256 are
`8dffd71438be03b76da967461115c8cb9a98b9e1c17be82ed600ee9c42665cf5` /
`8ad8c7ebdd76468f6d543c461a7b0c766321ff64df3450fdb65854ea9976ac28`.
Reference driver SHA-256 is
`bebb5d586aef47fe6b451d116a7d3d866285da90c8feb29bad5a83959551c9a1`.
The final producer compile and reference guard exit zero, peaking at 100,663,296
and 25,493,504 bytes in 0.417 and 0.715 seconds, respectively. Constructor seeds
and short prefixes were made unique before freezing; no expected output was
changed to obtain a V pass. Temporary reference tools are removed after checking.

Frozen manifest SHA-256:

| File | SHA-256 |
| --- | --- |
| `noise-headers.tsv` | `30a8e58711a16cf8382446c0756ec26ffee4bcea9f8a2b723f57b55c0af21b47` |
| `noise-rng.tsv` | `505563229ade179ee763a786c8d11085a2ffdbe1e05e1dd8d873e654123f8e53` |

Current V 0.5.2 a5bda29 uses the same compiler pin and invocation policy as the
alpha report: `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler paths,
`VJOBS=1`, no compatibility fallback, separate 3 GiB guards/240-second timeouts.
The focused selection is `noise_test.v`.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 1/1 | 288,456,704 | 5.824 |
| No GC | 1/1 | 284,082,176 | 6.026 |
| Optimized | 1/1 | 340,754,432 | 15.798 |

All tests/guards exit zero with 659 unchanged input hashes/change times,
manifest SHA-256
`3f186d95422b27a3045b3cab21f99759e86a3479146c130662e7ef8cff8a94ff`.
Cadence is **8/10** after the 84-file checkpoint; no full 92-file run or
performance improvement is claimed. Checked-in verification uses V alone.
Production JPEG XL and its native developer tool still use Rust. Noise rendering,
patches/splines, composition, wider channel/LF combinations and production/tool
integration remain unfinished. The managed commit hook requests rebuilding;
no extra manual browser build/launch is used to validate this unconnected package.
