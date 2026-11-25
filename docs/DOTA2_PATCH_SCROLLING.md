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

### Settled memory owners

Two separate instrumented launches used fresh profiles and HTTP caches,
direct live HTTPS, and the 1024×768 viewport at backing scale 2. Each
confirmed the complete patch at the 23-second audit with 133 images and
15,620 bytes of matching normalized React-root text. The pinned production
executable was
`d64a7059bb505fa4b7fe8ae4ecccaaa4e9aa278f19a65ac5da7a247f64ba6b72`.
The AVIF library and adblock helper stayed fixed during each run.

The first valid probe invoked cleanup on the native main thread at 30, 35,
and 40 seconds. It used the executable image slide and validated the resolved
symbols against that binary. Malloc pressure relief and Core Image cache
cleanup each changed the immediate task footprint by 0 B. The Core Image
hardware context existed and the software context was absent. Releasing
the shaping cache returned 1,064,960 B immediately. Three-second footprint
medians ending at 29, 34, 39, and 45 seconds were 709,676,920 B, 709,554,040 B,
709,611,384 B, and 708,530,040 B. Browser, driver, and guard exited 0. The
guard observed 1,025,769,472 B peak RSS. A preliminary run on the previous
executable had a successful page audit and browser exit 0. Shared publication
changed its executable identity during the trial, so the driver and guard
exited 1.

The second probe matched the allocator's block-header allocation symbol
range, tracked recycled header lifetimes, and read live allocation cursors
at 38 seconds. It observed 110,040 block creations, 109,528 retirements,
and 512 live headers with zero drops. The main document arena used
285.93 MiB and unscoped allocations used 101.87 MiB. CSS selector parsing,
invalidation graph merges, layout recording, DOM attribute state and
external-script source copies grew document blocks. An unscoped growth
stack ran through the image response decoder and the deferred PNG array
clone. Its blocks held 15.49 MiB across all allocations they served.
Block-growth stacks identify the allocating call when the block was added.
Their final use includes later allocations in the same block. The sampler's
39-second median was 723,849,104 B. Browser, driver and guard exited 0.
The guard observed 1,058,390,016 B peak RSS. A separate byte-copy-counting
probe aborted at browser startup with exit −6 and supplied no copy counts.
Its driver and guard exited 1.

### Reuse of retained image response bytes

`b743bb6e8` gives the synchronous image decoders a read-only view of the
response body. A deferred PNG shares the encoded bytes when the fetch
worker or cache has already placed them in process-lifetime storage.
Scope-owned responses still copy the encoded bytes once for the deferred
pixel read. The CORS request path preserves its existing owned copy.

The focused 59,912 B PNG fixture used the original allocating path as its
control. Retained arena use fell from 122,446 B to 784 B for the
process-owned response. A temporary response used 60,736 B. The preallocated
C-backend test produced the same counts normally and with the request scope
poisoned. The C-backend `-gc none` test verified exact decoded pixels for
both response paths. The passing compile guards sampled 6,493,061,120 B
and 6,431,883,264 B of peak RSS. Both 3 GiB runtime guards exited 0.
The fixture establishes the encoded-copy reduction with matching image
semantics. Seven local CORS image cases also passed, covering pixel readback,
redirects, origin and credential checks, CSP, cancellation and deduplication.
Their 3 GiB runtime guard exited 0 and sampled 216,465,408 B peak RSS. The
first standalone CORS run pointed the unbundled asset override at bundled
filenames. The rerun supplied the expected asset names and passed.

### Live RAM before the image-response change

The last published single-unit C `-prod` build before the image-response
change was receipt `20261125-183352-aa7514a2` with executable SHA-256
`6f5a192bf9c9e338f41af173ac5c83b23e98db548ba4f4ea629c8b6c1bc625bb`.
A fresh pair used uninstrumented per-process footprint sampling at 50 ms,
direct HTTPS, private profiles and HTTP caches, and retained OS caches.
Both pages passed the full 1024×768 scale-2 patch audit. The settled
medians used 51 samples per browser from the final three of twelve
seconds after the audit. The elapsed audit times were 23.01 seconds for
Brave and 23.17 seconds for Vox.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 336,552,048 B | 877,584,448 B | 0 |
| Vox | 727,273,312 B | 1,164,071,328 B | 0 |

The Brave executable and framework stayed fixed on Chromium
`158.0.8127.42`. Both executables, renderer helpers, and native-library
hashes stayed fixed. The driver and 3 GiB guard exited 0. The guard
observed 1,015,742,464 B of peak RSS. One-minute load on 18 CPUs was
7.29→5.70 and 5.70→5.71. Vox used 2.16 times Brave's settled footprint.

### Live RAM on the image-response build

The production worker published single-unit C `-prod` receipt
`20261125-184341-9bfe537b` with executable SHA-256
`ff12fde05da780fe335310d7df448bc913dae54ea5e775b95a7cab749b4ac5c0`.
The frozen C passes the response byte view and ownership flag into the
decoder. The production compile and headless smoke guards exited 0 with
peak RSS of 7,677,771,776 B and 101,924,864 B respectively.

The next pair started Vox first and repeated the same memory and content
protocol. Vox and Brave passed the full patch audits at 23.17 and 23.01
seconds. The final windows held 52 and 53 samples respectively.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Vox | 714,510,224 B | 1,161,466,440 B | 0 |
| Brave | 332,603,336 B | 879,091,608 B | 0 |

The native AVIF library, adblock helper and all pinned Brave binaries
matched the preceding pair. The driver and 3 GiB guard exited 0. The guard
observed 1,022,558,208 B peak RSS. One-minute host load on 18 CPUs was
3.32→5.38 and 5.38→5.73. Vox used 2.15 times Brave's settled footprint.
The live results include other bundled changes and network variation.
The controlled PNG fixture isolates the allocation effect of the change.

### Retained CSS selector storage

`1c0a3935f` gives short lists of compound and simple selectors exact-sized
backing arrays. Parsing builds up to four entries in a fixed local array.
Longer lists transfer the first four entries to a growable buffer.
Lowercase ASCII selector names reuse their original spelling. Names that
need folding preserve the existing Unicode conversion, and arena
publication shares an owned copy for equal spellings.

A C-backend fixture parsed 384 complex selectors inside native document
storage. The control retained 852,880 B and the candidate retained
697,207 B, a reduction of 155,673 B or 18.25%. An earlier candidate used
a mutable wrapper that V allocated on the heap. It retained 1,149,495 B
and was discarded. The final fixture returned the same count normally
and with `short selector source` and `selector graph` arenas
write-protected after retirement. The control and candidate compile and
3 GiB runtime guards exited 0.

The focused suites passed 27 cases covering source lifetime, both vector
sizes, Unicode names, workspace publication, DOM queries, CSSOM rule
reuse and invalidation dependencies. The affected workspaces passed
again with targeted arena poisoning. The focused compile guard sampled
2,227,027,968 B peak RSS and both 3 GiB runtime guards exited 0. The
non-preallocated C-backend selector fixture also passed.

### Live RAM before the selector-storage change

The prior single-unit C `-prod` executable came from receipt
`20261125-185109-2fd902d5` with SHA-256
`1f7fb4fd495ae2f8186cb0a6cb056e6e8e6a4a59d010f1e5aab01daa5823a789`.
The Brave–Vox pair used fresh profiles and caches, direct HTTPS and
retained OS caches. Each passed the complete 1024×768 scale-2 audit
with loaded fonts, 133 image elements and 15,620 bytes of matching
normalized text. Brave and Vox audited at 23.01 and 23.14 seconds.
The final three-second windows after twelve seconds of settling
contained 54 and 55 samples respectively.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Brave | 329,981,992 B | 886,988,792 B | 0 |
| Vox | 694,226,736 B | 1,134,514,544 B | 0 |

Executable, framework and helper hashes stayed fixed. Brave reported
Chromium `158.0.8127.42`. The driver and 3 GiB guard exited 0. The
guard sampled 981,319,680 B peak RSS. One-minute host load was
6.19→5.93 and 5.93→4.63 on 18 CPUs. Vox used 2.10 times Brave's
settled footprint.

### Live RAM on the selector-storage build

The production worker published single-unit C `-prod` receipt
`20261125-185951-29d81323` with executable SHA-256
`2a4c5ca263a71dcf1cde0f816881cb89c0f667a2cd1f6e926c2a0fdb52e99847`.
The frozen C uses fixed local arrays for both selector lists. The
production compile and headless smoke guards exited 0 and sampled
7,655,309,312 B and 78,921,728 B peak RSS respectively.

