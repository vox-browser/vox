# Old Reddit: compiled LibJS, V8 and JSC — 2026-11-17

Compiled LibJS is slower and uses more process RAM on this recovered Reddit
script/DOM workload. For 100 collapse/expand cycles, its median is **657.184 ms**,
versus **266.793 ms for V8** and **409.549 ms for JavaScriptCore**: **2.4633×**
and **1.6047× slower**, respectively. Every LibJS trial is slower than every
V8/JSC trial, including their retained outliers. This is an integration
measurement, not a general engine ranking or a live-page loading/rendering result.

Seven alternating groups use fresh processes, documents and private profiles.
The RAM column comes from a separate seven-group cohort with the same workload.
Each cell is an independently computed median; interval medians need not sum to
the median total.

| Measured interval | V8 | JSC | Compiled LibJS, fresh-process reopen |
| --- | ---: | ---: | ---: |
| HTML/runtime/script initialization, ms | 165.995 | 151.516 | 302.891 |
| First measured collapse/expand, ms | 24.039 | 27.156 | 13.570 |
| Next 100 collapse/expand cycles, ms | **266.793** | **409.549** | **657.184** |
| Callback calling-thread CPU, ms | 266.197 | 400.139 | 656.711 |
| Cache-finish checkpoint, ms | 0.000 | 0.000 | 0.005 |
| Sum of measured spans, ms | **458.854** | **587.481** | **971.913** |
| Root-process peak RSS after 100 cycles, MiB | **516.438** | **421.391** | **2,011.219** |

The measured-span total is 2.1181× V8 and 1.6544× JSC. LibJS's root-process
peak is 3.8944× V8 and 4.7728× JSC. RSS includes common Vox infrastructure,
the fixture, bridge allocations and loaded code; it is not an isolated engine
heap, physical footprint, aggregate process-tree RAM or a normal browser-tab
memory measurement. The V host uses preallocation with GC disabled in every
build; V8 and JSC retain their own garbage collectors. These peaks are specific
to completing 100 synchronous cycles in this headless harness, without browser
frames or an event-loop settle between cycles.

| Group | V8 callbacks, ms | JSC callbacks, ms | Compiled LibJS callbacks, ms |
| --- | ---: | ---: | ---: |
| 1 | 261.840208 | 403.413583 | 648.640125 |
| 2 | 268.754125 | 409.549250 | 657.183625 |
| 3 | 291.103875 | 500.738041 | 664.668833 |
| 4 | 263.095625 | 416.372791 | 655.208250 |
| 5 | 405.864167 | 404.882709 | 668.479333 |
| 6 | 266.792792 | 409.968167 | 655.138500 |
| 7 | 265.077541 | 408.283625 | 684.821917 |

Callback ranges are 261.840–405.864 / 403.414–500.738 / 648.640–684.822 ms.
Separate memory-cohort RSS ranges are 516.266–516.641 / 421.250–421.469 /
2,011.156–2,011.234 MiB. All attempts and outliers are retained, with no retries
or sample exclusions within these completed cohorts. There is no optimization
acceptance target or claim that an implementation change earned a speedup.

## Empty cache and actual native reuse

One separately labelled empty-cache seed initializes the page, runs the same
100 cycles interpreted, then fills the native cache. Its cache-finish checkpoint
takes **158.203 seconds**, including **155.721 seconds in 11 compiler calls**
and library loading/bookkeeping. Initialization is 274.780 ms, callbacks
744.209 ms and the sum of measured spans is 159.236 seconds. This is **one cold
observation**, not a seven-sample cold median or a live first-navigation time.

The seed compiles 1,391 executables from 1,392 misses; the pending-key map
deduplicates identical executables. Every reopened timing/memory visit loads all
1,391 with **zero misses, invalid/pending entries or compiler calls** and
`VOX_LIBJS_NATIVE_COMPILER=/usr/bin/false`. OS filesystem caches remain warm;
parsed-source/realm state is new in every process. V8/JSC also start fresh
contexts, without a persistent code cache configured by this harness.

A separate three-cycle LibJS diagnostic enables counters only after
initialization and records **11,062 native entries**, 414,951 fast steps and
114,098 helper steps. LibJS never initializes a JSC/V8 context. Timed native
activity counters are all zero. V8's separate diagnostic reports actual V8
calls/callbacks, and both native builds verify their imported engine symbols.
Thus the compiled path executes the callback workload; an engine selector alone
is not the evidence.

## Workload and boundaries

The fixture is the same recovered `old.reddit.com/r/programming/` page used by
the [compatibility investigation](LIBJS_OLD_REDDIT.md), including all original
author script bytes. Its added self-reporting probe supplies two representative
nested comments and a dropdown, and calls Reddit's actual handlers once during
initialization. The first timed cycle is therefore the first **additional**
cycle, not the first ever invocation of those functions. This is not an archived
complete discussion or a benchmark of a large comment subtree.

