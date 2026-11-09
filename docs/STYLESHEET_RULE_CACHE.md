# Reusing stylesheet rule syntax

On a frozen signed-out `https://github.com/` page, the bounded rule-syntax cache
reduced repeat HTML/CSS parsing time by **17.98%** and parsing plus initial style
computation by **8.99%**. These are component measurements with an optimized
Boehm build; the full-browser limitations are recorded below.

## Why retain the complete rule set

A rule that does not match the first render can match after a class change,
script-created content, hover, viewport resizing, or a container-query change.
Scripts can also inspect and edit that rule through CSSOM. Deleting those rules
from a cached response would change the page's behavior and the dependency
information used by style invalidation.

Vox already defers property-value conversion for owner-node stylesheets of at
least 16 KiB. The rule-syntax cache extends that optimization: a repeated load
reuses the immutable raw rule tree, skipping tokenization and declaration-syntax
parsing for both used and unused rules. Conversion still creates a fresh
stylesheet and selectors with the current document, URL, namespaces, parsing
mode, UA policy, and eager/deferred declaration policy. Previously unused
declarations remain lazy until matching or CSSOM access needs them.

## Cache identity, bounds, and ownership

- The key is the complete decoded CSS source, compared byte for byte. A changed
  response body at the same URL misses and builds a new template when eligible.
  A revalidated unchanged body can reuse its existing template. HTTP freshness,
  revalidation, `Vary`, and response-body storage continue through the existing
  network cache.
- Only top-level parsing with an empty initial rule context is eligible.
  Sources smaller than 16 KiB bypass the cache.
- The LRU holds at most 24 entries, 4 MiB of source, and 262,144 syntax nodes.
  An over-budget candidate is parsed once and not admitted.
- Cached trees contain no document or CSSOM owners. Cache hits export retained
  values before releasing their lease. Editing one stylesheet cannot change
  another stylesheet or its cached template.
- In prealloc builds, each entry owns a separate retained arena. Eviction drops
  the cache lease; an active conversion keeps its own lease until it finishes.
  The payload is reclaimable even when conversion cooperatively reenters and
  clears the cache. Prealloc worker parses bypass this origin-thread-owned
  cache. GC builds support concurrent lookup and publication.
- The cache is in process, not serialized to disk. Existing unused-syntax
  cleanup clears it; in particular, static script-disabled GC pages may clear
  it during idle memory maintenance. It does not promise warm hits across
  process launches or explicit memory cleanup.

`VOX_DISABLE_STYLESHEET_RULE_CACHE=1` selects the previous parsing path in the
same binary. `VOX_STYLESHEET_RULE_CACHE_DIAGNOSTICS=1` reports the first hit and
the cache's current source/node accounting; diagnostics belong outside timed
measurements.

## GitHub measurement: 2026-11-09

The capture contains 20 unique linked CSS responses totaling 2,557,030 bytes.
It preserves all 28 linked stylesheet occurrences, including duplicate bodies,
and one original inline stylesheet. Parsing produces 29 sheets and 42,219 rules
for 2,107 elements, of which 2,103 receive computed styles. The viewport is
1280 by 800 pixels. The transformed HTML fixture is 7,068,513 bytes.

The harness calls the production owner-node HTML/CSS parser and then
`document.update_style()`. Seven paired comparisons alternate which mode runs
first. Each mode uses a fresh process and the same executable, with
`VOX_DISABLE_STYLESHEET_RULE_CACHE=1` selecting the control. Each process makes
one first parse followed by two warm parses: 14 processes and 42 samples in
total. All process and memory-guard exits were zero. No concurrent build ran
during this cohort.

### Elapsed time

The warm rows pool 14 samples per mode. First-document rows pool seven samples
per mode. Combined times are medians of each sample's parse-plus-style total,
not sums of the separate column medians.

| Measurement | Disabled (ms) | Enabled (ms) | Time reduction |
|---|---:|---:|---:|
| Warm HTML/CSS parse | 864.998 | 709.510 | **17.98%** |
| Warm style computation | 1043.283 | 992.685 | 4.85% |
| Warm parse + style | 1895.987 | 1725.590 | **8.99%** |
| First-document HTML/CSS parse | 1081.112 | 987.818 | 8.63% |
| First-document parse + style | 2067.834 | 1851.779 | 10.45% |

Every pair improved in warm parsing and in the combined interval. The table
below uses the median of the two warm samples within each process.

| Pair | Disabled parse (ms) | Enabled parse (ms) | Parse reduction | Disabled total (ms) | Enabled total (ms) |
|---|---:|---:|---:|---:|---:|
| 1 | 935.291 | 756.568 | 19.11% | 2069.441 | 1803.628 |
| 2 | 800.662 | 708.894 | 11.46% | 1784.811 | 1670.999 |
| 3 | 878.038 | 714.016 | 18.68% | 1851.923 | 1679.282 |
| 4 | 913.935 | 730.170 | 20.11% | 1872.206 | 1778.530 |
| 5 | 845.496 | 709.510 | 16.08% | 1847.834 | 1664.453 |
| 6 | 834.025 | 727.325 | 12.79% | 1749.392 | 1733.101 |
| 7 | 891.105 | 716.260 | 19.62% | 2013.329 | 1762.628 |