The next pair started Vox first and repeated the same audit and
measurement conditions. Vox and Brave passed the complete patch checks
at 23.15 and 23.01 seconds. The final windows contained 56 and 55
samples respectively.

| Order | Settled footprint | Sampled peak | Browser exit |
| --- | ---: | ---: | ---: |
| Vox | 710,709,064 B | 1,159,942,512 B | 0 |
| Brave | 324,444,224 B | 887,644,176 B | 0 |

The AVIF library, adblock helper and all pinned Brave binaries matched
the preceding pair. Both process trees stayed fixed within each trial.
The driver and 3 GiB guard exited 0. The guard sampled 1,011,908,608 B
peak RSS. One-minute host load was 4.74→5.32 and 5.32→4.90 on 18 CPUs.
Vox used 2.19 times Brave's settled footprint. The candidate's fixture
shows lower selector storage, while the total live footprint rose by
16,482,328 B between builds. The live runs include other changes and
network variation.

### Native wheel scrolling on the selector-storage build

Two fresh launches of the same executable used private profiles and
HTTP caches, direct live HTTPS, retained OS caches, automatic scripting,
and the matching 1024×768 viewport at backing scale 2. Both audits
confirmed the complete patch at 22.84 and 23.04 seconds. The measurements
used `tools/measure_precise_scroll.py` with `VOX_TEST_WINDOW=1`, 720 precise
wheel events at nominal 60 Hz, delta 16, reversal after 360 events and a
23-second settle after the title matched.

| Trial | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 17.28 | 59.54 / 91.16 / 167.04 ms | 219/235 | 720 / 266 | 52.88 Hz | 66.01 / 0.24 ms |
| 2 | 18.54 | 54.06 / 92.85 / 134.25 ms | 230/250 | 720 / 284 | 53.32 Hz | 60.26 / 3.84 ms |

Throughput spans the full 13.597- and 13.484-second input windows. The
endpoint records completed native frame installation after outer view
paint. Scroll positions reached 12,034.5 and 12,066.5 CSS pixels and
returned to the top. One-minute host load on 18 CPUs was 5.14→5.63 and
5.98→6.11. Both browsers, both drivers and the 3 GiB guard exited 0.
The guard sampled 1,347,518,464 B peak RSS. These trials were slower
than the animation-fix observations. The frozen build contains other
engine changes and the comparisons ran under different live conditions.

### Drop-shadow paint diagnostics

Two fresh live launches used the same viewport, backing scale, private
profiles and caches, and direct HTTPS. Both audited the full patch with
133 images, 15,620 bytes of matching React-root text and loaded fonts.
The probes used a 23-second settle after the title matched, then 480
precise wheel inputs at nominal 60 Hz, delta 16, reversing at 240.
The single-unit production executable hashes were
`2a4c5ca263a71dcf1cde0f816881cb89c0f667a2cd1f6e926c2a0fdb52e99847`
and `99d6e8590f0a7c7749c65dc5dc243e4707405edcb1daa6371fae4feaaac7eae5`.
Both used AVIF library SHA-256
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The diagnostic probe validated the filter function's symbol range against
the running executable image. Browser, driver and guard exits were 0 in
both runs. The guards sampled 1,399,734,272 B and 1,643,053,056 B peak RSS.
Host load on 18 CPUs was 6.04→7.00 and 11.93→17.04. These are instrumented
diagnostics and the additional image comparisons ran on the render path.

| Probe | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Direct crop | 15.70 | 66.31 / 113.42 / 178.95 ms | 124/144 | 480 / 169 | 52.22 Hz | 81.76 / 0.26 ms |
| Aligned crop | 12.49 | 81.00 / 145.53 / 193.21 ms | 111/125 | 480 / 145 | 47.86 Hz | 88.42 / 181.08 ms |

The throughput windows were 9.173 and 10.009 seconds from first to last input.
The endpoint was frame installation after native view paint.

The first run recorded zero direct filter sources before input and 258
during input and its tail. All were 2048×1760 drop shadows. The visible
portion had a median area of 79.2%. Median completion took 10.28 ms,
including 2.18 ms to prepare the input, 4.69 ms to render in Core Image
and 2.44 ms to draw in Quartz. Requesting the visible output directly
matched 11 of 20 sampled draws. Rounding the output bands to 64 device
rows matched all 20 draws in the second live probe.

The broader pixel fixture found one-channel rounding differences in 20
of 63 cases for the aligned crop. Keeping the full output and deferring
its render matched all 63 cases, with elapsed times of 6.44 and 6.74
seconds for 200 draws against 4.58 and 4.47 seconds for the immediate
control. Reusing bitmap access and mapping sparse input also took longer
than the immediate control in both fixture runs. These variants were
discarded.

### Temporary attribute setter replies

`d767892ff` gives attribute setters a short-lived serialization workspace.
JavaScriptCore copies the reply before the workspace retires. DOM values,
reactions and invalidation keep their existing owners. The generic element
query uses the same workspace for its attribute setter response.

The C-backend preallocation fixture wrote attributes eight times through
each path on an element with a 36,864-byte unrelated attribute. Both paths
returned the complete attribute snapshot and kept the written Unicode
values after workspace retirement. The combined document-arena growth was
under 64 KiB. All five trusted-attribute tests and both UTF-16 reflection
tests passed, including safeguards for callback exceptions, reentrant
policies, namespace handling and unpaired surrogate values. Both suites
also passed with the reply and input transport workspaces poisoned on
retirement. The compile and runtime guards exited 0. The runtime guards
sampled 84,459,520 B and 66,093,056 B peak RSS respectively.

Nine SVG comparisons passed with zero differing pixels on the previously
completed `99d6e8590f0a7c7749c65dc5dc243e4707405edcb1daa6371fae4feaaac7eae5`
bundle at 800×600. The capture driver and 3 GiB guard exited 0 and all
input, reference and executable hashes matched. This baseline predates
the attribute reply change.

The same completed bundle and Brave Chromium `158.0.8127.42` ran one fresh
live pair in Brave–Vox order. Each used a private profile and cache, direct
HTTPS and a 1024×768 document at scale 2. Both verified visible, complete
content with loaded fonts, 133 images and 15,620 UTF-8 bytes of root text.
The normalized text matched with generated UUIDs replaced. The audits
passed at 23.02 and 23.05 seconds. Settled footprint is the median over
the final three seconds of the following 12-second observation.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Brave | 335,192,296 B | 883,482,832 B | 51 |
| Vox baseline | 783,421,304 B | 1,218,482,040 B | 52 |

Process identities stayed fixed in both final windows. The browsers,
drivers and 3 GiB guards exited 0. The guards sampled 898,187,264 B and
1,049,837,568 B of peak RSS. One-minute host load on 18 CPUs was
5.54→5.45 and 5.81→4.49. The baseline used 2.34 times Brave's settled
footprint.

The worker then published single-unit C `-prod` receipt
`20261125-192653-2cd495a0` with executable SHA-256
`cdecff67a9324189ef24b4dba842efcaf1995ff8ce820ad8304e0e87c1349712`.
The generated C contains the new reply workspace after the native
mutation call. The compile and headless smoke guards exited 0 and
sampled 7,708,246,016 B and 119,767,040 B peak RSS. All nine SVG
comparisons on the published executable were pixel-exact again. Their
driver and 3 GiB guard exited 0 with 181,829,632 B peak RSS.

The live candidate passed the same document audit at 23.04 seconds.
It settled at **779,702,208 B** across 50 samples and peaked at
1,206,505,408 B. Process identity stayed fixed in the final window.
The browser, driver and 3 GiB guard exited 0. The guard sampled
1,030,733,824 B of peak RSS, and one-minute host load was 7.99→6.68.
The candidate's settled footprint was 2.33 times the Brave observation.
The 3,719,096 B difference between the two Vox builds includes other
production changes and live-run variation.

### Physical footprint breakdown

A separate launch of the published candidate passed the full patch audit at
23.02 seconds. After the 12-second observation, macOS `footprint` reported
778,407,848 B. Its largest category was 506,216,448 B of dirty memory in
untagged mappings, followed by 106,004,480 B in WebKit Malloc and 103,956,480 B
across IOSurface, graphics accelerator and unmapped graphics allocations.
`vmmap -summary` corroborated the untagged total at 482.5 MiB. The older
allocator trace above identifies some retained owners inside anonymous
mappings. The VM category cannot attribute the whole balance to those owners.

