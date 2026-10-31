# Stack Overflow rendering: Linux instruction optimization

## Status

The complete three-pair Linux benchmark clears the 15% target: **17.5134% fewer
Cachegrind instruction references by median counts**, and **16.9113% fewer**
under the stricter largest-candidate/smallest-control comparison. All six
captures passed the full document, resource, process, counter, and exact-pixel
checks. The benchmark and its memory guard exited successfully.

The optimized sources passed 179 distinct selected CSS test functions in each
of Boehm and no-GC modes. The production executable passed its native startup
check, the benchmark tooling tests passed, and the independent evidence audit
passed.

## Complete instruction results

| Pair | Execution order | Control Ir | Candidate Ir | Reduction |
| --- | --- | ---: | ---: | ---: |
| 1 | Control, candidate | 186,811,868,651 | 153,675,088,126 | 17.7380% |
| 2 | Candidate, control | 189,897,538,450 | 154,712,392,833 | 18.5285% |
| 3 | Control, candidate | 186,201,592,590 | 154,094,669,772 | 17.2431% |
| Median of each variant | — | 186,811,868,651 | 154,094,669,772 | 17.5134% |

The difference between the two median counts is **32,717,198,879 Ir** per
complete render. Every pair improved. The median of the three individual
paired percentages is 17.7380%; it is a different calculation from the ratio of
the two variant medians in the table.

The acceptance rule uses every sample: the largest candidate count is
154,712,392,833 and the smallest control count is 186,201,592,590. Their ratio is
0.83088651757, below the required 0.85. The exact integer test is
`154712392833 * 20 <= 186201592590 * 17`. The measured worst-case reduction across
this cohort is 16.9113%.

All six decoded viewport images have SHA-256
`d4934504491a1ca82aa1983e744cee0c26f0021e27a761b35eaae4315e036698`.
The complete raw cohort is in
`Build/stackoverflow-cachegrind-candidate-02-pairs`; its guard completed in
3,485.4 seconds with a sampled aggregate peak RSS of 2,264,420,352 bytes under
the 3 GiB limit. That elapsed time describes instrumented measurement overhead
and receives no native render-latency credit.

The [portable result ledger](benchmark-results/stackoverflow-linux-2026-10-31.json)
retains the counts, hashes, acceptance arithmetic, build/workload identity and
validation status. Raw evidence is preserved separately; no completed sample
was discarded from the final cohort.

## Workload and metric

The workload is the repository's frozen, author-script-free archive of
`https://stackoverflow.com/questions`, titled `Newest Questions - Stack Overflow`,
at a 1024 × 768 document viewport. The archive contains 15 ordered questions and
56 stored responses. Its archived, script-stripped HTML and original resource
bytes are replayed at their original origins through the sealed local replay
server, with no forwarding. The recorded document POST entry is replayed as GET
for browser navigation.

The measurement endpoint is executable launch through normal process exit after
the complete native capture. The explicit counter is Valgrind 3.22.0 Cachegrind
`Ir`, with cache and branch simulation disabled. It includes guest user-space
instructions in the main process and all its threads. Other processes, kernel,
hypervisor, GPU execution, and Valgrind's own observer code are excluded.

This is a software instruction-reference metric. Hardware-retired instructions
remain unverified: `perf_event_open` returned `ENOENT` on this host. The driver
never silently substitutes a software counter for hardware counters. Cachegrind
and Callgrind counts are kept separate, and profiled elapsed time receives no
native-latency credit. Cachegrind counts each iteration of x86 `REP` instructions
separately; see Valgrind's [accuracy notes](https://valgrind.org/docs/manual/cg-manual.html)
and the [Linux counter contract](LINUX_INSTRUCTIONS.md).

Each observation uses a fresh private browser profile and cache, a fresh Xvfb
display, software GL through llvmpipe, one GL worker, and one Boehm marker. The
snapshot cache is disabled. The same archived assets, native libraries, compiler
flags, viewport, readiness checks, and observer sources are pinned throughout.
No heavy build or test job overlaps the final cohort.