The source-built test uses the actual browser document-script initialization.
LibJS binds native DOM records; V8/JSC keep their existing compact DOM bridge.
Callback spans include native DOM MouseEvent dispatch, Reddit/jQuery execution,
activation bookkeeping and compact mutation synchronization where applicable.
Audits require real collapsed/expanded classes, `[+]`/`[–]` labels, restored
comment classes, successful menu self-probe, no unexpected script diagnostics,
empty VM interpreter stacks and the expected engine context identity.

Reddit's `togglecomment` returns `undefined`; its inline handler does not cancel
the `javascript:void(0)` link. The harness preserves the parser-owned HTML
browsing context and accepts that expected non-replacing default action.
It does not install the windowed browser's JavaScript-URL navigation hook or
measure evaluation of that URL by the browser app.

Initialization measures HTML parsing, runtime/bridge setup, original scripts,
readiness dispatch and the added probe. It includes one locally replayed image
and one blocked `reddit.com:443` HSTS-pixel connection per native-engine visit;
LibJS does not eagerly request those images. Each completed cohort records
16 archived image responses and 16 denied connections. Missing replay traffic
never reaches the external network. This incomplete-resource/bridge difference
limits interpretation of initialization as an isolated JavaScript comparison.
The expected badge-fetch console message is allowed; other startup/callback
diagnostics fail the visit.

Totals sum disjoint measured spans. Process startup, fixture reads/hashing,
correctness audits, teardown, external network, native windows, viewport layout,
painting and PNG capture are excluded. This cannot establish live-site page
load, native pointer latency, scrolling performance, pixel parity, voting or
additional-comment loading. The prior installed-browser validation remains
separate.

## Artifacts and validation

Both private executables use current V, literal `-prod -no-prod-options`,
preallocation, `-gc none`, a sealed single C unit and clang `-O3`, without LTO.
They contain identical benchmark source SHA-256
`c28f2e25eb2781f8dffc3e778891717dc6862c30024c2e42905aae196e9c7552`.
Exact parsed-source manifests, frozen native-input receipts and actual binaries
identify the shared dirty checkout used for compilation. This is not a claim
about code contained in the older shared production bundle.

* V8 executable: `d42b0680990b7c3979fb6ab57eccd8eb454b85d384d4746c317691c3edcaaf94`.
* JSC/LibJS executable: `ed40cc3c41951e4a655c02be03735cfd68087a9abf1ac0a9541a60b85618965f`.
* V8 14.6.202.34-node.40; adapter
  `ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb`;
  libnode `a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef`.
* System JavaScriptCore 22625.2.8.11.9, macOS 27.2 (26B123). System images in
  dyld's shared cache are identified by the OS/framework versions; available
  executable/native-library files are hashed throughout the cohort.
* Fixture manifest `30110a369fae6d4198106cc92021365cf0604573ffa9d212ae50e72f1b4ec764`;
  HTML `1ea757603125fe1a5ac537e31971b4570dc3ba5fa121fad4fb6987c9410e9e63`.
* Native cache ABI `812aba8dedf9cfb6996a8cdf0aab5f04d4a1aa23b1dd32894d1f102632c5f972`.

The 18-logical-CPU Apple M5 Max host has 128 GiB RAM. Own builds finish before
timing. Other sessions remain active: one-minute loads during the timing
attempts range 6.597–7.336 and during memory attempts 5.233–6.012. Observations
are qualified by this host and these build/cache conditions.

The completed timing cohort has 25 successful processes (one cold seed, three
eligibility diagnostics, 21 timed visits); memory has 24 (three diagnostics,
21 visits). All child/driver/guard exits are zero, with unchanged pinned inputs.
The timing guard's sampled aggregate peak is 3,079,061,504 bytes under 3 GiB,
including the cold compiler tree; memory's guard peak is 2,174,877,696 bytes.
Those guard metrics differ from the root-process RAM table. Builds use separate
12 GiB guards and peak below 9.1 GB. Seven Python harness/receipt checks pass;
both backend benchmark builds and all functional visit audits execute.

An initial harness seed failed before producing a timing result: the copied HN
setup replaced the parser's actual HTML context with a bare DOM context and hit
a WindowProxy identity panic during activation. HN's cancellation expectation
was also inappropriate for Reddit's handler. Both harness assumptions were
corrected before rebuilding and collecting the cohorts above. Its original
binary identities, failure output and nonzero guard exit are retained rather
than counted as an engine result or silently dropped.

Benchmark tooling is committed in `d559bb335`:
`sites/reddit_engine_benchmark_test.v`, `tools/benchmark_reddit_engines.py` and
the generalized entry option in `tools/build_hn_engine_benchmark.py`.
Raw commands, all attempts, counters, process/guard exits, host records, input
pins and replay logs remain local under
`docs/performance/libjs-old-reddit-perf-20261117/`. Private executables, build
receipts and the native cache remain under
`~/Library/Caches/Vox/benchmarks/libjs-old-reddit-20261117/perf-20261117/`.
Generated C, preprocessed units and static link scratch were removed after the
measurements, retaining their hashes and completed build receipts.
No app bundle or source tree was copied; managed commit rebuild requests remain
coalesced, with no extra production build queued for this measurement.
