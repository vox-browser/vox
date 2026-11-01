# ChatGPT rendering and startup against Brave

The macOS production browser now starts the archived logged-out ChatGPT
application. Pixel-exact parity and an actual conversation are **not complete**.
The full-page comparison still has rendering differences; focused fixtures and
a successful application startup are not a substitute for that comparison.

The latest unchanged-original-archive capture differs in **876 of 786,432
pixels (0.1114%, MAE 0.0009)**. Startup, native typing and Enter are validated;
a completed chat reply remains unverified. The recorded 60-second idle check
peaks at 1.82 GB rather than continuing toward the 12 GiB guard.

## Captured workload

The successful capture used a fresh, normal Brave window through
`socks5h://127.0.0.1:1337`, away from the pointer. The page title was
`ChatGPT: Chat, Work, Create & Code with AI`, at 1024×768 CSS pixels and an
emulated device scale of 1. Earlier curl and headless Brave attempts received
Cloudflare challenges; those responses are retained separately.

Private evidence is under `Build/chatgpt-parity-20261031/`. The successful
capture is `native/`, including `brave.png`, `frozen.html`, and
`original-archive/manifest.json`. That archive retains the original HTML,
stylesheets and available script responses, rather than replacing the site
with an imitation. The original document's SHA256 is
`1f72b297f96be72d20c6392e53c5fc63b05fcb022e70c8bb1449afdd20c13903`.

The archive has 304 response entries, including 291 scripts and two
stylesheets. It also records 218 response-body retrieval errors, including
requests from the earlier document before the site's reload. It is a captured
homepage workload, not a complete archive of every route or future API request.
CDP's newline-combined headers were split into individual HTTP fields for
replay; the original CDP metadata remains in `manifest.cdp.json`.

Vox additionally requested a 4,001-byte HTML-setter polyfill that Brave did not
need. A separate normal Brave capture downloaded that asset once through SOCKS
after curl received a challenge. `original-plus-fallback-archive/` adds this
response while retaining the original archive unchanged. It does not replace
the missing response with a fabricated script or forward later cache misses.

Subsequent comparisons use the local, non-forwarding HTTPS replay in
`tools/page_archive.py`. Missing requests never download from the internet.
The separate `frozen-archive/` removes scripts from the captured DOM to isolate
rendering. A successful frozen capture cannot validate application behavior.

The initial live reference used native-window raster settings. Later controlled
references pin Brave's device scale with the updated reference tool. Their
decoded images differ, so they are not interchangeable references. No exact
live-to-frozen parity is claimed.

## Implemented fixes

- `2baaeecd`: Inactive scroll timelines no longer sample the document clock
  and install forwards-filled animation values. ChatGPT's sidebar, header and
  composer retain their cascaded geometry. Explicit scroll clocks and paused
  hold times have focused coverage. This does not implement source resolution
  or the complete CSS scroll-animation range model.
- `88203642`: Compact wrappers expose the correct HTML interfaces for links,
  scripts, buttons, forms, dialogs and textareas. Parser-created and created
  elements retain their namespace, prototype hierarchy and interface identity.
- `889ae90d`: `querySelectorAll()` returns a static, branded `NodeList` with
  `item()`, iteration and out-of-range behavior. `childNodes` remains live.
  This removes ChatGPT's startup failure when it calls `list.item(list.length-1)`.
- `dd340a2a`: The Chromium font policy continues past unavailable
  `ui-sans-serif`. Brave's platform-font probe identifies `.SF NS` for the
  homepage heading. This commit also assumed -apple-system was an alias;
  `97efe424` corrects that assumption using a disambiguating Arial fallback.
  A standalone unavailable UI family still falls through to the author's
  ordinary sans-serif fallback. The LibWeb fixture policy is preserved.
- `3ee2380c`: Compact elements implement `toggleAttribute()`, including
  optional/undefined force values, validation, preserved existing values and
  the ordinary attribute mutation path. HTML names use ASCII lowercasing;
  non-ASCII names and SVG attribute case remain intact.

The initial `bde4c36a` mapping selected system UI directly for `ui-sans-serif`.
The unchanged Brave reference rejected it with 9,347 differing pixels.
`dd340a2a` corrects that generic-family assumption rather than changing the
reference or relaxing the comparison. Its separate -apple-system alias
assumption is corrected in the continuation below. The failed test and platform-font probes are retained.

