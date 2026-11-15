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
