# github.com/vlang/v: Vox with V8, JavaScriptCore and compiled LibJS

![Vox engine comparison on github.com/vlang/v](images/github-vlang-js-engines-20261120.png)

Measured 2026-11-20 with `tools/benchmark_github_page.py` (engines
`libjs-native jsc v8 brave`). Each launch was a fresh process with a fresh
profile and HTTP cache. It loaded the frozen original-origin replay
(`libjs-page-engines-20261117-5204-r52`) and ran to GitHub's hydrated
content, a 1 s settle, a 1024×768 document PNG at 2× density, the audit and
process exit. Engine order alternated each round.

| Engine | Valid launches | Instructions, median (min–max) | PNG available, median (min–max) |
|---|---|---|---|
| Vox + V8 | 6 | 33.24B (32.62–33.84) | 3.51 s (3.37–4.09) |
| Vox + JavaScriptCore | 7 | 28.89B (28.79–29.51) | 3.16 s (2.99–3.49) |
| Vox + LibJS (compiled) | 7 | 41.53B (40.55–41.96) | 3.63 s (3.51–4.15) |
| Brave (reference) | 6 | 20.35B (18.94–21.01) | 2.04 s (1.95–2.17) |

Relative to Vox + JavaScriptCore, V8 needs 1.15× the instructions and compiled
LibJS 1.44×. Brave's V8 `ScriptDuration` median was 194 ms.

## Builds

- JSC and LibJS share the published bundle `fe01881e…` (HEAD `c62b26514`,
  `-b c`, a single C unit, V `-prod`). LibJS used the grouped native-code
  cache prepared for that executable by `tools/prepare_github_grouped_cache.py`,
  with its lookup index learned in three untimed visits and then read-only.
- V8 used a private `VOX_V8=1` build of the same HEAD, built about 50 minutes
  later from the shared working tree (other sessions' uncommitted edits can
  differ). It used the same backend, C mode, `-prod` and JIT entitlement, and
  linked V8 14.6.202.34 from Homebrew's libnode. Every V8 launch printed the
  `Vox V8 backend` diagnostic.

## Validity and limits

- Every Vox capture differs from Brave's reference PNG by 2 pixels, so all
  three engines rendered the same page. All Vox launches passed the content
  audit and verified engine execution.
- Brave's first launch differed from the reference in a faint 646×42 strip
  (maximum channel error 9). The other five Brave launches matched the
  reference exactly, but the driver's same-engine check compares them with
  the first one and flagged them. Their loads and counts are complete and
  included above.
- The seventh round's V8 launch completed (34.00B, 3.24 s), but the pixel-diff
  tool it pinned was deleted during the run, so it is excluded. That round's
  Brave launch did not run.
- Instruction counts are polled process-tree sums. They are lower bounds and
  exclude GPU and system-service work. The host was shared (load average
  7–12), so wall times are noisier than instruction counts. This is a
  whole-browser observation, not an acceptance cohort or an isolated
  JavaScript benchmark.
