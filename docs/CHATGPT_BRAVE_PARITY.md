# ChatGPT rendering and startup against Brave

ChatGPT support and pixel-exact parity are **not complete**. The changes below
fix specific failures reproduced on the logged-out homepage. They do not make
ChatGPT's module-based application executable, or establish that chatting works.

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
  `ui-sans-serif` and recognizes the later `-apple-system` family alias.
  Brave's platform-font probe identifies `.SF NS` for the homepage heading.
  A standalone unavailable UI family still falls through to the author's
  ordinary sans-serif fallback. The LibWeb fixture policy is preserved.
- `3ee2380c`: Compact elements implement `toggleAttribute()`, including
  optional/undefined force values, validation, preserved existing values and
  the ordinary attribute mutation path. HTML names use ASCII lowercasing;
  non-ASCII names and SVG attribute case remain intact.

The initial `bde4c36a` mapping selected system UI directly for `ui-sans-serif`.
The unchanged Brave reference rejected it with 9,347 differing pixels.
`dd340a2a` corrects that assumption rather than changing the reference or
relaxing the comparison. The failed test and platform-font probes are retained.

The focused V tests execute twelve cases in each of Boehm and no-GC modes,
24 executions total. Compilations use the 12 GiB guard and a 10G V compiler
limit; test binaries execute under separate 3 GiB guards. Receipts are in
`focused-test-results.json`. The first attempt to compile the CSS tests under
a 3 GiB aggregate guard was stopped; it receives no test credit.

The reduced `inactive-scroll-sidebar` native comparison passes with zero
differing pixels. Both font comparisons also pass with zero differing pixels,
using the original `ui-sans-system-font` reference and the added
`apple-system-font-stack` reference.

## Final native validation

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

The JavaScript backend explicitly rejects module execution in
`browserjs/runtime.v`. ChatGPT's entry point uses `type="module"` and an import
map, so constructor and collection fixes alone cannot start the application.
Original-script replay is diagnostic, not an interaction or conversation test.
The completed replay with the additional polyfill still reports an absent
`ShadowRoot` interface as well as module rejection. The previous constructor,
`NodeList.item()` and `toggleAttribute()` startup errors no longer occur.
Complete original-script startup checks use the default 12 GiB aggregate
browser budget, separately from the 3 GiB focused unit tests. The first nested
3 GiB startup attempt failed during guard cleanup and receives no validation
credit. A later 12 GiB run completed at 3,047,276,544 sampled bytes, exposing
the missing `toggleAttribute()` call and the uncaptured fallback script;
those diagnostics motivated the follow-up work above.

Vox also deliberately hides matching cookie banners by default through
`cookie_blocker.v`. This adds `display: none !important` to ChatGPT's consent
dialog, while the captured Brave homepage displays it. This is an existing
browser policy difference, not a missing dialog layout box. Full-page parity
cannot be claimed while those consent states differ.

No screenshot tolerance or reference region is relaxed for ChatGPT. Startup
failures, incomplete captures, changed executable identities and memory-guard
failures do not count as successful validation.

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
