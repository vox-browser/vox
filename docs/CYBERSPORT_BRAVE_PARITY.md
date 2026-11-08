# Cybersport Dota 2 rendering parity — 2026-11-08

Pixel-perfect parity is **not established**. The latest validated production
capture has **112 differing pixels out of 786,432 (0.0142%)**, down from the
34,104-pixel baseline, with a passing native content audit. All seven focused
pixel fixtures match Brave exactly. The original full-uBlock Brave replay and
its post-capture trace PNG still match the unchanged original reference exactly.
Thirteen engine changes are committed; the final compositor changes need a
production bundle containing their code before their page effect is accepted.

## Captured workload and reference

URL: <https://www.cybersport.ru/tags/dota-2>. Guest page, 1024 × 768 document
viewport, logical capture scale 1, sRGB, empty private profiles, cold resource
cache, bypassed service workers. The reference was captured with the repository's
full uBlock Origin policy, using uBO 1.75.0, rather than an uncontrolled timed ad.
The acquisition audit recorded 306 requests (6 blocked, 300 allowed), zero
policy mismatches, and zero oracle disagreements.

`tools/forum_news_pixels.py::seal_capture` preserves the guest DOM after script
execution, removes scripts, and replays the original resource bytes at their
original origins. It contains 131 responses totaling 6,982,809 body bytes.
This is a frozen first-viewport rendering comparison, not full live scripting
or all-width/all-scroll-position conformance.

Original archive manifest SHA-256:
`dbac179db3d95821e21f23e7ea4c9367591253f147ed7845bc8c3c7446f44135`.

Brave framework version: `156.1.98.60`. Brave executable SHA-256:
`9d53e182ab59b7c430abea0233088cb452694b96843d62ccccbc6c0902b98fe5`.
Full executable, framework, native library, filter-list, resource, and archive
identities are retained in the local evidence.

| Comparison | Differing pixels | Interpretation |
| --- | ---: | --- |
| Baseline Vox vs Brave | 34,104 / 786,432 (4.3365%) | Complete native content audit; original font transport |
| Live Brave vs frozen Brave | 0 | Frozen reference reproduces the acquired live viewport |
| Fresh Brave replay vs reference | 0 | Reference stable across fresh launches |
| Diagnostic Vox vs Brave | 1,544 / 786,432 (0.1963%) | Font transport changed; **not original-source acceptance** |
| Resumed production Vox vs original Brave reference | 496 / 786,432 (0.0631%) | Original archive, unchanged data URLs; content audit passes |
| Second completed production bundle vs original reference | 496 / 786,432 (0.0631%) | Fresh process, original archive; same observed pixels |
| Production with planar video and float SVG strokes | 137 / 786,432 (0.0174%) | Original archive; content audit passes |
| Production with local SVG clips and translucent partial borders | 112 / 786,432 (0.0142%) | Fresh repeated captures; original archive; content audit passes |
| Fresh original-source full-uBlock Brave replay and post-trace PNG | 0 | Original reference SHA-256 unchanged |
| Font precedence regression fixture after fix | 0 / 480,000 | Exact native production capture |
| Fractional skewed-border regression fixture | 0 / 480,000 | Exact native production capture |

The diagnostic moves five embedded font payloads from data URLs to synthetic
archived HTTPS responses, preserving the TTF bytes. Its Brave pixels remain
exactly equal to the live reference. It isolates text/layout from a data-URL
memory failure; it does not excuse changing the original workload for acceptance.
Its manifest SHA-256 is
`ef5ca54017922a7b510efd341476fdedf1ea7866dd0caeaa1b948efe447ae462`.
Remaining diagnostic differences are concentrated in the logo (1,148 pixels)
and login border (285 pixels), with small scattered header/topic differences.
No tolerance or reference was changed to accept them.

## Committed fixes and verification

