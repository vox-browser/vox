# Ladybird newly imported tests 301–500

This batch continues the [first 100](LADYBIRD_NEW_FIRST_100.md) and
[next 200](LADYBIRD_NEW_NEXT_200.md). The
[fixed 200 case IDs](../Tests/Browser/ladybird-new-301-500-20261109.txt) are discovery
positions 301–500 newly imported since Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`, from fetched revision
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. They do not overlap the earlier 300.
The upstream checkout is unchanged; fixtures are exported to an immutable cache.

**Strict acceptance remains incomplete: 197/200 pages and
6,182/6,188 assertions pass.** Six assertions in three pages remain failures.
All counts below come from one executable and the complete cohort; passing
cases from different runs are not combined.

## Complete native run

The r41 run uses fresh native browser navigation, DOM, CSS, layout,
JavaScriptCore, HTML event loop and a separate profile for every page, with an
800×600 viewport. It does not create a GUI window or validate painting. Its
scheduler publishes frame timestamps so document timelines advance. All 200
harnesses report OK. Failed assertions remain failures. No upstream assertions,
expected values or selection filters are weakened.

| Group | Pages | Fully passing | Passing assertions |
|---|---:|---:|---:|
| css-anchor-position | 11 | 11 | 330/330 |
| css-animations | 10 | 10 | 275/275 |
| css-backgrounds | 2 | 2 | 55/55 |
| css-borders | 4 | 4 | 47/47 |
| css-box | 1 | 1 | 8/8 |
| css-break | 2 | 2 | 40/40 |
| css-cascade | 1 | 1 | 4/4 |
| css-color | 6 | 5 | 1421/1423 |
| css-color-adjust | 1 | 1 | 42/42 |
| css-conditional | 57 | 56 | 341/344 |
| css-contain | 2 | 2 | 13/13 |
| css-display | 1 | 1 | 112/112 |
| css-flexbox | 6 | 6 | 19/19 |
| css-fonts | 14 | 13 | 2353/2354 |
| css-grid | 82 | 82 | 1122/1122 |
| Total | 200 | 197 | 6182/6188 |

Executable SHA-256: `e77c61dba584da41dffc190564de86d7afaa3691694798aff89b7bd1f1020c19`.
The controller verifies the executable, controller, server tools and immutable
fixture tree before and after the cohort; all pins remain unchanged. Upstream
wptserve supplies the original HTML/support files, substitutions and handlers.
The existing harness timeout normalization and collecting reporter preserve
assertions. Every page process has a 2 GiB / 80 second guard. The 3 GiB aggregate
guard completed cleanly, observing 421,429,248 bytes peak RSS over
120.80 seconds. Runner and guard exit 1 because strict acceptance has
not been reached.

Earlier runs registered 6,176 assertions. Fixing inline fragment client rectangles
and rounded hit testing lets that page finish registration and execution of 12
more original assertions, bringing the total to 6,188.

## Remaining pages

| Fixed case ID | Passing assertions |
|---|---:|
| `css/css-color/parsing/color-computed-powerless` | 568/570 |
| `css/css-conditional/container-queries/scroll-state/scroll-state-query-with-var` | 3/6 |
| `css/css-fonts/animations/font-palette-animation-not-specified-endpoints` | 1/2 |

Two negative-lightness round-trip assertions in `color-computed-powerless`
remain inconsistent with parsed-value clamping in
[CSS Color 4](https://drafts.csswg.org/css-color-4/#specifying-lab-lch) and
[its OKLab rules](https://drafts.csswg.org/css-color-4/#specifying-oklab-oklch).
This is an inference from the specification: the first computed conversion
produces a negative lightness, but parsing that serialized value clamps it to
zero. The selected test expects both values to remain negative. The pinned
Ladybird expected output records the same two failures.

Three assertions in `scroll-state-query-with-var` expect bare
`@container (scrollable: ...)` conditions to match. The
[container query grammar](https://drafts.csswg.org/css-conditional-5/#container-rule)
requires scroll features inside `scroll-state(...)`. The pinned Ladybird output
records the same three failures. Vox's parser and the fixtures have not been
changed to accept the bare features.

The implicit `font-palette` endpoint has a compatibility disagreement. The page
sets the underlying inline style to `font-palette: --custom`, supplies only a
`from` keyframe with that same value, but expects `normal` after the animation.
Vox and pinned Ladybird preserve `--custom`; the focused Brave 157.1.99.55
control passes the expected `normal` endpoint. The
[Web Animations endpoint algorithm](https://drafts.csswg.org/web-animations-1/#the-effect-value-of-a-keyframe-effect)
uses the underlying value for a missing endpoint. This suggests an upstream
expectation problem, but the browser disagreement remains unresolved. It is
still counted as a failure.

## Implemented fixes and checks

The completed engine changes cover CSS parsing/computation and animation,
container-query eligibility and dependencies, accessibility roles, SVG geometry,
logical grid/flex axes and baselines, table client dimensions, sticky offsets,
cascade layers, line clamping and vertical atomic columns.

The last fixes add physical inline fragment client rectangles and rounded hit
regions, preserve clamping through nested vertical blocks, resolve cyclic
percentage rows without feeding them back into intrinsic container height,
remeasure orthogonal grid contributions after row sizing, and use directional
middle-image and central baselines. Anonymous table wrappers retain their
separate sizing path. Unpositioned grid children retain their aligned absolute
static positions. Legacy SVG region queries use native Bezier boundaries and
stroke outlines, including transform and static NodeList regressions.

Focused native regressions pass for these changes, including the full cohort's
baseline and orthogonal table cases. Native path-region tests cover holes,
curve extrema and stroke outlines. The border-shape slice validates typed
values and line-based shape() geometry; it does not establish painting support.

Required Volt checks through r29 ran after the final fixes: `make app` succeeds.
The direct `v -memory-limit 10G -enable-globals -o volt .` build fails at its
configured 10 GiB compiler physical-footprint limit. The limit remains enabled.

## Evidence

Fixtures are in
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
Exact selected objects are in
`~/.cache/vox/wpt/batch301-500-20261109/selection.json`.
The final r41 cohort, controller, per-page guards, compile receipt, executable
and final Volt checks are archived under `/Users/alex/.cache/vox/wpt/batch301-500-20261109/evidence-20261109-final-r41/`.
Its executable is in `completed-core/`. Earlier completed attempts and focused
checks remain in sibling evidence directories, including
`evidence-20261109-114903/`. No incomplete run is used for the final counts.

## Production browser

The latest completed shared production executable checked is SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`.
Its request head is `45375fcc55f6e885c9d4218fa926af1ccea1bf8d`. It predates the final
fixes and cannot validate code it does not contain. These counts come from the
fresh native r41 executable above. Implementation commits request coalesced
managed production rebuilds; no duplicate production build is queued manually.
Full validation of the latest code in the production GUI bundle remains pending.

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

All 200 passing remains blocked by the six visible assertions above; this report
does not mark the batch accepted.
