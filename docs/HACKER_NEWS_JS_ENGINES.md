# Hacker News: V8 and cold/warm LibJS

This compares Vox's JavaScript/DOM integrations on the archived 101-comment HN
discussion, using the complete unchanged `hn.js`. It measures HTML parsing,
runtime/binding setup, script initialization, a first collapse/expand, 100 more
collapse/expand cycles, and an explicit native-cache checkpoint. It excludes
process startup, external network, a native window, document layout/painting, PNG capture,
correctness audits and teardown. The reported total sums those measured spans;
it is not a continuous browser navigation or rendering time.
Adblock is disabled in every mode to exclude filter-list initialization.

## Results — 2026-11-15

Seven complete groups used one optimized source-built executable containing
both backends. Each cell below is an independently computed median in ms.

| Measured interval | V8 | LibJS cold | LibJS warm, restarted | LibJS warm, same process |
| --- | ---: | ---: | ---: | ---: |
| HTML/runtime/script initialization | 122.200 | 33.657 | 37.250 | 30.306 |
| First collapse/expand | 6.532 | 3.659 | 4.327 | 4.928 |
| Next 100 collapse/expand cycles | 259.788 | 340.742 | 335.808 | 363.416 |
| Cache compilation/finish checkpoint | 0.000084 | 557.463 | 0.005791 | 0.000333 |
| **Total measured spans** | **388.847** | **938.405** | **378.223** | **398.756** |
| Total minimum–maximum | 373.595–389.493 | 909.468–960.414 | 374.530–388.431 | 396.102–424.894 |

Warm restarted LibJS takes **40.3% of cold time**, approximately **2.48× faster**
for this workflow, principally by avoiding first-visit compilation. Warm/cold
callback medians differ by only about 1.4%; the native tier does not demonstrate
a reliable callback-throughput improvement here. Same-process parser reuse
reduces initialization relative to restart, but its callback interval is slower
and its total is higher. No causal explanation for that difference is established.

V8's repeated-callback median is **259.788 ms versus 335.808 ms** for restarted
LibJS: warm LibJS takes **29.3% longer** in that interval. Every V8 callback
trial is faster than every restarted-LibJS callback trial. These intervals
include the engines' different browser DOM bindings and synchronization.
Overall totals are close: restarted LibJS/V8 is 0.972679 by the ratio of medians,
0.980599 by the median paired ratio, and **1.039711** by highest-LibJS/lowest-V8.
Their overlapping total ranges do not establish an overall winner.

| Group | V8 total ms | LibJS cold ms | LibJS restarted ms | LibJS same-process ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 386.657001 | 909.468334 | 388.430624 | 397.674916 |
| 2 | 389.244750 | 940.624209 | 378.223291 | 424.893543 |
| 3 | 373.594917 | 931.644792 | 374.530167 | 404.373875 |
| 4 | 389.075459 | 932.395249 | 376.452792 | 403.836750 |
| 5 | 388.847000 | 958.040876 | 381.302959 | 396.101917 |
| 6 | 389.492749 | 938.405417 | 380.518541 | 398.091917 |
| 7 | 380.673875 | 960.414001 | 377.023500 | 398.755793 |

Every cold visit compiles **27 executables with one clang invocation**. Both
warm modes load all 27 with zero native misses, invalid entries or compiler
invocations. Restart reparses one source; same-process reopen records one
frontend hit and zero misses. Median clang compilation itself is 389.714 ms;
first library loading is 159.296 ms. Warm library loading is 3.104 ms after
restart and 2.914 ms in the same process. Those costs are already included above.
Each separate warm diagnostic records 37,471 native callback entries, 177,457
fast steps and 342,390 dynamic-helper steps; cold records zero native entries.
Timed visits have all activity counters disabled/zero and no script errors or
native-engine fallback.

The 18-logical-CPU host's one-minute load ranges from 10.98 to 11.70. All 24
processes (three diagnostics and 21 timed processes), the driver and runtime
guard exit zero. Runtime guard peak sampled aggregate RSS is 386,007,040 bytes
under 3 GiB; duration is 28.096 s. The final source build uses current V
`0.5.2 cbfc1be`, C/clang, literal V `-prod -no-prod-options`, `-O2`, one C unit,
no LTO and default Boehm GC. It finishes in 287.442 s with sampled peak
12,435,816,448 bytes under the unchanged 12 GiB guard; compiler/guard exit zero.
This is a source-built headless benchmark, not the installed production bundle's
allocator/build configuration. Seven Python evidence-validation tests also pass.
Benchmark tooling is committed as `9dcf51f62`. The executable was built from the
shared canonical checkout with concurrent uncommitted work; its binary identity
and sealed generated-C hash in the local build context identify the measured
artifact, rather than a claim that it is a clean build of that tooling commit.

V8 reports **14.6.202.34-node.40**. Pinned SHA-256 identities:

* Executable: `a75333d531086eaeacf76baffe08549a80009594d8b6587d3301fc84940abf37`
* V8 adapter: `ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb`
* Homebrew libnode: `a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef`