The browser, both diagnostic tools, driver and 3 GiB guard exited 0. The
guard observed 1,084,063,744 B peak RSS. Host load was 4.93→4.68 on 18 CPUs.
A preliminary diagnostic on the previous executable coincided with shared
bundle publication. Its browser exited 0 and its driver and guard exited 1
after the identity check. The table and breakdown use the stable launches.

### Resident pages in the allocator's live blocks

A fresh diagnostic launch used the published `cdecff67` executable, a
private profile and cache, and the same live HTTPS document and viewport.
It passed the complete patch audit. The injected probe selected the main
Mach-O executable and matched the block-header allocation caller against
the `vmemory_block_new_sized` symbol range. It tracked the allocator's
headers through reuse and used `mincore` to check mapped pages in each
still-live block. The snapshot completed at 37.44 seconds.

| Blocks | Live blocks | Bytes used by allocation cursors | Resident bytes |
| --- | ---: | ---: | ---: |
| Main document arena | 264 | 297,757,246 B | 292,405,248 B |
| Unscoped arenas | 163 | 98,877,910 B | 98,713,600 B |
| All measured allocator blocks | 513 | 411,712,829 B | 414,334,976 B |

The probe recorded 114,046 header creations, 113,533 retirements and zero
dropped or incomplete records. All 513 page-residency checks succeeded.
Allocation cursors and resident pages measure different quantities. Retired
headers and system allocator mappings are outside these totals. The
browser, driver and 3 GiB guard exited 0. The guard sampled 1,025,097,728 B
peak RSS, and host load on 18 CPUs was 5.71→5.13.

Two document blocks grew while cloning fetched script text. Together they
held 6,275,072 B of resident pages at the snapshot. This is the size of
the blocks reached by those growth stacks, including later allocations.
Two other growth stacks started in CPU pixel arrays for background JPEG and
stb decoding. Their blocks held 30.91 MiB of resident pages. The streamed
Fetch data path accounted for a growth stack with 13.67 MiB of resident
pages in its block. The browser also retained computed style projections,
invalidation queues and committed layout data in the document arena.

### Reuse of external script and stream response bytes

`d03cf6d29` shares immutable external script text when the browser has
already given its response a process-lifetime owner. Other responses
still give the delayed parser task a document-owned copy. Nine parser
request tests passed with the preallocated C backend. The new fixture
verified that both preload and worker-result paths executed directly from
the original 983,040 B buffer and resumed the parser with correct events.

`c2f4112af` removes a duplicate copy at the curl callback boundary and
hands each already-owned delivery buffer directly to the byte stream.
Seven Fetch tests passed, including readback of an owned chunk by
identity after another network delivery. All six native curl transport
tests passed using the existing `VOX_DISABLE_CURL_PIPEWAIT=1` control.
With the default setting, all 64 response bodies and events matched
but the concurrency fixture observed one concurrent connection and
failed its lower-bound assertion. A control that restored both copies
in the generated test code reproduced the same one-connection result
with all 64 bodies and completion events delivered.

A focused preallocation fixture delivered sixteen 256 KiB chunks and
verified every byte at EOF. In the same diagnostic executable, restoring
the copy in the stream enqueue path grew the allocation cursors by
13,112,319 B. Passing the owned chunk through grew them by 8,917,583 B,
a reduction of 4,194,736 B. The fixture starts at the Fetch receiver.
The compile and 3 GiB runtime guards exited 0.

### Live RAM before response-copy changes

A fresh Vox–Brave pair used the same live full-patch audit and process
footprint method as above. Vox was single-unit C `-prod` receipt
`20261125-193430-ae774619`, executable SHA-256
`b0238ff5933a7ae9fc37bc03c0c4ea3a6f45e08bc0a86f56c0bae3477f9cae62`.
Brave reported Chromium `158.0.8127.42`. Both included the complete
15,620-byte patch text and 133 image elements at the 23-second
audit. Final process identities stayed fixed.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Vox | 767,414,184 B | 1,176,440,744 B | 53 |
| Brave | 351,707,224 B | 870,326,336 B | 54 |

Both browsers, driver and 3 GiB guard exited 0. The guard sampled
959,610,880 B peak RSS. One-minute host load was 5.07→6.15 and 6.15→7.23.
Vox used 2.18 times Brave's settled footprint.

### Live RAM on the response-copy build

Single-unit C `-prod` receipt `20261125-194705-28f9e7fe` installed
executable SHA-256
`a1daa1e8050bedd8657e8e056d2b2c70e64b7222a41a92291d37c9f45e4caade`.
The sealed C contains both source ownership changes. The production
compile and headless smoke guards exited 0 and sampled 7,673,102,336 B
and 101,482,496 B peak RSS. All nine SVG source-switch and paint-server
reftests were pixel-exact at 800×600. The capture and 3 GiB guard exited 0
with pinned executable, resource and fixture hashes.

The next pair ran Brave first with the same audit and memory endpoint.
Brave and Vox confirmed the complete patch at 23.06 and 23.01 seconds,
respectively. Process identities stayed fixed in the final windows.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Brave | 344,874,856 B | 848,256,872 B | 52 |
| Vox | 675,975,056 B | 1,135,071,912 B | 54 |

The browsers, driver and 3 GiB guard exited 0. The guard sampled
1,000,472,576 B peak RSS. One-minute host load was 4.82→5.80
and 5.80→6.60 on 18 CPUs. The Vox result was 91,439,128 B lower
than the earlier build and 1.96 times the Brave observation.
Both live pairs include variation in the network, launch order,
and shared production changes.

An instrumented launch of the same executable recorded 22 script fetches
totaling 5,740,554 B. The allocation probe found no live block growth
stack through external script completion. A growth trace identifies
the allocation that expanded a block and does not count every copy.
The diagnostic read 594 live blocks at 36.89 seconds after 129,544
creations and 128,950 retirements, with zero dropped or incomplete
records. The main document arena had 353,878,016 B of resident pages,
and unscoped arenas had 98,238,464 B. The live preallocation blocks
held 491,552,768 B altogether.

macOS recorded a 787,681,216 B footprint after the instrumented
snapshot, including 498,335,744 B of dirty untagged memory. Document
blocks that grew while reserving dense map entries accounted for
47,284,224 B of resident pages. Their stacks led mainly through
independent formatting context layout, carried committed layout
records and compatibility box indexing. The browser, driver, footprint
tool and 3 GiB guard exited 0. The guard sampled 1,117,863,936 B peak RSS.
This diagnostic's higher footprint illustrates the run-to-run differences
in retained arenas and includes probe and request-log activity.

### Native scrolling on the response-copy build

Two fresh launches of the same executable used direct HTTPS, private
profiles and caches, retained OS caches, automatic scripting, and a
1024×768 document at backing scale 2. Both audits confirmed the
complete patch. The driver supplied 720 precise wheel events at
nominal 60 Hz after a 23-second settle from the matching title, using
delta 16 and reversing at 360 events.

| Trial | Scroll publications/s | Median / p95 / max scroll interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 21.49 | 47.31 / 71.23 / 123.28 ms | 257/278 | 720 / 316 | 55.59 Hz | 67.23 / 9.80 ms |
| 2 | 20.25 | 49.08 / 82.43 / 124.36 ms | 243/269 | 720 / 305 | 54.12 Hz | 64.10 / 11.10 ms |

Throughput covers the 12.934- and 13.285-second input windows. The
endpoint records frame installation after native view paint. The
document reached 12,031 and 12,063 CSS pixels and returned to the top in
both runs. One-minute host load on 18 CPUs was 5.19→4.27 and 4.27→5.30.
The browsers, drivers and 3 GiB guard exited 0. The guard peaked at
1,379,106,816 B RSS. Both runs remained well below the 60 Hz target.

### Reclaiming paint-box indices between layout passes

`7b8377990` rebuilds the first-box and last-box lookup maps in their
own arena. Replacing the paint tree resets the index. A full relayout
transfers the arena to the new result after clearing the old result's
lookup pointer. The lookup still resolves fragmented boxes in tree
order and keeps the Viewport's containing-block entry.

Three client-geometry fixtures passed, including eight repeated index
rebuilds with zero document-arena growth and a full relayout that
reused the index arena. They also passed with retired paint-tree and
index pages made inaccessible. The standalone layout package compile
exceeded the 12 GiB guard. The passing checks compiled the same test
bodies through the browser module, with 6,491,783,168 B peak compile
RSS. The compile and 3 GiB runtime guards exited 0.