## Runtime changes

1. **Copy validated declaration spans once.** `parse_declaration_value` advances
   through the same validation and stopping conditions, then clones the accepted
   contiguous token span. This removes repeated array appends while preserving
   independent result storage and the stream's failure/EOF position.
2. **Copy substitution leaves in bulk.** Substitution step 2 detects spans with
   no nested functions or blocks and clones only their live elements. Nested
   processing reserves a bounded initial destination. Existing recursion, cycle
   guards, fallback behavior, taint, and expansion limits are preserved. Slicing
   before cloning matters because this V runtime's clone copies spare capacity.
3. **Clone accumulated invalidation maps.** A union clones the left set's
   existing table before merging the right set, avoiding repeated rehashing and
   insertion of every accumulated property. Flags, insertion order, duplicate
   precedence, and independent ownership are preserved.
4. **Read single-byte ASCII delimiters directly.** The common punctuation path
   avoids allocating a rune array. Empty, Unicode, malformed, and multi-character
   values retain the previous decoding path.

These fast paths apply to general CSS input.

## Shared Linux rendering prerequisite

The Linux GG staging adapter now gives the sampler pool at least the image
pool's capacity. The prior 64-sampler default exhausted the pool on this page
and could omit text or images despite a complete DOM audit. The change preserves
larger explicit capacities and is present in both control and candidate; it
receives no optimization credit.

The native candidate capture is pixel-identical to the corrected Linux control.
Both retain the pre-existing Linux SVG rendering defects visible in the header
wordmark and left promotional tile. The comparison establishes preservation of
the Linux control's rendering. Browser conformance remains outside this result.

## Build identities

| Input | Pinned value |
| --- | --- |
| Runtime control source | `53906747f004c12f57b4888cc1f215bac5aa5634` plus the shared Linux adapter |
| Runtime optimization revision | `b42a833a9631fb4cf214c83b2922190be28a33f4` |
| V compiler | `92cf0f51a5b5f1c6004084aad5bc6b17151f18e6` |
| Native compiler | Clang 18.1.3, `-O2 -gline-tables-only` |
| Control binary SHA-256 | `d2be3ee812560ea03132059d3975776d409e2523c65433ddc239331b3134f0fc` |
| Candidate binary SHA-256 | `0e9b05767b4312cac23ab21ca39ffc53828d6d2f6212d39f3fd56d7fa33020fd` |
| Fixture manifest SHA-256 | `86a9d1fc61aeebf0c382e15105a0aaec5926ddef0a4841ca6c8be077622d55e6` |
| Fixture HTML SHA-256 | `592d214f1f87bc26c3aa98ca70bb609dd03e0dad76b5558828e967d7ada7a8e1` |
| Decoded RGBA SHA-256 | `d4934504491a1ca82aa1983e744cee0c26f0021e27a761b35eaae4315e036698` |

The native flag files are byte-identical. All seven native archives and helper
inputs match. The runtime source hashes match both successful focused test
builds. V-to-C emission and native compilation ran as separate memory-guarded
phases, avoiding simultaneous compiler heaps on the host's 8 GiB cgroup.
The host is Ubuntu 24.04.3 LTS, Linux 6.18.57, x86-64; both production binaries
use dynamic Boehm GC. Full receipts are
`Build/linux/build-comparison-provenance.json` and
`Build/linux/host-toolchain-summary.json`.

## Validation and evidence

- The 17 focused CSS test functions passed once in each of Boehm and `-gc none`.
  The generated native harnesses were checked for exactly those calls and for
  propagation of failures. Evidence:
  `Build/linux/focused-css-test-results-candidate-02.json`.
- The broader selection passed 162 additional functions across 36 test files
  in each GC mode: 121 parser/substitution/token functions and 41 invalidation
  functions. Its disjoint union with the retained focused tests is **179 distinct
  functions per GC mode**. Generation, native compilation, and execution all
  exited zero for the four accepted broad group/mode runs. Successful groups
  were retained without reruns. These counts describe distinct test functions
  invoked; existing prealloc-only checks remain conditional and were not
  exercised in these configurations. Evidence:
  `Build/linux/broader-css-regression-results.json`.
