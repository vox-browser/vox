# XML parser migration: first native performance cohort

Recorded 2026-11-09. **Result: failed the original-parser performance gate.**

The first complete native comparison contains 210 successful benchmark processes and 210 successful runtime guards. Every workload produced identical source bytes and complete DOM fingerprints across all three variants. Nevertheless, the candidate exceeded both the 1.05 median CPU ratio and the 1.05 retained-used-byte ratio against the original parser on **nine of ten workloads**. These results are accepted evidence of a regression; no failed comparison, slower pair, or outlier was removed. The only workload passing both original-parser gates was `large-text`. All ten comparisons against the initially merged vlib adapter passed the same gates.

## Evidence and exact identities

- [Actions run 42581185187, attempt 1](https://github.com/vox-browser/vox/actions/runs/42581185187), [prealloc job 129040158019](https://github.com/vox-browser/vox/actions/runs/42581185187/job/129040158019), [PR #30](https://github.com/vox-browser/vox/pull/30).
- [Raw `xml-performance-receipts` artifact ZIP, ID 13658480839](https://api.github.com/repos/vox-browser/vox/actions/artifacts/13658480839/zip). GitHub records expiry on 2026-11-16. Its SHA-256 is `f8bfa9630918ae0ab0498e0a87731dec5b0d3f084458474d31bb904df0d2b0ef`, matching the downloaded archive.
- The archive contains all per-attempt results, logs, kernel process statistics, memory guards, build receipts, and `comparison.json`. The original archived comparison JSON SHA-256 is `929ea237005e7c9da4d07e341fcb0620615e1fdd25a43abd1cd27282e6999082`. The locally reformatted JSON has SHA-256 `06da27f1a24ac7f6c11af8620a7812efe59e4d5de0cc68dd7b179da9a094ddf1`; parsed JSON values are identical. All 210 individual result files also equal their corresponding aggregate records.
- The driver started at `2026-11-09T07:52:17Z`. Checked-out synthetic PR merge SHA: `199dafad9ad02c14485316da21be1d073c78f4e5`; PR head: `fd367727f7855906858d47682ab48d132e9eaf90`. The working tree was clean before the comparison and parser sources were restored afterward.

| Variant | Parser inputs | Executable SHA-256 |
|---|---|---|
| Original | `html/dom_parser.v` from `9b3df2b374181102c9f621a11672d0ca5353cdca`; current `html/xml_parser.v` excluded | `b3da1085338fde75f24572a861f59d3b10cf127f14a879549ded0deadac70982` |
| Merged | `html/xml_parser.v` and `xmlcompat/parser.v` from `8e49769627b7c0713da221a2e83ffdf1e2c04c90` | `5c22810871f3e528255419a352e37f86153e2e8a933111eeed029a974c54367e` |
| Candidate | Parser files from the checked-out PR merge above | `f5b5d1b195ea8c197ae30b91ed26d7ce059d3d98fc701c0115c0fdba662e2024` |

Only parser files were exchanged. The three executables share the current DOM engine; they are not complete historical browser builds. Exact parser-file hashes, 7,204 other source-file hashes, six native-archive hashes, and preparation-script hashes are preserved in `comparison.json`. The unchanged harness SHA-256 is `1e86a4aaa3c32740be8a889ad22ef1bd59cae859a81905ab077b58aa65595d81`.

## Scope and method

The measured interval is `html.parse_xml_document_source`, including compatibility preparation, XML parsing, namespace handling, and actual DOM construction. Source generation/file reads, document creation, tree verification, scope exit, and destruction are outside that interval and separately recorded. Each measured parse enters a document-owned native arena. Arena usage is sampled immediately after parsing, before verification allocations; cleanup destroys/finalizes the document and releases its storage before the next parse. Inputs are allocated outside the document arena.

The allocator is the staged production prealloc runtime with `-prealloc -gc none`, `VOX_ARENA_POISON=0`, and `VOX_ARENA_NO_REUSE` unset. Each workload uses seven fresh-process cohorts, alternating `original, candidate, merged` and `merged, candidate, original`. Each process performs three warmups. There are 148,743 measured parses plus 630 warmup parses. A candidate sample is paired with both controls in the same cohort; those comparisons are correlated, not two independent candidate cohorts.

CPU values below are the median of seven process-level means (`parse_cpu_ns / iterations`), in microseconds per parse. Ratios are the median of the seven matched candidate/control ratios, so they need not equal the quotient of separately displayed medians. “Worst” is the largest observed paired ratio. CPU uses `CLOCK_PROCESS_CPUTIME_ID`; its interval also includes two wall-clock reads. Wall time uses the monotonic clock. No profiling or hardware-instruction measurement was active.

## CPU results

Ratios below 1 favor the candidate. The original-parser acceptance ceiling was 1.05.

| Workload | Original µs/parse | Merged µs/parse | Candidate µs/parse | Candidate/original, median / worst | Candidate/merged, median |
|---|---:|---:|---:|---:|---:|
| `small-svg` | 7.577 | 14.181 | 13.391 | 1.790 / 1.814 | 0.944 |
| `many-elements` | 14,328.636 | 19,364.877 | 18,937.231 | 1.320 / 1.340 | 0.973 |
| `attributes` | 3,002.477 | 5,868.180 | 5,521.519 | 1.832 / 1.866 | 0.941 |
| `mixed` | 3,658.565 | 8,061.388 | 6,821.613 | 1.877 / 1.889 | 0.844 |
| `indented` | 3,031.187 | 7,224.822 | 5,068.824 | 1.682 / 1.767 | 0.708 |
| `entities` | 2,685.999 | 7,809.055 | 5,443.216 | 2.111 / 2.185 | 0.705 |
| `large-text` | 622.872 | 60,105.660 | 462.219 | 0.746 / 0.908 | 0.008 |
| `menu-svg` | 6.230 | 12.746 | 11.304 | 1.833 / 1.908 | 0.891 |
| `star-svg` | 23.819 | 77.634 | 41.021 | 1.732 / 1.755 | 0.531 |
| `strokes-svg` | 1,497.479 | 4,543.481 | 2,562.725 | 1.704 / 1.748 | 0.565 |

Against the original parser, the candidate won **0/7 CPU pairs on each of the nine regressing workloads** and **7/7 on `large-text`**. Against the merged adapter, it won **7/7 on every workload** (70/70 paired comparisons). This improves the merged implementation without recovering the original parser's performance on element/attribute-heavy documents and real SVGs. Original-control median wall ratios agree with the direction of every CPU result; wall time had no acceptance threshold in this cohort.

For scale, the menu SVG increases from approximately 6.230 to 11.304 µs per parse. The 101 KB strokes SVG increases from approximately 1.497 to 2.563 ms. The many-elements workload increases from approximately 14.329 to 18.937 ms. The large-text candidate instead falls from 622.872 to 462.219 µs and substantially removes the merged adapter's 60.106 ms cost.

## Retained arena usage

These are exact used bytes in the document arena immediately after parse. All iterations and all seven processes report the same used-byte count for each workload/variant. The metric includes parser temporaries retained in that arena; it is not a count of only live DOM objects, process RSS, cumulative malloc traffic, or total page memory. The original-parser acceptance ceiling was again 1.05.

| Workload | Original bytes | Merged bytes | Candidate bytes | Candidate/original | Candidate/merged |
|---|---:|---:|---:|---:|---:|
| `small-svg` | 8,952 | 24,100 | 21,668 | 2.420 | 0.899 |
| `many-elements` | 26,078,251 | 35,476,706 | 34,264,843 | 1.314 | 0.966 |
| `attributes` | 4,730,130 | 8,949,264 | 7,695,601 | 1.627 | 0.860 |
| `mixed` | 3,805,047 | 14,107,897 | 14,099,477 | 3.705 | 0.999 |
| `indented` | 3,645,059 | 12,476,872 | 10,705,367 | 2.937 | 0.858 |
| `entities` | 3,956,455 | 12,765,408 | 9,767,654 | 2.469 | 0.765 |
| `large-text` | 1,101,694 | 68,005,689 | 1,113,101 | 1.010 | 0.016 |
| `menu-svg` | 7,778 | 21,854 | 18,254 | 2.347 | 0.835 |
| `star-svg` | 32,211 | 118,991 | 68,559 | 2.128 | 0.576 |
| `strokes-svg` | 1,397,537 | 6,761,576 | 3,455,651 | 2.473 | 0.511 |

The candidate retains more used bytes than the original in every workload. `large-text` remains within the allowed 5% increase; the other nine fail. Candidate used bytes are lower than the merged adapter in all seven pairs of every workload. Reserved arena capacity is a separate metric: for `mixed`, candidate capacity rises from 14,417,920 to 15,990,816 bytes despite a small reduction in used bytes. Median process peak RSS for that workload rises from 98,279,424 to 99,332,096 bytes. Capacity and kernel `wait4` peak-RSS records are retained in the raw evidence and were not gates.

## Workloads and identity

Node counts include the document node. Tree fingerprints cover ordered structure, node types/names, text/CDATA/comments/PIs, namespace and prefix identity, and attributes sorted by name. Every row's fingerprint is identical across all 21 sample processes. Builtin shape assertions also passed.

| Workload | Source bytes | DOM nodes | Parses/process | DOM checksum |
|---|---:|---:|---:|---|
| `small-svg` | 160 | 4 | 2,000 | `7c7ad3acaab2e74b` |
| `many-elements` | 88,893 | 3,002 | 10 | `94f568df8203c9ce` |
| `attributes` | 91,035 | 102 | 20 | `b9fa7eb00facfa22` |
| `mixed` | 85,925 | 7,003 | 10 | `6a9490c8a7912567` |
| `indented` | 41,926 | 5,003 | 10 | `e4d2e4c387818466` |
| `entities` | 122,035 | 2,002 | 10 | `cda0646162aab108` |
| `large-text` | 1,097,763 | 3 | 3 | `a0ce458758b10490` |
| `menu-svg` | 174 | 3 | 4,000 | `7e50f756b82705c5` |
| `star-svg` | 2,180 | 15 | 1,000 | `2cd643e9ac4f84a5` |
| `strokes-svg` | 101,049 | 603 | 20 | `a919ebc951b9b0ba` |

Builtin sizes were: `small-svg=1`, `many-elements=1000`, `attributes=100` (64 ordinary attributes per item plus ID and namespaced attribute), `mixed=1000`, `indented=1000` nested group/item rows with short whitespace text nodes, `entities=1000`, and `large-text=16384` repetitions. No doctype workload is included; the migration's intentional doctype changes are outside these equal-output comparisons.

The three repository fixtures were pinned as follows:

| Workload | Repository path | Source SHA-256 |
|---|---|---|
| `menu-svg` | `Tests/Browser/Brave/resources/techcrunch-menu.svg` | `16b113879817e29616479bbe87f578c960743d0f5f717f540064d11d4fa60d71` |
| `star-svg` | `Tests/Browser/Brave/resources/discord-star.svg` | `c9eabeeb9bbecb981720b66cdf76bff12b3cf8249eab24c0676cb09425ec6d67` |
| `strokes-svg` | `Tests/Browser/Brave/input/isolated-svg-strokes.svg` | `e8214df1fd9efc199d9e7bf00972be201d46be4acbb65c054ec5dbd7a9644c6f` |

All ten source SHA-256 values are present in the raw results; the three file inputs also match the driver's independent fixture hashes.

## Build-input audit and limits

The V source revision is `339affce1891514d11aeb7111f579845d966a138` (`V 0.5.2 339affc`). Original and staged compiler binaries share SHA-256 `bca7a24df5d04bf56524ae7c6ece087d570b494f60135864690be7411e9393cd`. The staged prealloc runtime identity is `f760e5628e10eacfef9515cabed4deb2c242c0235b626d7aa177b9f8fbb27d94`. Clang is Ubuntu 18.1.3, target `x86_64-pc-linux-gnu`. The Ubuntu runner had four logical CPUs; initial/final load averages were `[1.801, 1.830, 0.962]` and `[1.089, 1.339, 1.191]`.

All three recorded compiler argument lists are identical after replacing only the output-executable argument. They specify C backend, `-prod`, explicit C `-O2`, the same strict native diagnostics, `-memory-limit 10G`, `-enable-globals`, `-gc none`, `-prealloc`, `use_openssl`, module paths, and the zoneinfo exclusion. Builds exited zero, with the same five warnings and 116 notices each. Their guarded durations were 184.770 s (original), 183.581 s (merged), and 184.137 s (candidate); peak aggregate build RSS stayed below 5 GiB. The complete driver took 728.235 s and correctly exited 1 for its nine original-parser gate failures. All 210 sample guards completed normally, totaling 54.113 s; no sample failed or was discarded.

No differing declared build setting or non-parser input was found. There is an evidence limitation: this first cohort predates `-showcc`, so the final expanded Clang command and generated C unit sizes are absent. The pinned V driver selects additional production/LTO/inlining settings partly from generated-unit size, including an 8 MiB large-unit threshold. Explicit user C flags are applied through the dependency flag plan, but this archive alone cannot prove the final automatic inlining settings matched. Future receipts should retain the expanded commands; this missing detail does not justify discarding the observed failures.

This is a fixed seven-pair component cohort on one shared CI runner, with no confidence interval or independently repeated host cohort. It does not measure browser navigation, image rendering, first frame, JavaScript, scrolling, or hardware instructions; it does not establish Boehm behavior. RSS includes process/runtime and batch-lifetime overhead and should not be interpreted as a single document's footprint. These native results are separate from earlier pure-`xmlcompat` microbenchmarks and from correctness-only XML test runs. Later parser/storage candidates require their own complete cohort; they must not overwrite or relabel this failed result.
