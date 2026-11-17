# Old Reddit LibJS verification — 2026-11-17

Old Reddit does **not** pass the LibJS functionality check. Native compiled-cache
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

The explicit rejection remains in `libjs/bytecode_generator.v` in `collect_vars`
and block-statement generation. Reddit's sloppy-mode block functions are not
supported by the current bytecode generator. Subsequent scripts report missing
`r` and `$`. The server-rendered page reaching `ready=complete` and the browser
exiting successfully do not establish successful JavaScript initialization.

## First visit and compiled reopen

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

## Comment and menu probe

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

## Live discussion and native mouse input

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

## Identity, limits and local evidence

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