The focused V tests execute twelve cases in each of Boehm and no-GC modes,
24 executions total. Compilations use the 12 GiB guard and a 10G V compiler
limit; test binaries execute under separate 3 GiB guards. Receipts are in
`focused-test-results.json`. The first attempt to compile the CSS tests under
a 3 GiB aggregate guard was stopped; it receives no test credit.

The reduced `inactive-scroll-sidebar` native comparison passes with zero
differing pixels. Both font comparisons also pass with zero differing pixels,
using the original `ui-sans-system-font` reference and the added
`apple-system-font-stack` reference.

## Earlier native validation

The shared production build completed successfully and its recorded tracked
inputs stayed stable. Its receipt is
`Build/forum-news-svg-opacity-fold-20261031/production-final-guard/result.json`.
This session's later build request encountered the busy shared guard and did
not queue a build. The completed shared bundle was reused instead. Its tracked
feature hashes match the tested source; the complete current toggle helper's
JavaScript bytes were additionally verified in the executable because that
new file was untracked when the other session collected its build inputs.

The executable SHA256 is
`7a940e79d2d2105d721e201664d17885863b9010680510d8a3266cbfb3627306`.
`selected-production.json` records the native libraries and bundled filter
snapshot too. Every final check launches fresh processes and retains an
unchanged executable/library identity before and after capture.

- Three focused Brave pixel comparisons: all exact.
- Default screenshot smoke set: 11 passes, eight exact and three within their
  existing allowances.
- SVG image replacement and paint-server mutation guards: ten exact passes.
- Native `--headless-smoke`: passes.
- Original-script replay: document loads, but application startup fails its
  JavaScript gate. Successful screenshot capture is not application success.

The 1024×768 frozen-page comparison still fails exact equality:

| Saved Vox capture | Differing pixels against the same controlled Brave reference |
| --- | ---: |
| Initial completed production bundle | 222,349 / 786,432 (28.2731%) |
| Selected final production bundle | 124,595 / 786,432 (15.8431%) |

The final maximum channel error is 239 and MAE is 2.5606. No pixels or regions
are excluded. These whole-page counts include independent native changes in
the shared builds and do not isolate an individual fix's contribution.
Cookie-banner policy and text wrapping still visibly differ. The exact focused
fixtures do not establish exact rendering of the complete page.

Images, diffs, commands and actual guard results are in `frozen-acceptance/`,
`original-acceptance/`, `acceptance.pixels.json`, `screenshot-summary.json` and
`acceptance-validation.json`. `site-status.json` explicitly records
`target_met: false`, `application_startup_success: false` and
`conversation_verified: false`.

## Remaining gates

The macOS host now executes real JavaScriptCore module graphs, with import-map
resolution, cycles, live bindings, dynamic imports and top-level await. The
standalone runtime without that host, and the Linux backend, still reject
module execution. Native module support alone does not establish that the
complete ChatGPT application starts.

The original-script replay passes the app's `data-octane-home-behavior-ready="1"`
gate in a fresh production window, with no native reported script errors.
The unmodified native startup probe also settles with 284 module sources,
no pending module requests, and no host errors. Brave reaches the same marker
from the same non-forwarding archive.

Vox hides matching cookie banners by default through `cookie_blocker.v`.
Conformance launches set `VOX_BLOCK_COOKIE_BANNERS=0` so both browsers display
the site's unchanged consent UI. Screenshot mode otherwise reports an inactive
window; `VOX_CAPTURE_DOCUMENT_ACTIVE=1` matches the focus emulation used in the
Brave reference. These policies are recorded explicitly and do not alter site
HTML, scripts, stylesheet rules, expected pixels, or comparison regions.

No screenshot tolerance or reference region is relaxed for ChatGPT. Startup
failures, incomplete captures, changed executable identities and memory-guard
failures do not count as successful validation.

## Native modules and live DOM follow-up

Private evidence for this continuation is under
`Build/chatgpt-shadow-modules-20261031/`. It reuses the sealed original archive
and the captured fallback response; ChatGPT has not been downloaded again.

- `4c870df8` and `aaba271e`: declarative shadow attachment clears the existing
  children, and compact ShadowRoot wrappers operate on native trees, including
  attachment, markup replacement, queries and root lookup.
- `bbc8921b` and `77ce4dbb`: parser-created import maps reach the owning Window,
  and the macOS host loads native JavaScriptCore module graphs through Fetch.
  Dynamic import rewriting uses the pinned es-module-lexer parser. Focused
  tests retain native module identity, cycles, live bindings and top-level await.