| Commit | Change | Focused checks |
| --- | --- | --- |
| `f95b64fc6` | Later matching Chromium font-face definitions and subsets take precedence; preserve LibWeb policy | 34 font test functions pass with GC and `-gc none`; native font fixture changes from 11,770 differing pixels to zero |
| `38fbc0bb1` | Decode VP8/VP9 WebM alpha through libvpx | Exact alpha before/after seek, opaque control, lazy loading and missing-file cleanup pass |
| `dcb2b5f47` | Install and refresh cosmetic filtering in hosted child documents | Static/dynamic and timer-driven filtering, repaint and child-load error checks pass (5 test functions) |
| `fad7eade5` | Decode embedded base64 resources with one byte buffer | 11 fetch test functions pass with GC and `-gc none`, including a 256 KiB embedded font payload |
| `dd4820a92` | Fetch video-only WebM through Vox's resource loader and play with persistent FFmpeg decoding | Browser selection of extensionless typed sources, transparent paused preview and unchanged-frame polling pass for VP8/VP9; native pause/seek/rate/endpoint/loop checks pass |
| `16367b22f` | Use Chromium's BT.601 and 2×2 chroma sampling for untagged WebM | Odd 3×3 chroma, known RGB values, straight alpha and opaque controls pass; VP8/VP9 playback checks pass |
| `6cee2ab4b` | Snap fractional transformed borders in local paint coordinates | 13 border/background test functions pass; small and full-page-position native pixel fixtures match Brave exactly |
| `7240aa1df` | Retain WebM Y/U/V/A planes through GPU sampling; preserve RGBA canvas access and alpha-aware cache identities | 9 browser/frame-model tests pass; native VP8/VP9 tests pass; actual compressed-video GPU crops match Brave exactly at 34×34 and 65×65; alpha-only byte/digest/raster/decode invalidation checks pass |
| `85ad3bb29` | Keep SVG stroke widths in float user units under Chromium painting | 2 focused stroke tests and 3 existing root-SVG paint-offset tests pass; LibWeb rounding preserved; GPU probe confirms the chevron's two-pixel difference disappears with a 1.2px stroke instead of 1.1875px |
| `93ce20867` | Share translucent partial rounded-border coverage and retain computed alpha | 3 layout test files pass; the 16-pixel corner reproduction becomes exact in production |
| `91dca8af3` | Keep opaque rectangular SVG image clips in local GPU recordings | Model, mask and shared-recording checks pass; final opaque clip fixture is exact; 9 full-page edge differences disappear |
| `4399170f9` | Preserve surrounding compositor geometry metadata around bounded atomic blend groups | New blend test and existing metadata test file pass; production page validation pending |
| `b76472b76` | Record curved SVG strokes using complete native stroked-path bounds | 2 compositor test files pass, including round caps/joins, quadratics, cubics, arcs, and retained dash/non-scaling fallbacks; production validation pending |

Existing native MP4 and HTTP HLS playback tests also pass, including frames,
seeks, rates, endpoints, repeated loop restart, error and cancellation paths.
WebM resources containing audio are rejected until a WebM audio sink exists;
declared unsupported audio codecs are not advertised as playable.

Brave's canvas readback of the actual 65×65 WebM logo independently confirms the
conversion diagnosis: libyuv BT.601 matches every fully opaque RGB channel and
every alpha value exactly. Later production captures also match the complete
transparent-video pixel fixture, including its screen-blended crops.

## Resumed production and live checks

The original archive was restored from the verified local evidence, without
changing its manifest or resource bytes. Production receipt
`20261108-054401-91d67216`, executable
`fa3b82a3b41d07243bc05c3dcb45a54222f1645afd2ce02b8050b9e123ab7dd6`,
contains the first seven fixes. A fresh process captures the page successfully,
exits zero, passes the content audit and has 496 differing pixels. It also
matches the font precedence fixture exactly. Its capture guard observes
1,362,673,664 bytes peak process-tree RSS; the earlier embedded-font memory
failure no longer occurs in this run.

Production receipt `20261108-060445-7df1d8ac`, executable
`692d893aa761c77d6f8fc6eb50db183accd230bbe40edbb9e6f738b3a817ce9d`,
repeats the same 496-pixel result and passes the content audit. The normal
skewed-border fixture and a diagnostic placing the border at its full-page
coordinates both match Brave exactly. These builds predate the planar-video
and float-stroke fixes. No full-page pixel result is attributed to code absent
from its executable.

The 496-pixel difference comprises 357 logo pixels, 28 login-outline pixels,
78 other primary-header pixels, 2 secondary-header chevron pixels, and 31
scattered content pixels. Isolated diagnostics identify two remaining causes:

- Converting video to RGBA before scaling loses the GPU's separate chroma and
  alpha sampling. Direct YUVA draws match both the actual site's logo and the
  independently generated odd-sized WebM reference at natural/reduced sizes.
- The layout accessor truncates a 1.2px SVG stroke to 1.1875px. Keeping the
  float user-space width reproduces Brave's chevron samples. The existing
  outer-SVG origin snapping remains correct.

