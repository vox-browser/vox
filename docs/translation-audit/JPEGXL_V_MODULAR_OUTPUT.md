# JPEG XL visible modular XYB output

The next two slices after the preview work share modular XYB rendering between
LF frames and visible output, and add `decode_opaque_rgba` for opaque 4:4:4
VarDCT or modular XYB files. The older `decode_vardct_rgba` entry point retains
its VarDCT-visible-frame contract. Production still uses Rust; the new entry
point does not replace it.

| Slice | Commit |
| --- | --- |
| Shared modular XYB frame renderer | `9ecab355b` |
| Complete-file opaque VarDCT/modular XYB entry point | `16b9843ac` |

The package has **282,781 independent source records and 84 test files**.
The twenty new image records are counted once; reusing older conversion and
VarDCT references does not add source records.

`render_modular_xyb_frame` validates channel geometry and supported services,
normalizes the source integer storage during XYB conversion, filters at coded
resolution and upsamples before color conversion. The LF owner uses the same
renderer before saving reference floats. The complete-file owner preserves
container parsing, preview skipping, LF ownership, source-space restoration,
XYB/sRGB conversion, positional dithering and orientation. Straight and paint
requests coincide for this opaque subset.

The new files use a real nonuniform modular stream extracted from the Guardian
photo's LF frame. Its three progressive passes and two downsampling brackets
are retained, although every coded channel is in the global section. This
does not establish new grouped-payload or nonzero-HF coverage. The existing
grouped lossless references and the nonzero-HF Guardian photo retain their own
coverage. Alpha/extra channels, non-XYB modular rendering beyond the existing
lossless path, whole-frame chroma sampling, feature streams, wider composition,
non-visible preview dependencies and larger entropy maps remain open.

## Independent native files

The source remains checksummed `jxl` 0.7.0, archive SHA-256
`6513ef8722db71eea2b3806ea71b8d9b39481f214af295788d7ceb4d3395eb9e`.
Consulted files were byte-verified against that archive:

| Source | SHA-256 |
| --- | --- |
| `frame/render.rs` | `e9728c0d5f072380e165cd9056524b3327ee0b136e5c8ef902380e6e16f6ca77` |
| `frame/modular/mod.rs` | `8c1e521cd0343d6d55b6f7d8f203c3c5655d5a98eb0229a501b7424f03bab853` |
| `headers/frame_header.rs` | `54313497dd11a72a365af3000d0d60fbbb8745a4b18729c2e0effdee6bdf01ad` |
| `headers/toc.rs` | `d45dc800777e372a3c9f7b84e1e2fb456ccfc2a4b331800643e01a01a5ef89f1` |

The cached original crate parser identifies the source frame header at bits
40–78 and the physical section payload at bit 152, with logical section sizes
`[412, 0, 0, 0, 0, 0]` and no permutation. The source image SHA-256 is
`f895a94ea328cf2548fff9d1fd2d1b1bc03d22c0ebd8012c1dc66b25774c7eae`.
An independently authored writer keeps those 412 entropy bytes and writes
regular-frame headers at their coded 13×13 geometry. It varies Gaborish,
EPF iterations 0–3, 1×/2×/4×/8× output, cropped dimensions and orientation.
Modular sigma is 1 in this cohort; other sigma values retain the
existing component references.

The temporary parser caller links the unchanged cached `jxl` artifact SHA-256
`06df072014bab7d540f1e8d29d7f78f24cae957d3e8619bd25a81b0d5bc66fe8`,
verified before/after reference creation. Caller source SHA-256 is
`8de4b664c499924f3ffa7e417035414201806b9dcefcf4ab2ddf0c820baca69f`;
executable SHA-256 is
`c838b13a22a715bda0a97e023d1e74d03a80a3a91bbc2a53301fb91e29eebbf5`.
The writer/reference program SHA-256 is
`affaa1bf1035f5de915c3a77b424bbafd1848780a9697835286861c60e8d5e7a`.
No translated parser or candidate pixels supply its expected results.

All **20 complete native images and 269,336 RGBA bytes** are frozen in
`modular-color-files.tsv`, SHA-256
`09043f6e03cc6d47ecdf55fe2b9f5a71096738094953003d288f391a8eb884d6`.
Expected pixels come exclusively from API version 1 of the cached production
helper SHA-256
`517b56ddf74be8fbb87160948cb39eea1873200120e799eea47631da4b39fda5`,
verified before/after decoding. No fresh build provenance is asserted for that
cached library. Both V output requests compare the whole opaque image exactly;
there are no pixel tolerances or candidate-derived gold. The new entry point
also checks all 42 existing opaque native image references. The older 512
modular XYB records compare all 130,560 source float words through the shared
renderer without being counted again as new source cases.

