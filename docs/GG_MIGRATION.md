# Migrating from Skia to vlib/gg

## Opt-in direct compositing for solid rectangular SVG masks

With `VOX_SVG_MASK_SOLID_RECTS=1`, the portable group player applies a
single pixel-aligned solid mask rectangle directly to the group's alpha.
It verifies the packed corners in device coordinates and uses the existing
premultiplication and luminance weights. Fractional boundaries use the
path rasterizer. An opaque rectangle covering the group needs no
per-pixel mask pass. The default uses the raster mask.

The focused raster tests compared all 65,536 channel and alpha pairs
against both canvas blenders and compared rasterized integer rectangles
with the direct coverage, including clipped, narrow, and reflected
rectangles. They passed with ASan and UBSan. The browser regression
checked partial alpha, reflected luminance, opaque coverage, and a
fractional edge.

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. The control and candidate executable SHA-256 values
were `2f98a0d0cbdf1ba4621255a1bf8535c57d6e26d32c8e81f833ad15d88a254510`
and `cd4e1a9734f4d827cbe6cc7961ab1c00719774d38328cd01c5aba93203e31a82`.
The default and opt-in modes matched the previous 800 × 600 document
captures for both fixtures at scroll offsets 0 and 42 CSS pixels. A
marker identified the document viewport. Diagnostics confirmed the
alpha and luminance rectangle paths in opt-in mode.

| Fixture | Decoded RGBA SHA-256 at 0 px | Decoded RGBA SHA-256 at 42 px |
| --- | --- | --- |
| Content masks | `7078409b2933f1e3648207611c4e2e4e5426cb66f48ed9db4466a3d08c7a8bbc` | `8e703dfc217ae9b2b5534378a5f3856eb21cc3835580c71d64b5b28a31d4b852` |
| Solid rectangle masks | `38ca83ed1a278acfde5fb4fe14f04b14b33982da4a58bb01583241f85fe60164` | `9802586f5ce9218ab97886d75b0d3d6eb5a66e3e7186153050ed8e1fc7f05c8d` |

The initial candidate `867bf2d039ddc0470d73ee78509a000d137434bd1ea5941bc4e624e7aba18834`
decoded a path before checking its rectangle. The content-mask
fixture stayed on the raster path and its median replay rose in both
pairs. Its median paint preparation time rose too, from 288 to 375 µs and
from 270 to 324 µs. The revised candidate checks packed corners directly
and checks the operation count before calling the rectangle helper.

| Initial fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Content 1 | 4.712 / 6.199 | 9.136, 23.110 / 9.354, 28.405 | 2130.5 / 2135 |
| Content 2 | 4.629 / 6.237 | 8.787, 22.762 / 7.525, 22.939 | 2127.5 / 2130.5 |
| Rectangle 1 | 13.526 / 7.491 | 14.598, 31.938 / 8.462, 21.944 | 3423.5 / 2684 |
| Rectangle 2 | 15.996 / 5.486 | 18.314, 36.207 / 8.021, 25.680 | 3418.5 / 2683.5 |

The packed-coordinate candidate
`c22a14f476faf2567e68597f02f40baccddefb7bbbcc59d6509f970ac3e0494d`
used the same direct path as the opt-in mode. Both cohorts used
alternating builds, fresh processes and private profiles, a 1024 × 712
Xvfb window, Mesa software rendering, and a one-second settle period.
JavaScript, GPU SVG replay, SVG texture reuse, and leading-row cropping
were disabled. Each trial processed 80 synthetic callbacks with
matching command counts and scroll offsets up to 1248 CSS pixels.
The content and rectangle fixture SHA-256 values were
`6dc176903d66f637659b97484bc34a89ee0357c828c182ff9fefca52b8f3f966` and
`cd16d9ff6d4817947444efa78d084354701b3805080a3183778229f6688b433d`.
Input hashes stayed fixed and browser and guard exits were zero.
Guest one-minute load ranged from 1.10 to 1.34 in the initial cohort
and 0.66 to 1.83 in the packed cohort on four vCPUs.

| Packed fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Content 1 | 4.396 / 8.876 | 8.961, 22.443 / 11.220, 26.595 | 2136.5 / 2134 |
| Content 2 | 4.705 / 9.437 | 9.084, 22.048 / 11.363, 26.457 | 2134 / 2136.5 |
| Rectangle 1 | 13.401 / 7.380 | 15.077, 25.236 / 8.081, 21.432 | 3421 / 2675.5 |
| Rectangle 2 | 13.376 / 9.087 | 15.538, 31.812 / 9.755, 25.425 | 3425.5 / 2680.5 |

The packed candidate saved 745–746 KiB per callback on the rectangle
fixture. Replay medians rose in both content-fixture pairs. Those
candidate trials had a median of three garbage collections per callback,
while both controls had zero. Paint preparation rose from 257 to
2501 µs and from 284 to 2510 µs. These software replay results leave the
direct solid-mask path opt-in. All 21 Linux browser checks, the pinned
Skia differential suite, and the macOS and Windows source checks passed.

## Skipping invisible SVG mask opacity groups

The mask player uses the bitmap compositor's opacity byte before
allocating an isolated layer. When that byte is zero, it advances to the
matching end marker, including across nested opacity scopes. The
line-path bounds check also skips empty scopes and groups wholly above
the clip. The opt-in row-band path can recognize groups below the clip.

The browser regression verified that opacity `.003` skips a nested
group, opacity `.004` still contributes one alpha byte, and a line
group wholly above the clip is skipped. Sibling and nested visible
groups still matched their expected pixels. The focused canvas layer
tests and pinned Skia differential suite passed.

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. The control and candidate executable SHA-256 values
were `ff14bdef6e5182048f190fca2b55c5c7175db7891ca8d59e0c726986a1a90ca4`
and `cc1bf01dd908d7fcf485d0bf80c8cb496231929b8c758bafc035dc971d24dee8`.
The ordinary, gradient, and invisible-group fixtures matched pixel for
pixel in 800 × 600 document captures at scroll offsets 0 and 42 CSS
pixels. The invisible-group fixture extends the solid mask regions to
170 pixels and adds a four-level opacity subtree at `.003` plus a
group above the clip. Its pixels matched the ordinary solid fixture.
The solid and gradient hashes match the
[previous opacity captures](#blending-svg-mask-opacity-layers-directly-on-linux).

Two alternating replay pairs per fixture used fresh processes and
private profiles, a 1024 × 712 Xvfb window, Mesa software rendering,
and a one-second settle period. JavaScript, GPU SVG replay, SVG texture
reuse, and leading-row cropping were disabled. Each trial completed 80
synthetic callbacks with matched paint command counts and scroll offsets
up to 1248 CSS pixels. The ordinary and invisible-group fixture SHA-256
values were
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51` and
`34c38493efc649a8bd7a32af592cf5e073ff6b66a0f22edf4d21ae825892d680`.
Input hashes stayed fixed and all browser and guard exits were zero.
Guest one-minute load ranged from 0.92 to 0.95 on four vCPUs.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Ordinary 1 | 7.059 / 6.439 | 13.375, 25.402 / 13.623, 29.785 | 2903.5 / 2905.5 |
| Ordinary 2 | 6.421 / 6.461 | 13.818, 26.074 / 13.375, 25.971 | 2901.5 / 2905 |
| Invisible 1 | 17.417 / 15.045 | 30.567, 34.771 / 17.520, 32.755 | 4970.5 / 3786 |
| Invisible 2 | 26.822 / 8.824 | 32.033, 49.871 / 18.050, 31.102 | 4968.5 / 3798 |

The invisible-group fixture allocated 1171–1185 KiB less per callback.
Its p95 fell by 43–44% across the two pairs. Its median varied between
trials, and ordinary-fixture timings were mixed. These results cover
software-rendered synthetic replay. All 20 Linux browser checks passed,
along with macOS source checks and Windows source checks for D3D11 and
OpenGL.

## Opt-in leading-row cropping for SVG mask opacity layers

With leading-row cropping enabled, the mask player stores a row band
around the occupied area of a line-only opacity layer. The scan converter
and gradient shaders use the original device coordinates. The blitter
subtracts the first row when addressing the layer's backing store.
Restoring the band uses its row offset in the parent and keeps the full
row width for both blend rules. Leading rows
are dropped when they account for at least a quarter of the layer
remaining after trailing-row trimming. Set `VOX_SVG_MASK_ROW_BANDS=1`
to enable the experimental crop. The default uses trailing-row trimming.

Focused tests matched the full-surface renderer for fractionally
transformed solid and gradient paths in both blend modes. A padded,
odd-width restore matched the full layer and preserved the surrounding
rows. The focused suite passed with ASan and UBSan, and the pinned Skia
differential suite passed. The browser regression checked nested groups,
growth and reuse across siblings, and a curve using the parent surface.

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. The control and candidate executable SHA-256 values
were `de754489737b6fd9f901f75e35d536c4053532a1b2a4b55bbe3c995d483b5206`
and `f60242a79478fb506352a9ef3a5b98f7a1554960d6283070be4ede1061c7a8ba`.
Both settings matched the previous 800 × 600 document captures for all
three fixtures at 0 and 42 CSS pixels of scrolling. The default matched
the previous row extents. The solid and gradient fixtures retained their
[earlier pixel hashes](#blending-svg-mask-opacity-layers-directly-on-linux).
The lower mask fixture raises both mask regions to 170 pixels and moves
the three outer opacity groups down 64 pixels. It produced a band of
84 rows starting at row 71. Its decoded RGBA SHA-256 values were
`665eafd32174c63f3b39f38acd3472dfe3bf80bcc06aec5e4a9a492c80318097` and
`9c05dd173cfaf171059a256ae717f6a67888ee0e99dd14b67667da7f4fdb100c`.

The initial candidate `de1c4bba6053679651d354dbcf4c9ae9dabc7f40840dbc859cac8c86bb38d5cb`
also trimmed small leading bands in the solid fixture. Its median replay
rose in both solid pairs, motivating the quarter-layer cutoff.

| Initial fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Solid 1 | 6.242 / 7.119 | 12.109, 30.114 / 11.966, 28.782 | 2903.5 / 2848.5 |
| Solid 2 | 6.227 / 6.406 | 11.684, 24.648 / 13.710, 24.919 | 2898 / 2848 |
| Lower 1 | 8.336 / 8.053 | 17.875, 36.504 / 16.481, 25.670 | 3916 / 3455 |
| Lower 2 | 8.470 / 7.758 | 18.333, 27.279 / 15.748, 32.177 | 3922 / 3455 |

The cutoff build `f3fdb092d86e8de700a41159dae6889474b14ce373b9ac18929c92a7f6da297a`
used the same crop as the opt-in path. Both cohorts used fresh processes
and private profiles, a 1024 × 712 Xvfb window, Mesa software rendering,
and a one-second settle period. JavaScript, GPU SVG replay, and SVG texture
reuse were disabled. Each trial processed 80 synthetic callbacks with
matched command counts and scroll offsets up to 1248 CSS pixels. The
solid and lower fixture SHA-256 values were
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51` and
`54b5bacc238da3f54c8e3647c5586d46ffadb9197e348c0898627955fb01d381`.
Input hashes stayed fixed and the browser and memory guard exited zero.
Guest one-minute load ranged from 0.80 to 1.03 in the first cohort and
from 1.00 to 1.23 in the cutoff cohort on four vCPUs.

| Cutoff fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Solid 1 | 6.046 / 8.367 | 11.318, 23.116 / 12.566, 28.464 | 2901 / 2902 |
| Solid 2 | 8.441 / 6.193 | 13.380, 23.158 / 13.493, 26.396 | 2894.5 / 2904 |
| Lower 1 | 8.917 / 14.536 | 18.185, 28.528 / 17.178, 28.919 | 3919 / 3461 |
| Lower 2 | 7.788 / 10.170 | 17.578, 26.491 / 15.555, 26.005 | 3926.5 / 3459 |

In the cutoff cohort the lower fixture allocated 458–468 KiB less per
callback and its p95 fell. Both lower-fixture median times rose. The
synthetic timing results leave the leading-row crop opt-in. All 20
Linux browser checks passed, along with macOS source checks and Windows
source checks for D3D11 and OpenGL.

## Omitting empty trailing rows from SVG mask opacity layers

The mask player bounds line-only opacity layers using device-space path
points, including those in nested groups. It keeps the original pixel
origin and row width, with a guard row past the last possible coverage.
Curve-containing layers use the parent height. At each opacity depth the
player reuses capacity across siblings and clears and restores only the
current layer's rows.

The browser regression covers a seven-row layer, growth to 91 rows,
a nested 67-row layer, reuse for a 66-row sibling, and a curved layer
that uses all 100 parent rows. A focused padded-stride raster test restored
a three-row, odd-width layer into a nine-row target and matched a
full-size transparent-padded reference with both blend rules. The test
passed with ASan and UBSan. The pinned Skia differential suite also passed.

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. Control and candidate executable SHA-256 values were
`9fc67fac31bf2229f38fa511dd3754a6d79eb0564574743f0ed3595634309de7`
and `3341757a07897de34455a4e039e4f4859f005959e177dd8a41affb13b9075241`.
The solid, gradient, and tall mask fixtures matched pixel for pixel in
800 × 600 document captures at scroll offsets 0 and 42 CSS pixels.
The decoded hashes matched the
[earlier opacity captures](#blending-svg-mask-opacity-layers-directly-on-linux).
The tall fixture raises both 100-pixel mask regions to 170 pixels and
leaves the painted paths at their original heights. Its diagnostics
reported restores as short as 66 rows within a full 170-row region.

Two alternating replay pairs per fixture used a 1024 × 712 Xvfb window,
software OpenGL, fresh processes and private profiles, and a one-second
settle period. JavaScript, GPU SVG replay, and SVG texture reuse were
disabled. Each trial completed 80 synthetic callbacks with matched
command counts and scroll offsets up to 1248 CSS pixels. The solid and
tall HTML SHA-256 values were
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51` and
`93cba5210e94a8710c7bc79d2f6d403c7974deafb4f79c2530b2f640ba25123d`.
Input hashes stayed fixed and both browsers and the memory guard exited
zero. Guest one-minute load ranged from 0.67 to 1.99 on four vCPUs.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Solid 1 | 6.647 / 6.847 | 13.944, 24.893 / 14.247, 29.486 | 3035.5 / 2898.5 |
| Solid 2 | 7.228 / 6.609 | 15.811, 26.082 / 13.976, 31.291 | 3030 / 2899.5 |
| Tall 1 | 9.155 / 9.338 | 20.884, 30.517 / 17.747, 33.393 | 4084 / 3516 |
| Tall 2 | 15.375 / 8.567 | 22.297, 48.143 / 17.785, 38.667 | 4086.5 / 3512.5 |

Allocation fell in every pair. The first pair for each fixture had a
slightly higher candidate median, and the maximum rose in three pairs.
The second tall control ran at the highest guest load and had a much
higher median than the first. The timing results cover synthetic replay
with varying load. All 20 Linux browser checks passed, along with macOS
and Windows D3D11 and OpenGL source checks.

## Blending SVG mask opacity layers directly on Linux

An isolated mask layer has the same dimensions and pixel origin as its
parent. On Linux, a disjoint premultiplied sRGB layer can now restore
directly into the parent's rows using the existing 8-bit source-over
rounding. Transparent pixels leave the backdrop untouched. Large restores
can use the existing row workers. The shared entry point selects the
legacy sprite blend on macOS and Windows.

Focused tests compared the direct blend with image replay at all 256
opacity bytes, using every source alpha byte, padded strides, and an
odd-width target. The large restore matched with default and forced serial
scheduling. Invalid and aliased layouts declined the direct path. The
focused tests passed with ASan and UBSan, and the pinned Skia differential
suite passed, including 10,000 canvas image draws.

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. Control and candidate executable SHA-256 values were
`f076eb4b88a922bdd3653aaf5fcf0edc4d6e3bb9ec28410529850e6fcff807ab`
and `6854af820046dc7e274637ef131642696a6f6a7cfbdf21ea303632bd663d5225`.
The 800 × 600 document captures matched pixel for pixel at 0 and 42 CSS
pixels of scrolling. Diagnostics confirmed that the portable player
composited the isolated alpha and luminance groups. The solid fixture also
exercised nested and sibling groups.

| Fixture | Decoded RGBA SHA-256 at 0 px | Decoded RGBA SHA-256 at 42 px |
| --- | --- | --- |
| Solid opacity groups | `9b8b28f0a6f88bc8aa43e67bd781a007929e2ed357705ef5296a4637d3957797` | `ea96e6d798c7c050881db806327df547beab92f82d177109a44911c4c7a8e7b6` |
| Gradient opacity groups | `a42cf4b37188b15819173e6af7f86314c9296becd6072b603036e6f5148a6933` | `b1ab791c2350016696a2655f4b333f094b6d3be2c0d7874fe5df519ef2f7db99` |

The synthetic replay cohort used fresh processes, private profiles and
caches, a 1024 × 712 Xvfb window, software OpenGL, and a one-second settle
period. JavaScript, GPU SVG replay, and SVG texture reuse were disabled.
The original fixture SHA-256 values were
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51`
and `c4768659c273d4ecaa356425dd16ee6070fd102805a8951d54de60cabfd2572d`
in table order. The 120 callbacks in each trial matched their paired
command counts and scroll offsets. The offsets reached 1248 and 1240 CSS
pixels, respectively. All input hashes stayed fixed. Both browser and
memory guard exits were zero. Guest one-minute load ranged from 0.58 to
1.19 on four vCPUs.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Solid opacity 1 | 31.851 / 7.903 | 39.162, 45.254 / 13.138, 24.421 | 3048 / 3031.5 |
| Solid opacity 2 | 33.281 / 6.080 | 41.250, 53.984 / 10.916, 26.625 | 3057 / 3034.5 |
| Gradient opacity 1 | 30.013 / 15.425 | 37.155, 49.112 / 21.741, 36.473 | 2954 / 2943 |
| Gradient opacity 2 | 28.609 / 15.193 | 35.427, 45.891 / 21.195, 35.318 | 2950 / 2939 |

Median, p95, and maximum replay time fell in all four pairs. These
measurements cover uncached callbacks in unoptimized software-rendered
Linux builds. All 20 Linux browser checks passed. Source checks passed
for macOS and Windows amd64 with D3D11 and OpenGL. Native scrolling and
macOS and Windows runtime timings were outside this comparison.

## Compositing SVG mask strips directly into group alpha

Portable linear SVG masks shade one row or column and apply its samples
directly to the group's alpha. For luminance masks, each premultiplied RGB
sample is converted once. This removes the full-size RGBA mask allocation
and the strip expansion. The macOS native mask surface uses the same
strip shader to populate its full bitmap.

The Linux fixture tests compare strip compositing with the full-size
shader at 0 and 42 CSS pixels of scrolling. They include a translucent
masked path and verify the scroll offset from visible document pixels.
The previous and updated builds also matched for every pixel in the
1024 × 600 document viewport at both offsets. Diagnostics confirmed
vertical alpha and both axes of luminance mask coverage.

| Fixture | Decoded RGBA SHA-256 at 0 px | Decoded RGBA SHA-256 at 42 px |
| --- | --- | --- |
| Vertical alpha | `197de6e1fe4824a937eaed9524e953ad67299af4154ed580343d17d7a993841f` | `6ad53b97a410744ec017651a431a7631166570e057a2686ec10939bbf8541037` |
| Linear luminance | `b7e5995fec1588c8c74fdf0d2dce51feabc2c0510706769818e007c6f862499c` | `a55863e545add569e0fe4eab311309e0cd7b29ad721b7d17b262526697c5b021` |

Fresh Linux aarch64 builds used V `5a39a4d` and matching single-unit
Clang `-O0` flags. Control and candidate executable SHA-256 values were
`a101e54b1eb80744e9b34e4f81a245fba63a586fe3ba76d866f9830bbd82dcf4`
and `e610ef63d5af8a5ee1d12dd815308871a19b955b4d9915463fbd09644a9d9453`.
Replay timings used the original fixture HTML, a fresh profile and
cache, a 1024 × 712 Xvfb window, and a one-second settle period. Mesa
used software rendering. JavaScript, GPU SVG replay, and SVG texture
reuse were disabled. Each trial completed 180 synthetic callbacks
with the same command counts and scroll offsets between 0 and 1240 CSS
pixels in its pair. The fixture SHA-256 values were
`c19ec971f0e234926c0c7aae97081d19c53d249cd2391d18507c0bb2ad4ffeff`
and `263051a227a5964cd27fe855f4e2d00a8e2c6a262958706aaa774b2b4f614f27`
in table order. Input hashes stayed fixed and all browser and guard
exits were zero. Guest one-minute load ranged from 1.00 to 1.54 on four
vCPUs.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Vertical alpha 1 | 3.432 / 2.566 | 7.796, 24.061 / 6.069, 22.258 | 2260 / 1709.5 |
| Vertical alpha 2 | 3.707 / 2.640 | 7.890, 21.418 / 5.014, 24.560 | 2263.5 / 1711 |
| Linear luminance 1 | 6.177 / 2.580 | 8.356, 23.785 / 6.580, 22.810 | 2253.5 / 1716 |
| Linear luminance 2 | 4.680 / 2.597 | 8.623, 22.969 / 5.075, 23.596 | 2258.5 / 1714 |

Median time, p95, and median allocation fell in all four pairs. Maximum
replay time rose in two pairs, and the luminance controls varied in
median time. These measurements cover uncached software-rendered
callbacks. All 20 Linux browser checks passed. The macOS source check and
both Windows amd64 source checks passed. Platform runtime timings and
native scrolling were outside this comparison.

## Storing geometric SVG clip coverage in one byte per pixel

Portable geometric SVG clips composite path components into a packed
alpha plane. The coverage buffer uses one byte per pixel instead of four.
The scan converter and the existing platform-specific rounding at
intersections and antialiased edges are preserved.

The focused macOS `-prod -gc none` checks passed for both Canvas2D rounding
rules, including all 65,536 alpha and coverage pairs, overlapping
fractional paths, an even-odd hole, and invalid bounds. The same tests
passed with ASan and UBSan. The pinned Skia differential suite passed with
the default GC and 20,000 randomized path fills.

Fresh Linux aarch64 builds used V `5a39a4d` and identical single-unit
Clang `-O0` flags. Control and candidate executable SHA-256 values were
`3ee34dbae0d5ca40e14cc687b49c4744890f995b98eb45c886b60875cddaae48`
and `857f82696d62bc7d36adbe0bf517fd1ad4c0189e6bdb9ba69a5d058594cde9f0`.
The `svg-clip-groups.html` capture added a fixed marker to identify the
800 × 600 document area inside the 800 × 712 window. Both builds matched
every document pixel at scroll offsets 0 and 42 CSS pixels. Diagnostics
confirmed that the curved union and fractional clip used the coverage
buffer. The decoded RGBA hashes were
`597ce7150fc24f0fe99910a49967f8556bd5b93b498c17aa9fae214846ac1b8e` and
`4cd18ce24fbe9af912d9c68435a8d253f2161c6311470f3a0e7c55e1ec88b506`.

The replay benchmark used the original fixture with SHA-256
`1d8db436b21f32f96dc5496db99be7867e73508823d056f5dc8939ace2c06a31`.
Each fresh process used a private profile and cache, a 1024 × 712 Xvfb
window, a one-second settle period, and Mesa software rendering.
GPU SVG replay and SVG texture reuse were disabled. Both alternating
pairs processed 180 synthetic callbacks with identical paint command
counts and scroll changes between 0 and 1248 CSS pixels. Hash checks for
the inputs and the browser and memory-guard exits passed. Guest
one-minute load ranged from 1.25 to 1.41 on four vCPUs.

| Pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| 1 | 2.622 / 2.429 | 5.070, 23.477 / 5.180, 22.617 | 1774 / 1653.5 |
| 2 | 2.617 / 2.405 | 5.110, 22.059 / 2.915, 21.923 | 1755.5 / 1650 |

Both trials had lower median replay time and allocation. The first pair
had a slightly higher p95. The timings cover synthetic raster and replay
callbacks. The 20 Linux browser checks and all 17 Linux GG SVG checks
passed. Windows amd64 source checks passed for D3D11 and OpenGL.
Native scrolling and Windows runtime performance remain unmeasured.

## Converting portable SVG rasters in place before upload

CPU SVG fills, strokes, and composited groups now convert their owned
premultiplied RGBA buffer to straight alpha in place. Opaque pixels need
no writes. The conversion uses the existing readback rounding and runs
large buffers through disjoint packed scan ranges. Clip and mask coverage
is applied after conversion. At scroll position zero, the three group
uploads in the fixture previously allocated 94,464 bytes of temporary pixel
storage per uncached replay.

The focused macOS `-prod -gc none` test matched all 65,536 channel and alpha
pairs and compared a 1051 × 533 raster with serial and worker scheduling.
It also checked trailing bytes after an incomplete pixel. The focused
test passed with AddressSanitizer and UndefinedBehaviorSanitizer. The pinned
Skia suite passed, including 76 exhaustive and 20,000 randomized readback
cases. The Linux CPU fallback captures matched pixel for pixel for fill,
stroke, and group fixtures at 0 and 42 CSS pixels. The stroke comparison's
capture fixture puts the stage in document flow so scrolling clips it.
Diagnostics confirmed that the CPU fill, stroke, opacity, clip, and mask
paths drew the samples.

The Linux Clang `-O3` microbenchmark timed conversion and the copy mode's
output allocation. Both modes start with a filled input buffer. Two
alternating pairs used fresh processes with 101 measured calls after 11
warmups. All output hashes matched. Both modes used executable SHA-256
`8fe98421f7799962399128ee4d3700b52d8ce6961f289dab8e73f4031123a76f`.

| Raster | Copy medians, µs | In-place medians, µs |
| --- | ---: | ---: |
| 144 × 72 opaque | 9.750, 12.958 | 3.042, 3.292 |
| 144 × 72 mixed | 25.084, 22.333 | 23.083, 24.667 |
| 144 × 72 translucent | 75.875, 108.167 | 37.833, 40.792 |
| 1051 × 533 opaque | 254.584, 295.876 | 121.542, 126.751 |
| 1051 × 533 mixed | 1612.506, 1836.507 | 1519.839, 1505.547 |
| 1051 × 533 translucent | 1914.215, 1855.966 | 1699.965, 1757.423 |

The browser comparison used matching single-unit Clang `-O0` flags
and V `5a39a4d`. Control and candidate executable SHA-256 values were
`e5002f13a1207bf2bec6ae001d85df9bcfa0672d2e7b9ae22bf53e79ee4c9c62`
and `81786f2b29c23d7e3781b789b73a5e2f749905cae150de7d5c5754122f973bc9`.
Each of two alternating pairs per fixture used the previous
[gradient callback setup](#writing-full-coverage-gradient-source-spans-directly)
with texture reuse disabled and fresh private state. Scroll positions
and paint command counts matched across the 180 callbacks in each trial.
Guest one-minute load ranged from 0.48 to 1.60 on four vCPUs. All measured
processes and guards exited zero.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | --- | ---: |
| Grouped 1 | 3.954 / 4.050 | 4.921, 6.254 / 5.814, 6.398 | 870.5 / 784 |
| Grouped 2 | 4.170 / 3.742 | 4.900, 6.872 / 4.334, 6.175 | 868 / 784 |
| Individual 1 | 9.659 / 8.664 | 10.981, 17.830 / 9.448, 10.867 | 1135 / 858 |
| Individual 2 | 9.271 / 8.712 | 10.153, 11.604 / 9.524, 10.685 | 1133.5 / 856.5 |

Grouped replay timings varied, with the second control running at higher
host load than its candidate. The allocation samples fell in every pair.
The individual fixture also had lower medians and tails in both pairs.
The Linux browser suite, all 17 GG SVG checks, and both Windows amd64
source checks passed. These synthetic software-rendered timings leave
native scrolling, Windows runtime, and hardware GPU performance unverified.

## Writing full-coverage gradient source spans directly

The CPU raster pipeline writes clamped source bytes directly when
a low-precision gradient span has full coverage and uses source replacement.
This includes opaque source-over fills. Linear spans of at least eight
pixels use the existing batched shader. Smaller spans and radial spans
use the scalar shader. Partial coverage, paint alpha, and filters follow
the general pipeline.

Focused `-prod -gc none` span, gradient, and mask tests passed on macOS.
The pinned Skia differential suite passed with the default GC, including
10,000 gradient draws. The Linux group and individual gradient fixtures
matched the control pixel for pixel at 0 and 42 CSS pixels of scrolling.
A separate generated-C probe counted 14,208 linear and 5,184 radial
pixels entering the replacement span at the return to the full group
viewport. The probe binary was excluded from timings.

Matching Linux V `5a39a4d` builds used single-unit Clang `-O0`.
Control and candidate browser executable SHA-256 values were
`51b59b2e77fdf96758ce623fad76a8efcb5a99422835a79b48d4dbe85d6eae4c`
and `ce045250148997ebf2915984dfcd5a6c660b9065d81e0f04dcf3bc1c10edaf95`.
The timings use the [group viewport cohort's](#reusing-svg-group-textures-when-scrolling-back)
synthetic callback scope, local fixtures, four-vCPU guest, private browser
state, one-second settle, and software OpenGL under Xvfb. Both fixtures
used a 642 CSS pixel document with six moves in 180 callbacks. Scroll
positions, paint command counts, binaries, fixtures, and shader inputs
were checked across trials. The emitted C differed in the span routines,
build timestamps, and a generated closure name. One-minute guest load was
0.51–1.38. All timed process and memory guard exits were zero.

| Fixture and pair | First two moving replays before / after, ms | All-callback median before / after, ms | All-callback p95 and maximum before / after, ms |
| --- | --- | ---: | --- |
| Grouped 1 | 7.598, 5.487 / 4.154, 4.405 | 1.107 / 1.110 | 2.956, 7.598 / 2.823, 4.405 |
| Grouped 2 | 4.674, 4.883 / 6.219, 7.879 | 1.090 / 1.087 | 1.530, 4.883 / 3.224, 7.879 |
| Individual, cache off 1 | 9.300, 10.086 / 9.054, 10.302 | 9.506 / 9.424 | 10.500, 11.220 / 10.145, 11.861 |
| Individual, cache off 2 | 8.956, 9.921 / 8.861, 10.322 | 9.249 / 9.261 | 10.640, 11.921 / 10.402, 11.430 |

Cold browser results varied between pairs. The cohort leaves the
first-visit browser speedup unresolved.

Two further alternating pairs disabled group texture reuse for every
callback, so all 180 callbacks rasterized the grouped fixture. The same
builds, viewport and input schedule ran at one-minute load 1.07–1.20.

| Pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms |
| --- | ---: | --- |
| 1 | 4.633 / 3.860 | 5.268, 6.938 / 4.976, 6.095 |
| 2 | 4.151 / 3.831 | 4.482, 6.226 / 5.410, 8.540 |

The optimized Clang `-O3` microbenchmark timed the path fill into a
preallocated RGBA buffer cleared before each call. Its control sends
source replacement through the generic pixel loop by changing the
dispatch condition in generated C. Both binaries share the rest of the
compiled implementation. SHA-256 values were
`12e79f5f5a7c6cde50476cc7c8f31de8a2b23cc57cc500bc456ea6abf0c80213`
and `5b05186f00ab9d9385eb3b7f847cd6f0dd3adead02d31f207da0b1377948fb1f`.
Each row shows both 121-call medians from fresh processes, in pair order.
The outputs matched for all four inputs and the guard and processes exited zero.

| Gradient and dimensions | Control medians, µs | Candidate medians, µs |
| --- | ---: | ---: |
| Opaque linear 144 × 72 | 99.667, 97.416 | 54.583, 55.791 |
| Opaque radial 144 × 72 | 111.667, 104.625 | 84.625, 90.334 |
| Opaque linear 6 × 100 | 7.708, 7.167 | 6.541, 6.875 |
| Translucent linear 144 × 72 | 81.375, 76.917 | 76.125, 79.375 |

The Linux browser suite, all 17 GG SVG checks, and both Windows amd64
source checks passed. These synthetic and raster-only timings leave
native scrolling, Windows execution, and hardware GPU performance unverified.

## Reusing SVG group textures when scrolling back

`VOX_GG_SVG_VIEWPORT_REUSE=1` lets each of the 16 portable SVG group slots
keep one alternate texture of up to 65,536 pixels. The cached placement
includes the document's paint revision, the recorded viewport, the replay
viewport, origin, and scale. Root scrolling can rebuild the lowered commands
while keeping the paint revision. Returning to a recorded placement selects
its exact texture, including for clipped gradients whose pixels depend on
the raster origin. Paint changes, unrelated uploads, and retired slots
discard their old textures.

The window fixture alternated between 0 and 42 CSS pixels and edited a
gradient stop after both placements were cached. The edited group rasterized
at the next placement, then reused the updated texture on a later visit.
Diagnostics counted 15 alternate hits across opacity, clip, and mask scopes.
The clipped document pixels matched with viewport reuse on and off. Their
decoded SHA-256 was
`b486409d21779baf4ddfb12a35db4752216c5278a3c7dd355c1c9b2edeae64d8`.

The performance cohort used the same fixtures and software OpenGL callback
scope as the [gradient group comparison](#preserving-gradients-in-portable-svg-groups).
The two builds used V `5a39a4d` and identical single-unit Clang `-O0` flags.
Control and candidate executable SHA-256 values were
`4dbcf8d6bf8c1c7b9d2622f6ee2c7371fd334271e93a2f01f7fdf6a9f71483e1`
and `26c26ac008c3cfcaed30219a1c15db565af7e516116d80a3772982c01724a05f`.
The gradient timing copy retained SHA-256
`34329b0b5ba8e8419b7974ed15e60fb50094f8650d4c98b18888d59b454214f5`.
Two alternating pairs per fixture matched scroll positions and paint-command
counts. Guest one-minute load ranged from 0.99 to 1.13 on four virtual CPUs.
All timed browser processes and the memory guard exited zero.

| Fixture and pair | Replay median before / after, ms | Replay p95 and max before / after, ms |
| --- | ---: | --- |
| Solid, all 1 | 5.906 / 6.135 | 7.471 and 27.430 / 7.540 and 25.734 |
| Solid, all 2 | 5.832 / 5.848 | 7.450 and 25.870 / 6.345 and 27.616 |
| Gradient, all 1 | 1.073 / 1.084 | 2.961 and 4.967 / 2.701 and 4.812 |
| Gradient, all 2 | 1.116 / 1.133 | 2.829 and 4.944 / 1.400 and 4.926 |
| Gradient, moving 1 | 4.575 / 1.140 | 4.967 and 4.967 / 4.812 and 4.812 |
| Gradient, moving 2 | 4.595 / 1.151 | 4.944 and 4.944 / 4.926 and 4.926 |

The first two moving callbacks cost 4.537 and 4.812 ms in the first
candidate trial and 4.620 and 4.926 ms in the second. The remaining four
moving callbacks had medians of 1.089 and 1.053 ms, down from 4.442 and
4.616 ms. The separate diagnostic replay confirmed raster misses on the
first two moves and three alternate hits on each subsequent move.
The solid fixture matched the control pixel for pixel. These timings
cover synthetic software-rendered callbacks. The Linux browser suite, all
17 GG SVG checks, and both Windows amd64 source checks passed. Windows
runtime and hardware GPU timing remain unverified.

## Preserving gradients in portable SVG groups

The shared portable renderer composites supported linear and radial fills
with the other paths in an SVG opacity, clip, or mask scope. It restores
leaf fill alpha before blending the group and applies the group opacity
or coverage once. The existing path count, area limits, and fallback for
unsupported paints still apply.

Top-level groups reuse their GG texture when the recorded paint generation,
scope position, viewport, origin, and scale match. The streaming slot
invalidates the group on upload or retirement. The fixture verifies the
same pixels with the GG Canvas setting enabled, disabled, and with texture
reuse disabled. It changes a gradient stop during animation and checks the
updated masked pixels. The overlap changed from RGB `(127, 63, 191)` to
`(127, 127, 255)`. The gradient previously painted outside the curved
clip and alpha mask.

Linux used V `5a39a4d` and matching single-unit Clang `-O0` flags. The
control, grouped raster without reuse, and final executable SHA-256 values
were `25322d3dfaa9abd7e499582a78716f9c7797ae18e9941f4fdc90819dd9daabf6`,
`62dba1b39a28803be1f06b19d679a3a0fd772b02ccf1af2946e2650c10cd0546`,
and `98eac3719d2cf94c7a6a07bc3016a277855868f7e4de606e665bb63bb4254e92`.
The animation test starts with `svg-gradient-groups.html`, SHA-256
`0d186c3a4faa88d19d00a1018df54d81005438de0f9a4f264861b6750f09d110`.

Two alternating pairs per fixture used private browser state, a 1024 × 712
window, software OpenGL with `LP_NUM_THREADS=1` under Xvfb, and a one-second
settle. The synthetic driver sent 180 callbacks and reversed direction
every 30. The gradient timing copy set a 642 CSS pixel minimum body height,
giving six moving callbacks. Scroll offsets and paint-command counts matched.
Guest one-minute load was 0.71–0.94 on four vCPUs in the final cohort.
Process and guard exits were zero.

| Fixture and pair | Replay median before / final, ms | Replay p95 before / final, ms | Replay maximum before / final, ms |
| --- | ---: | ---: | ---: |
| Solid, all 1 | 5.456 / 5.536 | 7.079 / 6.327 | 7.854 / 24.798 |
| Solid, all 2 | 5.703 / 5.494 | 8.077 / 7.279 | 11.014 / 24.679 |
| Gradient, all 1 | 1.017 / 1.092 | 2.271 / 2.893 | 3.120 / 4.780 |
| Gradient, all 2 | 1.002 / 1.039 | 2.528 / 2.924 | 3.245 / 4.858 |
| Gradient, moving 1 | 2.035 / 4.628 | 2.271 / 4.780 | 2.271 / 4.780 |
| Gradient, moving 2 | 2.040 / 4.339 | 2.528 / 4.858 | 2.528 / 4.858 |

The intermediate build rebuilt the gradient groups and spent 4.244–4.483 ms
at the all-callback median. The final build reused unchanged viewport
textures. The solid fixture matched the control pixel for pixel, with
higher maximum replay times in the final cohort. Moving the gradients still
rebuilds a correct group at the new viewport. These are software renderer
callback timings. The full Linux browser smoke suite, all 16 Linux GG SVG
window checks, and Windows amd64 D3D11 and OpenGL source checks passed.
Windows execution and hardware GPU timing remain unverified.

## Sharing the portable SVG fallback with Windows

The standard Windows D3D11 window now uses the same CPU raster and GG texture
cache as Linux for supported SVG path fills and strokes. The OpenGL variant
tries GG Canvas first when enabled and uses the same CPU fallback on a
decline. Non-scaling strokes get the same viewport culling allowance on both
platforms.

The Windows browser smoke driver samples the presented pixels of an SVG
gradient with an even-odd hole and a dashed, non-scaling stroke. Its fixture
also ran through an aarch64 Linux build with `vox_gg_svg` omitted. All six
SVG pixel assertions matched, and diagnostics showed a raster miss followed
by texture hits for both paint operations. The V `5a39a4d` single-unit
Clang `-O0` executable SHA-256 was
`74c8ee0b9fa0fe90a97663d8b91c05d49498db6f77c17851f61dca2a01d86902`.
The full Linux browser smoke suite passed on its second run. The first
run passed the rendering checks and exited 139 during keyboard navigation.
A separate lifecycle retry also passed with the same binary.

The guarded Windows amd64 D3D11 cross-build produced a PE32+ executable
with SHA-256
`21f77d647e14e0d051f45d7458c6d4a5850c8369ec139297a83a4d7759e08725`.
The PE calls the shared fill and raster stroke routines. The smoke driver
cross-compiled with warnings treated as errors, and the Windows OpenGL
source check passed. The Windows VM's disk reserve
requires 5 GiB of free host storage. The host had about 1.6 GiB free, so
Windows pixel and timing checks remain pending.

## Sharing CSS gradient text masks with Windows

Windows D3D11 and OpenGL now replay `background-clip: text` through the
same FreeType glyph mask and GG texture upload as Linux. The FreeType
adapter streams font files through wide Windows paths, including CSS
fonts downloaded into a Unicode profile path.

The Linux browser smoke test passed on retry. The initial run passed
the rendering checks and timed out during keyboard navigation. An
isolated lifecycle retry passed before the complete rerun. The
gradient ramp and full-raster modes produced identical document rows.
On the Windows driver's `0.5` fixture under Linux Xvfb, the pixel check
accepted the clipped glyphs and rejected the full gradient rectangle.
The V `5a39a4d` single-unit Clang `-O0` executable SHA-256 was
`2fc5115814fe7360e76b964401f9da3a000a83adef0aab26dd4297e215174a54`.
The focused FreeType pixel and outline tests also passed on Linux.

The macOS and both Windows source checks passed. The Windows smoke
driver and Unicode-path glyph test cross-linked with MinGW GCC 16.2.0.
The first D3D11 production build ran out of space staging generated C.
A diagnostic build and a production retry linked to `d3d11.dll` and
`libfreetype-6.dll`. The V `178232d` single-unit
`-prod -no-prod-options` executable SHA-256 was
`67b9c9edf7fac983e83cb4c14348751acf24b35207434239910b7fbe077cf0a2`.
The retry and its 12 GiB guard exited zero at a sampled peak
RSS of 8,536,981,504 bytes.
The Windows VM could not meet its 5 GiB host disk reserve. Windows
runtime pixels and timings remain unverified.

## Shared replay for retained web-font text

Linux now clips horizontal `@font-face` glyph runs to the viewport
before allocating the raster, using the document's retained glyph IDs
and positions. Windows can use the same FreeType and GG texture path
with `VOX_PORTABLE_WEB_FONTS=1`, pending native testing of the
`-gc none` working set.
The layout regression compared every pixel with the corresponding
crop of the full bitmap at device scales 1 and 2. The browser fixture
checked the author's glyph stems and gaps in a fully visible run and
one clipped at the left edge. The decoded document pixels matched the
control exactly.

Two alternating synthetic replay pairs for each fixture used V
`5a39a4d` and single-unit Clang `-O0` on the four-vCPU AArch64 Linux
guest. Each trial used Mesa software rendering, a fresh process and
private profile and cache, a 1024 × 712 window, a one-second settle, and
48 synthetic scrolling callbacks. JavaScript was disabled and OS caches
remained available. All trials had matching command counts, scroll
offsets, and final document pixels, with stable input hashes and
zero browser and guard exits. One-minute guest load ranged from 0.48
to 1.34. The replay times cover draw callbacks.

| Workload and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| System font 1 | 32.943 / 39.687 | 40.331, 41.022 / 44.622, 50.920 | 3450 / 3448.5 |
| System font 2 | 39.232 / 38.859 | 41.276, 41.652 / 41.510, 41.985 | 3447 / 3448 |
| Web font 1 | 61.542 / 59.847 | 62.848, 66.066 / 61.769, 62.913 | 5493 / 5285 |
| Web font 2 | 67.200 / 62.196 | 73.841, 76.770 / 67.109, 69.448 | 5492 / 5287 |
| Long clipped web font 1 | 451.907 / 100.673 | 480.093, 498.030 / 107.877, 113.180 | 43009.5 / 8766.5 |
| Long clipped web font 2 | 357.769 / 93.186 | 366.851, 382.198 / 96.910, 107.932 | 43008 / 8767 |

The Linux control and measured candidate executable SHA-256 values were
`4f6317cec4b8bfe4b14b73414b4308a0beeb6a6cc1e2e38c0dfaab244113da63`
and `9261af318a04509b77dcd906a4aeeff1bb618b33d10abaf220abea7173ab0df4`.
The long fixture placed 300 glyphs per line 1500 pixels left of the
viewport. The system-font results were mixed.

The final Linux build
`4dc94f461906804b82e0eec4b35d1401b6980f80ee1101da6ed06b2ae6586748`
passed the browser smoke suite and matched the measured candidate's
fixture pixels. The macOS and Windows
OpenGL source checks passed. The D3D11 diagnostic cross-build linked
to `d3d11.dll` and `libfreetype-6.dll`. Its SHA-256 was
`1e0306aba08371663600d61bd965589230d2c275eaaa26fb86ee7419200435aa`.
The Windows VM requires 5 GiB of free host storage. Windows native
pixels, memory, timings, and precise scrolling remain unverified.

## Reusing retained web-font textures

The portable web-font painter reuses a texture when the adopted root
paint command, recording generation, viewport, and backing scale match.
The cache uses the first 16 existing GG streaming slots. A replacement
upload or slot removal clears the corresponding entry. The live-edit
regression observed hits before and after changing the glyph sequence
and color. The edited capture matched the uncached document exactly.

Two alternating pairs per workload used the same Linux AArch64
single-unit Clang `-O0` executable with V `5a39a4d` and SHA-256
`cd08b8eb79ba82c6a95fb87e02a5e587aeeae2eb7c6fc6808be7a555065dee1d`.
The fixture contains 31 lines of 36 author-font glyphs at 32 px.
Its SHA-256 was `f8080532a860d12b4cae56e9e5e2ff3f6711a143f7e0e2df101135cefd34569e`.
The font SHA-256 was `9438128eaeb21796c5adc70376734aaa1c47d3b955009985ab6b8c448a8afa63`.
Each trial used 48 synthetic draw callbacks, a fresh process and
private profile and cache, a 1024 × 712 Xvfb window, Mesa software
OpenGL, and one second of settling. JavaScript was disabled and OS
caches stayed available. Command counts, scroll offsets, and final
document pixels matched within each workload. All input hashes stayed
fixed and the browsers and memory guard exited zero. One-minute guest
load ranged from 1.19 to 1.84 on four vCPUs in the timed runs.

| Workload and pair | Replay median uncached / cached, ms | Replay p95 and maximum uncached / cached, ms | Median allocated KiB uncached / cached |
| --- | ---: | ---: | ---: |
| Stationary 1 | 64.609 / 0.702 | 88.652, 99.372 / 0.920, 2.628 | 5058 / 114 |
| Stationary 2 | 64.739 / 0.721 | 66.872, 67.946 / 1.890, 2.379 | 5059 / 113 |
| Scrolling 1 | 65.211 / 65.083 | 69.299, 70.526 / 69.685, 74.257 | 5241.5 / 5237 |
| Scrolling 2 | 63.626 / 64.077 | 67.002, 69.953 / 69.896, 73.557 | 5246 / 5237 |

Separate diagnostic runs counted 658 hits and zero misses during
stationary callbacks 1–47, and 108 hits and 560 misses during the
same interval with synthetic scrolling. The scrolling replay medians
were within 1%, and both cached scrolling trials had higher p95 and
maximum times. These are draw-callback measurements. The Linux browser
smoke suite and the macOS, Windows D3D11, and Windows OpenGL source checks
passed. Windows native memory and timing checks still await a VM with
enough host storage.

## Reusing web-font textures across scroll recordings

`VOX_WEB_FONT_SCROLL_REUSE=1` allows a fully visible horizontal web-font
run to reuse a texture after viewport scrolling records a new paint
list. The renderer compares the document content revision, font path
and face, exact glyph IDs and positions, color, opacity, backing scale,
and raster-local transform and dimensions. Whole-pixel translation can
therefore reuse pixels. A clipped run, a non-translation transform, or
a changed subpixel phase takes the existing raster path. The lookup can
move a matching texture from a later unused web-font slot within the
same 16-slot budget. Each entry stores at most 128 glyphs and 512
font-path bytes. The tab releases the metadata when it closes.

The first diagnostic rejected the scroll translation and recorded no
hits. The raster-local comparison then recorded 265 cross-recording
hits and 294 raster misses during synthetic callbacks 1–47. The window
regression checked exact pixels across scrolling, a live color edit,
clipped and fractional text, and an SVG sharing the streaming slots.

Two alternating pairs compared the flag off and on with the existing
stationary cache enabled in both. The Linux AArch64 executable used
V `5a39a4d` and single-unit Clang `-O0`. Its SHA-256 was
`fb31f3f8d3ba9101614150ab324220d2cca91f81895aee423ddd104b7d2965a1`.
The fixture used 31 alternating-color lines of 36 author-font glyphs
at 32 px and had SHA-256
`1bdc2d1ef877068d0b788a9ef431f6eaab8bbf1d5c0d541176bd559557df550c`.
The trials used fresh processes with private profiles and caches,
Mesa software OpenGL in a 1024 × 712 Xvfb window, one second of settling,
and 48 synthetic scrolling callbacks with JavaScript disabled. OS caches
stayed available. One-minute load ranged from 1.13 to 1.44 on four
guest vCPUs. Input hashes, scroll offsets, command counts, and final
document pixels matched. Browser and guard exits were zero.

| Pair | Replay median off / on, ms | Replay p95 and maximum off / on, ms | Median allocated KiB off / on |
| --- | ---: | ---: | ---: |
| 1 | 58.504 / 6.313 | 61.632, 64.134 / 59.651, 60.818 | 5220.5 / 799 |
| 2 | 57.827 / 7.783 | 59.622, 59.823 / 59.216, 59.765 | 5217 / 805.5 |

The final document pixel SHA-256 was
`9aadcb12b8d0ddc547c8c7509fbcc9f70feb793acf5f1e7f4ae11911f9d68622`.
The results measure synthetic draw callbacks. The Linux browser smoke
suite passed. The cleanup build
`01c30c5fd3c7ec15ac4994313f8b635df694e9ccb2c34921ee2899b4ce52fefa`
passed the focused pixel checks and exited cleanly when its X11 window
closed with a populated cache. A separate X11 wheel probe re-recorded
the document and timed out waiting for a cross-recording hit. macOS,
Windows D3D11, and Windows OpenGL source checks passed. Native scrolling
performance and Windows memory and timing remain unverified.

## Preserving web-font textures on upward scroll

With `VOX_WEB_FONT_SCROLL_REUSE=1`, an entering top row can move a
displaced texture to an unused trailing slot before uploading its
own pixels. The following rows can look up the displaced texture
within the same 16-slot limit. Frame retirement releases unused
slots. The focused regression requires hits on the first upward
frame. The control reported zero hits on that frame.

A separate X11 diagnostic explained the earlier single-wheel miss.
At window width 800, the first 42-pixel tick advanced the paint
content revision from 183 to 184, and the next downward tick reused
10 textures. At width 1024 the same diagnostic kept revision 183
and reused 10 on both downward ticks. In both widths the first
upward tick missed every texture even with a stable revision.

The pixel comparison used Xvfb, Mesa software OpenGL, fresh profiles,
and one `xdotool` wheel event per step in a 1024 × 712 window. A
document marker confirmed the offsets. The captures matched exactly
between the two executables at each step. Both browsers closed with
exit zero.

| X11 scroll offset before → after | Textures reused before / after |
| --- | ---: |
| 0 → 42 | 0 / 0 |
| 42 → 84 | 12 / 12 |
| 84 → 42 | 0 / 12 |
| 42 → 0 | 12 / 12 |

Two alternating synthetic replay pairs used AArch64 Linux, V
`5a39a4d`, and identical single-unit Clang `-O0` flags. The control
and candidate executable SHA-256 values were
`2ef8bf880b4cbd50e1405cef40489f943c59aa272581aafc183f05463874fa1b`
and `53bd06a9a6db07fe61e45b99ea2933ffd5ceebbc4ba5305203bd0ae6fa5f3312`.
The input fixture SHA-256 was
`5efa7465a7fb43d67ab24c5bb3428beb3b2b8aa05296b1f87e25b898969a7f59`.
Trials used the same window dimensions and software backend as the
wheel check, fresh processes and private profiles and caches, one
second of settling, and JavaScript disabled. OS caches were retained.
Each trial recorded 48 callbacks, with 21 moving down and 18 moving
up. All command counts, offsets, and final document pixels matched.
One-minute guest load ranged from 1.32 to 1.69 on four vCPUs. Browser
and guard exits were zero.

| Callbacks and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Up 1 | 62.014 / 5.932 | 64.837, 64.837 / 13.291, 13.291 | 5336.5 / 707 |
| Up 2 | 62.637 / 5.526 | 64.904, 64.904 / 11.507, 11.507 | 5339 / 708 |
| Down 1 | 6.381 / 6.656 | 8.847, 14.470 / 11.657, 14.048 | 688 / 703 |
| Down 2 | 6.642 / 4.633 | 11.202, 13.211 / 8.421, 16.829 | 704 / 688 |
| All 1 | 6.647 / 5.879 | 64.354, 64.837 / 11.659, 14.048 | 794 / 679 |
| All 2 | 7.815 / 5.007 | 64.541, 64.904 / 8.421, 16.829 | 785 / 678.5 |

The final synthetic document pixel SHA-256 was
`a2fc0d02980fb56aa1f04a1d831dec058a2c8c73a988c007ca4c1f19a90f7064`.
Downward timings were mixed. The X11 wheel check establishes pixel
and cache behavior. Native frame timing and Windows runtime remain
unverified. The Linux browser smoke suite and macOS, Windows D3D11,
and Windows OpenGL source checks passed.

## Reusing horizontally clipped web-font textures

With `VOX_WEB_FONT_SCROLL_REUSE=1`, `24e450729` lets a vertically
scrolling line reuse its texture when the horizontal viewport crop
produces the same raster dimensions and origin-relative transform. Rows
cut by the top or bottom edge use the existing raster path. An initial
version cached those rows and recorded zero hits on the ordinary
fixture's first upward frame.

The revised build reproduced all document pixels with the cache enabled
and disabled, including after a live color edit. On the wide-line fixture
the previous build logged 3 cross-recording hits, including 1 on the first
upward frame. The revised build logged 222 hits, including 11 on that
frame. The ordinary fixture also logged 222 and 11 hits.

Two alternating pairs per fixture used AArch64 Linux, V `5a39a4d`, and
matching single-unit Clang `-O0` flags. The control and revised executable
SHA-256 values were
`ce33fc3fbf0140fbc8e49f7c8bc48226aedbd5689a1e91c18d81a338c6499c24`
and `f47551b9a0284675b2fabdd767bba2a142a976bb2c3f774cdd0dba1a6d46749e`.
The ordinary and wide fixture SHA-256 values were
`668b4e3f6a02611e4ee864d2834ab7e64bccfa855cf759a1f7e9a8421ce3c08b`
and `041eee702ad8788936a4ed6d014064c989ed04c1112463f1d0439850edfff641`.
Executable, linked library, font, and input hashes stayed fixed. Trials
used fresh processes and private profiles and caches, a 1024 × 712 Xvfb
window with Mesa software OpenGL, a one-second settle period, and JavaScript
disabled. OS filesystem caches were retained. Each trial recorded 48
synthetic callbacks including 21 downward and 18 upward movements.
Offsets, paint command counts, and final 1024 × 628 document pixels matched.
Guest one-minute load ranged from 0.96 to 1.31 on four vCPUs. Browser and
guard exits were zero.

| Fixture and pair | Replay median before / after, ms | Replay p95 and maximum before / after, ms | Median allocated KiB before / after |
| --- | ---: | ---: | ---: |
| Ordinary 1 | 5.838 / 6.287 | 11.601, 13.738 / 11.652, 12.248 | 677.5 / 682.5 |
| Ordinary 2 | 6.042 / 6.459 | 12.644, 14.450 / 13.159, 14.187 | 672.5 / 674.5 |
| Wide 1 | 87.966 / 9.162 | 93.298, 94.520 / 16.127, 18.017 | 8106 / 941.5 |
| Wide 2 | 91.118 / 8.805 | 98.408, 100.573 / 16.565, 21.946 | 8094.5 / 940 |

The ordinary and wide document pixel SHA-256 values were
`9aadcb12b8d0ddc547c8c7509fbcc9f70feb793acf5f1e7f4ae11911f9d68622`
and `35d2f8f5f8a1e5fec7d37b964ad7cce39d943caacbe24b8594eb40cef79079bb`.
Separate diagnostics logged 481 hits in both ordinary builds and 0 versus
481 for the wide fixture. Ordinary medians rose by 0.42–0.45 ms while
wide replay allocated about 88% less per callback. Reuse remains opt-in.

A live X11 check used four `xdotool` wheel events on the wide fixture
with a scroll position marker. The marker confirmed offsets of 0, 42,
84, 42, and 0 CSS pixels. At each offset the document pixels matched
outside the rightmost eight columns occupied by the fading scrollbar.
The revised build reused 12 textures on each event and the control
reused zero. Both browser processes and the memory guard exited zero.
The marked fixture SHA-256 was
`e745172fc5a79858ae9cb78b84a321648bdbdc6aaa0ab97d500d98af86a2016b`.

The timing measurements cover synthetic replay. Native GPU timing and
Windows runtime remain unverified. All 25 Linux browser checks passed.
The stationary-cache test now allows the capture-ready attribute to
re-record unchanged pixels and still requires two generations with both
an upload and a hit. macOS, Windows D3D11, and Windows OpenGL source
checks passed.

## Converting CPU SVG upload pixels faster

The shared CPU raster readback copies opaque RGB bytes directly and writes zero
RGB for transparent pixels. It converts partial alpha with the original f32
operations and rounds the saturated byte to nearest even. The scan uses the
source and destination bounds checked by `read_pixels` before it starts,
including for overlapping views.

The focused readback test passed on macOS and Linux, covering every channel
and alpha byte pair, padded rows, and overlapping views. The pinned Skia
oracle matched 76 exhaustive and 20,000 randomized readback cases on macOS,
including in the `-prod -gc none` run that reached the 12 GiB guard in
subsequent raster tests. The full pinned suite completed with the default GC.
All 16 Linux GG SVG window checks and the Windows amd64 OpenGL source check
passed.

A Linux Clang `-O3` readback-only benchmark measured the 200 × 112 tile with
warm, preallocated buffers. Median times for opaque, mixed, and translucent
tiles went from 0.322 / 0.338 / 0.337 ms to 0.020 / 0.056 / 0.119 ms. At
1051 × 533, where the row workers participate, medians went from
2.166 / 2.301 / 2.332 ms to 0.251 / 1.611 / 1.616 ms. Each value is the
median of four 61-call medians from two runs per build. Output hashes matched
for each input, both executable hashes held, and the benchmark and guard
exited zero.

The Linux browser cohort used V `5a39a4d`, single-unit Clang `-O0`, and
software OpenGL with `LP_NUM_THREADS=1` under Xvfb. The control and candidate
executable SHA-256 values were
`a8a5c6bb84d78a7993f8a4dfcc99656474652fa7b4b10452a45b46ac3921ec58`
and `ec8ccd43ce7e5d2127c027b861fb58f452859382c62947b85f08cb4567b749ae`.
The generated C differed in the readback functions, build timestamps, and
a compiler-generated closure name. Both builds used identical C flags.
Each trial ran a fresh process with private browser state and an 800 × 712
window. The fixture and wheel schedule were the same as the
[gradient clip reuse cohort](#retaining-exact-cpu-svg-gradient-clips).
Viewport reuse was enabled on both builds. The scroll fixture SHA-256 was
`4642727427b15f988ef7108628726a153dad2abaa0d6e1a9acaa4929fa0ac3d0`.
Guest one-minute load ranged from 1.52 to 2.00 across the eight timed trials
on four vCPUs.

| Renderer and pair | First moving callback, control / candidate, ms | Revisit median, control / candidate, ms |
| --- | ---: | ---: |
| CPU fallback 1 | 13.975 / 10.067 | 1.075 / 1.227 |
| CPU fallback 2 | 16.601 / 10.744 | 1.254 / 1.216 |
| GG 1 | 8.159 / 7.844 | 2.883 / 1.143 |
| GG 2 | 7.641 / 7.021 | 1.229 / 1.131 |

Both CPU builds rasterized the first clipped extent and reused the
alternate texture on 15 later fills. Full and clipped document captures
were pixel-exact between builds on each renderer. All measured browser
processes and the runtime guard exited zero. The first CPU clip callback
took 28% and 35% less time in the two pairs. Revisit medians moved in both
directions. These synthetic callback timings leave native scroll
publication, hardware GPU performance, and Windows runtime unverified.

## Retaining exact CPU SVG gradient clips

`VOX_GG_SVG_VIEWPORT_REUSE=1` can retain the previous CPU gradient fill
texture when the same path and paint need a differently sized viewport
clip. Reuse requires an exact match for the path, fill rule, resolved
gradient, local raster transform, and image dimensions. Each streaming
slot can hold one alternate of up to 65,536 pixels, for at most one
megatexel of additional retained texture area. A paint change, unrelated
upload, or retired streaming slot discards the alternate. First visits
still rasterize at the requested extent, preserving its sampling origin.

The viewport fixture visited full and clipped linear and radial fills,
returned to both extents, and changed a gradient stop before returning
to a previously cached clip. The edited fill rasterized again. Output
matched pixel for pixel with viewport reuse disabled on each renderer.
All 16 Linux GG SVG window checks passed, as did the Windows amd64
OpenGL source check with `-gc none`.

For timings, `Tests/Browser/Native/svg-gg-gradient-viewport.html` used a
642-pixel minimum body height. This left 42 pixels of overflow in the
600-pixel document viewport with the bookmark bar visible. V `5a39a4d`
and single-unit Clang `-O0` used identical flags for the control and
candidate from the shared checkout with other work in progress. The
executable SHA-256 values were
`696fe12821023008f539dae5ea4507201411c08ce5c57ce9f38343f1d875168e`
and `80a33098539e12aff4d47f259253ca49a96b80197b2b18de867e573cad59c8e9`.
The page and shader directory SHA-256 values were
`4642727427b15f988ef7108628726a153dad2abaa0d6e1a9acaa4929fa0ac3d0`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb with `LP_NUM_THREADS=1`,
a fresh process and private browser state, an 800 × 712 window, and a
one-second settle. The synthetic driver sent 180 self-paced wheel
events and reversed every 30 callbacks. Six steps moved the document
between 0 and 42 CSS pixels. The first was a new clip, and the other
five revisited a previously painted extent. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 0.71
to 1.46 on four virtual CPUs. The timing driver and memory guard
exited zero. Each renderer's clipped captures matched exactly between
builds and with viewport reuse disabled.

| Renderer and pair | Revisit median control / candidate, ms | All moving median, ms | All moving p95 and maximum, ms |
| --- | ---: | ---: | ---: |
| CPU fallback 1 | 14.436 / 1.175 | 14.283 / 1.1905 | 15.989 / 16.242 |
| CPU fallback 2 | 13.971 / 1.135 | 13.958 / 1.1445 | 14.816 / 13.084 |
| GG 1 | 1.071 / 1.017 | 3.431 / 3.2515 | 7.849 / 6.185 |
| GG 2 | 1.104 / 1.113 | 3.368 / 3.393 | 6.337 / 6.184 |

Diagnostics counted 15 exact alternate hits in the candidate CPU run
after the first moving callback. The control rasterized those 15 draws.
Each GG run hit all 537 subsequent gradient draws. The two CPU revisit
medians fell by about 92%. The candidate's first visit still spent
13.084 and 16.242 ms. These timings cover synthetic replay on software
OpenGL. Native GPU performance and Windows runtime remain unverified.

## Cropping cached CPU SVG fills at viewport edges

`VOX_GG_SVG_VIEWPORT_REUSE=1` also enables crops of cached CPU solid
fills made of closed, pixel-aligned rectangles, including even-odd
holes. The cached and visible rectangles must share the same linear
transform and differ by a whole-texel offset, with all visible texels
present in the cached texture. Replay samples that subrectangle with
nearest filtering. The original texture remains available when its
larger extent comes back into view. Fills with curved edges, gradients,
fractional coverage, or newly exposed pixels use the raster path for a
changed clip.

The Linux window fixture exercised top and left clipping, an even-odd
hole, a quarter-pixel transform, a growing visible rectangle, and a
translucent rotated path. The CPU reused the aligned crops and
rasterized the fractional, growing, and curved cases. Each renderer's
cropped and rerasterized document captures matched exactly. All 16
Linux GG SVG window checks passed, as did the Windows amd64 OpenGL
source check with `-gc none`.

The timing page had three 560-pixel-high solid fills, two with
rectangular holes and one with partial opacity. The scroll tests used
the same V `5a39a4d` and single-unit Clang `-O0` flags for both Linux
builds from the shared checkout with other work in progress. The control
and candidate executable SHA-256 values were
`11f3796f2c951c090fef51c15410378ad806192057c0ebd82d81c0822f3fbfa8`
and `b18e1b19afe875f10e19994d9b90af11e154b608f0942aa3a901afa9c542b83a`.
The page and shader directory SHA-256 values were
`56423df16f9085ff7546277dc85b15c78f2137cea0d95ec889d081bfffd9affd`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb with `LP_NUM_THREADS=1`,
a fresh process and private browser state, an 800 × 628 document
viewport, a one-second settle, and 32 self-paced 42-pixel scroll steps.
The clipped subset contains 13 steps, ending at 546 CSS pixels. Scroll
positions and paint-command counts matched. One-minute guest load
ranged from 1.05 to 1.31 on four virtual CPUs. The timing driver and
memory guard exited zero. Captures at 168 CSS pixels matched exactly
for each renderer between builds and with viewport reuse disabled.

| Renderer and pair | Clipped median control / candidate, ms | Full median, ms | Full p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: | ---: |
| CPU fallback 1 | 16.356 / 1.021 | 1.1985 / 1.010 | 27.881 / 2.481 | 30.192 / 2.514 |
| CPU fallback 2 | 15.965 / 1.002 | 1.135 / 1.009 | 27.623 / 1.284 | 28.957 / 2.573 |
| GG 1 | 0.994 / 1.048 | 0.9945 / 1.020 | 1.171 / 1.366 | 2.728 / 2.855 |
| GG 2 | 1.027 / 1.023 | 1.0025 / 0.9985 | 2.522 / 2.547 | 2.557 / 2.579 |

After the first measured callback, the diagnostic counted 36 crops in
the candidate CPU run and 36 rasterizations in the control CPU run.
Both GG runs recorded 36 crops. The clipped CPU median fell by about
94%. Whole-run GG medians were within 2.6%, with higher p95 in both
pairs. These timings cover synthetic callbacks on software OpenGL.
Native GPU performance and Windows runtime remain unverified.

## Retaining CPU SVG fill textures

Portable SVG fills use the same streaming texture cache as strokes.
The fill rule is part of the key alongside path bytes, transform,
clipped dimensions, and resolved solid or gradient paint. A matching
texture can be drawn at a new integer position without decoding the
path, rasterizing it, or uploading its pixels. The cache keeps its
16-slot bound, and every pixel upload invalidates the old entry for
that streaming slot.

The Linux window checks changed a solid fill from the nonzero rule to
even-odd, replaced a stroke's slot with a same-sized fill, and checked
live edits to gradient stops, local transform, opacity, and focal radius.
Cached, forced-uncached, and OpenGL 4.2 fallback captures matched exactly
after the edits and the clipped scroll. All 16 Linux GG SVG window checks
and the Windows amd64 OpenGL source check with `-gc none` passed.

The timing fixture was `Tests/Browser/Native/svg-gg-gradient-fill.html`.
Both Linux builds used V `5a39a4d`, one Clang translation unit, and identical
`-O0` flags from the shared checkout with other work in progress. V C
generation and Clang linking ran separately after the guest exhausted
memory in the first combined control build. The control and candidate
executable SHA-256 values were
`cc929b35e08a08021b95285603ddbe688a4ce4988721f7d709f476fbae3fbf15`
and `79382eb0cc425c45580d4ffcfa5fb7178c26566b7021e626f6f3d20ba9cfcd34`.
The fixture and shader directory SHA-256 values were
`1612e79253b84585b6e9052a16466b6d65eb6ff8b60929ec1f34b974cb9e1cad`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb with `LP_NUM_THREADS=1`,
a fresh process and private browser state, an 800 × 628 document viewport,
a one-second settle, and 32 self-paced 42-pixel scroll steps. Scroll
positions and paint-command counts matched. One-minute guest load ranged
from 1.22 to 1.84 on four virtual CPUs. The timing driver and its memory
guard exited zero. Static captures matched exactly between builds on
each renderer and with caching forced off on the candidate.

| Renderer and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| CPU fallback 1 | 4.2135 / 1.245 | 6.080 / 3.211 | 22.983 / 21.362 |
| CPU fallback 2 | 4.220 / 1.276 | 6.042 / 4.327 | 23.950 / 21.576 |
| GG 1 | 1.071 / 1.025 | 5.905 / 5.747 | 22.915 / 22.745 |
| GG 2 | 1.045 / 1.0455 | 5.787 / 5.739 | 23.354 / 23.266 |

Separate diagnostics counted 155 stationary CPU fill texture hits with
caching and 155 rerasterizations with caching disabled, plus one clipped
fill in each run. The GG diagnostic counted 155 stationary GG texture
hits and one clipped fill, with zero CPU gradient fills. Median CPU
fallback times fell by 69.8–70.5%. GG medians were within 4.3%.
The maximum in every run occurred during replay of the scroll step from
42 to 84 CSS pixels. These trials measure synthetic callback times on
software OpenGL. Native GPU performance and Windows runtime behavior
remain unverified.

## Retaining CPU SVG gradient stroke textures

The CPU stroke texture cache also handles linear and radial gradients.
It compares the resolved gradient geometry, local transform, spread,
opacity, and exact stop values alongside the stroke key. Each slot owns
a bounded copy of up to 16 stops. Larger gradients still rasterize on
every draw. The cache uses the same streaming textures as solid strokes.

The Linux window fixture checked live changes to stop color, opacity,
radial radius, spread, and the local gradient transform of a non-scaling
stroke. The cache rasterized each changed stroke and reused it on later
frames. CPU captures with caching enabled, caching forced off, and
OpenGL 4.2 matched exactly. All 16 Linux GG SVG window checks and the
Windows amd64 OpenGL source check passed.

The timing fixtures were `svg-gg-gradient-stroke.html` and
`svg-gg-stroke.html` in `Tests/Browser/Native/`. Document pixels matched
exactly between builds on each tested route, including when caching
was forced off on the candidate. Both builds used V `5a39a4d`,
single-unit Clang, and `-O0`, from the shared checkout with other changes
in progress. The control and candidate executable SHA-256 values were
`7c42a28b6ef8fbc2503e25fd78f4396bea49c2f15e9eee2228125343a94c77d6`
and `6cd5127d7fdcfcc2f1a1e14ed0a53a1c42434ce18b3574d2a035f21df22f57a3`.
The gradient fixture, solid fixture, and shader directory SHA-256 values were
`0aa4184832b9e3a900f0f8484933ed48e9104d5cd60bb4609aea082d1be41f4e`,
`d760304658f81f4e28f0665645566626ed28b5dcce7d86f195bad583d12c1f5b`,
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb, a fresh process and
private browser state, an 800 × 628 document viewport, a one-second
settle, and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.14
to 2.17 on four virtual CPUs. Timing drivers and memory guards exited
zero.

| Renderer and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Gradient CPU 1 | 3.6175 / 3.515 | 7.402 / 5.033 | 7.442 / 5.716 |
| Gradient CPU 2 | 3.616 / 3.521 | 6.518 / 4.208 | 7.732 / 6.837 |
| Gradient GG 1 | 1.173 / 3.304 | 1.352 / 3.872 | 2.995 / 5.199 |
| Gradient GG 2 | 1.243 / 1.204 | 1.439 / 3.027 | 3.474 / 3.337 |
| Solid CPU 1 | 2.717 / 2.6725 | 3.105 / 4.857 | 6.516 / 5.625 |
| Solid CPU 2 | 2.798 / 2.8175 | 3.087 / 5.972 | 3.142 / 6.070 |
| Gradient GG follow-up 1 | 2.100 / 2.1075 | 2.882 / 2.486 | 6.022 / 5.986 |
| Gradient GG follow-up 2 | 2.1015 / 2.154 | 2.617 / 3.054 | 5.727 / 5.654 |
| Gradient GG one Mesa worker 1 | 1.098 / 1.293 | 1.398 / 1.787 | 3.079 / 3.275 |
| Gradient GG one Mesa worker 2 | 1.0965 / 1.0985 | 2.795 / 1.282 | 3.372 / 1.492 |

Diagnostics counted 155 gradient CPU texture hits with caching and
155 rerasterizations with caching forced off. The solid CPU trace
recorded 186 hits. The instrumented GG runs recorded 155 GG gradient
stroke hits and zero CPU gradient stroke draws in each worker mode.
The exceptional first GG pair spent 1.0775 vs 3.183 ms in median
replay, with one collection in each run. Two further pairs at the
default Mesa setting and two with `LP_NUM_THREADS=1` did not reproduce
that gap. The results leave its cause unresolved.

Median gradient CPU callback time fell by 2.6–2.8%, and p95 fell by
32.0–35.4%. Solid CPU medians were within 1.7%, with higher p95 in
both pairs. GG timing varied across the runs. These synthetic trials
cover software OpenGL. Native GPU timing and Windows runtime remain
unverified.

## Retaining CPU SVG stroke textures

The portable CPU stroker can reuse the contents of a GG streaming image
for a solid stroke. It compares the copied path and dash data, effective
color and stroke style, clipped image dimensions, and the transform
relative to the image. An integer translation can reuse the image at a
new destination. An upload for any other draw invalidates the saved
stroke in that slot. The browser keeps bounded metadata for 16 of its
existing slots. `VOX_DISABLE_GG_SVG_CACHE=1` also disables this reuse.

The Linux window fixture replaced a blue stroke with a red fill of the
same image dimensions, then restored the stroke. Diagnostics recorded
two stroke rasterizations, one before the fill and one after it, with
reuse on subsequent frames. The cached and uncached final captures
matched exactly. All 16 Linux GG SVG window checks and the Windows
amd64 OpenGL source check passed.

The timing fixture was `Tests/Browser/Native/svg-gg-stroke.html`. Its
document pixels matched between the control and candidate on each
renderer, including with caching forced off on the candidate. Both
builds used V `5a39a4d`, single-unit Clang, and `-O0` from the shared
checkout with other changes in progress. The control and candidate
executable SHA-256 values were
`fee8af70e44e2c439fff8de7e8b4e97f2cdc59546fc98ca5b1a3da5faf700901`
and `e5b20619fa57dbf5e721c1fc445b41a2ef22d3a087a286fe31c3a3192c7e6a9a`.
The fixture and shader directory SHA-256 values were
`d760304658f81f4e28f0665645566626ed28b5dcce7d86f195bad583d12c1f5b`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb, a fresh process and
private browser state, an 800 × 628 document viewport, a one-second
settle, and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.45
to 2.78 on four virtual CPUs. The timing driver and memory guard exited
zero.

| Renderer and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| CPU fallback 1 | 5.223 / 2.567 | 6.523 / 5.448 | 7.145 / 5.563 |
| CPU fallback 2 | 5.100 / 2.706 | 6.954 / 5.799 | 6.961 / 5.882 |
| GG 1 | 5.158 / 4.9975 | 7.451 / 6.346 | 7.636 / 9.529 |
| GG 2 | 4.952 / 4.9245 | 7.119 / 5.572 | 8.961 / 9.496 |

Separate diagnostics counted 186 CPU stroke texture hits with caching
and 186 CPU rasterizations with caching forced off. The GG diagnostic
counted 186 GG stroke texture hits and zero CPU fallback draws. Median
CPU fallback times fell by 46.9–50.9%. GG medians and p95 were lower in
both pairs, while maximum callback times were higher. These synthetic
trials cover software OpenGL. Native GPU timing and Windows runtime
behavior remain unverified.

## CPU fallback for solid SVG strokes

On Linux and in opted-in Windows OpenGL builds, a solid SVG stroke that
GG declines uses the same CPU Canvas stroker as gradient strokes. It
resolves the retained stroke color and opacity, rasterizes every contour,
and preserves caps, joins, dash intervals, phase, non-scaling widths, and
SVG paint order. The viewport cull includes the visible fringe of a
non-scaling stroke on Linux even when GG is disabled.

The previous Linux build missed the exterior of a round cap with GG
disabled. Three focused window checks covered live changes to caps,
dash patterns, dash phase, and `vector-effect`, as well as a second
contour, transformed curves, joins, opacity, paint order, zero-length
round dashes, and visible ink at the scrolled viewport edge. The
candidate's GG-disabled and Mesa OpenGL 4.2 captures matched exactly in
each check, as did its cached and uncached GG captures. The Windows
amd64 OpenGL source check and all 15 Linux GG SVG window checks passed.

The timing fixture was `Tests/Browser/Native/svg-gg-stroke.html`. Its
document pixels matched exactly between builds with GG active. Both
builds used V `5a39a4d`, single-unit Clang, and `-O0` from the shared
checkout with other changes in progress. The control and candidate
executable SHA-256 values were
`0f4c995b77a9462718da4a86dca492a04bb600dd4a1a823e67a78850dd7876ca`
and `65fdd0937bbc22feb0d0884470e1573ab3d7835c5a5b093c22298c79aa18bb60`.
The fixture and shader directory SHA-256 values were
`d760304658f81f4e28f0665645566626ed28b5dcce7d86f195bad583d12c1f5b`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each trial used Mesa software OpenGL under Xvfb, a fresh process and
private browser state, an 800 × 628 document viewport, a one-second
settle, and 32 self-paced 42-pixel scroll steps. Both builds recorded
the same scroll positions and command counts. Separate candidate
diagnostics recorded 186 GG stroke texture hits with caching and 186
GG stroke rasterizations with caching disabled. One-minute guest load
ranged from 0.85 to 1.74 on four virtual CPUs. The timing driver and
memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached GG 1 | 5.0615 / 5.211 | 5.998 / 8.291 | 8.292 / 8.794 |
| Cached GG 2 | 4.979 / 4.425 | 6.882 / 7.895 | 8.011 / 9.756 |
| Rerasterized GG 1 | 5.4755 / 5.447 | 6.401 / 7.198 | 6.437 / 8.713 |
| Rerasterized GG 2 | 5.4375 / 5.347 | 7.420 / 6.734 | 9.975 / 6.862 |
| GG disabled 1 | 2.5955 / 3.650 | 3.117 / 5.626 | 3.846 / 5.809 |
| GG disabled 2 | 2.780 / 3.904 | 5.623 / 6.445 | 5.788 / 7.059 |

GG medians ranged from 11.1% faster to 3.0% slower and p95 rose in three
pairs. With GG disabled, the candidate took 1.05–1.12 ms more per
median callback while rendering geometry the control omitted. These are
synthetic callback timings on software OpenGL. Native GPU performance
and Windows runtime behavior remain unverified.

## CPU fallback for SVG gradient strokes

Portable SVG replay tries GG first for gradient strokes, then uses the CPU
Canvas stroker when GG declines a supported sRGB gradient on Linux or in
opted-in Windows builds. The CPU route shares the fill gradient descriptors,
clips the stroke bounds to the viewport, and preserves paint order, opacity,
caps, joins, miter limits, and dashes. For non-scaling strokes it transforms
the centerline and the gradient into surface space while keeping the requested
stroke width in device pixels.

The Linux fixture covered both paint orders, a repeating dashed stroke with
edited opacity, a transformed non-scaling stroke, live gradient-stop edits,
and text outlines. The control showed the underlying blue fill at the first
stroke sample with GG disabled. The candidate passed the color samples in all
four modes. Its GG cached and uncached captures matched each other exactly,
as did its GG-disabled and Mesa OpenGL 4.2 captures. The Windows amd64 OpenGL
source check and the full Linux GG SVG window suite passed.

The Linux comparison used the static stroke fixture and a second fixture
with six previously supported radial fills. Document pixels matched exactly
between builds on both fixtures. Both builds used V `5a39a4d`, single-unit
Clang and `-O0`. The control and candidate executable SHA-256 values were
`d70bc5e8a1142e782139fbf44a956e93b79b3570083c6f2def03ef72c8beeb73`
and `d49cbafa734689d8580b7548d5df9774901b03395ffb1ead2ea00867058a3cf5`.
The stroke fixture, fill fixture and shader directory SHA-256 values were
`0aa4184832b9e3a900f0f8484933ed48e9104d5cd60bb4609aea082d1be41f4e`,
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh process
and private browser state, an 800 × 628 document viewport, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. The comparison used builds from a shared
checkout with other changes in progress.

| Workload and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached strokes 1 | 2.119 / 2.1285 | 2.588 / 2.528 | 5.234 / 5.756 |
| Cached strokes 2 | 1.963 / 2.111 | 2.557 / 5.764 | 6.290 / 7.457 |
| Rerasterized strokes 1 | 5.8305 / 5.9695 | 7.519 / 7.798 | 8.503 / 8.424 |
| Rerasterized strokes 2 | 5.859 / 5.6065 | 7.828 / 6.786 | 8.405 / 7.417 |
| Cached fills 1 | 5.081 / 5.1815 | 6.607 / 6.764 | 8.688 / 7.544 |
| Cached fills 2 | 5.514 / 5.145 | 7.064 / 6.024 | 9.148 / 6.173 |
| Rerasterized fills 1 | 5.9935 / 5.8015 | 8.141 / 7.203 | 8.431 / 8.634 |
| Rerasterized fills 2 | 5.519 / 5.541 | 6.890 / 6.838 | 10.117 / 7.347 |

Median changes ranged from 6.7% faster to 7.5% slower. Both of the slowest
callbacks in the second cached candidate stroke trial included a garbage
collection. Its paired control and both trials in the first cached pair
recorded one collection apiece. Diagnostics counted 155 gradient stroke
texture hits and 186 gradient fill hits, with the same counts of GG
rasterizations when caching was disabled. One-minute guest load ranged
from 0.94 to 2.08 on four virtual CPUs. Both timing drivers and memory guards
exited zero. These trials measure the existing GG route on software OpenGL.
CPU fallback timing, hardware performance, and Windows runtime remain
unverified.

## CPU fallback for SVG repeat and reflect fills

The portable CPU fallback handles sRGB `repeat` and `reflect` fills for
linear gradients and expanding radial gradients with a contained focal
circle. The high-precision shader wraps or mirrors the gradient position
before sampling the stops. Tiled ramps use the interior colors at hard
stops on their endpoints. A repeating point focus on the outer circle
uses the weighted premultiplied stop color beyond the tangent.
[SVG 2 gradient spread and focal circles](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

The Linux fixture checked negative gradient positions, linear endpoint
hard stops, concentric and tangent radial gradients, and the weighted
color beyond a repeating point focus. The control left the first fill
white with GG disabled. The candidate's disabled and Mesa OpenGL 4.2
captures matched exactly. GG and both CPU runs matched the expected
color samples. Existing SVG gradient mask pixels matched the previous
build. Focused CPU gradient and span tests, the full Linux GG SVG window
suite, and the Windows amd64 OpenGL source check passed. The pinned CPU
raster suite matched 20,000 Canvas2D gradient draws against Skia,
including 6,607 strokes, in both default and `-prod -gc none` builds with
seed `20261106`.

The Linux timing comparison used six previously supported radial
gradients, including two tangent pad gradients. Document pixels matched
exactly. Both builds used V `5a39a4d`, single-unit Clang and `-O0`. The
control and candidate executable SHA-256 values were
`2e7839d81825892e44b2592ce955aec163ac6269110866985bbec137a75ce353`
and `d70bc5e8a1142e782139fbf44a956e93b79b3570083c6f2def03ef72c8beeb73`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.13 to
1.61 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 5.0885 / 5.1245 | 7.397 / 6.123 | 9.381 / 6.163 |
| Cached 2 | 5.093 / 4.966 | 6.120 / 6.851 | 7.672 / 8.203 |
| Rerasterized 1 | 5.4855 / 5.858 | 7.847 / 7.844 | 9.258 / 8.858 |
| Rerasterized 2 | 5.541 / 5.9015 | 6.666 / 7.761 | 7.754 / 8.575 |

Cached medians were within 2.5%. Both rerasterized medians increased by
6.5–6.8%. Separate diagnostics counted 186 steady-state GG texture hits
with caching and 186 GG rasterizations with caching disabled. This
workload uses the GG route throughout, and the timing comparison leaves
CPU fallback performance, hardware performance and Windows runtime
unverified.

## CPU fallback for SVG pad fills

The portable painter uses the CPU Canvas rasterizer for sRGB SVG pad
fills when GG declines a gradient. The CPU path accepts linear and
expanding radial gradients with a contained focal circle. It uses the
same gradient descriptors as the SVG mask rasterizer and uploads the
viewport-clipped fill through the existing portable raster path. The
primary GG route handles eligible fills before CPU fallback is needed.

The focused Linux window fixture checked an even-odd hole, a translated
linear ramp with translucent stops, and a translated radial fill with
half opacity. With GG disabled, the control left the first fill white.
The candidate's disabled and OpenGL 4.2 captures matched exactly and
the GPU, CPU and OpenGL 4.2 samples matched the expected colors. The
uncached image-budget fixture now paints the gradient beyond the GPU
budget. The gradient mask and both linear mask strip captures remained
pixel-exact against the previous build. Windows amd64 OpenGL source
checking and the full Linux GG SVG window suite passed.

The Linux timing comparison used six previously supported radial
gradients, including two tangent pad gradients. Document pixels matched
exactly. Both builds used V `5a39a4d`, single-unit Clang and `-O0`. The
control and candidate executable SHA-256 values were
`59ce22808305d99ec7b6511ca77a94eee055b47e1d2b76496619ef2058b75d8d`
and `2e7839d81825892e44b2592ce955aec163ac6269110866985bbec137a75ce353`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.08 to
1.30 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 5.1385 / 5.1965 | 6.926 / 7.618 | 8.219 / 8.150 |
| Cached 2 | 4.9855 / 4.9725 | 6.447 / 6.342 | 8.273 / 8.299 |
| Rerasterized 1 | 5.5465 / 5.735 | 8.462 / 6.859 | 8.503 / 11.410 |
| Rerasterized 2 | 5.662 / 5.468 | 6.555 / 8.533 | 6.598 / 9.014 |

Median differences were within 3.5% across the four pairs, with mixed
p95 results. Separate diagnostics counted 186 steady-state GG texture
hits with caching and 186 GG rasterizations with caching disabled.
This timing workload uses the GG route. Hardware performance and
Windows runtime remain unverified.

## Charging each SVG image once per frame

Portable OpenGL SVG replay accounts for the area of each image when a
frame first references it. Later placements and crops of that image can
draw without spending more of the one-megapixel budget. A cropped draw
charges the full backing image on first use. New and transient images
are admitted against the same budget, before rasterization and queueing.

The Linux window fixture first uses eight distinct 400 × 320 gradient
images. With 24,576 pixels left, both builds decline a ninth distinct
image. The candidate queues two further placements of the first image
and paints the rightmost sample blue. The control leaves it white. A
100 × 200 solid uses another 20,000 pixels. The candidate then reuses
that image for its 30 × 200 viewport crop with 4,576 pixels left. The
uncached candidate draws the same eight large gradients per frame, and
the solid's crop uses the portable fallback. The full Linux GG SVG
window suite and Windows amd64 OpenGL source check passed.

The Linux timing comparison used six previously supported radial
gradients, including two tangent pad gradients. Document pixels matched
exactly. Both builds used V `5a39a4d`, single-unit Clang and `-O0`. The
control and candidate executable SHA-256 values were
`a6406b15ec784be11dced330e5d0e6e83da2db673d56ecaccdc17b432b32a91a`
and `59ce22808305d99ec7b6511ca77a94eee055b47e1d2b76496619ef2058b75d8d`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.33 to
1.67 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 5.193 / 5.199 | 6.640 / 6.741 | 7.594 / 9.698 |
| Cached 2 | 4.7685 / 5.226 | 5.980 / 6.585 | 7.292 / 8.846 |
| Rerasterized 1 | 5.981 / 5.655 | 8.686 / 6.389 | 8.863 / 8.167 |
| Rerasterized 2 | 5.3215 / 5.3615 | 7.588 / 7.339 | 9.686 / 8.034 |

The cached median was nearly equal in the first pair and 9.6% higher in
the second. The rerasterized medians moved in opposite directions.
Separate diagnostic runs counted 186 steady-state texture hits with
caching and 186 rasterizations with caching disabled. Working-tree
differences and trial variability limit attribution. Hardware performance
and Windows runtime remain unverified.

## Portable SVG draws beyond the texture cache

Portable OpenGL SVG replay admits draws under its pixel and image budgets.
Its 16 retained texture slots serve matching draws, including repeated
placements of one raster. New rasters can use up to 64 transient image
handles when the retained slots are occupied. These images are retired
after GG submits the frame. Both kinds of draw share a one-megapixel
per-frame budget and a 1024-pixel limit on either surface axis. The
transient handle cap leaves space in the Sokol image pool for other painters.

The Linux window fixture contains 20 distinct gradients, 44 translated
repeats and a translucent overlay. The control rendered eight gradients
and left the ninth sample white. The candidate rendered all 65 draws
through GG, with identical cached and uncached document pixels. Warm
cached frames had 60 texture hits and submitted five transient images.
Uncached frames submitted 49 transient images. The test sampled each
gradient and the overlay to verify paint order and image lifetime.
The full Linux GG SVG window suite and Windows amd64 OpenGL source check
passed.

The Linux timing comparison used six previously supported radial
gradients, including two tangent pad gradients. Document pixels matched
exactly. Both builds used V `5a39a4d`, single-unit Clang and `-O0`. The
control and candidate executable SHA-256 values were
`9103707a0fece84803f9b575da2fb4b1ac5886547cd4b08cd5bedc56ff39423d`
and `a6406b15ec784be11dced330e5d0e6e83da2db673d56ecaccdc17b432b32a91a`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.41 to
2.68 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 4.243 / 4.410 | 5.630 / 5.107 | 7.125 / 7.428 |
| Cached 2 | 4.4425 / 4.3845 | 6.209 / 7.511 | 7.604 / 7.985 |
| Rerasterized 1 | 5.3585 / 5.1485 | 7.279 / 7.493 | 8.856 / 7.777 |
| Rerasterized 2 | 5.3605 / 5.2515 | 8.333 / 8.360 | 8.598 / 8.424 |

The four median differences were within 4%, and p95 varied in both
directions. Separate diagnostic runs counted 186 steady-state texture
hits with caching and 186 rasterizations with caching disabled. The
builds can include unrelated working-tree changes. Hardware performance
and Windows runtime remain unverified.

## Repeating SVG point focuses on the outer circle

For an sRGB `repeat` gradient whose point focus lies on the outer circle,
the shared Canvas shader paints the repeating ramp on the side containing
the circles and the weighted stop color across the tangent. Paint
preparation averages the premultiplied stop colors over their normalized
offsets, including implicit endpoints. The same paint opacity applies to
both regions. The tangent shader stores the average in the gradient
paint's spare RGB channels and final padding word. [SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

Metal and Mesa OpenGL pixel tests covered clipping, unequal stop
spacing, implicit endpoints, hard stops and translucent colors. The
Linux window fixture verified both sides of the tangent after a live
stop-color edit. The texture was rebuilt with the retained path bounds,
and cached and uncached captures matched exactly. The first fixture
attempt placed this case after eight other SVG draws, which exhausted
the portable renderer's per-frame draw limit. The new fixture exercises
the case independently. The full Linux GG SVG window suite and Windows
amd64 OpenGL source check passed.

The Linux comparison used a fixed page of six previously supported
radial gradients, including a tangent circle and point in pad mode.
Document pixels matched exactly. Both builds used V `5a39a4d`,
single-unit Clang and `-O0`. The control and candidate executable
SHA-256 values were
`5b1241a7ccbcc403609354ec767a336800cffa21d9078d0511e8b0f571016b31`
and `9103707a0fece84803f9b575da2fb4b1ac5886547cd4b08cd5bedc56ff39423d`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.43 to
2.59 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 6.2215 / 5.389 | 7.397 / 7.590 | 10.970 / 8.922 |
| Cached 2 | 4.8905 / 4.762 | 6.049 / 7.632 | 6.337 / 7.982 |
| Rerasterized 1 | 5.633 / 5.024 | 8.442 / 7.583 | 9.444 / 9.055 |
| Rerasterized 2 | 5.2775 / 6.9095 | 6.609 / 9.577 | 7.697 / 10.696 |

Separate diagnostic runs confirmed 186 steady-state texture hits with
caching and 186 rasterizations with caching disabled. The cached
medians were lower but both p95 values increased. The rerasterized
pairs moved in opposite directions. These builds also contain different
working-tree changes, so the comparison does not isolate the shader's
effect. Hardware performance and Windows runtime remain unverified.

## Spreading internally tangent SVG gradients

The tangent shader now also handles reflection and positive-radius
repetition. The existing four- and eight-stop variants apply spread
after solving for the gradient position and preserve the transparent
region beyond the tangent. [SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

Focused Metal and Mesa OpenGL pixel tests verified tiling at negative
gradient positions and the transparent region beyond tangency. The Linux
window fixture changed `spreadMethod` from `pad` to `repeat` on a tangent
circle and checked the repeated ramp, a diagonal reflected point at half
opacity and texture invalidation with path bounds reuse. Cached and
uncached document captures matched exactly. The full Linux GG SVG window
suite and Windows amd64 OpenGL source check passed.

The established-workload fixture contains six radial gradients,
including a tangent circle and point in pad mode. Its document pixels
matched exactly between Linux builds made with V `5a39a4d`, single-unit
Clang and `-O0`. Control and candidate executable SHA-256 values were
`d61e60572f01765c86f8078fd5597a0a488c9f9c06e03dcfa3c43861209943fd`
and `5b1241a7ccbcc403609354ec767a336800cffa21d9078d0511e8b0f571016b31`.
The fixture and shader directory SHA-256 values were
`31fa083ecdeb687010ac4d67fd9d1aca933bee20f0d77c21b97ea640e7b31e26`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 1.01 to
1.75 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 5.3895 / 5.6655 | 8.047 / 6.297 | 8.905 / 6.480 |
| Cached 2 | 5.641 / 5.0925 | 7.402 / 8.814 | 8.607 / 10.173 |
| Rerasterized 1 | 7.2865 / 6.2165 | 11.375 / 7.330 | 12.817 / 9.393 |
| Rerasterized 2 | 11.523 / 6.7815 | 17.935 / 10.125 | 20.539 / 10.901 |

Separate diagnostic runs confirmed 186 steady-state texture hits with
caching and 186 rasterizations with caching disabled. The cached pairs
had mixed results and the rerasterized control medians varied by over
4 ms. The executables also contain different working-tree changes, so
these results do not isolate this change's effect. Hardware performance
and Windows runtime remain unverified.

## Internally tangent SVG focal circles

The shared Canvas path handles an expanding pad gradient whose focal
circle touches the outer circle, including a point focus. When the
quadratic term vanishes, the gradient uses the linear solution and
leaves the half-plane beyond the common tangent transparent. Dedicated
four- and eight-stop shader variants are compiled on demand.
[SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

The shared pixel test passed on Metal and Mesa OpenGL for a tangent
circle at full and half opacity. The Linux window fixture also covers a
diagonal point focus and an `fx` edit that moves a strictly nested circle
into tangency. Cached and uncached document captures matched exactly.
The full Linux GG SVG window suite and Windows amd64 OpenGL source check
passed.

Existing radial gradients matched pixel for pixel against the previous
Linux executable. Both builds used V `5a39a4d` and single-unit Clang
`-O0`. The control and candidate executable SHA-256 values were
`45ddfffaac3740494f141417f07a83639ecc97df5b2fd60c04bec3745883061d`
and `d61e60572f01765c86f8078fd5597a0a488c9f9c06e03dcfa3c43861209943fd`.
The fixture and shared shader directory SHA-256 values were
`c5d880e712d0a6eb9bd203e4c58cbbcd0939ade054911cc6cd893ed49e01fef2`
and `970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.

Each synthetic trial used Mesa software OpenGL under Xvfb, a fresh
process and private browser state, an 800 × 712 window, a one-second
settle and 32 self-paced 42-pixel scroll steps. Scroll positions and
paint-command counts matched. One-minute guest load ranged from 0.93 to
2.19 on four virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median control / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 5.5675 / 4.083 | 7.660 / 7.126 | 9.444 / 7.522 |
| Cached 2 | 5.019 / 4.3205 | 6.100 / 5.334 | 7.636 / 7.006 |
| Rerasterized 1 | 5.250 / 4.077 | 7.944 / 6.689 | 9.116 / 7.023 |
| Rerasterized 2 | 5.296 / 5.0175 | 8.521 / 6.422 | 8.625 / 7.676 |

Separate diagnostic runs confirmed 62 steady-state cache hits with
caching and 62 rasterizations with caching disabled. The executables
also contain different working-tree changes, so the timing comparison
does not isolate the tangent shader's effect. Hardware performance and
Windows runtime remain unverified.

## Off-center SVG focal circles

The shared Canvas path now draws a radial gradient whose focal circle
is strictly contained in its outer circle, including a zero-radius focal
point. The gradient transform aligns the coordinate system with the line
between the centers. The radial shader uses the larger root of the
two-circle equation before applying the spread method. The geometry
parameters fit into existing uniform padding and texture cache hits
reuse the rendered pixels. [SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

The shared path pixel test passed on Metal and Mesa OpenGL, including
samples along and across the axis and declines for crossing circles and
circles that round to tangency at shader precision.
The Linux window fixture checked a shifted focal circle and a diagonal
zero-radius focal point with reflection. Pixel samples matched the
expected ramps. Cached and uncached document captures were identical
after an `fx` edit that rebuilt the texture and reused the path bounds.
The full Linux GG SVG window suite and Windows amd64 OpenGL source check
passed.

The first comparison was invalid because the prior non-production binary
read the changed shader snippet from the shared module directory. Its
fragment shader could not compile. The renderer generates the new
formula from the compiled shader generator and preserves the shared
snippet used by the baseline. The comparison pins the shader directory
along with the executable and fixture hashes.

The corrected comparison used V `5a39a4d`, single-unit Clang `-O0`, and
baseline and candidate executable SHA-256 values
`05def48a1bead78677995b824dc0d0b4830e6de0f41a47e981996f404db0d767` and
`45ddfffaac3740494f141417f07a83639ecc97df5b2fd60c04bec3745883061d`.
The zero-focal fixture SHA-256 was
`c5d880e712d0a6eb9bd203e4c58cbbcd0939ade054911cc6cd893ed49e01fef2`.
The staged shader directory hash was
`970ce36acbf7ea10b948d0a063d6315d587aadf8a8d84784d644b17ab6ffc48e`.
The captures for existing gradients matched pixel for pixel. These runs
preceded the tangent precision guard, which the focused path tests cover.

The comparison used Mesa software OpenGL under Xvfb, fresh processes and
private browser state, an 800 × 712 window, a one-second settle and 32
synthetic 42-pixel scroll steps. Scroll positions and paint-command
counts matched. The one-minute guest load ranged from 1.03 to 1.82 on four
virtual CPUs. The benchmark and memory guard exited zero.

| Mode and pair | Median baseline / candidate, ms | p95, ms | Maximum, ms |
| --- | ---: | ---: | ---: |
| Cached 1 | 4.4945 / 4.469 | 6.308 / 5.327 | 7.947 / 8.459 |
| Cached 2 | 4.386 / 4.8495 | 5.670 / 6.343 | 7.466 / 8.463 |
| Rerasterized 1 | 4.2595 / 4.219 | 8.080 / 4.998 | 9.174 / 6.681 |
| Rerasterized 2 | 4.2735 / 5.040 | 5.736 / 5.963 | 6.674 / 6.349 |

Diagnostic runs confirmed 62 steady-state texture hits with caching and
62 rasterizations without it. Timing varied in both modes. Hardware
performance remains unverified.

## Reusing the SVG geometry lookup for exact textures

The OpenGL SVG bounds lookup now returns the matching cache slot. If that
slot also matches the draw's transform, extent, paint and dash pattern,
the renderer uses its texture immediately. The full search still handles
paths that share geometry but use different paints or clipped extents.

The zero-focal-radial fixture produced identical document pixels before
and after the change. In a separate diagnostic, all 62 gradient draws
after the first callback reused the bounds slot and skipped the texture
search. The Linux GG SVG window suite verified that a linear and radial
fill sharing geometry still select separate textures. The Windows amd64
OpenGL source check passed.

Both Linux executables used V `5a39a4d` and single-unit Clang `-O0`.
Baseline and candidate executable SHA-256 values were
`577804eeb49b809f51da18c546080ee3f0001583b96ae3e9ee4b81d4e10cf5f4` and
`d2501c77a1daa3da6b158756406ff4c8ea6dfee4e5d3d38d633997e585fb8bd3`.
The fixture SHA-256 was
`c5d880e712d0a6eb9bd203e4c58cbbcd0939ade054911cc6cd893ed49e01fef2`.
Three alternating pairs used cached SVG textures, Mesa software OpenGL
under Xvfb, an 800 × 712 window, a one-second settle and 32 synthetic
42-pixel scroll steps. Each run had a fresh process and private browser
state. Scroll positions and paint-command counts matched. One-minute
guest load ranged from 1.28 to 1.58 on four virtual CPUs. The benchmark,
browser and memory guard exited zero.

| Pair | Median callback baseline / candidate, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 4.658 / 4.8475 | 6.163 / 5.836 | 7.932 / 8.452 |
| 2 | 4.714 / 4.437 | 7.737 / 7.006 | 7.938 / 8.314 |
| 3 | 4.8445 / 4.871 | 8.130 / 6.089 | 8.912 / 7.695 |

The first window suite exposed a diagnostic suffix used by the dashed
stroke test. The final build moved the new marker earlier on the line.
Its executable SHA-256 was
`05def48a1bead78677995b824dc0d0b4830e6de0f41a47e981996f404db0d767`.
It repeated the same workload and reproduced the exact document pixels
and the 62 direct texture hits. One-minute guest load ranged from 1.10
to 1.25. The benchmark, browser and memory guard exited zero.

| Final pair | Median callback baseline / candidate, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 4.7345 / 4.3795 | 7.722 / 5.056 | 7.892 / 6.339 |
| 2 | 4.6845 / 4.566 | 5.425 / 5.107 | 7.144 / 5.117 |
| 3 | 4.8195 / 4.876 | 6.050 / 6.111 | 7.880 / 7.403 |

Across the six pairs, the p95 fell five times. Median callback times
varied. These synthetic callbacks leave hardware performance open.

## Repeating and reflected SVG focal circles

The shared Canvas gradient constructor accepts expanding concentric radial
gradients with a nonzero `fr` and `repeat` or `reflect` spread. It maps the
distance from the center to `(distance - fr) / (r - fr)` before tiling. The
focal and outer circles define one period. The offset occupies existing
uniform padding and uses the same radial shader variants. This handles
expanding circles with a shared center. [SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

The shared path pixel test passed on Metal and Mesa OpenGL. It sampled
points inside the focal circle and exercised both the four-stop shader and
the eight-stop alpha variant. The Linux window fixture's cached and
uncached document pixels matched exactly, including after a live `fr`
edit that reused geometry bounds. The full Linux GG SVG window suite and
the Windows amd64 source check passed.

Existing gradients with `fr="0"` produced identical document pixels in
the previous and updated Linux builds. The executables used V `5a39a4d`
and single-unit Clang `-O0`. Their SHA-256 values were
`6fd17e6319c21f92f6049eca3e57d9df8a414323c20c45d374f78caa201afa9b` and
`577804eeb49b809f51da18c546080ee3f0001583b96ae3e9ee4b81d4e10cf5f4`.
The zero-focal fixture SHA-256 was
`c5d880e712d0a6eb9bd203e4c58cbbcd0939ade054911cc6cd893ed49e01fef2`.
Six alternating runs used Mesa software OpenGL under Xvfb, fresh
processes and browser profiles, an 800 × 712 window, a one-second settle
and 32 synthetic 42-pixel scroll steps. Scroll traces and paint-command
counts matched. One-minute guest load ranged from 0.90 to 1.37 on four
virtual CPUs. The benchmark, browser and memory guard exited zero.

| Pair with rerasterization | Median baseline / candidate, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 5.261 / 5.0275 | 8.679 / 5.605 | 8.997 / 8.432 |
| 2 | 4.406 / 4.9025 | 5.862 / 6.976 | 7.209 / 7.374 |
| 3 | 4.4585 / 5.275 | 6.644 / 6.893 | 9.593 / 8.181 |

A separate diagnostic confirmed 62 radial rerasterizations after the
first callback. Median callback time fell in one pair and rose in two.

Three more pairs used the same inputs with the SVG texture cache enabled.
One-minute guest load ranged from 1.46 to 1.68. A separate diagnostic
confirmed texture and bounds cache hits for all 62 radial draws after the
first callback. The benchmark and memory guard exited zero.

| Pair with caching | Median baseline / candidate, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 4.6855 / 4.8055 | 8.908 / 6.582 | 9.325 / 7.114 |
| 2 | 4.7045 / 4.713 | 6.375 / 7.292 | 7.331 / 8.416 |
| 3 | 3.852 / 4.324 | 5.329 / 6.185 | 6.536 / 6.493 |

Median callback time rose by 0.2–12.3% with caching, and p95 varied.
The callback timings include the full browser replay, with the radial
shader skipped on cache hits. Hardware performance remains unverified.

## Sharing OpenGL gradient shaders across viewport clips

When the rectangular hole in an SVG gradient rectangle moves out of view,
the opt-in OpenGL path keeps the same shader and blend state. The
ordinary rectangle and viewport-filling draws use full coverage when the
clip is absent. The viewport fixture now ends with the holes offscreen.
Baseline and candidate document pixels matched exactly. The full Linux GG
SVG window suite and the Windows amd64 source check passed.

A cold OpenGL trace found two program links and two roughly 84 ms first
draws when the holes moved out of view. An initial fix covered the
rectangle draw, leaving the viewport-filling draw to select a separate
shader. Its three candidate times for that callback were 243, 308 and
208 ms. The final diagnostic submitted eight shader sources before the
first measured callback completed in both builds. It submitted four sources
during the third callback in the baseline and zero with the fix. The next
29 callbacks recorded 232 exact gradient cache hits in each build.

Both builds used V `5a39a4d` and single-unit Clang `-O0`. The baseline
SHA-256 was `f00fee78c624da1f24e9fd480718063667b22d491d5727e44da9d68b366957db`
and the candidate SHA-256 was
`6fd17e6319c21f92f6049eca3e57d9df8a414323c20c45d374f78caa201afa9b`.
The 12-row fixture SHA-256 was
`a9fe42f2a7f42265436ffea8a2af7eb03675aab90c076beda33508f28a336d02`.
Three alternating pairs used Mesa software OpenGL under Xvfb with an
800 × 712 window, a one-second settle, 32 synthetic 42-pixel scroll
steps, and fresh processes, profiles, browser caches and shader caches.
Scroll traces and paint-command counts matched. The one-minute guest
load ranged from 1.20 to 1.34 on four virtual CPUs. The benchmark,
browser and memory guard exited zero.

| Pair | Third callback baseline / candidate, ms | Median, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 199.210 / 6.477 | 2.2165 / 2.343 | 6.405 / 6.807 | 199.210 / 7.519 |
| 2 | 200.487 / 5.075 | 2.1375 / 2.351 | 7.086 / 6.120 | 200.487 / 7.998 |
| 3 | 204.138 / 3.158 | 1.8045 / 2.4275 | 6.381 / 6.706 | 204.138 / 7.544 |

The cold clip transition became shorter in each pair. Median callback
time increased by 6–35%, and the p95 rose in two pairs.

Three more pairs retained each build's Mesa shader cache from its first
cold trial and used fresh browser state. One-minute guest load ranged
from 1.15 to 2.02. The benchmark, browser and memory guard exited zero.

| Pair | Third callback baseline / candidate, ms | Median, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 33.254 / 3.701 | 1.6895 / 2.3865 | 8.694 / 6.165 | 33.254 / 7.734 |
| 2 | 36.471 / 5.623 | 1.611 / 2.270 | 6.745 / 6.394 | 36.471 / 8.155 |
| 3 | 26.026 / 3.963 | 2.2555 / 2.114 | 7.461 / 7.533 | 26.026 / 12.044 |

The warm clip transition also became shorter in each pair. The median
increased in two pairs and fell in one. These timings cover synthetic
draw callbacks. Hardware performance remains unverified.

## Retaining exact SVG gradient textures at viewport edges

With `VOX_GG_SVG=1` and `VOX_GG_SVG_VIEWPORT_REUSE=1`, OpenGL keeps unused
gradient textures within the existing one-megapixel retained budget.
Revisiting a viewport clip can reuse an exact match for the raster extent,
transform, path and paint. When all 16 slots are occupied, the renderer can
evict an older texture that the current frame has yet to use. The most
recent frame's textures stay available during matching.

An initial experiment sampled a larger texture at the same 8×8 dither
phase. Two document pixels differed by one channel level against a
freshly rasterized clip. A new gradient extent still rasterizes on first
use, with subsequent reuse limited to identical inputs.

The Linux viewport check moved three paths across the top edge, restored
them, and revisited the first clip. The cached run rendered each clipped
extent once and reproduced the baseline's document pixels exactly. The full
Linux GG SVG window suite and Windows amd64 OpenGL source check passed.

The Linux executable used V `5a39a4d` and single-unit Clang `-O0`, with
SHA-256 `bde18d2a431c82edc9fcf76a87600348c19a91a5f570dce7df95cf6e43af0499`.
The timing fixture repeated the three paths in 12 SVG rows spaced at 168
CSS pixels, with SHA-256
`a9fe42f2a7f42265436ffea8a2af7eb03675aab90c076beda33508f28a336d02`.
Three alternating pairs used Mesa software OpenGL under Xvfb, fresh
processes and private profiles and caches, an 800 × 712 window, a
one-second settle and 32 synthetic 42-pixel scroll steps. System caches
remained available. One-minute guest load ranged from 1.05 to 1.26 on
four virtual CPUs. Executable and fixture hashes, scroll positions and
paint-command counts matched. The benchmark and memory guard exited zero.

| Pair | Median callback baseline / retained, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 3.5535 / 2.486 | 7.645 / 7.539 | 206.909 / 203.608 |
| 2 | 4.004 / 2.100 | 9.219 / 8.884 | 284.325 / 209.542 |
| 3 | 4.230 / 1.686 | 7.293 / 7.541 | 281.776 / 257.525 |

Median callback time fell by 30–60%. Separate diagnostic runs recorded 248
gradient draws in each mode after the first callback and reduced fresh
rasterizations from 69 to 6. Every run reached its maximum callback at
the third step, when the 27- and 28-pixel-high clips were first rasterized.
These synthetic runs measure callback time. First-time clip latency and
hardware performance remain open.

## Concentric SVG focal circles

The shared GG path renderer handles an expanding concentric radial gradient
with `spreadMethod="pad"` and a nonzero `fr`. On a texture miss it maps the
stops into the ordinary radial shader's coordinate range. The implicit first
stop extends the first color inside the focal circle. The shader and cached
texture replay are shared with ordinary radial gradients. The shader's
effective eight-stop limit still applies, including the implicit stop.
Offset centers, contracting radii, and repeat or reflect with a nonzero `fr`
remain outside this slice. [SVG 2 radial gradients](https://www.w3.org/TR/SVG2/pservers.html#RadialGradients)

The focused path tests passed on Metal and Linux OpenGL for transformed fills
and strokes. The Windows amd64 OpenGL source check passed. The full Linux GG
SVG window suite (`tools/test_linux_browser.py --gg-svg`) verified that
separate live edits to `gradientTransform` and `fr` each rerasterized the
texture and hit the geometry cache. Its cached and uncached document pixels
were identical.

The Linux window and timing runs used V `5a39a4d`, single-unit Clang
`-O0`, and executable SHA-256
`6781cbd687d9bfda3e9a0b4991b09c11c7d2effdf57dd1049b86dd825e9da116`.
The fixture SHA-256 was
`1612e79253b84585b6e9052a16466b6d65eb6ff8b60929ec1f34b974cb9e1cad`.
`tools/measure_browser_scroll.py` ran with Mesa software OpenGL under
Xvfb, an 800 × 712 window, a one-second settle, 32 synthetic 42-pixel
steps, and fresh processes, profiles and browser caches. System caches
remained available. Scroll positions and paint-command counts matched.
The one-minute load observed on the four guest CPUs ranged from 0.52 to
1.12. Browser, test and memory guard exits were zero for these runs.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 5.4625 / 2.067 | 8.377 / 4.636 | 22.223 / 21.518 |
| 2 | 5.3505 / 1.9955 | 8.057 / 6.510 | 22.784 / 25.772 |

Caching reduced median callback time by 62–63%. Separate diagnostics
showed that all 31 focal-circle draws after the first measured callback
hit both the texture and geometry caches.

A second check compared the cached focal-circle fixture with an ordinary
radial gradient that repeats the first color at offset `8/24`. The
ordinary fixture SHA-256 was
`137dfb8953be3986f6f4904ad0455ca5d0f2dd9038f5e4debad0c5a9118cb9b9`.
Their document pixels and scroll traces matched exactly.

| Pair | Median callback ordinary / focal circle, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 1.713 / 2.033 | 5.176 / 7.058 | 30.576 / 31.865 |
| 2 | 1.932 / 1.590 | 5.138 / 5.632 | 34.402 / 35.385 |

Median timings varied between pairs and the focal-circle fixture had
a higher p95 in both. Every timing run had its longest callback at the
second step, when the moving gradient crossed the viewport edge. These
callback timings leave end-to-end performance parity open.

## SVG gradient strokes on OpenGL

The opt-in OpenGL renderer uses the same sRGB linear and concentric
radial gradient descriptors for fills and strokes. The texture cache keys
on the gradient, stroke style and dash pattern. A gradient-only paint
stays in document paint order when the stroke has an empty solid-color
field. Gradient-stroked text retains the glyph outline. A zero-width
gradient stroke still permits the solid-fill glyph path.

The non-scaling draw maps the gradient into the same texture coordinates
as the transformed outline. This preserves the gradient's placement on
the shape while computing the stroke width in device space. [SVG 2 vector effects](https://www.w3.org/TR/SVG2/painting.html#VectorEffects)

The Windows OpenGL source check and the Metal shared-path and
non-scaling regression tests passed. A focused Metal descriptor check
sampled the transformed gradient and its six-pixel stroke width. The
combined macOS layout test reached its aggregate memory limit. The
gradient-stroke assertions passed in a focused driver after separating
compilation and execution. They kept the outline at positive width and
used glyphs at zero width.

The first Linux attempt stopped on host disk writes, and an in-guest
compiler was killed while another compiler was resident. After recovery,
the full Linux GG SVG window suite passed. Cached and uncached document
captures matched exactly. The gradient stroke fixture covered both
paint orders, dashes, non-scaling width, text outlines and live stop and
opacity edits.

The current Windows OpenGL browser also linked with V `178232d`, MinGW
GCC 16.2.0 and single-unit C `-prod -no-prod-options`. Its executable
SHA-256 was
`3defcf4daeef62d3994adaae06b9b6998b08d3cd69f4a05b108d99247d719483`.
The 12 GiB guard exited zero at a sampled peak of 10,086,531,072 bytes.
The legacy Python builder initially failed because its staged GG layer
lacked the repeat-filter and translation fields. It now calls the same
Canvas staging helper as the V builder. A focused driver check verified
the fields and the OpenGL build flag using the prepared module tree.

The Windows 11 x86-64 QEMU guest matched the executable and live-edit
fixture hashes before launch. The cached run requested Mesa llvmpipe
and reached its five-minute deadline with exit 124 and 237,436,928 bytes
of peak committed memory under the 3 GiB job guard. It produced no
capture or renderer diagnostics. The harness skipped the uncached run.

The [focused graphics smoke](WINDOWS.md#focused-native-checks) opens a
Sokol window without the browser or JavaScriptCore. Its OpenGL variant
checks a shared Canvas gradient stroke before capturing window pixels.
On Linux with Mesa under Xvfb, the stroke and the projection, color and
text pixel checks passed. Both Windows variants linked with V `178232d`
and MinGW GCC 16.2.0 using the dynamic pthread import library.

The Windows 11 QEMU OpenGL probe timed out before its window startup
marker. The D3D11 control also timed out without output or a capture.
Both reached the four-minute limit and exited 124 under 3 GiB guards.
Peak committed memory was 2,150,400 bytes for OpenGL and 2,297,856 for
D3D11. All transfer input hashes matched after the tests.

A fresh Windows OpenGL browser built with the same compiler and C mode
had SHA-256
`fdf6715ed791993d844e89260457faded012d06babbb0b2b509f5b8c492b8aa9`.
Its headless run in the guest's SSH session executed JavaScript and
passed DOM mutation, click and wheel handling. The 3 GiB guard reported
exit zero and 442,695,680 bytes of peak committed memory.
The same executable's interactive run reached the shared Canvas
renderer and logged linear, radial, dashed and non-scaling strokes.
It reached its first paint replay checkpoint before the five-minute
guard timed out with exit 124 and 543,813,632 bytes of peak committed
memory. The harness skipped the uncached run.

A ten-minute retry with warm system caches captured both cache modes.
The document rows matched pixel for pixel, and the shape and live-edit
checks passed. Both captures lacked the gradient on the text outline.
The deployed Windows executable could not resolve the checkout-based
fallback font. Windows now resolves installed Arial when the configured
and bundled paths yield no font, using the installed bold face where
available. The font path uses the existing per-family and weight cache.

The Windows tests found the regular and bold fallbacks and decoded a
glyph outline from installed Arial. The macOS configured-font override
test also passed. The rebuilt Windows executable had SHA-256
`cbff4ec24dd0bd918cb51fdb3f4ee5c37698b67fce9c300fd128741cb49ee313`.
Its fresh cached and uncached processes captured the same 800 × 600
window fixture with Mesa software OpenGL. Both passed the stroke order,
dash, non-scaling, text and live-edit assertions. Document pixels matched
exactly. Both 3 GiB guards exited zero and reported peak committed memory
of 564,645,888 and 569,634,816 bytes, respectively.

The Linux executable SHA-256 was
`1e91375a68de0d8d906ed22a6c1021901b570acb45a6300386cffa0739da5b46`.
It used V `5a39a4d` and single-unit Clang `-O0`. The fixture SHA-256 was
`0aa4184832b9e3a900f0f8484933ed48e9104d5cd60bb4609aea082d1be41f4e`.
The benchmark used Mesa software OpenGL under Xvfb with fresh processes,
private profiles and caches, an 800 × 712 window, one second of settling,
and 32 synthetic 42-pixel scroll steps. System caches remained available.
Input hashes, scroll positions and paint-command counts matched.
One-minute guest load ranged from 0.23 to 1.14 on four virtual CPUs.
Linux window checks, replay benchmarks and their memory guards exited zero.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 5.959 / 2.160 | 7.407 / 2.631 | 9.095 / 5.751 |
| 2 | 5.790 / 2.155 | 7.303 / 2.728 | 9.086 / 6.266 |

Caching reduced median callback time by 63.7% and 62.8%. Separate
diagnostics recorded 155 fixed gradient stroke draws over 31 moving
callbacks. All 155 reused their textures and bounds with caching enabled.
These measurements cover synthetic software OpenGL replay.

## SVG gradient fills on OpenGL

The opt-in OpenGL renderer sends sRGB linear and concentric radial SVG
fills to the shared `gg.canvas` descriptor renderer. It uses the retained
gradient coordinates and transform, pad/repeat/reflect spread, exact
stop colors and positions, and the combined fill opacity. It preserves
even-odd holes and the author-specified order of fill and stroke. The
shader still requires supported geometry and at most eight effective
stops after stop normalization.

The texture cache owns the gradient parameters and compares stops
before reusing pixels. The geometry-bounds cache is independent of
paint changes. Gradients rerasterize when they cross a viewport edge,
where a cropped texture can have a different dither phase.

Linux window checks exercised linear and radial fills, repeat and
reflect, a single translucent stop, an even-odd hole, and stroke-first
painting. Live edits to stop color, gradient transform, and fill
opacity each rerasterized the affected gradient while reusing its
geometry bounds. Cached and uncached document pixels matched, including
the clipped gradient at scroll offset 65. The Windows OpenGL source
check passed. Windows window and pixel verification remain pending.

The Linux executable SHA-256 was
`79e37d4ac9924f5cbb379da3c51573a09445c724816589926fab6c4a49a77f6f`.
It used V `5a39a4d` and single-unit Clang `-O0`. The fixture SHA-256 was
`35365473bf7d60f093c34051576f417a906c1fa8ecedad1564950b44b43d687b`.
The benchmark used Mesa software OpenGL under Xvfb with fresh processes,
private profiles and caches, an 800 × 712 window, one second of settling,
and 32 synthetic 42-pixel scroll steps. System caches remained available.
Input hashes, scroll positions and paint-command counts matched.
One-minute guest load ranged from 0.49 to 0.81 on four virtual CPUs.
The browser tests, benchmark and their memory guards exited zero.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 4.616 / 1.662 | 7.603 / 4.493 | 29.502 / 32.193 |
| 2 | 4.427 / 1.647 | 6.652 / 6.312 | 31.991 / 31.241 |

Caching reduced the medians by 64.0% and 62.8%. Separate diagnostics
recorded all 150 fixed gradient draws as texture and bounds hits over
the final 30 moving callbacks. With caching disabled all 150 gradients
rasterized again. Every timed run had its longest callback at the
second scroll step, while the scrolling gradient crossed the viewport
edge. These measurements cover synthetic software OpenGL replay.

## Dashed SVG strokes on OpenGL

The opt-in OpenGL renderer splits a solid-color dashed stroke with the
existing CPU dash effect, then rasterizes the resulting contours with
`gg.canvas`. Scaling strokes split in SVG user space. Non-scaling strokes
split after transforming the path into device space. The texture cache
owns the interval list and keys on the dash offset, so an unchanged draw
reuses its texture without splitting the path again. Bounds reuse depends
on geometry alone.

The path uses the existing texture budgets. Dashed draws accept up to
32 intervals and 128 source segments and decline when the dash-count
estimate exceeds 2,048. These declines use legacy replay.

Linux window checks covered lines, quadratic curves, arcs, round dots,
closed contours, `pathLength`, paint order, and non-scaling dashes. Live
changes to the intervals and offset each rebuilt the texture and reused
the geometry bounds. The cached and uncached document captures were
pixel-exact. The CPU dash and path-hit regression tests, the new dash budget
test, the Metal shared-path and non-scaling regression tests, and the
Windows OpenGL source check passed. Windows runtime verification remains
pending.

The Linux executable SHA-256 was
`937e2a27992b266598894ff742dca3b3721ab80f031785d29c335e4fcec35017`.
It used V `5a39a4d` and single-unit Clang `-O0`. The fixture SHA-256 was
`f6dc5669fe10c1f4c17c179264066dc446b538fd222d8dcdd2719f73c0817fbc`.
The benchmark used Mesa software OpenGL under Xvfb, fresh processes
with private profiles and caches, an 800 × 712 window, one second of
settling, and 32 synthetic 42-pixel scroll steps. System caches remained
available. Input hashes, scroll positions and paint-command counts
matched. One-minute guest load ranged from 0.52 to 1.44 over four virtual
CPUs. The browser tests, benchmark, and their memory guards exited zero.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 5.290 / 3.248 | 7.724 / 5.199 | 7.777 / 5.442 |
| 2 | 4.784 / 1.311 | 6.219 / 1.874 | 6.867 / 3.461 |

Separate diagnostics counted 217 dashed-stroke texture and bounds hits
over the final 31 moving callbacks. With caching disabled all 217
strokes rasterized again. The measured medians improved by 38.6% and
72.6%. The cached runs varied by more than 2×. These timings cover
synthetic software OpenGL replay. The first Linux link launch hit a
shared-filesystem log write error, and the first Windows check stopped
before emitting a report. Both passed on retry.

## Non-scaling SVG strokes on OpenGL

The opt-in OpenGL path now uses the existing `gg.canvas` non-scaling
stroke implementation. It transforms the path first and applies its
stroke width in device space, matching the standalone macOS path's
width convention. The viewport cull and texture bounds include the
device-space outset for caps, joins and antialiasing. The retained
geometry bounds are shared, and the texture key includes the vector
effect.

The Linux fixture covers enlargement, reduction, skew, a stroke whose
centerline scrolls above the viewport, and a live switch from a scaling
stroke. The switch reused local bounds and rasterized a new texture even
though the old scaled texture covered its rectangle. The clipped stroke
reused its texture at scroll offset 65. The document comparison excludes
the live status bar and is pixel-exact. The first two test runs exposed
an incorrect expected texture width and a comparison that included the
live RAM readout. The complete Linux GG window suite then passed.

The Linux executable SHA-256 was
`587aaa1acdf1a8f94d88476ac8a6622c6afa33835ad08626c267263dd3a4e749`.
It used V `5a39a4d` and single-unit Clang `-O0`. The fixture SHA-256 was
`fd1760541fc6c51b3c1848e24c863aff3fd43ddf98305f9841a5135087085a25`.
The benchmark used Mesa software OpenGL under Xvfb, a fresh process
with private profile and cache for each run, an 800 × 712 window, one
second of settling, and 32 synthetic 42-pixel wheel steps. OS caches
remained available. Input hashes, scroll positions and paint-command
counts matched. One-minute load ranged from 0.36 to 0.46 on four virtual
CPUs. The final window suite, benchmark, and their memory guards exited zero.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 3.680 / 1.704 | 5.545 / 5.736 | 6.391 / 7.670 |
| 2 | 3.863 / 1.579 | 6.200 / 3.682 | 6.604 / 3.775 |

Texture reuse reduced the medians by 53.7% and 59.1%. The first pair's
p95 and maximum rose. Separate diagnostics recorded 93 texture and
bounds hits over the final 31 moving callbacks and 93 rasterizations
with caching disabled. These timings cover synthetic software OpenGL
replay. The Windows OpenGL source check passed. Windows window and pixel
verification remains pending.

## Solid SVG strokes on OpenGL

The opt-in `VOX_GG_SVG=1` renderer passes solid, undashed SVG strokes
to `gg.canvas` in document paint order. It preserves curve segments,
multiple contours, transforms, caps, joins, and stroke opacity. A stroke
shares cached local geometry bounds with its fill and has a separate
texture key containing its width, cap, join, and miter limit. It uses the
existing frame limits of eight draws and one megapixel. This first slice
left dashed, non-scaling, gradient and pattern strokes on legacy replay.

The Linux window tests passed the existing fill, mutation, cropping and
GL 4.2 fallback checks. A six-stroke fixture verified cap and join
geometry, transformed curves, multiple contours, translucent blending,
and both fill/stroke orders. Changing a round cap to a butt cap rebuilt
the texture while reusing the geometry bounds. Cached and uncached
document rows matched before and after the edit, and at scroll offset 126.
The first window run paused when the host ran out of disk space, then
failed a test sample on the round join's antialiased fringe. The passing
run used RAM-backed scratch and checked a pixel farther outside the join.

The Linux executable SHA-256 was
`e0bf9f472f80ef3d8c190ebb938917500afaf9273de00ce7ed2bb58fd2f9a072`.
It used V `5a39a4d` and single-unit Clang `-O0`. The fixture SHA-256 was
`d760304658f81f4e28f0665645566626ed28b5dcce7d86f195bad583d12c1f5b`.
Mesa software OpenGL ran under Xvfb in an 800 × 712 window. Fresh
processes used private profiles and caches, with OS caches available,
one second of settling, and 32 synthetic 42-pixel scroll steps. The
scroll positions and paint-command counts matched. One-minute guest load
ranged from 0.65 to 0.80 on four virtual CPUs.

| Pair | Median callback uncached / cached, ms | p95, ms | Maximum, ms |
| ---: | ---: | ---: | ---: |
| 1 | 4.290 / 3.288 | 6.015 / 5.166 | 6.108 / 5.214 |
| 2 | 3.871 / 3.369 | 5.967 / 4.242 | 6.008 / 5.546 |

The median fell by 23.4% and 13.0% with caching. Separate diagnostics
confirmed 186 stroke texture and bounds hits over the final 31 moving
callbacks, compared with 186 rasterizations when caching was disabled.
The final browser tests, benchmark, capture checks, and memory guards exited
zero. These measurements cover synthetic replay on software OpenGL.
The Windows OpenGL source check passed with V `eae4fce`. Windows window
and pixel validation still need a runnable build.

## Reusing SVG textures at viewport edges

`VOX_GG_SVG=1 VOX_GG_SVG_VIEWPORT_REUSE=1` lets the OpenGL SVG renderer
sample part of a cached texture as a fill crosses the viewport edge. The
geometry, paint, linear transform and subpixel phase must agree, and the
texture must cover every visible texel. The draw keeps its clipped
destination rectangle and uses nearest sampling. Exact matches take
priority. A covering match charges the full texture to the one-megapixel
frame budget. New or expanding areas use normal rasterization when the
cache lacks the needed texels.

The Linux window test warms the SVG textures, scrolls through the top
edge, then moves a fixed SVG across the left edge. Captures compare the
reused and rerasterized pixels, including a rotated translucent path.
The scrolling fixture has 42 SVG rows at 84 CSS pixels each, with
60-pixel-high even-odd fills. Its SHA-256 is
`2185a43add049d63b05bf254cc747d06ceae7fab15b788a1f502cde0a59e25e9`.

An initial build computed texture coordinates for every draw. Its
executable SHA-256 was
`0e1930fdbea1f79e91ea5f79ed65c15692145a4871b4a8e41b09ca357a293bb8`.
The first two matched pairs and four repeat pairs gave these results.
Values within each cell are rerasterized / reused, in milliseconds.

| Cohort | Pair | Median callback | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Initial | 1 | 5.384 / 5.349 | 7.020 / 9.006 | 8.770 / 9.172 |
| Initial | 2 | 3.116 / 5.243 | 4.892 / 8.076 | 5.735 / 8.716 |
| Repeat | 1 | 3.370 / 3.295 | 5.723 / 5.245 | 5.882 / 5.392 |
| Repeat | 2 | 3.324 / 3.479 | 3.537 / 5.875 | 3.946 / 6.214 |
| Repeat | 3 | 3.394 / 5.452 | 5.592 / 6.856 | 6.004 / 9.008 |
| Repeat | 4 | 5.175 / 5.095 | 8.690 / 8.656 | 9.277 / 9.450 |

The timings varied substantially across both modes. Viewport reuse has
its own opt-in and computes adjusted texture coordinates on crop hits.

The final executable SHA-256 was
`9a4a688dc58ee18496490acb7492d0f8c510e41f7ba929d00925aba0491061f7`.
Both Linux executables used V `5a39a4d` and single-unit Clang `-O0`.
After a shared-volume link ran out of space, the Linux link and test
executables used the guest filesystem. The final window tests matched
the portable reference and GL 4.2 fallback, and the top- and left-edge
captures matched the rerasterized reference. The row fixture also matched
at scroll offset 126.

The measured runs used Mesa software OpenGL under Xvfb, fresh
processes with private profiles and caches, an 800 × 712 window, one
second of settling, and 32 synthetic 42-pixel scroll steps. OS caches
remained available. Scroll traces, command counts and input hashes
matched. Separate diagnostics measured 232 draws over the final 31
moving frames. Rasterizations fell from 46 to 31, with 15 crop hits.
The benchmark and 3 GiB guards exited zero. Final one-minute guest load
ranged from 1.44 to 1.69 on four virtual CPUs.

| Final pair | Median callback | p95 | Maximum |
| ---: | ---: | ---: | ---: |
| 1 | 5.419 / 4.979 | 7.704 / 8.225 | 9.828 / 8.507 |
| 2 | 3.030 / 5.501 | 6.250 / 6.528 | 7.574 / 8.543 |

The final pairs still gave mixed callback timing, so the separate opt-in
remains. The Windows OpenGL source check passed with V `eeee53a`. Available
scratch space limited Windows validation to that check.

## Reusing SVG path bounds

The OpenGL SVG texture cache stores the local bounds computed by the
portable path decoder. A byte-for-byte geometry match can reuse those
bounds through color changes, transforms, and integer scrolling. Replay
maps the bounds to the current device and intersects them with the current
viewport. A geometry miss decodes the path. A portable raster fallback
decodes it when the GPU lookup supplied only its bounds.

The Linux window tests matched the portable reference, including the
GL 4.2 fallback, and matched cached and uncached captures after live edits.
The diagnostics confirmed that an edited path missed the bounds cache
and that a paint-only edit reused the bounds while rebuilding its texture.
`VOX_DISABLE_GG_SVG_CACHE=bounds` forces a fresh bounds decode with texture
reuse enabled.

The Linux executable SHA-256 was
`a371fa1a4deecc8dcf4cac1bd845b5b4efa67edf5a950edefeb029ecc4e46812`.
It used V `5a39a4d`, with C emission and single-unit Clang `-O0`
run separately. The software OpenGL runs used Xvfb, fresh processes,
private profiles and caches, and a one-second settle in an 800 × 712
window. Each measured run delivered 32 synthetic 42-pixel wheel steps.
OS caches remained available, and one-minute guest load ranged from
0.48 to 1.68 on four virtual CPUs. Both variants used the texture cache.

The simple fixture was the three fixed SVG paths used in the earlier
cache test, SHA-256
`e975fd4989c2d95e18b9c2a3336b3940335b7057d770a2a3cf9a7ece0a71f13c`.
The arc fixture drew six fixed paths with 64–69 elliptical arcs each,
SHA-256
`e7a6a1e50c466843b6be7214cabd25bc4b0663281701ea3b2d0d2372f142b1b0`.
The two modes produced identical document rows on each fixture.
Separate diagnostics counted 93 and 186 texture and bounds hits during
the final 31 moving frames. Scroll traces, paint-command counts and input
hashes matched. The browser tests, benchmarks and 3 GiB guard exited zero.

| Fixture | Trial | Bounds | Median callback (ms) | p95 (ms) | Maximum (ms) |
| --- | ---: | --- | ---: | ---: | ---: |
| Simple | 1 | Decoded | 1.4795 | 1.662 | 3.591 |
| Simple | 2 | Retained | 1.4405 | 1.825 | 3.874 |
| Simple | 3 | Retained | 1.2485 | 3.149 | 3.470 |
| Simple | 4 | Decoded | 1.3555 | 1.614 | 3.541 |
| Arcs | 1 | Decoded | 1.4335 | 3.278 | 3.574 |
| Arcs | 2 | Retained | 1.3060 | 3.143 | 3.222 |
| Arcs | 3 | Retained | 1.3375 | 3.218 | 3.398 |
| Arcs | 4 | Decoded | 1.7555 | 1.931 | 4.385 |

Median callback time fell by 2.6–7.9% for the simple fixture and
8.9–23.8% for the arc fixture. Median allocated memory on the arc
fixture fell from 674–678 KiB to 614–615 KiB per callback. The p95
rose in three pairs. These timings cover synthetic software OpenGL
callbacks. The renderer remains opt-in.

The Windows OpenGL V check passed with `-os windows -arch amd64 -check`
and V `eeee53a`. Local disk space limited this change's Windows
validation to source checking.

## Reusing SVG textures when paint order changes

The OpenGL SVG cache matches textures by raster inputs across the whole
frame. A fill can change position in paint order or share a texture with an
identical fill. GG submits each draw in document order. The cache holds up
to eight images from the previous frame while recording up to eight current
draws. Each frame has a one-megapixel budget. Unused and transient images
retire after submission.

The Linux window test passed with cached and uncached GG, the portable
painter, and the GL 4.2 fallback. A live SVG edit changed geometry and
color, moved paths in paint order, and duplicated a translated path.
The cached capture matched the uncached capture exactly. The translated
path needed one rasterization across the edit and duplication.

The Linux executable SHA-256 was
`4ffae25b325e988786ab35392fad64ea7bb7e548818376c19abf12337081cbcc`.
It used V `5a39a4d` and single-unit Clang `-O0`. The first build was
killed with V and Clang resident together in the 6 GiB guest. Emitting
C and its flags first and running Clang separately succeeded.

The scrolling fixture had 42 SVG rows at 84 CSS pixels each, with
20-pixel-high even-odd fills of distinct widths and colors. Its SHA-256 was
`635d9d9aad04cda211d47d4d9ee113f65eb8e3cf000048ea900eb13df4e25d8b`.
Document rows captured at scroll offset 126 matched exactly across the
three modes. The separate diagnostic counted 195 cache hits in 210 draws
over 30 consecutive frame transitions. Of those hits, 90 had different
dimensions at the same draw position in the previous frame. Matching by
draw position could therefore have hit at most 105 times on that trace.

Two triplets used fresh processes, private profiles and caches, an 800 × 712
window, a one-second settle and 32 synthetic 42-pixel scroll steps under
Xvfb with Mesa software OpenGL. OS caches remained available. The scroll
positions, paint-command counts, fixture hash and executable hash agreed.
One-minute guest load was 1.28–1.51 on four virtual CPUs. The browser runs
and the 3 GiB guard exited zero.

| Trial | Renderer | Median callback (ms) | p95 (ms) | Maximum (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Portable | 2.823 | 5.373 | 5.450 |
| 2 | Uncached GG | 3.187 | 5.402 | 5.451 |
| 3 | Cached GG | 2.533 | 3.237 | 4.884 |
| 4 | Cached GG | 2.739 | 5.034 | 5.142 |
| 5 | Uncached GG | 3.385 | 5.579 | 6.575 |
| 6 | Portable | 2.695 | 4.742 | 5.566 |

Caching lowered median callback time by 19–21% versus uncached GG. Against
the portable painter, it was 10.3% faster in the first triplet and 1.6%
slower in the second. The renderer remains opt-in.

The Windows `--opengl --console` build linked an x86-64 PE executable with
V `eeee53a` and MinGW GCC 16.2.0 using `-pipe`. The build and 12 GiB
guard exited zero. The executable SHA-256 was
`983e0ce2477fefb3c29183cb6206906726a9346310a34b55ead2d1600efa949a`.
Windows rendering still needs runtime verification.

## Retaining windowed SVG textures

The first OpenGL SVG cache kept up to eight resolved textures from the
previous frame, with the existing one-megapixel per-frame budget. A slot
followed replay order and owned a copy of up to 128 path segments. Reuse checks
the exact path bytes, fill rule, RGBA paint, texture dimensions
and the matrix relative to the texture. Integer movement can reuse the
texture. A changed key replaces the image, and unused slots retire after
frame submission. Set `VOX_DISABLE_GG_SVG_CACHE=1` for uncached replay.

The [Linux window test](../tools/test_linux_browser.py) found identical
document pixels with cached GG, uncached GG, the portable painter and the
GL 4.2 fallback. It also moved an even-odd hole, changed a translucent fill
color and translated a path during live replay. Cached and uncached captures
both showed the updated pixels. All six browser runs and the 3 GiB guard
exited zero.

The Linux executable SHA-256 was
`04ef205528bf2072647984010dc53069de04a0670d33d35fac45d6325496e381`.
The build used single-unit Clang `-O0` and V revision `5a39a4d`.
Three rotating triplets used that executable and the same fixed-SVG fixture
recorded below. Fresh browser processes used private profiles and caches,
Mesa software OpenGL under Xvfb, an 800 × 712 window, one second of settling,
and 32 synthetic 42-pixel wheel steps. The fixture and executable hashes,
scroll positions and paint-command counts matched throughout. OS caches
remained available. A separate diagnostic run recorded all three texture
hits throughout the measured scroll window. All ten browser runs and the
3 GiB guard exited zero. One-minute guest load ranged from 0.79 to 2.97 on
four virtual CPUs.

| Trial | Renderer | Median callback (ms) | p95 (ms) | Maximum (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Portable | 4.802 | 41.371 | 70.535 |
| 2 | Uncached GG | 6.292 | 13.618 | 14.407 |
| 3 | Cached GG | 2.261 | 5.223 | 5.372 |
| 4 | Uncached GG | 6.439 | 9.801 | 11.341 |
| 5 | Cached GG | 2.321 | 10.482 | 26.782 |
| 6 | Portable | 4.503 | 10.472 | 12.735 |
| 7 | Cached GG | 2.249 | 5.376 | 8.396 |
| 8 | Portable | 4.705 | 7.825 | 8.112 |
| 9 | Uncached GG | 6.840 | 16.508 | 16.849 |

In matched triplets, the cache lowered median callback time by 64–67%
versus uncached GG and by 48–53% versus the portable painter. Trial 5 showed
a 26.8 ms maximum and a higher p95 than the two controls in its triplet.
The measurements cover a warmed, software-rendered fixture. The OpenGL
renderer remains opt-in pending hardware and production measurements.

The Windows `--opengl --console` build linked an x86-64 PE executable
with V `eeee53a` and MinGW GCC 16.2.0. It used `-pipe` on the retry
after the assembly scratch file exhausted local disk space. The 12 GiB
guard exited zero with a peak RSS of 10,462,429,184 bytes. The executable
SHA-256 was
`f4dba55bcee427c5487a30fac7d3211c09594717193e368420d2e93d6fb5e92e`.
Windows rendering still needs runtime verification.

## Windowed SVG replay on OpenGL

`VOX_GG_SVG=1` sends eligible solid SVG fills through `gg.canvas` on Linux
and in a Windows `--opengl` build. Canvas borrows the window's Sokol context.
GG samples the resolved texture in document paint order with premultiplied
alpha. The initial renderer retired each texture after submission. Linux
uses the portable painter when the current context lacks OpenGL 4.3 or
shader storage buffers. The launch switch is opt-in.

On ARM64 Linux with Mesa software OpenGL under Xvfb,
`python3 tools/test_linux_browser.py BINARY --gg-svg` verified the three
fills on the [SVG fixture](../Tests/Browser/Native/svg-gg-path-fill.html).
Its document pixels matched the portable path exactly, including the
even-odd hole, translucent overlap, orientation, and translated fill.
Forcing GL 4.2 exercised the portable fallback and reproduced the same pixels.
An earlier build requested GL 4.3 at window creation and failed on GL 4.2.
The final Linux build checks capabilities after the normal window opens.
The macOS shared path and non-scaling stroke suites also passed.

The Windows `--opengl --console` build compiled and linked an x86-64 PE
executable with MinGW GCC 16.2.0 and V revision `eeee53a`.
Its SHA-256 was
`07b50265fcd123855187eb5e688402aeceb90f71c9d751844d0021fa32aa6dad`.
The 12 GiB build guard exited zero with a peak sampled RSS of
9,838,542,848 bytes. Windows window and pixel checks await a runnable VM.

The Linux executable SHA-256 was
`4a684ddae49945472fc8e5128b21a8afb44238acf03d98202d110bfab03ac0bb`.
It used single-unit Clang `-O0` and V revision `5a39a4d`. Two alternating
pairs used the same executable, fresh profiles and caches, and 32 synthetic
42-pixel wheel steps in an 800 × 712 window after one second of settling.
The local fixture added `body{min-height:4096px}` and
`svg{position:fixed;top:32px}` so the same paths were visible throughout.
Its SHA-256 was
`e975fd4989c2d95e18b9c2a3336b3940335b7057d770a2a3cf9a7ece0a71f13c`.
OS caches remained available. A separate diagnostic recorded all three
GPU paths throughout scrolling. All browser exits and the 3 GiB guard
exit were zero. Scroll positions and paint-command counts matched in both
pairs. One-minute load was 0.53–0.97 on four guest CPUs.

| Trial | Renderer | Median callback (ms) | p95 (ms) | Maximum (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Portable | 4.142 | 7.437 | 7.555 |
| 2 | GG | 6.625 | 19.221 | 20.588 |
| 3 | Portable | 4.336 | 8.038 | 9.723 |
| 4 | GG | 6.551 | 16.751 | 21.796 |

Median callback time rose by 51–60% on this software-rendered workload.
These are synthetic callback timings. Hardware GPU and production scroll
performance remain unverified.

## Shared GPU SVG path replay

`ggshape` uses one SVG descriptor decoder and `gg.canvas` draw implementation
on Metal and OpenGL. A caller can supply a GPU context and rasterize one path
into premultiplied BGRA8. The macOS browser still uses its persistent,
precompiled Metal context and the same surface, backdrop upload, draw, and
readback sequence. Its batched SVG images use the shared descriptor replay
inside the existing macOS batch wrapper. Linux browser pages still use the
portable raster and Sokol presentation path.

The same [SVG pixel test](../ggshape/path_canvas_test.v) passed against
Apple Silicon Metal and ARM64 Linux offscreen EGL with Mesa software OpenGL.
It checks the entire translated solid fill, the even-odd hole, BGRA order and
row padding, then samples a multisampled backdrop and a linear gradient. The
test also checks that an unsupported gradient leaves the destination intact.
The macOS non-scaling stroke, SVG batch, mask path, and SVG shadow pixel
references passed unchanged. These checks ran with the C backend and
`-gc none` under 3 GiB memory guards, with compiler revisions `eeee53a`
on macOS and `5a39a4d` on Linux. Browser-level timing remains to be measured.

## Shared CSS background replay

The portable painter and the macOS gradient fallback use the same V raster
replay. The native macOS gradient path runs first for its supported draws.
For an axis-aligned linear gradient with full rectangular coverage, the
portable painter samples one row or column and presents it with a nearest-filtered
Sokol texture. Text masks, non-axis-aligned gradients and tiled gradients use
the full raster when the ramp cannot represent their coverage.

On Linux ARM64, the X11 regression exercised both ramp directions and compared
all fixture content pixel for pixel with `VOX_DISABLE_PORTABLE_GRADIENT_RAMP=1`.
The pixels matched. The Linux browser smoke suite and live vlang.io capture
passed. The macOS and Windows V type checks also passed using their build flags.

Two alternating pairs used [the scrolling gradient fixture](../Tests/Browser/Native/scroll-gradient-ramps.html)
with software OpenGL in a four-vCPU VM. Each fresh launch delivered 80
synthetic integer scroll steps at a requested 1024 × 600 document viewport.
The executable SHA-256 was
`e381e9ec1de2f89ec57205c36cd2f9485467a7d531c38b6b9a5aa9524ed49bca`.
This was a single-unit Clang `-O0` diagnostic build. The initial `-O1` compiler
process was killed in the 6 GiB VM. Replay times below end at callback completion.

| Trial | Replay variant | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Full raster | 233.936 | 382.445 | 394.999 |
| 2 | Ramp | 2.422 | 4.962 | 5.500 |
| 3 | Full raster | 246.396 | 341.972 | 344.777 |
| 4 | Ramp | 1.876 | 4.005 | 4.161 |

Scroll positions and command counts agreed across all four trials. The guest
one-minute load averages were 1.15, 1.36, 1.49 and 1.57. The benchmark and
3 GiB guard exited zero with a peak sampled RSS of 509,161,472 bytes.

The `-O1` retry in the 10 GiB VM completed with a peak sampled process-tree
RSS of 9,984,811,008 bytes under the 12 GiB build guard. The executable
SHA-256 was `0a7603ca435b9ad5fcb0e16b3e99a046d34f9195854511e868633f9338d0ac41`.
The browser suite again passed its exact ramp checks. The same fixture and
four-trial protocol produced the following synthetic callback replay results.

| Trial | Replay variant | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Full raster | 68.384 | 75.983 | 96.934 |
| 2 | Ramp | 0.741 | 0.963 | 2.652 |
| 3 | Full raster | 61.133 | 65.499 | 84.492 |
| 4 | Ramp | 0.710 | 2.127 | 2.351 |

The scroll traces agreed. The guest one-minute load averages were 1.11, 1.02,
1.02 and 1.02. The build, browser suite, cohort and their guards exited zero.
The cohort guard sampled a peak of 496,852,992 bytes.

The subsequent macOS single-unit `-prod` bundle with verified source HEAD
`3d7b08948920d7f685be88f8ad70f783b256821d` was tested in fresh PIDs 8217 and
8340. Its executable SHA-256 was
`23ba3183f6c6446597823e434ba9016fc6949940758a6bcbcba91991b782b3bb` and its
AVIF library was `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
Both trials used the local scrolling gradient fixture with scripting disabled,
fresh profiles and caches, a 1 second settle, and a 1024 × 600 viewport at
backing scale 2. The native probe delivered 120 precise wheel inputs at 60 Hz
with a 4-pixel delta and a reversal after 60 inputs. These are changed frame
installations after the outer view paint, with nested revisions coalesced.
The fixture SHA-256 was
`d3a835484b1c637d5b1cd34b757e3feba4463b59dff370140a92667f2eb257c5`.

| Trial | Scroll fps | Median interval (ms) | p95 (ms) | Max (ms) | Over 16.67 ms | Input / scroll changes | First / last gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 59.47 | 16.658 | 17.817 | 29.058 | 47.5% | 120 / 118 | 24.378 / 14.904 |
| 2 | 59.49 | 16.693 | 18.199 | 30.633 | 54.2% | 120 / 118 | 25.331 / 13.984 |

Both browser processes and the guard exited zero. The 18-CPU host one-minute
load averages before these trials were 5.75 and 5.69. The earlier unpublished
bundle controls ran under different host load, so these results describe the
published bundle's cadence on this fixture. The document screenshots at 800 × 600
matched the gradient-text and radial-gradient references exactly. The gradient
backdrop comparison differed by one blue-channel level at one pixel.

## Solid SVG opacity groups

The portable GG painter rasterizes a run of solid SVG fills inside one normal
opacity scope into a bounded premultiplied surface. It uploads the resolved
color once and applies group alpha during the GG image draw. This preserves
source-over ordering, fill opacity, and the path's even-odd or winding rule.
The native Chromium SVG adapter uses the same eligibility check for a normal
opacity scope and retains its accelerated replay. The portable group pass
accepts up to 128 paths with a common rectangular clip and a surface of up
to 4,194,304 pixels. A sparse scope can also fall back when its bounding image
would add more than 16,384 pixels beyond its individual path textures.
Nested effects, non-solid paints, strokes, and complex clips use the existing replay.

The Linux browser smoke suite checks that the grouped path ran and verifies
overlap, a path hole, fill opacity, and the sparse fallback on the
[SVG fixture](../Tests/Browser/Native/svg-opacity-groups.html). A four-trial
Linux ARM64 software OpenGL cohort compared the default group pass with
`VOX_DISABLE_PORTABLE_SVG_OPACITY=1` on the same executable. Each trial used a
fresh browser process and 80 synthetic 42-pixel scroll steps at a requested
1024 × 600 viewport, with a 1 second settle. Scroll positions and retained
command counts agreed. The switch changes overlap pixels to the earlier
flattened-alpha result. The timings measure replay through synthetic callback
completion.

The single-unit `-O0` diagnostic executable SHA-256 was
`7cf42f0fb16ae4ab55afb27984fb184646117490aaeb722a904c74e1b03983f1`.
This first cohort used the fixture before addition of the sparse-path check
(`4da62c1472359a4f179deb11fbd2e8330b0903b5e0dbb4e9927f434ee247d89e`).

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Per path | 25.069 | 27.360 | 27.803 |
| 2 | Grouped | 12.853 | 14.855 | 15.392 |
| 3 | Per path | 25.372 | 27.433 | 28.650 |
| 4 | Grouped | 13.718 | 15.596 | 17.296 |

The four-vCPU guest one-minute load averages were 1.44, 1.32, 1.22 and 1.12.
The build, suite and cohort exited zero under their guards. The cohort guard
sampled a peak of 462,340,096 bytes.

The final single-unit `-O1` executable SHA-256 was
`fe2d72410446d85e866ef0256fee9f5ab3ade5132b5d4d9a6334a837c14a1cb5`.
The fixture SHA-256 was
`bf84c48d0a59c14477967fcea87e577442b563c6e10a80aec541e4777d8de6d9`.
Each trial had a fresh profile and cache. The four guest one-minute load
averages were 1.51, 1.39, 1.28 and 1.18.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Per path | 4.789 | 6.644 | 7.540 |
| 2 | Grouped | 2.842 | 4.522 | 5.349 |
| 3 | Per path | 5.004 | 6.875 | 7.283 |
| 4 | Grouped | 2.918 | 4.798 | 5.076 |

The 80-frame scroll and retained command traces matched across all four trials.
The build, Linux browser suite, and benchmark exited zero with sampled process
tree peaks of 9,959,768,064, 867,598,336 and 452,648,960 bytes, respectively.
The macOS production-mode V check and Windows D3D11 V check also passed.
The final Linux executable also loaded live vlang.io in a fresh 1280 × 800
X11 window. The header, gradient version text, icons, and compilation card
rendered. The compilation video needs the Linux media implementation.
The published macOS single-unit `-prod` executable
`9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301` carried
the verified `eaca5f62c` opacity replay source. Its native renderer passed
the opacity color, overlap, hole and fill-opacity pixel samples in fresh PID
96263. Portable macOS runtime validation and the full compositor remain open.

## Solid SVG clip groups

The portable GG painter applies SVG `<clipPath>` geometry to complete groups
of solid fills. The clip and opacity passes share the bounded V raster replay.
An integer-aligned rectangular clip limits the raster bounds directly.
Fractional rectangles and curved or compound geometry produce a coverage
mask. The painter resolves the source paths in order, applies the coverage
once, and uploads one texture. The existing limits for path count, surface
size, and sparse ink apply. Clips may have up to 64 components. SVG `<mask>`
content and complex group contents still use their existing replay paths.

The [browser fixture](../Tests/Browser/Native/svg-clip-groups.html) checks
visible overlap, rectangular cropping, curved coverage, disjoint components,
even-odd holes, a fractional edge, and a following unclipped sibling. It pins
the rectangular crop and coverage paths with `VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS=1`.
The initial Linux `-O0` capture and the published macOS native renderer agreed
at all ten sampled solid pixels. The fractional sample was `(127, 212, 127)`
on Linux and `(128, 213, 128)` on macOS.

The macOS baseline used the published single-unit `-prod` executable
`23ba3183f6c6446597823e434ba9016fc6949940758a6bcbcba91991b782b3bb`, with AVIF
library `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The local fixture ran in fresh PIDs 68794 and 68952 at 1024 × 600, 2× backing
scale, fresh profiles and caches, scripting disabled, and one second settle.
Each run used 120 precise wheel inputs at a requested 60 Hz, moving four
pixels per input and reversing after 60. The endpoint was changed Cocoa
frame installations after outer view paint.

| Trial | Scroll fps | Median interval (ms) | p95 (ms) | Max (ms) | Over 16.67 ms | Input / scroll changes | First / last gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 40.35 | 23.851 | 28.495 | 30.624 | 100% | 120 / 92 | 56.107 / 18.643 |
| 2 | 40.99 | 23.527 | 27.927 | 30.002 | 100% | 120 / 90 | 54.493 / 18.367 |

Both browser exits and the guard exit were zero. The 18-CPU host's starting
one-minute load averages were 9.93 and 9.70 while other builds were running.
These are baseline measurements from the existing Cocoa compositor.

The optimized Linux ARM64 single-unit `-O1` executable SHA-256 was
`4b93e4c7848a396db38ead5022aaae012ddbe2fce8235ab4a3606e2970396020`.
The local fixture SHA-256 was
`1d8db436b21f32f96dc5496db99be7867e73508823d056f5dc8939ace2c06a31`.
A separate diagnostic showed both the rectangular crop and coverage pass
executing during scroll. The cohort alternated the default with
`VOX_DISABLE_PORTABLE_SVG_CLIP=1`, which restores the earlier bounding-box
clip. Each trial used software OpenGL, a fresh process, profile and cache,
and 80 synthetic 42-pixel scroll callbacks at a requested 1024 × 600 viewport
after a one-second settle. Scroll positions and retained command counts
matched. Timings end at callback replay completion.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Bounds only | 20.720 | 21.490 | 22.023 |
| 2 | Clip geometry | 2.258 | 4.793 | 5.500 |
| 3 | Bounds only | 21.253 | 23.460 | 26.127 |
| 4 | Clip geometry | 2.313 | 4.836 | 5.229 |

The four-vCPU guest's starting one-minute load averages were 1.31, 1.20,
1.43 and 1.31. The build, Linux browser suite and cohort exited zero under
the memory guards, with respective peaks of 9,644,331,008, 939,761,664 and
483,737,600 bytes. The suite included the existing opacity and gradient
pixel checks. A disabled-path capture reproduced the curved leak and filled
hole. Live vlang.io rendered its header, gradient version text, icons and
compilation card in the optimized Linux build. The Linux media path still
needs support for its compilation video. The macOS production-mode and
Windows D3D11 V type checks also passed. The shared macOS runtime build and
full compositor cutover remain open.

The next published macOS bundle, pinned above, passed the native clip samples
in PID 96347. Its two precise-wheel trials used the same clip fixture and
schedule as the baseline, with an unchanged AVIF library. This bundle includes
the earlier opacity replay and intervening changes. The portable clip path
had yet to reach the production bundle.

| PID | Scroll fps | Median interval (ms) | p95 (ms) | Max (ms) | Over 16.67 ms | Input / scroll changes | First / last gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 99887 | 38.51 | 24.590 | 29.010 | 29.721 | 100% | 120 / 81 | 53.475 / 20.027 |
| 104 | 39.26 | 24.372 | 28.805 | 52.494 | 100% | 120 / 84 | 52.767 / 18.454 |

Both browser exits and the guard exit were zero. These two runs began at
one-minute host load averages of 7.38 and 7.67. The earlier cohort used a
different build and host load, so the two sets describe observed native
cadence. The fixture remains below 60 scroll-changing installations per second.

## Nested SVG image replay

Replaced SVG images and CSS SVG backgrounds now use the portable clip and
opacity passes for eligible solid-fill groups. The player projects one
validated scope at a time and intersects its raster bounds with the embedding
viewport. Ordinary leaves replay individually and intersect their own
scissor with the same viewport when they carry a clip. Group replay applies
to fully opaque embeddings. Translucent embeddings use ordinary replay.

The [nested fixture](../Tests/Browser/Native/nested-svg-groups.html) checks
clip interiors, group overlap, pixels outside each embedding rectangle, and
a translated and scaled image. It loads a separate SVG resource through both
an image element and a CSS background. The published native macOS capture
in PID 96408 matched the previous bundle exactly over all 614,400 document
pixels. Linux and macOS agreed at the sampled solid pixels and differed by
one level in red and green at the two sampled 50% blue overlap pixels.

The Linux ARM64 optimized single-unit `-O1` executable was
`2111fdcd31e701b8c90884550bd1634d8d185fde66dfe837d0f0612daa518233`.
The HTML and SVG input SHA-256 values were
`ae9a94a4a14acbf5f27378a6730541cf16b37cf2f8ca4f2e9b5a2b4f763c384f` and
`e447d42766910bc2ceef13fa92a672e9ccff8e9e6392372da16a7e56d84e645e`.
A separate diagnostic observed both passes after scrolling began. The cohort
alternated the default with `VOX_DISABLE_PORTABLE_SVG_CLIP=1` and
`VOX_DISABLE_PORTABLE_SVG_OPACITY=1` on the same executable. Each software
OpenGL trial used a fresh profile, cache and process, a one-second settle,
and 80 synthetic 42-pixel scroll callbacks at a requested 1024 × 600 viewport.
Timings end at callback replay completion.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Per path | 37.160 | 40.162 | 41.285 |
| 2 | Grouped | 2.159 | 4.598 | 5.247 |
| 3 | Per path | 36.474 | 38.963 | 41.417 |
| 4 | Grouped | 2.166 | 4.609 | 4.832 |

Scroll positions and retained command counts matched across the cohort.
The four-vCPU guest's starting one-minute load averages were 0.91, 0.84,
1.65 and 1.55. The guarded build, suite and benchmark exited zero with
process-tree peaks of 10,023,243,776, 865,431,552 and 474,693,632 bytes.
The disabled-path capture reproduced leaking clip corners and incorrect
overlap alpha on both embeddings. Live vlang.io rendered its header,
version gradient, icons and compilation card in the optimized Linux build.
The compilation video still requires a Linux media path. macOS production-mode
and Windows D3D11 V type checks passed. The next shared macOS build is queued.
Running the portable replay on macOS remains open.

## SVG alpha and luminance masks

The portable GG player applies SVG content masks to eligible groups of
solid fills, including in nested SVG images. It resolves the solid mask
operations in paint order and uses the resulting alpha or premultiplied
luminance as coverage for a single group texture. The mask region bounds
both rasters, and fractional region edges contribute coverage once. This
pass takes up to 64 solid mask fills in an axis-aligned rectangular region.
Complex mask resources retain their existing replay.

The [mask fixture](../Tests/Browser/Native/svg-content-masks.html) checks
the coverage from black in alpha and luminance modes, even-odd holes,
partial opacity, overlapping color fills, and the mask region. It also
checks a fractional translated mask in an embedded SVG. Thirteen sampled
pixels matched the native macOS capture from executable
`9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301` in fresh
PID 40042. The translated edge sample was `(127, 127, 255)` on Linux at
1× backing scale and `(191, 191, 255)` in the logical-pixel macOS capture.

The optimized Linux ARM64 single-unit `-O1` executable SHA-256 was
`3c969cb83555495aca50dfc7c520a1a0481881fa6b83e7b277a151342f0445c1`.
The fixture SHA-256 was
`6dc176903d66f637659b97484bc34a89ee0357c828c182ff9fefca52b8f3f966`.
A separate diagnostic recorded 40 applications of each mask mode during
scroll replay after the first callback. The cohort alternated the default
with `VOX_DISABLE_PORTABLE_SVG_MASK=1`. Each software OpenGL trial ran a
fresh process with a fresh profile and cache, one second of settle, and 80
synthetic 42-pixel scroll callbacks at a requested 1024 × 600 viewport.
Timings end at callback replay completion.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Per path | 15.577 | 16.736 | 19.508 |
| 2 | Masked group | 3.141 | 5.659 | 5.759 |
| 3 | Per path | 14.572 | 15.073 | 15.780 |
| 4 | Masked group | 3.005 | 5.497 | 5.892 |

Scroll positions and retained command counts matched across all four trials.
The guest one-minute load averages were 0.73, 0.73, 0.91 and 1.88. The
guarded build, Linux browser suite and benchmark exited zero with sampled
process-tree peaks of 10,053,210,112, 869,707,776 and 473,800,704 bytes.
A disabled-path capture reproduced the filled alpha hole and visible black
luminance region. The optimized Linux browser also rendered the header,
version gradient, icons and compilation card on live vlang.io. The macOS
production-mode and Windows D3D11 type checks passed. The shared runtime
build and macOS portable renderer cutover remain open.

## SVG mask opacity groups

The portable GG replay now handles up to four nested opacity groups inside
an eligible alpha or luminance mask. Each group renders into a bounded
premultiplied surface. The existing CPU image compositor applies the
group's opacity once when restoring it over its parent. Sibling groups
reuse a cleared surface at the same depth.

The [browser fixture](../Tests/Browser/Native/svg-mask-opacity.html) checks
path overlap, nested half-opacity groups, surface reuse across siblings,
and luminance after compositing over an opaque mask background. Ten sampled
pixels agreed within one level per channel with the native macOS capture
from executable `9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301`
in fresh PID 73912. For example, the 50% blue overlap was `(128, 128, 255)`
on Linux and `(127, 127, 255)` on macOS.

The Linux ARM64 single-unit `-O1` executable SHA-256 was
`d9f0f93b94d00d8c28effb665bd89fc0206d35da7275caba738d565fad1445cd`.
The fixture SHA-256 was
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51`.
A separate diagnostic recorded 41 applications of each grouped mask mode
after the first scroll callback. Each trial used software OpenGL, a fresh
profile, cache and process, one second of settle, and 80 synthetic 42-pixel
scroll callbacks at a requested 1024 × 600 viewport. The cohort alternated
the default with `VOX_DISABLE_PORTABLE_SVG_MASK=1`. Timings end at callback
replay completion.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Per path | 16.352 | 17.944 | 18.870 |
| 2 | Masked group | 7.077 | 10.196 | 10.343 |
| 3 | Per path | 14.554 | 17.398 | 18.491 |
| 4 | Masked group | 7.299 | 9.959 | 10.917 |

Scroll positions and retained command counts matched across all four
trials. The guest one-minute load averages were 0.93, 1.10, 1.01 and 1.01.
The 6 GiB guest used temporary swap for the build. The guarded build,
Linux browser suite and cohort exited zero with sampled process-tree RSS
peaks of 5,988,016,128, 877,191,168 and 470,147,072 bytes. Prior clip,
opacity and flat-mask fixtures passed in the suite. Disabling mask replay
reproduced fully opaque coverage in the half-opacity and nested scopes.
The macOS production-mode and Windows D3D11 type checks also passed.

## SVG gradient masks

Portable GG replay uses the CPU gradient shader for padded linear and
radial fills in SVG content masks. The gradient transform maps shader
coordinates into the path's local space while the path keeps its existing
geometry. Alpha masks use stop alpha and fill opacity. Luminance masks
resolve the sRGB colors in a premultiplied surface before applying the
luminance weights. Other spread modes, unsupported radial geometry and
luminance gradients in linear RGB use the existing replay.

The [gradient mask fixture](../Tests/Browser/Native/svg-gradient-masks.html)
checks a translated and scaled alpha ramp, an elliptical luminance mask,
and an object-bounding-box gradient inside an embedded SVG. Thirteen
samples from the optimized Linux capture agreed with the macOS native
capture within one level per channel. Eleven matched exactly. The native
comparison used fresh PID 13320 from single-unit `-prod` receipt
`20261118-035602-2025fd74`, with executable SHA-256
`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`
and AVIF SHA-256
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
That bundle also passed the nested SVG and solid-mask samples in fresh PIDs
18048 and 18123. The macOS comparison uses Cocoa rendering.

The Linux ARM64 single-unit Clang `-O1` executable SHA-256 was
`cc506b86027f251a4191e852de3cd05e183cbbb2be1f974a8af8818547309506`.
The fixture SHA-256 was
`358aaffab9b6a968c0c450a8466d13761813fff26d3bf507791f59d7ac200d4c`.
A separate diagnostic confirmed both gradient mask modes during scroll
replay. The four trials alternated `VOX_DISABLE_PORTABLE_SVG_MASK=1`
with the enabled path on the same binary. Each used software OpenGL
and a fresh process, profile and cache, one second of settle, and 80
synthetic 42-pixel steps at a requested 1024 × 600 viewport. The scroll
and command traces matched. The disabled path painted four sampled
points fully blue where the masks should make them transparent.
Timings measure replay within the synthetic callbacks.

| Trial | Replay | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Disabled | 21.783 | 23.402 | 24.774 |
| 2 | Gradient mask | 5.856 | 9.597 | 10.075 |
| 3 | Disabled | 19.603 | 22.658 | 23.706 |
| 4 | Gradient mask | 4.301 | 6.999 | 7.068 |

Starting one-minute load averages in the four-vCPU guest were 2.37, 2.26,
2.08 and 2.07. The build, full Linux browser suite and cohort exited zero
under their guards, with sampled process-tree RSS peaks of 5,974,519,808,
899,305,472 and 477,368,320 bytes. The CPU gradient unit tests and the
macOS production-mode and Windows D3D11 V checks passed. The pinned CPU
raster differential suite passed with 10,000 exact gradient draws.

### Shared gradient mask raster on macOS

`VOX_SHARED_SVG_MASK_RASTER=1` uses the V mask rasterizer on macOS for
eligible gradient fills. The rasterizer writes only the aligned mask
rectangle in the bitmap that enters the existing native cache. It uses
the bitmap's row stride and leaves the transparent padding intact. Native
composition continues to use the cached alpha or luminance image. Other
resources and fractional mask rectangles use the existing Quartz replay.

The macOS pixel check compares both settings in new browser processes
and verifies that the shared path ran for both alpha and luminance.
Across the 1024 × 600 document, the largest difference against Quartz
was two channel levels. The Linux browser suite, Windows D3D11 type
check, native SVG mask conversion and layer checks all passed.

The same macOS single-C executable, compiled with V `-prod` and Clang
`-O1`, ran both paths. Its SHA-256 was
`06fa95ced9400bbc889a099c3e9643d14d1aff8ee81250dfa18e94a627d52f8b`
and the AVIF library SHA-256 was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The build, captures and focus checks used the same fixture digest as the
Linux trials above. The build peaked at 12,438,732,800 bytes under the
12 GiB process-tree guard. The two pixel capture PIDs were 94900 and 94917.

The initial private builds exited 139 before scroll input in the STB
bookmark icon decoder. The non-`-prod` build reproduced that exit in both
mask modes. With the same private `-prod` timing build, a fresh profile
with an empty hidden bookmark bar allowed the precise-wheel runs to start.
All trials used that profile seed, a fresh cache, disabled scripts,
no external resources and a one-second settle after the fixture title
appeared. The observed viewport was 1024 × 600 at 2× backing scale.
A separate diagnostic recorded 267 alpha and 257 luminance shared
mask rasterizations during the input window.

The trial used 120 precise wheel inputs at a requested 60 Hz, with a
four-pixel delta and one reversal after 60 inputs. The endpoint was
changed native frame installation after the outer view paint. Both
variants exceeded the 16.67 ms deadline on every measured scroll interval.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 95630 | Quartz | 41.76 | 22.764 | 26.339 | 47.476 | 54.02 | 120 / 92 | 52.645 / 20.213 |
| 95741 | Shared | 27.89 | 34.473 | 38.127 | 68.844 | 55.32 | 120 / 60 | 78.019 / 0.088 |
| 95891 | Quartz | 42.89 | 22.282 | 26.031 | 27.966 | 54.29 | 120 / 94 | 54.111 / 17.040 |
| 95985 | Shared | 27.66 | 34.271 | 38.500 | 69.497 | 54.86 | 120 / 60 | 75.839 / 17.467 |

The 18-CPU host's starting one-minute loads were 6.83, 6.84, 6.45 and
6.42. All browser and guard exits were zero and the cohort peaked at
402,685,952 sampled RSS bytes. The shared path remains opt-in because
of the measured scroll regression.

### Reusing translated gradient masks

The shared macOS raster path retains up to sixteen finished mask images
of at most 512 KiB each. An integer device-pixel translation can reuse
the image at its new placement. The key includes the retained mask
resource, backing scale, bitmap dimensions, clipped area and each path's
matrix relative to the mask bitmap. The placement cache retains the same
image object. `VOX_DISABLE_SHARED_SVG_MASK_CACHE=1` isolates the earlier
shared replay for comparisons.

Four fresh captures ran the macOS pixel check. The cached and uncached
document images after a 96-pixel scroll were byte-for-byte equal after
decoding, and the capture observed reuse in both mask modes. At the top
of the fixture, the shared raster still agreed with Quartz to two levels
per channel over the full document. The Linux browser suite and Windows
D3D11 type check passed. Standalone layout test compilation reached the
12 GiB guard.

Both passes through the timing cohort used the same single-C V `-prod`,
Clang `-O1` build, SHA-256
`4f3c80fb7fa4fd31cbec44e78a04de057e95c4400ac87fab293dda998a4807a1`.
The fixture and AVIF digests were unchanged from the prior cohort. The
probe repeated the 120-input precise-wheel schedule at 1024 × 600 and
2× scale. Each launch used a fresh cache and the same private profile
seed with a hidden bookmark bar, no external resources, disabled scripts,
and one second of settle after the title appeared. The endpoint was
changed native frame installation after the outer view paint.
A separate diagnostic counted 574 reused images and 231 rasterizations
during the input window.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 24894 | Quartz | 43.89 | 21.634 | 26.385 | 27.662 | 56.16 | 120 / 93 | 54.243 / 17.280 |
| 24970 | Shared, uncached | 35.77 | 26.565 | 31.054 | 53.245 | 59.11 | 120 / 72 | 60.695 / 17.628 |
| 25064 | Shared, cached | 42.92 | 22.249 | 26.507 | 29.159 | 55.52 | 120 / 92 | 52.185 / 19.879 |
| 25172 | Quartz | 39.15 | 24.789 | 29.103 | 29.957 | 54.80 | 120 / 85 | 53.806 / 17.360 |
| 25459 | Shared, uncached | 34.09 | 28.304 | 32.572 | 56.677 | 58.80 | 120 / 69 | 65.182 / 0.107 |
| 25645 | Shared, cached | 44.45 | 21.696 | 25.936 | 27.384 | 54.53 | 120 / 97 | 52.580 / 17.302 |

The six trials exceeded 16.67 ms on every measured scroll interval.
Starting one-minute loads on the 18-CPU host were 8.29, 7.78, 7.80, 7.50,
7.38 and 7.35. All browser and guard exits were zero. Sampled process
tree RSS peaked at 8,038,252,544 bytes during the macOS build and
407,552,000 bytes in the scroll cohort. Caching improved both shared
raster trials. The comparison with Quartz was mixed, and the shared
path remains opt-in.

### Allocating the mask bitmap after cache lookup

The macOS shared path determines the device bounds and checks the
translated-mask cache before it opens a Quartz bitmap. A cache hit
publishes the retained image directly for the new placement. A miss
opens a bitmap for the V rasterizer. Masks that decline shared replay
use the existing Quartz clip and draw operations. The benchmark switch
`VOX_EAGER_SHARED_SVG_MASK_BITMAP=1` opens and clips the bitmap before
lookup.

Five fresh macOS captures compared Quartz, shared raster without
reuse, and both allocation orders. After a 96-pixel scroll, the two
cached variants matched the uncached document pixels exactly. The
largest channel difference against the Quartz capture at the top of
the fixture was two levels. The full Linux browser suite, Windows
D3D11 type check, and native SVG mask conversion and layer tests passed.

The timing used a single-C V `-prod`, Clang `-O1` executable, SHA-256
`3746585bae7afa0a93f5e2fb6ac602160763f8b52839922b8a624944aab9560e`.
It used the previous fixture and AVIF digests. The five capture PIDs
were 52618, 52635, 52641, 52668 and 52681. In separate precise-wheel
diagnostics, 643 translated-mask hits in PID 52738 allocated a bitmap
before lookup. None of the 668 hits in PID 52833 allocated one after
moving allocation. Both diagnostics exercised alpha and luminance.

Three timing groups rotated the allocation orders and Quartz. Each
ran the same local 120-input precise wheel schedule at a 1024 × 600
document viewport and 2× backing scale. Each launch used a fresh cache
and private profile with a hidden bookmark bar, disabled scripts, and
a one-second settle after the title matched. The endpoint was changed
native frame installation after outer view paint.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 52947 | Quartz | 42.87 | 22.514 | 25.906 | 26.772 | 54.86 | 120 / 93 | 57.652 / 17.496 |
| 53048 | Shared, before lookup | 45.22 | 21.337 | 25.043 | 26.647 | 54.91 | 120 / 98 | 56.723 / 17.158 |
| 53147 | Shared, after lookup | 44.87 | 21.507 | 25.927 | 27.060 | 55.62 | 120 / 96 | 51.838 / 16.888 |
| 53249 | Shared, before lookup | 44.34 | 21.661 | 25.710 | 27.033 | 54.96 | 120 / 96 | 51.870 / 17.284 |
| 53354 | Shared, after lookup | 44.97 | 21.445 | 24.969 | 27.397 | 57.54 | 120 / 93 | 51.518 / 16.539 |
| 53455 | Quartz | 43.00 | 22.342 | 26.097 | 26.664 | 55.02 | 120 / 93 | 54.038 / 17.052 |
| 53550 | Shared, after lookup | 44.13 | 21.467 | 25.779 | 27.932 | 56.47 | 120 / 93 | 51.643 / 20.577 |
| 53680 | Quartz | 41.26 | 23.625 | 26.843 | 29.801 | 55.79 | 120 / 88 | 56.376 / 18.882 |
| 53798 | Shared, before lookup | 44.10 | 21.522 | 25.935 | 45.029 | 58.96 | 120 / 89 | 52.505 / 0.079 |

All measured scroll intervals exceeded 16.67 ms. Starting one-minute
loads on the 18-CPU host were 7.16, 6.83, 6.84, 6.69, 6.64, 6.51, 6.35,
6.40 and 6.45. The macOS build and timed cohort passed their memory
guards with sampled RSS peaks of 11,692,883,968 and 411,107,328 bytes.
All browser exits were zero. The two allocation orders gave similar
scroll publication rates. The shared raster remained opt-in.

### Publishing the shared mask bitmap directly

After V rasterizes an eligible mask, Vox converts that bitmap in place
to premultiplied white RGB with alpha or luminance coverage. The same
bitmap context supplies the final Core Graphics image. The benchmark
switch `VOX_COPY_SHARED_SVG_MASK_BITMAP=1` uses a second bitmap for the
conversion.

The C conversion tests on macOS and Linux covered all RGB triples,
every alpha value, row padding, and unaligned starts. The Core Graphics
test compared the sRGB and DeviceRGB images through destination-in and
clip-to-mask operations at fractional bounds. Both operations produced
identical pixels. Six fresh macOS browser captures passed, with exact
document pixels between the copied and in-place masks after a 96-pixel
scroll. The largest difference against Quartz at the top of the
fixture was two channel levels.

The timing build used single-C V `-prod` with Clang `-O1`, SHA-256
`57d50c29e332d4d97d5760728426ce6b1ea04dcc843bcf8a9c69f9f0ca8253c1`.
The fixture and AVIF digests matched the previous cohort. The diagnostic
in PID 81887 produced 232 masks in the second bitmap during the input
window. PID 82049 published all 246 freshly rasterized masks from the
original bitmap. Both diagnostics exercised alpha and luminance.

Each run used a fresh process, cache and private profile with a hidden
bookmark bar. The local fixture used disabled scripts, a one-second settle
after the title matched, a 1024 × 600 document viewport at 2× backing scale,
and 120 precise wheel inputs at a requested 60 Hz. The wheel delta was
four pixels with a reversal after 60 inputs. The endpoint was changed
native frame installation after outer view paint.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 82187 | Quartz | 42.95 | 22.417 | 25.985 | 27.339 | 53.24 | 120 / 96 | 51.382 / 17.548 |
| 82282 | Copy | 45.20 | 21.433 | 25.128 | 26.427 | 55.45 | 120 / 97 | 51.402 / 18.280 |
| 82427 | In place | 45.13 | 21.293 | 25.748 | 27.315 | 54.80 | 120 / 98 | 52.153 / 19.167 |
| 82530 | Copy | 42.49 | 22.504 | 26.742 | 46.180 | 53.79 | 120 / 94 | 55.638 / 17.586 |
| 82652 | In place | 42.32 | 23.181 | 26.500 | 48.483 | 56.59 | 120 / 89 | 53.007 / 0.109 |
| 82810 | Quartz | 42.55 | 22.639 | 26.063 | 28.437 | 53.86 | 120 / 94 | 56.068 / 20.066 |
| 82964 | Copy, translated cache off | 37.85 | 25.232 | 29.649 | 31.393 | 57.75 | 120 / 78 | 61.572 / 17.276 |
| 83058 | In place, translated cache off | 37.39 | 25.794 | 29.164 | 31.488 | 57.79 | 120 / 77 | 62.478 / 16.717 |
| 83151 | Copy, translated cache off | 37.10 | 25.644 | 30.125 | 32.050 | 59.67 | 120 / 74 | 61.490 / 16.935 |
| 83263 | In place, translated cache off | 38.42 | 25.317 | 28.810 | 29.486 | 57.87 | 120 / 79 | 58.469 / 0.103 |

Every measured scroll interval exceeded 16.67 ms. Starting one-minute
loads on the 18-CPU host were 6.92, 6.44, 6.33, 7.39, 7.28, 6.94, 6.70,
6.49, 6.37 and 6.42. The browser and guard exits were zero. Sampled
RSS peaked at 11,339,235,328 bytes for the build and 407,846,912 bytes
for the scroll cohort. Publication rates were similar for both
conversion methods. The shared renderer remains opt-in.

### Reusing masks across viewport edges

The macOS shared renderer can retain a complete aligned mask within the
512 KiB per-image cache limit, even when the viewport clips part of it.
Vox uses a cropped Core Graphics image for the current placement and
keeps the complete raster available for later scroll positions. The
placement retains the existing clipped bounds used by both mask
compositing operations. `VOX_CLIP_SHARED_SVG_MASK_RASTER=1` restores
rasterization into the clipped bounds for comparisons.

The native tests matched cropped and directly rasterized images through
both clip-to-mask and destination-in. Ten fresh browser captures passed.
At a 42-pixel scroll offset, both paths matched pixel for pixel at
1024 × 600 and 2048 × 1200. The full-raster path recorded viewport-edge
cache hits in both alpha and luminance mode.

The single-C V `-prod`, Clang `-O1` executable SHA-256 was
`6adc1975a6fc82923205e87baccdf527a69c253b402e38bc87f82a8751315f63`.
The fixture and AVIF digests matched the previous cohort. In separate
precise-wheel diagnostics, PID 91817 rasterized 249 masks with the
viewport-clipped strategy and recorded 660 translated cache hits. PID
91888 rasterized six masks and recorded 942 translated cache hits,
248 of them for partially visible masks. These counts cover the input
window and include alpha and luminance.

Three timing groups ran the same 120 precise wheel inputs at a requested
60 Hz, with four-pixel steps and a reversal after 60 inputs. Each used a
1024 × 600 document viewport at 2× backing scale, a fresh cache and private
profile with a hidden bookmark bar, and one second of settle after the
local fixture title matched. Scripts were disabled. The endpoint was
changed native frame installation after outer view paint.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 91970 | Quartz | 43.46 | 22.094 | 25.487 | 26.927 | 56.83 | 120 / 91 | 54.253 / 17.352 |
| 92019 | Viewport-clipped | 41.89 | 22.980 | 26.921 | 27.921 | 56.64 | 120 / 88 | 53.585 / 18.806 |
| 92213 | Full mask | 45.88 | 21.028 | 25.991 | 27.746 | 55.14 | 120 / 99 | 49.545 / 0.098 |
| 92331 | Viewport-clipped | 44.36 | 21.950 | 25.962 | 26.431 | 56.16 | 120 / 94 | 54.532 / 0.101 |
| 92464 | Full mask | 47.02 | 20.561 | 24.863 | 26.529 | 52.79 | 120 / 106 | 48.050 / 0.107 |
| 92567 | Quartz | 41.20 | 23.560 | 27.170 | 28.022 | 55.72 | 120 / 88 | 53.146 / 0.105 |
| 92685 | Full mask | 45.69 | 21.015 | 25.671 | 26.686 | 57.85 | 120 / 94 | 48.630 / 0.111 |
| 92785 | Quartz | 40.24 | 23.832 | 28.463 | 30.009 | 54.41 | 120 / 88 | 52.915 / 18.589 |
| 92901 | Viewport-clipped | 44.75 | 21.882 | 25.509 | 26.090 | 54.90 | 120 / 97 | 52.645 / 0.085 |

Starting one-minute loads on the 18-CPU host were 4.60, 4.87, 4.96,
4.96, 5.21, 5.27, 5.25, 5.07 and 5.14. All sampled scroll intervals
exceeded 16.67 ms. The browser and guard exits were zero. Sampled RSS
peaked at 11,696,046,080 bytes for the build and 407,158,784 bytes for
the timed cohort. Full-mask caching improved scroll publication rates
in all three groups on this fixture. The shared renderer remains opt-in.

### Backing scale and live mask changes

The macOS placement cache includes backing scale alongside the resource
key and canvas coordinates. Clip and content masks use that identity
when preparing an image and when compositing it. The native key check
verified that 1× uses a distinct key from both 1.5× and 2× for both mask
types.

The [live mutation fixture](../Tests/Browser/Native/svg-gradient-mask-mutation.html)
changes linear stop opacity and radial stop color after the first
render. A published Quartz capture in PID 29997 changed the sample
pixels to blue and red, as expected. The candidate shared renderer
recorded the original and updated resource keys for each mask in PID
33812. Its final document matched the uncached capture in PID 33819
pixel for pixel. The first static suite run reported an eager-cache
screenshot mismatch. A fresh focused pair and two full 13-capture
repeats passed using the same comparisons. Native mask conversion,
cropping and layer checks also passed.

The single-C V `-prod`, Clang `-O1` timing executable SHA-256 was
`e158e06331a5d55155620e49143ecf17cb5d9c1446857bf6c1ba5de8f4de6bd8`.
The two alternating pairs used the previous scrolling fixture and AVIF
digests, a fresh cache and private profile with a hidden bookmark bar,
disabled scripts, and a one-second settle after the title matched. Each
ran 120 precise four-pixel wheel inputs at a requested 60 Hz, with one
reversal after 60 inputs. The document viewport was 1024 × 600 at 2×.
The endpoint was changed native frame installation after outer view paint.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 33874 | Quartz | 40.26 | 24.098 | 27.151 | 29.930 | 55.07 | 120 / 87 | 54.279 / 19.342 |
| 34105 | Shared | 45.74 | 20.992 | 25.327 | 27.439 | 52.84 | 120 / 103 | 55.262 / 0.123 |
| 34363 | Quartz | 38.26 | 24.577 | 29.323 | 52.284 | 54.85 | 120 / 83 | 56.003 / 20.481 |
| 34476 | Shared | 47.81 | 20.368 | 24.087 | 25.441 | 56.90 | 120 / 100 | 49.640 / 0.123 |

Starting one-minute loads on the 18-CPU host were 4.13, 4.04, 4.19
and 4.18. All measured scroll intervals exceeded 16.67 ms. The browser
and guard exits for the cohort were zero. Sampled process-tree RSS
peaked at 11,481,743,360 bytes during the build and 403,701,760 bytes
during timing. The shared renderer remains opt-in.

### Reusing rows in horizontal SVG alpha masks

The shared raster shades one row for an alpha mask formed by a single
horizontal linear gradient in a device-aligned rectangle. It copies that
row within the covered part of the cleared bitmap, using the existing
shader's sampling and rounding. macOS selects this path by default for
eligible masks with at most 128 Ki pixels including bitmap padding.
`VOX_SHARED_SVG_MASK_RASTER=1` enables the broader shared gradient path
and `=0` selects Quartz. `VOX_DISABLE_SVG_MASK_RAMP=1` disables row reuse.

The [15-capture macOS check](../tools/test_macos_svg_gradient_mask.py)
confirmed automatic selection for the horizontal alpha fixture and
Quartz selection for the radial luminance fixture. The automatic
document remained within two channel values of Quartz. The scrolled
document matched the full shared shader pixel for pixel. Cache,
viewport-edge and live mutation checks also passed. The Linux browser
suite passed all 17 checks, including the gradient-mask capture, which
logged 324 row replays. The Windows D3D11 browser passed the V type check.

The private timing build used V `-b c -prod` in one C unit with Clang
`-O1`. Its SHA-256 was
`87391a09626cd363ea2b3239ec15836fe3ed86c11c41b9a39aa63e482f1edcbb`.
The AVIF library and [local fixture](../Tests/Browser/Native/svg-gradient-masks.html)
digests were `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
and `358aaffab9b6a968c0c450a8466d13761813fff26d3bf507791f59d7ac200d4c`,
respectively. A separate diagnostic in PID 59286 with caching disabled
logged 448 row rasters and zero shared luminance rasters during input.

The two alternating pairs for each control used
`tools/measure_precise_scroll.py` with a 1024 × 600 document viewport
at 2×, one second of settle after the title matched, and 120 precise
four-pixel wheel inputs at a requested 60 Hz with reversal after 60.
Each process started with a fresh cache and private profile seeded
for file navigation and an empty hidden bookmark bar. The local
fixture had no external resources and scripts were disabled. The
endpoint was completed native frame installation after outer view
paint. The rates divide scroll changes by the first-to-last input
duration. Only the forced-shader and forced-row trials disabled the
mask cache. All timing trials disabled diagnostic logging.

| PID | Raster | Scroll fps | Median (ms) | p95 (ms) | Max (ms) | Input Hz | Inputs / scroll changes | First / last gap (ms) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 59398 | Quartz | 42.88 | 22.309 | 26.219 | 26.971 | 54.87 | 120 / 93 | 52.923 / 17.435 |
| 59513 | Automatic | 43.82 | 22.308 | 25.022 | 26.995 | 56.07 | 120 / 93 | 51.683 / 18.977 |
| 59614 | Quartz | 41.87 | 22.789 | 26.415 | 46.579 | 55.99 | 120 / 89 | 51.785 / 17.979 |
| 59719 | Automatic | 42.89 | 22.349 | 26.657 | 29.469 | 53.73 | 120 / 95 | 52.778 / 18.667 |
| 59873 | Forced shader | 38.22 | 25.305 | 29.537 | 30.902 | 58.31 | 120 / 78 | 60.225 / 0.089 |
| 59998 | Forced row | 41.16 | 23.404 | 26.686 | 28.159 | 55.03 | 120 / 89 | 53.836 / 18.386 |
| 60118 | Forced shader | 37.92 | 25.464 | 29.687 | 32.123 | 56.40 | 120 / 80 | 59.338 / 16.222 |
| 60227 | Forced row | 40.10 | 24.073 | 27.379 | 27.741 | 55.49 | 120 / 86 | 53.179 / 19.358 |

The cohort ran from 03:02:07 to 03:02:51 UTC on November 18, 2026.
Starting one-minute loads on the 18-CPU host were 4.01, 4.09, 4.65,
4.75, 5.01, 4.85, 4.78 and 4.48. The automatic trials recorded about
one more scroll-changing publication per second than Quartz, with
mixed p95 intervals. Forced row reuse improved both rate and p95 in
the uncached pairs. All measured intervals exceeded 16.67 ms. The
browser and guard exits were zero. Sampled process-tree RSS peaked at
11,248,877,568 bytes in the build and 406,306,816 bytes in the combined
diagnostic and timing job.

### Retaining radial SVG masks on macOS

Automatic selection includes supported single rectangular radial masks
when the aligned bitmap and its padding fit the 128 Ki pixel limit.
The shared raster keeps the complete image available across viewport
edges. When all cache slots were used in the current or previous frame,
new radial masks use Quartz. This keeps active rasters available and
avoids repeatedly paying for a full gradient draw during scroll.

The mixed workload used the [existing fixture](../Tests/Browser/Native/svg-gradient-masks.html)
with the digest above. The radial-only workload removed the horizontal
alpha group and the embedded SVG. Its SHA-256 was
`b66ebedef633eecae19f55e42854cc83038737e72f2dfb50a45631e8eb4856d6`.
The pressure workload used 75 individually positioned 136 × 90 masks,
five per row with different radial gradients and 120 px row spacing.
Its SHA-256 was
`a4a1afea97b530b617586b294767619ce251e7791414932defc760c210029017`.
Each run used the same precise wheel schedule, window, 2× backing
scale, readiness checks and private profile as the row-reuse cohort.
Automatic selection and Quartz alternated on the same executable for
each pair. The endpoint was completed native frame installation.

#### Initial radial selection

The single-C V `-prod`, Clang `-O1` executable SHA-256 was
`c23f508609599e4574c0b1fec6d980ca9fd21032bcfb754e5dcc1b0fbb571afe`.
The AVIF digest matched the row-reuse cohort. The first pressure
diagnostic counted 1,560 luminance rasters and zero hits inside the
input window. In the unprofiled pairs, throughput fell to 23.51
scroll-changing publications per second in both pressure trials.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Over 16.67 ms | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 89695 | Mixed | Quartz | 41.06 | 23.588 / 26.454 / 28.675 | 54.28 | 120 / 90 | 55.192 / 18.292 | 100% | 7.24 |
| 89792 | Mixed | Automatic | 44.29 | 21.696 / 25.687 / 27.660 | 57.29 | 120 / 92 | 49.202 / 17.050 | 100% | 7.14 |
| 89896 | Mixed | Quartz | 40.75 | 24.020 / 27.174 / 30.170 | 51.05 | 120 / 95 | 57.474 / 17.738 | 100% | 7.53 |
| 90008 | Mixed | Automatic | 45.37 | 20.942 / 25.501 / 25.995 | 57.43 | 120 / 94 | 48.617 / 16.626 | 100% | 7.25 |
| 90115 | Radial only | Quartz | 51.45 | 18.798 / 22.319 / 23.386 | 54.67 | 120 / 112 | 45.566 / 0.114 | 96% | 7.15 |
| 90185 | Radial only | Automatic | 50.06 | 19.368 / 25.035 / 26.411 | 55.67 | 120 / 107 | 44.198 / 0.117 | 96% | 6.81 |
| 90481 | Radial only | Quartz | 51.41 | 18.729 / 23.286 / 25.239 | 56.12 | 120 / 109 | 44.277 / 0.110 | 95% | 6.75 |
| 90549 | Radial only | Automatic | 54.91 | 17.565 / 21.356 / 32.489 | 55.38 | 120 / 118 | 40.731 / 0.128 | 70% | 6.45 |
| 90720 | Pressure | Quartz | 33.71 | 28.701 / 32.544 / 32.964 | 59.88 | 120 / 67 | 64.470 / 0.262 | 100% | 6.11 |
| 90805 | Pressure | Automatic | 23.51 | 41.507 / 45.575 / 47.180 | 57.11 | 120 / 49 | 86.267 / 17.668 | 100% | 5.94 |
| 90925 | Pressure | Quartz | 34.10 | 28.418 / 32.368 / 34.054 | 58.80 | 120 / 69 | 65.204 / 0.105 | 100% | 5.70 |
| 91010 | Pressure | Automatic | 23.51 | 40.739 / 44.407 / 48.358 | 55.96 | 120 / 50 | 87.978 / 36.418 | 100% | 5.57 |

The trials ran from 03:14:34 to 03:15:54 UTC on November 18, 2026.
Load is the starting one-minute average on the 18-CPU host. All
browser and guard exits were zero.

#### Radial selection with cache protection

The final single-C V `-prod`, Clang `-O1` executable SHA-256 was
`4c25938bbb11f6a6fa7e665ffc6163b28d9999ab6e3e3f922fc973ff06c29209`.
The AVIF digest matched the initial candidate. During input, separate
diagnostics recorded 418 radial hits, including 110 cropped
placements, and three rasters in the mixed workload (PID 18123).
The pressure workload recorded 1,120 radial hits, 16 rasters and 1,174
Quartz fallbacks (PID 17452).

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Over 16.67 ms | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 17572 | Pressure | Quartz | 32.60 | 29.271 / 34.036 / 35.715 | 59.69 | 120 / 65 | 65.289 / 16.742 | 100% | 8.42 |
| 17686 | Pressure | Automatic | 35.66 | 26.931 / 31.454 / 33.339 | 59.77 | 120 / 71 | 56.277 / 16.892 | 100% | 8.30 |
| 17793 | Pressure | Quartz | 32.22 | 29.344 / 33.515 / 63.052 | 59.91 | 120 / 64 | 65.200 / 18.718 | 100% | 8.12 |
| 17897 | Pressure | Automatic | 34.43 | 27.847 / 32.699 / 36.707 | 59.39 | 120 / 69 | 62.598 / 17.343 | 100% | 7.95 |
| 18290 | Mixed | Quartz | 37.34 | 25.457 / 30.492 / 50.336 | 54.86 | 120 / 81 | 59.302 / 20.051 | 100% | 7.86 |
| 18437 | Mixed | Automatic | 42.32 | 22.547 / 27.363 / 28.755 | 52.47 | 120 / 96 | 48.450 / 16.756 | 100% | 7.71 |
| 18599 | Mixed | Quartz | 38.58 | 24.728 / 29.268 / 31.015 | 54.65 | 120 / 84 | 54.919 / 19.384 | 100% | 7.73 |
| 18745 | Mixed | Automatic | 42.08 | 22.665 / 27.050 / 47.592 | 54.43 | 120 / 92 | 55.006 / 18.164 | 100% | 7.67 |
| 18937 | Radial only | Quartz | 41.94 | 23.026 / 26.617 / 44.260 | 53.66 | 120 / 93 | 64.275 / 16.491 | 100% | 7.38 |
| 19346 | Radial only | Automatic | 52.00 | 18.701 / 22.936 / 24.895 | 53.81 | 120 / 115 | 44.649 / 0.128 | 90% | 7.75 |
| 19522 | Radial only | Quartz | 49.44 | 19.366 / 24.698 / 25.876 | 56.03 | 120 / 105 | 47.950 / 0.095 | 100% | 7.47 |
| 19660 | Radial only | Automatic | 53.64 | 17.877 / 22.210 / 33.538 | 55.03 | 120 / 116 | 45.430 / 0.118 | 80% | 7.27 |

The final cohort ran from 03:22:41 to 03:23:54 UTC. All browser and
guard exits were zero. Automatic throughput and p95 improved in both
pressure pairs. The mixed and radial-only pairs also improved, with
substantial variation between the radial-only Quartz controls.
Sampled process-tree RSS peaked at 11,683,315,712 bytes for the build,
396,869,632 bytes for the pressure job and 413,171,712 bytes for the
mixed and radial-only job.

The [macOS pixel suite](../tools/test_macos_svg_gradient_mask.py)
pins backing scale and uses the same AppKit capture path throughout.
The initial unpinned comparisons varied even on an unmasked orange
marker. With fixed backing scale, both automatic and forced sampling
were within two channel levels of Quartz at 2×. At 1×, the horizontal
alpha mask differed by three levels in two columns. The suite checks
the two-level bound at 2×, the analytic samples at 1×,
and exact comparisons for row reuse, viewport edges and mutations.
The 2× automatic scroll capture matched forced shared rasterization
pixel for pixel. The capacity capture verified cache hits and Quartz
fallbacks in the same document. Native pixel and layer checks and
the Windows D3D11 V type check passed.

### Reusing columns in vertical SVG alpha masks

For a single vertical alpha gradient in a device-aligned rectangle,
the shared raster shades one column with the existing CPU shader and
copies each packed pixel across its covered row. This keeps the
gradient's original vertical coordinates and leaves uncovered pixels
clear. The existing aligned-mask default and bitmap size limit on
macOS also apply to these masks.

The [vertical mask fixture](../Tests/Browser/Native/svg-vertical-alpha-masks.html)
covers both gradient directions, a gradient transform, partial fill
opacity, and a mask path clipped horizontally by its region. Its
SHA-256 was `c19ec971f0e234926c0c7aae97081d19c53d249cd2391d18507c0bb2ad4ffeff`.
At 1× and 2×, scrolled macOS captures matched the full shared shader
pixel for pixel. The largest 2× difference from Quartz was two channel
levels. The X11 document capture also matched the full shader exactly.
All 18 Linux browser checks and the Windows D3D11 V type check passed.

The Linux ARM64 Clang `-O0` smoke build SHA-256 was
`070b385041a9188b5b20e6f574f68150ba3e0c00fc23d139f498e48aa447d868`.
Two alternating pairs used software OpenGL under Xvfb, fresh profiles
and caches, an empty hidden bookmark bar and a one-second settle.
The fixture had no scripts or external resources. The driver requested
a 1024 × 600 document viewport and advanced 80 synthetic 42-pixel
steps per trial. Command and scroll traces matched. The table measures
replay inside those callbacks.

| Trial | Raster | Median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Full shader | 23.611 | 26.726 | 41.903 |
| 2 | Column reuse | 13.027 | 15.625 | 31.355 |
| 3 | Full shader | 24.652 | 27.680 | 44.341 |
| 4 | Column reuse | 13.203 | 15.932 | 32.296 |

The four-vCPU guest started the trials at one-minute loads of
0.46, 0.50, 0.54 and 0.58 while the host compiled the macOS binary.
The Linux build, browser checks, and replay cohort exited zero.

The private macOS single-C V `-prod`, Clang `-O1` executable SHA-256
was `00add4e3c4fa45cdd9afbd2fa439abddcc0cab10da28755ee3f9398967eb0128`.
The AVIF library matched the horizontal-mask cohort. A separate
diagnostic in PID 53713 recorded 692 vertical strip rasters during
the input window with the cache disabled.

The macOS trials used the same private profile, 1024 × 600 viewport
at 2× and native wheel protocol as the preceding cohorts. Each
process settled for one second after the fixture title matched.
The script-free local fixture required no external resources. Each
pair ran 120 four-pixel inputs at a requested 60 Hz with reversal
after 60 inputs. The endpoint was completed native frame installation
after outer view paint, measured over the first-to-last input window.
Uncached trials disabled the shared mask cache. The full shader and
column trials both forced shared selection to isolate the shading
change. Diagnostics were disabled during timing.

| PID | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 53764 | Quartz | 33.44 | 28.662 / 34.424 / 37.263 | 56.84 | 120 / 70 | 61.865 / 16.837 | 6.89 |
| 53893 | Automatic | 38.49 | 25.013 / 31.096 / 32.511 | 56.54 | 120 / 81 | 57.531 / 19.251 | 6.74 |
| 54084 | Quartz | 35.75 | 26.943 / 31.995 / 33.457 | 57.48 | 120 / 74 | 61.315 / 0.103 | 6.68 |
| 54162 | Automatic | 39.78 | 24.168 / 28.635 / 29.979 | 55.70 | 120 / 85 | 54.831 / 19.322 | 6.23 |
| 54228 | Full shader, uncached | 28.40 | 34.393 / 38.965 / 39.765 | 55.41 | 120 / 61 | 69.271 / 18.959 | 5.97 |
| 54348 | Column, uncached | 35.95 | 26.768 / 32.737 / 52.525 | 54.85 | 120 / 78 | 57.597 / 18.082 | 6.13 |
| 54444 | Full shader, uncached | 31.29 | 31.416 / 35.909 / 37.197 | 58.18 | 120 / 64 | 65.895 / 0.089 | 6.63 |
| 54550 | Column, uncached | 36.56 | 26.540 / 30.940 / 31.460 | 56.50 | 120 / 77 | 60.663 / 17.941 | 6.82 |
| 55235 | Quartz, uncached | 35.85 | 26.965 / 31.205 / 50.105 | 56.14 | 120 / 76 | 61.021 / 18.240 | 7.14 |
| 55288 | Automatic, uncached | 38.66 | 25.285 / 29.721 / 31.037 | 58.98 | 120 / 78 | 54.758 / 17.177 | 6.89 |
| 55342 | Quartz, uncached | 35.26 | 27.234 / 32.654 / 33.395 | 58.28 | 120 / 72 | 61.307 / 16.636 | 6.50 |
| 55432 | Automatic, uncached | 35.99 | 26.454 / 33.102 / 34.078 | 54.90 | 120 / 78 | 58.707 / 18.101 | 6.30 |

The cohorts ran from 03:36:01 to 03:37:18 UTC on November 18, 2026.
Load is the starting one-minute average on the 18-CPU host. All
measured intervals exceeded 16.67 ms. Automatic selection improved
throughput in all four Quartz pairs. The uncached Quartz pairs had
mixed p95 results. Column reuse improved throughput and p95 in both
full shader pairs. All browser and guard exits were zero. Sampled
process-tree RSS peaked at 11,019,010,048 bytes during the build,
397,901,824 bytes in the first timing job and 392,527,872 bytes
in the uncached Quartz comparison.

### Reusing strips in linear SVG luminance masks

The shared raster also uses one shaded row or column for aligned
rectangular luminance masks with a single sRGB linear gradient.
The strip retains premultiplied RGB, including stop alpha and fill
opacity. The luminance conversion uses the same integer channel
weights as the full shader. macOS uses the existing automatic
selection and the 128 Ki pixel limit.

The [luminance fixture](../Tests/Browser/Native/svg-linear-luminance-masks.html)
uses an opaque red–green–blue horizontal gradient and a transformed
vertical gradient with changing stop alpha and partial fill opacity.
The fixture SHA-256 was
`263051a227a5964cd27fe855f4e2d00a8e2c6a262958706aaa774b2b4f614f27`.
The published binary at `e720fb9a8`, SHA-256
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`,
confirmed the earlier full shared shader and Quartz were within
two channel levels across both masks at 1× and 2×. All four fresh
captures exited zero with the pinned fixture and library.

The Linux X11 captures matched the full shader pixel for pixel.
All 19 browser checks and the Windows D3D11 V type check passed.
The Linux ARM64 Clang `-O0` executable SHA-256 was
`dafeb83d9ca4314ecf40514c6760c0d7671a6bedae8d2f5339892b603338ffca`.
The synthetic Linux cohort used the same Xvfb software OpenGL
protocol as the vertical-alpha test. Each process used a fresh cache
and profile, disabled scripts, and requested a 1024 × 600 viewport.
Two pairs alternated the full shader and strip reuse, with matching
traces for all 80 synthetic 42-pixel steps. A separate diagnostic
exercised both strip directions.

| Trial | Raster | Replay median (ms) | p95 (ms) | Max (ms) |
| --- | --- | ---: | ---: | ---: |
| 1 | Full shader | 31.800 | 36.355 | 50.191 |
| 2 | Strip reuse | 20.183 | 22.935 | 37.913 |
| 3 | Full shader | 34.515 | 39.111 | 48.450 |
| 4 | Strip reuse | 21.008 | 24.531 | 38.599 |

Starting one-minute guest loads were 0.58, 0.61, 0.56 and 0.52 on
four vCPUs, while the host compiled the macOS candidate. The Linux
build, browser suite and synthetic replay guards exited zero.

The 30-capture macOS suite compared the automatic strip path with
the full shader at 1× and 2×. Both matched exactly. The 2× Quartz
comparison differed by at most two channel levels. With
`color-interpolation="linearRGB"`, the automatic path selected Quartz
and matched the explicit Quartz control pixel for pixel.

The private macOS single-C V `-prod`, Clang `-O1` executable SHA-256
was `1cb9eb53debe18625616ee7946bb087953c191c58620c50bdde376719fb00500`.
It used the same AVIF library as the published comparison. In a
separate uncached diagnostic, PID 79286 recorded 348 horizontal
strips and 345 vertical strips for 693 luminance rasters within
the input window.

The macOS trials used the same profile, viewport, settle and
precise wheel settings as the vertical-alpha cohort. The endpoint
was completed native frame installation after outer view paint.
The uncached pairs disabled the shared mask cache. The strip and
full shader pairs also forced shared selection to isolate the
raster change. The timing launches disabled diagnostics and
preserved binary, library, fixture and driver hashes.

| PID | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 79374 | Quartz | 34.08 | 28.212 / 32.786 / 35.701 | 57.94 | 120 / 70 | 65.415 / 16.433 | 6.02 |
| 79499 | Automatic | 38.17 | 25.514 / 30.205 / 33.120 | 57.50 | 120 / 79 | 57.620 / 17.498 | 5.86 |
| 79599 | Quartz | 32.16 | 29.864 / 35.548 / 40.242 | 57.98 | 120 / 66 | 66.084 / 16.907 | 5.79 |
| 79757 | Automatic | 35.64 | 27.440 / 32.488 / 33.535 | 54.37 | 120 / 78 | 60.210 / 17.548 | 5.89 |
| 79929 | Full shader, uncached | 29.56 | 32.854 / 36.736 / 37.402 | 57.66 | 120 / 61 | 71.646 / 20.434 | 6.28 |
| 80138 | Strip, uncached | 36.54 | 26.721 / 31.683 / 32.400 | 55.74 | 120 / 78 | 59.857 / 0.101 | 6.18 |
| 80298 | Full shader, uncached | 29.37 | 32.324 / 37.568 / 67.637 | 57.29 | 120 / 61 | 71.324 / 0.115 | 6.16 |
| 80446 | Strip, uncached | 35.21 | 27.331 / 32.653 / 33.486 | 57.39 | 120 / 73 | 61.038 / 16.520 | 6.39 |
| 80589 | Quartz, uncached | 32.31 | 29.376 / 34.623 / 36.072 | 53.40 | 120 / 72 | 65.242 / 16.428 | 6.68 |
| 80744 | Automatic, uncached | 36.81 | 26.305 / 32.499 / 33.518 | 56.16 | 120 / 78 | 60.793 / 16.905 | 6.70 |
| 80938 | Quartz, uncached | 35.65 | 27.321 / 32.134 / 32.957 | 58.93 | 120 / 72 | 64.319 / 0.089 | 6.89 |
| 81101 | Automatic, uncached | 37.25 | 25.664 / 31.289 / 47.322 | 56.82 | 120 / 78 | 60.479 / 17.333 | 6.82 |

The timed cohort ran from 03:45:57 to 03:47:02 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
All intervals exceeded 16.67 ms. Scroll publication throughput and
p95 improved in all six pairs on this fixture. The second uncached
automatic trial had a longer maximum interval than its Quartz
control. All browser and guard exits were zero. Sampled process-tree
RSS peaked at 11,709,595,648 bytes for the build and 400,637,952
bytes for the diagnostic and timing job.

### Caching diagonal SVG gradient masks on macOS

Automatic selection uses the shared linear shader for a single
diagonal gradient in a device-aligned rectangle when the complete
bitmap fits the existing cache limit. It reuses the raster across
scroll positions, including at viewport edges. Admission protects
rasters used by the current or preceding frame. An unavailable cache
slot or a disabled shared cache sends the mask through Quartz.
The strip rasterizer still handles axis-aligned fades.

The [diagonal fixture](../Tests/Browser/Native/svg-diagonal-gradient-masks.html)
has a diagonal alpha mask and a transformed sRGB luminance mask.
Its SHA-256 was
`3f798c17a0915cd23fe0a16bf8c24742b52689247667227b2c22f96ae11da7c5`.
The published binary at `e720fb9a8` and AVIF library digests
matched the luminance cohort. Fresh 1× and 2× captures in PIDs
89882, 89902, 89923 and 89961 compared Quartz with the forced full
shader. Each mask stayed within two channel levels of Quartz and
all launches exited zero.

The candidate suite initially checked a 42-pixel offset, which
did not exercise cropped cache hits for both masks. At a 132-pixel
offset both masks recorded cropped hits. The automatic captures
matched uncached shared shader output pixel for pixel at 1× and
2×. Disabling the shared cache in automatic mode produced the
same pixels as Quartz. The 2× Quartz comparison differed from the
cached path by at most two channel levels. All 37 candidate macOS
captures, all 19 Linux browser checks and the Windows D3D11 type
check passed.

The pressure fixture generated 75 different diagonal gradients,
with five 136 × 90 mask regions per row and 120 px row spacing.
Its SHA-256 was
`3017bbb7c1cbeb4f9ddb4adec577dad7d168fd1667d94c6ac08dfd7b7ea9a6c9`.
The macOS timing cohorts used the preceding wheel protocol with
a 1024 × 600 document viewport at 2×. Each process used a fresh
cache and profile with an empty hidden bookmark bar. The script-free
local files required no external resources. Timing began after one
second of settle after the title matched. Each trial used 120
four-pixel wheel inputs at a requested 60 Hz with one reversal,
and counted scroll-changing native frame installations after outer
view paint over the input window. The private single-C V `-prod`,
Clang `-O1` executable SHA-256 was
`fb5330bfacd52e673ad0a41e7d942231482d5344ebfcced76b2f5da1dc7358f0`.
Its AVIF library matched the published comparison.

Separate diagnostics counted 740 hits, 199 cropped placements
and six rasters in the diagonal fixture (PID 11204). The
pressure fixture recorded 1,216 hits, 203 cropped placements,
16 rasters and 1,263 Quartz fallbacks (PID 11577).
The timing launches disabled diagnostics and alternated Quartz
with automatic selection on the same binary for each fixture.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 11329 | Diagonal | Quartz | 36.48 | 26.220 / 31.648 / 32.890 | 57.89 | 120 / 75 | 63.448 / 0.081 | 5.56 |
| 11385 | Diagonal | Automatic | 39.78 | 24.051 / 28.161 / 32.137 | 57.04 | 120 / 83 | 54.639 / 19.523 | 5.44 |
| 11453 | Diagonal | Quartz | 36.39 | 26.354 / 32.048 / 32.769 | 56.24 | 120 / 77 | 59.011 / 18.430 | 5.40 |
| 11506 | Diagonal | Automatic | 40.56 | 23.816 / 28.299 / 29.360 | 56.78 | 120 / 85 | 54.640 / 19.252 | 5.61 |
| 11676 | Pressure | Quartz | 34.21 | 28.481 / 31.848 / 37.230 | 59.87 | 120 / 68 | 65.978 / 0.199 | 5.52 |
| 11799 | Pressure | Automatic | 36.78 | 26.267 / 29.599 / 32.453 | 59.96 | 120 / 73 | 64.408 / 0.235 | 6.36 |
| 11869 | Pressure | Quartz | 33.14 | 28.372 / 32.845 / 62.509 | 59.76 | 120 / 66 | 72.754 / 17.042 | 7.13 |
| 11984 | Pressure | Automatic | 36.68 | 26.062 / 31.140 / 56.864 | 59.79 | 120 / 73 | 59.824 / 0.241 | 6.96 |

The timed cohort ran from 03:57:37 to 03:58:25 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
Throughput, median and p95 improved in all four pairs. All measured
intervals exceeded 16.67 ms. The timing browser and guard exits were
zero. Sampled process-tree RSS peaked at 11,682,955,264 bytes
for the build and 398,196,736 bytes for the diagnostic and timing job.

### Caching SVG gradient masks with group opacity on macOS

Automatic selection can render an isolated opacity group with one
or two pixel-aligned rectangular fills, including a supported
gradient, in the shared rasterizer. It composites the fills before
applying the group opacity and retains the complete raster within
the existing 128 Ki pixel limit. Cache admission protects rasters
used by the current or preceding frame. Nested groups and masks
without an available cache slot use Quartz.

The [group opacity fixture](../Tests/Browser/Native/svg-gradient-mask-opacity.html)
combines an alpha gradient with an overlapping solid fill and
an sRGB luminance gradient with a red overlay. Its SHA-256 was
`c4768659c273d4ecaa356425dd16ee6070fd102805a8951d54de60cabfd2572d`.
The published binary at `e720fb9a8` and AVIF library digests
matched the diagonal cohort. Fresh PIDs 22784, 22842, 22859
and 23125 compared forced shared rasterization with Quartz.
The document differed by at most two channel levels at 1×
and one at 2×. Native mask conversion and layer tests passed.

The pressure fixture generated 75 single-fill groups with
different diagonal gradients in 136 × 90 mask regions.
Its SHA-256 was
`b30caf8f441c3385143cbbc9e04e1978b4006ca08d5ae499c5d54d571f84f385`.
The macOS timing cohorts used the preceding precise wheel
protocol with the 1024 × 600 document viewport at 2×, a fresh
cache and private profile per process, and one second of settle
after document-title readiness. Each script-free local fixture
received 120 four-pixel inputs at a requested 60 Hz, reversing
after 60. The endpoint was completed native frame installation
after outer view paint, measured over the first-to-last input.

The private single-C V `-prod`, Clang `-O1` executable SHA-256
was `27b94e043e8abf7c13e0f1cf71de2386f48c6a977fc79e35d5ede7607c89df48`.
Its AVIF library matched the published comparison. All 46
macOS captures passed. At the 132-pixel offset the candidate
used cropped cache hits and matched the uncached shared shader
exactly at 1× and 2×. On the half-opacity mask, both individual
fills and their overlap produced `(128, 128, 255)`. The 2× Quartz
comparison differed by at most one channel level. Disabling the
shared cache and adding a nested opacity group both matched the
explicit Quartz control pixel for pixel.

The separate grouped diagnostic in PID 38200 recorded 608 cache
hits, including 161 cropped placements, and six rasters during
input. With cache pressure, PID 39029 recorded 1,104 hits,
188 cropped placements, 16 rasters and 1,165 Quartz fallbacks.
The timing launches disabled diagnostics and alternated Quartz
with automatic selection on the same pinned binary.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 38366 | Two fills | Quartz | 27.60 | 35.279 / 39.689 / 40.510 | 55.67 | 120 / 59 | 76.625 / 17.717 | 7.75 |
| 38531 | Two fills | Automatic | 35.42 | 27.355 / 33.101 / 35.895 | 56.95 | 120 / 74 | 60.525 / 0.100 | 7.93 |
| 38689 | Two fills | Quartz | 26.88 | 36.130 / 41.650 / 42.520 | 57.12 | 120 / 56 | 76.629 / 0.259 | 7.54 |
| 38880 | Two fills | Automatic | 31.75 | 29.763 / 35.617 / 61.855 | 56.39 | 120 / 67 | 67.398 / 19.015 | 7.44 |
| 39198 | Pressure | Quartz | 30.72 | 31.588 / 35.081 / 35.995 | 58.97 | 120 / 62 | 69.623 / 0.106 | 7.27 |
| 39314 | Pressure | Automatic | 35.46 | 27.302 / 31.447 / 32.747 | 59.44 | 120 / 71 | 65.485 / 0.195 | 6.93 |
| 39412 | Pressure | Quartz | 29.81 | 31.671 / 36.749 / 67.294 | 59.13 | 120 / 60 | 73.174 / 16.602 | 6.78 |
| 39511 | Pressure | Automatic | 34.32 | 28.050 / 33.047 / 34.950 | 59.19 | 120 / 69 | 62.772 / 0.098 | 6.71 |

The timed cohort ran from 04:06:29 to 04:07:17 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
Throughput, median and p95 improved in all four pairs. The second
two-fill automatic trial had a longer maximum interval than its
Quartz control. All measured intervals exceeded 16.67 ms. Browser
and guard exits were zero. Sampled process-tree RSS peaked at
11,680,628,736 bytes for the build and 402,440,192 bytes for
the diagnostic and timing job.

### Caching solid SVG rectangle masks on macOS

Automatic selection can reuse the shared raster of a single solid
fill in a pixel-aligned rectangular path. It uses the same alpha
and luminance conversion as the portable renderer. The complete
bitmap must fit the existing 128 Ki pixel limit, and admission
protects rasters used in the current or preceding frame. Quartz
handles masks with fractional edges or no available cache slot.

The [solid rectangle fixture](../Tests/Browser/Native/svg-solid-rectangle-masks.html)
checks a black half-opacity alpha mask and a red three-quarter-opacity
luminance mask. Its SHA-256 was
`07b57389db3bc434b3c6899b28a1213630aba27a330399b034cef0bc89d2975d`.
The published binary at `e720fb9a8` and its AVIF library matched
the grouped-mask cohort. Fresh Quartz captures in PIDs 42703
and 42746 produced `(127, 127, 255)` and `(255, 215, 215)`
on the two fills at both 1× and 2×.

The cache-pressure fixture used 75 partially opaque solid masks
with distinct colors in 136 × 90 regions. Its SHA-256 was
`57792682cba8436d07bc79bbe02ee038fcf179d62541b72136af4f299ee3ffdc`.
The local fixtures had no scripts or external resources. The
macOS timing cohorts used the preceding precise wheel protocol
with a 1024 × 600 document viewport at 2×. Each run started with
a fresh cache and private profile and settled for one second
after the document title matched. The 120 four-pixel inputs
reversed halfway at a requested 60 Hz. The endpoint was completed
native frame installation after outer view paint, measured over
the first-to-last input window.

The private single-C V `-prod`, Clang `-O1` executable SHA-256 was
`ae117f01b28cda83bc6e623e4b38b80c68deba924c9a2412ff4cab5cbb0b4253`.
Its AVIF library matched the published comparison. The 55-capture
macOS suite recorded cropped cache hits in both mask modes
and matched the uncached shared result exactly at 1× and 2×.
The 2× solid rectangle capture matched Quartz pixel for pixel.
Tests with fractional path edges and with the shared cache
disabled verified the Quartz fallback. The native mask conversion
and layer checks passed.

The separate diagnostic in PID 62073 recorded 682 cache hits,
including 183 cropped placements, and six rasters during
input. Under pressure, PID 62421 recorded 752 hits, 124 cropped
placements, 16 rasters and 797 Quartz fallbacks. The timing
launches disabled diagnostics and alternated Quartz with automatic
selection on the same pinned binary.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 62146 | Solid | Quartz | 30.05 | 31.864 / 37.685 / 63.915 | 56.76 | 120 / 63 | 69.414 / 16.595 | 6.64 |
| 62210 | Solid | Automatic | 36.80 | 26.092 / 31.405 / 48.858 | 58.40 | 120 / 75 | 59.545 / 0.095 | 6.35 |
| 62264 | Solid | Quartz | 31.73 | 30.847 / 35.175 / 37.414 | 55.53 | 120 / 68 | 71.998 / 0.093 | 6.24 |
| 62364 | Solid | Automatic | 36.42 | 26.659 / 31.426 / 32.843 | 57.79 | 120 / 75 | 61.418 / 16.565 | 6.14 |
| 62536 | Pressure | Quartz | 20.39 | 46.346 / 50.915 / 52.348 | 57.77 | 120 / 42 | 101.321 / 32.979 | 5.96 |
| 62646 | Pressure | Automatic | 23.11 | 41.368 / 45.778 / 47.003 | 59.78 | 120 / 46 | 89.129 / 32.843 | 5.89 |
| 62807 | Pressure | Quartz | 21.29 | 44.564 / 47.993 / 49.653 | 58.91 | 120 / 43 | 103.292 / 33.146 | 5.90 |
| 62907 | Pressure | Automatic | 23.27 | 40.421 / 44.452 / 89.715 | 57.68 | 120 / 48 | 88.067 / 16.351 | 5.74 |

The timed cohort ran from 04:15:01 to 04:15:49 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
Throughput, median and p95 improved in all four pairs. The second
pressure trial had a longer maximum interval with automatic
selection. All measured intervals exceeded 16.67 ms. Browser and
guard exits were zero. Sampled process-tree RSS peaked at
11,680,612,352 bytes for the build and 397,950,976 bytes for
the diagnostic and timing job.

### Caching overlapping solid SVG mask fills on macOS

The bounded solid-mask path also accepts two pixel-aligned
rectangular fills. The shared raster composites them in paint
order before converting the premultiplied result to alpha or
luminance. Both paths must be aligned, and the complete bitmap
uses the existing cache limit and admission policy.

The [overlap fixture](../Tests/Browser/Native/svg-overlapping-solid-mask-fills.html)
has two half-opacity alpha fills and overlapping red and green
luminance fills. Its SHA-256 was
`014ff8fe50e532a757b267173b04d324f1cd8ea1f242ae5d7a9f5e5901bc9e4b`.
The pinned published binary and AVIF library matched the preceding
solid-rectangle cohort. The Quartz captures in PIDs 82279 and
82353 at 1× and 2× gave `(127, 127, 255)` on the individual
alpha fills and `(63, 63, 255)` in their overlap. The red-backed
luminance overlap was `(255, 150, 150)`.

The pressure fixture placed two overlapping translucent solid
fills in each of 75 136 × 90 mask regions, with different colors
across masks. Its SHA-256 was
`85d29b8571a0779f730498d19b291a40fce26b08378e6fced5b7bd4a2aa8e239`.
The macOS comparisons used the preceding precise wheel protocol
with a 1024 × 600 document viewport at 2×, a fresh cache and
private profile for each process, and one second of settle
after the document title matched. Each local fixture ran without
scripts or external resources. The 120 four-pixel wheel inputs
reversed after 60 inputs at a requested 60 Hz. The counted endpoint
was completed native frame installation over the first-to-last
input window.

The private single-C V `-prod`, Clang `-O1` executable SHA-256
was `992e30d529904cc486c03ed75ab152ad25f1079c9f708b765663bdc2a85f18a1`.
Its AVIF library matched the published comparison. The 66-capture
macOS suite verified cropped cache hits and exact matches with the
forced uncached shared path at 1× and 2×. The 2× overlap fixture
matched Quartz pixel for pixel. A fractional translation of the
second fill and a disabled shared cache both selected Quartz.
Reordering the live luminance fills produced a new raster key and
the same `(255, 183, 183)` overlap as the uncached render and
published Quartz control. Native mask conversion and layer tests
also passed.

The separate overlap diagnostic in PID 90124 recorded 609 cache
hits, including 164 cropped placements, and six rasters during
input. The pressure diagnostic in PID 90642 recorded 608 hits,
99 cropped placements, 16 rasters and 651 Quartz fallbacks.
Timing launches disabled diagnostics and alternated Quartz with
automatic selection on the same pinned binary.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 90223 | Overlap | Quartz | 25.07 | 38.119 / 42.680 / 74.868 | 57.38 | 120 / 52 | 83.235 / 18.563 | 4.57 |
| 90327 | Overlap | Automatic | 32.67 | 29.232 / 34.519 / 54.838 | 58.90 | 120 / 66 | 67.248 / 16.557 | 4.55 |
| 90430 | Overlap | Quartz | 26.19 | 37.101 / 42.006 / 42.848 | 55.66 | 120 / 56 | 85.793 / 0.093 | 4.35 |
| 90543 | Overlap | Automatic | 33.22 | 28.769 / 34.333 / 35.487 | 59.00 | 120 / 67 | 70.608 / 18.312 | 4.32 |
| 90744 | Pressure | Quartz | 14.81 | 63.941 / 68.395 / 69.529 | 58.76 | 120 / 30 | 141.998 / 16.956 | 4.28 |
| 90848 | Pressure | Automatic | 18.36 | 52.160 / 57.135 / 58.095 | 56.03 | 120 / 39 | 119.605 / 0.087 | 4.17 |
| 90952 | Pressure | Quartz | 13.84 | 70.365 / 76.187 / 77.499 | 58.82 | 120 / 28 | 140.011 / 17.234 | 4.00 |
| 91152 | Pressure | Automatic | 16.72 | 56.453 / 59.734 / 61.026 | 58.51 | 120 / 34 | 117.386 / 50.691 | 3.92 |

The timed cohort ran from 04:24:25 to 04:25:13 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
Throughput and all three interval statistics improved in all four
pairs. All measured intervals exceeded 16.67 ms. Browser and guard
exits were zero. Sampled process-tree RSS peaked at 11,681,857,536
bytes for the build and 398,295,040 bytes for the diagnostic and
timing job.

### Caching nested opacity in SVG gradient masks on macOS

Automatic selection accepts a stack of up to four opacity
groups enclosing the same one or two pixel-aligned rectangular
fills, including a supported gradient. The shared raster
composites the fills, then restores each group from the inside
out. The complete raster fits the existing 128 Ki pixel limit
and uses the same admission policy as the single opacity group.

The test generates two- and four-layer variants of the
[group opacity fixture](../Tests/Browser/Native/svg-gradient-mask-opacity.html).
Their SHA-256 digests were
`e079f8edabba482e455ea5aebb5d380b850464e871d15147c96d5fae3ddeca62`
and `acf9d5a545bc8a7ebc682f6a1daea81ed4ba4725beb1c2a082d675f1b621e924`.
The published `e720fb9a8` executable and AVIF library matched the
preceding cohort. Eight fresh captures compared the forced shared
path with Quartz at 1× and 2×. Both variants stayed within two
channel levels of Quartz. The overlap and individual alpha fills
produced `(160, 160, 255)` with two layers and `(202, 202, 255)`
with four layers in the shared captures.

The pressure fixture used 75 different gradients, each enclosed
by four opacity groups in a 136 × 90 mask region. Its SHA-256 was
`0492aa6de8ed826f5fc3c61732707c66a9e32cf2399b15c3e30bf1ff4ca324aa`.
The local fixtures had no scripts or external resources. The
macOS trials used the preceding precise wheel protocol at a
1024 × 600 viewport and 2× backing scale, with fresh processes,
caches and private profiles and one second of settle after the
document title matched. Each launch received 120 four-pixel
inputs at a requested 60 Hz, reversing after 60. The endpoint
was completed native frame installation after outer view paint
over the first-to-last input window.

The private single-C V `-prod`, Clang `-O1` executable SHA-256 was
`e282cf6668c096955ca53a4f7a5d4990087e7720dbecde43739a949f36bbcb1c`.
All 80 macOS captures passed. The two- and four-layer fixtures
matched the forced uncached shared render pixel for pixel at
1× and 2×, with cropped cache hits in both mask modes.
The four-layer pressure capture stayed within two channel levels
of Quartz while using both cached rasters and Quartz fallbacks.
Five nested groups and disabling the shared cache both matched
the explicit Quartz control exactly. Native conversion and
layer checks passed.

The first diagnostic, PID 14148, exited zero. A production publish
replaced AVIF and adblock helper files during that run. Both digests
stayed the same and both file identities changed. The driver
rejected the run and the guard exited 1. The subsequent cohort
used the new published file identities with the same private
browser executable.

The valid nested diagnostic in PID 15556 recorded 659 cache hits,
including 177 cropped placements, and six rasters during input.
With four-layer masks under pressure, PID 16092 recorded 928
hits, 150 cropped placements, 16 rasters and 971 Quartz fallbacks.
The timing launches disabled diagnostics and alternated Quartz
with automatic selection on the same pinned browser.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 15697 | Two layers | Quartz | 26.13 | 36.325 / 42.588 / 71.553 | 57.59 | 120 / 54 | 80.781 / 0.129 | 5.08 |
| 15791 | Two layers | Automatic | 33.24 | 28.518 / 34.321 / 52.908 | 57.34 | 120 / 69 | 63.529 / 17.554 | 5.23 |
| 15899 | Two layers | Quartz | 26.59 | 36.569 / 42.306 / 43.270 | 56.51 | 120 / 56 | 76.603 / 0.122 | 5.04 |
| 15996 | Two layers | Automatic | 34.89 | 27.586 / 32.057 / 32.750 | 58.48 | 120 / 71 | 59.650 / 16.387 | 5.04 |
| 16219 | Four layers, pressure | Quartz | 21.34 | 44.835 / 49.635 / 53.384 | 59.06 | 120 / 43 | 95.851 / 17.103 | 5.11 |
| 16346 | Four layers, pressure | Automatic | 27.07 | 35.329 / 42.285 / 48.696 | 56.51 | 120 / 57 | 74.343 / 16.512 | 5.02 |
| 16439 | Four layers, pressure | Quartz | 22.99 | 40.896 / 44.888 / 86.509 | 58.21 | 120 / 47 | 93.940 / 17.885 | 5.02 |
| 16556 | Four layers, pressure | Automatic | 29.11 | 32.569 / 37.489 / 71.423 | 57.74 | 120 / 60 | 68.845 / 18.128 | 4.94 |

The accepted cohort ran from 04:34:10 to 04:34:59 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host.
Throughput and all three interval statistics improved in all four
pairs. All measured intervals exceeded 16.67 ms. Browser and guard
exits in this cohort were zero. Sampled process-tree RSS peaked at
11,685,937,152 bytes for the build and 405,733,376 bytes for the
accepted diagnostic and timing job.

### Caching solid SVG opacity groups on macOS

Automatic shared rasterization accepts nested and sibling opacity groups
with up to six pixel-aligned solid rectangle fills and 12 paint operations.
Fills outside the groups participate in the same ordered replay. The existing
four-layer and 128 Ki-pixel limits apply. Cache pressure, fractional edges and
operation counts beyond the limit can select Quartz.

The published executable `4ac49eb9690c121587fd4efd8f859f2cf0e2762013861238f07bb91a05547540`
used Quartz for both masks in the [opacity fixture](../Tests/Browser/Native/svg-mask-opacity.html)
in fresh PID 36794. Its source SHA-256 was
`2ca5b13ae5723502fa64a1661cb1ea2b3eb129e2508c048cd6fa1cf6e429ea51`.
The private single-unit V `-prod`, Clang `-O1` executable was
`a64f3f3c0250ca1863b62a2a78a8c863de4a0bb94f2e54807a6f37c58fc6f77d`.
All 92 macOS captures passed on that executable. The grouped alpha and
luminance masks matched uncached shared replay exactly at 1× and 2×, including
cropped viewport hits. The largest difference from Quartz at 2× was one
channel level. A mixed cache and Quartz capture with 30 masks stayed within
two channel levels. Fractional fills, excessive operation counts and disabled
caching matched the explicit Quartz control exactly. Native pixel conversion
and layer tests passed.

Three local, script-free fixtures ran at 1024 × 600 and 2× after a one-second
title-matched settle. Each fresh process used a private cache and profile.
`tools/measure_precise_scroll.py` sent 120 four-pixel precise inputs at a
requested 60 Hz, reversing after 60. Each pair used the same executable and
changed `VOX_SHARED_SVG_MASK_RASTER` from `0` to automatic. The throughput
endpoint was completed native frame installation after outer view paint over
the first-to-last input window.

The 30-mask pressure fixture reached its 240 CSS-pixel scroll limit before
the input reversed. The 75-mask fixture used the same mask geometry with more
rows. Its four timed runs reached 495–503.5 CSS pixels, below the 1320 CSS-pixel
scroll limit. The short and tall pressure fixture SHA-256 values were
`157c3c6e8973e910b18a2a7dad820b5e8bf0f9f9069ea7f470566a8d5b45a679` and
`5cc0a84a101caee62df2bd8f68ddce774e73e6cd7017a8eef3ef7065b0a8e0bf`.

Separate instrumented launches counted cache hits, cropped hits, fresh rasters
and Quartz fallbacks during input. The regular fixture, PID 45276, logged
562 / 130 / 6 / 0. The short pressure fixture, PID 46589, logged
406 / 40 / 21 / 337. The tall pressure fixture, PID 56008, logged
400 / 57 / 16 / 464. All three browser exits were zero. The first diagnostic's
wrapper misread the start record and returned one after the probe had passed.
The corrected wrapper read that receipt and the timings used diagnostics off.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 46798 | Regular | Quartz | 20.13 | 47.695 / 52.029 / 53.216 | 58.43 | 120 / 41 | 103.926 / 0.281 | 4.74 |
| 46989 | Regular | Automatic | 29.61 | 32.397 / 36.453 / 62.776 | 55.07 | 120 / 64 | 73.265 / 17.677 | 4.76 |
| 47178 | Regular | Quartz | 20.07 | 48.161 / 52.312 / 53.115 | 56.87 | 120 / 42 | 108.167 / 0.131 | 4.94 |
| 47364 | Regular | Automatic | 30.55 | 31.699 / 36.051 / 38.416 | 58.63 | 120 / 62 | 72.363 / 0.137 | 5.03 |
| 47551 | Short pressure | Quartz | 7.93 | 64.960 / 550.287 / 550.287 | 59.00 | 120 / 16 | 141.221 / 427.100 | 5.26 |
| 47736 | Short pressure | Automatic | 11.61 | 44.792 / 50.063 / 516.180 | 57.54 | 120 / 24 | 98.124 / 470.272 | 5.56 |
| 47866 | Short pressure | Quartz | 8.36 | 64.633 / 499.224 / 499.224 | 58.52 | 120 / 17 | 138.815 / 419.979 | 5.28 |
| 48048 | Short pressure | Automatic | 11.51 | 44.866 / 50.015 / 546.007 | 57.07 | 120 / 24 | 96.273 / 469.368 | 5.50 |
| 56176 | Tall pressure | Quartz | 9.35 | 102.302 / 112.865 / 112.865 | 58.53 | 120 / 19 | 200.446 / 0.188 | 7.38 |
| 59924 | Tall pressure | Automatic | 12.32 | 75.733 / 82.055 / 83.359 | 58.64 | 120 / 25 | 161.172 / 49.293 | 7.27 |
| 62413 | Tall pressure | Quartz | 9.89 | 95.246 / 103.443 / 106.110 | 58.83 | 120 / 20 | 200.657 / 0.107 | 7.57 |
| 62494 | Tall pressure | Automatic | 13.00 | 72.524 / 79.231 / 79.877 | 59.51 | 120 / 26 | 150.543 / 17.084 | 7.44 |

The cohorts ran 04:46:07–04:46:50 and 04:47:37–04:47:57 UTC on November 18,
2026. Load is the starting one-minute average on the 18-CPU host. Both
fixtures without a scroll clamp improved throughput, median and p95 in both
pairs. The maximum interval increased in one regular pair and in one short
pressure pair. All measured intervals exceeded 16.67 ms. All timed browser
and guard exits were zero. The C generation and compile jobs peaked at
8,184,463,360 and 7,241,416,704 bytes of sampled process-tree RSS. The
first compile command failed when it passed framework flags as single
arguments. The corrected command used the same generated C. The screenshot
guard peaked at 541,966,336 bytes. The timing jobs peaked at 683,769,856 and
600,162,304 bytes.

### Caching linear gradient fills in SVG opacity groups on macOS

The automatic cache accepts up to two supported linear gradients among
the six aligned rectangle fills in a nested or sibling opacity sequence.
The full bitmap still uses the 128 Ki-pixel limit and the existing cache
admission rules. Radial gradients retain the previous eligibility. A new
radial sibling in the initial fixture differed from Quartz by three channel
levels in the forced shared renderer at 1×, so the new route keeps that
sequence on Quartz.

The published single-unit executable
`870e280a166afa2249e1f90dcd8fb7cee701e0614f25414dd12004c9f4472077`
used Quartz for the automatic path on both linear fixtures. Three matched
screenshot sets compared automatic, Quartz and forced shared replay in fresh
processes. The largest channel difference from Quartz was two for the regular
fixture at both scales and for the 30-mask pressure fixture at 2×. All nine
browser exits and the guard exit were zero.

The private single-unit V `-prod`, Clang `-O1` executable SHA-256 was
`5a109f23a1350184a1eacf9f1632cdada3272c161b3a462213dc42ace6312d07`.
All 104 macOS captures passed. The mixed alpha and luminance masks matched
uncached shared rendering pixel for pixel at 1× and 2×, including cropped
viewport hits. The largest 2× channel difference from Quartz was two.
Radial siblings, groups with three gradients and uncached automatic mode
matched explicit Quartz. The native pixel and layer tests passed.

The regular and 75-mask pressure fixtures had SHA-256 digests
`526cd8171ae580d1be70ac5c9d4b00b1837243253e2648a2c67724591bf014e6` and
`b748a2e7db06461df5b1dadf2c0e71882011474419ea1f84b3165bab8cc7d9f5`.
They ran as local files with scripts disabled at 1024 × 600 and 2×, with
fresh processes, caches and private profiles and a one-second title-matched
settle. `tools/measure_precise_scroll.py` delivered 120 four-pixel inputs at a
requested 60 Hz and reversed at 60 inputs. Maximum scroll positions were
487.5–510 CSS pixels, below the bottom of either document. The endpoint was
completed native frame installation after outer view paint over the first-to-last
input window. Each timed pair changed only `VOX_SHARED_SVG_MASK_RASTER` from
`0` to automatic.

Instrumented PID 93723 recorded 638 regular-fixture cache hits, 152 cropped
hits and six fresh rasters during input. Pressure PID 93875 recorded 496 hits,
78 cropped hits, 16 fresh rasters and 568 Quartz fallbacks. The timed launches
used diagnostics off.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 94153 | Regular | Quartz | 23.21 | 41.255 / 45.279 / 45.806 | 57.54 | 120 / 48 | 90.816 / 33.224 | 6.10 |
| 94467 | Regular | Automatic | 33.66 | 28.153 / 33.776 / 57.366 | 56.42 | 120 / 71 | 65.166 / 16.837 | 6.42 |
| 94674 | Regular | Quartz | 22.87 | 41.086 / 44.859 / 83.005 | 56.71 | 120 / 48 | 92.047 / 34.203 | 6.22 |
| 94821 | Regular | Automatic | 34.77 | 27.329 / 32.074 / 34.730 | 59.11 | 120 / 70 | 61.583 / 17.198 | 6.77 |
| 94967 | Pressure | Quartz | 11.91 | 77.080 / 84.254 / 84.847 | 56.67 | 120 / 25 | 161.522 / 66.693 | 6.62 |
| 95158 | Pressure | Automatic | 14.79 | 64.248 / 69.711 / 71.944 | 58.66 | 120 / 30 | 130.891 / 33.739 | 6.57 |
| 95300 | Pressure | Quartz | 10.86 | 85.513 / 93.632 / 98.935 | 58.77 | 120 / 22 | 169.677 / 51.263 | 6.29 |
| 95648 | Pressure | Automatic | 13.65 | 68.947 / 77.796 / 77.894 | 57.99 | 120 / 28 | 135.218 / 48.846 | 6.26 |

The timed cohort ran 04:59:33–05:00:15 UTC on November 18, 2026. Load is
the one-minute average on the 18-CPU host at launch. Throughput, median and
p95 improved in all four pairs. The maximum interval rose in one regular
pair. All measured intervals exceeded 16.67 ms. The timed and instrumented
browsers and their guard exited zero. Peak sampled RSS was 8,142,831,616
bytes for the final build, 479,019,008 for the screenshots and 604,979,200
for the scroll cohort.

### Caching standalone rectangular SVG mask fills on macOS

Automatic selection accepts ordered sequences of up to six pixel-aligned
rectangular fills, including up to two supported linear gradients. Standalone
fills and opacity groups share the same eligibility scan. Single gradients use
their established strip, diagonal and radial paths. The retained bitmap uses
the existing 128 Ki-pixel limit and cache admission rules.

The published single-unit executable
`870e280a166afa2249e1f90dcd8fb7cee701e0614f25414dd12004c9f4472077`
used Quartz automatically on the mixed-fill fixtures. Forced shared replay
stayed within two channel levels of Quartz at 1× and 2× on the regular
fixture and at 2× with 30 different masks. A later published executable
`896b2d35d455afdbb5ec57c6dd5d5759a42e1a15d5f71961ae39fc0d146365cb`
also used Quartz for the three-solid-fill fixture. All 11 baseline browser
exits and both baseline guard exits were zero.

The private single-C-unit V `-prod`, Clang `-O1` executable SHA-256 was
`70a777d3b455065f6ebaefcf72327e8af22edc47c9d4c831f50f167fa54eedb4`.
All 120 macOS captures passed. For both mask modes, cached stand-alone fills
matched uncached shared replay pixel for pixel at 1× and 2×, including viewport
crops. At 2× the solid fixture matched Quartz exactly, and the mixed fixture
and 30-mask pressure capture stayed within two channel levels. The seven-fill
fixture and cache-disabled automatic captures matched Quartz exactly. Native
mask conversion and layer tests passed.

The solid, mixed and 75-mask pressure fixture SHA-256 digests were
`3fd1361bfdef91654571f8d66e90094a400ac5471dca1c55f141583baca4508f`,
`0b632cf00614060ee065220778d3fa2391eeb6f15c3e87a8049c309e43f002a8` and
`7dc1e0579a3f556eaaab306258e2c87047bba6b0a2bf098b045d2b12e2dabcf5`.
These local pages ran with scripts disabled, fresh profiles and caches,
a 1024 × 600 viewport at 2× and a one-second title-matched settle. Each
launch received 120 four-pixel precise inputs at a requested 60 Hz and
reversed at 60 inputs. The endpoint was completed native frame installation
after outer view paint over the first-to-last input window. Each timed pair
changed only `VOX_SHARED_SVG_MASK_RASTER` between `0` and automatic.

Instrumented launches counted cache hits, cropped hits, fresh rasters and
admission fallbacks during input. The solid fixture, PID 25137, recorded
607 / 150 / 6 / 0. The regular mixed fixture, PID 25316, recorded
685 / 173 / 6 / 0. The pressure fixture, PID 25496, recorded
576 / 88 / 16 / 648. Timed launches used diagnostics off.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 25632 | Solid | Quartz | 22.39 | 42.397 / 47.605 / 49.920 | 57.92 | 120 / 46 | 90.501 / 33.129 | 6.35 |
| 25732 | Solid | Automatic | 30.98 | 31.534 / 35.683 / 36.187 | 53.42 | 120 / 69 | 73.088 / 16.863 | 6.32 |
| 25842 | Solid | Quartz | 23.39 | 41.704 / 45.189 / 45.823 | 57.99 | 120 / 48 | 92.122 / 0.096 | 6.05 |
| 25997 | Solid | Automatic | 30.88 | 31.260 / 36.327 / 38.918 | 57.42 | 120 / 64 | 74.880 / 16.743 | 6.21 |
| 26152 | Mixed | Quartz | 28.17 | 34.189 / 38.856 / 40.445 | 55.87 | 120 / 60 | 78.217 / 0.112 | 6.27 |
| 26251 | Mixed | Automatic | 35.22 | 26.589 / 32.778 / 51.333 | 58.22 | 120 / 72 | 63.650 / 16.358 | 6.97 |
| 26350 | Mixed | Quartz | 27.03 | 35.000 / 41.163 / 73.463 | 56.43 | 120 / 57 | 79.633 / 16.706 | 6.57 |
| 26454 | Mixed | Automatic | 35.97 | 26.800 / 31.366 / 52.145 | 57.85 | 120 / 74 | 65.195 / 0.099 | 6.10 |
| 26626 | Pressure | Quartz | 13.84 | 67.026 / 72.523 / 73.432 | 58.83 | 120 / 28 | 147.282 / 49.524 | 5.93 |
| 26732 | Pressure | Automatic | 16.30 | 57.756 / 66.250 / 66.666 | 58.79 | 120 / 33 | 122.977 / 33.169 | 5.85 |
| 26865 | Pressure | Quartz | 14.45 | 66.615 / 69.147 / 69.643 | 59.31 | 120 / 29 | 143.195 / 0.099 | 5.94 |
| 26922 | Pressure | Automatic | 17.64 | 53.816 / 59.282 / 64.738 | 56.74 | 120 / 37 | 121.487 / 16.537 | 5.71 |

The timed cohort ran 05:08:41–05:09:43 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. The timed scroll
positions peaked at 493–510 CSS pixels, below the document limits.
Throughput, median and p95 improved in all six pairs. The maximum interval
rose in one mixed pair. All intervals exceeded 16.67 ms. All diagnostic and
timed browser exits and their guard exit were zero. Sampled process-tree RSS
peaked at 8,147,353,600 bytes during the build, 493,568,000 for the screenshot
suite and 605,487,104 for the scroll job.

### Caching reflected rectangular SVG mask fills on macOS

Axis-aligned reflections qualify when the transformed fill edges land on
whole device pixels. The rectangle check orders the mapped endpoints and
passes the signed transform to shading and the cache key. Horizontal,
vertical and two-axis reflections use the existing bitmap and paint-operation
limits. Fractional reflections use Quartz in automatic mode.

The published single-unit executable
`896b2d35d455afdbb5ec57c6dd5d5759a42e1a15d5f71961ae39fc0d146365cb`
used Quartz automatically. Its reflected solid fixture matched the
unreflected Quartz control exactly. Forced shared replay of the mixed
fixture differed from Quartz by at most two channel levels at 1× and
2×. The 30-mask pressure capture had the same maximum at 2×. The
11 baseline browser exits and the guard exit were zero.

The private single-C-unit V `-prod`, Clang `-O1` executable SHA-256 was
`cccf135b96deecd493908fc028340cf935885bcb7216869b8a0070fc88e48f6f`.
All 136 macOS captures passed. Cached reflected masks matched uncached
shared replay at 1× and 2×, including cropped cache hits. At 2× the solid
fixture matched Quartz exactly and the mixed and pressure fixtures stayed
within two channel levels. Fractional reflections and the cache-disabled
automatic captures matched Quartz exactly. Native mask pixel conversion and
layer tests passed.

The solid, mixed and 75-mask pressure fixture SHA-256 digests were
`f4885e50c7c8d623db57fb1024a72ff28a122fa1b0328124de6ebb143300faba`,
`2e01c984f21f88594b872b344cd8a369167161e067470f7d25ce983d4461ad85` and
`3c8573f99abbf6062ef507f668efacdda401c4902b2a905475d756944c3b6792`.
The local pages ran with scripts disabled, fresh profiles and caches,
a 1024 × 600 viewport at 2× and a one-second title-matched settle.
`tools/measure_precise_scroll.py` delivered 120 four-pixel inputs at a
requested 60 Hz, with a reversal at 60 inputs. The endpoint was completed
native frame installation after outer view paint over the first-to-last
input window. Each timed pair changed only `VOX_SHARED_SVG_MASK_RASTER`
between `0` and automatic.

Separate diagnostics counted cache hits, cropped hits, fresh rasters and
admission fallbacks during wheel input. Solid PID 54913 logged
587 / 144 / 6 / 0. Mixed PID 54994 logged 671 / 171 / 6 / 0.
Pressure PID 55056 logged 592 / 88 / 16 / 662. Timed launches used
diagnostics off.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 55105 | Solid | Quartz | 22.79 | 41.850 / 45.947 / 46.964 | 57.71 | 120 / 47 | 91.070 / 34.330 | 5.51 |
| 55200 | Solid | Automatic | 29.73 | 32.031 / 38.925 / 61.697 | 58.97 | 120 / 60 | 74.900 / 0.261 | 5.31 |
| 55307 | Solid | Quartz | 22.97 | 41.218 / 46.211 / 48.767 | 58.17 | 120 / 47 | 93.071 / 17.217 | 5.45 |
| 55374 | Solid | Automatic | 31.66 | 30.534 / 35.166 / 56.209 | 58.86 | 120 / 64 | 77.085 / 0.098 | 5.25 |
| 55441 | Mixed | Quartz | 27.82 | 34.839 / 39.489 / 40.218 | 57.07 | 120 / 58 | 78.661 / 0.101 | 5.31 |
| 55554 | Mixed | Automatic | 35.36 | 27.185 / 32.223 / 52.838 | 59.26 | 120 / 71 | 61.591 / 16.915 | 5.05 |
| 55612 | Mixed | Quartz | 27.64 | 35.126 / 39.530 / 42.387 | 56.70 | 120 / 58 | 78.855 / 0.121 | 5.12 |
| 55685 | Mixed | Automatic | 35.33 | 27.472 / 32.094 / 52.216 | 58.39 | 120 / 72 | 66.159 / 0.102 | 5.19 |
| 55911 | Pressure | Quartz | 13.69 | 68.525 / 71.770 / 73.463 | 56.16 | 120 / 29 | 143.291 / 49.291 | 5.34 |
| 56100 | Pressure | Automatic | 16.46 | 57.439 / 64.262 / 66.558 | 57.60 | 120 / 34 | 121.001 / 33.299 | 5.31 |
| 56196 | Pressure | Quartz | 13.01 | 70.492 / 76.669 / 149.711 | 57.35 | 120 / 27 | 139.029 / 17.270 | 5.20 |
| 56295 | Pressure | Automatic | 16.65 | 57.282 / 62.571 / 63.758 | 58.29 | 120 / 34 | 112.730 / 18.360 | 5.11 |

The timed cohort ran 05:18:30–05:19:33 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 486–509.5 CSS pixels, below the document limits. Throughput, median
and p95 improved in all six pairs. The solid and mixed automatic trials had
longer maximum scroll-changing intervals at the reversal. Each published
after input 61 at the same scroll position as after input 59, then moved
again after input 62. Maximum gaps across all publications decreased in
every pair, from 46.964–48.767 to 37.011–39.845 ms on the solid fixture,
40.218–42.387 to 33.376–33.457 ms on the mixed fixture and 73.463–76.881
to 63.758–66.558 ms under pressure. Every scroll-changing interval exceeded
16.67 ms. All diagnostic and timed browser exits and their guard exit were
zero. Sampled process-tree RSS peaked at 8,146,255,872 bytes for the build,
497,483,776 for the captures and 599,769,088 for the scroll job.

### Shading strips for reflected SVG gradient masks

The shared rasterizer shades one row or column for pixel-aligned reflected
rectangles. It keeps the signed transform for shade direction. On macOS,
automatic reflection replay uses the strip for luminance masks and for alpha
masks at backing scales of at least 2. Lower-scale reflected alpha uses Quartz.

The published single-unit executable
`604f51df0b16e909d556320a196324d6fb5af2f4b425127326d6c9899a6c46b4`
used Quartz automatically on the reflected alpha fixture at 1×. Forced full
shared shading differed by up to three channel levels on the alpha ramp with
a scaled gradient transform. An eight-capture comparison on the same binary
confirmed the three-level difference at 1× and found at most two levels at
2× and on the luminance fixture at both scales. The first guard exited one
when it reached the three-level result. All comparison browser exits and
the second guard exit were zero.

The reflected alpha and luminance fixture SHA-256 digests were
`1fa08445c0ee140c80ea47836ebe7f0d361b3a818f533d70abbf366efe0d0533` and
`5bd7a0fbe3629603977396e80769157720e14b4fde21ae2e3def12b91552c853`.
In the arm64 Linux guest, a single-C-unit Clang `-O0` executable
(`9aeba8065fc8937380fa4f89f1d3fa116075b896213754d3689402e4a90a9788`)
matched full shading pixel for pixel on both reflected fixtures at X11
backing scale, using software OpenGL. Separate processes with fresh
profiles exercised the strip and full-shader controls under Xvfb. The
19-check Linux browser smoke suite passed. The Linux build and test guards
exited zero at 6,007,660,544 and 1,132,670,976 bytes peak sampled RSS.

The macOS candidate was single-C-unit V `-prod`, Clang `-O1`, SHA-256
`9f84db1ea3f5f113762d165e34edf1a69e225583ef7732539de3e1a2fe06c433`.
All 155 captures passed. Reflected strips matched full shading pixel for
pixel at 1× and 2×. Automatic reflected luminance and 2× alpha captures
matched their cached controls exactly, including viewport clipping. They
stayed within two channel levels of Quartz. The automatic 1× reflected
alpha and fractional reflections matched explicit Quartz exactly. Native
mask conversion and layer tests passed.

The macOS scroll trials used local files, no script execution, fresh
profiles and caches, a 1024 × 600 viewport at 2× and a one-second title-matched
settle. `tools/measure_precise_scroll.py` sent 120 four-pixel inputs at a
requested 60 Hz, reversing at 60 inputs. The endpoint was completed native
frame installation after outer view paint over the first-to-last input window.
Quartz and automatic pairs kept caching enabled and changed only
`VOX_SHARED_SVG_MASK_RASTER`. The forced shared luminance pairs left caching
off and changed only `VOX_DISABLE_SVG_MASK_RAMP`.

Separate diagnostics counted shaded strips, cache hits and cropped hits
during input. Alpha PID 11900 recorded 6 / 595 / 147. Luminance PID 12105
recorded 6 / 583 / 138. The uncached luminance diagnostic, PID 12334,
recorded 468 strips and zero hits. Timing launches disabled diagnostics.

| PID | Fixture | Raster | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 12571 | Alpha | Quartz | 25.47 | 37.699 / 44.728 / 48.027 | 56.13 | 120 / 54 | 77.657 / 33.251 | 10.78 |
| 12718 | Alpha | Automatic | 33.05 | 28.938 / 35.894 / 57.849 | 56.19 | 120 / 70 | 67.023 / 0.134 | 10.80 |
| 12878 | Alpha | Quartz | 27.83 | 34.060 / 41.454 / 69.976 | 55.19 | 120 / 60 | 72.634 / 0.147 | 10.49 |
| 13030 | Alpha | Automatic | 32.02 | 29.493 / 37.119 / 38.742 | 58.62 | 120 / 65 | 66.853 / 16.815 | 10.61 |
| 13188 | Luminance | Quartz | 27.96 | 34.020 / 40.974 / 69.352 | 55.45 | 120 / 60 | 76.216 / 0.129 | 10.44 |
| 13334 | Luminance | Automatic | 33.48 | 29.065 / 34.403 / 36.007 | 56.91 | 120 / 70 | 67.719 / 0.152 | 10.88 |
| 13499 | Luminance | Quartz | 27.93 | 34.439 / 40.752 / 65.574 | 54.49 | 120 / 61 | 73.024 / 0.124 | 10.73 |
| 13669 | Luminance | Automatic | 32.25 | 29.367 / 36.041 / 55.967 | 58.15 | 120 / 66 | 67.315 / 16.762 | 10.51 |
| 13834 | Luminance | Full shader | 22.46 | 42.815 / 48.239 / 48.843 | 54.55 | 120 / 49 | 89.757 / 34.915 | 10.63 |
| 13995 | Luminance | Strip | 29.68 | 31.994 / 38.642 / 59.656 | 56.97 | 120 / 62 | 66.941 / 19.695 | 10.58 |
| 14144 | Luminance | Full shader | 19.57 | 48.459 / 57.859 / 58.161 | 55.46 | 120 / 42 | 103.631 / 36.203 | 10.21 |
| 14381 | Luminance | Strip | 26.30 | 36.628 / 43.288 / 46.759 | 54.91 | 120 / 57 | 78.780 / 19.602 | 10.12 |

The timed cohort ran 05:35:57–05:37:02 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 501–510 CSS pixels. Throughput, median and p95 improved in all six
pairs. The first automatic alpha and first uncached strip trials published
at the same scroll position after inputs 59 and 61 before moving after input
62. Both had a longer maximum gap between position changes. The longest gap
between any two native publications decreased in every pair. Every measured
scroll-changing interval exceeded 16.67 ms. All timed and instrumented
browsers and their guard exited zero. Peak sampled RSS was 8,155,660,288
bytes for the final build, 497,958,912 for the captures and 608,698,368 for
the scroll job.

### Fixed-size SVG rectangle checks

SVG rectangle recognition stores its four corners in a fixed array. An
optional line back to the first corner is checked directly. Shared mask
rectangle alignment and the macOS mask-region check iterate fixed arrays of
four edges. Generated C for the previous published build used a dynamic
point array and two dynamic edge arrays on this path. The candidate emitted
no array allocation or append calls in the three checks.

The single-C-unit V `-prod`, Clang `-O1` comparison harness used both sets
of geometry checks with the production geometry field types and packed
segment stride. It checked all 64 input records for identical eligibility
and returned bounds before timing. Each of seven pairs used fresh processes,
alternating which variant ran first. Each process ran two workloads of
2,000,000 checks with prepared inputs. Timers covered geometry checks and
result checksumming, with process launch and input preparation outside.
The executable SHA-256 was
`2d57fd42e83795c47a5bbd2109a5efa6a8e9ef92da76c67a2331d08ca34866fa`.

| Workload | Accepted checks | Median before / fixed (ms) | Before range (ms) | Fixed range (ms) | Checksum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Aligned rectangles | 2,000,000 | 125.535 / 95.728 | 120.173–127.843 | 94.031–97.336 | 4546511169908150597 |
| Mixed eligibility | 250,000 | 57.933 / 42.653 | 55.063–58.865 | 41.846–45.804 | 7602596038793500197 |

The checksums matched across all runs. Both workloads improved in every
pair. The cohort ran 05:45:36–05:45:38 UTC on November 18, 2026, with a
one-minute host load of 13.42 on 18 CPUs and other compiler jobs active.
The 14 processes and the 3 GiB guard exited zero. Peak sampled process-tree
RSS was 651,755,520 bytes.

The focused `chromium/rounded_svg_background_test.v` file passed, including
an explicit line back to the first corner and rejection checks for a curved
closing segment and a misplaced endpoint. The test guard exited zero.

All 155 macOS mask captures passed on the single-unit V `-prod`, Clang `-O1`
candidate (`6ff6ea6a7421011989894c17a7a9cce1616bf81b275d10c791ed4ae738a49e27`).
Twelve additional fresh captures compared the candidate with the published
executable (`19554c666e7ef07de44937357e3a2f37df63bc26d8347bd4830a133c38be1766`).
The rounded SVG background, transformed rectangular clip and overlapping
solid mask fixtures matched pixel for pixel at 1× and 2×. These local
captures used a 1024 × 600 viewport, private profiles and scripts disabled.
Their fixture SHA-256 digests were
`52f45dc0717159947ba655db78000f2e702a96b1f9c3ff457fc747d207b124b7`,
`8454f39d3d14e943da9983cf5a46c61e9d6ec09103e8015b3bc35147967f817f` and
`014ff8fe50e532a757b267173b04d324f1cd8ea1f242ae5d7a9f5e5901bc9e4b`.
The browser build, captures and comparison guards exited zero. Their sampled
RSS peaks were 8,152,825,856, 498,024,448 and 325,074,944 bytes.

The first arm64 Linux build was killed with exit 137 while the V frontend
and Clang overlapped. The split build emitted C, then linked a single unit
with Clang `-O0`. The flags dump omitted the STB image object, so the final
link compiled the matching `stbi.c` from the guest V toolchain. Its executable
SHA-256 was `b16fb498da7f666edb010f7036d74a3db459ff4e0e8496a35797e339eadb7832`.
All 19 Linux browser smoke checks passed under Xvfb with software OpenGL.
The final link and test guards exited zero, with sampled RSS peaks of
1,823,965,184 and 1,103,851,520 bytes.

### Reusing SVG mask geometry validation on macOS cache hits

The shared raster lookup precedes rectangle recognition for retained radial,
diagonal, grouped and solid-fill rasters. The cache key identifies the mask's
path data, device matrices and raster bounds. A miss runs geometry
recognition. Mask eligibility and single-gradient strip selection run before
lookup.

The geometry mutation fixture first draws two cacheable masks. JavaScript
replaces one rectangle with a triangle of the same bounds and translates the
other by a quarter CSS pixel. The resulting screenshot must match Quartz,
including at the translated edge. The published executable
`ea5cc7a3d626c8fdef30c81044f1e9a78976d20c1c5726245d8a335b1950bb74`
passed the fixture in three fresh launches.

All 158 macOS captures passed on the single-C-unit V `-prod`, Clang `-O1`
candidate (`c5b85a1fb95dc2c3ca4398ac3e5eb5c463ac66e3a720b3e0cb10c8c779059d16`).
The native mask pixel-conversion and layer tests passed. The timing control
(`de640550ee459c0fd59c4264bfd806d6bdd4905d2a0130dff33445586d499a09`)
used the same generated C and Clang flags with the rectangle validation
block moved immediately before the lookup. The original generated C digest
was `1b3714a48cd2d404d036d49193822a8555f79c2524b62275ec0729a22861656f`.

Six fresh 2× captures at a 132 CSS-pixel scroll offset matched before and
after pixel for pixel on the overlap, pressure and fractional fixtures.
The fixture SHA-256 digests were
`014ff8fe50e532a757b267173b04d324f1cd8ea1f242ae5d7a9f5e5901bc9e4b`,
`b748a2e7db06461df5b1dadf2c0e71882011474419ea1f84b3165bab8cc7d9f5` and
`1843231e99f39e4b1bd32e187855b56acb62879025c0a951367af0a5b1bb55f8`.
The pressure fixture had 75 masks with three paths each under sibling
opacity groups. The fractional fixture used the overlap page with one
fill in each mask translated by a quarter CSS pixel to exercise rejection.

`tools/measure_precise_scroll.py` delivered 120 four-pixel inputs at a
requested 60 Hz and reversed at 60 inputs. The tests used local files,
scripts disabled, fresh profiles and caches, a 1024 × 600 viewport at 2×
and a one-second title-matched settle. The endpoint was completed native
frame installation after outer view paint over the first-to-last input
window.

Separate instrumented launches checked the paths during wheel input. On the
overlap fixture, PID 85677 logged 642 hits, 162 cropped hits and six new
rasters. Two fills per hit account for 1,284 skipped rectangle checks. On
the pressure fixture, PID 85791 logged 528 hits, 78 cropped hits, 16 new
rasters and 601 admission fallbacks. Three fills per hit account for 1,584
skipped checks. The fractional fixture, PID 85898, logged neither a shared
raster nor a cache hit. The paired timing runs disabled diagnostics.

| PID | Fixture | Order | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 86000 | Overlap | Before | 33.71 | 28.579 / 33.315 / 35.547 | 58.99 | 120 / 68 | 66.871 / 16.739 | 6.19 |
| 86103 | Overlap | After | 33.95 | 29.001 / 33.309 / 34.347 | 57.71 | 120 / 70 | 65.727 / 16.594 | 6.01 |
| 86252 | Overlap | Before | 32.96 | 29.240 / 34.844 / 53.430 | 58.54 | 120 / 67 | 66.034 / 17.081 | 6.01 |
| 86350 | Overlap | After | 34.20 | 27.764 / 32.653 / 51.983 | 58.98 | 120 / 69 | 65.786 / 16.741 | 5.77 |
| 86448 | Pressure | Before | 15.33 | 61.305 / 69.768 / 73.784 | 58.85 | 120 / 31 | 125.879 / 16.776 | 5.95 |
| 86655 | Pressure | After | 15.27 | 61.332 / 68.879 / 69.624 | 58.62 | 120 / 31 | 127.089 / 50.172 | 5.79 |
| 86903 | Pressure | Before | 16.26 | 58.676 / 63.772 / 65.198 | 58.63 | 120 / 33 | 123.414 / 16.746 | 5.89 |
| 87034 | Pressure | After | 16.11 | 59.697 / 65.844 / 66.690 | 59.90 | 120 / 32 | 124.324 / 0.118 | 5.83 |
| 87144 | Fractional | Before | 25.52 | 37.630 / 43.690 / 45.961 | 56.24 | 120 / 54 | 87.411 / 18.101 | 5.76 |
| 87257 | Fractional | After | 25.78 | 37.366 / 42.501 / 45.293 | 56.82 | 120 / 54 | 82.201 / 0.133 | 5.78 |
| 87363 | Fractional | Before | 25.18 | 38.408 / 42.931 / 45.472 | 57.63 | 120 / 52 | 86.024 / 18.551 | 5.64 |
| 87459 | Fractional | After | 24.83 | 37.884 / 43.687 / 48.117 | 59.09 | 120 / 50 | 80.301 / 35.411 | 5.58 |

The timed cohort ran 06:04:23–06:05:25 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Scroll positions
peaked at 493.5–510 CSS pixels. Overlap throughput rose in both pairs,
pressure throughput fell by 0.4% and 0.9%, and the fractional pair changes
were +1.0% and −1.4%. The largest interval grew in the second pressure
and fractional pairs. All measured intervals exceeded 16.67 ms. All
capture, instrumented and timed browser exits and their guards were zero.
Peak sampled RSS was 8,205,336,576 bytes for the candidate build,
6,611,386,368 for the control build, 495,616,000 for the screenshot suite
and 637,452,288 for the scroll job.

### Checking SVG mask cache capacity before rectangle recognition

For shared rasters that require a cache entry, a lookup miss checks admission
before recognizing the fill rectangles. The admission query reads the native
cache. A capacity fallback can therefore return to Quartz without walking
path geometry.

The grouped-gradient pressure fixture adds a fractional solid mask after the
grouped fills in paint order. Its diagnostic label identifies a capacity
fallback separately from the grouped masks. On the published executable
`eb9c83cc14fe48f533dcf68e7dbc3e4c871426aa6aa110d3e65a570d961f22a1`, the
fractional fill rejected geometry before admission. Its visible pixels matched
Quartz exactly. Both fresh comparison captures exited zero.

The private candidate used single-unit V `-prod`, Clang `-O1`, with
executable SHA-256
`c94058e958d1e4774a0bd9a405054797a3043db1e432ef0ac2e66128ca9cd091`.
The timing control moved the geometry block before admission in the same
generated C and used the same Clang flags. Its executable SHA-256 was
`d6909dd960be6655ec7977adbb200148deb1c619388721b643cb1f3f9c74887a`.
The original generated C SHA-256 was
`b4081dc68f7067ee0c8faabded4a5a269f9de902a1457089d8b6aee3715bf3f6`.

All 158 macOS mask captures passed. The fractional fill's 2× pixels matched
Quartz exactly, and the new capacity diagnostic appeared for that fill. The
native conversion and layer tests passed. The fixture SHA-256 values for the
75-mask pressure page, overlapping solid masks, and the pressure page with
the fractional fill were
`b748a2e7db06461df5b1dadf2c0e71882011474419ea1f84b3165bab8cc7d9f5`,
`014ff8fe50e532a757b267173b04d324f1cd8ea1f242ae5d7a9f5e5901bc9e4b` and
`90452e2ac51bba709111edcc8f2481093a4c86eb5d197ec33f664284788e4bf6`.

The timing protocol used fresh processes, profiles and caches, local pages
with JavaScript disabled, and a 1024 × 600 viewport at 2×. After a one-second
title-matched settle, `tools/measure_precise_scroll.py` delivered 120
four-pixel inputs at a requested 60 Hz and reversed at 60 inputs. The endpoint
was completed native frame installation after outer view paint over the
first-to-last input window.

Six captures matched the before and after builds pixel for pixel. The
pressure and overlap fixtures used a 132 CSS-pixel scroll offset, and the
fractional test used 42 CSS pixels. An instrumented pressure launch,
PID 18095, recorded 528 retained hits, 88 cropped hits, 16 new rasters and
601 admission fallbacks during input. Each denied mask had three paths, so
the new order skipped 1,803 rectangle checks. The overlap launch, PID 18206,
recorded 651 hits, 163 cropped hits, six new rasters and zero admission
fallbacks. Timing launches disabled diagnostics.

| PID | Fixture | Order | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 18303 | Pressure | Before | 15.46 | 58.154 / 66.235 / 122.933 | 59.34 | 120 / 31 | 121.760 / 51.989 | 6.08 |
| 18402 | Pressure | After | 16.33 | 57.260 / 61.656 / 65.297 | 58.90 | 120 / 33 | 127.642 / 51.613 | 5.92 |
| 18525 | Pressure | Before | 16.68 | 57.214 / 63.855 / 64.785 | 58.40 | 120 / 34 | 124.750 / 0.267 | 6.00 |
| 18626 | Pressure | After | 15.36 | 60.934 / 67.445 / 67.525 | 58.96 | 120 / 31 | 127.039 / 49.743 | 5.77 |
| 18931 | Pressure | Before | 16.03 | 59.179 / 66.611 / 66.885 | 59.61 | 120 / 32 | 126.275 / 17.957 | 5.71 |
| 19079 | Pressure | After | 15.68 | 59.115 / 71.092 / 121.518 | 56.54 | 120 / 33 | 123.225 / 0.262 | 6.22 |
| 19215 | Overlap | Before | 33.47 | 28.637 / 33.234 / 36.270 | 57.73 | 120 / 69 | 70.546 / 16.464 | 6.04 |
| 19322 | Overlap | After | 33.27 | 28.945 / 34.060 / 35.674 | 59.09 | 120 / 67 | 66.874 / 16.699 | 5.87 |
| 19417 | Overlap | Before | 32.87 | 28.829 / 34.733 / 37.077 | 58.38 | 120 / 67 | 68.265 / 16.767 | 5.96 |
| 19519 | Overlap | After | 33.74 | 28.501 / 33.430 / 34.102 | 57.36 | 120 / 70 | 66.502 / 16.425 | 5.81 |

The timed cohort ran 06:16:35–06:17:27 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 484.5–510 CSS pixels. Pressure throughput rose in one pair and fell
in two. Overlap throughput rose in one pair and fell in the other. Both
long pressure gaps above 120 ms straddled the reversal, with a publication
at the same scroll position after inputs 58 and 62. All measured intervals
exceeded 16.67 ms. The capture, diagnostic and timed browsers and guards
exited zero. The candidate build, control build, screenshot suite and scroll
job peaked at 7,369,539,584, 7,105,593,344, 488,194,048 and 641,040,384 bytes
of sampled process-tree RSS.

### Reusing the SVG mask cache replacement slot

The macOS raster cache normally keeps its selected replacement slot across
admission checks. A store or a hit that can change the selection invalidates
it. Admission still reads the slot's current age on each call. The existing
capacity, frame protection and tie-breaking order apply.

The native test compared 4,096 mixed queries with the original scan. It also
checked empty slots, tied timestamps, clock wrap and protection across frame
wrap. The layer and pixel conversion tests passed. A separate Clang `-O1`
microbenchmark made eight million consecutive denied queries per arm with a
full cache and alternating current and preceding frame ages. Across seven
alternating pairs, median query time was 5.409 ns with the scan and 0.759 ns
with the cached slot. The microbenchmark isolates the admission call.

The first private build was discarded for comparison after a concurrent
native header edit. The paired builds reused one generated C unit from V
`-prod`, compiled with Clang `-O1 -fno-lto`. The control used the native
bridge from `267914943`. The preprocessed bytes outside the native bridge
and new cache header matched before compilation.

The generated C SHA-256 was
`f049b80cc97480230e37567b1d59e2b1c5849473c4ca3b3a1db1d0f998741554`.
The paired executable SHA-256 values were
`18b9a6e480b2d4c8e290fde05303bd2f7a8e4239899ab989618ecc002bbe7b68` for the
control and `cec9e1601df71910d767ec0427a363fe82d98b181e6ebd77bc6aa1ee82042fc4`
for the candidate. All 158 macOS mask captures passed on the candidate.
At a 132 CSS-pixel scroll offset the paired 2× captures matched pixel for
pixel. The browser logs agreed on all 385 pressure and 106 overlap mask
decisions across those captures.

The wheel trials used the same 75-mask pressure and overlapping solid-mask
fixtures as the preceding section. The driver used fresh processes, profiles
and browser caches, local files, JavaScript disabled and a 1024 × 600
viewport at 2×. Host caches were retained. After a one-second title-matched
settle, it sent 120 four-pixel inputs at a requested 60 Hz, reversing after
60 inputs. Throughput counts scroll-changing native frame installations
after outer view paint over the first-to-last input window.

From `SCROLL_START` through the final publication, a separate diagnostic
pressure launch (PID 62552) logged 592 capacity denials, 512 hits including
78 crops, and 16 new rasters. Overlap (PID 62644) logged zero denials, 648
hits including 159 crops, and six new rasters. The timed launches ran with
the mask diagnostics disabled.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 62749 | Pressure | Before | 16.72 | 56.403 / 61.950 / 65.487 | 58.50 | 120 / 34 | 119.612 / 33.171 | 4.83 |
| 62816 | Pressure | After | 16.62 | 57.194 / 63.832 / 66.152 | 59.93 | 120 / 33 | 121.435 / 16.994 | 4.79 |
| 62869 | Pressure | After | 16.90 | 56.570 / 62.890 / 64.675 | 59.14 | 120 / 34 | 123.592 / 16.985 | 4.81 |
| 62924 | Pressure | Before | 16.06 | 56.609 / 63.814 / 116.701 | 57.90 | 120 / 33 | 119.491 / 50.865 | 4.98 |
| 63002 | Pressure | Before | 16.10 | 57.514 / 63.827 / 116.412 | 58.06 | 120 / 33 | 123.824 / 17.589 | 4.90 |
| 63085 | Pressure | After | 14.61 | 61.836 / 71.366 / 131.861 | 57.95 | 120 / 30 | 126.876 / 48.997 | 4.99 |
| 63256 | Overlap | Before | 33.34 | 29.011 / 34.082 / 36.429 | 58.35 | 120 / 68 | 67.225 / 16.497 | 4.99 |
| 63318 | Overlap | After | 34.46 | 27.872 / 32.792 / 35.942 | 57.76 | 120 / 71 | 63.979 / 16.601 | 4.99 |
| 63387 | Overlap | After | 34.21 | 27.796 / 33.043 / 51.223 | 58.15 | 120 / 70 | 69.507 / 16.412 | 4.91 |
| 63447 | Overlap | Before | 34.04 | 28.532 / 33.890 / 34.806 | 58.71 | 120 / 69 | 63.866 / 16.841 | 4.76 |
| 63555 | Overlap | Before | 34.49 | 27.830 / 33.745 / 35.437 | 59.48 | 120 / 69 | 67.101 / 0.255 | 4.70 |
| 63611 | Overlap | After | 33.59 | 28.303 / 33.610 / 53.167 | 56.29 | 120 / 71 | 66.539 / 16.377 | 4.48 |

The cohort ran 06:33:36–06:34:39 UTC on November 18, 2026. Load is the
one-minute average at launch on the 18-CPU host. Peak scroll positions
were 484.5–510 CSS pixels. Throughput varied across pairs for both fixtures.
All measured intervals exceeded 16.67 ms. The three pressure gaps above
100 ms and the two overlap gaps above 50 ms straddled the input reversal.
All browsers and guards in the sealed cohort exited zero. The sealed build,
screenshot and comparison jobs peaked at 6,721,585,152, 459,997,184 and
638,713,856 bytes of sampled process-tree RSS.

### Publishing Quartz color masks in place

The Quartz fallback converts its premultiplied RGBA bitmap to coverage in
place and takes a Core Graphics snapshot. The shared raster uses the same
publisher. The copy path expands alpha-only clip bitmaps into RGBA and
handles snapshot failures. It can retry a failed snapshot because the
premultiplied white pixels have equal luminance and alpha.

The native tests passed 16 exact publication comparisons across alpha and
luminance, clipping and destination-in, sRGB and Display P3 destinations,
and direct and cropped placements. The layer, cache and exhaustive pixel
conversion checks also passed.

A Clang `-O1` harness timed snapshot or copy publication through release of
the source context. It created and drew the source before timing and
verified the composited pixel hash afterward. Seven alternating pairs used
fresh processes for each size and mode. Each small process published 51
masks and each large process published 17. Warm times use the medians after
the first sample of each process. All 56 processes matched their fixture's
control pixel hash and exited zero. One-minute load ranged
from 8.26 to 8.67 on 18 logical CPUs.

| Mask | First before / after (µs) | Warm before / after (µs) | Faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 276 × 184 alpha | 747.958 / 697.709 | 55.270 / 40.500 | 5/7 / 7/7 |
| 276 × 184 luminance | 717.709 / 660.500 | 61.167 / 41.792 | 5/7 / 7/7 |
| 1902 × 1284 alpha | 1856.500 / 1511.375 | 1020.250 / 584.646 | 7/7 / 7/7 |
| 1902 × 1284 luminance | 1929.416 / 1393.916 | 1069.333 / 601.229 | 7/7 / 7/7 |

The harness SHA-256 was
`68f6cbfcbb28d365951e9b5cae1456ec72ae90871b678165eac520db4fb69c18`.

A second harness included the destination-in draw, image release and
destination flush. It timed publication and drawing around the excluded
destination allocation and fill. Every output matched its control hash.
Across seven alternating pairs per row, the candidate improved every warm
pair. Host load ranged from 6.16 to 6.94. The harness SHA-256 was
`0cab4251b88f2573072996d065ae107b886aff132dc5bc5759cc90ae1401d181`.

| Destination | Mask | First before / after (µs) | Warm before / after (µs) | Faster pairs, first / warm |
| --- | --- | ---: | ---: | ---: |
| sRGB | 276 × 184 alpha | 600.458 / 572.958 | 59.520 / 48.417 | 5/7 / 7/7 |
| sRGB | 276 × 184 luminance | 569.042 / 555.583 | 60.584 / 48.813 | 6/7 / 7/7 |
| sRGB | 1902 × 1284 alpha | 2242.501 / 1945.958 | 1423.062 / 1203.624 | 6/7 / 7/7 |
| sRGB | 1902 × 1284 luminance | 2267.792 / 2053.292 | 1483.374 / 1200.792 | 6/7 / 7/7 |
| Display P3 | 276 × 184 alpha | 834.001 / 832.208 | 211.145 / 196.417 | 4/7 / 7/7 |
| Display P3 | 276 × 184 luminance | 799.459 / 785.833 | 214.104 / 199.645 | 4/7 / 7/7 |
| Display P3 | 1902 × 1284 alpha | 8162.792 / 8163.292 | 7618.209 / 7177.709 | 3/7 / 7/7 |
| Display P3 | 1902 × 1284 luminance | 8262.041 / 7670.209 | 7706.688 / 7312.146 | 6/7 / 7/7 |

The private browsers shared one generated C unit from V `-prod` and used
single-unit Clang `-O1 -fno-lto`. An unrelated Retina PNG metadata change
landed during compilation. The first wheel cohort used a control without
that change and was excluded. Its three pressure pairs measured
15.25 → 13.81, 13.44 → 14.60 and 13.25 → 13.86 scroll fps. Its overlap
pairs measured 27.82 → 28.71, 27.42 → 27.10 and 30.08 → 28.99 scroll fps.
The matched control incorporated the same metadata statement into the
sealed unit. The compiler inputs matched outside the mask publication
functions and header.

The generated C SHA-256 was
`b4aaa0545a33da6b7db94fed8a3e66adda0cb60fb422f1425b975628f3485f61`.
The executable hashes were
`530f4bd2d2d6db0c34ed7ca331e568db8653af1bd60e18556f8566a62d7ffc95` for the
matched control and
`03c77bc5c67c800bd74cb54c19d04cf02e0bbc645240a3a0c91f3790009c726d` for the
candidate. The candidate passed all 158 macOS SVG mask captures. In the
matched comparison, four 2× capture pairs agreed on every pixel. Those
included the default pressure and overlap workloads, plus the pressure
and nested gradient-opacity fixtures with Quartz forced. The default
pressure and overlap logs agreed on 385 and 116 shared-mask decisions.

The wheel trials used the same 75-mask pressure and overlap files as the
preceding section. Each run used a fresh process, profile and browser
cache, a local file, JavaScript disabled and a 1024 × 600 viewport at 2×.
Host caches were retained. A one-second title-matched settle preceded 120
four-pixel wheel inputs at a requested 60 Hz, reversing after input 60.
Throughput counts scroll-changing native frame installations after outer
view paint over the first-to-last input window.

A separate diagnostic launch on pressure (PID 5136) reported 568 Quartz
fallbacks for denied cache admission, 496 hits including 73 crops, and 16
new rasters between the start marker and final publication. The overlap
launch (PID 5390) reported zero capacity denials, 622 hits including 155
crops, and six new rasters. Timed launches disabled mask diagnostics.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 5606 | Pressure | Before | 17.11 | 56.241 / 61.336 / 63.305 | 59.89 | 120 / 34 | 120.840 / 16.591 | 6.68 |
| 5740 | Pressure | After | 16.86 | 56.985 / 63.537 / 64.871 | 59.00 | 120 / 34 | 119.766 / 0.092 | 6.38 |
| 5852 | Pressure | After | 16.41 | 57.350 / 62.063 / 63.258 | 59.19 | 120 / 33 | 120.173 / 49.721 | 6.35 |
| 5949 | Pressure | Before | 16.36 | 57.569 / 65.419 / 70.213 | 59.00 | 120 / 33 | 119.741 / 18.733 | 6.40 |
| 6035 | Pressure | Before | 17.19 | 56.032 / 60.202 / 62.356 | 58.43 | 120 / 35 | 122.216 / 0.248 | 6.21 |
| 6091 | Pressure | After | 15.94 | 57.562 / 64.483 / 116.434 | 57.47 | 120 / 33 | 123.732 / 48.983 | 6.03 |
| 6149 | Overlap | Before | 33.56 | 28.368 / 33.951 / 53.576 | 58.72 | 120 / 68 | 66.902 / 16.635 | 5.71 |
| 6216 | Overlap | After | 32.91 | 28.722 / 34.275 / 53.099 | 56.75 | 120 / 69 | 66.191 / 16.474 | 5.73 |
| 6384 | Overlap | After | 33.67 | 28.789 / 33.924 / 35.278 | 58.07 | 120 / 69 | 66.673 / 16.601 | 6.14 |
| 6849 | Overlap | Before | 29.33 | 32.694 / 42.703 / 54.551 | 57.21 | 120 / 61 | 73.437 / 16.921 | 5.88 |
| 8075 | Overlap | Before | 32.16 | 30.118 / 34.767 / 37.762 | 57.12 | 120 / 67 | 74.589 / 0.132 | 7.09 |
| 8327 | Overlap | After | 31.56 | 29.993 / 35.793 / 54.474 | 56.90 | 120 / 66 | 70.144 / 17.085 | 7.17 |

The matched cohort ran 06:50:44–06:51:48 UTC on November 18, 2026.
Load is the one-minute average at launch on the 18-CPU host. Peak scroll
positions were 484.5–510 CSS pixels. Median pressure throughput fell from
17.11 to 16.41 fps, and median overlap throughput rose from 32.16 to 32.91
fps. Both fixtures slowed in two of three pairs. All measured intervals
exceeded 16.67 ms. All browser, native test and guard exits were zero.
Peak sampled process-tree RSS was 8,212,135,936 bytes for the original
build job, 6,528,106,496 for the matched control rebuild, 471,252,992 for
the screenshot suite, and 638,976,000 for the matched comparison.

### Bounding rectangular GG SVG mask fills on macOS

The Quartz mask bridge stages an uncomposited GG path image before applying
the current clip and opacity. A contained rectangular fill with exactly
integral device edges now stages its ink bounds and a one-pixel fringe.
The bridge rebases the GG transform to that bitmap and restores the image
placement in the original Quartz context. Strokes, fractional edges,
skew, and rectangles that cross the bitmap boundary use full staging.

Six native placement checks compared cropped and full staging over a
partially clipped backdrop. They covered ordinary and reflected fills,
scaling, fractional translation, skew and out-of-bounds geometry. The
16 native layer scenes, 16 mask publications, cache checks and exhaustive
conversion checks passed.

The browser pair shared one V `-prod` generated C unit and used single-unit
Clang `-O1 -fno-lto`. The preprocessed inputs matched outside the mask-path
header and its native call. The generated C SHA-256 was
`122be60004c69f19247efa757e6b495f28db6641440707b64bf3e8227b121430`.
The control and candidate executable SHA-256 values were
`818fd1de212606da201f2f3da0bda432957d0dbd0ba51c083e406a320a0ec9ed` and
`42b82dd61860f73d7d4e5990d11d30a9acdcf805c5e6b0d9c7b9daebe2f0528d`.

The candidate passed all 158 macOS mask captures. Four paired 2× captures
matched every decoded pixel. They used the default pressure and overlap
fixtures, the same pressure fixture with the shared raster disabled, and
a Quartz fixture with reflected, fractional and rotated rectangles. The
default builds logged the same 385 pressure and 106 overlap mask decisions.

An LLDB trace of the Quartz rectangle fixture measured the arguments at
`draw_document_path_pixels` entry on the two pinned executables. The
control (PID 70034) used four 280 × 188 readbacks. The candidate (PID 70087)
used 58 × 130 and 94 × 182 for the two integral fills and 280 × 188 for the
fractional and rotated fills. Total staged pixels fell from 210,560 to
129,928, a 38.3% reduction. The traced PNGs matched every decoded pixel.
Both browsers and the guard exited zero. The first diagnostic attempt
stopped at the allocator's startup `exec`. The recorded trace let LLDB
continue across it. The trace is separate from the wheel timing.

The precise wheel trials used fresh processes, profiles and browser caches
with the same local pressure and overlap fixtures as the preceding section.
They used a 1024 × 600 viewport at 2×, disabled JavaScript and retained host
caches. After a one-second title-matched settle the driver sent 120
four-pixel inputs at a requested 60 Hz, reversing after 60 inputs. The
endpoint counts scroll-changing native frame installations after outer
view paint over the first-to-last input window.

The separate pressure diagnostic (PID 67099) recorded 615 capacity denials,
544 shared hits including 83 crops, and 16 new shared rasters through the
final publication. Overlap (PID 67233) recorded zero capacity denials,
632 hits including 154 crops, and six new rasters. Timing used the default
renderer configuration with mask diagnostics disabled.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 67363 | Pressure | Before | 16.93 | 54.531 / 62.704 / 109.816 | 55.96 | 120 / 36 | 120.133 / 32.940 | 6.19 |
| 67509 | Pressure | After | 17.68 | 54.078 / 58.831 / 61.910 | 58.43 | 120 / 36 | 118.410 / 0.269 | 5.94 |
| 67639 | Pressure | After | 16.48 | 55.849 / 65.568 / 115.645 | 57.69 | 120 / 34 | 119.459 / 34.972 | 5.78 |
| 67741 | Pressure | Before | 16.30 | 56.981 / 63.121 / 117.252 | 57.06 | 120 / 34 | 125.273 / 17.015 | 5.56 |
| 67854 | Pressure | Before | 15.60 | 60.015 / 63.895 / 65.483 | 59.89 | 120 / 31 | 123.741 / 49.735 | 5.27 |
| 67982 | Pressure | After | 15.09 | 63.100 / 68.403 / 69.168 | 57.91 | 120 / 31 | 128.069 / 34.147 | 5.01 |
| 68149 | Overlap | Before | 33.81 | 28.355 / 33.355 / 51.391 | 55.88 | 120 / 72 | 66.262 / 16.498 | 5.09 |
| 68264 | Overlap | After | 34.48 | 27.441 / 33.486 / 51.981 | 56.21 | 120 / 73 | 64.789 / 0.109 | 5.15 |
| 68364 | Overlap | After | 34.32 | 28.027 / 33.437 / 34.817 | 58.34 | 120 / 70 | 67.484 / 16.492 | 5.38 |
| 68485 | Overlap | Before | 32.96 | 29.094 / 35.333 / 54.344 | 56.84 | 120 / 69 | 70.545 / 0.110 | 5.19 |
| 68585 | Overlap | Before | 32.79 | 30.145 / 35.359 / 37.128 | 56.56 | 120 / 69 | 66.801 / 0.137 | 5.25 |
| 68728 | Overlap | After | 33.15 | 28.868 / 33.966 / 52.105 | 58.88 | 120 / 67 | 67.256 / 16.532 | 5.23 |

The timed cohort ran 07:11:55–07:12:59 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 484.5–510 CSS pixels. Pressure throughput improved in two of three
pairs and its median rose from 16.30 to 16.48 fps. Overlap throughput
improved in all three pairs and its median rose from 32.96 to 34.32 fps.
Variation in the overlap control and input delivery limits attribution of
the timing differences. Every measured interval exceeded 16.67 ms.
The build, screenshot and comparison guard exits were zero and sampled
process-tree RSS peaked at 7,466,958,848, 491,520,000 and 635,076,608 bytes.

### Skipping the input channel swap for transparent SVG mask paths

The GG path callback now swaps incoming red and blue channels only when
it uploads a backdrop. A transparent draw clears the GG surface and
replaces the staging pixels at readback. The output swap continues to
publish RGBA to Quartz.

An initial experiment used a BGRA staging bitmap and removed both swaps.
It produced identical pixels and increased warm staging and compositing
time on all three sizes below. The final change keeps RGBA staging and
removes the input pass on transparent draws.

The Apple Clang `-O1` harnesses used the three staging sizes from the
rectangle fixture above. Each measurement included staging allocation,
the serial red/blue loops, a CPU copy simulating readback, image creation,
the Quartz draw and the destination flush. Source generation, destination
allocation and filling, and output hashing were outside the timed interval.
Each size and configuration used seven alternating pairs of fresh processes,
with 101 samples per process. All outputs for each size matched the old
composite hash. Warm times use each process's median after its first sample.

| Bitmap | Experimental warm RGBA / BGRA (µs) | Final first before / after (µs) | Final warm before / after (µs) | Final faster pairs, first / warm |
| --- | ---: | ---: | ---: | ---: |
| 58 × 130 | 82.812 / 111.271 | 845.708 / 846.875 | 62.125 / 60.146 | 4/7 / 5/7 |
| 94 × 182 | 179.646 / 231.728 | 908.792 / 949.500 | 137.646 / 130.083 | 3/7 / 7/7 |
| 280 × 188 | 505.708 / 547.938 | 1191.125 / 1114.625 | 353.812 / 333.854 | 5/7 / 6/7 |

The two harness SHA-256 values were
`f6ebec6ee406bb29b534713d75fda83771b1bcff73e405e0e19d0f8991406f92` and
`3b965939a4d5e9ce65a76ada86215ffd61371ab60cad1f707b77fe8c34083ce0`.
One-minute host load was 15.68 for the BGRA experiment and 9.10 for the
final harness on 18 logical CPUs.

The matched browsers used one V `-prod` generated C unit and single-unit
Clang `-O1 -fno-lto`. The RGBA control restored the two channel swaps in
the sealed code. The paired candidate added the backdrop guard to that
same sealed unit. The control executable SHA-256 was
`1c1b37a3a10aa48c0192ac5e22b69733fb5de8b369a6a63e4271250be2b1089a`
and the candidate executable SHA-256 was
`fc4dc6c4f5409a824ad0a4a4fe6c8b0d4d16a9c5e9e2f06987682bde4e77793a`.
Disassembly confirmed a branch around the input swap for a zero backdrop
and an unconditional output swap. A separate `-prod` C generation from the
canonical V source confirmed the callback shape. Its generated C SHA-256
was `d21b5afb66d1efa712eff24dec250a723f8f4a31f34db71b4418c3c26210d1b0`.
The native mask layer and exhaustive conversion checks also passed.

All 158 macOS SVG mask captures passed on the candidate. Four paired 2×
captures matched every decoded pixel. They covered the default pressure
and overlap fixtures, pressure with Quartz forced, and a Quartz luminance
mask with translucent red, blue, reflected and transformed paths. The
colored fixture's SHA-256 was
`9829156b10f124098b59a589cf1a348c5bc24e3fcbeab72abd36ffeef07da657`.
Both colored captures logged five successful GG path draws. The default
captures agreed on 385 pressure and 106 overlap mask decisions.

The wheel trials used the same local pressure and overlap fixtures as above,
fresh processes and browser caches, JavaScript disabled, and a 1024 × 600
viewport at 2×. Host caches were retained. After a one-second title-matched
settle, the driver sent 120 four-pixel inputs at a requested 60 Hz, reversing
after input 60. Throughput counts scroll-changing native frame installations
after outer view paint over the first-to-last input window.

A separate pressure diagnostic (PID 12277) logged 620 cache capacity
denials, 544 hits including 88 crops, and 16 new shared rasters between the
start marker and the final publication. The overlap diagnostic (PID 12378)
logged zero denials, 621 hits including 155 crops, and six new shared
rasters. The timed trials disabled mask diagnostics.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 12495 | Pressure | Before | 16.17 | 57.833 / 61.887 / 65.180 | 58.30 | 120 / 33 | 124.521 / 48.960 | 8.07 |
| 12596 | Pressure | After | 16.12 | 58.638 / 62.906 / 63.957 | 58.15 | 120 / 33 | 123.770 / 33.187 | 7.82 |
| 12696 | Pressure | After | 15.49 | 58.176 / 66.456 / 117.650 | 59.46 | 120 / 31 | 121.754 / 49.166 | 7.44 |
| 12814 | Pressure | Before | 15.78 | 60.158 / 65.103 / 65.464 | 58.68 | 120 / 32 | 125.818 / 32.691 | 7.22 |
| 12986 | Pressure | Before | 15.68 | 58.294 / 65.154 / 123.535 | 58.31 | 120 / 32 | 121.245 / 18.398 | 7.28 |
| 13092 | Pressure | After | 15.59 | 59.198 / 66.239 / 120.105 | 59.86 | 120 / 31 | 122.111 / 32.685 | 6.94 |
| 13190 | Overlap | Before | 29.76 | 32.972 / 38.867 / 41.172 | 56.22 | 120 / 63 | 73.249 / 0.331 | 7.10 |
| 13355 | Overlap | After | 31.39 | 30.822 / 37.181 / 38.093 | 58.36 | 120 / 64 | 70.175 / 0.120 | 7.17 |
| 13502 | Overlap | After | 31.35 | 31.231 / 36.049 / 38.984 | 55.67 | 120 / 67 | 70.792 / 0.095 | 7.16 |
| 13656 | Overlap | Before | 29.44 | 32.161 / 37.610 / 39.680 | 54.74 | 120 / 64 | 70.800 / 33.733 | 7.71 |
| 13845 | Overlap | Before | 27.64 | 33.561 / 44.765 / 72.432 | 55.76 | 120 / 59 | 71.539 / 0.134 | 7.81 |
| 14058 | Overlap | After | 26.86 | 36.495 / 41.575 / 43.860 | 54.18 | 120 / 59 | 87.482 / 0.124 | 7.67 |

The timed cohort ran 07:32:08–07:33:12 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 485–510 CSS pixels. Pressure throughput decreased by less than 2% in
each pair, and its median fell from 15.78 to 15.59 fps. The overlap median
rose from 29.44 to 31.35 fps, with one pair slower. Every scroll interval
exceeded 16.67 ms. All browsers and final validation guards exited zero.
Sampled process-tree RSS peaked at 7,541,555,200 bytes for the matched
candidate build, 7,737,901,056 for canonical C generation, 487,751,680 for
the screenshot suite, and 670,285,824 for the scroll comparison.

### Publishing small SVG alpha masks from their existing coverage

The macOS snapshot publisher can reuse the alpha in an RGBA mask of up to
131,072 pixels. It flushes the bitmap and creates the image without
rewriting the color channels. Luminance masks derive coverage from RGB.
Larger alpha masks go through the premultiplied-white conversion before
publication.

The native checks compare colored alpha and luminance masks through both
Quartz clipping and destination-in compositing, at fractional placements
and on sRGB and Display P3 destinations. The small-alpha cases verify
that publication preserved the source color bytes. A 512 × 257 alpha
mask verifies the conversion just above the cutoff. The layer, cache,
placement and exhaustive pixel conversion checks passed.

An exploratory Clang `-O1` harness tried the direct snapshot without an
area limit. On a 1902 × 1284 mask, median warm publication and layer
compositing fell from 1725.833 to 1208.583 µs. Publication and clipping
rose from 9426.333 to 9996.646 µs, with the direct snapshot faster in two
of seven pairs. All composite pixel hashes matched. The harness hash was
`55da644046980dd161b0d6be6629e8878ef71c96b4a3edace73d278e90468ac5`.

The bounded candidate was measured through source release and then
through mask application, image release and destination flush. The
timings exclude source generation, destination allocation and setup,
and output hashing. Each mode used seven alternating pairs of fresh
processes and 41 samples per process. Warm values are medians of each
process's post-first-sample median. All composite hashes matched. Host
load was 7.23–7.42 on 18 logical CPUs. The harness SHA-256 was
`fb78bb1688b21b311a9566eba596ec44a32ce0cc203b539960040bf8e61a0b07`.

| Alpha bitmap | Application | Warm publication before / after (µs) | Warm publication and application before / after (µs) |
| --- | --- | ---: | ---: |
| 276 × 184 | Destination-in | 35.250 / 9.667 | 52.417 / 26.895 |
| 276 × 184 | Clip | 34.584 / 10.437 | 212.730 / 193.083 |
| 512 × 256 | Destination-in | 76.021 / 12.104 | 115.397 / 53.688 |
| 512 × 256 | Clip | 78.270 / 12.062 | 497.646 / 457.625 |

The candidate had a lower warm time in all seven pairs for each endpoint
and row.

Repeating the bounded benchmarks with a Display P3 destination produced
identical composite hashes within each pair. With 21 samples per process,
including the first sample, warm publication and application improved in
all seven pairs per row. Host load was 6.17. The harness SHA-256 was
`3e7b898c09af7c9e41c07a78d033d006f687aba29013766fca5e31ceea5c26ee`.

| Alpha bitmap | Display P3 application | Warm publication and application before / after (µs) |
| --- | --- | ---: |
| 276 × 184 | Destination-in | 230.584 / 206.062 |
| 276 × 184 | Clip | 240.000 / 214.416 |
| 512 × 256 | Destination-in | 530.271 / 450.354 |
| 512 × 256 | Clip | 548.083 / 489.896 |

The matched browsers used one V `-prod` generated C unit and single-unit
Clang `-O1 -fno-lto`. The bounded candidate substituted the preprocessed
publisher from the final header into the sealed control. The generated
C SHA-256 was
`a18adf92f5369baf4a87109f3d48c42461d247ddc37534ae23710227fe423351`.
The executable SHA-256 values were
`b95160bb3798ccf6b4d4188bb3e09f1a387853f3672c65145144b0e490e9884e` for
the control and `d67ea514ce10c96c02319d861a5d851571e8550bfd35c93a187b6035e75979a6`
for the candidate.

All 158 macOS mask captures passed. Four paired 2× captures matched every
decoded pixel. They covered the default alpha and luminance pressure pages,
the alpha page with Quartz forced, and the overlapping solid-mask fixture.
The alpha fixture changes the mask type and gradient stops on the existing
75-mask pressure page. Its SHA-256 was
`a9edaf4677215287c6f68c8b9e98b2571e98e87e60fd43b695037a74ecdf7c2f`.
Both default pressure captures matched 385 mask decisions per pair. The
overlap candidate matched all 106 control decisions and then repeated the
last ten cache hits in one additional paint. The diagnostic log comparison
resumed with those same captures and accepted the repeated pass.

The wheel trials used the two local pressure fixtures, fresh processes,
profiles and browser caches, JavaScript disabled, and a 1024 × 600
viewport at 2×. Host caches were retained. After a one-second title-matched
settle, the driver sent 120 four-pixel inputs at a requested 60 Hz, reversing
after input 60. Throughput counts scroll-changing native frame installations
after outer view paint over the first-to-last input window.

The alpha diagnostic (PID 54094) logged 568 cache-capacity denials, 496
shared hits including 78 crops, and 16 new shared rasters between the start
marker and final publication. The luminance diagnostic (PID 54239) logged
639 denials, 560 hits including 84 crops, and 16 new shared rasters. Both
fixture types were confirmed by the published mask diagnostics. Timing ran
with those diagnostics disabled.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 54412 | Alpha | Before | 15.61 | 58.303 / 65.478 / 123.438 | 59.90 | 120 / 31 | 127.345 / 33.445 | 5.85 |
| 54555 | Alpha | After | 15.46 | 61.314 / 70.591 / 72.743 | 59.36 | 120 / 31 | 127.910 / 0.117 | 5.94 |
| 54792 | Alpha | After | 15.44 | 59.676 / 66.238 / 123.095 | 59.29 | 120 / 31 | 130.345 / 16.857 | 6.27 |
| 54954 | Alpha | Before | 15.45 | 59.468 / 68.659 / 127.084 | 59.29 | 120 / 31 | 128.758 / 17.693 | 6.17 |
| 55110 | Alpha | Before | 15.46 | 60.600 / 67.899 / 69.380 | 59.34 | 120 / 31 | 122.755 / 49.923 | 6.31 |
| 55253 | Alpha | After | 15.35 | 60.770 / 67.256 / 68.854 | 58.91 | 120 / 31 | 123.686 / 50.465 | 6.21 |
| 55403 | Luminance | Before | 15.66 | 59.196 / 65.521 / 67.415 | 58.25 | 120 / 32 | 124.968 / 49.789 | 6.03 |
| 55551 | Luminance | After | 16.26 | 58.215 / 64.755 / 65.977 | 58.62 | 120 / 33 | 122.333 / 16.760 | 5.95 |
| 55700 | Luminance | After | 15.93 | 58.834 / 63.092 / 66.286 | 57.44 | 120 / 33 | 123.415 / 49.489 | 6.11 |
| 55852 | Luminance | Before | 12.76 | 72.225 / 81.623 / 83.215 | 58.41 | 120 / 26 | 150.889 / 50.623 | 6.02 |
| 56165 | Luminance | Before | 13.86 | 67.700 / 77.461 / 93.169 | 56.87 | 120 / 29 | 138.978 / 18.111 | 5.94 |
| 56323 | Luminance | After | 13.70 | 68.640 / 77.744 / 78.466 | 58.22 | 120 / 28 | 141.128 / 17.203 | 6.10 |

The wheel cohort ran 07:49:54–07:50:58 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 485–503 CSS pixels. Alpha throughput fell by less than 1% per pair,
with a median of 15.46 → 15.44 fps and 31 scroll changes in each arm.
Luminance throughput varied more, with a median of 13.86 → 15.93 fps.
Every measured scroll interval exceeded 16.67 ms. The final checks,
benchmarks and guards exited zero. Peak sampled process-tree RSS was
7,180,599,296 bytes for the bounded build, 481,345,536 for the screenshot
suite, and 670,171,136 for the paired wheel comparison.

### Vectorizing SVG mask coverage conversion on Apple Silicon

RGBA luminance conversion uses an unsigned ARM dot product for four pixels
at a time. It applies the same 54, 183 and 19 weights and truncates after
shifting by eight. RGBA alpha expansion uses a byte shuffle. Forward
overlaps keep the per-pixel order because stores can affect later reads.
The common RGBA converter accepts aliasing, including in-place bitmaps.
The separate alpha-only clip expansion retains its disjoint-buffer contract.

The native checks passed all 16,777,216 RGB combinations and every alpha
value, including padding, unaligned buffers, in-place conversion, and
overlap both across and within rows. They also passed with workers disabled,
with ARM dot-product support undefined, and under AddressSanitizer and
UndefinedBehaviorSanitizer. The native layer and mask publication checks
passed. The scalar test also compiled for x86-64. Disassembly of the
candidate harness confirmed `udot`.

The Apple Clang `-O2` harnesses timed conversion through return, including
worker dispatch where the bitmap was large enough. Source preparation,
in-place resets and comparison against a scalar reference were outside the
timed interval. Seven alternating pairs used fresh processes per row with
81 samples for small masks and 31 for large masks. Warm times are medians
of the post-first-sample median in each process. All outputs matched,
including padding. One-minute host load was 14.09–14.71 on 18 logical CPUs.

| Bitmap and mode | First before / after (µs) | Warm before / after (µs) | Faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 276 × 184 luminance copy | 5.459 / 4.250 | 5.375 / 3.958 | 6/7 / 7/7 |
| 276 × 184 luminance in place | 5.584 / 4.417 | 5.375 / 4.083 | 7/7 / 7/7 |
| 512 × 256 luminance in place | 14.167 / 10.916 | 13.917 / 10.792 | 6/7 / 7/7 |
| 1902 × 1284 luminance copy | 180.917 / 165.917 | 100.833 / 93.416 | 6/7 / 5/7 |
| 1902 × 1284 luminance in place | 189.750 / 166.250 | 141.812 / 124.459 | 5/7 / 5/7 |
| 512 × 257 RGBA alpha in place | 11.333 / 11.625 | 11.041 / 11.416 | 1/7 / 0/7 |
| 276 × 184 alpha-only expansion | 3.917 / 3.917 | 3.917 / 3.917 | 4/7 / 3/7 |
| 1902 × 1284 alpha-only expansion | 242.709 / 245.917 | 106.876 / 105.688 | 3/7 / 4/7 |

The RGBA harness executable SHA-256 values were
`5260742a84c2cfd484404ed071d73a13ed13457eeb52100c391e765507bfa1f6` and
`25d0a463a09dae28a494131e6031b625f540c40cfd846c8e68b88e1125e1e61c`.
The alpha-only harness hashes were
`ef739b19d25749f70a2a55ae02132adc9d3ea54475fe2df5ce00bdf5259fa093` and
`3337431490feaf37df69aea882740d53e1aca936616d038e16dda4b9069e0214`.

The initial widening-multiply version brought the warm 512 × 257 RGBA
alpha control from 10.375 to 38.709 µs after removing the shared alias
restriction. The packed alpha loop recovered most of that cost. Its
earlier paired run measured 16.500 → 15.250 µs at load 12.31. The final
paired run measured 11.041 → 11.416 µs at load 14.09. The alpha-only
copy loop's disjoint-buffer annotation recovered its small-mask median
after an earlier run measured 5.125 → 6.208 µs at load 22.15–22.77.

The matched browsers used one V `-prod` generated C unit and single-unit
Clang `-O1 -fno-lto`. The preprocessed inputs matched outside the conversion
header. The generated C SHA-256 was
`c8a532663d98846ace1c7e7f114dc5dc2b181d494a123ab55a7fe2ac20073d04`.
The control and candidate executable SHA-256 values were
`cca02f60d3e0c3df331e927efe6959496caf4501584d56be7882fc1738d402d4` and
`e46e135ecc9f1511c8345a533ce406d51c1db01eb241758f2190b63278cc89fe`,
respectively.

The candidate passed all 158 macOS mask captures. Four paired 2× captures
matched every decoded pixel. They covered the default luminance and alpha
pressure fixtures, luminance with Quartz forced, and overlapping masks.
The pressure captures agreed on 385 mask decisions per pair, and the
overlap captures agreed on 106. The luminance diagnostics confirmed new
rasters and Quartz fallback on the same fixture. The candidate browser's
row converter contained the ARM `udot` instruction.

The wheel trials reused the two local 75-mask pressure fixtures at 1024 × 600
and 2× with JavaScript disabled, fresh processes, profiles and browser caches,
and retained host caches. The title-matched settle lasted one second. The
driver sent 120 four-pixel inputs at a requested 60 Hz, reversing after input
60. Throughput counts scroll-changing native frame installations after outer
view paint over the first-to-last input window.

A separate luminance diagnostic (PID 39862) recorded 662 capacity denials,
592 hits including 89 crops, and 16 new shared rasters through the final
publication. The alpha diagnostic (PID 40015) recorded 634 denials, 560
hits including 88 crops, and 16 new rasters. The timed cohort disabled
mask diagnostics.

| PID | Fixture | Build | Scroll fps | Median / p95 / max (ms) | Input Hz | Inputs / changes | First / last scroll gap (ms) | Load |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 40171 | Luminance | Before | 15.11 | 61.849 / 68.561 / 69.628 | 59.94 | 120 / 30 | 135.227 / 49.964 | 5.26 |
| 40317 | Luminance | After | 16.64 | 56.602 / 63.819 / 65.985 | 58.23 | 120 / 34 | 118.641 / 32.717 | 5.00 |
| 40464 | Luminance | After | 16.55 | 58.387 / 61.891 / 63.410 | 59.70 | 120 / 33 | 119.828 / 16.802 | 4.84 |
| 40609 | Luminance | Before | 16.51 | 57.136 / 65.788 / 66.312 | 57.77 | 120 / 34 | 123.534 / 32.855 | 4.77 |
| 40861 | Luminance | Before | 16.37 | 56.302 / 63.189 / 115.969 | 59.02 | 120 / 33 | 121.365 / 18.034 | 4.71 |
| 41074 | Luminance | After | 16.38 | 57.412 / 62.671 / 68.044 | 59.05 | 120 / 33 | 119.594 / 50.003 | 4.89 |
| 41220 | Alpha | Before | 16.11 | 57.913 / 63.991 / 66.736 | 58.11 | 120 / 33 | 121.014 / 49.221 | 4.82 |
| 41376 | Alpha | After | 15.80 | 57.343 / 67.148 / 119.362 | 58.77 | 120 / 32 | 120.078 / 33.262 | 5.08 |
| 41511 | Alpha | After | 16.99 | 57.101 / 61.790 / 62.353 | 59.46 | 120 / 34 | 120.044 / 0.112 | 4.99 |
| 41625 | Alpha | Before | 15.89 | 58.937 / 66.673 / 127.244 | 59.11 | 120 / 32 | 116.589 / 18.629 | 5.07 |
| 41832 | Alpha | Before | 15.90 | 59.798 / 65.415 / 65.972 | 59.12 | 120 / 32 | 122.414 / 16.765 | 4.99 |
| 41969 | Alpha | After | 15.56 | 61.738 / 66.922 / 67.553 | 59.75 | 120 / 31 | 129.117 / 0.122 | 5.15 |

The timed cohort ran 08:16:08–08:17:12 UTC on November 18, 2026. Load is
the one-minute average at launch on the 18-CPU host. Peak scroll positions
were 484.5–502 CSS pixels. The luminance median rose from 16.37 to 16.55
fps. The alpha median moved from 15.90 to 15.80 fps with mixed pairs.
Every measured scroll interval exceeded 16.67 ms. All browsers and final
guards exited zero. Sampled process-tree RSS peaked at 7,509,360,640 bytes
for the paired build, 484,048,896 for the screenshot suite, and 671,760,384
for the paired wheel comparison.

## Original migration plan

Vox currently renders through two Skia builds: LibWeb's Skia (CPU raster,
`libLadybirdVSkiaText.dylib`; the `skia/` module was removed on 2026-11-10) and the pinned Chromium
Skia Graphite builds (`libVoxGraphite.dylib` on Metal and
`libVoxGraphiteDawn.dylib` for pictures). Brave parity depends on reproducing
Chromium's Skia output exactly. The migration replaces Skia with `gg.canvas`, a
new `vlib/gg` module, without changing any pixel of the passing tests.


The CPU differential suite and large generated verification receipts live in
[vox-browser/vox-tests](https://github.com/vox-browser/vox-tests). Vox pins the
suite in `tools/raster_tests.json`; `tools/raster_tests.py` fetches that exact
revision, verifies a clean checkout and runs it against this canonical source.
The existing `tools/gg_migration/test_cpu_raster.sh` command remains a launcher.
Small focused unit tests and their frozen inputs stay in `cpuraster/`. New
bulk receipts belong in the test repository, with a concise result here.
Historical receipts below retain their original bytes and source identities.

## Approach

`gg.canvas` reproduces Skia rather than approximating it:

- **GPU work.** Graphite's generated MSL is embedded unchanged and compiled
  with Graphite's options. Instance, vertex and uniform data are written byte
  for byte, render passes use the same attachments, sample counts and blend
  state, and draws are ordered, sorted (libc++ `std::sort`) and split into
  instanced draw calls exactly like Graphite's `Device`, `DrawList`,
  `DrawWriter` and `DrawBufferManager`. On Apple GPUs, splitting or reordering
  a batch changes MSAA and antialiased pixels, so batching is part of the
  output.
- **CPU arithmetic.** Ported geometry uses the same float operations. Skia is
  built with `-ffp-contract=off`; the V code avoids expressions that clang
  would contract into FMAs, and `tools/raster_tests.py fma_audit.py` enforces it.
- **Verification.** `tools/gg_migration` runs scene scripts through the pinned
  Skia (an oracle linked against `libskia.a`) and through `gg.canvas`, compares
  every byte, and traces both Metal command streams to locate the first
  divergent draw.

The ABI between Vox and Graphite is plain values and pixel buffers
(`native/include/native_graphite_bridge.h`), so each entry point can be replaced by a V
implementation exporting the same symbols and compared against the pinned
original dylib with the existing `tools/native_graphite_*_test.cpp` harnesses.

## Status (2026-11-06)

The browser adapters and differential tools now live on canonical Vox
`master` (`05ffb14b8`, `edeebc78e`). They were integrated from `gg-migration`
`7377e0384`; the original worktree and its historical results remain intact.
Build and test from `/Users/alex/code/vox2`.

The V renderer PR is merged. The canonical Vox push
was rejected as non-fast-forward: `origin/master` at `868e16b99` has three
commits absent locally, while the shared local history has hundreds absent
remotely. The tested Vox integration, tooling and report commits remain local.
Reconciling those histories requires a decision consistent with the repository's
linear-history and no-rewrite rules; no force push, merge or rebase was attempted.

Upstream V merged [vlang/v#31826](https://github.com/vlang/v/pull/31826) on
November 6 at squash commit `ac9fbda08a140196f9aff3aa377b404868249740`.
Its `vlib/gg/canvas` directory is byte-identical to the reviewed source head
`5b06b5a56b` in `~/code/v-gg`. The shared parallel compiler still uses its
earlier V checkout without this module; it has not been overwritten.
`V_BIN=~/code/v-gg/v sh build-prod-browser.sh` selects the existing GG compiler.
The default macOS build requires `gg.canvas` and supplies `-d vox_gg_canvas`.
GG's text, shape and path adapters now register by default. `VOX_USE_SKIA=1`
at launch selects the legacy renderer, overriding all three adapter switches.
Explicit `VOX_GG_TEXT=0`, `VOX_GG_SHAPES=0` and `VOX_GG_PATHS=0` still isolate
individual adapters for differential checks. Unsupported and unmigrated draws
retain Skia fallback; **the default binary is not Skia-free**.

With `V_BIN` unset, an older shared compiler can use the existing
`~/code/v-gg/v` without overwriting the shared parallel compiler. An explicit
compiler lacking `gg.canvas` fails the default build. An explicit
`VOX_USE_SKIA=1 sh build-prod-browser.sh` builds the legacy renderer without
requiring or compiling the GG adapters. This build choice is recorded in the
shared queue and its renderer receipt. Linux's existing Skia renderer is unchanged;
the GG browser adapters currently require macOS.

The GG compiler predates `v root`. Build detection now uses the existing
`@VEXEROOT` library probe (`aa03e9ba8`), including for moved compilers and
staged runtimes. Three focused checks pass; real compiler probes detect the
GG module and identify its absence from the standard shared V compiler.

### Default selection and remaining Skia dependencies

`e76d0e595` makes GG the macOS default and adds the explicit Skia override. Build
workers use protocol `bundle-lease-v4`, preserving a queued legacy request and
rebuilding when the requested renderer changes even if source bytes do not.
`renderer.json` records both the selected default and `skia_free:false`.
Comparison tools explicitly select Skia for controls, clear inherited renderer
overrides, and retain the existing selective adapter cohorts.

Production receipt `20261106-133828-93b254e2`, executable
`7f519bf2f01db83bf45be3da6b09f7031f7c4d894df4b50f07662e8a07e5544e`,
verifies registration with **no renderer flags** (all three GG adapters true)
and `VOX_USE_SKIA=1` (all three false). The two fresh captures match. Twelve
focused fixture pairs also match, with unchanged executable, native libraries,
fixtures and resources: 57 unclipped and 38 device-clipped text draws, six
shape draws, 24 path draws and three path declines. Those three gradient
declines still require Skia to preserve pixels. All 26 launches exit zero;
the four V selection cases and 55 build/comparison-tool checks pass.

The requested binary-size reduction remains unfinished. `otool -L` confirms
both Vox and `libLadybirdVSkiaText.dylib` directly link `libskia.dylib`.
The Graphite and Dawn picture libraries also retain their Skia implementation.
The `skia/` package, removed on 2026-11-10, then supplied canvas paths/text/filters and shadows (font
validation, pixel readback and bitmap export have since moved to Skia-free
code; see [Removing Skia](#removing-skia-started-2026-11-06)); the native text
bridge creates Skia fonts and blobs before invoking GG. Removing these links now would leave required symbols and
rendering operations unimplemented. Runtime environment selection cannot
eliminate compiled dependencies. See the
[default-selection receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/default-20261106.json) for the verified
selection, pixel tests and dependency audit. Skia-free rendering still requires
the ports listed under Remaining work.

### Upstream review fixes

Seven fixes were committed and pushed to the PR's verified source branch,
`medvednikov/v-pr-fork:gg-skia-parity`, after review of `ff4cd6dc66`:

| Commit | Fix |
| --- | --- |
| `01a7922600` | Define `GL_PACK_ALIGNMENT` in the embedded Windows GL loader. |
| `8e76b07a8f` | Isolate CoreText files; unsupported platforms expose explicit text errors. |
| `50dad21400` | Restore the temporary DRRect clip/save on every error path. |
| `0b9adab99b` | Reject CPU gradient text before modifying pixels. |
| `7b1b0ebb16` | Reject depth exhaustion, reserving the extra depth for deferred clips. |
| `6ce199418c` | Reserve complete draw and pending-clip uniforms before the 4096-block limit. |
| `dbfcab86a1` | Bound text caches; release retained fonts, glyph masks and native contexts. |

The text cache retains at most 32 strikes in LRU order, with at most 256 glyphs
and 256 KiB of masks per strike. Individual masks over 512 pixels in either
dimension decline. `canvas.clear_text_cache()` releases strikes while preserving
live faces; `Typeface.free()` also releases that face's retained font. Text
drawing and cleanup are serial operations on the drawing thread.

All 12 canvas test files pass on macOS, including the retained Metal and CPU-text
pixel hashes. The text cache, text pixels and draw-list tests also pass with
`-gc none`. Linux and Windows type checks cover paths and the platform/cache
tests. The Windows GLCORE regression test compiles the embedded loader with
MinGW, and a separate GLCORE executable cross-build links successfully. Native
Windows execution and Linux runtime tests were not run. See the
[review-fix receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/pr-reviews-20261105.json) for source pins,
commands, actual exits and retained failures.

The follow-up review confirmed those implementation fixes and found three text
helper tests still referencing Darwin-only definitions on other platforms.
`b434ae7005` puts their bodies under matching macOS guards. The previous
cross-target checks omitted `text_test.v`; verification now typechecks all 12
canvas test files for both Linux and Windows (24 checks), then runs the text
and platform test files on macOS. All pass. This follow-up changes only tests;
see its [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/pr-review-followup-20261105.json).

A fresh review of `b434ae7005` reproduced two further state-management bugs.
`6c8b7be581` clears pending clip usage, order and depth when a draw list is
discarded; otherwise restoring a clip after `clear()` could resurrect the
discarded depth and reject the first new draw. `5b06b5a56b` unwinds the implicit
save if layer creation fails, preserving the caller's save and matrix. Both
regressions failed before the fixes and pass afterwards. All 12 canvas test files,
three affected files with `-gc none`, and six Linux/Windows type checks pass.
The new Metal pixel test also checks that clearing pending usage preserves the
active clip geometry. See the [fresh-review receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/review-20261106.json).

The 262-fixture stage22 browser result below remains pinned to `ff4cd6dc66`;
it does not validate a production browser built with this newer review-fix head.

Implemented in `gg.canvas`:

- sokol: integer vertex formats; synchronous image upload/readback and flush;
  Metal shader compile options; partial uniform updates on Metal.
- `gg.canvas`: Graphite's analytic rrect and non-AA bounds renderers for
  filled, stroked and hairline rects, rrects and ovals, inner fills, fixed src
  blending, 1x and 4x MSAA surfaces, backdrop upload (loaded into MSAA passes
  with Graphite's `LoadMSAAFromResolve` draw) and readback, SkCanvas quick
  reject, Graphite draw ordering, sorting and batching, the ordering effects
  of Vox's forced-MSAA path, and `GpuContext.precompile()`.
- `gg.canvas` clips: a port of Graphite's ClipStack for rect and rrect
  elements: `save`/`restore` with deferred save records, intersect and
  difference `clip_rect`/`clip_rrect` under any affine transform (rrects
  under 90-degree rotations through SkRRect's legacy transform), element
  simplification and combination, geometric intersection of rect and rrect
  draws with intersect elements in the same or a relatively axis-aligned
  space (SkM44 concatenation), flood fills and the fullscreen clear,
  scissors, the legacy analytic rect and circular rrect clip shader on every
  renderer, and depth-only element draws in 4x MSAA passes: convex wedges
  (lines and conics, FixedCountWedges' templates) for difference elements,
  winding stencil wedges and an inverse cover of the scissor for intersect
  elements. `draw_drrect` follows Graphite's drawDRRect (stroked rects and
  rrects, rect differences, clipped fills, and other strokes as even-odd
  paths).
- sokol: vertex-only Metal shaders. Graphite's depth-only clip pipelines have
  no fragment function, and on Apple GPUs an empty fragment function changes
  their rasterization.
- `gg.canvas` paths: `Path`/`PathBuilder` (SkPathBuilder's verbs, conic
  weights, `addOval` and SVG `arcTo`), path bounds, Skia's convexity and its
  line, rect and nested-rect detection, and `draw_path` for fills, following
  Graphite's `drawPath` with `PathRendererStrategy::kTessellation` (Graphite
  on Apple silicon uses no path atlas): rect, oval and nested-rect paths use
  those renderers, convex paths the shaded convex wedges, and other paths the
  MSAA stencil-and-cover wedges (winding and even-odd, disjoint stencil sets),
  with Wang's formula for lines, quads, conics and cubics and PatchWriter's
  chopping of curves that need more than 32 segments. Compiled Skia
  evaluates the sine and cosine of one angle with a combined sincos call,
  which can differ from separate calls in the last bit; the arc port does the
  same.
- `gg.canvas` strokes: Graphite's tessellated stroke renderer for path strokes
  and for rrects the analytic renderer cannot stroke (elliptical corners):
  deferred first patches joined to the closing patch, miter, round and bevel
  joins, butt, round and square caps, cubic, quad and conic cusps,
  hairlines, cubic convex-180 chops, chopped long curves and the stroke
  tolerances that select the fixed-count vertex count. Lines (`draw_line` and
  single-line paths) use the analytic rrect renderer with caps, like
  Graphite's `drawPoints`.

- Clip paths: convex and non-convex elements, winding and even-odd stencil
  tests, and clip-state save/restore. Some rotated curved clip paths still decline.
- Gradients: dithered linear and radial gradients, up to eight stops, every
  tile mode, local matrices, premultiplied interpolation and translucent paint
  variants. General two-point conical gradients still decline.
- Layers: `save_layer` without a paint, nested offscreen textures and image
  shader restores. `restore` also restores the matrix. Fractional rectangular
  restores now use Graphite's PerEdgeAAQuad renderer: its 16 template vertices,
  29 indices, 80-byte instance layout, coverage, bounds, ordering and batching.
- Inverse winding and even-odd path fills: stencil wedges followed by an inverse
  cover. Empty inverse fills still require the drawPaint path.

Differential results against the pinned Graphite (exact means every byte equal;
unsupported scenes decline rather than earn a pass):

| Corpus | Scenes | Exact | Unsupported |
| --- | ---: | ---: | ---: |
| 400 mixed single/few draws | 400 | 400 | 0 |
| 2000 mixed single/few draws | 2000 | 2000 | 0 |
| 30 fills per scene | 60 | 60 | 0 |
| 90 fills per scene | 60 | 60 | 0 |
| 200 fills per scene | 60 | 60 | 0 |
| 400 with 4x MSAA backdrops (69 such scenes) | 400 | 400 | 0 |
| 2000 with 4x MSAA backdrops (322 such scenes) | 2000 | 2000 | 0 |
| 400 with difference clips (`--clip-outs`) | 400 | 400 | 0 |
| 2000 with difference clips (`--clip-outs`) | 2000 | 2000 | 0 |
| 300 skip-ink lines with 1-10 clip-outs each | 300 | 300 | 0 |
| 400 with save/restore, rect/rrect clips, DRRects, border sides (`--clips --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 filled paths mixed with shapes and clips (`--paths --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 of the same with SVG arcs (seed 777) | 400 | 400 | 0 |
| 2000 of the same with SVG arcs | 2000 | 2000 | 0 |
| 400 mostly stroked paths of every join and cap (`--strokes --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 stroked and filled curves that need chopping or turn around (`--curves`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 single line segments of every cap, hairlines and dots (`--lines`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| Clip paths, 400 scenes | 400 | 399 | 1 |
| Clip paths, 2000 scenes | 2000 | 1997 | 3 |
| Gradients | 2000 | 1604 | 396 |
| Gradient paths | 2000 | 1434 | 566 |
| Gradient strokes | 2000 | 1430 | 570 |
| Layers before the per-edge AA port | 2000 | 1604 | 396 |
| Layers after the per-edge AA port (`ff4cd6dc66`) | 2000 | 1796 | 204 |
| Inverse fills | 2000 | 2000 | 0 |
| Focused fractional layer restores (`ff4cd6dc66`) | 8 | 8 | 0 |

The stroke corpora listed in earlier revisions of this document (376 of 400
and 1846 of 2000 exact) were generated after a `gen_shape_corpus.py` change
dropped the paint lines from path scenes, so they drew only fills; the
corpora above were regenerated with the paints restored (the SVG arc corpora
regenerate byte for byte). The previous build of `gg.canvas` declined 831
and 421 scenes of the 2000 curve scenes for stroked chopping and cusps.

The clip-path and gradient rows retain the preceding session's corpus results.
The current layer, inverse-fill and focused layer rows were rerun with the new
renderer: zero differing scenes. On identical layer inputs the previous
`canvas-scene-inverse` binary declines 192 scenes specifically because the
per-edge AA renderer was missing; the new renderer draws all 192 exactly.
The remaining layer declines are gradient limitations (68 linear color space,
30 without dithering, 65 general conical, 24 over eight stops, 17 degenerate).
See the [focused verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/focused-20261105.json) for
input hashes, executable identities, commands, actual exits and raw evidence.
All ten canvas test files pass; the layer test also passes with `-gc none`.

`gg.canvas` still declines unsupported image operations, layer paints,
stroke-and-fill, empty inverse fills, blurs and perspective transforms.

CPU text (`gg.canvas.RasterSurface.draw_glyphs`) reproduces the bridge's
retained glyph path, which runs on LibWeb's Skia (vcpkg m144, source
`google/skia@ee20d565`). That build defines `SK_GAMMA_APPLY_TO_A8` and uses
RGBA as kN32, so BGRA surfaces always blend through the lowp
`SkRasterPipeline`, never the legacy ARGB32 blitters. Ported: the scaler
record, `SkScalerContext_Mac` CoreGraphics masks with Skia's linearization and
`SkMaskGamma` pre-blend, subpixel buckets and placement, and the A8 mask
pipeline (`uniform_color`, `lerp_u8`/`scale_u8`, `srcover`, NEON `div255`).

| Text corpus | Scenes | Exact | Unsupported |
| --- | ---: | ---: | ---: |
| 400 random glyph runs | 400 | 400 | 0 |
| 2000 random glyph runs | 2000 | 2000 | 0 |

The runs cover six system fonts, 6-90px, opaque and translucent colors over
opaque, translucent and transparent backgrounds, identity, scale/translate and
rotated/skewed matrices, and both the Chromium and LibWeb smoothing settings.

### Text in the browser (`VOX_GG_TEXT=1`)

With `VOX_GG_TEXT=1` the browser registers `ggtext.glyph_run` with the text
bridge (`native/include/native_gg_text.h`), and the bridge's raster glyph paths (retained glyph
runs and glyph bitmap tiles) draw single-run blobs with `gg.canvas` instead of
`SkCanvas::drawTextBlob`. Typefaces wrap the bridge's own CTFonts
(`Typeface.from_ct_font`). Runs `gg.canvas` cannot draw exactly fall back to
Skia: shaders, mask/color/image filters, float colors, multi-run blobs, LCD
pixel geometry, synthetic bold and color glyphs.

`capture_ab.py` captured all 262 Brave fixtures (1024x852 window) with one
bundle, with and without the switch (Vox `1deb74782`, V `3c0c17b20c`,
executable `034ac038`, unchanged before and after): **262 pixel-equal**, none
different, unstable or failed. An earlier bundle with the adapter in `main`
(`3ccf48da`) matched on the 241 fixtures it reached before the memory guard's
30-minute timeout.

A separate lldb diagnostic counted the text drawn with the switch on:

| Glyph runs | Count | Fixtures |
| --- | ---: | ---: |
| Drawn by `gg.canvas` | 875 | 89 |
| Declined by `gg.canvas` (13 color emoji, 1 synthetic bold) | 14 | 2 |
| Raster runs declined before `gg.canvas` (`background-clip: text`, one root-background run) | 3 | 2 |
| Recorded into the shared recording canvas | 253 | 37 |
| Recorded into pictures for the GPU picture backend | 183 | 18 |

`SkPicture::serialize` replays recorded text through `drawTextBlob` another
299 times. The recorded paths (compositor layers, sticky and select content,
and most stackoverflow, lobsters and forum fixtures) are not routed to
`gg.canvas` yet. 160 fixtures, mostly gradients, borders, shadows and images,
draw no bridge text.

Canonical Vox `257add3f9` also routes borrowed-frame tiles with a device clip
through GG. The native adapter keeps the original raster dimensions and device
matrix, renders partial clips against a private backdrop, then copies back only
the visible rectangle. Full-tile clips need no staging. A declined draw leaves
the original backdrop available for Skia, including if a callback writes before
returning failure. Quartz snapshot detachment and RGBA/BGRA conversion retain
their existing behavior.

The focused native integration compares the actual `ggtext.glyph_run` callback
against the original CPU Skia draw through the same borrowed-frame adapter:

| Configuration | Pixel-exact cases | GG drawn | Fallback | Fully hidden |
| --- | ---: | ---: | ---: | ---: |
| Normal | 2000 | 1280 | 231 | 489 |
| `-prod -gc none` | 2000 | 1280 | 231 | 489 |

Both runs attempt 1,405 GG callbacks and change 1,413 tiles. They cover three
system fonts, fractional sizes and affine transforms, 1x/2x backing scales,
transparent and translucent backdrops, narrow/empty/disjoint clips, synthetic
bold and aliased masks, shader/float-color/perspective/LCD rejection, row padding
and immutable frame snapshots. The original implementation fails the first
case because it never invokes GG. Both existing text-adapter test runs pass,
normally and with `-prod -gc none`. These are correctness checks, with no speed
claim. See the [clipped-text receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/clipped-text-20261106.json)
for input and executable hashes, actual exits and retained failures.

Production receipt `20261106-101340-fca9026b` builds this adapter with the
reviewed V module (identical to the merge), literal `-prod`, preallocation and
one C unit. Executable
`74fbd0d869fef85f67ef07679310566dde0c325f224a70063c1d411883b5d09c`
passes 12 focused browser A/B fixtures with text, shapes and paths enabled:
24 successful fresh launches, no different, unstable or failed pairs, and
unchanged bundle, fixture and resource hashes. Diagnostics count 91 text draws
without a device clip and **38 with a device clip across three fixtures**,
all drawn by GG. The latter fixtures are `hacker-news-comment-initial-text`,
`scrolling-text-raster` and `select-label-ink-clip`. Shapes and paths each
draw four descriptors, with no declines. The 1024x852 captures exclude only the
existing status-bar RAM readout; they compare the two Vox modes, not Brave.
The first build attempt was rejected because shared sources changed before
preprocessing; the supervisor's retry sealed its compiler inputs and succeeded.
This focused result does not replace stage22's older 262-fixture acceptance.
All six existing native glyph executables also pass with AddressSanitizer and
UBSan, including 216 bitmap-surface cases, 16 device clips and four disjoint
damage-clip checks. Their source inputs stay unchanged throughout the run.

### Shapes in the browser (`VOX_GG_SHAPES=1`)

With `VOX_GG_SHAPES=1` the bridge's four `libVoxGraphite` shape entry points
(`native/include/native_gg_shape.h`) first offer each descriptor to `ggshape.draw`:
rounded-rect fills and strokes with an optional underlay, with or without
forced MSAA and a backdrop. Region, rounded-part and batched draws render the
same full surface with the CPU views as the only backdrop; a batch falls back
as a whole. Clip-outs become `gg.canvas` difference clips. The CSS border
modes now include elliptical rings, single rounded sides, three-sided labels,
and backgrounds sharing the border's layer. Unsupported draws keep the original
backend. `tools/gg_migration/shape_bridge_check.v`
checks the adapter against the saved `graphite_shape_oracle.mm` outputs
(14 of 14 exact), all 29 clip-out descriptors dumped from Brave fixtures
(29 of 29 exact), and the 35 formerly declined CSS border descriptors
(35 of 35 exact). These replay results precede the current integration.

The macOS browser renders natively and never sets up sokol.gfx, so
`gg.canvas` sets up a headless Metal context. sokol allocates its pools
through V's allocator, so the context and its precompiled pipelines are
created in Vox's persistent arena; each draw uses a fresh surface on the main
thread. (Creating the context inside a paint scope corrupted sokol's pools
once that scope's arena was reclaimed; `ggtext` keeps `gg.canvas`' typeface,
strike and glyph caches in the persistent arena for the same reason.)

`capture_ab.py` with `VOX_GG_TEXT=1` and `VOX_GG_SHAPES=1` together (Vox
`651df85fb`, V `cb7d505099`, executable `27e72ca8`, unchanged before and
after): **262 of 262 fixtures pixel-equal**, none different, unstable or
failed. A separate lldb count of the shape descriptors:

| Shape descriptors | Count | Fixtures |
| --- | ---: | ---: |
| Drawn by `gg.canvas` (29 of them with clip-outs) | 367 | 85 |
| Declined: CSS border modes (12 elliptical rings, 8 three-sided labels, 15 single sides) | 35 | 7 |

These historical 35 declines match the 35 calls that still reach `libVoxGraphite` (17
region, 9 full-surface and 9 batched calls); in those 9 batches, shapes
`gg.canvas` drew before the declined one were discarded. 87 fixtures draw
shapes through these entry points. Before clip support, the same count was
338 drawn and 64 declined.

### Paths in the browser (`VOX_GG_PATHS=1`)

The path and SVG-image entry points offer their descriptors to `ggshape.draw_path`
and `ggshape.draw_svg_image`. Supported fills and strokes include gradients and
rounded clips. SVG images concatenate parent and path matrices, apply their
viewport, and use a layer for the rounded clip. Here "SVG image" means a batch
of vector paths, not a general bitmap/image draw.

The preceding session compared 2,000 path descriptors exactly against
`libVoxGraphite`; SVG image and region comparisons were 794 of 800 exact, with
six declines and zero differences. The canonical integration reran 2,000 solid
path descriptors (all exact), and a different SVG gradient cohort: 590 of 800
exact, 210 declines, zero differences or original-backend failures. Coverage
counts belong to their particular seeds and flags; they are not interchangeable.

Canonical Vox `09d135d80` adds affine non-scaling strokes, including SVG image
and region draws. The adapter transforms the completed path's points and conics
like SkPath, retains oval classification for axis-aligned transforms, and leaves
the original clips in device space. Standalone strokes reset the draw matrix;
embedded SVG strokes concatenate SkMatrix's inverse so only the path's user-space
transform is cancelled, preserving the parent transform and SkM44 rounding.
Singular intersect clips and non-invertible SVG matrices follow Skia's no-op
behavior. Perspective and other unsupported draws still fall back atomically.

Focused checks against the original `libVoxGraphite` with `--non-scaling`
(mixed fills and strokes; the flag changes strokes without consuming random values):

| Cohort | Comparisons | Exact | Declined | Different / original failed |
| --- | ---: | ---: | ---: | --- |
| Paths, seed 20261105 | 2000 | 2000 | 0 | 0 / 0 |
| Gradient paths, seed 20261105 | 2000 | 1741 | 259 | 0 / 0 |
| SVG images and regions, seed 1 | 800 | 800 | 0 | 0 / 0 |
| SVG images and regions with gradients, seed 2 | 800 | 596 | 204 | 0 / 0 |

The solid path and SVG-gradient cohorts also pass through an optimized C-O3/LTO driver.
Both GG adapter test files pass normally and with `-prod -gc none`, including
original-backend comparisons for clips, affine SVG parents, singular matrices,
row padding and unchanged pixels after an unsupported batch. The assembly audit
finds zero fused multiply-adds in `ggshape__*`. See the
[non-scaling stroke receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/non-scaling-20261105.json) for pins,
commands, exits, retained failed attempts and raw evidence. These checks exercise
the adapter directly and do not establish browser acceptance.

Browser A/B results with text, shapes and paths enabled:

| Bundle | Fixtures | Pixel-equal | Different / unstable / failed |
| --- | ---: | ---: | --- |
| stage18 | 262 | 262 | 0 / 0 / 0 |
| stage19 | 262 | 262 | 0 / 0 / 0 |
| stage20 | 262 | 262 | 0 / 0 / 0 |
| stage21 | 262 | 262 | 0 / 0 / 0 |
| stage22 (`ff4cd6dc66`, canonical integration) | 262 | 262 | 0 / 0 / 0 |

Stage21 used Vox `60516f48f`, V `276636673e`, executable
`54eedf139a745d9daadffe4a3a75a99d6089550ed3f0f80dd3c65d7375f6f91c`, unchanged
before and after. The older rows retain their capture logs; superseded bundles
and PNG directories were removed in the earlier disk cleanup. These captures
mask only the status bar's live RAM readout and do not establish parity with Brave.

Stage22 originally failed with ENOSPC before compilation. The continuation
completed a GG-enabled canonical production build, including the inverse-fill,
per-edge AA and non-scaling stroke work. Receipt `20261105-112409-8bb6c959`
pins executable
`58129def664e8367a17cd04b3f8e8e313d3665ac31187ba71fe475b33a920ef9`
and V `ff4cd6dc66`. The frozen source record is based on canonical HEAD
`6835e42ea`, with dirty shared changes recorded by its input hashes; it is not
a clean-commit build. The GG compiler lacks native-header splitting, so this
build uses one C unit despite requesting parallel compilation. It supplies no
performance comparison with the standard compiler's split builds.

With `VOX_GG_DIAGNOSTICS=1`, all 262 historical fixture names, using their
current canonical contents, matched on their first control/candidate pair.
No repeats were needed. All 524 browser launches and the memory guard exited
zero; executable, native libraries, fixtures, runner, manifest and the Guardian
font hashes stayed unchanged. Captures used a 1024x852 window and the existing
224x24 RAM-readout exclusion, private profiles and fresh browser processes.

Candidate-log descriptor counts for this cohort:

| Adapter | Drawn | Declined | Fixtures with calls |
| --- | ---: | ---: | ---: |
| Shapes | 535 | 0 | 87 |
| Paths | 436 | 3 | 81 |
| SVG vector batches | 57 | 0 | 14 |

The three declines are gradient descriptors in `css-gradient-masks` (one) and
`svg-path-coverage` (two); their Skia fallback preserves the matching pixels.
`device-layout-svg-user-space` executes one non-scaling stroke through GG.
These counts include repeated paint calls; they count adapter descriptors,
not all primitives or all Skia work. Text registration is verified, but these
diagnostics do not count glyph runs. Recording canvases, GPU picture playback
and other bypasses still use Skia. The historical stage17 counts (394/4 shapes
and 205/103 paths drawn/declined) belong to a different bundle and workload.

The current runner automatically enables `VOX_GG_DIAGNOSTICS=1`, verifies the
requested adapters registered in each candidate process, pins executable,
native-library and fixture/resource hashes throughout, retains actual exits,
and fails on changed inputs or rendering failures. The canonical input directory
now has more than 262 fixtures; use the recorded historical fixture list when
continuing that cohort. See [the tool instructions](../tools/gg_migration/README.md).

The first continuation run was correctly rejected after 58 matching pairs when
the shared builder replaced the executable and libraries. `4415f3e07` adds a
shared bundle publication lease: captures retain the canonical app while builds
can compile, then publication waits for readers to finish. Five lease checks
and 22 build-supervisor checks pass. During the successful full run, a completed
standard build actually waited at publication and installed after the lease
released. The shared app may therefore differ from this tested GG bundle now;
the receipt and capture hashes identify the accepted result.

The recompare fix `fcfceaebc` preserves interrupted-run exits and provenance,
rejects missing registration proof and unknown exits, and keeps incomplete
cohorts from passing despite equal PNGs. The runner also supports explicit
resource files and automatically pins its source and fixture manifest
(`1fac432a7`); all 14 capture-tool checks pass. The full browser run preceded
that final tool change and used an equivalent per-launch hash extension for
its font, runner and manifest. See the
[stage22 receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/stage22-20261105.json) for commands, build
identities, coverage, actual exits, rejected attempts and retained raw evidence.
The older `49a4b05f` capture remains baseline evidence in the non-scaling receipt.

### Brave fixture inventory

`libvox_metal_trace.dylib` traced the production bundle on all 262 Brave
fixtures (`classify_inventory.py`; the bundle's hashes were identical before
and after). Fixtures using each Metal renderer:

| Renderer | Fixtures |
| --- | ---: |
| Graphite CoverBounds (non-AA fills, covers) | 146 |
| Dawn picture path (Tint MSL) | 113 |
| Graphite AnalyticRRect | 112 |
| Graphite tessellated wedges (path fills) | 78 |
| Graphite middle-out fans | 15 |
| Graphite tessellated strokes | 8 |
| Graphite coverage masks (path atlas) | 6 |
| Graphite per-edge AA quads | 3 |
| None (CPU Skia and CoreGraphics only) | 58 |

Text, images and most decorations of every fixture go through the CPU Skia
bridge as well.

## Removing Skia (started 2026-11-06)

The goal is a binary with no Skia at all, keeping every pixel Skia produces
today. Each Skia call is replaced by a Skia-free V port only once it matches the
pinned build byte for byte, and the Skia code is deleted in the same change.
CPU ports live in the `cpuraster` module (`gfxfont` for font validation); their
oracle `tools/gg_migration/skia_cpu_oracle.cpp` keeps the original Skia
implementations verbatim, and `test_cpu_raster.sh` compares them against
LibWeb's vcpkg Skia (`google/skia@ee20d565`, the same revision as Linux).

To find the exact arithmetic, run the original call under lldb: breakpoints on
the `neon::` and `neon::lowp::` stage functions list the raster pipeline Skia
actually executes, and stage contexts hold its constants (transfer functions,
gamut matrices, sampling matrices). The disassembly shows which operations
fuse: this Skia is built with `-ffp-contract=off`, so only explicit `mad()`
(`fmla`/`fmls`) fuses. Ports must keep every other product in its own
statement, because clang fuses `a + b * c` written in one V expression;
`tools/raster_tests.py fma_audit.py --contracted-only` lists any it finds. V
calls `dlsym` pointers without prototypes, so oracle entry points take their
integer arguments as one `i32` array.

| Dependency | Users | Status |
| --- | --- | --- |
| `skia.read_pixels` (SkBitmap::readPixels) | getImageData/putImageData | `cpuraster.read_pixels`; all 65,536 channel/alpha pairs (NEON blocks and tail) plus 20,000 random geometries exact |
| `skia.font_typeface_is_valid` (SkFontMgr makeFromStream) | CSS font loading | `gfxfont.typeface_data_is_valid`: CoreText descriptor/font creation, or FreeType face, axes and design coordinates on Linux; 3,022 font comparisons equal |
| `skia.export_bitmap_to_byte_buffer` (drawImageRect into export formats) | WebGL texture uploads | `cpuraster.export_bitmap_to_byte_buffer`: lowp/highp pipelines, Display P3, nearest sampling with draw tiles, legacy fixed-point sampler; 448 exhaustive and 100,016 random exports exact |
| `skia.draw_path` solid fills | Canvas 2D `fill()`/`fillRect()` | `cpuraster.fill_canvas_path` for solid source-over fills without shadows or filters, including SVG arcs and global alpha: Skia's analytic AA (`SkScan_AAAPath`, analytic edges, edge and line clippers with `SkCubics` chops, introsort) and legacy `SkARGB32` blitters on macOS's `SkPathRef` paths; 60,000 random fills and 5,000 production canvas fills exact |
| `skia.draw_path` hairline strokes | Canvas 2D `stroke()`/`strokeRect()` whose `lineWidth` maps to at most one device pixel, including the default width 1 untransformed | `cpuraster.stroke_canvas_path` for solid, undashed source-over strokes without shadow blur or filters: SkDraw's thin-stroke-as-hairline alpha scaling and SkCanvas's quick reject, `SkScan_Hairline` flattening with butt, square and round caps (cubics chopped at maximum curvature), `SkScan_Antihair`'s four line walkers with fixed-point range and rect clipping; 36,124 random strokes exact |
| `skia.draw_path` wider strokes | Canvas 2D `stroke()`/`strokeRect()` wider than a device pixel | `cpuraster.stroke_canvas_path` for the same solid source-over strokes: `skpathutils::FillPathWithPaint`'s `SkStrokeRec` at the matrix's resolution scale, `SkStroke`/`SkPathStroker` (quad approximation of quads, conics and cubics with their recursion limits, inflection splits and cusp circles, degenerate-curve reductions, `strokeRect` for closed rects) with `SkStrokerPriv`'s caps and joins (unit-arc round joins, miter limits), then `SkPathBuilder::transform` and analytic AA fill, keeping a rect outline's known convexity; 150,000 random strokes over five seeds, 112,726 of them wider than a device pixel, exact in both default and `-prod -gc none` builds |
| `skia.draw_path` dashed strokes | Canvas 2D `setLineDash()` strokes | `cpuraster.stroke_canvas_path` with `SkDashPathEffect`: `ValidDashPath`/`CalcDashParameters` (invalid lists leave the stroke undashed), `SkDashPath::InternalFilter` with its cull rect (the device bounds mapped through `SkMatrix::invert`/`mapRect`, lines and rects trimmed in phase, the closed-rect corner join), `SpecialLineRec`'s direct quads for butt-capped lines, the million-dash limit's fallback, and `SkContourMeasure` (length tables with curve tolerances, `getSegment` with quad, conic and cubic chops); the dashes are then drawn as hairlines or stroked; 100,000 random dashed strokes over five seeds, 66,597 of them wider than a device pixel, exact in both default and `-prod -gc none` builds |
| `skia.draw_path` clips | Canvas 2D `clip()` under fills and strokes | `cpuraster.canvas_raster_clip` with `SkCanvas::clipPath`'s anti-aliased intersections in device space: `SkRasterClip` (rect paths through `op(rect)` with its nearly-integral hard-edge test, path clips into an `SkAAClip`, and AA clips that are hard-edged rects back to rects, keeping `SkAAClip::isRect()`'s offset quirk), `SkAAClip` (the builder's coverage rows from an RLE analytic AA fill, row merging, Y-gap rows, top/bottom and left/right trimming, `quickContains`, and intersections run by run with `SkMulDiv255Round`), and `SkAAClipBlitter` merging the clip's coverage into every span and column; fills force the RLE blitter and hairlines go unclipped where the clip is opaque, as in Skia; quick reject and the dash cull rect use the clip's bounds; 100,000 random clipped fills and strokes (hairline, wide and dashed) over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` composite operations | Canvas 2D `globalCompositeOperation` under solid fills and strokes | `cpuraster` pipeline blitter (`SkRasterPipelineBlitter` for a constant color) for every operation, including the runtime-effect `plus-darker` and `plus-lighter` (their SkSL programs in highp, with `saturate()` as `min(max(x, 0), 1)`, coverage lerped and nothing skipped): `SkBlitter::Choose`'s fast paths (an opaque `copy` draws as source-over, an opaque `destination-in` draws nothing) and `SkPaint::nothingToDraw`, the constant color pipeline and `copy`'s memset, coverage scaled before or lerped after the blend, the lowp stages (wrapping 16-bit lanes, NEON's exact `div255`) and the highp ones for color-dodge, color-burn, soft-light, hue, saturation, color and luminosity (fused `mad`, `vminq`/`vmaxq` NaN and signed-zero rules, `rcp_fast` from a software `FRECPE` equal to the hardware's on all 2^32 inputs); thin strokes stay `SkStroke` outlines unless the mode supports coverage as alpha; 200,000 random composited fills and strokes over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` blurred shadows | Canvas 2D `shadowBlur` under solid fills and strokes | `cpuraster` blur (`SkBlurMaskFilterImpl`, normal style) as `vox_skia_canvas_path()` sets it up: sigma `blur / 2` mapped by `SkMatrix::mapRadius` (at most 128) in place of the canvas filters and global alpha, `SkCanvas`'s quick reject with the 3-sigma outset, rects and nested-rect rings as nine-patches (`SkBlurMask::BlurRect`'s analytic profile for one rect, the blurred ring for two, found by `SkPathPriv::IsRectContour` with its partial contours), and other paths drawn into an A8 mask through `SkA8_Blitter` (hairlines always with butt caps) and blurred by `SkMaskBlurFilter` (its Bessel-normalized Gaussian kernel below sigma 2, three box passes above, nothing below 1/3), then blitted through the clip; masks more than 8191 pixels across are filled with the non-anti-aliased `SkScan::FillPath`, as `SkScan::AntiFillPath` falls back to it; 200,000 random shadows over five seeds exact, none declined, in both default and `-prod -gc none` builds |
| `skia.draw_path` gradients | Canvas 2D `createLinearGradient()`, `createRadialGradient()` and `createConicGradient()` fills and strokes | `cpuraster` gradient shaders as `apply_style()` builds them: `SkGradientShader::MakeLinear`, `MakeTwoPointConical` (radial, concentric, strip and focal geometries, with `FocalData`'s swap, on-circle, well-behaved and smaller/greater cases and their degenerate masks) and `MakeSweep`, their degenerate fallbacks to `SkShaders::Color()` (the last color, or a thin ring as a radial gradient) and null shaders, and `SkGradientBaseShader`'s stops (implicit end stops, monotonic pinning, uniform stops as evenly spaced, hard-stop runs reduced); the pipeline's seed, `appendMatrix()` matrix (the inverse CTM concatenated with the unit matrix from `SkMatrix::setSinCos`, `postScale`, `setPolyToPoly` and `Concat`), radius, unit-angle, conical, `clamp_x_1`, two-stop, evenly spaced and arbitrary fill and premul stages in lowp and highp; conical strip and focal gradients force highp, so every blend mode and coverage prescaling has a highp version; shaders never take the legacy blitter, opaque shaders draw source-over as Src, and the paint alpha follows as `scale_1_float`; 200,000 random gradient draws over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` patterns | Canvas 2D `createPattern()` fills and strokes | `cpuraster` image shaders as `apply_style()`'s `SkImage::makeShader()` builds them. LibWeb's Skia keeps `SK_ENABLE_LEGACY_SHADERCONTEXT`, so source-over draws of premultiplied sRGB images with equal, non-decal tile modes use `SkBitmapProcState` and `SkARGB32_Shader_Blitter`: `init()`'s tiling division, near-translate snapping and filtering checks, the translate and one-column shader procs, the scale, affine and translate matrix procs (16.16 and 32.32 fixed point, decal fast paths, 4-bit bilinear weights, remapping per 128-entry chunk), NEON `filter_and_scale_by_alpha()` and `blit_row_s32a_opaque`/`blend`, and `blend_row_A8` masks. Other patterns run `SkImageShader::appendStages()`: nearest sampling for integer translations, one-pixel clamps, repeat and decal tiling (lowp's half-open decal test, highp's inclusive edge), `gather_8888`, the four-sample bilinear sampler, `bilerp_clamp_8888` and its forced highp, and `SkColorSpaceXformSteps` to premultiplied sRGB, including Display P3 images; 200,000 random pattern draws over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` bitmap commands | Canvas 2D `clearRect()` and unfiltered `drawImage()` | `cpuraster.clear_canvas_rect`: `clipRect()` without anti-aliasing (a hard rect, or `SkAAClip::op()`'s rounded rect inside anti-aliased clips) and `clear()` as `drawColor(kSrc)` through `SkScan::FillIRect`. `cpuraster.draw_canvas_image`: `SkCanvas::drawImageRect()` with the strict constraint (mipmaps dropped, fillable rects, quick reject) and `SkBitmapDevice::drawImageRect()`'s `Rect2Rect` matrix, source clipping, subset extraction with `preTranslate`, `Draw::drawBitmap()`'s `SkTreatAsSprite()` and `SkBlitter::ChooseSprite()` (Memcpy, `Sprite_D32_S32` and the raster pipeline sprite blitter), and otherwise the clamped image shader (legacy context or pipeline, now with nearest sampling and lowp's fixed-point `bilerp_clamp_8888`) through `Draw::drawRect()` and `SkScan::FillRect`; transforms that do not keep rects rects fill the rect's path with `SkScan::FillPath` (into a region for the clear's clip, intersected with anti-aliased clips through `SkAAClip::setRegion()`, and through the image shader for images); 200,000 random clears and 200,000 random image draws over five seeds exact, none declined, in both default and `-prod -gc none` builds |
| Non-anti-aliased path fills | Rotated `clearRect()` and `drawImage()`, oversized blur masks | `cpuraster.fill_path` (`SkScan::FillPath`): `SkEdge`'s 26.6 and 16.16 fixed-point lines and forward-differenced quadratic and cubic segments, `SkBasicEdgeBuilder` (poly and clipped builds, vertical-edge combining), `SkTQSort`, `walk_edges()` for winding and even-odd fills and `walk_simple_edges()` for convex paths, the 16.16 clip limit, conservative bounds rounding and `SkScanClipper`; 200,000 random fills of lines, quads, conics and cubics over five seeds exact in both default and `-prod -gc none` builds. Inverse fills are not ported |
| `skia.draw_glyph_run` (`vox_skia_canvas_glyphs`) | Canvas 2D `fillText()` without filters | `cpuraster.fill_canvas_glyphs` on macOS, with CoreText doing exactly what `SkTypeface_Mac` and `SkScalerContext_Mac` ask of it (the font from the file's bytes, `SkCTFontCreateExactCopy()` at the strike's text size, advances and bounding rects through `fTransform`, glyphs drawn into the offscreen `CGBitmapContext`, CoreGraphics' inline point and size transforms evaluated without fused multiply-adds): `SkScalerContextRec`'s relaxed 2x2, `computeMatrices(kVertical)` with its Givens rotation, the quarter-pixel `SkPackedGlyphID` positions and rounding, `generateMetrics()`'s bounds rounding and outset, `SkTMaskGamma<3, 3, 3>`'s default sRGB tables selected by the paint's luminance color (a gradient's average stop color, gray for patterns), the blob's conservative quick reject from the typeface bounds, and `Draw::paintMasks()` through the existing blitters and anti-aliased clip; glyphs over 256 pixels per em are the 64-point strike's outlines (`generatePath()`'s 4x request through `SkCTPathGeometrySink`) filled like `SkCanvas::drawPath()`, concatenated onto the canvas matrix in `SkM44`'s float arithmetic or mapped first under a shader; color typefaces make ARGB32 strikes drawn whole by `Draw::drawSprite()` (sprite blitters, or a clamped image shader where the clip cuts them), and glyphs without outlines stay masks at path sizes; 80,000 random runs over two seeds (22,710 of them drawing, about 1,300 path-sized) and 10,000 color emoji runs (2,960 drawing) exact in both default and `-prod -gc none` builds. Declines faces past the first of a collection (Skia's CoreText manager cannot open them either), color glyphs 8192 or more pixels wide and non-finite positions; Linux uses the FreeType outline, bitmap and COLRv0 routes; COLRv1 remains pending |
| `skia.draw_path` and `draw_glyph_run` color filters | Canvas 2D `filter` lists of grayscale, sepia, saturate, hue-rotate, invert, opacity, brightness and contrast on fills, strokes and `fillText()` | `cpuraster.ColorFilter`: `SkImageFilters::ColorFilter()`'s composed `SkMatrixColorFilter`s, moved into the paint by `SkCanvasPriv::ImageToColorFilter()` and folded by `SkBlitter::Choose()`'s `RemoveColorFilter()`: `filterColor4f()`'s one-pixel highp pipeline for a solid color (then the legacy blitter when it fits in bytes, else the constant pipeline, highp through `unbounded_uniform_color` when a channel exceeds alpha), `SkColorFilterShader` stages after gradients and patterns, `CheckFastPath()` and `nothingToDraw()` seeing the filter, and the filtered luminance color for glyph mask gamma; 200,000 random filtered draws over two seeds exact in both default and `-prod -gc none` builds. Filters that change transparent black decline (they need an image filter layer) |
| `skia.draw_path` and `draw_glyph_run` filter layers | Canvas 2D filters on fills, strokes and text | `cpuraster.draw_filter_layer` and `draw_blur_filter_chain` cover scale/translate blur and drop-shadow layers, every composite mode, color matrices around one spatial filter and throughout repeated blur lists. Rotated layers, chains containing further shadow nodes, sigmas over 135, transparency-flooding matrices and tiling retain fallback. Native fixtures and comparison receipts are linked below. |
| Rest of `skia.draw_path`, `draw_glyph_run` (`canvas_raster.cpp`, `canvas_chromium_raster.h`) | Canvas 2D | **Removed 2026-11-10.** Draws the exact ports decline (rotated or skewed filter layers, SVG `url()` graphs, flooding color matrices, unported chain positions) use `cpuraster/general_filter.v`'s device-space layer; it is faithful but not bit-identical. Chromium-mode filtered `drawImage()` on macOS uses the exact CPU bitmap-space port instead of the Dawn picture replay. See [Removing the Skia module](#removing-the-skia-module-2026-11-10) |
| `skia.rasterize_shadow` (`shadow_raster.cpp`) | Portable (sokol/Linux) shadows | **Removed 2026-11-10.** `cpuraster.rasterize_shadow` keeps the exact outer, nested inner and text-shadow ports; intersecting inner contours, rotated/skewed text layers and other declines use the device-space fallback, and surfaces past 8,191 pixels draw in tiles |
| `libLadybirdVSkiaText.dylib` (`native_skia_text_darwin.cpp` and headers, 65 entry points) | macOS native painter (`native_capture_darwin.m`), HarfBuzz advances, glyph intercepts, PNG ICC | Not started: fonts and blobs feeding GG text, images and decode cache, gradients, shadows, blurs, SVG turbulence, command groups, SkPicture recording, Ganesh GPU canvas |
| `libVoxGraphite.dylib` (`native_graphite_darwin.mm`) | Loaded by the bridge | Shapes and paths partly through GG adapters; images, shadows, canvas presentation and pictures remain |
| `libVoxGraphiteDawn.dylib` | Picture playback | Not started |
| Linux `pkg-config skia` | Canvas and portable shadows | **Removed 2026-11-10.** The Linux browser builds and links without Skia; `tools/build_linux_skia.py` remains only for the differential oracle |

SVG fill/stroke geometry queries now use `cpuraster.path_hit_test`; the
production `vox_skia_path_hit_test` entry point and C transport are removed.
See the [path geometry checks](#path-containment-and-svg-hit-testing-2026-11-09).

Anti-aliased path filling, hairlines, the stroker, dashing, anti-aliased clips,
the legacy solid blitters, the raster pipeline blitter with constant colors,
gradient shaders and image shaders, the legacy bitmap shader context and the
blur mask filter are ported (see `cpuraster/scan_aaa.v`,
`cpuraster/scan_hairline.v`, `cpuraster/stroke.v`, `cpuraster/dash.v`,
`cpuraster/aaclip.v`, `cpuraster/pipeline_blitter.v`, `cpuraster/gradient.v`,
`cpuraster/image_shader.v`, `cpuraster/bitmap_proc.v`, `cpuraster/canvas_image.v`,
`cpuraster/scan_path.v` and `cpuraster/blur.v`), and so are the CoreText glyph
strikes of canvas glyph runs (`cpuraster/glyph_run.v`,
`cpuraster/glyph_coretext.h`), color-matrix canvas filters
(`cpuraster/color_filter.v`) and blur filter layers (`cpuraster/image_blur.v`,
`cpuraster/image_filter.v`, `cpuraster/filter_layer.v`).
Platform
differences matter: macOS LibWeb Skia uses the `SkPathRef` path backend
(trailing moves keep their bounds) and RGBA as kN32 (legacy blitters for RGBA
canvases), while the Linux build defines `SK_HIDE_PATH_EDIT_METHODS`
(`SkPathData`, which trims trailing moves) and `SK_R32_SHIFT=16` (BGRA kN32, so
RGBA canvases use the raster pipeline blitter). The native Linux behavior is
now ported and verified in the Linux RGBA section below. The pipeline stages follow the arm64 (NEON) build; x86 Skia's lowp
`div255` and its `rcp_fast` differ. Next prerequisite: the rest of the image filter
layers (mixed lists, rotations, SVG graphs).

### Drop-shadow canvas layers (2026-11-08)

`cpuraster` now draws a single Canvas2D `drop-shadow()` on fills, strokes and
text under a translation-only canvas transform. Shadow offsets may be
fractional: the image is blurred, sampled through a deferred SrcIn tint,
then merged beneath SourceGraphic before applying the original composite
operation and device clip. This keeps paint alpha on the source and shadow
tint alpha on the shadow. An invalid blur still leaves the tint, offset and
merge intact. Offscreen shadow input is intersected with the content before
unioning the foreground input, so it cannot unnecessarily enlarge the layer.

The port retains the padded image boundary and Skia's matrix-conjugation,
concatenation and integer-bound rounding order. Scaled drop shadows still
decline: differential checks found one-byte errors that require more of
FilterResult's resampling/crop analysis. Rotations, mixed filter lists,
composites that affect transparent black, oversized sigmas/layers and text
without typeface bounds also retain the native fallback. The existing scaled
single-blur path remains supported. This is another migration slice, not a
Skia-free browser.

Feature commit `244dc3607` passes 9,343 supported byte-for-byte comparisons
from 20,000 attempts in each of the default and `-prod -gc none` builds
(seed 20261106); 10,657 draws decline in each build without changing the
pixels. Seven focused raster test files pass normally, four also with
`-prod -gc none`; two HTML canvas test files and a final translation-path
HTML check pass. The full-browser type check passes and the final FMA audit
reports zero contracted multiply-adds. All ten final memory-guard receipts
have actual child exit zero. These are focused correctness checks, with no
production-browser, Linux-build or performance claim. See the
[verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/drop-shadow-20261108.json) for source and
oracle hashes, commands, exits and the unsuccessful intermediate candidates.

Linux dependency audit: `build-linux-browser.sh` still requires `skia.pc`;
`tools/build_linux_native.py` still builds the Skia canvas and shadow bridges;
`skia/canvas.c.v` links that archive and Skia; and
`cpuraster/glyph_scaler_linux.c.v` now selects the portable FreeType outline scaler; bitmap/color faces still decline. The macOS native text,
Graphite and Dawn dependencies listed above also remain. No Skia-free Linux
build has been produced. The local Linux VM failed to bring up SSH on both
startup attempts, so no Linux compilation took place during that slice.

### Portable outer shadows (2026-11-08)

`404906f5b` ports normalized rounded rectangles and AA clip subtraction;
`57422172f` routes untiled portable outer shadows through `cpuraster`.
The normalized geometry and transformed clips match 20,000 randomized pairs
per build, and outer shadows match all 30,000 cases per build (4,938 painted),
in both default and `-prod -gc none` modes. The corpus includes elliptical
corners, rotated/skewed clips, content holes, and zero, negative, tiny and
positive blur values. Focused V and native shadow tests pass; the FMA audit
reports zero contracted operations. The tests preserved local fast-bounds
rejection, hard clipping of nearly integral holes and the separate 24.8
rectangle coverage algorithm. See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/portable-outer-shadow-20261108.json).

Inner/text shadows, tiled surfaces and the other dependencies above remain
open. A new Linux VM now mounts the canonical checkout and has its system
dependencies and compiler installed; Skia-free browser linking is still pending.

`207516e40` also ports nested inner shadows whose outer caster is rectangular.
The difference path preserves PathOps' contour order, near-degenerate edge
elimination and conic endpoint joining. All 30,000 comparisons match in each
build mode (7,964 painted). Focused portable and native shadow tests pass, and
the FMA audit stays at zero contracted operations. The outer-shadow and rounded
rectangle tests also pass on Ubuntu 24.04 aarch64 in normal and `-prod -gc none`
modes, with compiler fallback disabled. The nested inner-shadow tests pass on
Linux too. `e3e879076` supplies the GNU feature flag needed by glibc's combined
trigonometry function. These module tests do not establish a Skia-free browser
link; see the [nested-shadow/Linux receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/nested-inner-shadow-20261108.json).

`fa8188a4e` ports retained text shadows through an unbounded blur layer and one
SrcIn tint on restore. It also adds retained-text baseline snapping, the
CoreText smoothing probe and gamma correction, zero-contrast mask tables, and
aliased large-glyph outlines. All 20,000 comparisons match in each build mode
(4,163 painted), across four smoothing modes, scale/reflection, rounded clips,
variable/color fonts, large glyphs and invalid blur. All 23 raster/native shadow
test files pass and the FMA audit stays clean. The earlier 10,000-case AA and
default-smoothing cohorts also passed. Headers and native oracle includes now
join the pinned differential inputs (`b5634a8cc`). See the
[retained-text receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/retained-text-shadow-20261108.json).

Linux staging now keeps UI2 under `Build/linux/modules` (`6c96821cf`); its real
staging check preserved all 140 entries in the shared macOS UI2 tree. This avoids
replacing host module symlinks with guest-only paths during concurrent builds.


## Removing the Skia module (2026-11-10)

The `skia/` V module and its native bridges (`canvas_raster.cpp`,
`canvas_chromium_raster.h`, `shadow_raster.cpp` and their headers) are
removed. This was the only Skia dependency of the Linux browser and the only
place V code linked `libskia` directly.

- **Canvas 2D** (`html/canvas_raster.v`) calls `cpuraster` directly. Every draw
  the exact ports cover keeps their Skia-identical pixels. Draws they decline
  used to fall back to Skia; they now use `cpuraster/general_filter.v`. That
  fallback evaluates the original `SkImageFilter` graph in device space: the
  unfiltered draw into a layer around the clip, blur (the raster blur engine,
  including its downsampled path above sigma 135), drop shadow, color
  matrices, Chromium's opacity table, and SVG `url()` graphs (blur, erode,
  dilate, merge, offset, linear/sRGB conversion, color matrix, filter-region
  crop), then a restore through the clip with the blender. CSS parameters map
  through the drawing transform. Rotated and skewed layers use the per-axis
  device scale, which is exact for similarity transforms and isotropic blurs.
- **Glyph runs** the ports cannot open draw nothing, as Skia's font manager and
  `drawTextBlob()`'s bounds check did (faces past the first in a macOS
  collection, non-finite positions).
- **Chromium-mode filtered `drawImage()`** on macOS used the Dawn picture
  replay. It now uses the exact CPU port of Chromium's bitmap-space policy
  (`draw_canvas_image_filtered(..., bitmap_filter: true)`), then the fallback.
- **Portable shadows** (`cpuraster.rasterize_shadow`) keep the exact outer,
  nested inner and text-shadow ports. Inner holes that cross the outer shape
  use a DstOut difference, rotated or skewed text shadows use the same
  device-space layer, and surfaces wider or taller than 8,191 pixels draw in
  translated tiles.
- **Path hit testing**, the packed path type and the shadow command types
  moved into `cpuraster` (`PackedPath`, `PackedPathHitTest`, `ShadowCommand`).

The fallback results are faithful, not bit-identical. On draws both paths can
take, the fallback stays within 3 of 255 per channel of the exact port for a
scaled blur and a drop shadow (`cpuraster/general_filter_test.v`).

The HTML canvas parity suite (`html/canvas_cpu_raster_test.v`) used
`skia.draw_path()` as its in-repository oracle. Before removal, all its
comparisons passed on Linux and their 128 results were frozen as SHA-256
hashes in `html/testdata/canvas_cpu_raster_hashes.json`. The suite now compares
against those hashes. The differential suite in `vox-tests` keeps comparing
the exact ports against the pinned Skia. The macOS compile of this
browser-sized test exceeds the 12 GiB shared memory guard, as before, so it
runs on Linux.

Verification (2026-11-10):

- **macOS:** nine cpuraster suites pass, with the new
  `general_filter_test.v`, `shadow_command_test.v` and `packed_path_test.v`
  (the latter two moved from `skia/`). The full browser type-checks without
  the module (`-b c -check`). The FMA audit over a build that includes the
  fallback finds zero contracted operations (170 explicit). The first audit
  found 19 contractions in the new code, which were split into separate
  statements.
- **Linux (Ubuntu 24.04 aarch64 VM):** the moved and new cpuraster tests, the
  portable-shadow and SVG pointer-event layout tests, and all five HTML canvas
  suites pass, including all 128 frozen Skia-parity hashes. A full browser
  build (C backend, `-O0`) links FreeType, HarfBuzz, Fontconfig,
  JavaScriptCoreGTK, EGL/GLES and the system libraries. `readelf`, `ldd` and
  the symbol table contain no Skia. `--headless-smoke` passes. An Xvfb
  screenshot renders outer, inset and rotated text shadows through
  `cpuraster.rasterize_shadow`. Canvas readback returns the exact fill color
  and a blurred edge for a rotated `blur()` layer. FastC in that VM's V cannot
  compile a `json2` generic instance in browser-tab code; this is unrelated to
  Skia, and the C backend builds.
- **Linux canvas elements** are drawn correctly into their bitmaps but are not
  presented on screen: the portable painter's `draw_canvas` command only has a
  macOS body. This predates the change.

Implementation: `8abf9a7a7`; Linux build and CI: `856f6977b`. See the
[verification receipt](https://github.com/vox-browser/vox-tests/blob/77b442f592e3406e6e903d5040e44dd64fb756e5/evidence/gg-migration/skia-module-removal-20261110.json).

Still on Skia: `libLadybirdVSkiaText.dylib` (the macOS native painter's Skia
backend), `libVoxGraphite.dylib` and `libVoxGraphiteDawn.dylib`. The macOS
browser therefore still loads `libskia.dylib` through those libraries.

## Hacker News performance (2026-11-06)

GG's current adapters preserve pixels and sustain the same continuous-scroll
publication throughput as Skia. Load/capture uses **2.80% more main-process
instructions** with GG; every one of the seven alternating pairs increases.
This compares all three adapters enabled versus disabled in one executable,
`c05715c149c8a3f7b70644bb425bfdcd740e3cc0f37c59254bae74374b4dd6a5`,
receipt `20261106-123237-a1883a12` (single C unit, literal `-prod`, preallocation).
Unsupported and unmigrated draws still use Skia.

The complete archived 30-story homepage retains its scripts and resources,
replayed over loopback with no-store responses, fresh profiles/caches, retained
OS caches, 1024x768 document pixels and 2x backing scale. Both modes use the
same compiled inputs and native libraries under a publication lease.

| Metric | Skia | GG |
| --- | ---: | ---: |
| Load/capture main-process instructions, median of 7 | 1,822,155,059 | 1,873,254,992 |
| Document installation to native submission, median (range), ms | 174 (120–215) | 176 (127–203) |
| Navigation to native submission, median (range), ms | 491 (294–747) | 566 (327–697) |
| Continuous scroll: median of 4 full-window mean publication FPS | 59.8985 | 59.8983 |
| Scroll interval median, median of trials, ms | 16.647 | 16.636 |
| Scroll interval p95, median of trials, ms | 22.176 | 20.125 |
| Worst observed scroll interval, ms | 32.188 | 37.423 |
| Intervals over 16.667 ms, median of trials | 47.83% | 46.82% |

Instruction counts run from main-process creation through encoded document PNG;
filter helpers, GPU work and external services are excluded consistently. This
is a different scope from the historical total-browser coalition comparison
against Brave. The conservative maximum-GG/minimum-Skia instruction ratio is
1.04846. Native submission includes scripting, style/layout and rendering.
Other sessions and compilation overlapped on the 18-CPU host; the wide wall-time
ranges prevent an isolated renderer wall-time conclusion.

The continuous-scroll cohort delivers 600 precise events per trial at nominal
60 Hz, delta 3 (observed 6.5 CSS pixels per event), reversing every 60 events,
after four seconds of title-based settling. Four alternating pairs complete
2,400 inputs per variant: 4,329 Skia and 4,135 GG total publications, including
stationary publications, and 2,392 changing-scroll intervals each. Actual input
delivery is 59.994–60.002 Hz. Leading counted-scroll delays are 20.30–31.01 ms
for Skia and 20.65–22.66 ms for GG; trailing gaps are 4.37–13.34 ms and
6.73–11.75 ms. Throughput uses the entire first-to-last-input period. The
interval tails and deadline misses remain visible despite the near-60 average;
these are native publications, not physical display scanout.

All timed load PNGs and final scroll PNGs match the fixed Skia references. Final
scroll captures exclude only the existing RAM status rectangle and run after
the timing/counter endpoints. Separate diagnostics confirm 317 GG text draws
on load and, during continuous scrolling plus final publication, 1,194 text
draws and 20 SVG vector batches, with no callback declines. A separate live
HTTPS check loads all 30 stories at the requested viewport, completes readiness
without script/native errors, and scrolls through GG; it supplies no paired
live performance result.

The original 90-event reversal cohort remains retained: it reaches the 498.5px
page boundary, measuring 52.0835 versus 51.5725 FPS while some inputs hold at
the end. Those numbers do not establish continuous-motion throughput. The first
coalition diagnostic was rejected when another session launched an independent
Vox window during its ownership scan. The strict audit remains unchanged; the
later main-process protocol declares its narrower scope. The rejected viewport
preflight and source-change build failures also remain failures.

The benchmark and post-endpoint pixel capture are committed in `890da6bb9`;
`fa96f3caf` adds the continuous reversal schedule and scrolling-only mode.
All 91 focused measurement-tool checks pass; both completed cohorts and the
live check exit zero under their memory guards. See the
[performance receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/hacker-news-performance-20261106.json) for
every trial, executable/resource hashes, CPU diagnostics, host loads, actual
exits and the retained raw PNGs/logs. Reproduction commands are in the
[tool instructions](../tools/gg_migration/README.md).

## Performance after removing the Skia module (2026-11-11)

**Page rendering.** Hacker News on one production bundle (`e2c0baaf9`),
alternating GG and the legacy Skia renderer (`VOX_USE_SKIA=1`) over seven
load pairs and four continuous-scroll pairs, keeps every PNG identical.
Load/capture main-process instructions (launch through encoded PNG) have
medians of 2,351,195,275 for Skia and 2,395,174,453 for GG (+1.87%; all seven
pairs higher). Scrolling is unchanged: median mean scroll FPS 59.8949 versus
59.8934, median p95 interval 19.07 versus 19.35 ms. One hardware-counter
scrolling diagnostic per variant retires 3.7% more instructions with GG but
uses fewer cycles (4.65 versus 4.91 billion) and less CPU time (2,132 versus
2,204 ms).

`VOX_PROFILE_INSTRUCTIONS` checkpoints place the whole gap in the final painted
frame (layout attach to frame completion): 148.1M instructions with Skia and
199.7M with GG (medians of seven). The GG text adapter copied each run's raster
region into a gg.canvas surface and back one bounds-checked pixel at a time;
`0f920c4be`/`8bca8a7a8` copy rows. On the rebuilt bundle (receipt
`20261111-083210-ab5858e7`) the final frame costs 150.0M with Skia and 181.0M
with GG, and launch-to-PNG medians are 2,310,080,617 for Skia and 2,298,753,850
for GG (-0.49%, inside the ±40M spread between runs), with every load and
scroll pixel check exact and 59.90 FPS for both. The remaining frame cost is
gg.canvas' scalar glyph-mask blitting, which lives in V's `gg.canvas`.

**Canvas.** The vox-tests `CPU_RASTER_CHECKS=perf` mode draws eight fixed
800x600 scenes through the former Skia bridge (the oracle) and through
cpuraster, alternating sides, and requires identical final pixels. After the
module removal, cpuraster was 2-4x slower on scaled images and gradients and
rasterized every glyph of every fillText() again. Exactness-preserving changes
(`064a03804`, `7a3d63d00`, `2824880a6`, `a1dc93e6e`, `0584ad2d0`, `ec8958e8a`,
`533e8d8ed`, `2de5b20c5`) remove per-pixel bounds checks and closure
allocations, filter two channels per word in a loop clang vectorizes, process
gradient spans in batches and keep each canvas context's glyph masks in a
`GlyphCache`. Twenty-one alternating batches (vox-tests `a404a33`, host load
about 17-26 on 18 CPUs, so medians, minimums and cycles are all shown):

| Scene (draws) | Median ms Skia / cpuraster | Min ratio | Cycle ratio | Instructions Skia / cpuraster |
| --- | ---: | ---: | ---: | ---: |
| Rect fills (200) | 30.12 / 1.89 | 0.07 | 0.07 | 174.9M / 19.5M |
| Circle fills (100) | 13.02 / 1.66 | 0.13 | 0.13 | 91.3M / 18.5M |
| Hairline polylines (10) | 2.14 / 1.17 | 0.64 | 0.61 | 13.6M / 15.6M |
| 4px round strokes (10) | 3.99 / 3.83 | 1.03 | 0.96 | 30.4M / 35.5M |
| Linear gradient fills (50) | 9.57 / 8.44 | 1.05 | 0.94 | 64.2M / 89.6M |
| Blurred shadows (50) | 8.62 / 3.25 | 0.46 | 0.41 | 46.7M / 39.4M |
| Scaled 256->200x150 drawImage (50) | 12.30 / 8.42 | 0.79 | 0.72 | 100.2M / 104.3M |
| Text runs, 30 glyphs (50) | 33.75 / 2.15 | 0.08 | 0.07 | 185.3M / 30.9M |

Before these changes the same harness measured 667M instructions and
44.3 ms for scaled drawImage, 268M instructions and 13.8 ms for gradients,
and 207M instructions for text. The Skia column includes the bridge's
per-draw path, paint and typeface conversion, which dominates the rect,
circle and text scenes. Round strokes and gradients are at parity; Skia's
NEON pipeline still retires fewer instructions there.

The differential cohorts stay exact after the changes (gradients, patterns,
images, resampled and large image layers, composites, strokes, glyphs in
CoreText and FreeType modes, text and outer shadows, mipmaps, clips,
non-anti-aliased fills, rounded rectangles, shadows, color filters and filter
layers). Every glyph comparison also draws through one shared `GlyphCache`,
which must reproduce the uncached pixels. The
image-filter cohort exposes a gap that predates them and fails identically
on the earlier code: a drop shadow whose blur is below the identity
threshold, drawn from a source subset stretched over a
`[-1e9, -1e9, 3e9, 3e9]` destination, samples a different source pixel than
Skia (seed 20261131 case 3313; seed 1111 case 61).

## Remaining work

Stage22's GG-enabled browser comparison and drawn/declined summary are complete.
Keep using the shared build protocol, publication lease and memory guards for
later cohorts. Pin resources outside the default directories explicitly. Do not
delete the old GG worktree until its committed logic and retained evidence have
been incorporated and verified.

Next renderer gaps: general image entry points and texture sampling; true
two-point conical gradients; gradients with more than eight stops and linear
color space; layer paints; stroke-and-fill; empty inverse fills; remaining
rotated curved path clips; blurs, filters and shadows.

Remaining text includes synthetic bold, color glyphs, aliased masks, glyphs over
256px, fractional paint colors/F32 surfaces, shaders, and recording/picture text.
Frame-borrowing glyph tiles now offer device-clipped draws to GG. Partial clips
use a private copy of the original backdrop, with unchanged raster dimensions,
matrix and glyph positions. Only pixels inside the device clip are published
after a successful draw; a decline leaves the original backdrop for Skia.
Full-tile clips keep the existing direct path. This is a correctness migration;
the extra scratch copy has no measured performance benefit.

The shared recording canvas, SkPicture/Dawn picture playback, LibWeb CPU Skia
paths and Linux still need migration. Remove Skia only after those paths pass
the native, screenshot and browser pixel suites through a production bundle.


### Portable FreeType outlines (2026-11-08)

`37b39b5bd` adds Linux outline glyphs through FreeType's native rasterizer,
with the full strike decomposition, 26.6 sizing, 16.16 transforms, quarter-pixel
placement, mask gamma and the existing V blitters. Large glyphs use the
canonical 64-point outlines, and variable faces explicitly initialize their
default design coordinates. The macOS test switch uses the native FreeType face
factory and the same FreeType library for the reference and candidate.

Across 20,000 runs in each build mode, 18,631 are exact (5,326 painted, about
304 as paths); 1,369 decline. Bitmap/color faces and remaining filter/tiling
cases still retain fallback in this slice. Focused Linux tests pass normally
and with `-prod -gc none`, including hashes captured from native FreeType;
macOS's normal CoreText glyph/filter/text-shadow tests still pass. The FMA audit
reports zero contracted operations. See the [outline verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/freetype-outlines-20261108.json).

`38d1c9223` gives Linux its own production queue, receipts, memory locks and
publication lease under `Build/linux/production-build`. Its focused Linux
supervisor/lease run passes (37 tests, 11 platform skips), including publication
while the macOS build lock is held. Full-browser Skia removal remains open.


### Portable bitmap glyphs and mipmaps (2026-11-08)

`601709dab` ports image mipmap construction and selection; 20,000 random levels
match the native image sampler in each build mode. `f281b6557` adds FreeType
bitmap-only faces, color glyph sprites, strike selection, transformed bitmap
bounds, quarter-pixel phases, and resampling through those mipmaps. Scalable
faces keep embedded strikes disabled, matching the native font defaults.
An original 16-by-16 sbix fixture exercises tiny mipmapped glyphs and rotated,
nonzero bitmap origins on Linux as well as macOS's test-only FreeType backend.

Of 20,000 mixed-font runs per build, 19,688 match exactly (5,441 painted) and
312 decline. The fixture has 9,793 exact runs per build (3,831 painted), with
207 declines for invalid collection faces. Another 10,000 emoji-only runs
match in the normal build (849 painted). The portable fixture's native hashes
pass on Linux normally and with `-prod -gc none`; all 25 CPU raster test files
pass on macOS, and the FMA audit reports zero contracted operations. The
comparison tooling now pins font files and fixture data throughout each run.
See the [bitmap and mipmap receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/bitmap-glyphs-mipmaps-20261108.json),
including the failed diagnostic attempts and their corrections. COLR paint
graphs, oversized glyphs, other filters, the browser bridges and their Skia
links still remain; this is not a completed browser dependency removal.


### Portable layered color glyphs (2026-11-08)

`3bf202a52` adds COLRv0 palette/current-color layers. Small glyphs compose
native FreeType outlines into V-rendered color sprites. Large glyphs replay
the canonical 64-point outlines as vector drawables through saved layers,
including clip-relative allocation and transparency-affecting restores.
An original font fixture covers overlapping translucent outlines and current
text color. Over two seeds, all 48,971 supported runs match exactly; 1,029
invalid-face runs decline. This includes 10,000 normal runs and 20,000
production runs at seed 20261106 plus 20,000 normal runs at seed 20261108.
Focused Linux golden-image tests and CoreText regression tests pass; the FMA
audit reports zero contracted operations. See the [COLRv0 receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/colrv0-glyphs-20261108.json).
The broad Linux module run passes 25 files and exposes two platform-dependent
SVG arc/stroke hashes in `aaclip_test.v`; native Linux verification is pending.
COLRv1 graphs and the browser's remaining native dependencies are still open.


### Native Linux RGBA surfaces and reference fixtures (2026-11-08)

`36c6d146f` carries the destination storage policy through paths, glyphs,
images and filters. Linux RGBA canvases use the raster pipeline. FreeType
bitmap masks and image-filter content use native N32 scratch surfaces, which
are BGRA on Linux. Ordinary saved layers preserve the parent surface format.
This resolves the differences found by the native Linux comparison build.

All 26 CPU raster test files now pass on both platforms. Four focused Linux
files also pass with `-prod -gc none`. Native Linux differential checks match
20,000 clipped draws, 20,000 patterns, 20,000 images, 19,560 supported glyph
runs, 18,736 supported color-filter draws and 5,868 supported blur-layer draws.
The FMA audit reports zero contracted operations and 166 explicit operations.

The fixture capture tool records 60 complete native inputs and output hashes
on each platform. Its macOS outputs equal the frozen macOS test references;
32 Linux hashes differ. The earlier arc investigation is resolved: platform
libm and pixel-layout behavior require native Linux references. See the
[Linux raster report](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-rgba-raster-20261108.json),
[macOS fixture inputs](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/macos-native-raster-fixtures-20261108.json)
and [Linux fixture inputs](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-native-raster-fixtures-20261108.json).
These are module checks. The browser still links Skia; bitmap export sampling,
remaining filters, tiled draws, boolean shadows and native browser bridges
still require work.


### Linux bitmap export and scaled drop shadows (2026-11-08)

`478d7dcab` selects the native Linux raster-pipeline sampler for RGBA WebGL
bitmap exports. All 448 exhaustive configurations and 20,016 random exports
match in both normal and production builds. A native boundary fixture retains
the differing Linux and macOS row selection. See the
[bitmap export receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-bitmap-export-20261108.json).

`f58b137ad` enables single drop-shadow layers under scales and translations.
Saved layers have transparent borders; blur output has initialized borders
that require anti-aliased image edges when transformed. The distinction
resolves the original one-pixel mismatch, and merge surfaces now retain their
one-pixel padding too. Of 20,000 attempts per mode, 15,330 supported macOS
draws match in both normal and production builds; on Linux 16,298 match.
Unsupported draws preserve the destination. Focused platform and production
checks pass, and the arithmetic audit reports zero contracted operations.
See the [scaled-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/scaled-drop-shadow-20261108.json),
including native fixture inputs and the failed intermediate experiments.

The full Linux browser type check also passes. This does not establish a
Skia-free browser link or run: remaining filter, shadow and native bridge
fallbacks still link Skia.


### Filter restores with all composite operations (2026-11-08)

`87e152a92` removes the composite-mode fallback for single blur and
drop-shadow layers. Restores use a decal shader to fill the clip when the
blender affects transparent black and the filtered image does not cover it.
Empty filtered sources also restore through that blender, while the draw's
quick reject still avoids a restore. Fast bounds preserve the native handling
of empty path bounds.

All 12,195 supported blur draws match out of 20,000 attempts in each build
mode. Drop shadows match 17,475 supported draws in the normal seed-20261106
run and 17,395 in the production seed-20261108 run. The native Linux run
matches 18,608 supported drop-shadow draws. Four focused test files pass on
each platform, including Linux production mode, and 14 native fixtures cover
the clearing and runtime blend modes through an AA clip. The FMA audit reports
zero contracted operations. See the
[composite-filter receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/filter-composites-20261108.json).
Mixed filters, rotated layers, tiled draws and the native browser bridges
remain open.


### Filtered source images and bitmap-space policy (2026-11-08)

`289bb001b` adds translated, pixel-aligned color-filtered image subsets and
a CPU implementation of the bitmap-space blur/drop-shadow policy. Native
image filters preserve their source transform and sampling through
`FilterResult::MakeFromImage`; rasterizing into a layer first is not generally
equivalent. General source-image resampling therefore remains a fallback.
The browser preserves the existing macOS Chromium/Dawn image dispatch.

`a7401d378` fixes sprite eligibility when an RGBA source enters a Linux BGRA
filter layer. Native regression fixtures retain the differing platform rounding.
Of 20,000 attempts, 6,123 supported comparisons match on macOS and Linux at
seed 20261106; 6,223 match in production mode at seed 20261108. These counts
include no-ops and both CPU policies. Image/filter/bitmap-glyph focused tests
and HTML canvas integration pass. The FMA audit reports zero contracted
operations. See the [filtered-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/filtered-images-20261108.json)
for source identities, native fixture inputs, exact declines and failures.
This is CPU verification; Skia-free browser compilation and GPU image parity
remain open.


### Transformed nearest color-filtered images (2026-11-08)

`045e0ace6` extends deferred source images to scales, flips and rotations.
The matrix concatenation preserves SkM44 float association, and image edges
use the native antialiasing and sprite eligibility rules. Four added native
fixtures match on macOS and Linux, including a near-integer transform whose
AA clip prevents sprite snapping.

At seed 20261106, 6,745 of 20,000 comparisons match on both platforms,
with 13,255 declines; production seed 20261108 matches 6,870 with 13,130
declines. Counts include no-ops and the existing bitmap-space policy. Focused
macOS and Linux production image tests pass, and the arithmetic audit reports
zero contracted operations. See the
[transformed-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/transformed-images-20261108.json).
Linear mipmaps, clearing blends under general transforms, fractional source
subsets, image-space blur/drop-shadow, GPU parity and browser dependency
removal remain open.


### Linear mipmaps for filtered images (2026-11-08)

Deferred source images now support linear sampling under scales, flips and
rotations. Sampling interpolates the two adjacent mipmap levels before color
conversion, alpha and color filtering. Native fixtures cover magnification,
rotation and odd-size downsampling in premultiplied sRGB and unpremultiplied
Display P3.

At seed 20261106, 7,347 of 20,000 comparisons match on both macOS and Linux,
with 12,653 declines; production seed 20261108 matches 7,519 with 12,481
declines. Counts include no-ops and the existing bitmap-space policy. All 26
CPU raster test files pass on macOS; the image and mipmap files also pass in
Linux production mode. The FMA audit reports zero contracted operations and
170 explicit operations. See the
[linear-sampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linear-image-sampling-20261108.json).
Clearing blends under general transforms, fractional source subsets, direct
image-space blur/drop-shadow, mixed filters, general rotated layers, GPU
parity and full browser dependency removal remain open.


### Clearing composite modes on filtered source images (2026-11-08)

`b5fe5ba8d` restores color-filtered images across the clip for composite
operations that affect transparent black. Nearest sampling supports affine
transforms; linear sampling supports rect-preserving transforms. Scaled linear
edges use the native layer-space decal ramp. Runtime decal shader children
retain the base image level, matching the native matrix-record policy.

Sixteen new native fixtures match on macOS and Linux. At seed 20261106,
7,523 of 20,000 comparisons match on both platforms with 12,477 declines;
production seed 20261108 matches 7,683 with 12,317 declines. Counts include
no-ops and both CPU policies. All 26 CPU raster test files pass on macOS,
and the image tests pass in Linux production mode. The FMA audit reports zero
contracted operations. The full Linux browser type check passes in 40.23
seconds with 4.75 GB sampled peak RSS. See the
[image-composite receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/image-filter-composites-20261108.json).
The browser still links Skia; the type check does not establish a Skia-free
compile, link or run. Rotated linear restores, source clipping, direct image
blur/drop-shadow, mixed filters and native browser bridges remain open.


### Filtered source-image clipping (2026-11-08)

`e0cd3675f` clips source rectangles to the image before mapping the smaller
source into the destination. Empty clipped sources restore through the
composite operation; the original draw's quick reject and empty-rectangle
handling still precede that restore. Five native fixtures match on both
platforms.

At seed 20261106, 9,055 of 20,000 comparisons match on macOS and Linux,
with 10,945 declines; production seed 20261108 matches 9,161 with 10,839
declines. Counts include no-ops and both CPU policies. Focused image tests
pass on macOS and in Linux production mode; the FMA audit reports zero
contracted operations. See the
[source-clipping receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/image-source-clipping-20261108.json).
The remaining source-image, filter-layer and native bridge work still retains
Skia dependencies in the browser.


### Rotated linear source-image restores (2026-11-08)

`58d397180` extends clearing composite restores to rotated and skewed linear
source images. Singular values select image-space or layer-space decal
sampling. Layer-space edges retain the native scale decomposition and the
separate rounding of the two matrix stages. Nine native fixtures match on
macOS and Linux, including near-unit scales and all seven clearing/runtime
composite modes.

At seed 20261106, 9,057 of 20,000 comparisons match on both platforms with
10,943 declines; production seed 20261108 matches 9,161 with 10,839 declines.
Counts include no-ops and both CPU policies. All 26 CPU raster test files
pass; the image tests also pass in Linux production mode. The FMA audit
reports zero contracted operations and 175 explicit operations. See the
[rotated-restore receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rotated-image-restores-20261108.json).
Blur/drop-shadow source images, mixed filters, general rotated filter layers
and native bridges still retain browser Skia dependencies.


### Color matrices combined with filter layers (2026-11-08)

Filter layers now support color matrices before and after one blur, and
after one drop shadow. A real blur resolves the preceding matrices into
pixels; an identity blur keeps them deferred through the final color filter
and restore blend, preserving native quantization. Eight native fixtures
cover solid/pattern fills, a dashed stroke, clearing/runtime composite
operations, scaled layers, and unpremultiplied destinations.

Of 20,000 attempts, 15,813 supported mixed blur comparisons match on macOS
at seed 20261106, 15,772 in production mode at seed 20261108, and 16,717
on Linux at seed 20261106. Filtered-image comparisons also pass: 9,727
on Linux and 9,856 in macOS production mode, including no-ops and both CPU
policies. All 26 CPU raster files and the focused Linux production tests
pass. The FMA audit reports zero contracted operations. See the
[mixed-filter receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/mixed-filter-layers-20261108.json).
Color filters before drop-shadow, repeated spatial filters, rotated layers,
SVG graphs, source-image blur/drop-shadow and native bridges remain open;
the browser still retains Skia dependencies.


### Color filters before drop shadows (2026-11-08)

Drop-shadow layers now preserve the preceding color filters on the foreground
through its merge draw. Real shadow blurs resolve those filters into pixels;
identity blurs keep them deferred through tinting and sampling. An invalid
blur instead discards its shadow input filter while the foreground retains
it, matching the native filter graph. Five native fixtures cover the real,
identity and invalid blur branches.

The new `CPU_RASTER_CHECKS=mixedshadows` corpus matches 15,840 supported
draws out of 20,000 on macOS at seed 20261106, 15,896 in production mode
at seed 20261108, and 16,760 on Linux at seed 20261106. The unchanged
single-shadow corpus still matches 17,475 supported draws. Focused production
tests pass on both platforms, and the FMA audit reports zero contracted
operations. See the
[prefiltered-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/prefiltered-drop-shadows-20261108.json).
Spatial filter chains, rotated layers, SVG graphs, image-space blur/drop-shadow
and native browser bridges still retain Skia dependencies.


### Repeated blur filters (2026-11-08)

Sequences of blur filters now share a single source layer and evaluate
backward input-bound requests and separate quantized intermediate images.
Six native fixtures cover Gaussian and box passes, identities on either
side and within a chain, scaled layers, unpremultiplied targets and clearing
composites. Intermediate dimensions are checked before touching the target.

Of 20,000 attempts, 17,490 supported comparisons match on macOS at seed
20261106, 17,435 in production mode at seed 20261108, and 18,459 on Linux
at seed 20261106. All 26 CPU raster test files pass, the focused Linux
production tests pass, and the FMA audit reports zero contracted operations.
See the [repeated-blur receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/repeated-blurs-20261108.json).
Color matrices within repeated spatial chains, drop-shadow chains, rotated
layers, SVG graphs, image-space spatial filters and native bridges remain
open; the browser still retains Skia dependencies.


### Bitmap-space color filters (2026-11-08)

Explicit bitmap-space CPU color filters now draw into an N32 layer before
applying the color filter on restore. Three native fixtures retain the source
quantization and platform rounding for translated premultiplied images,
rotated unpremultiplied Display P3 images, and downsampled clearing restores.

Of 20,000 comparisons, 13,261 match on both platforms at seed 20261106,
with 6,739 declines. Production seed 20261108 matches 13,321 with 6,679
declines. Counts include no-ops and both CPU policies. Focused image tests
pass on macOS and in Linux production mode; the FMA audit reports zero
contracted operations. See the
[bitmap-color receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/bitmap-color-filters-20261108.json).
This validates the explicit CPU policy; the existing macOS Dawn dispatch is
unchanged. Direct image-space spatial filters, remaining spatial chains,
rotated layers, SVG graphs and native bridges retain browser Skia dependencies.


### Portable Linux shadow blending (2026-11-08)

Portable box shadows now select blending for the explicit RGBA surface instead of native N32. Two native fixtures freeze faint inner and outer shadows on both platforms. The isolated regression tests pass on macOS and Linux production builds; 20,000 existing Linux inner-shadow attempts also match, including 5,364 painted results.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/shadow-rgba-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Linux rounded-clip convexity (2026-11-08)

Axis-preserving transforms now retain rounded-rectangle convexity on Linux, matching immutable SkPathData. The legacy macOS path behavior is preserved. A frozen mask regression covers the quarter-turn rounding difference. Both platforms match 20,000 rounded-rectangle and difference-clip cases; Linux also matches 20,000 outer-shadow attempts, including 3,285 painted results.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rounded-clip-convexity-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Nested rounded inner shadows (2026-11-08)

Portable inner shadows now accept strictly nested rounded contours when bounding-box corners or concentric corner ellipses prove containment. Six native fixtures cover curved outer bounds, scales, rotations, antialiased overlap and concentric insets. The 20,000-attempt corpora match on macOS (5,134 painted), production macOS (5,167 painted) and Linux (5,155 painted). All 27 CPU raster test files pass; the FMA audit reports zero contracted operations. Intersections and shared edges still require the native fallback.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rounded-inner-shadows-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Color matrices within repeated blur chains (2026-11-08)

Repeated blur layers now retain color matrices between passes. Identity blurs
keep the matrices deferred; real blurs resolve them into N32 pixels before
sampling. Eight native fixtures cover clearing composites, patterns, scaled
layers, unpremultiplied targets and dashed strokes. Canvas integration tests
exercise fills, strokes and text.

Of 20,000 attempts, 16,044 supported comparisons match on macOS at seed
20261106, 16,079 in production mode at seed 20261108, and 16,985 on Linux
at seed 20261106. All 27 CPU raster test files and focused Linux production
tests pass. The FMA audit reports zero contracted operations. See the
[blur/color-chain receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/blur-color-chains-20261108.json).
Drop-shadow chains, general rotated layers, SVG graphs, image-space spatial
filters and native bridges still retain browser Skia dependencies.


### Spatial filters on pixel-aligned source images (2026-11-08)

Direct source-image filters now use V for integer-aligned premultiplied sRGB
subsets at full paint alpha, with one source pixel per device pixel. The
port retains unknown source-image boundaries for identity shadow sampling.
Eight native fixtures cover real and identity blur/shadow passes, subsets,
color-filter chains and clearing composites. A canvas integration test also
checks the direct CPU route against the native command.

Of 20,000 attempts, 18,973 supported comparisons match on both platforms
at seed 20261106, and 19,016 match in production mode at seed 20261108.
The existing Linux filtered-image corpus matches 13,283 supported draws.
All 27 CPU raster files, canvas integration tests and focused Linux
production tests pass. The FMA audit reports zero contracted operations.
See the [aligned-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/aligned-image-layers-20261108.json).
General source-image transforms, fractional subsets, paint alpha and color
conversion still require work, as do the remaining filter graphs and native
bridges. The browser retains Skia dependencies.


### Deferred source-image color state (2026-11-08)

Pixel-aligned source filters now retain unpremultiplied sRGB and Display P3
storage until the native filter graph converts it. Color matrices, identity
passes and shadow foregrounds keep that conversion deferred. Image shadow
merges also retain the original layer coordinates, preserving fractional
offset rounding. Twelve new native fixtures cover these branches; the
canvas integration test now exercises an unpremultiplied filtered image.

Of 20,000 attempts, 18,792 supported comparisons match on both platforms at
seed 20261106, and 18,771 match in production mode at seed 20261108. The
existing Linux image-filter corpus matches 13,330 supported draws. All 27
CPU raster files, canvas integration tests and focused Linux production tests
pass; the FMA audit reports zero contracted operations. See the
[source color-state receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-color-state-20261108.json).
Nonintegral mappings, source-image paint alpha, remaining spatial chains,
rotated layers, SVG graphs, tiling and native bridges retain Skia dependencies.


### Fractional source-image filter surfaces (2026-11-08)

Fractional in-bounds source rectangles now draw into an antialiased source
surface before filtering under scale/translation, including flips. Color-only
filters use the same surface policy. Source-image filter evaluation keeps its
original layer coordinates. Six native fixtures cover color conversion,
clearing composites, blur chains, fractional shadows and flipped sources.

At seed 20261106, 18,821 supported comparisons match out of 20,000 on both
platforms. Production runs match 4,698 of 5,000 at seed 20261108 and 4,694
of 5,000 at seed 20261109. All 27 CPU raster files, focused Linux production
tests and canvas integration tests pass; the FMA audit reports zero contracted
operations. HTML continues to round source rectangles; the integration test
checks its existing output and the direct fractional service separately.

The full current Linux browser typecheck passes in 50.18 seconds with 4.72 GB
sampled peak RSS after refreshing the VM UI2 dependency. Skia libraries were
available during that check. See the
[fractional-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/fractional-image-layers-20261108.json).
Source-image paint alpha, integer-source resampling, rotations, remaining
spatial chains, SVG graphs, tiling and native bridges retain Skia dependencies.


### Paint alpha before source-image filters (2026-11-08)

Filtered source images now keep paint alpha as a deferred DstIn filter before
the canvas filter graph. Real blurs resolve it into pixels; identity passes
and shadow foregrounds retain it through sampling and color filters. Invalid
shadow blurs still sample SourceGraphic with its paint alpha. Ten native
fixtures cover raw and fractional sources, sRGB and Display P3, unpremultiplied
storage, zero alpha, clearing blends and repeated blur/color lists.

Of 20,000 attempts, 18,735 supported comparisons match on both platforms at
seed 20261106, and 18,801 match in production mode at seed 20261108. The
existing Linux image-filter corpus matches 13,685 supported draws. All 27
CPU raster files, canvas integration tests and focused Linux production tests
pass; the FMA audit reports zero contracted operations. See the
[paint-alpha receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-paint-alpha-20261108.json).
Integer-source spatial resampling, source clipping, general rotated layers,
remaining spatial chains, SVG graphs, tiling and native bridges still retain
Skia dependencies.


### Resampling integer source images before blur (2026-11-08)

Scaled, flipped and fractionally translated integer source rectangles now
resolve their sampling, source color conversion, paint alpha and preceding
color filters together before the first real blur. Identity blurs preserve
that ordering. Native bounds analysis chooses clamp or decal and the backing
image or strict subset, including linear mipmaps. Eight new frozen native
fixtures match on both platforms.

At seed 20261108, 8,310 of 20,000 attempts are supported and exact on both
macOS and Linux. Production mode matches 8,349 at seed 20261109. The original
Linux filtered-image corpus matches 14,397 supported draws. All 27 CPU raster
files, the canvas integration test and focused Linux production tests pass;
the FMA audit reports zero contracted operations. Counts include no-ops and
explicit declines. See the [resampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resampled-image-blurs-20261108.json).

Source clipping, scaled shadow foregrounds, all-identity lists, near-integer
transforms, general rotated layers, remaining spatial chains, SVG graphs,
tiling and native browser bridges remain open. The browser still links Skia.


### Source clipping before spatial filters (2026-11-08)

Source rectangles that cross an image edge now clip before the source-to-layer
mapping. Quick rejection retains the original draw bounds, including clearing
blends whose clipped image has no visible pixels. This covers the previously
supported aligned and fractional-source shadows and resampled blur chains.
Shadow restores also reproduce FilterResult's nearest sampling within 1e-3 of
an integer translation while preserving the original geometry. A two-pixel
regression failed before that fix and matches the frozen native result after it.

At seed 20261108, 16,855 of 20,000 attempts are supported and exact on both
macOS and Linux. Production mode matches 16,803 at seed 20261109. All 27 CPU
raster files, canvas integration and focused Linux production tests pass. The
full canonical Linux browser typecheck passes with Skia available; no Skia-free
browser compile/link/run is established. The FMA audit reports zero contracted
operations. Counts include no-ops and explicit declines; nine new native
fixtures and the initial failing checks are in the
[clipping receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/spatial-source-clipping-20261108.json).

Scaled shadow foregrounds, all-identity and nearly integer source mappings,
general rotated layers, remaining spatial chains, SVG graphs, intersecting
boolean shadows, large-sigma rescaling, tiling and native browser bridges
continue to retain Skia dependencies.


### Deferred color through source-image identity blurs (2026-11-08)

When every mapped blur is an identity and a color matrix remains, integer
source images now retain their sampling, color conversion, alpha and matrix
list through the final image draw. The original expanded draw bounds still
control quick rejection, including clearing blends. Six new native fixtures
cover mipmaps, flips, P3, source clipping and a fully transparent clearing draw.

At seed 20261108, 17,281 of 20,000 attempts are supported and exact on both
platforms; production mode matches 17,298 at seed 20261109. All 27 CPU raster
files, canvas integration and focused Linux production tests pass. The FMA
audit reports zero contracted operations. Counts include no-ops and explicit
declines. See the [identity-blur receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-image-blurs-20261108.json).

Identity lists without color matrices, nearly integer deferred mappings,
scaled shadow foregrounds and the previously listed graph/native work remain
open. The browser still links Skia.


### Source-image identity blurs without color matrices (2026-11-08)

Integer source images now also restore all-identity blur lists when no color
matrix remains. Paint alpha stays in the raster pipeline, while unfiltered
full-alpha draws retain the native legacy eligibility. Linear mipmap sampling
correctly declines the legacy bitmap context and uses the raster pipeline.
Six new native fixtures cover these routes, including downsampling, P3,
unpremultiplied pixels, flips, clearing blends and fractional translations.

All 20,000 attempts are supported and exact on both macOS and Linux at seed
20261108, and in production mode at seed 20261109. The original Linux
filtered-image corpus matches 15,427 supported draws. All 27 CPU raster files,
canvas integration and focused Linux production tests pass; the FMA audit
reports zero contracted operations. The full canonical Linux typecheck also
passes with Skia available. Counts include no-ops. See the
[identity-sampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-image-sampling-20261108.json).

Nearly integer deferred mappings, scaled shadow foregrounds and the previously
listed graph/native work remain open. The browser still links Skia; a full
Skia-free browser compile/link/run remains unverified.


### Nearly integer source-filter mappings (2026-11-08)

Source filters now reproduce applyTransform's replacement of requested
sampling by default bilinear sampling for nearly integer incoming transforms,
and the final restore's separate reduction to nearest. Real blurs preserve
raw sRGB pixels when no deferred effect requires resolution, including
unpremultiplied storage. Color effects resolve with the original transform.
Slight scales with integer translations also use the native sprite shortcut,
including clearing blends whose clip lies inside the image. Thirteen new
native fixtures cover these rules and factored canvas transforms.

Of 20,000 near-integer attempts, 19,217 supported draws match on each platform
at seed 20261108; production mode matches 19,184 at seed 20261109. Factored
transforms match 19,265 on each platform and 19,207 in production mode. The
original Linux image-filter corpus matches 15,427 supported draws. All 27
CPU raster files pass, as does the expanded image fixture file on macOS and
Linux production builds. Canvas integration, the FMA audit (zero contracted
operations) and the full canonical Linux typecheck pass. Counts include
no-ops and explicit declines. Initial sampling/sprite failures and two
transient, unrelated regex compile failures are retained in the
[near-integer receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-image-filters-20261108.json).

Rounding-induced layer crops, scaled shadow foregrounds, remaining spatial
chains, rotations, SVG graphs, intersecting boolean shadows, large-sigma
rescaling, tiling and native browser bridges remain open. The Linux typecheck
uses Skia development files; a Skia-free browser compile/link/run remains
unverified.


### CPU mipmap exhaustion review verification (2026-11-08)

The review's proposed clamp beyond the mipmap pyramid was checked against
the pinned native CPU renderer. Its SkMipmapAccessor calls getLevel(), which
rejects a missing upper level and reloads the base image. When only the lower
level is missing, linear mode retains the available upper level without a
lerp. The separate extractLevel() API clamps, but neither these image shaders
nor the legacy bitmap context use that API.

Eight direct native shader cases match on both platforms. They distinguish
the base image's clamped edge (192) from the final 1x1 mip's average (96), at
scales .125, .1, .05 and .025 in nearest and linear mipmap modes. The portable
regressions pass in default and production builds on macOS and Linux. Another
2,000 macOS and 10,000 Linux mipmap-level comparisons pass. Production sampling
arithmetic is unchanged; comments explain the intentional fallback. See the
[native review verification](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/mipmap-review-native-20261108.json).


### Scaled source-image drop shadows (2026-11-08)

Integer source images under real drop-shadow blurs now resample through the
portable filter layer. The blur input resolves sampling, color conversion,
paint alpha and preceding matrices together. The foreground retains those
effects until the merge, avoiding an extra 8-bit quantization. Its original
global mapping is preserved before translating the merge surface. The blur's
sampling region is independent of the foreground extent. Reversed axes use
sorted double-precision integer filter bounds.

Eight new native fixtures cover scaled subsets, nearest sampling, P3 and
unpremultiplied sources, paint alpha, color matrices, downscaling, reversed
axes and fractional translation. All 86 image-filter reference fixtures pass
on macOS and Linux. Of 20,000 random scaled-shadow attempts, 17,958 supported
draws match exactly on each platform; production mode matches 17,975 at a
second seed. The broader Linux filtered-image cohort matches 16,195 supported
draws. Counts include no-ops and explicit declines.

All 27 CPU raster files, the focused FastC image tests, Linux production image
tests and HTML canvas integration pass. The FMA audit reports zero contracted
operations (175 explicit). The filter still declines identity or invalid
resampled shadow blurs, nearly integer shadow mappings and rounding-induced
layer crops. General spatial chains, rotations, SVG graphs, boolean shadows,
large-sigma rescaling, tiling and native/GPU bridges remain. The browser still
links Skia; a Skia-free Linux browser compile/link/run is unverified. See the
[scaled-source shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/scaled-source-image-shadows-20261108.json).


### Nearly integer source-image shadows (2026-11-08)

Real drop shadows now share the blur's raw-subset shortcut at nearly integer
source mappings. The shadow input can preserve unpremultiplied sRGB storage,
while the foreground keeps its original mapping and deferred effects until
merge. Color-converting sources retain the existing resampling path. Seven
new native fixtures cover both routes, source subsets, requested sampling
and factored canvas transforms. All 93 native image-filter fixtures pass on
macOS and Linux.

Of 20,000 attempts, 19,116 supported draws match on each platform; production
mode matches 19,032 at another seed. A separately factored Linux cohort
matches 19,075. The new raw-shadow regression fails without the change.
Focused C/FastC tests, Linux production image tests and HTML integration pass.
This small forwarding change reuses the preceding slice's broader checks.
Counts include no-ops and explicit declines. Rounding-induced crops and
identity/invalid resampled shadow blurs still decline, and the remaining
filter graphs, native/GPU services and Skia-free browser link/run remain
unfinished. See the [near-integer shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-image-shadows-20261108.json).


### Deferred identity and rejected source-image shadow blurs (2026-11-08)

Source-image shadows now keep sampling, source conversion, paint alpha,
color matrices and the SrcIn tint deferred when the blur is an identity.
Rejected blur nodes tint SourceGraphic, while the foreground still retains
its preceding matrices. Compatible offset sampling follows the native rules;
nearest sources requiring a separate linear resolve surface still decline.
The merge drops empty shadow/color-filter results from its bounds, preserving
the native surface origin and floating-point sampling.

Nine additional native fixtures bring the image-filter corpus to 102 exact
cases on both platforms. Of 20,000 identity-shadow attempts, 9,499 supported
draws match on each platform. Production mode matches 9,461 at another seed,
and the broader Linux image-filter cohort matches 16,430. Counts include
no-ops and explicit declines. The production cohort originally found a
one-byte origin error; its frozen regression produces 127 before the fix
and the native 128 afterward, with the whole-image hash matching as well.

All 27 CPU raster test files, C/FastC image regressions, Linux production
image tests and HTML integration pass. The FMA audit reports zero contracted
operations (175 explicit). The Linux browser typecheck passes with Skia
available; the later bounds correction is compiled and exercised by Linux
production image tests. Initial concurrent-edit compile failures and a
comparison rejected by the input guard are retained without pass credit.
The differential harness now enables globals for shared module diagnostics.
Concurrent pixel-readback work is preserved outside these commits and PR
changes. See the [identity-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-source-image-shadows-20261108.json).

Rounding-induced crops, nearest/fractional-offset resolve surfaces, further
spatial chains, rotations, SVG graphs, boolean shadows, large-sigma rescaling,
tiling and native/GPU bridges remain. The browser still links Skia, and a
complete Skia-free Linux browser compile/link/run remains unverified.


### Nearest source-image shadows with fractional offsets (2026-11-09)

Nearest source images now resolve their shadow tint, color conversion and
paint effects before a fractional linear offset. The foreground remains
deferred. The intermediate retains its transparent pixel border, and its
restore uses the destination's RGBA color type. Linux therefore keeps the
raster-pipeline shader where native N32 would be BGRA. The full pixel outset
is drawn without an unnecessary logical-layer clip; a thin-shadow control
captures legacy bilerp's nonzero four-bit contribution beyond epsilon-rounded
bounds. This fixes the second seed's one-byte coverage difference.

Twelve new native fixtures bring the image-filter corpus to 114 exact cases
on both platforms. Of 20,000 forced-nearest shadow attempts, 19,109 supported
draws match on each platform; production mode matches 19,131 at a second seed.
The broader Linux image-filter cohort matches 16,573 supported draws at seed
20261108. Counts include no-ops and explicit declines. All 27 CPU raster files,
C/FastC image regressions, HTML integration, the FMA audit (zero contracted
operations, 175 explicit) and the canonical Linux browser typecheck pass.

The standalone Linux image tests also compile with Skia unavailable to
pkg-config, then execute all 34 generated test functions. The link command
contains no Skia libraries; readelf and ldd confirm no direct or transitive
Skia dependency. Direct dependencies are FreeType, libm and libc. This proves
the portable image-raster module's build and execution, while the complete
browser still retains Skia services and uses Skia files for its typecheck.
A full Skia-free browser compile/link/run remains unverified.

Rounding-induced crops, additional spatial chains, rotated layers, SVG graphs,
intersecting boolean shadows, large-sigma rescaling, tiling and native/GPU
bridges remain. The [resolve-surface receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resolved-source-image-shadows-20261109.json)
retains source and binary identities, native hashes, the Linux dependency
inspection and initial failures without full-cohort pass credit.


### Mixed blur and drop-shadow graphs (2026-11-09)

`cda95382d` moves mixed blur/drop-shadow lists off the canvas Skia fallback
for axis-aligned saved layers: fills, strokes, glyph runs and bitmap-space
image layers. Color matrices remain deferred through identity passes, resolve
before real blurs and run before each shadow tint/foreground merge. Each
shadow evaluates its preceding graph separately for the foreground and blur
requests. Source bounds are intersected at each graph leaf before request
unions. Both details have frozen native regression fixtures. Evaluation above
256 graph visits declines before changing destination pixels.

Native captures supply 21 new fixtures on both macOS and Linux (40 mixed
filter fixtures total), including repeated shadows, scaled strokes, P3
patterns, identity passes and clearing composite modes. Random comparisons:

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, default | 20261109 | 5,000 | 3,896 | 1,104 |
| macOS, `-prod -gc none` | 20261110 | 5,000 | 3,811 | 1,189 |
| Linux ARM64, default | 20261109 | 5,000 | 4,141 | 859 |

All runs finish with unchanged input pins. The two earlier failing prototypes
are retained in the receipt and covered by regressions. All 27 CPU raster
test files, focused C/FastC filter-layer tests, and HTML canvas integration
pass. The FMA audit reports zero contracted operations (175 explicit FMAs).
The full Linux browser typecheck passes **with Skia available**.

A separate Linux `-prod -gc none` filter-layer binary compiles with Skia
unavailable to pkg-config and runs all 14 registered test functions, including
the three new tests. Its only direct dynamic dependencies are FreeType, libm
and libc; the transitive library list also contains no Skia. This is a
component proof. The existing production browser predates these changes and
still links Skia; a complete Skia-free browser compile/link/run is unverified.

Direct source-image mixed graphs, rotated layers, SVG graphs, boolean shadow
intersections, large-sigma rescaling, tiling and native/GPU bridges remain.
See the [checks, native fixtures and retained failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/spatial-filter-chains-20261109.json).


### Mixed spatial graphs on source images (2026-11-09)

`0554d9a4d` extends the branching evaluator to source images. Pixel-aligned
sources keep their raw alpha type, color space and paint alpha until each
consumer resolves them. Fractional source rectangles use MakeFromImage's AA
surface. The graph evaluates in the original image-filter coordinate system,
retains the correct known/unknown pixel boundary and applies global shadow
offsets. Fourteen new native cases cover interleaved matrices, repeated shadows,
P3/unpremultiplied input, source clipping, empty sources and zero-alpha clears.
All 128 native source-image fixtures verify on macOS and Linux.

| Platform/build | Sources | Seed | Attempts | Exact | Declined |
| --- | --- | --- | ---: | ---: | ---: |
| macOS and Linux, each | Aligned | 20261111 | 10,000 | 8,824 | 1,176 |
| macOS and Linux, each | Fractional | 20261111 | 10,000 | 8,853 | 1,147 |
| macOS, `-prod -gc none` | Aligned | 20261112 | 5,000 | 4,381 | 619 |
| macOS, `-prod -gc none` | Fractional | 20261112 | 5,000 | 4,431 | 569 |

Every cohort ends with unchanged input pins; exact counts include no-ops.
C and FastC image tests, all 27 raster test files, and HTML canvas image
integration pass. A fresh FMA audit reports zero contracted operations (175
explicit). The full Linux browser typecheck passes with Skia development
files available. The first attempt saw a temporarily incomplete shared
`main.v`; the successful retry pins its unchanged before/after identity.

A separate Linux production/no-GC image test binary runs all 35 registered
tests with Skia unavailable to pkg-config. Its direct dependencies are
FreeType, libm and libc, with no direct or transitive Skia linkage. This is
component evidence; the full browser still needs Skia. The existing production
bundle predates this change and cannot validate it.

General resampled integer-source mixed graphs still decline, along with the
remaining crops, rotations, SVG graphs, boolean shadows, large-sigma/tiling
paths and native/GPU bridges. The requested Skia-free full-browser Linux
compile/link/run remains unverified. See the
[source-image graph checks and native fixtures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-spatial-chains-20261109.json).


### Mixed spatial graphs after source-image resampling (2026-11-09)

`0061d1d78` supports scaled/flipped integer-source images when a real blur
precedes the first shadow. Each branch resolves the source using its own
first-blur sample bounds. Reusing one union-sized source surface changes
clamping and strict/decal sampling. Larger default and production cohorts
exposed that error; both full inputs and native output hashes are frozen as
regressions. Ten new native fixtures include those failures, minification,
identity prefixes, nearest sampling, source clipping and clearing composites.
All 138 source-image native fixtures verify on macOS and Linux.

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, current pinned compiler | 20261113 | 10,000 | 8,288 | 1,712 |
| Linux ARM64 | 20261113 | 10,000 | 8,288 | 1,712 |
| macOS, `-prod -gc none` | 20261114 | 5,000 | 4,137 | 863 |

Each accepted cohort finishes with unchanged listed input pins. Counts include
no-ops. C/FastC image tests, all 27 CPU raster files, HTML canvas integration,
and the full Linux browser typecheck pass. The latter uses installed Skia
development files. The FMA audit reports zero contracted operations (189
explicit with this compiler). Host checks pin compiler executable
`d39159ce199ca1aa9c8734d2ae4f4a05fd468d79165ad9a1e8a7c0d6b2ac3145`;
the receipt retains the compiler/test-harness and shared-edit setup failures.
These concurrent bounded checks establish pixel parity, not performance gains.

The Linux production/no-GC image-test executable runs all 38 registered tests
with Skia unavailable to pkg-config. Its only direct libraries are FreeType,
libm and libc, and its transitive library list contains no Skia. This remains
component evidence: the full browser and the older shared bundle still need
Skia, and a Skia-free full-browser Linux compile/link/run remains unverified.

Resampled graphs that branch into a shadow before a real blur keep the native
fallback so their original foreground stays deferred. Remaining crops,
rotations, SVG graphs, boolean shadows, large-sigma/tiling paths and native/GPU
bridges also remain. See the
[resampling graph checks and retained failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resampled-spatial-chains-20261109.json).


### Path containment and SVG hit testing (2026-11-09)

`c0bf6f955` translates path containment to V, including monotonic line,
quadratic, conic and cubic crossings, on-curve points, inverse/even-odd fill
rules and coincident tangent cancellation. SVG stroke queries use the existing
V dash and stroke-outline engines at the native identity resolution scale;
non-scaling strokes transform the geometry first. The production C entry point
and query struct are removed. The compatibility API in `skia/` now calls V.

| Platform/build | Seed | Containment queries | Fill/stroke queries |
| --- | --- | ---: | ---: |
| macOS, C backend | 20261116 | 100,000 exact | 100,000 exact |
| Linux ARM64, C backend | 20261116 | 100,000 exact | 100,000 exact |
| macOS, `-prod -gc none` | 20261117 | 50,000 exact | 50,000 exact |

These cohorts have no declines and finish with unchanged input pins. An
independent native capture supplies 72 coincident-curve boundary expectations
on each platform. Focused C/FastC hit tests, the compatibility API tests, all
28 CPU raster test files and SVG pointer/group/bounding-box integration pass.
Raster-suite credit combines 27 completed files from the interrupted batch
with a guarded final text-shadow check; no whole-batch exit is claimed.
The bounding-box fixture now owns its helper so it can compile independently;
its assertions are unchanged. The optional FastC differential driver encounters
an unsupported generic in V's math library; no FastC random-parity credit is
claimed. The FMA audit finds zero contractions (189 explicit operations).
The full Linux browser typecheck passes with Skia development files available.

A standalone Linux production/no-GC hit-test binary compiles with Skia
unavailable to pkg-config, then executes all four registered test functions.
Its only direct libraries are FreeType, libm and libc, with no direct or
transitive Skia linkage. This verifies the geometry component. The complete
browser still links Skia and its older production bundle cannot validate this
change. Full-browser Linux compile/link/run without Skia remains unverified.
See the [receipts, native fixtures and retained interrupted checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/path-hit-geometry-20261109.json).


### Resampled chains beginning with a real shadow (2026-11-09)

`5756031ad` preserves the source-image foreground through a first real
`drop-shadow()` in a mixed graph. Only the blur branch resolves its source
sampling, alpha and color filters. The merge draws the original deferred
foreground; later blur/shadow nodes consume that merged surface. Identity
blur and matrix prefixes remain supported. Identity/rejected shadows before
the first real blur still decline.

Eight new native regressions cover scaling, nearest sampling, minification,
P3/unpremultiplied input, flips, nearly integer mappings, repeated shadows,
clipped sources and clearing composites. All 146 native source-image fixtures
verify on both platforms. At seed 20261119, each platform matches 4,121 of
5,000 attempts and declines 879. Optimized macOS/no-GC matches 1,647 of 2,000
at seed 20261120 and declines 353. Counts include no-ops; every cohort ends
with unchanged input pins. Host contention and the separate eligibility sample
are retained without performance credit.

C/FastC image and filter-layer tests, HTML canvas integration, the full Linux
browser typecheck and the zero-contraction FMA audit (189 explicit operations)
pass. The typecheck uses installed Skia development files. The standalone
Linux production/no-GC image-test binary runs all 39 registered tests with
Skia unavailable to pkg-config and no direct or transitive Skia linkage.
Its direct libraries are FreeType, libm and libc. The complete browser still
links Skia, and full-browser Linux compile/link/run without it remains open.
See the [source identities, fixtures and guarded check results](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/shadow-first-spatial-chains-20261109.json).


### Resampled chains beginning with an identity shadow (2026-11-09)

`290baeab8` extends the source-view graph to identity shadows. The shadow
keeps its tint, color filters and image sampling deferred through merge. A
nearest source followed by a fractional linear offset resolves the tinted
input first, preserving both sampling operations. The lone-shadow renderer
uses the same preparation helper. Matrix prefixes stop folding at the first
shadow, so later matrices apply to its merged image.

Eight new regressions bring the independently verified native source-image
corpus to 154 cases per platform. The nearest/P3 case retains different
macOS and Linux native expectations. Random comparisons, including no-ops:

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, identity-first graph | 20261121 | 1,000 | 844 | 156 |
| Linux, identity-first graph | 20261121 | 2,000 | 1,661 | 339 |
| macOS, production/no-GC graph | 20261122 | 2,000 | 1,676 | 324 |
| Linux, existing nearest-source shadows | 20261123 | 2,000 | 1,921 | 79 |

Every cohort ends with unchanged input pins. C/FastC image and filter-layer
regressions, HTML canvas integration, the full Linux browser typecheck and
zero-contraction FMA audit (189 explicit operations) pass. The Linux standalone
production/no-GC image-test binary runs all 40 registered tests with Skia
unavailable to pkg-config and no direct or transitive Skia dependency. Its
direct libraries remain FreeType, libm and libc. The browser typecheck uses
Skia development files; the complete browser still links Skia.

Rejected mixed-graph blur nodes, rounding-induced crops, rotated layers, SVG
filters, boolean shadows, large-sigma/tiling paths and native/GPU bridges
remain. A full Skia-free Linux browser compile/link/run is still unverified.
See the [native platform expectations, checks and retained setup failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-first-spatial-chains-20261109.json).


### Rejected blur branches in mixed shadow graphs (2026-11-09)

`ab4ec8e68` handles rejected drop-shadow blur nodes in mixed graphs. The
shadow's tint/offset branch reads the original SourceGraphic while the
foreground retains its preceding filters. Source bounds, requests and fast
bounds follow that branch reset. Resampled images keep an unfiltered source
view independently of their resolved foreground. Invalid standalone blur
functions continue to discard preceding nodes as before.

Eleven new native image cases freeze resets before/after blurs, after earlier
shadows and after an alpha-changing matrix. All 165 image fixtures verify on
both platforms. Two additional geometry-layer cases replace the former
unsupported-case expectation with native pixels for both destination alpha
types; the rotation guard is preserved. The receipt retains that initial
assertion failure without whole-selection pass credit.

At seed 20261124, macOS and Linux each match 853 of 1,000 resampled graph
attempts, declining 147. Optimized macOS/no-GC matches 840 of 1,000 at seed
20261125, declining 160. Fill/stroke/glyph layer cohorts match 387 of 500 on
macOS and 400 of 500 on Linux, declining 113 and 100 respectively. Counts
include no-ops; all cohorts finish with unchanged input pins.

Final C/FastC focused tests, HTML canvas integration, the full Linux browser
typecheck and zero-contraction FMA audit (189 explicit operations) pass.
A standalone Linux production/no-GC executable runs all 42 image tests with
Skia unavailable to pkg-config and no direct or transitive Skia linkage.
Its direct libraries are FreeType, libm and libc. The browser typecheck uses
installed Skia development files, and the complete browser still links Skia.
Full-browser Linux compile/link/run without Skia remains unverified.
See the [native branch-reset fixtures and guarded checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rejected-shadow-graphs-20261109.json).


### Cropped deferred image views (2026-11-09)

`c03433aba` retains MakeFromImage's layer crop on deferred foregrounds and
shadow source views. The renderer clips intermediate source-over draws to
that crop. A visible crop followed by a fractional offset resolves the tinted
input first, preserving the crop and its quantization through both sampling
operations. Identity-first graphs bypass the raw blur-subset shortcut.

A bounded geometry search found three exact float inputs whose mapped image
extends one pixel past its stored layer bounds. The prior renderer declined
all three identity-shadow probes. Their float bits are frozen in twelve
independent native cases, covering identity, real and rejected shadow blurs,
alpha matrices, P3, unpremultiplied sources and clearing composites. All 177
native image fixtures verify on both platforms; C/FastC image and filter-layer
regressions pass.

Default macOS and Linux each match 880 of 1,000 crop-focused attempts at seed
20261127, declining 120. Optimized macOS/no-GC matches 880 of 1,000 at seed
20261128, also declining 120. Earlier identity/rejected-only cohorts each
match 453 of 500 and decline 47. Counts include no-ops; all cohorts finish
with unchanged input pins. The initial probe is diagnostic evidence, not a
performance measurement.

HTML canvas integration, the full Linux browser typecheck and zero-contraction
FMA audit (189 explicit operations) pass. The Linux standalone production/no-GC
image binary executes all 43 registered tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The browser typecheck uses installed Skia development
files, and the complete browser still links Skia. The older shared production
bundle predates this change.

Raw near-integer real-blur crop/resampling cases and other layer crops remain,
along with rotated layers, SVG graphs, boolean shadows, large-sigma/tiling
paths and native/GPU services. Full-browser Linux compile/link/run without
Skia remains unverified. See the [native crop cases, baseline probes and guarded checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/deferred-image-crops-20261109.json).

### Color-filter image crops and clearing restores (2026-11-09)

`216da0f27` preserves the source layer crop for color-filter-only images.
Bounded blends clip the draw; transparency-affecting blends resolve the cropped
image before restoring across the full clip. General affine bounds use mapped
float corners, retaining the existing double-precision scale/translate path.

The new random crop selection exposed a real mismatch at case 92: a gain of
100 amplified sampling beyond the source crop, producing red 39 instead of 36
at pixel (9, 8). The exact source, background and filter request are frozen as
a regression; independent native recapture on both platforms reproduces the
original full expected SHA-256. Twelve additional native cases cover gain,
opacity, P3, source alpha, clips and clearing modes. All 190 image fixtures
verify on macOS and Linux. Initial focused checks caught five rotated-image
regressions from applying scale-only bounds math; their failures remain in
the receipt and the final C/FastC image and filter-layer suites pass.

Default macOS and Linux each match 1,863 of 2,000 crop-focused attempts at
seed 20261129, declining 137. Optimized macOS/no-GC matches 1,888 of 2,000
at seed 20261130, declining 112. The broader image-filter selection matches
4,122 of 5,000 on each platform at seed 20261131, declining 878. Counts
include no-ops; every final cohort finishes with unchanged input pins.

HTML canvas integration, the full Linux browser typecheck and the FMA audit
pass (zero contracted operations, 189 explicit). A standalone Linux
production/no-GC executable runs all 45 image tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The browser typecheck uses installed Skia development
files. The complete browser still links Skia, and full-browser Linux
compile/link/run without Skia remains unverified. The shared production bundle
was not used to validate this fix; its parsed source manifest predates it.

Raw near-integer real-blur crops, rotated saved layers, SVG graphs, boolean
shadows, large-sigma/tiling paths and native/GPU services remain. See the
[original mismatch, native fixtures, input pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/color-image-crops-20261109.json).

### Nearly integer blur source crops (2026-11-09)

`66151b4db` handles rounding-induced source crops in single image blurs and
blur/color-filter chains. When a crop is visible to the requested blur input,
the source resolves sampling and alpha conversion first. A request wholly
inside the logical layer retains the native raw subset shortcut, including
unpremultiplied storage. Cropped near-integer shadow graphs still decline
without changing the destination; their branches need independent decisions.

A geometry search found three distinct float inputs that previously declined.
Eighteen new native regressions cover visible crops, interior requests,
premultiplied/unpremultiplied images, clearing restores and blur/color chains.
Every new native case changes pixels; all 208 fixtures verify on macOS and
Linux. The diagnostic search output retains duplicate hits explicitly, and
compiler failures from initial probe setups receive no comparison credit.

At seed 20261132, macOS and Linux each match 1,954 of 2,000 crop-focused
attempts, declining 46. Optimized macOS/no-GC matches 1,948 of 2,000 at seed
20261133, declining 52. The existing near-integer image selection matches
4,807 of 5,000 on each platform at seed 20261134, declining 193. Counts
include no-ops; all final cohorts finish with unchanged input pins.

C/FastC image and filter-layer tests, HTML canvas integration, the full Linux
browser typecheck and the FMA audit pass (zero contracted operations, 189
explicit). A standalone Linux production/no-GC executable runs all 46 image
tests with Skia unavailable to pkg-config and no direct or transitive Skia
linkage; direct libraries remain FreeType, libm and libc. The browser
typecheck uses installed Skia development files. The shared production bundle
was not used to validate this slice. The complete browser still links Skia;
full-browser Linux compile/link/run without it remains unverified.

See the [baseline declines, eighteen native cases, input pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-blur-crops-20261109.json).

### Cropped first-shadow image branches (2026-11-09)

`0ab10a4cf` resolves a cropped nearly integer source separately for each
first-shadow blur request. An interior request can retain raw source pixels
and their alpha type; a visible crop resolves sampling and conversion first.
The foreground remains deferred until merge. Lone cropped real shadows use
the same graph path. The source policy requires no pending color filter,
paint alpha, tint or color-space conversion before reusing raw pixels.

Eighteen new native cases cover lone shadows, interior requests and mixed
blur/color/multiple-shadow graphs, with both source alpha types. Every new
case changes pixels. All 226 native fixtures verify on both platforms.
The prior unsupported-case regression now covers a real blur before the
first shadow, which remains a separate unported case.

Default macOS and Linux each match 1,892 of 2,000 crop-focused attempts at
seed 20261135, declining 108. Optimized macOS/no-GC matches 1,902 of 2,000
at seed 20261136, declining 98. The existing first-shadow graph selection
matches 4,138 of 5,000 on each platform at seed 20261137, declining 862.
Counts include no-ops; all cohorts finish with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration, the full
Linux browser typecheck and the FMA audit pass (zero contracted operations,
189 explicit). The standalone Linux production/no-GC executable runs all 47
image tests with Skia unavailable to pkg-config and no direct or transitive
Skia linkage; direct libraries are FreeType, libm and libc. The browser
typecheck uses installed Skia development files, and the shared production
bundle was not used to validate this slice. The complete browser still links
Skia; full-browser Linux compile/link/run without it remains unverified.

See the [native branch cases, source pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/first-shadow-image-crops-20261109.json).

### Cropped image graphs with prior blurs (2026-11-09)

`b9ec7f034` retains a deferred source view when a real blur precedes the
first shadow. Each request for that blur can reuse raw storage or resolve
its visible crop independently. This removes the previous branch-order
restriction; the guard for differing parameter/mapped layer bounds remains.

Eighteen new native cases cover blur-before-shadow graphs, high-gain color
filters between nodes, interior clips and additional blur/shadow branches,
with both source alpha types. Every case changes pixels. The expectations
were captured independently before the V implementation change and verified
through the canonical fixture generator. All 244 native image fixtures verify
on macOS and Linux, and the former unsupported regression is replaced with
positive native expectations.

Default macOS and Linux each match 1,890 of 2,000 crop-focused attempts at
seed 20261138, declining 110. Optimized macOS/no-GC matches 1,891 of 2,000
at seed 20261139, declining 109. The broader resampled graph selection matches
837 of 1,000 on each platform at seed 20261140, declining 163. Counts include
no-ops; all final cohorts finish with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration, the full Linux
browser typecheck and the FMA audit pass (zero contracted operations, 189
explicit). The standalone Linux production/no-GC executable runs all 48 image
tests with Skia unavailable to pkg-config and no direct or transitive Skia
linkage; direct libraries are FreeType, libm and libc. The browser typecheck
uses installed Skia development files. The shared production bundle was not
used to validate this slice. The complete browser still links Skia, and
full-browser Linux compile/link/run without it remains unverified.

Other crop/bounds cases, rotated saved layers, SVG graphs, boolean shadows,
large-sigma/tiling paths and native/GPU services remain. See the
[independent native expectations, guarded checks and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/prior-blur-image-crops-20261109.json).

### Original source-image layer bounds (2026-11-09)

`bab7f6d56` preserves the integer layer bounds produced by MakeFromImage's
concatenated source transform. Single blur/shadow layers and blur/spatial
graphs use those bounds instead of re-mapping the parameter-space destination.
Raw near-integer subsets retain their actual snapped bounds. This removes
the guards that declined deferred shadows when the two calculations differed.

A bounded search found twelve declined geometries. Four distinct inputs,
including bounds that grow and shrink, are frozen in twenty-four native cases
covering identity/real shadows, prior blurs, color filters, P3, source alpha,
clips and clearing blends. The random baseline also exposed a real bug at
case 3: alpha 4 instead of 3 at pixel (25, 7). Its exact source, background
and filter request are saved; native recapture on both platforms reproduces
the original full expected SHA-256. All 269 native image fixtures verify.

Default macOS and Linux each match 1,920 of 2,000 bounds-focused attempts at
seed 20261141, declining 80. Optimized macOS/no-GC matches 1,935 of 2,000 at
seed 20261142, declining 65. Broader resampled graphs match 811 of 1,000 on
each platform at seed 20261143, declining 189; near-integer image layers match
955 of 1,000 at seed 20261144, declining 45. Counts include no-ops; every final
cohort finishes with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration and the FMA
audit pass (zero contracted operations, 189 explicit). The standalone Linux
production/no-GC executable runs all 50 image tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The initial full-browser typecheck hit an unavailable
method in concurrent SVG geometry work. After that source was corrected in
the shared checkout, the same check passed. The initial failure is retained;
no foreign source edits are included in this slice.

The browser typecheck uses installed Skia development files. The shared
production bundle was not used to validate this change. The complete browser
still links Skia; full-browser Linux compile/link/run without it remains
unverified. See the [original failure, native cases, source pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-layer-bounds-20261109.json).

### Large single-blur layers (2026-11-09)

`4115cd979` ports progressive resampling for sigmas beyond the raster blur
engine's 135 limit. Each pass keeps floating-point logical bounds and padded
integer surfaces. The low-resolution blur retains its final upscale until
restore. Single saved canvas blur layers support this path, including incoming
and outgoing color matrices and clearing blends. The standalone image blur API
also supports large, asymmetric sigmas. Native sigma clamping still applies.
Large direct source-image filters, spatial chains, drop-shadows, rotated layers
and tiled surfaces retain their guards.

Thirty-six independent native fixtures cover image subsets, threshold sigmas,
progressive rescaling, asymmetric axes, clips, color filters, strokes and
clearing restores. Four captured macOS mismatches freeze initialized padding,
color-filter ordering, logical bitmap subsets and clearing draw selection.
A narrow Linux fixture also exposed an intermediate-surface distinction:
saved canvas filters use N32 buffers, whereas the standalone image API keeps
RGBA. All thirty-six fixtures now match native expectations on each platform.

Default C builds match 2,000 large image-filter attempts on each platform at
seed 20261147 (147 empty results). The optimized macOS/no-GC image run matches
1,000 at seed 20261154 (69 empty). Default canvas runs at seed 20261146 match
2,539 of 3,000 attempts on macOS and 2,657 on Linux, declining 461 and 343.
The broader resampled graph control matches 846 of 1,000 on macOS at seed
20261155, declining 154. Counts include no-ops. All completed final cohorts
finish with unchanged input pins.

The first 2,000-attempt optimized/no-GC canvas run reached the unchanged 3 GiB
memory guard and supplies no passing result. Eight separate 128-attempt
processes, with seeds 20261153 through 20261160, subsequently matched 840 of
1,024 attempts, declining 184, within that same budget. The failed larger
attempt remains recorded. These bounded no-GC diagnostics do not establish
bounded allocation over a long-running no-GC process.

The focused C suites, HTML canvas integration, Linux browser typecheck and C
FMA audit pass (zero contracted operations, 189 explicit). The earlier three
image/filter suites also pass FastC. The new FastC large-blur suite fails the
captured degenerate linear-gradient fixture: an emitted-C probe shows a fully
transparent source layer. A capacity-initialization exploration also failed
and was reverted. No FastC canvas parity is claimed for this slice.

A separate Linux production/no-GC executable compiles with Skia unavailable
to pkg-config and runs all four new test functions, including the thirty-six
fixtures, under the 3 GiB guard. Its link command, `readelf` and `ldd` show no
direct or transitive Skia dependency; direct libraries are FreeType, libm and
libc. This verifies the component. The browser typecheck uses installed Skia
development files. The older shared bundle does not contain this change and
was not used to validate it. The complete browser still links Skia; full
Linux browser compilation, linking and execution without it remain open.

See the [native fixtures, failed attempts, final checks and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-blur-rescaling-20261109.json).

### Large aligned and fractional source-image blurs (2026-11-09)

`bfa0951df` sends large single-blur image filters through the CPU rescaling
engine when the original pixels are aligned or MakeFromImage prescribes an
AA surface for a fractional source subset. Exactly aligned factored mappings
also work. Image filters retain their original layer coordinates and RGBA
intermediate buffers. When the near-identity downsample is skipped, the blur
retains the source's alpha type instead of treating unpremultiplied pixels as
premultiplied. Other deferred source transforms keep their existing guard.

Thirty-five supported fixtures match independent native expectations on macOS
and Linux, covering P3, both source alpha types, paint alpha, color filters,
clips, clearing modes, clipped sources and asymmetric/scaled fractional
surfaces. Four further controls retain native reference hashes and verify that
unsupported transforms decline without changing the destination. The final
fixture explicitly checks raw unpremultiplied storage through a skipped
resample; final focused suites and the Linux component executable include it.

At seed 20261161, the baseline declines all 500 attempts. The new code matches
392 of those same attempts on each platform, declining 108. Default C builds
match 1,573 of 2,000 at seed 20261162 on each platform, declining 427. Optimized
macOS/no-GC matches 1,560 of 2,000 at seed 20261163, declining 440. The existing
converted-image control also passes. Counts include no-ops and every completed
cohort finishes with unchanged input pins.

The C source/image/filter suites, the corresponding FastC source/image/filter
suites, HTML canvas integration, Linux browser typecheck and C FMA audit pass
(zero contracted operations, 189 explicit). The earlier FastC saved-canvas
large-blur gradient failure remains separate. A standalone Linux production/
no-GC executable compiles with Skia unavailable to pkg-config and explicitly
runs all three new test functions under the 3 GiB guard. Its link command,
`readelf` and `ldd` show no direct or transitive Skia dependency; direct libraries
are FreeType, libm and libc.

These checks verify the component. The browser typecheck uses installed Skia
development files, and the older production bundle was not used to validate
this slice. Complete Linux browser compilation, linking and execution without
Skia remain open. See the [native expectations, baseline, guarded cohorts and
Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-source-image-blurs-20261109.json).

### Near-integer large blurs with skipped downsampling (2026-11-09)

`e51a070aa` admits near-integer source mappings when the native downscale-step
calculation omits both resampling passes. The original pixels and snapped
origin then follow the same path as a smaller blur. Existing eligibility
checks still exclude incoming color/alpha effects and visible source crops
that require resolution. Near-integer mappings that need actual resampling
retain their guard.

The baseline declines all 500 requests at seed 20261165. The new default C
builds match all 2,000 requests at that seed on macOS and Linux, including that
same 500-request prefix. Optimized macOS/no-GC matches all 2,000 at seed
20261166. All final cohorts finish with unchanged input pins. Two additional
native fixtures cover both source alpha types and fractional near-integer
origins; source-image coverage now includes 37 supported native fixtures and
four decline controls on each platform.

Focused C/FastC source/image/filter suites, Linux browser typechecking and the
C FMA audit pass (zero contracted operations, 189 explicit). The standalone
Linux production/no-GC source-image executable runs all four registered test
functions under the 3 GiB guard with Skia unavailable to pkg-config. Its link
command, `readelf` and `ldd` show no direct or transitive Skia dependency.

HTML integration remains pending. The pinned comparison compiler exceeded
the unchanged 12 GiB aggregate guard twice. A fresh attempt with the production
browser's compiler reached invalid `to_keyword()` and `StyleValueList.create()`
calls in concurrent, uncommitted CSS parser edits. Those edits were preserved;
the unsuccessful attempts are retained. After those API calls were corrected,
both compilers still exceeded the same guard. An experiment using plain error
messages instead of formatting error objects also exceeded it and was reverted;
every assertion remained enabled. Integration validation therefore remains
limited by compilation memory on macOS. A separate Linux attempt fails before
running any tests at another concurrent, uncommitted CSS edit: a `:not()` loop
iterates `SelectorList` instead of its `.selectors` array. That edit was also
preserved. The earlier integration result predates this near-integer change
and cannot validate it.

The Linux typecheck uses installed Skia development files. The shared bundle
was not used to validate this slice, and complete browser compilation, linking
and execution without Skia remain open. See the [native fixtures, guarded
checks and integration failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-near-integer-image-blurs-20261109.json).


### External parity suite and large canvas shadows (2026-11-09)

The CPU differential suite and all 68 generated receipts (517,447 lines)
now live in `vox-browser/vox-tests`. Imported receipts retain their exact
bytes and original SHA-256 hashes. Vox keeps a pinned launcher and small
focused unit tests. Four launcher checks and twenty production-manifest
checks pass; new bulk evidence belongs in the test repository.

`e9c57e1fc` adds large saved-canvas drop shadows using the rescaled blur,
deferred tint/offset and foreground merge. Native N32 rules survive a
resolved shadow intermediate on Linux. All 58 large-blur fixtures, including
22 new shadow cases, verify on macOS and Linux. Through the external launcher,
macOS matches 112 of 128 large-shadow requests and Linux matches 111 of 128
(seed 20261181). Optimized macOS/no-GC matches 110 of 128 (seed 20261182).
Other requests decline; counts include no-ops. All cohorts finish with
unchanged inputs under the 3 GiB guard. The C FMA audit passes with zero
contracted operations (189 explicit).

The standalone Linux production/no-GC executable runs all five registered
large-blur test functions with Skia unavailable to pkg-config; its link,
`readelf` and `ldd` checks find no Skia dependency. This is component evidence.
The current browser typecheck stops at a CSS highlight-selector error before
execution. The inherited FastC degenerate-gradient failure remains open.
The complete browser still links Skia; full Linux compile/link/run without
it remains unverified. See the [retained checks and failures](https://github.com/vox-browser/vox-tests/blob/b61c01f7326843d005cad1f3e5f9a1269da5db2f/evidence/gg-migration/external-suite-and-large-shadows-20261109.json).


### Large source-image drop shadows (2026-11-09)

`24e007856` retains original image coordinates, RGBA filtering rules and
source alpha/color metadata through large shadow blur and merge. An eligible
deferred foreground is drawn from its original view. This covers aligned
sources, prescribed fractional AA surfaces and eligible near-integer sources;
other deferred large mappings keep their guards.

The baseline declines all 500 attempts at seed 20261191; the candidate matches
395 of that same 500. Final default C cohorts match 1,563 of 2,000 on both
macOS and Linux at seed 20261192, declining 437. Optimized macOS/no-GC matches
777 of 1,000 at seed 20261193, declining 223. Counts include no-ops; every
completed cohort retains unchanged input pins. Twenty-two independent native
shadow fixtures verify on each platform. Their bulk inputs and receipts live
in `vox-tests`; the focused V regression uses compact hashes and existing inputs.

Focused C/FastC image suites, Linux HTML canvas integration, the full Linux
browser typecheck and the C FMA audit pass (zero contracted, 189 explicit).
The standalone Linux production/no-GC image executable explicitly runs all
five test functions with Skia unavailable to pkg-config. Its link command,
`readelf` and `ldd` show no direct or transitive Skia dependency. This verifies
the component: the browser integration checks still use installed Skia, and
full Linux browser compile/link/run without it remains open. The older shared
bundle was not used to validate this change. See the [native cases, guarded
cohorts and component linkage](https://github.com/vox-browser/vox-tests/blob/202eeab62636f300465f78280e3fc9e7ce9a31c3/evidence/gg-migration/large-source-image-shadows-20261109.json).


### Large blurs with an initial minified-source resolve (2026-11-09)

`a53278da8` handles whole-image mappings for which native rescale resolves
minification before progressive downsampling. The step-count test preserves
that boundary; other deferred mappings keep their guards. Sampling, paint
alpha, P3 conversion and incoming matrices resolve together, while outgoing
matrices stay deferred through the large blur.

The fixed-sigma baseline declines all 500 requests at seed 20261201; the
candidate matches all 500. Broader final cohorts vary scales, flips, sigmas
and matrices: macOS and Linux match 1,380 of 2,000 requests at seed 20261202,
declining 620. Optimized macOS/no-GC matches 699 of 1,000 at seed 20261203,
declining 301. Counts include no-ops; all completed cohorts finish with
unchanged inputs under the 3 GiB guard. Eight additional native regressions
verify on both platforms. Focused C/FastC suites, Linux browser typechecking,
Linux HTML canvas integration and the C FMA audit pass (zero contracted,
189 explicit).

The standalone Linux production/no-GC image executable runs all six registered
test functions with Skia unavailable to pkg-config. Its direct libraries are
FreeType, libm and libc; link/readelf/ldd checks find no Skia dependency. Browser
integration still uses installed Skia, so the requested full-browser Linux
compile/link/run without it remains open. See the [native inputs, cohorts and
component linkage](https://github.com/vox-browser/vox-tests/blob/ecea3ad79cde8a95bac6a811ad46ba0a04b50e42/evidence/gg-migration/large-minified-source-blurs-20261109.json).


### Large shadows of minified whole images (2026-11-09)

`f90220e40` resolves a minified whole image for the shadow blur's own requested
bounds, then merges the original deferred foreground above the tinted,
offset blur. Foreground sampling, paint alpha and incoming color effects
remain deferred through merge. An offscreen shadow retains the foreground.

The corrected baseline declines all 500 requests at seed 20261211; the
candidate matches 340 of that same cohort, declining 160. Final default C
cohorts on macOS and Linux both match 1,360 of 2,000 requests at seed 20261212,
declining 640. Optimized macOS/no-GC matches 705 of 1,000 at seed 20261213,
declining 295. Counts include no-ops; completed cohorts finish with unchanged
input pins under the 3 GiB guard. The first driver attempt omitted the
minification selector and is retained as a setup error, outside these results.
Ten independent native fixtures verify on each platform, including two
foreground-only results whose shadow lies outside the clip.

Focused C/FastC suites, Linux browser typechecking, Linux HTML canvas
integration and the C FMA audit pass (zero contracted, 189 explicit). The
standalone Linux production/no-GC image executable runs all seven registered
test functions with Skia unavailable to pkg-config; link/readelf/ldd checks
find no direct or transitive Skia dependency. Its direct libraries are
FreeType, libm and libc. Browser integration still uses installed Skia;
full-browser Linux compile/link/run without it remains open. See the
[native cases, setup error, cohorts and component linkage](https://github.com/vox-browser/vox-tests/blob/655628b3d28da2c41312f5af653c2071b22f294b/evidence/gg-migration/large-minified-image-shadows-20261109.json).


### Large filters of minified source subsets (2026-11-09)

`fb9c8e5af` extends initial source resolution to cropped images when native
rescale requires it before progressive downsampling. The extracted bitmap
keeps its original row stride and layer crop. Fractional subsets retain their
AA surface; shadow merge retains the original deferred foreground.

At seed 20261221 the baseline accepts 47 of 500 requests; the candidate accepts
336 of the same cohort. Final default C cohorts on macOS and Linux both match
1,418 of 2,000 requests at seed 20261222, declining 582. Optimized macOS/no-GC
matches 686 of 1,000 at seed 20261223, declining 314. Counts include no-ops;
all completed cohorts finish with unchanged input pins. Fourteen independent
native regressions verify on each platform, covering integer, fractional,
clipped and flipped source subsets across blur and shadow filters.

Focused C/FastC suites, Linux browser typechecking, Linux HTML canvas
integration and the C FMA audit pass (zero contracted, 189 explicit). The
standalone Linux production/no-GC executable runs all eight registered image
test functions with Skia unavailable to pkg-config. Link/readelf/ldd checks
find no direct or transitive Skia dependency; direct libraries are FreeType,
libm and libc. Browser integration still uses installed Skia development
files. Full-browser Linux compile/link/run without Skia remains open. See the
[guarded comparisons and dependency proof](https://github.com/vox-browser/vox-tests/blob/a0a230fb6b113ac5935d7a758a6805add64031c3/evidence/gg-migration/large-minified-source-subsets-20261109.json).


### Source shaders at the large-blur rescale boundary (2026-11-09)

`46f124838` handles large blur and shadow filters whose native rescale factors
round to zero downsampling steps. The identity shader pass still samples and
converts the source with paint alpha and incoming color filters. Outgoing
filters and the original shadow foreground stay deferred. Actual decimation
keeps its existing eligibility checks.

The fixed-sigma 135.01 baseline accepts 29 of 500 requests at seed 20261231;
the candidate accepts 385 of that same cohort. Wider final cohorts cycle
sigmas from 135.001 through 135.14 across the step-count boundary: macOS and
Linux each match 1,387 of 2,000 requests at seed 20270101, declining 613.
Optimized macOS/no-GC matches 699 of 1,000 at seed 20270102, declining 301.
Counts include no-ops; completed cohorts retain unchanged inputs. Sixteen
independent native fixtures verify on both platforms, and a neighboring
unsupported request verifies atomic fallback.

Focused C/FastC suites, Linux browser typechecking and HTML canvas integration
pass. The C FMA audit finds zero contracted operations (189 explicit). The
standalone Linux production/no-GC executable runs all nine registered image
test functions with Skia unavailable to pkg-config; link/readelf/ldd checks
find no Skia dependency, with FreeType, libm and libc as direct libraries.
A full-browser Linux C compile with Skia hidden instead fails at link time on
Skia symbols from the canvas and shadow bridges. Full-browser Skia removal
therefore remains open; the passing component is not that result.

`0eddb82df` also fixes concurrent suite-cache publication: macOS/Linux can
report a nonempty-directory error after another fetch wins. The launcher now
validates that winner and still rejects dirty checkouts and unrelated I/O
errors. All six Python tests pass on both platforms. The [guarded evidence,
cache race and full-browser link failure](https://github.com/vox-browser/vox-tests/blob/6f101eac79a7d6a1157d427be98c8d964801d48c/evidence/gg-migration/large-identity-source-rescale-20261109.json)
remain in vox-tests; passing V checks disable compatibility fallback.


### Deferred sources in large-filter downsampling (2026-11-09)

`4afcb4d89` combines image sampling, source conversion, paint alpha and incoming
color effects with the first downsample when native rescale keeps the source
transform deferred. Subset bounds analysis selects the original backing store
or a strict bitmap subset before nearest or mipmapped sampling. Progressive
passes retain their own quantized surfaces; outgoing effects and the original
shadow foreground remain deferred.

At seed 20270111 the baseline accepts 233 of 500 requests; the candidate
matches 479 of the same cohort. Final macOS and Linux C cohorts each match
1,919 of 2,000 at seed 20270112, declining 81. Optimized macOS/no-GC matches
955 of 1,000 at seed 20270113, declining 45. Counts include no-ops, and completed
cohorts retain unchanged inputs under the 3 GiB guard. Twenty-three independent
native fixtures verify on both platforms, including flips, source clipping,
P3/alpha effects, an offscreen shadow and a rejected negative blur. Enlarged
source, scaled-CTM and neighboring step-boundary declines now have positive
native expectations; unsupported near-integer and skewed controls stay atomic.

Focused C suites on both platforms, macOS FastC, Linux browser typechecking
and HTML canvas integration pass. The C FMA audit finds zero contracted
operations (189 explicit). The standalone Linux production/no-GC executable
runs all ten registered image test functions with Skia unavailable to
pkg-config; link/readelf/ldd checks find no Skia dependency, with FreeType,
libm and libc as direct libraries. Full-browser integration still uses Skia;
its canvas/shadow bridges remain compiled. See the [native cases, guarded
comparisons and component dependency proof](https://github.com/vox-browser/vox-tests/blob/b230c6245b878cb5cfaac64b1ed5c2debb8c20da/evidence/gg-migration/large-direct-source-rescale-20261109.json).


### Near-integer sources in real large-filter rescale passes (2026-11-09)

`c03df8cc6` retains nearly integer source transforms during actual downsampling,
including deferred P3 conversion, paint alpha and incoming color effects.
Exact integer translations without pending effects keep their raw-pixel path.
Default sampling retains native N32 shader-context eligibility; mipmapped
sources and deferred paint alpha use the raster pipeline.

At seed 20270121 the baseline accepts 78 of 500 requests; the candidate
matches 469 of that same cohort. Final macOS and Linux C cohorts each match
1,929 of 2,000 at seed 20270122, declining 71. Optimized macOS/no-GC matches
960 of 1,000 at seed 20270123, declining 40. Counts include no-ops; completed
cohorts retain unchanged inputs under the 3 GiB guard. Twenty-three native
fixtures verify on each platform, covering both scale directions around 1,
near-limit and larger sigmas, exact composed transforms with color effects,
raw-pixel reuse, a rejected negative shadow blur and an offscreen shadow.
The former near-integer decline now has a positive native expectation;
the skewed control remains atomic.

Focused C suites on both platforms, macOS FastC, Linux browser typechecking
and HTML canvas integration pass. The initial browser check hit a concurrent
layout edit; the receipt retains that failure and the successful retry after
its correction. The C FMA audit finds zero contracted operations (189 explicit).
The standalone Linux production/no-GC executable runs all eleven registered
image test functions with Skia unavailable to pkg-config; link/readelf/ldd
checks find no Skia dependency, with FreeType, libm and libc as direct libraries.
Full-browser integration still uses Skia. See the [native cases, guarded
comparisons, integration retry and component linkage](https://github.com/vox-browser/vox-tests/blob/620abd5a99c04452effdd18a4d7be01f786f1b7e/evidence/gg-migration/large-near-source-rescale-20261109.json).


### Large terminal blurs in saved-canvas chains (2026-11-09)

`a6028f156` downsamples the final large blur in a saved-canvas pure-blur
chain. Earlier small or identity passes keep their native quantized images;
pending input color effects enter the first downsample and outgoing effects
stay deferred through restoration. An initialized backing border may contain
color, so the rescale path distinguishes it from transparent padding. Earlier
large stages, source-image chains and mixed large shadow graphs remain guarded.

At seed 20270201 the baseline accepts 11 of 500 requests; the candidate
matches 409 of that same cohort. Final macOS C matches 1,622 of 2,000 requests
at seed 20270202, declining 378; Linux matches 1,700, declining 300. Platform
glyph backends and fonts differ. Counts include no-ops; completed cohorts
retain unchanged inputs under the 3 GiB guard. Twenty-eight independent native
fixtures verify on both platforms, including colored requested boundaries,
intermediate/post color effects, clips, composites, strokes and P3 patterns.
Unsupported chain positions and source-image controls preserve the destination.

A single 1,000-request macOS `-prod -gc none` process exceeded the 3 GiB guard
and did not complete. Ten fresh 100-request processes at seeds 20270203–20270212
then matched 786 requests and declined 214, using the same pinned optimized
binary and oracle; peak sampled RSS was 1.41 GiB. These different seeded batches
establish short-batch pixel parity, not bounded long-run no-GC ownership.
The receipt retains the failed stress run and an initial runner setup error.

Focused C suites on both platforms, the selected macOS FastC suite, Linux
browser typechecking and HTML canvas integration pass. The inherited FastC
saved-canvas degenerate-gradient failure remains outside that passing selection.
The C FMA audit finds zero contracted operations (189 explicit). A standalone
Linux production/no-GC executable runs all 17 registered filter-layer test
functions with Skia unavailable to pkg-config; link/readelf/ldd checks find no
Skia dependency, with FreeType, libm and libc as direct libraries. Full-browser
integration still uses installed Skia. See the [native cases, guarded comparisons,
resource limits and component linkage](https://github.com/vox-browser/vox-tests/blob/b58019050c2fb0ef00975448f4f247d7426eb3fb/evidence/gg-migration/large-terminal-blur-chains-20261109.json).


### Large terminal blurs after resolved image stages (2026-11-09)

`caeea072c` permits a large final blur on image chains when an earlier
non-identity blur has materialized the source. The large stage consumes that
quantized intermediate, retaining pending color effects through downsampling
and restoration with the image-source context. Identity-only prefixes and
earlier large stages remain guarded; the identity-prefix control stays atomic.

At seed 20270221 the baseline declines all 500 requests; the candidate matches
416 and declines 84. Final macOS and Linux C cohorts each match 860 of 1,000
at seed 20270222, declining 140. Optimized macOS/no-GC matches 84 of 100 at seed
20270223, declining 16. Counts include no-ops; all completed cohorts retain
unchanged inputs under the 3 GiB guard. Twenty-six independent native fixtures
verify on both platforms, all changing the background, covering alpha types,
P3, paint alpha, matrices, clips, fractional subsets, scaling, reflection,
near-integer mapping and larger source content.

Focused C suites on both platforms, selected macOS FastC tests, Linux browser
typechecking and HTML canvas integration pass. The FMA audit finds zero
contracted operations (189 explicit). The standalone Linux production/no-GC
executable runs all 12 registered source-image test functions with Skia
unavailable to pkg-config; link/readelf/ldd checks find no Skia dependency,
with FreeType, libm and libc as direct libraries. Full-browser integration
still uses installed Skia. The optimized random cohort is deliberately small;
it does not resolve the preceding saved-canvas long-run no-GC resource failure
or the inherited FastC saved-canvas degenerate-gradient failure. See the
[native cases, guarded comparisons and component dependency proof](https://github.com/vox-browser/vox-tests/blob/d7e7e7609c0388c6491c3664c8daf7fd187ac32a/evidence/gg-migration/large-terminal-image-blurs-20261109.json).


### Exact-zero stages around one nonzero blur (2026-11-09)

`d181cc992` normalizes pure blur/matrix chains with exactly one nonzero-radius
blur by removing exact-zero blur stages. The remaining blur keeps its layer
semantics, with color matrices combined in their existing order. This lets
zero-prefixed and zero-suffixed image chains use the existing large-blur source
sampling path. All-zero chains retain their layer behavior; tiny nonzero
stages are never dropped and multiple nonzero blurs keep the chain path.

At seed 20270301 the baseline declines all 500 requests; the candidate matches
417 and declines 83. Final macOS and Linux C cohorts each match 858 of 1,000
at seed 20270302, declining 142. Optimized macOS/no-GC matches 86 of 100 at seed
20270303, declining 14. A separate saved-canvas mixed-blur regression matches
818 of 1,000 at seed 20270304, declining 182. Counts include no-ops; completed
cohorts retain unchanged inputs under the 3 GiB guard. Twenty-six independent
native fixtures verify on both platforms, all changing the background, with
zero stages before and after the blur, P3/alpha/color effects, clips, fractional
subsets, scaling, reflection, near-integer mapping and larger source content.

Focused C suites on both platforms, selected macOS FastC tests, Linux browser
typechecking and HTML canvas integration pass. The FMA audit finds zero
contracted operations (189 explicit). The standalone Linux production/no-GC
executable runs all 13 registered source-image test functions with Skia
unavailable to pkg-config; link/readelf/ldd checks find no Skia dependency,
with FreeType, libm and libc as direct libraries. Full-browser integration
still uses installed Skia. Short optimized comparisons do not resolve the
retained long-run no-GC resource failure or the inherited FastC saved-canvas
degenerate-gradient failure. See the [native cases, guarded comparisons and
component dependency proof](https://github.com/vox-browser/vox-tests/blob/80233f56cec916a70526a4af6628b51a20a892e7/evidence/gg-migration/zero-stage-image-blurs-20261109.json).


### Identity-kernel tails after large blurs (2026-11-09)

`82c466c87` handles a large blur at the last mapped non-identity stage of a
pure-blur chain. Later identity kernels preserve its deferred image and carry
their incoming color effects through restoration. The complete original list
still supplies fast bounds and requests. A later real kernel on either axis
continues to decline atomically, including when a transform makes sigma .02
non-identity. Image sources still need an earlier real blur to resolve them.

At seed 20270311 the canvas baseline accepts 10 of 500 requests; the candidate
matches 275. The image baseline declines all 500; the candidate matches 366.
Final canvas cohorts at seed 20270312 match 587 of 1,000 on macOS and 605 on
Linux, declining 413 and 395; platform glyph backends/fonts differ. Final image
cohorts each match 696 of 1,000, declining 304. Optimized macOS/no-GC at seed
20270313 matches 59 of 100 canvas requests and 70 of 100 image requests,
declining 41 and 30. Counts include no-ops; all completed candidate cohorts
retain unchanged inputs under the 3 GiB guard.

Twenty-eight canvas and 26 image native fixtures verify on each platform,
covering identity tails, color effects, alpha/P3, clips, composites, dashed
strokes, fractional subsets, scaling/reflection, near-integer mappings and
larger content. Two initial Linux reference verifications used the previous
fixture pin with empty Linux expectations; both complete reruns passed after
the captured hashes were published. The receipt retains those setup failures.
Focused C suites, selected macOS FastC tests, Linux browser typechecking and
HTML canvas integration pass. The FMA audit finds zero contracted operations
(189 explicit). Separate Linux production/no-GC executables run all 19
filter-layer and 14 source-image test functions with Skia unavailable to
pkg-config; link/readelf/ldd checks find no Skia dependency. Direct libraries
are FreeType, libm and libc. Full-browser integration still uses installed
Skia. Short optimized cohorts do not resolve the retained long-run no-GC
resource failure or inherited FastC saved-canvas degenerate-gradient failure.
See the [native cases, guarded comparisons, setup failures and component
proofs](https://github.com/vox-browser/vox-tests/blob/7bbc2a2fca7ed1332b72c162003bcd07b1066e23/evidence/gg-migration/large-blur-identity-tails-20261109.json).


### Identity-kernel prefixes before large image blurs (2026-11-10)

`b422ec7ef` reduces a pure-blur image chain to its only mapped non-identity
stage when that stage is large. Identity kernels before it return the deferred
image unchanged, so the image never reaches a resolved surface, and these
chains previously declined. The reduced blur now uses the existing single-blur
source-sampling path. Incoming color effects join its input and later ones
restore with its result, as identity tails already did. Quick-reject bounds
still outset by every original radius, in order. Chains with a second real
kernel, including sigma .02 made non-identity by a 2x scale, keep their chain
path or decline atomically.

At seed 20270311 a baseline built from a read-only export of `2aeab0885`
declines all 500 requests; the candidate matches 345 and declines 155. Final C
cohorts at seed 20270312 match 693 of 1,000 on both macOS and Linux, declining
307. Optimized macOS/no-GC at seed 20270313 matches 70 of 100, declining 30.
Regression cohorts at seed 20270312 find no mismatches: identity tails match
696 of 1,000 (unchanged from their recorded final), zero stages 868 and
terminal image blurs 832. Counts include no-ops; all cohorts retain unchanged
inputs under the 3 GiB guard.

Twenty-six native fixtures and three decline controls verify on each platform.
They cover one to three identity prefix stages, prefix/between/post color
matrices, optional identity tails, alpha/P3, clips, composites, fractional
subsets, scaling/reflection and larger content, and every case changes the
background. The controls, with a later real kernel, leave the destination
untouched. An existing unit test expected the image chain `[.01, 300]` to
decline; it now checks `[.01, 300, .8]`, which still declines.

Focused C suites on both platforms, selected macOS FastC tests, Linux browser
typechecking and HTML canvas integration pass. The FMA audit finds zero
contracted operations (170 explicit). The standalone Linux production/no-GC
executable runs all 15 source-image test functions with Skia unavailable to
pkg-config; direct libraries are FreeType, libm and libc. Full-browser integration still uses installed Skia. See the
[native cases, guarded comparisons and component
proof](https://github.com/vox-browser/vox-tests/blob/7550a2aa6ea614dd9d9d21dcf7146e30f194f499/evidence/gg-migration/identity-prefix-image-blurs-20261110.json).


## Retained document text after removing Skia (2026-11-12)

The native macOS painter now transports tightly bounded RGBA rasters from V
`cpuraster` for retained glyphs. Registered CoreText faces preserve collection
indices, variation coordinates and strike advances. Cached and uncached retained
runs use the same coverage pipeline. Variable-font skip-ink uses the canonical
64px outline and ignores pathless spaces without discarding the other glyphs.
V `gg.canvas` draws eligible rounded shapes and solid SVG paths; shape replay
preserves the raster grid and each tile's multisampling selection. Outer shadows
keep unrounded author alpha. The developer executable does not link Skia.

The unchanged `glyph-document-origin` Brave fixture is pixel-exact. Focused glyph,
font-advance, variable-outline, shadow-alpha and geometry checks pass on macOS,
including glyph-cache checks with `-prealloc -gc none`. The non-scaling stroke
checks pin 42 outputs recorded from the prior Graphite library
(SHA-256 `59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54`);
these tests require no Skia library at runtime.

The frozen ChatGPT homepage remains **short of pixel parity**. At 1024×768 CSS
pixels and scale 2, the unchanged archive
`Tests/Browser/Brave/archives/chatgpt-home-20261104-v2` has 3,145,728 pixels.
The C developer build reduced differences from 435,025 (13.8291%) to 45,495
(1.4462%); 1,095 differ by more than three channel levels, with maximum error 59.
The remaining differences are predominantly faint shadows and geometry edges.
The reference PNG was not modified (SHA-256
`6e81a153394cf640168483ae1979025df0271c4886a6f44e83792d548106028e`).
The final fresh-process capture exited 0 under the 3 GiB guard with unchanged
executable identity `82b536155fc6c379e3ee01b0a3ba9ea072b6e909b7a746153c0a6b559ddd4db0`.
This is rendering evidence, not a performance comparison or a production-bundle
acceptance result. The commit requests the managed production rebuild.

The subsequently completed managed build `20261112-075730-7e81c09c` contains the
rendering commit and uses literal C `-prod` in a single unit. Its executable
SHA-256 is `23ad40a6373357f83e8feab4e41e55ded8abda3a84f26fa6ff77f257427d91a1`.
Fresh launches passed `--headless-smoke` and reproduced exactly the same 45,495
ChatGPT differences, with stable executable/resource identities. Its
`glyph-document-origin` capture has **zero differing pixels** out of 768,000.
All three browser checks exited 0 under separate 3 GiB guards. Local commands,
receipts, captures and failed attempts are retained under
`docs/performance/plain-v-text-20261112/`, outside tracked measurement history.

A separate direct live-site capture exited 0 but remained blank and `loading`
with no editor. It does not validate the live ChatGPT experience. Full-page exact
parity and live-site readiness remain open.

The November 12 follow-up checked the two Linux outer-shadow byte failures
against an independent Skia ee20d565 oracle (library SHA-256
`19dedece03588619f6857b0b7936ef393d038cdc8f5c8d10f65b4c7bfe55cde5`).
Native RGBA gives `[248,131,36,35]` and red `124`; non-native RGBA gives
`[241,128,35,36]` and red `128`, exactly matching Linux's existing pipeline.
The tests now pin both platform results without changing rasterization or
tolerances. All six outer-shadow tests pass when executed on macOS and in the
Debian 13 ARM64 VM, under separate memory guards.

### Completed ChatGPT text and pixel follow-up (2026-11-12)

The frozen homepage now matches the original Brave document **pixel for pixel**:
**0 differing pixels out of 3,145,728**, maximum channel error 0, MAE 0 and
RMSE 0. The viewport was 1024×768 CSS pixels at scale 2, replaying
`Tests/Browser/Brave/archives/chatgpt-home-20261104-v2/archive` at its original
`https://chatgpt.com/` origin with a private profile/cache and cookie blocking
disabled. The reference PNG remains unchanged, SHA-256
`6e81a153394cf640168483ae1979025df0271c4886a6f44e83792d548106028e`.
The fresh C developer executable was
`9b78d4613bf2b271d435a10ec17d1d560bde16601b177cce11c2ad4508417948`;
its identity was checked before and after capture. Both capture and the 3 GiB
guard exited 0, at a sampled peak RSS of 803,241,984 bytes. The complete
readiness/content audit retained the heading and editor; no reference or
tolerance was changed.

The remaining migration gaps were an absent superellipse painter, blurred
rounded-shadow filtering, prematurely resolved SVG/contour samples, and large
page coordinates retained in rounded-border conics. These now use V/GG paths
and a bounded Metal pixel-filter service. Native Cocoa code only transports
retained descriptors, coordinates and pixels. The application does not link
the independent Skia/Graphite libraries used to generate test expectations.

Focused pixel hashes cover contour fills, border alignment, outer shadows,
rounded-shadow nine-patches, shared SVG samples, and compositor-local conics.
The shared-contour sequence independently reproduces the old combined GPU
recording; separate resolves reproduce the prior 124-pixel composer failure.
The group eligibility and existing SVG batch tests pass. The new contour, SVG
and local-coordinate tests also pass with `-prealloc -gc none` under a 3 GiB
guard. Build setup's 19 Python tests pass. The earlier 45,495-, 8,617-, 5,330-,
134-, 10- and 2-pixel attempts remain local diagnostic history.

A separate fresh **live** launch of `https://chatgpt.com/` reached `complete`,
with loaded fonts, one heading and the visible `mobile-composer-prompt`
textarea. It reported zero native errors and JavaScript diagnostics. Its
browser and 3 GiB guard exited 0, peaking at 781,697,024 bytes, with the same
verified executable identity. This closes the earlier blank/loading live
check; frozen-page pixel equality does not claim equality with changing live
content. These are rendering and functional checks, not a performance cohort.

Reproduce the pixel-only check with:

```sh
python3 tools/test_chatgpt_pixels.py --output Build/chatgpt-pixels-UNIQUE
```

It uses the latest completed production bundle, a fresh browser under its
3 GiB guard, disk-only replay, and the existing source/content audit. It rejects
changed executable, library, fixture or reference identities and any nonzero
pixel difference. The Vox capture waits for `textarea,[contenteditable=true]`
before settling. Raw commands, logs, audits, PNGs, executable identities and guarded exits for this
follow-up are retained locally under
`docs/performance/plain-v-text-20261112/final-continuation/`.

The latest completed managed production build also passes the same exact check.
Receipt `20261112-121345-ed07aa77` used literal C `-prod` in one unit, with
executable SHA-256
`1522067fc882717d4eecb49d6bea89ae9a85929fe55a7b246cbe174a59119ad3`.
All eight changed rendering source files match that receipt's parsed source
manifest. The canonical pixel-only tool passed the source and viewport-button
content gates and reported **0 differences**; browser/guard exit 0, sampled
peak RSS 1,222,656,000 bytes. A separate fresh production `--headless-smoke`
also passed DOM mutation, JavaScript click, native wheel routing and ordinary
wheel listeners (guard exit 0, peak 143,949,824 bytes).

A fresh live launch of that same production executable also reached `complete`
with a laid-out heading and editor and zero native errors (browser/guard exit
0; sampled peak RSS 2,298,757,120 bytes). Its audit retained Google's One Tap
FedCM migration warning; the earlier developer live run had no diagnostics.
The production identity remained unchanged throughout the launch.


### Small rounded shadows, 2026-11-13

`a2427d085` extends the bounded V/GG Gaussian filter to device sigma 0.5 and
uses a single 2D pass when the kernel fits in 28 samples, preserving A8 rounding.
The new four-case `small-blur-shadows` browser fixture matches two fresh pinned
Brave captures exactly. The six shadow test files pass with arena poisoning
and 3 GiB runtime guards, retaining all previous GPU-oracle hashes. The unchanged
GitHub archive improves from 207 to 49 differing pixels in the diagnostic build;
production validation is pending. See the [pixel audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#small-rounded-shadow-kernels-2026-11-13)
for capture scope, retained failures and remaining gaps.


### Scrollbar capture policy, 2026-11-14

`e68a210c6` matches Brave's explicit hidden-scrollbar capture policy under both
macOS scrollbar preferences. Four focused visibility/fade tests pass; live
behavior is preserved. With the current staged closure runtime, both rendering
fixtures and HN/Wikipedia/Lobsters are exact twice. GitHub remains at 49 pixels,
vlang.io at 3,250 and CNN at 175,866; CNN repeatability remains open. Production
confirms the previous rendering fixes at 49 GitHub pixels; this capture-policy
fix awaits its managed rebuild. The [pixel audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#production-confirmation-and-scrollbar-capture-policy-2026-11-14)
retains all failed setup and diagnostic attempts. No reference or tolerance changed.


### Shared rounded outer decorations, 2026-11-14

`93b2ed18e` retains an opaque rounded box's shadows, background and border
through one sample resolve. The exact corner-band GPU regression and guarded
layout eligibility test pass. The new complete Brave fixture is exact twice;
the unchanged GitHub archive improves from 49 to 39 differing pixels twice.
Other checked site counts and focused controls are preserved. Production
validation is pending; see the [pixel audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#shared-rounded-outer-decorations-2026-11-14)
for pinned builds, failed probes, scope and remaining gaps. No reference or
tolerance changed, and no performance credit is claimed.


### Inset-shadow alpha, 2026-11-14

`83683f508` retains fractional inset-shadow alpha through layout lowering and
both direct and fallback CPU raster routes. Fifteen focused tests pass,
including forced fallback coverage, existing raster oracles and both layout
policies. The complete site recheck preserves 39 GitHub differences and the
previous other counts; the exact controls remain exact. This precision fix
does not resolve the input-corner gap. Production validation remains pending;
see the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#inset-shadow-alpha-transport-2026-11-14).


### Unblurred inset shadows, 2026-11-14

`7440a807d` replays eligible inset shadows with a square caster, rounded hole
and retained content clip through V/GG `drawDRRect`, preserving the existing
tile antialiasing policy and CPU fallback. The new three-case Brave fixture is
exact twice; all 27 focused tests pass. GitHub improves from 39 to 19 differing
pixels and vlang.io from 3,250 to 3,228 in two fresh diagnostic captures each.
The other site and focused-control results are preserved. Production bundle
`6bf5db1e` now confirms the new fixture exactly and the 19/3,228 site counts,
with 32 source witnesses, 22 fresh captures and a passing startup smoke. The [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#unblurred-inset-shadow-geometry-2026-11-14)
retains failed probes, CNN's instability and the remaining all-site gaps.


### Native leaf padding and tile coordinates, 2026-11-14

`7019fc7ec` retains the compositor tile when a native readback's two-pixel
padding crosses its origin. The outside fringe stays untouched. Both single
and grouped replay now match the exact search-border regression. All 24 focused
tests pass; the full fixture is exact twice and GitHub improves from 19 to 15
differing pixels twice. Other site/control counts are preserved. Production `b6501a1e` now confirms the search-border fixture exactly
and GitHub at 15 pixels, each twice; see the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#native-leaf-fringe-correction-2026-11-14).


### Shared PNG and outer-shadow resolve, 2026-11-14

`cd0173d0d` draws an eligible adjacent unblurred shadow and PNG on one V/GG
surface, preserving samples until the image has blended. Root-owner, clip,
opacity, transform, color/profile and decoded-bitmap checks preserve fallbacks.
Five focused tests and all seven existing image controls pass. GitHub's frozen
archive improves from 15 differing pixels to zero in two fresh captures; the
new shadowed-avatar fixture is also exact twice. HN/Wikipedia/Lobsters stay
exact; vlang.io and CNN counts are unchanged. Production validation is pending.
See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#shared-png-and-outer-shadow-resolve-2026-11-14).


### Uniformly rotated ellipse decorations, 2026-11-14

`50bdd42d6` retains adjacent elliptical shadows and a translucent border through
one sample resolve, including their shared rounded clip list. Unrotated,
nonuniformly transformed, clipped-out, differently owned and non-AA paints retain
their previous path. Nine focused checks pass. Two fresh diagnostic captures
reduce vlang.io from 3,228 to 2,946 differing pixels and the orbit diagnostic from
1,901 to 1,530. There are 287 corrected and five newly differing one-level site
pixels; equality remains open. Production now separately confirms the preceding
PNG-shadow fix with GitHub exact twice. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#shared-rotated-ellipse-decorations-2026-11-14).


### Text-layer gradient dither origin, 2026-11-14

`f2ee06925` gives an eligible scale-1 text gradient its mask layer's device
origin through the existing V/GG raster boundary. Native code supplies bounds
and backing scale; V selects the grid and clips padded leaf input to it. Other
gradients and higher backing scales keep their prior grid. Seven focused checks
pass, including unchanged Brave pixels, padding, safe declines and existing CSS
gradient oracles. vlang.io improves from 2,946 to 2,710 pixels twice, correcting
236 pixels without new differences. The basic gradient-text control is exact;
fractional, inline and mixed-scope controls retain failures. Retina text keeps
its previous pixels exactly after two rejected higher-scale experiments.
Production `314e32e9` now confirms the 2,710-pixel site result and exact basic
gradient-text control, each twice, with all 36 rendering witnesses matched.
See the [production audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#production-confirmation-of-ellipse-and-text-gradient-fixes-2026-11-14).

### Tile-local shadow filter inputs, 2026-11-14

`de478eee8` restricts axis-aligned filter inputs to the raster tile plus its
three-sigma footprint before progressive downsampling. This preserves the
tile-local sampling grid for tall offscreen sources. Rotated geometry retains
its preceding path; kernels and final A8 resolution are unchanged. The new
complete panel/control fixture and independent mask control are exact twice
against agreeing fresh Brave references. Thirteen focused shadow tests pass.
Thirty-two fresh captures across sixteen workloads preserve the four exact
archives and reduce vlang.io from 2,710 to 2,139 pixels, correcting 571 without
new differences. CNN retains its rendering and repeatability failures.
Production validation is pending the managed rebuild; see the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#tile-local-shadow-filter-inputs-2026-11-14).

### Rotated shadow filter layers, 2026-11-14

`d79672699` resolves translucent rotated ellipses in filter-layer coordinates
and restores the resulting A8 image with linear sampling. The active clip
bounds the layer input; extended readback fringes require the entire visible
clip to fit the compositor grid. Existing kernels and unsupported paint paths
are preserved. All 23 focused checks pass. vlang.io improves from 2,139 to 830
pixels, correcting 1,451 but introducing 142 one-level differences. Four
archived sites stay exact. Production `731ef68c` confirms all eighteen workload
counts twice with matching source witnesses. The complete new translucent fixture retains four
one-level errors despite its focused shadow-band test passing; the opaque
control and remaining site failures stay open. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#rotated-shadow-filter-layers-2026-11-14).

### Root-picture shadow fringes, 2026-11-14

`a4b71a733` keeps eligible rotated filters on the root compositor grid when an
offscreen clip includes negative document coordinates. The root picture clips
that fringe before publication; outside readback bytes remain unchanged.
Non-root and positive-edge guards retain their preceding constraints. Eight
focused checks pass, including single/grouped raster comparisons and the
unchanged non-root fallback control. The complete translucent-shadow fixture
improves four pixels to zero twice, without shader, kernel or reference changes.
The other seventeen workloads retain their preceding counts, including vlang.io
at 830 and
four exact archives. All native pairs agree in this cohort; earlier CNN failures
remain open. Production `e1925955` now confirms the complete translucent fixture
exactly twice with matching witnesses. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#root-picture-shadow-fringes-2026-11-14).

### Shared rounded backgrounds and borders, 2026-11-14

`77143c150` routes eligible opaque background/border pairs through the existing
V document-shape group. The old native transaction declines, leaving separate
resolves; the new group preserves corner samples through both paints. Root
ownership, geometry, transform, clip and sample-state guards remain strict.
Seven focused checks pass with arena poisoning. The complete rounded-border
fixture improves 14 pixels to zero, twice; its independent GPU bands improve
24 pixels to zero. vlang.io improves 830 to 818, correcting twelve without new
differences, while four archived sites and preceding exact controls stay exact.
The 23-workload cohort retains the CNN and other known failures. Production
validation was pending at that check; production `1861ac91` now confirms both
decoration fixes at 810. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#rounded-backgrounds-and-borders-in-one-v-raster-group-2026-11-14).

### Shared unblurred inset decorations, 2026-11-14

`f4a40d91b` groups one box's opaque background, unblurred inset shadows and
border in a common root or non-root picture. It reuses the existing inset
geometry and tile sample policy; clipped, blurred and incompatible cases keep
ordinary replay. Eleven focused checks pass with arena poisoning. The new
Brave fixture improves nine pixels to zero, and vlang.io improves 818 to 810,
correcting eight without new differences. Production `1861ac91` confirms all
27 workload counts twice, including four exact archives. The earlier tall-shadow
baseline repeat failure remains open alongside the existing site failures.
See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#shared-unblurred-inset-decorations-2026-11-14).

### Recorded rotated-filter clips beyond the window, 2026-11-14

`8dc5c0df1` carries supported recorded author clips through the native pixel
transfer, preserving the blur grid beyond the visible window. The final-tile
RGBA oracle improves 485 differences to zero; the complete reduced scene
improves 596 to 111 and vlang.io improves 810 to 341, both without new errors.
Twenty-three focused checks pass with arena poisoning. The fixed-input
30-workload diagnostic cohort preserves four exact archives and preceding
control counts; CNN and the earlier tall-shadow instability remain open.
Production validation is pending the managed rebuild. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#recorded-filter-clips-beyond-the-window-2026-11-14).


### Gradient pictures without optional hit-test metadata, 2026-11-14

`19224ad53` retains eligible contiguous promoted gradient pictures at scale 1
without optional hit-test metadata. Unsafe intervening paints and unsupported
scales retain the existing fallback. Sixteen focused checks execute with arena
poisoning, including real picture ownership and scale changes on a reused plan.
The complete orbit scene improves 111 to 4 differences and its underlay 105 to
3, both without new errors; vlang.io remains 341. The 29-workload diagnostic
cohort preserves four exact archives and preceding control counts. CNN and the
earlier tall-shadow repeat failure remain open. `de783cfd7` separately corrects
an independently reproduced stale shadow-recording assertion. Production
validation is pending the managed rebuild. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#gradient-picture-isolation-without-hit-test-metadata-2026-11-14).


### Shared elliptical decoration and glyph samples, 2026-11-14

`efaca9e3c` retains a supported shape prefix and following horizontal A8 glyphs
through one GPU resolve, preserving their common owner, clip and paint order.
The independent Brave text-band oracle improves 50 differences to zero.
Fifteen focused checks pass with arena poisoning. The complete vlang.io capture
improves 341 to 284 pixels, correcting 57 with zero new differences. The
29-workload diagnostic cohort preserves four exact archives and all other
preceding counts. CNN and the earlier tall-shadow repeat failure remain open;
production validation is pending the managed rebuild. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#shape-and-glyph-samples-in-one-pass-2026-11-14).


### Plane-scaled circular JPEG avatars, 2026-11-15

`e63689e7a` resizes JPEG planes before RGB conversion for supported small circular
minified avatars, then reuses the existing sampled-image GPU painter. Unsupported
profiles, orientation, geometry and sampling modes retain replay. Five C-backend
YUV test files pass, including five new scaling/EXIF cases. Vlang.io improves
284 to 111 pixels, correcting 173 with zero new differences. The 30-workload
diagnostic cohort preserves the four exact archives, the unscaled JPEG control
and preceding counts. Production confirmation is pending; CNN and historical
repeatability failures remain open. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#scaled-jpeg-avatar-planes-2026-11-15).


### Fractional scaled JPEG texture colors, 2026-11-15

`f0b7f4a68` carries opaque JPEG components through RGBA32F base-texture sampling
using the V canvas adapter. Byte mips, geometry, clip and shader are preserved.
Five YUV test files and two GPU cases pass. Vlang.io improves 111 to 28 pixels:
92 corrected, **nine new one-level differences**, net 83 fewer. The JPEG remains
inexact. A stable 30-workload cohort preserves all other counts and repeats
exactly; the earlier input-drift cohort and historical failures are retained.
Production confirmation remains pending. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#fractional-jpeg-texture-colors-partial-improvement-2026-11-15).


### Production confirmation of the 28-pixel cohort, 2026-11-15

Production `05e6ace1` (C backend, literal `-prod`, single C unit) matches all 61
selected compiled rendering-source witnesses. Thirty workloads captured twice
confirm vlang.io at 28 pixels and four exact archived sites; every preceding
reference count matches diagnostics. All 60 native guards and driver/outer exits
are zero. CNN repeats differ at 1,558 pixels; historical failures remain open.
The nine introduced JPEG differences remain within vlang.io's residual. Two
newer layout edits are not in this bundle. No renderer change was applied by
this confirmation. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#production-confirmation-of-the-28-pixel-result-2026-11-15).


### Text gradients in local picture coordinates, 2026-11-15

`4e3445943` localizes supported line-only text-gradient paths and their clips in
V before GPU drawing. This removes the final heading pixel: vlang.io improves
28 to 27, one corrected and none introduced. Two new GPU cases and seven existing
root cases pass with arena poisoning; 33 workloads captured twice preserve every
other reference count. Four archived sites remain exact. Retina PNGs stay
identical to production. Existing references, shader and dither are unchanged.
The JPEG's 23 and scene's four pixels remain, alongside CNN/Reddit and historical
repeat failures. Production is still at 28; the 27 result awaits the managed
build. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#text-gradient-coordinates-inside-recorded-layers-2026-11-15).


### Production confirmation of the local-coordinate fix, 2026-11-15

Production `01436d0a` (C, literal `-prod`, single unit) matches all 62 selected
compiled rendering witnesses. Thirty-three workloads captured twice confirm
vlang.io at 27 and four exact archived sites; every diagnostic reference count
matches. All 66 capture guards and driver/outer exits are zero, with 69 stable
input witnesses. Vlang.io's production PNG matches diagnostics exactly. CNN's
repeat pair differs at 1,540 pixels; its rendering/source failures and the
remaining vlang/Reddit/historical repeat issues stay open. This supersedes the
preceding pending-production status. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#production-confirmation-of-the-27-pixel-result-2026-11-15).


### Opaque lossless WebP sampling and source coverage, 2026-11-15

`c242016bb` restores sampled uploads for downscaled opaque VP8L images. Two
unchanged Brave mip references improve from 32,399/57,599 differing pixels to
zero, twice. Eligibility/cache ownership tests and both GPU references at 1×/4×
pass with arena poisoning. A 44-workload diagnostic cohort retains every other
reference count; CNN and vlang.io remain open. Production confirmation is pending.

`e0fec36b2` adds package-wide compiled V witnesses (23 Python tests). The restored
production baseline passes 122 rendering witnesses including all 64 consumed GG
V sources; the experimental shader bundle is explicitly rejected. Embedded
shader/library identity remains a separate check. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#opaque-lossless-webp-sampling-2026-11-15).


### Limited-range WebP plane sampling, 2026-11-15

`df3fea85d` preserves fractional limited-range RGB for native-size and half-size
opaque VP8 images. Unchanged Brave controls improve from 9,981/3,288 differing
pixels to zero, twice. Six YUV test files, cache/ownership and historical-policy
checks, and both GPU references at 1×/4× pass. A 44-workload diagnostic cohort
retains every other reference count. General rescaling probes remain rejected;
no new native sampler is shipped. Production validation of this fix is pending.

The earlier `c242016bb` lossless controls are now exact twice in production
`5171fc6f`, with final helper/caller and all 64 GG V witnesses matching. That
preview contains older lossy helpers and cannot validate the final new slice.
See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#native-size-and-half-size-lossy-webp-sampling-2026-11-15).


### Alpha WebP magnification and production confirmation, 2026-11-15

`59d71dca9` borrows premultiplied VP8L rows for native-size/magnified sampling
without changing resize history. Three untagged alpha images become exact;
the combined control improves 10,274→2,658 pixels with zero new differences.
The profiled image remains unresolved. Three browser tests and six GPU draws
at 1×/4× pass. No new native painter or shader is shipped.

The final lossy fix `df3fea85d` is confirmed in production `7f651f2d` across
44 workloads. Production `36f72f4a` additionally confirms the alpha correction:
44 workloads/88 captures, all guards/exits zero, 133 compiled witnesses and
160 stable input pins. Other stable PNGs match diagnostics exactly; CNN still
fails repeatability. This supersedes the lossy fix's pending status. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#magnified-alpha-webp-sampling-2026-11-15).


### Numerical sRGB WebP profiles, 2026-11-15

`a5b29f604` interprets ICC RGB/XYZ matrix profiles and parametric curves before
canonicalizing a conservative numerical sRGB subset. Original straight decode
rows then use the existing alpha multiplication and magnified image sampler;
other profiles and alpha minification retain their prior paths. No new native
painter, shader or browser dependency is introduced.

The alpha control becomes exact twice (2,658 corrected, zero introduced).
Three profile tests, seven browser checks and eight GPU draws pass. The
44-workload/88-capture diagnostic retains every other reference count and all
42 stable non-alpha/non-CNN PNGs; CNN still fails repeatability. All 89 native
guards and enclosing exits are zero, with 100 compiled V witnesses and 166
stable pins. Production confirmation is pending. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#numerical-srgb-profiles-in-lossless-webp-2026-11-15).


Production `a542533f` (receipt `20261115-122533-7861f9dc`, C/literal V `-prod`,
one C unit) now confirms `a5b29f604`: all four alpha images exact twice,
44 workloads/88 captures, 134 compiled V witnesses, 164 stable pins and all
native/driver/outer guards zero. All 43 non-CNN PNGs match diagnostics exactly;
CNN retains its repeat failure. This supersedes the pending-production status.

### Sampled sRGB WebP curves and RGB minification, 2026-11-15

`1e1ffdd4e` recognizes dense numerical sRGB ICC curves and retains full RGB
WebP rows for the existing GPU mip sampler. Tagged VP8 stays outside the YUV
upload path. Six parser tests, the browser decode/eligibility test and six GPU
draws at sample counts 1 and 4 pass; no shader or native painter changes ship.

The new frozen control improves 5,059→588 pixels (4,471 corrected, zero
introduced). Its native-size and small images are exact; its clipped bottom
image remains open despite the isolated sampler being exact. The C/O0 browser
cohort covers 45 workloads/90 captures, 101 compiled V witnesses, 171 stable
pins and 91 successful native guards. CNN improves 175,866→165,579 and repeats
exactly; all 45 pairs repeat exactly and the other 43 existing PNGs match the
previous production captures. Production confirmation is pending. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#sampled-srgb-profiles-and-rgb-webp-minification-2026-11-15).

Production `73cc5a36` (receipt `20261115-140919-8b8a4fe0`, C/literal V `-prod`,
one unit) now confirms `1e1ffdd4e`: 45 workloads/90 captures, 135 compiled
witnesses, 167 stable pins, all native/driver/outer exits zero. All reference
counts are retained and all native pairs repeat exactly within that cohort.
The 44 non-CNN PNGs match diagnostics; CNN has a retained 1,558-pixel cross-build
gap. This supersedes that slice's pending-production status.

### Sampled-image compositor fringes, 2026-11-15

`78f1fcf3b` uses the existing two-pixel geometry-fringe rule for image readbacks
and selects samples from their intersection with the owning compositor grid.
Mixed tile selections, larger overhangs and empty intersections retain replay.
Three regression functions fail before the fix and pass afterward, including
the actual WebP callback at sample counts 1 and 4. No native or shader change
ships. The full browser control becomes exact twice: 588 corrected, zero
introduced; its original 5,059 differences are now resolved in diagnostics.

The 45-workload/90-capture recheck has 161 compiled V witnesses, 209 stable
pins and 91 successful native guards. The other 43 existing non-CNN PNGs are
unchanged. CNN retains 165,579 reference differences but its native repeat
fails at 1,558 pixels, in the historical bottom photograph region. The failed
repeat is retained; equal counts do not establish stability. Production
confirmation of this fringe correction is pending. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#sampled-image-compositor-readback-fringes-2026-11-15).

Production `2e089712` (receipt `20261115-142738-638a0adf`, C/literal V `-prod`,
one unit) confirms `78f1fcf3b`: the complete WebP control is exact twice and
all 44 non-CNN PNGs match diagnostics. The 45-workload/90-capture cohort has
136 per-capture selected source witnesses, 160 consumed package V witnesses,
209 stable pins and all native/driver/outer exits zero. CNN retains 165,579
reference differences and fails its repeat at 1,484 pixels. An earlier
interrupted production attempt is retained without acceptance. This supersedes
the fringe correction's pending-production status; all-site equality remains open.

### Native media routing in frozen CNN replay, 2026-11-15

`de138d5e5` fixes native playback bypassing browser proxy routing. The unstable
104×15 region is a video command; the neighbouring train image has stable
pixels and uses the verified sampler. The archive contains no MP4 responses.
Two Brave diagnostic processes report paused videos with zero time/metadata,
while Vox's old player loaded remote URLs outside browser transport and
published changing frames.

When proxy policy may apply, progressive native media now uses the browser
transport and an owned local file retained until the player closes. Redirects,
explicit direct overrides and global bypasses retain their proxy policy.
Errors preserve their allocation lifetime and cannot trigger direct fallback.
Unproxied/local playback and the existing WebM adapter retain their paths.
Proxied progressive media buffers before decoding; proxied playlists explicitly
require future streaming-loader support.

Proxy-policy and real native MP4 integration checks pass, including redirects,
file lifetime/cleanup, missing media, failed proxy and error-message ownership
under arena poisoning. The C/O0 browser's 45-workload/90-capture cohort has
177 compiled V witnesses, 311 stable pins and 91 successful native guards.
CNN improves 165,579→164,021 (1,558 corrected, zero introduced); all 45 pairs
repeat exactly. All 44 non-CNN PNGs are unchanged. Eight missing MP4 requests
reach the replay proxy and return 404. Production confirmation remains pending.
No raster, reference, tolerance, scripting or performance acceptance changes
are claimed. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#native-media-routing-in-frozen-cnn-replay-2026-11-15).

### Opaque compositor continuation, 2026-11-15

`58846cb2e` reconnects the V compositor's proved opaque continuation to the native
painter. CNN's archived header is exact (24 corrected pixels, zero introduced),
and the existing mask-gap ellipse control improves 7→0. All 46 other prior PNGs
are unchanged in 48 workloads/96 stable captures. Native scope ownership and all
15 existing mask/opacity continuation proof tests pass under arena poisoning.
Production `c19672ae` confirms both this fix and the preceding SVG tile sample
count correction across 48 workloads/96 fresh captures. Every PNG matches the
accepted diagnostic; the CNN header and both focused controls are exact.
Startup smoke passes. CNN's image/source differences, Vlang and missing Reddit
evidence remain open; see the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#opaque-compositor-continuation-in-the-native-painter-2026-11-15).

### Filtering minified WebP planes before RGB, 2026-11-15

`d1799617e` adds a bounded YUV444 upload and post-filter RGB conversion through
the existing V/GG image backend. Exact power-of-two plane reductions requiring
only the final bilinear sample are supported; other cases keep their renderer.
Both preparation tools stage the same uniform/shader change. Lazy shared shader
bytes load in the persistent arena; an explicit old-initialization control
traps under poisoning, while the regression survives reclaimed paint scopes.

The C/O0 diagnostic improves CNN 163,830→88,752: 75,105 corrected and 27
introduced one-level differences. All changes are inside two image rectangles.
All 47 other PNGs are unchanged across 48 workloads/96 stable captures. CPU,
GPU, native preparation and Python preparation checks pass. No original
reference or tolerance changes. Production `44f9e0ff` confirms every diagnostic
PNG in 48 workloads/96 fresh captures; catalog parity remains open. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#bounded-minified-webp-plane-filtering-2026-11-15).


### Sampled YUV across mixed MSAA tiles, 2026-11-15

`59c259a55` keeps packed YUV filtering when an image readback crosses tiles with
different sample counts. It rasterizes each tile with its own gutter and sample
count, publishes only owned pixels, preserves the outside fringe and padded
rows, and leaves the destination untouched on failure. Existing non-YUV mixed
sample paths retain their fallback.

The C/O0 diagnostic improves CNN 88,752→71,925: 16,841 corrected and 14
introduced one-level differences, all inside one image. All 47 other PNGs are
unchanged in 48 workloads/96 repeatable captures. Two focused V checks exercise
both seam directions, sample selection, native channel conversion, fringe,
row padding and rejection under arena poisoning. No original reference or
tolerance changes. Production confirmation remains pending the managed build;
CNN and catalog-wide parity remain open. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#sampled-yuv-images-across-mixed-msaa-tiles-2026-11-15).


### Additional mip filtering before YUV conversion, 2026-11-15

`262c477c1` keeps supported scaled WebP uploads as packed planes through GPU mip
generation and the existing canvas sampler, then converts the final sample to
RGB. It retains the single-level path, original scale/source restrictions,
non-YUV paths, tile sample counts and existing shader/sampler policy. The native
callback carries the mip flag through uniform and mixed-sample regions.

CNN improves 71,925→58,062 in diagnostics: 14,488 corrected and 625 introduced
pixels, each new error at most two channel levels. Every change lies inside
Sullivan's image; its interior maximum error improves 88→2. All 47 other PNGs
are unchanged across 48 workloads/96 repeatable captures. Five focused test
functions pass under arena poisoning, including clipped YUV mip arithmetic,
native callback routing across seams and the existing reclaimed-scope checks.
Production confirmation remains pending the managed build; full equality is
open. No original reference or tolerance changes. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#additional-yuv-mip-filtering-2026-11-15).


### Production confirmation of sampled YUV tiles and mips, 2026-11-16

Production `523e30dd` (C/literal V `-prod`/single unit) confirms `59c259a55` and
`262c477c1` through matching consumed implementation hashes and 48 workloads/96
fresh captures. Every pair repeats and every PNG matches the accepted mip
diagnostic. CNN remains at 58,062, Vlang at 27 and the four exact archived sites
at zero. Startup smoke and all guards pass. The driver's 195 source checks stay
active. This closes both production holds above; full equality remains open.

### Native chroma grid for near-half WebP, 2026-11-16

`5995502f5` packs full-size Y and edge-extended half-size U/V into separate
channels of one texture. The shader samples chroma at half coordinates before
limited-range RGB conversion. Selection is bounded to even full-source opaque
VP8 images drawn strictly between half and native size on both axes. Existing
bindings, the 112-byte uniform, sampler policy and scaled-upload paths remain;
the new flag uses a reserved uniform component. Both preparers stage the same
flag, capability check and shader branch, including partial-staging repair.

CNN improves 58,062→54,627 in diagnostics: 3,508 corrected and 73 introduced
one-level differences. All introduced pixels are in the peptides image; its
interior improves 4,106→1,048 with maximum error 26→1. Three other existing
one-level photo pixels also become exact. All 47 other PNGs are unchanged in
48 workloads/96 repeatable captures. Ten focused V test functions and a Python
preparer check pass, including odd chroma dimensions, clamping, reclaimed paint
scopes, tile seams and source/shader restoration after production validation.
Production `419ad8d7` now confirms this slice across 48 workloads/96 fresh
captures: every PNG matches the accepted diagnostic, with CNN at 54,627 and
all pairs repeating. Startup smoke and all guards pass. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#native-chroma-sampling-for-near-half-webp-2026-11-16).

### Full YUV planes through aligned mip filtering, 2026-11-16

`69e1fce6c` extends the atlas path to aligned stronger minification: natural
dimensions divisible by four, both destination dimensions strictly between
quarter and half size, and the reduced upload requiring another mip. It keeps
the original planes through GPU filtering and preserves the earlier near-half
and promoted paths. Generated UV mip padding repeats that mip's averaged edge;
luma and alpha bytes remain unchanged. The existing shader and sampler suffice.

CNN improves 54,627→33,409 in diagnostics: 21,724 corrected and 506 introduced
one-level differences, all inside Sullivan's image. Its interior improves
22,366→2,698, maximum error 2→1. All 47 other PNGs are unchanged across 48
workloads/96 repeatable captures. Ten focused V test functions pass with arena
poisoning and 3 GiB runtime guards. An independent chroma-texture comparison
fails before the mip-edge correction and passes exactly afterward in both
sample modes. Production `99957e17` confirms the final correction across all 48
workloads/96 fresh captures: every PNG matches its accepted diagnostic and all
pairs repeat. Startup smoke and all guards pass; full equality remains open.
No original reference or tolerance changes.
See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#full-plane-aligned-yuv-mips-2026-11-16).

### Profiled RGB WebP half uploads, 2026-11-16

`5a2157173` retains CPU mip averages when a canonical sRGB VP8
image requests an exact half-size upload. Larger uploads already used in the
same resource/navigation/raster scope keep their existing GPU mip samples;
stronger and rounded reductions retain their previous path. Cached pixels
outlive temporary paint memory. No shader or native application UI changes.

CNN improves 33,409→6,091 in diagnostics: 27,321 corrected and three introduced
one-level differences, all inside the ice-cap image (27,345→27). All 47 other
prior PNGs are unchanged across 50 workloads/100 repeatable captures. Four
focused V functions pass with arena poisoning and 3 GiB runtime guards.
Both new direct GG controls match independent Brave references exactly at
sample counts one and four; their browser captures retain 18/24 one-level
differences. Production `d0fa860e` confirms every diagnostic PNG across 50
workloads/100 fresh captures, with all pairs repeating. Startup and all guards
pass. No original reference or tolerance changes; catalog parity remains open.
See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#profiled-rgb-webp-half-uploads-2026-11-16).

### Normalized highp R8 plane resampling, 2026-11-16

`f09630164` uses the existing raster-pipeline arithmetic for single-channel
plane resizing: normalized bytes, four fused bilinear contributions and the
UNORM8 store. It replaces interpolation in byte space followed by half-up
rounding. CPU mip construction and supported browser upload ranges remain.

The independent Skia oracle now agrees on all 24,480 real scaled-plane bytes
(previously ten differed) and 9,493 bytes across ten additional dimension cases.
Ten focused V functions pass with arena poisoning and 3 GiB runtime guards.
All 50 existing PNGs remain unchanged in 100 repeatable diagnostic captures.
This establishes a resampler correction, with no site-level pixel gain.
Production `c23c0d0a` confirms all 50 workloads/100 fresh captures with all
196 source checks active; startup and all guards pass. The three primitive
checks also pass with literal V `-prod` and C `-O2`. The unsupported
rounded-upload experiment is reverted; original references and tolerances
remain unchanged.
See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#normalized-r8-plane-resampling-2026-11-16).

### Full-range JPEG planes through final sampling, 2026-11-16

`8c2e79555` retains scaled JPEG Y/U/V bytes through CPU mip construction and
texture filtering. The full-range matrix and RGB clipping now follow the final
sample. The V tile bridge keeps each compositor tile's sample count; both
preparers install the uniform, capability check and shader together, including
repair of partially staged atlas/JPEG inputs.

Vlang improves **27→5 pixels**, with **22 corrected and zero introduced**;
its remaining JPEG pixel and four scene pixels are unchanged. All 49 other
PNGs are unchanged in 50 workloads/100 repeatable diagnostic captures.
Eighteen focused V functions and the Python staging check pass with 3 GiB
runtime guards; V checks use arena poisoning. The staging repair leaves all
93 staged canvas inputs byte-identical to the accepted capture inputs.
Production `aa91e7cc` now confirms this five-pixel result across 50 workloads/
100 fresh captures, with all 196 feature checks active and every PNG matching.
No reference/tolerance changes or live-site/performance claim. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#full-range-jpeg-plane-sampling-2026-11-16).

### Gray8 CPU-plane stores, 2026-11-16

`293c8abed` uses Gray8 storage for resized CPU YUV planes, matching
`SkYUVAPixmapInfo`. The existing highp interpolation feeds the existing BT.709
luma stage before byte storage. The R8 API preserves its previous arithmetic.

Vlang improves **5→4 pixels**: its JPEG becomes exact, with one corrected pixel
and zero introduced differences. All 49 other PNGs are unchanged across 50
workloads/100 repeatable diagnostic captures. Fifteen permanent focused V
functions pass; the four Gray8 functions also pass with literal V `-prod` and
C `-O2`, under arena poisoning and 3 GiB guards. Independent Skia references
cover 393,216 midpoint bytes, 9,493 additional Gray8 bytes and 24,480 real plane
bytes, with exact agreement. Production confirmation of this correction remains
pending. No reference, tolerance, shader or mip-kernel change. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#gray8-cpu-plane-stores-2026-11-16).

### Opaque planar-image draw semantics, 2026-11-16

`6448185cc` carries the YUV shader's guaranteed opaque alpha into GG's image
paint classification, enabling native draw ordering and analytic interior fills.
RGB uploads and restored layers keep their existing conservative metadata.
Both preparers stage the same change and repair either affected file independently.

CNN improves **4,788→1,414** in diagnostics: 3,450 corrected and 76 introduced
one-level pixels. All 51 pairs repeat, with 50 other PNGs unchanged. Ten focused
V functions and two Python checks pass; native YUV sampling and rounded coverage
also pass with literal V `-prod`. The new complete 64×64 native R8-plane coverage
oracle is exact. Production `036bf130` confirms the preceding 4,788 CNN result
and exact Vlang, GitHub, Hacker News, Lobsters and Wikipedia across twelve fresh
captures; it lacks this new flag. Its managed rebuild is pending. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#preserve-opaque-planar-image-draws-2026-11-16).

### Planar fragment-coordinate normalization, 2026-11-16

`3d3b3c6d2` normalizes limited-range YUV coordinates after interpolation, matching
the native plane sampler. Both staging paths repair each operation independently.
CNN improves **1,414→1,311** in diagnostics: 105 corrected and two introduced
one-level differences. All 51 pairs repeat; 50 other PNGs stay unchanged.
Native full-frame viewport/tile residuals improve 194/190→0/0; the new regression
fails with the control shader. Eleven focused V functions and two Python checks
pass; the coordinate and native sampling functions also pass with literal V
`-prod`. Production confirmation remains pending through the managed hook.
References/tolerances are unchanged. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#planar-fragment-coordinate-normalization-2026-11-16).

### Uniform planar draws in tile coordinates, 2026-11-16

`a56efe4fd` uses each owning tile's raster space for uniform planar draws as well
as mixed-sample draws. It retains direct fallback without usable document geometry.
CNN improves **1,311→1,197** in diagnostics: 115 corrected and one introduced
one-level difference. Sullivan's interior becomes exact. All 51 pairs repeat;
50 other PNGs stay unchanged. Four callback functions pass with arena poisoning
and a 3 GiB guard, including native-tile crop equality, no-grid fallback, mixed
sampling, JPEG, backdrop margins and rejection. The new crop regression fails
with the control implementation. Production confirmation remains pending.
References and tolerances stay fixed. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#uniform-planar-draws-in-tile-coordinates-2026-11-16).

### CPU byte mips for native-size planar atlases, 2026-11-16

`9331c0681` carries CPU byte mips through native-size near-half YUV atlas uploads,
including owning tiles and direct fallback. Stronger atlas minification keeps
GPU mip construction. CNN improves **1,197→94** in diagnostics: **1,103 corrected,
zero introduced**. Sullivan, Netanyahu and peptides are entirely exact.
All 51 pairs repeat; 50 other PNGs stay unchanged. Fifteen focused V functions
pass under arena poisoning and 3 GiB guards; the new complete native CPU-frame
regression also passes with literal V `-prod`. GPU-control assertions fail as
expected. Original references and tolerances stay fixed.

Production `2ba33ee7` confirms the preceding opacity/fragment-coordinate result
across 51 workloads/102 fresh captures, all matching accepted diagnostics:
CNN 1,311 twice, and five other archived sites exact. Its compiled source and
embedded shader predate tile routing and CPU atlas mips; those await the managed
rebuild. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#cpu-byte-mips-for-native-size-near-half-atlases-2026-11-16).

### One recorded SVG background image, 2026-11-16

`a6edd14de` preserves fractional SVG layout when CSS permits repetition but one
rounded recording covers the snapped clip. Playback and recording/MSAA planning
share the selection. Mismatched recording/destination sizes keep the sampler
fallback. CNN improves **94→73**: **21 corrected, zero introduced**. All five
complete untagged image rectangles are now exact. All 53 pairs repeat; 50 existing
non-CNN PNGs stay unchanged. Fourteen focused V functions pass under arena
poisoning and 3 GiB guards. Independently repeated/pinned Brave references add
an exact flat control and a nonuniform control improving 755→265 with no
introduced pixels; that control retains an explicit fallback limitation.

Production default captures on `7515422c` confirm the preceding CPU-mip result:
CNN 94 twice, five other archived sites exact, all twelve PNGs matching accepted
diagnostics. That shared build contains an inactive capture probe, removed from
the checkout before this commit. The clean managed rebuild and new SVG production
validation remain pending. Original references/tolerances are unchanged. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#single-visible-svg-background-pictures-2026-11-16).

### Rounded RGBA owning-tile coordinates, 2026-11-16

`fb71abe2d` shares the existing planar tile renderer with rounded RGBA uploads.
A cropped target changed interpolation even with uniform sample counts. Rendering
in the owning tile makes CNN's ice image exact: **73→46** overall, **27 corrected,
zero introduced**. All 53 workloads/106 fresh captures repeat; 52 other PNGs are
unchanged. Eleven focused V functions pass under arena poisoning and 3 GiB runtime
guards, including an independently sourced Brave crop hash. The old callback
fails the new regression. Unrounded and mixed-sample RGBA fallback is preserved;
an earlier broader prototype regressed an unrounded control and is rejected.
Existing references/tolerances are unchanged. Managed production confirmation
and catalog parity remain open. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#rounded-rgba-draws-in-owning-tile-coordinates-2026-11-16).

### Decoded frame for CPU-resized planar uploads, 2026-11-16

`9b326517b` folds CPU-resized YUV444 into the decoded image frame before building
the GPU matrix. A 480×270 source reduced to 120×68 previously kept an unnecessary
natural-image scale; its rounding left CNN's final 46 one-level differences.
Independent native R8-plane rendering agrees exactly in three complete frames
with the decoded-frame path. The actual callback crop pins their stitched output
across a 4x MSAA seam and rejects invalid natural metadata. The old implementation
fails the new regression; seven focused functions pass under arena poisoning and
3 GiB guards. Shader, decoder and mip construction stay unchanged.

CNN becomes **46→0**, with **46 corrected, zero introduced**. All 53 workloads/
106 fresh captures repeat, and 52 other PNGs are unchanged. Six available archived
catalog workloads are exact. Production confirmation, Reddit's unavailable
workload and CNN's historical source/replay verification remain open. A fresh
anonymous Old Reddit probe reaches a blocked login page with no posts. References
and tolerances are unchanged. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#decoded-image-frames-for-cpu-resized-planar-uploads-2026-11-16).

### Filled list-marker coverage, 2026-11-16

`57c86c2f7` routes filled ellipses through the document shape rasterizer instead
of CoreGraphics. Two focused functions pass, including exact independent Brave
pixels at the actual raster callback and invalid-geometry fallbacks. The public
marker fixture improves 92→0 pixels twice. A recovered older Reddit page improves
18→6; only its rounded subscribe-button pixels remain. All 54 workloads/108 fresh
captures repeat, and all 53 prior PNGs are unchanged. New public marker references
agree in two fresh Brave processes; existing references and tolerances stay.
Production confirmation and the newer missing Reddit workload remain open.
See the [recovery audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#recovered-reddit-html-and-filled-marker-coverage-2026-11-16).

### Repeated background and border composition, 2026-11-16

`5b52ceaab` lets repeated straight-RGBA backgrounds share a rounded clip, opaque
background and adjacent opaque border in one owning-tile pass. The image shader
keeps repeat filtering and derives local coordinates after the analytic
geometry's antialiasing outset. This correction is selected only for repeated
backgrounds; a broader experiment changed five prior controls and is rejected.
Unsupported transforms, scales and effect scopes keep their existing fallback.

The recovered older Reddit page improves **6→0 pixels** twice against two fresh
full-uBO Brave captures. The unchanged public multisample reference and a new
independently repeated single-sample reference are exact. All **56 workloads/
112 captures** repeat, with all 54 prior PNGs unchanged. Ten focused V functions
pass, including native callbacks across tile gutters and an invalid-stride
fallback. Production confirmation, the newer missing Reddit fixture, Lobsters'
fresh-Brave repeatability and CNN's historical source/replay gate remain open.
See the [sprite audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#repeated-reddit-sprite-backgrounds-and-adjacent-borders-2026-11-16).

### Published production and Lobsters sample history, 2026-11-16

Published single-C-unit V `-prod` executable `bbd47035` reproduces all 56 accepted
diagnostic outputs in 112 fresh captures, including exact CNN and both repeated
sprite controls. The recovered older Reddit page is exact against two fresh
full-uBO Brave references. This qualifies the sealed artifact and recorded fixes;
a separate current-checkout source guard stops on concurrent image-sampling
edits, later committed as `12fc9e48b`. That newer code is not validated here. All 187 selected rendering-package V buffers and 23 feature/native/shader
inputs agree with the accepted diagnostic; embedded shader bytes are extracted
from receipt-bound generated C.

Eight alternating default/full-raster Brave pairs reproduce five default
101-pixel failures and no full-raster failures. All failing frames become exact
after paint instrumentation, so their preserved original PNGs remain essential.
Standalone GPU predictions reproduce all 54 tag pixels and 47 avatar pixels:
one sample matches the failures, four samples match the historical reference.
This is predictive coverage evidence, not a measured Brave GPU sample-count flag.
The post-capture paint tool passes 57 related JavaScript tests and never replaces
the saved reference. Default Brave repeatability, the missing newer Reddit
fixture and CNN's historical source/replay audit remain open. See the
[audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-production-confirmation-and-lobsters-sample-history-2026-11-16).


### Elliptical image geometry and PNG decode history, 2026-11-16

Full elliptical image clips in single-sample tiles use destination geometry
instead of a nonuniformly transformed natural image rectangle. Larger PNG
requests retain separate decoded uploads so later small draws keep their first
usable frame. The own-clip tile-planning hunk is already in `8641a3868`; object-fit,
SVG and ancestor-clip cases retain conservative multisampling.

The independently repeated `uniform-scaled-png` control improves **1,412→0
pixels twice**, with no reference or tolerance change. All 30 focused V functions
pass, including actual GPU execution and small/large/small cache reuse. The final
57 workloads/114 captures repeat; all 56 prior PNGs are unchanged. The six
available catalog archives remain exact, as does the recovered older Reddit
page in two separate captures with all 25 post identities. Existing inexact
controls retain their recorded counts. Production confirmation of `40d8c41ed`
is pending. See the
[PNG audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#uniform-png-scales-decoded-frame-history-and-elliptical-geometry-2026-11-16).


### Odd-height WebP chroma planes, 2026-11-16

`4924a3389` retains ceiling-sized 4:2:0 chroma planes for odd luma dimensions.
The newly supported near-half atlas range preserves edge texels and keeps
stronger, unverified odd-plane minification on its existing fallback. An exact
full-image rectangular clip is redundant for this path; omitting its inverse
transform avoids two remaining one-level sampling errors while retaining the
tile's MSAA trigger.

The independent public control improves **17,320→0 pixels** twice. The complete
BBC frozen viewport improves **32,482→23,822**, correcting 8,660 pixels with none
introduced. Ten focused CPU/GPU functions pass. All **59 workloads/118 captures**
repeat, and all 58 prior PNGs remain unchanged. BBC's cropped photo, Guardian and
Verge rendering gaps remain open. Production `93adced1` separately confirms the
earlier PNG scaling/cache fix in 58 workloads/116 captures; production validation
of this newer WebP change is pending. See the [audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#odd-height-webp-planes-in-bbc-photos-2026-11-16).


### Local SVG drop-shadow layers, 2026-11-16

`0dd8f7f65` replays one opaque black SVG path in local filter space before its
quarter-turn CSS transform. The reduced-resolution blur is sampled and colored
into an RGBA layer, merged with the source, then rotated in the owning root
tiles. Linear offset sampling retains its extra input border. Source geometry,
clips, effect nesting and 1× readbacks have conservative eligibility checks;
overflowing ink keeps native clipping. Cached GG preparation refreshes the
canonical layer helper in both preparers.

The isolated logo improves **31,489→14 pixels twice**; the complete frozen
Verge viewport improves **32,035→14,916 twice**, with maximum channel error two.
It remains inexact. BBC and Guardian remain **zero twice** each. All **72
workloads/144 captures** repeat; all 69 preceding PNGs outside the logo are
byte-identical. Fifteen focused V functions and five Python staging tests pass,
including actual GPU execution and typed scope/clip checks. Executable,
native-library, fixture/reference and 24 runtime shader hashes stay pinned.
New production `0cae86c8` separately repeats the 14-pixel logo and 14,916-pixel
Verge baseline, but contains the earlier implementation without the final
geometry-enclosure guard. Production confirmation of that guard and live/catalog
acceptance remain open. See the
[SVG filter audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-local-svg-drop-shadows-2026-11-16).


### Analytic rectangular box shadows, 2026-11-17

`da4e91d4f` constructs the Gaussian integral profile and device geometry in V,
samples float coverage through a bounded Metal pass, and blends it with the paint
through a floating-point GG mask. The full frozen Verge capture improves
**14,916→8 pixels twice**, with maximum channel error one; BBC and Guardian
remain exact. The isolated card improves **18,935→1**. Small and narrow controls
are exact; a fractional scaled rectangle remains open. All **74 workloads/148
captures** repeat, with all 72 previous PNGs byte-identical. Fourteen focused V
functions and both Python staging tests pass. Production validation and exact
Verge equality remain open. See the
[rectangular shadow audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#analytic-rectangular-shadows-on-verge-2026-11-17).


### SVG filter merge allocation and transparent borders, 2026-11-17

`b2f198209` uses GG's approximate save-layer backing allocation for the SVG
filter merge, with a one-pixel transparent boundary and matching origin/crop.
The complete frozen Verge viewport improves **8→0 pixels twice**; the isolated
logo and rectangle improve **14/12→0**. BBC and Guardian remain exact. All **74
workloads/148 captures** repeat; all 72 other previous PNGs are byte-identical.
Fourteen focused V functions and both Python staging tests pass, including an
exact full-reference SVG test with one and four destination samples. Production
and live-site confirmation remain open. See the
[merge audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-svg-merge-allocation-and-transparent-borders-2026-11-17).

### Containing rectangle clips in document rasterization, 2026-11-17

`60880e94e` moves eligible ordinary containing clips into GG before a plain
antialiased fill, avoiding a second Quartz clip that removed the GPU's correct
fringe pixel. Native fallback restores the authored clip. Guarded original-page
compiled-LibJS captures improve 25 to 24 pixels (maximum 15 to 10) with one
resolved pixel and no regressions; the off control is exact to the prior
image. The 3,760-source production build parses zero tests. Regression sources
are committed but remain uncompiled/unrun by request; defaults and the original
zero-tolerance Brave reference remain unchanged. See the
[GitHub runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#rectangle-clip-ownership-24-differing-pixels-2026-11-17).


### Fractional fills and all containing ancestors, 2026-11-17

`b2ce3a8e5` retains fractional thin-fill geometry in GPU paint space; `968d162f9`
intersects every eligible containing rectangle there. This avoids both Quartz
shared-edge conditioning and a remaining outer publication clip discarding the
correct tab fringe. Guarded original-page compiled-LibJS captures improve
24→22→21 differing pixels with no newly wrong pixels, maximum error 10. The
21-pixel build consumes 3,761 production sources and zero tests; all captures
have exact content and zero native misses/compiler calls. Defaults and the
zero-tolerance original reference are unchanged. Regression sources are committed
but uncompiled/unrun under the requested hold. Full parity remains open. See the
[GitHub runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#fractional-fills-and-nested-clip-ownership-21-differing-pixels-2026-11-17).


### Raster runtime opt-ins without custom defines, 2026-11-17

`05c41f8bf` makes the existing document/image P3, thin-fill and PNG density/mipmap
experiments available through runtime environment options in ordinary production
builds. The sealed 3,761-source/zero-test build repeats the 21-pixel compiled-LibJS
GitHub image exactly; options off repeat the preceding shared bundle's off-path
image. The profile-bridge regression source remains uncompiled/unrun under the
requested hold. No mesh/depth counterfactual improves the complete reference;
full parity is still open. See the
[GitHub runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#runtime-raster-opt-ins-in-ordinary-production-builds-2026-11-17).


### Repeated fractional rectangle clips, 2026-11-17

`26b30df0b` coalesces identical finite ordinary rectangular clips before native
publication in the explicit diagnostic mode. A traced half-pixel file-name
clip had been applied twice, reducing coverage to a quarter. The complete
compiled-LibJS GitHub comparison improves 21→20 pixels with one exact correction
and no regressions; off repeats 21 exactly. Source, native-cache, full-content,
PID-adoption and exit gates pass. Regression sources remain uncompiled/unrun by
request, and the original zero-tolerance reference is unchanged. See the
[GitHub runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#identical-rectangular-clips-20-differing-pixels-2026-11-17).


### Fractional glyph clip boundaries, 2026-11-17

`86324739d` intersects ordinary axis-aligned text clips and blends their boundary
coverage through GG's A8 glyph mask. Fully covered pixels retain the existing
blitter; complex clips remain native and fallback restores deferred rectangles.
The opt-in compiled-LibJS GitHub capture improves 20→15 pixels with five resolved,
zero regressed/new pixels; off repeats 20. The sealed production build consumes
3,765 V sources and zero tests. CPU-clip and full-GG attempts remain rejected in
the receipts. Focused geometry/merge and one/four-sample mask test sources are
committed but uncompiled/unrun by request. Reference and zero tolerance are fixed;
full parity remains open. See the
[GitHub runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#fractional-glyph-clip-edges-15-differing-pixels-2026-11-17).


### Retained Chromium glyph-shadow masks, 2026-11-17

`12924db35` retains fractional author color, separates filtered linear-coverage
strikes, applies the existing fixed-point mask filter per glyph, then blends
float paint color once through GG. Eligibility is bounded to translated black
shadows with blur ≤3 at document scale one and an opaque backdrop; other cases
keep native replay. No shader changes. All 17 focused V functions execute,
including the existing retained-glyph, shadow and Skia blur golden hashes.
The unchanged twelve-case public shadow control improves 4,083→zero twice;
archived Slashdot improves 390→12 twice. All 76 workloads/152 captures repeat,
with the other 75 PNGs unchanged. BBC, Guardian and Verge remain zero twice,
also confirmed on production `8dbf43a2`; that production build contains an older
shadow prototype and cannot validate the final glyph filter. Remaining Slashdot
edge pixels, final production and live/catalog acceptance stay open. See the
[glyph-mask audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-per-glyph-shadow-masks-2026-11-17).


### SVG background image viewport clips, 2026-11-17

`2d65e5d97` retains the viewport in each supported fill's GPU clip stack, before
coverage, instead of clipping the resolved pixels again in Quartz. Authored
clips and local viewBox precision remain; analytic ovals keep their existing
sampling policy. All 34 focused V functions execute. Frozen Slashdot improves
12→10 pixels twice; BBC, Guardian and Verge remain zero twice. All 77 workloads/
154 captures repeat with the 76 prior PNGs unchanged. The new logo region is
exact and 9,720 outside-viewport samples pass; its complete compound control
retains 18 unchanged interior edge differences. A rejected 16-pixel circle
regression and complete earlier cohort remain in the evidence. Production
`ad081765` confirms the previous shadow fix at 12 Slashdot pixels and the three
news pages at zero; it lacks this viewport fix. Final production, remaining
pixels and live/catalog acceptance stay open. See the
[viewport audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-svg-background-viewport-clipping-2026-11-17).

### Extended P3 glyph ink, 17 November 2026

`2624eace7` adds an opt-in CPU A8 blend that preserves transformed RGB outside
[0,1] until the destination store, with GG retaining fractional clip edges.
The compiled-LibJS frozen GitHub page improves 15→13 pixels, exactly two resolved
and none new; same-binary off remains 15. Native compiler calls/misses are zero.
The full-GG alternative regresses Sign in and is rejected. New regression sources
remain unrun under the requested test hold. See the
[source-color audit](LIBJS_GITHUB_RUNTIME_20261115.md#extended-p3-glyph-source-13-differing-pixels-2026-11-17).

### Extended P3 shape ink, 17 November 2026

`2c77167fb` keeps finite opaque shape/underlay colors extended through GPU
coverage and blending when `VOX_DIAGNOSTIC_EXTENDED_SHAPE_COLOR=1` is selected.
The frozen compiled-LibJS GitHub comparison improves 13→12 pixels, exactly one
header edge resolved and none new. Same-binary off reproduces 13; native cache
misses/compiler calls are zero. Defaults and translucent conversions keep their
existing behavior. Focused regression sources remain unrun under the test hold.
See the [shape-color audit](LIBJS_GITHUB_RUNTIME_20261115.md#extended-p3-shape-source-12-differing-pixels-2026-11-17).

### Root capture pixel width, 17 November 2026

`77db37b0e` adds an opt-in capture-width projection for a single root raster
column when layout density exceeds capture density. Actual Brave rectangle
buffers replay identically with Dawn and GG shaders; changing only attachment
width isolates five separator errors. The final frozen compiled-LibJS GitHub
capture improves 12→7 pixels, five resolved and none new; same-binary off repeats
12. Both fresh processes have 4,245 native hits and zero misses/compiler calls
in the new 812a ABI partition. Sealed production inputs include zero tests;
focused regression sources remain unrun under the test hold. Broad shader-width
and compiler-language probes are rejected. Six button corners and an avatar
edge remain; live parity and matched performance are open. See the
[capture-width audit](LIBJS_GITHUB_RUNTIME_20261115.md#captured-rectangle-replay-and-root-capture-width-7-pixels-2026-11-17).

The latest completed shared production bundle now independently repeats seven
pixels with 4,246 native LibJS hits and zero compiler calls. Captured Dawn shaders
and GG both reproduce the same six changes when splitting the rectangle batch;
an auxiliary target preserves both control tiles while tracing primitive coverage.
`91252e0cf` adds a hash-pinned native replay CLI for exported rectangle draws;
three real captured draws match their complete raw-tile controls. Its rejection
regression sources remain unrun by request. No further production raster change
is accepted. See the [shared-bundle and replay audit](LIBJS_GITHUB_RUNTIME_20261115.md#shared-production-confirmation-and-captured-shader-grouping-2026-11-17).

### Disjoint rounded decoration batches, 17 November 2026

`753c3b684` adds an opt-in root batch across conservatively disjoint text/vector
gaps. Retained A8 ink refines broad bold/varied-font bounds only for this proof;
declines and truncated masks keep the conservative fallback. Effects/resources,
foreign owners, custom corners and unsupported opacity retain ordinary replay.
The compiled-LibJS frozen GitHub page improves 7→3 pixels: four Star corners
resolve with none new or regressed; same-binary off repeats seven. Both processes
have 4,245 native hits and zero misses/compiler calls. The sealed production
build consumes zero test sources; focused classification/mask regression sources
remain unrun under the test hold. Four ineligible candidates remain in the
receipts. Notifications corners, an avatar edge, live parity and matched speed
remain open. See the [three-pixel audit](LIBJS_GITHUB_RUNTIME_20261115.md#disjoint-rounded-decorations-3-differing-pixels-2026-11-17).


### Shadowed PNG and overlapping text samples, 17 November 2026

`289da9c02` adds an opt-in shared pass for an adjacent supported A8 text run
whose ink overlaps a shadowed PNG. The image, shadow and glyph keep their
multisample values until one resolve; each tile receives the rebased mask,
and the image's clip ends before the text draw. Unsupported text clips,
effects, ownership and native destinations keep ordinary replay. Frozen GitHub
improves **3→2** pixels, fixing the avatar/text edge without regressions.
Same-binary compiler-disabled on/off runs each use 4,245 native hits, zero
misses/compiler calls and complete content. The new actual ABI is prepared
normally before those checks. Focused selection, clip and transactional-failure
regression sources are committed but unrun under the test hold. The two
Notifications corners, live parity and matched speed remain open. See the
[two-pixel audit](LIBJS_GITHUB_RUNTIME_20261115.md#shared-image-and-overlapping-text-samples-2-differing-pixels-2026-11-17).


### Per-sample rectangle diagnostics, 17 November 2026

`796583540` adds optional per-sample primitive/coverage/fragment-position output
to `tools/replay_metal_rectangle.m`. Four retained-draw diagnostics reproduce
all complete control tile hashes, including normal replay. The split draw
changes triangle ownership at equal fragment-reported depth. The diagnostic
explicitly does not read the hardware depth-test result. Regression sources
for preserving sample evidence and rejecting conflicting outputs remain unrun.

A bounded late-fill batching candidate selects the Code underline but leaves
both Notifications corner errors unchanged in on/off/full-page trace captures.
It is reverted. These cache-disabled diagnostics provide no compiled-cache or
performance credit; the accepted frozen native-cache result stays at two pixels.
See [the runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#per-sample-rectangle-replay-two-pixels-remain-2026-11-17).


### Stored-depth and coverage-mask replay, 17 November 2026

`2dc3bb649` adds depth, raster-coverage and post-depth-coverage sample modes to
the canonical Metal rectangle replay. All 13 retained-draw diagnostics preserve
their complete BGRA controls; component labels and untouched values verify.
Mode-validation regression sources remain unrun. Final depth samples agree at
the disputed corners, while coverage masks vary with grouping. The flat-varying
mapping probe changes its control image and is rejected for attribution.

Explicitly returning the input coverage mask fixes the two Notifications pixels
but introduces 18 new full-page differences, so it is rejected. Both on/off
processes execute the pinned native cache with 4,245 hits and zero compiler
calls. The retained result stays at two pixels; no renderer change is kept.
See [the runtime report](LIBJS_GITHUB_RUNTIME_20261115.md#stored-depth-and-coverage-masks-rejected-whole-page-identity-2026-11-17).


### Constant-varying controls and live navigation, 17 November 2026

Fifteen selected-draw diagnostics preserve all ordinary control hashes but show
that flat constant color/radius/stroke varyings reproduce the rejected coverage
mask result, with 3/9/5 changed pixels across the three draw groupings. No
renderer change is retained; the frozen comparison stays at two pixels.
The latest shared production control at launch reproduces that exact image
with the native cache disabled. A separate direct-live reopen executes native
LibJS but fails the zero-miss gate after its module URLs change. These checks
supply no performance acceptance, and automated tests remain paused. See the
[live navigation audit](LIBJS_GITHUB_RUNTIME_20261115.md#direct-live-navigation-and-partial-native-cache-reopen-2026-11-17).


### Newer shared runtime rendering control, 17 November 2026

The shared `d166b53e…` production executable reproduces the accepted frozen
GitHub image exactly, with the same two remaining Notifications pixels. The
native cache is explicitly disabled; this establishes interpreter/rendering
behavior for that newer runtime. Its live GitHub capture evaluates all 76
modules and retains full content without reported errors. Separately, archived
and live Hacker News compiler-disabled reopens pass the new strict native-reuse
check; an identical-image empty-cache control correctly fails it. No renderer
change or performance acceptance is claimed. Tests remain paused. See the
[runtime audit](LIBJS_GITHUB_RUNTIME_20261115.md#strict-native-reuse-diagnostics-and-newer-runtime-checks-2026-11-17).


### Instanced-draw boundaries, 17 November 2026

Seventeen retained-draw diagnostics preserve instance/index order and all
resources while changing only instance chunk sizes. Full nine/eight controls
and the nine-instance split control reproduce their known complete hashes;
intermediate chunks change corner coverage. This supplies no whole-page fix,
and no renderer change is retained. The frozen two-pixel image and original
Brave reference stay unchanged. The pinned live native-cache cohort still
fails its zero-miss gate as module URLs change. See the
[cohort report](LIBJS_GITHUB_RUNTIME_20261115.md#fixed-bundle-live-cohort-changing-module-graphs-2026-11-17).

### Parallel CPU blur

Large Canvas2D image-filter blurs and box-filtered shadow masks split their
horizontal and vertical scans across up to four CPU threads. Each participant
needs at least 128 Ki pixels of work. The caller waits for each pass before
starting the next one or publishing the pixels. Every participant owns its
scratch state, and the vertical pass reads and writes only its assigned columns.
`VOX_SERIAL_CPU_RASTER=1` runs these passes serially for diagnostic comparisons.

The focused serial/parallel comparisons pass byte for byte on macOS and Linux,
including single-axis and in-place RGBA passes and a padded alpha mask. The
existing macOS blur fixtures pass with production preallocation. ThreadSanitizer
passes the focused tests, and a native macOS probe observes four distinct
threads covering all rows at the caller's rounding mode.
The pinned raster differential suite passes with its default count and seed,
including 10,000 pixel-exact blurred Canvas2D shadow draws.

### Parallel CPU image scaling

Large RGBA, R8 and Gray8 bilinear resizes and RGBA mipmap levels use up to
four raster participants. Each participant reads the shared source and writes
its own output rows. Canvas2D and the browser's premultiplied image uploads use
the same mipmap kernel, including its odd-dimension weighting. Each level
finishes before the next level or upload starts. `VOX_SERIAL_CPU_RASTER=1`
selects the serial path.

Seven alternating fresh-process pairs used a single optimized macOS C build
with preallocation. The synthetic images were 2047×1795 and the destination
was 1003×857. The RGBA span includes premultiplication, mip reduction and
the final resize. The Gray8 span covers the resampler. Input generation and
output hashing sit outside both spans. Host one-minute load was 7.35 on
18 logical CPUs.

| CPU image operation | Serial median | Parallel median | Faster pairs |
| --- | ---: | ---: | ---: |
| Prepare a premultiplied RGBA image | 39.969 ms | 15.327 ms | 7/7 |
| Resize a Gray8 plane | 3.822 ms | 1.385 ms | 7/7 |

All output hashes matched and all timed processes exited zero. The focused
large-image tests pass on macOS with preallocation and Linux with Boehm,
including uneven scan ranges, mixed scaling, padded mipmap input and source
ownership. ThreadSanitizer passed on macOS. The pinned Skia differential
check matched all 2,500 mipmap cases. The macOS PNG and odd WebP upload
fixtures passed with staged GG and the production allocator, and with the
ordinary `-gc none` allocator. The initial unstaged run lacked the GG upload
APIs. Staging GG alone let it compile, but the unstaged preallocator crashed
inside the PNG decoder before resizing. Staging the production allocator
resolved that failure.

### Parallel JPEG and WebP plane mipmaps

Large byte-plane mip reductions share the RGBA integer mipmap kernel and
divide their output rows across up to four CPU participants. The JPEG and
WebP upload paths borrow the decoded source while filtering and retain the
new output directly at each level. Identity uploads still copy borrowed
pixels before appending chroma. Odd-dimension weights and the subsequent
Gray8 interpolation retain their existing rounding.

Seven alternating fresh-process pairs used macOS single-C `-prod` builds
with preallocation. The timed spans begin with deterministic decoded planes
and end with packed upload pixels. Host one-minute load was 6.51 on 18 logical
CPUs. Every output hash matched and every process and memory guard exited zero.

| CPU upload preparation | Dimensions | Before median | After median | Faster pairs |
| --- | --- | ---: | ---: | ---: |
| JPEG 4:4:4 | 2047×1795 to 1003×857 | 13.168 ms | 8.552 ms | 7/7 |
| WebP 4:2:0 | 2048×1840 to 1024×920 | 3.407 ms | 2.380 ms | 7/7 |

Focused serial and parallel pixel checks passed on macOS and Linux. The
production-allocator JPEG and odd/even WebP native fixtures, macOS
ThreadSanitizer check, and 2,500 existing Skia mipmap comparisons passed.

### Parallel CPU pixel readback

Large reads from premultiplied RGBA buffers now use up to four raster workers
when the touched source and destination ranges are disjoint. This conversion
serves Canvas2D pixel reads and some portable SVG and shadow uploads.
Overlapping views retain their original serial row order. The focused tests
cover padded and zero source strides, clipped rows, untouched destination
bytes and overlapping views, and pass on macOS with preallocation and Linux
with Boehm. The macOS ThreadSanitizer check and pinned CPU raster suite passed,
including 76 exhaustive and 2,000 random pixel-read comparisons against Skia.

On an Apple M5 Max with 18 logical CPUs and one-minute load of 6.04, seven
alternating fresh-process pairs used matching macOS single-C `-prod` builds
with preallocation. The timed call reads a 1920×1080 source into a 1927×1073
destination at (-7, 3), with padded rows on both sides. Input generation and
output hashing are outside the timed span. Median CPU readback latency
fell from 8.683 ms to 3.496 ms, with the candidate faster in all seven pairs.
A separate instrumented run observed four distinct threads. Every timed run
produced the same destination SHA-256
(`01deabb3dae311e16d18730a6e7f69d7fd5eae346b594f71d604782546a23e8b`).
All processes and guards exited zero. These timings cover the CPU conversion
call and its dispatch.

### Parallel WebGL bitmap export

Large bitmap conversions for WebGL texture uploads divide destination rows
among up to four CPU participants. Workers share the prepared source and
column mapping and join before the texture upload. The same code handles
flipped and scaled exports, including the platform's nearest sampler, packed
formats and Display P3 conversion. Small conversions and the raw RGB888
export use the caller.

Seven alternating fresh-process pairs per format used matching macOS
single-C `-prod` builds with preallocation on an Apple M5 Max. A 2047×1153
source with padded rows was flipped and scaled to 1920×1080. The timed span
includes output allocation, setup, sampling, conversion and worker completion.
It excludes source generation, output hashing and the GPU upload. One-minute
host load ranged from 7.38 to 7.42 on 18 logical CPUs.

| Output | Before median | After median | Faster pairs |
| --- | ---: | ---: | ---: |
| RGB565 | 5.019 ms | 3.086 ms | 7/7 |
| Premultiplied sRGB RGBA8888 | 5.809 ms | 2.906 ms | 7/7 |
| Straight RGBA8888 from Display P3 | 150.697 ms | 49.269 ms | 7/7 |

Every output matched its baseline byte for byte and all timed processes and
guards exited zero. A separate probe observed four distinct CPU threads in
each conversion. Focused macOS and Linux comparisons covered sampling across
tile boundaries, padded input, flipping and color conversion. ThreadSanitizer
passed on macOS. The pinned Skia suite matched 448 exhaustive and 2,016
random bitmap exports. The native WebGL test read back all pixels of a
1031×521 flipped upload successfully in serial and parallel modes.

### Parallel CPU erosion and dilation

Canvas2D SVG-reference `feMorphology` uses a sliding per-channel minimum for
erosion and maximum for dilation over the existing separable passes. Each sample enters
and leaves the queue at most once. The same 256-pixel radius cap and
transparent-black border apply. Large surfaces split the horizontal pass by
rows and the vertical pass by columns, with a join between passes. An axis
with no radius reuses its input.

Seven alternating fresh-process groups used macOS single-C `-prod` builds
with preallocation on an Apple M5 Max. Each group compared the previous
implementation, the new implementation with `VOX_SERIAL_CPU_RASTER=1`, and
the default worker policy. The timed span is a Canvas2D path draw with one
SVG morphology node and includes mask creation, filtering, cropping and the
final composite. Input construction and output hashing are outside the span.
One-minute load ranged from 5.16 to 5.17 on 18 logical CPUs.

| Operation and canvas size | Before median | New serial median | New default median |
| --- | ---: | ---: | ---: |
| Radius-16 dilation, 1103×577 | 110.632 ms | 15.729 ms | 7.980 ms |
| Radius-2 erosion, 1600×900 | 48.682 ms | 29.950 ms | 13.433 ms |
| Radius-1 dilation, 176×128 | 0.597 ms | 0.496 ms | 0.466 ms |

All 63 draws matched their baseline pixels and exited zero under the memory
guard. A separate macOS probe observed four distinct threads on both passes
of both large workloads. The small workload stayed serial under both settings.
The macOS and Linux focused checks matched a direct rectangular reference,
including one-pixel axes, unequal radii, radius capping, ring wrap, and the
decal border. The serial and parallel large results matched byte for byte.
The SVG graph regression tests, macOS ThreadSanitizer run, and pinned CPU
raster differential suite also passed.

### Parallel CPU filter offsets

The CPU fallback for SVG-reference `feOffset` and fractional drop-shadow
translations shares bilinear column samples across rows. Each of up to
four raster workers calculates its row samples and writes separate output
rows. The filter keeps its per-channel interpolation and transparent-black
samples outside the layer. Integral offsets use the row copy. Fully
off-layer offsets produce a transparent surface.

Seven alternating fresh-process groups used matching macOS single-C
`-prod` builds with preallocation on an Apple M5 Max. The timed span is a
Canvas2D path draw with one fractional SVG offset node, including layer
creation, filtering, cropping and the composite. Path construction and
hashing are outside the span. One-minute load was 6.20 on 18 logical CPUs.

| Canvas size and offset | Before median | New serial median | New default median |
| --- | ---: | ---: | ---: |
| 1031×527 at (13.16843, −9.625) | 9.604 ms | 6.989 ms | 3.981 ms |
| 1920×1080 at (−0.00014648, 1) | 35.726 ms | 25.799 ms | 15.169 ms |
| 176×128 at (0.5, −0.5) | 0.407 ms | 0.324 ms | 0.323 ms |

Every output matched its baseline bytes and all 63 timed processes and
the memory guard exited zero. A separate probe observed four distinct
threads in each large workload. The small workload runs serially under
both worker settings. Focused tests on macOS and Linux checked bilinear
edges, integer translations, large off-layer shifts and matching serial
and parallel results. The SVG filter graph tests, ThreadSanitizer and
the pinned CPU raster differential suite also passed.

#### Archived browser eligibility

The published single-C receipt `20261118-030853-ecf3924d`, executable SHA-256
`9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301`,
predates this change. A separate injected diagnostic pinned that executable
and its helpers and counted calls to the raster dispatch callback at Mach-O
offset `0x1170254`. A large Canvas2D blur on the same executable executed
two four-thread batches, confirming the callback and JavaScript path.

Each site used a fresh process and private profile/cache through sealed
original-origin replay at 1024×768 and 2×, with one second of settling.
The audit checked URL, title, complete readiness, JavaScriptCore
initialization and distinct content IDs. All browsers and guards exited
zero. An initial pilot used a 796-pixel document height and was repeated
with the corrected 768-pixel height.

| Archive | Content IDs | CPU raster batches | Diagnostic launch to capture exit |
| --- | ---: | ---: | ---: |
| Hacker News | 30 | 0 | 1,539.620 ms |
| GitHub `vlang/v` | 33 | 0 | 3,639.429 ms |
| Old Reddit `r/programming` | 25 | 0 | 1,756.248 ms |

The Hacker News and Old Reddit decoded pixels matched the retained
[frame-clear references](NATIVE_FRAME_CLEAR_BENCHMARK.md#input-identities).
The GitHub replay used the retained November 12 archive
`b9e3e33910c5df77c2f723532cc9f5e791341c8cc44ce4bfbabd5fb40cc3b7db`
and produced decoded RGBA SHA-256
`69ab76c878a122501f91053ef8ae07b2ca073da35bafc92c065dbce55920a0bc`.
These single observations establish dispatch eligibility for the published
browser at capture time. A before-and-after site comparison of the new
offset code awaits the newer production executable.

### Parallel CPU filter compositing

The software `feMerge` and fallback drop-shadow merge composite disjoint
output row bands on up to four raster workers. Each band processes the
inputs in drawing order, including repeated inputs. Work sizing uses the
number of source pixels across all inputs. Premultiplied source-over,
transparent-pixel skipping and integer rounding use the existing arithmetic.

Seven alternating fresh-process groups used matching macOS single-C
`-prod` builds with preallocation on an Apple M5 Max. The timed span was a
Canvas2D path draw with the source and translated copies merged through
one SVG-reference filter. It included filter-layer creation, integer offsets,
the merge, cropping and final composition. The one-minute load was 10.56
on 18 logical CPUs while the shared production build ran.

| Canvas size and inputs | Before median | New serial median | New default median | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 1031×527, two inputs | 5.123 ms | 5.191 ms | 4.038 ms | 7/7 |
| 1920×1080, five inputs | 35.386 ms | 35.059 ms | 21.875 ms | 7/7 |
| 176×128, two inputs | 0.279 ms | 0.282 ms | 0.274 ms | 4/7 |

All 63 draws produced byte-identical output for their workload and every
timed process and memory guard exited zero. A separate probe confirmed
four distinct threads for both large workloads. The smallest workload
stayed serial. Focused macOS and Linux tests covered order, repeated
inputs, opacity, saturation and unchanged sources. SVG filter graph tests,
ThreadSanitizer and the pinned CPU raster differential suite passed.

### Parallel CPU color matrices

The software color-matrix layer used by Canvas2D `feColorMatrix` and
matrix filters that require an intermediate surface now divides large
buffers into disjoint row ranges for up to four CPU participants. A matrix
evaluates transparent black once for the layer because unpremultiplication
maps every zero-alpha source pixel to that input. The result can remain
transparent or introduce color and opacity. Workers borrow the validated
matrix and source pixels and use the existing channel clamping and rounding.

Seven alternating fresh-process groups used matching macOS single-C
`-prod` builds with preallocation on an Apple M5 Max. The timed span covered
a Canvas2D path draw using one SVG color-matrix node, including layer drawing,
matrix evaluation, cropping and final composition. Path construction and
output hashing were outside the span. One-minute load was 5.49 on 18 logical
CPUs.

| Canvas size and transparent-pixel behavior | Before median | New serial median | New default median |
| --- | ---: | ---: | ---: |
| 1920×1080, preserves transparency | 27.842 ms | 21.940 ms | 15.779 ms |
| 1920×1080, adds color and opacity | 29.153 ms | 25.230 ms | 17.296 ms |
| 176×128, preserves transparency | 0.338 ms | 0.284 ms | 0.283 ms |

All 63 draws matched their baseline pixels byte for byte and every timed
process and the memory guard exited zero. A separate probe observed four
distinct threads in both large workloads. The small canvas stayed serial
in both worker modes. Focused tests passed on macOS and Linux, including
zero alpha with nonzero stored RGB, alpha bias and invalid matrices.
The SVG filter graph tests, macOS ThreadSanitizer and pinned CPU raster
differential suite passed.

### Parallel CPU SVG color-space conversion

The Canvas2D SVG filter evaluator divides large sRGB and linear RGB
conversions across up to four CPU workers. Each worker writes a separate
range of rows and shares the gamma table built for the pass. Integer
unpremultiplication computes the same clamped lookup index as the former
floating-point calculation for every byte channel and nonzero byte alpha.
The conversion preserves alpha and writes transparent black at zero alpha.

Seven alternating fresh-process groups used matching macOS single-C
`-prod` builds with preallocation on an Apple M5 Max. The timed span was
a Canvas2D path draw with one or two SVG color conversion nodes, including
layer drawing, conversion, cropping and final composition. Path construction
and output hashing were outside the span. One-minute load ranged from 6.07
to 6.14 on 18 logical CPUs.

| Canvas size and conversion | Before median | New serial median | New default median | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 1920×1080, sRGB to linear RGB and back | 30.442 ms | 21.991 ms | 16.834 ms | 7/7 |
| 1051×527, sRGB to linear RGB | 5.596 ms | 4.829 ms | 4.135 ms | 7/7 |
| 176×128, sRGB to linear RGB and back | 0.382 ms | 0.282 ms | 0.289 ms | 6/7 |

All 63 draws produced byte-identical pixels against their respective
baselines and all timed processes and the memory guard exited zero.
A separate probe observed four distinct threads per conversion on both
large canvases. The small canvas stayed serial. Focused macOS and Linux
tests passed, covering all 65,280 nonzero-alpha lookup combinations,
both gamma directions and unchanged source buffers. The general SVG
filter tests, macOS ThreadSanitizer and pinned CPU raster differential
suite passed.

### Parallel CPU opacity filtering

The Canvas2D CPU fallback for Chromium-style `opacity()` distributes
large premultiplied layers across up to four raster workers. Each worker
uses the same 8-bit alpha table and writes separate rows. Transparent
source pixels and pixels reduced to zero alpha leave the output clear.
Other pixels use the existing premultiplication and rounding.

Seven alternating fresh-process groups used matching macOS single-C
`-prod` builds with preallocation on an Apple M5 Max. The timed span was
a Canvas2D image draw with an opacity filter, including the layer draw,
opacity pass and final composition. Source generation and output hashing
were outside the span. One-minute load was 7.65 on 18 logical CPUs.

| Canvas size and opacity | Before median | New serial median | New default median | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 1920×1080, 48% | 27.830 ms | 26.566 ms | 20.565 ms | 7/7 |
| 1051×527, 25% | 7.310 ms | 7.134 ms | 5.802 ms | 7/7 |
| 176×128, 48% | 0.302 ms | 0.292 ms | 0.289 ms | 6/7 |

All 63 draws matched their baseline pixels byte for byte and all timed
processes and the memory guard exited zero. Focused macOS and Linux tests
covered the byte alpha table, transparent input and output, serial equivalence
and unchanged input. The general filter tests, ThreadSanitizer and pinned
CPU raster differential suite passed.
A separate probe observed four distinct threads on each large workload.
The small workload stayed serial.

### Archived sites with CPU raster workers enabled and disabled

Seven alternating fresh-process pairs on the published single-C
`-prod` receipt `20261118-035602-2025fd74` compared
`VOX_SERIAL_CPU_RASTER=1` with the default. Its sealed filter source
includes the parallel merge implementation `9df5b6d37`. The new opacity
implementation was measured separately in the Canvas2D benchmark above.
The timed site span was executable launch through document PNG capture,
audit, and successful process exit. Fresh private profiles and HTTP
caches used sealed original-origin replay at 1024×768 and 2× with a
one-second settle period. System caches remained in place.

| Archived page | Workers disabled | Default | Default faster pairs | Raster batches in separate probe |
| --- | ---: | ---: | ---: | ---: |
| Hacker News | 1576.322 ms | 1567.403 ms | 3/7 | 0 |
| GitHub `vlang/v` | 4057.344 ms | 4088.959 ms | 1/7 | 0 |
| Old Reddit `r/programming` | 1897.367 ms | 1875.483 ms | 5/7 | 0 |

The medians vary from a 1.2% decrease to a 0.8% increase. The sites
dispatched no CPU raster batches in the eligibility runs, so the
launch-to-capture differences cannot be attributed to those workers.
A large Canvas2D blur on the same executable dispatched two batches
through the Mach-O callback at offset `0x11733d8`.

All 42 captures matched their independent serial references byte for
byte. They preserved 30/33/25 distinct content IDs and 6/61/18 served
response identities respectively, with complete readiness, JavaScriptCore
initialized, and zero reported script or replay errors. Every browser and
the memory guard exited zero. The sampled peak process-tree RSS was
1,658,454,016 bytes, with one-minute load ranging from 6.23 to 11.44 on
18 logical CPUs.

The pinned executable SHA-256 was
`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`.
The archives and decoded pixels matched the
[earlier eligibility runs](#archived-browser-eligibility), including the
November 12 GitHub archive. The AVIF and adblock helper hashes matched the
[frame-clear input identities](NATIVE_FRAME_CLEAR_BENCHMARK.md#input-identities).

The samples below are launch-to-exit milliseconds, rounded to three decimal
places and ordered by pair. Odd pairs ran the disabled setting first.

| Page | Workers disabled, ms | Default, ms |
| --- | --- | --- |
| Hacker News | 1533.567, 1547.174, 1576.322, 1744.063, 1597.556, 1567.270, 1587.807 | 1564.719, 1567.366, 1587.198, 1598.561, 1567.403, 1583.624, 1555.268 |
| GitHub | 3853.822, 3950.398, 4105.820, 4075.114, 4057.344, 3971.380, 4060.107 | 4933.405, 3977.557, 4124.217, 4159.841, 4056.026, 3978.884, 4088.959 |
| Old Reddit | 1927.751, 1863.949, 1870.874, 1862.046, 1903.934, 1902.416, 1897.367 | 1901.780, 1874.911, 1842.151, 1887.112, 1877.571, 1875.483, 1853.312 |

### Parallel macOS screenshot opacity checks

The native screenshot path checks whether an RGBA region is fully opaque.
On large macOS bitmaps the caller checks the first row, then up to four
threads scan disjoint row ranges using the existing vector and scalar
kernels. The immutable region stays borrowed until all workers join.
Early translucency in the first row skips dispatch. Small regions, scalar
diagnostics and `VOX_SERIAL_CPU_RASTER=1` use the serial scan.

On published receipt `20261118-035602-2025fd74`, an interposed probe
validated the caller at Mach-O offset `0x1164d68`. It observed one scan and
one successful presented-frame capture per archived site. All three
captures had the same decoded RGBA hashes and content counts as the
[worker-setting cohort](#archived-sites-with-cpu-raster-workers-enabled-and-disabled).
Each capture used a fresh process, sealed replay, a 1024×768 document
viewport at 2×, and a one-second settle period. Browser and guard exits
were zero.

Matching Clang `-O2` builds benchmarked just the scan on each captured
2048×1536 RGBA image after reading it into memory. Each group used seven
alternating fresh-process pairs. The first cohort ran under one-minute
load of 13.33–27.01 on 18 logical CPUs and improved four of seven pairs
per opaque input. A follow-up at load 8.46 had lower medians for every
opaque input. The warm comparison used the same candidate binary in
both modes and took the median of 17 scans after six warm-ups per process,
at load 10.65. All seven warm pairs improved on every opaque input.

| Image | Contended before → after, µs | Follow-up before → after, µs | Warm serial → parallel, µs |
| --- | ---: | ---: | ---: |
| Hacker News | 420.417 → 413.833 | 259.375 → 187.750 | 125.709 → 59.500 |
| GitHub | 404.709 → 350.750 | 267.709 → 195.708 | 125.959 → 48.125 |
| Old Reddit | 411.375 → 384.417 | 277.125 → 187.458 | 129.041 → 61.208 |
| Hacker News with translucent first pixel | 0.708 → 0.834 | 0.417 → 1.667 | — |

Both builds returned the same opacity verdict in every trial. All
benchmark processes and guards exited zero. A separate probe observed
four distinct worker threads and confirmed direct serial execution when
forced and when the first pixel was translucent. Tests covered unaligned
and padded rows, all small alpha positions, and large worker boundaries.
The native snapshot fixtures matched decoded pixels, profile and other
PNG metadata in ARC, non-ARC, ASan/UBSan and ThreadSanitizer builds.
The published browser supplied the workload and eligibility evidence.
The timing spans exclude painting, PNG encoding and browser startup.

### Parallel CPU scroll-tile publication copies

The opt-in macOS CPU tile compositor and CPU bootstrap for GPU tiles
now batch changed tile uploads. The caller reserves and locks the
IOSurfaces, then up to four workers copy disjoint destinations. The caller
joins the workers before unlocking and publishing. Clean tiles keep their
image references. A failed reservation leaves the previous tile frame
available. One-tile uploads and `VOX_SERIAL_SCROLL_TILE_COPY=1` stay serial.

A standalone Apple Clang 21 `-O2 -fobjc-arc` harness timed
`native_scroll_tiles_commit` from entry through image adoption. It checked
every visible pixel after the measurement, with a new process for each
trial. The control used the previous header. The serial and parallel
arms used the same candidate binary. Each case had seven alternating
groups and zero process or guard failures. Full-refresh cases ran at a
one-minute load of 7.78 on an 18-logical-CPU Mac17,6. The sparse cases ran
at load 26.41 and showed greater spread.

| Document pixels and tile updates | Before, µs | Candidate serial, µs | Candidate default, µs | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 2048×1536, six tiles, cold | 4045.125 | 3810.125 | 3420.209 | 7/7 |
| 2048×1536, six tiles, warm | 440.125 | 407.916 | 232.583 | 7/7 |
| 2051×1043, five padded tiles, warm | 389.917 | 393.333 | 143.959 | 7/7 |
| 641×229, one tile, warm | 16.584 | 16.833 | 16.375 | 3/7 |
| 2048×1536, one changed tile, warm | 49.583 | 56.542 | 54.916 | 5/7 |
| 2048×1536, two changed tiles, warm | 180.083 | 177.250 | 91.084 | 6/7 |

Warm runs had two prior commits. The sparse runs primed all six tiles
and then replaced one or two while retaining the rest. A separate probe
resolved the tile callback at Mach-O offset `0x18b4` and observed four
distinct threads on each full-size dispatch. The one-tile case and
forced-serial case did not dispatch. The native tests passed in ARC,
non-ARC and ASan/UBSan builds, including pixel equality for packed and
padded surfaces, retained image identity, and partial reservation
failure. ThreadSanitizer passed both large copy workloads.

The published single-C-unit receipt `20261118-035602-2025fd74`
(`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`)
supplied browser eligibility evidence. Fresh sealed-archive captures of
Hacker News, GitHub and Old Reddit matched the existing decoded RGBA and
content references at 1024×768 CSS pixels and 2× backing scale. Screenshot
capture produced zero tile publications on all three sites.

A separate windowed diagnostic on that same bundle enabled
`VOX_SCROLL_TILE_COMPOSITOR=1` and tile logging. Each archived site used a
fresh profile and cache, two seconds of title-matched settling, and
48 native wheel events at nominal 60 Hz with a reversal halfway through.
Hacker News committed six changed tiles once before input. During input
it reported 46 one-tile updates, two two-tile updates, and one publication
with zero tiles changed. Old Reddit scrolled with zero tile publications.
GitHub loaded the archived document and received all 48 events, but its
scroll offset stayed fixed. The measurement driver exited 1 for GitHub and
0 for the other two. All browser processes and the memory guard exited 0.
These runs establish eligibility on the older bundle. The before/after
timings cover the native upload and adoption only. Whole-browser timing
for the new code awaits a published build containing it.

### Parallel native SVG turbulence

The macOS SVG filter graph builds its deterministic gradient table once.
The CPU raster workers then fill disjoint row bands of the turbulence
bitmap. Core Image receives the complete bitmap after all workers join.
Small images and `VOX_SERIAL_CPU_RASTER=1` use a single range. Both
`turbulence` and `fractalNoise` retain their pixel arithmetic.

Matching Apple Clang 21 `-O2` harnesses measured gradient-table setup and
RGBA generation through completion. Seven alternating fresh-process
groups used the previous function, the candidate with forced serial
execution, and the candidate with default workers. Warm cases generated
one untimed image first. The 18-logical-CPU host's one-minute load was
8.70–12.41. All processes and the memory guard exited zero. Output hashes
matched across all arms.

| Bitmap and filter | Before, ms | Candidate serial, ms | Candidate default, ms | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 64×65, one octave, turbulence, warm | 0.055 | 0.056 | 0.056 | 2/7 |
| 257×193, three octaves, fractal noise, cold | 1.084 | 1.256 | 0.439 | 7/7 |
| 641×393, three octaves, turbulence, warm | 7.527 | 6.609 | 1.868 | 7/7 |
| 1281×785, four octaves, fractal noise, warm | 34.097 | 34.252 | 9.165 | 7/7 |

An earlier callback implementation at load 5.50 had before/default
medians of 0.043/0.047, 0.919/0.301, 4.542/1.283 and 23.652/6.856 ms.
A separate diagnostic resolved the final worker entry at Mach-O offset
`0xe10` and observed four distinct threads in each large dispatch. The
small and forced-serial cases did not dispatch. ASan/UBSan and
ThreadSanitizer passed both large raster cases. The native CSS filter
suite compared exact serial/parallel bytes, rounding modes, translated
Core Image output and repeated-frame ownership.

The published single-C-unit build
`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`
supplied eligibility observations. Sealed Hacker News, GitHub and Old
Reddit captures retained their prior content and decoded RGBA references
at 1024×768 CSS pixels and 2× backing scale with a one-second settle.
None called the turbulence rasterizer. A local `feTurbulence` control
activated the probe at executable offset `0x2ed0c` with a 1282×786
noise image. All browser processes and the memory guard exited zero.
The before/after timings cover only the native filter. A published
browser with the new worker code is pending.

### Published Hacker News scroll-tile check

Receipt `20261118-043956-76e1c1ba`, single C unit with V `-prod`, sealed
the scroll-tile header from `121617152`. Executable SHA-256 was
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`.
The archived homepage retained its 30 audited entries and exact decoded
RGBA reference `a12f1a485f6b1e6f9d87dc1a49e47c3e2b7c2245858332e1209ff15041734642`
with the CPU tile compositor enabled. The screenshot and guard exited 0.

A separate interposed diagnostic resolved the tile worker at executable
offset `0x1172328`. It observed four distinct threads on the initial
six-tile upload and two distinct threads on each of two two-tile uploads
during input. The diagnostic received all 48 wheel events, produced 48
native publications, and exited 0 in the browser, driver and guard.

Two alternating pairs used `tools/measure_precise_scroll.py` with
`VOX_SCROLL_TILE_COMPOSITOR=1`, then contrasted
`VOX_SERIAL_SCROLL_TILE_COPY=1` with the default worker setting on that
same build. Each trial used a fresh process, profile and cache, sealed
original-origin HTTPS replay, JavaScript enabled, a 1024×768 document
viewport at 2×, and two seconds of title-matched settling. The driver
sent 48 wheel events at nominal 60 Hz with delta 5 and a reversal after
24 inputs. Browser, driver and guard exits were all 0. One-minute load
was 10.28–10.68 on 18 logical CPUs. Each trial completed all 48 inputs,
49 total native publications and 46 measured scroll changes.

| Pair and worker setting | Actual input Hz | Scroll publications/s | Median / p95 / max interval, ms | Intervals over 16.67 ms | Leading / trailing gap, ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 serial | 59.87 | 58.59 | 16.46 / 20.38 / 26.46 | 22/46 | 18.22 / 14.53 |
| 1 parallel | 60.00 | 58.72 | 16.73 / 20.79 / 24.74 | 24/46 | 20.24 / 12.90 |
| 2 parallel | 59.90 | 58.62 | 16.99 / 21.67 / 26.82 | 25/46 | 19.98 / 14.24 |
| 2 serial | 59.85 | 58.58 | 16.62 / 21.97 / 24.97 | 22/46 | 18.56 / 14.76 |

Throughput uses the entire first-to-last input window and counts changes
at completed native frame installation after the outer view paint.
Observed throughput stayed close to 58.6–58.7 publications per second
across settings. The parallel trials had more intervals over budget.
The result establishes native worker use on this archive, with no
measurable scrolling gain under this short input schedule.

### Parallel macOS opacity-group compositing

The macOS CSS opacity and SVG mask groups use the CPU raster workers for
large blends. The caller flushes Quartz, lends the source and backdrop
bitmaps, and publishes the result after the worker batch joins. Each
worker owns complete output rows and uses the existing normal or screen
pixel kernel. Groups below 131,072 pixels and
`VOX_SERIAL_CPU_RASTER=1` use a single range.

Matching Apple Clang 21 `-O2` harnesses timed compositing into a completed
RGBA buffer. Seven alternating fresh-process groups used the previous
row loop, the new forced-serial path, and the new default. Warm inputs
had one untimed composite. The 18-logical-CPU host's one-minute load was
6.13. Every process and the guard exited 0, and output hashes matched
across all arms.

| Region and blend | Before, µs | Candidate serial, µs | Candidate default, µs | Default faster than before |
| --- | ---: | ---: | ---: | ---: |
| 84×72, padded normal, warm | 7.042 | 6.833 | 6.792 | 6/7 |
| 511×385, padded normal, cold | 214.959 | 213.792 | 102.333 | 7/7 |
| 1480×960, normal, warm | 1245.334 | 1255.375 | 366.542 | 7/7 |
| 1480×960, screen, warm | 2437.583 | 2372.583 | 667.667 | 7/7 |

A separate dispatch probe resolved the worker entry at executable offset
`0x2c68` and observed four distinct threads for the large normal and
screen cases. The small and forced-serial cases stayed on the caller.
The optimized and ASan/UBSan unit tests passed for both modes, padded
destinations and changing rounding modes. ThreadSanitizer passed both
large blend cases. Core Graphics tests compiled the previous and
current CSS and SVG mask group endings in ARC and non-ARC modes. They
matched byte for byte on cropped groups with a padded parent bitmap.

The published single-C-unit build
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
supplied browser eligibility observations. Sealed Hacker News, GitHub
and Old Reddit captures at 1024×768 CSS pixels and 2× backing scale
matched their prior content and decoded RGBA references after a
one-second settle. All browser processes and the guard exited 0.
An allocation probe at executable offset `0x1cd9c` found three CSS
blend regions on GitHub (84×72, 90×28, 28×32). All fit the serial path.
Hacker News and Old Reddit made no allocations at that call site.
A local opacity control exercised the same call site with a 1480×960
region. The table measures only the native blend, with the large
control's dimensions. Whole-browser verification of the new worker
code awaits its production build.

### Parallel macOS screenshot PNG compression

Large opaque sRGB snapshots split their unfiltered PNG rows into up to
four bands and compress them with system zlib. The caller joins the
byte-aligned DEFLATE blocks and combines their checksums into one zlib
stream. PNG dimensions, profile, density and ancillary metadata use the
existing writer. Small, translucent and other unsupported captures keep
the existing codec selection. `VOX_SERIAL_SNAPSHOT_PNG=1` bypasses the
band encoder for matched checks.

The single-C-unit production executable
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
supplied archived inputs at 1024×768 CSS pixels, 2× backing scale and a
one-second settle. All three pages used the direct presented capture
path and matched their prior content and decoded RGBA references.
A second set of fresh browser processes loaded the band encoder through
the existing codec extension point. Each screenshot invoked the codec
once and matched the prior decoded pixels, color profile, density and
ancillary metadata. All browser processes and guards exited 0.

Matching Apple Clang 21 `-O2 -fobjc-arc` harnesses timed
`native_encode_snapshot_png` from the captured bitmap through complete
PNG bytes in memory, including checksums and chunk construction. Seven
alternating fresh-process groups compared the previous ImageIO path,
the candidate forced to the same ImageIO path, and the candidate using
four bands. Input loading and writing to disk were outside the timer.
One-minute load was 4.95–5.12 on 18 logical CPUs. Every trial and guard
exited 0. Each mode's output was deterministic across trials.

| Archived page | Before, ms | Candidate serial, ms | Candidate parallel, ms | Before → after PNG bytes | Parallel faster than before |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hacker News | 17.846 | 17.881 | 4.931 | 461,920 → 462,100 | 7/7 |
| GitHub | 16.734 | 16.822 | 4.911 | 340,530 → 340,293 | 7/7 |
| Old Reddit | 19.185 | 19.311 | 5.073 | 544,974 → 544,785 | 7/7 |

A separate dispatch probe resolved the band callback at executable
offset `0x21fc` and observed four distinct threads for every archive.
Forced serial produced the same PNG bytes as the original path. Native
ARC and non-ARC tests passed under normal, ASan and UBSan builds. They
validated two through four bands, padded rows, incompressible input,
the complete Retina PNG and the optional codec fallback.
ThreadSanitizer also passed an archived capture. Timing covers encoding
only. The installed browser supplied the pixels and codec-extension
verification, so the default production route awaits its rebuild.

### Parallel PNG chunk checksums

The screenshot workers now emit complete PNG image-data chunks and
calculate their CRCs. Each zlib stream records its Adler-32 as it
compresses the filtered scanlines. After joining the workers, the
caller combines the Adler-32 values, finishes the last chunk's CRC and
appends the chunks in row order. This removes the intermediate joined
buffer and the caller's CRC scan across the whole compressed image.

The same sealed Hacker News, GitHub and Old Reddit archives produced
their prior pixel and content references using the published
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
executable. Fresh browser processes captured at 1024×768 CSS pixels,
2× backing scale and one second of settling. Browser and guard exits
were zero. The published browser supplied the input pixels.

Matching Apple Clang 21 `-O2 -fobjc-arc` harnesses timed the complete
`native_encode_snapshot_png` call before and after this change. The
control was the previous four-worker encoder in `d46e64920`. Seven
alternating fresh-process pairs ran per case. Warm trials performed one
untimed encode. Input loading, decoding for validation and disk writes
were outside the measurement. One-minute load was 3.91–4.16 on 18
logical CPUs. All processes and the guard exited zero.

| Archive | Cold before → after, ms | Cold pairs faster | Warm before → after, ms | Warm pairs faster |
| --- | ---: | ---: | ---: | ---: |
| Hacker News | 4.440 → 4.337 | 6/7 | 4.229 → 4.171 | 7/7 |
| GitHub | 4.102 → 3.971 | 5/7 | 3.879 → 3.843 | 4/7 |
| Old Reddit | 4.656 → 4.520 | 6/7 | 4.514 → 4.475 | 5/7 |

The concatenated image-data payload was byte-identical in each
comparison. Three extra chunk headers and CRCs add 36 bytes per file
with four bands. Each output matched the archived pixels, profiles,
density and ancillary metadata. An independent zlib decoder validated
two through four chunks with padded rows and incompressible input,
and checked each chunk's CRC. Retina metadata and fallback checks passed
in ARC, non-ARC and ASan/UBSan builds. A separate probe identified the
worker at offset `0x23cc` and observed four threads on every archive.
Forced serial matched the earlier ImageIO output. The software CRC
and ThreadSanitizer runs matched the new Hacker News PNG.

### Parallel stationary-frame bitmap copies

The macOS stationary-frame cache uses up to four raster workers when it
must copy a large bitmap. Byte-backed cache stores and restores, and
restores from a copied Core Graphics provider, share the same pitched
row copy. Workers join before the caller returns or publishes any
pixels. Copies smaller than 4 MiB and `VOX_SERIAL_CPU_RASTER=1` execute
on the caller.

Published executable
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
at 2× rendered the same sealed Hacker News, GitHub and Old Reddit
archives at a 1024×768 CSS-pixel viewport. The default reused an
immutable frame and made no instrumented cache copies. With
`VOX_COPY_STATIONARY_RASTER_PIXELS=1` the full 2048×1704 frame copied
13,959,168 bytes per operation. The site diagnostics observed two
stores each and four, sixteen and six restores respectively. An initial
probe that resolved symbols for every copy stalled on GitHub. The
completed diagnostic resolved the executable base once and matched
only the three stationary-copy call sites. A separate interposition
run executed the new copy helper at those call sites with the
compatibility switch. All completed captures matched their previously
audited content and decoded RGBA references and exited zero.

Matching Apple Clang 21 `-O2 -fobjc-arc` harnesses timed the native cache
store or restore call. Seven alternating fresh-process groups compared
the previous implementation, the new forced-serial path and the new
default. Cold cases allocated the copied-to storage before timing and
left its pages untouched. Full-frame inputs extended the archived
document bytes to the observed copy size. Warm cases made one prior
copy. One-minute load was 6.81–7.14 on 18 logical CPUs. Every byte,
including row padding, matched and all trial and guard exits were zero.

| Input and operation | Before, µs | Candidate serial, µs | Candidate parallel, µs | Faster than before |
| --- | ---: | ---: | ---: | ---: |
| Hacker News cold store | 900.375 | 916.666 | 691.208 | 7/7 |
| GitHub cold store | 840.208 | 938.000 | 847.500 | 5/7 |
| Old Reddit cold store | 825.958 | 878.750 | 663.584 | 6/7 |
| Hacker News cold restore | 1017.208 | 959.041 | 716.792 | 6/7 |
| GitHub cold restore | 839.084 | 940.583 | 693.583 | 4/7 |
| Old Reddit cold restore | 909.375 | 973.834 | 593.167 | 6/7 |
| Padded 2054×1514 warm store | 174.792 | 227.709 | 125.459 | 7/7 |
| Padded 2054×1514 warm byte restore | 165.584 | 180.042 | 103.083 | 6/7 |
| Padded 2054×1514 warm image restore | 174.125 | 175.791 | 122.500 | 7/7 |
| Padded 321×241 warm byte restore | 3.833 | 3.917 | 3.875 | 2/7 |

A dispatch probe resolved the worker callback at executable offset
`0x1b04` and observed four distinct threads for all three large copy
entry points in the completed run. Small and forced-serial copies
stayed on the caller. Native ARC, non-ARC, ASan/UBSan and ThreadSanitizer
checks passed, including fallback after a failed snapshot allocation.
The timings cover the compatibility copy calls. Production verification
of the new code awaits the shared rebuild.

### Parallel transparent clears for large pooled frames

The macOS frame pool uses the existing row workers to clear reused
transparent buffers of at least 33,177,600 bytes, the packed size of a
3840×2160 RGBA frame. A slot and its optional IOSurface stay reserved
until all rows have been cleared, including padding. Smaller buffers
keep the single clear. `VOX_SERIAL_FRAME_CLEAR=1` also forces a single
clear. Opaque callbacks can still defer initialization.

The published single-C-unit executable
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
supplied archive diagnostics. A probe resolved the pool clear at
executable offset `0x116a240`. Default captures of Hacker News, GitHub
and Old Reddit made zero clears there. Forcing
`VOX_CLEAR_OPAQUE_FRAME_BUFFERS=1` produced 5, 20 and 9 clears respectively,
all 13,959,168 bytes. Fresh processes used the sealed archives, a
1024×768 CSS-pixel viewport at 2×, and one second of settling. All
browser and guard exits were zero and the document content and decoded
pixels matched the prior references in both settings.

Matching Apple Clang 21 `-O2 -fobjc-arc` harnesses timed reacquisition
of a seeded pool slot through completion of its transparent clear.
This includes reservation and the shared buffer's lock. An eviction
case wrote a separate 64 MiB buffer before timing. Each case used
seven alternating fresh-process groups on 18 logical CPUs. The
one-minute load was 4.04–4.19 in the final cohort, with zero process or
guard failures. All tests checked every byte.

An initial candidate used workers for the 13–14 MiB frames. Its
before/default medians were 58.959/57.750 µs for the shared archive
size, 66.750/87.042 µs with eviction, 57.917/71.667 µs for padded
shared storage, and 53.792/69.750 µs for mapped storage. Those sizes
retain the single clear after an exploratory 4K and 5K cohort showed
consistent gains.

| Frame and storage | Before, µs | Candidate serial, µs | Candidate default, µs | Faster than before |
| --- | ---: | ---: | ---: | ---: |
| 1024×852 shared | 15.458 | 15.583 | 15.667 | 2/7 |
| 2048×1704 shared | 73.500 | 84.250 | 99.000 | 1/7 |
| 2048×1704 shared, evicted | 249.625 | 207.875 | 211.667 | 3/7 |
| 2051×1703 padded shared | 85.917 | 86.250 | 95.541 | 5/7 |
| 2051×1703 mapped | 62.416 | 72.375 | 75.292 | 4/7 |
| 3840×2160 shared | 295.958 | 345.583 | 194.167 | 6/7 |
| 4096×2160 shared, evicted | 521.041 | 539.458 | 232.458 | 6/7 |
| 5120×2880 shared | 625.625 | 742.416 | 356.750 | 7/7 |
| 5120×2880 shared, evicted | 814.792 | 832.542 | 470.666 | 7/7 |
| 5123×2879 mapped | 696.792 | 763.083 | 404.833 | 7/7 |

The smaller rows used the single-clear path in both builds and showed
trial variation. A separate probe resolved the worker at offset
`0x18b4` and saw four distinct threads on the large shared and mapped
buffers. It saw no dispatch for the archive size or forced serial.
The ARC and non-ARC pool suites, 288 white-clear compatibility
comparisons, and the focused ASan/UBSan and ThreadSanitizer runs passed.
Production validation of the new path awaits the shared rebuild.

### Parallel premultiplication of sampled PNG and WebP uploads

Sampled RGBA uploads now write a premultiplied copy in a single pass.
The existing CPU raster workers divide source rows at 262,144 pixels
and can use up to four lanes. The conversion keeps the original
`(channel * alpha + 127) / 255` rounding, preserves the source buffer,
and finishes before mip selection and filtering. There is no worker
dispatch below the threshold or with `VOX_SERIAL_CPU_RASTER=1`.

The archived page diagnostics used the published single-C-unit bundle
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`.
The probe counted source clones from the RGBA decode entry point at
return offset `0x1f4fc4`. It detected the 2,107,404-byte source in a
separate 1027×513 transparent PNG scaled to 200×100 CSS pixels. At
1024×768 CSS pixels and 2× capture scale with one second of settling,
the three sealed replays matched their content counts and existing
decoded PNG references. Fresh captures used private profiles and
caches, with JavaScriptCore context initialization and zero reported
JavaScript errors. The browser and guard exits were zero.

| Archive | Audited entries | RGBA premultiplication at capture | Frozen capture RGBA SHA-256 |
| --- | ---: | --- | --- |
| Hacker News | 30 | None | `a12f1a485f6b1e6f9d87dc1a49e47c3e2b7c2245858332e1209ff15041734642` |
| GitHub | 33 | 60×60 and 40×40, both serial | `69ab76c878a122501f91053ef8ae07b2ca073da35bafc92c065dbce55920a0bc` |
| Old Reddit | 25 | None | `d31ea76663720b84aa5e78a722e3cb21eb41cb345742572d2e6e66fc1070bc1a` |

A matching uninstrumented, single-C-unit `-prod -prealloc -gc none`
harness timed output allocation and premultiplication through return.
It compared the original clone and scalar loop, the new pass forced
serial, and the new pass with default scheduling. The timed scope ends
before mip generation or painting. Inputs were the two archived GitHub
avatars, the decoded PNG control, and synthetic packed RGBA with mixed
alpha. Seven alternating, fresh-process groups ran on 18 logical CPUs
at one-minute loads of 4.59–4.62. All 126 processes and the guard exited
zero, and each input produced identical output across the three modes.

| Source | First call before / serial / default, µs | Warm before / serial / default, µs |
| --- | ---: | ---: |
| GitHub 40×40 | 3.583 / 2.500 / 2.500 | 2.542 / 1.542 / 1.542 |
| GitHub 60×60 | 6.583 / 4.416 / 4.416 | 6.334 / 4.125 / 4.125 |
| 512×512 | 455.584 / 298.791 / 200.791 | 456.917 / 289.688 / 183.605 |
| PNG 1027×513 | 926.542 / 574.959 / 327.541 | 917.833 / 592.896 / 266.042 |
| 1025×1023 | 1849.625 / 1176.500 / 501.333 | 1855.417 / 1190.750 / 485.854 |
| 2049×2047 | 7818.292 / 4957.875 / 2166.542 | 7496.396 / 4954.813 / 1934.063 |

A separate dispatch diagnostic observed two threads at the threshold
and four at 1027×513. It recorded no dispatch at 60×60 or when forced
serial. The image suites passed with the Clang C backend in default
and production allocator configurations. The FastC attempt stopped
at an SDK-header compilation error before tests ran. The three
archives provide path eligibility and baseline pixel checks.
A candidate whole-page timing comparison requires the shared
production rebuild.

### Parallel RGBA and BGRA channel swaps

The macOS document raster callbacks and GPU image color readbacks
share an in-place red and blue channel swap. It runs serially below
524,288 pixels and can use up to four raster workers at or above
that size. Each lane owns complete rows and all lanes finish before
painting or publishing the buffer. The swap preserves alpha, green,
and any row padding. `VOX_SERIAL_CPU_RASTER=1` forces serial execution.

A single-C-unit V `-prod -prealloc -gc none` harness timed one in-place
swap of an initialized buffer through completion. It compared the
original macOS loop, the shared loop forced serial, and the shared
loop with default scheduling. Seven alternating fresh-process
groups ran on 18 logical CPUs at a one-minute load of 4.83. All
147 processes and the guard exited zero and their buffer hashes
matched across modes. The initial threshold trial at 512×512 had
first-call medians of 65.458 µs before and 65.000 µs with workers.
It was faster in four of seven groups, so that size stays serial.

| Surface | First call before / serial / default, µs | Warm before / serial / default, µs | First call faster |
| --- | ---: | ---: | ---: |
| 48×34 | 0.625 / 0.500 / 0.583 | 0.375 / 0.375 / 0.375 | 5/7 |
| 256×258 | 17.375 / 16.792 / 16.875 | 16.792 / 16.958 / 16.666 | 6/7 |
| 512×512 | 68.417 / 66.083 / 67.292 | 68.125 / 67.000 / 66.146 | 4/7 |
| 1024×512 | 136.000 / 132.042 / 79.417 | 136.063 / 131.084 / 60.396 | 6/7 |
| 1031×513, unaligned and padded | 137.958 / 138.458 / 123.791 | 141.771 / 138.188 / 56.063 | 7/7 |
| 2048×1536 | 826.459 / 803.125 / 319.334 | 832.167 / 819.500 / 223.021 | 7/7 |
| 3840×2160, padded | 2188.583 / 2184.125 / 626.834 | 2186.437 / 2143.542 / 583.542 | 7/7 |

A dispatch probe verified four threads at 1024×512 and at the
unaligned, padded size. It recorded zero dispatch at 1023×512 or
with the serial override. The focused CPU and GPU image color tests
passed with the prepared production allocator and the browser's GG
overlay. The CPU test checks every byte of a padded, unaligned
surface and verifies that two swaps restore the full original buffer.
It also passed with forced serial scheduling and with ASan and UBSan.

The published single-C-unit executable
`66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`
replayed Hacker News, GitHub, and Old Reddit at 1024×768 CSS pixels
and 2× capture scale. Each used a fresh process, private profile and
cache, and one second of settling. All three content audits
(30, 33, and 25 entries) and decoded PNG hashes matched their frozen
references. A breakpoint at `0x183ca0` recorded two 408×66 swaps
in a text-shadow control and no hits on the three archives. The
compiler inlines other call sites, so those counts cover only the
out-of-line entry. A first debugger run exceeded the focused 3 GiB
guard while capturing GitHub. The full diagnostic used the default
12 GiB guard and all three browser, debugger, and guard exits were
zero. Candidate whole-page timings still require the shared rebuild.

### Parallel premultiplication of Canvas2D destinations

Canvas2D draws use the same row workers as sampled-image uploads to
prepare straight-alpha destinations in place. As before, conversion
starts when a supported draw is ready to use the surface. The workers
finish before drawing. They round each RGB channel with
`(channel * alpha + 127) / 255` and leave alpha and row padding intact.
The caller still owns the transition to a premultiplied surface.
The shared scheduler can split surfaces of at least 262,144 pixels
across two to four workers. `VOX_SERIAL_CPU_RASTER=1` forces one range.

A prepared single-C-unit `-prod -prealloc -gc none` harness timed one
transparent source-over draw. The old control ran the original
Canvas loop and drew into the resulting premultiplied surface. The
candidate prepared a straight-alpha surface through the normal draw
entry. Each iteration restored the same input outside the timed
span. Seven rotating fresh-process groups per size compared the
original loop, the candidate forced serial, and the candidate with the
default scheduler. All 105 processes and the memory guard exited
zero and their full-buffer hashes matched across the three modes.
Warm values are the median of the within-process medians after the
first draw.
The one-minute host load was 13.25–15.84 on 18 logical CPUs.

| Canvas | First draw before / serial / default, µs | Warm before / serial / default, µs | Default faster than serial |
| --- | ---: | ---: | ---: |
| 300×150 | 105.792 / 44.541 / 54.042 | 99.188 / 40.688 / 42.375 | 3/7 |
| 512×512 | 490.292 / 290.417 / 214.500 | 499.646 / 264.062 / 173.333 | 5/7 |
| 1031×513, padded | 1066.958 / 516.125 / 252.875 | 1149.958 / 533.646 / 195.521 | 7/7 |
| 1920×1080 | 4407.500 / 2242.333 / 775.750 | 4390.980 / 2163.562 / 689.562 | 7/7 |
| 3840×2160 | 19590.333 / 8618.083 / 2578.000 | 16429.980 / 8707.416 / 2671.813 | 7/7 |

The exploratory timing overlapped the browser cohort at a one-minute
load of 22.65–23.58. Its first-draw before/default medians in table
order were 97.000/52.292, 712.083/224.917, 1211.291/373.708, 5241.291/867.792, 20287.625/3094.333 µs.

A separate probe observed two threads at 512×512 and four on the
padded 1031×513 surface. It saw no dispatch below the threshold or
in forced serial mode. The prepared allocator passed the focused
Canvas, glyph, filter-layer, and image raster tests. The Canvas
and sampled-image byte comparisons also passed in forced serial
mode and with ASan and UBSan.

Seven alternating fresh-process pairs per site used the published
single-C-unit receipt `20261118-055438-888e0b4d`, executable SHA-256
`9568a08eccc0567b56fa837e6d487bd57a63ec69d31c10b9760c9b5a6b5df757`.
This executable contains the sampled-image premultiplication change
and predates the Canvas change. The timings compare the existing
raster scheduler enabled and disabled from launch through PNG capture,
document audit and successful exit. All 42 captures used sealed
original-origin replay, fresh private profiles and HTTP caches, a
1024×768 CSS-pixel viewport at 2×, and one second of settling.
System caches remained in place.

| Archive | Workers disabled, ms | Default, ms | Default faster | Worker batches in separate probe |
| --- | ---: | ---: | ---: | ---: |
| Hacker News | 1556.732 | 1540.750 | 3/7 | 0 |
| GitHub | 3779.487 | 3789.892 | 4/7 | 0 |
| Old Reddit | 1787.573 | 1807.386 | 2/7 | 0 |

All captures matched their frozen pixel references and preserved the
same audited content and served response identities across both modes
(30/33/25 entries and 6/61/18 responses by site). The replay returned
the same 404s for the Hacker News and GitHub favicons and the two
unarchived Vinix screenshot URLs on GitHub in both modes. Those
known fixture misses were confirmed after two preflight attempts.
JavaScriptCore initialized, with no reported script errors, and
the audit found no canvas elements on these pages. The separately
validated worker probe observed a four-thread batch on a 1200×900
Canvas readback. It observed zero batches on each archive. The
measured site differences therefore provide no speedup attribution.
The one-minute site load was 5.08–24.59, with overlapping
benchmark work near the end of the cohort. All browser and guard
exits were zero. Whole-page checks of the Canvas change await the
shared rebuild.

The samples below are launch-to-exit milliseconds, ordered by pair.
Odd pairs ran the workers-disabled setting first.

| Archive | Workers disabled, ms | Default, ms |
| --- | --- | --- |
| Hacker News | 1793.020, 1556.732, 1530.002, 1531.847, 1521.110, 1618.192, 1628.853 | 1514.265, 1528.653, 1540.750, 1540.249, 1551.347, 1670.876, 1616.710 |
| GitHub | 3689.112, 3779.487, 3764.194, 3684.892, 3887.710, 4131.023, 4108.306 | 3639.933, 3789.892, 3748.792, 3724.459, 4339.400, 4051.171, 4049.266 |
| Old Reddit | 1758.637, 1768.435, 1787.573, 1735.655, 2354.995, 1886.693, 1857.683 | 1760.005, 1774.321, 1807.386, 1752.116, 2183.433, 1892.087, 1839.270 |

### Parallel truncating premultiplication for WebP paint pixels

The macOS WebP RGB paint path now fills the premultiplied copy directly
from the straight decoder bytes. It shares the raster premultiplication
loop with Canvas2D and sampled-image uploads, using a zero rounding
bias for WebP and 127 for the rounded conversions. The worker ranges
cover complete 1024-pixel batches. A final short range uses the same
conversion, and any partial-pixel bytes are copied unchanged. WebP
decoding policy and the straight bitmap used by Canvas stay intact.

A prepared single-C-unit `-prod -prealloc -gc none` harness timed output
allocation and premultiplication through return. The original control
cloned the straight buffer and truncated each color channel in a
scalar loop. Seven rotating fresh-process groups measured each input
with that loop, the new pass forced serial, and the new pass with
default scheduling. The input from the WebP control was decoded before
timing and the others used synthetic mixed alpha. The one-minute load
was 8.05–8.28 on 18 logical CPUs. All 105 timed processes and the guard
exited zero, and the full output hashes matched across modes for every
input. An initial 4×2 timing attempt reached the timer's resolution,
so that size is covered by the exact pixel tests.

| Source | First call before / serial / default, µs | Warm before / serial / default, µs | Default faster than before |
| --- | ---: | ---: | ---: |
| 128×128 | 26.166 / 9.250 / 8.916 | 26.083 / 9.000 / 9.042 | 6/7 |
| 512×512 | 423.750 / 145.750 / 129.500 | 424.605 / 148.250 / 110.896 | 7/7 |
| WebP 1031×513 | 876.583 / 315.042 / 194.084 | 858.000 / 299.625 / 175.396 | 7/7 |
| 1027×513, three trailing bytes | 876.500 / 297.417 / 194.167 | 870.146 / 296.583 / 179.459 | 7/7 |
| 2049×2047 | 6849.208 / 2497.042 / 1308.042 | 6892.959 / 2326.834 / 1256.251 | 7/7 |

A dispatch probe observed two threads at 512×512 and four at 1031×513.
There was no dispatch one pixel below the threshold or with
`VOX_SERIAL_CPU_RASTER=1`. The prepared allocator, forced serial, and
ASan/UBSan runs passed. The focused tests compare all bytes across
worker boundaries, check the last complete pixel and trailing bytes,
and verify that the source is preserved. The browser's focused WebP
tests passed through both local and fetched image entry points. Their
first combined invocation reached the 3 GiB guard during compilation.
Building that test under the default compile guard and then running
it under the focused 3 GiB guard succeeded.

The published single-C-unit bundle
`9568a08eccc0567b56fa837e6d487bd57a63ec69d31c10b9760c9b5a6b5df757`
provided archive eligibility and pixel checks. A probe at return
offset `0x125b98` detected the 2,115,612-byte RGBA source of a separate
1031×513 transparent WebP control. At 1024×768 CSS pixels and 2× capture
scale, Hacker News, GitHub and Old Reddit matched their frozen
references with 30, 33 and 25 audited entries. No archive called
the WebP paint conversion. Each capture used a fresh process,
private profile and cache, and one second of settling. Browser and
guard exits were zero. The component timings measure the WebP paint
conversion, and the candidate production capture awaits the rebuild.

### Parallel straight-alpha conversion for portable Canvas uploads

Linux and Windows Canvas uploads now use the shared CPU raster workers
to build the straight RGBA copy from the premultiplied surface. The
caller waits for every range before uploading it. The shared scheduler
keeps inputs below 262,144 pixels serial and can use up to four lanes.
The conversion uses a 256-entry read-only reciprocal table and preserves
the exact integer division and saturation for every color/alpha pair.
The source remains available for Canvas readback.

Seven rotating fresh-process groups timed allocation and conversion
through return for each surface. The three modes were the original
clone and scalar loop, the new implementation with
`VOX_SERIAL_CPU_RASTER=1`, and the new implementation with default
scheduling. Input generation and hashing were outside the timed span.
Warm values are medians of within-process medians after the first
conversion. The Linux run used four virtual CPUs in an AArch64 Lima
guest, V 0.5.2, and single-C-unit Clang `-prod -gc none`. The macOS
component run used the prepared single-C-unit Clang
`-prod -prealloc -gc none` compiler on 18 logical CPUs.
The one-minute load was 0.20–0.33 in the guest and 6.42–6.67 on macOS.

| Surface | Linux first before / serial / default, µs | Linux warm before / serial / default, µs | macOS first before / serial / default, µs | macOS warm before / serial / default, µs |
| --- | ---: | ---: | ---: | ---: |
| 300×150 mixed | 372.283 / 88.206 / 87.414 | 369.137 / 86.915 / 86.623 | 93.500 / 59.792 / 58.209 | 91.542 / 57.542 / 57.188 |
| 512×512 mixed | 2152.114 / 517.071 / 340.575 | 2170.238 / 508.050 / 305.014 | 541.917 / 335.625 / 240.458 | 531.750 / 337.854 / 222.250 |
| 1027×513 mixed | 4369.183 / 1014.142 / 373.616 | 4360.996 / 1013.016 / 328.762 | 1071.417 / 681.625 / 365.792 | 1068.000 / 687.270 / 292.479 |
| 1920×1080 mixed | 17091.994 / 4062.066 / 1218.928 | 17251.363 / 3988.068 / 1155.179 | 4258.750 / 2745.417 / 1098.708 | 4211.583 / 2718.375 / 1156.167 |
| 1920×1080 opaque | 4777.423 / 2191.779 / 955.310 | 4774.757 / 2152.572 / 722.232 | 1279.083 / 1438.250 / 745.875 | 1218.729 / 1434.375 / 683.375 |
| 1920×1080 transparent | 6598.254 / 868.604 / 364.866 | 6056.995 / 489.300 / 165.559 | 3879.375 / 900.208 / 563.458 | 3919.062 / 911.416 / 553.980 |
| 3840×2160 mixed | 68299.986 / 15967.145 / 4485.597 | 68174.463 / 15778.318 / 4353.475 | 16817.125 / 11019.041 / 4277.208 | 16976.916 / 10872.812 / 4306.333 |

Default scheduling was faster than the original in all seven pairs for
every input on both platforms. The forced-serial opaque case on macOS
was slower than the original. All 147 timed processes per platform and
both guards exited zero, and each input's full-buffer hash matched
across modes and platforms.

The Linux probe saw one new worker at 512×512 and three at 1027×513,
in addition to the calling thread. It observed no workers at 511×513
or with forced serial scheduling. Linux focused tests passed in both
modes, including the WebP copy that shares the packed batch scheduler.
The guest compiler could not bootstrap the V memory guard, so the
Linux commands used the repository's Python memory guard. The macOS
production-allocator tests and ASan/UBSan checks passed.

The [archived site cohort](#parallel-premultiplication-of-canvas2d-destinations)
found no canvas elements on Hacker News, GitHub, or Old Reddit. The
measurements here cover the portable upload conversion. Full browser
validation of the new upload path and Windows execution remain unverified.

### Parallel channel swaps during Quartz bitmap handoff

An owned RGBA bitmap handed to a compatible BGRA destination now
swaps channels in place across disjoint row bands. The existing
NEON and scalar loops handle each band, with one lane below 4 MiB
of pixel data and at most four lanes overall.
`VOX_SERIAL_BITMAP_SWIZZLE=1` keeps the original serial schedule.
The source context is flushed before the swap. Workers finish before
the completed bitmap is handed to the image provider. Row padding,
green, alpha, format metadata and provider ownership are preserved.

Seven rotating fresh-process groups used a matching Apple Clang
`-O2 -flto` harness with the original and candidate implementations.
The timed span includes the destination format checks and the swap
through return. Buffer setup, pixel verification and Quartz image
creation are outside the span. Warm times are medians of per-process
medians after the first call. Every process verified its full buffer.
All 147 final processes and their memory guard exited zero.
The final one-minute load was 9.10 on 18 logical CPUs.

| Surface | First call before / serial / default, µs | Warm before / serial / default, µs | Default faster than before |
| --- | ---: | ---: | ---: |
| 67×43, padded | 0.750 / 0.750 / 0.750 | 0.250 / 0.250 / 0.250 | 3/7 |
| 512×512 | 20.000 / 19.333 / 20.250 | 18.229 / 18.021 / 18.042 | 5/7 |
| 1024×1024 | 144.041 / 146.250 / 119.042 | 73.438 / 73.166 / 52.646 | 5/7 |
| 2048×1536 | 290.000 / 285.875 / 152.625 | 209.292 / 206.125 / 102.605 | 7/7 |
| 2051×1537, padded | 248.917 / 344.583 / 169.416 | 224.792 / 225.125 / 99.395 | 7/7 |
| 3840×2160 | 572.208 / 571.292 / 273.500 | 555.812 / 554.625 / 235.688 | 7/7 |
| 5123×2881, padded | 1042.916 / 1046.542 / 540.417 | 1018.708 / 1029.875 / 383.084 | 7/7 |

An earlier candidate sent the serial path through the band callback.
It took 21.833 µs at 512×512 against 19.542 µs before. The final
version invokes the row loop directly for serial work. That earlier
trial's first-call before/default medians at 1024×1024, 2048×1536,
2051×1537, 3840×2160 and 5123×2881 were 80.375/73.375,
256.459/127.250, 238.500/150.625, 597.625/299.292 and
1163.667/504.833 µs. Its one-minute load was 7.69–8.20.

A separate dispatch probe observed two threads at 1024×1024 and four
at 2051×1537, with no dispatch below the threshold or when forced
serial. The bitmap suite passed 13,824 exact draw comparisons and
216 opacity cases, plus a new padded 3851×2161 provider-byte and
metadata check. It passed with default scheduling, forced serial
scheduling, and ASan/UBSan.

The published single-C-unit executable
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`
provided archive diagnostics. Fresh Hacker News, GitHub and Old
Reddit captures used sealed original-origin replay at 1024×768 CSS
pixels and 2×, private profiles and caches, and one second of settling.
They matched the frozen pixel references and preserved 30, 33 and
25 audited entries, with zero browser and guard exits. A probe of the
out-of-line destination-format check at return offset `0x1175548`
observed no matches on these captures. The same probe detected the
format conversion in a padded standalone control. Whole-page
measurements of the candidate await the shared production rebuild.

### Parallel capture of retained scroll tiles

On-demand capture of a retained scroll-tile frame now initializes the
output bitmap and overlays the tile slices across disjoint row bands.
The caller checks the existing frame fences and reads each provider.
Workers borrow those immutable bytes and join before the result is
published. The image provider takes ownership of the finished
allocation, removing the final full-bitmap copy. Wrapped slices, the
right and bottom overlay edges, and padding are preserved. Captures
below 4 MiB stay serial, and `VOX_SERIAL_SCROLL_TILE_CAPTURE=1` forces
serial execution on larger frames.

A single-C-unit Apple Clang `-O2 -flto -fobjc-arc` harness used the
same wrapped ring, base image and tile providers in each mode. Its
timed span starts at the flatten call and ends with image creation.
Fixture setup and full provider-byte verification are outside that
span. The three modes were the original implementation, the new
implementation forced serial, and the new implementation with its
default scheduler. Seven rotating fresh-process groups timed each
surface. All 105 processes and the memory guard exited zero and every
capture matched the independently assembled expected bytes.
The one-minute load was 10.36 on 18 logical CPUs.

| Frame | First call before / serial / default, µs | Warm before / serial / default, µs | Default faster than before | Default faster than new serial |
| --- | ---: | ---: | ---: | ---: |
| 1024×768, overlays | 501.958 / 268.125 / 281.375 | 280.687 / 111.562 / 107.375 | 7/7 | 3/7 |
| 2048×1536, overlays | 2127.542 / 1158.833 / 1046.709 | 1299.022 / 472.667 / 225.375 | 7/7 | 7/7 |
| 2048×1536, no overlays | 2111.958 / 1153.834 / 1115.042 | 1186.500 / 381.354 / 205.292 | 7/7 | 4/7 |
| 2051×1537, padded | 2167.459 / 1160.833 / 1014.708 | 1285.542 / 465.979 / 221.230 | 7/7 | 7/7 |
| 3840×2160, overlays | 6181.541 / 3749.792 / 2572.792 | 3828.709 / 1418.521 / 603.250 | 7/7 | 7/7 |

Warm numbers are medians of within-process medians after the first
capture. Median process peak RSS sampled immediately after the first
4K call was 173,817,856 bytes before and 140,623,872 bytes with the
candidate default, including the unchanged harness inputs. At
2048×1536 with overlays those figures were 70,975,488 and 58,376,192
bytes.

A separate probe verified two threads at 1024×1024 and four threads
at the padded size. It observed no dispatch at 1024×768 or with
forced serial scheduling. The ARC, non-ARC, ASan/UBSan, and forced
serial retained-tile tests passed, including the 2051×1539 fixture
with padded, wrapped slices and a retained image after frame release.

Published executable SHA-256
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`
provided the archive diagnostics. Six captures of sealed Hacker News,
GitHub and Old Reddit used fresh profiles and caches, 1024×768 CSS
pixels at 2× and one second of settling. Default and explicitly
enabled CPU tile settings both matched the frozen document pixels
and their 30, 33 and 25 audited entries. The flatten probe at return
offset `0x116c4ac` found zero calls on these document captures. A
standalone original-path control validated the probe with a
12,582,912-byte base image. The browser and guard exits were zero.

Active-window snapshots were a separate diagnostic with a 1024×740
document viewport. At a three-second observation delay Hacker News
published two tiled frames when enabled, with zero flatten calls.
Its full-window captures differed in 3,669 of 13,959,168 RGBA bytes.
The first GitHub observation was still interactive. At a 6.5-second
delay GitHub and Old Reddit both completed with zero tile publications
and zero flatten calls. The GitHub windows matched exactly and the
Old Reddit windows differed in 5,091 RGBA bytes. These observations
do not establish a complete-page performance gain. A candidate
production capture still requires the shared rebuild.

### Parallel copies of scroll damage and linear fallback rows

Damage-rectangle transfers and the linear scroll-cache fallback now use
the existing row-copy workers. Each job describes the source origin,
viewport rows and horizontal byte range. The caller marks dirty tiles
before dispatch. Workers write separate rows with the same packed or
padded stride as the original copy. The linear fallback still leaves
the newly exposed strip for painting. Copies below 4 MiB or spanning
fewer than 16 rows stay serial. The existing
`VOX_SERIAL_SCROLL_RASTER_COPY=1` override applies to these transfers.

The Apple Clang single-C-unit `-O2 -flto -fobjc-arc` harness compared
the original loops with the new implementation, both forced serial
and with default scheduling. It timed each copy through return, with
fixture setup and comparison outside the span. The full-row control
already used workers before the change. Each of 147 fresh processes
verified both complete buffers and the dirty-tile flags. Seven
rotating groups produced the medians below. Warm values are medians
of each process's post-first-call median. Browser and timing probes
ran separately from the timed harness.
One-minute load was 7.89–7.98 on 18 logical CPUs. All timed process and guard exits were zero.

| Transfer | First call before / serial / default, µs | Warm before / serial / default, µs | Default faster than before |
| --- | ---: | ---: | ---: |
| 1024×768 damage restore | 55.375 / 55.833 / 56.042 | 54.291 / 54.834 / 54.542 | 1/7 |
| 2048×1536 damage restore | 254.166 / 263.167 / 216.917 | 246.980 / 245.812 / 111.959 | 6/7 |
| 2051×1537 padded damage store | 302.667 / 335.541 / 236.667 | 269.604 / 276.458 / 116.999 | 7/7 |
| 3840×2160 padded damage restore | 1013.916 / 1009.167 / 515.083 | 909.438 / 871.583 / 297.166 | 7/7 |
| 2048×1536 linear restore | 185.125 / 189.500 / 180.375 | 180.792 / 182.978 / 112.062 | 6/7 |
| 3840×2160 padded linear restore | 1011.875 / 1023.292 / 507.333 | 876.375 / 827.812 / 297.188 | 7/7 |
| 2048×1536 full-row control | 187.250 / 190.625 / 181.958 | 113.103 / 183.625 / 106.062 | 5/7 |

The 1× case remained serial and its first-call median rose 0.667 µs.
A separate worker probe saw four distinct threads for the large
rectangular restore, padded store and shifted restore. It saw no
dispatch for the 1× case or with the serial override.
The row-union, scroll raster and retained-tile tests passed in their
normal and sanitizer configurations. Forced serial, forced parallel,
ARC and non-ARC checks also passed. Focused tests covered a large
wrapped, padded rectangle and a Retina fallback with a scroll
reversal.

The published single-C-unit executable
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`
still predates this change. Separate fresh document captures matched
the frozen Hacker News, GitHub and Old Reddit pixel references
with 30, 33 and 25 audited entries at 1024×768 CSS pixels and 2×.
Each used sealed replay, a private cold cache and profile, and a
one-second settle.

The baseline-only wheel diagnostics used sealed replay in fresh
processes, a 1024×768 CSS-pixel document viewport, JavaScript enabled,
and the CPU tile compositor explicitly enabled. The interposer
identified the original rectangle-loop return offsets
`0x117739c` and `0x11773e4`. Its standalone original-path control
counted all 698 expected row copies. During title-matched wheel
input it counted the following native row copies and publications.
These are observations of the instrumented published build.

| Archive | Completed inputs | Completed native publications | Tile publications | Restored rows / bytes during input | Stored rows / bytes during input |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hacker News | 24 | 25 | 27 | 810 / 6,056,592 | 0 / 0 |
| GitHub | 120 | 9 | 0 | 0 / 0 | 0 / 0 |
| Old Reddit | 24 | 14 | 0 | 0 / 0 | 0 / 0 |

Hacker News and Old Reddit used 24 nominal 60 Hz wheel events of
delta five, reversed after 12 events and with a two-second settle.
The first GitHub run completed all 24 inputs but produced only
three publications in total, too few inside the input window. The
driver and its enclosing guard returned one. A longer GitHub trial
used a three-second settle, 120 events and a reversal after 60.
The successful browsers and the longer GitHub driver and guard all
exited zero. These row totals do not establish an individual copy's
parallel eligibility or a page-level speedup. Candidate page
measurements await the shared production rebuild.

### Parallel BT.601 video conversion

The FFmpeg playback path converts limited-range I420 and YUVA420
frames in disjoint output-row ranges. It shares the CPU raster worker
dispatch, which starts at 262,144 pixels and uses up to four threads.
The conversion joins before publishing the frame. Small frames,
overlapping buffers and the `VOX_SERIAL_CPU_RASTER=1` override
preserve serial row order. Odd dimensions, signed source pitches,
straight alpha and destination padding retain their original bytes.

A single-C-unit V `-prod -prealloc -gc none` harness compared the
original scalar loop, the new code forced serial, and default
scheduling. Timers cover conversion through its return, with fixture
setup and RGBA hashing outside the span. Each of seven rotating
groups launched a fresh process per size and mode. All 105 process
exits and the guard exit were zero, and the complete padded RGBA
hashes matched. Warm values are medians of each process's median
after its first call. The benchmark executable SHA-256 was
`a63ba5757d10eb408684189672a620f69a83634ad572dfc93778787eddd347c2`.
One-minute host load ranged from 4.90 to 5.16 on 18 logical CPUs.

| Frame | First conversion before / forced serial / default, µs | Warm before / forced serial / default, µs | Default warm wins |
| --- | ---: | ---: | ---: |
| 320×240 opaque | 96.750 / 96.959 / 98.916 | 96.000 / 96.042 / 96.313 | 2/7 |
| 512×512 opaque | 333.708 / 326.750 / 208.125 | 330.271 / 324.208 / 179.938 | 7/7 |
| 1031×513 alpha, reversed Y rows | 677.500 / 686.209 / 338.333 | 677.355 / 685.709 / 260.250 | 7/7 |
| 1920×1080 opaque | 2726.166 / 2785.375 / 1127.500 | 2715.208 / 2747.229 / 830.605 | 7/7 |
| 3840×2160 opaque | 11063.250 / 11341.333 / 3402.167 | 10829.396 / 10932.500 / 3378.209 | 7/7 |

The small-frame warm median rose 0.313 µs. A separate dispatch probe
saw zero dispatches for 511×513 and forced serial, two distinct
threads at 512×512, and four distinct threads for the larger
probed frames. The actual native FFmpeg playback helper decoded a
1031×513 limited BT.601 VP9 alpha frame and called the exported V
bridge. It dispatched four distinct threads by default and zero
with the override. Both modes returned all 2,115,612 identical RGBA
bytes with SHA-256
`55e17f8d0e3755b2853aa0b86daa86118c410cd9a96aad91127c78e406e40db4`.
Both decode runs and the final diagnostic guard exited zero. An
ASan-instrumented decoder did not expose dispatch to the interposer.
The final worker diagnostic used a separate, unsanitized decoder.
The nine YUV test files, focused ASan/UBSan and forced-serial tests,
native bridge checks, and the focused arm64 Linux test passed.

Fresh captures with the published single-C-unit Vox executable
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`
matched the frozen Hacker News, GitHub and Old Reddit pixels. The
sealed replays used JavaScript, private cold profiles and caches,
a 1024×768 CSS-pixel document viewport, 2× capture and a one-second
settle. They audited 30, 33 and 25 entries respectively and zero
video elements on each page. Each browser and the guard exited zero.
The timings above cover CPU conversion of video frames. The shared
production build used for the archive checks predates this change.

### More PNG compression bands for Retina captures

The macOS opaque PNG encoder can dispatch up to eight independent
DEFLATE bands. It still assigns about 2 MiB per band, so a full
2048×1536 capture uses six on a machine with enough CPUs. The
previous four-band cap remains on hosts with four or fewer online
CPUs. The serial override and ImageIO fallback still apply.

The published single-C-unit Vox executable
`5d72f61417d4e5c75c4bd333550ce43baf8a65fcbd00bf89c1e1dafd8f641660`
supplied screenshots with four threads observed at callback offset
`0x11706c4`. Fresh sealed replays used JavaScript, private cold
profiles and caches, a 1024×768 CSS-pixel viewport, 2× capture and a
one-second settle. Captures audited 30 Hacker News stories, 33
GitHub directory rows and 25 Old Reddit posts. All three matched
the earlier [archived browser pixel references](#archived-browser-eligibility).
All browser exits and the replay guard exit were zero.

Matching single-unit Apple Clang `-O2 -flto -fobjc-arc` harnesses
timed the complete native PNG encoder through PNG bytes in memory.
Input setup, process launch, page rendering and disk writes were
outside that span. The old harness reproduced the published PNGs
byte for byte. Seven alternating fresh-process pairs ran per case.
Each process timed eight encodes. Warm times are medians of each
process's post-first-call median. All 56 process exits and the
cohort guard exit were zero. One-minute load was 4.88 on 18 logical
CPUs.

| Capture | First before → after, ms | Warm before → after, ms | Faster pairs, first / warm | PNG bytes before → after |
| --- | ---: | ---: | ---: | ---: |
| Hacker News | 4.428 → 3.416 | 4.082 → 2.972 | 7/7 / 7/7 | 462,136 → 462,479 |
| GitHub | 3.976 → 3.155 | 3.852 → 2.797 | 7/7 / 7/7 | 340,329 → 340,198 |
| Old Reddit | 4.629 → 3.582 | 4.531 → 3.310 | 7/7 / 7/7 | 544,821 → 545,118 |
| Hacker News, cropped to 2048×1024 | 3.047 → 2.913 | 2.647 → 2.660 | 5/7 / 2/7 | 299,207 → 299,207 |

The cropped control fit four bands in both builds and its PNGs
were identical. Its warm median rose by 0.012 ms. Every output
passed PNG chunk CRC and zlib stream validation, and the decoded
RGBA, ancillary metadata, density and profile matched. The two
harness executable hashes were
`20ddb5d632ef068763994fcc0ae28d1852c939becf0f671c490ec9388ea9b960`
and `61a6e69f3e7ab91a4a90e4d4cd3ea50337a9f2da4a3153356f7262f345b81f50`.
An earlier uncapped-by-CPU candidate measured warm medians of
4.110 → 2.945 ms, 3.841 → 2.745 ms and 4.366 → 3.179 ms on the
same three captures. Its four-band control measured
2.737 → 2.728 ms. It ran at one-minute load 3.97–4.37 with zero
process and guard exits.

A separate probe resolved the candidate callback at offset
`0x29ec` and observed six distinct threads for each full capture.
An emulated four-CPU host used four threads and reproduced the
old byte-identical PNG. The serial override dispatched zero bands.
Native ARC and non-ARC tests passed with normal and ASan/UBSan
builds. The padded and incompressible input checks covered the
eight-band cap. ThreadSanitizer reproduced the new Hacker News
PNG with zero reported races. The installed browser supplied the
capture input and baseline. Candidate production capture awaits
the shared rebuild.

### Parallel Quartz SVG mask conversion

Quartz SVG mask publication flushes the bitmap before converting it
in disjoint row ranges. Large alpha-only, RGBA alpha and RGBA
luminance masks use two to four of the existing CPU raster workers.
Conversion stays serial below 1,048,576 pixels, for partial source
and destination overlap, and with `VOX_SERIAL_CPU_RASTER=1`. Exact
in-place RGBA conversion remains eligible. The workers join before
Quartz receives the premultiplied-white mask, and padding is preserved.

Two matched single-unit Apple Clang `-O2 -flto` harnesses timed the
original and new conversion calls through return. Timing excludes
source generation, the in-place reset, output comparison and
Quartz image creation. Seven rotating groups used a fresh process
per mode and checked each complete output against a scalar
reference. All 168 process exits and the guard exit were zero.
Warm times are medians of each process's post-first-call median.
One-minute host load ranged from 7.11 to 7.34 on 18 logical CPUs.

| Mask | First before / forced serial / default, µs | Warm before / forced serial / default, µs | Default faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 67×43 luminance | 0.458 / 0.458 / 0.417 | 0.333 / 0.292 / 0.292 | 4/7 / 3/7 |
| 1023×1024 luminance | 116.625 / 109.000 / 120.583 | 106.771 / 106.479 / 111.167 | 2/7 / 1/7 |
| 1024×1024 luminance | 113.875 / 122.917 / 121.084 | 107.000 / 109.896 / 86.187 | 3/7 / 7/7 |
| 2051×1537 RGBA luminance | 365.166 / 376.000 / 269.333 | 324.000 / 328.563 / 130.750 | 5/7 / 7/7 |
| 2051×1537 RGBA alpha | 418.167 / 438.459 / 260.083 | 379.334 / 384.459 / 141.938 | 7/7 / 7/7 |
| 2051×1537 alpha-only | 326.833 / 321.333 / 248.583 | 305.688 / 316.375 / 124.646 | 7/7 / 7/7 |
| 2051×1537 in-place luminance | 329.375 / 333.375 / 222.792 | 329.917 / 327.833 / 124.230 | 6/7 / 7/7 |
| 2051×1537 in-place alpha | 1300.500 / 245.208 / 192.125 | 1290.708 / 246.687 / 94.771 | 7/7 / 7/7 |

The large in-place alpha case also benefited from the compiler's
code generation for the reorganized serial loop. A lower threshold
was considered in a full earlier cohort. The 1024×512 first call
rose from 64.708 to 82.291 µs and lost all seven pairs, while its
warm median fell from 62.104 to 41.917 µs. The final threshold
keeps that size serial. The final harnesses had SHA-256
`6ca3c6bc11c7ac902e1950baeacee99846d1aa266c7d072d8b2e3e3df96a4c28` and
`85fa3d61c4752f9063320d61337df523559a68db7f890ff55513343bdf113ee2`.

The worker probe observed zero dispatch below the final threshold
and with the serial override, two distinct threads at the threshold,
and four on the large masks. The native Objective-C capture adapter
also compiled in an ARC harness and published three 1902×1284 masks
through its ordinary PNG-independent image provider path. Both copy
modes and in-place conversion each used four distinct threads and
matched their forced-serial images. The combined visible RGBA
SHA-256 was
`da3caca70233117a20b1337aea3f1ff84c0da54c2015b69754b4fcc5a54170eb`.
Focused macOS, arm64 Linux, ASan/UBSan, ThreadSanitizer and 16 native
mask layer scenes passed. The focused tests include all 16,777,216
RGB triples, exact overlap order, padding and uneven row ranges.

The published single-C-unit browser
`4ac49eb9690c121587fd4efd8f859f2cf0e2762013861238f07bb91a05547540`
predates this change. A separate probe identified the two original
conversion entries at offsets `0x2ed34` and `0x2f1fc`. A synthetic
large SVG reached the conversion in both native mask modes. Sealed
Hacker News, GitHub and Old Reddit replays audited 30, 33 and 25
entries and matched the frozen pixel references. Each used private
profiles and caches, JavaScript, a 1024×768 CSS-pixel viewport, 2×
capture and one second of settling. The probe observed no conversion
calls on the three archived pages. Browser and guard exits were
zero. Candidate validation inside the browser awaits its production
rebuild.

### Parallel CPU shadow tinting

The fallback filter pipeline's constant SrcIn tint now computes the
RGBA result once per possible input alpha. Starting at 1024 pixels,
it applies the lookup table directly to the existing buffer. The
existing CPU raster scheduler distributes complete pixel ranges at
262,144 pixels and can use up to four threads. Smaller masks retain
scalar tint calculation below 1024 pixels and serial lookup below
the dispatch cutoff. Both kernels keep the original coverage and
rounding. An incomplete final pixel remains untouched.

Matched V single-unit C `-prod -prealloc -gc none` harnesses timed the
tint call through return. The source reset and output hashing were
outside the timer. Each of seven rotating groups ran a fresh process
per mode. All 147 processes and the memory guard exited zero.
Within each case the complete output SHA-256 matched across modes
and groups. Warm values are medians of each process's post-first-call
median. One-minute load was 5.08–5.17 on 18 logical CPUs.

| Layer | First before / forced serial / default, µs | Warm before / forced serial / default, µs |
| --- | ---: | ---: |
| 24×17, explicit coverage | 0.833 / 0.458 / 0.459 | 0.709 / 0.250 / 0.250 |
| 64×64 | 7.542 / 2.250 / 2.291 | 7.167 / 1.875 / 1.875 |
| 511×513 | 477.959 / 97.417 / 95.208 | 476.938 / 96.938 / 95.792 |
| 512×512 | 478.084 / 95.000 / 85.083 | 477.000 / 93.771 / 64.730 |
| 1031×513, explicit coverage | 934.666 / 203.625 / 139.000 | 941.250 / 196.708 / 90.917 |
| 1920×1080 | 3834.000 / 825.958 / 401.708 | 3732.167 / 772.938 / 276.605 |
| 3840×2160, explicit coverage | 14960.750 / 3086.500 / 1186.500 | 15344.167 / 3128.626 / 1090.375 |

The default candidate won all seven first-call and warm pairs per
case. The final harness executable hashes were
`5d83281daab1b00979dff8112ae0877d3c855431a7e777e336398b35db7f1653`
and `375fe950d188303f5375e93e1c0d27e838d9e7dd1e50a56e9a360a2aa79a2c51`.
An earlier candidate built the table only at the dispatch threshold.
Its new scalar loop was slower at 64×64 (7.125 → 9.583 µs warm)
and 511×513 (457.021 → 613.750 µs warm). Both sizes improved in the
final cohort.

The separate probe resolved the tint callback and saw zero batches
below 262,144 pixels and under `VOX_SERIAL_CPU_RASTER=1`, two threads
at the cutoff and four above it. The public Canvas2D fallback drew
a 1441×927 drop-shadow scene with four threads in the tint batch.
Its complete surface SHA-256 matched the forced-serial draw
(`f22810741a34dac44f60279ce3cfefe5fa02d7607ad8e160dc83324dd886770e`).
All probe processes and the guard exited zero. Focused macOS and
arm64 Linux tests, forced serial, ASan/UBSan and ThreadSanitizer
passed. The pinned CPU raster differential suite passed at count
2000 and seed 20261106.

Sealed Hacker News, GitHub and Old Reddit replays matched their
frozen document pixels on the published single-C-unit browser
`870e280a166afa2249e1f90dcd8fb7cee701e0614f25414dd12004c9f4472077`.
They audited 30, 33 and 25 entries and zero Canvas elements, with
fresh private profiles and caches, JavaScript, a 1024×768 CSS-pixel
viewport, 2× capture, and a one-second settle. All three browser
exits and the replay guard exit were zero. The timing above covers
the isolated tint, and browser validation of the tint awaits the
shared rebuild. The published captures also verified the earlier
[PNG scheduling change](#more-png-compression-bands-for-retina-captures).
Each had six valid IDAT chunks and matched the corresponding
six-band encoder benchmark PNG byte for byte.

### Parallel CPU filter crop and integer offset copies

The SVG filter fallback resolves the visible pixel rectangle once.
It uses the existing float pixel-center expression to preserve
fractional edges and rounding at large device origins. Crops copy
the retained rectangle into a transparent result. Integer filter
offsets and placement of blur results use the same pitched copy.
The scheduler borrows disjoint output rows when the actual copy
covers at least 4 MiB. Whole rows combine into a contiguous transfer.
`VOX_SERIAL_CPU_RASTER=1` keeps the copy on the caller.

Matched single-unit V C `-prod -gc none` harnesses timed each
operation from entry through its return, including output allocation.
Source construction, output hashing and release were outside the
timer. Seven rotating groups used fresh processes per mode. All 189
exits and the guard exit were zero. Complete output hashes matched
for all modes in each case. Warm values are medians of each process's
post-first-call median. One-minute load ranged from 6.10 to 6.42 on
18 logical CPUs.

| Operation | First before / forced serial / default, µs | Warm before / forced serial / default, µs | Default faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 67×43 inset crop | 4.083 / 1.416 / 1.417 | 2.625 / 0.167 / 0.167 | 7/7 / 7/7 |
| 67×43 integer offset | 1.666 / 1.417 / 1.292 | 0.333 / 0.208 / 0.208 | 7/7 / 7/7 |
| 1024×768 inset crop | 517.250 / 237.833 / 234.917 | 374.521 / 76.146 / 76.188 | 7/7 / 7/7 |
| 2051×1537 inset crop | 2255.791 / 1003.709 / 626.208 | 1422.917 / 363.855 / 182.708 | 7/7 / 7/7 |
| 2051×1537 narrow crop | 3559.292 / 766.500 / 767.834 | 2886.500 / 104.417 / 108.854 | 7/7 / 7/7 |
| 2051×1537 empty crop | 3849.083 / 4.667 / 5.042 | 3048.313 / 49.521 / 50.563 | 7/7 / 7/7 |
| 3840×2160 full crop | 5497.417 / 2251.750 / 2269.292 | 3653.187 / 652.417 / 455.646 | 7/7 / 7/7 |
| 1920×1080 integer offset | 606.458 / 610.459 / 617.958 | 214.313 / 203.688 / 118.542 | 5/7 / 7/7 |
| 3840×2160 integer offset | 2478.541 / 2407.208 / 2325.166 | 869.813 / 913.834 / 459.208 | 5/7 / 7/7 |

Integer offsets were −7 pixels horizontally and +13 vertically.
The 1080p offset's first-call median rose by 11.500 µs. The narrow
crop's warm improvement came from avoiding the full pixel scan.
The harness executable hashes were
`01654b088d88e8f1dc37d13d3ead52c02a665b3048b4b0a90ec63f1df0e832bc`
and `61e1eb151abcc9e73c87f12975f051bb945ff19d98e2a2334721399f2aaabf23`.

A separate probe saw four distinct threads on a large inset crop,
a full crop and a large offset. A 1024×768 inset crop, the large
narrow crop and forced serial dispatched zero batches. The
2051×1537 public Canvas2D fallback applied an integral SVG offset
and crop in two four-thread copy batches. Its entire surface
matched the forced-serial draw byte for byte with SHA-256
`5a755be8b85e9bd964beea785f65d7fb6f8847c2ef9adaa92cd4c9e8fa12edda`.
Both final draw processes and their guard exited zero. Focused
macOS, arm64 Linux, forced serial, ASan/UBSan and ThreadSanitizer
tests passed. The pinned CPU raster differential suite passed with
count 2000 and seed 20261106.

The published single-C-unit executable
`870e280a166afa2249e1f90dcd8fb7cee701e0614f25414dd12004c9f4472077`
matched the frozen document pixels for Hacker News, GitHub and
Old Reddit. Fresh sealed replays used private profiles and caches,
JavaScript, a 1024×768 CSS-pixel viewport, 2× capture and a one-second
settle. They audited 30, 33 and 25 entries and zero Canvas or SVG
filter elements. The browser and guard exits were zero. Timings
cover the filter operations in isolation. Candidate browser
validation awaits its shared rebuild.

### Parallel CPU filter image subset copies

Packed blur subsets and nearly integer Canvas image resolves now use
the filter row-copy scheduler. It considers only the visible bytes
when applying the 4 MiB cutoff. Packed outputs keep independent
storage, and padded Canvas sources keep their original straight-alpha
or premultiplied bytes. Workers write disjoint output rows and join
before the filter borrows the packed result.

Matched single-unit V C `-prod -gc none` harnesses measured each
subset operation through return, including allocation. Source setup,
hashing and release were outside the timer. Each of seven rotating
groups ran a fresh process per mode. All 147 processes and the guard
exited zero. Compacted output hashes matched across all modes and
groups. Warm medians use each process's post-first-call median.
One-minute host load was 9.17–9.18 on 18 logical CPUs.

| Copied rectangle | First before / forced serial / default, µs | Warm before / forced serial / default, µs | Default faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 67×43 packed inset | 1.708 / 1.583 / 1.834 | 0.417 / 0.250 / 0.250 | 2/7 / 7/7 |
| 67×43 padded source | 2.000 / 1.708 / 1.917 | 0.417 / 0.250 / 0.250 | 2/7 / 7/7 |
| 1024×768 packed inset | 253.458 / 246.125 / 272.625 | 90.104 / 85.000 / 87.542 | 3/7 / 5/7 |
| 2051×1537 packed inset | 1200.042 / 1042.167 / 996.792 | 368.771 / 369.896 / 187.605 | 5/7 / 7/7 |
| 2051×1537 padded source | 1125.166 / 1009.875 / 984.125 | 364.688 / 374.188 / 190.375 | 7/7 / 7/7 |
| 3840×2160 full packed image | 2988.834 / 3068.250 / 2403.916 | 909.209 / 666.834 / 419.125 | 7/7 / 7/7 |
| 3840×2160 padded source | 2806.125 / 2734.250 / 2327.417 | 962.500 / 1027.834 / 513.334 | 7/7 / 7/7 |

The 1024×768 first-call median rose 19.167 µs. Padded cases used
29 padding bytes per source row. Harness SHA-256 values were
`298a5fe19c553b84dcd0e030ab464bb5cf9ec43270539232eaafa786e5f8ba02`
and `8251202df3df4052ed17a7bfdbaa3fb718ae53b5600bb620f8652c73e1928756`.
The worker probe saw four distinct threads for large packed and
padded subsets and zero dispatch below 4 MiB or under forced serial.
The public blur call with a 2051×1537 source dispatched two four-thread
copies and matched the serial result
(`369724e5553efb81cc8e2cc195bded46e8fa9671b274c21f3636df5fd8419f7d`).
Probe processes and the guard exited zero. Focused macOS, arm64 Linux,
forced serial, ASan/UBSan and ThreadSanitizer tests passed. The
pinned CPU raster differential suite passed with count 2000 and
seed 20261106.

The published single-C-unit executable
`896b2d35d455afdbb5ec57c6dd5d5759a42e1a15d5f71961ae39fc0d146365cb`
matched the frozen Hacker News, GitHub and Old Reddit pixels.
Fresh sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS-pixel viewport, 2× capture and a one-second settle.
They audited 30, 33 and 25 entries and zero Canvas or SVG filter
elements. Browser and guard exits were zero. The measurements above
cover isolated subset operations. Candidate browser validation
awaits the shared rebuild.

The same published executable also validated the earlier
[Quartz SVG mask conversion](#parallel-quartz-svg-mask-conversion).
The large luminance fixture
`76b0f2b69a872ef93ce60088bf1cbd23f3cf5ed47478ce5213213fe90db90832`
used four distinct threads in its 1284-row copy and zero under
the serial override. Both fresh browsers and the replay guard
exited zero. The captured RGBA matched between settings
(`2c2688c954e2901c44e62b32b5acc956bed15da23c129cf16c288172c0b169c9`).

### Parallel direct Gaussian mask blur

For sigma below 2, each output row now completes the vertical pass
into a private temporary row and immediately applies the horizontal
pass. This removes the full vertical write and read of the output
bitmap. The original fixed-point products, rounding and transparent
edges apply to both passes. Workers borrow a validated source slice,
including its pitch and offset, and write disjoint destination rows.
The existing scheduler uses up to four threads starting at 262,144
source-width times destination-height samples. Sources wider than
8191 pixels use dynamically sized scratch and stay serial.

Matched V single-unit C `-prod -gc none` harnesses timed from the blur
call through its return, including destination and scratch setup.
The source had a nonzero origin, an eleven-byte base offset and
thirteen bytes of row padding. Source setup, hashing and release
were outside the timer. Seven rotating groups launched fresh
processes per mode. All 147 process exits and the guard exit were
zero. The complete mask SHA-256 matched across groups and modes.
Warm values are medians of each process's median after its first
call. One-minute host load was 6.84–7.02 on 18 logical CPUs.

| Padded mask and sigma | First before / forced serial / default, µs | Warm before / forced serial / default, µs |
| --- | ---: | ---: |
| 23×19, 1.5 | 9.292 / 8.000 / 8.000 | 7.167 / 5.875 / 5.958 |
| 481×480, 1.5 | 2616.459 / 1946.500 / 2021.333 | 2500.313 / 2006.063 / 1940.272 |
| 512×512, 1.5 | 2867.417 / 2248.750 / 1631.958 | 2989.458 / 2310.896 / 1283.771 |
| 1031×517, 1.5 | 6030.167 / 4486.583 / 1855.917 | 5931.938 / 4619.063 / 1663.396 |
| 1920×1080, 0.45 | 13061.375 / 8646.625 / 3124.666 | 12848.479 / 8918.917 / 3064.729 |
| 2051×1537, 1.9 | 47090.083 / 33906.333 / 11997.875 | 45727.313 / 34514.167 / 11582.229 |
| 8205×45, 1.5 | 4603.584 / 3517.583 / 3465.334 | 4467.146 / 3507.021 / 3455.250 |

The default candidate won every matching first and warm pair in
the final cohort. Harness SHA-256 values were
`82af195be34ae9fbd1725b49c086616645eef3d5405187ad1192615bdee36c29`
and `ec4543d40af5cbd58bec528fb7e5ab84ca200522de3cc0fee032dde0e27cbd33`.
An earlier candidate before the checked source slice measured
46.908 → 12.253 ms warm for the 2051×1537 case. It also matched
all pixels, with load 5.70–5.99 and zero process and guard exits.

Generated C kept the 8191-byte worker scratch on the stack. A probe
saw two distinct threads for 512×512 and four at 1031×517, with no
dispatch below the size cutoff, above the scratch width or under
the serial override. A 1441×927 Canvas path draw used four distinct
threads in its Gaussian mask batch and matched the forced-serial
surface (`c9ccb9e79eea8c7d1e6e71cdffe0cb9a3445102d7478629c62a399ac90a1ff8e`).
Probe processes and the guard exited zero. Focused macOS and arm64
Linux tests, forced serial, ASan/UBSan and ThreadSanitizer passed.
The pinned raster differential suite passed with count 2000 and
seed 20261106.

The published single-C-unit executable
`896b2d35d455afdbb5ec57c6dd5d5759a42e1a15d5f71961ae39fc0d146365cb`
matched the archived pixels on Hacker News, GitHub and Old Reddit.
Fresh sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS-pixel viewport, 2× capture and a one-second settle.
They audited 30, 33 and 25 entries and zero Canvas elements.
Browser and replay guard exits were zero. Timings cover the isolated
blur operation. Candidate browser validation awaits the shared rebuild.

### Parallel analytic rectangular shadow masks

The portable rectangular blur still derives its horizontal and
vertical profiles on the caller. It now multiplies the profiles
over disjoint mask rows with the existing CPU raster scheduler.
The original integer rounding, mask bounds and nine-patch
placement are preserved. Dispatch starts at 262,144 mask pixels
and uses up to four threads.

Matched V single-unit C `-prod -gc none` harnesses measured
`filter_rects_to_nine` through return, including profile creation
and mask allocation. Output hashing and release were outside the
timer. Seven rotating groups ran fresh processes per mode. All
147 process exits and the guard exit were zero. The complete A8
hash and dimensions matched across all groups and modes. Warm
values are medians of the per-process median after the first call.
One-minute host load was 5.19–5.34 on 18 logical CPUs.

| Sigma / working mask | First before / forced serial / default, µs | Warm before / forced serial / default, µs | Default faster pairs, first / warm |
| --- | ---: | ---: | ---: |
| 1.5 / 17×17 | 1.667 / 1.542 / 1.666 | 0.292 / 0.209 / 0.209 | 2/7 / 7/7 |
| 6 / 73×73 | 4.334 / 3.167 / 3.125 | 3.250 / 2.230 / 2.250 | 7/7 / 7/7 |
| 25 / 301×301 | 55.792 / 38.708 / 40.125 | 50.062 / 32.063 / 32.583 | 7/7 / 7/7 |
| 70 / 841×841 | 412.750 / 290.125 / 113.666 | 366.583 / 237.083 / 77.146 | 7/7 / 7/7 |
| 92 / 1105×1105 | 690.125 / 471.583 / 167.375 | 627.250 / 409.687 / 122.916 | 7/7 / 7/7 |
| 112 / 1345×1345 | 1026.125 / 715.959 / 232.916 | 923.084 / 603.959 / 175.208 | 7/7 / 7/7 |
| 128 / 1537×1537 | 1333.291 / 908.792 / 286.375 | 1203.417 / 788.896 / 228.083 | 7/7 / 7/7 |

The sigma 1.5 and 6 source rects were 128×92, sigma 25 used
512×384, and the larger cases used 1930×1345. All were positioned
at (31.25, 17.75). The harness SHA-256 values were
`76241d326d63784995584e0fd6bd498061d303aa5e8210bbbb76ef637d05f264`
and `fe43277d92747c902557a0f8b8dddbf13c5273b25a921bd48ac62e3e79e5e36d`.

A separate worker probe saw no dispatch for 505×505 or with
`VOX_SERIAL_CPU_RASTER=1`, two distinct threads for 517×517,
and four for 1537×1537. A 2173×1553 Canvas path draw through
the normal rectangular-shadow route used four distinct mask
threads and matched its forced-serial RGBA surface
(`3198e11e5f8ca4b1bf1b968851deda060dbdec04b15ae941c0ca09666d5ff23e`).
All probe processes and the guard exited zero. Focused macOS,
arm64 Linux, forced-serial, ASan/UBSan and ThreadSanitizer
checks passed. The pinned CPU raster differential suite passed
with count 2000 and seed 20261106.

The published single-C-unit browser
`604f51df0b16e909d556320a196324d6fb5af2f4b425127326d6c9899a6c46b4`
matched the frozen Hacker News, GitHub and Old Reddit pixels.
Fresh sealed replays used JavaScript, private caches and profiles,
a 1024×768 CSS-pixel viewport, 2× capture and a one-second settle.
They audited 30, 33 and 25 entries and zero Canvas elements.
Browser and replay guard exits were zero. Timings cover analytic
mask generation. Candidate browser validation awaits the shared
rebuild.

### Parallel solid-color mask compositing

The premultiplied RGBA solid blitter validates the clipped source
and destination spans once. Independent rows then share the
existing raster scheduler, with up to four threads at 262,144
pixels and above. A zero mask pitch identifies an immutable
repeated row. Overlapping storage, overlapping output rows
and other layouts outside this path use the original checked
serial loop. Black, opaque and translucent colors retain their
existing integer blend formulas.

Matched V single-unit C `-prod -gc none` harnesses measured the
`blit_mask` call through return. Destination reset and output
hashing were outside the timer. The case buffers had padded
destination rows and clipped origins. Ordinary masks used an
eleven-byte row pad and a seven-byte base offset. A repeated
mask used one row. All 189 processes across seven rotating
fresh-process groups and the guard exited zero. Complete
destination hashes matched in every group and mode. Warm values
are medians of per-process medians after the first call.
One-minute load was 9.43–10.07 on 18 logical CPUs.

| Mask | First before / forced serial / default, µs | Warm before / forced serial / default, µs |
| --- | ---: | ---: |
| 9×9 translucent | 0.417 / 0.417 / 0.583 | 0.209 / 0.125 / 0.125 |
| 67×43 translucent | 7.167 / 4.792 / 4.666 | 6.917 / 4.375 / 4.375 |
| 511×513 translucent | 610.125 / 392.416 / 391.667 | 610.438 / 386.896 / 394.063 |
| 512×512 translucent | 612.458 / 387.625 / 232.334 | 661.375 / 392.021 / 212.521 |
| 1031×517 translucent | 1215.834 / 774.750 / 409.750 | 1220.208 / 775.875 / 301.125 |
| 2051×1537 black | 6958.542 / 3310.667 / 1312.000 | 6808.771 / 3428.916 / 1142.292 |
| 2051×1537 opaque | 8080.042 / 5047.459 / 1780.834 | 7532.292 / 4822.250 / 1668.750 |
| 2051×1537 repeated translucent row | 7868.584 / 4863.208 / 1752.375 | 7632.958 / 4824.084 / 1691.833 |
| 3840×2160 translucent | 20742.916 / 13423.000 / 4518.625 | 20094.271 / 13064.084 / 4499.667 |

The 9×9 first-call median rose by 0.166 µs. All other sizes won all
seven pairs on both metrics. The harness SHA-256 values were
`d09c476224fe2bd088dfc2fbf91605c0f9363e31e5c91ec10448a68a36493a15`
and `0cec83a4b596886147266ad3a5ed2c7bec72ebff1897d9407bb3a7785a2f5d02`.
An earlier candidate selected the validated loop only for
parallel-sized masks. Its 67×43 warm result rose from 7.500
to 7.958 µs. The final version applies the validated loop to
small disjoint masks too.

A separate probe observed two distinct threads at 512×512,
four on larger packed and repeated masks, and zero below the
cutoff or under `VOX_SERIAL_CPU_RASTER=1`. A normal 1441×927
Canvas path shadow used four distinct threads in the mask
compositor. Its complete RGBA surface matched forced serial
(`c9ccb9e79eea8c7d1e6e71cdffe0cb9a3445102d7478629c62a399ac90a1ff8e`).
Focused tests covered clipped origins, padding, repeated rows
and genuinely overlapping storage. macOS, arm64 Linux, forced
serial, ASan/UBSan and ThreadSanitizer checks passed. The pinned
raster differential suite passed with count 2000 and seed
20261106. Probe and guard exits were zero.

The published single-C-unit executable
`604f51df0b16e909d556320a196324d6fb5af2f4b425127326d6c9899a6c46b4`
matched the frozen Hacker News, GitHub and Old Reddit pixels.
Fresh sealed replays used private profiles and caches, JavaScript,
a 1024×768 CSS-pixel viewport, 2× capture and one second of settling.
The audits recorded 30, 33 and 25 entries respectively and zero
Canvas elements. All browser and guard exits were zero. The timings
above cover mask compositing in isolation. Candidate browser
validation awaits the shared rebuild.

### Parallel pipeline mask compositing

The A8 pipeline blitter sends independent rows of large constant
and gradient masks to up to four raster threads. They share read-only
paint inputs and preserve absolute shader coordinates. The solid and
pipeline blitters share the clipped span and overlap check. Image
shaders and masks whose writes could change later reads use ordered
composition. Masks smaller than 262,144 pixels use the pipeline's
existing serial loop.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured blit_mask through return. The pitched and clipped fixtures
used padded target rows, an eleven-byte source row pad and a
seven-byte mask offset. Buffer reset and SHA-256 ran outside the
timer. Seven rotating groups ran on Mac17,6 with 18 logical CPUs
on 2026-11-18 at 08:34 local time. One-minute load varied from
12.14 to 12.56. All 21 fresh processes and the guard exited zero.
Times below are medians in microseconds. Warm results use the
median of each process's eight calls after its first.

| Mask and blend | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 67×43 solid multiply | 28.125 / 29.500 / 24.875 | 25.625 / 28.542 / 24.084 |
| 67×43 gradient soft-light | 79.791 / 78.416 / 73.000 | 74.604 / 72.333 / 63.459 |
| 511×513 solid multiply | 2611.250 / 2560.041 / 2275.083 | 2351.729 / 2503.625 / 2135.833 |
| 511×513 gradient soft-light | 6659.083 / 6755.791 / 5853.625 | 6383.688 / 6708.688 / 5867.395 |
| 512×512 solid multiply | 2300.708 / 2560.166 / 1453.667 | 2396.521 / 2321.416 / 1348.917 |
| 512×512 gradient soft-light | 6451.875 / 6496.916 / 3315.041 | 6390.771 / 6242.105 / 3271.812 |
| 1031×517 solid multiply | 4939.583 / 5190.958 / 1531.750 | 4831.354 / 5037.771 / 1413.521 |
| 1031×517 gradient soft-light | 12952.250 / 12993.625 / 3472.375 | 12880.417 / 12699.041 / 3387.771 |
| 2051×1537 solid multiply | 27817.458 / 30177.042 / 8318.500 | 26254.312 / 28671.312 / 8236.833 |
| 2051×1537 gradient soft-light | 70390.875 / 74224.833 / 19958.417 | 69886.479 / 73261.625 / 20356.854 |

Every complete destination hash matched. Default execution won all
first and warm pairs for parallel-sized masks. Below the cutoff,
both modes used ordered composition and individual pairs varied.
The largest forced-serial warm medians increased by 9.2% for
multiply and 4.8% for soft-light. Harness hashes were
`d80da5933c3fc52391499a544abfbd918e424c316f7c27f517e1fa791f72f40e`
before and
`095244f6d8379593c2f3daabf71917772d5496cb643c20a86a10ca1fc15adb02`
after.

A separate dispatch probe observed two distinct threads at 512×512,
four at larger sizes, and zero below the cutoff or with workers
disabled. A 1441×927 Canvas multiply path shadow reached the
pipeline compositor with 848 rows and four threads. Full surface
pixels matched forced serial
(`986dd190507d2d3359861a2f922bab0210495be66cef99f296e0854c5b8a0039`).
All four probe processes and the guard exited zero. Focused checks
covered clipped and repeated coverage, low and high precision
blending and genuine backing overlap. macOS, arm64 Linux,
forced-serial, ASan/UBSan and ThreadSanitizer checks passed. The
pinned CPU raster differential suite passed with count 2000 and
seed 20261106.

The published single-C-unit browser
`604f51df0b16e909d556320a196324d6fb5af2f4b425127326d6c9899a6c46b4`
with native library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched frozen Hacker News, GitHub and Old Reddit pixel references.
Fresh sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS-pixel viewport, 2× captures and a one-second settle.
The audits found 30, 33 and 25 entries respectively and zero Canvas
elements. An initial setup attempt exited 1 before launching any
browser. All three browser exits and the completed replay guard
exit were zero. Timings above cover the mask compositor. Candidate
browser measurements await the shared production rebuild.

### Parallel Canvas sprite blits

Large integer-translated Canvas image rectangles on the native N32
sprite path use independent rows. Blends dispatch at 262,144 pixels
and retain the distinct rounding of the unpaired first pixel in
odd-width rows. Copies use the shared bulk-copy kernel and dispatch
at 4 MiB. Disjoint draws skip temporary row allocation. A draw with overlapping input and output retains its
original row order and blending snapshot.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured the clipped SpriteBlitter rectangle through return. Each
input had padded source and target rows. The source contained
transparent, opaque and intermediate premultiplied pixels. Destination
reset and SHA-256 ran outside the timer. Seven rotating groups ran
on Mac17,6 with 18 logical CPUs on 2026-11-18 at 08:42 local time.
One-minute load varied from 8.04 to 8.59. All 21 fresh processes and
the guard exited zero. Warm results use the median of the six calls
after the first in each process. Times are medians in microseconds.

| Size and operation | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 67×43 copy | 9.250 / 0.375 / 0.542 | 8.646 / 0.208 / 0.167 |
| 67×43 source-over (alpha 255) | 11.833 / 11.209 / 9.500 | 9.209 / 9.875 / 8.312 |
| 67×43 source-over (alpha 141) | 10.875 / 10.667 / 9.084 | 8.917 / 10.250 / 8.500 |
| 511×513 copy | 709.750 / 24.792 / 24.209 | 621.167 / 24.541 / 23.917 |
| 511×513 source-over (alpha 255) | 974.959 / 947.958 / 781.167 | 927.605 / 977.833 / 827.229 |
| 511×513 source-over (alpha 141) | 736.875 / 935.583 / 765.167 | 934.896 / 990.708 / 799.208 |
| 512×512 copy | 572.583 / 23.833 / 24.166 | 566.083 / 23.584 / 24.584 |
| 512×512 source-over (alpha 255) | 857.125 / 641.917 / 441.041 | 795.688 / 610.458 / 372.542 |
| 512×512 source-over (alpha 141) | 729.667 / 517.375 / 287.750 | 705.854 / 442.104 / 306.416 |
| 1031×517 copy | 1372.750 / 58.167 / 49.917 | 1139.125 / 48.999 / 47.250 |
| 1031×517 source-over (alpha 255) | 1829.292 / 1127.042 / 570.333 | 1820.833 / 1096.729 / 394.604 |
| 1031×517 source-over (alpha 141) | 1564.916 / 1167.250 / 422.083 | 1535.958 / 913.521 / 329.375 |
| 2051×1537 copy | 7324.375 / 414.042 / 193.459 | 8147.895 / 354.334 / 145.938 |
| 2051×1537 source-over (alpha 255) | 9584.541 / 7269.416 / 2181.542 | 10679.354 / 6744.458 / 2116.312 |
| 2051×1537 source-over (alpha 141) | 10275.250 / 5244.500 / 1791.834 | 9056.729 / 5918.374 / 1776.001 |
| 3840×2160 copy | 21041.000 / 1258.000 / 491.458 | 20430.541 / 1104.146 / 421.104 |
| 3840×2160 source-over (alpha 255) | 29685.583 / 18165.625 / 5753.333 | 29168.729 / 18799.541 / 5405.000 |
| 3840×2160 source-over (alpha 141) | 27732.958 / 14556.917 / 4723.542 | 25978.916 / 14695.938 / 4556.583 |

All complete destination hashes matched. Default execution won all
seven first and warm pairs for cases that dispatched workers. The
511×513 alpha-141 blend used the original ordered path and its
first-call median rose from 736.875 to 765.167 µs, while paired
warm results varied. The 4K copy took 1.10 ms with the new bulk loop
forced serial and 0.42 ms with workers. Harness hashes were
`a6bf00097e3586ab7427c560f45a5939b0a0b95abfe04f24712f79705810800c`
before and
`b22454d3aec85029418d5fd7cbc559d9baa97a174f1955ee8e714b8b43890ef7`
after.

A separate dispatch probe observed two distinct threads for 512×512
blends, four for larger parallel batches, and zero below each cutoff
or with workers disabled. Public macOS Canvas image draws used four
threads for a 2051×1537 copy and a blend. Their full surfaces matched
forced serial with hashes
`294f3fe95d765597daf302c34ded190788f09e7369cf0b55b32f752b4b3aa4b0`
and `7ef455c31b68d5738a485b6923a57366a77395f5528ac2787d0ed7ec62eebf95`.
The first probe setup used a target stride the public Canvas API
declined. Both valid public draws and the probe guard exited zero.
Focused macOS and arm64 Linux checks covered odd and even clipped
rows, padding and shared source and destination storage. Forced
serial, ASan/UBSan and ThreadSanitizer passed. The pinned CPU raster
differential suite passed with count 2000 and seed 20261106.

The published single-C-unit executable
`19554c666e7ef07de44937357e3a2f37df63bc26d8347bd4830a133c38be1766`
and native library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched frozen Hacker News, GitHub and Old Reddit pixel references.
Fresh sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS-pixel viewport, 2× captures and a one-second settle.
The audits found 30, 33 and 25 entries and zero Canvas elements.
All three browsers and the replay guard exited zero. This published
build predates the sprite change. Timings above cover the sprite
blitter, and candidate site timings await a production build.

### Parallel shaded rectangle blits

Large pipeline rectangles use the existing raster scheduler for
disjoint destination rows. Image draws also check the backing of
both sampled mipmap levels. An overlap keeps the original ordered
draw, as do small rectangles and constant-color stores. The workers
share the blitter header and paint inputs and write only their
assigned rows.

Fixed bilinear tap offsets remove three dynamic V arrays per
high-precision sample. The gradient span borrows its shader directly,
and rectangle and A8 mask callbacks borrow the blitter header.
Generated production C showed no allocation calls in the 83 and
78 raster functions reached from the two callbacks, respectively.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured the clipped pipeline rectangle through return. The image
cases used padded rows, an approximately 2× bilinear scale, and paint
alpha 0.83. Buffer reset and SHA-256 ran outside the timer. Seven
rotating groups on Mac17,6 with 18 logical CPUs started at 08:59
local time on 2026-11-18. One-minute load varied from 7.87 to 8.74.
The initial baseline attempt reached a 3 GiB guard and exited 137.
The full cohort used the repository's default 12 GiB guard, peaked
at 4.12 GiB sampled RSS, and completed with all 21 processes and
the guard exiting zero. Times are medians in microseconds. Warm
results use each process's median of six calls after the first.

| Size and paint | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 67×43 linear gradient | 21.083 / 17.417 / 17.792 | 18.979 / 16.604 / 16.500 |
| 67×43 image source-over | 64.083 / 64.750 / 67.084 | 62.938 / 63.896 / 64.083 |
| 67×43 image soft-light | 190.375 / 150.208 / 156.458 | 178.396 / 142.625 / 145.563 |
| 511×513 linear gradient | 1557.209 / 1436.292 / 1446.416 | 1498.458 / 1440.729 / 1430.604 |
| 511×513 image source-over | 5547.417 / 5712.709 / 5889.750 | 5654.312 / 5855.333 / 5846.792 |
| 511×513 image soft-light | 16875.500 / 13038.542 / 13255.833 | 16175.001 / 12995.438 / 13151.083 |
| 512×512 linear gradient | 1452.167 / 1415.709 / 962.125 | 1488.042 / 1456.626 / 778.146 |
| 512×512 image source-over | 5684.500 / 5659.750 / 3030.250 | 5697.042 / 5742.562 / 3071.146 |
| 512×512 image soft-light | 16344.541 / 12795.542 / 6772.958 | 15930.334 / 13002.750 / 6816.167 |
| 1031×517 linear gradient | 3137.334 / 3000.125 / 1149.625 | 3152.396 / 2920.479 / 990.708 |
| 1031×517 image source-over | 11584.667 / 11541.208 / 3563.958 | 11413.062 / 11755.291 / 3820.291 |
| 1031×517 image soft-light | 32943.250 / 26637.625 / 7685.500 | 32460.250 / 26742.229 / 7663.542 |
| 2051×1537 linear gradient | 19744.292 / 17869.917 / 5494.125 | 18293.750 / 17780.208 / 5822.042 |
| 2051×1537 image source-over | 67562.709 / 69443.459 / 22492.500 | 67081.146 / 68185.792 / 20657.354 |
| 2051×1537 image soft-light | 193470.750 / 157997.208 / 42812.041 | 193213.750 / 158015.709 / 43713.520 |

All full destination hashes matched. The default configuration won
all first and warm pairs at and above the dispatch threshold. The
511×513 source-over case stayed serial and its first and warm
medians rose 6.2% and 3.4% respectively. The largest soft-light case
ran in 158.02 ms forced serial and 43.71 ms with workers. Harness
hashes were
`1ad420cd299b856d01fe8625af43ae8cd656f1fa7f9a3d4d3c09e5af83afd07c`
before and
`05c3e9695fe39386c3ca3e9f4549d7bfe5a30def843e0b8caebbce25209a386a`
after.

A separate probe observed two distinct threads at 512×512, four
on larger batches, and zero below the cutoff or with workers
disabled. Public macOS Canvas image draws in multiply and soft-light
modes both dispatched four threads for a 2051×1537 destination.
Their full surface hashes matched forced serial
(`dd5cee2f3728877c3dd8f3d78401faf7f71bbefebca6f27967d057ce144d6db2`
and `1768b517455d7fcd00f7fd59d1d155e79c40abfd7148572fddb4ffa1be60807b`).
All four probe processes and the guard exited zero. Focused macOS
and arm64 Linux tests covered clipped gradient and image rectangles,
low and high precision, and both disjoint and aliased mipmap levels.
Forced serial, ASan/UBSan, ThreadSanitizer, and the pinned CPU raster
differential suite (count 2000, seed 20261106) passed.

The published single-C-unit executable
`ea5cc7a3d626c8fdef30c81044f1e9a78976d20c1c5726245d8a335b1950bb74`
and native library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched the frozen Hacker News, GitHub and Old Reddit references.
The parsed source receipt pins the sprite implementation from
`461e46094`. Fresh sealed replays used JavaScript, private profiles
and caches, a 1024×768 CSS-pixel viewport, 2× captures and a
one-second settle. The audits found 30, 33 and 25 entries and zero
Canvas elements. The three browser processes and guard exited
zero. Timings above cover the isolated rectangle path. Site timings
for the rectangle change await its production build.

### Parallel legacy bitmap shader rectangles

Large N32 source-over image rectangles with disjoint source and
destination storage use up to four workers at 262,144 pixels. Each
worker owns a stack-backed scratch row and uses the existing sampler
and blend routines on complete rows. This preserves chunk origins
and fixed-point rounding for scaled and repeated images. Small
rectangles and overlapping storage use the original ordered
shading and blending with one scratch size check per rectangle.
The generated C showed no allocation calls in the 33 raster
functions reachable from the worker callback.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured the clipped blit through return. Both surfaces had padded
rows. The source included opaque, transparent and partially
transparent premultiplied pixels. The fixtures used nearest scaling
at full paint alpha, bilinear scaling at alpha 211, and bilinear
affine repeat at alpha 211. Buffer resets and SHA-256 ran outside
the timer. Seven rotating groups ran on Mac17,6 with 18 logical
CPUs starting at 09:10 local time on 2026-11-18. One-minute load
was 10.20–10.75. All 21 processes and the guard exited zero.
Times are medians in microseconds. Warm results take each
process's median of six calls after the first.

| Size and sampling | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 67×43 nearest scale | 7.584 / 7.833 / 7.500 | 8.042 / 7.250 / 6.896 |
| 67×43 bilinear scale | 15.500 / 13.333 / 13.542 | 14.688 / 12.917 / 12.563 |
| 67×43 bilinear affine repeat | 23.709 / 21.000 / 20.084 | 23.312 / 20.687 / 19.709 |
| 511×513 nearest scale | 632.417 / 754.000 / 782.792 | 706.292 / 645.833 / 601.438 |
| 511×513 bilinear scale | 1106.791 / 1084.417 / 1078.000 | 1098.062 / 1171.833 / 1061.167 |
| 511×513 bilinear affine repeat | 2030.833 / 2246.875 / 1960.958 | 2103.313 / 2299.751 / 1939.500 |
| 512×512 nearest scale | 692.125 / 668.292 / 539.917 | 668.917 / 657.042 / 457.667 |
| 512×512 bilinear scale | 1156.542 / 1152.542 / 720.084 | 1134.062 / 1150.708 / 707.770 |
| 512×512 bilinear affine repeat | 1913.458 / 1879.583 / 1288.667 | 1930.979 / 1980.792 / 1279.396 |
| 1031×517 nearest scale | 1254.375 / 1357.625 / 553.583 | 1233.625 / 1333.500 / 492.896 |
| 1031×517 bilinear scale | 2092.417 / 2204.542 / 802.541 | 2168.126 / 2151.813 / 780.145 |
| 1031×517 bilinear affine repeat | 4159.125 / 4211.375 / 1437.750 | 4253.605 / 4016.979 / 1409.208 |
| 2051×1537 nearest scale | 7764.625 / 8409.667 / 2878.750 | 8387.916 / 8769.125 / 2672.166 |
| 2051×1537 bilinear scale | 14030.458 / 12961.750 / 4428.125 | 14004.750 / 13104.188 / 4413.458 |
| 2051×1537 bilinear affine repeat | 22688.625 / 24241.917 / 8375.208 | 23800.250 / 23612.292 / 7999.229 |
| 3840×2160 nearest scale | 21427.917 / 20403.875 / 7456.084 | 21654.709 / 20936.688 / 7269.521 |
| 3840×2160 bilinear scale | 33720.167 / 35336.083 / 11337.708 | 34250.500 / 34800.063 / 11285.792 |
| 3840×2160 bilinear affine repeat | 64875.542 / 62727.459 / 20333.459 | 65847.855 / 59959.084 / 20428.312 |

Default scheduling won all seven pairs at and above the cutoff on
both metrics. Below it, the 511×513 nearest first-call median rose
from 632.417 to 782.792 µs, and its warm median fell from 706.292 to
601.438 µs. Individual pairs varied below the cutoff. An earlier
cohort kept the scratch capacity check inside the serial row loop
and showed a 511×513 nearest warm regression of 501.771 to 545.730 µs.
That cohort ran at load 4.84–5.26 and measured 4K warm default times
of 4.236, 7.164 and 12.668 ms for the three modes. Host load and
control medians differed between the two cohorts. All destination
hashes matched in both cohorts. Harness SHA-256 values were
`4192d16ae370065a0bfe9ef590b3b45f02505e10beab071d407191a2aa1f63ea`
before and
`c38a5dc99551a822b2231d495759e6e55ef392a479bd115da4b4da482175b321`
after.

A separate probe observed two threads at 512×512 and four on
larger worker batches. It observed zero batches below the cutoff
or with workers disabled. Two public macOS Canvas source-over
draws scaled to 2051×1537 with and without smoothing. Both used
four threads and matched forced serial pixel for pixel
(`a7aef68e149aa66ce13d303a453a3096da41020d6aa1ade7a5861178bbcdcda8`
and `e136bd70ab871634186ab3ee9989b13913117a3305cf69fa8ac2c3133e382152`).
All probe processes and the guard exited zero. Focused macOS and
arm64 Linux checks covered clipped and padded sources, nearest
and bilinear sampling, affine repeat, and shared storage.
Forced serial, ASan/UBSan, ThreadSanitizer, and the pinned CPU
raster differential suite (count 2000, seed 20261106) passed.

The published single-C-unit executable
`eb9c83cc14fe48f533dcf68e7dbc3e4c871426aa6aa110d3e65a570d961f22a1`
and native library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched archived Hacker News, GitHub and Old Reddit pixels.
The parsed-source manifest pins the preceding shaded rectangle
implementation from `23091d029`. Fresh sealed replays used
JavaScript, private profiles and caches, a 1024×768 CSS viewport,
2× capture and a one-second settle. The audits found 30, 33 and
25 entries and zero Canvas elements. All browser and guard exits
were zero. The timings above cover legacy bitmap shader rectangles.
Candidate site measurements await the shared production rebuild.

### Parallel AVFoundation frame conversion

The macOS playback bridge copies BGRA frames into packed RGBA by
assigning disjoint rows to the raster workers. The CoreVideo buffer
remains locked and the RGBA buffer remains private until the workers
join. The ARM64 loop converts sixteen pixels at a time, with vector
and scalar tails for odd widths. Dispatch starts at 1,048,576 pixels,
with up to four threads. `VOX_SERIAL_CPU_RASTER=1` forces serial
conversion.

Matched native Clang `-O3 -g` harnesses measured conversion through
return for deterministic BGRA frames with 44 bytes of source row
padding. Allocation, source initialization and output hashing were
outside the timer. The first measurement for each size included
accessing the new output buffer. Seven rotating groups on Mac17,6
with 18 logical CPUs started at 09:20 local time on 2026-11-18.
The one-minute load was 4.08. All 21 processes and the guard exited
zero. Times are medians in microseconds. Warm values take each
process's median of the 16 calls after its first.

| Frame | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 320×240 | 20.750 / 25.167 / 20.500 | 4.875 / 4.834 / 4.875 |
| 1023×1025 | 324.875 / 312.292 / 306.917 | 79.979 / 92.562 / 91.709 |
| 1024×1024 | 79.416 / 71.459 / 77.625 | 78.187 / 70.438 / 39.459 |
| 1426×1080 | 486.125 / 510.166 / 353.084 | 112.417 / 145.083 / 82.605 |
| 1921×1081 | 707.458 / 665.125 / 431.750 | 150.854 / 194.145 / 77.188 |
| 3840×2160 | 2957.375 / 2878.875 / 1590.500 | 583.395 / 543.292 / 317.396 |

Default scheduling won all seven warm pairs for every dispatched
size. First-call wins for those sizes were 4, 6, 7 and 7. The
1023×1025 warm median rose by 11.730 µs below the cutoff. An
earlier four-pixel loop took 6.917 µs for warm 320×240 and
311.750 µs for 4K. A sixteen-pixel interleaved load/store trial
took 4.917 and 314.271 µs respectively. Hashes matched across all
three cohorts. Final harness hashes were
`eb43d0937dd0a0c3a47c2511f43cca8076731eed5d35450f904b903d0731bbc7`
before and
`8746566284cb567e9070deb90ca07577fe888504ca9aea710abd36ed042f4ea1`
after.

A separate native probe saw two threads at 1024×1024 and 1426×1080,
three at 1921×1081 and four at 4K. It saw zero batches below the
cutoff and under forced serial. AVFoundation decoded a local
1920×1080 MP4 fixture
(`b7f44d034cb48490132861748ecbbf46db3c63cb935be9c1e7a9e43d046f6cae`)
through the playback bridge and used three distinct conversion
threads. Its RGBA output matched forced serial
(`1fe0091d81bbd335aac0a789928b6f172f51c6c3ccc42362a23347c6d80071b4`).
All four probe processes and the guard exited zero. The native MP4
and loopback HLS playback suite passed in both modes, including
pause, seek, end and cancellation. Byte and canary checks covered
unaligned output, odd widths, padding and both sides of the cutoff.
ASan/UBSan and ThreadSanitizer passed the conversion fixtures.

The published single-C-unit executable
`eb9c83cc14fe48f533dcf68e7dbc3e4c871426aa6aa110d3e65a570d961f22a1`
with library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched archived Hacker News, GitHub and Old Reddit pixels.
The sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS viewport, 2× capture and a one-second settle. They
audited 30, 33 and 25 entries and zero video elements. All browser
and guard exits were zero. The shared bundle predates the change.
The benchmark measures CPU frame conversion, and the archived
pages provide pixel regression coverage.

### Parallel rounded shadow patch expansion

The macOS rounded-shadow adapter maps horizontal coordinates once
for the full mask. Workers sample the same nearest-neighbor patch
into disjoint destination rows before the adapter submits the
completed mask to the GPU. Dispatch starts at 262,144 pixels and
uses up to four threads. The smaller masks also reuse the column map.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured patch expansion through return, including output
allocation and column map preparation. Patch generation and output
hashing were outside the timer. The synthetic 205×205 patch and
fractional sample origins were identical across modes. Seven
rotating fresh-process groups on Mac17,6 with 18 logical CPUs
started at 09:34 local time on 2026-11-18. The one-minute load was
4.99. All 21 processes and the guard exited zero. Warm values
use the medians of each process's four calls after its first.
Times are medians in microseconds.

| Mask | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 67×43 | 7.917 / 2.250 / 2.250 | 7.271 / 1.875 / 1.855 |
| 511×513 | 672.250 / 147.667 / 146.209 | 620.146 / 147.230 / 147.875 |
| 512×512 | 621.750 / 149.500 / 124.167 | 638.792 / 148.417 / 96.958 |
| 1600×400 | 1520.833 / 364.833 / 165.000 | 1526.083 / 358.354 / 196.270 |
| 1921×1081 | 4895.917 / 1156.542 / 552.167 | 5063.875 / 1154.583 / 572.854 |
| 3840×2160 | 19865.625 / 4663.291 / 1802.042 | 19833.250 / 4674.730 / 1880.792 |

All full output hashes matched. The default configuration beat
the original in all seven first and warm pairs, including the
serial-sized masks. The benchmark executable SHA-256 values were
`41804e5f247e4e84437963145c0e4d0a436cdfe37e4972429e6ad1ac7ed36e3c`
before and
`ff337dafc0469304497bf1bb501bc1f3e34ba3d87e80788b623a095b1d1874ec`
after.

A separate dispatch probe observed two threads at 512×512, four
on larger batches and zero below the cutoff or with workers
disabled. Six full 1600×400 shadow draws through the public
gg.canvas adapter each used four threads. They all matched the
existing Graphite golden hashes in both modes. The initial probe
executable lacked the callback symbol. The final driver exercised
the public draw entry point with explicit runtime checks. All
four final probe processes and the guard exited zero. Focused
scalar-reference, forced-serial, ASan/UBSan and ThreadSanitizer
checks passed.

The published single-C-unit executable
`abc313c877690171f669481414f33c967376bd88d45f1128596e79e76f749f4a`
with library
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`
matched archived Hacker News, GitHub and Old Reddit pixels.
Fresh sealed replays used JavaScript, private profiles and caches,
a 1024×768 CSS viewport, 2× capture and a one-second settle.
The audits verified 30, 33 and 25 entries and all browser and
guard exits were zero. The published build predates this shadow
change. Timings above cover mask expansion in isolation.

### Parallel alpha extraction after GPU readback

Rounded image clips, blurred shadows and SVG shadows share an A8
extraction kernel. It copies the fourth byte of each complete
pixel. The source and output allocations are disjoint. The raster
scheduler joins its packed batches before the caller uses the mask.
Inputs smaller than 2 MiB use the optimized serial scan. Larger
inputs use up to four threads and finish any partial batch on the
caller.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured extraction through return, including mask allocation.
Input generation and output hashing ran outside the timer. Seven
rotating fresh-process groups ran on Mac17,6 with 18 logical CPUs
starting at 09:42 local time on 2026-11-18. One-minute load varied
from 4.70 to 9.06. All 21 processes and the guard exited zero.
Warm medians use each process's eight calls after its first.
Times are in microseconds.

| Mask | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 32×32 | 0.792 / 0.292 / 0.375 | 0.709 / 0.125 / 0.125 |
| 511×513 | 195.709 / 48.125 / 46.083 | 175.750 / 52.479 / 52.438 |
| 512×512 | 175.166 / 54.084 / 49.375 | 173.458 / 42.312 / 52.917 |
| 1600×400 | 432.583 / 116.584 / 129.833 | 383.021 / 106.729 / 95.188 |
| 1024×1024 | 704.292 / 206.416 / 169.625 | 795.105 / 196.813 / 161.687 |
| 1921×1081 | 1581.750 / 368.667 / 304.167 | 1571.354 / 353.021 / 282.354 |
| 3840×2160 | 6251.666 / 1369.875 / 909.708 | 6625.355 / 1634.729 / 1145.896 |

All output hashes matched. The default configuration won every
pair against the original, including the below-cutoff fixtures.
The initial candidate dispatched at 512×512 and took 43.479 µs
warm versus 38.750 µs forced serial in that group. The retained
cutoff keeps that size serial. The final 1600×400 first-call
median rose against forced serial by 13.249 µs, while the warm
median fell by 11.541 µs. The initial cohort had load 4.21–4.27
and 4K warm medians of 4509.688 / 1255.521 / 809.667 µs.
Final harness SHA-256 values were
`55912cc28f98c816950bdcd46e490698104bf4f1cdbc6e420c3a1efd4b6e5eb4`
before and
`bc52aff736e98566226d4375bf50aa03d0504115a6741f92220c7b4a6297a10d`
after.

A separate probe saw four threads for a public 1024×1024 rounded
image clip and a 1600×900 shadow draw with uneven corner radii.
Their complete outputs matched forced serial
(`85a6f0fa911e7242a01fab31f1d5f3ad34916e5ab04fae0cd998c5d5b1c477fa`
and `6cab9c3c836d7bc1ab9fcc2bc4ec703cecba29deb7893dbfd3dd3333d52a48b3`).
The 1600×400 harness assigned four ranges and used two to four
distinct threads. Larger cases used four. There were zero worker
batches below the cutoff and with forced serial. Probe processes
and guard exited zero. The rounded-image clip, cookie-shadow, SVG
shadow and tall-shadow GPU fixtures passed. macOS, arm64 Linux,
forced serial, ASan/UBSan, ThreadSanitizer and the pinned CPU raster
differential suite (count 2000, seed 20261106) passed.

The available completed browser was still
`abc313c877690171f669481414f33c967376bd88d45f1128596e79e76f749f4a`,
which matched the archived Hacker News, GitHub and Old Reddit
references in the [preceding check](#parallel-rounded-shadow-patch-expansion).
The timings above cover alpha extraction. Candidate site timings
await the shared rebuild.

### Parallel SVG shadow border crops

The macOS SVG drop-shadow adapter removes the one-pixel border
from the resolved GPU readback with the shared raster rectangle
copy. The packed BGRA result is uploaded after the copy joins.
The copy borrows the destination slice explicitly, avoiding a
compiler-inserted clone, and copies only the visible bytes in each
row. Copies of at least 4 MiB use up to four workers.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured the crop including allocation of the packed result.
Source setup and output hashing ran outside the timer. Seven
rotating fresh-process groups ran on Mac17,6 with 18 logical CPUs
starting at 09:50 local time on 2026-11-18. One-minute load varied
from 6.68 to 7.05. All 21 processes and the guard exited zero.
Times are medians in microseconds. Warm results take each
process's median of eight calls after its first.

| Packed output | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 32×32 | 0.334 / 0.333 / 0.291 | 0.250 / 0.167 / 0.167 |
| 511×513 | 77.666 / 87.250 / 76.417 | 84.188 / 85.396 / 82.729 |
| 1023×1025 | 313.250 / 330.042 / 336.167 | 334.167 / 342.583 / 343.334 |
| 1024×1024 | 323.583 / 330.250 / 311.708 | 326.521 / 355.334 / 312.604 |
| 1921×1081 | 678.000 / 655.083 / 598.958 | 667.708 / 669.230 / 595.042 |
| 2048×2048 | 1286.625 / 1364.250 / 1128.166 | 1305.458 / 1351.938 / 1169.938 |

Every full output hash matched. The two largest cases won all
seven warm pairs. The 1023×1025 case stayed serial and its warm
median rose by 9.167 µs. Harness SHA-256 values were
`58ef6e5a3c6f1c9b24650785c278bcd81803e748b35a7dc19077bb744eff4b3c`
before and
`10180243c93a8352aa05bb3f9cdcc083b550577d2dc9b407e4d1a999b5eff998`
after.

The dispatch probe observed four distinct threads at and above
the cutoff and zero below it or with workers disabled. The
1600×900 public SVG shadow draw used four threads for the
900×1600 crop with one and four destination samples. All four
complete surfaces, including the forced-serial draws, had SHA-256
`e39949b272bf555938ebe79711085deadf9881609cecd6bc5c44f64b5ac3a9e3`.
The four probe processes and guard exited zero. Existing SVG
shadow fixtures matched the unchanged Brave references. The
padded copy checks, macOS and arm64 Linux tests, ASan/UBSan,
ThreadSanitizer and the pinned CPU raster differential suite
(count 2000, seed 20261106) passed.

The available completed browser was still
`abc313c877690171f669481414f33c967376bd88d45f1128596e79e76f749f4a`.
Its archived Hacker News, GitHub and Old Reddit pixel checks are
recorded in the [preceding replay](#parallel-rounded-shadow-patch-expansion).
The timings here cover the isolated crop. Candidate browser
timings await the shared rebuild.

### Parallel preparation of repeated background textures

The macOS rounded-background compositor prepares its repeated
texture with the shared raster premultiplication kernel. It writes
premultiplied RGBA directly into the upload buffer, preserving the
source bytes and the original `(channel * alpha + 127) / 255`
rounding. At and above 262,144 pixels, raster workers join before
the GPU upload. Smaller textures, including the archived Old
Reddit sprite, use the fused serial loop.

Matched single-C-unit V `-prod -g -prealloc -gc none` harnesses
measured allocation and premultiplication through return. PNG
decoding, input setup and output hashing ran outside the timer.
The Old Reddit case used the original 140×1751 RGBA sprite
(`3151728340f566d1400cd9437ae64e8d95583d066712fa1d7c0718b8d10f5527`).
Other inputs were synthetic. Seven rotating fresh-process groups
ran on Mac17,6 with 18 logical CPUs starting at 09:56 local time
on 2026-11-18. One-minute load varied from 4.98 to 5.14. All 21
processes and the guard exited zero. Warm results take each
process's median of its eight calls after the first. Times are
medians in microseconds.

| Texture | First before / forced serial / default | Warm before / forced serial / default |
| --- | ---: | ---: |
| 32×32 | 1.542 / 0.667 / 0.666 | 1.417 / 0.458 / 0.438 |
| 140×1751 Old Reddit | 391.208 / 135.792 / 141.667 | 399.938 / 144.042 / 142.270 |
| 512×512 | 431.500 / 156.250 / 143.000 | 423.646 / 156.645 / 130.667 |
| 1031×517 | 837.209 / 310.666 / 234.958 | 857.354 / 320.937 / 229.355 |
| 1921×1081 | 3346.042 / 1267.500 / 863.334 | 3354.562 / 1242.375 / 801.938 |
| 2048×2048 | 6970.792 / 2617.625 / 1409.708 | 6851.792 / 2507.791 / 1530.312 |

Every output hash matched. Default scheduling won every first and
warm pair against the original. The harness SHA-256 values were
`2b122e1bd45fe28f43894bff915193155079d25ffa9eb30f013a8daf42dbcc8d`
before and
`f6ed15b925b82597e68204ca3edc0af4fb4a6f84416cd847fce11f4e3bca2d44`
after.

The dispatch probe observed two distinct threads at 512×512, four
on larger synthetic cases, and zero below the cutoff or with
workers disabled. A 140×3502 texture formed from two copies of the
Old Reddit sprite reached the public repeated-background path and
used three threads. All draws with the single and doubled sprites,
including forced serial, produced the complete surface SHA-256
`4a8b97797c29a8342798c573db35afc529341f3d96028b5ce6ff6abb203bd79d`.
All four probe processes and the guard exited zero. The unchanged
single-sample and multisample Brave references passed, including
the double-height upload regression check. The first GPU test
setup failed compilation before running because the fixture
reassigned a mutable array alias. The final fixtures passed in
both scheduling modes. Focused macOS and arm64 Linux tests,
ASan/UBSan, and ThreadSanitizer passed.

The latest completed browser was still
`abc313c877690171f669481414f33c967376bd88d45f1128596e79e76f749f4a`.
The same build matched archived Hacker News, GitHub and Old Reddit
references in the [preceding replay](#parallel-rounded-shadow-patch-expansion).
The timings here cover texture preparation through return.
Candidate page timings await the shared production rebuild.

### Parallel CPU copies for Metal texture transfers

Joined Metal uploads and readbacks now split CPU staging copies of
at least 8 MiB across up to four raster workers. Packed buffers use
one `memcpy` per band. Padded buffers copy each row's active bytes.
The upload joins before GPU encoding, and readback joins after
Metal completes and before the buffer is released. Smaller copies
and `VOX_SERIAL_CPU_RASTER=1` use a single thread.

The first cutoff trial dispatched at 2 MiB. At 2048×768, warm
copies improved but the first upload rose from 118.917 to 135.750 µs
and the first readback from 98.042 to 124.208 µs. The final cutoff
keeps that size serial.

The final cohort used seven rotating fresh-process groups on
Mac17,6 with 18 logical CPUs and one-minute load of 7.55–8.32.
A single Apple Clang `-O2 -flto` harness called either the original
row loop or the production copy helper on actual shared Metal
buffers and client memory. Times cover the CPU copy through return,
including worker dispatch and join. Buffer allocation, fill, byte
verification and GPU work are outside the timed span. Warm times
use the median of each process's ten copies after its first call.
All 378 processes and the guard exited zero and checked every byte.

| Surface and direction | First before / serial / default, µs | Warm before / serial / default, µs | Warm default faster pairs |
| --- | ---: | ---: | ---: |
| 512×512 upload | 17.375 / 15.917 / 16.500 | 17.521 / 17.292 / 17.375 | 4/7 |
| 512×512 readback | 16.750 / 17.375 / 17.875 | 17.625 / 17.333 / 16.646 | 5/7 |
| 2048×768 upload | 328.917 / 129.833 / 183.667 | 96.063 / 97.375 / 100.250 | 1/7 |
| 2048×768 readback | 182.500 / 115.667 / 144.125 | 102.938 / 99.021 / 103.750 | 2/7 |
| 2048×1024 upload | 252.625 / 261.125 / 160.375 | 133.667 / 134.459 / 108.584 | 7/7 |
| 2048×1024 readback | 314.958 / 164.042 / 192.375 | 135.000 / 135.521 / 99.938 | 7/7 |
| 2051×1537 padded upload | 541.583 / 647.292 / 199.875 | 407.750 / 439.208 / 199.855 | 7/7 |
| 2051×1537 padded readback | 617.000 / 510.792 / 253.542 | 438.208 / 422.125 / 210.021 | 7/7 |
| 2048×1536 upload | 204.083 / 278.667 / 194.167 | 219.792 / 221.438 / 157.771 | 7/7 |
| 2048×1536 readback | 289.875 / 286.208 / 209.917 | 215.375 / 216.834 / 142.438 | 7/7 |
| 3840×2160 padded upload | 1608.292 / 1413.417 / 552.167 | 613.646 / 589.855 / 355.396 | 7/7 |
| 3840×2160 padded readback | 1908.458 / 1451.167 / 708.958 | 1184.875 / 1134.355 / 484.959 | 7/7 |

The harness executable SHA-256 was
`f04d6a30109091622508e9ce0f312a29d46145d7d4a9ecf4b6f3b1e27da3c2cf`.
A separate dispatch probe recorded four distinct threads at 8 MiB
and on 2051×1537 padded copies. It recorded no dispatch below
8 MiB or in forced serial mode. The real Metal test passed its
existing command ordering, staging ownership and failure checks
and new large packed and padded round trips under default
scheduling, forced serial, and ASan/UBSan. ThreadSanitizer passed
both large padded copy directions. The V and Python staging paths
produced identical Sokol Metal headers. The broader UI adapter
staging check stopped at a missing `gg/canvas/vox_path_math.m`
wrapper, before reaching its Metal assertion.

#### Archived page baseline

The completed single-C `-prod` receipt `20261118-095612-f974a35a`
sealed the previous repeated-background texture change and the
original Metal transfer loop. Its executable SHA-256 was
`c758ea483aa8943ec31cdbdbb282e5271c1335c9a5df3c29b37a32cbedfce3a8`.
The AVIF and adblock helper hashes match the
[frame-clear benchmark](NATIVE_FRAME_CLEAR_BENCHMARK.md#input-identities).

Fresh processes used the same archives and decoded pixel hashes
as the [earlier eligibility runs](#archived-browser-eligibility).
The 1024×768 viewport was captured at 2× after one second of
settling. Each process used a private empty profile and cache,
sealed origin replay and JavaScriptCore. System caches remained
available. All nine captures matched the frozen references and
retained 30, 33 and 25 distinct content IDs. JavaScriptCore
initialized and reported no script diagnostics. The browsers and
the memory guard exited zero. One-minute load ranged from 14.07
to 15.68. A pilot capture exited zero but its audit check used the
wrong runtime field name. The completed cohort uses the actual
`native_context_initialized` field.

| Archived page | Launch through PNG, audit and process exit, ms | Median, ms |
| --- | ---: | ---: |
| Hacker News | 2115.233, 1782.767, 1812.123 | 1812.123 |
| GitHub | 4974.524, 4307.651, 4552.195 | 4552.195 |
| Old Reddit | 2029.691, 2041.569, 2028.785 | 2029.691 |

These times establish the page baseline for the original Metal
copy. A whole-page comparison requires a completed build with the
final 8 MiB cutoff and confirmation that the sites reach it.
