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
