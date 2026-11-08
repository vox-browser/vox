# Cybersport Dota 2 rendering parity — 2026-11-08

Pixel-perfect parity is **not established**. Seven focused fixes are committed.
The available production browser validates the font precedence fix, but does not
contain the subsequent embedded-font decoder, WebM playback, color conversion,
and fractional border fixes. Their focused checks pass; final production pixel
and live-page checks remain pending.

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
| Font precedence regression fixture after fix | 0 / 480,000 | Exact native production capture |

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
| `6cee2ab4b` | Snap fractional transformed borders in local paint coordinates | 13 border/background test functions pass; Brave reference fixture added; production pixel run pending |

Existing native MP4 and HTTP HLS playback tests also pass, including frames,
seeks, rates, endpoints, repeated loop restart, error and cancellation paths.
WebM resources containing audio are rejected until a WebM audio sink exists;
declared unsupported audio codecs are not advertised as playable.

Brave's canvas readback of the actual 65×65 WebM logo independently confirms the
conversion diagnosis: libyuv BT.601 matches every fully opaque RGB channel and
every alpha value exactly. This does not establish equality of the final scaled,
blended logo in a production page capture.

## Production and live validation still required

The initial baseline executable SHA-256 was
`7b499a1f6ed787eae5785ab953c1d119ec5867d3c50ed88a35d1948ac33b12a4`
(production receipt `20261108-032631-fbb6609c`). The newer available executable is
`c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`
(receipt `20261108-040315-4aba4e3c`, single C unit, production V, prealloc).
Its sealed compiler input contains the font precedence, frame-filtering and
stateless alpha fixes, but not the later changes above.

Fresh captures of the original archive on that newer executable hit the memory
guard before producing a PNG: 3.65 GB with the 3 GiB guard, and 13.50 GB with the
default 12 GiB guard. A tiny page containing one actual embedded Roboto font
reproduced the problem. The old forgiving-base64 decoder appended one character
to a growing string, retaining quadratic temporary storage under prealloc.
The buffer fix passes focused checks but requires a newer browser for end-to-end
verification. Both failed capture attempts and their unchanged identities are
retained, not retried into an acceptance claim.

Shared production builds after the available bundle repeatedly failed with
`Repository inputs changed before C preprocessing`. No duplicate production
build was queued for this session. The existing completed bundle was used for
all checks it could exercise. `shared-build-status.json` in the evidence records
the observed receipts, actual exits and pending build state.

Live Vox checks on the older bundle did not produce a valid capture: one timed
out, and a clean private profile reached the 3 GiB guard after first paint.
Consequently this report makes no live-site fix claim.

Before accepting parity, use a fresh process from a successfully published
bundle whose sealed inputs contain all seven commits. Replay the **original**
archive, require zero differing pixels and a complete native content audit,
rerun the font and skewed-border pixel fixtures, then verify the live URL with
an empty private profile and matching blocking policy. Record identities before
and after each run. The final scaled WebM logo and the scattered diagnostic
pixels remain acceptance questions until that capture succeeds.

## Local evidence and commands

Raw captures, frozen responses, exact pixel metrics, request and DOM audits,
commands, guard receipts, failed attempts and temporary diagnostic helpers are
sealed locally in `docs/parity/raw/cybersport-parity-20261108.tar.gz` (ignored;
never committed). The [evidence manifest](parity/cybersport-parity-20261108.json)
records its SHA-256 and verified file inventory. The per-job
`Build/cybersport-parity-20261108-001` directory is removed
after sealing. This report does not depend on an untracked replacement reference.

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
