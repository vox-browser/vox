# JPEG XL complete VarDCT noise output

Slice `bf2f9e2fb` reads LFGlobal noise parameters, constructs deterministic random
fields, performs the reflected 5x5 convolution, and applies noise after color
restoration/image upsampling and before color conversion. The current one-visible-
image owner uses source frame counters (1,0), including after non-visible LF
frames. A single RNG is shared by three channels within each 256-pixel subregion;
partial rows consume whole sixteen-sample batches. Alpha remains independent.
Zero LUTs preserve the unmodified output without allocating unused fields.

Whole-file output fixes the verified BF16 lookup profile across hosts, matching
the pinned ARM64 native helper. Original scalar/AVX full-table profiles may
produce different pixels and are not claimed as whole-file equivalents. The
color-stage full-precision option remains separate. Noise is currently limited
to regular XYB VarDCT output; noisy LF/modular/non-XYB frames remain unsupported.

There are **28 native files and 2,477,600 exact straight/paint RGBA bytes**.
Seven zero-LUT controls reproduce their original base pixels exactly. All 21
nonzero-LUT files change their native image. Seven verified bases cover opaque,
straight/associated alpha, orientation, global/grouped payloads, multiple LF
owners, TOC permutations and 1x/2x/4x/8x image sampling. Existing nonzero-HF
alpha inputs retain their entropy; the simplified opaque bases do not establish
new nonzero-HF coverage. The new file records count once: **285,019 source
records and 94 test files** total.

`jpegxl/testdata/noise-files.tsv` SHA-256:
`3cfb463177496205bc418e2e7f967c58e157aad15b3995bc0077c2e23e49a732`.
It freezes complete input/pixel/alpha hashes, LUT float words and frame geometry.
No expected value comes from V; references/tolerances are not adjusted for a pass.

## Independent native input construction

Original crate, cached artifact and native helper API/library identities follow
[the alpha report](JPEGXL_V_VARDCT_ALPHA.md), and kernel/lookup sources follow
[noise application](JPEGXL_V_NOISE_APPLICATION.md). Additional consulted files
were byte-verified against the same `jxl` 0.7.0 archive:

| Source | SHA-256 |
| --- | --- |
| `frame/decode.rs` | `7c6964276f01b6d8d56661f0357c39bac8097ada88332eeaabfb02b169c4c0e0` |
| `frame/render.rs` | `e9728c0d5f072380e165cd9056524b3327ee0b136e5c8ef902380e6e16f6ca77` |
| `headers/frame_header.rs` | `54313497dd11a72a365af3000d0d60fbbb8745a4b18729c2e0effdee6bdf01ad` |
| `headers/toc.rs` | `d45dc800777e372a3c9f7b84e1e2fb456ccfc2a4b331800643e01a01a5ef89f1` |
| `headers/encodings.rs` | `f4f5ace9aa04989430c5ba16b74c9a4027a34a7b0d559575430250db6b585500` |
| `headers/permutation.rs` | `b80c880161d6d44a4459ece643a5f734e9447432cec3df7b664b42a417f93d9a` |

An independent writer obtains flag/header/permutation boundaries from the
unchanged cached original parser. It expands all-default headers when needed,
sets the noise flag, retains the encoded permutation bits, writes fresh byte
padding/TOC sizes and inserts ten LUT bytes into logical LFGlobal. Existing
section payloads remain byte-exact. The four LUT patterns are zero, constant,
ramp and irregular values across the ten-bit domain. Original-parser verification
compares every semantic decoded file/frame field against the base, allowing only
the noise flag and nonsemantic all-default coding selectors to differ.

The bases are `vardct/gradient-33x25.jxl`, `vardct/gradient-512x16.jxl`,
`vardct-alpha/alpha-33x25-2.jxl`, `vardct-alpha/alpha-2056x17-2.jxl` and
`alpha-upsample/up-0-{c2-a4-513x31-3,c4-a4-33x25-2,c8-a8-513x31-2}.jxl`,
all under `jpegxl/testdata`. Their byte hashes and all reference tools/native
artifacts remain pinned before/after generation. Native decoding supplies the
expected straight/paint pixels. No fresh cached-helper build provenance is asserted.

Temporary tool source/executable SHA-256:

| Tool | Source | Executable |
| --- | --- | --- |
| Boundary reader | `683f0da549b22302ca41b3541e4c4348c1217b7b71facbed49e9452b81537440` | `08d88c1b413ab9f21c56d92b76a58e607e8b9c9f8b0f80e8306619e810a9b255` |
| Header verifier | `15ea842f31031268a8c467b728efb311da17f43c41e2333c1a699c85a23cc331` | `ca4bb1bdf9527f40967ff6675d7ded21cd7e1287b2f6db7630c203f65d5cd415` |
| Noise inspector | `df5dbb48c30d3d6c2f8df92424743e385f7342590bcdfb7c362178f61e078d39` | `74d9698ea48cd135966c922d2f5e941e0415c6047a680122a2ab34dc132495f4` |

Writer/reference-driver SHA-256:
`2117309304c996f94e122b2cc0bb07263d22d874e060fcfc622d4f169a2847a2`.
Final native reference creation exits zero under a 3 GiB guard: 45,531,136
sampled RSS bytes, 1.720 seconds.

The first libjxl encoder attempt did not emit a noise section and receives no
noise coverage. Early boundary-reader assumptions rejected all-default/permuted
headers; an initial writer then misplaced the encoded permutation by assuming
alignment before it. The original source aligns after permutation decoding.
Those failed authoring attempts receive no whole-run pass credit; the corrected
writer is independently verified before any V pixel comparison or gold freezing.

## Focused verification

Current V 0.5.2 a5bda29 and its pin follow the earlier reports. Commands use
`-memory-limit 10G -b c -cc clang`, unavailable Rust compiler paths, `VJOBS=1`,
no compatibility fallback and separate 3 GiB guards. Final guards allow 600
seconds for the heavily contended host; memory bounds are unchanged.

| Selection | Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Corrected whole-noise file | Default GC | 1/1 | 312,803,328 | 44.393 |
| Whole-noise/LFGlobal/noise-color/unified output | No GC | 4/4 | 536,707,072 | 137.623 |
| Same | Optimized | 4/4 | 498,794,496 | 137.255 |

The original default batch matched all native noisy pixels, but a helper test
found zero-sized fields accepted. The corrected generator rejects those shapes.
The three other default files retain their passing results; together with the
corrected standalone file they cover all four selected files. The failed
original batch has no whole-run pass credit. All final tests/guards exit zero;
693 final input hashes/change times stay unchanged, manifest SHA-256
`55dc5ac75b8f6693f2ddc212f250ac8eaf7c45c4f108ed44668571ef06c88066`.

The selection is `noise_frame_test.v`, `lf_global_test.v`, `noise_apply_test.v`
and `rgba_test.v`. Host observation: 18 CPUs, load averages
125.207/103.936/98.914. Durations are correctness-check observations, not a
performance comparison.

## Required full checkpoint

This is slice **10/10** after the full 84-file checkpoint. The full 94-file
checker runs in default and no-GC modes are pending; this report does not yet
claim a full 94-file pass or cadence reset.

Production JPEG XL and its native developer tool still use Rust. Patches/splines,
frame/reference composition, wider channel/LF combinations and production/tool
integration remain. The managed commit hook requests rebuilding; no extra
manual browser build or launch is used to validate this unconnected V package.
