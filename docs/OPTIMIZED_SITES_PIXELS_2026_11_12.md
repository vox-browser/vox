# Optimized-site pixel audit, 2026-11-12

**The all-site pixel-equality gate remains open.** The initial audit below
found five differing sites and an unverified Reddit workload. Subsequent fixes
now make the registered Lobsters page and archived Wikipedia portal
pixel-exact in two fresh production captures each; see the corrective results
below. This is a rendering correctness audit, not a new instruction or
scrolling benchmark. Existing references, zero-error gates
and historical performance statistics remain unchanged.

| Catalog site | Initial result | Differing RGBA pixels | Workload |
| --- | --- | ---: | --- |
| Hacker News homepage | Exact in two fresh pairs | **0 / 3,145,728**, every capture | Original six-response instruction archive; 1024×768 CSS pixels, native scale 2, author scripts enabled |
| Lobsters | Fails; initial native launch also crashed | **17,969 / 786,432**, both subsequent native captures | Registered 33-response frozen guest page, full-uBO filtering; scale 1 |
| Old Reddit /r/programming/ | **Unverified** | — | Historical account-bearing fixture is absent; current unauthenticated request returns HTTP 403 |
| CNN homepage | Fails; source/replay gate also fails | **176,037 / 786,432**, both native captures | Registered 85-response frozen guest page, full-uBO filtering; scale 1 |
| Wikipedia portal | Fails in both fresh pairs | **445 / 786,432** | Newly acquired 15-response archive; JavaScript disabled in both engines; scale 1 |
| vlang.io | Fails in both fresh pairs | **309,884 / 786,432** | Newly acquired 42-response archive; JavaScript disabled in both engines; scale 1 |
| GitHub /vlang/v | Fails in both fresh pairs | **38,784 / 786,432** | Retained script-free hydrated DOM and 62 cached resources, sealed original-origin replay; normal scripting policy; scale 1 |

Each listed difference is against a fresh Brave capture of the same sealed
bytes, viewport and script policy. Wikipedia, vlang.io and GitHub reproduce
their respective engine images exactly across both pairs. The two completed
Lobsters images are also identical. CNN's native images differ from each other
at **1,558 pixels**, despite equal cross-browser differing-pixel counts. Its
reference is stable across two fresh Brave processes, so native image stability
also remains open. Every counted comparison uses the full RGBA viewport without
masks or a nonzero tolerance.

The subsequent `9b326517b` diagnostic cohort makes all six available archived
catalog workloads exact, including CNN. Production confirmation, CNN's historical
source/replay check and Reddit remain open; see the [latest decoded-frame result](#decoded-image-frames-for-cpu-resized-planar-uploads-2026-11-16).

## Executable identity and conditions

- Vox executable SHA-256:
  `c4252882672bfdcdf670312d0d836f5fd946805bc393d5ba4bdc0499addc2330`.
- Completed build receipt: `20261112-080916-95bea68e`, source head
  `ec111fb6f6c40bbca1b94071b594233093852a2f`, dirty-input receipt retained.
  The managed build used the C backend, literal V `-prod`, and one C unit.
- Brave: **157.1.99.56**, executable SHA-256
  `a81c3ddf3dd2c5a0e8b0c3d816cac27778d4969df47ae6d5b95fc55b2c60e247`;
  framework SHA-256
  `f8d05a2d5a6324420a9de621d38272937f2c9ae27b8650c011f8c4d8d9422f22`.
- Every browser observation launches a fresh process with a fresh private
  profile/cache. Replay never forwards unknown requests to the live network.
  Replay trust and proxy settings apply only to the test processes. OS caches
  are retained. Vox captures the document viewport, excluding browser chrome;
  screenshot launches use the test display placement policy.
- HN retains two seconds of settling; the full-uBO site checks retain five.
  The original Wikipedia/GitHub capture drivers supply the other capture
  boundaries. The script-disabled vlang.io check does not freeze or replay an
  initialized video frame and makes no live JavaScript-parity claim.
- Browser processes run through memory guards. Focused capture jobs use 3 GiB;
  the existing HN/GitHub comparison-driver invocations use the default 12 GiB.
  HN uses the same private PID registry for its LaunchServices launches and
  memory-guard adoption; the adoption error is null.
- Bundle reader leases protect the grouped replay and native-repeat checks.
  The original drivers also pin their inputs. A final verification of all
  **1,040 HN input paths**, covering both browser bundles, native dependencies,
  fixtures and tools, finds **zero changed identities** across the audit.
  Newly sealed archive bodies are hash-validated too.

Source commits made concurrently after the pinned build are outside this result.
The latest completed bundle was reused; no duplicate production build was
requested to run these checks. This documentation commit requests the normal
managed rebuild, which does not retroactively validate a newer binary.

## Failure details and limits

**Lobsters:** the first native capture exits **139**, with signal 11 in
`layout__layout_uncached_independent_formatting_context`, reached through inline
and flex layout. Both later captures exit 0 and differ from Brave at the same
17,969 pixels. The successful captures do not erase the crash. Both fresh Brave
images match each other and the immutable archived source exactly.

**CNN:** the two fresh Brave replays agree exactly but differ from the archived
source by **107,289 pixels**, retaining the previously documented source/replay
failure. Native differs from the current agreeing Brave replays by 176,037
pixels. The native-repeat difference above prevents a stability pass. All
completed native and Brave capture exits are 0, and the existing full-uBO
request/cosmetic checks pass. Neither source drift nor filtering agreement
excuses the rendering differences.

**GitHub:** the first legacy cache-only driver run loads an unstyled native page
and fails its historical Vox reference by 304,691 pixels. That attempt is retained
as a harness/cache failure, not the final rendering result. Replaying the retained
raw resources at their original URLs restores styles. Both fresh Brave images
then match the unchanged historical Brave reference exactly; native differs from
the historical Vox reference by **37,997 pixels** and from Brave by 38,784.
Native URL/readiness/viewport checks and all **33 directory-row identities** pass.
The 33-row audit alone does not prove every resource or interaction is supported.

**Wikipedia and vlang.io:** their historical Build fixtures are absent, so the
new archives establish current cross-browser differences, not preservation or
regression relative to the historical workloads. Wikipedia's earlier seven-pixel
gap and vlang.io's earlier 112,005-pixel gap cannot be compared numerically with
these new workloads as a before/after result. Most current vlang.io differences
are small: 3,244 pixels exceed three channel levels; maximum error is 136.
Wikipedia's maximum error is 171. Both still fail the exact gate.

**Reddit:** the missing `/r/programming/` archive was not replaced by another
subreddit, a login page or the old Linux `/r/worldnews/` evidence. The current
request returns 403 at the requested URL. The historical Reddit homepage claim
also remains unverified; this audit supplies no recovered private fixture.

The English Wikipedia Main Page mentioned in the catalog's separate scrolling
follow-up is a different workload from the portal row tested here. This audit
does not establish live-site parity, whole-document/scrolling parity, interactive
JavaScript correctness, or a performance gain.

## Reproduction and local evidence

The runs use canonical tools:

- [HN comparison driver](../tools/hacker_news_browser_instructions.py), with
  `--home-archive Tests/Browser/Brave/hn-home-instructions --instruction-scope launch
  --repeat 2 --scale 2 --settle-seconds 2`.
- [Forum/news driver](../tools/forum_news_pixels.py), with
  `--sites lobsters,cnn --cache-policy cold`, full uBO **1.75.0**, the repository
  filter snapshots, and a checker built from `tools/adblock_check.v` using
  `-b c -enable-globals -memory-limit 10G`.
- [Archive tool](../tools/page_archive.py) to acquire the current Wikipedia and
  vlang.io bytes; the retained GitHub cache is imported without live fetching.
  [Wikipedia capture primitives](../tools/wikipedia_browser_instructions.py)
  and [GitHub row validation](../tools/github_browser_instructions.py) execute
  the paired original-origin replays. The local command scripts record the
  explicit script policies and reader leases.
- The existing verified `Build/pixel-tools/pixel_diff`; known exact and
  one-pixel controls pass again. The local evidence records its hash.

Raw PNGs, diffs, audits, command scripts, process exits, guard receipts, fixture
manifests/bodies, before/after identity pins and the completed-build receipt are
retained locally under
`docs/performance/optimized-pixels-20261112/`. They are deliberately not committed.
The corresponding per-job Build directories, locks and guard files were removed
after collecting the report. Embedded absolute paths in raw receipts retain the
original Build locations; `relocation.json` maps them to their local locations.

Failed attempts remain in that evidence: the initial HN invocation rejected
`--repeat 1`; checker builds first lacked `-enable-globals`, then selected the
unsupported FastC generic path before the successful explicit C build; the
first repeat script serialized the proxy port as a number instead of a string
and exited before browser startup. Corrected repeats use fresh output paths.
These setup failures receive no rendering credit. The replay controller exits
0 after recording the comparisons; that is successful evidence collection,
**not** an all-site parity pass.

## First corrective slice: fractional glyph colors

Commit `e546a39ac` preserves computed floating-point text colors through glyph
coverage and the final pixel store. The restored document rasterizer had passed
only the serialized byte color into the CPU glyph painter, discarding the
existing `PaintSRGBColor` payload. For example, Lobsters uses author alpha 59%,
which must remain fractional while it blends with the glyph mask. The precise
path uses floating-point coverage blending; unsupported color-font, outline,
shader and filtered cases still decline to the caller's existing drawing path.

The new `glyph-fractional-color` fixture uses the existing test font and a fresh
Brave reference. Its original production capture differs at **585 pixels**.
The new production executable
`696faec3e67977fec3b70839999367f89c04d8293219f9e89e51f0476c1a8b41`
(managed receipt `20261112-084900-fdef0d9b`, source head `e546a39ac`) matches
that reference at **zero pixels in both fresh launches**. Cached and uncached
glyph tests match the exact Brave crop in normal and `-prealloc -gc none` modes;
the existing glyph-run tests also pass. All run through memory guards.

Two fresh native captures of the unchanged Lobsters archive now differ from
the retained Brave reference at **637 pixels each**, down from 17,969. The
remaining pixels are confined to the small avatars, mainly their rounded
boundaries; maximum channel error is 14. Both launches exit 0 and pass the
document identity, readiness and viewport checks. Their executable/resource
identities remain unchanged. This bundle also includes concurrent graphics
changes and the separate `0c99d4545` layout scratch-lifetime fix. Two successful
captures do not establish that the earlier intermittent crash is resolved.

**Lobsters and the all-site goal remain open.** The other site's original rows
above have not been replaced by results from this new executable. Production
attempts preceding this receipt repeatedly rejected source membership changes
or changed inputs during concurrent development; no consistency guard was
bypassed. Local corrective-slice evidence is in
`docs/performance/optimized-pixels-fixes-20261112/`, including the rejected
legacy-blending experiment and the floating-color replay diagnostic. Diagnostics
are not whole-browser acceptance results.

## Second corrective slice: rounded image clipping

Commit `adcfdb660` installs V/gg.canvas coverage for uniform rounded image
clips aligned to the device grid. The native adapter installs that coverage
into the existing image context; unsupported geometry retains its prior path.
Small repeated masks use a bounded persistent cache (at most 64 KiB), with a
test that retires the construction workspace before reusing its cached mask.

The new black-avatar clip fixture matches fresh Brave coverage exactly at
both 1× and 2× through the actual CoreGraphics mask-installation boundary.
All three focused tests pass in normal and `-prealloc -gc none` modes under
3 GiB guards. Existing references and tolerances remain unchanged.

Managed build `20261112-090832-84e95ffc`, executable SHA-256
`5ac58eb4aba69b6a16b7ffb777f0ee0c319e72dbd04e1c5defaa0d59bd69d975`,
contains the fix: the receipt's parsed-source manifest hashes for the V clip
implementation, native adapter header and native image painter match the
committed implementation. The receipt's earlier source head is `547cfce1b`;
its dirty, verified input snapshot includes this subsequent corrective slice.
Two fresh browser captures of the reduced fixture are pixel-exact. Two fresh
Lobsters captures now differ at **303 pixels each**, down from 637, with stable
executable/resource identities, successful content/viewport checks and exits 0.

Lobsters is still open. The remaining errors include single-level color errors
around colored avatar boundaries and differences inside one photographic
avatar. That resource, named `aphyr-16.png`, actually contains JPEG bytes;
image decoding/sampling needs a separate check from clip coverage. Maximum
remaining channel error is 13. Other catalog sites have not been reaccepted.
Local commands, images, comparisons, build/source identity checks and guard
receipts are retained under `docs/performance/lobsters-avatar-20261112/`.

## JPEG corrective slice: acceptance still pending

Commit `429e05476` adds a full-range JPEG conversion for unscaled rounded
images, with bilinear chroma sampling. The native decoder returns exactly the
384 archived Y/Cb/Cr bytes in the focused fixture. The converter matches the
immutable Brave photo interior in normal, production, and preallocated builds.
The application-level helper test also matches that interior exactly.

Whole-browser checks caught a regression before acceptance: executable
`57542962a91d72773b716394aa806df273c63c0583f1b9c9b6aa6c1cf621a91e`
(receipt `20261112-093011-42ded915`) differed at **1,807 Lobsters pixels** in
both fresh launches. Retained bitmap wrappers can share ID zero, so using that
ID as the variant key allowed later PNG draws to reuse a cached photograph.
Commit `cfc0d1afe` keys variants by their source-byte digest and rejects non-JPEG
bytes before cache lookup. Its focused application test checks JPEG reuse and
PNG rejection, and passes through the browser's V/C test harness under the
12 GiB guard. The focused production-mode converter test passes under 3 GiB.

The reduced JPEG browser fixture still differed at 156 pixels in two fresh
captures of both the first JPEG bundle and later executable
`9c7c1c7f4e70b786ee89ccdcb2faa6ebe350cd2803833401a19651bdebe46ef2`
(receipt `20261112-094105-7c7ea90f`). Those receipts contain the earlier cache
implementation. A diagnostic PNG containing the independently converted JPEG
pixels has zero interior differences and 18 boundary differences in both
native captures. These diagnostics do not accept the JPEG rendering path or
replace the unchanged whole-page reference.

Production validation of `cfc0d1afe` remains pending. The managed worker rejected
`20261112-094842-68dcb35e` after `webgl/native_egl.h` changed during compilation;
subsequent managed attempts are retained by the worker. No build-input or memory
guard was bypassed. The JPEG and all-site parity work remain open; the last
accepted pre-JPEG Lobsters measurement is still the 303 differing pixels above.
Local logs, images, failed attempts, debugger diagnostics, exact commands and
guard reports are retained in `docs/performance/lobsters-jpeg-20261112/`.
Debugger runs are diagnostic only, including one timeout.


## Rounded-image corrections: Lobsters is pixel-exact

The registered 33-response Lobsters archive now differs from the unchanged
Brave reference at **0 / 786,432 pixels in both fresh native captures**.
Both reduced controls, `avatar-colored-clip` and `avatar-jpeg-fractional`, also
match at zero in both fresh captures. Each browser process exits 0, with complete
document readiness, matching title/URL, the required body-content audit and a
1024×768 document viewport at scale 1 for the full page. Executable and runtime
asset identities remain unchanged throughout the group.

The completed production executable is SHA-256
`5e955a71137d93413c5ea9e0f552a2ec620f9e642f1b031f704134af831ae56d`,
managed receipt `20261112-112147-2dee6b0d`. The build began at `0a77dd3bf`;
its verified parsed/native snapshot records `03bd136ee`. The rounded-image
native adapter, V raster, tile sample selector and prepared GG image adapter
hashes match the committed implementation. This remains a single-C-unit,
literal `-prod` build. The guards and managed publisher were retained.

The additional fixes are:

- `8cbe1e8c2`: local JPEGs use the fetched-image decoder and pixel dimensions.
  AppKit interpreted the 16×16 control's 96-DPI metadata as 12×12 points,
  bypassing the intended paint path. Its two production captures improved
  from 156 to 18 differing boundary pixels.
- `d3e5cd3de` and `d74d3bab8`: combine rounded coverage with source color in
  V/GG, retain photographic RGB as floats until the pixel store, and preserve
  the document-to-canvas translation including chrome and scrolling. The
  unscaled small-image path declines unsupported formats, transforms, scales,
  opacity, clipping and mixed-sample tile boundaries to the existing painter.
- `03bd136ee`: use the texture shader and the document tile's multisample
  selection. The first raster tile required four samples. Treating each
  texel as a solid fill changed its clipping behavior; byte and floating-point
  textures reproduce both its PNG and JPEG crops exactly.

Normal and preallocated/no-GC focused GPU tests match immutable Brave crops,
including padded rasters and the multisampled tile. Application tests cover
local JPEG dimensions, the cache collision, floating source transport, the
native CoreGraphics boundary, a 60-pixel chrome offset and sample selection.
Separate native test-binary reruns pass under the 3 GiB runtime guard; browser
module compilation uses the 12 GiB guard. The 11 preparation compatibility tests
pass, including minimal GG modules without the optional layer API. New source
and reference controls are committed; generated diagnostics remain local.

Rejected production results remain in the evidence:

| Executable prefix | Full Lobsters differences | Finding |
| --- | ---: | --- |
| `b0d98845` | 178, twice | Cache correction works; avatar boundaries remain |
| `ffa969bd` | 178, twice | Local JPEG control improves to 18 pixels |
| `e89fe8ea` | 2,954, twice | Rejected: new raster omitted the chrome offset |
| `3678cf92` | 47, twice | Translation and float color fixed; three avatars in the multisampled tile remain |
| `5e955a71` | **0, twice** | Texture shading and tile sampling match the retained Brave image |

Earlier failures are not erased by this pass. Rejected builds include changed
native headers and the generated `vox2.c` input during compilation. A final
focused recheck initially used the unprepared GG library after a concurrent
shadow API change; rerunning with production's prepared GG module passes in
both memory modes. No reference was regenerated from Vox and no tolerance was
relaxed. The pixel-diff tool, commands, fixture bodies, audits, exact counts,
failures, source identities and guard reports remain under
`docs/performance/lobsters-rounded-20261112/`.

This accepts the frozen Lobsters viewport above. It does not reaccept the other
catalog pages, live/interactive behavior, whole-document scrolling, scale 2 or
any CPU/FPS result. The all-site task remains open. The Wikipedia investigation below follows
this Lobsters milestone.


## Wikipedia numeric-direction correction

Wikipedia is now **0 / 786,432 differing RGBA pixels in both fresh captures**
against the unchanged Brave portal reference. Both the four-row numeric bidi
control and the fallback-font control are exact twice; Lobsters remains exact
in two fresh regression captures under the same bundle lease.

- Production executable SHA-256:
  `ceed0de7fca9cbcb7d03972db94189ead1cc37a0378c3034c837e6682dad1c72`.
- Managed receipt: `20261112-123123-60187c40`; verified source head
  `6b8993a705f70ce98dae5a766e894e86873c6e8e`, dirty-input receipt retained.
  Relevant source hashes match the completed numeric-direction commits.
- Same sealed 15-response archive, URL, 1024×768 viewport, backing/capture
  scale 1, private profile/cache, disabled author scripts and five-second
  settling as the initial audit. Every native process is fresh; document
  identity, readiness, content and viewport audits pass with browser/guard
  exits 0. Fixture/reference/tool hashes and executable/library identities
  remain unchanged throughout the grouped checks. OS caches are retained.

The initial 445-pixel failure consisted of the Persian count line (443) and
two wordmark pixels. Resolving only a numeric chunk's shaping direction
(`d21dd0c2b`) leaves 430 pixels. Resolving separate text/font fragments together
with ICU paragraph levels (`d82dd35d4`) leaves 70. Keeping number and neutral
levels separate before font fragmentation, and honoring resolved RTL for ASCII
neutrals (`9881fffec`), leaves 26. The reduced same-font control is exact at
that stage, while its system-font/fallback version reproduces the remaining
26-pixel failure.

The final correction (`6b8993a70`) retains the precise advance when an RTL
fragment combines the plus and its space, rounding their total once. Previously
rounding each chunk separately moved the adjacent number by 1/64 pixel and
selected a different quarter-pixel mask for one Persian digit. The two wordmark
pixels disappear in the concurrently updated renderer; no isolated credit for
those two pixels is assigned to the numeric changes.

Focused application tests execute the paragraph layout and display-list path,
including split Persian spans, adjacent Latin spans, RTL attributes, explicit
overrides, translation-policy preservation and the fractional-advance case.
They pass under the 3 GiB runtime guard after the 12 GiB compilation guard.
Platform tests execute level resolution and ASCII neutral shaping in normal
and preallocated ownership modes. New control references come from two agreeing
fresh Brave processes; the fallback count crop also matches the original portal
exactly. References and the zero-error gate are unchanged.

A screenshot-tool correction (`140afa2e4`) removes animation-callback waits for
script-disabled pages. Its 14 tests and real Brave capture pass; its numeric
control matches the earlier reference exactly. A separate Brave geometry
probe uses different form-control launch flags and differs at 1,728 search-form
pixels. It supplies only character geometry, never a replacement acceptance
reference. The original timeout, the standalone layout test stopped by the
12 GiB guard, partial pixel failures and production source-guard rejection are
retained locally under `docs/performance/wikipedia-numeric-20261112/`.

The all-site gate remains open. vlang.io still differs at **309,681 pixels in
both fresh captures** of the same script-disabled archive under the
`1522067f` bundle (initial audit: 309,884); these are mostly small gradient
color differences. The clipped CSS gradient GPU entry points currently decline
the draws and use the CoreGraphics fallback, which is the next investigation.
CNN, GitHub and the unavailable account-bearing Reddit workload remain open.
These are frozen viewport results, with no new live-site, scale-2, interaction,
scrolling or instruction-performance acceptance claim.


## CSS gradient GPU correction

`f76294b85` restores eligible CSS linear and radial gradient draws through the
V document GPU tile renderer. The native entries previously declined every
such draw, leaving CoreGraphics to choose different interpolation and rounding.
The bridge now preserves premultiplied stops, rounded and ancestor clips,
backdrop pixels, tile gutters and per-tile sample selection.

Production executable
`7f74bcb7355130ccc4d2cc51e8f02e2e8baf2a902d32f16a2159d0fdc7a77069`
(receipt `20261112-132807-5c76223f`, feature source hashes verified) reduces the
unchanged vlang.io archive from **309,681 to 70,357 differing pixels**, in both
fresh captures. The original Brave reference is unchanged; vlang.io remains
open. At their existing scale-one viewports, `css-radial-gradient`,
`css-premultiplied-fades` and `radial-gradient-float-geometry` each match exactly
in two fresh production captures. Wikipedia and Lobsters also remain exact in
both repeated captures. Content, readiness, viewport, executable and resource
identity checks pass.

The focused test executes six real gradient draws through the native pixel
boundary and GPU renderer, checking exact reference pixels, mixed backgrounds,
rounded clips, tile seams and browser chrome offsets. Normal ownership and the
prepared preallocated runtime pass. An initial run using an unprepared
preallocated compiler crashes in PNG decoding before the draw; that failed run
is retained. `59d80db2f` adds a focused entrypoint test which calls the real
browser startup. Its mandatory headless smoke passes, and two diagnostic
captures reproduce the production vlang.io pixels exactly. These unoptimized
diagnostic captures supply no production or performance acceptance.

Raw baseline, control and production receipts are local under
`docs/performance/vlang-gradients-20261112/`. GitHub's unchanged archive still
has **38,656** differing pixels in both follow-up captures. CNN and the missing
account-bearing Reddit fixture remain open. No live-site, Retina, scrolling or
instruction-performance acceptance is claimed.


## Promoted shadow raster bounds

`3878a38b1` clips ordinary root-scrolled promoted pictures to the scrollable
document before choosing their GPU tiles. Brave's compilation-panel picture
starts at x=0; Vox previously included its shadow at x=-58, incorrectly choosing
three half-width tile columns and shifting the gradient dither coordinates.
The focused application test checks both viewport-width and horizontally wider
documents. It executes successfully under the 3 GiB guard after a 12 GiB
compilation guard. The initial standalone layout test compilation reaches the
12 GiB limit and is retained as a failed attempt; it supplies no runtime result.

Production executable
`296a9fa4b2e908a8e0447010f1cbe635fc62ad076fd7d0c4d5c7895bd6c320bb`
(receipt `20261112-135812-f195c746`, matching feature source hashes) reduces the
unchanged vlang.io archive to **28,961 differing pixels in both fresh captures**.
The three existing gradient controls, Wikipedia and Lobsters each remain exact
in both production captures. All content, readiness, viewport and identity
checks pass. Two additional Brave diagnostic captures preserve the original
reference exactly with and without a process device-scale override; re-enabling
LayerTree observation exposes the document-clipped panel bounds. Neither probe
changes the acceptance reference.

A reduced shadow/gradient reproduction improves from 110,185 to 7,478 differing
pixels, but retains separate shadow and small gradient-rounding differences.
It is diagnostic, with no relaxed tolerance or full-parity claim. vlang.io's
remaining panel differences follow its rotated orbit decoration. Further shadow
and image corrections, CNN, GitHub and the unavailable Reddit workload remain
open. Raw diagnostics and production receipts are retained locally under
`docs/performance/vlang-gradients-20261112/`.


## Rotated and short rounded shadow corrections

`9ac4bf9ab` keeps rotated elliptical shadows on a bounded V/GPU image-filter
path, rather than falling back to CoreGraphics. Uniform rotations use the
transformed source bounds and the corresponding isotropic kernel; shear and
unequal scales keep their fallback. The new focused test executes both a
rotated ellipse and its equivalent axis-aligned geometry and requires exact
RGBA equality, visible outer blur and an empty clipped interior. Existing
unblurred-shadow and six nine-patch reference hashes also pass. A standalone
native include correction avoids Cocoa math macros colliding with V's C
prototypes; the initial compiler failure and successful rerun are retained.

Production executable
`a484d15d68d391366a0b66099091630984da22ab7ef835d66f4aaed870abc9e8`
(receipt `20261112-140916-7a45d7d6`, source hashes matched to the committed
feature) reduces vlang.io to **9,054 differing pixels in both fresh captures**.
The diagnostic rotated-orbit reference improves from 26,238 to 1,901, in both
captures; its two independent Brave captures agree exactly. It remains a
known failing diagnostic, never a relaxed acceptance reference.

`7c97385d9` also filters axis-aligned rounded shadows when the short dimension
cannot hold a nine-patch. The focused GPU test exercises short and asymmetric
corners, visible blur, the clipped interior and a pixel beyond the finite
filter bounds. Its first assertion incorrectly expected a pixel inside the
blur extent to be empty; the retained failing run is followed by a corrected
geometric assertion and passing runtime check.

Production executable
`2f6e12170d69a41b13c09970556d3c3fda455b72a72872e021ba8fb7090f6d3e`
(receipt `20261112-141300-a1768de5`, matching feature inputs) reduces the same
vlang.io archive to **6,738 differing pixels in both fresh captures**. For both
shadow corrections, the three gradient controls, Wikipedia and Lobsters remain
exact in two fresh production captures each. Content, readiness, viewport,
reference and executable identity checks pass. Compilation uses the 12 GiB
guard; focused runtime checks use 3 GiB. The remaining image, text-mask and
shadow differences keep vlang.io and the all-site gate open. Raw attempts,
commands and receipts remain local under
`docs/performance/vlang-gradients-20261112/`.


## Gradients inside transparency layers

`eac42f21f` also renders eligible CSS gradients in transparent native groups,
including background text masks. These groups receive a transparent GPU raster
and retain their existing native clipping and composition. The focused native
boundary test requires an opaque gradient to produce identical pixels with
and without a transparency layer; the six earlier gradient draws remain exact.
An initial test incorrectly encoded its stop tuple as position/RGBA rather
than RGBA/position and is retained alongside the corrected passing test.

Production executable
`8bdf8c3a0f29f8041c325bfc13f6f1ac167e0073773cbb4556bd8fee54fa1925`
reduces the unchanged vlang.io archive to **6,287 differing pixels in both fresh
captures**. The existing text-gradient controls improve from 15,068 to 8,686
and from 5,196 to 4,423 respectively, with both repeated captures agreeing;
they remain failures. The compositor-gradient control retains its existing
one-pixel failure. The three ordinary gradient controls, Wikipedia and Lobsters
remain exact in both fresh production captures. Matching feature inputs,
reference/resource hashes, complete document identity, viewport and normal
exits are recorded under `docs/performance/vlang-gradients-20261112/`.


## PNG decode, GPU filtering and rounded clips

`283a01512` restores the bounded CPU decode-size/mipmap path and the GPU's
trilinear image sampler for complete, static, untagged PNGs. It reuses the
existing Q15 CPU bilinear sampler exposed by `a59948164`, premultiplies alpha
before resizing, preserves natural-image coordinate arithmetic, and keeps
resource URL, document generation and compositor scope in decode identities.
Video posters use the same path only when their immutable paint snapshot still
belongs to the current document and resource. Live frames retain their path.
Tagged images, animation, transforms, source crops, opacity and unsupported
capture scales keep the existing renderer.

`2e749d85f` carries rectangular and rounded overflow clips into the same GPU
image draw. The new 600×160 diagnostic has two exactly agreeing Brave
157.1.99.56 references, captured before the correction with scripts disabled.
It improves from **2,143 differing pixels to zero**, twice. The focused GPU
tests require unchanged Brave logo pixels, with and without rounded clipping,
and preserve every pixel outside a rectangular crop. Cache/ownership tests,
alpha and odd-size CPU mip tests, the existing rounded-image/shadow checks,
and all eleven UI2 preparation tests pass under their required guards.

Production executable
`303a768fe0f94a3b22c129a1cc3f471e0c7dad8c932527fed35d79831efe5511`
(receipt `20261112-154007-d64f9163`) contains both corrections. Exact compiled
source hashes match the V/native implementations, CPU sampler and prepared GG
image shader inputs. With the unchanged archive, reference, viewport and
script policy, **vlang.io improves from 6,287 to 4,144 differing pixels in both
fresh production captures**. Image resource reuse, compositor reuse, the
first-use image/video-poster mip control and the rounded PNG diagnostic are
all exact twice. Wikipedia, Lobsters and the three ordinary gradient controls
remain exact twice. GitHub improves from 38,654 to **38,404**, twice, with all
33 row identities preserved. No reference or tolerance was changed.

Additional diagnostic controls retain their existing crop, ICC and scrolling
failures; the rounded transformed-image control improves from 21,076 to 571,
twice, and translated minification stays exact. These results do not establish
full image-cache or color-profile parity. vlang.io still differs in its tagged
Mastodon image, JPEG icon, text mask and orbit decoration. CNN and the missing
Reddit archive remain open as described above.

Every attempt remains local under `docs/performance/vlang-gradients-20261112/`.
This includes the corrected crop-test assertion, an early source-guard rejection
when the native header changed during input collection, and two diagnostic
commands with misspelled fixture names. The local capture driver now validates
all fixture/reference paths before launching; the final complete production
command and every browser/guard exit pass. Completed job binaries and generated
C are removed from `Build/`; raw commands, identities, PNGs and receipts are
retained locally.

## Tagged PNG color conversion

`7defc6a8c` converts supported legacy PNG gamma/chromaticity metadata into an
8-bit sRGB texture before final filtering, then regenerates its GPU mip levels.
The unchanged Mastodon image on vlang.io becomes exact: its 24×24 crop improves
from 475 differing pixels to zero. The unchanged whole-page archive improves
from 4,144 to **3,669 differing pixels**, agreeing in two fresh diagnostic
captures. Its JPEG icon, text mask and decorative shadows still differ.

The new legacy-gamma PNG diagnostic is exact twice against two independently
agreeing Brave references. Focused profile parsing, GPU conversion, odd-sized
GPU mips, rounded clipping and cache/ownership checks pass. The converted upload
also matches the independently captured former renderer's bytes exactly;
alpha and source bytes remain unchanged. Wikipedia, Lobsters, ordinary
PNG/gradient controls and image/poster resource reuse remain exact twice.
GitHub remains at 38,404 differing pixels with all 33 row identities preserved.

These are **diagnostic results**, from an unoptimized browser built with the
current compiler and its matching libraries. Production validation is pending:
the shared completed bundle predates this correction. Later managed build
attempts failed with a mismatched shared compiler/library installation, then
with compiler-manifest verification; they did not replace the completed bundle.
The fail-fast compiler probe in `2cd7046ea` rejects the mismatched installation
without falling back to an older compiler. All attempts and their actual exits
remain local under `docs/performance/vlang-gradients-20261112/`.

## Retained glyph coverage in background text masks

`6520e253a` routes eligible horizontal Chromium-policy mask glyphs through the
same V/CPU glyph rasterizer as ordinary document text, preserving black paint
for its color-dependent coverage adjustment. The native bitmap boundary keeps
the original paint clip while aligning the mask image to device pixels. Emoji,
unsupported faces and other declined runs retain the existing fallback.

Diagnostic executable
`dbc14bc451668364c65b1d962c7622f086f44cb415b528cb4a3134b73d1157d2`
reduces vlang.io from 3,669 to **3,250 differing pixels**, twice. The existing
retained-gradient control improves from 8,686 to 3,752 differing pixels, all
with maximum channel error one. The new fractional-position/overflow diagnostic
improves from 13,044 to 7,725, also with maximum channel error one. Its two Brave
reference captures agree exactly. The existing scope control improves from
4,423 to 2,939; its separate shadow/SVG errors remain, including maximum error
14 outside the text mask. The compositor-gradient control retains one error.
These remaining differences are failures under the unchanged zero-tolerance
gate, including the single-channel rounding differences.

Wikipedia and Lobsters remain exact in two fresh diagnostic captures each.
GitHub remains at 38,404 with all 33 row identities preserved. The compiler,
mandatory non-windowed startup check, document readiness/viewport/content audits,
reference/input identity checks and every browser exit pass. Compilation peaks
at about 6.2 GiB under the 12 GiB guard; captures use 3 GiB guards. Initial
pointer-view and exported-C declaration compile errors are retained alongside
the corrected passing build. Production validation remains pending on the
managed build; these results do not validate the older completed bundle.

## Production receipt isolation and next GitHub investigation

The new failure receipts from `f66e7fad8` identified two different compilers'
inputs in the same receipt: 311 V build-tool sources followed by 393 browser
worker sources. `8950af241` removes the ambient manifest destination only from
the V tool bootstrap environment. The supervised compiler still receives its
explicit manifest destination and keeps the existing source-verification gate.
The focused environment test passes, and a real compiler probe leaves both
pre-existing receipt files byte-for-byte unchanged. The managed attempt
`20261112-194619-964c3f1f` passes source verification and reaches sealed C
compilation with the tagged-PNG and text-mask corrections included. Production
pixel validation is still pending until that attempt publishes successfully.
An idle upgrade worker holding and waiting for its own inherited build lock
was stopped with its launch wrappers; no active compiler or memory guard was
terminated. The identities and lock evidence remain local.

Two additional Brave captures of the unchanged GitHub archive agree exactly
with the original reference. Read-only geometry audits locate a 0.75px header
height discrepancy (Vox 69.75px, Brave 69px), shifting the directory below it.
The fork/star links' containing list items are 28.75px in Vox versus 28px in
Brave. Reduced button/grid/counter cases currently match Brave at 28px, so
these findings do not yet justify an engine change or establish a GitHub fix.
Two standalone layout-probe compilations hit the 12 GiB memory guard; the
selected root-harness probe compiles and runs successfully within its guards.
All raw attempts, successful captures and failed compilations are retained.

## Production confirmation after PNG and text-mask corrections

Production executable
`081a75f66fbda26d5df97732bce84bfdb4664ea73257ee19ec3f9f381b474829`
(receipt `20261112-202158-a889a56c`, C backend, literal `-prod`, single C unit)
contains `7defc6a8c` and `6520e253a`. Exact compiled source hashes match the
profile parser, GPU conversion, CPU image sampler, native image boundary,
prepared GG shader inputs and retained text-mask implementation. This
supersedes the pending-production qualification for those two fixes above.

| Catalog workload | Differing pixels, each of two fresh production captures |
| --- | ---: |
| Hacker News, original six-response archive, scale 2 | **0** |
| Lobsters, registered guest archive, scale 1 | **0** |
| Wikipedia portal archive, scripts disabled, scale 1 | **0** |
| vlang.io archive, scripts disabled, scale 1 | **3,250** |
| GitHub archived hydrated DOM, all 33 row identities preserved | **38,404** |
| CNN registered archive | **175,866** |

HN retains all 30 story identities. Its PNGs match the unchanged Brave reference
from the initial audit. CNN's two native PNGs now match each other exactly;
this does not clear its cross-browser failure or the earlier source/replay
mismatch. Concurrent changes are included in this production build, so the CNN
change is not attributed to either rendering correction. Reddit remains
unverified because its historical fixture is missing; no workload was
substituted. These checks establish frozen-viewport results, not live-site,
whole-document or interactive parity.

The legacy-gamma and rounded PNG diagnostics, first-use image/poster mip,
image-resource/compositor reuse and all three ordinary gradient controls remain
exact twice. Text-mask diagnostics retain 7,725 and 3,752 differences; the scope
control retains 2,939 and the compositor-gradient control retains one. Their
nonzero results remain failures with the original references and tolerance.

All 36 saved captures have normal browser/3 GiB guard exits, completed document
readiness and unchanged executable, native-library, fixture and reference
identities. A separate verifier rechecks every saved PNG, feature witness and
exit receipt and exits zero. FuseCode interrupted delivery of the original
capture driver's final CLI exit, so that outer exit is recorded as unknown;
it is not inferred from the completed observations. Earlier interrupted and
preflight-failed attempts remain alongside the completed results locally under
`docs/performance/vlang-gradients-20261112/`. Completed job directories, generated
C, diagnostic executables and guard files are removed from `Build/` after their
evidence is retained. **The all-site zero-error gate remains open.**

## Root baselines in reused flex measurements

`08cbf34dd` fixes the largest remaining GitHub layout discrepancy. A column-flex
ancestor caused measured flex geometry to be promoted into final layout. The
cache restored descendants but cleared the flex root's published baselines.
Synthesizing them again through the descendants produced a different result,
expanding the header from Brave's 69px to 69.75px and shifting the directory.
The cache now owns and restores both horizontal and vertical baseline sets;
root offsets and percentage bases remain owned by the current caller.

Diagnostic executable
`1b19003f1fe81cf29758d86821cb5eb37e7498fd9778f004634609b8dc5a9324`
reduces the unchanged GitHub archive from **38,404 to 1,083 differing pixels**
in two fresh captures, with every one of the 33 row identities preserved.
Wikipedia and Lobsters remain exact twice; vlang.io remains at 3,250 twice.
The startup smoke check, all capture/content/identity checks and the complete
comparison driver exit zero. This is an unoptimized diagnostic executable;
production validation awaits the managed post-commit rebuild.

The new focused test confirms that row and column flex cache hits restore the
measured baselines instead of stale caller values, and verifies borrowed line
storage to establish that the cache was actually used. The existing committed
geometry test now compares baselines with its measured producer and uncached
oracle. These tests, the cache-miss checks and the external-height dependency
checks pass with arena poisoning under a 3 GiB runtime guard. Compilation uses
the 12 GiB guard and peaks near 6.2 GiB. The selected root test harness includes
the layout implementation files and focused tests explicitly; generated test
calls were checked so an empty selector cannot supply a false pass.

Retained diagnostics narrow the trigger from the whole page to its column-flex
ancestor chain. Individually disabling committed flex measurement reuse or
unused-height matching restores the 69px header; disabling grid or inline reuse
does not. Moving the grid baseline reset and retaining descendant line boxes
both leave GitHub at 38,404 twice, so those candidates were reverted. Initial
standalone test builds reached the memory guard; an incomplete module selection
was stopped after a compiler sample identified unknown-type diagnostics, and
an empty test selector was corrected before executing the final tests. All
attempts remain local under `docs/performance/vlang-gradients-20261112/`.
The original references and zero-error gate are unchanged; GitHub still fails
at 1,083 pixels and the all-site task remains open.


## Production flex confirmation and table percentage precision (2026-11-13)

Production executable
`86516f7f2eb9c44f78173c2a4f7acd12834c9d31bb24aa1a7954ec0dca640234`
(receipt `20261112-220611-a7923f72`) contains the root-baseline cache correction
`08cbf34dd`, verified against its exact compiled source manifest. Two fresh
captures confirm GitHub at **1,083 differing pixels**, preserving all 33 row
identities. HN, Wikipedia and Lobsters remain exact twice; vlang.io remains
at 3,250 twice. HN retains all 30 stories. All ten capture guards and the
complete driver exit zero. This clears the preceding pending-production
qualification for the flex correction only.

`7077ea544` fixes a separate percentage-column rounding discrepancy. Brave's
fixed GitHub table gives its 40% column 258.390625px from a 646px grid. Vox
rounded this percentage to the nearest 1/64px, yielding 258.40625px and shifting
commit text across glyph raster phases. Chromium policy now truncates the
percentage guess before adding box-model offsets, for both fixed and auto
tables. LibWeb policy keeps its existing rounding. A reduced Brave probe
independently confirms both modes. Fresh full-page Brave geometry captures
still match the original GitHub reference exactly.

Diagnostic executable
`a4da33d01cd1e0166e90b681921ac347a5f9b63f7823036fd4476107cd98b8d8`
reduces GitHub from **1,083 to 303 differing pixels** in each of two fresh
captures. All table text now agrees; remaining differences lie above the
table. All 33 rows retain their identities. HN, Wikipedia and Lobsters remain
exact twice, vlang.io remains at 3,250 twice, and CNN remains at 175,866 twice.
The startup smoke check, all 12 capture/content/identity checks, their 13
memory guards and the complete driver exit zero. The focused regression test
executes both table modes under both rendering policies; it and the existing
surplus-distribution test pass with arena poisoning under the 3 GiB guard.
Generated C confirms both selected test calls execute. Guarded compilations
peak near 6.3 GiB and finish normally. Production validation of the table fix
awaits its managed rebuild; the diagnostic result does not validate an older
production executable.

The initial auto-only attempt leaves GitHub at 1,083 pixels and is retained
locally alongside the corrected fixed-layout attempt, reduced Brave geometry,
commands, raw PNGs, audits, identities and actual exits under
`docs/performance/vlang-gradients-20261112/`. References and zero tolerances
are unchanged. CNN's earlier source/replay failure, vlang.io, Reddit and the
all-site gate remain open. No live-site or performance claim follows from
these frozen viewport checks.


## Fractional image clips and outer shadows (2026-11-13)

Three further corrections keep floating-point geometry through Chromium replay:

- `cd5261e7d` preserves replaced-image and video corner radii after border
  insets. The integer corners in the portable paint result had changed the
  GitHub avatar's 4.5px horizontal radius to 4px. A separate instrumented
  capture confirms that the PNG renderer executes; platform fallback is not
  responsible for this discrepancy. LibWeb's portable paint result is unchanged.
- `3b1e1fd03` selects tile multisampling when an image clip needs path rendering.
  The decision queries the renderer's analytic-clip capability, including its
  circular-radius tolerance. The isolated unshadowed 9×20 ellipse now matches
  Brave without an unrelated SVG path enabling multisampling.
- `ffdd1cf49` preserves outer-shadow offsets, blur, spread and radii when the
  device/layout conversion is one or the document density is one. These cases
  previously entered integer shadow resolution. LibWeb, inset shadows and the
  explicitly requested legacy snapping policy retain their existing paths.

| Diagnostic executable SHA-256 | GitHub differing pixels, each of two captures |
| --- | ---: |
| `eb715e6d70f23f542807b10192c00769171e34f11eaf9f9afe6b3899d1685531` — fractional image corners | **287**, down from 303 |
| `e49ec5b12bd44d14704a38cee04910f7295950c96f221c7cab7fe14d6d32aab9` — image-clip multisampling | **287**; this page's relevant tile already used multisampling |
| `ee72bd3da0790d6dab29f980a26579d11f39b1eb0ecaa1c31a953deaf98f5a7a` — fractional outer shadows | **231**, maximum channel error 16 |

Each cohort retains all 33 GitHub rows and all 30 HN stories. HN, Wikipedia and
Lobsters remain exact twice in every cohort; vlang.io stays at 3,250 and CNN at
175,866. Seven existing image/poster controls remain exact twice: rounded,
colored and fractional-JPEG avatars, first-use mip, image-resource reuse,
rounded scaled PNG and rounded video poster. Each complete driver exits zero,
including its startup smoke check, 30 captures, content audits and identity
checks. These are diagnostic executables, not production validation.

The isolated avatar probe initially differs at 139 pixels across its three
images. Fractional radii reduce this to 82; correct tile multisampling reduces
it to 76; fractional shadows reduce it to **15**, all with maximum channel error
**1**, confined to the shadowed image. Its unrounded and unshadowed elliptical
images are exact. The control with an additional SVG path agrees with the
ordinary probe after the multisampling fix. Neither residual result passes the
zero-error gate.

The scale-2 device-shadow control improves from **12,966 to 92 differing pixels**
in both corrected captures per executable. Its original reference is
1600×1200 for an 800×600 CSS-pixel viewport. An initial control run incorrectly
used a 1600×1200 CSS viewport at scale 1 and differed at 41,790 pixels; that
attempt is retained and excluded from the before/after claim. Both corrected
arms use the original reference, scale 2 and the same viewport. The remaining
92 pixels, maximum error 6, still fail. Eight other shadow controls retain their
baseline results: box-shadow blur 3,301; opaque shadow 26; inset shadow 16,588;
padding-background shadows 38,584; fractional underlay 0; fixed fractional-color
shadow 0; overlapping shadow boxes 1,941; rounded inset shadow 15,550.

All thirteen selected focused test functions execute and pass with arena
poisoning under the 3 GiB guard: five image/video clip cases, four tile cases
and four layout/shadow cases. Generated C records their actual harness calls.
The shadow regression exercises Chromium and LibWeb at densities 1 and 2;
existing opaque cutout and translucent-border tests also pass. Compilations
finish under the 12 GiB guards, peaking below 6.4 GiB. The eleven UI2 preparation
tests pass. Failed adapter compilations and control preflight/scale attempts
remain with the successful commands, raw PNGs, audits, input hashes and actual
exits locally under `docs/performance/vlang-gradients-20261112/`.

The latest completed production executable remains `86516f7f…`, predating the
table and these three corrections. Managed post-commit rebuilds are requested;
no duplicate production build is queued for this audit. Production validation
remains pending. References and tolerances are unchanged, Reddit's original
fixture is still missing, and CNN's source/replay mismatch remains open. No
live-site, whole-document or performance claim is made. **The all-site gate
remains open.**


### Native repeatability follow-up

A separate final check of decoded RGBA pixels confirms exact native repeats
for GitHub, HN, Wikipedia, Lobsters and vlang.io in all three new cohorts.
CNN remains unstable: the fractional-corner cohort's two native captures differ
at **1,030 pixels** (maximum channel error 37), the multisampling cohort repeats
exactly, and the fractional-shadow cohort differs at **1,007 pixels** (maximum
error 22). Both failures occupy the same 104×15 region beginning at (460, 753),
inside a photograph clipped by the viewport. Equal cross-browser counts of
175,866 did not establish native repeatability. These observations reopen the
native-stability qualification after the earlier production checkpoint; they
are not attributed to a particular correction. The original image resources
and both failed repeat comparisons remain local with the other evidence.


## Production confirmation of fractional geometry corrections (2026-11-13)

The completed production executable
`5fb3eb909ae426b7cfcb1b0e8a67ab494177d13b0a0f693d5ae5d1e737561576`
(receipt `20261113-011934-947f0697`, C backend, literal `-prod`, single C unit)
contains the table precision, fractional image-corner, image-clip multisampling
and fractional outer-shadow corrections. Exact compiled source hashes match
these implementations and the preceding rendering fixes, including the prepared
GG image, layer and surface inputs. This supersedes their pending-production
qualification above.

Two fresh production captures of each catalog archive confirm GitHub at
**231 differing pixels**, HN/Wikipedia/Lobsters at **0**, vlang.io at **3,250**
and CNN at **175,866**. All 33 GitHub rows and all 30 HN stories are preserved.
The seven image/poster controls remain exact twice, and the corrected scale-2
device-shadow control remains at **92 pixels** twice. All 28 capture guards,
content/viewport/identity checks and the complete driver exit zero. All
references and zero-error tolerances are unchanged.

Decoded native pixels repeat exactly for GitHub, HN, Wikipedia, Lobsters and
vlang.io. CNN's two native images differ at **1,555 pixels**, maximum channel
error **127**, again confined to the same 104×15 photographic region beginning
at (460, 753). Thus production confirms the CNN stability failure as well as
its cross-browser mismatch; equal cross-browser counts do not clear it.
The all-site task remains open. Raw captures, feature witnesses, production
receipt, commands, repeat comparison and actual exits remain local under
`docs/performance/vlang-gradients-20261112/`.


## Rotated thin border sides (2026-11-13)

`867f88d6f` fixes GitHub's breadcrumb separator: a rotated, one-sided border
whose 1px thickness fills its 1px-wide box. Its fractional 11.1875px height
and the full-width side had excluded it from rectangle painting. The fallback
painted a joined path with different edge coverage. Chromium now records this
side as a local antialiased rectangle, snapping its dimensions while preserving
the layout origin and replay transform. `695af8b0d` retains the joined-path
fallback when multiple sides overlap after dimension snapping. Non-finite and
empty snapped boxes also retain their fallback.

The new `rotated-collapsed-border` fixture covers thin right, left and bottom
sides plus a wider control. Two fresh, identity-pinned Brave **157.1.99.56**
processes match its reference exactly. The production baseline differs at
**100 pixels** in both native captures; the candidate is **exact** twice.
Existing site references and tolerances are unchanged.

Final diagnostic executable
`b588c878778dcc00851c8646c055e23f33aa233e4d3ab719d9c5e39d371160ea`
reduces GitHub from **231 to 207 differing pixels**, in two fresh captures,
preserving all 33 rows. HN retains all 30 stories and remains exact, as do
Wikipedia and Lobsters. vlang.io remains at 3,250; CNN remains at 175,866 and
still fails native repeatability in the same cropped photograph. All other
catalog pairs repeat exactly within the cohort.

The seven image/poster controls remain exact twice. Transformed partial borders,
transformed border offsets and the scale-2 rounded-side control stay exact;
the existing rounded-partial-border control keeps its seven-pixel failure.
The scale-2 device-shadow control remains at 92. All 38 final captures, their
startup smoke check, 39 memory guards and the complete driver exit zero, with
unchanged implementation/test input hashes. Six focused border tests execute
and pass with arena poisoning under the 3 GiB runtime guard, including live
transform replay, fallback preservation, snapped overlap and non-finite inputs.
Generated C confirms the selected harness calls.

Initial setup failures from a transient build-tool helper error, concurrent
module preparation and an unrelated in-progress shader syntax error remain
local alongside successful runs. Prepared modules were reused for the final
compilations; sources remained in the canonical checkout. After the completed
cohort, the shared diff executable became unavailable. Its replacement passes
known exact and one-pixel controls before the independent pinned-Brave checks;
earlier results retain their original tool identity. No measurements or
references were replaced to obtain a pass.

Commands, identities, compilation/guard exits, raw PNGs and repeat checks remain
local under `docs/performance/vlang-gradients-20261112/`. The published bundle
above establishes the earlier fixes at 231 GitHub pixels; this border correction
awaits its managed production rebuild. **GitHub's remaining 207 pixels and the
all-site gate remain open.**


## Small rounded-shadow kernels, 2026-11-13

Commit `a2427d085` handles device-space Gaussian sigmas from 0.5 through 1
in the V/GG rounded-shadow filter instead of falling back to the approximate
Core Graphics shadow. Kernels that fit in 28 taps use a single two-dimensional
pass, matching Chromium's filter. Two separate A8 passes add an intermediate
rounding step: the first attempt retained four exterior pixels at one channel
level in the sigma-0.5 case. Removing the nine-patch did not fix them; the
single-pass kernel does. The existing larger-kernel path remains unchanged.

The new `small-blur-shadows` fixture covers GitHub's two low-opacity green-button
shadows, sigma-0.5 and sigma-0.75 rounded rectangles, and a sigma-0.5 ellipse.
Two fresh, identity-pinned Brave 157.1.99.56 captures agree exactly. Both fresh
Vox diagnostic captures match that new reference at **all 53,760 RGBA pixels**.
The focused unit test independently checks the exterior bands at both sample
settings and verifies that smaller unsupported kernels leave their target
untouched. All six relevant shadow test files execute successfully with arena
poisoning under 3 GiB runtime guards: the new cases and the previous capsule,
nine-patch, short-rectangle, rotated-ellipse and unblurred-shadow tests. Existing
oracles and tolerances are unchanged.

The final diagnostic executable is
`1a0939c8bbd7175d36a096df9eefec7ad280117fcaf5feed7340f0b1cc630a39`.
It reduces the unchanged GitHub archive from **207 to 49 differing pixels**
in two fresh captures, with the complete 33-row audit and the document at its
reference origin. HN keeps all 30 stories and remains exact, as do Wikipedia
and Lobsters. vlang.io remains at **3,250**, CNN at **175,866**. CNN's two
successfully loaded images differ at **1,558 pixels**; its stability and
source/replay gates remain open. All other completed site pairs repeat exactly.
The seven image/poster controls and the rotated-border control remain exact
in both captures; the scale-2 device-shadow control retains its **92-pixel** gap.

Failed observations are retained separately. One preliminary GitHub capture
scrolled its body to y=-115 and differed by 348,134 pixels, while the next was
at the origin with 49 differences. The local driver now rejects that position
drift. The first larger run stopped when CNN navigated to an unavailable
article rather than its archived homepage; its driver exit is 1, despite a
browser/guard exit of 0. The later CNN/control run has the required URL/title,
complete audits, all browser/guard exits 0 and driver exit 0. The initial
unit-test failure, duplicate-file compile failure and unsuccessful half-precision
shader experiment are retained too. No failed attempt was turned into a pass.

The original six-box diagnostic scene changes from 2,020 to 626 differences;
all remaining differences belong to its unchanged unsupported sigma-0.25 box
or existing sigma-1 control. The new four-box fixture omits those controls;
it does not replace an existing reference or supply credit for their gaps.

Commands, input/executable/library identities, raw PNGs, failed attempts,
repeat checks and actual compile/browser/guard/driver exits remain local under
`docs/performance/vlang-gradients-20261112/`. The latest completed production
bundle is still the previously checked `5fb3eb90…` executable. The managed
post-commit hook requests the new production build; no additional manual build
was queued. **The 49-pixel GitHub result is diagnostic validation, and the
all-site gate remains open.** No live-site or performance claim is added.


## Production confirmation and scrollbar capture policy, 2026-11-14

The checkout moved from `vox2` to `vox`. Receipt
`20261113-103410-86416163`, literal C `-prod` in one unit, publishes executable
`07b5873dc78af20df3f730261db0fb44e79b6b7d061aa210bff1dcb4f9a0316c`.
The local audit resolves receipt paths against the relocated checkout and checks
all 27 rendering input hashes against the original manifest keys; it does not
rewrite the sealed receipt. This production browser confirms **49 differing
GitHub pixels**, twice, with all 33 rows and the reference origin, and **zero
HN differences**, twice, with all 30 stories. The seven image/poster controls
remain exact twice; the scale-2 device-shadow control remains at 92.

This run also exposed a capture-policy mismatch. Brave's canonical reference
launcher explicitly uses `--hide-scrollbars`. Vox suppressed capture scrollbars
only when AppKit preferred overlay scrollbars, allowing the persistent preference
to add a visible right-edge thumb. Raw production counts are retained:
small shadows 1,476; rotated borders 452; Wikipedia 1,724; Lobsters 2,636;
vlang.io 3,534; CNN 176,606, each twice. These observations fail equality and
are not silently relabeled as passes or removed from the viewport comparison.

The V capture policy now hides Chromium viewport scrollbars during screenshots
under either system preference, matching the reference launcher. Live visibility,
hover, drag, hold and fade retain their existing policy. Four focused tests
execute and pass under the 3 GiB runtime guard with arena poisoning, covering
both preferences and the live behavior. Initial test setup failures from a stale
compiler path and an incompatible HTTP module are retained with their exits.
The prepared compiler/module combination then compiles and runs successfully.

The first diagnostic runtime subsequently crashed twice in PNG realloc during
GitHub capture (browser/guard 139, driver 1). Its prepared runtime predates the
closure allocator restoration fix; both attempts are retained. The final
cohort uses a newly staged runtime containing those existing allocator hooks.
Candidate results and remaining gates are recorded below after that cohort. Existing references, pixel tolerances and historical instruction
statistics remain unchanged. This policy correction earns no rendering or
performance optimization credit.


Fix `e68a210c6` is validated by diagnostic executable
`de3dc74e85e1d12fba6034f51a67f594f415a3d6dbea9a8b319af3f80f4da622`,
using the current staged closure allocator runtime. Both focused fixtures are
exact in two fresh captures each. GitHub remains at **49**, HN/Wikipedia/Lobsters
at **0**, vlang.io at **3,250**, CNN at **175,866**, and the scale-2 device-shadow
control at **92**, each twice. All 18 completed captures, the startup smoke,
19 runtime guards and the final driver exit 0; source hashes and executable,
library, fixture and reference identities remain unchanged during the run.
The complete content audits retain all 33 GitHub rows and 30 HN stories.
CNN repeatability still fails at 1,558 pixels in the 104×15 photograph region;
all five other site pairs repeat exactly. The earlier production CNN pair
already differed at 1,477 pixels. Neither run establishes CNN stability.

The managed commit hook requests the normal C `-prod` rebuild. No duplicate
manual production build was queued. Production now confirms the earlier
rotated-border/small-shadow fixes at 49 GitHub pixels; the scrollbar-policy
correction itself still awaits production validation. Raw commands, identities,
guard exits, failed attempts and PNGs remain local under
`docs/performance/vlang-gradients-20261112/raw/scrollbar-20261114/`.
The all-site gate remains open, including the missing original Reddit fixture.


## Shared rounded outer decorations, 2026-11-14

Commit `93b2ed18e` keeps a rounded box's outer shadows, background and opaque
uniform border in one V/GG recording. The preceding per-leaf resolves rounded
sample colors before the next decoration blended over them. Grouping only the
background and border retains the corner error; retaining the shadow's samples
through the final border fixes it. The path accepts adjacent paints of one root
owner with matching transforms, ordinary circular corners, and no clips or
translucent border. Unsupported groups retain the existing replay path. Pending
backgrounds flush only after a complete supported group has been accepted.

The new `rounded-opaque-shadow-group` fixture reproduces the two-pixel corner
gap in two fresh production captures. Two fresh pinned Brave captures agree
exactly; the final diagnostic matches the full reference exactly twice. Its
small SVG trigger occupies the affected raster tile, reproducing the site's
MSAA configuration. An initial fixture placed that trigger in another tile and
its unit replay failed at eight pixels; those references and the failure remain
local. No existing fixture, reference or tolerance was changed. The focused GPU
test checks the exact corner band and verifies that separate resolves retain a
difference. The layout eligibility test executes with arena poisoning under a
3 GiB guard and preserves layer, clip, opacity, geometry and bleed-pair fallbacks.

Final diagnostic executable
`10283d26550631b4c8c076d10e15d39e62e8072cc48adebf4e9997cc8a6c9ca5`
reduces the unchanged GitHub archive from **49 to 39 differing pixels**, twice,
retaining all 33 rows and the reference origin. The ten corrected pixels are
the rounded action-button and branch-button corners. The remaining 39 are four
search-border pixels, twenty input-corner pixels and fifteen avatar pixels.
HN retains its 30 stories and is exact twice, as are Wikipedia and Lobsters.
vlang.io remains at **3,250** and CNN at **175,866**. All six site pairs repeat
exactly in this particular cohort; CNN's earlier native instability and its
source/replay failure remain unresolved. This change supplies no CNN fix.
The small-shadow and rotated-border controls stay exact twice; the scale-2
device-shadow control retains its **92-pixel** gap. All 20 final captures,
the startup smoke, 21 runtime guards and the complete driver exit 0, with
unchanged feature source hashes and pinned capture input identities.

Earlier cropped-surface probes, the stale/pruned font-module compile failure,
the background/border-only experiment and the preliminary complete cohort are
retained separately. Final compilation included the strict pair validator and
the deferred pending-background flush. Heavy host contention reached load
averages above 130 on 18 CPUs; no timing or instruction credit is claimed.
Commands, source/executable/library identities, PNGs, test calls and actual
exits remain local under
`docs/performance/vlang-gradients-20261112/raw/rounded-outer-20261114/`.

The managed commit hook requests the normal production rebuild. The last
verified production result remains 49 GitHub pixels; **39 is diagnostic
validation pending production**, and the all-site gate remains open.


## Inset-shadow alpha transport, 2026-11-14

Commit `83683f508` fixes a separate precision bug found while tracing the
remaining input corners. Inset shadow lowering dropped its retained sRGB
payload, and both the direct CPU inner-shadow path and general shadow tint
ignored the supplied fractional alpha. The inset command now retains that
payload in paint order; both raster routes honor the retained alpha. Existing
callers without an override retain the legacy path and its oracle hashes.

Fifteen focused tests execute successfully: six inner-shadow tests, seven
general-filter tests and two layout color-transport tests. The alpha regression
checks explicit RGBA8 results for quarter, three-quarter and opaque coverage,
including a geometry proven to decline the direct path and enter the fallback.
The layout checks retain fractional components and serialization in reverse
paint order while preserving the LibWeb policy. Runtime tests use 3 GiB guards;
the layout checks also use arena poisoning. A missing relocated harness link
caused an initial compile failure; the repaired canonical link and successful
commands are retained alongside it.

Final diagnostic executable
`17d86d6239fe90a7b0f44fcdf0dc4170013e53762ca0dbd042abb6fa0eabb5d6`
preserves the existing site counts in both fresh captures: **GitHub 39**,
**HN/Wikipedia/Lobsters 0**, **vlang.io 3,250**, **CNN 175,866**. The small-shadow,
shared-outer-shadow and rotated-border controls remain exact twice, and the
scale-2 device-shadow control remains at 92. All 20 captures, their 21 runtime
guards including startup smoke, and the complete driver exit 0 with unchanged
feature source hashes and pinned capture identities. CNN's two images differ
at 1,556 pixels; its historical stability and source/replay gates remain open.

This fixes the alpha transport/raster contract; it does **not** close GitHub's
twenty input-corner differences. The isolated coordinate probe omitted the
input's inset shadow and part of its comparison overlapped the adjacent button;
its 302/303-pixel results are retained as incomplete diagnostic evidence, not
an acceptance comparison. Remaining input coverage/sample ownership needs
further work. Existing references and tolerances were unchanged, and no
instruction, timing, live-site or all-site parity claim is added.

Commands, test-call witnesses, source/executable identities, guards, PNGs and
failed attempts remain local under
`docs/performance/vlang-gradients-20261112/raw/inset-alpha-20261114/`.
The managed hooks request production rebuilding; this fix's production
validation and the all-site pixel gate remain open.


## Unblurred inset-shadow geometry, 2026-11-14

Commit `7440a807d` replays eligible unblurred inset shadows through V/GG as a
square caster with a rounded hole, intersected with the retained content clip.
This follows Blink's `FillRectWithContouredHole` / `drawDRRect` geometry and
inverse-hole clipping rather than a generic compound rounded path. The caster
covers the content and its offset, including negative spread. Blur, inherited
clips, incompatible radii and invalid geometry retain the existing CPU fallback.
The surrounding tile keeps its existing analytic or MSAA selection.

The new `unblurred-inset-shadow` fixture has three ordinary CSS boxes, including
positive and negative offsets/spreads, without an artificial SVG trigger. Two
fresh pinned Brave 157.1.99.56 captures agree exactly; the final native browser
matches the full 1024×768 reference exactly twice. Twenty-five browser-module
tests execute successfully (three new geometry/eligibility/layout tests and the
22 existing MSAA-policy tests), plus two GPU tests for exact corner pixels and
failure without backdrop mutation. Runtime guards use 3 GiB and arena poisoning.
All compiler and runtime checks exit 0; generated test-call witnesses are retained.

The latest completed production bundle, SHA-256
`8695c878b296dc6a5abcec4ac1fe85fca814c339f2d5ad6c1f5ac454c3e3f74e`,
receipt `20261114-104533-f814e776`, contains the prior shared-decoration and
inset-alpha fixes, verified against its frozen source manifest. Two fresh
production captures now confirm **39 GitHub differences**. That bundle predates
this GPU inset correction and differs from the new focused reference at **76
pixels**, twice.

Final diagnostic executable
`032d36bda9b022e673543bd750b2fb03815fa63c790f12272efadafa7bceb4eb`
reduces the unchanged GitHub archive from **39 to 19 differing pixels**, twice:
the twenty input-corner differences are gone; four search-border and fifteen
avatar pixels remain. vlang.io improves from **3,250 to 3,228**, twice.
HN/Wikipedia/Lobsters remain exact twice, with all 30 HN stories and 33 GitHub
rows preserved. CNN remains at **175,866**, twice, and its native pair differs
at **1,554 pixels**. The small-shadow, shared-outer-decoration and rotated-border
controls remain exact twice; the scale-2 device-shadow control remains at 92.
All 22 final captures, 23 runtime guards including startup smoke, and the driver
exit 0 with unchanged source, executable, library, fixture and reference hashes.

Earlier probes and failures remain available. Generic compound-path attempts
left 14 and 8/9 input-band differences before `drawDRRect` matched that band.
An intermediate implementation incorrectly treated the inset as an MSAA trigger:
it improved GitHub but differed from the natural fixture at 66 pixels and failed
the GPU corner test at 18 pixels. Removing that trigger and retaining the existing
tile policy produces the final exact fixture. The initial Brave command used an
unsupported command-line option and exited 2 before capture; corrected commands
retain the launcher's existing hidden-scrollbar policy. No established reference
or tolerance was changed, and no instruction, timing or live-site parity credit
is claimed.

Raw commands, source/build identities, PNGs, guard exits, failed attempts and test
calls remain local under
`docs/performance/vlang-gradients-20261112/raw/inset-gpu-20261114/`.
The managed commit hook requests the normal C `-prod` rebuild; this new fix's
production validation remains pending. The all-site gate remains open, including
CNN's source/replay failure and the missing original Reddit fixture.


## Production inset confirmation and search-border investigation, 2026-11-14

The normally managed production worker completed during this investigation.
Bundle SHA-256
`6bf5db1e031eea8a68b6a4752ae3f45f603735510d16c6c7c5b43c27a0cde526`,
receipt `20261114-111608-a68550bc`, uses the C backend, literal V `-prod` and
one C unit. Its frozen manifest matches all **32 selected rendering-source
witnesses**, including the committed inset helper, GG descriptor, dispatch and
prior corrections. This supersedes the inset fix's pending-production status
above. No additional manual production build was queued.

All eleven workloads were checked in two fresh production processes each with
private profiles/caches, the same sealed page bytes and unchanged references.
**GitHub is 19**, **vlang.io 3,228**, and **HN/Wikipedia/Lobsters 0** differing
pixels in both captures. The new inset fixture, small-shadow, shared-decoration
and rotated-border controls are exact twice. The scale-2 device-shadow control
remains at 92. CNN remains at **175,866**, twice; this particular native pair
repeats exactly, but its earlier instability and source/replay failure remain
unresolved. All 22 captures and their guards, the comparison driver, and a
separate fresh production startup/JavaScript/wheel smoke check exit 0. Executable,
library, source-witness, fixture, reference and comparison-tool identities remain
unchanged throughout. No live-site or performance acceptance is inferred.
Production evidence remains local under
`docs/performance/vlang-gradients-20261112/raw/inset-gpu-20261114/`.

Further search-border probes did not establish another fix. On the unchanged
GitHub reference, a direct full-tile stroke reproduces its corner band exactly;
cropped, translated, fractional-origin and double-rounded-rectangle variants
retain four differences. A separately captured minimal backdrop fixture is a
counterexample to treating the full-tile observation as a general correction.
Its two pinned Brave images agree, but the focused full-tile test still fails
at four pixels. The proposed parent-grid helper preserves the existing site
counts and does not reduce GitHub's gap. Its first eligibility-test compile
fails on an optional-pointer payload; after correction, the minimal fixture's
layer-identity assertion fails because it does not reproduce the intended
separate effect owner. These attempts supply no correction or acceptance.
The experimental implementation, fixture and tests were removed after preserving
their sources, commands and failures locally.

A fresh Brave replay still matches the original GitHub reference exactly and
records the search button's unsnapped x coordinate as **760.75**, border-box size
42×36, radius 6 and backdrop blur 20. Folding that origin into the isolated
stroke does not remove the four differences. The remaining search-border and
avatar gaps therefore stay open; reference geometry is not adjusted to force
a pass. Search diagnostics remain local under
`docs/performance/vlang-gradients-20261112/raw/search-border-20261114/`.

## Legacy-grid reduction, 2026-11-14

`a2fd01d46` adds the known failing diagnostic
`Tests/Browser/Brave/diagnostic/legacy-backdrop-border.html` and its Brave
reference. Unlike the earlier fixed-header reduction, this retains the relative
header, isolated long page, fractional x=760.75 and backdrop blur 20. Two fresh
identity-pinned Brave captures agree exactly. Two fresh production captures of
`6bf5db1e` differ at precisely the original GitHub search-border coordinates
(764,16), (762,18), (801,49), (799,51), with the same actual/reference RGBA pairs.
It isolates that four-pixel failure without GitHub's other content or resources.
This reproducer supplies no rendering fix or all-site acceptance.

Two geometry-grid candidates were tested and rejected. The first reused the
normal root grid; the second prepared an independent document grid even when
the root itself uses legacy rasterization. Both preserve native effect ownership
and MSAA rows, but neither reduces the original GitHub gap or the new reduction.
The first cohort completes 22 captures, the second 24, plus their startup smokes,
with driver/browser/guard exits 0. Both preserve GitHub 19, vlang.io 3,228,
CNN 175,866, HN/Wikipedia/Lobsters 0, the exact focused controls and the scale-2
device-shadow gap of 92. The reduction stays at four differences twice in the
second cohort. The final candidate's two focused grid tests and 22 existing
MSAA tests execute successfully, but passing those checks does not demonstrate
pixel correction. Both experimental implementations and their temporary unit
tests were removed; production rendering code remains unchanged.

Raw commands, source snapshots, build identities, PNGs, guard reports, test-call
witnesses and actual exits remain local under
`docs/performance/vlang-gradients-20261112/raw/legacy-grid-20261114/`.
The eight temporary job directories and their guards were deleted after archival.
Host load exceeded 150 on 18 CPUs; no performance credit is claimed. The existing
production result and all unresolved site gates remain unchanged.


## Native leaf fringe correction, 2026-11-14

Commit `7019fc7ec` fixes the search-border mismatch. A callback trace proves
that the correct 64×64 compositor grid starts at (760,16), while the padded
native leaf starts at (759,14). Rejecting that one/two-pixel overlap caused a
fallback to a 46×40 GPU surface, changing corner coverage. The existing tile
copy/publication bounds can safely preserve the outside padding. Single and
grouped replay now accept this bounded fringe only when the leaf intersects
a valid tile; larger excursions and unsupported grids retain their fallback.
The existing diagnostic flag also reports callback grid/leaf coordinates.

Diagnostic executable SHA-256
`dcc40b06d4aec5cba0466a17ea7efdcbb19912652c552ab6ab2fb64d585a3694`
reduces GitHub **19 → 15**, twice; all four search-border differences are gone
and the avatar's fifteen pixels remain. The complete committed reduction is
exact twice. HN/Wikipedia/Lobsters remain exact, vlang.io remains 3,228 and CNN
175,866, each twice. Small-shadow, inset, shared-decoration and rotated-border
controls stay exact; scale-2 device shadows remain at 92. All twelve native
pairs repeat exactly in this cohort, without resolving CNN's historical
instability or source/replay failure. References and tolerances are unchanged.

Two focused tests execute GPU pixel checks through both replay routes and
reject unsafe fringe bounds; the 22 existing MSAA tests also pass. All 24
captures, startup smoke, 25 runtime guards, compilers and driver exit 0. Feature
source hashes and executable/library/fixture/reference identities remain stable.
The preceding trace and five-plane GPU probe are retained separately. This
explains why the earlier legacy-grid candidates did not fix the error: the
correct compositor grid was already available. No performance credit is claimed.

Evidence remains local under
`docs/performance/vlang-gradients-20261112/raw/geometry-fringe-20261114/`.
The managed commit hook requests production rebuilding; the new result is
**diagnostic pending production**, and the all-site gate remains open.


## Shared PNG and outer-shadow resolve, 2026-11-14

Commit `cd0173d0d` removes GitHub's remaining fifteen avatar differences.
An eligible adjacent unblurred shadow and downsampled PNG now share one V/GG
surface. Previously, resolving the shadow before the image rounded the backdrop
before its edge samples blended. Eligibility requires one root owner, identity
transform, full opacity, ordinary corners, matching content/image clips and no
inherited clipping. Other cases retain the existing replay. Native code supplies
only pixels, coordinates and the optional shadow descriptor; V owns selection.
The original PNG boundary remains compatible. Retained decoded bitmaps follow
the same selection/row-marker policy as ordinary image replay.

The new white-background shadowed-avatar fixture differs from production
`6bf5db1e` at eight pixels, twice; two fresh pinned Brave captures agree exactly.
The GPU control reproduces those eight differences with separate resolves and
matches exactly with one resolve, using the existing retained 38/255 alpha.
Using .15 instead produces 42 separated / 37 shared differences and supplies
no color-policy correction. Five focused tests execute successfully: two new
GPU checks, two existing sampled-image oracles and a layout eligibility check.
They cover shared pixels, the separated control, unchanged destination on
unsupported blur, and layer/clip/opacity/transform fallbacks. Runtime guards
use 3 GiB and arena poisoning.

Final diagnostic executable SHA-256
`279fe3e6db45e16ee10e20a3d6d187659e9d93a8945cceba21d079f0faa99817`
makes the unchanged **GitHub archive pixel-exact twice**, retaining all 33 rows.
The new avatar and prior search-border fixtures are also exact twice.
HN/Wikipedia/Lobsters remain exact, including all 30 HN stories; vlang.io stays
at **3,228**, CNN **175,866**, each twice. CNN's native pair differs at 1,558
pixels, preserving its stability failure. Small-shadow, inset, shared-decoration,
rotated-border and all seven prior image/poster controls remain exact twice;
scale-2 device shadows remain at 92. All 40 final captures, startup smoke,
41 runtime guards, driver and focused compiler/test exits are zero. The five
changed rendering-source hashes and executable/library/fixture/reference/tool
identities remain stable. No existing reference or tolerance changed.

The first browser candidate excluded retained decoded bitmaps and therefore
preserved the old differing counts. It is retained alongside the corrected
instrumented and uninstrumented runs. The final build removes temporary decline
logging and is checked independently without tracing. Concurrent DOM/query edits
are outside this focused commit. Evidence remains local under
`docs/performance/vlang-gradients-20261112/raw/avatar-shadow-20261114/`;
temporary jobs, binaries and generated C are deleted after archival.
The managed hook requests the normal production rebuild. **GitHub zero is
diagnostic pending production**, not live-site or JavaScript conformance.
vlang.io, CNN's rendering/source-replay/stability failures, the missing Reddit
fixture and the overall all-site gate remain open. No performance credit is claimed.


### Production confirmation of the preceding fringe fix

While finishing the PNG-shadow correction, production bundle
`b6501a1e85c9bc260ed3664ed58de7a100e24521eff9bd55b870292ea471f6ac`
completed through the managed worker (receipt `20261114-120227-85e8c420`,
C backend, literal V `-prod`, one C unit). Its frozen manifest matches the 34
selected pre-PNG rendering witnesses at `7019fc7ec`. Six fresh production
captures confirm **GitHub 15**, **search-border fixture 0**, and **shadowed-avatar
fixture 8**, each twice. Browser/guard/driver exits are 0 with unchanged pinned
inputs. This confirms the preceding fringe correction in production; the new
shared PNG-shadow correction remains diagnostic pending production. These six
checks do not rerun the entire catalog. Evidence is archived with the avatar
work; no duplicate manual production build was requested.


## Shared rotated ellipse decorations, 2026-11-14

Commit `50bdd42d6` shares a uniformly rotated ellipse's adjacent outer shadows
and border in one V/GG pass. It preserves the complete common clip list,
including rounded ancestor clips, through the existing native graphics boundary.
Selection requires one owner/layer, a uniform rotation, elliptical radii,
matching transforms, full opacity and a shared supported clip list. Other paints,
including unrotated geometry and non-AA commands, retain their previous replay.
No blur kernel, reference or pixel tolerance changes.

Final diagnostic executable SHA-256
`bc0de89a8aee8a49f9d036d61508e23b972febe4afa628351b77a4ce058096bb`
reduces the unchanged vlang.io archive **3,228 → 2,946**, twice. The comparison
corrects **287 pixels** and introduces **five one-channel, one-level differences**;
the 2,946 remaining differences still fail equality. The orbit diagnostic improves
**1,901 → 1,530**, twice, retaining maximum channel error 1. GitHub, HN,
Wikipedia, Lobsters, the prior avatar/border fixtures, small-shadow,
shared-decoration and rotated-border controls stay exact twice. CNN remains at
175,866 and its native repeat differs at 1,558 pixels; scale-2 device shadows
remain at 92. All 26 final captures, startup smoke, their 27 runtime guards and
the driver exit 0, with stable feature-source/executable/library/fixture/reference
and tool identities. Content checks preserve 33 GitHub rows and 30 HN stories.
Nine focused checks execute successfully: the selection test covers rectangular
and rounded clips plus safe declines, and eight existing GPU shadow checks retain
their oracle hashes. Runtime guards use 3 GiB and arena poisoning.

The first rectangle-only candidate improves the reduced orbit but leaves the
site unchanged. A scalar callback trace shows that the site inherits a rounded
panel clip, explaining its decline. The broader clipping candidate improves the
site, but a separate unrotated ellipse probe exposes a four-pixel residual with
worse maximum error. Failed exact-match/no-new-error assertions and a duplicate
unit-file compile error are retained. The final selector excludes unrotated
geometry; temporary probes and their uncommitted fixture were removed rather
than changing reference tolerances. This is a partial correction, not a pixel
pass or performance claim.

Production bundle
`243a18521e40b66394d8b6901294bf718bd8381e2eaf76aade81524ff9b0cb17`,
receipt `20261114-123523-3c4097b7`, separately confirms the preceding PNG-shadow
fix. Its 35 selected rendering witnesses match `cd0173d0d`; eight fresh native
captures give GitHub 0, avatar fixture 0, vlang.io 3,228 and orbit diagnostic
1,901, each twice, with guard/browser/driver exits 0. It uses C, literal V `-prod`
and one C unit. An initial baseline request against the older feature revision
fails its source-witness assertion before capture and is preserved. A later
production preview already contains the broad experiment, so its unrotated
fixture capture is not treated as a pre-change control or validation of the
final guarded selector.

Evidence and all attempts remain local under
`docs/performance/vlang-gradients-20261112/raw/ellipse-group-20261114/`.
Completed job directories, binaries, generated C and guards are removed after
archival. The normal managed commit hook requests rebuilding; the final 2,946
result remains **diagnostic pending production**. vlang.io, CNN, missing Reddit
and the all-site gate remain open. No additional manual production build was queued.

A subsequent production check rejects bundle `a7d897a12f0d662693441df9110770289fbacf73ebf98b678ce5993f5601481c`
before capture: the final ellipse and other 34 witnesses match, but its compiled
table-layout witness differs from the committed source. The next managed build,
`20261114-133524-783edcee`, exits 1 because `layout/incremental_layout.v` changes
during compilation; the previous bundle remains installed. Both failures are
retained under the ellipse evidence directory. They do not validate the final
fix in production, and no source guard was relaxed.

Further JPEG investigation accepts no decoder change. A 540×540 image displayed
at 24×24 remains imperfect in Vox; isolated native decode/downsample combinations
do not reproduce Brave exactly. Two fresh Brave checks preserve the original
displayed image crop exactly, but their full-page comparisons differ at 38
dropdown-chevron pixels. Full-resolution canvas readbacks differ at 526 pixels
between these processes, so they are not used as a stable decode oracle. The
initial probe omitted the scrollbar flag and is retained as a rejected policy
mismatch. Commands, failed compile attempt, GPU probes and captures remain local
under `raw/jpeg-scale-probes-20261114/`; the temporary test and four job directories
were removed. All 26 preceding ellipse jobs were likewise archived and removed.


## Text-layer gradient dither origin, 2026-11-14

Commit `f2ee06925` selects a mask-layer grid for eligible scale-1 background-text
gradients. Native graphics code supplies the retained mask's device-aligned
bounds and backing scale; V owns selection, sample policy and rasterization.
Padded leaf input is intersected with that grid, preserving pixels outside it.
Higher backing scales, unsupported bounds and ordinary gradients keep their
previous grid. No shader, mask coverage, reference or pixel tolerance changes.

Final diagnostic executable SHA-256
`472adce2973034c81e1ef239fed1471d3907bfc19cd51240d42752af75c7fa20`
reduces the unchanged vlang.io archive **2,946 → 2,710**, twice: **236 corrected
pixels and none newly differing**. The text mask retains one green-channel,
one-level difference at (871,264); the JPEG crop retains 279 differences and
other page regions retain 2,430. This remains a failure of equality. The basic
gradient-text fixture improves **3,752 → 0**, twice; the fractional-position
control improves **7,725 → 2,214**, twice.

All 28 candidate captures in the 14-workload cohort and its separate startup
smoke exit 0 under 29 runtime guards. GitHub/HN/Wikipedia/Lobsters remain exact
twice, with 33 GitHub rows and 30 HN stories preserved. Prior border, avatar,
small-shadow, shared-decoration and rotated-border controls remain exact;
scale-2 device shadows remain at 92. CNN remains at 175,866; its native pair
differs at 1,534 pixels, so its prior stability and source/replay failures stay
open. The other 13 native pairs agree exactly. Feature-source, executable,
native-library, input, reference and diff-tool identities remain unchanged.

Eight further candidate captures and eight matched prior-path controls cover
inline/wrapped text, mixed clipping, Retina text and compositor gradients. Every
browser and guard exits 0. Inline text improves **26,489 → 16,007**; the mixed
scope improves **2,898 → 1,401**; the compositor control retains one difference,
each twice. Retina text remains at **1,767**, with candidate and prior-path PNGs
pixel-identical. Its scale-2 Brave reference comes from two pinned fresh
processes that agree exactly. These controls retain their recorded failures.
Seven focused checks execute successfully with arena poisoning and 3 GiB runtime
guards: three new grid/oracle/padding checks, the retained-input eligibility check
and three existing CSS gradient oracles. Compiler jobs retain the 12 GiB guard
and 10 GiB V compiler limit.

Mask/gradient readbacks show that separate-term mask compositing already
reproduces Vox exactly; alternate rounding formulas regress. A 64-phase GPU
probe instead isolates the dither origin: the unchanged linear-text reference
is exact at the layer origin, versus 597 differences at the page phase. A first
browser compile fails a C declaration qualifier check and is corrected. Extra
checks reject Retina candidates at 43,986 and then 12,100 pixels against the
1,767-pixel prior path; the final selector explicitly declines higher backing
scales. A diagnostic driver also exits 1 on a missing optional compositor
reference before that case captures; the corrected run retains all attempts.
Temporary instrumentation and the phase probe are removed.

Evidence remains local under
`docs/performance/vlang-gradients-20261112/raw/text-mask-resolve-20261114/`;
completed scratch jobs, binaries, generated C, guards and the test harness link
are removed after archival. The managed hook requests the normal C `-prod`
single-unit rebuild. The preceding managed attempt
`20261114-135103-86ce3af6` failed because its staged HTTP response code calls a
Brotli callback API absent from the staged pure-V decoder. The latest completed
bundle remains available, but does not validate this correction. The 2,710 result
is **diagnostic pending production**. vlang.io, CNN, the missing Reddit fixture
and the all-site gate remain open; there is no live-site, scripting or performance
acceptance claim.

A later completed production preview,
`ec1876e0fa1f9f57c588f6b5ae980489f7a5455663a0cd3d5bb1330c155bdbc6`
(receipt `20261114-141124-93161f1d`), contains an earlier mask-grid experiment.
Two of the 36 current rendering witnesses differ: the gradient adapter and its
native callback header. Its compiled sources match the preceding candidate
before the higher-backing-scale restriction and empty-intersection guard. This
preview supplies no production acceptance for the final fix. The final source
is committed and requested through the managed rebuild hook.


## Production confirmation of ellipse and text-gradient fixes, 2026-11-14

Production executable SHA-256
`314e32e91a00d4b7e38ab01f3ed68531506770bd6aac15596e752d2b06e93d20`,
receipt `20261114-142402-7aecdb3e`, contains the final guarded implementations of
`50bdd42d6` and `f2ee06925`. All 36 selected rendering witnesses match the
committed sources and staged GG inputs. The build uses C, literal V `-prod`
and one C unit. Thirty fresh document captures across 15 workloads exit 0,
as do all 30 native capture guards and the enclosing 12 GiB driver guard.

| Workload | Differing pixels in each fresh capture |
| --- | ---: |
| vlang.io archive, scripts disabled, scale 1 | **2,710** |
| Basic gradient text | **0** |
| Fractional-position gradient text | **2,214** |
| GitHub archive, 33 rows preserved | **0** |
| Hacker News archive, 30 stories preserved | **0** |
| Wikipedia / Lobsters archives | **0 / 0** |
| CNN archive | **175,866** |
| Border / avatar / small-shadow / shared-decoration / rotated-border controls | **0 each** |
| Device-pixel shadows, scale 2 | **92** |
| Rotated ellipse diagnostic | **1,530** |

Every pair agrees internally except CNN, whose native repeat differs at 1,555
pixels. Its source/replay and stability failures remain open. Fixture,
reference, executable, library and diff-tool hashes remain unchanged throughout
the cohort. A separate fresh non-windowed startup check exits 0; its empty
environment creates disposable workspace-relative cache files, which are
recorded and removed. A subsequent private-profile startup request is rejected
before launch when a newer bundle appears; it supplies no replacement evidence
for this pinned cohort. No changed-input attempt is counted as successful.

Further JPEG probes accept no browser rendering change. Chromium's
[GPU decode cache](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/cc/tiles/gpu_image_decode_cache.cc)
resizes YUV planes separately and promotes scaled images to 4:4:4. Isolated
probes of that order, plane-filter precision, fractional RGB storage, mipmaps
and compositing reduce the icon's residual to 23 one-level pixels in the best
case, but do not reproduce the unchanged reference exactly. Half-float storage,
conversion after mip filtering, different surface bounds and alternate natural
coordinate normalization supply no accepted correction. The production JPEG
crop still differs at 279 pixels. Two initial probe compiles fail on array
assignment and slice-copy syntax; corrected executions and every failed result
are retained. The temporary floating-image API and four probe tests are removed,
and all staged rendering witnesses are restored exactly.

Production evidence remains local under
`docs/performance/vlang-gradients-20261112/raw/textmask-production-20261114/`;
JPEG diagnostics remain under `raw/jpeg-planes-20261114/`. Completed scratch
jobs, binaries, generated C and guards are archived and removed. This confirms
the prior fixes in production; it does not pass the vlang.io, CNN, missing Reddit
or all-site equality gates. No live-site, scripting or instruction-performance
acceptance is claimed.

## Tile-local shadow filter inputs, 2026-11-14

Commit `de478eee8` restricts an axis-aligned shadow filter's source to the
raster tile plus its three-sigma input footprint before progressive resampling.
Previously, the entire offscreen box determined the centered downsampling grid.
For vlang.io's tall panel, that shifted the faint shadow across the download
buttons and panel corners. Gaussian kernels, final A8 resolution and existing
references remain unchanged. Rotated geometry keeps its preceding path.

The source-bound calculation follows the filter input/desired-output relationship
in [SkCanvas](https://skia.googlesource.com/skia/+/refs/heads/main/src/core/SkCanvas.cpp)
and [SkImageFilterTypes](https://skia.googlesource.com/skia/+/refs/heads/main/src/core/SkImageFilterTypes.cpp).
Local snapshots retain the consulted source. The new complete colored-control
fixture has two agreeing fresh Brave references. Production executable
`d94dced5f7643aa17ec662ec0a72400c5bb62a5e1ce87752af0a15ac07c41ce6`
differs at **2,114 pixels** in that fixture. The corrected diagnostic is exact
twice. A separate opaque-black shadow control has agreeing fresh Brave captures,
also verified after simplifying its canonical HTML, and is exact twice in Vox.
Its focused test compares the complete upper shadow band with that independent
reference. All **13 focused tests** across nine files execute successfully,
including unchanged nine-patch, capsule, small-kernel, rotated, unblurred,
shared-decoration and sampled-image oracle checks. Runtime guards use 3 GiB
and arena poisoning; compiler guards retain the default 12 GiB budget.

Final diagnostic executable SHA-256
`1ec08bbf8240c18ce8bd4538e1881ad8972b8cdff73a8e8f1cc243480aa168a2`
completes 32 fresh document captures across sixteen workloads plus a fresh startup
smoke. All 33 native guards, the driver and outer guard exit 0. The selected
36 rendering-source witnesses remain stable, with only the intended filter
source differing from the preceding production cohort. Executable, native
libraries, fixture, reference and diff-tool identities remain stable throughout.

| Workload | Differing pixels in each fresh capture |
| --- | ---: |
| vlang.io archive, scripts disabled, scale 1 | **2,139** |
| Tall panel / independent shadow mask | **0 / 0** |
| GitHub / HN / Wikipedia / Lobsters archives | **0 each** |
| CNN archive | **175,866** |
| Small shadows / shared decorations / avatar / border controls | **0 each** |
| Basic gradient text | **0** |
| Rotated ellipse diagnostic | **1,530** |
| Device-pixel shadows, scale 2 | **92** |

The vlang.io change corrects **571 pixels with zero newly differing pixels**
relative to the fresh 2,710-pixel production control. GitHub preserves all 33
rows and HN all 30 stories. Fifteen native pairs agree exactly; CNN's pair
differs at 1,558 pixels, retaining its stability failure and earlier source/replay
failure. vlang.io still has JPEG, text and decoration differences; Reddit's
historical fixture remains missing. The all-site equality gate stays open.

Two broader experiments are rejected and reverted. Deferring the final A8
upscale makes vlang.io worse at 3,405 pixels and the new fixture worse at 2,179,
although the orbit improves to 1,312. The complete restore path resolves coverage
to an image, so the final implementation preserves that step. Applying input
clipping to rotated shapes gives vlang.io 1,978 pixels, but introduces 392 new
differences; the final correction is restricted to axis-aligned filtering.
All failed results and exploratory sources remain in local evidence.

Evidence is retained under
`docs/performance/vlang-gradients-20261112/raw/shadow-resolve-20261114/`.
Thirteen completed job directories, binaries, generated C and guards are removed
after verified archival. The normal managed commit hook requests a C, literal
V `-prod`, single-unit rebuild. The latest completed bundle still predates the
correction; **production validation of 2,139 remains pending**. These frozen
captures establish no live-site, author-script or performance acceptance.

## Rotated shadow filter layers, 2026-11-14

`d79672699` filters translucent, antialiased, noncircular elliptical shadows in
scale-and-translation layer space, then restores the resolved A8 mask through
the remaining rotation. The destination clip is mapped into the filter layer
before allocating its bounded input. The native graphics boundary supplies
only a conservative clip box; V carries it through tile translations. A larger
readback fringe uses the compositor grid only when that grid contains the
entire visible filter clip, preserving outside bytes. Opaque, circular,
nonuniform and unsupported paints retain their preceding paths. Gaussian
kernels, existing scale-helper arithmetic and references remain unchanged.

The mapping follows the scale/translation filter capability in
[SkImageFilter_Base](https://skia.googlesource.com/skia/+/refs/heads/main/src/core/SkImageFilter_Base.h)
and scale decomposition in
[SkMatrix](https://skia.googlesource.com/skia/+/refs/heads/main/src/core/SkMatrix.cpp).
These are consulted mainline sources, not a verified source revision for
installed Brave 157.0.8103.79: its Chromium revision's upstream DEPS lookup
returned 404. Independent Brave screenshots remain the pixel oracle.

All **23 focused checks** pass: sixteen GPU checks across ten files, plus
seven root geometry, grouping and prefetch checks. The new GPU check matches
both sampling modes exactly through the independent reference's upper shadow
band. It also checks safe declines and bounded/invalid filter requests. The
complete browser fixture still differs at **four one-level pixels**; the
focused test does not establish full-page equality. Two fresh Brave captures,
and two additional captures at the canonical input path, agree exactly.
The opaque diagnostic remains a known failure.

Diagnostic executable SHA-256
`9317a2dfbc810292679e70e9a73fd923d20aaba937a9ff70925f7696648bd64b`
completes 36 fresh document captures across eighteen workloads and a fresh
startup smoke. All 37 native guards, the driver and outer guard exit 0.
All 41 selected rendering-source witnesses remain stable. Existing fixture,
reference, executable, native-library and diff-tool identities are pinned.
GitHub retains all 33 rows and Hacker News all 30 stories.

| Workload | Diagnostic differing pixels, each fresh capture |
| --- | ---: |
| vlang.io archive, scripts disabled, scale 1 | **830** |
| GitHub / HN / Wikipedia / Lobsters archives | **0 each** |
| CNN archive | **175,866** |
| Rotated translucent fixture | **4**, maximum channel error 1 |
| Rotated ellipse / opaque layer diagnostics | **19 / 21,069** |
| Tall panel / independent mask / small shadows / shared decorations / avatar | **0 each** |
| Border controls / basic gradient text | **0 each** |
| Device-pixel shadows, scale 2 | **92** |

Against the fresh 2,139-pixel source control, vlang.io has **1,451 corrected
pixels and 142 newly differing pixels**, all new errors one level. Seventeen
native pairs agree exactly; CNN's pair differs at 1,558 pixels and retains its
source/replay failure. vlang.io, CNN, missing Reddit and all-site equality remain
open. No reference or tolerance was changed to obtain this improvement.

An approximate texture-allocation recheck leaves the same 830/four-pixel
results and is reverted. A global half-precision sampling experiment fails
four focused checks, including existing capsule, nine-patch and shared-image
oracles, and is reverted. Earlier prototype zero-pixel results therefore do
not describe the accepted configuration. Initial layer-space filtering without
the destination clip produces 1,398 vlang.io differences with 672 new errors;
that result and all other unsuccessful probes are retained.

Production executable SHA-256
`731ef68c901b8be1ce7858eef0c1d5d93c2b8df7584cc7b4f61a80d42bcef604`
now confirms every count in the table in two fresh captures each. All 36 native
guards, the driver and outer guard exit 0; seventeen pairs repeat exactly and
CNN again differs at 1,425 pixels. The completed bundle is reused without a
manual rebuild. Although its nominal build-start revision predates the commit,
all 41 rendering witnesses match the accepted source, including the two shadow
fixes. The full embedded Metal shader is decoded from its generated C, hashed
and compared with the staged shader; they agree. The receipt and sealed C hash
are retained. Production therefore confirms 830 rather than the earlier
2,710-pixel result. vlang.io still fails equality.

Local evidence is under
`docs/performance/vlang-gradients-20261112/raw/rotated-filter-space-20261114/`.
Runtime checks use 3 GiB guards and arena poisoning; compiler guards retain
12 GiB and V's 10G compiler limit. Completed job outputs are archived before
scratch directories, binaries, generated C and guards are removed. The normal
managed hook requests a C, literal V `-prod`, single-unit rebuild; no additional
manual production build is requested. Frozen captures establish no live-site,
author-script or instruction-performance acceptance.

## Root-picture shadow fringes, 2026-11-14

`a4b71a733` corrects the reduced translucent-shadow fixture's remaining four
pixels without changing its reference, the filter kernel or the image shader.
The native trace shows a 400×404 readback at picture position `(0, -60)`, with
a clip covering the whole readback. The compositor grid is 416×256 with two
rows. Its preceding guard treats the negative part of that offscreen clip as
visible and declines tiled drawing, producing the four-pixel whole-readback
result. An isolated GPU control reproduces the same four errors.

The root picture clips negative document coordinates before publication. V now
carries that property with the selected root grid and allows eligible rotated
filters to retain the tile sampling grid across this invisible fringe. Copying
and publication preserve the outside bytes. Right and bottom bounds retain
their previous checks; non-root grids keep the stricter clip requirement.
The existing diagnostics now report the filter clip alongside the grid.

All **eight focused checks** pass under the 3 GiB runtime guard. The new
regression compares the unchanged Brave shadow band through
both single and grouped drawing: root tiles are exact, non-root fallback retains
its four-pixel control result, and the sixty outside rows remain unchanged.
Geometry, grouping and prefetch checks continue to pass. Compiler guards retain
the default 12 GiB and V's 10G limit.

Diagnostic executable SHA-256
`b6fc5c6fc96111ae6964297c4f94ee774dc434462fbe4b1c533ef58c7de5c8b8`
completes 36 fresh document captures across eighteen workloads plus startup.
All 37 native guards, the driver and outer guard exit 0. All eighteen native
pairs agree exactly in this cohort. The 41 selected rendering witnesses and
executable, native-library, fixture, reference and diff-tool identities stay
stable. GitHub preserves its 33 rows and HN its 30 stories.

The **complete translucent-shadow fixture is exact twice**, correcting four
pixels with no newly differing pixels. vlang.io stays at **830**, byte-for-byte
unchanged from the fresh production control. GitHub, HN, Wikipedia, Lobsters
and the preceding exact controls remain exact. The orbit retains 19 differences,
the opaque layer 21,069, device-pixel shadows 92, and CNN 175,866. CNN's pair
agreement here does not erase earlier native-repeat failures or its unresolved
source/replay mismatch. vlang.io, CNN, missing Reddit and all-site equality
remain open.

The latest completed production bundle at this check is `0be493a0…`. Its receipt
matches 39 of the candidate's 41 witnesses but predates both changed rendering
inputs, `chromium/gpu_raster_darwin.v` and `chromium/msaa_tiles.v`. It cannot
validate this fix. The normal managed hook requests a C, literal V `-prod`,
single-unit rebuild; no duplicate manual build is requested. **Production
validation was pending at that check.** A subsequent fresh check with production
`e1925955…`, matching all 41 preceding rendering witnesses, now confirms the
complete translucent fixture exactly twice.

Local evidence is retained under
`docs/performance/vlang-gradients-20261112/raw/rotated-refine-20261114/`.
Completed jobs, binaries, generated C, guards and the temporary harness symlink
are removed after verified archival. Frozen screenshot checks establish no
live-site, author-script or instruction-performance acceptance.

## Rounded backgrounds and borders in one V raster group, 2026-11-14

`77143c150` gives adjacent opaque rounded backgrounds and uniform borders one
V raster group. The preceding batching code calls a native decoration
transaction that now declines every request, so asymmetric corner paints reach
separate raster resolves. The new path uses the existing document-shape group
boundary and preserves their samples until both paints finish. The eligibility
checks retain root ownership, matching geometry and transforms, antialiasing,
full opacity and simple clip requirements. Pairs with color-cache alpha below
255, independent clips, partial decoration runs and unsupported state keep
their preceding path; retained floating-point colors are preserved.
No native code, shader, filter kernel or reference is changed.

Seven focused checks pass with `VOX_ARENA_POISON=1` and 3 GiB runtime guards.
The new GPU check covers uniform, left-only and right-only rounded corners
against the unchanged 1280×800 Brave reference: separate resolves differ at
24 pixels in its selected bands; one resolve is exact. Six layout, eligibility
and existing decoration checks execute successfully. An initial unit probe
uses the wrong reference stride and fails in both modes; the corrected test
asserts the reference dimensions. That failed attempt and its source are retained.
Compiler guards retain 12 GiB and V's 10G limit.

The fresh production control is executable SHA-256
`e19259550bdc6ba53f2e3aae16f557aa3099416a1ba0d48b6f4f2291b36ac8d8`.
It gives vlang.io **830** and the complete `rounded-background-border-root`
fixture **14** differing pixels, each twice. It also confirms the preceding
root-shadow-fringe fixture exactly twice, with all 41 preceding witnesses
matching that correction. The additional HSL, transformed and transparent
background controls are exact; the partial-border control retains seven errors.

Candidate executable SHA-256
`f4eccdef49ba3edaf530c46f03958562602c03d5e8e96d1f4191872e585f4666`
completes 46 fresh document captures across 23 workloads plus startup. All 47
native guards, the driver and outer guard exit 0. The 43 selected rendering
witnesses and executable, native-library, fixture, reference and diff-tool
identities stay stable. GitHub preserves all 33 rows and HN all 30 stories.

| Workload | Differing pixels in each fresh candidate capture |
| --- | ---: |
| vlang.io archive, scripts disabled, scale 1 | **818** |
| Complete rounded-background/border fixture | **0** |
| GitHub / HN / Wikipedia / Lobsters archives | **0 each** |
| Existing exact shadow, avatar, border, gradient-text and added background controls | **0 each** |
| Rotated ellipse / opaque layer diagnostics | **19 / 21,069** |
| Device-pixel shadows / partial-border control | **92 / 7** |
| CNN archive | **175,866** |

vlang.io has **12 corrected pixels with zero newly differing pixels** against
the fresh control; the rounded-border fixture has **14 corrected and zero new**.
Twenty-two native pairs agree exactly. CNN's pair differs at 1,556 pixels,
retaining its repeatability and source/replay failures. vlang.io, CNN, missing
Reddit and all-site equality remain open.

Production `e1925955…` matches 41 of the candidate's 43 witnesses, predating the
new group implementation and its dispatch. **Production validation of 818 was
pending at that check.** The subsequent inset-group cohort below confirms both
corrections in production at 810.
No additional manual build is queued. Commands, all attempts, source witnesses,
executed test calls, PNGs and actual exits are retained locally under
`docs/performance/vlang-gradients-20261112/raw/rounded-background-20261114/`.
Completed job scratch and the test harness symlink are removed after verified
archival. These frozen captures establish no live-site, author-script or
instruction-performance acceptance.

## Shared unblurred inset decorations, 2026-11-14

`f4a40d91b` keeps one box's opaque background, eligible unblurred inset shadows
and uniform border in a V document-shape group. The legacy native transaction
still declines. The new path accepts a common root or non-root raster owner,
preserves paint order and floating-point colors, and reuses the existing
square-caster/rounded-hole inset geometry. Independent clips, mismatched state,
blur and unsupported decorations retain ordinary replay. Shaders, filter
kernels, existing references and tile MSAA-trigger policy are unchanged.

The new `inset-decoration-samples` diagnostic has a fractional-position rounded
box and a tall asymmetric box, plus an SVG tile trigger. Two fresh Brave
captures at its canonical path agree exactly. Its raster test uses the actual
snapped paint geometry from the native trace: separate resolves leave nine
errors; a shared resolve is exact. Initial probes incorrectly use the unsnapped
CSS coordinate and fail; those sources, outputs and failed attempts are retained.
The ordinary inset fixture still uses its analytic tile selection.

All **eleven focused checks** execute and pass: eight grouping, geometry and
fallback checks, plus three GPU checks. Runtime guards use 3 GiB and
`VOX_ARENA_POISON=1`; compiler guards retain 12 GiB and V's 10G limit.

A freshly compiled control reproduces vlang.io at 818 pixels and the new
fixture at nine, twice each. Candidate executable SHA-256
`5353b68525c61bfd56b60b79957aa3ae618b74b9022c699345a443b13284a75d`
completes 54 fresh document captures across 27 workloads plus startup. All 55
native guards, the driver and outer guard exit 0, with 45 selected rendering
witnesses unchanged. vlang.io improves **818 → 810**, correcting all eight
panel-corner pixels with **zero new differences**. The complete new fixture
improves **9 → 0**, twice. The mixed blurred/unblurred inset control improves
**14,108 → 14,102**, correcting six without new errors; its blurred cases retain
the preceding fallback. Twenty-six native pairs repeat exactly; CNN differs at 1,558 pixels.

Production executable SHA-256
`1861ac9181458f16bfbb56b6f07c3ead5edbfd39593349804bcc34d67d7d5e64`
confirms every candidate workload count in two fresh captures each. All 54
native guards, the driver and outer guard exit 0. Its 44 compiled-file witnesses
match the feature revision, and the canonical shadow helper matches its
compiled staged copy. Although the build-start revision predates this commit,
the frozen parsed source contains the complete correction. The completed bundle
is reused; no extra manual build is requested.

| Workload | Production differing pixels in each fresh capture |
| --- | ---: |
| vlang.io archive, scripts disabled, scale 1 | **810** |
| New inset diagnostic / ordinary inset / minimal rounded inset | **0 each** |
| GitHub / HN / Wikipedia / Lobsters archives | **0 each** |
| Preceding exact background, border, shadow, avatar and gradient-text controls | **0 each** |
| Mixed inset / partial-border / device-pixel-shadow controls | **14,102 / 7 / 92** |
| Rotated ellipse / opaque layer diagnostics | **19 / 21,069** |
| CNN archive | **175,866** |

GitHub preserves all 33 rows and HN all 30 stories. Twenty-six production pairs
agree exactly; CNN's pair differs at 1,555 pixels. Compared directly with the
retained 830-pixel production control, the two latest decoration fixes correct
**20 pixels with zero new differences**. This also confirms the preceding
rounded background/border correction in production.

A separate failure remains open: before this change, the unchanged control
executable produces tall-shadow errors of **0 and 29,188** in two fresh captures,
with maximum channel error two. Its visible SVG marker, geometry and sample
flags agree, so a missing marker or changed MSAA flag is not established as the
cause. Preview, final diagnostic and production pairs are exact, but those
later passes do not erase that baseline instability or establish a fix for it.
No reference, tolerance or input identity was relaxed. vlang.io, CNN, missing
Reddit and overall equality remain open.

Evidence is local under
`docs/performance/vlang-gradients-20261112/raw/inset-group-20261114/`, including
all failed probes, commands, actual exits, input/source witnesses and PNGs.
Completed job scratch, binaries, generated C and the temporary harness symlink
are removed after verified archival. Normal managed commit hooks request C,
literal V `-prod`, single-unit rebuilds. Frozen captures establish no live-site,
author-script or instruction-performance acceptance.

## Recorded filter clips beyond the window, 2026-11-14

`8dc5c0df1` preserves the recorded author clip when preparing grouped rotated
elliptical shadows. The native graphics clip included the visible window's
bottom edge. In vlang.io's picture, the final visible tile starts at y=638;
using the window edge at 792 instead of the author's rounded-out edge at 841
changed the blur input's centered downsampling grid. V now intersects supported
axis-aligned recorded ancestor clips, and the native transfer converts that
document rectangle into readback coordinates. Publication retains the native
clip. Unsupported clips keep the preceding boundary; kernels, shaders,
sampling policy and existing references are unchanged.

Two independently captured, identity-pinned Brave references for each new
fixture agree exactly. The empty transform hint in `large-clipped-orbit`
reproduces the non-root picture and its y=384 raster origin. Its companion
`large-orbit-underlay` supplies the same scene without the orbit. The focused
GPU check compares every RGBA pixel in the final tile's visible interior:
the window-clipped input differs at 485 pixels; the author-clipped input is
exact. The complete scene retains other differences, reported below.

Twenty-three focused checks execute successfully: four browser-module checks
and nineteen GPU checks, including the existing capsule, rounded-shadow,
rotated, inset and shared-decoration oracles. The final RGBA assertion also
executes separately. Runtime checks use the 3 GiB guard and the supported
`VOX_ARENA_POISON=1`; compiler jobs use the default guard and V's 10G limit.

Diagnostic executable SHA-256
`b6a9250894995a81b60d59e33dc014764f879d660ea8902aa83fea04e9d997c6`
produces these counts in two fresh captures each:

| Workload | Differing pixels |
| --- | ---: |
| vlang.io | **341**, down from 810 |
| New large clipped orbit | **111**, down from 596 |
| New orbit underlay control | **105**, unchanged |
| GitHub / Hacker News / Lobsters / Wikipedia | **0 each** |
| All preceding exact background, inset, shadow, avatar and gradient-text controls | **0 each** |
| Other preceding diagnostic controls | Unchanged |
| CNN | **175,866**, with its existing source/replay failure |

vlang.io has **469 corrected pixels and zero new differences**; the complete
orbit fixture has **485 corrected and zero new**. vlang.io retains 279 JPEG
pixels, one heading pixel and 61 scene pixels. The four exact archived sites
retain their content audits, including 33 GitHub rows and 30 Hacker News
stories. The fixed-input rerun covers 30 workloads, 60 document captures and
one startup check; all 61 native guards, the driver and outer guard exit 0.
Its 46 rendering-source and six tool witnesses remain unchanged. Twenty-nine
native pairs repeat exactly; CNN differs at 1,050 pixels. The earlier tall
shadow baseline repeat failure remains unresolved despite this cohort's
matching tall-shadow captures.

An initial wider run is retained as diagnostic evidence because the on-disk
driver manifest changed briefly during its execution. The unchanged-input
rerun supplies the results above. Other retained investigations establish
that the thin capsule control is already exact, sampled CPU/GPU glyph blending
agrees, and a matrix-association candidate changes no browser pixels. That
candidate and temporary tracing/probe code are reverted.

Production `aa19da69`, receipt `20261114-191855-433aa86a`, still supplies the
810-pixel baseline. Its compiled manifest lacks this fix; **341 remains a
diagnostic result pending the managed production rebuild**. A concurrent
LibJS performance-binding change also separates the recorded control and
candidate source sets; these captures use the default JavaScriptCore build,
with author scripts disabled for vlang.io. The isolated GPU comparison directly
exercises the changed filter boundary. No live-site, scripting or performance
acceptance is claimed. All-site equality remains open, including CNN, the
missing original Reddit fixture and the retained repeatability failure.

Raw commands, identities, sources, PNGs, actual exits, failed attempts and
transition counts are local under
`docs/performance/vlang-gradients-20261112/raw/large-orbit-20261114/`.


## Gradient picture isolation without hit-test metadata, 2026-11-14

`19224ad53` retains eligible contiguous gradient pictures when optional
hit-test metadata is absent. The gradient leaf already carries the geometry,
color and clip needed for recording. Rejecting it discarded the promoted
picture's transparency boundary in the reduced orbit scene. Intervening
unrepresented paints still require the existing geometry proof. The plan now
records device scale explicitly; metadata-free scale-2 pictures retain their
previous fallback, including when a plan is reused at different scales.
No references, tolerances, blur kernels or shaders change.

The final diagnostic executable SHA-256 is
`7f98db407390ab8088a6eb08b9ed0f4bac62299d01e17e7dc70a5f9631e13968`.
Two fresh captures per workload produce:

| Workload | Previous differences | Final differences |
| --- | ---: | ---: |
| Large clipped orbit | 111 | **4** |
| Orbit underlay | 105 | **3** |
| vlang.io | 341 | **341** |
| GitHub / Hacker News / Lobsters / Wikipedia | 0 each | **0 each** |
| Other preceding controls | Their preceding counts | Unchanged |

The scene corrects **107 pixels with zero new differences**, and the underlay
corrects **102 with zero new**. The scene comparison uses the preceding pinned
candidate; the underlay also has a fresh current control. Existing independent
Brave reference hashes and the installed Brave identity remain unchanged.
This does not reduce vlang.io's remaining 279 JPEG pixels, one heading pixel
and 61 scene pixels.

The final cohort covers 29 workloads, 58 document captures and one startup
check. All 59 native guards, the driver and outer guard exit 0; 47 rendering
source and six tool witnesses remain unchanged. Twenty-eight native pairs
repeat exactly. CNN still differs from Brave at 175,866 pixels and between
native repeats at 706 pixels, with its retained source/replay failure. The
four exact archives preserve their content audits, including 33 GitHub rows
and 30 Hacker News stories. This cohort's matching tall-shadow captures do
not clear the earlier baseline repeat failure.

Sixteen focused tests execute successfully under the 3 GiB runtime guard with
`VOX_ARENA_POISON=1`. They cover valid linear/radial leaves without metadata,
unsupported gradients, unsafe gaps, real picture ownership and plan reuse at
scales 2, 1 and 2, plus existing leaf/shadow recording. `de783cfd7` separately
corrects a stale plain-shadow assertion: the unchanged preceding selector and
current selector both accept that case, independently verified by execution.
Initial compile failures involving concurrent script/LibJS edits, the stale
assertion failure, a temporary probe compile error and a preview missing an
expected PNG are retained. They are not counted as passing checks.

A separate GPU experiment reproduces 50 text-over-orbit differences when the
orbit resolves before glyph coverage and zero when both retain samples in one
pass over the independent background. This is diagnostic evidence for future
text grouping, not an implemented browser fix. Half-precision blend models
introduced new errors and were rejected; no precision change was applied.

Production `aa19da69`, receipt `20261114-191855-433aa86a`, still supplies the
810-pixel vlang.io baseline and lacks both the preceding clip fix and this
change. **341 and the reduced-scene results remain diagnostic pending the
managed production rebuild.** Normal commit hooks request coalesced C backend,
literal V `-prod`, single-unit builds; no duplicate build is requested.
The managed attempt `20261114-213235-cee7c9b9` failed its frozen-input check
because `tools/libjs_native_hn.v` changed during the build; the previous bundle
was retained. This failure is archived separately from the successful
focused and diagnostic checks.
All-site equality remains open, including CNN, the missing original Reddit
fixture and the retained repeatability failure. Frozen captures establish no
live-site, author-script or instruction-performance acceptance.

Commands, identities, actual exits, source witnesses, PNGs, probe masks and
failed attempts are local under
`docs/performance/vlang-gradients-20261114/raw/glyph-coverage-20261114/`.
Completed scratch jobs and temporary probes are removed after archival.


## Shape and glyph samples in one pass, 2026-11-14

`efaca9e3c` preserves an eligible elliptical decoration picture's samples until
its following glyph coverage has blended. Previously, publishing the shapes
before drawing text rounded the shared edge colors. V now records a bounded
prefix of supported shapes followed by retained horizontal A8 glyph runs in
one GPU pass. The real vlang.io picture uses seven shapes and six text runs.
It stops at the next distinct clip. Culled leaves with author clips wholly
outside the viewport may be skipped; visible owner, clip, effect and resource
boundaries remain strict. Scale 1, supported geometry, opaque source text and
representable font masks are required; unsupported inputs retain ordinary
replay. Byte colors use the existing glyph rasterizer's color and font policy.
The existing rounded native publication clip and outward filter-input rounding
are preserved. No shaders, blur kernels or existing references change.

The focused GPU regression uses an unchanged independent Brave text-band crop
and the captured A8 coverage for that run. Separate resolves retain **50**
differences; the shared pass is **pixel-exact**. The coverage PNG is an input,
not an expected rendering. Thirteen browser-module checks and two GPU checks
execute successfully under the 3 GiB guard with `VOX_ARENA_POISON=1`. These
include byte-color coverage without optional float metadata, invalid coverage
rejection before publication, unsafe owners/clips, invalid geometry, real
picture ownership and the preceding gradient scale/fallback checks.

Final diagnostic executable SHA-256:
`9f011deb601e645efc3863832e08108c5c0f62d20570ad1fc335775b50c88320`.
Two fresh vlang.io captures each have **284 differing pixels**, down from 341:
**57 corrected pixels and zero new differences**. The remaining pixels are
279 JPEG pixels, one heading pixel and four scene pixels. Those four scene
pixels now match the reduced orbit fixture's residual coordinates and colors;
the reduced scene remains four differences and its underlay remains three.

The unchanged-input cohort covers 29 workloads, 58 document captures and one
startup check. All 59 native guards, the driver and outer guard exit 0.
Its 57 rendering-source and six tool witnesses remain unchanged. GitHub,
Hacker News, Lobsters and Wikipedia remain exact twice, with all 33 GitHub rows
and 30 Hacker News stories audited. All other preceding workload counts are
unchanged. Twenty-eight native pairs repeat exactly. CNN remains 175,866 pixels
different from Brave and differs between native repeats at 655 pixels, alongside
its retained source/replay failure. Matching tall-shadow captures in this run
do not clear the earlier baseline repeat failure.

Initial non-activating candidates, a test fixture that initially omitted recorded
clip metadata, formatter/import errors, an intentionally stopped stale compile,
pruned compiler/font-runtime failures and a concurrent LibJS compile failure
are retained separately from the final passing checks. The final diagnostic
uses the available staged compiler and freshly prepared font runtime; no shared
production bundle was replaced for this check.

Production `aa19da69`, receipt `20261114-191855-433aa86a`, still supplies the
810-pixel vlang.io baseline and lacks these changes. **284 remains a diagnostic
result pending the managed production rebuild.** The normal commit hook requests
a coalesced C backend, literal V `-prod`, single-unit build. No duplicate manual
production build is requested. All-site equality remains open, including CNN,
the missing original Reddit fixture and the retained repeatability failure.
These frozen captures establish no live-site, author-script or performance
acceptance.

Commands, source/executable identities, font/runtime identities, reference crop
provenance, actual exits, PNGs and failed attempts are local under
`docs/performance/vlang-gradients-20261114/raw/orbit-text-20261114/`.
Completed job scratch and the temporary harness symlink are removed after
verified archival.


## Scaled JPEG avatar planes, 2026-11-15

`e63689e7a` filters JPEG luma and chroma planes before RGB conversion for
eligible small circular minified avatars. The preceding RGBA decode/resize path
reconstructed chroma and clipped colors before reducing the image. The new V
path promotes resized chroma to 4:4:4 at the upload size, then uses the existing
sampled-image painter and clip. It follows the plane scaling and chroma promotion
in [Chromium's GPU image decode cache](https://raw.githubusercontent.com/chromium/chromium/main/cc/tiles/gpu_image_decode_cache.cc).
This source reference describes the algorithm; the browser measurements below
establish the observed result against the pinned Brave image.

Eligibility requires an opaque, full-source, untransformed, circular avatar no
larger than 32 CSS pixels and at least twofold minification in both dimensions.
The existing native boundary additionally requires backing scale 1 and a readable
compositor destination. Unsupported color profiles, non-default or malformed
EXIF orientation, other geometry and sampling modes retain ordinary replay.
The upload cache has its own namespace and keys source content and decoded size.
No shaders, native UI, existing expected images or tolerances change.

The final diagnostic executable SHA-256 is
`11b526d3a485d5f9c31a9f2f0a80b59d0d7d4dc7f77cb752a7bd54407ca71bd7`.
Two fresh vlang.io captures each improve **284 to 111 differing pixels**:
**173 corrected, zero new differences**. The trace verifies that the 540×540
JPEG uses a 34×34 plane upload. Its remaining JPEG errors decrease from 279 to
106 pixels; the one heading pixel and four scene pixels remain unchanged.
This is progress toward equality, not a pixel-exact JPEG result.

All five C-backend YUV test files pass, including five new cases for neutral
chroma, fractional resizing, promotion before RGB clipping, invalid dimensions
and payloads, and EXIF validation in both byte orders. Runtime checks use the
3 GiB memory guard and `VOX_ARENA_POISON=1`. The initial default FastC attempt
failed to compile a loop; C compilation then caught an array assignment requiring
an explicit clone. Those failed attempts and the corrected passing checks are
retained separately.

The final cohort covers 30 workloads, 60 document captures and startup. All 61
native guards, the driver and outer guard exit 0; 60 rendering-source and six
tool witnesses stay unchanged. GitHub, Hacker News, Lobsters and Wikipedia
remain exact twice, preserving all 33 GitHub rows and 30 Hacker News stories.
The existing unscaled fractional JPEG avatar remains exact twice. All preceding
control counts remain unchanged. Twenty-nine native pairs repeat exactly; CNN
retains 175,866 differences against Brave and 519 between native repeats, alongside
its prior source/replay failure. This cohort does not clear the historical
tall-shadow baseline repeat failure.

Production `aa19da69`, receipt `20261114-191855-433aa86a`, still supplies the
810-pixel baseline and lacks the pending fixes. **111 is diagnostic pending the
managed production rebuild.** Normal commit hooks request a coalesced C backend,
literal V `-prod`, single-unit build. All-site equality remains open, including
CNN and the missing original Reddit fixture. No live-site, scripting or
performance acceptance is claimed.

Commands, source/executable witnesses, PNGs, actual exits, failed attempts and
transition counts are local under
`docs/performance/vlang-gradients-20261114/raw/jpeg-upload-20261115/`.
Completed scratch jobs are removed after verified archival.


## Fractional JPEG texture colors: partial improvement, 2026-11-15

`f0b7f4a68` retains scaled JPEG RGB as floating components through the base texture
sample and clip. The preceding upload quantized every converted source texel to
RGB8 first. V now carries opaque RGBA32F rows through the existing native pixel
transfer and the repository's V canvas adapter. The existing byte mip levels,
geometry, clip and shader remain unchanged. Other image payloads keep the byte
path. Invalid components, non-opaque colors and unsupported sizes are rejected
before publication; eligibility remains limited to the preceding JPEG slice.

Final diagnostic executable SHA-256:
`1068803693eb4c8ade628cf3ee78d4579a0e445366fbb4f45d8f85d74e2d8650`.
Two fresh vlang.io captures each have **28 differing pixels**, down from 111.
This corrects **92 pixels but introduces nine new one-level pixel differences**,
all in the same still-failing JPEG, for **83 fewer differences overall**. The
JPEG retains 23 differing pixels; the heading pixel and four scene pixels are
unchanged. This is a partial precision improvement, not JPEG pixel equality.
Existing expected images and tolerances are unchanged. The installed Brave
identity still matches the independent archived references.

All five C-backend YUV test files pass, including the new fractional conversion
case. Two GPU cases pass for sampled fractional colors in single/multisample
surfaces and rejection of malformed/non-opaque inputs without changing the
destination. Runtime checks use the 3 GiB guard and `VOX_ARENA_POISON=1`.

The stable-input cohort covers 30 workloads, 60 document captures and startup;
all 61 native guards, the driver and outer guard exit 0. Its 61 rendering-source
and six tool witnesses remain unchanged. The other 29 workload counts are
unchanged, including four exact archives and the exact unscaled JPEG avatar.
GitHub's 33 rows and Hacker News's 30 stories pass their content audits. All 30
native pairs repeat exactly in this cohort. CNN still differs from Brave at
175,866 pixels, and its historical source/replay and repeatability failures,
alongside the earlier tall-shadow baseline failure, remain open.

The preceding cohort is retained as rejected input-coherence evidence: the
managed worker refreshed the staged graphics helper during capture, changing
one trailing newline. Its native driver exited 0 with matching counts, but the
source-audit supervisor exited 1. The entire cohort was repeated with unchanged
inputs to obtain the stable result above.

Production `aa19da69`, receipt `20261114-191855-433aa86a`, remains the completed
810-pixel baseline. **28 is diagnostic pending the managed production rebuild**;
normal hooks request coalesced C backend, literal V `-prod`, single-unit builds.
All-site equality remains open, including the missing original Reddit fixture.
No live-site, scripting or performance acceptance is claimed.

Local evidence, including both cohorts, exact transition counts, remaining
pixel coordinates, source witnesses, commands and actual exits, is under
`docs/performance/vlang-gradients-20261114/raw/jpeg-float-20261115/`.
Completed scratch jobs are removed after verified archival.


## Production confirmation of the 28-pixel result, 2026-11-15

The latest completed production bundle tested here is
`05e6ace1a48deb21b40a1b731885229088f8b5abf6940df2ebbd205dcc044e33`, receipt
`20261115-004720-a7e0da7f`. It uses the C backend, literal V `-prod` and one C
unit. All **61 selected rendering-source hashes** match the verified compiled
manifest. This confirms the previously pending recorded filter clip, gradient
picture isolation, shared shape/glyph samples, scaled JPEG planes and fractional
texture changes in production. No additional manual build was requested.

Thirty workloads were captured twice through fresh processes with private
profiles and the existing viewport, scale, replay and author-script policies.
All 60 native capture guards, the driver and outer guard exit 0. The 61 rendering
and six tool witnesses remain unchanged through the run. Every reference count
matches the preceding diagnostic cohort:

| Workload | Production differing pixels |
| --- | ---: |
| GitHub / Hacker News / Lobsters / Wikipedia | **0 each, twice** |
| vlang.io | **28, twice**, down from the previously confirmed 810 |
| Unscaled fractional JPEG avatar | **0, twice** |
| Other preceding controls | Unchanged |
| CNN | **175,866, twice** |

Vlang.io's production PNG also matches the accepted diagnostic PNG exactly.
The remaining 23 JPEG pixels, one heading pixel and four scene pixels therefore
include the same **nine introduced one-level JPEG differences** documented in
the partial precision slice. No expected image or tolerance changes. GitHub's
33 rows and Hacker News's 30 stories pass their content audits. Twenty-nine
native pairs repeat exactly; CNN differs between repeats at 1,558 pixels.
CNN's prior source/replay mismatch and the historical tall-shadow baseline
repeat failure remain open.

An initial attempt supplied the build request's commit as `--feature-revision`.
That revision predates later dirty buffers in the verified compilation, so the
guard correctly rejected it before capture. The successful default check instead
compares the actual current feature bytes with the exact compiled manifest; all
match. Both attempts are retained. The production receipt's request revision
alone is not treated as proof of its compiled sources.

Two currently edited files, `layout/clean_subtree_reuse.v` and
`layout/document_tree_builder.v`, differ from this bundle's compiled manifest.
Those uncompiled changes are outside this validation. The result establishes
the published production bundle's frozen-page behavior, not equality for every
current checkout edit, live site, script behavior or performance metric.
All-site parity remains open, including the missing original Reddit fixture.

A separate GPU diagnostic reproduces the JPEG's 23-pixel residual. Unclamped
source colors and the default normalized matrix from
[upstream SkYUVMath](https://raw.githubusercontent.com/google/skia/main/src/core/SkYUVMath.cpp)
retain the same count, so neither was applied. Initial probe arithmetic produced
black source colors and failed calibration; explicit floating arithmetic restored
the control. Those invalid initial outputs are retained but supply no rendering
conclusion. No renderer code changed in this confirmation slice.

Local receipts, compiled-source comparisons, both production attempts, PNGs,
actual exits and diagnostic logs are under
`docs/performance/vlang-gradients-20261114/raw/production-28-20261115/`.
Completed scratch and the temporary diagnostic source are removed after verified
archival. The normal documentation commit hook requests a coalesced managed
production rebuild.


## Text-gradient coordinates inside recorded layers, 2026-11-15

Commit `4e3445943` removes vlang.io's final heading difference. The gradient
previously retained large page coordinates while drawing into its small text
picture. Cancelling the page translation in the vertex shader changes one
rounded green value. The V graphics adapter now copies eligible line-only paths
into local coordinates, translates their gradient and rounded clips consistently,
and leaves the original descriptor untouched. Selection stays inside the
existing scale-1 text-layer grid. Curves, strokes, fractional translations,
transformed pictures, unsupported matrices and other gradients keep their
previous route. No shader, dither, glyph coverage or existing reference changes.

Diagnostic executable SHA-256
`a7e79f64bee143d2d47b941b1f3d40fcf12479fde41e0917fd433e11f5516cfb`
improves the full archived page **28 → 27**, twice: **one corrected pixel and
none introduced**. Only (871,264) changes, from RGBA (177,202,233,255) to the
unchanged Brave value (177,201,233,255). All 23 JPEG and four scene differences
remain. The JPEG still includes the nine introduced one-level differences from
the earlier fractional-texture slice.

The focused oracle uses an unchanged 78×79 Brave crop at (854,208), together
with the retained glyph mask as input. The old path differs at one of its 991
fully covered samples; local coordinates match all 991. The second new case
checks clip translation, source immutability and unsupported-input rejection.
Both new GPU cases and seven existing root gradient cases execute successfully
under 3 GiB guards with arena poisoning; actual calls and zero exits are retained.
The two PNG resources are lossless derivatives of existing reference/input
bytes, independently verified after encoding, and do not replace page references.

A stable 33-workload cohort produces 66 fresh document captures plus a separate
startup check, all 67 native guards and driver/outer exits zero. All 83 selected
rendering/tool/resource witnesses stay unchanged through capture. The other 32
reference counts are unchanged. GitHub, Hacker News, Lobsters and Wikipedia
remain exact twice, with all 33 GitHub rows and 30 HN stories audited. Thirty-two
native pairs repeat exactly; CNN remains at 175,866 differing pixels and its
pair differs at 1,558 pixels. Historical CNN source/replay, tall-shadow
repeatability and missing original Reddit failures remain open.

Fresh production controls match the candidate: the fractional text-grid fixture
retains 2,214 pixels, text-clip scope stays exact and compositor backdrop retains
one pixel, each twice. Four additional Retina captures retain the existing 1,767
reference differences and production/candidate PNG equality in both pairs. The
higher-scale route remains unchanged. The available production `90aaf0a5`, receipt
`20261115-005842-658dc21d` (C, literal `-prod`, single unit), separately reproduces
vlang.io at 28 twice; it predates this fix. The 27-pixel result is **diagnostic,
pending managed production confirmation**, not a live-site or performance claim.

An initial browser compile fails on unfinished foreign LibJS Set declarations.
Later successful compilations retain unchanged selected rendering inputs, while
an unrelated LibJS realm source changes. Both source comparisons are preserved;
the final comparison is tied to its fixed executable and default JavaScriptCore
capture policy, not whole-checkout reproducibility or LibJS validation. All
selected rendering inputs remain unchanged through compilation and capture.

Earlier isolated JPEG probes supply no accepted change. Half precision after
texture sampling worsens 23 differences to 41; explicit derivative-based LOD,
a different sharpen bias and base-only sampling worsen the result to 114 or
172. The initial heading probe uses incorrect color stops and fails calibration;
only the corrected source stops reproduce the one-pixel control. These attempts
are retained. Both experimental GG helpers/shaders were restored byte-for-byte,
and temporary probe source is removed.

Local commands, input/source hashes, asset provenance, PNGs, actual exits,
failed attempts and selected archived scratch are under
`docs/performance/vlang-gradients-20261114/raw/jpeg-sample-precision-20261115/`.
Completed job directories, guards, generated C and binaries are removed after
verified archival. The normal commit hook requests the coalesced production
rebuild; no duplicate manual build is queued. All-site equality remains open.


## Production confirmation of the 27-pixel result, 2026-11-15

The completed production bundle became available during closeout. Executable
`01436d0a3575be46dc850d0450af7480f4b5fd97a0fae0de63263489ae0eb34d`,
receipt `20261115-013256-3c6d2644`, uses the C backend, literal V `-prod` and a
single C unit. All 62 selected rendering-source witnesses match its exact
compiled manifest, including `4e3445943`. No extra build was requested.

Thirty-three workloads captured twice confirm **vlang.io at 27 pixels**, the
four exact archived sites and every other diagnostic reference count unchanged.
Vlang.io's production and accepted diagnostic PNGs match exactly. The heading
is now exact; the 23 JPEG and four scene differences, including the earlier nine
introduced JPEG pixels, remain. All 66 native capture guards, driver and outer
guard exit zero; 69 source/tool witnesses stay unchanged. GitHub's 33 rows and
HN's 30 stories pass their audits. Thirty-two native pairs repeat exactly; CNN
remains at 175,866 pixels and its pair differs at 1,540 pixels.

The previously pending layout sources checked against this receipt now match,
including clean-subtree reuse and the document-tree builder. A newer uncompiled
capture-audit edit is outside this validation. The earlier diagnostic pending
status is superseded for this gradient fix; all-site, live-site, scripting and
performance parity remain open. Production receipts, source witnesses and all
captures are retained alongside the preceding evidence under
`raw/jpeg-sample-precision-20261115/production27-summary.json` in the local
performance evidence directory. Completed production-check scratch is archived
and removed. The ordinary documentation hook requests the next coalesced build.


## Restored shader baseline and complete GG witnesses, 2026-11-15

No additional scene-gradient correction was accepted. Broader linear localization
introduces one pixel at (492, 557); radial localization, equivalent center/extent
forms and a calibrated precomputed colorizer leave the three underlay differences
unchanged. Tracing confirms those three pixels are already wrong after radial
painting, with exact incoming backgrounds. All experiments are reverted; no
reference, tolerance or coordinate-specific color adjustment is accepted.

An automatic production build consumed a temporary staged GG colorizer experiment
during this audit. Executable `2827b9be`, receipt `20261115-021725-4ab63d5a`,
is rejected: vlang.io differs at 490,268 pixels. The previous 62-file manual source
shortlist omitted `gpu_gradient.v`; successful process exits and unchanged
shortlisted sources did not establish correct rendering. This failed cohort and
its consumed-source receipts are retained.

`e0fec36b2` adds package-wide compiled V source witnesses, with 23 focused Python
tests passing. The comparison driver now checks all 64 consumed GG V files,
including staged adapters and compiler-vlib sources, before capture and retains
source pins throughout. It rejects the actual bad receipt at `gpu_gradient.v`
and accepts the restored one. This check covers V buffers; embedded resources
and native libraries require separate identity checks. All 24 current Metal
shader payloads are found byte-for-byte in the restored executable.

Restored production executable
`73e7c2752a11a78cd30d8ab0cdf62482747a4efa433700e1ca26b3b3fcb4f409`,
receipt `20261115-023044-27db595c`, uses literal V `-prod`, C and one C unit.
Thirty-three workloads captured twice retain every preceding reference count:
four archived sites exact, vlang.io 27, CNN 175,866. All 66 native guards and
both enclosing exits are zero; 122 compiled rendering witnesses and 130 captured
source/tool witnesses pass. CNN's pair still differs at 419 pixels. No extra
manual production build was requested.

## Opaque lossless WebP sampling, 2026-11-15

`c242016bb` routes downscaled, opaque, simple VP8L images through the existing
sampled-image upload and CPU mip chain. Previously they used the generic image
replay filter. Uploads retain document, navigation, resource and compositor
scope, and own their pixels beyond the scratch decode scope. Lossy, alpha,
profiled/extended and animated streams, cropped sources and other unsupported
paint states keep their existing paths. CNN's major photographs are lossy WebP;
this correction does not fix them.

| Unchanged Brave reference | Before | After, each of two fresh native captures |
| --- | ---: | ---: |
| Opaque WebP mip texture, 240×135 | 32,399 | **0** |
| Opaque WebP mip blending, 320×180 | 57,599 | **0** |

Two fresh Brave captures per four WebP controls repeat exactly and match their
original references. Two browser-focused tests cover eligibility, cache ownership
and compositor scope. The GPU test checks both lossless references at 1× and 4×
sampling. All focused builds and arena-poisoned runtime guards exit zero.
The first probe compile missed its decoder header; another probe loaded an
unrelated 4×2 asset. Both invalid attempts are retained alongside the corrected
fixture calibration.

Diagnostic executable
`a1f5d135667093a3a1329736bcf43a612fd5c729f0293dfccedcce503d7a2429`
passes a 44-workload, 88-capture check with 134 stable source/tool witnesses.
All 89 capture/startup guards, driver and outer guard exit zero. All preceding
33 reference counts and five other WebP counts remain unchanged; four PNG
sampling controls are exact. Forty-three pairs repeat exactly; CNN differs at
1,406 pixels between native captures. Vlang.io's PNG is unchanged from the
restored production result. Its 23 JPEG pixels still include the nine historical
introduced pixels, and its four scene pixels remain.

The normal commit hook requests production validation; this lossless WebP result
is **diagnostic pending production**. One earlier managed build rejected source
membership changes and retained the completed bundle; its failed receipt remains
in the evidence. No duplicate manual build was queued. CNN's source/replay and
repeat failures, missing Reddit fixture, historical tall-shadow repeat failure
and all-site equality remain open. These frozen-page checks supply no live-site,
scripting or performance acceptance.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/scene-coordinates-20261115/`:
restored/rejected production summaries, WebP baseline/candidate summaries,
source and decoder identities, commands, actual exits, all failed probes,
unchanged-reference PNGs and verified archival manifests. All 99 owned scratch
roots (10,073 file records) were hashed; selected evidence was copied and
reverified before removing jobs, binaries and guard files. Temporary source and
test-harness links are removed.


## Native-size and half-size lossy WebP sampling, 2026-11-15

`df3fea85d` samples simple opaque VP8 planes before RGB conversion. Native-size
images interpolate 4:2:0 chroma at luma centers; half-size images first reduce
luma to bytes, then use the original chroma at full resolution. Fractional RGB
survives until coverage and final framebuffer rounding. The normalized limited-
range matrix follows [SkYUVMath](https://raw.githubusercontent.com/google/skia/main/src/core/SkYUVMath.cpp).
Chromium's [WebP decoder](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/platform/image-decoders/webp/webp_image_decoder.cc)
identifies this YUV color space and plane layout; the comparison still depends
on the pinned Brave references, not an assumption that its installed source is
identical to current upstream.

| Unchanged Brave reference | Before | After, each of two fresh native captures |
| --- | ---: | ---: |
| Native-size lossy WebP, 140×94 | 9,981 | **0** |
| Half-size lossy WebP, 70×47 | 3,288 | **0** |

The path accepts bounded even-sized images, complete matching frame dimensions,
full source rectangles, integral placement, identity linear transforms and
opaque Chromium-policy painting at those two sizes. Unsupported scales,
subpixel placement, other formats and paint states retain their existing path.
The cache separates output sizes and document/navigation/resource/compositor
scope, owns its floating pixels beyond scratch lifetime, and respects the
historical incremental-RGB policy. The dormant generic YUV image capability
remains disabled. CNN's arbitrary-scale photographs are outside this fix.

All six YUV test files pass with GC disabled, including three new cases for
luma reduction, fractional chroma and rejected inputs. Two browser tests pass
with arena poisoning under both normal and historical paint policies. The GPU
test matches both references at 1× and 4× sampling. Its first compile fails on
untyped pointer arithmetic; the corrected element-address version passes.

Diagnostic executable
`227764bee14ac9ce6ccdcd10871fc4c05d03213f68a667efe3bea79a02020b92`
completes 44 workloads and 88 fresh captures. All 89 native/startup guards,
driver and outer guard exit zero. There are 117 compiler-parsed rendering V
witnesses, including all 64 GG sources, and 164 stable source/tool/shader pins.
Native inputs have separate witnesses; this is not whole-checkout or LibJS
validation. All other reference counts remain unchanged, including the exact
lossless controls and four archived sites, vlang.io at 27 and CNN at 175,866.
Forty-three pairs repeat exactly; CNN's pair differs at 1,517 pixels. Brave's
identity is unchanged from the preceding independent repeated-reference check.

Broader rescaling is not accepted. An isolated Metal plane sampler leaves
182–185 enlarged-image differences without fast math, or 171 with it, all one
level; the initial mode introduces three previously exact pixels. A higher-
precision matrix regresses the native-size/half-size controls to four/one and
the enlarged control to 331–332. A double-precision CPU enlarged sampler leaves
79,757 differences. These attempts are retained; no native sampler or shader
experiment is shipped by this commit.

The new fix is **diagnostic pending production**. A completed production
preview contains earlier bytes of the two lossy helpers and is rejected for
final implementation validation. Future production checks now verify all
consumed V files in `gg`, `ggshape`, `images`, `imageraster` and `yuv`, rather
than adding only individual image helpers to the manual shortlist. This
expansion happened after the captured cohort; the captured driver's original
bytes are retained.
Normal commit hooks request coalesced rebuilds; no manual duplicate is queued.

Local evidence, including every failed probe, source scopes, identities,
commands, actual exits, PNGs and verified scratch archival, is under
`docs/performance/vlang-gradients-20261114/raw/lossy-webp-20261115/`.
Vlang.io's 23 JPEG pixels (including the earlier nine introduced pixels) and
four scene pixels remain. CNN's rendering, source/replay and native-repeat
failures, missing Reddit fixture and historical tall-shadow failure remain
open. No live-site, scripting or performance acceptance is claimed.

## Production confirmation of the lossless WebP controls, 2026-11-15

The preceding `c242016bb` lossless correction is now confirmed in production
executable `5171fc6f3e1a086aaf72b11bcae0379e5a8bc7b7eaa74bc970f9b034619b2f89`,
receipt `20261115-032000-dd2d60f6`, C, literal V `-prod`, one C unit. Its main
caller, final lossless helper and all 64 consumed GG V sources match. The two
lossless controls are exact in two fresh captures each; all four capture guards
and the outer guard exit zero, with 112 selected compiled witnesses.

This focused confirmation covers the lossless controls only. The same preview
contains preliminary lossy helper bytes, so it cannot validate `df3fea85d`.
Earlier managed attempts reject a concurrent `tools/gc_allocation_sampler.c`
edit and retain the previous bundle; those failures remain recorded. Full
catalog equality and production validation of the final lossy fix stay open.


## Production confirmation of lossy WebP controls, 2026-11-15

The final `df3fea85d` helpers are now verified in production executable
`7f651f2d86709866c45ec1f069dcf17ed7aed25f201861a5dc0e3be23a2d98be`,
receipt `20261115-093837-2119e81e`, C, literal V `-prod`, one C unit. All
consumed V files in GG, ggshape, images, imageraster and yuv match, including
the final lossy helpers. The 44-workload, 88-capture cohort retains every
preceding reference count: four WebP controls and four archived sites exact,
vlang.io 27, CNN 175,866. All native guards, driver and outer guard exit zero,
with 133 selected compiled witnesses and 160 stable source/tool/shader pins.
Forty-three native pairs repeat exactly; CNN's pair differs at 1,554 pixels.
This supersedes the preceding lossy fix's pending-production status.

## Magnified alpha WebP sampling, 2026-11-15

`59d71dca9` samples simple, untagged VP8L images at native or larger sizes through
the existing GG image shader. Marker 7 already owns premultiplied rows; the
helper borrows those rows without applying alpha again, and leaves existing
resize history intact. The existing opaque minification path is retained.
Source/target bounds and existing paint-state restrictions still apply; alpha
minification, extended/profiled streams and unsupported paint states decline.
No native painter or shader changes are shipped.

The three untagged images in the unchanged alpha fixture become exact. Its
whole-document result improves from **10,274 to 2,658 differing pixels**, twice:
**7,616 corrected, zero introduced**. All remaining differences lie in the
profiled image at (320, 20), size 76×38. That image remains on the previous
renderer. A separate decoder probe also exposes RGB changes from the 8-bit
premultiply/unpremultiply round trip; interpolation and decoder work remain.
Ignoring its profile is not an accepted correction.

Two fresh Brave processes match the original reference exactly. The initial
probe incorrectly used 80×40 for the last two images; the `img + img` rule
actually sizes every later sibling to 76×38. The corrected dimensions agree
with Brave's recorded DOM rectangles. Rounded premultiplication and using the
authored fractional top instead of its existing paint snap fail calibration.
Those attempts are retained. Another focused compile fails after shared cleanup
prunes its old font dependency; it is rerun with the current published build's
font stage, preserving the sparse-font option.

Three browser-focused tests cover format eligibility, borrowed rows, persistent
resize-cache ownership and unchanged resize history. The GPU test matches all
three untagged images at both 1× and 4× sampling. Final arena-poisoned focused
runtime guards exit zero. An early prototype changed resize history on a native
upload; that side effect was removed before final validation, with its exact
consumed sources and non-final test results retained separately.

Diagnostic executable
`569d4bd3cb50decef3f3a5e74945dddfdbec33b61c4c6f3e4d9eea278ac49a31`
completes 44 workloads/88 captures, with all 89 capture/startup guards and both
enclosing exits zero. It has 100 compiled V witnesses and 162 stable source/tool
pins. Forty-three pairs repeat exactly; CNN differs at 551 pixels between
captures. Every stable non-alpha workload's pixels match the production
baseline exactly, beyond merely preserving its reference-difference count.

Production executable
`36f72f4aa98fc2734d6765842446a01a0a8aca92404c2e6bb932bb999944ab8f`,
receipt `20261115-112056-6ae3f0ff`, contains the final helper bytes and uses C,
literal V `-prod`, one C unit. A second 44-workload/88-capture cohort confirms
**2,658 alpha pixels twice**, all earlier reference counts and exact agreement
with the diagnostic PNGs for every workload except unstable CNN. All 88 native
guards, driver and outer guard exit zero; 133 compiled witnesses and 160 stable
source/tool/shader pins pass. Forty-three pairs repeat exactly; CNN's pair
still differs at 1,520 pixels. The final helper was consumed before the commit;
its byte witnesses establish code identity independently of the receipt's HEAD.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/webp-production-alpha-20261115/`:
production and candidate summaries, source/decoder identities, commands, actual
exits, failed calibrations and builds, decoded rows, PNGs and archival manifests.
Native libraries have separate identities; these checks do not establish whole-
checkout reproducibility or LibJS behavior. No reference or tolerance changes,
manual production build, live-site acceptance or performance credit are involved.
Completed scratch archival hashes 9,156 file records across 68
owned roots, copies and reverifies selected evidence, and removes all job
outputs, binaries, guards and locks. Temporary probe sources and the owned test
harness link are removed.

All-site equality remains open: vlang.io retains its 23 JPEG pixels (including
the historical nine introduced pixels) and four scene pixels; CNN retains
rendering/source-replay/repeat failures; Reddit's original fixture is missing.
The historical tall-shadow failure and other retained diagnostic failures also
remain open. The profiled alpha image is an additional unresolved control.


## Numerical sRGB profiles in lossless WebP, 2026-11-15

`a5b29f604` fixes the remaining 2,658 pixels in the alpha WebP control. V now
interprets a conservative subset of ICC RGB/XYZ matrix profiles: every primary
and every channel's parametric transfer curve must agree with named sRGB.
The 1/4096 numerical bound is stricter than Skia's canonicalization bounds.
Descriptions, producer strings, timestamps and fixture/profile hashes do not
select this path. Malformed/ambiguous tags, LUTs, CICP, other primaries or curves,
lossy and animated streams retain their previous decoder and renderer.

For the recognized color space, libwebp supplies its original straight rows,
avoiding the previous 8-bit premultiply/unpremultiply round trip. Chromium paint
then uses its existing truncated alpha multiplication and bounded GG sampling
at native or larger sizes. Alpha minification still declines; existing resize
history is unchanged. The native change factors out a straight decoder service;
no painter, shader or new browser dependency is introduced.

This follows the numerical canonicalization in
[SkColorSpace](https://skia.googlesource.com/skia/+/main/src/core/SkColorSpace.cpp)
and the no-transform decode path in
[SkWebpCodec](https://skia.googlesource.com/skia/+/main/src/codec/SkWebpCodec.cpp).
Local source copies retain their hashes. A separate test-only Skia oracle
recognizes both the original and renamed profiles as sRGB, and rejects the
changed primaries. It is not linked into the browser. Three profile tests cover
numbers, unsupported representations and malformed/truncated containers. Seven
browser checks exercise straight rows, local/fetched parity, borrowed uploads,
cache history, bounds and the non-sRGB fallback. All pass with arena poisoning
and 3 GiB runtime guards. Eight GPU draws, covering all four images at both 1×
and 4× sampling, match the unchanged Brave pixels.

Diagnostic executable
`6d8bc17fb89814f58977813fafb64c958ba95edfd74619f88ec5d8a856a5b5a6`
(C/O0, prealloc, GC none) completes 44 workloads and 88 fresh captures. The
alpha control is **exact twice: 2,658 corrected pixels, zero introduced**.
The preceding 7,616-pixel correction is retained. Two fresh Brave captures also
match the original reference exactly. All other reference-difference counts
are unchanged; all 42 non-alpha/non-CNN workloads' PNGs match the preceding
production captures pixel for pixel. The four exact site archives remain exact.
Vlang.io stays at 27 pixels, including the historical nine introduced JPEG
pixels. CNN stays at 175,866 and fails its native repeat at 1,534 pixels.
Forty-three native pairs repeat exactly.

All 89 capture/startup guards, the driver and outer guard exit zero, with
100 consumed V witnesses and 166 stable source/tool/shader pins. Native
libraries and the decoder header have separate identities. These are selected
rendering-source checks, not whole-checkout or LibJS validation. The completed
production baseline `dee877bf591a539e1d6c9b59582291ab8fbd0805dd8baed845918fb28dc5fb5f`,
receipt `20261115-121056-e24d3a67`, still has the previous helper bytes and
reproduces 2,658 alpha pixels twice. It cannot validate the new code.
**The new correction remains diagnostic pending production.** The ordinary
commit hook requests the coalesced C backend/literal V `-prod` rebuild; no
manual duplicate is queued.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/webp-srgb-profile-20261115/`,
including consumed-source identities, commands, actual exits, oracle profiles,
unchanged-reference comparisons, transition coordinates and cleanup manifests.
All-site equality remains open: Vlang's JPEG/scene pixels, CNN's rendering,
source/replay and repeatability failures, the missing Reddit fixture, the other
ICC/rescaling controls and historical diagnostic failures remain unresolved.
No live-site, scripting or performance acceptance is claimed.


Scratch archival hashes 3,134 file records across 50 owned roots, preserves
1,027 selected evidence files (23,929,728 bytes), reverifies the copies, and
removes all owned job outputs, binaries, guards and locks. The temporary
Skia oracle source and three test-harness links are also removed.


## Production confirmation of numerical sRGB WebP, 2026-11-15

The final `a5b29f604` correction is now confirmed in production executable
`a542533fba25473552d7afb35fd50cc49caea8a42ff4159c89b3ba3119d4f91e`,
receipt `20261115-122533-7861f9dc`, C, literal V `-prod`, one C unit. Its final
helper, parser, main caller and decoder header match the sealed build inputs.
The code was consumed before the commit; byte witnesses establish identity
independently of the receipt's HEAD. The new 44-workload/88-capture cohort has
134 selected compiled V witnesses and 164 stable source/tool/shader pins.
All 88 native guards, the driver and outer guard exit zero.

**The complete alpha control is exact twice in production**, including its
profiled fourth image. Every other reference count is retained, and all
43 non-CNN workloads' PNGs agree exactly with the accepted diagnostic build.
Forty-three pairs repeat exactly. CNN retains 175,866 reference differences and
fails its native repeat at 1,511 pixels. The four exact site archives stay exact;
Vlang.io retains 27 pixels. This supersedes the preceding pending-production
status. The optional decoder's library identity also remains unchanged.

The production summary, receipt metadata and source witnesses are retained in
the same local evidence directory. A second verified archive removes
9 production job roots after hashing 3,026 file records and
preserving 955 selected files (22,601,407 bytes).
All owned scratch outputs, binaries, guards and locks are removed. All-site
pixel equality, live behavior, scripting and performance acceptance remain open
as described above.

## Sampled sRGB profiles and RGB WebP minification, 2026-11-15

`1e1ffdd4e` extends the numerical ICC classifier to dense `curv` tables with
256–4,096 knots. Every knot must be monotonic and within 1/4096 of the sRGB
transfer curve, alongside the existing conservative RGB/XYZ matrix checks.
Sparse, malformed, animated, alpha-VP8 and other color spaces retain their
prior paths. An independent test-only Skia oracle identifies nine of ten CNN
ICC images as sRGB; the wide-gamut negative remains rejected. Descriptions,
dates and image identities do not select the rendering path.

Opaque profiled VP8 retains full decoded RGB rows and uses the existing GPU
mip sampler for supported full-source, identity-linear-transform draws.
Chromium's WebP decoder disables YUV when ICCP is present, including canonical
sRGB, so the untagged YUV path remains ineligible. No shader, native painter
or browser dependency is added. Blink source/download records are retained
with the probe sources. Scaled-codec and CPU-mip probes against the unchanged
control failed; full RGB GPU-mip draws are exact at sample counts 1 and 4.
An independent Skia RGB resize probe agrees with the existing CPU resize
bytes; no CPU resize arithmetic changed.

The new `webp-srgb-table` reference was captured twice in fresh Brave
157.1.99.57 processes, with exact repeat, before the renderer correction.
It draws the tracked train WebP at native size, as a 104×58.5 CSS-pixel
thumbnail and clipped by the bottom of the viewport. Its reference SHA-256 is
`141711ca2cdcd062dc1cbfaf031df00d6366141ea67a1713b3b1abc20b0a9c1e`.
No existing reference or tolerance changed.

The final diagnostic browser is C/O0 executable
`4b282d362c7381e81bb09c40b11f951aee892eb8dc10f0b158482132bb1e5d40`.
Its compiler buffers witness 101 consumed V rendering inputs, including the
new helper. Six profile tests, one final browser decode/eligibility test and
six GPU draws pass through the required guards. The browser test has 102
consumed renderer/test witnesses. It rejects the lossless and untagged YUV
routes for this image, invalid upload markers, dimensions and file-backed
images.

The new control improves **5,059→588 pixels twice: 4,471 corrected, zero
introduced**. Its native-size and small images are exact. All 588 remaining
pixels belong to the bottom-clipped image: the browser does not yet match
the isolated sampler there. This is **not** a full-viewport pass.
Classification alone retained all 5,059 differences and earns no sampling
correction credit.

The final **45-workload/90-capture** cohort retains 171 stable source/tool/shader
pins. All 91 native startup/capture guards, the driver and enclosing guard exit
zero. **All 45 native pairs repeat exactly**, including CNN, whose reference
difference improves **175,866→165,579**. This supersedes the preceding native
repeat failure for this diagnostic cohort; it does not repair CNN's historical
source/replay mismatch. All **43 other existing workloads' PNGs** match the
preceding production captures exactly. GitHub, Hacker News, Wikipedia and
Lobsters remain exact. Vlang remains at 27 pixels, including its historical
nine introduced JPEG differences. Engadget's ICC control retains 124,925 and
the root-raster WebP control retains 541,745 differences.

The latest completed production executable checked here is `4a0da515ac04…`;
its sealed source manifest lacks the new helper and retains the older
classifier. It cannot validate this code. The commit hook requests the
coalesced C/literal V `-prod` rebuild. **Production confirmation is pending**;
no duplicate production build was queued.

The earlier JPEG investigation found exact agreement between Skia R8
nearest-mipmap scaling and V's retained planes. Twenty-one of 23 residual
JPEG pixels are fully opaque. A private half-precision shader-output probe
worsened the calibrated control from 23 to 34. These probes were rejected,
results retained, and shared GG/shaders were not edited.

Evidence, failed disk-space attempts, commands/exits, compiler witnesses,
reference transitions and cleanup manifests are local under
`docs/performance/vlang-gradients-20261114/raw/webp-table-20261115/` and
`raw/jpeg-oracle-20261115/`. Disk space recovered before the final normal
V/C compile; the intermediate C-only output was not linked or modified.
All-site equality remains open: the clipped image, Vlang, CNN's remaining
rendering/source-replay failures, the missing Reddit fixture and the earlier
controls. No live-site, scripting or performance acceptance is claimed.

The initial verified archive hashes 700 file records across 105 owned roots
and preserves 239 selected files (32,588,709 bytes). The final archive hashes
3,520 file records across 25 owned roots and preserves 1,045 selected files
(28,648,574 bytes). Copies are hash-verified before deleting owned scratch
outputs, generated C, binaries, guards and locks. The temporary test alias is
also removed. Shared production bundles, libraries and dependencies are retained.

## Production confirmation of sampled sRGB WebP, 2026-11-15

The preceding `1e1ffdd4e` correction is confirmed in production executable
`73cc5a369ba8dcf011521ec9ea5bb00038a62a82a1f8f0c926fca57f8f48e54b`,
receipt `20261115-140919-8b8a4fe0`, C/literal V `-prod`, one C unit. The sealed
buffers contain the final helper, classifier, premultiplication helper and main
caller; their bytes establish identity independently of the receipt's HEAD.
The new 45-workload/90-capture cohort retains 135 selected compiled witnesses
and 167 source/tool/shader pins. All 90 native guards and driver/outer exits
are zero. All 45 pairs repeat exactly and every reference-difference count
matches the accepted diagnostic, including the WebP control's retained 588.

All 44 non-CNN PNGs match the accepted diagnostic exactly. CNN retains 165,579
reference differences and repeats exactly within production, but its PNG
has 1,558 differences from the preceding C/O0 diagnostic. The first summary's
cross-build-zero assertion failed on CNN. That failure is retained; the later
analysis records this gap explicitly and does not claim cross-build CNN
identity. No successful capture was repeated or excluded to change the result.
This supersedes the prior pending-production status for `1e1ffdd4e`; the
remaining clipped-image defect is addressed separately below.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/webp-clipped-20261115/`.

## Sampled-image compositor readback fringes, 2026-11-15

`78f1fcf3b` resolves the new control's remaining clipped image. A temporary
browser trace identifies its compositor origin as (460, 753), while the native
backdrop readback begins at (458, 751), size 108×41. The image sample selector
rejects this two-pixel fringe, returning zero and forcing the older painter.
Standalone full, small and tile-sized GPU surfaces all match the same Brave
pixels at sample counts 1 and 4; their size is not the cause.

The correction reuses `geometry_grid_covers_leaf`, already used by other leaf
painters. It chooses samples from the readback's intersection with its owning
grid; the fringe owns no additional tile. More than two pixels of overhang,
empty intersections and mixed sample selections still decline. Three focused
regression functions reproduce the old failure and pass after the V change.
The callback regression uses the real tracked WebP and unchanged Brave PNG,
including both sample counts. Temporary V/native logging is reverted before
the final compile; no native painter, shader or decode changes ship.

The final C/O0 diagnostic executable is
`ab5bd846e3e8404e7f850b0ef16fcc0f45e4749fd110fafb88b1fca78b5270ec`.
Its compiler buffers witness 161 consumed V inputs across Chromium, images,
GG, GGShape, imageraster, YUV and the main caller. The final focused binary has
162 renderer/test witnesses. The complete `webp-srgb-table` browser control is
**exact twice: 588 corrected, zero introduced**, resolving the original 5,059
control differences across the two corrections. The reference, decoder library
and native adapter retain their earlier hashes.

The complete 45-workload/90-capture cohort retains 209 stable source/tool/shader
pins. All 91 native startup/capture guards, the driver and enclosing guard exit
zero. All 43 existing non-CNN/non-control PNGs match both preceding production
and diagnostic captures exactly. GitHub, Hacker News, Wikipedia and Lobsters
remain exact; Vlang retains 27, Engadget's ICC control 124,925 and the root-raster
WebP control 541,745 reference differences.

**CNN's native repeat fails again at 1,558 pixels**, bounds (460, 753)–(563, 767),
maximum channel error 146. Both captures retain 165,579 reference differences.
Its first capture differs by 1,521 pixels from the preceding production and by
1,557 from the preceding diagnostic. The first final-summary assertion failed
on this repeat; the failed analysis, captures and comparison remain retained.
The completed analysis records the failure explicitly. No successful capture
was repeated or excluded, and no CNN stability or all-site pass is claimed.
The matching photograph region has recurring repeat failures in earlier
cohorts; this observation does not attribute the failure to a specific fix.
Forty-four native pairs, including the corrected control, repeat exactly.

The available production bundle `73cc5a36` still has the previous sample-selector
bytes. It establishes the preceding correction's production result, but cannot
validate this one. The managed commit hook requests the coalesced C/literal V
`-prod` rebuild. **Production confirmation of `78f1fcf3b` remains pending**;
no additional production build is manually queued.

Raw commands, actual exits, original regression failures, diagnostic sources,
compiler witnesses, reference transitions, both summary failures and cleanup
records remain local under
`docs/performance/vlang-gradients-20261114/raw/webp-clipped-20261115/`.
All-site equality remains open: Vlang, CNN rendering/source-replay/repeatability,
the missing Reddit fixture and earlier controls. No live-site, scripting or
performance acceptance is claimed.

The verified cleanup hashes 6,703 file records across 48 owned job roots and
preserves 2,131 selected files (55,080,253 bytes). Copies are hash-verified
before removing owned generated C, binaries, job outputs, guards and locks.
The temporary test alias and GPU probe source are removed; shared production
bundles, libraries and dependencies remain intact.

## Production confirmation of sampled-image fringes, 2026-11-15

The final `78f1fcf3b` correction is confirmed in production executable
`2e08971261e0625d26c1005f1dcd859421619ae6b19ff16c9e9f2459e7d256fc`,
receipt `20261115-142738-638a0adf`, C/literal V `-prod`, one C unit. The
sealed sample-selector bytes match the committed correction, independently
of the receipt's earlier HEAD. The new guard-complete 45-workload/90-capture
cohort preserves 136 selected per-capture source witnesses, 160 consumed
package V witnesses (including Chromium), and 209 stable source/tool/shader
pins. All 90 native guards, the comparison driver and enclosing guard exit zero.

**The complete WebP control is exact twice in production.** All 44 non-CNN
PNGs match the final diagnostic exactly, including the four exact site archives;
all 44 non-CNN pairs repeat exactly. Every reference-difference count is
retained. CNN remains at 165,579 differences twice, but its native repeat
fails at **1,484 pixels**, maximum channel error 150, in the same (460, 753)
to (563, 767) photograph region. Its first production PNG matches the final
diagnostic's first PNG exactly. No CNN stability or global pixel pass is claimed.

The preceding production attempt completed all 90 native captures with zero
individual guard exits, but lost its outer completion receipt during the user
continuation; no process remained and the report was empty. It is retained
without production acceptance. Its CNN pair differed at 685 pixels in the same
region. The complete fresh recovery cohort uses separate output/receipt names;
no original attempt was overwritten. Recovery establishes the correction's
production control result and retains CNN's failure, rather than clearing it.

This supersedes the preceding pending-production status for `78f1fcf3b`.
Receipts, original/recovery commands and exits, all captures, compiled-source
witnesses and comparisons remain in the same local evidence directory.
The shared completed bundle was reused; no additional manual production build
was queued. All-site equality, live behavior, scripting and performance
acceptance remain open.

The second verified archive hashes 6,014 file records across 11 production
job roots and preserves 1,859 selected files (44,225,272 bytes), including
the interrupted attempt. Copies are hash-verified before deleting all owned
production outputs, guards and locks. No owned scratch jobs remain.

## Native media routing in frozen CNN replay, 2026-11-15

`de138d5e5` resolves the recurring native-repeat defect in the registered CNN
replay. The command trace identifies the unstable (460, 753)–(563, 767) region
as `draw_video`, with authored geometry (460.265625, 752.59375, 103.46875,
58.1875). Earlier descriptions identifying it as the train photograph were
incorrect. The train thumbnail is next to it at (588, 753), has identical
decoded-row SHA-256 in both processes, and consistently uses the image sampler.
The prior static WebP fixes and their exact control remain valid; they did not
establish video stability.

The frozen HTML contains four muted autoplay videos, but its manifest contains
no MP4 responses. The old native player passes remote URLs directly to
AVFoundation. The browser trace publishes changing video frames while the
replay proxy sees 82 requests and zero MP4 requests. Two fresh Brave
original-origin diagnostic processes, using the same archive, report the
visible videos paused at time zero, readiness zero and network state 3. This
read-only diagnostic does not replace the existing full-uBO reference. The
registered reference and all tolerances remain unchanged.

The correction detects saved or ambient proxy policy, including scopes that
may apply after an initially bypassed redirect. Remote progressive media then
uses the ordinary browser request path, preserving proxy resolution, TLS,
filtering, redirects and HTTP errors. The native decoder receives an owned
local file; reset/close removes it after closing the native handle. The media
element retains its original `currentSrc`. Fetch/decode failures do not fall
back to a remote native URL. Explicit direct overrides, universal environment
bypasses, local files, ordinary media with no active proxy policy and the
existing WebM path retain their applicable native/transport behavior.

This implementation buffers progressive responses before native decoding.
Proxied playlists explicitly fail until a streaming resource loader is
implemented; they must not bypass the proxy. Unproxied native HLS remains on
its previous path. Full media streaming and transport CORS parity are not
claimed. No native painter, shader, author-script policy or animation
preference changes were made.

The proxy-policy test and real native MP4 integration test pass. The latter
uses a generated H.264 movie, a local SOCKS proxy and an unresolvable redirected
host, verifies native dimensions and original `currentSrc`, checks the retained
file's bytes and deletion on close, rejects missing/playlist responses, and
proves a refused proxy cannot fall back to a reachable local origin. Both
focused runtimes pass under 3 GiB guards and arena poisoning. An earlier
poisoned-arena fault exposed a scratch-allocated error escaping the new staging
path; that failed run is retained. The corrected implementation copies error
messages/interfaces into persistent storage, and the final test also reads the
returned HTTP error after the scratch arena retires.

The final C/O0 diagnostic executable is
`05a631a537bb5e91f7be665dba338bb99cc7b7d809fa1c38e5574ddca269999b`.
Its compiler buffers witness 177 consumed V inputs, including media, network,
proxy settings and rendering. The final native test has 178 selected inputs.
The 45-workload/90-capture cohort retains 311 stable source/tool/shader/archive
pins. All 91 native startup/capture guards, the driver and outer guard exit zero.
**CNN improves 165,579→164,021 twice: 1,558 corrected, zero introduced. All 45
native pairs repeat exactly.** All 44 non-CNN PNGs match preceding production
captures exactly. The four exact site archives and the full WebP control stay
exact; Vlang retains 27 pixels, including its historical introduced JPEG pixels.
Engadget's ICC control and the root-raster WebP control retain their counts.

Across both CNN captures, all eight MP4 requests reach the replay proxy and
receive 404 with `archived=false`, matching its missing-media policy. This
restores the configured workload boundary; it is not a raster optimization or
instruction-comparison result. Earlier CNN native-replay checks must not be
called strictly offline merely because the HTML/image archive was sealed.
The original source/replay mismatch and missing media remain explicit archive
limitations; no new source or live-site parity claim is made.

The latest completed production bundle checked here is `2e089712`, whose sealed
inputs lack this correction. It cannot validate the new code. The ordinary
managed commit hook requests the coalesced C/literal V `-prod` rebuild;
**production confirmation is pending**, with no duplicate manual build queued.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/cnn-request-20261115/`, including
both Brave media observations, command/row traces, source witnesses, successful
and failed checks, route logs, unchanged-reference transitions and cleanup
records. Initial disk pressure and a failed default-backend compiler bootstrap
are retained; the final focused/browser builds use explicit C and no compiler
fallback. All-site pixel equality remains open: CNN's 164,021 rendering pixels,
its source/replay limitations, Vlang, missing Reddit evidence and prior controls.

The first verified cleanup hashes 461 file records across 11 probe roots and
preserves 67 selected files (4,483,688 bytes). Final cleanup hashes 3,544
records across 35 owned job roots and preserves 1,054 selected files
(27,215,541 bytes). Copies are verified before deleting owned outputs,
generated C, binaries, guards and locks. The test alias and Python bytecode
are removed. Shared bundles, libraries and dependencies are retained.

## Production confirmation of native media routing, 2026-11-15

Production executable
`0d895b01829a9bb4631354d8c148d7e646912a35ce41e6abeecc5c9449da31ba`
confirms `de138d5e5`. Receipt `20261115-160857-ecd32b48` records the C backend,
literal V `-prod` and one C unit. The completed shared bundle is reused without
another manual build. Its consumed inputs match the final persistent-error
ownership fix, rather than an earlier work in progress. The precheck verifies
177 consumed V inputs across the rendering, media, networking and settings
packages plus the main caller; the capture driver records 192 feature-input
witnesses and 311 stable source, resource and tool pins. This is scoped
rendering validation, rather than whole-checkout validation of concurrent work.

All **45 workloads and 90 fresh native captures** complete successfully.
Every pair repeats exactly, and all 45 PNGs match the accepted diagnostic
build `05a631a5` exactly. CNN retains **164,021** reference differences, with
1,558 corrected and zero introduced against the preceding production result.
GitHub, Hacker News, Lobsters and Wikipedia remain exact; Vlang retains 27.
The complete sampled sRGB WebP control remains exact. All 90 native guards,
the capture driver, its outer guard and the guarded summarizer exit zero.
All eight MP4 requests reach the replay proxy and receive the expected
unarchived 404s. The source/replay limitation remains open; missing video bytes
are not supplied from the live network. No reference or tolerance changes.

The next image investigation isolates five existing CNN image interiors,
excluding four pixels at each edge. It compares decoded RGB filtering with
per-plane YUV filtering, CPU and GPU mips, mip selection, arithmetic precision
and coordinate evaluation. CPU plane mips with nearest-level selection reduce
Netanyahu's interior from 52,702 differing pixels to 540, Trump's from 15,507
to 283, and the CNN logo's from 18,505 to 253. Each remaining error is one
level. These are isolated compute-probe results, not browser captures or an
accepted rendering change. The same policy still leaves 32,147 differences
in Sullivan's interior; no universal scaling fix is established. Altered
arithmetic and coordinate expressions do not make these controls exact.
A pixel-coordinate sampler attempt fails Metal compilation because that
sampler cannot use mip filtering; its failed guard and compiler log are
retained. None of these experiments changes shipped code.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-plane-scale-20261115/`:
production receipt, before/after pins, all captures and exits, unchanged
reference comparisons, probe source revisions, decoder identities and rejected
attempts. All-site equality remains open: CNN rendering and source/replay,
Vlang's JPEG/scene pixels, missing Reddit evidence and the prior controls.
No live-site, script-runtime or performance acceptance is claimed.

Cleanup verifies 3,085 file records across 28 owned job roots and preserves
986 selected files (22,264,713 bytes). Hashes are rechecked before deleting
the diagnostic library, capture profiles, scratch directories, guards and locks.
The shared production bundle and dependencies are retained.

## CNN decoder isolation and production recheck, 2026-11-15

`085e9ad57` adds the decoder regression, subsequently scoped to macOS in
`images/cnn_webp_planes_darwin_test.v`. Five frozen CNN resources cover
Sullivan, Trump, Netanyahu, the CNN logo and peptides. Each case validates the
encoded bytes, dimensions, packed I420 layout and three independent plane
SHA-256 witnesses. The witnesses come from Brave `157.1.99.57`'s WebCodecs
`ImageDecoder`, using a fresh private process and the same encoded resources.
All fifteen planes match the browser's complete-YUV decoder entry point exactly.
CNN's arbitrary-scale photographs continue through RGBA fallback painting.
The planar checks supply decoder regression coverage; HTML image filtering
remains a separate check.

The final C/preallocated/no-GC test executable passes under a 3 GiB guard with
arena poisoning and no skips. Its compiler buffers match 25 selected consumed V
inputs, including the test, image helpers, native bindings and main caller.
The first test compile rejects an unhandled Result in the new assertion helper;
the corrected helper is retained. A second compile encounters an intervening
shared LibJS type error. Successful subsequent compiles and actual executions
are recorded; this change includes no LibJS edits. The platform filename change
preserves the test body and receives its own successful compile and execution.

Further isolated checks distinguish CPU resizing, GPU sampling and capture
context. The prototype's CPU plane reductions match existing test-only Skia
libraries byte for byte. Metal fragment rendering into an 8-bit target, WebGL, and Skia
Metal/Dawn oracles still retain residual errors. Half precision and converting
to floating RGB before filtering do not establish equality. Rounded clipping
changes sampling results but does not make the candidates exact. No rendering
candidate is accepted and no pixel reference or tolerance changes.

Two fresh Brave captures of a minimal five-image page repeat exactly. Four
image interiors match the original CNN reference; Sullivan's interior differs
at 29,572 pixels, maximum channel error three. Interiors exclude four pixels
at each edge. This reduced page has a different context from the archived
homepage and does not clear its source/replay gate or establish a live-site fix.

The latest completed shared bundle at the new cohort's launch is
`7083f309c32ccdf8288453c74b120e950dbd6316beb84f1ea24680a0c6da3de1`, receipt
`20261115-170146-0ceea77c`, C/literal V `-prod`/single C unit. All **45 workloads
and 90 fresh captures** retain the preceding diagnostic outputs exactly; every
pair repeats exactly. CNN remains **164,021** and Vlang **27**. GitHub, Hacker
News, Lobsters and Wikipedia remain exact. The driver checks 192 feature-input
witnesses and 312 stable pins. All 90 native guards, driver, outer guard and
guarded summarizer exit zero. Eight missing MP4 requests return replay 404s.
This rechecks a newer bundle; it supplies no new rendering or performance credit.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/cnn-fragment-scale-20261115/`:
decoder metadata and plane comparisons, source revisions, all rejected attempts,
focused-test receipts, production identities, captures and verified cleanup
manifests. All-site pixel parity remains open, including CNN rendering and
source/replay, Vlang, missing Reddit evidence and the prior controls.

Probe cleanup verifies 801 file records across 72 owned roots and preserves
156 selected files (16,237,816 bytes). Final cleanup verifies 3,096 records
across 25 roots and preserves 999 files (23,909,000 bytes). Copies are hashed
again before removing binaries, capture profiles, jobs, guards and locks.
The owned test alias is removed; shared bundles and dependencies are retained.

## Solid SVG mask coverage, 2026-11-15

`1d32867a2` corrects the antialiasing of filled-only and stroked-only paths
inside SVG content masks. Those paths previously used Quartz coverage while
ordinary document SVGs used V/GG. The native graphics adapter now supplies the
mask bitmap's device transform to the existing V/GG path renderer and publishes
its transparent result through the mask's original Quartz context. This keeps
the parent's clipping and opacity. Unsupported inputs and allocation failures
retain the existing renderer; combined fill/stroke and gradient paths are
unchanged. No original reference or tolerance changes.

The C/O0/preallocated/no-GC diagnostic browser is
`f0897a3d040676ed896fe5461063874652bd493947bf1919d5ea74c50992e987`.
All **46 workloads, 92 fresh captures** complete successfully and every pair
repeats exactly. CNN improves **164,021→163,914**: all 107 changed pixels are
corrections in the header's headphone icon, with zero introduced differences.
All 44 other existing workload PNGs match the preceding accepted outputs
exactly. GitHub, Hacker News, Lobsters and Wikipedia remain exact; Vlang
remains at 27. All 92 native guards, the startup smoke, driver and outer guard
exit zero. The feature inputs remain unchanged through the cohort; fourteen
selected consumed V source witnesses also match the candidate.

The new `svg-mask-solid-coverage` control has two independent, identical Brave
`157.1.99.57` captures at scale 1. Its isolated icon, scaled icon, even-odd fill
and stroke become exact. The expanded control improves 906→275 differences;
28 overlapping-path seam pixels and 247 transformed-opacity pixels remain
open. Its reference retains those failures. The focused GPU test compares four
independent Brave RGBA crop hashes and checks parent clipping and opacity.
The final formatted test compiles and actually runs under a 3 GiB guard with
arena poisoning, exit zero; 31 selected consumed GG/SVG/test inputs match.
Earlier test-helper naming and coordinate-space mistakes, their failed runs,
and the corrected final execution are retained. The existing native mask
pixel-conversion and layer suites also pass.

The latest completed production browser is still `6addbda0`, receipt
`20261115-171520-4a8b8f38`, and does not contain this fix. The normal commit hook
requests a coalesced C/literal V `-prod`/single-unit rebuild. Production
validation remains pending; these results establish frozen-page diagnostic
correctness, with no live-site or performance claim. CNN's photographs and
source/replay gate, Vlang, missing Reddit evidence and the prior inexact
controls keep catalog-wide pixel parity open.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-mask-20261115/`, including
commands, all attempts, identities, source witnesses, captures, pixel
transitions and cleanup receipts. Cleanup hashes 3,491 file records across
11 owned roots and preserves 900 selected files (18,085,437 bytes). Copies
are verified before removing the owned binaries, profiles, jobs, guards and
locks. Shared production bundles and dependencies are retained.

## Declared custom properties and production mask confirmation, 2026-11-15

`d8e280439` preserves an element's own custom-property declarations when an
ancestor's variable environment changes. The inheritance shortcut previously
checked whether ordinary computed properties used `var()` or `inherit()`, then
replaced the element's complete variable environment with its parent's. Literal
declarations could disappear even while descendants needed them. CNN's Watch
dot consequently had an empty background and a 0×0 generated box. A declaration
flag now makes those elements recascade; elements that only inherit retain the
shortcut. The flag includes pseudo-element rules and resets on a full cascade.

The focused regression reproduces the missing own variable before the fix.
The final C/O0/preallocated/no-GC test executable
`7c612810ab89289d25d3b4ff6909a14e89d0073a2e3a7fc8a1d4bad346179c4d`
passes under a 3 GiB guard with arena poisoning. It checks preserved own values,
updated inherited values, pseudo-element geometry, and resumed inheritance after
declarations are removed. All four feature/test compiler-buffer witnesses match.
An intermediate test expected the viewport width despite the UA body margins;
the corrected assertion compares the flex box with its containing box.

Diagnostic browser
`0d608f015398a8ea6f781a5f87625b58ba9b23d958f2983b1051921936129e10`
completes **46 workloads and 92 fresh captures**, plus a separate startup smoke.
Every pair repeats byte for byte. CNN improves **163,914→163,862**: 52 corrected
pixels, zero introduced, and eight changed pixels that remain one level from the
reference. All changes lie in the restored dot. Both CNN audits confirm its 8×8
generated box and the link's 61.5-pixel width. All **45 non-CNN PNGs are unchanged**.
GitHub, Hacker News, Lobsters and Wikipedia remain exact; Vlang remains at 27.
The candidate checks 822 consumed GG/rendering/CSS/DOM/layout V witnesses and
826 stable source pins. All 92 capture guards, startup, driver, outer guard and
guarded pixel analysis exit zero. No original reference or tolerance changes.

Production executable
`395539f070321dc8cb06f44467d591253d9dafffe61d55687bd37c08ba2b0859`, receipt
`20261115-175250-61270ea8`, independently confirms the earlier `1d32867a2` mask
fix using C, literal V `-prod` and one C unit. All 46 workloads and 92 captures
match that accepted diagnostic's PNGs exactly, with exact native repeats and
zero capture/driver/guard exits. Its 192 feature witnesses and the two native
mask input hashes match the frozen compilation. This completes the mask fix's
previously pending production validation.

The newer available `0729cf11` bundle, receipt `20261115-180802-4c486722`, also
contains the mask inputs but predates the inheritance fix by all three changed
implementation hashes. It cannot validate `d8e280439`. The commit's normal hook
requests a coalesced C/literal V `-prod`/single-unit rebuild; no duplicate manual
build is queued. The inheritance result remains diagnostic, pending production
confirmation. No live-site or performance acceptance is claimed.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-watch-20261115/`: production
receipts, source witnesses, commands, all capture outputs, pixel transitions,
the before/after regression and failed probes. Reduction isolates a triggering
theme/font environment; temporary tracing identifies the subsequent inheritance
overwrite. Positive `unset` controls, rejected over-budget standalone compiles,
failed helper attempts and an intervening shared LibJS compile error are retained.
The provisional controls and tracing are removed from the canonical source.

Cleanup verifies 6,772 file records across 21 owned roots and preserves 2,034
selected files (41,048,842 bytes). Copies are hashed again before removing the
owned binaries, profiles, jobs, guards, locks and test alias. Shared production
bundles and dependencies are retained. Catalog-wide parity remains open for
CNN's remaining rendering/source differences, Vlang, the missing Reddit fixture
and the previously inexact controls.

## SVG leaf sample counts and production inheritance confirmation, 2026-11-15

Production executable `a7918541efb0271c0388a5f7319ef8b8e00234bb13a5fed1c8bac5a0b2de9589`,
receipt `20261115-184113-f64340c2`, now independently confirms `d8e280439`.
All three changed inheritance implementation hashes match the frozen compilation.
Its C/literal V `-prod`/single-unit recheck completes 46 workloads and 92 fresh
captures. Every pair repeats byte for byte, and every PNG matches the accepted
inheritance diagnostic. CNN remains 163,862; the four exact archived sites and
Vlang's 27 differences are retained. All capture, driver and outer-guard exits
are zero, with 822 consumed rendering/CSS/DOM/layout V witnesses and stable source
pins. This closes the inheritance fix's previously pending production validation.

The eight remaining Watch-dot pixels came from SVG leaf rasterization losing
the owning picture's sample count. An analytic oval does not itself request
MSAA, but joins a multisampled tile when another path requires it. The native
leaf bridge previously always created a fresh single-sample surface. It now
passes the cropped document coordinates to V, which replays the path in each
owning tile and preserves that tile's sample count. The separate mask callback
keeps its existing image-local raster policy. Tile classification also stops
using isolated, unclipped filled ovals as MSAA triggers; strokes and compound
or clipped paths retain conservative classification.

The new `svg-promoted-analytic-edges` control has eight cases covering opaque
and transparent backgrounds, promoted pictures, curves, and rounded borders.
Two fresh Brave captures agree byte for byte with stable executable identity.
Independent Skia Metal GPU probes match GG's circle pixels over opaque and
transparent backdrops in both single-sample and explicitly multisampled passes.
They confirm that this is a pass-selection difference, without changing shader
precision. The first candidate fixes CNN but introduces 16 control pixels by
incorrectly promoting the two otherwise single-sample pictures; that complete
47-workload/94-capture cohort is retained as rejected evidence. The oval trigger
correction removes all 16 introduced pixels.

Final diagnostic executable
`deb05301af34f3c233e43dcf3f9fb8570ceca364834b753f7b4f6f0cc2ceddac`
(C/O0/prealloc/no-GC) completes **47 workloads and 94 fresh captures**, plus
startup smoke. Every pair repeats byte for byte. CNN improves
**163,862→163,854**, with exactly eight corrected pixels and zero introduced;
the Watch dot is exact. All **45 other existing PNGs are unchanged**, including
GitHub, Hacker News, Lobsters and Wikipedia at zero and Vlang at 27. The new
control is exact twice. All 94 capture guards, startup, driver and outer guard
exit zero; 822 consumed rendering/CSS/DOM/layout V witnesses and the feature,
native and fixture source pins remain stable. Original references and tolerances
are unchanged.

Focused tests compare both sample counts against independent Brave crops with
two tile columns and zero/nonzero picture origins, and retain compound/stroked
path classification. Final focused executable
`d729e8e3292fd2e8dbf2b4b7ffa348cafc0ef990a7fb13bd4921bb5377cd71a4`
passes under a 3 GiB guard with `VOX_ARENA_POISON=1`; all four implementation/test
V witnesses match the consumed buffers. All 22 existing MSAA tests also pass
under arena poisoning and a 3 GiB guard; their implementation/test source
witnesses match the consumed buffers.
The previous ellipse bounds test had classified a filled oval as an MSAA
trigger; it now checks that the fill remains analytic and preserves both-corner
and transform bounds with a visible elliptical stroke. The earlier failing
expectation, a corrected stack-pointer declaration and transient shared LibJS
compile errors are retained. Foreign edits are preserved.

After the diagnostic checks, production `b5ecb480` completed, receipt
`20261115-191824-6ba7d19a`. It contains the exact raster/native inputs and the
previous formatted classifier variant, retained with the passing focused test.
Of 822 consumed V witnesses, 821 match byte for byte; running both classifier
versions through the same pinned V formatter yields identical bytes. The default
production conformance driver nevertheless rejects the differing classifier hash
before capturing any pages (`Frozen build input changed`). That rejection is
retained, and no production acceptance is claimed or gate bypassed. The normal
commit hook requests the coalesced C/literal V `-prod`/single-unit rebuild;
no duplicate manual build is queued. The SVG leaf result remains diagnostic
pending production confirmation with matching final source witnesses. CNN still has image scaling and rounded-border
mismatches and an open source/replay gate; Vlang and the missing Reddit fixture
also keep catalog parity open. No live-site or performance acceptance is claimed.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-edge-20261115/`, including both
catalog candidates, production confirmation, reference captures, GPU probe
sources/results, actual source witnesses and all guard/exit receipts. Cleanup
records 9,547 file hashes across 14 owned job roots and preserves 2,579 selected
files (50,371,653 bytes). Copies are hashed again before deleting
owned binaries, generated intermediates, profiles, guards, locks and test aliases.
The shared production bundle and dependencies are retained.

The later rejected production precheck, formatter proof and frozen receipt are
also retained in that evidence directory. Its one additional job root, two top
files and guards are archived with verified hashes and removed from `Build/`.

## Opaque compositor continuation in the native painter, 2026-11-15

`58846cb2e` restores a native graphics operation left empty during migration.
The V compositor already proves that a picture may safely resume over its
opaque prefix after a disjoint mask/effect, but the native continuation setter
ignored that request. The resumed header therefore started on a new transparent
bitmap. Its white button background and gray stroke were quantized there before
being composited over the already painted white header.

The native boundary now consumes the one-shot request at the next effect begin.
A normal, unit-opacity continuation on a readable bitmap preserves its parent
canvas and the existing balanced graphics-state scope. Other effects keep their
isolated surfaces. A failed begin consumes its request too. Paint ownership,
opaque coverage, disjoint ink and supported scopes remain decisions of the
existing V proofs; no site, color, coordinate, shader, reference or tolerance
selection is added to rendering.

Independent GG and Skia Metal probes reproduce the rounded stroke exactly over
an opaque backdrop. Retained native raster dumps show the old resumed backdrop
is entirely transparent. Replaying the same white underlay and stroke over that
transparent input, then compositing over white, reproduces all 24 erroneous
border pixels. The captured rectangle, radii and stroke width were already
correct. Temporary tracing and exploratory controls are removed from the
canonical source; no Skia code is linked into the browser.

Diagnostic executable
`a3c9083e3df310bb0a5ee57646d8ee8016dc4b9e7433ffda4195c7b5e2228df4`
(C/O0/prealloc/no-GC) completes **48 workloads and 96 fresh captures**, plus
startup smoke, with all pairs repeating byte for byte. CNN improves
**163,854→163,830**: 24 corrected pixels, zero introduced. Its archived header
is now exact. The existing `opaque-svg-mask-ellipse-resume` reference improves
**7→0**. All **46 other previous PNGs are unchanged**, including the four exact
archived sites and Vlang's 27 differences. Existing inexact controls retain their
previous counts. All 96 capture guards, startup, driver, outer guard and guarded
pixel analysis exit zero. All 822 consumed rendering/CSS/DOM/layout V witnesses
and 825 source pins stay stable through the final cohort.

The new native regression checks actual canvas/backdrop ownership, painting and
clip restoration, request consumption, cancellation, null-context failure,
translucency and screen blending. Its executable
`82e8dffd663b8b4fa6824555817616e6ff8ba845d19cd76b7e4c3bc9cb78d198`
passes under arena poisoning and a 3 GiB guard. The eight existing mask-gap and
seven existing opacity-gap proof tests also execute successfully under the same
runtime guard and poison policy, with matching parsed V input witnesses.

The earlier 49-workload cohort is retained without acceptance: its post-check
caught an edit to the uncompiled test helper while captures ran. The helper's
Objective-C initialization/goto compile error was corrected before the final
unit run; the subsequent 48-workload cohort freezes all final test sources too.
An exploratory CSS circle-mask control retains 160 differences before and after
this fix, all in the mask, and is not claimed as solved. Both reference captures,
failed attempts, native traces, probe sources/results and intermediate outputs
remain in local evidence. No original screenshot reference changes.

Available production `b5ecb480`, receipt `20261115-191824-6ba7d19a`, does not
contain the native continuation implementation by its frozen C input hash.
Production confirmation remains pending. The managed commit hook requests the
coalesced C/literal V `-prod`/single-unit rebuild; no duplicate manual build is
queued. CNN's remaining image/scaling differences and source/replay gate, Vlang,
the missing Reddit fixture and previously inexact controls keep catalog-wide
parity open. No live-site or performance acceptance is claimed.

Evidence is local under
`docs/performance/vlang-gradients-20261114/raw/cnn-border-20261115/`. Cleanup
records 7,991 file hashes across 20 owned job roots and preserves 1,982 selected
files (42,531,758 bytes). Copies are hashed again before deleting owned binaries,
generated intermediates, profiles, guards, locks and three test aliases. Shared
production bundles and dependencies are retained.

## Production header confirmation and CNN decoder isolation, 2026-11-15

Production executable
`c19672aeee65b4f3124a25ee13490f450616c040cb1ce4106a0f08f1eb2a5e41`,
receipt `20261115-203517-3ad4c231` (C/literal V `-prod`/single unit), now
confirms both `d86c965a2` and `58846cb2e`. Their consumed SVG/native input
hashes match. All **48 workloads and 96 fresh captures** complete successfully;
every pair repeats byte for byte, and every PNG equals the preceding accepted
diagnostic. The driver's 192 input witnesses remain matched throughout.
Startup smoke, all capture guards, driver, outer guard and guarded analysis
exit zero.

CNN retains **163,830 differences**, with its archived header exact. The SVG
analytic-edge and opaque mask-gap ellipse controls are exact. GitHub, Hacker
News, Lobsters and Wikipedia remain exact; Vlang retains 27. Existing inexact
controls retain their counts. This closes the preceding two production holds;
it supplies no new renderer improvement or catalog-wide acceptance.

`312cf5094` adds independent natural-size **RGBA** references for all five CNN
photographs to the existing decoder regression. Two fresh Brave `157.1.99.57`
processes produce identical Canvas2D `getImageData` bytes with sRGB/unorm8 and
`willReadFrequently=true`; the second run pins the executable and native
framework identities. All five outputs equal libwebp's straight RGBA bytes.
The test now checks those five images alongside the fifteen existing exact
WebCodecs YUV planes. Its C/preallocated/no-GC executable
`4e8c1809b6fbe90259a5247bcbaa4c0d3304ab3c1a7b6c2a6f4ec5f18039d62d`
actually runs successfully under arena poisoning and a 3 GiB guard. Seventeen
consumed image/decoder/test V input hashes match. No decoder or painter changes.

Post-navigation LayerTree command logs confirm full source dimensions and the
snapped photo rectangles. These instrumented diagnostics apply the recorded
cosmetic CSS separately; they do **not** reproduce the complete uBO oracle or
replace its reference. The initial stale-layer attempt, missing-filter capture,
and their outputs remain retained. The filtered diagnostic's Sullivan interior
still differs from the original reference at 29,572 pixels (maximum error
three). Reproducing the recorded transforms in independent Skia/Dawn oracles
does not establish equality. Generating plane mips on the GPU rather than in
the CPU upload reduces that one oracle's Sullivan residual to 1,833 one-level
pixels, but worsens other photos; no universal fix is accepted. An unsupported
R8 surface attempt and two zero-data/dropped-draw variants remain invalid even
where their processes exited zero. Decoder-byte agreement does not establish
HTML filtering, decode-cache selection or source/replay equality.

CNN's rendering/source gate, Vlang, missing Reddit evidence and prior inexact
controls remain open. No original reference, tolerance, live-site, scripting
or performance claim changes. Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-picture-20261115/`.
Cleanup hashes 3,474 files across 61 owned roots, preserves and reverifies
1,038 selected files (57,126,231 bytes), and removes the owned binaries,
generated intermediates, profiles, jobs, guards, locks and test alias. Shared
production bundles and dependencies are retained.


## Bounded minified WebP plane filtering, 2026-11-15

`d1799617e` filters scaled opaque WebP planes before converting them to RGB.
The prior arbitrary-scale fallback filtered already converted/clipped RGB,
which changes chroma reconstruction and color extrema. The new V decoder
adapter retains a packed YUV444 upload, and the existing V/GG texture backend
applies limited-range Rec.601 conversion after bilinear sampling and before
coverage/blending. Selection requires a complete simple VP8 resource, full
source rectangle, opaque Chromium rendering, integer translation, an exact
power-of-two plane reduction and no additional mip selection. Native/half-size
sampling stays on its preceding path. Rounded-up upload sizes, extra mips,
profiles, alpha, unsupported geometry and unreadable native targets retain
existing rendering. No site, resource hash, reference or coordinate selects
pixel corrections.

Both the Python and production V preparers now install the same YUV uniform and
shader patch. The backend checks shader support before accepting a YUV upload.
GG also loads the shared lazy shader payload while its persistent arena is
active. Without this preparation, non-production embedded-file loading caches
bytes from a disposable paint scope. A negative control recreating the former
context initialization triggers an arena-poison fault in
`EmbedFileData.to_string`, exit 138. The accepted regression draws through
reclaimed scopes at sample counts 1 and 4 without that fault. This is a
controlled diagnostic failure, not a production crash claim; literal V `-prod`
embeds the uncompressed shader bytes.

Diagnostic executable
`3192431be7a0347489991879929472f8f43bfabd58d540287d648bdf19fe93ca`
(C/O0/preallocated/no-GC) completes **48 workloads and 96 fresh captures** plus
startup smoke. Every pair repeats byte for byte. **All 47 non-CNN PNGs are
unchanged**, including exact GitHub, Hacker News, Lobsters and Wikipedia, and
Vlang's 27 differences. CNN improves **163,830→88,752**: 75,105 corrected pixels,
27 introduced pixels, each introduced channel error at most one. All 75,711
changed pixels lie within the Netanyahu and CNN-logo image rectangles; the
header and other image regions are unchanged. Those images still have
residual differences. This remains partial rendering progress, not pixel
parity or source/replay acceptance.

All 824 consumed rendering/CSS/DOM/layout V witnesses and 860 pins, including
shader inputs, stay matched throughout the accepted cohort. All 96 capture
guards, driver, outer guard, startup and guarded analysis exit zero. CPU plane
packing/domain checks, GPU filtering/clip/alpha and frame-ownership checks, the
production V preparation regression and Python partial-staging/idempotence
checks actually pass. Positive V runs use arena poisoning and 3 GiB runtime
guards. Their 44 GG, 10 YUV and 19 build-tool V input witnesses match.

Earlier mismatched preparation attempts, failed guards and the broader
minification prototype are retained without acceptance. That broader path
regresses a new irregular-size exploratory control, 804→805 pixels. The bounded
path restores its prior PNG byte for byte and leaves that case unsupported;
both independent Brave captures and the inexact control remain in local
evidence. The temporary fixture/reference and negative-control source are
removed from the canonical tree. No original reference or tolerance changes.

Available production `a29214bc`, receipt `20261115-204745-385a0d38`, lacks the
new implementation by frozen source hashes. The commit hook requests the
coalesced C/literal V `-prod`/single-unit rebuild. Production confirmation is
pending; no duplicate manual production build is queued. CNN's other images
and source/replay gate, Vlang, missing Reddit evidence and prior inexact
controls keep catalog-wide equality open. No live-site, scripting or
performance acceptance is claimed.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-planar-20261115/`.
Cleanup hashes 7,087 files across 119 owned roots and preserves/reverifies
1,511 selected files (45,667,837 bytes). Owned binaries, generated intermediates,
profiles, jobs, guards, locks and exploratory fixtures are removed. Shared
production bundles and dependencies remain.


## Production confirmation of bounded WebP, 2026-11-15

Production executable
`44f9e0ff55791443cd9b5bd7fef8809412951f838f560eef935314d6aff461ae`,
receipt `20261115-215405-67b64854` (C/literal V `-prod`/single unit), confirms
`d1799617e` by its consumed implementation hashes. All **48 workloads and 96
fresh captures** complete successfully. Every pair repeats byte for byte, and
**every production PNG equals the accepted diagnostic PNG**. The driver's 194
input witnesses remain matched. Startup smoke, all capture guards, driver,
outer guard and guarded analysis exit zero.

CNN retains **88,752 differing pixels**, including the same 27 introduced
one-level differences. All changes from the preceding accepted build remain
inside the two image rectangles; its header is exact. GitHub, Hacker News,
Lobsters and Wikipedia remain exact, Vlang stays at 27, and the other existing
controls retain their previous PNGs. This closes the production hold above.
It does not clear CNN's other rendering/source failures, missing Reddit
verification, prior inexact controls or catalog-wide equality. No original
reference, tolerance, live-site, scripting or performance acceptance changes.

Evidence remains under `raw/cnn-planar-20261115/` in the local performance
folder described above. Additional cleanup hashes 3,058 records across eight
owned roots, preserves/reverifies 955 files (19,545,245 bytes), and removes the
production capture jobs, profiles, guards and locks. The shared bundle and its
dependencies are retained.


## Sampled YUV images across mixed MSAA tiles, 2026-11-15

`59c259a55` fixes another supported minified WebP fallback. A native diagnostic
shows that CNN's Trump image has a readable, unit-scale backdrop with no
transparency depth, but its V image callback rejects the later paint. The
readback crosses root tile row 1 (one sample) and row 2 (four samples). The
uniform-sample selector correctly returns zero for that mixed region; treating
zero as a whole-image fallback discards the supported plane filtering.

The packed-YUV callback now draws in each owning tile's coordinate space and
sample mode. It copies the original backdrop into the tile including its
gutter, translates image and clip together, and publishes only owned pixels.
The cropped result is committed only after every tile succeeds. Outside
fringes and padded rows retain their original bytes. Unsupported grids still
fall back. This does not broaden the bounded decoder's scale/profile/source
selection, or the other image formats' mixed-sample paths. No site, resource
hash or pixel coordinate selects a correction. The native diagnostic edits
are removed; the implementation and focused tests are V.

Diagnostic executable
`b1c36ebf6460f92a7fcf9274c3bd5fa8910aa1bea2c149c54dae865108ba4771`
(C/O0/preallocated/no-GC) completes **48 workloads and 96 fresh captures**, plus
startup smoke. Every pair repeats byte for byte; every one of the **47 non-CNN
PNGs is unchanged** from accepted production `44f9e0ff`. CNN improves
**88,752→71,925**: 16,841 corrected pixels and 14 introduced pixels, each new
error at most one channel level. All 16,967 changed pixels lie inside the Trump
image's rectangle. Its interior, excluding a four-pixel border, improves
**15,507→116**, maximum error **84→1**. Other selected image interiors retain
their prior results: Sullivan 34,991/max88, Netanyahu 384/max1, logo 231/max1,
and peptides 4,106/max26. The logged focused capture and unlogged broad capture
are byte-identical. GitHub, Hacker News, Lobsters and Wikipedia remain exact;
Vlang remains at 27. These are frozen-page results, not full CNN equality.

All **825 consumed rendering/CSS/DOM/layout V witnesses and 851 input pins**
stay matched. All 96 capture guards, startup, driver, outer guard and guarded
analysis exit zero. Focused test executable
`4abaf70178c27611f90732c6798d839c3a4d6ff22333cca6d3e57ae6aa878b1f`
passes both tests with arena poisoning and a 3 GiB runtime guard; its 164 V
witnesses match. The tests compare both seam directions against independent
whole-surface one/four-sample rectangle coverage, exercise the native callback's
channel conversion, and verify unchanged fringe, pitch padding and rejected
draws. An initial rounded-clip translation-invariance assertion differs by one
alpha level between different-sized GPU surfaces; its failed source and guard
are retained. The accepted exact test uses binary-fraction rectangle coverage
and does not claim general rounded-raster translation invariance. No existing
reference or tolerance is changed.

An interrupted compile produced no executable or completed guard receipt.
A subsequent prototype compiled successfully but its post-compile hash guard
rejected formatting during compilation. Both attempts remain recorded without
acceptance. The first broad-driver invocation failed before any captures
because its script had not been written; the completed cohort above uses a
separate job and retains that failure. The final code's focused and broad
checks use stable source inputs. No performance or instruction claim is made.

Completed production `48b7a944`, receipt `20261115-220911-056313d0`, lacks the
new V file and callback change by consumed source hashes. The feature commit
requests the coalesced C/literal V `-prod`/single-unit build. Production
confirmation remains pending; no duplicate manual build is queued. CNN's
remaining image/source differences, Vlang's remaining pixels, Reddit's missing
evidence and the existing inexact controls keep catalog-wide parity open.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-target-20261115/`.
Cleanup hashes 3,905 files across 34 owned roots, preserves/reverifies 1,034
selected files (26,332,260 bytes), and removes owned binaries, generated
intermediates, capture profiles/jobs, guards and locks. The owned test alias is
removed; shared production bundles and dependencies remain.


## Additional YUV mip filtering, 2026-11-15

`262c477c1` extends the supported minified WebP upload to draws needing additional
mip levels. The previous bounded route rejects an upload/destination ratio
whose log2 is at least 0.5, so Sullivan's 960×540 image, uploaded at 480×270 and
drawn at 269×151, falls back to RGB filtering. The new route filters its packed
YUV channels through GPU-generated byte mip levels and the existing canvas
sampler before limited-range Rec.601 conversion. Single-level uploads retain
their path. Complete opaque untagged VP8, full-source geometry, integer
translation and exact power-of-two plane-reduction restrictions remain; rounded
upload sizes remain unsupported. The native V callback's new transfer flag
carries mip selection through both uniform and mixed-sample regions. Native
application code and the canvas shader/sampler policy are unchanged.

Diagnostic executable
`fcc31b7d871adcb6a5e83a0b438ce3b560d10b38c73871ca049c075fd7f8a190`
(C/O0/preallocated/no-GC) completes **48 workloads and 96 fresh captures**, plus
startup smoke. Every pair repeats byte for byte. All **47 non-CNN PNGs are
unchanged** from the preceding accepted mixed-tile cohort. CNN improves
**71,925→58,062**: 14,488 corrected pixels and 625 introduced pixels, each new
error at most two channel levels. All 37,896 changed pixels lie inside
Sullivan's image rectangle. Its interior, excluding four pixels at each edge,
improves **34,991→22,366**, maximum channel error **88→2**. This is partial
filtering progress with retained small errors, not exact image reconstruction.
Trump remains 116/max1, Netanyahu 384/max1, logo 231/max1 and peptides 4,106/max26
in their corresponding interiors. GitHub, Hacker News, Lobsters and Wikipedia
remain exact; Vlang stays at 27. Logged and unlogged CNN captures are identical.

All **825 consumed rendering/CSS/DOM/layout V witnesses and 851 input pins**
remain matched. All 96 capture guards, startup, driver, outer guard and guarded
analysis exit zero. Five focused test functions actually pass with arena
poisoning and 3 GiB runtime guards. The new GPU test verifies byte-plane mip
rounding/blending and an out-of-range chroma case: filtering planes before RGB
conversion produces blue 1, while filtering the prematurely clipped RGB bytes
would produce blue 64. Both sample counts pass. Native callback tests exercise
the mip flag through both seam directions; existing single-level, clipping,
rejection and reclaimed-paint-scope tests pass. Consumed V witnesses match for
all three test executables (44, 44 and 164 respectively).

The final GPU test executable is
`44ce656ec98bbe82baf1dccb8f0cdbcd67c7d9c21d57c2262fa3c8b7fabd9fc2`;
the existing YUV checks use
`097605939a2ea699f5c1803b77a3a75e3636f81014441c7584e6b1c0151f5686`,
and the native callback checks use
`84db90aefa574e97cd6bf5135bda82536fe6a294c636d5d21dccef3a4c4728cb`.
An initial arithmetic assertion assumed selection of the rounded mip alone and
failed. The existing canvas sampler blends levels with its fixed bias; that
policy was retained, and the final exact arithmetic case checks its actual
blending as well as the later color conversion. The failed source, log and
guard, and the intermediate successful test remain retained. Browser input pins
exclude unconsumed test files; final test sources have their own consumed-hash
witnesses. No original golden or tolerance changes, site exceptions, live-site,
scripting, performance or instruction acceptance claims.

Completed production `48b7a944`, receipt `20261115-220911-056313d0`, lacks the
new sampled-tile implementation and mip callback by consumed source hashes.
Both feature commits request the coalesced C/literal V `-prod`/single-unit
rebuild through the managed hook. Production confirmation remains pending; no
duplicate manual build was queued. CNN's remaining rendering/source failures,
Vlang's residuals, Reddit's missing evidence and prior inexact controls keep
catalog-wide pixel equality open.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-yuv-mips-20261115/`.
Cleanup hashes 3,504 files across 38 owned roots, preserves/reverifies 1,007
selected files (22,661,361 bytes), and removes owned executables, generated
intermediates, capture jobs/profiles, guards, locks and the test alias. Shared
production bundles and dependencies remain.


## Production confirmation of sampled YUV tiles and mips, 2026-11-16

Production executable
`523e30ddb154f3a25f336661a213bc912b3eaddd409226ab886f19f440cff6f7`,
receipt `20261115-234808-804cb6d9` (C/literal V `-prod`/single unit), confirms
`59c259a55` and `262c477c1`. The consumed hashes of the callback, minified WebP,
sampled-image and tile implementations match those committed fixes. The
receipt's requested head predates their commits; the actual consumed buffers
establish which code ran.

All **48 workloads and 96 fresh captures** pass the unchanged production driver.
Every pair repeats byte for byte, and **every PNG equals the prior accepted mip
diagnostic** `fcc31b7d`. CNN remains **58,062**, Vlang **27**, and GitHub, Hacker
News, Lobsters and Wikipedia remain exact. Existing inexact controls retain
their previous outputs. All 96 native guards, driver, outer guard, startup smoke
and guarded analysis exit zero. The default source gate's **195 checks** stay
active throughout. No original reference or tolerance changes.

This validation uses the matching prior committed source (`f19ce6055`) and GG
preparation inputs for the owned files. The atlas candidate's source and shader
inputs are then restored exactly: **857 pins match**, and its focused GPU,
callback and preparer checks pass again. Both the production and candidate
identities, commands, transaction states and complete results remain local.
This closes the two preceding production holds. It supplies no production
acceptance for the new atlas slice below, which the bundle does not contain.
CNN's source/replay and residual rendering gates, Vlang, missing Reddit evidence
and catalog-wide equality remain open.


## Native chroma sampling for near-half WebP, 2026-11-16

`5995502f5` handles the full-upload case where both destination dimensions lie
strictly between half and native size. The existing promoted 4:4:4 upload path
requires a power-of-two reduction and does not cover CNN's 256×144 peptides
image drawn at 130×73. The new upload preserves Y at full size and U/V at their
native half size in the top-left quarter of two channels of one RGBA8 texture.
Chroma edges extend over the remaining texels. The shader samples Y at ordinary
coordinates and chroma at half coordinates, giving the planes independent
sampling derivatives, then applies the existing limited-range Rec.601 matrix.
With the existing sampler policy this domain uses chroma level zero and at most
the first luma mip, preserving alignment even when the chroma dimensions are odd.

The rendering path retains complete opaque untagged VP8, full source rectangle,
integer translation, unit opacity and existing size bounds. The native callback
carries its new mode through uniform and mixed-sample tiles. The 112-byte
uniform uses a reserved component; texture bindings and sampler policy remain.
Both Python and production V preparers install the same uniform flag, shader
branch and runtime support check. Each atlas component can be repaired without
duplicating the others. No site, resource hash or pixel coordinate selects the
correction. No native application UI or new graphics dependency is added.

Diagnostic executable
`69792131a50c2bdf87f8a316288a7f38bb810c97b12b7ef6e37dcbea45d7d84c`
(C/O0/preallocated/no-GC) completes **48 workloads and 96 fresh captures**, plus
startup smoke. All pairs repeat byte for byte; **all 47 non-CNN PNGs are
unchanged** from the accepted mip cohort. CNN improves **58,062→54,627**:
**3,508 corrected** and **73 introduced** pixels, with every introduced error
at most one channel level and inside the peptides image. Its interior,
excluding four pixels at each edge, improves **4,106→1,048**, maximum error
**26→1**. Three pre-existing one-level photo pixels also become exact: one each
in Trump, Netanyahu and the CNN logo. All other changed pixels are in peptides.
Sullivan stays at 22,366/max2 in its interior; Trump is now 115/max1, Netanyahu
383/max1 and the logo 230/max1. The archived header stays exact. GitHub, Hacker
News, Lobsters and Wikipedia remain exact; Vlang stays at 27.

The logged focused and unlogged broad CNN PNGs are identical. All **826 consumed
rendering/CSS/DOM/layout V witnesses and 857 input pins** stay matched. All 96
native guards, startup, driver, outer guard and guarded analysis exit zero.
Ten focused V test functions run successfully under arena poisoning and 3 GiB
runtime guards, plus the Python preparer test. They cover exact plane bytes and
edge extension, independent sampling/clipping, 3×3 chroma from even 6×6 luma,
invalid input/alpha/scales, reclaimed paint scopes, both tile seam directions,
native channel conversion, existing mip arithmetic and both preparers. The
native preparer also repairs each partially missing atlas component.

The final GPU test is
`7320cca13a012e87a524f65d348c424bbafd9551e30dcafbb7d4698bc3075b8b`;
its 54 consumed V witnesses match. CPU packing uses
`a8df194488bde83c7466d98d1a02e9c2037d8aa1507748d9d308b8ad0fa78b04`
(11 witnesses), and the native callback uses
`c1cac50d4b6ed58dd54c6695064fc86da440f9414877339534fd544f2e3ad1a5`
(165 witnesses). The preparer and existing GPU checks retain their identities
and 19/44/44 witness sets in local evidence. Initial test-only range-assignment
compile errors and an incomplete minimal staging fixture remain recorded;
accepted checks use corrected test syntax and the actual uniform layout. No
original golden or tolerance changes.

Completed production `523e30dd` lacks the atlas code by consumed hashes. The
feature commit requests the coalesced C/literal V `-prod`/single-unit rebuild;
production confirmation remains pending, with no duplicate manual build queued.
These are frozen-page rendering results. They do not establish live-site,
scripting, instruction, performance or catalog-wide equality. CNN's remaining
rendering/source failures, Vlang's residuals, Reddit's missing evidence and prior
inexact controls keep the overall task open.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-yuv-atlas-20261115/`.
Cleanup hashes **6,588 files across 66 owned roots**, preserves/reverifies 1,978
selected files (42,198,904 bytes), and removes owned binaries, generated
intermediates, capture profiles/jobs, guards, locks and the test alias. Shared
production bundles and dependencies remain.

## Production confirmation of the near-half atlas, 2026-11-16

Production executable
`419ad8d777319bd5b8605799a59da05b59e20ae596bc3f50594babb87db2ba56`,
receipt `20261116-002422-18914df3` (C/literal V `-prod`/single unit), confirms
`5995502f5` by consumed source hashes. All **48 workloads/96 fresh captures**
pass the unchanged driver's **196 source checks**. Every pair repeats and every
PNG matches the accepted atlas diagnostic. CNN stays at **54,627**, Vlang at
**27**, and GitHub, Hacker News, Lobsters and Wikipedia stay exact. Startup
smoke, all native guards, driver, outer guard and guarded analysis exit zero.
This closes the preceding atlas production hold.

The six owned candidate files were temporarily restored to their committed
`a87e95b89` inputs in the canonical checkout, and the real V GG preparer ran.
After validation, the candidate checkpoint was restored atomically and staged
again; all **852 checkpoint pins** matched. This transaction preceded the
additional mip-edge correction below. No foreign changes were reverted, no
production gate was bypassed, and no separate production build was requested.

## Full-plane aligned YUV mips, 2026-11-16

`69e1fce6c` preserves the original YUV420 planes for a further bounded scale
domain: natural dimensions divisible by four, destination dimensions strictly
between quarter and half size on both axes, and the previously reduced upload
requiring another mip under the existing sampler policy. The original luma
levels 0–2 and chroma levels 0–1 then retain aligned grids. The earlier near-half
atlas and promoted/reduced-upload paths keep their selection outside this
domain. Full source, complete opaque untagged VP8, integer translation, unit
opacity and existing size restrictions remain. No site, resource hash or pixel
coordinate selects this behavior; no shader or sampler policy changes.

Generated mip padding also needs correction: averaging the original padded
edge does not necessarily repeat the newly averaged logical UV edge texel.
The first generated UV mip now extends its own last row and column; generated
luma and alpha bytes stay unchanged. An independent 6×6 chroma texture supplies
the exact edge oracle for a 12×12 atlas drawn at 4×4. That regression fails
before the edge correction and passes byte for byte afterward with both
single-sample and four-sample rasterization. A separate exact-color test checks
plane filtering before RGB clipping without depending on implicit LOD precision.

Accepted diagnostic executable
`4eb066fc6eeb12d3c6b5ae2fc6045d2b8a4b7ea301efb3bb0e413f27d111a544`
(C/O0/preallocated/no-GC) completes **48 workloads/96 fresh captures**, plus
startup smoke. Every pair repeats exactly, and **all 47 non-CNN PNGs are
unchanged** from the preceding accepted atlas cohort. CNN improves
**54,627→33,409**: **21,724 corrected** and **506 introduced** pixels. Every new
error is at most one channel level; every changed pixel lies inside Sullivan's
image. Its interior, excluding four pixels at each edge, improves
**22,366→2,698**, maximum error **2→1**. The other four measured photo interiors
retain 115/383/230/1,048 differences, each with maximum error one. GitHub,
Hacker News, Lobsters and Wikipedia remain exact, and Vlang stays at 27.

The logged focused and unlogged broad CNN PNGs agree. All **826 consumed
rendering/CSS/DOM/layout V witnesses and 852 input pins** stay matched. All 96
native guards, driver, outer guard, startup and guarded analysis exit zero.
Ten focused V test functions pass under arena poisoning and 3 GiB runtime
guards: four CPU packing/eligibility/mip-padding checks, four GPU sampling and
edge checks, and two native-callback checks. The callback exercises original
and stronger minification across both tile seam directions, preserving sample
counts, fringe and row padding. The CPU, GPU and callback executables have
11/54/165 matched V witnesses respectively. Their hashes are
`bf111a91fa4e65b7c7de7ada5cd1cfc06586d99a3f1f59a0a0ea90685bf11360`,
`c75551e314ae91fd85babb9bdd8ad918c346042b016db63743aa7c58f07b0311`, and
`0b744e0a6fdec5e3e7d13a2868df0ee97aafb3772247b9021b8679ae09a35488`.

The initial prototype's 33,412 result, its complete 48-workload cohort, a failed
test arithmetic estimate of implicit LOD blending and the failing mip-edge
control remain in local evidence. The arithmetic test now uses inputs whose
independent base and mip samples coincide; it does not alter rendering or a
tolerance. The edge regression exposed a real defect and led to the padding
repair. Only the corrected 33,409 result, after rerunning all focused checks
and the full 48-workload cohort, supplies this feature's diagnostic acceptance.

Production confirmation passes on completed shared executable
`99957e17381616eafd23c961e391677980d05c30240dedcf75a5f49f759ed5d0`,
receipt `20261116-011251-c8495e02` (C/literal V `-prod`/single unit). Its consumed
implementation hashes match the final edge-corrected source, despite a requested
head predating this commit. All **48 workloads/96 fresh captures** pass the
unchanged driver's **196 source checks**. Every pair repeats byte for byte, and
every PNG equals the accepted final diagnostic. CNN stays at **33,409**, Vlang
at **27**, and the four exact archived sites stay exact. Startup smoke, all 96
native guards, driver, outer guard and guarded analysis exit zero. This closes
the full-plane feature's production validation. No duplicate manual build was
queued; the shared completed bundle was reused.

Residual analysis accounts for all 33,409 CNN differences inside eight image
rectangles, with zero outside. The right-column ice-cap photo contributes
**27,345** (26,927 with maximum channel error one, 418 with error two).
Two partly visible bottom images contribute 986 and 372, with maximum errors
58 and nine. The five other full image rectangles contribute
2,825/131/388/241/1,121, each at most one channel level. These full rectangles
include borders and differ from the interior statistics above. This identifies
remaining work; no pixels are masked from the equality gate.

These are frozen-page rendering results, without a performance, instruction,
live-site or scripting claim. CNN's remaining rendering/source failures,
Vlang's residuals, missing Reddit evidence and prior inexact controls keep
catalog-wide equality open. No original reference or tolerance changes.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-full-plane-20261116/`.
Cleanup hashes **13,115 files across 85 owned roots**, preserves and reverifies
**3,919 selected files (83,816,153 bytes)**, then removes owned binaries,
generated intermediates, profiles, capture jobs, guards, locks and the focused
test alias. The archive guard and lock are separately preserved, verified and
removed after completion. No owned scratch remains; the shared production
bundle and dependencies are retained.

## Profiled RGB WebP half uploads, 2026-11-16

`5a2157173` corrects the bounded case where a canonical sRGB VP8
image requests an exact half-size upload. The ice-cap image carries ICCP and
therefore uses RGB decoding, independently of the preceding untagged YUV fix.
All **341,640 decoded RGBA pixels** agree byte for byte with an independent
fresh Brave Canvas2D readback. The difference occurs after decoding.

The new path preserves the CPU mip's integer averages in the half-size upload
and its remaining CPU mip chain. A full-size upload already used in the same
resource/navigation/raster scope stays available with its existing GPU mips.
Unsupported rounded uploads, stronger reductions and other profiles retain
their previous path. Cache keys include the body digest; retained pixels and
keys live outside temporary paint memory. Existing complete opaque sRGB VP8,
full-source, identity-linear-transform, opacity and size restrictions remain.
No shader, sampler bias, native application UI, site-specific condition or
pixel-coordinate exception changes.

The public [Chromium decode-cache policy](https://github.com/chromium/chromium/blob/main/cc/tiles/gpu_image_decode_cache.cc)
motivated checking upload size and larger cached decodes separately. Those
current upstream sources do not identify the exact path in the pinned Brave
binary; the independent pixel controls establish this correction's bounded
behavior. A separate first-use stronger-reduction diagnostic remains inexact
and outside this feature. Its source, references and all probe attempts remain
local; no reference was changed to make that case pass.

Two new controls capture the same immutable image bytes in different upload
orders: `profiled-webp-half-upload` draws two initially minified images, while
`profiled-webp-native-first` draws the ice-cap image at native size before its
thumbnail. Each new reference repeats exactly in two fresh Brave processes.
The existing native-first train reference is unchanged. Direct GG rendering of
both complete new controls is pixel-exact at sample counts one and four.
Full browser captures still differ by **18/24 one-level pixels** respectively;
the native-size part of the second control is exact. These browser residuals
are counted without masks or a nonzero tolerance.

Final diagnostic executable
`6b61cd6ac49023af95b07814b170d57bcc429f1aacdde68b31072cedb902708c`
(C/O0/preallocated/no-GC) completes **50 workloads/100 fresh captures**, plus
startup smoke. Every pair repeats exactly, and all **47 prior non-CNN PNGs**
are unchanged from the accepted full-plane cohort. CNN improves
**33,409→6,091**: **27,321 corrected** and **three introduced** pixels. Every
new error is at most one channel level, and every changed pixel lies in the
ice-cap photo. Its complete rectangle improves **27,345→27**, maximum error
**2→1**; six differences remain after excluding four pixels at each edge.
GitHub, Hacker News, Lobsters and Wikipedia stay exact; Vlang stays at 27.
The logged focused and unlogged broad CNN PNGs agree.

The first complete 100-capture cohort checked V inputs but omitted explicit
runtime shader pins. It remains recorded without supplying final acceptance.
The second complete cohort includes **826 consumed rendering/CSS/DOM/layout V
witnesses and 873 source/runtime-asset pins**; all stay matched. Every PNG
equals the preceding complete cohort. All 100 native guards, startup, driver,
outer guard and guarded analysis exit zero. The focused checks also run again
with shader/runtime-asset pins matched before and after execution.

Four focused V functions pass with arena poisoning and 3 GiB runtime guards.
They verify temporary-scope pixel ownership, larger-upload reuse, independent
raster scopes, rejected targets/markers, retention of stronger reductions and
both complete independent GG pixel controls. The browser helper test has
165 matched V witnesses and executable
`c2a026384482a3f35fb6bf94232f152a20288c9ede3f4b512a11a09a68ca0992`;
the GPU test has 58 and executable
`7272e0dea2248ac04ebf32875a44d0f197fcbd4fb4af39e5100a3884b07d0c42`.
An initial diagnostic name collision, an initially incorrect manual destination
height and a test setup missing Chromium font policy remain recorded. The
accepted checks use corrected setup and observed paint geometry.
The test-only follow-up `ea42af34f` marks the browser-helper test file as
macOS-only with the platform suffix and V test directive. Both helper checks
run again successfully with matched V/shader/runtime pins and arena poisoning;
implementation bytes and all pixel references stay unchanged.

Initially available production `195b5171` lacks the new helper by consumed
source hash. After diagnostic cleanup, shared production executable
`d0fa860e0a8e080190c84b261b26e1a68bafabfaa32a73f660a96c5a45fb3b5a`
completed, receipt `20261116-015645-b9d02ef9` (C/literal V `-prod`/single unit).
Its consumed helper hash matches the final committed source, despite the
requested head predating the feature commit. All **50 workloads/100 fresh
captures** pass the unchanged driver's **196 source checks**. Every pair repeats
and every PNG equals the accepted diagnostic. CNN stays at **6,091**, Vlang at
**27**, and the four exact archived sites stay exact; the new controls retain
18/24. Startup smoke, all 100 native guards, driver, outer guard and guarded
analysis exit zero. This closes production validation of this slice. The
completed shared bundle was reused, with no duplicate manual build requested.
This is frozen-page rendering evidence, without a live-site, scripting,
instruction or performance claim.
CNN's remaining image/source failures, Vlang, missing Reddit evidence, the new
one-level control residuals and prior inexact controls keep full equality open.
No original reference or tolerance changes. Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-icc-mips-20261116/`.
The three cleanup phases hash **10,136 files across 95 owned roots**, preserve
and reverify **3,141 selected files (73,646,760 bytes)**, and remove owned test/browser
binaries, intermediates, profiles, capture jobs, guards, locks and the temporary
test alias. Independent decoded RGBA readbacks are retained locally. The
archive guards and locks are separately copied, verified and removed after
completion. No owned scratch remains; shared bundles and dependencies stay.

## Normalized R8 plane resampling, 2026-11-16

`f09630164` corrects the single-channel resizer used after CPU plane mip
selection. The previous implementation interpolated byte-valued floats and
rounded halfway values upward. The R8 raster pipeline normalizes bytes first,
accumulates four weighted samples with fused multiply-add, and stores UNORM8
with nearest-even rounding. Merely changing the final rounding is insufficient:
normalization can move an apparent byte-space tie slightly above the midpoint.
The new V sampler reuses the existing raster-pipeline arithmetic helpers;
RGBA lowp sampling, CPU mip construction, browser upload eligibility, shaders,
native UI and original references/tolerances remain unchanged.

An independent test-only Skia library supplies exact R8 references. Before the
fix, **ten of 24,480 scaled plane bytes** differ, each by one; afterward all
24,480 agree byte for byte. Ten additional cases cover 1D planes, enlargement,
reduction, odd extents and anisotropic scales: **all 9,493 output bytes agree**.
The final oracle compile and execution retain **2,028 source/header/library/data
input hashes**, checked before and after, plus the executable identity. Skia
is a local diagnostic dependency, not a new browser dependency.

Ten focused V functions pass under arena poisoning and 3 GiB runtime guards:
seven existing/new plane-scaling checks and three R8 sampler checks. They
include both midpoint parities, normalized-byte roundtrips, clamped constant
planes, independent reference dimensions, invalid extents and incomplete
buffers. The plane test executable is
`05b72cd1eefecbf108032244995682540b0757cf08315aee237df8c5d6d647dc`
with **71 matched V witnesses**; the R8 primitive test is
`fcd917a00648b30435404965af4e36f661f6d48bd24bb4f639bd558190100fc3`
with **61**. All focused guards exit zero.

The three R8 primitive functions also execute successfully with literal V
`-prod` and C `-O2`, under arena poisoning and a 3 GiB guard. This executable is
`8ea6d6ecaae001ace50c5cb6cb28e1ebc4b8681763d28572cc5cce627579a47d`;
its **61 V witnesses** and executable hash remain stable during execution.

The final C/O0/preallocated/no-GC diagnostic completes **50 workloads/100 fresh
captures**, plus startup smoke. Its executable is
`6f5887b82c59cfc7ad43f67c1a8ac9c66c7754de117e9637635992a1f9dfa367`.
Every pair repeats, and **every PNG is byte
identical to the preceding accepted cohort**. The logged focused and unlogged
broad results agree. All **886 consumed rendering/CSS/DOM/layout/raster V
witnesses and 935 source/runtime-asset pins** stay matched. All 100 native
guards, driver, outer guard, startup and guarded analysis exit zero. CNN stays
at **6,091**, Vlang at **27**, and GitHub, Hacker News, Lobsters and Wikipedia
stay exact. **This fix receives no site-level pixel or performance credit.**

The original investigation concerned CNN's partly visible 480×270 image whose
requested quarter upload rounds to 120×68. Fresh baseline production `d0fa860e`
reproduces CNN's 6,091 pixels twice. All **194,400 decoded I420 bytes** of this
additional image agree with independent fresh Brave WebCodecs readback. The
rounded-upload experiment changes CNN 6,091→6,062, but corrects only 187 pixels
and introduces 158; its separate new photo control still has 5,526 differences,
maximum error 33. That expansion is rejected and fully reverted. No new
reference or nonzero tolerance makes it pass. The experimental HTML, stable
Brave references, source snapshots, outputs and failed GPU comparison remain
local. They supply no implementation or pixel acceptance.

The independent oracle revealed the narrower R8 bug above during that rejected
experiment. A rounding-only attempt leaves twelve differing scaled bytes and
is also superseded by the complete normalized sampler. Initial test pointer
syntax errors and an attempted launch of its absent executable are retained;
neither establishes a browser crash. An initial browser compile caught an
unrelated form edit mid-change; the retry compiles after that edit is committed.
No foreign edits were reverted or incorporated into this feature.

The initially available production executable `7674999d`, receipt
`20261116-024427-5b398122`, contains the earlier rounding-only diagnostic and
lacks the final helper; it cannot validate the fix. The subsequently completed
shared production executable
`c23c0d0a98ad945b7f6ffb581c1dc91172ed39b99aa5a37eecf23641607c8fa8`,
receipt `20261116-030137-13ee3df8`, contains the final implementation by consumed
source hashes (C/literal V `-prod`/single C unit). Its **50 workloads/100 fresh
captures all repeat and match the accepted diagnostic byte for byte**, with the
default **196 source checks active**. All native capture guards, startup,
driver, outer guard and guarded analysis exit zero; executable, native library,
runtime assets and all 935 source/runtime pins stay unchanged throughout.
The normal coalesced build is reused; no duplicate manual build is requested.
These are frozen workloads, without a live-site, scripting, scrolling or
instruction claim.
CNN, Vlang, missing Reddit evidence and the prior inexact controls keep the
overall equality gate open. Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-rounded-yuv-20261116/`.

Cleanup inventories **135 owned roots/8,233 files** across the diagnostic and
production phases. **2,307 selected evidence files/55,860,721 bytes** are copied
locally and SHA-verified before deleting job binaries, intermediates, profiles,
capture jobs, guards and locks. Archive guards and locks are separately copied,
verified and removed. Temporary test sources and the rejected photo control
are removed; no owned scratch remains. Shared bundles and dependencies stay.

## Rejected general gradient localization, 2026-11-16

The four remaining Vlang scene differences reproduce in the reduced orbit
fixture. Three are already present with the orbit hidden. Fresh production
controls repeat the underlay at **three** and the scene at **four** differences,
with PNGs identical to the accepted production cohort. This separates those
three background differences from the JPEG and orbit geometry.

A diagnostic expands the existing text-only gradient coordinate localization
to ordinary linear/radial CSS gradient tiles. It **corrects zero pixels and
introduces one** in each workload: Vlang **27→28**, underlay **3→4**, scene
**4→5**. Each changes only `(492,557)`, red 20→19 against Brave's 20. The
candidate is rejected and both source changes are restored byte for byte;
there is no accepted gradient fix or reference/tolerance change.

Executable `3e95f3dc3aaaeb3bb4c678ab3fbb12455b1464ef1ec31785ff9c8c861f02b842`
uses C/O0/preallocated/no-GC. Six fresh candidate captures repeat, in addition
to four fresh production controls. All **886 consumed V witnesses and 935
source/runtime pins** remain matched through candidate compilation/capture.
Startup, ten capture guards, both drivers, compilation and guarded analysis
exit zero; those successful executions do not clear the visual regression.
Local commands, identities, transitions, candidate source snapshots and PNGs
are retained under
`docs/performance/vlang-gradients-20261114/raw/vlang-scene-grid-20261116/`.
Cleanup inventories **11 owned roots/480 files**, preserving and SHA-verifying
**117 evidence files/3,660,230 bytes** before removing all job scratch. The
archive guard and lock are separately copied, verified and removed. No owned
scratch or experimental source changes remain.

## Full-range JPEG plane sampling, 2026-11-16

`8c2e79555` keeps eligible scaled JPEG uploads as packed full-range Y/U/V
components. Previously, the floating upload converted and clipped each texel
to RGB before interpolation and built RGB byte mips. CPU mip construction and
texture filtering now operate on the independent components; the full-range
matrix and clipping follow sampling. The matrix uses Skia's default
[Rec601 full-range constants](https://raw.githubusercontent.com/google/skia/main/src/core/SkYUVMath.cpp).
The cache namespace distinguishes this byte payload from earlier float uploads.
Existing JPEG decode/shape guards remain, while the V tile bridge preserves
each tile's sample selection even across mixed readbacks. Native UI is untouched.

The isolated GPU control reproduces the old **23 JPEG differences**. The
CPU-plane-mip path retains **one**, correcting **22 with zero introduced**.
Base-only sampling instead gives 169 differences (maximum three), and GPU plane
mips give 18 (maximum one); neither variant is selected. The final browser
diagnostic, C/O0/preallocated/no-GC executable
`82898a136e1754e1809152f252b84a0858b59cb9ee61125c55a3db7db1df4ecb`,
verifies the live code path's **540×540→34×34** upload in its diagnostic log.

Vlang improves **27→5**, with **22 corrected, zero introduced and 22 changed**.
The remaining JPEG pixel `(47,169)` is green 239 against Brave's 240; its
unchanged four scene differences remain separate. This pixel was already
incorrect before the earlier fractional-RGB slice, so **all nine pixels
introduced by that historical slice are now corrected**. Focused and broad
PNGs match. The final **50 workloads/100 fresh captures** all repeat, with
**all 49 other PNGs byte-identical** to the preceding accepted production
cohort. CNN stays at **6,091**; GitHub, Hacker News, Lobsters and Wikipedia
remain exact. All 100 native capture guards, startup smoke, driver, outer guard
and guarded analysis exit zero. **886 consumed V witnesses and 939
source/runtime pins** stay matched throughout this cohort.

Eighteen focused V functions execute under arena poisoning and 3 GiB guards:
eight plane checks, three full-range GPU checks, three existing limited-range
GPU checks, three tile/native-callback checks and one native-preparer check.
The Python preparer check also passes under a 3 GiB guard. They exercise
unclipped plane values, odd-sized CPU mip weights, full-range filtering,
malformed payload rejection, native channel conversion, mixed sample ownership,
backdrop/pitch padding and partial staging repair. The tile test executable is
`6776e29fe45648956c1e588cf5724f66832cc9c36e44afe9ff0126714e05d8be`.

The first probe's full-range shader was not enabled because the two preparers
disagreed; its 484-pixel outputs do not establish this path's behavior. The
corrected probe calibrates the old 23-pixel control before comparing variants.
A focused native-preparer test then catches an ambiguous atlas repair marker
after adding the JPEG branch. Restricting that marker to its limited-range
branch fixes repair without changing the generated shader. After this tooling
correction, **all 93 staged canvas inputs are byte-identical** to the accepted
capture inputs; both preparer tests pass. The failed staging run, an early
driver read before its executable existed, and an incomplete verification
command are retained separately from successful checks. A Python/V preparer
newline difference is resolved through the canonical native preparer and
verified by those 93 hashes. No failed attempt is counted as a pass.

Available production `7c47d4f3`, receipt `20261116-032112-8cff4a11`, lacks the
JPEG plane change by consumed source hashes. **Production confirmation remains
pending**; the feature requests the normal coalesced C/literal V `-prod`/
single-unit rebuild, with no duplicate manual build. These are frozen captures,
without a live-site, scripting, scrolling or instruction claim. CNN, five
Vlang pixels, missing Reddit evidence and prior inexact controls keep full
equality open. Local commands, identities, transitions, source witnesses,
PNGs and failures are under
`docs/performance/vlang-gradients-20261114/raw/jpeg-planar-20261116/`.

Cleanup inventories **65 owned roots/3,974 files**. **1,114 selected evidence
files/30,095,832 bytes** are copied locally and SHA-verified before removing
job binaries, intermediates, profiles, captures, guards and locks. The archive
guard and lock are separately copied, verified and removed. The temporary probe
is removed; no owned scratch remains. Shared bundles and dependencies stay.

## Production confirmation of full-range JPEG planes, 2026-11-16

Production executable
`aa91e7cc1c8c2c3ebe083a96582817e16f1de903c8a81ff43a4a3674bc5b1a64`,
receipt `20261116-035309-fefe9f5d` (C/literal V `-prod`/single C unit), contains
`8c2e79555` by consumed source hashes. Its executable also embeds the unchanged
complete shader source byte for byte. **50 workloads/100 fresh captures** all
repeat and match the accepted five-pixel diagnostic. All **196 default feature
checks** remain active; **60 additional selected source/runtime pins** stay
unchanged. Startup, all capture guards, driver, outer guard and guarded analysis
exit zero. Vlang is **five**, CNN **6,091**, and the four previously exact
archived sites remain exact. This confirms the JPEG slice in that production
bundle, without validating other uncompiled checkout edits. The normal completed
bundle is reused, with no duplicate production build.

## Gray8 CPU-plane stores, 2026-11-16

`293c8abed` corrects the CPU plane's storage format. Although its GPU texture is
R8, `SkYUVAPixmapInfo::DefaultColorTypeForDataType(kUnorm8,1)` selects **Gray8**
for CPU pixmaps. Gray8 applies the raster pipeline's BT.709 luma stage after
interpolating equal RGB components. The separate products and additions can
round differently from a direct R8 store. V now reuses that existing luma stage
for CPU YUV-plane resizing, preserving the R8 API's original behavior. No
source/site/coordinate exceptions, matrix tuning, shader or mip-kernel changes.

Independent test-only Skia checks cover every pair of byte values, resized from
two samples to three: **196,608 Gray8 bytes and 196,608 R8 bytes** agree exactly.
The reference formats differ at **1,600 bytes**; for example, the 0/13 midpoint
stores as Gray8 6 versus R8 7. Ten additional Gray8 dimension cases agree at all
**9,493 bytes**. A real three-plane 120×68 upload agrees at all **24,480 bytes**;
R8 and Gray8 references differ at three of them. The final oracle rerun pins
**2,032 source/header/library/data/executable inputs** before and after both
native executions. Skia remains a diagnostic dependency only.

Fifteen permanent focused V functions pass: four Gray8, three existing R8 and
eight plane checks. The four Gray8 functions also pass with literal V `-prod`
and C `-O2`; both modes retain exact midpoint/reference hashes. A separate
real-plane diagnostic also executes successfully. V runtime checks use arena
poisoning and 3 GiB guards. The optimized test executable is
`043fb9ea16925ae66c2e5626cad7002ae252fcfa94f9bc645ef6c9a62db9814c`.

The JPEG's uploaded U texel `(8,12)` changes **123→122**, correcting green
**239→240** at document pixel `(47,169)`. The isolated JPEG now has **zero**
reference differences. Final C/O0/preallocated/no-GC browser executable
`cb6a2dd2cc6465abf1ea35522863d779cc368b5f85e1f01fa3d6de7d37a01e16`
improves Vlang **5→4**, with **one corrected, zero introduced and one changed**
pixel. Its four scene differences remain. All **50 workloads/100 fresh captures
repeat**, with **all 49 other PNGs byte-identical** to the accepted production
cohort. Logged focused and unlogged broad captures agree. All **888 consumed V
witnesses and 941 source/runtime pins** stay matched. All 100 native capture
guards, startup, driver, outer guard and guarded analysis exit zero. CNN stays
at **6,091**; GitHub, Hacker News, Lobsters and Wikipedia stay exact.

The available production `aa91e7cc` validates the preceding five-pixel result,
not this subsequent Gray8 correction. **Production confirmation remains
pending**; the new feature requests the normal coalesced rebuild. Existing
references and tolerances remain unchanged. These frozen checks establish no
live-site, scripting, scrolling or instruction result. Four Vlang scene pixels,
CNN, missing Reddit evidence and prior controls keep overall equality open.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/gray8-planes-20261116/`.

## Retained matrix and Brave decode diagnostics, 2026-11-16

A matrix-constructor experiment changes neither the isolated JPEG's one-pixel
result nor any PNG in six focused browser captures (Vlang five, CNN 6,091 and
the JPEG control zero). Both source edits are reverted byte for byte before
the accepted work. It receives no implementation or pixel credit.

A separate Brave trace initially uses `img.decode()` for readiness and changes
the original script policy. That protocol retains full 480×270 luma and 240×135
chroma textures. Its PNG differs from the unchanged control at **5,401 pixels**,
maximum 29.
Polling normal completion under the original script-disabled policy instead
reproduces that reference **exactly**, with three 120×68 R8 GPU textures. Both
runs retain identical Brave executable/library identities. This diagnostic
also illustrates why GPU texture format alone does not identify the CPU
pixmap's store. The changed-workload trace is retained without acceptance;
no page reference or production readiness code is changed. Commands, traces,
identities, source snapshots and PNGs are local under
`docs/performance/vlang-gradients-20261114/raw/yuv-matrix-order-20261116/`.

Cleanup for both phases inventories **95 owned roots/8,224 files**, preserving
and SHA-verifying **2,231 evidence files/68,371,224 bytes** locally before deleting
job binaries, intermediates, profiles, captures, guards and locks. All six
temporary canonical probes are removed. The archive guard and lock are
separately copied, verified and removed; no owned scratch remains. Shared
production bundles and dependencies stay.


## Preserve CSS gradient destination geometry, 2026-11-16

`6003e7627` removes an identical rectangular clip at the CSS gradient boundary.
Brave's recorded picture draws the snapped gradient rectangle under its rounded
parent clip. Vox additionally clipped the fill to that same rectangle, allowing
Graphite to replace its geometry with a cover draw and changing interpolated
coordinates. The new scalar proof requires five segments forming the same closed
rectangle, four distinct corners, straight edges, finite positive clip geometry,
zero radii and a fill. It preserves rounded, smaller, nonrectangular and stroked
clips. SVG's recording path stays unchanged. No reference, tolerance, shader,
gradient coefficient, source/site exception or coordinate adjustment changes.

Final C/O0/preallocated/no-GC diagnostic executable
`f3f3369ed8b23d736b98c984b5a5f22c1634cbb234c3637fdb2ce2b39a1d5f1b`
completes **50 workloads/100 fresh captures**, plus startup:

| Workload | Previous differences | Final differences | Corrected / introduced |
| --- | ---: | ---: | ---: |
| Vlang | 4 | **1** | **3 / 0** |
| Orbit underlay | 3 | **0** | **3 / 0** |
| Complete clipped orbit | 4 | **1** | **3 / 0** |
| Rotated-ellipse shadow control | 19 | **5** | **14 / 0** |
| CNN | 6,091 | **6,091** | 0 / 0 |
| GitHub / Hacker News / Lobsters / Wikipedia | 0 each | **0 each** | 0 / 0 |

Every pair repeats byte for byte. **46 workload PNGs remain unchanged**, and no
workload introduces a differing pixel. All final PNGs also equal those of both
preceding 100-capture candidates. All **889 consumed V witnesses and 942
source/runtime pins** stay matched. Startup, 100 capture guards, driver, outer
guard and guarded analysis exit zero. The one remaining scene pixel is
`(630,617)`, green 34 versus Brave's 33; it reproduces with only the blurred
orbit shadow. Changing border color normalization does not correct it.

Two new focused functions verify the unchanged Brave scene's interior and
conservative clip rejection, including corner order, diagonal/duplicate points,
invalid segment kinds, open paths, strokes, mismatched extents and nonfinite clips. Three existing
coordinate-localization/filter-clip functions also execute successfully. The new
functions additionally pass with literal V `-prod` and C `-O2`; its executable
is `0ccec714f6e207e530397b8345dd9ad20ab69021923bfe71ae1dfdf2e44ae5af`.
All V runtime checks use arena poisoning and 3 GiB guards. A dedicated arena
shows **zero growth across 100 calls**. The intermediate by-value adapter and
fixed-array slice allocated; the final borrowed descriptor and indexed radius
loop remove both sources. The failed allocation assertion is retained.

Three fresh Brave captures reproduce the original underlay reference exactly.
The first two LayerTree attempts retain stale/empty-layer evidence; the third
obtains the picture after a zero-width outline invalidation following PNG
capture. Its command log confirms the snapped rectangle and rounded parent
clip. These logs are diagnostics, not a replacement reference or an unchanged
live workload. An existing independent Skia Metal library reproduces the
clipped/unclipped gradient differences. The CPU-only Skia library's missing
Graphite linker symbols, initial probe syntax/API failures and a full-layout
probe stopped by the 12 GiB guard remain recorded without passing credit.

Production `4488b888297c87a05424c6b5c6fcd32d76a15c901c1b0ee099a9a6bb65b863a7`,
receipt `20261116-052137-95504e65` (C/literal V `-prod`/single C unit), contains
Gray8 and the earlier generic clip-elision variant by consumed source hashes.
Two fresh captures each show Vlang at **one** and the isolated JPEG at **zero**;
Vlang's PNG equals the final diagnostic. This validates that production result,
**not the final CSS-only allocation-free implementation**, whose managed rebuild
is requested by the normal commit hook. No duplicate production build is queued
or awaited. The earlier `c07ab59e` identity check alone supplies no capture result.

All-site equality remains open: the remaining Vlang pixel, CNN, missing Reddit
evidence and prior inexact controls persist. Frozen PNG checks supply no
live-site, author-script, scrolling or instruction-performance acceptance.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/scene-precision-20261116/`.
Cleanup inventories **154 owned roots/10,778 files**, preserves and SHA-verifies
**3,328 evidence files/122,876,618 bytes**, and removes all job binaries,
intermediates, profiles, guards and locks. Four temporary canonical probes are
removed. The archive guard and lock are separately copied, verified and removed;
no owned scratch remains. Shared production bundles and dependencies stay.


## Preserve resolved blur support before rotation, 2026-11-16

`bd6bfd3f7` fixes Vlang's last differing pixel by retaining the actual rounded
low-resolution blur support and its origin when resolving a rotated shadow.
The input footprint still uses the nominal three-sigma bounds; the final A8
resolve now intersects the mapped blurred-image bounds with the original desired
output. The previous resolve cropped back to the nominal footprint, changing the
image origin and final sampling. Axis-aligned callers retain their output bounds.
No reference, tolerance, shader, kernel, application UI or site exception changes.

An independent native Skia Metal mask-filter draw matches Brave's orbit interior
at both compositor origins. All **669,752 A8 bytes** of the two original-sized
mask comparisons also match. Capturing the oracle's own Metal draw parameters
then identifies native resolved sizes **953×264 / 959×446**, versus Vox's prior
**953×258 / 959×442**. The new generic bounds calculation reproduces the native
sizes and corrects the remaining `(630,617)` pixel. Texture-padding, coverage-quad
and shader-precision experiments did not correct it and are fully reverted.
The optimized probe that skipped a draw embedded in an assertion receives no
passing credit; the final focused test invokes the draw outside its assertion.

Final C/O0/preallocated/no-GC diagnostic executable
`74ff34d9c5d68d27d0e68671d30107d48b6a8919d4f8e73aaeb66187aed5b39a`
completes **50 workloads/100 fresh captures**, plus startup:

| Workload | Previous differences | Final differences | Corrected / introduced |
| --- | ---: | ---: | ---: |
| Vlang | 1 | **0** | **1 / 0** |
| Complete clipped orbit | 1 | **0** | **1 / 0** |
| Rotated-ellipse shadow control | 5 | **0** | **5 / 0** |
| CNN | 6,091 | **6,091** | 0 / 0 |
| GitHub / Hacker News / Lobsters / Wikipedia | 0 each | **0 each** | 0 / 0 |

Every pair repeats byte for byte. **47 other workload PNGs are unchanged**;
no workload introduces a differing pixel. All **889 consumed V witnesses and
942 source/runtime pins** stay matched. Startup, all 100 capture guards,
driver, outer guard and guarded analysis exit zero. The separate logged focused
captures also make Vlang, the underlay and the complete clipped orbit exact.

The focused test covers both tile origins, verifies the resolved dimensions,
compares the unchanged Brave scene's rectangular interior, and retains the
truncated-window negative control (**486 differences**). Ordinary and literal V
`-prod` C builds both execute successfully with arena poisoning and 3 GiB guards,
with executables `97930db9742cdebdeb5073bdbd75c244d1b8651307e3b30330d72ac281760a08`
and `e853487f080f38aa061ebadc8ef93469a32ad29175dae6e0fac822ce1f118fe4`
respectively. Both retain 45 matched V witnesses.

Production `4488b888`, receipt `20261116-052137-95504e65`, remains the latest
completed bundle checked here. It cannot validate this new source. The managed
commit hook requests a coalesced C/literal V `-prod`/single-unit rebuild; no
duplicate production build is requested or awaited. Production confirmation
remains pending. CNN's image/source failures, missing Reddit evidence and prior
inexact controls keep catalog-wide equality open. These frozen checks establish
no live-site, scripting, scrolling or instruction-performance acceptance.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/orbit-shadow-20261116/`.
Cleanup inventories **86 owned roots/4,111 files**, preserves and SHA-verifies
**1,604 evidence files/130,148,886 bytes**, and removes job binaries,
intermediates, profiles, guards and locks. Both temporary canonical probes are
removed. The archive guard and lock are separately copied, verified and removed;
no owned scratch remains. Shared production bundles and dependencies stay.


## Rounded WebP uploads and legacy CPU mips, 2026-11-16

`eb35365d2` permits minified VP8 uploads whose two dimensions are rounded up
from the same power-of-two decode level. It also corrects the shared CPU plane
mip selector: Chromium's legacy Skia configuration uses the geometric mean of
the two scales, preserving f32 rounding, rather than the stronger reduction.
For 480×270→120×68, the former selector incorrectly chose one extra mip for
both luma and chroma. Source, opacity, profile, transform and size restrictions
remain. No shader, reference, tolerance, site exception or application UI changes.

Current upstream [decode-cache policy](https://github.com/chromium/chromium/blob/main/cc/tiles/gpu_image_decode_cache.cc)
and [decode-size rounding](https://github.com/chromium/chromium/blob/main/cc/tiles/mipmap_util.cc)
motivated the investigation; those sources alone do not identify the pinned
Brave path. A fresh instrumented Brave capture repeats the earlier rounded-photo
control byte for byte. Its detailed memory dump records **24,480 upload bytes**,
consistent with three 120×68 unorm8 planes. The independent native Skia build's
recorded arguments explicitly enable legacy anisotropic mip selection. Its
nearest-mip Gray8 draw reduces the isolated control's large errors to one level;
the alternate fractional source-extent hypothesis is rejected and retained.
The earlier CPU oracle used a different Skia build and did not establish this
legacy mip choice; its R8 store comparisons remain separate numerical evidence.

All **24,480 resized plane bytes** from the corrected V code match the native
Gray8 oracle exactly. Ten synthetic isotropic, rounded and anisotropic cases
add **135 exact bytes**. Twelve focused V functions execute successfully with
arena poisoning and 3 GiB guards, including exact reference arrays and rejection
of mismatched decode levels, invalid dimensions and incomplete planes. The
plane/upload executables are `6cbe877a6b952d2632f2c5f86fac3fe235967662f29c845ce2a9af485d1a53be` and
`75e592f21795062d381ef510bc049bf963fab20f3c49ddf2b773a270678a204a`, each with **72 matched V witnesses**.
An additional literal V `-prod` C executable, `a7239c87df06ef095e1ee47074611260121f44a9401821bb4b6664621799cf12`,
writes all 24,480 real plane bytes; an external byte comparison confirms equality.
This check executes the scaler outside assertions. Native header/library,
configuration, source, fixture and executable pins remain matched.

Final C/O0/preallocated/no-GC browser
`42f2ee25fa12b5767c5929b9318a15029f23f8fc289e5833e3bcd2a190453c45`
completes **50 workloads/100 fresh captures**, plus startup. All pairs repeat;
**all 49 non-CNN PNGs remain unchanged**. All **889 consumed V witnesses and
942 source/runtime pins** stay matched. Startup, all 100 capture guards, driver,
outer guard and guarded analysis exit zero. Logged focused PNGs agree with the
broad result, and confirm the 120×68 planar upload executes on CNN.

| Scope | Previous differences | Final differences | Maximum channel error |
| --- | ---: | ---: | ---: |
| Complete CNN viewport | 6,091 | **5,160** | **58→9** |
| Partly visible 480×270 photo | 986 | **55** | **58→1** |
| Vlang / GitHub / Hacker News / Lobsters / Wikipedia | 0 each | **0 each** | 0 |

The change corrects **934 pixels and introduces three one-level differences**;
981 pixels change, all inside the partly visible photo at x=333..435, y=753..767.
It does not make that photo or CNN exact. The other partly visible ICC photo
retains **372 differences/max9**; the remaining six image regions are unchanged.
CNN's missing archived MP4 responses and source/replay gate remain open.

A newly completed shared production executable,
`3c6be545f32f9e495767cd91f5ea53c019603cf52d4f500f335260f6cedee909`,
receipt `20261116-062906-c6814bce` (C/literal V `-prod`/single C unit), now contains
the final CSS-only, allocation-free gradient fix by consumed source hashes.
Six fresh baseline captures repeat and match the corresponding prior diagnostics:
Vlang **1**, orbit underlay **0**, CNN **6,091**. Startup and all native guards
exit zero; selected source/shader/runtime/executable pins remain matched. This
is focused production confirmation of the gradient slice. The bundle lacks the
resolved-shadow and current mip fixes by source hash and cannot validate them.
Their managed rebuild requests remain coalesced; no duplicate production build
is requested or awaited. Frozen results supply no live-site, scripting,
scrolling or instruction-performance acceptance. Catalog-wide equality remains open.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-rounded-sampling-20261116/`.
Cleanup inventories **50 owned roots/4,754 files**, preserves and SHA-verifies
**1,199 evidence files/37,363,776 bytes**, and removes owned binaries,
intermediates, profiles, guards and locks. All three temporary canonical probes
are removed. The archive guard and lock are separately copied, verified and
removed; no owned scratch remains. Shared bundles and dependencies stay.

## Rounded profiled WebP uploads and native reuse, 2026-11-16

`6840391d5` extends the supported opaque, numerically sRGB-profiled VP8 path to
rounded power-of-two CPU uploads. The RGBA scaler now uses the legacy Skia
geometric-mean mip rule already established for byte planes. For the partly
visible train photo, 480×270→120×68 preserves the appropriate larger CPU mip
before resizing. Existing profile, source, opacity, transform and size bounds
remain. No existing reference, tolerance, shader or application UI changes.

Native-size upload history now follows the document, navigation, resource and
body digest across raster scopes; smaller CPU decodes retain their raster scope.
This matters when a native-size image appears in an earlier tile and its thumbnail
appears near the viewport bottom. The first candidate forgot that native upload
at the scope boundary: its complete **51-workload/102-capture** cohort repeats,
but regresses the existing sRGB-table edge by **371 pixels/max10**. That cohort
is rejected and retained. The final history correction restores the unchanged
reference. Unit checks cover CPU-scope separation, native reuse across scopes,
navigation isolation, larger-decode reuse, scratch lifetime and invalid targets.

An independent native Skia build with recorded legacy-mip configuration produces
**32,640 resized RGBA bytes**, all matching V exactly. Ten synthetic cases add
**540 exact bytes**, represented by independent hashes in the focused test.
All **400 native source/header/library/configuration/fixture/executable pins**
remain matched. Seven focused V functions pass with arena poisoning and 3 GiB
runtime guards. Their executables are:

| Check | Executable SHA-256 | Matched V witnesses |
| --- | --- | ---: |
| RGBA scaler | `bfe39daccd55b67495f3fa64c06bbb35a783f6c52e1d6c1d3462854448a11f76` | 66 |
| Upload history and lifetime | `130e7754ea66ea512b3c955bca4b6a5e103484c7382da59a9f75ce8eaef4554f` | 143 |
| Complete GPU control, one sample | `30415ebe7e7a20ec3335b5f6b7be9d2f9be7c60fce9c2f3d5300974278520b49` | 110 |
| Same GPU control, literal V `-prod` C build | `e0391b5cc7e4ef57f9242a0a6cdafa1b6eb05c38d2da5a5d14fb3e7eb8ab169d` | 110 |

The new rounded/clipped control captures a complete image and a second image
crossing the viewport bottom. Two fresh Brave processes reproduce it exactly
with source/body/tool/executable pins; their PNG also equals the preceding pair.
Its original decoded image bytes and strict reference are unchanged afterward.
Both ordinary and optimized GPU checks invoke decoding/drawing outside assertions
and externally verify the logged full-frame difference count of zero.
The first optimized compilation rejects a deprecated test-only `usize` spelling;
the final native call uses `uint`. The failed attempt remains recorded.

A forced four-sample diagnostic differs at **seven pixels, maximum error one**.
Its BGRA output, source and failed assertion are retained. It supplies no passing
four-sample parity claim. The permanent direct comparison is scoped to one sample;
the complete browser captures below also pass this new reference exactly.

Final C/O0/preallocated/no-GC browser
`5221336050ae2a5437b37ea8cf278aa6c953850cf42064b0bbe1070eb1cbd8d4`
completes **51 workloads/102 fresh captures**, plus startup. All pairs repeat;
all **49 other existing workload PNGs are unchanged**, and the new control is exact.
All **889 consumed V witnesses and 945 source/runtime pins** remain matched.
Startup, 102 native guards, driver, outer guard and guarded analysis exit zero.
Focused captures agree and record the corrected 120×68 RGB upload on CNN, plus
native-size reuse for all three sRGB-table placements.

| Scope | Previous differences | Final differences | Maximum channel error |
| --- | ---: | ---: | ---: |
| Complete CNN viewport | 5,160 | **4,788** | **9→1** |
| Partly visible profiled train photo | 372 | **0** | **9→0** |
| Existing sRGB-table control | 0 | **0** | 0 |
| New rounded-upload control | — | **0** | 0 |
| Vlang / GitHub / Hacker News / Lobsters / Wikipedia | 0 each | **0 each** | 0 |

All **372 changed pixels are corrected**, with **zero introduced differences**,
at x=588..690, y=753..767. CNN still fails strict equality at 4,788 one-level
pixels. Its source/replay failures, missing Reddit evidence, the forced-sample
diagnostic and other prior inexact controls keep full parity open.

Available production remains `3c6be545`, receipt `20261116-062906-c6814bce`, and
lacks this source, the preceding planar mip fix and the resolved-shadow fix by
consumed source hashes. Prior focused baseline captures remain valid; this older
bundle cannot validate the new source. The managed commit hook requests the
coalesced C/literal V `-prod`/single-unit rebuild; production validation is pending.
No duplicate production build is requested or awaited. Frozen checks establish
no live-site, scripting, scrolling or instruction-performance acceptance.
Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-profiled-rounded-20261116/`.
Cleanup inventories **83 owned roots/7,731 files**, preserves and SHA-verifies
**2,315 evidence files/55,206,570 bytes**, and removes owned binaries,
intermediates, profiles, guards and locks. All three temporary canonical probes
are removed. The archive guard and lock are separately copied, verified and
removed; no owned scratch remains. Shared bundles and dependencies stay.

## Native YUV sampler isolation, 2026-11-16

`d78d83dc3` adds two focused GPU regressions in
`ggshape/yuv_native_sampling_darwin_test.v`. Three complete 260×260 BGRA frames
match independent native Skia Graphite/Metal R8-plane draws exactly. They cover
256×144→130×73 and 320×180→245×138 near-half sampling, plus 640×360→200×113
full-plane sampling through original 1280×720 image coordinates. The source
patterns include rapidly varying luma/chroma and out-of-gamut conversion.
Twelve independent R8 channel hashes also pin two mip levels each for odd
13×9 and even 256×144 textures, including halfway byte averages. These are
component oracles; they do not establish Brave screenshot equality.

The native oracle uses the existing Skia archive revision
`29ed1e87a0a50f3d8347e988842d9d59e7573efa`, with static-library SHA-256
`179544f74bb6ebeecc6633e3dd55cf2129d14f0e05e28e8b13503a138f81a97c`.
Each R8 plane is uploaded without mips, then passed through `TextureFromImage`
with mipmaps required, forcing GPU generation. Wrapped plane textures supply a
Rec601-limited YUV image. Linear mip sampling, white sRGB BGRA8 output and a
single-sample draw supply the frame references. The byte oracle reads actual
Metal mip textures through a blit; it does not calculate the expected bytes
with Vox's algorithm. Two fresh native processes reproduce the frame hashes.
Native sources, commands, header/library pins and readbacks remain in local
evidence. No existing PNG reference or tolerance changes.

Seven distinct focused V test functions pass: the two new regressions, four
existing atlas checks and the existing mip check. The new tests also pass with
literal V `-prod`. Every runtime uses arena poisoning and a 3 GiB memory guard;
compiler buffers match all 167 selected V witnesses, and shader/executable pins
remain stable. The C/O0 and `-prod` new-test executable hashes are
`4d87aa2926b83ebd90dbd0ce52f9bef454c6fd3306b04b5367d0831815e39303`
and `9c9e30a9c95e9c8d9f8aa55eb3755c27bf47db9629e19ae75fda50d06f27b75b`.

The preceding isolation checks find exact native agreement for the 327,680
Rec601 palette pixels and for synthetic GPU R8 mips across two patterns and
256×144, 960×540 and 13×9 dimensions. The real Sullivan image's selected luma
levels 0–2 and chroma levels 0–1 are also byte-identical. This rules out the
tested mip-generation and conversion hypotheses, not all sampling behavior.
For Sullivan's 37,323-pixel interior, native Metal and native Dawn GPU oracles
each retain **1,836/max1** Brave differences. Vox's isolated full-viewport draw
retains **1,819/max1**, and differs from the complete native frame at 24 pixels.
These isolated draws have a different capture context from the homepage.
Enabling Dawn ShaderF16 produces 18,031/max2 interior differences; changing
the native sampler bias to -0.5 produces 13,315/max3. Neither is accepted.
A fresh, pinned Brave process confirms `GraphiteDawnMetal` on this host.

Two C/O0 browser prototypes each complete four workloads/eight fresh captures:
CNN, Vlang and the two YUV controls. Every pair repeats; Vlang and both controls
stay exact and unchanged. Both prototypes are rejected:

| Prototype | CNN differences | Corrected | Introduced |
| --- | ---: | ---: | ---: |
| Always draw uniform-sample YUV in its document tiles | 4,788→4,788 | 4 | 4 |
| Normalize limited-YUV coordinates in the fragment shader | 4,788→4,799 | 2 | 13 |

Their executables are
`4141d1627df743fb32d558261c8d9625e4acf4b3066abbc6ecc2d7fc6bd180c3`
and `1717c6f3d8e639bdadafcaa7a866f5e8dcd18df69581da7c74216decd457615f`.
Both retain 889 consumed V witnesses and stable input pins throughout their
cohorts (945/946 pins). Driver completion does not clear the pixel gate.
The browser implementation, both preparers and staged shaders are restored
before the regression commit. **No rendering fix is accepted in this slice;
CNN remains at 4,788 one-level differences.** Source/replay, Reddit and earlier
production-validation gates remain open. Available production is unchanged at
`3c6be545`; no manual production build or new production acceptance is claimed.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/yuv-matrix-20261116/`.
Cleanup inventories 128 owned roots/2,240 files and preserves and SHA-verifies
593 evidence files/31,159,021 bytes. Five temporary canonical probes are
preserved and removed. Owned binaries, intermediates, profiles, guards and
locks are deleted; the archive guard and lock are separately copied, verified
and removed. Shared production assets and dependencies remain.

## Preserve opaque planar-image draws, 2026-11-16

`6448185cc` preserves known image opacity in GG's paint classification. The
limited-range and full-range YUV shaders construct alpha one; their uploads now
carry that guarantee into draw ordering and the analytic renderer's opaque
interior fill. Previously every image was classified as potentially transparent.
Paint alpha and mask alpha still participate, and RGB uploads and restored layer
textures retain their existing conservative metadata. Both the native V and
Python preparers install the same field and paint change, repairing either file
independently. Samplers, decoded bytes, mip kernels and color matrices stay fixed.

Brave's saved picture records a device-space rounded clip, a canvas translate/
scale, and a draw at natural image size. The earlier direct-destination native
oracle did not preserve this operation order. Its 1,836-pixel result remains in
the prior evidence. Replaying the recorded order in native 1024×256 tiles spaced
254 rows apart makes Sullivan's 37,323-pixel interior exact against the original
Brave reference. The matching Vox component initially differs from that native
tile at 2,464 pixels; carrying opacity reduces the prototype residual to 190.
This isolation establishes the exercised rendering path. The unchanged original
Brave PNG supplies the browser acceptance comparison below.

Final C/O0/preallocated/no-GC executable
`5a36d84daffa4cc1b642d407ef60be984f3789baa728ad584c212f601700dd21`
completes **51 workloads/102 fresh captures** plus startup smoke. Every pair
repeats byte for byte and **all 50 non-CNN PNGs are unchanged** from the preceding
accepted 51-workload cohort. CNN improves **4,788→1,414**: **3,450 corrected,
76 introduced** pixels. Complete-viewport and introduced maximum channel errors
are both one. The remaining errors are retained; strict CNN equality is open.
The 890 consumed V witnesses, 948 input pins, executable and shader identities
remain stable throughout the cohort. Native guards, driver, outer guard and
analysis all exit zero.

Image interiors exclude four pixels at each edge:

| Region | Prior differences | Accepted differences |
| --- | ---: | ---: |
| Sullivan | 2,698 | 206 |
| Trump | 115 | 0 |
| Netanyahu | 383 | 0 |
| CNN logo | 230 | 1 |
| Ice cap | 27 | 6 |
| Peptides | 1,048 | 1,030 |

Ten distinct focused V test functions pass with arena poisoning and 3 GiB
runtime guards: the new rounded YUV oracle, two native sampling/mip checks,
four atlas checks, the byte-mip regression, the profiled RGB control and the
native preparer. The three native sampling/coverage functions also pass with
literal V `-prod`. GG checks retain 167 selected V witnesses; the native preparer
retains 19. The new complete 64×64 BGRA coverage reference comes from separate
Graphite/Metal R8 textures and GPU-generated mips, using a rounded clip before
translate/scale. Its SHA-256 is
`77a8d85e85d3c547e206571c84040fcbb3bad3873992d595419084da6d8f5199`;
the C/O0 and `-prod` test executables are
`3815662624c656e9b024b6314d37b1bbc5e54d1497b32da81f4225e5755cd6f8`
and `ef0bc95983a26ca899b506388ec4c42b6d1c9725990d29e8a4dfad11d8bf2902`.
New Python opacity-staging and existing YUV-staging checks pass. No existing
PNG reference or tolerance changes.

The initial opacity scan also promoted RGB uploads whose observed alpha bytes
were all 255. Its focused CNN result was 1,488, but it regressed the previously
exact profiled rounded-upload control to 35 differing pixels. That prototype,
its failed assertion and its captures remain retained. The accepted selection
uses the planar shader's opacity guarantee; the RGB control is exact again.
Plain-Brave layer probes omitted full-uBO cosmetics and do not qualify as new
references. Their source differences and unavailable snapshot attempts remain
local diagnostics.

A newly completed production bundle became available during this work:
`036bf13076fd03b266f2e1a2f7e355a7e8e5f9a4f3fe9832a86954378e54c08f`,
C/literal V `-prod`/single C unit. Its frozen inputs include the preceding rounded
WebP and resolved-shadow implementations, and lack this opacity change. Six
sites/twelve fresh captures reproduce the preceding accepted diagnostic PNGs
exactly: CNN 4,788 twice; Vlang, GitHub, Hacker News, Lobsters and Wikipedia zero
twice each. This confirms those preceding fixes in production. The managed
commit hook requests the new coalesced rebuild; this slice remains diagnostic
pending production. No duplicate manual build is requested. Full catalog parity,
CNN source/replay and Reddit gates remain open. No live-site, script-runtime,
scrolling or instruction-performance acceptance is claimed.

Local evidence is under
`docs/performance/vlang-gradients-20261114/raw/cnn-yuv-context-20261116/`.
Cleanup inventories 111 owned roots/6,069 files, preserving and SHA-verifying
1,392 evidence files/53,345,952 bytes. Two temporary canonical probes are preserved
and removed. Owned binaries, intermediates, profiles, guards and locks are deleted;
archive and final-verification guards are separately preserved and removed.
Shared production assets and native dependencies remain.

### Planar fragment-coordinate normalization, 2026-11-16

`3d3b3c6d2` delays limited-range YUV coordinate normalization until the fragment
shader, matching the native plane sampler's operation order. Vertex interpolation
retains natural-image coordinates; luma and atlas chroma use the resulting
normalized coordinates. RGB and full-range JPEG retain their prior path. Both
preparers repair each coordinate operation independently. The JPEG insertion
marker now includes its conversion statement, avoiding an ambiguous normalization
condition during partial staging repair; final staged shader bytes stay fixed.

A fresh matched source control reproduces CNN at **1,414** twice and retains
exact Vlang and both YUV controls. Candidate executable
`e0b0e34c63b83f2983f9d77045f53f187e8994be7f5680657389d1b08ed07adb`
(C/O0/preallocated/no-GC) completes **51 workloads/102 captures** with byte-identical
repeats and **50 other PNGs unchanged**. CNN improves **1,414→1,311**:
**105 corrected, two introduced** pixels, all errors at most one. Sullivan's
interior improves 206→105 and the logo 1→0; Trump/Netanyahu remain zero,
ice six and peptides 1,030. The 890 consumed V witnesses and 949 selected pins
stay stable. Driver, capture and memory guards exit zero.

The new full-frame regression decodes the frozen Sullivan WebP, pins its source
and luma bytes, and renders the recorded rounded clip and natural-image
transform at both 1024×768 and 1024×256. Independent native Graphite/Metal
R8-plane frame hashes are exact: the previous **194/190** differences become
**zero/zero**. The complete viewport hash is
`7f28b70276ba342b68d3a914b6c588a474e968dcedb223e628e0b43c0cfc04bb`;
the tile hash is `10ce2be37045e9278e4d6c0e2cb692f8be97862dc9f59344fa634f9fd3c88ed7`.
The unchanged control shader fails this regression as expected after passing
the decoder assertions. That failure and initial compiler diagnostics are retained.

Eleven distinct focused V functions pass under arena poisoning and 3 GiB runtime
guards: the new coordinate regression, two native sampling checks, four atlas
checks, byte-mip, profiled RGB, opaque rounded YUV and native staging. The new
coordinate function and two native sampling functions also pass with literal V
`-prod`. The two Python staging checks pass, including partial-coordinate repair.
Two browser build attempts failed on concurrent LibJS edits; those failures and
the separate fixes are retained. The final candidate builds successfully.
No original PNG reference or tolerance changes.

Production remains `036bf130` and does not contain this change. The managed hook
requests its coalesced rebuild; no duplicate build is queued. This is frozen-page
diagnostic evidence, with no live-site, scrolling or instruction-performance
claim. CNN equality, source/replay, Reddit and the catalog's other open controls
remain unresolved. Cropped readback surface dimensions remain a sampling lead.
Local raw evidence: `docs/performance/vlang-gradients-20261114/raw/cnn-yuv-fragment-20261116/`.
Cleanup inventories 81 owned roots/4,050 files, preserving and SHA-verifying
1,164 evidence files/35,941,633 bytes. The temporary canonical probe, binaries,
intermediates, profiles, guards and locks are removed; archive guard evidence is
separately preserved. Shared production assets and dependencies remain.

### Uniform planar draws in tile coordinates, 2026-11-16

`a56efe4fd` retains the owning document tile's raster space even when every tile
uses the same sample count. Previously uniform limited-range planar images used
a smaller cropped readback surface; its interpolation can differ from the full
tile. Mixed samples and JPEG already used tile routing. Uniform limited-range
draws retain their direct fallback when no usable grid exists. Failed tiled draws
remain atomic, preserving the backdrop before fallback. No sampler, decoder,
color matrix, reference, tolerance or resource-specific rendering rule changes.

C/O0/preallocated/no-GC diagnostic executable
`e2079a6008ecfee56405ee4b0a6e71c4ca723a00fbdc41c42253978907479480`
completes **51 workloads/102 captures** plus startup smoke. All pairs repeat
byte for byte, and **all 50 non-CNN PNGs remain unchanged** from the preceding
coordinate-normalization cohort. CNN improves **1,311→1,197**: **115 corrected,
one introduced**, with maximum channel error one. Sullivan's interior improves
105→0; Trump, Netanyahu and the logo stay exact. Ice retains six and peptides
1,030 interior differences. The 890 consumed V witnesses and 949 selected pins
remain stable. Native guards, driver, outer guard and analysis exit zero.

Four focused callback functions pass under arena poisoning and a 3 GiB guard
(executable `028ad3862b059eb1eeef84a4dfc99f4df47110c83c5751615dd6e659f149ae77`,
274 consumed V witnesses). They exercise uniform and mixed sample ownership,
full-range JPEG, native channel conversion, both tile seams, backdrop margins,
atomic rejection and direct fallback without a grid. The new test compares a
273×155 crop crossing the 254/255 publication seam against independently rendered
native R8-plane tiles. Its complete BGRA hash is
`a35a8597defe242feac2eb5ef0677e97b6286dfa3b18f450acd80cf4a260fdd2`.
The unchanged control implementation fails that assertion as expected; the
candidate matches exactly. The initial driver failure from a removed probe in
its pin list is retained, followed by corrected successful compile receipts.

An independent native Graphite/Metal render of the real 256×144 peptides planes,
recorded rounded clip and natural-image transform matches Vox's interior exactly
in both full-viewport and owning-tile targets. It retains the same 1,030 one-level
differences from the original Brave PNG. This narrows the remaining investigation
to the selected native sampling/decode setup rather than establishing equality.
The native diagnostic supplies no browser acceptance on its own.

Production remains `036bf130`; it cannot validate the newer source. The managed
hook requests a coalesced rebuild without a duplicate manual build. Catalog
parity, remaining CNN rendering and source/replay checks, Reddit and other open
controls remain unresolved. No live-site, scripting, scrolling or instruction
performance acceptance is claimed. Raw evidence is local under
`docs/performance/vlang-gradients-20261114/raw/cnn-yuv-tiles-20261116/` and
`docs/performance/vlang-gradients-20261114/raw/cnn-yuv-peptides-20261116/`.
Native alternatives remain retained: omitting mips yields 3,309 peptide interior
differences (maximum 29); nearest mip sampling yields 3,261 (maximum 28).
Neither clears the residual, and neither is applied to the renderer.
Cleanup inventories 22 tile-job roots/3,158 files and 13 native-diagnostic
roots/50 files. It preserves and SHA-verifies 1,021 tile evidence files
(22,601,986 bytes) and 43 native files (54,619,059 bytes). The temporary canonical
native probe, owned binaries, profiles, intermediates, guards and locks are
removed; archive guards are separately retained and removed. Shared production
assets and dependencies remain.

### CPU byte mips for native-size near-half atlases, 2026-11-16

`9331c0681` retains CPU byte-mip construction for native-size near-half planar
uploads. The atlas shader, plane bytes, color matrix and sampler stay fixed.
The renderer can now select CPU or GPU mip construction explicitly, carrying
that choice through owning tiles and direct fallback. Near-half full uploads
select CPU byte mips; stronger atlas minification retains GPU mip behavior.
The existing direct GG atlas API retains its GPU default. No site/resource hash
selects this behavior, and no original reference or tolerance changes.

An independent native Graphite/Metal `TextureFromYUVAPixmaps` upload builds CPU
mips before transfer. With the recorded rounded clip and natural-image transform,
it makes the real 256×144 peptides interior exact against the original Brave
PNG at both full-viewport and owning-tile sizes. The preceding wrapped R8 textures
with GPU-generated mips retain 1,030 one-level differences and match the old Vox
interior exactly. The new renderer matches both complete native CPU frames:
`4e7e3266040e010ab512d21555c1356ccd90160216e2b9384dd8bbd4717dc7e1`
and `40fdfe0389164a1caf140c27212d2b0c1eabcd4ce6961830aa838c3ef362494c`.
Its focused test also pins all 55,296 decoded Y/U/V bytes to
`dceb5bf634152414d8eb379359cb3b1a680cd5bd1b7bacb15153577f030ff4e3`.
The independent native source, headers, library identities, commands and frames
are retained locally. No native dependency is rebuilt or added.

Final C/O0/preallocated/no-GC diagnostic executable
`1ddba79fd798a0640478e1bc7c88544d8f80433c9a76a3a1ecf4474f2d8d0515`
completes **51 workloads/102 fresh captures** plus startup smoke. Every pair
repeats byte for byte; **all 50 non-CNN PNGs are unchanged** from the accepted
tile-coordinate cohort. CNN improves **1,197→94**, with **1,103 corrected and
zero introduced** pixels. Every remaining channel error is at most one.
All 891 consumed rendering/CSS/DOM/layout V witnesses and 951 selected pins stay
stable. Native capture guards, driver, outer guard and analyses exit zero.

Sullivan, Netanyahu and peptides are entirely exact. Trump and the logo interiors
remain exact, with 11 and 10 edge pixels respectively. The profiled ice image has
27 differences (six in its interior), and the cropped image at the bottom has
46. These 94 differences remain open; the native oracle does not waive them.

Fifteen distinct focused V functions pass under arena poisoning and 3 GiB runtime
guards: the new CPU-frame regression; two native GPU sampling/mip checks; five
callback tests; four existing atlas checks; fragment coordinates; opaque rounded
YUV; and the byte-mip regression. The new CPU-frame function also passes with
literal V `-prod` and C `-O2`. Its C/O0 and `-prod` executables are
`0a5d113377a27004a5d3d84bbbb5fe25a3c7194324a87420bdef549f889f3465`
and `701537742020107ec9d8273afb07e714e6863d07ac30bc53a6c1d0085394fc01`.
The five-function callback executable is
`1483ca2f9f7d776997c16c23a2e7a3546941b3c3404ca463817da6e2554d37b3`.
GG checks retain 168 selected V witnesses; callback checks retain 275. The new
callback compares the entire 134×77 native crop, then verifies CPU mip selection
through the no-grid fallback. Its BGRA crop hash is
`fcfdf9b06b11cbcbfbe9f8afe3a1447aba2349179c7fc2d1bee67eccb5d8f5e8`.
Two expected GPU-control assertion failures are logged; a fresh uniquely named
control retains its source and witness manifest and fails with unchanged pixels.

A newer completed production bundle is available:
`2ba33ee7775ab067a96f4b78107bc8fab855843bea554b6d52ffa05ebef26e66`,
C/literal V `-prod`/single C unit, receipt `20261116-095551-bf007c38`.
Its consumed paint classification/image helper matches the opaque implementation,
and its executable contains the complete normalized-coordinate shader bytes
(SHA-256 `7f18331dd0962f1116989367b04c4bbfc49925f989185c79e049b5ba94b664cc`).
Its PNG callback matches the preceding source, without `a56efe4fd` tile routing.
A separate fresh-process **51-workload/102-capture** production-binary check
matches every preceding coordinate-normalization diagnostic PNG exactly:
CNN **1,311 twice**, with GitHub, Hacker News, Lobsters, Wikipedia and Vlang exact.
All pairs repeat, and executable/native-library/reference/driver pins stay stable.
The diagnostic driver permits these recorded historical sources; the older
bundle does not validate current source it lacks. Its frozen manifest and
feature proof are retained. This confirms the opacity and coordinate result in
production, while tile routing and this CPU-mip slice await the coalesced managed
rebuild. No duplicate manual production build is requested.

Frozen-page checks establish no live-site, scripting, scrolling or instruction
performance acceptance. CNN source/replay checks, Reddit's missing evidence and
other previously inexact controls keep catalog parity open. Raw evidence is local:
`docs/performance/vlang-gradients-20261114/raw/cnn-peptides-followup-20261116/`.
Cleanup inventories 71 owned roots/6,362 files, preserving and SHA-verifying
2,073 evidence files/57,717,927 bytes. Both temporary canonical probes, owned
binaries, intermediates, profiles, guards and locks are removed. Archive guard
evidence is separately preserved and removed. Shared production bundles and
native dependencies remain.

### Single visible SVG background pictures, 2026-11-16

`a6edd14de` keeps fractional SVG layout separate from the rounded image recording
when CSS permits repetition but one recorded tile covers the complete snapped
clip. The renderer previously retained this distinction only for `no-repeat`.
The new selection is shared by playback, recording eligibility and MSAA bounds.
Actual multi-tile backgrounds retain their existing replay. The recording frame
must match the painted tile dimensions; a 104-pixel recording in a 103-pixel
painted tile retains the sampler fallback. Non-finite and empty repeat geometry
are rejected. No image decoder, color matrix, reference or tolerance changes.

The remaining logo/Trump edge errors came from their SVG video placeholder,
not the foreground YUV image. Exact browser callback captures reveal the loaded
foreground blends over that placeholder. Its `#f8f8f8` boundary had become 249
because a fractional SVG container was rounded before viewBox fitting. The new
path preserves the LayoutUnit container and applies the existing residual scale
to its independently rounded recording. The placeholder boundary becomes 248,
and all five complete untagged image rectangles now match the original Brave
PNG. Initial foreground-only native/GUI probes matched each other but did not
model the actual backdrop; those diagnostics remain retained and are not new
references.

Final C/O0/preallocated/no-GC executable
`da5ce96176a9a6d9bfa2e20bc44d3944ba58ce3b9a7963e52b4338e319252cfa`
completes **53 workloads/106 fresh captures** plus startup smoke. Every pair
repeats byte for byte; **all 50 existing non-CNN PNGs are unchanged** from the
accepted CPU-atlas-mip cohort. CNN improves **94→73**: **21 corrected, zero
introduced**, maximum channel error one. Sullivan, Trump, Netanyahu, the logo
and peptides are entirely exact. The remaining 73 pixels are 27 in the profiled
ice image and 46 in the cropped image at the bottom. All 891 consumed rendering/
CSS/DOM/layout witnesses and 955 selected pins stay stable. Native guards,
driver, outer guard and analyses exit zero.

The two new independent Brave controls use a single visible SVG tile with
fractional container/origin values. Both references repeat byte for byte in two
fresh private profiles, then are independently reproduced in two more fresh
processes each while pinning the installed Brave executable, framework Mach-O
files, active-version aliases, application version, fixture and capture script.
The installed version is `157.1.99.57`, sRGB, DPR 1, 1024×768, no author scripts.
Verified captures match the committed new references exactly; no old reference
is replaced. The flat control improves **490→0** pixels. The nonuniform control
improves **755→265**, with **490 corrected and zero introduced**; its unsupported
frame/destination mismatch remains an explicit strict-equality failure.

Fourteen focused V functions pass with arena poisoning and 3 GiB runtime guards:
six SVG recording/rounding functions (including the new containment and frame
mismatch regression), five recording/fallback functions and three fractional
background/MSAA functions. Their executables are
`6575a226ea5aec0a104752b96957fb30733919084d19bbdd615a7b1c41985512`,
`eed65be4ea73fe48a7d3a74dddae29bccbd1bc51ccc5e81a2123e15baa9d28e1`
and `16c1c6e85d4fd7cb5dff5a3e77871a45c1c8f5265fb78eca8fbb9f21c8a61d33`.
Each retains 275 selected V witnesses. The full screenshot cohort supplies the
pixel verification; the geometry tests alone do not establish conformance.

Earlier attempts remain retained. Raw floating-point containment selected no
new path and left CNN/control outputs unchanged. Comparing rounded areas without
checking recording dimensions fixed CNN but introduced 35 colored-control pixels
(up to 97 channel levels) in the 104/103 case; that prototype is rejected.
The accepted size guard restores that case's previous PNG region byte for byte.
A focused check caught a concurrent platform-font-metrics edit before runtime;
it was recompiled. A standalone layout probe hit the default 12 GiB compile
guard and was discarded; successful main-module focused checks keep the guard.
Diagnostic builds retain their keyword/JSON-import errors and a temporary JSON
metadata encoder failure. A scalar dump writer recovered the complete draw
inputs, and all capture-probe source is removed from the canonical checkout.
No failed or rejected attempt earns pixel/performance credit.

Production advanced while this work ran. Fresh captures on
`499d9907fe53c55f35882e060e602debb173b3fd8a8778df36c98652e1f03ec6`
reproduce the preceding tile-coordinate CNN result, 1,197 twice. The subsequently
completed bundle `7515422c0006a9451ea33a2d7d2f71f15e98cfb9865ef4aa27f4c50b82b7d4e4`
(C/literal V `-prod`/single C unit, receipt `20261116-114004-5bc27bfa`) contains
the CPU-atlas-mip implementation and the prior SVG replay. Six sites/twelve
fresh captures reproduce the accepted CPU-mip diagnostic PNGs exactly:
CNN **94 twice**, with Vlang, GitHub, Hacker News, Lobsters and Wikipedia zero
twice each. Executable/native-library/reference/driver pins stay stable.

That shared production build also captured the temporary, inactive draw-input
probe. Its callback and probe hashes match the retained diagnostic source; the
capture environment removes the probe variable, so it returns before dump I/O.
The production evidence applies to this pinned default environment and does not
establish a clean release build or validate the new SVG source. The probe is
removed before the feature commit; its managed hook requests the next clean,
coalesced rebuild. No duplicate manual production build is queued or awaited.
Frozen-page checks establish no live-site, scripting, scrolling or instruction
performance acceptance. CNN rendering/source/replay, missing Reddit evidence,
the new nonuniform fallback and prior inexact controls keep catalog parity open.
Local evidence: `docs/performance/vlang-gradients-20261114/raw/cnn-single-level-20261116/`.
Cleanup inventories 136 owned roots/7,849 files, preserving and SHA-verifying
1,764 evidence files/98,909,232 bytes. All four temporary canonical probe files,
owned binaries, intermediates, profiles, guards and locks are removed. Archive
guard evidence is separately retained and removed. Shared production bundles
and native dependencies remain.

### Rounded RGBA draws in owning tile coordinates, 2026-11-16

`fb71abe2d` extends the existing owning-tile planar readback to rounded RGBA
uploads. The callback renders each owning tile with its gutter and sample count,
then publishes only that tile's pixels. Failed tile draws remain atomic. Plain
rectangles, mixed-sample RGBA, missing geometry and unsupported grids preserve
their existing fallback. The generic helper retains the planar/JPEG dispatch;
no decoder, mip policy, shader, reference or tolerance changes.

For CNN's profiled 780×438 ice image, the actual CPU upload is 390×219. The same
upload and clip have 27 one-level differences in the 273×155 readback, zero in
the owning 1024×256 tile, and 22 in a full 1024×768 target. The permanent callback
regression pins its decoded source and original Brave crop, including rounded
coverage and white padding. It fails against the old callback and passes the
fix, alongside direct fallback and untouched mixed-grid rejection checks.

Final C/O0/preallocated/no-GC executable
`c78d2a91462b70d7696346d246e3aae628bf98b60f0b92047250e8a4304c4b23`
completes **53 workloads/106 fresh captures** plus startup smoke. Every pair
repeats and **all 52 non-CNN PNGs are unchanged**. CNN improves **73→46**:
**27 corrected, zero introduced**, maximum channel error one. The complete ice
rectangle is exact; the remaining errors are in the bottom clipped image.
All 892 consumed rendering/CSS/DOM/layout witnesses and 959 selected pins stay
matched, including selected compiler-buffer witnesses. All 107 native guards,
driver and outer guard exit zero. Eleven focused functions pass under arena
poisoning and 3 GiB guards: six tile/callback functions, one rounded RGBA upload,
two sampled-image and two floating-color functions.

A broader prototype changed unrounded controls: half-upload 18→8 (14 corrected,
4 introduced), native-first 24→29 (18 corrected, 23 introduced). It is rejected;
those outputs return byte for byte to their accepted baseline with the rounded
selection. That first full pass also detects a concurrent `main.v` edit and
cannot provide stable-input acceptance. Compilation failures for enum inference
and concurrent audit integration are retained; the audit correction was supplied
by the other work, with no edits to its files by this task. No failed attempt
supplies pixel or performance credit.

The latest completed production remains `7515422c`, confirming the preceding
CPU-mip result (CNN 94), with its previously documented inactive-probe limitation.
The shared managed build is already active and the normal commit hook requests
a coalesced rebuild; no duplicate manual production build is queued. The new
RGBA and preceding SVG changes await production validation. Frozen checks give
no live-site, script-runtime, scrolling or instruction acceptance. CNN source/
replay, missing Reddit evidence and prior inexact controls keep catalog parity
open. Local evidence:
`docs/performance/vlang-gradients-20261114/raw/cnn-rgb-tiles-20261116/`.

### Decoded image frames for CPU-resized planar uploads, 2026-11-16

`9b326517b` folds a CPU-resized YUV444 upload into its decoded image frame before
constructing the GPU image matrix. CNN's final cropped photo decodes 480×270 to
120×68. Retaining the original frame carried a rounded vertical scale through
the shader; using the decoded frame first clears its 46 one-level differences.
The mode-3 policy is shared, with no site, resource or coordinate exceptions.
Natural-image metadata retains its original positive/4096 limits. Other image
modes, CPU plane resizing, mip construction, color conversion and shaders stay
unchanged. Existing PNG references and tolerances are unchanged.

Independent Skia Graphite/Metal tests use the actual three 120×68 R8 planes,
linear sampling, device-space rounded clipping and sRGB BGRA8 targets. Recorded
render passes establish 4x MSAA in the viewport and both owning tiles. The old
natural-frame transform reproduces Vox's 46 visible errors. The decoded-frame
transform agrees with Brave's visible photo and with V/GG at **every byte of
three complete native frames**. Their stitched 107×41 callback crop, including
white padding and the ownership seam, has SHA-256
`496cc60bd21aeb50fe399f94de9b8feca5a7db9b3959468533d17197267552f5`.
The packed CPU source is independently pinned; no new browser reference is added.

The permanent regression decodes the original WebP, verifies the complete upload,
then checks the real callback against that native crop. The old implementation
fails with crop hash `f2f12c2043c191370b45d9acbe954d8797b9ab7f2bbc2875f35118ccf9b19bbc`.
Seven focused V functions pass with arena poisoning and 3 GiB runtime guards,
including unchanged planar/JPEG/RGBA dispatch, fallback and rejection tests.
Six invalid natural-dimension cases leave sentinel destinations untouched.
The final focused executable is
`e19423a54b8c5132d38bc437674d560b40c2765566a77381429c8997f3a3d8b0`,
with 276 consumed V witnesses. Five unchanged GG functions passed earlier in this
same task. A concurrent raster-arena edit is detected before an earlier focused
execution; that executable is recompiled. The original negative run, all
intermediate cohorts and boundary-validation follow-up remain retained.

Final C/O0/preallocated/no-GC browser executable
`be35784f4597343841094f7bc40607a1387888f849b145bc26a03681ba867c84`
completes **53 workloads/106 fresh captures** plus startup smoke. Every pair
repeats byte for byte; **all 52 non-CNN PNGs are unchanged** from the accepted
rounded-RGBA cohort. CNN improves **46→0**, **46 corrected, zero introduced**.
CNN, GitHub, Hacker News, Lobsters, Wikipedia and Vlang are zero twice each.
All 892 selected compiled rendering/CSS/DOM/layout witnesses and 960 selected
pins stay matched. All 107 native guards, driver, outer guard and analysis exit
zero. Prior inexact diagnostic controls remain inexact at their existing counts.
These frozen results establish no live-site, scripting, scrolling or instruction
acceptance. CNN's historical source/replay verification remains open.

A fresh anonymous headless Brave availability check requests
`https://old.reddit.com/r/programming/` in an empty private profile, without
ambient proxies. It redirects to `/login/?reason=lor2&dest=…` and displays a
network-security block, with no posts and `logged_in=false`. Browser/tool inputs
stay pinned; browser and 3 GiB guard exit zero. Successful capture of that page
provides no programming-page coverage. The historical account-bearing fixture
is still absent. Earlier HTTP 403 evidence is retained; this observation records
the current redirect and document rather than asserting an unmeasured HTTP code.

The latest completed production remains `7515422c`, with its preceding CNN-94
result and documented inactive-probe limitation. The shared worker is already
active; both implementation commits request the normal coalesced C/literal
V `-prod` rebuild. No duplicate manual build is queued or awaited. New production
validation remains pending. The rounded-RGBA documentation was picked up by
concurrent commit `50f3dd30c` during a HEAD race; no shared history was rewritten.
This report records the final feature in a separate documentation commit.

Local evidence:
`docs/performance/vlang-gradients-20261114/raw/cnn-rgb-tiles-20261116/`.
Cleanup inventories **107 owned roots/12,930 files**, preserves and SHA-verifies
**4,307 evidence files/139,028,148 bytes**, and removes owned binaries,
intermediates, profiles, guards and locks. Both temporary canonical probes are
removed. The archive guard and lock are separately preserved, verified and
removed; no owned `Build/rgb-tiles-*` scratch remains. Shared production bundles
and native dependencies stay.

### Preserve recorded image decode preparation, 2026-11-16

`597984bc6` makes the reference's image-decode preparation explicit through the
full-uBO oracle, source capture and frozen replay. The recent `img.decode()`
readiness check changes the shared image upload cache and sampled pixels. A
fixture captured before that preparation cannot silently inherit it. Direct
oracle/source captures keep the existing `visible-image-decode` default. Frozen
comparisons select their source's recorded policy; older receipts preserve
`load-and-paint`. Loaded-font/resource audits, paint checkpoints and consecutive
identical PNG requirements remain. New source manifests record the preparation.
Contradictory source or replay metadata fails before qualification. Follow-up
`a9e6df6cf` also validates the source's separate pixel-reference receipt.
No rendering implementation, PNG reference, tolerance or filter snapshot changes.

The independent reference audit uses installed **Brave 157.1.99.57**, original-
origin sealed replay, sRGB, 1024×768 at scale 1, five seconds of settling, fresh
private profiles/empty HTTP caches and bypassed service workers. OS caches are
retained. Full uBlock Origin **1.75.0** is restored from its release package;
all **59 retained vendor files** agree exactly, including the relocated assets
manifest. The release ZIP's SHA-256 is
`393cf95709d1074d4022970e9014e434395c53a822387f1e25f43be97cf4b582`.
Browser/framework/helper, oracle, extension, checker, list and fixture inputs
stay pinned. No proxy request is forwarded to the live network.

| Observation | Differences from retained replay PNG | Fresh-process repeat |
| --- | ---: | ---: |
| CNN, explicit visible-image decoding | 31,766 | 0 |
| CNN, preserved load/paint preparation | **0** | **0** |
| Lobsters, preserved preparation, first process | 0 | — |
| Lobsters, preserved preparation, second process | 101 | **101** |

Both CNN preparations pass full-uBO page/filter audits: 105 checks each, six
blocked and 99 allowed, with zero decision disagreements and matching cosmetics,
procedural filters and scriptlet selections. Preserved CNN references match the
prior `be35784f` diagnostic Vox PNG exactly. All **960 prior selected rendering/
resource input hashes** still match the checkout. This is reference compatibility
with the retained Vox capture; no new Vox process or production result is claimed.
The original live CNN PNG still differs by **107,289 pixels**. Its historical
source/replay gate remains open; changing preparation earns no engine or
performance credit.

Each Lobsters process is stable across its consecutive PNGs, with loaded fonts,
identical text, identical element rectangles and identical image inventories.
Across fresh processes, 101 pixels differ within x=68..670, y=75..253, maximum
channel error 13. Both full-uBO audits pass all 69 checks with zero disagreements
and matching cosmetics/procedural/scriptlet selections. The first reference
matches the retained PNG, while the second differs at those same 101 pixels.
This reference-repeat failure invalidates new acceptance. Both observations and
the prior exact diagnostic result are retained; no retry is excluded or replaces
the reference.

**35 JavaScript and 35 Python tests pass** under 3 GiB guards. Coverage includes
non-mutating readiness, explicit decoding and failures, source capture forwarding,
sealed policy provenance, mismatched receipts/overrides, stable frames and cache
warmup. An unchanged catalog test initially fails because `bd5d3f9bd` replaced
Reddit with ChatGPT but left the test and fixture coverage behind. Separate
`389327728` aligns the test with the existing registration and adds an explicit
missing-archive status for ChatGPT, without asserting a capture or HTTP outcome.
Earlier suite/setup failures remain retained. The registry change does not
supply Reddit or ChatGPT page coverage.

The latest published production is still `7515422c`; it predates the three latest
rendering fixes. Receipt `20261116-125455-46077f6a` completed successfully but was
superseded while a prior comparison held the bundle reader lease. The following
`20261116-132205-1611d6ef` build correctly failed its input guard when this task
changed `brave_parity.mjs`. The shared worker is active with coalesced commit
requests; no duplicate manual production build is queued or awaited. This audit
launches only Brave and holds no Vox bundle reader lease. Production confirmation,
Reddit access, historical CNN source/replay and current Lobsters repeatability
remain open.

Local evidence:
`docs/performance/vlang-gradients-20261114/raw/cnn-replay-refresh-20261116/`.
Cleanup inventories **33 owned roots/786 files**, preserves and SHA-verifies
**100 evidence files/8,356,471 bytes**, and removes the downloaded extension,
checker binary, intermediates, replay state, guards and locks from `Build/`.
The archive guard/lock are separately retained, verified and removed. No owned
`Build/cnn-replay-refresh*` scratch remains; shared bundles/dependencies stay.

### Lobsters raster history and completed browser selection, 2026-11-16

The 101 differing Lobsters pixels are **54 rounded tag/background pixels and
47 avatar/anchor-fringe pixels**, within the first 1024×256 raster tile. This
corrects the earlier working hypothesis about text glyphs: the changed pixels
are pale rounded edges and image samples. The maximum channel error is 13;
text, rectangles and resource bodies remain unchanged. Three avatars are
involved, including a JPEG response served with a PNG name/type. Their body
bytes remain pinned.

Four alternating pairs use the same sealed original-origin replay, recorded
load/paint preparation, full uBlock Origin 1.75.0 and installed Brave
157.1.99.57. Each capture launches a fresh private process. The release ZIP and
all 59 retained vendor files match the preceding audit. Source/reference,
browser/framework/helper, extension, checker and list identities stay unchanged.
No reference, tolerance, page bytes or engine implementation changes.

| Pair | Brave raster control | Differences from historical PNG, in capture order | Cross-process repeat |
| --- | --- | --- | ---: |
| A | Default | 101, 0 | 101 |
| B | Partial raster disabled | 0, 0 | 0 |
| C | Default | 0, 0 | 0 |
| D | Partial raster disabled | 0, 0 | 0 |

All eight full-uBO audits pass. All eight separate post-capture traces complete
without errors and retain the captured PNG. Tile snapshots confirm the first
tile's 1024×256 extent and origin (0,0). The diagnostic flag is Chromium's
[`--disable-partial-raster`](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/third_party/blink/common/switches.cc).
These observations support a raster-history hypothesis; they do not establish
the exact MSAA configuration or clear default-path repeatability. Every attempt
is retained. Disabled-partial-raster controls supply no default conformance or
performance acceptance.

Four fresh Vox captures on published **`7515422c`**, in two guarded pairs, match
the unchanged Lobsters reference exactly. Native audits, startup/capture guards
and outer guards exit zero; each pair repeats byte for byte. The second pair
also exercises automatic completed-browser selection in the canonical command.
This is current baseline evidence for Lobsters. That older browser does not
contain the latest CNN rendering fixes and cannot validate them.

`ef02df435` promotes the existing archived-site driver into
`tools/check_archived_site_pixels.py` and leases the actual selected executable.
`5bd532ff2` makes discovery and artifact leasing atomic: it checks the newest
available completed artifact under its shared artifact lock, verifies its hash,
and otherwise uses the published bundle under its publication lock. Removed,
busy, failed, superseded or malformed staging candidates cannot be launched.
Explicit stale staging paths fail. Published receipts and compiled source
witnesses remain mandatory for production claims. All **18 lease/selection
tests pass** under a 3 GiB guard; the integrated command passes two fresh
Lobsters captures. No application bundle or canonical tool is copied into
measurement scratch.

Example (unique output, existing completed browser, unchanged references):

```sh
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/archive-pixels-UNIQUE.lock \
  --report Build/archive-pixels-UNIQUE.json -- \
  python3 tools/check_archived_site_pixels.py \
    --output Build/archive-pixels-UNIQUE lobsters
```

Production confirmation of the latest CNN fixes remains pending. Completed
staging receipts `20261116-134046-b115eb01` (`544de6b5`) and
`20261116-141326-d95b5aa4` (`3edf3c34`) were superseded before pinning. The first
launch attempt fails before measurement (outer exit 1); the later bounded
discovery run finds only the older published browser. Neither earns validation
credit. Build `20261116-143822-6dccd969` exits 1 because
`tools/buildtools/gg_patches.json` changed after its input inventory. The managed
worker receives coalesced commit requests; no duplicate manual build is queued.

An out-of-space error interrupts one analysis command. Removing this job's
downloaded extension and checker recovers scratch; their recorded identities
and all completed observations remain. The canonical 12-hour prune reports
`Operation not permitted` for an unrelated old BBC directory; no manual deletion
or permission bypass follows. These diagnostics are retained too.

Local evidence:
`docs/performance/vlang-gradients-20261114/raw/lobsters-repeat-20261116/`.
Cleanup inventories **35 owned roots/827 files**, preserves and SHA-verifies
**228 evidence files/17,034,147 bytes**, and removes this job's outputs,
profiles, replay keys, locks and guards. The archive guard and lock are separately
preserved, verified and removed; no owned `Build/lobsters-repeat*` scratch remains.
The temporary diagnostic wrapper is retained as text and removed from the
canonical diagnostic directory. Shared bundles and production state remain.
Catalog acceptance still requires stable default Brave references, the missing
Reddit workload, CNN's historical source/replay gate and production confirmation.

### Recovered Reddit HTML and filled marker coverage, 2026-11-16

The default Vox page cache still contains the older `/r/programming/` source:
**137,106 bytes**, SHA-256
`4107cafa0e130f6f604ee2763c575669748a8ff21269d39b4a85cddb1d23fa40`.
Removing its 17 script elements and inserting the documented base URL reproduces
the **117,609-byte** historical derivative exactly, SHA-256
`a432e6846a949c02957b4e880300e588c1e0b4829276daee44d4c9ae100a7e90`.
Both agree with the [2026-11-03 report](OLD_REDDIT_PROGRAMMING_RECHECK.md).
The source, derivative and account-bearing captures remain local in a mode-0700
evidence directory, excluded from Git. No browser session or cookie jar is imported.

The retained cache supplies 23 resource responses. All 96 missing static-asset
fetches return 200, yielding a sealed **120-response candidate**, including the
document. Both browsers replay these same pinned bytes at the original HTTPS
origin through a private certificate/proxy, with no live fallback. This restores
a runnable older page; it does **not** certify the historical sealed resource
cache or restore the separate 2026-11-04 source. A scan of 746 cached page bodies
(288,714,643 bytes) finds neither documented hash of that newer source/derivative.
Its historical 2,046-pixel wrapping difference remains unverified.

Installed Brave **157.1.99.57**, full uBlock Origin **1.75.0** and all 59 retained
vendor files stay pinned. Each browser has fresh private profiles/HTTP caches,
1024×768 at scale 1 and five seconds of settling. Replay preserves load/paint
preparation; OS caches remain. Each cohort follows Brave/Vox/Vox/Brave order.
All four full-uBO observations pass **39 checks**, one blocked and 38 allowed,
with zero disagreements and matching cosmetics, procedural filters and scriptlets.
Native audits retain the original URL, `programming` title, complete readiness,
viewport and all 25 source post IDs in order. Browser and guard exits are zero.

| Browser | Differences from that cohort's unchanged Brave PNG, in capture order | Fresh-process repeat |
| --- | --- | ---: |
| Published Vox `7515422c` | 18, 18 | 0 |
| Marker-fix diagnostic Vox `9912b0a8` | **6, 6** | **0** |
| Brave, before the fix | 0, 0 | 0 |
| Brave, after the fix | 0, 0 | 0 |

Twelve changed pixels belong to a filled disc marker; six belong to the rounded
subscribe button. `57c86c2f7` sends filled ellipses through the document shape
rasterizer, retaining the owning tile's coverage and normal transform. Unsupported
geometry keeps the existing fallback. Two focused functions pass under a 3 GiB
runtime guard. The raster callback agrees with independent Brave coverage exactly.
The new public marker control improves **92→0** in both captures. The complete
**54-workload/108-capture** check repeats byte for byte, with **all 53 prior PNGs
unchanged**, including CNN at zero. Parsed source hashes prove that the fresh
diagnostic executable contains the implementation. Existing PNGs and tolerances
are unchanged; these are pixel results, with no instruction/FPS credit.

`8a324ac63` retains a public diagnostic for the remaining six pixels. Its original
Reddit UI sprite is SHA-256
`3151728340f566d1400cd9437ae64e8d95583d066712fa1d7c0718b8d10f5527`.
An inline button and an SVG curve reproduce the page's tile context; the complete
button region agrees with the recovered-page Brave reference. Two fresh references
agree, SHA-256
`ee25d9a3d176ac384b1406d886d48e690c281d2385db56efc2f1384f1e63c632`.
Fresh diagnostic Vox captures retain six differences, maximum channel error 9.
Initial block-only and curve-free reductions have different corner coverage;
their observations remain retained and do not replace the final reference.

A sample-aware image-mask counterfactual retains all six differences while
reducing maximum error 9→2. Standalone GPU pattern experiments also fail exact
equality; later variants still fail at a one-level blue-channel difference in
the first checked corner. Grouped/separate passes, wrapped texels, repeat sampling
and [SkSL half-color precision](https://skia.googlesource.com/skia/+/refs/heads/main/src/sksl/sksl_graphite_frag.sksl)
are investigated separately. The first pattern test exceeds a small-image API's
supported dimensions; a later shader fails compilation on an incorrect uniform
name. These failures and corrected diagnostics are retained. None supplies an
accepted button fix or establishes the exact cause. All experimental runtime and
staging changes are reverted; only the verified marker fix and public fixture stay.

`34a4c0e96` also fixes a concrete production build failure: a generated adapter
from the rejected MSAA experiment references a removed `GpuContext` field.
Staging removes the orphan unless the actual GG source supplies that module.
Both focused staging functions pass, and canonical staging removes the orphan.
Completed production `98f13265` is subsequently superseded before pinning; the
published bundle remains `7515422c`. Managed commit requests stay coalesced;
no duplicate manual production build is queued. This older published executable
cannot validate the latest CNN or marker code.

Local evidence: `docs/performance/reddit-recovery-20261116/`.
Accepted cohort source/resource/browser pins, commands, parsed-source receipts,
PNGs, audits and actual guard exits remain local, alongside failed diagnostic
logs and source snapshots. Cleanup inventories **136 owned roots/4,787 files**,
preserves and SHA-verifies **1,644 evidence files/28,767,537 bytes**, and removes
owned build outputs, binaries, profiles, replay keys and locks. The archive guard
and lock are separately preserved, verified and removed. No owned
`Build/reddit-recovery*` scratch remains. Temporary probes and rejected runtime
sources are removed; canonical GG staging is restored to the committed code.
Production confirmation, the newer Reddit fixture, default Brave Lobsters
repeatability and CNN's historical source/replay gate remain open.

### Repeated Reddit sprite backgrounds and adjacent borders, 2026-11-16

`5b52ceaab` fixes the six remaining subscribe-button pixels on the recovered
older Reddit page. Brave's CDP `LayerTree.snapshotCommandLog` records an outer
rounded clip at (719,186), size 35×16, radius 3; a white rectangle and repeated
image shader within it; and a separate 1px border centered at
(719.5,186.5), size 34×15, radius 2.5. The diagnostic capture still matches the
unchanged reference byte for byte at the pixel level. The neighboring SVG curve
requires the tile's four-sample pass.

The native painter previously resolved an image clip before drawing the border.
The replacement retains the repeated image shader, clipped background and border
in one pass, using the existing owning-tile transfer and sample selection. It
also derives image coordinates from the analytic geometry's final device
position: its antialiasing outset otherwise moves texture sampling near the
sprite's transparent seam. A uniform selects this coordinate rule only for the
new repeated-background path. The implementation currently accepts unscaled,
straight RGBA, repetition in both axes, an opaque paired background/border,
translation-only placement and a 1x native readback; unsupported cases retain
their existing painter. Native code transfers the backdrop; V owns composition.

An earlier global coordinate correction is retained as a rejected cohort. It
changed CNN by 17 pixels, GitHub by 6, Vlang by 8, the forced profiled-WebP rounded
control by 2 and the elliptical-avatar control by 3. The scoped final candidate
restores every prior PNG. Neither references nor tolerances were changed to
accept that experiment.

Final diagnostic executable SHA-256:
`3aa13d5d7ed892b2662889e87aab5eb7a938c4942a23c044baf0f7cf6b59e7bf`.
The C diagnostic compile, browser launches and checks exit 0 under the memory
guards. Native, shader and feature input hashes agree before/after compilation;
68 consumed GG/feature V buffers match the compiler's manifest. These are pixel
checks on an unoptimized diagnostic executable, with no performance claim.

- The recovered 2026-11-01 source and script-free derivative retain the hashes
  documented above. Its reconstructed 120-response archive is replayed offline
  at the original origin. Two fresh full-uBO Brave captures and two fresh Vox
  captures agree exactly. Each oracle checks 39 requests: 1 blocked, 38 allowed,
  zero decision mismatches and zero oracle disagreements. Content audits retain
  all 25 post identities in order. Private page markup and captures remain local.
- `rounded-repeated-sprite-border` moves from diagnostic to conformance with
  unchanged reference SHA-256
  `ee25d9a3d176ac384b1406d886d48e690c281d2385db56efc2f1384f1e63c632`.
  Two fresh Brave captures and two fresh Vox captures are exact.
- The curve-free `rounded-repeated-sprite-border-single-sample` independently
  checks the ordinary one-sample pass. Two fresh Brave references agree at
  `4b2bb5e844b255b99684a82257fdc67207dc926a955d0604937a6daf2d1f7b44`;
  two fresh Vox captures are exact.
- The 55-workload broad check plus the single-sample companion gives 56 workloads
  and 112 fresh Vox captures. Every pair repeats byte for byte; all 54 prior
  workload PNGs remain pixel-identical. All six available catalog archives
  remain exact. Existing nonzero diagnostic controls retain their prior results.
- Ten focused V functions pass: three repeat/background GPU tests, two native
  callback tests and five existing rounded-image tests. The callbacks compare
  the fixed Brave crop in the first tile, across its gutter and in a lower tile,
  and reject an invalid stride before touching pixels. Runtime guards use 3 GiB.

Commands, counters, exits, source proofs, failed attempts and PNGs are retained
locally in `docs/performance/sprite-paint-20261116/`; job directories, generated
C, executables, guards and locks are removed from `Build/` after preservation.
The initial C declaration mismatch and a disk-full interruption are retained;
no failed attempt is counted as acceptance.

The latest published production bundle remains `7515422c`, which predates these
fixes. The managed post-commit rebuild is coalesced with the shared worker; no
manual production build is queued. Production confirmation remains pending.
The recovered page still does not supply the missing 2026-11-04 Reddit catalog
workload or its historical resource cohort. Lobsters' fresh-Brave repeat failure
and CNN's historical source/replay mismatch also remain open.

### Published production confirmation and Lobsters sample history, 2026-11-16

The shared worker has published a completed production executable,
`bbd4703576665b62c43c763fa6e75c767ec867b4e33b8b7595a7dbcca231a208`,
from receipt `20261116-164214-b768c752`. Its receipt records literal V `-prod`
and one C unit. No manual or duplicate production build was requested.

The strict current-checkout invocation correctly stops before capture because
another session has edited `images/png_sampling_darwin.v` with a diagnostic probe.
That failed attempt is retained, and the foreign edit is preserved. The changes
were later committed as `12fc9e48b`; that newer implementation is not validated
by this artifact. The following
artifact-baseline invocation uses the driver's `--diagnostic` mode with the
published executable explicitly selected. It establishes the named compiled
artifact's rendering, not that the mutable checkout has been built or tested.
The usual executable/native-library leases, original fixtures/references,
resource/readiness checks, fresh profiles and memory guards stay enabled.

Separate provenance checks compare 187 consumed V buffers in `gg`, `ggshape`,
`images`, `imageraster`, `yuv`, `chromium`, `media`, `browsernet` and
`browsersettings` with the accepted diagnostic executable `3aa13d5d`. All match;
layout source buffers also have no differences. Eight selected feature/native/staging
inputs match the production's frozen source manifest. Fifteen embedded Metal
shader resources match the accepted bytes, extracted from both byte arrays and
C string literals in generated C whose full SHA-256 is bound by the production
receipt. Other globbed resources were not resolved by this extraction and are recorded
separately; no embedded-byte identity claim is made for them. The entire
browser source sets are not identical; no complete-checkout equivalence is
claimed.

All **56 workloads/112 fresh production captures** repeat byte for byte, and
all 56 decoded PNGs are identical to the accepted diagnostic outputs. The six
available catalog archives—CNN, GitHub, Hacker News, Lobsters, Wikipedia and
Vlang—are **zero pixels twice each**. Both public repeated-sprite controls are
exact. Known nonzero diagnostic controls keep every prior result. The outer
and browser guards exit 0. On the same production executable, two fresh captures
of the recovered older Reddit fixture agree exactly with two fresh full-uBO
Brave references. The 120-response reconstructed archive, original-origin sealed
replay, 25-post content audit and 39-request filter audits remain intact. This
confirms the recorded fixes in production; it does not restore the newer missing
Reddit fixture or its historical resource cohort.

For Lobsters, `1e60a660e` adds the optional `--post-capture-paint-dir` diagnostic,
which runs only
after the normal full-uBO reference has been completed and saved. It enables
`LayerTree`, waits for two animation frames, saves a separate PNG, snapshots
painted content layers, collects command logs and releases every snapshot.
Stale layer events, unsupported commands, missing logs, changed viewport or a
changed reference invalidate the diagnostic. Existing output directories are
never overwritten. The saved reference is never replaced. **57 related
JavaScript tests pass**, including error cleanup and unchanged default reference
preparation.

The predeclared experiment uses eight alternating pairs of fresh Brave
157.1.99.57 processes: default raster policy and `--disable-partial-raster`.
Both use the sealed Lobsters archive, full uBO 1.75.0, identical repository list
bytes, load/paint image preparation, empty HTTP caches, bypassed service workers,
1024×768 at scale 1, sRGB and five seconds of settling. OS caches remain.
Executable/framework, extension, checker, fixture, reference, list and harness
identities remain pinned. The release ZIP and all 59 vendor files verify.

| Pair | Default Brave differences | Partial-raster-disabled differences |
| --- | ---: | ---: |
| 1 | 0 | 0 |
| 2 | 0 | 0 |
| 3 | 101 | 0 |
| 4 | 101 | 0 |
| 5 | 101 | 0 |
| 6 | 0 | 0 |
| 7 | 101 | 0 |
| 8 | 101 | 0 |

All 16 full-uBO audits pass 69 request checks with zero decision mismatches or
oracle disagreements. Each capture is stable across the reference's consecutive
PNGs. **All five failing default frames change to the historical reference after
paint instrumentation starts.** The original failures remain unchanged on disk.
Thus an instrumented later screenshot cannot certify the earlier default frame.
All 16 later snapshots contain 755 commands in a 1024×1783 content layer.
Replacing only process-local image `uniqueID` values with first-encounter
ordinals, preserving reuse identity, makes the recorded command lists identical
(SHA-256 `460766b80b28aaaefccdc7107d239be1c0bf1912b3fb3b6d3041e27a5aacffba`).
CDP omits opaque shader and text-blob contents, and the logs describe the later
frame; they are not a record of the original failing partial redraw.

An independent focused GPU diagnostic replays the five tag background/border
pairs from those commands and three pinned avatar sources at their actual tile
coordinates. The JPEG uses its retained YUV planes and fractional RGB. At every
one of the **101 differing pixels**, sample count 1 predicts the failed Brave
value and sample count 4 predicts the historical value, with zero exceptions:
54 tag/background pixels and 47 avatar pixels. This strengthens the raster-history
explanation to exact sample-coverage agreement. It does not directly observe
Brave's GPU sample-count flag. Vox's full-paint output matches the stable reference;
changing it to match the failing one-sample state would regress that output.

The default Brave repeatability gate remains open, and disabled-partial-raster
or post-instrumentation captures earn no default-path or performance acceptance.
No page/reference bytes or tolerance changed. CNN's historical source/replay
mismatch and the newer missing Reddit fixture also remain open. Commands, source
proofs, successful and failed attempts, logs, counters and PNGs remain local in
`docs/performance/lobsters-paint-20261116/`; owned job outputs and the temporary
GPU probe are removed after preservation.

Cleanup inventories 37 owned roots/4,548 files, preserves and SHA-verifies
1,463 evidence files/42,554,486 bytes, and removes owned executables, generated
C, profiles, guards, locks and the temporary GPU probe. Shared bundles and
dependencies remain.


### Uniform PNG scales, decoded-frame history and elliptical geometry, 2026-11-16

The completed production artifacts available at the start of this follow-up
still reject non-identity PNG scales before calling the geometry helper from
`12fc9e48b`. The newest frozen generated C confirms that early return. A bounded
C diagnostic build is therefore required to exercise the newer implementation;
no additional manual production build is queued. Commits request the managed
production rebuild. The initial diagnostic reproduces all 56 prior accepted PNGs in 112 fresh captures.

The new public `uniform-scaled-png` control draws one 40×40 PNG at 9×20 and
18×40, both directly and through uniform half/double CSS scales. A separate SVG
curve requires the upper tile's multisampled pass; the lower tile has no such
trigger. Two fresh official Brave captures agree exactly at 1024×768, scale 1,
with a five-second settle. Its PNG is promoted unchanged from diagnostics to
`expected/`: SHA-256
`09bec91dbbf65b709f7e043be50b4b86b3e8d3c0bcb397d449c0ebc6306333e1`.

The published baseline differs by **1,412 pixels** twice. Uniform scale folding
alone reduces this to **318**. Testing an ellipse only as a standalone clip
incorrectly forces a shared multisampled tile: the bitmap's full rectangle can
absorb its own rounded clip. Fixing that planning decision reduces the result
to **270**. SVGs, object-fit cropping, ancestor clips and rotated, reflected or
skewed transforms retain conservative selection; independent paths still force
multisampling.
The planning hunk is already present in shared commit `8641a3868`.

`40d8c41ed` completes the fix. Two remaining details matter together. For a fully
clipped elliptical image in a single-sample tile, the GPU now uses the destination rectangle as geometry,
with texture sampling mapped back to the upload. This preserves interpolation
when the analytic rrect expands its antialiasing vertices. Separately, a larger
PNG request retains an additional upload instead of replacing the first usable
decoded frame. Later small draws keep their earlier frame rather than selecting
different GPU mip levels from the enlarged upload. Existing resource and
compositor scope keys and larger-first reuse remain intact. A broader shader
coordinate experiment leaves one pixel in the isolated regression and is
retained as rejected evidence; its staging change is removed.

The final diagnostic executable is
`fd57fb51b25c8da9215f5c65271d10253352fdbfec02bbbcdacd67e807612022`.
It makes the complete new fixture **zero pixels twice**. Thirty focused V
functions pass: 22 tile-planning tests, three PNG cache/ownership tests, two uniform-geometry tests, two unchanged sampled-image
GPU tests, and one GPU regression covering both ellipse sizes and both sample
counts. All compiles and actual test executions use the required
memory guards. Two failed compiles caused by a concurrently changing native
callback declaration remain in the local evidence; final builds and tests exit
0 after that interface is consistent.

The final **57 workloads/114 fresh captures** repeat exactly. Every one of the
56 prior PNGs is byte-identical to its earlier accepted capture, including
previously inexact controls whose reference counts remain unchanged. The six
available frozen catalog archives are exact twice each. Two additional fresh
captures of the recovered older Reddit page remain exact against the retained
independently repeated full-uBO reference, with all 25 post identities in order.
At compilation and capture time, the seven selected V inputs and all 56
consumed V files in the GG, GGShape, Images, ImageRaster and YUV packages match
their compiler manifests; the native callback source is unchanged through
compilation. The diagnostic shader experiment is removed and canonical GG
staging matches its source. After the feature commit, a concurrent edit changes
`chromium/gpu_raster_darwin.v` again. Its later bytes are recorded separately;
the completed cohort qualifies the pinned executable and PNG fix, rather than
that later checkout state.
Production confirmation of these new PNG changes remains pending. The older
production result above continues to qualify its pinned artifact. The missing newer Reddit fixture, default Brave
Lobsters repeatability and CNN's historical source/replay gate remain open.
This follow-up establishes no live-site or performance acceptance.

Local raw commands, source manifests, browser identities, guard exits, original
failures and PNGs: `docs/performance/capture-scale-recheck-20261116/`.

Cleanup inventories **88 owned roots/10,313 files**, preserves and SHA-verifies
**3,513 evidence files/70,405,692 bytes**, and removes owned browser/test binaries,
generated C, profiles, replay keys, guard reports and locks. No owned
`Build/capture-scale-recheck*` scratch remains. The managed hook requests a
single-C-unit literal V `-prod` rebuild for `40d8c41ed`; no manual duplicate is
queued.


### Source and replay browser version qualification, 2026-11-16

`86220ffbe` fixes an acceptance gap in `tools/forum_news_pixels.py`: it previously
compared the retained live PNG with new replay PNGs without requiring the source
and replay Brave versions to match. Identical pixels could therefore pass that
part of the gate across different versions. The driver now records the source
and both replay version labels in `source-replay-browser-versions.json` and the
site summary. A version mismatch yields `source-browser-mismatch`; missing or
malformed evidence yields `source-browser-unverified`. Two complete replay
receipts are required. Reference-repeat failures retain priority. No pixel
comparison, full-uBO check, PNG, tolerance or executable/library identity guard
is removed or relaxed. Version equality is a necessary condition, not proof of
complete browser identity.

CNN's sealed source report records **Brave 156.1.98.60**. The November 12 replay
reports record **157.1.99.56**, and the retained preparation-preserving November
16 pair records **157.1.99.57**. Reanalysis of those independently repeated,
full-uBO November 16 references preserves the original **107,289-pixel** source
mismatch, their **zero-pixel** repeat, and their **zero-pixel** difference from
the retained replay reference. This is reanalysis of existing evidence; no fresh
Brave or live capture is claimed. The version mismatch is an additional
qualification failure. It does not establish that the upgrade caused all
107,289 differences, and it does not clear CNN's historical source/replay gate.
A matched source/replay browser remains necessary for that claim.

All **37 focused Python tests** pass under the 3 GiB memory guard. They reject
identical source/native/replay PNG verdicts when versions differ, a version
change between replay processes, absent/malformed versions and incomplete
replay cohorts. Existing reference-variation, pixel-failure, cache-preparation,
filter and archive-provenance checks continue to pass.

The default completed-browser selector chooses the published single-C-unit,
literal V `-prod` executable
`bbd4703576665b62c43c763fa6e75c767ec867b4e33b8b7595a7dbcca231a208`.
The newer `20261116-171233-fd0968a3` artifact is marked superseded, so it is not
selected. Fourteen fresh native captures verify that CNN, GitHub, Hacker News,
Lobsters, Wikipedia and Vlang remain exact twice against the unchanged archived
references. The newer uniform PNG control retains **1,412 differences twice**,
as expected for this older artifact. These captures do not confirm `40d8c41ed`.
Production receipts `20261116-173931-b63ac897` and `20261116-180118-e6072ca4`
fail the frozen-input guard because `native_capture_darwin.m` changed while
building. Their failure receipts are retained. Managed commit rebuild requests
remain coalesced; no duplicate manual production build is queued or awaited.

Production confirmation of the PNG fix, the missing newer Reddit fixture,
default Brave Lobsters repeatability and matched-version CNN source/replay
qualification remain open. No live-site or performance acceptance is claimed.

Local evidence: `docs/performance/catalog-followup-20261116/`. Cleanup
inventories **10 owned roots/1,953 files**, preserves and SHA-verifies **171
evidence files/6,861,330 bytes**, and removes owned profiles, replay keys,
guards and locks. No owned `Build/catalog-followup*` scratch remains.


### Public Reddit title/domain wrapping, 2026-11-16

The missing November 4 catalog report describes 2,046 differences from title
wrapping, including a break inside `(youtube.com)`. `130817464` adds a public
regression for this class of behavior without importing account-bearing HTML.
Its six entries include narrow and wide titles, a plain parenthesized domain,
a linked domain, separately nested parenthesis spans and a longer domain.
The title paragraph uses `overflow-wrap:break-word`; the domain uses
`white-space:nowrap`. The complete fixture is 800×600 at scale 1.

Two fresh independent Brave captures agree exactly after five seconds of
settling. The expected PNG is promoted unchanged from diagnostics, SHA-256
`31dc966815b8dfd6b0b419939940382b27bf7822a09fedc53a8b24c94ad801dd`.
The available published production executable `bbd47035` matches with **zero
pixels twice**, both before and after promotion to `input/` and `expected/`.
Its identity is bound to the completed production receipt. Original captures,
rectangles, reference hashes and guard exits are retained. No rendering patch
or reference/tolerance adjustment is needed for these cases. Exactness here
does not establish the missing historical page's current result.

A read-only local Git-object recovery attempt enumerates **113,857 objects**,
then SHA-256 hashes **8,850 blobs/1,168,535,373 bytes** whose uncompressed blob
sizes are 50,000–300,000 bytes. Neither recorded November 4 HTML hash matches:
source `e8ffb950f17bf25a339791238eb7b9618d878fe735b3557deca0c45c4b356f73`,
frozen `a1b991bdea72f51b02b812012e7691065b67f95e9d5a6b3411f15e67c0a1d2e1`.
The scan includes unreachable objects available to this repository; other
sizes, compressed members and external stores are outside this search. It
changes no Git objects and recovers no page. It does not prove that no copy
exists elsewhere. The missing fixture and its sealed resource identity remain
open.

During this check, a concurrent working-tree revert also removes the committed
own-clip image MSAA eligibility hunk from `8641a3868`. Only that exact verified
hunk is restored; the other raster changes are preserved. Before/after hashes
and the prior working diff are retained. This restores the earlier validated
PNG fix, with no new rendering implementation committed here. Other concurrent
raster edits and the current checkout are not validated by the older production
captures.

The newer managed production build remains in progress and has no completed
artifact at this checkpoint. The prior PNG fix still needs production
confirmation. No duplicate manual production build is queued or awaited.
Matched-version CNN source/replay qualification, default Brave Lobsters
repeatability and the newer missing Reddit fixture remain open. These public
controls supply no live-site or performance acceptance.

Local evidence: `docs/performance/reddit-wrap-20261116/`. Cleanup inventories
**16 owned roots/126 files**, preserves and SHA-verifies **90 evidence files/
405,193 bytes**, and removes owned profiles, programs, guard reports and locks.
No owned `Build/reddit-wrap*` scratch remains.


### Published PNG fix and expanded forum coverage, 2026-11-16

The managed worker successfully completes receipt `20261116-182007-1a934292`
and publishes the single-C-unit literal V `-prod` executable
`93adced1156f0bc5e7c6c059caff8f235b5c5688b7eb75026a3a210faf46fdd8`.
All six selected implementation inputs, including the own-clip tile rule,
match their pinned `40d8c41ed` versions in the sealed compiler manifest. The
uniform PNG control and public Reddit wrapping control are exact twice. The
complete **58-workload/116-capture** production sweep repeats, with all 57 prior
accepted diagnostic PNGs byte-identical. The six available instruction-catalog
site archives remain exact twice. The recovered older Reddit page is also
exact in two fresh production processes with all 25 post identities. This closes
production confirmation of the earlier PNG fix, while qualifying the sealed
artifact rather than all later shared-checkout edits.

An initial explicit staging-path check fails before any capture when publication
moves the completed app to the canonical bundle. That attempt is retained.
Subsequent checks acquire the completed-browser lease before resolving and
launching the executable. No extra production build or bundle copy is needed.

`OPTIMIZED_SITES.md` also lists forum/news rendering checkpoints beyond the six
instruction-comparison archives. Fresh full-uBO rechecks of the first three
additional sites reveal these current rendering gaps:

| Site | Published Vox versus fresh Brave | Brave replay repeat | Saved source versus replay |
| --- | ---: | ---: | ---: |
| BBC | 32,482 | 0 | 0 |
| The Guardian | 425 | 0 | 0 |
| The Verge | 262,012 | 0 | 0 |

The earlier `bbd47035` and new `93adced1` cohorts reproduce these counts. Both
fresh Brave references for each site agree and pass the full-uBO request/header,
cosmetic, procedural and scriptlet checks. They use original-origin sealed
replay, a cold private cache, bypassed service workers, the archived load/paint
image preparation, scale 1, sRGB and five seconds of settling. The original
source reports name Brave 156.1.98.60 while these replays use 157.1.99.57, so the
strict driver correctly returns `source-browser-mismatch` even though the
source/replay PNGs match. No new strict pass is claimed. These are frozen-page
rendering gaps; previous zero-pixel checkpoints in the coverage table remain
historical. Other forum/news entries still need a fresh recheck.

The full MV2 uBO 1.75.0 release is downloaded again with its retained ZIP hash;
all 59 vendor files match. The canonical checker compiles under the memory
guard. Each cohort records its actual strict-driver exit 1, separately from its
controller/guard exits. All failures and reference PNGs are retained. The source
version guard is not bypassed to obtain rendering credit.

### Odd-height WebP planes in BBC photos, 2026-11-16

`4924a3389` fixes the first BBC photo-sampling slice. Two images account for
32,471 of the 32,482 original differences: their WebP frames have size 320×179,
and the atlas path rejected odd dimensions. The uncropped lower image accounts
for 8,660 pixels; the cropped right-hand image accounts for 23,811. The remaining
11 differences are in even-sized images.

libwebp supplies ceiling-sized chroma planes for odd luma dimensions. The V
atlas now packs `(width+1)/2` by `(height+1)/2` chroma samples and extends their
own final edge texels. Near-half sampling keeps chroma at level zero; its
coordinates still map by one half, consistent with the upstream YUVA sampling
boundary. Stronger odd-plane minification remains outside the verified range.
The image dispatcher admits the newly supported atlas case while retaining
its previous fallbacks for unsupported source rectangles, encodings, transforms,
opacity, animation and color profiles.

The public `odd-height-webp-atlas` fixture reuses the existing tracked BBC WebP,
without copying the encoded asset. Two fresh Brave processes agree on its
1024×768 scale-1 reference. The expected PNG is promoted unchanged:
SHA-256 `2f1663309ecd3d003c344a80cc2a972bb0ac72fdcfc8f9b91708204a2102c573`.
It includes separate single-sample and four-sample image draws. Odd-plane packing
reduces the original **17,320** differences to **two**. A focused GPU test then
reproduces those two errors when the caller's identical full-image rectangular
clip is included: its inverse transform perturbs float32 sampling coordinates.
The final path omits that redundant clip only for the new odd-plane atlas case,
retains the shared MSAA trigger, and makes the complete public fixture **zero
pixels twice**. Rounded and partial clips keep their existing processing.

Final C diagnostic executable:
`ea045827a87765979f4e8d694b0c5a3099180f5133c23eed411db3d67cca3827`.
The four selected implementation buffers match their compiler manifest, and
selected feature/native inputs remain unchanged throughout compilation. The
complete BBC page improves **32,482→23,822 pixels twice**, with **8,660 corrected,
zero introduced**. Both recorded candidate request streams pass full-uBO checks:
44 requests each, all allowed, with zero mismatches or oracle disagreements.
The cropped right-hand photo remains unsupported by this slice. Its recorded
source rectangle is (1.3445379,0), size 317.31094×179, mapped to (772,251),
size 236×133; the atlas currently accepts only the complete source rectangle.

All **59 workloads/118 fresh diagnostic captures** repeat exactly; all 58 prior
PNG files are byte-identical to the accepted production captures. Existing
inexact controls retain their recorded counts. Ten focused V functions pass:
five CPU atlas checks, the new two-sample-mode GPU regression, and four existing
GPU atlas checks. Actual compiles and runtimes exit zero under the required
memory guards; failed test compiles and intermediate two-pixel results remain
in the evidence. No existing PNG reference or tolerance changes.

Additional candidate captures preserve The Verge's 262,012 differences twice.
Guardian diagnostic captures instead differ by **208,511 and 205,681 pixels**
and do not repeat; their maximum channel error is two. These are retained
failures outside the established 59-workload suite. The Guardian archive
contains **no simple VP8 WebP responses**, so the new odd-WebP dispatcher path
is ineligible there. Its visible image responses are JPEG XL. This establishes
path ineligibility, not the cause of the diagnostic variation; no Guardian
improvement or acceptance is claimed. Two additional fresh production captures
remain at **425 pixels each**.
The diagnostic JPEG XL variation remains unresolved and is not attributed to
this WebP fix. Further matched investigation is required.

Production confirmation of this newer WebP fix remains pending. The managed
hook requests the normal coalesced C/literal V `-prod` rebuild; no manual duplicate
is queued. BBC's cropped photo and residual even-image pixels, Guardian and
Verge rendering gaps, the remaining forum/news rechecks, the missing newer
Reddit fixture, default Brave Lobsters repeatability and matched-version source
qualification remain open. No live-site or performance acceptance is claimed.

Local evidence: `docs/performance/forum-sweep-20261116/`.

Cleanup inventories **98 owned roots/10,928 files**, preserves and SHA-verifies
**2,885 evidence files/87,622,354 bytes**, and removes owned browser/checker/test
binaries, generated C, downloaded extensions, private profiles/caches, replay
keys, guard reports and locks. No owned `Build/forum-sweep*` scratch remains.
Shared bundles, dependencies and production receipts remain in place.


### Cropped WebP plane sampling, 2026-11-16

`3ab0294c6` fixes BBC's cropped right-hand photo. The full frozen page improves
**23,822→11 pixels twice**, correcting **23,811** pixels and introducing **zero**.
The remaining differences are the same three hero-photo pixels and eight
lower-photo pixels, each with maximum channel error one. Together with the
preceding odd-height fix, 32,471 of the 32,482 production differences are now
corrected in diagnostics. This is not yet a complete BBC pixel pass.

The image dispatcher folds an in-bounds source subset into the full plane
rectangle and retains the original rectangular destination clip. For the
recorded 317.31094×179 source subset at (1.3445379,0), the full plane rectangle
is (771,251), size 238×133, with the original (772,251), size 236×133 crop.
The new path requires near-half minification, integral expanded geometry,
translation-only transforms, full opacity, and a rectangular clip contained
in the original destination. Unsupported crops keep their existing fallback.

The GPU draw uses the crop's actual rectangle as geometry and retains the
document-space origin across raster tiles. Normalizing each tile's geometry
before calculating texture coordinates changes float32 interpolation on one
single-sample scanline; retaining the document frame removes those errors.
Chroma sampling also follows Chromium's symmetric source-subset inset, including
the odd-height final row. The planar shader carries its four chroma bounds in
its otherwise inactive RGB gamut payload; ordinary RGB/gamma draws retain their
existing payload and the uniform size is unchanged. Both V and Python staging
repair the sampler and serializer together. Their partial-repair checks cover
missing uniforms, shader branches and the new subset payload independently.

The public `cropped-webp-atlas` control reuses the existing tracked 320×179 BBC
WebP and includes separate four-sample and single-sample tile draws. Two fresh
Brave 157.1.99.57 captures agree. The new reference is promoted unchanged, with
SHA-256 `4a422959aed386404d750dcba9808cae0efbbd9fefd09f7309cce921e841a6b0`.
The published browser differs by **50,390 pixels twice**; the final diagnostic
is **zero twice**, and the GPU regression compares both sample modes plus an
exterior ring exactly. No existing reference or tolerance changes.

Final C/O0 diagnostic executable:
`6fe34d8e3fe2b01bdd6ba9c6b56a9243727383c4043b01b8810cf67e529a5e3f`.
All 378 selected inputs remain unchanged during its successful compilation;
six consumed implementation/staged-GG buffers match their compiler manifest.
All **60 workloads/120 fresh captures** repeat exactly. All **59 previous PNGs
are byte-identical** to the preceding accepted captures, including the six main
catalog archives; pre-existing inexact controls keep their recorded counts.
Fourteen focused V test functions and one Python staging test pass. The browser
compile, focused checks and complete capture controller exit zero under the
required memory guards. Rejected compiles, intermediate pixel failures, and
staging-test failures remain in the local evidence.

Both BBC native request streams pass full-uBO 1.75.0 checks: 44 requests each,
44 allowed, zero blocked, zero mismatches and zero oracle disagreements. The
release ZIP hash and all 59 retained vendor files verify. A local controller's
report-key typo occurs after the first successful checker run; that result is
retained and validated, without rerunning the first request stream.

Production confirmation remains pending. The managed commit hook requests the
coalesced C/literal V `-prod` rebuild. The latest available published bundle
remains `93adced1`; retained builds abort on changing sealed inputs, including
`native_document_color_darwin.h` and the edited `gg_document_image.v` helper. No duplicate
manual production build is queued, and the older bundle is not used to validate
this fix. Source-browser version qualification, BBC's remaining 11 pixels,
Guardian/Verge rendering gaps and the other previously documented catalog gates
remain open. Guardian's earlier diagnostic instability is not resolved by this
check, and no live-site or performance acceptance is claimed.

Local evidence: `docs/performance/webp-crop-20261116/`. Cleanup inventories
**97 owned roots/4,581 files**, SHA-verifies and preserves **1,371 evidence
files/31,250,366 bytes**, then removes owned programs, generated C, downloaded
extension/ZIP, private profiles/caches, replay keys, guards and locks. No
`Build/webp-crop*` job output remains.


### Even WebP atlas clips and BBC rendering parity, 2026-11-16

`bdcad8eaa` removes BBC's remaining **11 pixels**: three in the 640×360 hero
photo and eight in a 320×180 lower photo. The complete archived BBC document
now matches the retained independent Brave reference **exactly in two fresh
diagnostic captures**, with 11 corrected and zero introduced pixels. The earlier
production gap of 32,482 pixels is fully corrected by the three WebP slices in
the diagnostic browser. Production and source-version qualification remain open.

The redundant full-image rectangle clip perturbs float32 inverse coordinates
before planar sampling. The existing odd-plane omission now also covers even
planes at near-half scales when every clip coordinate is integral and the clip
matches the complete image rectangle without rounded corners. Other clips and
minification ranges retain their prior processing. The original image transform
is preserved. An experiment using an absolute destination frame instead worsens
the hero control to 47 pixels and is rejected; that experiment is retained.

Two new public controls reproduce the image positions and dimensions across
three raster tiles, with four-sample and single-sample references respectively.
Both references repeat across two fresh Brave processes and are promoted
unchanged. Their SHA-256 values are
`d782bd01c4d74b101cdb825ccbf19b208e55576558206a89cb168ef2fe5fc749` and
`7c9099876fccbf81020ed9a933edbdb9740eacd9bc84cf089d4aaa5fbb0fee43`.
The published browser differs by **11 pixels twice for each control**; the
candidate gives **zero twice for each**. The GPU regression checks the published
parts of every intersected tile and an exterior ring in both sample modes.

C/O0 diagnostic executable:
`28744a1ba6eb376079e95facdffce843f69e5872264df145bbb0d805110fabcf`.
Selected compilation inputs remain unchanged; five consumed feature/staged-GG
buffers match their compiler manifest. All **62 workloads/124 fresh captures**
repeat, and all **60 preceding PNGs remain byte-identical**. Existing inexact
controls retain their recorded counts. Fifteen focused V functions and one
Python staging check pass. Actual compile, runtime and controller exits are zero
under the required memory guards. Both BBC streams pass full-uBO 1.75.0 checks:
44 requests each, all allowed, zero mismatches and oracle disagreements. The
release ZIP and 59 retained vendor files verify. No old reference or tolerance
changes, live-site acceptance or performance credit are claimed.

Additional Guardian captures still fail and vary: **207,975 and 186,856 pixels**.
Their investigation has a separate ownership probe: poisoning the first JPEG XL
output arena traps a subsequent quantization read through the lazily cached
dither table, exit 138. The ordinary unpoisoned probe passes and does not disprove
the dangling read. Those failures are retained for the next fix; they are not
included among the passing 62-workload repeat checks.

The managed hook requests the coalesced C/literal V `-prod` rebuild. The available
`93adced1` production bundle supplies the control captures and cannot validate
these newer WebP changes. No duplicate manual production build is queued.
BBC's frozen rendering gap is closed in diagnostics; the matching-version source
gate, production confirmation, Guardian/Verge gaps and other catalog checkpoints
still need work.

Local evidence: `docs/performance/even-webp-20261116/`. Cleanup SHA-verifies and
preserves **1,347 evidence files/33,217,001 bytes**, inventories **41 owned roots/
4,624 files**, and removes the owned browser/checker/test programs, generated C,
private caches/profiles, downloaded extension/ZIP, replay keys, guards and locks.
No `Build/even-webp*` job output remains.


### JPEG XL dither ownership and diagnostic stability, 2026-11-16

`e41b2bff0` fixes the unstable JPEG XL diagnostic captures. V development
builds lazily read the embedded 1,024-byte dither table in the first reader's
allocation scope. JPEG XL output can first read it inside a disposable decode
arena; its cached pointer then outlives that arena. A fresh scope-poisoning probe
traps the next quantization read through `quantize_output_row_into`, exit 138.
The ordinary probe passes because its allocation pattern does not overwrite the
old buffer; that pass does not establish correct ownership.

The module now initializes a fixed-size immutable table by value, checking its
length before copying. Quantization reads that module-owned array. The source
binary remains unchanged at SHA-256
`6247b14297fdc698d699d1e1fa2331e4da69215d852e2493af27009b9effc93e`.
Its attribution and rounding/dither arithmetic remain unchanged. The poisoning
regression passes with and without literal V `-prod`; the two existing output
functions also pass in both modes, covering 62 integer rows, 4,096 quantized rows
and 768 premultiplied rows, plus bounds/wrap cases. These focused test invocations
are not production-browser validation.

Before this fix, two retained Guardian C/O0 captures differ by **207,975 and
186,856 pixels** and do not repeat. Fixed C/O0 executable
`6fb81def653641d81c8544d11732ae15580bc154337ff395e94b681019159818`
gives **425 twice**, with both complete PNGs pixel-identical to the available
production baseline. The consumed output module matches its compiler witness;
selected inputs remain unchanged during compilation. Both 55-request streams
pass full-uBO 1.75.0 checks, with zero blocked requests, mismatches or oracle
disagreements. The release ZIP and 59 retained vendor files verify.
All **62 workloads/124 fresh captures** repeat, and every PNG remains byte-identical
to the preceding even-WebP cohort. The Guardian load is a separate retained
failure, outside that repeat suite; its 425 rendering differences remain open
at this point. No existing reference/tolerance or performance claim changes.

Local evidence: `docs/performance/guardian-dither-20261116/`. Cleanup inventories
**27 owned roots/4,376 files**, preserves and SHA-verifies **1,258 evidence files/
27,754,733 bytes**, then removes per-job programs, generated C, private
profiles/caches, downloaded extension/ZIP, replay keys, guard reports and locks.
No `Build/guardian-dither*` job output remains.

### Guardian JPEG XL circles and remaining dropdown border, 2026-11-16

`b0856f720` improves the complete archived Guardian page **425→3 pixels twice**,
correcting **422** pixels and introducing **zero**. All three circular photos
now match the retained independent Brave reference exactly. The remaining
pixels are (978,223), (980,223) and (979,224), maximum channel error two, in the
edition picker's rotated CSS border. Its `::after` uses a 5×5 border box,
1-pixel right/bottom borders, `translateY(-2px) rotate(45deg)` and white current
color. This is a remaining rendering gate, not a full Guardian pass.

The new V dispatch admits only opaque, unscaled, integral-positioned sRGB JPEG XL
circles up to 128×128, under Chromium rendering policy, full opacity and a
translation-only transform. Other corner shapes and crops, transparent pixels
and Display P3 rendering retain their existing fallback. The native change only
routes the shared readback boundary's new mode to its V callback; V owns its
eligibility, tile selection and image drawing.

The image and rounded clip now share one GPU draw, avoiding a separately
quantized platform clip mask. A direct GPU control initially retains 31 pixels
in the four-sample pass: its analytic rounded geometry perturbs interpolated
texture coordinates. Recovering those coordinates from device vertices removes
all 31. A dedicated color-transform flag selects the existing coordinate adapter
without changing texture wrapping. Single-sample draws leave that coordinate
adapter disabled; other image paths keep their existing selection. Opaque-image and absolute-frame experiments do not fix
those residual pixels; their failures remain in evidence.

The new `unscaled-jpegxl-circles` fixture reuses three tracked Guardian JPEG XL
responses and includes upper/lower circle sets. All four fresh Brave references
agree byte for byte; the final pair pins all three asset bodies and browser
inputs before and after capture. The expected PNG is promoted unchanged:
SHA-256 `fe498dae06577de321c944fd316ea7c16b2048d91609175915246277c55f853d`.
The control browser differs by **992 pixels twice**; the candidate is **zero
twice**. The GPU regression checks all three pictures in both sample modes plus
an exterior ring, and rejects translucent input without touching the backdrop.
V/Python staging checks cover installation and independent repair of the new
coordinate selection. No previous reference or tolerance changes.

Final C/O0 diagnostic executable:
`3590aada0059f7d0d9261af71a230c05b4e1d8f91690f572b19ccecb20867dd0`.
Six consumed implementation/staged-GG buffers match their compiler manifest;
selected source/native inputs remain unchanged during successful compilation.
An earlier compile whose inputs change is retained and rejected. Seventeen
focused V functions and four Python staging tests pass. All **63 workloads/
126 fresh captures** repeat; all **62 preceding PNGs remain byte-identical**,
including the six main catalog archives and the new BBC controls. Existing
inexact controls retain their recorded counts. Complete Guardian captures are
separately audited and still fail by the three dropdown pixels. Both new native
streams pass full-uBO checks: 55 requests each, all allowed, zero mismatches and
oracle disagreements. Actual accepted compile, test, capture and guard exits
are zero under the required memory caps.

The latest available completed production browser remains `93adced1`, selected
through its lease and completed receipt. It cannot validate the newer WebP or
JPEG XL fixes. Every source commit requests the normal coalesced C/literal V
`-prod` rebuild; no duplicate manual production build is queued. BBC's exact
frozen rendering is established by its earlier pinned diagnostic cohort;
Guardian's remaining three pixels, production confirmation, source-browser
version qualification, Verge and the other catalog gates remain open. No
live-site or instruction-performance acceptance is claimed.

Local evidence: `docs/performance/guardian-circles-20261116/`. Cleanup inventories
**50 owned roots/3,831 files**, preserves and SHA-verifies **1,338 evidence files/
30,001,450 bytes**, then removes owned programs, generated C, private
profiles/caches, replay keys, guards and locks. No `Build/guardian-circles*` job
output remains. The separate downloaded uBO/checker resources are removed with
the completed dither job above.


### Guardian solid border sample ownership, 2026-11-16

`aca448d3c` removes the remaining **3→0 pixels twice** in the complete archived
Guardian viewport, correcting all three and introducing zero. Adjacent opaque
sides from one transformed CSS border now keep their multisample coverage until
one resolve. Previously each rectangle was resolved and read back before the
next side, losing their common samples where they overlap. The existing V GPU
shape-group adapter supplies the shared pass; no shader or native boundary
changes are needed.

The border painter records the side count alongside its shared box-local data.
The V replay matcher requires the complete two- or three-side sequence, pointer
identity, common transform and raster layer, matching opaque color and full
opacity. Complex clips, effects, invalid geometry and incomplete groups retain
the existing replay. This does not group neighboring boxes or change side order.

The reduced `rotated-border-join` control includes a transparent four-sample
layer and an opaque single-sample root. Its two independently captured Brave
PNGs are byte-identical, SHA-256
`f8a1afc3e6eafac9cf1ae243740486650ae7c0a48b04b8f0d0dea4720f7dd591`;
the upper arrow matches the original Guardian reference region exactly.
The available production browser differs by three pixels twice; the candidate
is zero twice. Initial GPU experiments on an opaque backdrop retain seven
pixels even when grouped. Reproducing the transparent layer exposes the actual
three-pixel failure, and grouping then matches exactly. These attempts remain
in the local evidence. No existing reference or tolerance changes.

C/O0 diagnostic executable:
`a3fa7dda2b1e1b15ed294829593a17f871321311add249d8e0bad3ae4cda299a`.
Five consumed V implementation buffers match the compiler manifest; selected
source/native inputs stay unchanged throughout successful compilation. A prior
compile overlapping formatting is retained and rejected. Seven focused V test
functions pass, including two/three-side painter order, group fallbacks and GPU
pixels in both sample modes. All **64 workloads/128 fresh captures** repeat,
and all **63 preceding PNGs remain byte-identical**. Existing inexact controls
retain their counts. Both separate Guardian loads pass document/content audits
and full-uBO checks: 55 requests each, all allowed, zero mismatches or oracle
disagreements. The pinned uBO release and 59 vendor files verify. Accepted
compile/test/capture/filter/guard exits are zero.

The additional existing `layout/chromium_partial_border_test.v` check remains
unvalidated: C compilation exceeds the unchanged 12 GiB aggregate guard, even
with serial code generation; a separate 3 GiB attempt also hits its cap.
FastC attempts instead encounter unrelated generated-C errors, including
`CSSPixelPoint` expressions and LibJS value/object operations, after an initial
Objective-C mode error. These are recorded failed checks, not passing tests.
The new end-to-end painter/group tests and browser captures above do pass.

The latest completed production executable remains `93adced1`; it cannot
validate these newer source fixes. The managed post-commit hook requests the
coalesced C/literal V `-prod` rebuild. Production confirmation, the existing
source/replay browser-version qualification and remaining catalog gates stay
open. The next pinned Verge captures still differ by **262,012 twice**: the
visible differences cover the hero image and the vertical logo's shadow.
No Verge fix, live-site pass or instruction-performance acceptance is claimed.

Local evidence: `docs/performance/guardian-border-20261116/`.
Cleanup inventories **67 owned roots/5,568 files**, preserves and SHA-verifies
**1,423 evidence files/35,799,211 bytes**, then removes owned programs, generated
C, private profiles/caches, downloaded extensions, replay keys, guards and locks.
No `Build/guardian-border*` job output remains.


### Verge CSS shadow color, 2026-11-16

`15fefe590` corrects the native Core Image drop-shadow color matrix. Its RGB
channels now stay at the selected color while blurred source alpha controls
opacity. Previously RGB also followed alpha, so the shadow faded toward black
at low coverage. Core Image color filters operate on unpremultiplied channels;
see [Apple's filter reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html#//apple_ref/doc/filter/ci/CIColorMatrix).
The existing alpha extraction, blur, offset and composition remain in the same
order. The focused native helper is shared by the browser and its real Core
Image test.

The complete frozen Verge viewport improves **262,012→174,100 pixels twice**
relative to the preceding diagnostic cohort. **88,341 pixels are corrected and
429 newly differ**; this is an incomplete rendering fix. The retained
`verge-svg-filter-space` control improves **137,990→31,489 twice**, with residual
blur/antialiasing differences. The transformed no-blur control stays exact.
Two new independent Brave processes for each existing control reproduce its
unchanged reference byte for byte. No reference or tolerance is relaxed.

The new `constant-color-drop-shadow` control uses black HTML/SVG shapes over
white, red and blue panels, with matching shadow hues. Correct shadows blend
into these panels without dark halos. Two independent Brave references agree,
SHA-256 `262b496c97acab249ce359b25cb0639d8fe5d991bc550d0e12620b8fac74ed1b`.
Production differs by **103,570 pixels twice**; the candidate is **zero twice**.
The direct native test covers **3,072 alpha/color samples**: every byte alpha,
white/red/blue/black and zero/0.6/full shadow opacity. The old matrix fails the
RGB/alpha assertion; the fixed matrix passes. A typed paint-list test verifies
white, hexadecimal alpha, functional alpha and red resolve correctly before
reaching the native boundary. An initial test using the compatibility snapshot
finds no filter and is retained as a failed harness attempt.

Accepted C/O0 executable:
`4ed15f604761d5f443232e1d184708df32caa43e565be75fe092b9cc2265bbd6`.
Four consumed V paint/filter buffers match the compiler manifest; selected
V/native inputs remain unchanged during compilation, including the new helper.
Native compilation and real Core Image checks pass under the 3 GiB guard;
V compilation uses the unchanged 12 GiB aggregate guard and focused runtime
also passes under 3 GiB. All **67 workloads/134 fresh captures** repeat; all
**64 preceding PNGs remain byte-identical**. Existing inexact controls retain
their counts. Complete BBC and Guardian captures separately remain **zero twice**
each. Both Verge streams pass full-uBO checks: **178 requests each**, all
allowed, zero mismatches or oracle disagreements. The pinned release ZIP and
59 vendor files verify. Accepted compile, runtime, capture, filter and guard
exits are zero; failed controls remain in the local evidence.

The hero response is the tracked 540×360 VP8 WebP
`dfffe5e6ef2ca7d69e140c3d35089fbd7e66f83fd27e3d9be70742843abd28a1`;
both browsers report density-adjusted natural width 512 and a 580×464 displayed
box. A separate logging run repeats 174,100 twice and records source rectangle
(45,0,450.00003,360) mapped to that box, with a 540×360 channel-7 decoded image.
The expanded full-image draw needs enlargement, outside the current minifying
atlas gate. Its sampling and the remaining SVG filter raster differences stay open.
The latest completed production executable remains `93adced1`, which lacks
this fix. The managed hook requests the coalesced C/literal V `-prod` rebuild.
Production confirmation, the earlier source/replay browser-version guard,
remaining catalog rechecks and live-site behavior are still unverified. No
instruction-performance acceptance is claimed.

Local evidence: `docs/performance/verge-shadow-20261116/`.
Cleanup inventories **38 owned roots/6,425 files**, preserves and SHA-verifies
**1,576 evidence files/39,385,729 bytes**, then removes owned programs, generated
C, private profiles/caches, downloaded extensions, replay keys, guards and locks.
No `Build/verge-shadow*` job output remains.


### Verge enlarged WebP crops and runtime shader pins, 2026-11-16

`efc8321e7` admits integral, uniform WebP enlargement above 1× through 2× in
the original-plane atlas path. The complete archived Verge viewport improves
**174,100→32,035 pixels twice**, correcting **143,509** and introducing **1,444**.
The remaining overlays are still inexact; this is an incomplete site fix.
Separate complete BBC and Guardian captures remain **zero twice** each.

The hero's source is (45,0,450.00003,360) in the tracked 540×360 VP8 body
`dfffe5e6ef2ca7d69e140c3d35089fbd7e66f83fd27e3d9be70742843abd28a1`.
It maps to (222,204,580,464), with a full-image destination of (164,204,696,464).
The new enlargement branch normalizes source-coordinate float32 roundoff at
integer edges; meaningful fractional crops retain their fallback. Other existing
image, opacity, profile, transform and clip checks remain active. Minification
keeps its established eligibility. Enlargements keep the original luma/chroma
planes and need no mip chain.

Initial direct GPU probes differ by **115,814 pixels** when filtering decoded
RGB and **215** when sampling the YUV planes. All 215 sit at the enlarged crop's
luma boundary: magnification can sample beyond the subset's outer texel centers.
The shader now clamps luma as well as chroma. Its luma bounds use the planar
variant's spare gamut-payload slots, preserving the uniform ABI. The payload
stays zero for the earlier minification paths. The source-subset GPU test now
matches exactly in both sample modes, including tile ownership and an exterior
ring. An additional full-image control verifies the original plane edges.

The three new public controls reuse the tracked body. Each gets two fresh,
byte-identical Brave references; expected PNGs are promoted unchanged:

| Control | SHA-256 | Available production | Candidate |
| --- | --- | ---: | ---: |
| `upscaled-webp-atlas` | `8b7da5d01835e5171d7546c191a73bc4a6cefac6b7b511d68c46c277b4c685b5` | 181,255 twice | 0 twice |
| `upscaled-webp-atlas-single-sample` | `3b30d6e622d6ef22fbf8f4e739af22bd0b89896fa8e60482427b7b369e12ef2f` | 181,255 twice | 0 twice |
| `upscaled-webp-atlas-full` | `13e30bf6b6efda864fb00b587a4b4f4ef43a8b09b60e67e01f537a852d1b2e0b` | 193,075 twice | 0 twice |

A separate diagnostic verifies actual path execution: the hero uploads its
540×360 planes, paints successfully, and uses four samples in all three root
tile rows. These logging captures also differ by 32,035 twice. The isolated SVG
filter control remains at 31,489; image/overlay intersections retain further
errors. No previous reference or tolerance changes.

Validation exposed a shared-input problem. Generated diagnostic C initializes
`gradient_snippet_file` with null embedded-data pointers and an absolute file
path; shaders are loaded at runtime. During the first 70-workload run another
shared precision experiment changes that file and introduces an invalid
float3/scalar `half4` constructor. Later captures fall back to the old renderer.
That entire unpinned run is retained and rejected, despite controller exit zero.
The initial claim that executable identity alone pins these shader inputs is
withdrawn. `f9e29e413` adds all 24 runtime Metal shader hashes to the pixel driver's
scope and checks them after every capture. The explicit half-vector constructor
repair remains within the other unfinished precision block; it cannot be
committed separately without taking that unrelated experiment. Only the new YUV
shader/staging changes are included in the WebP feature commit.

The rerun uses pinned runtime shaders throughout. All **70 workloads/140 fresh
captures** repeat, all **67 preceding PNGs remain byte-identical**, and all three
new controls are exact. Nineteen focused V functions and three Python staging
tests pass, with the GPU tests' runtime shaders, references and body inputs
pinned before and after. V and Python preparers cover cold installation,
independent luma-shader repair and idempotence. The first native staging fixture
lacks a later shared gamma anchor and fails; its corrected fixture and actual
GPU runs pass. All failed probes and compiler attempts remain in evidence.

C/O0 diagnostic executable:
`7032db3a81d6ba492cb21f41484192725c7516310ed40892aae0895ff5ecfef5`.
Six consumed V buffers match the captured compiler manifest at the successful
build; later checkout edits are outside that binary's validation. Both final
Verge streams pass full-uBO checks: 178 requests each, all allowed, zero
mismatches and oracle disagreements. The pinned release ZIP and 59 vendor files
verify. Accepted build/test/capture/filter/guard exits are zero under the
unchanged 12 GiB build and 3 GiB focused runtime caps. The 24 runtime shader
files are preserved with their hashes in local evidence.

The latest completed production bundle remains `93adced1`; it cannot validate
these newer fixes. The managed hooks request coalesced C/literal V `-prod`
rebuilds. Production confirmation, the 32,035 remaining Verge pixels, other
catalog rechecks, source/replay version qualification and live behavior remain
open. No instruction-performance acceptance is claimed.

Local evidence: `docs/performance/verge-webp-20261116/`.
Cleanup inventories **72 owned roots/11,450 files**, preserves and SHA-verifies
**3,146 job evidence files/92,074,904 bytes**, then removes owned programs,
generated C, private profiles/caches, downloaded extensions, replay keys, guards
and locks. Runtime shader snapshots remain in the local evidence directory.
No `Build/verge-webp*` job output remains.


### Verge local SVG drop shadows, 2026-11-16

`0dd8f7f65` rasterizes an eligible opaque black SVG path before its
quarter-turn CSS transform. The blur stays at its reduced resolution until
sampling and shadow coloring into a local RGBA layer; the original source is
merged there before the final rotation. The linear offset's one-pixel input
border changes the centered downsampling footprint. Near-integer bounds use
0.001 rounding, including the SVG viewport's tiny negative top coordinate.
This follows the [matrix filter's input-border rule](https://github.com/google/skia/blob/886e42fda11610a56dd1b22e8697e27f9d1e34f2/src/effects/imagefilters/SkMatrixTransformImageFilter.cpp).

V owns eligibility, path conversion, filtering and owning-tile replay. Native
code transfers the backdrop and completed pixels. Source clips must contain
the SVG viewport; ancestor clips, nested effects, gradients, strokes, colored
or translucent source paths, other CSS transforms and non-1× readbacks retain
the existing fallback. A geometry-enclosure check also declines overflowing
paths without publishing partial output. Filter output beyond the root
picture keeps the root tile phase. Cached native and Python GG preparation
refresh the canonical RGBA-layer helper even after the ABI patch is installed.

The existing `verge-svg-filter-space` reference improves **31,489→14 pixels
twice**, with maximum channel error one. Its unfiltered local source is exact.
Two new controls have independently repeated Brave 157.1.99.57 references,
verified again with executable/framework hashes: the rectangle's earlier
fallback has 41,546 differences and the candidate has **12 twice**; the local
source is **zero twice**. Reference PNG hashes are respectively
`c8d3c7b2c9b1214709d1b02b24d14d1c609eaca77a6261cdd4f9e28ca74a5f09`
and `f5e21b3a7e8e22e0f3540fd23c4c79176da539156ee4451a211a39913f5cb9ba`.
The existing unblurred transformed-shadow control remains exact. Existing
references and tolerances are unchanged; the 14/12 residuals remain failures
of pixel equality.

The complete archived Verge viewport improves **32,035→14,916 twice**,
correcting **17,394** pixels and introducing **275**. Maximum channel error
falls from 86 to **two**. All 18,211 changed pixels stay in the SVG transfer
region; 9,042 remaining differences are at x≥416, beyond that transfer's right
edge. Photo/overlay differences and the isolated shadow's remaining precision
errors are open. Complete BBC and Guardian captures separately remain **zero
twice** each. This is an incomplete Verge fix.

Final C/O0 diagnostic executable:
`929de69264bd51f69d576416d31741cd60550ab253931ff30b2ca7b3d5df1c83`.
Five consumed V feature/helper buffers match their compiler manifest. Selected
V/native inputs stay unchanged through successful compilation; executable,
shared-library, page/reference and all **24 runtime Metal shader** hashes stay
pinned during captures. Shader snapshots remain in the local evidence.
**72 workloads/144 fresh captures** repeat. All **69 preceding PNGs outside
the SVG control are byte-identical**; existing inexact controls retain their
counts. A pre-enclosure cohort is retained too: all 72 final PNGs match it.
Fifteen focused V functions and five Python staging tests pass, including
real GPU draws, source samples, overflow/transform fallbacks, typed live-list
scope/clip checks, prior blur hashes and cached-helper refresh. Compilation
uses the default 12 GiB guard; focused GPU/runtime jobs use 3 GiB guards.
Both final Verge request streams pass full-uBO checks: **178 requests each**,
all allowed, zero mismatches or oracle disagreements. The release ZIP and 59
vendor-file pins verify. Accepted compile/runtime/capture/filter/guard exits
are zero.

Rejected diagnostics remain local: direct-backdrop A8 compositing, premature
A8 upscale, tight/cropped layers, shifted/full-source grids and half-precision
sampling. One shader experiment fails Metal compilation and supplies no
acceptance evidence. Two browser compilations overlap unrelated layout edits
and fail input pins. The first scope unit reads a compatibility snapshot that
has no filter boundaries; the corrected live-display-list check passes.
An in-progress bitmap-decoration expansion also exposes a positional
initializer error; `16d36c4` switches that independent call to named fields.

Production available at validation start was `93adced1`. During validation,
C/literal V `-prod`, single-unit build `0cae86c8` became available. Four checked
V buffers match the pre-enclosure diagnostic snapshot; its SVG implementation
lacks the final geometry-enclosure guard. Fresh production captures reproduce
**14/12/0** pixels for the logo/rectangle/source controls and **14,916** for the
complete Verge viewport, twice each. This is baseline evidence for that earlier
renderer, not production validation of the final guard. Managed hooks request
the coalesced rebuild containing the committed feature.
Production confirmation, source/replay version qualification, remaining catalog
checks and live behavior remain open. No instruction-performance acceptance
is claimed.

Local evidence: `docs/performance/verge-svg-20261116/`.
Cleanup inventories **184 owned roots/12,673 files**, preserves and SHA-verifies
**3,460 job evidence files/90,170,525 bytes**, then removes owned programs,
generated C, private profiles/caches, downloaded extensions, replay keys, guards
and locks. No `Build/verge-svg*` job output remains.


### Analytic rectangular shadows on Verge, 2026-11-17

`da4e91d4f` draws supported rectangular box shadows with the Gaussian
integral profile instead of the Core Graphics fallback. V builds the power-of-two
A8 lookup table and device geometry. A bounded Metal sampling pass evaluates
horizontal and vertical coverage, including rectangles narrower than six sigma.
The GG helper retains that coverage as RGBA32f until paint and destination
blending; an intermediate A8 resolve loses visible precision. Existing clip-outs,
underlay cuts and owning root-tile phase stay in the draw. Rounded, sheared,
anisotropic and unsupported-sigma descriptors retain their existing paths.
Filter-transfer metadata continues to be ignored by this unrotated box-shadow
path, as specified by the descriptor contract.

The complete frozen Verge viewport improves **14,916→8 differing pixels twice**,
with maximum channel error **two→one**. It corrects **14,909** pixels and introduces
**one**; 14,912 changed pixels lie within x=238…831, y=567…767. The eight residuals
remain failures of pixel equality. Complete BBC and Guardian captures remain
**zero twice** each. These are archived document captures, not live-site or
performance acceptance.

Two new controls use independently repeated Brave **157.1.99.57** references,
with executable/framework and fixture hashes pinned. The card improves
**18,935→1 pixel twice**, with maximum error one. The small/narrow/fractional
variants improve **15,490→7,050 twice**, with maximum error two; its small and
narrow rectangles are exact, while the fractional scaled rectangle remains
open. Reference hashes are respectively
`ccb6f79aacfd1905274f1ca21629baa2ac7dd6eaff96f2aee238c6e7036d2f54` and
`1674bce1d3b9be56cabd3dcfb17329cc9fe9b245da1a470cc80fc96260a53803`.
Existing references and tolerances are unchanged. The new GPU card test records
its single one-level residual explicitly rather than claiming exact equality.

The final **74 workloads/148 fresh captures** repeat. All **72 prior PNGs are
byte-identical**, including CNN, GitHub, Hacker News, Lobsters, Wikipedia and
Vlang.io at zero; existing inexact controls retain their counts, including the
14-pixel isolated SVG logo. Fourteen focused V functions pass with actual GPU
execution, existing blur hashes, both card sample counts, and eligibility checks.
Both Python cached-helper staging tests pass. Compile/runtime jobs use the
required 12/3 GiB guards. Both final Verge request streams pass full-uBO checks:
**178 requests each**, all allowed, zero mismatches or oracle disagreements.
The release ZIP hash and 59 vendor-file pins verify. Accepted compiler, runtime,
capture, filter and guard exits are zero.

C/O0 diagnostic executable:
`a0c6ea9e593ae603102b6aab59ffc1dc8f43b87c146843c1a018f1dc061cbca9`.
The four implementation/helper files and staged helper match its pinned inputs;
compiler-read feature buffers match too. Executable/native-library, archive,
reference and all **24 runtime Metal shader** hashes stay pinned through captures.
Accepted shader text is retained locally. A disabled-path control reproduces the
14,916/18,935/15,490 baselines and preserves all 72 prior PNGs. Its selected
renderer/native/helper inputs differ only in the eligibility gate; the compiler
also records unrelated LibJS edits, so this supplies no matched performance
claim. The browser's default backend remains JavaScriptCore.

Rejected diagnostics remain local: half-precision coverage produces 441 card
errors, and one earlier shader experiment fails compilation. A reciprocal-alpha
experiment retains the one-pixel error. A guard that incorrectly treats filter
transfer metadata as an unsupported shadow disables the fix; the final code
removes it and exactly matches the first pinned candidate's implementation.
One focused compilation overlaps an unrelated rounded-group edit and fails its
input pin; the unchanged feature is recompiled and its tests pass. A managed
production attempt also rejects changing experimental shader inputs rather than
publishing mixed code.

The latest completed production browser at validation is still `0cae86c8`;
its new-control baselines are 18,935/15,490 and it lacks this fix. Hooks request
the coalesced C/literal V `-prod`, single-unit rebuild. Production validation,
the eight Verge pixels, the fractional control, catalog source/version gaps and
live-site acceptance remain open. Raw commands, complete outputs, receipts,
shader snapshots and SHA-verified cleanup inventory stay ignored under
`docs/performance/verge-rect-20261116/`.
 Cleanup SHA-verifies **3,171 evidence files
(74,512,708 bytes)** before deleting all **83** owned Build roots, including
per-job programs, caches, profiles, locks and guards. No `Build/verge-rect*`
entries remain.


### Verge SVG merge allocation and transparent borders, 2026-11-17

`b2f198209` makes the SVG drop-shadow merge use an approximate backing allocation
and a one-pixel transparent boundary, including the corresponding device-origin
translation and logical-subset readback. V owns the bounded surface request,
clip, transforms and readback crop; the existing GG save-layer allocator supplies
the backing size. It matches Graphite's image-filter
[backend allocation](https://github.com/google/skia/blob/886e42fda11610a56dd1b22e8697e27f9d1e34f2/src/gpu/graphite/TextureUtils.cpp)
and [AutoSurface boundary](https://github.com/google/skia/blob/886e42fda11610a56dd1b22e8697e27f9d1e34f2/src/core/SkImageFilterTypes.cpp).
The allocation and one-pixel origin change the interpolation phase when the
low-resolution blur is sampled into the merge. Kernels, paint colors, fixtures,
reference PNGs and tolerances stay unchanged.

The complete frozen Verge viewport improves **8→0 pixels twice**, correcting
all eight with none introduced. Its isolated logo improves **14→0 twice**, and
the SVG rectangle control improves **12→0 twice**. Complete BBC and Guardian
captures separately remain **zero twice** each. All **74 workloads/148 fresh
captures** repeat; all **72 prior PNGs outside those two SVG controls are
byte-identical**. The six available catalog archives remain zero. Other inexact
controls retain their counts, including the single card-shadow pixel and the
fractional scaled rectangle's 7,050 differences. This is archived document
viewport conformance; live-site, scrolling and performance acceptance are
unchanged.

The strengthened SVG GPU test compares every published tile-interior pixel of
the unchanged Brave reference at both one and four destination samples, including
the last partial root tile. It replaces the earlier small list of sampled
pixels with exact full-viewport assertions. All **14 focused V functions** and
both Python helper-staging tests pass. Actual GPU draws exercise merge sampling,
source coverage, unsupported transforms, overflowing ink and prior blur hashes.
Compilation and checks use the required 12/3 GiB guards; accepted compiler,
runtime, browser and guard exits are zero. Both full-uBO request-stream checks
also pass: **178 requests each**, all allowed, zero mismatches or oracle
disagreements. The official release ZIP hash and all 59 vendor-file pins verify.

C/O0 diagnostic executable:
`26157dfd3fb1bef1486427a5f6c69036fc9a37f708db82cfcb4015f71e828939`.
The implementation and staged helper match the compiler-read buffer witnesses;
canonical helper, executable/native-library, archive/reference and all **24
runtime Metal shader** hashes stay pinned. Accepted shader text is retained.
The intermediate allocation-only candidate has three isolated-logo differences
and **two** full-page differences, twice. Adding the transparent boundary makes
both exact. Normalized blur sampling, stricter blur arithmetic, source-surface
rounding and final-upload rounding do not remove the baseline 14 logo pixels;
those diagnostics remain local. No unsuccessful experiment remains in the code.

The latest completed production browser at validation is still `0cae86c8`,
which predates both the rectangular-shadow fix and this merge fix. The managed
hooks request a coalesced C/literal V `-prod`, single-unit rebuild. Production
confirmation, historical source/replay qualification gaps and live acceptance
remain open. Raw commands, outputs, screenshots, compiler/guard receipts,
intermediate pixels and SHA-verified cleanup inventory stay ignored under
`docs/performance/verge-filter-20261117/`.

Cleanup SHA-verifies **1,940 evidence files (103,742,671 bytes)** before removing
all **74** owned Build roots. The disk-full recovery also removes completed
programs and generated C before copying evidence: 140,291,536 and 132,699,155
bytes respectively. No `Build/verge-filter*` entries remain. The later catalog
screen and its separate failures do not invalidate the completed merge cohort.


### Remaining forum and news archive screen, 2026-11-17

After completing the Verge fix, a separate nine-site diagnostic screen uses
C/O0 `26157dfd`, cold private caches, full uBO and each archive's recorded
animation/decode preparation. Every completed row below has two fresh Brave
references and one fresh Vox capture. These single Vox captures are preliminary;
no repeatability, live-site, production or performance acceptance is claimed.

| Archive | Vox vs first Brave, pixels | Brave repeat, pixels | Saved source vs first Brave, pixels |
| --- | ---: | ---: | ---: |
| Slashdot | 232,234 | 0 | 0 |
| Stack Overflow | 3,297 | 0 | 0 |
| TechCrunch | 173,970 | 0 | 0 |
| Engadget | 66,383 | 9,363 | 100,163 |
| The Register | 6 | 0 | 0 |

All five completed cases have matching executable/framework identities before
and after, successful document/readiness audits and full-uBO request-stream
checks. The source provenance records Brave **156.1.98.60** while both new
replays use **157.1.99.57**. The source/replay version gate remains open even
where source pixels match; Engadget additionally fails reference repeatability.
Archive bytes, native libraries and all 24 runtime shaders match the initial
pins when recovered after the interrupted run. The later deletion of the
completed executable is recorded separately from those input checks.

Slashdot visibly retains a featured-content card that both Brave replays hide.
The publisher's procedural rules include `.grid_24:has-text(Featured Content)`;
the native audit reports an initialized JavaScriptCore runtime with no JavaScript
diagnostics. Procedural filtering needs further diagnosis. No change to those
filters, their timing budgets, the DOM bridge or the reference has been made.

Pikabu's native process is stopped by the harness's **3 GiB** RSS guard after
56.995 seconds, with a sampled peak of **3,226,632,192 bytes** and exit -9. It
produces no valid completed capture. Slate's request-stream oracle times out in
CDP `Runtime.evaluate`; its native PNG alone cannot establish acceptance. Wired's
attempt is interrupted by filesystem exhaustion, and Discord is not reached.
The outer driver then fails with **errno 28, No space left on device**, leaving
its on-disk exit/guard files empty. Those files and partial logs are retained;
they are not treated as successful receipts. The CLI's returned guard metadata
records outer exit one, with the 12 GiB guard itself not exceeded.

This interrupted screen supplies no all-site pass. Completed C files, programs,
profiles and caches belonging to this job are removed, and the remaining
evidence is SHA-verified before deleting all owned Build roots. The filesystem
still reports about **1.2 GiB free on a 1.8 TiB volume** afterward. Other sessions'
files are untouched. Raw source/reference/native PNGs, audits, commands, failed
receipts, recovered input checks and cleanup inventory remain ignored under
`docs/performance/verge-filter-20261117/`. The successfully completed Verge,
BBC, Guardian and 74-workload merge checks precede this separate failure.
