# Old Reddit /r/europe instruction reduction, 2026-11-07

On a frozen `/r/europe/` workload, the Vox median fell from **5,870,338,864**
to **4,895,716,560** observed retired instructions between two seven-run
cohorts: **16.60% fewer** by the ratio of medians. The highest final count is
15.13% below the lowest baseline count. Every capture in all three cohorts
below is pixel-identical to the same fixed Vox reference.

| Run | Baseline | Final | Same-binary control |
| --- | ---: | ---: | ---: |
| 1 | 5,915,809,897 | 4,945,238,043 | 5,782,153,178 |
| 2 | 5,919,898,014 | 4,925,770,261 | 5,735,951,756 |
| 3 | 5,905,253,815 | 4,913,355,079 | 5,783,831,733 |
| 4 | 5,870,338,864 | 4,895,518,221 | 5,726,288,126 |
| 5 | 5,841,292,203 | 4,887,410,575 | 5,720,901,601 |
| 6 | 5,831,130,101 | 4,895,716,560 | 5,740,703,465 |
| 7 | 5,827,028,118 | 4,890,349,305 | 5,748,734,014 |
| **Median** | **5,870,338,864** | **4,895,716,560** | **5,740,703,465** |

No observation was retried or excluded; all browser and guard exits are zero.

## Attribution

The baseline is the shared `Build/v/Vox.app` built at 16:46 (executable
SHA-256 prefix `99dd89f79c418afe`). The final and control cohorts use one
private single-C-unit build of the canonical tree that includes `910255d60`
(prefix `30fbbb778af67966`); the control sets
`VOX_DISABLE_IMAGE_DISK_CACHE_RETENTION=1`. The fix accounts for
**844,986,905 instructions (14.72%)** against that same-binary control.
The remaining 129,635,399 between the baseline and control medians comes from
other sessions' commits in the intervening two hours and is not credited here.

`910255d60` keeps disk-cached image responses for the first frame. Vox
replays JPEG, WebP and color-managed PNG `<img>` pixels from their response
bytes through `background_image()`, not from the decoded image model (only
profile-free PNG bitmaps are shared with native replay). The image loader
decoded a synchronous disk-cache hit for the model but left the response out
of `app.resource_cache`. The first document replay therefore requested each
visible thumbnail again, painted it blank, and the arrival bumped the
document's paint revision, so the next frame replayed all 1,545 paint commands
a second time (about 870M instructions, 250 ms of CPU raster at 2× backing
scale). The loader now keeps a persistent copy of each disk-cache response and
`poll_browser_image_requests()` retains it before the frame paints, as it
already did for asynchronous completions. The next frame reuses the stationary
raster. Peak root footprint also falls from about 680 MB to 661 MB.

Found with frame markers (`VOX_DIAGNOSTIC_FRAME_PARTS=1`), load stages and
lldb breakpoints on `native_begin_stationary_raster_snapshot` (paint revision
`0x109f` → `0x10a0` between painted frames with an unchanged paint generation)
and `BrowserApp__request_background_resource`, which showed the four
`external-preview.redd.it` thumbnails requested from inside the first replay.

## Verification

`resources/async_images_test.v` passes 5 of 5, including the new
`test_static_disk_cached_image_response_reaches_the_replay_cache_before_paint`.
Eight related image/resource test files pass (34 functions:
lazy, remote, CORS, poll-storage, preloaded and resource images, initial image
completions and resources). `resources/request_image_reuse_test.v` does not
compile on its own before or after this change: it uses `asymmetric_raster_png`,
defined only in `paint/raster_orientation_test.v`. With the final private
bundle (`SCREENSHOT_BROWSER`, added to `capture_screenshot.sh` for this),
all 11 default screenshot smoke cases pass: 8 exact and 3 within their
established tolerances. The frozen viewport is pixel-exact in every
observation, with and without the kill switch.

## Remaining costs seen

- Steady-state replay of this viewport is CPU raster at 2× scale: about 750M
  main-thread instructions for one frame, mostly blurred box shadows (about
  4M each, 74 per frame) and large fills. The first replay adds about 1.2B of
  one-time initialization (pipelines, glyphs, image decoding).
- Style (`build_boxes`) costs about 670M; parsing the 18 stylesheets (no
  duplicates; `reddit.css` is 306 KB) about 325M.
- On a live first visit, an image whose loader request is still in flight can
  likewise be requested a second time by replay; this frozen workload does not
  exercise that path.

## Workload, scope and reproduction

The page was fetched on 2026-11-07 with the already imported Reddit session
(source SHA-256 `99c069cea2ac09aab516479f4bcb88dbf7742df0d1ddafe41989337c993eaf52`).
Freezing removes all 17 script elements and installs the original base URL
(`03e5c53d29f0256ef7a3d13ccd7ad7021def72c531f508b4bdf203399db50212`). One
networked Vox run populated a private resource cache of 44 responses, which
every observation replays from a fresh copy under a process-local network
deny library. Audits verify the `Europe` title, complete readiness, the
1024×768 viewport and all 25 post IDs in order. Vox selects JavaScriptCore;
no page script runs, so this measures startup, style, layout and painting.

Counters are `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions` for the Vox
process tree, sampled every 5 ms from launch through capture, audit and exit;
they are polling lower bounds and exclude GPU and outside services. One-minute
loads were 14.0–14.5 (baseline) and 17.8–19.9 (final and control) on 18
logical CPUs; the 12 GiB guard observed peaks of 784, 838 and 857 MiB.

No Brave cohort is claimed: Brave's capture of the thumbnails differed from
its own earlier capture by 2,603 pixels, so it cannot hold a fixed reference.
Two diagnostic Brave runs observed about 10.1–10.2B instructions. The driver
gained `--vox-only`, `--baseline-summary` and `--vox-env` for this reason
(`c9bbf89ab`, `09879b39d`), and replays query-string assets under Vox's
`raw-request-uri-v1` cache key (`b70593c61`). Raw counts and PNG hashes are in
[the durable record](performance/old-reddit-europe-reduction-20261107.json);
the account-bearing page, cache and PNGs are not committed.

```sh
D=Build/reddit-europe-UNIQUE   # frozen.html, cache/, references/vox.png, network-deny.dylib
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py --lock Build/reddit-europe-UNIQUE.lock \
    --report Build/reddit-europe-UNIQUE-guard.json -- \
  python3 tools/reddit_browser_instructions.py --html $D/frozen.html \
    --expected $D/references/vox.png --expected-vox $D/references/vox.png \
    --cache $D/cache --output $D/final --network-deny $D/network-deny.dylib \
    --diff-tool Build/pixel-tools/pixel_diff --repeat 7 --required-reduction .10 \
    --vox-only --baseline-summary $D/baseline/summary.json
# Same-binary control: add --vox-env VOX_DISABLE_IMAGE_DISK_CACHE_RETENTION=1
```