- `9ad0eff1`: asynchronous module supply enters the owning HTML realm.
- `1ca19806`: linked stylesheets expose their native CSSStyleSheet and live
  rule lists. Real link owners preserve style order, duplicate URLs each get
  completion events, and cross-origin rules retain their SecurityError gate.
  The pre-existing compact style-element sheet approximation is still separate.
- `0cb1ea9f`: input and textarea value/defaultValue access uses the real control
  models, including clean/dirty values, textarea newlines, reset and insertion.
  This fixes the captured app's `defaultValue.replace` startup exception.
- `f2afb17b`: macOS socket readiness survives partial SOCKS/TLS handshakes.
  Dispatch sources signal the owning CF loop; V callbacks stay on that loop.
  Duplicated descriptors remain owned until asynchronous cancellation finishes.
- `de4e64ac`: native socket callbacks and output pointers use 32-bit C integers.
  A Darwin arm64 ABI regression test deliberately leaves upper argument-register
  bits nonzero: the old callback created descriptor key 20014547599363 for
  descriptor 3; the corrected callback registers and removes descriptor 3.
- `b776b6b6`: the native module fixture covers 130 concurrent 256 KiB HTTPS
  responses through the local SOCKS replay. Failed module loads identify the
  requested URL. Both Boehm and no-GC executions pass.

The socket adapter passed twenty fresh-process HTTPS/SOCKS module trials.
Certificate tests still reject incorrect hostnames and unrelated certificate
chains. Native transport, large concurrent HTTP modules and scratch-lifetime
checks pass in Boehm and no-GC modes. Link/control tests additionally pass in
production allocator mode. Detailed compile and execution receipts, including
failed diagnostic attempts, remain in the private evidence directory.

The completed `production-control-styles-network` bundle includes the linked
stylesheets, text controls and dispatch socket adapter. Its executable SHA256 is
`2a3659dbae38badde55abe985f87b58f1c340ea1cfd7a42c134ae4d4db805f2d`.
Its build completed with stable recorded sources. It predates the integer ABI
fix and subsequent layout work, so it cannot validate those changes.

The unchanged original-script replay at 1024×768 still differs from its matched
normal-window Brave reference at 125,454 / 786,432 pixels (15.9523%, MAE 2.6107).
Both captures retain an identical native executable/library identity across
the check. `original-production-gcd-acceptance/` retains the images, complete
unmasked diff, readiness audit, proxy requests and build identity. This original
script workload is distinct from the earlier frozen-DOM comparison above.

## Focused screenshot checks

With the recorded completed production bundle:

```sh
python3 tools/test_scroll_animation_pixels.py
python3 tools/test_ui_sans_font_pixels.py
```

Each test pins the executable and native-library identity, launches a fresh
process with a private profile, and requires exact RGBA equality with its
Brave reference. The HTML inputs and reference PNGs are in
`Tests/Browser/Brave/{input,expected}/`.

## Native startup continuation

The original HTML response remains
`1f72b297f96be72d20c6392e53c5fc63b05fcb022e70c8bb1449afdd20c13903`.
No further ChatGPT download was made. Every replay uses the local SOCKS/TLS
archive with private, process-local trust; it does not forward misses.

- `547b107f` binds native document visibility; `96b9a8fa` reflects HTML language.
- `3bfd24c3` drains already-ready native completions within the event pump's
  existing budget. This lets the actual HTTPS module fan-out complete.
- `53906747` discovers lazy native controls in form collections; `5a560998`
  exposes live native form/radio collections and form-control owners.
- `873efb07` binds document focus queries to the actual navigable.
- `c5ffb62b` exposes native client rectangles and mutable DOMRect values.
  Native client rectangles currently describe one border box per element;
  fragmented inline geometry is not established by this slice.
- `dbd88037` keeps persistent allocations outside scratch around nested owners.
- `e4d17315` queues native mutation records and tracks removed subtree
  registrations through notification, re-observation and disconnect.
- `bfc8ad41` delivers MutationObserver/MutationRecord wrappers from native DOM
  records, with filtering, old values, static NodeLists, takeRecords and callback
  exceptions. During JavaScript, notifications share its protected Promise
  carrier; native-origin changes enter through the owning HTML checkpoint.
  Complete interleaving parity between the embedding's HTML and JSC queues
  is not established.
