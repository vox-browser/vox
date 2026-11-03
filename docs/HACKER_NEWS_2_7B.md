# Hacker News 2.7B instruction target

The requested **2,700,000,000 instruction target remains open**. Acceptance
requires seven complete fresh default-production trials with both median and
maximum observed coalition instructions at or below that ceiling. The earlier
[3.2B result](HACKER_NEWS_3_2B.md) remains independently recorded.

The latest complete default-production benchmark (`font-final-matched`,
executable `7b96605d1ea4d26f7fa565202e6a7b5976a2ddf0064f2aa2ee2dafd346ca6fd9`,
receipt `20261103-123257-90afe652`) measures **2,743,357,004 median /
2,747,482,367 maximum**. All 21 captures in its three-arm comparison pass
pixels, content, PNG stability, ownership, input identity and normal-exit audits.
Its control and key-only medians are 2,732,051,974 and 2,730,827,883. A bounded
font-key string cache saves only 1,224,091 between medians; adding parent font
reuse regresses by 12,529,121. Both prototypes and their authored, unexecuted
tests have been removed and retained under `rejected-font-caches/`. The last
default launch overlaps the first HarfBuzz loading diagnostic; this contention
is retained and prevents clean attribution of that last pair. The full cohort
misses the target regardless. The restored source needs a fresh default cohort.

An earlier default cohort (`current-default2`, executable
`98dfbb7c3afab2edc29657540910b8f66d2b3454d98ef9598def8383f442400b`,
receipt `20261103-120605-b5e5859e`) measures **2,732,796,959 median /
2,761,467,363 maximum**. All seven launches pass their original pixel/content/
identity/ownership/exit gates and the current metadata-stability reference.
This bundle includes two subsequently rejected experiments: absolute font-size
keywords and deferring an unused capture bitmap allocation. The later complete
`capture-keywords-matched2` triples measure 2,728,184,571 control,
2,729,885,374 keyword-only and 2,734,342,675 default medians. The two additions
regress by 1,700,803 and 4,457,301 respectively, with four and five pair
regressions. Both are removed. The preceding interrupted cohort is invalid
because the shared executable changes during pair five; all 13 attempts remain.

Scalar font computation has a complete seven-pair comparison:
**2,786,028,007 → 2,781,226,985** medians, six improving pairs and one regression.
The separate `scalar-font-path` diagnostic confirms the ordinary font algorithm
runs without length-metric setup, with exact output. An initial V sum-type guard
generated invalid C and failed production builds `112240`, `112823` and
`112936`; the guard now uses an explicit match and the later production build
compiles. Those failures remain recorded.

Separately packed numeric network-filter buckets measure
**2,790,114,724 → 2,783,043,167** medians, five improving pairs and two
regressions. All fourteen captures are exact. A native diagnostic observes
zero packed category reads after initialization and 34 after the archived
requests; all rules and bucket ordering remain available. Private-helper GC
markers measure **2,804,006,798 → 2,797,206,773** medians in an injected diagnostic,
with five improving pairs and two regressions. The private helper reports one
marker, retains concurrent collection and every JIT tier, and preserves explicit
caller overrides. The synchronous-collection arm supplies no retained setting.
The packaged helper also links successfully without ICU/Brotli/font libraries,
using system zlib; no helper runtime suite has been run. These focused changes
remain pending the deferred regression checks.

A further host-class sharing pilot saves only 1.89M between two-pair medians
with one regression and is rejected. Warm-up settings of 2,500 and 40,000 add
32.71M and 2.07M in their two-pair pilots, so the existing 10,000 setting remains.
A diagnostic relinks the same installed HarfBuzz 15.0.0 static archive and
retains the reachable OpenType/CoreText/Graphite shaping code. Exact captures
and loader diagnostics show GLib/gettext/PCRE2 remain unloaded. The first
seven-pair cohort fails ownership during concurrent BBC captures. The second
stops after twelve captures because the canonical Hacker News driver changes;
its proposed independent-capture ownership handling is a concurrent edit and
must be assessed separately. Neither cohort earns performance credit. Production
source now selects the same-version archive with its original explicit FreeType
and Graphite dependencies; the shared build is pending. No new font suite runs.
The raw first loader diagnostic overlaps the final font-cache trial and is
instrumented; its counts supply no performance credit.

