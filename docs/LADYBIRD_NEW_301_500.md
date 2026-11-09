# Ladybird newly imported tests 301–500

This batch continues the [first 100](LADYBIRD_NEW_FIRST_100.md) and
[next 200](LADYBIRD_NEW_NEXT_200.md). The
[fixed 200 case IDs](../Tests/Browser/ladybird-new-301-500-20261109.txt) are discovery
positions 301–500 newly imported since Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`, from fetched revision
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. They do not overlap the earlier 300.
The upstream checkout is unchanged; fixtures are exported to an immutable cache.

**Acceptance remains incomplete: the latest complete native run passes
185/200 pages and 6,105/6,176 assertions.**
All counts below come from that single executable and complete cohort. Earlier
runs are independent measurements and their passing cases are not combined.

## Complete native run

The r36 run uses a fresh native browser navigation, DOM, CSS, layout,
JavaScriptCore, HTML event loop and profile for every page, with an 800×600
viewport. It does not create a GUI window or validate painting. Its scheduler
publishes real frame timestamps so document timelines advance. All 200 pages
report: 199 harnesses are OK and one is ERROR. Failed assertions and aborted
registration remain failures. No upstream assertions, expected values or
selection filters are weakened.

| Group | Pages | Fully passing | Passing assertions |
|---|---:|---:|---:|
| css-anchor-position | 11 | 11 | 330/330 |
| css-animations | 10 | 10 | 275/275 |
| css-backgrounds | 2 | 2 | 55/55 |
| css-borders | 4 | 4 | 47/47 |
| css-box | 1 | 1 | 8/8 |
| css-break | 2 | 1 | 8/28 |
| css-cascade | 1 | 1 | 4/4 |
| css-color | 6 | 5 | 1421/1423 |
| css-color-adjust | 1 | 1 | 42/42 |
| css-conditional | 57 | 56 | 341/344 |
| css-contain | 2 | 1 | 9/13 |
| css-display | 1 | 1 | 112/112 |
| css-flexbox | 6 | 6 | 19/19 |
| css-fonts | 14 | 13 | 2353/2354 |
| css-grid | 82 | 72 | 1081/1122 |
| Total | 200 | 185 | 6105/6176 |

Executable SHA-256: `1068aa09b9736c900b08641b59b4f7877af73a8816149a88a1725eef669d2035`.
The controller verifies the executable, controller, server tools and immutable
fixture tree before and after the cohort; all pins remain unchanged. Upstream
wptserve supplies the original HTML/support files, substitutions and handlers.
The existing harness timeout normalization and collecting reporter preserve
assertions. Every process has a 2 GiB / 80 second guard. The 3 GiB aggregate
guard completed cleanly, observing 411,303,936 bytes peak RSS over
140.13 seconds. Runner and guard exit 1 because strict acceptance has
not been reached.

## Remaining pages

| Fixed case ID | Passing assertions |
|---|---:|
| `css/css-break/hit-test-inline-fragmentation-with-border-radius` | 4/24 |
| `css/css-color/parsing/color-computed-powerless` | 568/570 |
| `css/css-conditional/container-queries/scroll-state/scroll-state-query-with-var` | 3/6 |
| `css/css-contain/content-visibility/content-visibility-svg-path` | 5/9 |
| `css/css-fonts/animations/font-palette-animation-not-specified-endpoints` | 1/2 |
| `css/css-grid/abspos/absolute-positioning-grid-container-containing-block-001` | 7/10 |
| `css/css-grid/alignment/grid-align-baseline-line-clamp-001.tentative` | 25/26 |
| `css/css-grid/alignment/grid-align-baseline-line-clamp-002.tentative` | 19/24 |
| `css/css-grid/alignment/grid-align-baseline-line-clamp-003.tentative` | 22/24 |
| `css/css-grid/alignment/grid-align-baseline-vertical-mixed` | 10/11 |
| `css/css-grid/alignment/grid-align-baseline-vertical` | 6/11 |
| `css/css-grid/alignment/grid-container-baseline-001` | 3/11 |
| `css/css-grid/alignment/grid-content-alignment-second-pass-001` | 2/8 |
| `css/css-grid/alignment/grid-content-alignment-second-pass-002` | 0/8 |
| `css/css-grid/alignment/grid-item-aspect-ratio-justify-self-001` | 18/20 |

Two negative-lightness round-trip assertions in `color-computed-powerless`
remain inconsistent with parsed-value clamping in
[CSS Color 4](https://drafts.csswg.org/css-color-4/#specifying-lab-lch) and
[its OKLab rules](https://drafts.csswg.org/css-color-4/#specifying-oklab-oklch).
This is an inference from the specification: the first computed conversion
produces a negative lightness, but parsing that serialized value clamps it to
zero. The selected test expects both values to remain negative. The pinned
Ladybird expected output also records these two failures.

Three assertions in `scroll-state-query-with-var` expect bare
`@container (scrollable: ...)` conditions to match. The current
[container query grammar](https://drafts.csswg.org/css-conditional-5/#container-rule)
requires scroll features inside `scroll-state(...)`. The pinned Ladybird output
also records these failures. These expectations remain visible failures; Vox's
parser and the fixtures have not been changed to special-case them.

The implicit `font-palette` endpoint has a compatibility disagreement: Vox and
pinned Ladybird preserve the underlying `--custom` palette, while the focused
Brave 157.1.99.55 control passes the test's expected `normal` endpoint. That case
still needs resolution. Other remaining cases require engine fixes.

## Evidence and validation

The fixture cache is
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
The exact selected objects are in
`~/.cache/vox/wpt/batch301-500-20261109/selection.json`.
The r36 cohort, controller pins, per-page memory receipts and compile receipt
are archived under `/Users/alex/.cache/vox/wpt/batch301-500-20261109/evidence-20261109-105828/`. Its executable is in `completed-core/`.
Earlier completed attempts are retained in sibling evidence directories.
The r34 cohort reported all pages but its outer guard found remaining children;
r35 and r36 subsequently completed with clean guard teardown.

The completed fixes include CSS parsing/computation and animation work,
container-query eligibility and dependencies, accessibility roles, SVG geometry,
logical grid/flex axes and baselines, table client dimensions, sticky offset
geometry, cascade layer precedence, clamped content and vertical atomic columns.
The current border-shape slice validates typed values and line-based shape()
geometry; it does not establish border-shape painting support.
Focused native regressions accompany the implementation commits. Required Volt
checks through r23 also ran: `make app` succeeds; the direct
`v -memory-limit 10G -enable-globals -o volt .` build fails at its compiler memory
limit. The memory limit is preserved.

## Production browser

The latest completed shared production executable checked is SHA-256
`f14f71f6be464c11fa14ade78d458c28ef4a837524bc004ec9d1f9cdba1d7c53`.
Its receipt requests head `ec1ffcd4a6f9024c02309b626d1654d70ac0fd35` and
predates the recent fixes, so it cannot validate their code. Implementation
commits request coalesced managed production rebuilds; no duplicate build is
queued manually.

The initial fixed production baseline passed 23/200 pages. It can be reproduced
under the memory supervisor with:

```sh
python3 tools/wpt_compare.py --output Build/UNIQUE \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
  --offset 300 --limit 200 --browsers vox --chunk-size 10 \
  --browser-memory-gib 2 --require-all-pass \
  --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

Further engine fixes and full-cohort validation remain in progress.