`1d6ccb531` shares an immutable empty record when comparing missing
rare layout inputs. Before the change, the generated C allocated a
default record on each missing-input branch. The focused fixture
repeated matching and differing comparisons 256 times, including
diagnostic lookups, with zero allocation-arena growth. Its staged
preallocation compile and 3 GiB runtime guards exited 0.

### Live RAM with the paint-box index arena

The baseline executable was single-unit C `-prod` receipt
`20261125-195337-07b324e7` with SHA-256
`323b7d19437dff637c0e02e6ee9aca67fe21f0618c9b39779cdeb6e3468c1bef`.
The published single-unit C `-prod` receipt `20261125-200615-9febd3ff`
included the arena change in its generated C. Its executable SHA-256
was `ad82c4507bf9ac39e0bf86bfe8f4558c0b77000c95380a235fdf4109eff73172`.
The candidate build and headless smoke guards exited 0 and sampled
7,669,284,864 B and 133,103,616 B peak RSS.

The pairs used the same fresh profiles, caches, live HTTPS, 1024×768
viewport at scale 2 and full-content audit as above. They ran in
Vox–Brave and Brave–Vox order. Each confirmed the complete patch at
the first 23-second audit. All final process identities stayed fixed.

| Build and browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Baseline Vox | 688,934,704 B | 1,128,681,960 B | 52 |
| Baseline Brave | 333,422,536 B | 856,154,008 B | 57 |
| Index-build Brave | 353,116,032 B | 843,145,040 B | 55 |
| Index-build Vox | 677,121,840 B | 1,124,847,984 B | 55 |

All browsers, drivers and 3 GiB guards exited 0. The guards sampled
1,003,765,760 B and 991,264,768 B peak RSS. One-minute host load
on 18 CPUs was 5.11→4.59, 4.59→6.40, 5.72→5.13 and 5.13→5.92.
The index build used 1.92 times the paired Brave footprint.
The 11,812,864 B drop between Vox observations includes shared
production changes and live-run variation.

### Native scrolling on the paint-box index build

All nine SVG same-size source-switch and paint-server reftests were
pixel-exact on the candidate at 800×600. The capture, comparison and
3 GiB guard exited 0 with pinned browser, library and fixture hashes.
The guard sampled 195,706,880 B peak RSS.

Two fresh launches of the same bundle used the existing precise
wheel workload and complete live patch audit. Each used 720 events,
delta 16, nominal 60 Hz and reversal at 360, after 23 seconds from
the matching title. The 1024×768 viewport had backing scale 2.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 15.07 | 68.43 / 109.96 / 125.26 ms | 183/204 | 720 / 237 | 53.11 Hz | 68.06 / 178.07 ms |
| 2 | 19.10 | 55.82 / 78.79 / 137.47 ms | 226/248 | 720 / 281 | 55.38 Hz | 75.16 / 6.60 ms |

The input windows lasted 13.537 and 12.984 seconds. The endpoint was
completed frame installation after native view paint. The document
reached 12,098.5 and 12,070 CSS pixels and returned to the top. Host load
on 18 CPUs was 5.68→7.25 and 7.39→7.06. Both browsers, drivers and the
3 GiB guard exited 0. The guard sampled 1,294,057,472 B peak RSS.
Throughput was below the prior bundle's two observations. That build
comparison spans other production changes and different run conditions.

In a separate poisoned-arena trial of the same executable, 26 paint-index
blocks totaling 13,107,200 B of capacity retired before wheel input. One
1,048,576 B block retired inside the wheel interval. An interposed `mprotect`
checked successful page protections from the pinned executable's
`poison_prealloc_scope` symbol. Event timestamps excluded a 20 ms margin at
each input boundary. Those sizes describe retired capacity. The trial
completed all 480 wheel events and passed the full patch audit. The browser,
driver and 3 GiB guard exited 0, with 1,282,064,384 B peak sampled RSS and
one-minute load 5.30→5.52 on 18 CPUs. Two preliminary browsers and wheel
drivers completed successfully, but their wrapper and guard exited 1 while
validating the diagnostic flag and the resolved probe path, respectively.

### Live RAM with both layout allocation changes

Single-unit C `-prod` receipt `20261125-201551-cc7fa132` installed executable
SHA-256 `30500d29306cbb90a5dbd32a0eb127b2c370e955e8bcf2dc2cef2ab7da4363cf`.
Its sealed revision `9794688c2` includes both layout changes. The compile
and headless smoke guards exited 0 and sampled 7,669,219,328 B and
101,105,664 B peak RSS.

The next fresh pair ran Vox first. Both browsers confirmed the complete patch
at the first audit, 23.04 and 23.02 seconds after launch, respectively. The
1024×768 viewport at scale 2, direct HTTPS, fresh private profiles and caches,
and retained OS caches matched the earlier pairs. Pinned executables, libraries
and resources stayed fixed, as did process identities during the final window.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Vox | 684,117,856 B | 1,136,120,272 B | 55 |
| Brave | 314,154,784 B | 858,480,392 B | 56 |

Both browsers, the driver and its 3 GiB guard exited 0. The guard sampled
986,333,184 B peak RSS. One-minute host load was 5.02→5.87 and 5.87→5.45
on 18 CPUs. Vox used 2.18 times Brave's settled footprint. Across the three
pairs, live variation and other production changes overlap the measured
Vox differences.

### Native scrolling with both layout allocation changes

Two further fresh launches of the same executable passed the full live patch
audit. Each sent 720 precise wheel events at nominal 60 Hz, delta 16 and
reversal at 360, after 23 seconds from the matching title. All four scrolling
trials across these two builds pinned `libVoxAVIF.dylib` at SHA-256
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` and
`VoxAdblockWorker` at `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4`.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 20.69 | 49.03 / 77.45 / 133.02 ms | 244/267 | 720 / 301 | 55.73 Hz | 63.77 / 3.77 ms |
| 2 | 20.82 | 49.48 / 75.58 / 131.56 ms | 248/270 | 720 / 306 | 55.44 Hz | 60.25 / 10.46 ms |

The first-to-last input windows lasted 12.902 and 12.968 seconds. The
document reached 12,031 and 12,099.5 CSS pixels and returned to the top.
The endpoint was native frame installation after view paint. Both browsers,
drivers and the 3 GiB guard exited 0, with 1,389,346,816 B peak guard RSS.
One-minute host load was 6.31→7.54 and 7.54→6.89 on 18 CPUs.

```sh
VOX_TEST_WINDOW=1 sh tools/run_v_tool.sh run_memory_bounded \
  --lock "$job/scroll.lock" --report "$job/scroll-guard.json" --limit-gib 3 -- \
  python3 tools/measure_precise_scroll.py \
  --binary "$PWD/Build/v/Vox.app/Contents/MacOS/Vox" --output "$job/scroll-1" \
  --url https://www.dota2.com/patches/7.42a --require-title 'Dota Patch Notes - 7.42a' \
  --width 1024 --height 768 --chrome-height 112 --inputs 720 --delta 16 \
  --input-hz 60 --target-hz 60 --reverse-every 360 --settle-seconds 23 --timeout 65 \
  --script-policy automatic \
  --network-policy 'Direct HTTPS, fresh private profile and HTTP cache, retained OS caches' \
  --env "VOX_CAPTURE_AUDIT_PATH=$audit" --env "VOX_CAPTURE_AUDIT_CONFIG=$config" \
  --env VOX_NATIVE_OBSERVATION_DELAY_MS=22000
```

The audit config selects `#dota_react_root` and counts its `img` descendants.
The accepted document had 133 images and 15,620 UTF-8 bytes of patch text.
The UUID-normalized text SHA-256 was
`a17a1ac87c46cd03abde2d0ae3f58d1a1ff600dd72c10e5ef7187f675ce922fe`.

### Capturing the relayout snapshots once

`8c2cac0cf` stores the before and after geometry snapshots by value and
clones their rare geometry only when each snapshot is taken. The previous
generated C allocated temporary `UsedValues` records and cloned the rare
geometry again when publishing the map entry. The focused test binary's
record writer inserts the values directly into the map.

The browser-module fixtures verified that 128 independent contexts preserve
both snapshots after later edits to the source geometry and after eight
workspace retirements. The empty-input comparison fixture also passed.
Both tests ran normally and with `document geometry` arena reuse disabled.
The compile and 3 GiB runtime guards exited 0 with 6,496,305,152 B and
7,782,400 B peak RSS.