The resumed session's fresh default cohort (`current-default`, executable
`406aaa0e2a9130580d16bfcadc8ee08c8b0fa05f59cd9f0ec2ee18383b342808`,
receipt `20261103-110455-30b1ed31`) measures **2,773,701,537 median /
2,794,997,061 maximum**. Its seven counts are 2,782,153,587; 2,794,997,061;
2,767,817,025; 2,751,259,111; 2,773,701,537; 2,777,617,960; 2,772,592,607.
Every original pixel/content/identity/ownership/exit gate passes, and guard PID
adoption succeeds. Regression suites remain deferred. The target remains open.

Shared Build cleanup removed the earlier `Build/hn-2700-20261103` directory and
historical Vox metadata-reference PNG before this resumed session's inspection.
The committed ledger below retains earlier counts and identities, but its
missing raw artifacts cannot currently be independently rechecked. Fresh raw
evidence is under `Build/hn-2700-resume-20261103`, with a new
[durable ledger](performance/hn-2700-resume-20261103.json). The original archived
page bytes, author scripts, capture scope and pixel reference are unchanged.
For metadata stability only, new captures are compared against the first fresh
exact control PNG (`advance-path2/pair-1-control/document.png`); this establishes
matched current profile/density/chunk equality, without claiming recovery of the
historical metadata reference.

A fresh native glyph-advance cache prototype is rejected. It preserves exact
output in all fourteen matched captures but measures 2,793,316,549 control versus
2,790,389,005 candidate medians, a saving of only 2,927,544 instructions. Four
pairs regress. Both arms use the same executable and pinned private native bridge;
this diagnostic earns no default-production target credit. Source and authored,
unexecuted checks are preserved in the fresh evidence directory, and the cache
is removed from production source. A separate delayed-startup sampling run
supplies diagnostic stacks only. Scalar font-property computation and plain
font-family list restoration avoid unnecessary length-metric setup. Their fresh
matched result is recorded above; regression suites remain deferred.

The scope and correctness gates remain unchanged: exclusive browser coalition
creation through encoded document PNG availability; archived homepage and all
five resources with original scripts; fresh private profiles/caches; 1024×768
CSS pixels and 2× capture; two-second settling; exact reference pixels, complete
30-story audits, unchanged PNG profile/density/metadata, executable/native/input
identity and helper ownership checks, normal exits and adopted PID registry.
OS filesystem/shader caches remain retained. GPU/outside-service work remains
excluded. These are frozen-page startup/capture counts, without a new Brave
comparison, isolated rendering-time result or scrolling claim.

The first baseline uses executable SHA256
`d9ac8f02f93515ca33b5fee082d265e8cb794741c44d1fac6a201e8811bc7481`,
production receipt `20261103-034934-2de85867`. All seven trials pass the gates.
Counts are 3,098,032,236; 3,084,365,131; 3,085,350,784; 3,087,995,816;
3,078,770,416; 3,061,093,081; 3,068,584,644. Median is **3,084,365,131** and
maximum **3,098,032,236**, both above the target.

Raw commands, identities, host load, PNGs, extended metadata audits, ownership
records and counters are in `Build/hn-2700-20261103/baseline/`; the memory guard
is `Build/hn-2700-baseline-20261103-guard.json` (normal exit, successful adoption).
The new personal driver retains the previous protocol and metadata reference,
with only the requested instruction ceiling changed. No references or
tolerances are changed. Every attempt will be retained.

The user's instruction to run tests only after reaching the goal remains in
force. Benchmark correctness audits remain enabled; suites are deferred until
the 2.7B instruction gate passes. A first injected sampling diagnostic rendered
exactly but captured no usable stacks and changed bundle identity during its
run; it is retained as invalid and supplies no performance credit.

