# Dota 2 patch 7.42a scrolling

The live page stalled while Vox sent empty CSS filter layers to Core Image.
Vox now checks the entire isolated bitmap before running a single blur or drop
shadow. An empty bitmap can be discarded. A nonempty source keeps the full
filter path, including content outside the destination clip that can cast a
shadow inside it. Focused output comparisons are pixel-exact. Live scrolling
still has long frame gaps. [Dota 2 patch 7.42a](https://www.dota2.com/patches/7.42a)

## Live baseline

Two fresh launches used direct live HTTPS, private empty profiles and HTTP
caches, retained OS caches, automatic JavaScript policy, and a 1024×768
document viewport at backing scale 2. A startup probe requested redraws until
the patch title appeared to get past the earlier script wake bug in this
bundle. Input started ten seconds after the matching title. A separate audit
confirmed the patch document at complete readiness, JavaScriptCore executing
in its native context, and 15,620 UTF-8 bytes in the rendered React root.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing publication gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.28 | 1,818 / 1,916 / 1,916 ms | 2/2 | 240 / 5 | 33.87 Hz | 3,154 / 266 ms |
| 2 | 0.32 | 1,430 / 1,435 / 1,435 ms | 2/2 | 240 / 5 | 38.26 Hz | 2,046 / 1,342 ms |

The probe sent 240 precise wheel events at a nominal 60 Hz with delta 8,
reversing every 80 inputs. The endpoint is completed native frame installation
after the outer view paint. Rates count scroll changes over the whole input
window of 7.057 and 6.248 seconds. Physical display scanout was unmeasured.
The 18-CPU host's one-minute load was 49.08→63.17 and 63.17→52.74.
Both browser and driver exits were 0. The shared baseline guard exited 0
and peaked at 2,048,557,056 bytes against its 3 GiB budget.

```sh
VOX_TEST_WINDOW=1 MallocSpaceEfficient=1 sh tools/run_v_tool.sh run_memory_bounded \
  --lock "$job/live.lock" --report "$job/live-guard.json" --limit-gib 3 -- \
  python3 tools/measure_precise_scroll.py \
  --output "$job/native-1" --url https://www.dota2.com/patches/7.42a \
  --require-title 'Dota Patch Notes - 7.42a' --script-policy automatic \
  --width 1024 --height 768 --inputs 240 --delta 8 --reverse-every 80 \
  --settle-seconds 10 --timeout 32 \
  --network-policy 'Direct live HTTPS, empty private HTTP cache and profile, OS caches retained' \
  --insert-library "$startup_probe"
```

The single-unit C production build was based on `4b4019fcc`. Its executable
SHA-256 was `dc25eab492d3658b87caab0ba56e9c7021ab1573b18822fc95477c88b4f534af`.
The AVIF helper SHA-256 was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.

## Diagnostics and checks

- The 12 ms stack probe filled its 1,024-sample buffer and dropped 154 samples.
  Its browser exited 0 and its driver rejected the timing. In the captured
  portion, 661 snapshots were in CSS filter completion and 426 were in its
  rendering path. Raster logging separately showed complete replay during
  large image-driven damage followed by scroll-raster reuse. Shadow and
  background drawing still appeared in slow reused frames.
- A shorter 120-input run logged 172 single-operation Core Image renders of
  2048×1760 pixels during scrolling. A separate caller-checked bitmap probe
  found 172 all-zero inputs of that size in its scrolling window. The
  bitmap-probe browser and guard exited 0. Its driver rejected timing because
  too few publications fell inside the input window. The stack and bitmap
  traces are diagnostic.
- Existing tight-input, sparse-input and color-filter-cache switches produced
  no compact input in their sampled scroll windows. The three browsers
  exited 0. The driver rejected their timing because each sampled too few
  publications. Cropping prototypes changed rendered pixels in the drop-shadow
  fixture and were discarded.
- The focused native fixture passed 160 pixel-exact frame comparisons in
  each of the optimized and ASan/UBSan runs. It verified 56 avoided Core Image
  submissions per run, including eight blur or drop-shadow submissions. Both
  runs used the 3 GiB guard and exited 0.
- The existing drop-shadow color fixture passed all 3,072 comparisons.
  The filter source fixture passed ten exact comparisons, the SVG turbulence
  checks, and 200 filtered Retina frames with a 673,513,472-byte peak RSS.
  Both fixtures and their 3 GiB guard exited 0.

## Browser memory

A fresh window on the `4b4019fcc` build reached 1,923,502,760 bytes of sampled
physical footprint at 25.12 seconds. The median was 1,318,506,912 bytes at
62–72 seconds. The window used the live baseline's network, scale and profile
settings. Fourteen native page-up and page-down events ran from 23.33 to 38.61
seconds, followed by idle time. `proc_pid_rusage` sampled the browser process
tree from launch through 73 seconds. The endpoint capture confirmed complete
readiness and the same 15,620 bytes of React-root text. Browser, driver and
memory guard exited 0. The guard's sampled sum of RSS peaked at 2,038,661,120
bytes. The guard measures resident size and can count shared pages twice.

A separate mapping trace matched `mmap` addresses from callers in the Vox
executable to dirty mappings in a 12-second `vmmap` snapshot. Around 330 MiB
was first allocated in shadow rasterization, including around 165 MiB whose
mapping began at the four-channel float mask allocation. The arena can reuse
mappings after their first allocation, so the trace identifies allocation
sites. A diagnostic reload reached a second document parse and then exited
139 in nested JavaScriptCore XHR header handling. The driver and guard exited
0. The reload could not establish memory retention across reloads.

The rectangular-shadow compute pass now shares its Metal `R32Float` texture
with the paint shader. For the largest supported tile, this avoids a 16 MiB
CPU readback, a 64 MiB CPU staging array and a 64 MiB RGBA texture upload.
The original rectangular-card shadow pixel tolerance passed with and without
MSAA. The colored-shadow test also verified premultiplied channels on the
interior and the blurred edge. The rectangular shadow checks passed in the
default, `-prod -gc none`, and staged production `-prod -gc none -prealloc`
configurations and with Metal API validation enabled. The default run also
passed the blurred-shadow and pooled leaf-surface checks. An initial
`-prealloc` test with the unstaged compiler
exited 139 in `stbi` while loading the reference PNG. The staged production
rerun supplied the compiler and runtime used by the browser build. All checks
ran under the 3 GiB guard. Live memory with the texture change is pending.

## Follow-up scrolling baseline

The next completed single-unit `-prod` build, based on `4aad4baa6`, included
the parser wake and empty-filter fixes. Vox reached the patch title without
the startup probe. The same wheel command and conditions as above used a
40-second timeout and omitted `--insert-library`.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap | Peak sampled RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 28.74 | 17.17 / 111.44 / 319.62 ms | 79/140 | 240 / 225 | 49.07 Hz | 139.81 / 70.72 ms | 1,765,474,304 bytes |
| 2 | 28.92 | 16.99 / 106.31 / 323.42 ms | 80/143 | 240 / 236 | 48.34 Hz | 139.33 / 97.81 ms | 1,745,305,600 bytes |

The complete input windows were 4.871 and 4.944 seconds. The 18-CPU host's
one-minute load was 18.38→26.10 and 29.46→34.39. Browser, driver and guard
exits were 0 for both trials. The executable SHA-256 was
`2bf74b5de62aaf33a0b2e1c538bab9bda8afe89fecb8af683dd218d42e2b3849`.
The AVIF helper SHA-256 was unchanged and the adblocking worker SHA-256 was
`42b2b7c042058cc1fbff8025ea67f83922036683efd40b103050bac05097551c`.
The bundled changes and varying host load limit attribution across baselines.

An endurance diagnostic changed the wheel schedule to 3,000 inputs with a
reversal every 650 inputs. An audit nine seconds after launch confirmed
complete readiness, JavaScriptCore, the 1024×768 Retina viewport and the same
15,620-byte React root. The browser handled all inputs and completed 844
publications. It averaged 9.36 scroll-changing publications per second over
the 75.067-second input window, with a median interval of 126.91 ms, p95 of
180.19 ms, and maximum of 317.93 ms. Of 703 intervals, 605 exceeded 16.67 ms.
Input arrived at 39.95 Hz and the leading and trailing scroll publication
gaps were 153.81 and 73.04 ms. The 18-CPU host's one-minute load rose from
53.89 to 161.23 during this run. Browser, driver and 12 GiB guard exited 0.

The guard measured 2,044,674,048 bytes of peak RSS from launch. A separate
physical-footprint observer covered the final 41.64 seconds with 268 live
samples. Its observed peak was 2,227,933,936 bytes. The median for the first
33 samples was 2,027,409,920 bytes and the median for the last 33 samples was
2,085,245,608 bytes. The fresh Dota tab stayed below 5 GB in this diagnostic.

A separate stack sample on the same build used 240 inputs, delta 48, and a
reversal after 190 events. It sampled stalls at 17 ms and observed 19 stalled
frames with 949 snapshots and zero dropped samples or failures. Of the
snapshots, 397 included portable shadow replay and 192 included the float-mask
upload path that the texture change replaces. Another 170 were in the
empty-layer scan and 117 in tiled CSS gradient drawing. The browser, driver and
3 GiB guard exited 0. This instrumented run verifies the old shadow path was
active during scrolling.

## RAM target against Brave

The comparison uses the simultaneous sum of macOS task physical footprints
for an isolated browser process tree, including renderer and GPU helpers.
The settled result is the median of the final three seconds, twelve seconds
after the ready-document audit. The sampled peak runs from process launch
through that same endpoint. The sampler polls every 50 ms and can miss short
peaks or helpers that exit between samples. The 12 GiB guard measures RSS
separately to bound the job.

The first alternating diagnostic used fresh private profiles and HTTP caches,
direct live HTTPS, default content blocking and author JavaScript. It matched
the 1024×768 document viewport and backing scale of two. Brave used its CDP
viewport override and Vox used its native viewport. Vox's native audit and
Brave's CDP audit verified the patch title, complete readiness, visible
document, loaded fonts, and 133 patch image elements. Vox had 15,620 bytes of
React-root text and Brave's initial audit had 15,236 bytes. A follow-up Brave
audit had 15,620 bytes and matched Vox byte for byte after normalizing the
39 UUIDs generated in inline CSS class names. These live runs did not pin
server responses or compare final pixels.

| Browser and run | Settled footprint | Sampled peak footprint |
| --- | ---: | ---: |
| Vox 1 | 1,134,235,800 B | 1,566,118,736 B |
| Brave 1 | 393,453,512 B | 865,723,584 B |
| Brave 2 | 385,949,616 B | 888,922,008 B |
| Vox 2 | 1,251,397,808 B | 1,663,176,904 B |

The baseline Vox executable was from the single-unit C production build
based on `086d79a4c`. Its SHA-256 was
`4575782cafab004239ad56713933582762b7bc3f6806e876129c061e8e1cbfac`.
Brave reported Chromium `158.0.8127.42`. Each Vox trial ended with a deliberate
SIGTERM after sampling. Both Brave instances exited 0 via `Browser.close`.
The guard exited 0 and observed a peak 1,560,805,376 bytes of aggregate RSS.
One-minute host load at the start of the four trials was 5.30, 6.21, 5.68,
and 6.19 on 18 CPUs.

One Vox snapshot had 825.3 MiB of dirty anonymous memory. A probe on the
following production build (`f67d4df3e`, executable SHA-256
`dcbf80bcd447a22cccab9dec1709ca927f7fb7e773f21f825fd9ffda2fce382f`)
identified 638.6 MiB of cursor-used allocation in the native document arena.
The probe traced the allocations that currently owned each block, including
recycled blocks. Major growth sites included collecting measurement inputs
(62.7 MiB), flex measurement recording (57.1 MiB), and several line-box and
descendant snapshot copy sites. These figures attribute the filled blocks to
the caller that grew the arena and can include later allocations in those
blocks. The recycled-block pool itself held 16.9 MiB at that snapshot.

A diagnostic on that build disabled flex and grid measurement reuse with
`VOX_DISABLE_FLEX_MEASUREMENT_REUSE=1` and
`VOX_DISABLE_GRID_MEASUREMENT_REUSE=1`. It settled at 902,959,064 bytes and
peaked at 1,339,691,736 bytes with a complete patch audit. This demonstrates
the scale of the cache cost while the remaining footprint still exceeds the
Brave baseline. The production behavior must retain the layout algorithms
and document content. The comparison target remains open.

### Retiring flex and grid measurement storage

Flex and grid measurement inputs, rejection maps, and geometry snapshots now
share an arena owned by one layout pass. Committed layout copies the lines,
glyphs and other geometry it consumes before the pool releases its arena.
Temporary measurements can still reuse the same snapshot during the pass.
The recorded cache also avoids a duplicate copy of line-box data.

A second alternating diagnostic exercised the completed `-prod` build with
this change present in its compiled source. It used a minimum nine-second
readiness checkpoint in both browsers, then the same twelve-second settle
window. All four runs audited 133 image elements and 15,620 bytes of root
text. Their normalized content SHA-256 was
`58c17e85055d216d501de74d27b945582d45c17c1fd87d2408c9dc242d82c9da`.
The browser and driver exits were 0 in all four runs. The 3 GiB guard exited
0 with an observed peak 1,195,425,792 bytes of aggregate RSS.

| Browser and run | Settled footprint | Sampled peak footprint |
| --- | ---: | ---: |
| Vox 1 | 882,642,928 B | 1,329,320,664 B |
| Brave 1 | 404,586,536 B | 1,162,158,240 B |
| Brave 2 | 387,145,648 B | 886,202,192 B |
| Vox 2 | 891,588,568 B | 1,321,341,608 B |

The Vox median was 887,115,748 bytes, compared with 395,866,092 bytes for
Brave. One-minute load at trial start was 6.88, 8.90, 9.70, and 11.60 on
18 CPUs. The earlier Vox median was 1,192,816,804 bytes. Other bundled
changes and live network variation limit attribution of the 25.6% observed
difference. Vox still used 2.24 times Brave's settled RAM in the latest
diagnostic. This cohort covered load and idle.

Vox executable SHA-256 was
`e6de499528e972179c46e586aed7c1269ce07a7436bac4fc4e428a9b35fe7405`.
Brave executable SHA-256 was
`91891e4e395cb799e755f9ec5ee501f380560b4365959de0a15b5123ca0aacd5`.
The process-tree driver checked executable and runtime file hashes at each
launch and again after teardown.

The focused storage and flex baseline tests passed with preallocation,
with the measurement arena poisoned on retirement, and with `-gc none`
without preallocation. The C test driver hit the 12 GiB guard. The focused
runs used FastC with two generated `libjs.ExecutionContext` pointer
expressions corrected in scratch before Clang compilation. FastC's option
interpolation limitation blocked the broader geometry-oracle suite. On the
production build, the same arena-poisoning setting also passed a live run of
240 precise wheel inputs, completing 258 publications and exiting 0.
Its 3 GiB guard exited 0 and observed 1,305,624,576 bytes of peak RSS.

The remaining native document arena used 442.2 MiB in a separate candidate
trace. The runtime recycle pool held 111.9 MiB of address space, with about
2.6 MiB of dirty pages in an address-matched snapshot. The largest remaining
document growth sites were map backing storage, layout replay, and CSS
invalidation comparisons. The stylesheet syntax cache retained another
42.7 MiB of used arena space.

Unordered CSS invalidation comparisons now track the first 64 matched rule
positions in a word and use compact extra words for larger lists. The
focused preallocation test verified zero arena growth across 512 repeated
small comparisons. Both descendant and sibling tests verified that reversed
65-entry lists compare equal and that replacing a rule with a duplicate is
detected. The focused C-backend executable and its guard exited 0. The shared
production build still needs to publish this change before measuring its
effect on the live page.

## Follow-up with the CSS comparison change in production

The single-unit C production bundle at `8f0de4a0f` contains both the
measurement storage and the CSS comparison changes. Its executable SHA-256
was `3b23dceb917896c9fe16aa8d6b5485dfb53786ed4ef3d1cd07d8104777c4327a`.
The Brave executable and comparison method were the same as above. Each
audited document was visible at 1024×768, scale 2, with loaded fonts and 133
images. The test checked the complete 15,620-byte patch text with generated
UUIDs normalized. The settled value is the median sampled physical footprint
of the browser process tree over the last 3 seconds of a 12-second observation
after the readiness check. Each launch used live HTTPS, a fresh private
profile and cache, and retained OS caches.

| Earliest check | Trial order | Settled footprint | Sampled peak | Browser exit |
| --- | --- | ---: | ---: | ---: |
| 9 s | Vox 1 | Incomplete patch, 5 images | — | −15 |
| 9 s | Brave 1 | Incomplete patch, 5 images, hidden | — | 0 |
| 9 s | Brave 2 | 385,621,912 B | 801,104,680 B | 0 |
| 9 s | Vox 2 | 834,523,048 B | 1,288,278,696 B | 0 |
| 23 s | Vox 1 | 934,023,176 B | 1,366,266,632 B | 0 |
| 23 s | Brave 1 | 333,570,160 B | 886,464,504 B | 0 |
| 23 s | Brave 2 | 329,899,952 B | 851,255,216 B | 0 |
| 23 s | Vox 2 | Missing item and neutral item text, 133 images | — | −15 |

Both drivers and guards exited 1 because of the rejected trials. The
respective 3 GiB guards observed peaks of 1,154,695,168 and 1,240,727,552 B of
RSS. One-minute load at launch ranged from 32.79 to 54.24 on the 18-CPU host.
The successful pairs remain useful diagnostics and both still favor Brave on
settled footprint. A separate 23-second diagnostic with the stylesheet rule
cache disabled omitted the same item text, so it provided no matched memory
estimate. Its browser exited −15 after rejection and its guard exited 1.

A separate successful allocation trace at 38 seconds showed 402.8 MiB used
in the native document arena and 42.7 MiB of cached stylesheet syntax. Large
document-arena growth sites included the compact DOM bridge's element
response and attribute maps, and line boxes copied from measurement results
into committed layout. The trace samples the allocation stacks where each
arena block grew. Other allocations can share those blocks.

`08729cfc0` limits the stylesheet rule cache to 16 MiB of retained arena
capacity. Cached syntax still converts to independent CSSOM objects, and
over-budget trees still go through ordinary conversion. Its focused
C-backend tests passed normally and with the syntax cache arena poisoned.
`b2d54c0b1` shares the previous pass's published line boxes when replaying a
measurement produces exactly the same lines. Focused FastC tests passed
normally and with the measurement arena poisoned. The tests verified that
changed line boxes survive arena release and that later writes detach from
shared lines. The FastC test used the same scratch compiler workaround
described above.

`e402b6490` gives individual compact element query responses a temporary
workspace. The response graph and encoded JSON stay live through the
JavaScript copy. Element identities, attributes, and lazily initialized
control models keep their native owners. After FastC rejected an existing
script test expression, the focused C build and both runtime checks passed.
The second runtime check poisoned the reply workspace on retirement. The
measured production bundle predates all three changes. Automatic rebuilds
are queued on the shared worker.

### Native scrolling on the measured bundle

Two fresh launches of the same bundle ran 240 precise wheel events at a
nominal 60 Hz with delta 8, reversing every 80 inputs. Input began 23 seconds
after the title matched. Both pre-input audits confirmed the full patch
text, 133 images, and the viewport and live network conditions above. Rates
use the full first-to-last input window and count only completed native
frame installations with changed scroll positions. The probe measures Cocoa
publications. Physical display scanout was unmeasured.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 35.28 | 17.57 / 71.89 / 228.15 ms | 87/152 | 240 / 249 | 55.47 Hz | 85.13 / 0.32 ms |
| 2 | 34.14 | 17.34 / 78.28 / 234.88 ms | 88/149 | 240 / 243 | 54.76 Hz | 95.95 / 17.16 ms |

One-minute host load was 43.11→43.00 and 42.68→42.91. Both browsers and
drivers exited 0. The 3 GiB guard exited 0 and peaked at 1,462,337,536 B RSS.
These trials show that the page still misses many frame deadlines after
loading. They establish baseline behavior for the later memory changes.

## Production build with the stylesheet cache cap

The single-unit C production bundle at `08729cfc0` includes the stylesheet
cache cap. Its executable SHA-256 was
`4812830ce1912f8bb86e16b97dd4af79b5070c1857201732ad53f1cccd0d26bc`.
The latest audited comparison retained the 23-second checkpoint, viewport,
profile, live network policy, process-tree sampler and 12-second observation
period above. The Brave executable and runtime hashes were pinned through each
trial. The content audit still required the full 15,620-byte patch text with
UUID normalization, 133 patch images, and matching title, visibility and
font readiness.

| Trial order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Vox 1 | 749,883,208 B | 1,197,756,928 B | 0 |
| Brave 1 | 334,323,512 B | 887,693,040 B | 0 |
| Brave 2 | 295,690,328 B | 858,595,416 B | 0 |
| Vox 2 | Missing item and neutral item text, 133 images | — | −15 |

The guard and driver exited 1 after rejecting the incomplete Vox run. The
guard observed 1,059,815,424 B of peak process-tree RSS with its 3 GiB cap.
The 18-CPU host's one-minute load at launch was 25.10, 17.05, 15.95 and
14.06. The complete pair places Vox at 2.24 times Brave's settled footprint.
Host load and other bundled changes prevent isolating the CSS cap's effect
from these live observations.

Native Fetch now uses a shared stream read request throughout body delivery
(`011b4c2a7`). Each Fetch consumer receives an independent byte array.
Native reads skip the extra Uint8Array and promise result used for
script-facing reads. Focused body and response handover
tests passed with preallocation. The XHR binding tests initially stopped at
`OPENED` because the fixture drained the HTML queue before delivering
`PendingResponse`'s deferred platform callback. All cases passed once the
fixture drained both queues. The production bundle measured above predates
this change.

Inline measurements and resolved grid-track entries now share the existing
layout-pass arena (`28550f04f`). Probes can reuse cached geometry until the
pass ends. Final layout takes ownership of promoted lines, glyph buffers,
and inline box values before the arena retires. Tests covered matching
previous lines, changed lines, intrinsic glyph ownership, inline box edges,
and independent grid track results. All four focused FastC test files
passed normally and with the measurement and probe arenas poisoned.

Committed subtree replay now shares rare geometry when its backing is
safe to share (`0058ec186`). A write through either state detaches it.
SVG path and grid data retain their copy behavior. The rare-state and
incremental-root tests passed normally and with the targeted arena
poisoning enabled.

`33efcc64d` puts XHR text decoding and the JSON reply in a temporary
workspace. The JavaScript binding copies the text before the workspace
retires. The focused application test reads a 160 KiB response five times
through `response` and `responseText`. It verified text equality and
native document arena growth smaller than one response body. Both
the normal C-backend runtime check and the check with input and reply
workspace poisoning exited 0. Standalone browserjs C compilation hit the
12 GiB guard, so the focused check used the production application's
module layout.

### Longer scroll on the stylesheet-cap build

Two fresh runs used the same viewport, scale and live content audit. Each
sent 720 native precise wheel events at 60 Hz, with delta 16 and a reversal
after input 540. The completed frames reached scroll position 13,791.5 CSS
pixels. These trials use a different workload from the 240-input baseline.
A 50 ms process-tree observer sampled physical footprint from process
discovery. It used receipt of the native scroll log markers to identify the
input interval. Peak footprint in both launches occurred during scrolling.

| Run | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap | Sampled peak footprint |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 13.32 | 59.75 / 93.94 / 2,079.96 ms | 166/170 | 720 / 416 | 56.35 Hz | 123.41 / 18.45 ms | 1,473,581,112 B |
| 2 | 15.25 | 53.79 / 83.22 / 2,159.39 ms | 187/197 | 720 / 466 | 55.65 Hz | 59.39 / 37.02 ms | 1,425,641,528 B |

The input windows lasted 12.759 and 12.920 seconds. Both browsers and drivers
exited 0. The guard exited 0 with a 1,448,312,832-byte RSS peak. One-minute
host load was 14.56→10.65 and 10.65→10.27. These fresh single-tab runs
peaked below the reported 5 GB and still missed most frame deadlines.

A separate 10-second macOS stack sample during the same wheel schedule
recorded 3,966 main-thread samples. It found 1,128 in CSS filter-layer
completion, including 644 in Core Image rendering, and 1,027 in portable
shadow drawing, including Metal readback. Linear gradient shading and
transformed image drawing accounted for another 641 and 524 samples.
The full patch audit, sampler, browser and 3 GiB guard passed. The sample
identifies active rendering work during the stalls. The throughput table
uses the two separate runs without stack sampling.

An injected diagnostic switched off Core Image intermediate caching for the
same browser's CSS filter context. The probe verified the context constructor
in Vox. One run missed the content audit with only five images. The complete
run peaked at 1,384,353,848 B during scrolling and published 7.81
scroll-changing frames per second. The respective one-minute host loads
were 49.47→85.28 and 85.28→103.90. Both browsers and precise-scroll drivers
exited 0. The audit wrapper and its 3 GiB guard exited 1 because the first
document was incomplete. The guard's observed RSS peak was 1,378,615,296 B.
The host load disparity leaves the cache setting's effect unverified.
[Core Image cache option](https://developer.apple.com/documentation/coreimage/cicontextoption/cacheintermediates?language=objc)

## Production build with temporary DOM replay tables

`ef8a858a2` releases the compact DOM bridge's key set and temporary element
tables after each replay batch. Elements and published bridge keys keep
document ownership. A focused preallocation test built tables for 512 keyed
lookups with the C backend and verified zero document-arena growth during
construction. The tests also passed with both replay workspaces poisoned.

The next single-unit C `-prod` bundle passed its startup check. Its executable
SHA-256 was `16c404942668946b797186d3133dba0a7dd84b200e355e7596b2f02966514caa`
and its AVIF library SHA-256 was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The build was requested at `9df057554`. The sealed compiler inputs and
installed executable included the replay table, element reply and XHR text
workspace changes already present in the checkout. The build and smoke
guards exited 0. Several previous attempts had failed source verification
or lost their sealed compiler inputs during shared build cleanup.

Nine SVG reftests on this bundle matched pixel for pixel. They covered
same-size image replacement, gradient removal and updates, stop reordering,
paint-server ID collisions, and inherited style changes. The screenshot
driver and 3 GiB guard exited 0.

### Live memory

Fresh Vox and Brave processes used private profiles and HTTP caches, retained
OS caches, and loaded the live HTTPS page directly at 1024×768 and scale 2.
The process-tree sampler read physical footprint every 50 ms from launch.
The settled value is the median of the final three seconds of a 12-second
observation after a content check at about 23 seconds. Brave reported
Chromium `158.0.8127.42` and retained the same executable hash as the earlier
comparison. The executable, framework, and helper hashes stayed fixed.

The audit requires 133 images and equality with the complete patch text
after replacing generated UUIDs. The first attempt mistakenly required word
boundaries and missed UUIDs in CSS class names. It rejected both Vox launches
and the first Brave launch at 15,620 raw bytes and 133 images. The other Brave
launch independently had five images. The browser exits were −15, 0, 0,
and −15 in that order. No launch in that attempt reached the settled
measurement. The driver and guard exited 1, with 1,057,914,880 B of peak
sampled RSS observed by the guard.

| Corrected audit order | Document at checkpoint | Settled footprint | Sampled peak | Browser exit |
| --- | --- | ---: | ---: | ---: |
| Vox 1 | Missing item and neutral item notes, 133 images | — | — | −15 |
| Brave 1 | Incomplete patch, 5 images | — | — | 0 |
| Brave 2 | Incomplete patch, 5 images | — | — | 0 |
| Vox 2 | Complete patch, 133 images | 744,804,240 B | 1,200,034,376 B | 0 |

The corrected driver and guard exited 1 after the incomplete documents.
The guard observed 1,074,888,704 B of peak process-tree RSS. One-minute host
load at launch ranged from 7.21 to 15.23 on 18 CPUs. The complete Vox
launch audited the page 23.17 seconds after launch and had 56 samples in its
settled window. This cohort supplies no matched Brave measurement. The
latest matched fixed-checkpoint comparison remains 749,883,208 B for Vox
and 334,323,512 B for Brave at settled footprint.

A separate pair allowed up to 65 seconds for complete text, images, and
fonts. Vox wrote an audit every four seconds. Brave started sampling content
at 23 seconds and could check every four seconds thereafter. Both were
complete at the first checkpoint, about 23.01 seconds after launch. The
profiles, browser identities, process-tree sampler and 12-second observation
were unchanged. The different audit schedule makes this a separate
diagnostic.

| Diagnostic order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 318,480,472 B | 845,308,040 B | 0 |
| Vox | 732,450,728 B | 1,169,199,736 B | 0 |

Both audits matched the complete document. The settled windows contained 55
Brave and 56 Vox samples. One-minute host load was 7.03→5.58 for Brave and
5.58→5.29 for Vox. The driver and 3 GiB guard exited 0 and the guard observed
1,041,989,632 B of peak RSS. Vox used 2.30 times Brave's settled footprint
in this pair.

### Sustained native scroll

Two fresh launches passed the same document text and image audit. The
precise-input probe started after a 23-second settle with the patch title.
Each trial delivered 720 native vertical wheel events at nominal 60 Hz,
delta 16, with reversal after input 540. Both reached scroll position
13,791.5 CSS pixels. Throughput uses changed scroll positions in completed
native frame installations after outer view paint, over the entire input
window. This endpoint cannot measure display scanout.

| Run | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 17.05 | 48.35 / 72.79 / 2,151.94 ms | 204/215 | 720 / 482 | 57.02 Hz | 60.16 / 33.55 ms |
| 2 | 15.19 | 55.02 / 85.65 / 2,112.33 ms | 183/194 | 720 / 456 | 56.29 Hz | 64.54 / 19.96 ms |

The input windows lasted 12.609 and 12.774 seconds. The browsers, both
drivers, and the 3 GiB guard exited 0. The guard observed a peak
1,428,291,584 B of process-tree RSS. One-minute load was 5.81→5.72 and
5.72→7.12. Most scroll-changing intervals exceeded one 60 Hz frame budget.
The schedule can reach the bottom before reversing. The table's maximum
interval measures changes in scroll position and includes that stationary
time, as the later trace confirms. Host load and bundled changes differ from
the previous trials, so the throughput difference has no engine attribution.

A separate candidate rendered clipped output rectangles for single Gaussian
blurs and drop shadows with the full source available to Core Image. The
exact native pixel assertion failed in both the optimized and sanitized
fixture. The candidate was reverted before publication.

### Memory map on the following production bundle

A fresh launch of the bundle requested at `a81f48c01` passed the complete
live audit. Its executable SHA-256 was
`b0a6ad63e5e6a11c8b835f92894a1e392f2d1c44ce03cde21fd86182fa74b1b9`.
It settled at 766,250,896 B and peaked at 1,213,026,888 B in the process-tree
sampler. A separate `vmmap -summary` snapshot at 35 seconds reported 476.2 MiB
of dirty untagged mappings, 108.0 MiB of dirty WebKit Malloc regions, and
23.3 MiB of dirty graphics-owned unmapped memory. The snapshot classifies
the mappings by VM tag. It cannot identify their owners within the engine.
Vox, `vmmap`, the driver, and the 3 GiB guard exited 0.

## Arena ownership and dataset replies

A separate probe on the same `b0a6ad63` executable tracked live V arena
block headers, including headers for recycled mappings. It matched the
allocator's caller address against the pinned executable and sampled the
live cursors at the 38-second sampling point. Both launches used private
profiles and caches and the same live page, viewport and scale as the
earlier memory comparison. A block's stack describes where it grew. Its
byte count includes subsequent allocations that share the block.

| Launch | Content audit | Native document arena used | Unscoped arena used | Browser / driver / guard exits |
| --- | --- | ---: | ---: | --- |
| 1 | Missing 384 bytes of item notes, 133 images | 357.95 MiB | 109.12 MiB | 0 / 1 / 1 |
| 2 | Complete patch, 133 images | 316.04 MiB | 108.97 MiB | 0 / 0 / 0 |

The complete launch had 292 document blocks with 323.41 MiB of capacity.
The probe tracked 110,415 header creations and 109,874 retirements, with
no dropped records. The 3 GiB guards observed 1,057,587,200 B and
1,073,315,840 B of peak RSS with the probe active. These runs describe
arena owners under instrumentation. The earlier process-tree footprint
comparison used separate runs.

Stylesheet conversion, CSS invalidation publication, and committed layout
replay grew the document arena. The complete launch included 7.00 MiB of
block use attributed to the stack building attribute snapshots for
`dataset` replies. Those attribute maps only need to survive the host's
copy into JavaScript.

`c7f907fc5` retires dataset request and reply storage together. Native
attribute names, values and mutations remain document-owned. Focused
tests covered repeated replies containing a large unrelated attribute,
live native writes, SVG attribute names, and deletion. Eight repeated
reads retained less than 8 KiB in the document arena. All tests passed
with the reply and request workspaces poisoned, and both C compile and
runtime guards exited 0.

`2093b2408` lets a fresh CSS rule cache grow its unpublished invalidation
match sets in place. An extension of an existing cache and the general
plan union retain their copy-on-write behavior. The focused fixture built
128 descendant and 128 sibling selectors with shared prefixes. It
retained 298,069 B with the unpublished path and 2,206,549 B with the
existing merge. Both produced the same dependency graph. Invalidation
workspace, subset union, and cache extension tests passed normally and
with temporary selector storage poisoned. The C compile and runtime guards
exited 0.

### Live comparison on the dataset bundle

The single-unit C `-prod` dataset bundle had executable SHA-256
`c4ba7ebc9356d98497cda34e851ee5fb00bc9c1718d2c889380cb337a42ff924`.
The sealed inputs and executable contained the dataset workspace. The
build started before the CSS invalidation change. Nine SVG reftests were
pixel-exact on the installed bundle, including same-size image replacement
and paint-server updates. The screenshot driver and its 3 GiB guard
exited 0.

A fresh Brave–Vox pair used the extended readiness protocol above. Both
browsers had 15,620 raw text bytes and matched the normalized text checksum,
133 images, the patch title, and the viewport at the first 23-second
checkpoint. The Vox AVIF library and Brave executable, framework and
helpers retained their previous hashes. The final windows contained 56
Brave and 57 Vox physical footprint samples.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 289,824,784 B | 845,373,480 B | 0 |
| Vox | 728,354,632 B | 1,182,732,872 B | 0 |

The driver and guard exited 0. The 3 GiB guard observed 1,380,139,008 B of
peak process-tree RSS. One-minute load was 65.49→63.86 and 63.86→54.54 on
the 18-CPU host. The RAM target remains open. This build contains other
engine changes and ran under higher host load than the preceding pair.

### Scroll boundary audit

Two full live runs on the dataset bundle used the previous 720-event
schedule with reversal after input 540. Both reached the bottom at
13,791.5 CSS pixels on input 416 and stayed there until input 541.
Each run published 238 completed frames at the same position between
those two scroll changes. The longest gap between completed frames
was 161.34 ms and 203.63 ms respectively. This corrects the earlier
interpretation of the roughly two-second gaps between position changes
as rendering stalls. The original timing measurements remain above.

| Run | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 14.33 | 57.61 / 88.05 / 2,093.95 ms | 177/186 | 720 / 444 | 55.38 Hz | 66.67 / 82.66 ms |
| 2 | 9.86 | 85.97 / 148.98 / 2,089.34 ms | 130/138 | 720 / 388 | 51.38 Hz | 81.80 / 76.73 ms |

The input windows lasted 12.982 and 13.993 seconds. Both browser and driver
exits and the 3 GiB guard exit were 0. The guard observed 1,439,662,080 B
of peak RSS. One-minute load was 30.20→23.16 and 23.16→17.01.

### Scroll before reaching the bottom

The corrected schedule reverses after input 360 and keeps all other input
parameters the same. The dataset bundle's two fresh launches completed
the patch audit and reached 12,029 and 12,025 CSS pixels. Both stayed
above the page bottom of 13,791.5 CSS pixels.

| Run | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 12.27 | 86.03 / 123.09 / 175.56 ms | 161/173 | 720 / 196 | 50.99 Hz | 103.80 / 184.94 ms |
| 2 | 10.56 | 98.99 / 143.69 / 208.41 ms | 138/151 | 720 / 170 | 50.30 Hz | 108.35 / 183.28 ms |

The full input windows lasted 14.100 and 14.294 seconds. The longest
intervals between any completed frame publications were 173.10 ms and
205.30 ms. One-minute load was 15.85→15.91 and 15.91→36.79. Both browsers,
both drivers, and the 3 GiB guard exited 0. The guard observed a peak
1,401,405,440 B of process-tree RSS. Most scroll-changing intervals still
missed the 60 Hz frame budget.

A separate run of the corrected schedule sampled the main thread during
frames that exceeded 75 ms. The complete live document produced 113 slow
frames and 577 samples, with no dropped samples or thread snapshot failures.
CSS filter completion appeared in 437 samples. Core Image rendering appeared
in 276 of those samples, and filter source import appeared in 73. These
counts describe the instrumented slow frames. The throughput table uses the
two runs without profiling. The browser, driver, and guard exited 0. The
guard observed 1,393,377,280 B of peak RSS and one-minute host load was
51.13→53.81.

### Live comparison with both memory fixes

The production build requested at `7c6562f89` included the dataset and CSS
invalidation changes. Its single-unit C `-prod` executable SHA-256 was
`4087f96569a5011531befbe58071b20ae101e6e83aeeaa002859e4b68e21c72f`.
The build and startup check exited 0.

The next readiness-controlled live pair used the same identity and content
checks. Brave and Vox both matched the entire patch at the first 23-second
checkpoint. Each settled window contained 56 physical footprint samples.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 384,589,888 B | 871,030,680 B | 0 |
| Vox | 707,432,312 B | 1,162,842,744 B | 0 |

Vox used 1.84 times Brave's settled footprint in this pair. The driver and
3 GiB guard exited 0, with 1,369,325,568 B of sampled peak RSS. One-minute
host load was 50.25→42.38 and 42.38→32.51. This bundle also includes
other engine changes, so these data do not isolate either fix's effect.

The class and `:has()` invalidation reftests matched their pixel references
on both bundles. The pseudo-class test differed from its upstream reference
by the same 1,875 pixels on both. The upstream comparison exited 1 on each
bundle. All three actual PNG files were byte-for-byte equal across the
bundles. The extra comparison using the prebuilt pixel tool aborted with
exit 134. Comparing the PNG bytes established the same-output check.

Two more live launches of this build completed the patch audit and ran
the corrected schedule. They reached 12,060.5 and 12,026 CSS pixels.

| Run | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 10.79 | 97.00 / 140.12 / 198.06 ms | 145/157 | 720 / 177 | 49.43 Hz | 104.48 / 181.64 ms |
| 2 | 10.90 | 95.64 / 141.77 / 211.81 ms | 145/156 | 720 / 175 | 50.26 Hz | 94.10 / 190.52 ms |

The input windows lasted 14.546 and 14.305 seconds, with maximum gaps
between completed frame publications of 194.95 and 208.25 ms. One-minute
host load was 86.59→58.05 and 58.05→52.74. Both browser and driver exits
and the 3 GiB guard exit were 0. The guard observed 1,485,225,984 B of
peak RSS. Host contention and bundled changes limit timing attribution.
The scroll runs still show repeated missed frame deadlines.

## Completed bitmap input for spatial filters

`d28c30a42` passes the private bitmap of a completed single blur or drop
shadow to Core Image through immutable `NSData`. The data owns the bitmap
context until Core Image finishes with it. The filter renders the same full
extent as before and avoids the `CGImage` data-provider copy. This path
excludes backdrop snapshots and shared frame buffers.

The filter source fixture matched the copied path pixel for pixel in padded
RGBA and BGRA, in sRGB and Display
P3, after releasing the original context. Clipped blur and drop-shadow frame
publication also matched exactly. The ARC and manual-retain runs completed
200 spatially filtered Retina frames each with stable RSS after warmup. All
20 optimized and ASan/UBSan document-canvas cases passed. The filter source,
manual-retain and canvas jobs and their 3 GiB guards exited 0, with sampled
peak RSS of 777,748,480 B, 598,048,768 B and 891,174,912 B respectively.
[Filter source fixture](../tools/native_css_filter_source_test.m)

Four fresh launches of the same `-O2` manual-retain fixture tested the copy
switch in copied/direct/direct/copied order, with 200 frames per launch.
The 1280×900 canvas at backing scale 2 alternated blur and drop shadow.
Work began before frame 1 and ended after frame 200. Each fixture and the
3 GiB guard exited 0. The guard observed 584,204,288 B of peak RSS.

| Source | Elapsed | Sampled fixture peak RSS | One-minute host load at launch |
| --- | ---: | ---: | ---: |
| Copied | 4.957 s | 526,254,080 B | 37.32 |
| Direct | 5.248 s | 525,598,720 B | 35.53 |
| Direct | 5.151 s | 525,746,176 B | 34.29 |
| Copied | 6.204 s | 525,484,032 B | 32.66 |

The timings overlap and the peak differences are below 1 MB on this fixture.
The managed production build was still pending. The live scrolling effect
and the RAM comparison with Brave remain open.

### Live scrolling with and without the bitmap copy

The next single-unit C `-prod` bundle had executable SHA-256
`e9c5258ec283f042913e0f1dbfa7e0a4b19063ed1b75b7ee8107cd295816fb5e`.
Its frozen source receipt included `d28c30a42`. The AVIF library retained
the `ebde1494` hash above. The Adblock worker SHA-256 was
`8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4`.

The separate `VOX_CSS_FILTER_STAGE_TIMES=1` launch used the same live page
and input schedule as the timing trials. It logged 376 direct imports of
2048×1760 single drop-shadow bitmaps between `SCROLL_POSITION` and the final
record dump, with zero before input setup. Filter completion in that span
totaled 4.102 seconds and the post-input tail was 0.262 seconds. The native
probe prints input records as a batch at completion, so their log positions
cannot isolate the tail. The accumulated time establishes that the direct
path ran during input. The browser and native driver exited 0. An initial
wrapper used the request commit instead of the frozen source commit and
aborted before launch. The next wrapper interpreted the batched input log
incorrectly and exited 1. The preserved diagnostic passed the full content
audit and its guard observed 1,410,662,400 B of peak RSS.

Four fresh unprofiled launches used the corrected 720-input schedule, with
`VOX_DISABLE_DIRECT_CSS_FILTER_BITMAP=1` on the copied trials. Each complete
patch matched 15,620 bytes of text, the normalized checksum, and 133 images
before scrolling. The viewport was 1024×768 at backing scale 2. The input
reversed after 360 events with delta 16. It began 23 seconds after the title
matched. The driver used direct HTTPS, fresh private profiles and caches,
automatic scripting, and retained OS caches. All trials stayed above the
bottom of the document.

| Source | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Copied | 17.56 | 61.45 / 88.84 / 161.55 ms | 219/241 | 720 / 275 | 52.39 Hz | 64.47 / 0.27 ms |
| Direct | 19.56 | 52.71 / 80.00 / 133.97 ms | 229/250 | 720 / 285 | 56.24 Hz | 64.02 / 10.24 ms |
| Copied | 17.95 | 57.28 / 85.95 / 161.73 ms | 222/240 | 720 / 270 | 53.77 Hz | 67.76 / 0.17 ms |
| Direct | 17.95 | 57.77 / 85.42 / 163.86 ms | 219/242 | 720 / 276 | 53.34 Hz | 68.22 / 18.91 ms |

Throughput counts scroll-changing native frame installations after outer view
paint over 13.724, 12.784, 13.372 and 13.479 seconds of input. This endpoint
leaves physical scanout unmeasured. Maximum gaps between all completed
publications were 159.08, 131.78, 159.31 and 161.81 ms. One-minute host load
on 18 CPUs was 9.27→8.36, 8.50→7.45, 7.09→7.04 and 7.04→7.59. All browsers,
drivers and the 3 GiB guard exited 0. The guard observed 1,432,338,432 B of
peak RSS. The faster first direct trial did not repeat, and over 90% of
scroll intervals exceeded 16.67 ms in all four trials.

### Dynamic link stylesheet storage

A caller-checked V arena probe on the previous `4087f965` executable identified
296.81 MiB of document allocation cursors in 279 blocks, with 302.99 MiB of
capacity. The unscoped arenas used 108.41 MiB across 163 blocks. The 38-second
snapshot tracked 107,417 block header allocations and 106,902 retirements
with zero dropped or incomplete records. The main document owner was stable
between 27 and 38 seconds. The fresh patched-page launch passed the complete
audit and was terminated by the driver after the sample window. Browser,
driver and guard exits were −15, 0 and 0. The guard observed 1,100,693,504 B
of peak RSS. This diagnostic includes probe overhead.

One unscoped arena block grew while copying a script-inserted stylesheet to
the CSS bridge's process-wide cache. That stack identifies the allocation
that grew the block. Later allocations can share the block's bytes. The
browser already retained the response in its document session for late link
owners. `a00120094` lets fallback synchronization use that document-owned
text. It clears the fallback entry after a failed replacement and keeps
UTF-16 BOM decoding and the redirect base URL.

The focused CSS fixture verified that a 1 MiB response retains the same text
pointer in the fallback, stays invisible to a second document, and disappears
after a failed response. Browser integration exercised asynchronously supplied
and disk-cached script-inserted sheets. Both C-backend binaries passed with
preallocation and with arena poisoning enabled. Runtime guards exited 0 and
peaked at 24,608,768 B and 100,679,680 B. A first integration compile omitted
the prepared GG and UI2 modules and exited 1. The retried compile used the
browser's module overlays and exited 0. The scoped stylesheet change still
needs isolated same-build memory attribution.

### Live RAM on the stylesheet-response build

An initial Brave–Vox pair passed both content audits and both browsers exited
0. The shared bundle was replaced before the final hash check, so the driver
and guard rejected the pair with exit 1. The sampled settled and peak
footprints were 333,373,432 B and 867,753,904 B for Brave, and 749,260,664 B
and 1,192,464,920 B for the displaced Vox bundle. The guard sampled a peak
1,051,230,208 B of process-tree RSS.

The replacement single-unit C `-prod` bundle had executable SHA-256
`0737ebafdaf1a4203c80452b21a583040e9126d1b7da71183a63ba7b8ad477a2`.
The frozen generated C contained both the document-response bridge and
the native adapter call sites from the stylesheet change. Brave remained on
Chromium `158.0.8127.42`. The executable, native-library, framework and
helper hashes remained fixed in the rerun.

Both browsers opened fresh private profiles with direct live HTTPS and
retained OS caches. They audited the complete patch at 23.01 and 23.18
seconds respectively at 1024×768 and backing scale 2. The process-tree
footprint sampler took 55 observations in each final three-second window,
twelve seconds after the audit.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 331,981,008 B | 812,146,608 B | 0 |
| Vox | 733,122,424 B | 1,175,654,792 B | 0 |

One-minute host load was 4.22→4.29 and 4.29→4.51 on 18 CPUs. The driver and
3 GiB guard exited 0. The guard observed 1,095,204,864 B of peak RSS. Vox
used 2.21 times Brave's settled footprint on this pair. The bundle also
contains other engine changes, so the comparison measures total browser
memory on the live patch.

### SVG and grid layout geometry

`2b4e7ff2c` allocates grid track arrays and SVG geometry only for boxes that
use them. Ordinary positioned and flex boxes still retain their scalar
geometry. Grid array copies and published SVG path copies keep their
independent backing storage when a measurement arena retires.

A standalone fixture called the layout and allocator functions emitted by
the production C backend. The before and after compiler receipts were
`20261125-174702-1e7094d1` and `20261125-180110-c0f9257e`. Each fixture
created 1,024 ordinary rare records and cloned each record. Clang compiled
both at `-O0`. The record shrank from 872 B to 336 B. The arena allocation
cursor for the fixture fell from 1,802,216 B to 688,128 B.
The candidate produced the same result with arena poisoning enabled.
Both compiler inputs stayed fixed. The compile and execution guards exited
0 with sampled peak RSS of 4,102,586,368 B and 47,906,816 B respectively.

The V rare-state fixture also passed with FastC and Clang after correcting
two unrelated generated optional `libjs.ExecutionContext` casts in a
temporary C file. That backend reported zero arena bytes for the fixture,
so the allocation result above comes from the production C backend. The
ordinary C-backend test command exceeded its 12 GiB guard. The separate
production C fixture exercised the measured allocation and release path.

The single-unit C `-prod` bundle with the new geometry records had SHA-256
`85a440370b6dc773afdeb6213d63c9505e7ff7912b13698272671202cd1b55cc`.
The frozen generated C matched the candidate's layout implementation.
The next fresh pair used the same direct HTTPS, private profiles, viewport,
scale and content checks. Brave and Vox audited the complete patch at
23.01 and 23.13 seconds. The final three-second settled windows had 52 and
53 samples respectively.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 359,080,072 B | 866,443,448 B | 0 |
| Vox | 726,388,552 B | 1,165,824,584 B | 0 |

The executable, native-library and helper identities remained fixed. The
driver and guard exited 0. The 3 GiB guard observed 1,038,368,768 B of peak
RSS. One-minute host load was 5.64→5.29 and 5.29→5.03 on 18 CPUs. The
live comparison places Vox at 2.02 times Brave's settled footprint. It
includes other bundled engine changes and live network variation.

A separate fresh launch of the same executable stayed on the audited patch
without input for 100 seconds. Three-second windows ending at 35, 65, and
95 seconds yielded median footprints of 733,974,344 B, 733,990,728 B, and
733,990,728 B. The sampled peak was 1,168,970,096 B. Executable and library
hashes stayed fixed. Browser, driver and 3 GiB guard exited 0. The guard
observed 1,100,496,896 B peak RSS, with one-minute host load at 5.25→4.31.
This run covers a fresh tab through the first 100 seconds of its lifetime.

### Long-running session observation

An existing Vox process with almost twelve hours of uptime had
21,637,619,328 B of physical footprint. Its mapped executable inode was
different from the current bundle's inode. A read-only `vmmap -summary`
classified 19.7 GiB as dirty untagged memory across 11,012 regions. It also
reported 194.1 MiB of dirty WebKit Malloc and 110.8 MiB of dirty IOSurface
memory. The mapping check and its guard exited 0. A second physical sample
roughly two minutes later was 21,681,807,024 B. The process stayed running.
This observation measures a long-lived session and establishes neither its
loaded page nor the allocation owners within the engine.

A separate two-second, 5 ms stack sample recorded 296 main-thread stacks.
Of these, 289 waited in the event loop and five included a repeating timer
calling UI2 element rendering. The sampler and guard exited 0. The stack
sample measures active calls at that moment. Historical allocations cannot
be attributed from it.

### Tab-loading animation retention

`4debe2649` updates the existing UI2 AppKit vector path for each visible
loading tab. The frame geometry lives in a temporary arena. The native path
takes its own copy of the coordinates before that arena retires. The timer
still reconciles load completion through the regular chrome update.

The mounted AppKit fixture retained 2,256,000 B in the persistent arena
over 600 frames before the change and 0 B after it. The updated fixture
verified changing icon pixels, native control identity, and restoration
of the normal icon on completion. The browser integration fixture also
retained 0 B over 600 timer callbacks. It verified address and document
paint stability and timer stop and restart behavior. Both candidate fixtures
passed with `VOX_ARENA_NO_REUSE='tab loading vector'`, which protects retired
frame storage. All C-backend preallocation compile and runtime guards exited
0. The integration compile guard sampled 6,470,533,120 B of peak RSS and
its 3 GiB runtime guard sampled 51,576,832 B. The fixture reproduced a
specific source of growth during loading. The older session's historical
allocations remain unattributed.

### Live RAM before the animation fix

The fresh Brave–Vox pair used direct HTTPS, empty private profiles and HTTP
caches, retained OS caches, and a visible 1024×768 document at backing scale
2. Both audited the complete patch at 23.01 and 23.13 seconds with loaded
fonts, 133 image elements and 15,620 bytes of matching normalized React-root
text. Each final three-second window contained 51 measurements, ending
twelve seconds after the audit.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 324,378,568 B | 882,204,616 B | 0 |
| Vox | 731,991,928 B | 1,182,634,616 B | 0 |

The verified single-unit C `-prod` Vox executable SHA-256 was
`f55877b838c33d7a1d5ffedca5ef2bd64eab9d7851bb153f5235cb080cfc4efb`
from receipt `20261125-181318-8c447b81`. Brave reported Chromium
`158.0.8127.42` with executable SHA-256
`91891e4e395cb799e755f9ec5ee501f380560b4365959de0a15b5123ca0aacd5`.
Native libraries, frameworks and helpers stayed fixed. The driver and 3 GiB
guard exited 0. The guard sampled a 1,059,258,368 B peak RSS. One-minute
host load on 18 CPUs was 4.09→4.33 and 4.33→3.65. Vox used 2.26 times
Brave's settled footprint in this pair. The measured bundle predates the
animation fix.

### Live RAM on the animation-fix build

The shared worker published single-unit C `-prod` receipt
`20261125-182146-d7d3e0ef` with executable SHA-256
`f9c2c07f29c6e7efa43f38735cf65a67dcc56da8ffc6c79dd5bf05fd2e4905ca`.
The frozen generated C contains the scratch vector update and the timer
call site. The production compile and headless smoke guards exited 0.
Their peak RSS was 7,686,914,048 B and 102,563,840 B respectively.

A fresh pair repeated the same viewport, scale, network, profiles and
audit criteria. Brave and Vox passed complete content audits after 23.00
and 23.12 seconds. The final windows held 51 and 52 observations.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 330,555,312 B | 853,057,384 B | 0 |
| Vox | 729,141,064 B | 1,169,756,696 B | 0 |

Brave's executable, framework and helper identities remained fixed across
the two pairs. Vox's native helper and library were pinned within each
pair. The driver and 3 GiB guard exited 0. The guard sampled
1,030,389,760 B peak RSS. One-minute host load on 18 CPUs was 5.05→5.80
and 5.80→6.36. Vox still used 2.21 times Brave's settled footprint. The
spinner test measures allocations during loading. The live pair measures
the entire browser and includes other bundled changes and network variation.

### Native wheel scrolling on the animation-fix build

Two fresh launches used the same production executable and pinned AVIF
library and adblock helper. Separate private profiles and HTTP caches
used direct live HTTPS and retained OS caches. Each audit at 22.79 and
22.76 seconds confirmed the complete patch, 133 images, 15,620 bytes
of matching normalized text, and a 1024×768 viewport at backing scale 2.
The native driver waited 23 seconds after the title matched and sent 720
precise wheel inputs at a nominal 60 Hz with delta 16. It reversed direction
after 360 inputs.

| Trial | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 22.90 | 43.97 / 67.50 / 118.64 ms | 276/300 | 720 / 336 | 54.88 Hz | 60.44 / 2.74 ms |
| 2 | 22.51 | 45.68 / 69.53 / 120.24 ms | 269/293 | 720 / 331 | 55.24 Hz | 60.78 / 9.03 ms |

Rates cover the full 13.102- and 13.017-second input windows. The endpoint
was completed native frame installation after outer view paint. Scroll
positions reached 12,092.5 and 12,062.5 CSS pixels and returned toward the
top. One-minute load on 18 CPUs was 6.17→6.44 and 6.44→6.39. Both browsers
and drivers exited 0. The 3 GiB guard exited 0 and sampled 1,358,151,680 B
peak RSS. Roughly 92% of scroll intervals in each trial exceeded the 60 Hz
frame budget.

The guarded driver ran `tools/measure_precise_scroll.py` with
`VOX_TEST_WINDOW=1`, `--script-policy automatic`, `--width 1024 --height 768`,
`--inputs 720 --delta 16 --reverse-every 360 --settle-seconds 23`, and
`--require-title 'Dota Patch Notes - 7.42a'`. It set the native audit delay
to 22 seconds. These are two observations of the published build under live
conditions. Isolating the effect of the animation change on scrolling
would require matched controls.
