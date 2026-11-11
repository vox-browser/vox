# JPEG XL alpha with LF references

Slice `ddd1eeff8` allows one unscaled 8-bit alpha channel while decoding LF
reference frames. Modular LF decoding reconstructs and validates all channels,
then saves only the three restored source-color planes. LF alpha never
premultiplies those reference colors. Visible VarDCT decoding consumes its own
alpha stream alongside coefficients while reading the saved LF colors. Sample
budgets include extra channels; unsupported alpha geometry fails before reading
payloads. Legacy opaque entry points retain their contracts.

Twenty new independent native files compare **1,800,640 straight/paint RGBA
bytes exactly**. Each contains a modular LF frame at level 1 followed by a
visible VarDCT frame that depends on it. The original parser verifies both
frames and their section endpoints. The size/pattern family matches the
previous alpha cohorts, including associated alpha, orientation, multiple LF
groups and nonzero HF. Removing the LF frame, truncating either payload, or
requesting unsupported extra-channel geometry is rejected.

The package now has **282,841 source records and 88 test files**. New file
records count once; reused references add no cases. The manifest
`jpegxl/testdata/lf-alpha-files.tsv` SHA-256 is
`4c8fbbf9366eda5fcc99404bda122046f1893acad07b1e843536aac26e45d405`.

Source, cached original parser artifact, native helper API/library and installed
encoder-library pins follow [the VarDCT alpha report](JPEGXL_V_VARDCT_ALPHA.md).
Expected pixels come only from native decoding, with identities verified
before/after generation; no fresh provenance for the cached helper is asserted.
The temporary libjxl 0.11.1 encoder selects progressive DC level 1. Encoder
source/executable SHA-256:
`28152df3ec6fa5da5e1a1d378c6a69146f87c05a59f35ed9f09f61cb77269ada` /
`35f9570f242cd5075563dd5c70ef5b77913d8782f64198a0a6af425ac44ae0df`.
Original parser caller source/executable:
`6f36aefeea02a3c07786c5b779ea9369b985b4f9ac90b13db48ba9165a9f0d7b` /
`c30d506ce1a48903fbd5871d768c00a5a0ed6261d4739f5c63c07ac0e3e25cd7`.
Reference driver:
`21ed58f67569fc20d30b692e1a2799ab163686c95718999f59478cc14c68e75b`.
Encoder/parser compilation and native reference creation exit zero under 3 GiB
guards. The reference guard peaks at 32,931,840 bytes and takes 0.951 seconds.
No candidate pixels or changed tolerances supply expected results.

The compiler and invocation policy match the VarDCT-alpha report: current V
0.5.2 a5bda29, `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler
paths, `VJOBS=1`, no compatibility fallback, separate 3 GiB guards and 240-second
timeouts. The focused selection is `lf_alpha_rgba_test.v`,
`lf_reference_frame_test.v` and `modular_alpha_rgba_test.v`.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 3/3 | 337,723,392 | 26.090 |
| No GC | 3/3 | 376,651,776 | 25.796 |
| Optimized | 3/3 | 480,804,864 | 47.276 |

All tests/guards exit zero; all 426 selected input hashes/change times remain
unchanged across both snapshots, manifest SHA-256
`7554af19f677e19e104184b6552b5514c42aa5de5f35c38e1db9829ba8abf54b`.
No full 88-file run or performance improvement is claimed. Cadence is **4/10**
after the full 84-file checkpoint. Production still uses Rust; the managed
commit hook requests rebuilding, with no extra manual browser build/launch.

Wider/resampled alpha, whole-frame chroma sampling, feature streams, frame
composition, non-visible preview dependencies, larger entropy maps and
production/tool integration remain. Removing all Rust dependencies is unfinished.
