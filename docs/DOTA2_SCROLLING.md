# Dota2 comment-page scrolling

Scrolling [the reported old Reddit comment page](https://old.reddit.com/r/DotA2/comments/1x78he9/was_it_worth_it_no_i_am_happy_no/)
spent most of its frame time in native paint replay. Small opacity groups used
their ancestor's large clip, making transparency compositing and the Chromium
renderer's opacity-ink scans process viewport-sized regions, even for controls
below the viewport.

`fb37e5d5` bounds eligible opacity groups by the union of their transformed
painted contents. Text uses retained glyph ink, strokes retain their extent,
and bitmap backgrounds retain a source-space snapping fringe. Background
gradients use their paint clip rather than their positioning area. Nested
groups and viewport scrolling preserve those bounds. Filters, shadows,
unsupported operations and non-normal blending retain their original bounds.
The pass changes the published replay commands without modifying retained
layer payloads, leaf commands, layout or hit-test plans.

Three alternating pairs of 120 wheel events on the retained page produced
these medians of run medians:

| Per moving frame | Control | Bounds enabled | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 79.437 ms | 64.883 ms | 18.3% |
| Native replay | 76.882 ms | 62.511 ms | 18.7% |
| Retired instructions | 487.221 million | 351.554 million | 27.8% |

Every run uses the same 1024×768 viewport, initial resource cache and native
rendering libraries. All 120 events move the viewport, tracing 0–1260 CSS
pixels and back, with the same 2,355 paint commands. The comparison enforces
identical scroll positions and command counts. Slow frames and collections
remain in the results. The machine was running other compilation jobs, so
these wall times describe this workload under that load.

The control is a separately signed copy of the same production executable
whose content-bounds function returns immediately. Mach-O section comparison
confirms that only its first four instruction bytes differ; every other
file-backed section is identical. The installed executable runs the full pass.
The saved HTML retains the page's 85 comments and original base URL; its 20
scripts are removed to keep DOM content stable. JavaScriptCore remains enabled,
and the process-local network guard prevents remote fetches. These timings
cover native wheel dispatch, preparation and replay, including synchronous
renderer waits. Cocoa presentation, display-clock waits and post-frame idle
maintenance are outside the measured scope.

Four matched document viewports are pixel-exact: the top and a scrolled
position at 1×, and two scrolled positions at 2×. Seven focused content-bound
tests are included in the 210 selected test functions passing in each of the
default-GC and no-GC configurations: 10 layout, 13 painting and 26 platform
test files. The aggregate source manifest and retained recovery logs distinguish
successful checks from the initial harness failures. All 100 upstream LibJS
AST fixtures and 15 native Skia pixel scenes pass. Signed production startup
also passes.

The 11 default screenshot comparisons pass with their existing rules: eight
are exact and three use the existing allowances. All eight SVG mutation guards
are exact, as is the public Brave opacity-group fixture. Of seven additional
opacity reftests, four are exact and the rotated SVG case passes its existing
one-channel allowance. Two retain existing upstream-reference mismatches:
`scrollable-contains-boxes-with-hidden-overflow-and-opacity` (1,186 pixels) and
`abspos-escaping-overflow-clip-inside-opacity` (10,000 pixels). Both their input
and reference viewports are pixel-identical between the matched control and
changed browser.
The multiline match link in the live opacity-change fixture was followed
directly after the shell comparison script could not parse it; that comparison
is exact. No comparison limits were changed.

The measured saving is 135,667,014.5 instructions per moving frame, exceeding
the repository's 5,000,000-instruction broad-check threshold for this endpoint.
This is one scrolling fix; no other renderer change receives credit from the
matched comparison. That broad verification covers this fix; additional
instruction savings after this checkpoint are zero for this endpoint.

Evidence is retained in the private, ignored `Build/dota2-scroll/` directory:
`final-comparison.json`, `final-{before,after}-{1,2,3}/`,
`final-control-sections.json`, `final-pixels/`, `regression-composite.json`,
`regression/manifest.json`, and the build/startup logs. The interrupted build
was recovered using its unchanged generated C and original production compiler
response file; `build-final-recovery.json` records their hashes and exit zero.
Unrelated working-tree edits were preserved.

To profile the live page with the installed browser:

```sh
python3 tools/measure_browser_scroll.py \
  --url https://old.reddit.com/r/DotA2/comments/1x78he9/was_it_worth_it_no_i_am_happy_no/ \
  --env VOX_TEST_WINDOW=1 --frames 120 \
  --output Build/dota2-scroll-new-run
```
