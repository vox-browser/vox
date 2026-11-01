# Stack Overflow instruction counts: PR runtime variants and Brave

Three fresh-profile trials per variant measured the same frozen Stack Overflow
questions page on macOS arm64 at a 1024 × 768 document viewport.

| Trial | Vox without either PR optimization | Vox with both PR optimizations | Brave |
| --- | ---: | ---: | ---: |
| 1 | 37,216,889,968 | 33,820,534,494 | 10,460,445,211 |
| 2 | 33,763,332,359 | 29,409,512,509 | 10,429,378,200 |
| 3 | 33,543,346,390 | 28,329,681,268 | 10,320,265,784 |
| Median | **33,763,332,359** | **29,409,512,509** | **10,429,378,200** |

**This is a diagnostic comparison.** Before/after pixels differ on
72 pixels. Unrelated compositor runtime code changed
during the baseline build. Its strict source guard failed; the successful native
compilation and private executable were retained. The after build applies the
exact merged PR2 runtime patch and verifies all CSS runtime inputs. Both contain
the intended CSS versions, but the whole source snapshots are not strictly
matched. The observed median count difference is
12.8951% fewer instructions for the after variant.
That difference cannot be attributed solely to the PRs and supplies no 15%
optimization-target credit for either PR.
The observed ranges also overlap: the largest after count is 0.8264% above the
smallest before count. This cohort has no intermediate PR1-only variant, so it
cannot measure each PR's individual contribution.

## Metric and limits

The counter is macOS libproc hardware-retired CPU instructions, including charged
kernel execution, summed over the observed browser process tree. Every aggregate
is a lower bound: short-lived helpers and external services can be missed. GPU
execution is excluded. Vox counts executable launch through normal process exit
after native capture, its semantic audit and teardown. Brave counts executable
launch through the last completed sampling pass before its first CDP screenshot
response; its later semantic audit and cleanup are excluded. Per-run sampling
gaps, missing-final counts and actual cleanup exit codes are retained.

These are browser launch/capture workflow counts. They do not isolate layout,
measure native elapsed latency, establish pixel parity between engines, or
measure live script-enabled Stack Overflow. The archive contains no author
scripts. The two Vox variants are current-source runtime-patch variants rather
than the historical whole-repository builds. Mac arm64 hardware totals must not
be mixed numerically with the earlier [Linux Cachegrind guest Ir results](STACKOVERFLOW_LINUX_PERFORMANCE.md).

## Validation and provenance

Every measured trial launches a fresh process, profile and browser cache. A local
SOCKS replay serves the same archived bytes at the original URLs, uses private
certificate trust, and never forwards missing resources to the live web. All 15
question IDs, complete 50,138-byte body text, fonts, required stylesheets and
visible images pass the content checks. Full body text hashes agree across both
browsers. Each fixed Vox variant repeats pixel-exactly across its three trials,
as do the three Brave captures. The two Vox variants differ on
72 pixels; cross-browser pixels also differ.

Execution order is before/after/Brave, Brave/after/before, then after/Brave/before.
All nine observations are retained, with host CPU count, load averages,
timestamps, commands, screenshots, audits and raw counter reports. Both private
Vox executables pass native startup. The measured jobs run under the 3 GiB
process-tree memory guard. The shared production bundle and temporarily changed
CSS files are restored after compilation. Earlier failed source guards, the
busy-guard submission and the two setup-preflight captures remain in the
evidence history and supply no optimization credit. The initial direct comparison
failed its exact before/after pixel check and is retained separately. The later
cohort measures each fixed binary diagnostically, preserving that failed
comparison check and granting no optimization credit.

Raw evidence is under `Build/stackoverflow-prs-brave-20261101/`. The
[portable results ledger](benchmark-results/stackoverflow-macos-prs-brave-2026-11-01.json) retains all counts,
binary/library identities, source drift, hashes, validation outcomes and scope
limitations. Strict source matching and the failed before/after pixel
correctness check remain open.