- `487a6830` exposes CSS.supports and CSS.escape through the existing CSS engine.
- `a1618b65` gives parsed and constructed Text/Comment nodes their native
  interface identities and CharacterData/Text mutation operations.
- `3e70411d` completes initial style preloads on their actual link owners,
  allowing load listeners to promote them to stylesheets using the fetched
  bytes. Failure, duplicated-link identity and request-scratch ownership are
  covered. Dynamic preloads of every destination are outside this slice.
- `717307f5` balances short text and avoids orphan words using native advances;
  `d15bc3ae` retains this behavior with overflow-wrap:break-word when whole words
  fit. Long-word fallback remains with the existing breaker.
- `c62c4f32` and `52317945` make consent and capture focus policies explicit.

Evidence is under `Build/chatgpt-shadow-modules-20261031/`. The 23-case API batch
passes in Boehm, no-GC and preallocated modes, including arena poisoning in the
last mode (`api-batch-results.json`, source hashes in `api-batch-sources.json`).
The 12-case stylesheet/preload regression batch passes in all three modes
(`style-preload-final-results.json`); the four wrap cases do too
(`wrap-breakword-final-results.json`). Compile and execution receipts are
separate. Failed diagnostic attempts remain available.

The focused persistent-allocation poison reproducer and native observer lifetime
checks pass. The allocator regression diagnostic also retains the original
unmodified failures: several string buffers were not inside the asserted owner,
and subsequent tests inherited the unfinished scopes. A separate 20-case harness
that explicitly clones the input buffers passes with poisoning. That adjusted
harness is diagnostic evidence, not an unmodified broad-suite pass.

The first completed continuation production build is pinned in
`production-frontend-complete/{result,guard,identity-after}.json`: executable
`50678667e6408574074c5f7472ea601a61208ff038ff91d4fd6773a8daa91740`.
All recorded source inputs were stable. Its fresh full-page capture reaches the
application marker with zero native errors, but differs from Brave in 371,812
of 786,432 pixels (47.2783%, MAE 3.7186). This exposed the missing promotion of
the secondary stylesheet and the unmatched screenshot focus policy. It used
visible consent UI and cannot be compared as a performance or regression result
with the earlier hidden-banner capture. Artifacts are in
`frontend-production-acceptance/`.

That same executable passes the default 11 screenshot cases, all 10 required SVG
mutation guards, the shadow/module fixture, the original wrapping fixture and
headless startup (`candidate-validation/results.json`). Brave's 5-second and
20-second original-archive control captures are pixel-identical. The additional
break-word fixture also leaves Brave's existing reference pixel-identical.

The next production comparison includes preload promotion, matched focus and
break-word wrapping. The executable is
`8fc9c4297469ca52c766697319c56d31d722f189bd2fdec0d6dfbe154f9bae37`
(`production-preload-focus-wrap/`). Its required implementation sources were
stable, although two unrelated native renderer test/header files changed during
the shared build, so the complete checkout was not stable. The unchanged
original archive reaches the application marker, activates both stylesheets and
reports zero native or JavaScript errors after 20 seconds. At 1024×768, scale 1,
with visible consent UI and explicitly active capture focus, it differs in
9,495 of 786,432 pixels (1.2074%, MAE 0.1889). No mask or pixel tolerance is used.
Artifacts are in `frontend-preload-focused-acceptance/`.

That executable passes both wrapping fixtures, the shadow/module fixture,
headless startup, the default 11 screenshot cases and the 10 SVG mutation
checks (`candidate-validation-preload-focused/results.json`). Native typing
then exposed missing active-element getters and legacy input events; commits
`984b07da` and `72f02cc7` provide those bindings. A later shared executable's
longer typing diagnostic exceeded the default 12 GiB memory guard after input,
so that diagnostic supplies no acceptance result. A separate small native
textarea fixture reproduces the first-character loss without React: its first
input listener's `.value` read resets a still-clean model. The dirty flag now
precedes input dispatch, including reentrant `defaultValue` access. This is an
intentional ordering correction to the current upstream translation.

Cached sentinel and conversation preparation POSTs return 404 in this archive;
no conversation has been sent or verified. Full pixel equality and sustained
interactive memory behavior remain open.


## Native editing, caret and idle-memory continuation