Reference generation uses cached artifacts without Cargo or network. Parser
compile/run and native reference guards exit zero. Their sampled RSS peaks
are 161,906,688, 1,916,928 and 24,739,840 bytes; elapsed times are 1.798, 7.296
and 1.222 seconds. The checked-in verification runs through V alone.

## Focused checks

Current V is `0.5.2 a5bda29`, executable SHA-256
`53ae5fd6323569d6e2915db8305b3db5603b700f4e2f0f1cb8968772acd041b7`.
Focused commands use `-memory-limit 10G -b c -cc clang`, the selected GC or
production flag, `VJOBS=1`, `V_MACOS_V3_NO_FALLBACK=1` and unavailable Rust
compiler paths. Each has its own 3 GiB guard and 240-second timeout. Every
focused test/guard exits zero.

| Selection | Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | --- | ---: | ---: | ---: |
| Shared renderer/LF/upsampling | Default GC | 3/3 | 279,642,112 | 81.650 |
| Shared renderer/LF/upsampling | No GC | 3/3 | 283,426,816 | 76.021 |
| Shared renderer/LF/upsampling | Optimized | 3/3 | 420,675,584 | 170.363 |
| Complete output/shared renderer | Default GC | 2/2 | 337,149,952 | 74.326 |
| Complete output/shared renderer | No GC | 2/2 | 300,220,416 | 85.720 |
| Complete output/shared renderer | Optimized | 2/2 | 383,647,744 | 126.101 |
| Final complete output | Optimized | 1/1 | 372,211,712 | 66.980 |

The first selection is `modular_color_frame_test.v`, `lf_reference_frame_test.v`
and `frame_upsample_test.v`. Its 335 input hashes/change times remain unchanged,
manifest SHA-256
`0909a7f13b84dd479f50507cfdabaa87ff10d04f605b5bbe1ad06227f5e7b1dc`.
The second is `opaque_rgba_test.v` and `modular_color_frame_test.v`, with 357
unchanged inputs, manifest SHA-256
`77530ef9143e84335dcdadaf7be489ff9227c0ea172c3c84f0eff210ea35f2ad`.
The final optimized output check follows removal of an unused private
premultiply argument; public signatures and opaque results remain unchanged.
Its 357-input manifest SHA-256 is
`35c7a06bef0211fc0ddba35d3491773059fcd39da42dc0710386ffdc751abade`.
The complete checkpoint below covers the final code in both GC modes.

## Full 84-file checkpoint

All 84 JPEG XL test files pass through `tools/check_translation_corpora.v` in
default and no-GC modes. Both runs have actual test, inner-guard, driver and
outer-guard exits zero. These two slices finish ten after the prior 74-file
checkpoint, resetting cadence to **0/10** at `16b9843ac`.

The outer command is current V with `-memory-limit 10G -b c -cc clang run
tools/check_translation_corpora.v --suite jpegxl --gc MODE --compiler
/Users/alex/code/v/v --jobs 1`, supervised by separate default 12 GiB guards
with 5,400-second timeouts. The V driver starts its own 3 GiB guard around
`v -memory-limit 10G -enable-globals -b c -cc clang -gc MODE test jpegxl`.
The two broad suites run serially, with unavailable Rust compiler paths.

| Mode | Files | Inner sampled RSS bytes / seconds | Outer sampled RSS bytes / seconds |
| --- | ---: | --- | --- |
| Boehm | 84/84 | 355,172,352 / 1,000.248 | 591,527,936 / 1,011.991 |
| None | 84/84 | 1,645,363,200 / 1,230.680 | 1,870,807,040 / 1,244.071 |

All 358 selected input hashes/change times remain unchanged across both modes:
JPEG XL sources/fixtures, the root module declaration, compiler, corpus driver
and memory guard. Manifest SHA-256 is
`a197446297fd858ce7208f347ef320fedd457a98c7b46dcb62567c1701abef7f`.
No passing source record, expected pixel or tolerance was changed. The package
now has 282,781 frozen source records. Passing this recorded corpus does not
establish arbitrary JPEG XL conformance or production replacement.

The 18-CPU host was heavily contended: broad-start loads were
124.35/131.86/129.68 and 207.72/171.21/148.43. Separate capped native-reference
preparation could run while the fixed V inputs were checked. These are
correctness results, with no performance claim. No extra production build or
browser launch is used for this unconnected module. The latest completed bundle
inspected has executable SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`
and still uses Rust. Managed commit-build requests remain coalesced. Job locks
are checked obtainable before deleting temporary reference programs and guard
reports. The production decoder and its native developer tool remain Rust
dependencies until the outstanding behavior and integration are completed.