The preceding complete seven-pair production cohort is
`tokenized-preloads-matched`, executable SHA256
`b2c78a1c7959754aae157be4b03471e6260370865935892aa5c7db4dcec01066`,
receipt `20261103-074640-eeb788bc`. Its default median is **2,911,506,984**
instructions and maximum **2,917,899,987**. All fourteen captures pass the
unchanged pixel/content/PNG/identity/ownership/exit gates. The matched control
median is 2,918,739,304, a **7,232,320** difference; two pairs regress by about
10.42M and 6.05M. A separate debugger capture confirms the tokenized preload
path executes, with exact output; debugger counts earn no performance credit.
Required regression suites remain deferred, so this is benchmark progress,
with **2.7B still open**. The
[durable ledger](performance/hn-2700-progress-20261103.json) retains raw counts,
pinned inputs, guards and all earlier attempts.

The earlier `semantic-matched` production cohort remains recorded:
2,950,799,202 default median and 2,953,553,447 maximum. Its initial semantic
interner adds about 2.13M against its control and earns no isolated credit.
The later geometry cache uses the broader interner together with conservative
projection invariants; its matched result is recorded below.

A subsequent seven-launch default cohort (`helper-strip-default`) uses executable
`2cd7a62071b209a7e5028a2b290b7a85bff82f9afc107e4f9cd68aeff513292a`,
receipt `20261103-075630-018eebea`. All gates pass; the median is **2,908,600,006**
and maximum **2,915,031,268**. Its stronger helper dead stripping does not remove
ICU/Brotli dependencies, so the absolute result supplies no isolated attribution.
A later two-launch diagnostic (`current-default-pilot`) reaches 2,892,199,045
median but cannot replace the required seven-trial cohort.

An earlier complete matched production cohort, `initial-background-matched`,
uses executable `7b7b6983906c38dd92d3d052162b98c61e5419cbbca5084bd1b3ea1c450847f8`,
receipt `20261103-082817-8bf5ceb0`. Starting a bounded set of computed background
requests before geometry, together with conservative pending-repaint resource
refresh, measures **2,920,329,627 → 2,915,840,402** medians; the default maximum
is **2,927,760,540**. All fourteen captures pass the unchanged gates, but two
pairs regress. Diagnostics confirm one early request. The pending-repaint success
marker is absent on this workload; an attempted debugger breakpoint targeted an
inlined-away symbol and establishes no eligibility. This modest result remains
an experiment, without a completed-feature or target claim.

Separate profiles identify image-completion restyling after first geometry and
rejected longhand-cache inputs (`vertical-align: inherit`, inherited border
colors, `font-weight: bolder`, background images and font-relative margins).
The source now consumes only already-buffered initial image completions before
first geometry. A diagnostic confirms two ready responses and exact pixels.
The preceding complete cohort, `ready-inherit-matched3`, uses executable
`f5d3441370685d8d032fffe76deeb5c727aff0b0c46c2f85637b09084c4d1fad`,
receipt `20261103-084947-ca92c271`. Its seven default trials measure
**2,834,461,737 median / 2,852,355,429 maximum**, with all 21 captures passing
the original gates. The matched image-completion control measures
2,895,680,613 median: a **61,218,876** difference, with every pair improving.
The earlier attempt has an ownership failure; the second attempt stops after
eight captures because the production bundle changes. Both remain invalid.

The expanded longhand cache snapshots explicitly inherited non-inherited parent
inputs. Its separate control measures 2,890,073,543 versus 2,895,680,613 median:
a **5,607,070 regression**, with five of seven pairs slower. This experiment
and its authored tests are removed from source and preserved under the raw
evidence root. No regression suite has been run.

A direct text-surface experiment first used RGBA Skia blitters and changed
reference pixels, while retaining PNG profile/density/metadata. It is rejected.
The revised path keeps the original BGRA format, crop, matrix and surface
properties, temporarily swapping only an eligible private rectangular bitmap
region and detaching earlier Quartz snapshots before writing. A diagnostic
confirms 215 eligible draws. Seven `glyph-surface-bgra-matched` pairs on the
same executable with a pinned private native bridge measure
**2,832,080,113 → 2,821,580,780** medians; candidate maximum is 2,825,335,713.
Every pair improves and all fourteen captures pass the unchanged gates. Its
authored coverage/ownership tests are deferred. The later production cohort
below contains this change, and the 2.7B target remains open.

