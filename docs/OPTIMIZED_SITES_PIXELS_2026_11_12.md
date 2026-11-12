# Optimized-site pixel audit, 2026-11-12

**The all-site pixel-equality gate remains open.** The initial audit below
found five differing sites and an unverified Reddit workload. Subsequent fixes
now make the registered Lobsters page pixel-exact in two fresh production
captures; see the corrective results below. Wikipedia still differs at 445
pixels in its current baseline. This is a rendering correctness audit, not a
new instruction or scrolling benchmark. Existing references, zero-error gates
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
any CPU/FPS result. The all-site task remains open. Wikipedia's current two
captures still differ at 445 pixels (443 in its Persian article-count line and
two in the wordmark); that is the next corrective investigation.
