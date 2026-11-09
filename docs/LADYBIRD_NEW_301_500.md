# Ladybird newly imported tests 301–500

This batch continues the [first 100](LADYBIRD_NEW_FIRST_100.md) and
[next 200](LADYBIRD_NEW_NEXT_200.md). The
[fixed 200 case IDs](../Tests/Browser/ladybird-new-301-500-20261109.txt) are discovery
positions 301–500 newly imported since Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`, from fetched revision
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. They do not overlap the earlier 300.
The upstream checkout is unchanged; fixtures are exported to an immutable cache.

**Acceptance remains incomplete: the latest complete native run passes 99/200
pages and 3,189/6,175 assertions.** The available production baseline passes
23/200 pages and predates the fixes; it cannot validate the new code.

## Complete native run

The r12 run uses a fresh native browser navigation, DOM, CSS, layout, JavaScriptCore,
HTML event loop and profile for every page, with an 800×600 viewport. It does not
create a GUI window or validate painting. Its scheduler publishes real frame
timestamps so document timelines advance. All 200 pages report: 199 harnesses are
OK and one is ERROR. Failed assertions and aborted registration remain failures.
No upstream assertions, expected values or selection filters are weakened.

| Group | Pages | Fully passing | Passing assertions |
|---|---:|---:|---:|
| css-anchor-position | 11 | 11 | 330/330 |
| css-animations | 10 | 10 | 275/275 |
| css-backgrounds | 2 | 1 | 53/55 |
| css-borders | 4 | 2 | 13/47 |
| css-box | 1 | 1 | 8/8 |
| css-break | 2 | 1 | 8/28 |
| css-cascade | 1 | 0 | 1/4 |
| css-color | 6 | 2 | 671/1423 |
| css-color-adjust | 1 | 0 | 0/42 |
| css-conditional | 57 | 44 | 274/344 |
| css-contain | 2 | 0 | 0/13 |
| css-display | 1 | 0 | 111/112 |
| css-flexbox | 6 | 0 | 8/19 |
| css-fonts | 14 | 4 | 681/2353 |
| css-grid | 82 | 23 | 756/1122 |
| Total | 200 | 99 | 3189/6175 |

Executable SHA-256: `5c99c6d96b639dedde7bafaa36bac1be96f2f9b07a409683bb071fb130238d58`.
The controller verifies the executable, controller, server tools and immutable
fixture tree before and after the cohort; all pins remain unchanged. Upstream
wptserve supplies the original HTML/support files, substitutions and handlers.
The existing harness timeout normalization and collecting reporter preserve
assertions. Every process has a 2 GiB memory guard; the 3 GiB aggregate guard
observes 385,777,664 bytes peak RSS over 133.17 seconds. Runner and guard exit 1
because strict acceptance has not been reached.

## Evidence and validation

The fixture cache is
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
The exact selected objects are in
`~/.cache/vox/wpt/batch301-500-20261109/selection.json`.
Earlier completed attempts and their memory receipts are retained under
`~/.cache/vox/wpt/batch301-500-20261109/evidence-20261109-0710/`.
The current r12 cohort is temporarily in `Build/batch301-500-native-r12-full/`;
it will be archived with the completed work. Earlier attempts are independent
measurements and are not added to this run's passing totals.

The fixed production baseline can be reproduced under the memory supervisor with:

```sh
python3 tools/wpt_compare.py --output Build/UNIQUE \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
  --offset 300 --limit 200 --browsers vox --chunk-size 10 \
  --browser-memory-gib 2 --require-all-pass \
  --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

The baseline production executable is SHA-256
`23d3335dede25e37f908b5e4f17a0694aacf1bf314fbd453c9892eaab9b71688`.
Focused native regression tests cover each committed fix. Required Volt checks
have also run: `make app` succeeds; the direct `v -memory-limit 10G
-enable-globals -o volt .` build fails at its compiler memory limit. The memory
limit is preserved. Further engine fixes and full-cohort validation are ongoing.