The `startup-candidates-matched` cohort uses executable
`e9deac23254d41499763f0436838ba75fe4e8d1671932b38b19fb79cce68dac5`,
receipt `20261103-090239-9d1c7c6d`. All 21 captures pass the original gates;
its seven default launches measure **2,807,099,437 median / 2,818,971,939 maximum**.
Injected checksum and eager-bootstrap arms are slower than this uninjected
default. Their injected-library startup costs prevent isolated attribution.
The bootstrap experiment remains diagnostic only. A separate phase probe
attributes about 17.6M to factory parsing, 14.7M to first-call preparation,
19.6M to WebGL initialization, and 17.4M to Window/final bootstrap setup.
Those are instrumented diagnostic counts, without optimization credit.

The preceding complete cohort, `crc-production-matched`, uses executable
`c9ff98ac0d59e91e9a378147d8a62e1130780f2902e994c5bd038cd3c7af68d6`,
receipt `20261103-091717-6b3a184e`. A bounded Apple Silicon CRC implementation
preserves the complete IEEE checksum and incremental/null-buffer behavior,
retaining zlib for other targets or the explicit control. The seven default
launches measure **2,804,458,189 median / 2,812,566,441 maximum**. The same-build
zlib control measures 2,809,859,668 median: a **5,401,479** difference, with
six pairs improving and one regressing. All 21 captures pass every original
gate. The third arm combines one GC marker with synchronous collection and
measures 2,790,856,430 median / 2,808,756,103 maximum, with one pair regression.
That setting is not retained in source; its runtime tradeoffs still need review.

The subsequent `crypto-font-arena-matched` cohort uses executable
`8952628605d7026f7f5817a8b8149ff3cbdd0249f2402a609e2a6212c571f4d5`,
receipt `20261103-093652-b9f00af8`. All 28 captures pass every original gate.
Seven default launches measure **2,771,570,435 median / 2,814,519,462 maximum**.
Control, lazy-WebCrypto-only, and arena-update medians are 2,800,670,315;
2,781,037,085; and 2,779,956,520. Deferring WebCrypto saves **19,633,230**
between medians (six improving pairs, one regression); arena updates save
1,080,565 (six improving pairs, one regression). The final absolute-font-size
step saves 8,386,085 between medians but regresses in four pairs, including
34.6M and 10.5M increases. Its gain remains uncertain. The default maximum
still exceeds the requested ceiling by 114,519,462.

The WebCrypto table resolves all 145 typed symbols and returns ordinary operation
failures after a missing or incomplete library. A component diagnostic observes
18.2M instructions loading that library. The initial links expose seven omitted
ECDSA names; the corrected generator passes a compile-only shared-library check
referencing all 38 native adapters without linking OpenSSL. In the later
`webcrypto-loading-path` diagnostic, eager launches load `libcrypto.4.dylib` and
report `ready=1`; lazy launches do neither. All four diagnostic captures are
exact. Library-loading logs add overhead, so those counts earn no performance
credit. The authored functional and memory-safety suites remain deferred.

The latest completed build, executable
`46147ed291e0edb492574449f5f44ca72a5dd94a5b7fa69672b4058c576fb083`,
receipt `20261103-094946-b5a443b3`, also contains a full literal-cascade cache.
Separate diagnostics confirm its path executes with exact pixels. Seven
`cascade-matched` pairs pass all fourteen original correctness audits but
measure **2,785,972,164 control → 2,792,384,585 default medians**, a **6,412,421
regression**. Four pairs regress; default maximum is 2,816,743,866. This cache
and its unrun tests are removed from source, with the patch preserved in
`Build/hn-2700-20261103/rejected-cascade-result/`. That bundle cannot validate
the restored source. New delayed-startup sampling captures remain separate
instrumented diagnostics; they identify semantic page equality as another
candidate, without establishing an instruction saving.