The exact results, outputs, commands, process identities, host readings,
per-cache library hashes and replay requests remain local in
`docs/performance/hn-engines-20261115/cohort-r6/results.json`; build/guard logs
and prior attempts are retained beside it. The initial harness diagnostics
identified duplicate-ID dispatch, missing navigation settings and an inactive-VM
counter read; they yielded no accepted cohort. A rebuild stopped for a harness
correction exits 143. The subsequent live-image cohort is invalid: V8 host
setup fetched images over the internet. Its 23–24 s V8 totals are retained and
earn no optimization credit from switching to replay. The first replay rejects
the discussion fixture's local asset-base URLs. The final replay explicitly
aliases those two URLs to hash-identical retained images and passes all checks.

## Workload and cache policy

The three primary modes are V8 in a fresh process, LibJS in a fresh process with
an empty native cache, and LibJS in another fresh process using that cache.
Restarted LibJS reparses the script; it cannot reuse the process-local frontend
cache. A fourth observation reopens a fresh document/VM in the first LibJS
process and can reuse both native code and the parsed source. Both warm modes
replace clang with `/usr/bin/false` before creating their runtimes.

The first LibJS workload executes before its explicit cache checkpoint. Its
reported total includes compiling cache-eligible executed functions for subsequent visits.
There is no claim that production idle tasks have the same scheduling or that
cached native instructions alone account for changes in total time. V8 uses
Vox's compact/native DOM bridge; LibJS uses its direct native bindings. These
are actual browser integration paths, rather than isolated engine throughput.
Callbacks form a synchronous burst without per-click native window/run-loop
turns; their timings do not establish interactive input latency.

The fixture hashes are:

* `hn.js`: `2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0`
* Discussion HTML: `04bfd8b86c3a9098e4e4a8428e65142e4144d5f8184d66b802b26243baf19c07`

V8's native image host eagerly initializes the fixture's images; that local
fetch/decode work remains inside its initialization interval. LibJS's direct
binding installation does not eagerly fetch those images. Both processes use
the sealed HN original-response archive through the same loopback SOCKS replay
and private TLS certificate, with forwarding disabled and a new HTTP cache per
process. The fixture retains its existing local-assets `<base>`: its `s.gif`
and `y18.svg` URLs are explicitly aliased to archived bodies only after verifying
they match the retained discussion assets byte for byte. HTML and author-script
bytes are unchanged. All 16 replay requests (two per V8 process) return archived
HTTP 200 responses; no request is missing or forwarded. This setup difference
also limits interpreting initialization/total ratios as engine-only speed.

Every visit verifies navigation cancellation, actual collapse of the first
subtree, restoration of all 101 comment-row classes, absence of script errors
and empty interpreter frames. Warm visits must reuse the entire compiled cohort
without compiler invocations, native misses or invalid entries. A separate
diagnostic verifies native execution. Timed visits disable diagnostic counters.
The driver also verifies that the executable's JavaScript context/evaluation
imports bind to `libVoxJSCOnV8`, and records the backend's actual V8 version.

Seven groups alternate V8-first and LibJS-first order. Cold/reopen/restart order
is intrinsic to the cache workflow. Each group has a new private native cache
and each process a private profile. OS filesystem/loader caches are retained.
Executable, native libraries, fixtures and benchmark sources are hashed and
checked throughout. The raw local receipts retain every attempt, commands,
environment, PIDs, outputs, exits, exact timings, native/cache counters and host
load/timestamps.

## Reproduction

Build the V8 adapter and one source-built executable containing both backends.
No browser bundle is copied or manually rebuilt. Keep compilation and runtime
inside their separate memory guards; use the default 12 GiB for compilation
and 3 GiB for runtime. Generated C and binaries stay outside `Build/`.

```sh
mkdir -p /tmp/vox-hn-engines
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/hn-v8-UNIQUE.lock --report Build/hn-v8-UNIQUE.json -- \
  clang++ -std=c++20 -O3 -fPIC -dynamiclib -fvisibility=hidden \
    -I/opt/homebrew/include/node -Ibrowserjs/v8/include \
    browserjs/v8/jsc_on_v8.cpp /opt/homebrew/lib/libnode.147.dylib \
    -framework CoreFoundation -Wl,-rpath,/opt/homebrew/lib \
    -Wl,-install_name,@rpath/libVoxJSCOnV8.dylib \
    -o /tmp/vox-hn-engines/libVoxJSCOnV8.dylib

env V3_STR_CAP=1 V_MACOS_V3_NO_FALLBACK=1 \
    VOX_CHROME_TEST_FILE=sites/hacker_news_engine_benchmark_test.v \
  sh tools/run_v_tool.sh run_memory_bounded \
    --lock Build/hn-build-UNIQUE.lock --report Build/hn-build-UNIQUE.json -- \
  sh tools/test_address_bar.sh -w -n -b c -no-parallel -cc clang \
    -memory-limit 10G -prod -no-prod-options -d vox_v8 -skip-running \
    -cflags '-O2 -I/Users/alex/code/vox/browserjs/v8/include' \
    -ldflags '-L/tmp/vox-hn-engines -lVoxJSCOnV8 -Wl,-rpath,/tmp/vox-hn-engines' \
    -o /tmp/vox-hn-engines/hn-engines

sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/hn-run-UNIQUE.lock --report Build/hn-run-UNIQUE.json -- \
  python3 tools/benchmark_hn_engines.py \
    --binary /tmp/vox-hn-engines/hn-engines \
    --output docs/performance/hn-engines-UNIQUE --pairs 7 --cycles 100

python3 -m unittest discover -s tools -p benchmark_hn_engines_test.py
```
