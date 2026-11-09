# JPEG XL embedded preview skipping in V

Two further slices on 2026-11-09 preserve the native API's default preview
policy: `42a8c1d60` connects VarDCT output and `8bc84c4e1` connects the small
and grouped lossless entry points. Eight new native file references bring the
package to **282,761 source records and 82 test files**. Cadence is **8/10**
after the [74-file checkpoint](JPEGXL_V_FRAME_ASSEMBLY.md). No full 82-file run
or production decoder replacement is claimed; production and its developer
tool still require Rust.

`skip_preview` parses and postprocesses the preview frame using its own
dimensions, checks the sample/TOC budgets, validates the TOC and skips its
bounded sections. It never entropy-decodes the skipped pixel payload or lets
it supply pixels/references to the main image. The current subset requires
one visible final preview frame; non-visible preview dependencies remain open.
The source API otherwise processes those non-visible frames, so this bound is
explicit rather than a claim of unrestricted preview parity.

The following main frame retains its own context and bytes. Tests cover a
normal and deliberately invalid preview entropy payload, alpha in straight
and premultiplied output, grayscale, rotated dimensions, every truncation
through the preview/main boundary, absent-preview no-op and sample rejection
before TOC consumption. Existing small/grouped lossless and VarDCT references
remain unchanged.

## Source and native references

The source is cached `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
These consulted files were verified byte-for-byte against it:

| Source | SHA-256 |
| --- | --- |
| `api/options.rs` | `ba8ed4e21e10e58dac693815bcbc98c33a9d0b76a1fc7fe5ffa5da83ff4cba77` |
| `api/inner/codestream_parser/mod.rs` | `ec21114d5dab8ba079dedc9a5926b44e7cf1d2b5be67777ddd489a31c85c023b` |
| `api/inner/codestream_parser/frame_info.rs` | `3782c19b3b341d52f721c3ebb665e86683e23036d9cef6d7159f58c367dabc18` |

All native pixel references use API version 1 of the cached production helper,
SHA-256 `517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`,
verified before/after each reference. This does not claim a fresh source build
of that cached binary. Fixture construction and expected native pixels are
independent of V. No Cargo build or network is used; frozen verification
executes through V alone with unavailable Rust compiler paths.

Two VarDCT files preserve the original 33×25 nonuniform main frame and insert
an 8×8 preview. One replaces the preview's ten entropy bytes with `0xff`.
The native decoder still returns the same complete image, establishing its
skip policy independently. The 6,600 expected RGBA bytes are frozen by whole
image hash; V checks both opaque output modes. `preview-files.tsv` SHA-256 is
`3b87e8482984c41f5b40667d77bb1445e52611754545702977f43acc2b293112`.
The author/reference program SHA-256 is
`4b0fa336f56c156d4195f27040b5031f4e6467d1a71d02059f2d236e00795096`;
its temporary header helpers come from the program pinned in the
[upsampling report](JPEGXL_V_UPSAMPLING.md). Its guard exits zero, with sampled
peak RSS 18,268,160 bytes in 0.414 seconds.

Six lossless files insert normal/poisoned previews into the original RGBA,
gray and orientation-6 files. The original main frame and metadata fields
are preserved. The cached original crate's public `JxlHeader` parser supplies
metadata/transform bit boundaries; no translated parser supplies these offsets:

| Input | Metadata start/end | Complete header end |
| --- | --- | ---: |
| RGBA | 31/44 | 45 |
| Gray | 31/57 | 58 |
| Orientation 6 | 31/51 | 52 |
| Constant preview source | 25/26 | 27 |

The cached parser artifact SHA-256 is
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`,
verified before/after reference creation. The small Rust caller source SHA-256
is `8fa0d1954ea4e798bd472f3d60c06c78391f48ab72eb0d7cbfadd9584f9c1261`;
its executable SHA-256 is
`b3059b0a52bb2076b0065238a1f37c73204291873df130654f9226ca816e82f8`.
Compile/offset guards exit zero, with sampled peaks 161,611,776/32,768 bytes in
1.314/0.514 seconds. These sampled peaks can miss short-lived process RSS.

All **288 native straight/premultiplied bytes** also equal the prior independent
lossless gold. Both V lossless entry points check them, including alpha values
that distinguish straight and paint rows. `lossless-preview-files.tsv` SHA-256
is `c4d389eaed851f4cd78bf0f08856370ce3cf7d58ce2481f37c2d5f5000c5b25c`.
The author/reference program SHA-256 is
`25aba65ff3cee242dbc8f11c11a6d87afc8f491d43c47116d7f60e47ffe60425`.
Its guard exits zero, with sampled peak 245,760 bytes in 0.480 seconds.

## Checks

All checks use current V `0.5.2 a5bda29`, SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`,
`-memory-limit 10G -b c -cc clang`, the selected GC/production flag,
`VJOBS=1`, `V_MACOS_V3_NO_FALLBACK=1` and unavailable `RUSTC`/`RUST_CARGO`.
Each invocation has its own 3 GiB guard and 180-second timeout.

The first four-file VarDCT preview default run failed: three unchanged image
files passed, while `preview_test.v` failed compilation because its Size
assertion did not unwrap an option. Only that assertion was repaired; every
other input hash/change time remained identical. The corrected preview file
passes alone in default GC. The default result is therefore a four-file
composite, not a successful original whole-run/guard result. The complete
four-file selection passes fresh no-GC and optimized checks.

| Preview check | Files | Test/guard exits | Sampled peak RSS bytes | Seconds |
| --- | ---: | --- | ---: | ---: |
| Corrected default preview file | 1/1 | 0/0 | 337,444,864 | 10.081 |
| Full no-GC selection | 4/4 | 0/0 | 364,969,984 | 78.997 |
| Full optimized selection | 4/4 | 0/0 | 474,562,560 | 133.604 |

That selection is `preview_test`, `vardct_rgba_test`, `frame_upsample_test`
and `lf_reference_frame_test`, each `.v`. Its corrected 325-input manifests
are identical, SHA-256
`52cf16d1cbb52320b5b65c933328f9f3fe0cb8eec6aa90297f34753fd39c49ea`.

The later lossless selection is `lossless_preview_test.v`,
`small_lossless_test.v`, `modular_frame_test.v` and `preview_test.v`:

| Mode | Files | Test/guard exits | Sampled peak RSS bytes | Seconds |
| --- | ---: | --- | ---: | ---: |
| Default GC | 4/4 | 0/0 | 323,780,608 | 52.008 |
| No GC | 4/4 | 0/0 | 320,356,352 | 55.692 |
| Optimized | 4/4 | 0/0 | 357,646,336 | 77.288 |

All 333 input hashes/change times stay unchanged throughout those final modes;
manifest SHA-256 is
`e9c806c0edba1048c89b08eac732076d5208bd9ad3af2d2fbdfec47755136557`.
The 18-CPU host reached load 141.07/146.11/105.08. These are correctness checks
under contention, with no timing/performance claim. No extra production build
or browser launch is used for the unconnected V module. Managed post-commit
requests remain coalesced. Both jobs' guards completed and locks were verified
obtainable before scratch cleanup.