The C emitted for the production build of that commit still moved each
local `UsedValues` to heap storage. It did so even on calls that skipped
recording. `fd28b1093` carries both snapshots inline in the `RelayoutRecord`
instead. Inspection of the C from its focused build confirmed both direct
field assignments and the by-value record argument. Both fixtures passed
again, normally and with workspace poisoning. The compile and 3 GiB
runtime guards exited 0 with 6,451,609,600 B and 2,654,208 B peak RSS.
The commit hook requested the shared production rebuild.

A separate diagnostic on `30500d29` tried disabling incremental layout
to estimate how much its live records contributed. The control passed the
full audit at 23.01 seconds and settled at 676,597,576 B. The disabled launch
was still loading with an empty title and zero patch bytes at 59.35 seconds.
The driver closed that browser with SIGTERM and exited 1, as did the guard.
The control exited 0. The guard sampled 985,579,520 B peak RSS. The failed
audit ended the diagnostic before the second pair. It yielded no usable
comparison of the record footprint.

### Live RAM on the first relayout snapshot build

Single-unit C `-prod` receipt `20261125-202827-7588b02e` published executable
SHA-256 `3f021777d017a95715131e6fc059e865a6b70b41431a4151f508653daddd7a1c`.
It includes `8c2cac0cf`. The shared worker was building the inline-record
follow-up when this pair finished. The measured build and headless smoke
guards exited 0, sampling 7,654,080,512 B and 119,832,576 B peak RSS.

The pair ran Brave first with fresh profiles, pinned inputs and the same
viewport and full live patch audit. Both passed at the first audit, 23.05
and 23.06 seconds after launch, respectively.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Brave | 328,327,088 B | 846,012,336 B | 51 |
| Vox | 688,197,472 B | 1,133,203,968 B | 52 |

Both browsers, driver and 3 GiB guard exited 0. The guard sampled
1,001,652,224 B peak RSS. One-minute host load was 7.44→7.66 and
7.66→7.40 on 18 CPUs. Vox used 2.10 times Brave's settled footprint.

### Releasing relayout record maps by layout pass

`65fcdbef5` gives the last-call, first-call and text-control record maps a
native layout-state arena. The maps copy their values when a pass carries or
clones records. Referenced geometry retains document ownership. Replacing
the published state, rejecting a candidate pass and retiring the document
release the corresponding map buffers. A suspended page keeps its active
records until its layout publisher retires.

Nine focused cases passed through the browser module, both normally and with
`relayout records` and `document geometry` arenas poisoned at retirement.
The native case checked three viewport layouts, record slot ownership,
preserved snapshot data, and rejection of a cloned incremental attempt.
It verified zero capacity in the old record arena after each of two
replacement layouts and after deactivation. The suite also covered first-call
flex answers, retained line painting, and native document retirement.
The test compile and 3 GiB runtime guards exited 0 with 6,481,870,848 B
and 2,736,128 B peak sampled RSS.

An initial lifetime assertion used document destruction as the deactivation
boundary. The fixture now uses the document's inactive-layout hook and tests
the suspended case before deactivation. An expanded browser test run
hit SIGBUS while the nested textarea fixture resolved its focused cursor.
The same test and cursor stack reproduced on a separately compiled control
with the record arena changes reverted. Both runs and their 3 GiB guards
exited 138. This leaves the full browser typing check unresolved.

### Live RAM and readiness before relayout map recycling

The installed single-unit C `-prod` executable remained
`3f021777d017a95715131e6fc059e865a6b70b41431a4151f508653daddd7a1c`.
A fresh Vox–Brave pair held executable, helper and resource hashes fixed
through the same direct HTTPS, private profile and cache protocol. Both
confirmed the complete patch at 23.04 and 23.05 seconds, respectively.

| Browser | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: |
| Vox | 669,339,560 B | 1,121,522,344 B | 56 |
| Brave | 354,492,360 B | 881,811,376 B | 56 |

Both browsers, driver and 3 GiB guard exited 0. The guard sampled
1,031,471,104 B peak RSS. One-minute load was 6.44→6.20 and 6.20→5.63
on 18 CPUs.

A separate Vox diagnostic observed the full patch at 4.16 seconds using a
250 ms repeating native audit. The timing log recorded 28 document layout
passes through shutdown, 14 with tree rebuilds. The logged layout calls
totaled 359.68 ms inclusive of 34.98 ms of style time. The browser, driver
and 3 GiB guard exited 0, with 993,394,688 B peak RSS and one-minute load
6.30→6.07. This startup observation includes audit and timing instrumentation.

### Live RAM on the relayout map build

The shared single-unit C `-prod` build `20261125-205113-4a675b7f` compiled
from `b669cbb35` with the relayout record arena implementation in the
working directory. The generated C contains the arena retirement and the
inline snapshots from `fd28b1093`. The installed executable SHA-256 was
`b27e26e3422e1d900dffe0347b9dce7ff99cd10bddac6bd42578e2e6c456b9cf`.
The production compile and headless smoke guards exited 0 with peak RSS
of 7,703,642,112 B and 79,757,312 B.

The first comparison stopped when Brave's native window stayed hidden.
The second ran Vox first and its full patch passed at 23.05 seconds.
Vox's settled footprint was 735,022,944 B across 52 samples, with a peak of
1,175,507,576 B and one-minute host load 6.42→4.87. The Brave retry also
stayed hidden after a targeted activation attempt. Both Brave runs reached
the expected text, images and viewport. The browser processes exited 0.
The drivers and 3 GiB guards exited 1, with peak guard RSS of 781,598,720 B
and 1,057,423,360 B. The higher Vox observation spans shared build changes
and live-launch variation. The candidate runs establish no matched RAM
comparison against Brave.

The production arena diagnostic audited the full patch at 3.95 seconds.
It observed 29 retirements totaling 10,680,360 B of allocation cursor usage
and 30,388,480 B of reserved capacity, including the retired state's map
storage at shutdown. The largest retired pass used 1,518,496 B. These
figures sum the arena allocations through the launch. The instrumented
browser, driver and 3 GiB guard exited 0. The guard sampled 1,003,667,456 B
peak RSS and one-minute load was 3.92→3.86.

### Native scrolling on the relayout map build

Both fresh launches completed the full native wheel protocol and the live
patch audit. The viewport, backing scale, settle period and input schedule
match the preceding runs. The AVIF library and adblock helper SHA-256 hashes
also match. All nine SVG source-switch and paint-server comparisons were
pixel-exact at 800×600 with executable, helper and reference pins intact.
The capture, comparison and 3 GiB guard exited 0 with 181,059,584 B peak RSS.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 21.58 | 46.30 / 72.63 / 126.53 ms | 262/282 | 720 / 287 | 55.02 Hz | 56.73 / 3.86 ms |
| 2 | 22.99 | 43.44 / 67.39 / 122.08 ms | 278/297 | 720 / 302 | 55.66 Hz | 57.11 / 4.91 ms |

The input windows lasted 13.069 and 12.918 seconds. The document reached
12,065.5 and 12,061 CSS pixels before returning to 4.5 and 0 CSS pixels.
The endpoint was completed native frame installation. Both browsers,
drivers and the 3 GiB guard exited 0, with 1,365,590,016 B peak guard RSS.
One-minute host load was 3.71→3.26 and 3.26→3.60 on 18 CPUs. Roughly 93%
of scroll intervals exceeded 16.67 ms. Host load and other shared
build changes prevent attributing the higher observed rate to record storage.

### Resident pages in the free-block pool

The next production receipt `20261125-205709-4a1ea4df` installed executable
SHA-256 `f5fc8b33a6626ba4e16fdb3902c1754c05c6a8ccee0346f3332d3cb43c36b29f`.
A diagnostic resolved the allocator pool symbol in that executable,
checked its generated C field layout, and verified the UUID and slide
of the loaded Mach-O executable. It sampled the locked pool with `mincore`
while Vox loaded and showed the complete live patch.

At the final sample, around 34 seconds after launch, the 44 free blocks
reserved 46,420,928 B. Their resident pages totaled 2,752,512 B.
All 34 samples accounted for every block. Sampled residency peaked at
51,707,904 B earlier in the launch. The small settled pool residency
accounts for little of the diagnostic's 682,610,552 B settled footprint.
The browser, driver and 3 GiB guard exited 0 with a 990,625,792 B peak
guard RSS and one-minute host load 3.63→4.43.

