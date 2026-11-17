# Old Reddit LibJS verification — 2026-11-17

The subsequent [three-engine performance measurement](LIBJS_OLD_REDDIT_PERFORMANCE.md)
records compiled LibJS at 657.184 ms per 100 representative collapse/expand
cycles, versus V8 266.793 ms and JSC 409.549 ms. It separately records cache-fill
cost, process RSS, complete attempt data and the headless workload's limits.

## Compatibility fixes

The original Reddit-script diagnostic now passes comment collapse/expansion and
dropdown opening/closing with LibJS, including a fresh-process native-cache
reopen with the compiler disabled. A live native-input check of the updated
production browser remains pending; the earlier live failure below remains the
baseline evidence.

The implementation adds:

* Annex B block functions, including declaration-time copies into the outer var
  environment, unexecuted branches, lexical/parameter conflicts, labelled and
  switch declarations, and native-cache identity for the copy flag (`2b7eadb`).
* Independent `for (let …)` iteration environments, preserving closures created
  by initializers, bodies, `continue` paths and updates (`d5b8a312f`).
* Lazy native inline-handler compilation against the actual element/form/
  Document/global environment chain, native callback routing, handler getters
  and replacement, teardown, and `HTMLElement.click()` (`1a0eabcec`).
* Native owning-Window viewport and Screen geometry, eliminating Reddit's
  startup analytics exception (`0c8471e1b`).
* LibJS `javascript:` completion handling, preserving the document for
  `javascript:void(0)` and other non-string results without invoking object
  coercion hooks (`e821c4ea0`).

The focused block-function, loop-environment, inline-handler, geometry and URL
checks pass with both ordinary GC and `-gc none`. Native-cache tests include
fresh realms/documents and compiler-disabled reopens. The unchanged upstream AST
comparison matches all 100 cases. Full-package attempts did not pass: parallel
and combined compilation exceeded the memory guard, other builds exhausted disk,
and one batch exposed a date-test helper defined in another file. An exploratory
date-locale check also failed an assertion; its test-only edit was reverted.
Attempts and interruptions are retained. These focused results do not establish
complete LibJS or browser conformance.

The source-built diagnostic uses `tools/libjs_reddit.v`, the same original
response fixture and the native browser's DOM/module/performance bindings.
It has no JavaScriptCore context, window, layout or paint. All four real Reddit
handlers are functions; the added representative DOM probe reports correct
collapsed/expanded classes, `[+]` / `[–]` labels, and menu `inuse` transitions.
No LibJS initialization/callback exceptions remain in this probe. The incomplete offline
fixture still produces the same badge-fetch console message as the JSC control.

| Final native-cache snapshot | First process | Compiler-disabled fresh process |
| --- | ---: | ---: |
| Hits | 0 | 1,364 |
| Misses | 1,365 | 0 |
| Compiled executables | 1,364 | 0 |
| Compiler invocations | 11 | 0 |
| Invalid / pending entries | 0 / 0 | 0 / 0 |
| Native execution entries | 0 | 13,758 |

The pending-key map deduplicates identical missed executables, so first-visit
misses need not equal the final compiled count. Both runs preserve the successful
interaction probe and exit zero under the 3 GiB process-tree guard. The reopen
uses `/usr/bin/false`; this establishes native code reuse and functional behavior,
not a throughput or page-load performance claim. The diagnostic executable is
an optimized C build (`-cflags -O1`), separate from the production browser.
Its temporary executable was removed before its hash could be collected;
build/run commands, exits, fixture hashes and compiled-cache artifacts remain
available. This evidence does not establish an installed-browser result.

The latest completed production executable still predates these fixes. Managed
rebuilds first failed on the HTTP adapter below, then rejected a changed shared
Chromium source input. A later freeze rejected this session's diagnostic-tool
formatting change; that tool is now committed and stable. The managed rebuild
remains requested; no duplicate manual build was queued. A completed bundle containing the fixes is needed before the
live native mouse check can establish collapse/expansion and menu behavior.
Voting, posting, additional-comment loading, broader network APIs and full-page
rendering parity are outside the verified result.

An updated V checkout already supplies HTTP/2 admission locking. Browser
compatibility staging now recognizes and reuses that exact checked gate instead
of rejecting its changed field layout (`af3c8d919`). The real V preparer and its
V/Python regression checks pass. This removes the observed production rebuild
blocker while preserving the existing TLS wake/timeout adapters.

Current local fix evidence is under `docs/performance/libjs-old-reddit-fix-20261117/`;
its original-response fixtures remain in the cache location described below.

## Original failing production baseline

At the original production baseline, Old Reddit does **not** pass the LibJS functionality check. Native compiled-cache
reuse works, but Reddit's initialization bundles fail before their handlers are
installed. Disabling the cache produces the same failures.

A native mouse click on an actual live discussion also fails to collapse a
comment in LibJS. The same input path collapses that comment in JavaScriptCore.

The saved original `https://old.reddit.com/r/programming/` HTML was replayed at
its original origin with its author scripts retained. Seven referenced static
scripts were fetched successfully from `www.redditstatic.com`; response bodies
were hashed and served offline alongside the 24 recovered page/style/image
responses. Missing replay requests never go to the network. This is a recovered
listing-page diagnostic, not a complete archived discussion or live-site pass.

Both `reddit-init.en.Jre8Hvy5gDE.js` and `reddit.en.nBLA_HYpm1I.js` fail with:

```text
Annex B block function declarations is not translated yet
```

