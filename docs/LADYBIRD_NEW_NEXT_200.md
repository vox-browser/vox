# Next 200 newly imported Ladybird tests

This batch continues the [first 100](LADYBIRD_NEW_FIRST_100.md), using Ladybird
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`, newly imported since
`963d46a829f3e1b79f44dba9d02afb70654300fa`, discovery positions 101–300.
The [200 case IDs](../Tests/Browser/ladybird-new-next200-20261108.txt), query
variants, input files and upstream assertions remain unchanged. Fixtures are
exported from the fetched revision without changing the Ladybird checkout.

**Strict acceptance remains incomplete: 194/200 pages and 9,664/9,692 reported
subtests pass in the complete native engine run.** All 155 CSS pages pass.
The available production browser baseline passes 72/200 pages; it predates
these fixes and does not validate them.

## Complete native engine run

The November 9 continuation uses the actual browser navigation preparation,
parser lifecycle, native Document/DOM/CSS/layout, JavaScriptCore, child realms,
fetch and HTML event loop. Every page launches a fresh process and profile.
The driver supplies rendering opportunities and an 800×600 viewport without
creating a GUI window or painting. This is imported testharness coverage,
not screenshot conformance or the full upstream WPT suite.

| Group | Pages | Fully passing | Passing subtests |
|---|---:|---:|---:|
| Content Security Policy | 45 | 39 | 145/173 |
| CSS2 line boxes | 1 | 1 | 13/13 |
| CSS alignment | 80 | 80 | 2701/2701 |
| CSS anchor positioning | 74 | 74 | 6805/6805 |
| Total | 200 | 194 | 9664/9692 |

Executable SHA-256:
`efc1a850b57b1d3f19e4ba512fe68a3fc2b997569bf50ec2ba8836dc3e6a263b`.
The entire selection runs on this one executable. All 200 documents report;
195 harnesses are OK and five TIMEOUT. Subtests are 9,664 PASS, three FAIL,
five TIMEOUT and 20 NOTRUN. Uncaught author exceptions reach the stock harness,
so a document that aborts registration does not silently receive pass credit.

The controller verifies the executable, controller, server tools and immutable
fixture tree. All pins remain unchanged. It serves original support files with
upstream wptserve, including Python handlers, substitutions, stash and resources.
The existing harness timeout normalization and collecting report script do not
change assertions or expected results. Inner process guards are 2 GiB; the
aggregate 3 GiB guard observes 349,618,176 bytes peak RSS over 185.91 seconds.
The strict runner and supervisor exit 1 because acceptance is incomplete.

Earlier failed, interrupted, diagnostic and partial runs are retained separately.
Their results are not combined with this complete run or counted as additional
passing pages. The earlier 72/200 native checkpoint is superseded.

## Engine fixes

Alignment parsing preserves safe/unsafe and first/last baseline qualifiers,
legacy ordering, shorthand expansion and inherited legacy alignment. Block,
line, table-caption and absolute layout handle writing modes, overflow,
baselines, intrinsic constraints, aspect ratios and stretch sizing.

Anchor layout resolves live anchor geometry, scroll offsets, logical sides,
anchor sizes, invalid calculations and fallbacks. Position-area placement,
position-try parsing, shorthand variables, fallback order/tactics, successful
geometry and transitions now use the actual computed style and containing
block. Applying a fallback preserves ancestor selector context. CSSOM mutation
invalidates named fallback references even when the ordinary computed style is
unchanged. Shadow tree scopes, exposed parts, layers and backdrop resolved
geometry are covered. Live anchor queries interpolate as length calculations,
and CSS animations/transitions support cancellation through Animation.cancel().

The native CSSOM exposes CSSPositionTryRule descriptors and typed computed
values. Declarative shadow roots materialize when their template closes, so
following parser scripts observe the correct tree. The native harness uses the
same prepared navigation/parser order as the browser and services font-ready,
animation and rendering waits.

CSP uses actual event targets across fragments, disconnected nodes and shadow
trees; preserves nonce hiding for HTML/SVG; and enforces inline styles, scripts,
javascript: navigation, Window.open, timers and string compilation. Same-origin
Window proxies preserve native constructor identity. Timer operations are
nonconstructable and keep their receiver realm. Browser-owned event-handler
compilation restores the native eval gate before author code executes. Media
created after parsing starts the initial load lifecycle, including loadeddata;
Ogg support reflects the native decoder's real capabilities.

CSP property-store source positions map to the actual authored assignment
target, using the active Script Record and preserving UTF-16 columns. Native
method-call positions remain unchanged. The shadow-DOM source-column page and
all other event-targeting pages pass together. The first broader mapping
regressed calls and is retained as a rejected full run. The focused mapping is
committed as `597934ac7`, with parser and native DOM regressions.

Focused parser, layout, CSSOM, DOM and JavaScript regressions accompany the
committed fixes. Guarded C builds and focused runtimes are retained in the local
evidence, including failed attempts and memory-limit stops.

## Remaining failures

Five pages time out waiting for securitypolicyviolation after native eval is
blocked: `script-src-trusted_types_eval_with_report_only_require_trusted_types_eval`
and all four variants of `script-src-trusted_types_eval_without_require_trusted_types_eval`
(default, double-quoted, unquoted and uppercase). JavaScriptCore rejects eval
and Function compilation through its [native eval switch](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/API/JSContextRefPrivate.h),
but Vox's C API integration has no unsafe-eval reporting callback for caught
native exceptions. The first promise test times out; the remaining
four tests on each page are NOTRUN. Native direct-eval lexical scope and dynamic
policy gating have focused coverage. These pages still require engine integration;
wrapping eval would change its lexical scope and is not a correct substitute.

`inline-style-allowed-while-cloning-objects.sub` passes 22/25 assertions. Tests 19
and 20 compare a CSP-blocked background with a separately allowed CSSOM background;
`non-HTML namespace` expects the original SVG style attribute to be empty.
The pinned Ladybird expected file explicitly records these same three failures.
A fresh Brave run of the unchanged page also gives 22/25 with the same failures.
They remain strict failures; neither the selection nor the assertions are changed
and Ladybird's known failures are not silently treated as passes.

## Production baseline and required checks

The latest completed shared production receipt identifies source
`646535154eedc675df5dd6780755983417ec7fb8` and executable SHA-256
`23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`.
A fresh full-batch baseline with that executable passes 72/200 pages and
7,362/9,664 reported subtests: 2,271 FAIL, three TIMEOUT and 28 NOTRUN. There are
198 reporting documents and two NO_HARNESS; reporting harnesses are 173 OK,
22 TIMEOUT and three ERROR. The original older production measurement, executable
`f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`,
passed 10/200 and remains historical evidence only.

The managed production worker is already busy. No duplicate production build is
queued; a matching windowed production rerun remains pending. The native results
above validate the new engine executable, not the older installed bundle.

The original Volt workspace's mandatory `v -enable-globals -o volt .` build,
run with the existing 10 GiB compiler and 12 GiB process-tree bounds, fails when
the compiler reaches its 10 GiB physical-footprint limit. The required `make app`
passes. These checks do not replace Vox engine validation.

## Reproduction and evidence

The production runner remains:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-next200-repeat.lock \
  --report Build/ladybird-next200-repeat-guard.json -- \
  python3 tools/wpt_compare.py --output Build/ladybird-next200-repeat \
    --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
    --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
    --offset 100 --limit 200 --browsers vox --chunk-size 10 \
    --browser-memory-gib 2 --require-all-pass \
    --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

The native executable is built from `compact/upstream_testharness_test.v` with
`v -b c -memory-limit 10G -enable-globals -cc clang -w -skip-running`, under the
12 GiB build guard. Its HTTP integration mode takes VOX_UPSTREAM_WPT_URL and
VOX_UPSTREAM_WPT_RESULT. The local controller records all 200 case results,
identity pins, HTTP requests, guards and unchanged fixture verification.

The [local manifest](performance/ladybird-new-next200-20261108.json) and raw
evidence remain outside Git. The original archive is
`/Users/alex/.cache/vox/wpt/20261108-ladybird-new-next200.tar.gz`, SHA-256
`c45db5b0621fa9d1c8317faca666064a9cb0a76faaf3cd3b9cea277998eac21b`.
Continuation evidence is retained in
`/Users/alex/.cache/vox/wpt/next200-20261109-work/evidence-20261109-060144/raw-evidence.tar.gz`,
SHA-256 `7162c61a5228f8e911f2254245518300b9dd0d3ec1bcb3eecd67caa946a4a6c7`.
All 18,667 archive members are read back successfully. The final native executable
is retained alongside the archive with the hash recorded above. The archive
includes completed and rejected runs, controllers, identities, guards, logs,
fixtures metadata and the local manifest. All 795 completed session entries are
removed from Build; shared production artifacts and other sessions' files remain.
