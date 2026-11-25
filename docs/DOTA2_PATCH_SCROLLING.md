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