The baseline rejection was in `libjs/bytecode_generator.v` in `collect_vars`
and block-statement generation. Reddit's sloppy-mode block functions were not
supported by that bytecode generator. Subsequent scripts report missing
`r` and `$`. The server-rendered page reaching `ready=complete` and the browser
exiting successfully do not establish successful JavaScript initialization.

### First visit and compiled reopen

Fresh processes used the same private native-cache directory. The reopen set
`VOX_LIBJS_NATIVE_COMPILER=/usr/bin/false` and enabled separate native execution
counters. Final disposal snapshots show:

| Check | First visit | Fresh-process reopen |
| --- | ---: | ---: |
| Native cache hits | 0 | 534 |
| Native cache misses | 534 | 0 |
| Compiled executables | 534 | 0 |
| Compiler invocations | 5 | 0 |
| Invalid entries / pending executables | 0 / 0 | 0 / 0 |
| Native execution entries | 0 | 2,996 |
| JavaScript initialization errors | 8 | 8 |
| JavaScriptCore context initialized | false | false |

The cache successfully executes supported code from the other scripts on reopen.
It cannot supply semantics rejected before bytecode generation. A separate
`VOX_LIBJS_NATIVE_CACHE=0` run has the same eight initialization errors.

### Comment and menu probe

A separate fixture adds representative nested-comment and dropdown markup plus
a diagnostic script to the saved HTML, leaving all original author script
bytes unchanged. The probe reads handler types and attempts programmatic clicks.
It does not substitute reimplemented Reddit handlers.

| Observation | LibJS | JavaScriptCore control |
| --- | --- | --- |
| `$`, `togglecomment`, `open_menu`, `close_menu` | all undefined | all functions |
| Collapse and expand | unavailable | collapsed/noncollapsed classes and `[+]` / `[–]` labels switch correctly |
| Open and close menu | unavailable | `inuse` added and removed correctly |

The LibJS probe's `.click()` calls also report `TypeError: undefined is not a
function`; they therefore do not establish native pointer dispatch. The missing
Reddit globals are independently observed before those calls. The JSC control
validates the representative markup against Reddit's actual handlers; it does
not validate LibJS or a live discussion. JSC also reports a badge-indicator fetch
failure against the incomplete offline resource set.

### Live discussion and native mouse input

Fresh Vox processes with the existing imported read-only cookie jar load
`https://old.reddit.com/r/UkraineRussiaReport/comments/1xls5ou/ua_pov_ukraine_hits_10_of_russias_oil_refining/`
with its expected title and 75 comment elements. LibJS reports the same eight
initialization errors seen in replay.

A temporary input-only Cocoa test driver delivers mouse-down/up through the
native Sokol input view at the first `.comment .expand` link's audited center,
including the 92-pixel browser chrome offset. It installs no UI or JavaScript
engine hooks. The link's inline handler is `return togglecomment(this)`.

* **LibJS:** after the click, the first comment retains `noncollapsed`, the
  `[–]` label and its 408-pixel height. The browser additionally reports
  `JavaScript URL: Native JavaScriptCore values require the JavaScriptCore backend`
  when the uncancelled `javascript:void(0)` link follows its default action.
* **JavaScriptCore control:** the same native input path switches the comment
  from `noncollapsed` to `collapsed`, changes `[–]` to `[+]`, and reduces its
  height from 220 to 24 pixels. No JavaScript diagnostics are reported.

These live requests are separate functional observations; their changing
scores/content and different initial heights are not a matched rendering or
performance comparison. Before/after DOM audits and native delivery receipts
are retained. Both browsers and both 3 GiB guards exit zero with unchanged
executable/native-library hashes. This directly fails the requested LibJS
comment-collapse check, independently of the synthetic probe's missing `.click()`.

### Identity, limits and local evidence

All five replay processes use the canonical completed production browser:

* Executable SHA-256:
  `2c5e6da342aa8778cfe070fa6dd4f71cf7e17c82110376cca17d6a0d6f23b72e`.
* Production receipt: `20261117-103233-888ad036`, C backend, single C unit,
  literal V `-prod`, verified parsed inputs at `008914a45`.
* Each process pins the actual executable, native libraries and archive manifest
  throughout its run. The previously inspected receipt was superseded before
  the first launch; the first command's descriptive configuration string names
  that older executable, but its actual input pins and all subsequent processes
  consistently identify the hash above.
* Active, visible 1024 × 768 document viewport, backing/rendering scale 2, fresh
  process and private writable profile per replay trial. Live native-input runs
  use a 1024 × 656 document viewport. No performance or full-page pixel-conformance
  acceptance is claimed.
* All five replay browser/driver/guard exits are zero; no input hashes change.
  Each run uses the 3 GiB aggregate RSS guard. The largest sampled replay peak
  is 1,574,912,000 bytes.

Live HTTP checks for `/r/programming/` return 403 through direct and configured
proxy routes, including the existing imported read-only Reddit session. The
previously recorded discussion URL redirects anonymous requests to login.
A fresh native Vox process with the existing imported read-only cookie jar does
load the live listing, titled `programming`, with an isolated writable profile
and resource cache. It reports the same eight LibJS initialization errors with
the native cache disabled. Its executable/library identities remain unchanged
and browser/driver/3 GiB guard exits are zero. Thus the browser result independently
reproduces the language-support blocker; curl's access failures are not treated
as the browser's outcome.

Raw audits, final cache counters, launch commands, guard reports, probe output,
logs and screenshots remain local under
`docs/performance/libjs-old-reddit-20261117/`. Original-response fixtures and
native-cache artifacts remain in
`~/Library/Caches/Vox/benchmarks/libjs-old-reddit-20261117/`. No source or app
bundle was copied and no additional manual production build was requested.
