# Recent PR page-load check — 2026-11-09

These runs do **not establish a clear end-to-end load improvement** after the
recent merges. ChatGPT is effectively unchanged. GitHub has a slightly lower
median, but its pixel-reference stability check fails, and the timing ranges
overlap substantially. Neither site earns an optimization acceptance claim.

| Homepage | Before median | After median | Median time reduction | After wins | Validation |
| --- | ---: | ---: | ---: | ---: | --- |
| chatgpt.com | 8.546 s | 8.515 s | 0.36% | 4/7 | 14/14 exact pixels and content; complete replay |
| github.com | 9.508 s | 9.211 s | 3.12% | 4/7 | Content and replay pass; only 11/14 captures match the fixed pixel reference |

Times include the identical **five-second settle**. The measured endpoint is
fresh browser process launch through document PNG encoding, content audit and
normal process exit. These are unprofiled wall times, not hardware instructions,
physical display presentation, network-transfer time, or isolated renderer time.

Each site has seven complete alternating before/after pairs. Every attempt is
retained. No outlier or regression was removed. ChatGPT's observed before range
is 8.042–8.884 s and after range is 7.682–9.211 s. GitHub's ranges are
8.465–10.243 s and 7.797–10.845 s. Highest-after/lowest-before ratios are
1.145 and 1.281 respectively. These overlapping ranges and four wins out of
seven provide no convincing separation.

| Pair | ChatGPT before (s) | ChatGPT after (s) | GitHub before (s) | GitHub after (s) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 8.884 | 9.154 | 8.465 | 8.643 |
| 2 | 8.648 | 9.211 | 9.024 | 7.797 |
| 3 | 8.706 | 8.515 | 9.399 | 10.845 |
| 4 | 8.453 | 8.573 | 9.626 | 9.281 |
| 5 | 8.440 | 8.387 | 9.749 | 10.490 |
| 6 | 8.546 | 8.212 | 10.243 | 9.211 |
| 7 | 8.042 | 7.682 | 9.508 | 8.924 |

Both engines here are Vox with JavaScriptCore and author scripts enabled. Every
trial uses a fresh process, empty private profile and application cache, a
1024×768 CSS viewport, scale two, an unfocused test window, and the same settle
policy. OS filesystem and shader caches are retained. The sites run sequentially.
No profiling, counter collection, animation suppression, tolerance change or
pixel-reference replacement occurs in accepted timing comparisons. The 18-CPU
host's one-minute loads range from 13.31–17.78 during ChatGPT and 10.44–15.26
during GitHub. Shared-host variation remains a limitation. Both cohort guards
and every browser exit are zero; peak aggregate RSS is 1.55 GiB and 2.73 GiB
under the 12 GiB guard.

ChatGPT uses the retained November 4 public signed-out page, extended with
missing favicon responses. All 311 original response bodies **and request
methods** are preserved. The final sealed archive has 320 responses;
its manifest SHA-256 is `e7ecb1d9d766cef0e6291606e686e89f6030ea69920778056d764541b34e7a0a`.
GitHub uses a fresh November 9 homepage capture, with script-discovered resources
added before the final cohort: 179 responses, manifest
`8ba2d00fc4b6e14a75e27c00c228ad121609a26cb637b4f040cc3a75ff97dd36`. Replay forwards nothing. Every
final request resolves to its archived response; existing HTTP error responses
remain unchanged. Input and executable hashes are verified throughout.

ChatGPT completes its author bootstrap, has loaded fonts and an editor, and
records no JavaScript diagnostics or native errors in the final replay cohort.
All content inventories and all 3,145,728 pixels match the original control
reference in every run. GitHub completes with loaded fonts, matching content
inventories, no JavaScript/native errors and no replay misses, but pair 1 in
both builds and pair 2 after differ from the control by 296,033 pixels. Visual
inspection shows the animated hero/background at different phases. Those
captures remain failures; the reference and tolerance were not changed, and
no subset is promoted to a passing GitHub cohort.

A separate, untimed diagnostic confirms the GitHub paths execute: before removes
five duplicate initial stylesheets; after removes eight and reports an
exact-source rule-cache hit (seven entries, 2,155,231 source bytes, 258,891 nodes).
Reduced CSS work therefore executes, but these full-load measurements do not
establish a meaningful overall speedup. Warm revisits in the same browser
process are outside this experiment; the in-process rule cache may have a
different effect there. The earlier component results remain separately scoped
in [the rule-cache report](../STYLESHEET_RULE_CACHE.md).

Separate live checks launch each build once per site. Both URLs reach their
correct title and complete readiness with zero native errors and normal exits.
ChatGPT's bootstrap is present on both, but both log the same Google One Tap
FedCM migration warning, so neither receives the strict zero-diagnostic live
pass. GitHub has no recorded JavaScript diagnostics on either build. These
single live observations use changing network resources and are functional
checks, not before/after performance evidence.

The before executable is the published pre-merge production build, SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`, sealed source head
`a8bd72c10c396c0081989c6cf7085e8fbdb8303f`. After is the existing
completed, unpublished production artifact, SHA-256
`2512fd9b365450048321a49114b861da788ef0fd20708867474b2bf43cc1c4f5`, sealed source head
`b4209e8513041afb4c07d1bfd866bc6abe403b57`. Both use the C backend,
literal V `-prod`, preallocation and one C translation unit. Receipts show that
before lacks the new dense cascade heads and rule cache, while after contains
them and the new Brand deduplication. Artifact and publication leases keep both
inputs fixed without copying or replacing app bundles. The builds also contain
other local changes and use different staged V compiler binaries, so this is
an observed build comparison, not an isolated causal measurement of each PR.

Two earlier ChatGPT cohorts are retained without acceptance: the original
fixture omitted favicon responses; its first extension exposed an importer bug
that discarded recorded POST/HEAD methods. Their raw timings are unchanged and
are not pooled with the final cohort. Initial GitHub pilots likewise retain
all missing-resource failures. The importer correction is committed as
`08945d852` with a regression covering sealed and unfinished captures;
all 19 archive tests pass. No failure is relabeled as a passing run.

Detailed commands, process identities, timestamps, host loads, audits, every
sample, pins and guard exits remain in the local ignored
[raw result](recent-pr-load-times-20261109.json). The local evidence archive
`recent-pr-load-times-20261109.tar.gz` contains the fixtures, PNGs, logs,
failed attempts and temporary measurement drivers, excluding profiles, caches,
private TLS keys, app bundles and native build outputs. It has 1607 entries,
39,437,113 bytes, SHA-256 `0b182ce3aa950dcaf42215fb04ef90e7e8c3e4c6ec59580994b9053232b9d990`. Raw evidence and the archive are
not committed. The job directory, locks and guard reports are removed after
preserving this evidence, and the artifact leases are released.