JSC collection pilots retain every launch. A single-marker setting is promising
in two alternating pilots, but the seven-pair cohort has helper-ownership failures
and supplies no acceptance or production-setting credit. Synchronous collection
and larger heaps remain diagnostics, with no new source setting. The relevant
options are documented in the upstream
[WebKit options list](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/runtime/OptionsList.h).
An additional private-helper-only collector diagnostic confirms one marker
while leaving the page runtime unchanged. Its pilot has another ownership
failure and supplies no credit; no collector setting is retained in source.

Retained experiments include demand-loaded ANGLE, deferred private-filter URL
and regex services, broader scale-only CSS projection, wider lossless PNG pixel
run scanning, direct publication of completed glyph tiles, and fewer unchanged
UI2 control updates. Seven ANGLE pairs measure 3,098,514,773 → 3,066,804,585
medians; one pair regresses. Seven UI2 visual-update pairs measure
3,026,455,283 → 3,021,467,114 medians; one pair regresses. The bezel-only change
saves just 1,275,147 between medians. These modest gains do not establish the
requested target. The initial AVFoundation cohort and pixel-isolation diagnostic
fail pixels because the glyph-copy capability collided with the synthetic-italic
flag; the capability now has a separate bit. Their failures remain recorded.
Later ownership failures also remain invalid rather than being retried away.

Plain-window hosting, a higher DFG compilation threshold, the first identical-layout
input cache, and lazy WebGL prototype initialization showed no useful gain and
remain rejected diagnostics. Two signed executables built from the same frozen
production input with ordinary versus larger compiler inlining thresholds pass
seven direct-launch pairs, 2,151,685,227 → 2,128,254,800 **main-process-only**
medians. Both carry the production JIT entitlement. Their counts omit helpers
and lack the exclusive coalition boundary, and cannot satisfy this target.
The first compiler pilot, which lacked the production JIT entitlement, and the
instrumented profiles remain separate evidence.

Seven matched `svg-coverage-matched` pairs use executable
`ada886d05a2041fdcd430ee4b27b90f6af74de2cda6def01f214c0d1ad68b948`
with a pinned private native bridge. Reusing exact validated polygon coverage
reduces medians 3,032,622,828 → 2,996,691,589; every pair improves, and all
fourteen captures pass the original gates. The cache keeps paint/backdrop live,
retains at most 32 masks per thread, and preserves transactional fallback. This
attributes the native change; it is not a final default-production result.

The minimal computation-context experiment adds 547,101 instructions between
seven matched medians and has been removed. A larger JSC heap also increases
instructions in its two-pair pilot and has no source change. The framework
preload and allocator pilots remain diagnostics with no production credit.

The revised identical-layout-input cache executes about 735 hits on the archived
page. Seven `geometry-matched` pairs use executable
`73c98de015d89a592565d1d83a89e15e7e94cb8d0c99af912b1fa211f4ecdcf9`,
receipt `20261103-073211-15eccc1c`. Medians fall from **2,947,025,315** to
**2,919,661,324**, a **27,363,991** difference, with every pair improving and
all fourteen captures passing the unchanged gates. The cache preserves document
ownership, typed-value context, font/raw-page generations, scale and copy-on-write
behavior. Default grid and repeat-style values now retain their scale-independent
projection. Focused mutation and ownership suites are authored but deferred.

The native GG experiment is removed. An existing optimized host already skips
GG renderer initialization on this browser path. Its seven-pair pilot has exact
captures but no eligible execution, so the 5.9M median difference supplies no
attribution. Both source and failed eligibility evidence remain under the raw
evidence root. The first grid compilation and a concurrent immutable-font
compilation failure remain recorded and were corrected in source.

A component diagnostic on the latest bundle observes roughly 279M instructions
in the filter helper and 239M in its owned macOS SetStoreUpdateService. These
per-process samples are diagnostic lower bounds; acceptance continues to include
both through the original exclusive-coalition counter. The completed helper-strip build retains those libraries. No test suite has been run during this
continuation.

Disk recovery compressed inactive generated C/preprocessed compiler inputs,
verified each decompressed SHA256, and retained their compressed hashes and
paths in `Build/hn-2700-20261103/compressed-compiler-inputs.jsonl`. Source,
measurements, logs and screenshots were preserved. Historical inputs can be
restored with `gzip -dc` before reproducing their compilation commands.
