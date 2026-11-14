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