These direct GPU results do not establish that all remaining full-page pixels
are corrected. The committed video reference includes screen-blended crops;
the standalone GPU check validates only its two normal source-over crops.

A fresh live-URL attempt on `692d…` timed out at 120 seconds without a capture.
A separate diagnostic fresh process, with readiness tracing and an observation
timer enabled, subsequently captures the live URL successfully: exact requested
URL/title, `complete` readiness, 1024×768 viewport, zero reported native errors,
browser/guard exit zero and unchanged executable/native-resource identities.
It observes pending image downloads and interactive document readiness before
reaching readiness. Both attempts are retained. This validates a successful live
load, not live cross-browser pixel equality or complete scripting parity.

## Later production and compositor findings

Receipt `20261108-064807-93bb0c84`, executable
`468f7a4d650bf9880564cc40be5d8c60221ac769a9097714e639f499bb8b5201`,
contains the planar-video and float-stroke code. Its original-source capture
has 137 differing pixels and passes the content audit. All four pixel fixtures
then present pass exactly. The 357 WebM logo and two chevron differences are gone.

Receipt `20261108-072002-e3db71fa`, executable
`843893a4a6f9e8f235b9fe36cb4184e3df6c038dbf41370f219dcecdc1581bd2`,
contains the local SVG clip and partial-border code. It removes nine SVG
clip-edge pixels and 16 rounded-menu corner pixels, reaching 112 differences.
A fresh repeat gives the same result. Both captures pass the native content
audit, with unchanged executable, native/runtime assets, archive and original
reference identities. Builds use one C unit, literal production V and prealloc.

The seven final pixel fixtures cover font precedence, skewed borders, WebM
planes, float SVG stroke widths, rectangular SVG clips, translucent partial
rounded borders and blended-video metadata. The last is a compatibility case;
its model test independently verifies the previously discarded metadata.
All seven match their committed Brave references exactly on the latest
completed bundle. An early uncommitted clip probe also included
translucency and CSS scaling; its failures are retained. The final clip change
keeps those cases on their existing replay and admits opaque rectangular scopes.
The original site reference and zero-error acceptance rule were never changed.

One remaining SVG pixel differs by 56 channel values; the other 111 differences
are at most three. An instrumented post-capture trace of the original full-uBlock
Brave page preserves the reference PNG exactly and records independent
transparent compositor rasters for the header decorations and static SVG.
Its static SVG surface is 163 by 34 at (12, 8), with a (12, 9) paint origin.
Replaying that actual SVG picture through Vox's bundled Dawn backend matches
its entire text region exactly. At (107, 28), premultiplied RGBA
(191, 191, 191, 191) composites to Brave's (199, 200, 203). For this SVG sample, the surface boundary explains the mismatch rather than
the SVG path decoder. Other differences still require production verification.

The planner discarded surrounding geometry metadata at the video logo's screen
blend group. The metadata fix preserves that group as one atomic native run
while retaining the surrounding compositor geometry. Another eligibility fix
admits curved strokes into complete pictures, which use Skia's stroked bounds;
scalar batches and dashed/non-scaling paths keep their guards. These changes
pass focused model checks but still require a published browser capture.

A default fresh live capture on `843893a4…` succeeds without readiness tracing:
requested URL/title, complete readiness, 1024 by 768 viewport, zero reported
native errors, browser/guard exit zero and unchanged identities. Its guard
observes 2,467,938,304 bytes peak RSS and 42.5 seconds through capture and
teardown. This verifies a successful live load, not live cross-browser pixel
equality or isolated rendering time.

A changed-workload diagnostic replaces the video's screen blend with normal
blend and an opacity promotion hint. Brave preserves all pixels outside the
video rectangle; the available Vox bundle retains 112 differences outside it.
The changed workload has 236 cross-browser differences overall and is not
original-source acceptance. This diagnostic does not validate the committed
metadata change or establish that it alone resolves every remaining pixel.

The requested full-frame GPU-canvas diagnostic actually executes but worsens
the earlier 137-pixel result to 2,692 pixels. It is retained as a failed
diagnostic. No performance claim or relaxed pixel acceptance follows from it.

## Earlier production blockers and outstanding acceptance

At the first checkpoint, the baseline executable SHA-256 was
`7b499a1f6ed787eae5785ab953c1d119ec5867d3c50ed88a35d1948ac33b12a4`
(production receipt `20261108-032631-fbb6609c`). The newer available executable then was
`c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`
(receipt `20261108-040315-4aba4e3c`, single C unit, production V, prealloc).
Its sealed compiler input contains the font precedence, frame-filtering and
stateless alpha fixes, but not the later changes above.

