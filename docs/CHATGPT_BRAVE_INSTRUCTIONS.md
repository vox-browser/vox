# ChatGPT instruction comparison

The requested 5% advantage over Brave remains **unmet**. The latest complete
cohort uses production executable `401745782b25ace562042922ce4511c6138e41f1b15ee0aa0c146c72e3fe207b`
and seven alternating fresh Vox/Brave pairs. All fourteen observations exit
successfully and match the retained document PNG exactly, with complete content,
readiness, bootstrap and ownership audits.

| Launch through document PNG encoding | Retired CPU instructions |
| --- | ---: |
| Vox median | 32,363,448,715 |
| Brave median lower bound | 16,375,554,889 |
| Highest Vox upper bound | 33,451,751,487 |
| Lowest Brave lower bound | 16,289,804,431 |

The conservative observed ratio is 2.0535. The exact gate
fails: `100 * 33451751487 > 95 * 16289804431`. Raw counts, all previous
attempts and their failures, commands, identities, counter boundaries, host
load, guards and hashes are retained in the
[durable receipt](performance/chatgpt-instructions-20261104.json).
No qualifying entry is added to `OPTIMIZED_SITES.md`.

The workload replays the original anonymous homepage captured through SOCKS
once. No further live download was made. Original author scripts remain
enabled under JavaScriptCore; the homepage bootstrap executes. Both engines
use a 1024×768 CSS viewport, scale 2, unfocused documents, five-second settle
period and fresh private profiles/caches. OS filesystem and shader caches are
retained. Exclusive resource-coalition counters include startup and exited
helpers; GPU execution and outside services are excluded. Brave's endpoint
also includes CDP PNG delivery. These are startup/capture workflow counts,
with no live-site, signed-in conversation, isolated-render-time or FPS claim.

The probed native ink scan showed a 144,206,062-instruction conservative saving
in its matched component-library page trials. Its broad checkpoint passed ten
native scripts, SVG ASan, 100 exact upstream AST cases and twenty screenshot
checks with unchanged references/tolerances. Literal media-query caching and
primitive URL string projection are committed and execute in the production
page. Their focused checks pass in both GC modes, including controls. URL
projection improves the isolated component test, but whole-page trial ranges
overlap, so it receives no conservative page-level instruction credit.

An earlier seven-pair attempt failed because a preexisting interactive Brave
window spawned a new renderer during measurement. Commit `9dfcb790e` verifies
the new helper's pinned ancestry, creation times, executable and separate
coalition before excluding it; ninety counter/harness tests pass. The failed
cohort is retained. This audit correction earns no engine optimization credit.

## V compiler profile

The requested `v -profile` diagnostic now completes on the same saved page with
the original scripts, bootstrap marker and **zero differing pixels**. It uses
`-profile - -profile-no-inline -profile-fns main__main`, an instrumented `-O1`
standalone executable, and the canonical installed native libraries. Generated
compiler inputs and the executable are pinned; the shared source checkout
changed during generation, so this identifies an executable rather than a clean
source commit. No app bundle or source tree was copied.

| V function boundary | Calls | Inclusive ms | Self ms |
| --- | ---: | ---: | ---: |
| `end_chromium_text_scroll_layer` | 43 | 3,779.516 | 3,779.516 |
| `array.get` | 166,018,177 | 1,592.800 | 1,592.800 |
| `ModuleHost.supply` | 265 | 12,975.292 | 1,157.963 |
| `Runtime.call_engine_function` | 2,887 | 8,312.833 | 924.719 |
| `BrowserApp.draw_command` | 609 | 1,198.354 | 836.845 |

These are instrumented elapsed times. Self time includes native/JavaScriptCore
calls, waits and instrumentation overhead; it cannot separate CPU work from
GPU or OS waits. Inclusive rows overlap, and a recursive function's aggregate
inclusive time can exceed the run's wall time. The main-thread scope excludes
V module initialization and unscoped background-thread counters.

Short-settle captures ended before the author bootstrap and are retained as
failures. The successful diagnostic explicitly uses a **30-second settle**,
versus five seconds for acceptance. Its standalone filter-worker entry also
differs from the production minimal helper. It earns no instruction or Brave
acceptance credit. The [profile receipt](performance/chatgpt-v-profile-20261104.json)
records all attempts, rankings from the 11,269-function report, input identities,
compiler flags, memory guards and the raw report hash. The original 5% goal remains open.

Summarize the retained raw report with:

```sh
python3 tools/summarize_v_profile.py \
  Build/chatgpt-v-profile-20261104-1230/current-settled/profile.txt \
  --output Build/chatgpt-v-profile-20261104-1230/current-settled/summary.json
```

The summary tool's eight tests cover units, independent rankings, mixed-process
duplicate rejection, malformed counters and negative-self diagnostics.

## Selective performance collection experiment

An offline audit of 292 saved scripts found four review candidates. Existing
EasyPrivacy rules already block ChatGPT's event endpoints. The analytics module
has eight static importers, and native telemetry also performs service-worker
cleanup and lifecycle work, so a filename-based block would remove required
behavior. The [tracking audit](performance/chatgpt-tracking-audit-20261104.json)
retains the dependency graph and rule decisions.

The comparison tool now accepts `--script-policy chatgpt-home-performance` for
an explicit experiment on the sealed anonymous homepage. It verifies the exact
manifest and script hashes, creates an independent derived fixture, and bypasses
performance collection while preserving the module's exports, promise contract,
queue/observer cleanup and original fallback for other pages and authenticated
users. The HTML and other scripts retain their original bytes. Both browsers
receive the same changed script policy; this supplies no engine optimization
credit or live-site result. Default production filtering is unchanged.

A separate `--policy-diagnostics` run confirms that the guard executes in both
engines, with bootstrap completion and exact pixels in all four captures. Eight
uninstrumented observations then alternate original/suppressed/suppressed/original
policy pairs, using production executable
`19356cf6d7702f408fcb22c0a4a9ebdd40d069d6c3da630ecdd3af77ff80619e`.

| Two-trial diagnostic median | Original instructions | Suppressed instructions |
| --- | ---: | ---: |
| Vox | 33,536,277,314.5 | 33,139,297,591 |
| Brave lower bound | 16,369,831,910 | 16,358,415,242.5 |

The observed Vox median reduction is 1.184%; the small cohort's conservative
reduction is 205,996,983 instructions (0.616%). Brave's ranges overlap. All eight
browser/kernel exits are zero and every content/pixel check passes, with stable
inputs. Each one-pair API invocation retains its ordinary summary error because
that summary requires two pairs. Aggregating the two retained pairs per policy
provides diagnostic statistics only; the seven-pair acceptance minimum remains
enforced. Host load is 42–45 on 18 logical CPUs, limiting attribution.

Both original trials request the performance module twice and web-vitals once;
suppression requests neither, while native telemetry and service-worker cleanup
remain requested in both engines. Complete original web-vitals execution in Vox
is unproven. Visible homepage correctness does not establish signed-in or chat
submission behavior. Suppressed Vox still costs about twice Brave. The
[experiment receipt](performance/chatgpt-performance-policy-20261104.json)
preserves exact counts, all attempts, hashes, ownership audits, commands and guard
exits. The original 5% goal remains open.