`ecde0df9` integrates `origin/master` at `b5af1a2e`, preserving the existing
shared commits. No textual merge conflicts occurred. The incoming 63 Python
checks and 26 CSS checks pass; the CSS checks run in all three allocator modes.
The integration receipts are in `Build/chatgpt-master-integration-20261031/`.

The following focused changes are committed separately:

- `1b90a77e` marks textarea edits dirty before input listeners can read the value.
- `144829e2`, `1ce246dc`, `a48ace48` and `bbe70152` provide cap metrics,
  cross-node kerning, nested-inline wrapping and horizontal text-box trimming.
  Trimming supports the implemented Latin edges; ideographic edges, vertical
  propagation and the complete shorthand are not claimed.
- `fbc807eb` routes clicks through the native event path without duplicate
  delivery. `21c21bba` exposes native KeyboardEvent data and listeners;
  `9cb5058e` dispatches keydown/keypress before editing default actions. Native
  Enter reaches JavaScript and cancellation prevents the editing action.
  This is not complete platform-key coverage: the shell's printable-character
  path and keyup delivery still have separate implementation limits.
- `4a1d9636` holds the caret visible during explicitly focused deterministic
  captures, without changing ordinary interactive blinking.
- `e844a956` distinguishes :has() match propagation from a fresh DOM mutation
  and drains whole-subtree fanout in the same style pass. Nested :is()/:where()
  selectors previously lagged a state change and continually scheduled work.
  Eighteen related CSS cases pass in all three allocator modes, including
  shadow trees, sibling selectors, later mutations and the existing result cache.
- `d59473cb` paints opaque padding-box outer shadows before the background,
  using the existing one-CSS-pixel overlap. The isolated Brave fixture is exact
  with single, multiple, asymmetric and hard shadows. The rejected wider-border
  overlap attempt and its failed comparison remain under Build/.
- `643b27e7` creates a focused textarea's native editor before layout, paints
  its caret above the placeholder, and uses integer CSS-pixel font metrics for
  Chromium caret height. The existing focused-control preparation, selection
  and layout-retention regressions and the new empty-control case pass in
  Boehm, no-GC and preallocated modes.
- `97efe424` corrects the earlier -apple-system alias assumption. Brave's
  platform-font probe selects ArialMT for `-apple-system, Arial`; the family is
  unavailable and must fall through. Explicit system-ui and BlinkMacSystemFont
  continue to select the system face. The original stack reference remains
  unchanged; the new disambiguating fixture is also exact.

The final validated production executable is
`c088a9024bdf363d2b05d519bf4cd6c50f3109630aa384de10119e6fac74cce4`.
Its native-library identities and build receipts are in
`production-caret-font-fallback/` under
`Build/chatgpt-shadow-modules-20261031/`. Required implementation inputs stayed
stable. An unrelated flex-layout source changed during the shared build, so
this is not a stable-whole-checkout build claim. Every acceptance capture and
screenshot group pins an unchanged executable/library identity and starts fresh
processes on the test display.

`candidate-validation-caret-font/results.json` records ten exact focused Brave
fixtures, successful headless startup, all eleven default screenshot passes
(eight exact and three within existing allowances), and ten exact SVG mutation
guards. The broader Page regression compilation exceeded the 12 GiB guard;
those attempts supply no broad-suite test credit. The twelve native editing
cases and native Enter regression execute successfully in all three modes.

`frontend-caret-font-acceptance/` retains the unchanged-original-archive capture,
matched normal-window Brave reference, complete diff, native readiness audit,
proxy log, PID and identity. Both original stylesheets load, the actual frontend
reaches its home-ready marker, and native/JavaScript error counts are zero.
At 1024×768, scale 1, visible consent UI and explicitly active document focus,
7,169 pixels differ (0.9116%, maximum channel error 60, MAE 0.0110). There are
454 pixels above channel error 3 and seven above 25. No region is masked and
no tolerance is applied to this whole-page result. SVG edges, rounded controls
and shadow/compositing rounding remain open.

The matched 20-second original-archive captures record peak aggregate RSS of
9,051,865,088 bytes before the :has() correction and 1,822,883,840 bytes after it.
The separate pinned diagnostic `native-idle-has-settle-60s/` completes in 61.34
seconds with peak RSS 1,824,686,080 bytes and zero script/native errors. Its
symbolized mmap stacks contain no :has() invalidation allocations after the
first ten seconds. These are memory/eligibility observations, not frame-rate
or scrolling-performance claims; the shared builds include independent changes.
The final full-page capture peaks at 1,826,340,864 bytes.