Paired combined reductions range from 0.93% to 12.84%. Style time alone is
noisier: two of seven warm pairs regress, although both combined intervals
still improve. Three of seven first-parse pairs regress, by approximately
11.00%, 17.16%, and 0.27%, despite the lower pooled median. The first document
can reuse duplicate CSS bodies within that page; it is a fresh-process result,
not an exclusively miss-only workload. The results do not establish a
first-load benefit for every page.

### Memory and validation

Median sampled peak process-tree RSS is 2,352,205,824 bytes with the cache
disabled and 1,836,605,440 bytes enabled (2243.24 versus 1751.52 MiB, 21.92%
lower). Every observed process-tree RSS peak stayed below 3 GiB. These peaks include the final
exhaustive validation outside the timed intervals. They do not isolate cache
payload cost or measure production browser memory.

All accepted processes agree on full CSSOM serialization and every one of the
364 supported computed longhands. Validation happens only after the final
timed sample, so it cannot materialize unused declarations before another
timing. Four separate enabled/disabled, first/warm audits also produce exactly
the same 3,755-line native engine layout tree. Layout validation is untimed.

| Validation output | SHA-256 |
|---|---|
| Full CSSOM | `ee50ca4e965b5119c4eb19e8bcdbbb7ceb0a629a085c449f2611fd8fac9c6f3b` |
| All computed longhands | `2917786d92311e72db7cf74810a2fec8161ba2a532e9f4ec137d9cde171fa8b7` |
| Engine layout tree | `e59816bd01d67096b52a30e19c73317c9b06df24340de604fb56e5f64ae59125` |

An untimed diagnostic pilot confirms the raw-rule cache is used. Its first hit
reports seven entries, 2,155,231 source bytes, and 258,891 syntax nodes, close to
the existing 262,144-node budget. Capacity was not tuned after the cohort.

### Build, host, and scope

The benchmark uses V `0b0d92a699c7fea081749f09f5612b68673447d7`, the C backend,
Clang 19.1.7, a single C translation unit with `-O2`, and dynamic Boehm GC.
`GC_MARKERS=1` is fixed for both modes. This is not a production FastC/prealloc
performance measurement. The host exposes nine CPUs on an AMD EPYC 9V74
system, with Linux 6.18.57 and glibc 2.41. The cohort ran from 07:20:47 to
07:22:41 UTC on 2026-11-09; observed one-minute load averages were 0.656–1.029.

The timers include HTML/CSS parsing and initial style computation, including
automatic GC triggered within those operations. Network, JavaScript hydration,
layout, paint, browser startup, file I/O, finalization, validation, and explicit
pre-sample collection are outside the intervals. The page is a frozen public
signed-out homepage, not a live navigation or an authenticated GitHub session.