The first browser launch also passed the content audit and exited 0.
Its probe rejected block lengths that ended within a page, so the driver
and guard exited 1. The successful probe rounded the page count for those
mappings and still accounted for their exact logical sizes.

A separate uninstrumented launch of the same executable confirmed the
full patch at 23.01 seconds. It settled at 667,668,344 B over 52 samples,
with a sampled peak of 1,115,640,440 B and one-minute load 3.43→3.39.
Brave completed the expected patch in a normal native window, but reported
hidden document visibility through 59.70 seconds. Restoring and activating
that private window did not restore visible document state. Both browsers
exited 0. The driver and its 3 GiB guard exited 1 with 969,228,288 B peak
guard RSS. The Vox observation is valid on its own. The last complete
Brave comparison remains the control at 354,492,360 B.

### Releasing the DOM attachment workspace

`59b3c7a53` scopes the dense DOM mirror table, fallback identity map and
inline-fragment cache to one attachment traversal. The published mirrors,
text, caret provider and paintable geometry keep their document lifetime.
Copies of a published mirror can still materialize its earlier visual lines.

Nine attachment fixtures passed through the browser module. Both the normal
run and a run with the `DOM layout attachment` and `inline box pieces`
arenas poisoned passed. The native fixture rebuilt the workspace eight
times, checked ownership of the dense slots, fallback entry and pieces,
and kept document-arena growth below 12 KiB. Published text and visual
lines remained readable. The compile and 3 GiB runtime guards exited 0
with 6,487,408,640 B and 36,012,032 B peak sampled RSS.

### Live control before releasing attachment storage

Single-unit C `-prod` receipt `20261125-210603-b2c6160e` published executable
SHA-256 `217ed8355ca8144364a5a96da3786ccdeb0898d635aacd38546c1f7f23d86a44`.
Vox passed the full patch audit at 23.01 seconds. Its settled footprint
was 671,879,032 B across 52 samples, with a 1,121,702,328 B sampled peak.
Brave loaded the expected title, text, images and viewport, but its
document visibility remained hidden through 59.72 seconds. Its first
activation attempt reported the private process still inactive. Both
browsers exited 0. The driver and 3 GiB guard exited 1 with 978,337,792 B
peak guard RSS. One-minute host load was 5.51→6.12 and 6.12→5.15.

A distinct Brave trial used LaunchServices to open a fresh native instance.
The guard adopted the signed browser PID from the private registry. The
patch text and all 133 images appeared, but at 59.67 seconds the document
still reported hidden visibility and an empty title. The launcher and
browser exited 0. The driver and guard exited 1, with 1,352,269,824 B peak
guard RSS and one-minute host load 3.29→4.58.

### JavaScriptCore collection diagnostic

Four instrumented launches used the same control executable, with a
250 ms native content audit. The probe checked the main Mach-O executable's
UUID, tracked context creation and release, and sampled one live context
group on the main queue about 25 seconds after launch. Each browser passed
the full patch audit before and after its observation window.

The public `JSGarbageCollect` call took 6 µs. The sampled footprint
was 732,778,408 B both immediately before and immediately after the call.
The observation-only run also held steady across its sample. The group
was live in both runs. Upstream implements that public call by reporting
an abandoned object graph. [WebKit JavaScriptCore API implementation](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/JavaScriptCore/API/JSBase.cpp)

A second pinned probe used JavaScriptCore's synchronous debugging collector
and its heap statistics. Heap usage fell from 57,170,359 B to 51,788,125 B
in 5.15 ms. Protected objects stayed at 3,957. Process footprint changed
from 700,338,016 B to 700,518,240 B immediately after collection and was
700,436,320 B one second later. The observation-only run retained its
56,995,816 B sampled heap across the same point. All four browsers,
their drivers and the 3 GiB guards exited 0. The guards sampled
1,017,856,000 B and 996,179,968 B peak RSS. These diagnostic launches
changed the audit cadence and JavaScriptCore calls, so their absolute
footprints vary with instrumentation and live state.

### Live RAM on the attachment workspace build

Single-unit C `-prod` receipt `20261125-212159-e36f0a83` includes
`59b3c7a53` at sealed revision `f2ecdb7f4`. Its executable SHA-256 was
`2b3e7efd95a6e874743f6d486907d231b7d02e9d7fb3cde110c060d84e39649b`.
The production compile and headless smoke guards exited 0, with
7,668,629,504 B and 103,972,864 B peak RSS. Earlier shared attempts
stopped after checkout inputs changed before C preprocessing.

The fresh Vox window confirmed the full patch at 23.03 seconds. It
settled at 721,735,568 B over 52 samples and peaked at 1,180,439,136 B.
Brave completed the full patch but stayed hidden through 59.69 seconds.
Both browsers exited 0. The driver and 3 GiB guard exited 1, with
1,016,971,264 B peak guard RSS. One-minute host load was 3.59→3.50
and 3.50→3.26 on 18 CPUs. The two production builds included other
shared changes and the observations varied across launches.

A separate live diagnostic observed the complete patch at 3.22 seconds.
It logged 46 attachment workspaces totaling 295,648 B of cursor use.
The largest used 11,696 B, with 1,417 dense slots. The live document
created zero inline-fragment cache entries in these traversals.
The browser, driver and 3 GiB guard exited 0, with 963,575,808 B peak
guard RSS and one-minute host load 3.26→3.29. The workspace total
measures released allocation cursors over the launch.

### Native scrolling on the attachment workspace build

Two fresh launches passed the complete patch audit at 1024×768 and scale 2.
They used direct HTTPS, private profiles and caches, automatic JavaScript,
and 720 precise wheels at nominal 60 Hz with delta 16. Input began 23 seconds
after the matching title and reversed at event 360. Both runs pinned the
same AVIF and adblock helper hashes as the relayout map trials.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 22.87 | 44.06 / 68.32 / 120.36 ms | 267/292 | 720 / 295 | 56.31 Hz | 56.44 / 10.36 ms |
| 2 | 22.65 | 44.87 / 67.62 / 122.90 ms | 275/296 | 720 / 301 | 55.02 Hz | 62.13 / 6.74 ms |

The input windows lasted 12.769 and 13.069 seconds. The document reached
12,061 and 12,062.5 CSS pixels, then returned to 0 and 3.5. The endpoint
was completed native frame installation. Both browsers, drivers and the
3 GiB guard exited 0, with 1,354,563,584 B peak guard RSS. One-minute host
load was 3.74→4.81 and 4.81→3.86 on 18 CPUs. The observed rates were within
the prior relayout map build's range and missed most 60 Hz deadlines.

All nine SVG source-switch and paint-server reftests were pixel-exact at
800×600. The pinned build, helpers and reference files stayed unchanged.
The capture, comparison and 3 GiB guard exited 0 with 185,024,512 B peak RSS.

### Footprint regions on the attachment workspace build

Another fresh launch of the same executable passed the full patch audit at
23.02 seconds. It settled at 784,912,272 B across 54 samples and peaked at
1,236,832,912 B. A macOS `footprint` snapshot after the 12-second observation
reported the same settled total for the main process. The largest dirty
categories were 509,853,696 B of untagged mappings, 104,267,776 B of WebKit
Malloc and 103,956,480 B across IOSurface, IOAccelerator and unmapped
graphics allocations. The memory tool, browser, driver and 3 GiB guard
exited 0. The guard sampled 1,097,170,944 B peak RSS. One-minute host
load was 4.16→5.22 on 18 CPUs.

## Resident allocation owners and pending style invalidations

The live control was single-unit C `-prod` receipt `20261125-212936-1293ba54`,
with executable SHA-256
`29080a84257991cb8e599d92a2fc2b0e36c08bad7df0add03d9e78862ba04a11`.
Both launches used fresh profiles and caches, direct HTTPS and a 1024×768
document at scale 2. The complete patch audit checked the visible document,
title, 133 images and the existing 15,620-byte text digest. The memory
endpoint was the median across the last three seconds of a 12-second
observation starting at the first successful audit.

| Vox control | First passing audit | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: | ---: |
| Allocation tracing | 23.00 s | 702,697,336 B | 1,125,879,672 B | 52 |
| Standard launch | 23.04 s | 662,703,968 B | 1,106,563,440 B | 54 |