- The full benchmark/tooling suite passed 76 tests, with two macOS-only skips.
  Real success and signal-failure probes validated the installed counters; a
  killed process with a positive Cachegrind footer was correctly rejected.
  Evidence: `Build/linux-cachegrind-full-tests.json` and
  `Build/linux-cachegrind-backend-probes/result.json`.
- Both production executables passed native startup checks. Candidate page
  pixels, ordered question IDs, full body text, and audited CSS FontFace
  declarations/statuses match the control. The font comparison does not identify
  resolved native font files. Evidence:
  `Build/stackoverflow-candidate-02-smoke/reference-comparison.json`.
- An independent read-only audit streamed all six raw profiles. Their flat-row
  sums match the raw footers, Valgrind logs, capture JSON and cohort summary.
  It also verified execution order, binary/source/toolchain/library identities,
  all 56 fixture bodies, exact image hashes, and the integer acceptance rule.
  Evidence: `Build/linux/final-instruction-evidence-audit.json`.

### Test compatibility repairs

Two assertions in the broader invalidation selection also failed with the
original, unoptimized runtime in both GC modes, with identical native flags.
Those controls established that the failures predated this optimization.
The independent legacy traversal oracle now explicitly snapshots its map header
before a callback can replace the containing record. All expected strings,
replacement checks, production comparisons, and post-GC checks remain unchanged.
The duplicate-registration test now requires exactly one descendant and one
sibling rule, matching the original runtime's existing coalescing behavior.
All other key, order, callback-oracle, flag, and source-plan assertions remain.

The lifetime-test C header now recognizes both `_VGCBOEHM` and the current
compiler's `CUSTOM_DEFINE_gcboehm`. Its helper bodies and ownership assertions
are unchanged. The final repaired Boehm run passed without the temporary legacy
macro alias used to compare the original failed expectations. These three
test-only repairs do not change either measured production executable.

The original setup failures are also retained: a missing cross-test helper was
resolved by including two exact original dependency files, and the original
Boehm native compilation failed before the macro compatibility repair. Failed
attempts, original-runtime controls, their exact manifests/drivers/inputs,
and the reviewed compatibility diff remain in the evidence history. See
`Build/linux/invalidation-original-control-comparison.json`,
`Build/linux/broader-css-regression-results.json`, and the portable result ledger.

### Excluded diagnostic profile

An earlier complete Callgrind run was rejected: its header summary was
182,783,960,332 Ir and its footer was 182,783,967,765 Ir. The discrepancy is
retained, and the run receives no instruction-comparison credit. Its self-cost
rows sum to the footer and support diagnostic attribution only. In that profile,
the substitution leaf append call site and its callees accounted for about
25.05% of recorded work. This corroborated the earlier optimization choice; it
is not a measured before/after reduction.
See `Build/linux/o2-control-css-attribution-summary.json`.

## Reproduce the final comparison

With matching control and candidate Linux executables available:

```sh
python3 tools/run_memory_bounded.py \
  --limit-gib 3 --timeout 10860 \
  --lock Build/stackoverflow-cachegrind-repeat.lock \
  --report Build/stackoverflow-cachegrind-repeat-guard.json -- \
  python3 tools/stackoverflow_browser_instructions.py \
    --binary Build/linux/vox-control \
    --candidate Build/linux/vox-candidate-02 \
    --counter-backend cachegrind \
    --pairs 3 --required-reduction 0.15 \
    --output Build/stackoverflow-cachegrind-repeat \
    --timeout 1800
```

Use a fresh output directory for every cohort. The order is control/candidate,
candidate/control, control/candidate. Every capture must pass content, replay,
image, readiness, font, renderer-error, source-hash, and exact-pixel checks. The
acceptance rule is `max(candidate) <= 0.85 * min(control)`, with all samples and
failures retained.