`native-editor-enter-caret-font/` records the latest native input check. A probe
sends actual AppKit mouse and keyboard events to the content view, types Vox,
and presses Enter. The composer retains all three characters; Enter reaches
the frontend without adding an editing newline. Archive-only sentinel and
conversation preparation requests remain 404, so neither that check nor the
startup marker establishes a completed chat response. All these checks reuse
the original saved download through the non-forwarding local SOCKS replay.


The latest shared bundle subsequently replaced that executable with
`588e99f41112f9986419a766bf7682e66736886f809ea296a07c19325ff983be`.
Its `Build/vlang-parity-20261031/definite-flex-basis-production-inputs-{before,after}.json`
receipts match all fourteen required implementation hashes
(`installed-shared-source-validation.json`). It is reused without another build.
`candidate-validation-installed-shared/results.json` repeats every focused,
headless, screenshot and SVG group successfully with stable identity.
`native-installed-shared-acceptance/` records a fresh original-archive native
capture compared against the unchanged, matched Brave reference identified in
`reference.json`: the same 7,169 differing pixels, zero script/native errors,
and peak RSS 1,826,275,328 bytes. The native typing/Enter check above also uses
this latest shared executable. Pixel-perfect rendering and a completed chat
reply remain unverified.


## Translucent rounded borders (2026-11-01)

`b976cef2` composites a matching solid background and translucent uniform border
through one outer rounded clip and offscreen layer. The border fills the inverse
inner rounded path, matching Brave's recorded paint commands. The recorder finds
the background after leading outer shadows; padding-box and content-box
backgrounds retain their separate clips. The native fallback uses the Dawn
picture rasterizer to preserve the layer's premultiplied resolve. Its inverse
path remains inside that offscreen layer and does not select MSAA for unrelated
shapes in the parent raster.

The new `rounded-translucent-border-clip-layer` fixture includes five border
cases, with thin borders and several shadows, and an unrelated black pill.
Every RGBA pixel in its 800×600 viewport matches normal-window Brave at scale 1.
The five original cases are unchanged in the reference; the added pill catches
parent-pass MSAA leakage. That rejected trial differed by 32 pixels with maximum
channel error 12 in this expanded fixture and added three larger errors to the
homepage's Accept all button. The final build removes those errors. No masks,
reference allowances or full-page tolerances were introduced.

Evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `rounded-translucent-border-isolated-msaa-results.json`: both focused V cases
  execute in Boehm, no-GC and prealloc modes. They cover all three background
  clips, no/one/multiple shadows, empty clips and incompatible geometry.
- `native-clip-sanitizers/`: all five native sanitizer executables pass, including
  twelve exact native/GPU clip-layer cases and the existing rounded-underlay
  checks with tile batching and compound patches disabled separately.
- `black-neighbor-reference-v2/` and `border-reference-final.json`: the matched
  local Brave capture, reference identity and retained rejected control.
- `production-border-isolated-msaa/`: successful signed production build,
  stable source snapshots and `committed-source-validation.json`. All nine
  required committed source hashes match the build inputs. Later unrelated
  image-decode edits in shared files were excluded from this feature commit.
- `candidate-validation-border-isolated-msaa/results.json`: eleven exact
  focused Brave fixtures, successful headless startup, eleven default screenshot
  passes (eight exact and three within existing allowances), ten exact live SVG
  mutation comparisons, and successful archived startup/native input checks.
  Every group retains stable executable and native-library identities.

The executable SHA256 is
`c1d92f0e526723503945bb70de68b7337ad8195a86fa2bee484eed4ccd3511c7`.
The Skia bridge SHA256 is
`45909d7f9f2380c57ac81ddc65f991c99adcca526a88a8fe6f86ef79344efa5f`.

`Build/chatgpt-shadow-modules-20261031/rounded-border-isolated-msaa-20261101-acceptance/`
retains the final original-archive capture, PID, audit, proxy log and complete
pixel diff against the unchanged matched Brave reference. Both stylesheets load,
the frontend reaches its home-ready marker, and native/JavaScript error counts
are zero. The full 1024×768 comparison has 6,797 differing pixels, maximum error
60, MAE 0.0095, 334 pixels above error 3 and seven above 25. Its sampled aggregate
peak RSS is 1,821,261,824 bytes over 21.29 seconds. This is a capture observation,
not a new idle-memory or scrolling-performance measurement.