The temporary diagnostic checked the executing Mach-O UUID and allocator
symbol range. It tracked V allocator block creation and frees, then
sampled resident pages with `mincore` on the main queue. At about 35 seconds,
526 live blocks accounted for 419,069,952 resident bytes, with 119,655
observed creations, 119,129 retires and no dropped records. The main
navigation document arena accounted for 294,322,176 resident bytes in
266 blocks. The main thread's base arena accounted for 82,821,120 bytes.
The separate `footprint` snapshot reported 702,566,264 B physical footprint
and 425,820,160 B dirty untagged mappings. Resident pages and physical
footprint are distinct accounting measures.

Seven main document blocks totaling 15,433,728 resident bytes had grown
while converting CSS plans to DOM invalidation rules. Another 22 blocks
totaling 22,495,232 resident bytes had grown while constructing selector
invalidation caches. Growth stacks classify the allocation that opened a
block. They can include bytes subsequently used by other call paths.
Both Vox processes, their drivers and the 3 GiB guards exited 0, with 976,224,256 B
and 968,441,856 B peak guard RSS. One-minute host load was 5.72→5.56
and 8.83→7.29 on 18 CPUs.

`18c44dfcf` scopes CSS plan merges and DOM payload conversion to the
native document's pending invalidation batch. It builds the rule cache
before entering that arena. Descendant and sibling dispatch can continue
reading the plans until the queue drains, and document closure releases any
outstanding batch.

Six staged preallocation cases passed normally and with the pending-plan
and selector-construction arenas poisoned at retirement. The native case
tested a lazy rule-cache rebuild, three class toggles across both descendant
and sibling selectors, placement of queued match data outside the document
arena, public snapshot reads after retirement, and closure with pending
work. The other cases covered existing inert, relational and local-link
invalidation behavior. The compile and 3 GiB test guards exited 0 with
6,473,449,472 B, 10,502,144 B and 36,749,312 B peak RSS.

### Published build and live memory

Single-unit C `-prod` receipt `20261125-214923-2508873f` sealed
`18c44dfcf`. The executable SHA-256 was
`80a967c9d87ada4663e9f3e2f874eb06812489f7c270a3dc51bbb6f3d58ae430`.
The production compile and headless smoke guards exited 0 at peak RSS of
7,706,673,152 B and 89,473,024 B. The AVIF, adblock helper and adblock
asset hashes matched the control runs.

| Vox candidate | First passing audit | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: | ---: |
| Standard launch | 23.05 s | 664,817,552 B | 1,121,473,072 B | 54 |
| Allocation tracing | 23.03 s | 660,213,600 B | 1,117,819,464 B | 52 |

The candidate trace observed 111,076 block creations, 110,596 retires
and zero dropped records. The 480 live blocks accounted for
391,315,456 resident bytes. Main document residency was 251,379,712 B
in 232 blocks. The new pending-plan arena had zero used bytes and
16,384 resident bytes. Zero live block growth stacks included the plan
conversion. The separate selector cache construction still appeared in
22 blocks totaling 22,495,232 resident bytes. The physical footprint
snapshot measured 660,082,528 B overall and 398,098,432 B in dirty untagged
mappings. Both fresh processes, their drivers and the 3 GiB guard
exited 0, with 981,712,896 B peak guard RSS. One-minute host load was
5.36→4.80 and 4.80→5.21.

The traces confirm the allocation lifetime change on the live page.
The standard candidate settled 2,113,584 B above its standard control.
Other shared changes and normal variation across live loads limit
attribution of whole-process differences. The last valid Brave
comparison measured 354,492,360 B. The current macOS session was
screen-locked through the live checks, so a fresh visible Brave
comparison remains pending.

### Live precise scrolling and reference pixels

Two fresh processes per build passed the full patch audit. The guarded
`tools/measure_precise_scroll.py` runs used 720 native precise wheel events
at nominal 60 Hz, delta 16 and reversal at event 360. Input began 23
seconds after the matching title. The viewport was 1024×768 at scale 2
with 112 pixels of chrome, automatic JavaScript, fresh profiles and
HTTP caches, and direct HTTPS. The endpoint was completed native frame
installation after view paint.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control 1 | 21.25 | 47.11 / 72.64 / 129.54 ms | 255/278 | 720 / 282 | 54.95 Hz | 57.99 / 0.48 ms |
| Control 2 | 22.64 | 44.37 / 67.87 / 122.69 ms | 278/297 | 720 / 302 | 54.81 Hz | 55.08 / 0.16 ms |
| Candidate 1 | 23.63 | 42.12 / 66.00 / 118.62 ms | 284/310 | 720 / 313 | 54.81 Hz | 54.72 / 8.92 ms |
| Candidate 2 | 22.67 | 44.65 / 69.42 / 115.84 ms | 271/294 | 720 / 299 | 55.44 Hz | 56.18 / 6.99 ms |

The input periods were 13.084, 13.119, 13.119 and 12.969 seconds. The
document reached 12,064, 12,061, 12,057.5 and 12,062 CSS pixels, then
returned to the top. All browsers, drivers and 3 GiB guards exited 0.
The control and candidate guards sampled 1,306,214,400 B and
1,354,678,272 B peak RSS. One-minute host load on 18 CPUs was
6.77→6.83, 6.83→5.99, 5.21→3.50 and 3.46→4.73. The two cohorts ran in
build order, with lower host load during the candidate runs. Both
cohorts missed most 60 Hz deadlines.

At 800×600, `nth-child-of-class` and `nth-child-of-has` matched their
upstream pixel references for both builds. Each case produced identical
actual PNG bytes across builds. Both comparison and guard runs exited 0
with 163,627,008 B and 177,291,264 B peak guard RSS.

## Releasing temporary image probe allocations

`369394d25` gives layout's intrinsic-size and isolated SVG source probes
a temporary allocator scope. Intrinsic size returns numeric fields.
Isolated SVG parsing runs in the image document's own storage while the
source probe remains readable. Remote probes use the already parsed URL
and remove its fragment only when looking up the fetch response.

Four focused C-backend preallocation cases passed normally and with
`VOX_ARENA_NO_REUSE='layout image probe'`. The native case read a 256 KiB
extensionless SVG response and probed a missing URL eight times without
advancing the document arena cursor. It checked the parsed SVG's retained
URL, view box and relative child URL after the probe retired. The compile,
standard runtime and poisoned runtime guards exited 0 at sampled peak RSS
of 6,453,919,744 B, 21,381,120 B and 262,144 B.

### Live control

Single-unit C `-prod` receipt `20261125-215649-36a0ec39` published
SHA-256 `14f76a2a6e63d0d8b2de5b88f4c65d6a92cf54a1b283b5ea16cd1e34231de3cb`.
A fresh shared publication superseded the previous planned control before
its launcher started a browser. That attempt exited 1 at the identity check.

The live launches used the 1024×768 viewport at scale 2, direct HTTPS and
fresh private profiles and caches. Both passed the full patch audit with
133 images, 15,620 UTF-8 text bytes and the established normalized digest.
The endpoint was the
median browser process-tree physical footprint over the final three seconds
of a 12-second window after the first passing audit.

| Vox control | First passing audit | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: | ---: |
| Standard launch | 23.02 s | 673,419,152 B | 1,090,195,344 B | 51 |
| Allocation tracing | 23.05 s | 699,502,480 B | 1,128,632,232 B | 52 |

The diagnostic checked the running Mach-O UUID, sealed allocator header
layout and symbol address ranges. It tracked main-thread V allocator block
creation and retirement under the intrinsic-size and SVG document probes.
At about 35 seconds, 18 intrinsic-size growth blocks held 18,874,368 B of
resident pages. One SVG document growth block held 1,048,576 B. Together
the two paths accounted for 7,088 tracked creations and 7,069 retirements.
`mincore` reported resident pages for every live mapping. The tracker
dropped zero records. A growth stack attributes the block to its first allocation.
Other allocations can use the same block.

Both fresh processes, their drivers and the 3 GiB guards exited 0 with
929,382,400 B and 963,608,576 B peak guard RSS. One-minute host load was
5.01→5.04 and 4.40→5.73 on 18 CPUs.

### Published build and live memory

Single-unit C `-prod` receipt `20261125-220515-c448ff98` sealed
`6638b0783`, which includes `369394d25`. The executable SHA-256 was
`05da72a103b91f93c7a80af2955f8655c8e058a574f91b4929b7c73b216dea64`.
The sealed C and executable contained the two probe paths. The compile
and headless smoke guards exited 0 with 7,673,004,032 B and 131,072,000 B
peak RSS. An earlier shared attempt stopped before C preprocessing
after checkout inputs changed. The AVIF library, adblock helper and
adblock asset hashes matched the controls.

