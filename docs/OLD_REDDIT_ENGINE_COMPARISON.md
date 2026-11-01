# Old Reddit JavaScript-engine selection, 2026-11-01

The previous result selected **JavaScriptCore**, Vox's default. Vox also exposes
the translated **LibJS** backend through `--js-engine=libjs`; **V8 is Brave's
engine**, and is not an available Vox backend in this build.

The existing frozen fixture has **zero script elements**. Separate diagnostics
confirm that Vox creates **no selected page-script runtime in either mode**.
Consequently, the following counts compare explicit browser configurations on
the same static page. **They do not compare JavaScript execution speed.**

| Configuration | Captures | Median observed instructions | Fewer than Brave |
| --- | ---: | ---: | ---: |
| Vox, JavaScriptCore selected | 7 | 4,968,363,674 | 46.05% |
| Vox, LibJS selected | 7 | 4,969,734,801 | 46.04% |
| Brave, V8 | 7 | 9,210,001,354 | — |

The Vox medians differ by **0.028%**. With no selected page runtime initialized,
this variation cannot be credited to engine execution. Native HTML/CSS parsing,
layout, painting, browser startup, filtering and capture remain in the totals.
Brave additionally executes CDP readiness/font-wait expressions through V8;
the page itself contains no retained author scripts.

## Matched unprofiled measurements

Seven triples rotate all three configurations through a predeclared order.
Both Vox modes use the **same completed binary and native libraries as the
previous result**; only their explicit `--js-engine` selector differs. The page,
120-response encoded cache, private profiles, 1024×768 CSS viewport, 1× scale,
original fixed Brave reference and counter boundaries are unchanged. No new
production build is requested or used to attribute an engine difference.

| Triple | Vox, JSC selected | Vox, LibJS selected | Brave |
| --- | ---: | ---: | ---: |
| 1 | 4,927,292,772 | 5,009,369,572 | 9,195,471,660 |
| 2 | 4,963,109,424 | 4,909,002,331 | 9,145,156,880 |
| 3 | 4,960,017,148 | 4,969,734,801 | 9,210,001,354 |
| 4 | 4,975,800,090 | 4,986,520,324 | 9,246,570,996 |
| 5 | 4,974,733,981 | 5,000,677,760 | 9,207,268,299 |
| 6 | 5,080,057,006 | 4,962,907,487 | 9,293,911,057 |
| 7 | 4,968,363,674 | 4,943,465,483 | 9,406,176,596 |

Every observation is retained without retries or exclusions. All **21 captures
match every pixel** of the unchanged common 786,432-pixel reference and preserve
all **25 post IDs in order**. All browser, controller and guard exits are zero.
The maximum-observed-Vox/minimum-observed-Brave ratios are 0.555491510 for
JSC-selected mode and 0.547762016 for LibJS-selected mode: observed reductions
of 44.45% and 45.22%. Both satisfy the 10% observed-count gate.

Counters remain `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions` at 5 ms:
cumulative observed process trees from launch through capture, including Vox's
audit/teardown, and ending Brave at the last completed sampler pass before its
PNG CDP response. Both totals are polling lower bounds; unseen short-lived Vox
children are not given an upper bound. JSC-selected mode has final readings for
both observed Vox tasks in every trial; LibJS-selected mode misses one helper's
final sample in triple 5. Brave's missing final counts are 0, 1, 1, 1, 3, 1, 3.
No counters are denied. GPU execution, outside services and observer/replay work
remain excluded.

The host has 18 logical CPUs with one-minute loads of 5.80–8.70. The 12 GiB
guard observes 1,298.33 MiB peak aggregate process-tree RSS over 44.57 seconds
and exits zero. OS filesystem/shader caches are retained. No elapsed-time gain,
engine optimization or cold-system claim is made.

## Verifying engine activity

In separate diagnostic runs, the pinned application reports this for **both**
selectors:

```text
Ladybird V scripting: enabled=true runtime=false sources=0 source_bytes=0 preloaded_scripts=0
```

The native JSC probe interposes context/group creation and `JSEvaluateScript`.
Each capture validates the probe's PID against the measured executable's actual
root, and observes zero JSC context creations and evaluations. The probe is
validated by a JSC smoke run that records **3 context creations and 450 script
evaluations**. A LibJS smoke run passes its supported standalone bytecode
calculation with zero JSC context creations, confirming that selection does not
fall back to JSC for that calculation.

The pinned LibJS build still reports pending DOM bindings and an unsupported
`function_expr` in its built-in `about:home` script. Its standalone smoke passes;
that does not establish full browser scripting parity. **No live or original
Reddit author-script performance comparison is established.** Live acquisition
remains blocked, and the original fixture deliberately removed its script tags.

The initial debug-only diagnostic had its timing flag stripped by the normal
observer; its empty marker list proves nothing. The final isolated diagnostic
restores the flag and validates actual executable root PIDs. All initial logs
remain retained. No probe, debug timing or smoke-run count contributes to the
unprofiled results above.

## Evidence and reproduction

The implementation, source pins, exact commands, complete counters, PNGs,
eligibility probes and guard receipts are under
`Build/old-reddit-engines-20261101/`. Account-bearing HTML and screenshots remain
private. The durable [result](benchmark-results/old-reddit-engines-2026-11-01.json)
retains all 21 counts, probe results and artifact hashes. All **75 focused tests**
pass. Tooling commit `7e9c87bf` adds an explicit selector and records it in each
observation and summary. No runtime savings advance the broad-test ledger.

To repeat one selection through the public driver, use new output/receipt names:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/reddit-jsc-repeat.lock --report Build/reddit-jsc-repeat-guard.json -- \
  python3 tools/reddit_browser_instructions.py \
  --html Build/old-reddit-instructions-20261101/frozen.html \
  --expected Build/old-reddit-instructions-20261101/diagnostic/brave.png \
  --cache Build/old-reddit-instructions-20261101/frozen-cache \
  --output Build/reddit-jsc-repeat \
  --vox Build/old-reddit-instructions-20261101/measured/Vox.app/Contents/MacOS/Vox \
  --vox-js-engine javascriptcore \
  --network-deny Build/wikipedia-instructions-20261101/network-deny.dylib \
  --diff-tool Build/wikipedia-instructions-20261101/pixel_diff \
  --repeat 7 --required-reduction .10
```

Use `--vox-js-engine libjs` and fresh output/receipt names for the other mode.
The original matched-triple controller and ordering are retained in the evidence
directory. Selecting an engine or enabling scripting does not prove it ran;
verify runtime activity separately before attributing engine performance.
