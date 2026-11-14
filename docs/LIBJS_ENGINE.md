# Experimental LibJS browser backend

JavaScriptCore remains Vox's default JavaScript engine. The translated V LibJS
runtime can now execute Hacker News's comment-collapse script against the
browser's native DOM. This is an experimental, explicitly selected backend;
general ECMAScript and Web API compatibility remains incomplete.

## Select the engine

In **Vox Settings → Advanced**, enable **Use LibJS JavaScript engine
(experimental)**, apply, and restart Vox. Disable it and restart to return to
JavaScriptCore. The choice is saved with the other browser settings.

The command line overrides the saved choice for that process:

```sh
Build/v/Vox.app/Contents/MacOS/Vox --js-engine=libjs https://news.ycombinator.com/
Build/v/Vox.app/Contents/MacOS/Vox --js-engine=javascriptcore https://news.ycombinator.com/
Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke --js-engine=libjs
```

`--js-engine libjs` is also accepted. Unknown engine names are rejected; an
unknown saved value normalizes to `javascriptcore`. LibJS execution creates no
JavaScriptCore page context and never retries failed author scripts through JSC.
The LibJS headless smoke checks arithmetic and native DOM mutation/click handling.

## Implemented execution boundary

The VM executes ordinary functions and constructors, closures, recursion,
returns, lexical arrow `this`, object/array literals, and RegExp literals backed
by the V RegexEngine. Array and String intrinsics connect the existing translated
algorithms to script-visible prototypes. Function bodies compile on first call.
Scripts and callbacks share bounded execution entries; nested calls cannot reset
the outer instruction budget.

`libjsdom` wraps native document/node owners, preserving node identity. It
provides the document queries, attributes/classes, text/HTML mutation, traversal,
live HTML collections, native event listeners and cancellation needed by the
Hacker News fixture. URL construction, URL reads and search-parameter lookup use
the translated native URL implementation. Script-source and callback storage
outlive parser scratch allocations. Runtime closure removes listeners and stops
further VM entry.

Remaining work includes modules, async/generators, eval/Function, non-simple
parameters, complete arguments objects, class execution, try/catch code generation,
the remaining intrinsic graph and most Web APIs. The parser retains its 32-call
recursion guard. RegExp replace/split/search/matchAll hooks and constructor edge
semantics remain incomplete. Location is a read adapter; navigation setters and
complete URL mutation APIs are not provided. `querySelectorAll`/NodeList,
fetch/XHR, timers and logged-in Hacker News voting/hiding are outside this slice.
See [the translation status](../libjs/PORT_STATUS.md) for the detailed boundary.

## Hacker News verification — 2026-11-14

The tests execute the complete, unchanged `hn.js` body already archived in
`Tests/Browser/Brave/hn-home-instructions/bodies/`. A fresh fetch from
`https://news.ycombinator.com/hn.js` on this date matched SHA-256
`2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0`.
The comments fixture uses the archived discussion
`hacker-news-item-50231722-complete.html`, containing 101 comment rows, plus a
small nested-comment regression fixture. Network loading is not under test.

| Check | Result |
| --- | --- |
| Complete LibJS suite, default GC | 253/253 test files passed |
| Complete LibJS suite, GC disabled | 253/253 test files passed |
| Exact upstream AST comparison | 100/100 cases matched; no overrides |
| Native HN host suite | 4/4 test functions passed in both GC modes |
| Rendered HN pointer/layout suite | 3/3 test functions passed; both JSC and LibJS collapse/expand paths passed |
| Settings serialization and defaults | Both focused files passed |
| UI2 settings Apply, Cancel and saved preference roundtrip | Focused native test executable passed |
| Native live-collection attribute invalidation | Focused regression passed in both GC modes |

The native host checks restore all 101 original comment-row classes after a
collapse/expand cycle, preserve nested collapsed state, and exercise node identity,
live collection invalidation, URL reads, duplicate/once/removable listeners,
event identity, default cancellation and listener cleanup. The rendered-pointer
test clicks the laid-out toggle glyph through normal page input and script replay,
checks resulting layout heights/visibility and unchanged navigation/history, and
confirms that LibJS leaves its JSC context uninitialized. It also checks retained
function source after parser scratch storage is retired.

The first default-GC sweep passed 252/253 files: its exact global-property
expectation predated the new constructors. The correction preserves source
global-binding order and initializes collection/RegExp intrinsics before host
global creation. A focused intrinsic-order regression and the complete corrected
sweep pass. The earlier `browserjs` full-module compile exceeded the 12 GiB guard;
it did not execute tests. The focused source-built browser pointer and UI2 settings
executables above subsequently compiled and ran successfully.

All expensive commands used `tools/run_v_tool.sh run_memory_bounded`, with the
default 12 GiB aggregate compile limit and 3 GiB for focused runtime executables;
V invocations supplied `-memory-limit 10G`. Successful final commands and guards
exited zero. The complete default and GC-disabled sweeps took approximately 974s
and 782s with sampled peak aggregate RSS of 1.19 GiB and 2.14 GiB respectively;
these are test diagnostics, not browser performance measurements.

The package suites used current `/Users/alex/code/v/v` (version text
`V 0.5.2 7d74206`), without `-old-compiler`. The source-built browser tests used
the shared worker's matching compiler/vlib at
`/Users/alex/code/v/.codex-worktrees/fix-clang-linux-examples-43218932205/v`
(`V 0.5.2 293a312`), because the other compiler's HTTP compatibility adapter
currently fails to resolve Brotli's `decompress_with_callback`. Both compiled
canonical source with the C backend and clang.

Representative reproduction commands, each run inside its own memory guard:

```sh
v -b c -no-parallel -cc clang -memory-limit 10G -enable-globals test libjs
v -b c -no-parallel -cc clang -memory-limit 10G -enable-globals -gc none test libjs
v -b c -no-parallel -cc clang -memory-limit 10G -enable-globals run tools/libjs_ast_corpus.v --all
v -b c -no-parallel -cc clang -memory-limit 10G -enable-globals test libjsdom/hacker_news_test.v
env VOX_CHROME_TEST_FILE=sites/hacker_news_collapse_test.v \
  sh tools/test_address_bar.sh -b c -no-parallel -cc clang -memory-limit 10G
env VOX_CHROME_TEST_FILE=browserapp/browser_settings_test.v \
  sh tools/test_address_bar.sh -b c -no-parallel -cc clang -memory-limit 10G
```

## Production bundle status

Implementation is committed through `fad8fc64ac6dd8d1e88f984330de6ce13faeb3af`.
Each feature commit requested a managed production rebuild. At recording, the
shared worker was still processing that request after earlier attempts rejected
source inputs changed by other sessions during compilation. The latest completed
bundle was receipt `20261114-143607-0a077e61`, executable SHA-256
`d94dced5f7643aa17ec662ec0a72400c5bb62a5e1ce87752af0a15ac07c41ce6`.
It predates this feature and cannot validate it. The checks above execute the new
source in native test executables; production headless/windowed and live-site
validation remain pending a successfully published bundle containing the change.
No duplicate production build was queued.