| Vox candidate | First passing audit | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: | ---: |
| Standard launch | 23.01 s | 684,543,888 B | 1,095,258,000 B | 52 |
| Allocation tracing | 23.05 s | 677,711,784 B | 1,096,257,400 B | 52 |

The diagnostic counted all 5,248 tracked intrinsic-size blocks and 700
tracked SVG document blocks as retired at the sample. It dropped zero
records. The control still had 19 blocks totaling 19,922,944 resident
bytes whose growth began in these paths. Both candidate processes, their
drivers and the 3 GiB guard exited 0 at a guard peak of 949,125,120 B.
One-minute host load was 3.91→4.60 and 4.31→3.06 on 18 CPUs.

The live trace confirms the shorter allocation lifetime. The standard
candidate measured 11,124,736 B above its standard control. Whole-browser
results include other shared changes and live-load variation. Brave's
last valid visible observation was 354,492,360 B. The macOS session
reported a locked screen for this cohort, so a fresh visible Brave
comparison remains pending.

### Native scrolling and reference pixels

Both builds passed the live full-patch audit on each of two fresh
`tools/measure_precise_scroll.py` launches. The 1024×768 document used a
scale of 2 and default 112-pixel chrome. The runs used direct HTTPS,
private profiles and HTTP caches, retained OS caches and automatic
JavaScript. After 23 seconds from the matching title, each run sent
720 precise wheel events at nominal 60 Hz with delta 16 and reversal at
event 360. The endpoint was completed native frame installation.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control 1 | 21.72 | 46.42 / 73.11 / 138.52 ms | 257/281 | 720 / 285 | 55.58 Hz | 58.14 / 5.34 ms |
| Control 2 | 21.91 | 45.10 / 70.50 / 130.71 ms | 263/287 | 720 / 290 | 54.88 Hz | 57.63 / 8.85 ms |
| Candidate 1 | 24.36 | 41.26 / 62.68 / 123.18 ms | 297/320 | 720 / 324 | 54.74 Hz | 62.74 / 10.82 ms |
| Candidate 2 | 22.68 | 43.82 / 68.19 / 119.40 ms | 273/293 | 720 / 301 | 55.66 Hz | 54.30 / 3.18 ms |

The first-to-last input windows lasted 12.935, 13.101, 13.135 and
12.919 seconds. The document reached 12,095.5, 12,063, 12,054.5 and
12,028 CSS pixels and returned to 0, 0.5, 0 and 0. All browsers,
drivers and 3 GiB guards exited 0. The guards sampled 1,319,960,576 B
and 1,320,419,328 B peak RSS. One-minute host load on 18 CPUs was
4.06→4.56, 4.56→4.70, 3.06→2.37 and 2.26→3.74. The cohorts ran in
build order and the candidate had lower host load. Most frame intervals
missed the 60 Hz budget.

The nine SVG source-switch and paint-server reftests were pixel-exact
on both builds at 800×600. All corresponding actual PNGs matched byte
for byte across builds. Reference inputs and runtime hashes stayed pinned.
Both comparison and 3 GiB guard runs exited 0, with sampled peak RSS
of 235,143,168 B and 255,787,008 B.

A separate candidate launch used a repeating 250 ms native audit. It
first observed the complete visible patch at 3.81 seconds. Its browser,
driver and 3 GiB guard exited 0 with 950,255,616 B peak guard RSS and
one-minute host load 4.55→4.20. This diagnostic uses an earlier and more
frequent audit than the RAM cohort.

## Copies at the native Fetch boundaries

`e4cfdf3c1` passes libcurl's callback buffer directly to the receiver.
The receiver copies it synchronously into the stream delivery, sniff and
cache storage that it needs. Fetch's full-body collector reads each
delivered chunk during the callback and appends it to its accumulator.
Public incremental callbacks receive independent storage for asynchronous
consumers.

Twelve focused C-backend preallocation tests passed. They exercised the
native body callback with a reused input buffer, compared received chunk
identity for borrowed and public readers, and checked buffered input,
streamed input, EOF and error behavior. The compile and 3 GiB test
guards exited 0, with 6,506,102,784 B and 19,775,488 B peak RSS.

Six broader socket and proxy fixtures failed under the standalone test
driver. Separate private profiles and the pipe-wait override did not
resolve the failures. A control with the original native callback copy
restored reproduced all six failures, including requests with zero active
transfers before any body delivery. The isolated candidate and control
drivers and 3 GiB guards exited 1, with peak RSS of 13,598,720 B and
25,395,200 B. The control compile exited 0 at 6,499,074,048 B peak RSS.

### Live launches and copy diagnostics

The single-unit C `-prod` control was receipt
`20261125-221521-a0ddf206`, executable SHA-256
`f39a97dd16779ec05ce9dce29864188a6132cd6038d5b1f268450f23e78db2aa`.
The shared build published the candidate source in receipt
`20261125-222108-2ad23468` at sealed revision `f2ddd8a44`, with executable
SHA-256 `d61519f126aea5c731df5e1f46b86de4959dde6eb405c812b5a88b28f5313ca4`.
The generated C contained the borrowed reader path and disassembly showed
that the native body callback's direct array clone was gone. Production
compile and headless smoke guards exited 0 at peak RSS of 7,646,740,480 B
and 122,322,944 B. One later control attempt stopped at the identity check
before launch after the shared bundle changed.

Each accepted launch used live direct HTTPS, fresh private profiles and
HTTP caches, and a 1024×768 viewport at scale 2. The visible page matched
the 133-image, 15,620-byte full-patch audit and normalized text checksum.
Settled footprint is the browser process-tree median across the last
three seconds of the 12-second interval after the first passing audit.

| Launch | First passing audit | Settled footprint | Sampled peak | Settled samples |
| --- | ---: | ---: | ---: | ---: |
| Control standard | 23.03 s | 688,099,192 B | 1,101,041,528 B | 51 |
| Control growth trace | 23.06 s | 668,929,912 B | 1,083,740,024 B | 52 |
| Candidate standard | 23.04 s | 709,447,568 B | 1,124,503,440 B | 52 |
| Candidate growth trace | 23.02 s | 680,955,744 B | 1,098,993,504 B | 54 |

The first diagnostic interposed byte copies and aborted at browser startup
with exit −6. That driver and its guard exited 1. The replacement diagnostic
checked the running Mach-O UUID, allocator header layout and callsite
addresses. At about 35 seconds it found zero block-growth stacks matching
the two clone callsites on either build. Nine native curl GETs completed
with HTTP 200 and transport result 0 in the candidate trace. The allocator
probe measured block growth, so the number and size of live copies remain
unmeasured. All four accepted browsers, drivers and guards exited 0.
The two control guards and the shared candidate guard sampled 959,692,800 B,
948,846,592 B and 977,633,280 B peak RSS. One-minute host load was
5.58→4.93, 22.54→22.47, 16.85→16.74 and 16.74→11.85 on 18 CPUs.

The standard candidate measured 21,348,376 B above its standard control.
The cohorts include different host load, live resources and shared code
changes. The last valid visible Brave result was 354,492,360 B.
The macOS session was locked during this work.

### Native scrolling on the published bundle

Two fresh launches of the candidate passed the full patch audit using
`tools/measure_precise_scroll.py`. Each used 720 precise native wheels at
nominal 60 Hz, delta 16 and reversal at event 360, starting 23 seconds
after the matching title. The document viewport was 1024×768 at scale 2
with 112 pixels of chrome. Both used automatic JavaScript, direct HTTPS,
fresh private profiles and HTTP caches, and retained OS caches.

| Trial | Scroll publications/s | Median / p95 / max interval | Over 16.67 ms | Inputs / completed publications | Actual input rate | Leading / trailing scroll gap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 21.19 | 47.61 / 74.82 / 128.48 ms | 257/278 | 720 / 283 | 54.80 Hz | 56.86 / 0.16 ms |
| 2 | 21.75 | 46.53 / 71.32 / 120.42 ms | 266/286 | 720 / 291 | 54.67 Hz | 59.00 / 2.04 ms |

The input windows lasted 13.120 and 13.151 seconds. The page reached
12,065.5 and 12,098.5 CSS pixels and returned to 0 and 3.5. The
endpoint was completed native frame installation. Both browsers,
drivers and the 3 GiB guard exited 0, with 1,279,967,232 B peak guard
RSS. One-minute host load was 9.25→6.87 and 6.87→5.79. The cohort
missed most 60 Hz deadlines.