A full Linux browser build reached 14 generated-C errors in unchanged
application code. The measured base commit's
[Linux CI run](https://github.com/vox-browser/vox/actions/runs/42565980301)
also fails its whole-browser builds; its Boehm job records 14 errors using the
CI-pinned V revision `339affce1891514d11aeb7111f579845d966a138`.
The component benchmark compiled and ran successfully, and the focused
prealloc tests passed separately. Full browser startup, JavaScript hydration,
and pixel rendering remain unverified. Native layout-tree equality does not
establish pixel equivalence.

### Evidence identities

The benchmark's source base is `9b3df2b374181102c9f621a11672d0ca5353cdca`. The retained evidence
bundle contains the frozen HTML/CSS, every accepted raw sample and guard
receipt, separate layout audits, focused-test logs, build and dependency
identities, and unsuccessful setup/build attempts. It excludes binaries,
generated C, compilers, and dependency trees. No failed attempt contributes to
the accepted cohort. Raw data and archives stay outside Git; this report and
the reproducible drivers are committed.

| Evidence | SHA-256 |
|---|---|
| `css-cache-evidence.tar.gz` (2,878,034 bytes) | `cbe69345ad14940a76022b3ef778b688eb1415bf8deebc3b2d793904f2cc6828` |
| Accepted `summary.json` | `fdf40d4470a119dc1d237a7f54fae219fc5cfe45144e095e72c29c5b1195b511` |
| Original GitHub HTML | `65f8cdd1dd8fe0db52946f58650e312d4f8c4f524446f2ae201c6d3dc55a10df` |
| Transformed inline HTML | `35f6e0e718490d9404ce17ae4f753c8472a7048b5ba2763aebe1ec9bd623c934` |
| Measured executable | `98d8b1ee7db3e5c2796458e3475670da37777615d16d24994db9704c41e9229e` |
| Measured V harness source | `ade856a3dae5e9de59a807ea473ede3e306744c38e0e469c60eba07650cbbf97` |

The build receipt records the exact argv, compiler, runtime libraries, native
inputs, source identities, and fonts. Inputs remained stable throughout the
cohort and immediate verification. After measurement, the V harness header
was clarified to distinguish explicit pre-sample collection from automatic GC
inside a timed operation. This changes only a comment; the measured source
hash above is preserved, and no executable behavior or timing was changed.

## Correctness coverage

The focused regression suite covers exact-source identity, equal-length server
changes at the same URL, bounded LRU eviction, an outstanding lease during cache
clear, independent document and base-URL ownership, CSSOM mutation isolation,
namespace and initial-rule-context changes, initially unmatched rules becoming
active after a class change, and media queries after viewport changes. It also
compares nested rules, descriptor rules, custom properties, comments separating
tokens, and eager/deferred serialization after cache retirement.

A cache-arena lifetime check includes `@position-try`: its retained name must
be copied before conversion, just like other retained at-rule preludes.
Concurrent duplicate publication is exercised in the GC configuration; arena
retirement is exercised with `VOX_ARENA_POISON=1` in the prealloc configuration.

The nine new test functions and 18 surrounding test functions passed with
Boehm and the staged prealloc runtime (arena poisoning enabled). The concurrent
worker case is intentionally inapplicable to prealloc's origin-thread cache.
The surrounding suites are `stylesheet_conversion_workspace_test.v`,
`deferred_declarations_test.v`, and `chromium_selector_alias_test.v`.

With the native dependencies prepared as described in [Linux setup](LINUX.md):

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/css-cache-check.lock --report Build/css-cache-check.json -- \
  python3 tools/test_linux_native.py --gc boehm \
  css/stylesheet_rule_cache_test.v css/stylesheet_conversion_workspace_test.v \
  css/deferred_declarations_test.v css/chromium_selector_alias_test.v
VOX_ARENA_POISON=1 python3 tools/run_memory_bounded.py \
  --lock Build/css-cache-prealloc-check.lock --report Build/css-cache-prealloc-check.json -- \
  python3 tools/test_linux_native.py --gc prealloc \
  css/stylesheet_rule_cache_test.v css/stylesheet_conversion_workspace_test.v \
  css/deferred_declarations_test.v css/chromium_selector_alias_test.v
```

## Reproducing the GitHub component measurement

`tools/benchmark_stylesheet_rule_cache.py capture` freezes the HTML and every
linked CSS response, retains response validators, and writes source hashes.
It preserves stylesheet order, duplicate link instances, media attributes, and
the response URL used to resolve relative resources. The resulting fixture is
an HTML/CSS workload; it does not execute GitHub's JavaScript.

Build `tools/benchmark_stylesheet_rule_cache.v` with the compiler modules
and native dependencies used by the browser. For the measured Linux C-backend
configuration, with `V_BIN` pointing to the selected compiler:

```sh
export V_MACOS_V3_NO_FALLBACK=1 V_C_ERROR_BUG_REPORT_DISABLED=1
CSS_HTTP_MODULES="$(python3 tools/prepare_http_compat.py "$V_BIN")"
CSS_LINUX_MODULES="$(python3 tools/prepare_linux_modules.py "$V_BIN")"
python3 tools/run_memory_bounded.py \
  --lock Build/css-benchmark-compile.lock \
  --report Build/css-benchmark-compile.json --timeout 900 -- \
  "$V_BIN" -b c -memory-limit 10G -enable-globals -cc clang -gc boehm \
  -d dynamic_boehm -d use_openssl -exclude @vlib/time/zoneinfo.native.v \
  -path "$PWD|$CSS_LINUX_MODULES|$CSS_HTTP_MODULES|@vmodules|@vlib" \
  -cflags '-O2 -D_GNU_SOURCE=1' \
  -o ./stylesheet-rule-cache-benchmark tools/benchmark_stylesheet_rule_cache.v
```

Record the build command, compiler revision/version, compiler and executable
hashes, C mode, allocator, native dependencies, source hashes, and fonts in a
JSON build receipt. The runner preserves it verbatim in the result; the
evidence bundle's `build-info.json` is the receipt for this cohort. Pass
`--runtime-library /absolute/path/to/library` repeatedly to pin dynamic runtime
libraries as well; the accepted cohort pins 44 of them. Keep the chosen source,
binary, dependency, and fixture identities fixed while comparing modes.

The runner alternates enabled/disabled
processes using that one binary, retains failed attempts, verifies input and
binary/library hashes, and runs each process under the memory guard. Each
process measures one fresh-process first parse and a fixed number of warm parses.
Repeated stylesheet bodies within the first page can already produce cache hits.
Validation is outside the timed intervals and must not materialize unused declarations
between timed parses.

```sh
python3 tools/benchmark_stylesheet_rule_cache.py capture \
  --url https://github.com/ --fixture /path/to/empty/github-fixture
python3 tools/benchmark_stylesheet_rule_cache.py measure \
  --fixture /path/to/github-fixture --binary /path/to/optimized-benchmark \
  --build-info /path/to/compiler-and-source-receipt.json \
  --output /path/to/empty/results --pairs 7 --warm-repeats 2
```

These component timings exclude network, JavaScript hydration, layout, paint,
browser startup, validation, finalization, and explicit pre-sample GC. Automatic
collection during parsing and styling remains included. They establish
HTML/CSS parser and style-computation behavior for the frozen page, not a live
end-to-end page-load speedup. Full browser observations are recorded separately.
