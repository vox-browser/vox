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