Fresh captures of the original archive on that newer executable hit the memory
guard before producing a PNG: 3.65 GB with the 3 GiB guard, and 13.50 GB with the
default 12 GiB guard. A tiny page containing one actual embedded Roboto font
reproduced the problem. The old forgiving-base64 decoder appended one character
to a growing string, retaining quadratic temporary storage under prealloc.
At that checkpoint the buffer fix had only focused checks; the later
original-source production captures above complete end-to-end verification. Both failed capture attempts and their unchanged identities are
retained, not retried into an acceptance claim.

Shared production builds after that bundle repeatedly failed with
`Repository inputs changed before C preprocessing`. No duplicate production
build was queued for this session. The existing completed bundle was used for
all checks it could exercise. `shared-build-status.json` in the evidence records
the observed receipts, actual exits and pending build state.

Live Vox checks on the older bundle did not produce a valid capture: one timed
out, and a clean private profile reached the 3 GiB guard after first paint.
Those older failures remain recorded; the later default live capture above
establishes a successful load on the newer executable.

Before accepting parity, use a fresh published process containing all final
fixes. Replay the **original** archive, require zero differing pixels and a
passing native content audit, rerun all seven pixel cases, then check the live
URL with an empty private profile and matching blocking policy. Record all
identities before and after. The latest bundle cannot validate the final
compositor changes it does not contain.

After the 112-pixel bundle, shared builds repeatedly fail on concurrent input
changes. Transient Trusted Types and raster type errors were also observed;
those errors had already been corrected in the working tree when inspected.
A coalesced request was made after evidence that no available bundle contained
the metadata fix. The existing bundle remains the basis for applicable checks;
no copied source checkout/private browser bundle or bypassed guard was used.
The evidence records every observed receipt and its actual exit.

## Local evidence and commands

Raw captures, frozen responses, exact pixel metrics, request and DOM audits,
commands, guard receipts, failed attempts and temporary diagnostic helpers are
sealed locally in `docs/parity/raw/cybersport-parity-20261108.tar.gz` (ignored;
never committed). The [evidence manifest](parity/cybersport-parity-20261108.json)
records its SHA-256 and verified file inventory. The per-job
`Build/cybersport-parity-20261108-001` directory is removed
after sealing. This report does not depend on an untracked replacement reference.

The follow-up captures, commands, audits, successful and failed diagnostics,
original Brave compositor trace and build receipts are sealed separately in
`docs/parity/raw/cybersport-parity-20261108-followup.tar.gz`, described by the
[follow-up manifest](parity/cybersport-parity-20261108-followup.json). Archives
remain ignored and local; only reports and manifests are committed. The owned
`Build/cybersport-parity-20261108-002` job is removed after sealing and verifying
its inventory.

Key focused commands (each run through `tools/run_memory_bounded.py`):

```sh
v -b c -memory-limit 10G -enable-globals -cc clang test \
  css/font_face_precedence_test.v css/font_cascade_test.v css/font_rule_lifecycle_test.v
v -b c -memory-limit 10G -enable-globals -cc clang -gc none test \
  css/font_face_precedence_test.v css/font_cascade_test.v css/font_rule_lifecycle_test.v
v -b c -memory-limit 10G -enable-globals -cc clang test \
  fetch/data_url_buffer_test.v fetch/infrastructure_test.v
v -b c -memory-limit 10G -enable-globals -cc clang -gc none test \
  fetch/data_url_buffer_test.v fetch/infrastructure_test.v
VJOBS=1 v -b c -memory-limit 10G -enable-globals -cc clang test \
  layout/chromium_fractional_transformed_border_test.v \
  layout/chromium_local_border_shadow_test.v layout/chromium_local_background_test.v
python3 tools/test_native_webm_playback.py --output OUTPUT
python3 tools/test_native_media_playback.py --output OUTPUT
```

Root-browser tests require `-d vox_ui2` and staged UI2/HTTP module paths.
`media/webm_playback_test.v` also requires `-DLADYBIRD_V_HAS_FFMPEG`, the pinned
vcpkg include directory, and its library rpath. Exact expanded commands and exits
are retained in `webm-v-r2-guard.json`, `child-adblock-final-guard.json`,
`child-load-retry-guard.json`, and `child-tests-serial.log` (the repaint row).
All successful final focused jobs exit zero. Earlier configuration, assertion,
memory-limit and timeout failures remain in the archive with their outcomes.
