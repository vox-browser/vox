# Experimental LibJS browser backend

JavaScriptCore remains Vox's default JavaScript engine. The translated V LibJS
runtime can now execute Hacker News's comment-collapse script against the
browser's native DOM. This is an experimental, explicitly selected backend;
general ECMAScript and Web API compatibility remains incomplete.

The subsequent [GitHub work and pixel baseline](LIBJS_GITHUB.md) remain open.
Import-free ES modules now execute; dependency graphs and React hydration do not.

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

Remaining work includes module dependency graphs, dynamic imports, top-level
await, async/generators, eval/Function, non-simple
parameters, complete arguments objects, class execution, try/catch code generation,
the remaining intrinsic graph and most Web APIs. The parser retains its 32-call
recursion guard by default; browser execution requests depth 256 while retaining
native parser/compiler stack reserves. RegExp replace/split/search/matchAll hooks and constructor edge
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
small nested-comment regression fixture. These fixture tests do not exercise
network loading; the live navigation check is described separately below.

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
| Fresh production default-JSC and explicit-LibJS startup | Both headless smoke checks passed, including DOM mutation and native click handling |
| Production saved engine and CLI override | Saved LibJS selected; explicit JSC overrode it; both smoke checks passed |
| Production HN expanded/collapsed/restored pixels | Each phase matched JSC exactly; restoration matched baseline |
| Live HN discussion with LibJS | Loaded and rendered; live clicking was not measured |

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

## Production bundle verification

Implementation is committed through `fad8fc64ac6dd8d1e88f984330de6ce13faeb3af`.
Each feature commit requested a managed production rebuild. Earlier attempts
rejected source inputs changed by other sessions during compilation. The shared
worker then published receipt `20261114-165954-ab3a34ed`, built with the C backend,
literal `-prod` and a single C unit. Its recorded Git head is `da5c4769a`; the
feature was present as uncommitted source when compilation was sealed. The exact
source manifest matches all 556 macOS source inputs checked across LibJS,
libjsdom, browserjs, browsersettings and the changed main/settings/DOM boundary;
the two platform-specific Linux/Windows stack files are excluded from this build.
No duplicate manual production build was queued.

Fresh smoke processes 80206 (default JSC) and 80223 (LibJS) both exited zero.
Fresh processes 89158 and 89174 additionally verified saved-LibJS selection and
explicit-JSC override. Each used a separate private profile. Native library and
executable identities stayed unchanged throughout smoke and paired fixture
screenshot checks, with the managed bundle lease held during those jobs.

Six windowed capture invocations used `capture_screenshot.sh` at an 800×600
document viewport, two-second settle, separate private profiles, and the test
display away from the pointer. The small nested-comment fixture embedded the
unchanged `hn.js`; inline calls to `toggleCollapse("100")` drove the collapsed
and restored phases. All three JSC-versus-LibJS comparisons have zero differing
pixels. Collapse changes 4,067 pixels in each engine, and both restored images
match their expanded baseline exactly. These production captures execute the
collapse function directly; the source-built pointer test above validates actual
event routing. These production smoke, settings, paired screenshot processes and
their 3 GiB guards all exited zero.

A fresh production LibJS process (PID 97363) also loaded and rendered the live
discussion at `https://news.ycombinator.com/item?id=50231722`. Its 800×600 document
capture visibly contains the story and comment thread; browser and guard exited
zero, with a five-second settle and no ambient proxy overrides. The first live
attempt stopped before browser launch because the bundle lease was busy. The
retry used the available bundle and verified executable/native-library hashes
before and after capture; identities remained unchanged. This establishes live
navigation/rendering, while comment-collapse acceptance uses the frozen fixtures
and native pointer test described above.

Pinned SHA-256 identities:

| Artifact under `Build/` | SHA-256 |
| --- | --- |
| `v/Vox.app/Contents/MacOS/Vox` | `731ef68c901b8be1ce7858eef0c1d5d93c2b8df7584cc7b4f61a80d42bcef604` |
| `v/libLadybirdVSkiaText.dylib` | `ca10e83a001e18cf83ca29fea59da0091307c3ccb7ed5e4088f602b9e6ab0ac7` |
| `v/libVoxAVIF.dylib` | `cbbae055532f17ab8f656bb120dc8d7fe3ffd9841bada8c7f635957b5c15f0ba` |
| `v/libVoxGraphite.dylib` | `59b9b9a5d65da5d69b196474afc5eb48c9e71e21f3fddfc04b986aa9d2a47c54` |
| `v/libVoxGraphiteDawn.dylib` | `aca10cc49100191dcc27b528214f92f1c8e8e5227610916d89ecd865e1e7776b` |
| `v/libVoxJPEGXL.dylib` | `d8c2c90290e249524617ba1384453a6955bae630048ac7b2cbc6d8b3634882d9` |
| `pixel-tools/pixel_diff` | `41d1b3b0e20f2e1dc422ac190a9dff6cf33a225aebdea8c3329b2713a28b7972` |