`rounded-border-isolated-msaa-20261101-editor/` records fresh native AppKit
mouse/keyboard input. The composer retains `Vox`, Enter adds no newline, and
native/JavaScript errors remain zero. The archive still lacks the service
responses needed for an actual chat reply. All captures reuse the original
SOCKS download through non-forwarding local replay. Full-page pixel parity and
a completed conversation remain open.


## CSS superellipse decorations and shared recordings

`813c0e68` transports computed physical/logical `corner-shape` values through
layout decorations and retained paint payloads. The Chromium painter now draws
solid nonnegative superellipse backgrounds, uniform borders and outer shadows.
Inset curves retain their original border geometry. Separate native geometry
checks reproduce Brave's complete spread-shadow and below-round inset paths,
including their float control points and path ordering. Concave native replay,
gradient backgrounds and propagation of custom contours to descendant clips
remain outside this slice.

The captured ChatGPT composer uses `superellipse(1.1)`. Its outer contour and
unfiltered shadow require parent-tile multisampling; ordinary rounded-border
rules remain unchanged. Supported contoured decorations now join root and
compositor picture eligibility. Keeping interacting paints in one picture
preserves their shared coverage before resolving pixels. The native shadow
sequence also retains the opaque source and `SrcIn` color filter used by
[Chromium's DrawLooper](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/cc/paint/draw_looper.cc).
That sequence adjustment alone produced no pixel improvement in its diagnostic.

The new `corner-shape-superellipse` fixture covers `1.1`, `1.25` and `.98`,
padding/content background clips, elliptical corners, three overlapping
shadows and an independent rounded button. Its normal-window Brave reference
is unchanged across two captures. Earlier prototypes differed in 267 pixels,
then 100. A diagnostic shared recording reached zero; the final installed
production bundle also compares **pixel-exact over all 800×600 pixels**.
The reference and comparison regions were not changed to obtain that result.

Evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `contoured-final-binding-results.json` executes five focused binding,
  tile-classification and recording-eligibility cases in Boehm, no-GC and
  preallocated modes. The two style-transport cases also pass in all three
  modes; their original Boehm receipt is in `corner-shape-transport/`, and the
  other modes are in `corner-shape-transport-results.json`.
- `corner-shape-reference-native-sanitizers/` passes all seven sanitizer
  programs, including 27 geometry checks. The final expanded contour test
  passes 24 exact native/GPU cases in
  `native-corner-shape/test-msaa-color-v8-{compile,run}.*`, covering both scales,
  shared recording on/off, both parent-tile modes and three border alphas.
  Failed development prototypes remain retained without acceptance credit.
- `production-corner-shape-shared/` records the successful canonical production
  build: 452.16 seconds, sampled peak RSS 8,839,282,688 bytes, compiler and guard
  exit zero. Eighteen separate compiled feature files match both snapshots and
  the committed sources in `committed-feature-sources.json`. Independent edits
  changed shared files during compilation; no claim is made that the bundle
  validates every later edit in the shared checkout.
- `candidate-validation-corner-shape-shared/results.json` passes all fourteen
  groups with stable executable/native-library identities. Twelve focused
  Brave fixtures and ten SVG mutation guards are exact. The eleven default
  screenshot cases pass with their unchanged bounds: eight exact and three
  existing allowances. Headless startup and archived native input also pass.
  This totals 33 screenshot comparisons, thirty exact.

The accepted executable SHA256 is
`30c8df0398d9da52bd307e321324fad8ee0ef6e9973def12a270a5f8c4b6d045`;
the Skia bridge is
`a2c8091e077d7b6e7c807d7849db597a0a4bc65d264d9a25a954c14ee714290b`.
The retained identity files also pin Graphite, Dawn and the filter snapshot.
Each check launches a fresh process.

The original-archive capture is
`Build/chatgpt-shadow-modules-20261031/corner-shape-shared-20261101-acceptance/`.
Both stylesheets load, home-ready is `1`, and native/JavaScript errors are zero.
It differs from the unchanged Brave reference in **6,594 pixels**, with MAE
0.0066, maximum error 60, eight pixels above error 3, five above 25 and two
above 50. The capture peaks at 1,955,495,936 bytes over 21.29 seconds. The earlier
6,797-pixel capture is retained; these whole-bundle comparisons also include
independent changes and do not isolate one fix's contribution.

`corner-shape-shared-20261101-editor/` verifies native AppKit typing and Enter:
the textarea contains `Vox` without a newline and startup remains error-free.
Its peak RSS is 2,250,014,720 bytes over 23.10 seconds. These are capture/input
observations, not idle-memory or scrolling measurements. The original SOCKS
archive is reused through non-forwarding replay. Full-page pixel equality and
a completed service reply remain open.

## Rounded SVG compositor clips and shadow bounds (2026-11-01)

Commit `541dfe29` makes complete compositor pictures retain rounded ancestor
clips on supported solid SVG fills and simple strokes. Scalar SVG batches keep their rectangular
clip restriction. Balanced CSS scopes with full opacity and normal blending
are eligible when their boundaries share the layer; incomplete scopes, real
effects, masks and unsupported transforms retain their fallback.

The ChatGPT microphone's two filled paths exercise this path. The focused
`compositor-rounded-svg-clip` fixture combines a large SVG fill crossing a
rounded overflow clip with the captured microphone, translucent border and
three composer shadows. Its normal-window Brave reference is unchanged across
two captures. The final production capture matches all 480,000 pixels exactly.

A shadow recording must use the compositor's three-sigma ink extent in document
coordinates, while its fallback bitmap may keep a larger allocation margin.
Using the allocation margin as recording ink extends the picture above its
layer and disables the raster tile that preserves Chromium's coverage phase.
The original fixture had 270 one-level differences. The first installed bounds
fix retained those differences because its extent was calculated after the
paths moved to local coordinates; that failure is retained. The final fix
calculates the extent before moving the paths and is pixel-exact.

Private evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `compositor-rounded-svg-identity-scopes-results.json`: four focused V cases
  pass in Boehm, no-GC and preallocation modes (12 case executions).
- `compositor-clip-bounds-native-sanitizers/`: all seven native programs pass
  AddressSanitizer and UndefinedBehaviorSanitizer. After correcting the bounds'
  coordinate space, `compositor-clip-bounds-final-native/` repeats the affected
  contoured painter's 24 exact GPU cases successfully.
- `production-compositor-clip-bounds/`: the guarded base production build
  succeeds. Other sessions changed unrelated inputs during compilation; the
  feature's V files remain identical before and after. The initial installed
  native bounds failure is retained in
  `candidate-validation-compositor-clip-bounds/`.
- `production-compositor-native-bounds-final/`: rebuilds and installs only the
  corrected native painting library under the shared production lock, then
  re-signs and verifies the assembled bundle. All native source inputs remain
  stable. Re-signing changes the executable hash as well as the library hash;
  the final identities are recorded in `identity-after.json`.
- `candidate-validation-compositor-clip-bounds-final/results.json`: final
  focused pixels, headless startup, the original archived application and
  native input checks. All 15 groups pass with one unchanged final bundle
  identity. The 34 screenshot comparisons include 13 exact focused fixtures,
  the default 11 smoke cases (eight exact, three within existing bounds), and
  ten exact SVG mutation guards. No reference or tolerance was changed.

The accepted archived capture is
`Build/chatgpt-shadow-modules-20261031/compositor-clip-bounds-final-20261101-acceptance/`.
It preserves the original archived document and the existing 1024×768 Brave
reference, with scale 1, an active document and the cookie banner visible.
The private HTTPS SOCKS replay never forwards missing responses. A 60-second
settle is followed by checks for the home-ready marker, both stylesheets,
complete readiness, document activity and zero reported native JavaScript
errors. The guard records a successful exit and a 1,947,320,320-byte peak.
This is a readiness/rendering check, not a startup-speed measurement.

The result is **876 of 786,432 differing pixels (0.1114%, MAE 0.0008688)**,
with maximum channel error 18. Two pixels exceed 3 and 10; none exceed 25.
The remaining differences include the heading, footer, cookie-banner edges
and two caret-end pixels. The separately injected aliasing and clipping caret
experiments do not fix those two pixels and supply no acceptance credit.

`compositor-clip-bounds-final-20261101-editor/` checks native AppKit mouse and
keyboard input after startup. Typing `Vox` followed by Enter leaves `Vox` in the
focused textarea without a newline, with the home-ready marker present and no
reported JavaScript errors. The archive does not contain a successful chat
response, so a completed conversation and pixel-exact full-page parity remain
unverified.
