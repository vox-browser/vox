# JPEG XL modular XYB alpha

The next slice (`f983fda0c`) allows one unscaled 8-bit alpha channel in modular XYB images
through `decode_rgba`. The modular decoder reconstructs all four integer planes;
only the first three enter XYB conversion and color restoration. Alpha retains
its own samples for final straight/paint quantization. The existing public
opaque renderer and opaque entry points still reject extra channels. Combined
color/alpha samples retain the 64-million-sample budget. Wider/resampled alpha
and LF alpha dependencies remain outside this slice.

Twenty independently encoded images compare **1,800,640 RGBA bytes exactly**
across straight and paint requests. Sizes, alpha patterns, associated-alpha
metadata and orientation follow the earlier VarDCT-alpha cohort, using modular
encoding instead. Eight files have multiple groups; four have two LF groups.
The original parser confirms 512-pixel groups for the smaller images and
256-pixel groups for the two largest sizes, rather than one uniform group size.
Five files have associated alpha. No candidate output supplies expectations.

The package now has **282,821 independent source records and 87 test files**.
The new 20 file records count once; reusing older records adds no source cases.
`jpegxl/testdata/modular-alpha-files.tsv` SHA-256 is
`9a989c5ece7e0c665bea6f69593ac97657bd389df74bff6961c6f1e28d9468b5`.

## Source and reference identity

The checksummed `jxl` 0.7.0 source, unchanged cached parser artifact, native
helper API version 1, libjxl 0.11.1 encoder libraries and their pins are the
same as [the VarDCT alpha report](JPEGXL_V_VARDCT_ALPHA.md). Native helper and
parser artifact identities are verified before/after reference creation; no
fresh build provenance is asserted. The source render pipeline converts
modular XYB color independently of alpha, then premultiplies after sRGB transfer.

Temporary encoder source/executable SHA-256:
`0b07c3011ba30b1a922e7a537b00315c1068dd54937962f7a46ba2a9364f8ee6` /
`40317170cb8e4a2b135fb17e6850ec6090e749aa72eca44c85927b14cc0d91c5`.
Original parser caller source/executable:
`7fbf2cc8184446a3b3986b8ff5617b74abfb47582e7b3a46351631b0e598fc3a` /
`d28f04d24107a3fe88e8952fc9c1398968d7ab45369784ee7b3830ae85a52518`.
Reference driver:
`e545ebd6b4ec83f758bba98419e7d95087269b0ed94fb6b074d0b30040a33409`.
The later geometry-only caller source/executable are
`35169482a8037b589a2e543c3c04653fd41f4af2b38f902396566a973772b822` /
`570b210cefa8a29e242d3ab45281bcace6da7dcb2fd1e39db982222a0646d8e1`.
Its header observations do not change expected pixels or add source records.
Encoder/parser compile, native reference creation and geometry inspection all
exit zero under separate 3 GiB guards. Native reference creation peaks at
28,966,912 sampled RSS bytes and takes 1.170 seconds.

## Executed checks

The compiler and invocation policy match the VarDCT-alpha report: current V
0.5.2 a5bda29, `-memory-limit 10G -b c -cc clang`, unavailable Rust compiler
paths, `VJOBS=1`, no compatibility fallback, separate 3 GiB guards and 240-second
timeouts. The focused selection is `modular_alpha_rgba_test.v`, `rgba_test.v`,
`modular_color_frame_test.v` and `lf_reference_frame_test.v`. It preserves all
previous unified-image references and 512 modular conversion records.

| Mode | Files | Sampled peak RSS bytes | Guard seconds |
| --- | ---: | ---: | ---: |
| Default GC | 4/4 | 340,082,688 | 38.814 |
| No GC | 4/4 | 938,164,224 | 44.430 |
| Optimized | 4/4 | 487,407,616 | 58.672 |

All final tests and guards exit zero. The final snapshot covers 404 unchanged
input hashes/change times, manifest SHA-256
`ddb42edad169a8477a6d1e9da7b6f514433b41c44e2489691e2de72f7aef37c7`.
The first default batch has three retained passing files and one test compile
failure from using an unavailable array-filter index. The corrected alpha test
then matched every native image but failed an assumed group-count assertion.
The original parser independently establishes eight grouped files; correcting
that assertion does not change implementation or expected pixels. Neither
failed batch receives whole-run pass credit.

Cadence is **3/10** after the full 84-file checkpoint; no full 87-file run or
performance improvement is claimed. Production still uses Rust, and no extra
manual production build or browser launch is used to validate this unconnected
V package. The managed commit hook requests the normal coalesced rebuild.
LF alpha dependencies, wider/resampled extra channels, chroma sampling, feature
streams, frame composition, larger entropy maps and production/tooling
integration remain. Removing all Rust dependencies is unfinished.
