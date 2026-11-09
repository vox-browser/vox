# Ladybird import: cases 701–800

## Scope and acceptance

This is a fixed cohort of 100 distinct cases from Ladybird's imported WPT
testharness tests. It is **not yet fully passing**. These cohort results do not
establish an overall WPT pass rate or a comparison with another browser.

The [catalog](../Tests/Browser/ladybird-new-701-800-20261109.txt) contains the next
100 additions after the earlier 700, selected with offset 700 and limit 100
between these immutable Ladybird revisions:

- Baseline: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
- Imported revision: `2919bf87a5e5dfc49a210a70bda079afa411c6c5`.
- Selection JSON SHA-256: `a53999dfcecf747449c214b4f4bb2ed629437e50ee5e191822ced1de0805e62e`.
- Catalog SHA-256: `46995c7cf5449b2646c8f2f0c107aa11980258658980622d45b2925fbb32cecf`.

There are 27 properties-and-values cases, 18 pseudo-element cases, one shadow
case, two shapes cases, and 52 sizing cases. Their Ladybird expectations contain
**5,356 assertions**. Fixtures, support resources, assertions and deadlines are
unchanged. The original expectation names are compared as a multiset, including
multiline names; missing assertions fail acceptance.

`tools/ladybird_native_cohort.py` exports and verifies the pinned fixtures and
runs a fresh `compact/upstream_testharness_test.v` process for every page. A case
passes only with a successful guarded process exit, a clean harness, every
expected assertion reported, and every reported assertion passing. The runner's
five Python unit tests pass.

The native entry point exercises document navigation, parsing, resources,
JavaScriptCore, DOM, CSS and layout. It does not validate window painting.
Runtime jobs have a 3 GiB outer guard and a 2 GiB per-page guard. Compiler jobs
retain the default 12 GiB guard and V's `-memory-limit 10G`.

## Complete native runs

| Image | Passing pages | Passing / reported assertions | Missing expected assertions |
| --- | ---: | ---: | ---: |
| Prior r41 baseline | 16 / 100 | 3,544 / 5,032 | 324 |
| r1 | 33 / 100 | 3,689 / 5,032 | 324 |
| r2 | 40 / 100 | 4,314 / 5,032 | 324 |
| r3, optimized prepared runtime | 48 / 100 | 4,387 / 5,032 | 324 |
| r6, optimized prepared runtime | 59 / 100 | 4,803 / 5,356 | 0 |
| r7, optimized prepared runtime | 69 / 100 | 4,984 / 5,356 | 0 |
| r8, optimized prepared runtime | 76 / 100 | 5,114 / 5,356 | 0 |
| r9, optimized prepared runtime | 87 / 100 | 5,329 / 5,356 | 0 |
| r10, optimized prepared runtime | 93 / 100 | 5,340 / 5,356 | 0 |
| r11, optimized prepared runtime | 95 / 100 | 5,349 / 5,356 | 0 |
| r12, optimized prepared runtime | 96 / 100 | 5,351 / 5,356 | 0 |
| r13, optimized prepared runtime | **97 / 100** | **5,353 / 5,356** | **0** |

The missing assertions came from the Typed OM page terminating during setup.
The r6–r13 images report and pass all **325/325** of that page's assertions.
Registered-property computation passes **75/75**, and URL resolution passes
**18/18**, including the UTF-16 stylesheet. Every r13 page completes inside its
unchanged harness deadline, with harness status 0 and unchanged pinned runtime
inputs. The r13 cohort guard exits 1 because assertions remain failing; its
compiler guard exits 0. Both containment pages now pass: 48/48 and 42/42;
path interpolation passes 478/478. First-line property filtering and the nested
highlight-inheritance page also pass completely.

The r4 run was interrupted after 49 pages and has no terminal cohort receipt.
It is retained as partial evidence, without an aggregate pass-rate claim. The
r5 focused run reports 448/464 assertions across four pages, with three pages
passing; it predates the final stylesheet-base and linked-sheet decoding fixes.

The r13 executable SHA-256 is
`f2bf011a660391394a0d6e51b83299ce4de40d4d7b385c639d0158d1b9fb6802`.
Intermediate images are r12
`516b4fd17689e788f9ac155097aba122e9523eab0c214c3fe7f99fd36e8703b1`,
r11 `ae8e8be3028984b29b160c8aa889959dfd5e51f60fa8a308f83776a856b118a3`,
r10 `65fda36dd92f954f9162157a30503045a180b54bb754d7901979481641f0aaea`,
and r9 `c6fdeb796e85d4ed3f058277437481372421e41ace1289a582765d14abb8cffc`.
The earlier r8 image is
`fc130e706333ca73ea1382b23182136ffb2085c45e8e8c20cc70b1cf5890fc60`.
The earlier r7 image is
`1f2a1a53d81325c26f70faf637ecfab601f83cc53e2587d9c13511122cb3deae`;
r6 is `9f754b9de64698545774c1e984fdc58b9124ae441d4e1c57597ee0d75d3bcec7`.
It uses C, literal `-prod`, one C unit, and the prepared prealloc runtime with
`-gc none`. Its compiler SHA-256 is
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
Compiler-consumed source manifests distinguish each image from later shared
checkout edits. Concurrent sessions have contributed other engine changes;
the table describes the pinned images, rather than attributing every gain to
one patch.

Regressions remain visible: `stretch-block-size-003` falls from 36/36 in r3 to
28/36 in r6, then returns to **36/36 in r8**. `flex-line-003` falls from
3/4 to 1/4, then passes 4/4 in r9. `flex-line-004` regresses from 3/4
in r8 to 2/4 in r9, then returns to **4/4 in r12** after the intrinsic-column
measurement fix. The r11 automatic flex-height change introduces two failures
in `stretch-block-size-001`; resolving its stretch maximum against its actual
containing block restores **18/18 in r13**. All attempts are retained.

## Implemented slices and follow-up

The import includes focused implementation and regression-test commits for:

- Stretch parsing, available margin-box sizing, absolute static positions and
  final flex-line sizing.
- Enumeration and computation of registered custom properties, including
  canonical calculations and initial values.
- Mutable inline and rule Typed OM maps, computed maps, typed reification,
  iteration and rejected writes.
- Document and stylesheet URL bases, nested registered references, deferred
  custom declarations, and UTF-16 stylesheet decoding.
- Highlight pseudo types, selector suffix validation, native target mappings,
  boxless color resolution and highlight inheritance.
- Fractional aspect-ratio precision, premultiplied color composition,
  compatible path interpolation, and nonnegative contain-intrinsic interpolation.

The r8 image measures the preceding highlight, color, path and containment
fixes. Later committed fixes cover final flex-line constraints, simulated parent
margin collapse, intrinsic flex bases and float/list-marker contributions,
authored replaced-element ratios, intrinsic constraints across axes, and
suppressed generated content on replaced controls. The r9 run measures these
fixes, including 180/180 replaced-ratio assertions and 24/24 control-pseudo
assertions. Later grid, outer-scope shadow-part, details-content, indefinite
flex, intrinsic float, clearance and anonymous-containing-block fixes have
passing focused checks and are measured by r10–r13. The final flex-height
follow-up passes all nine focused test functions and restores both introduced
regressions in the original cohort.

The target remains all 100 pages and all original expected assertions passing
together. The **three remaining r13 failures** are also marked `Fail` in the
pinned Ladybird expectations: the two mixed length/percentage iteration cases
and shadow-part first-line rendering. Those upstream expectations contain 102
recorded failures overall; Vox passes 99 of them in r13. Expected upstream
failures are still failures in this cohort. The first-line case is a real
rendering implementation gap; its expected height is 106px and r13 produces
40px.

## Mixed length/percentage accumulation diagnostic

The comma-list and space-list pages each retain one failing iteration-accumulation
assertion. Their original expectation contains `calc(25% + 50px)`; Vox produces
`calc(25% + 250px)`. Applying two copies of the 100px final keyframe before
interpolating the interval endpoints appears to require the latter result under
the [Web Animations iteration-composition procedure](https://drafts.csswg.org/web-animations-2/#iteration-composition)
and [CSS numeric accumulation](https://drafts.csswg.org/css-values-4/#combining-values).
This is a suspected expectation inconsistency, not a passing result.

A separate fresh-process diagnostic on the same two unchanged imported pages
in installed **Brave 157.1.99.55** also reports 10/12 assertions, with both
iteration cases failing. Brave produces `50%` in the first list item where
the test expects `250%`, and retains the expected 50px component in the second
item; its output differs from Vox. Its executable SHA-256 is
`4772b8898cc23f044c134b75a494ddc9053f58d5ea8cd1acb6f60762292df513`.
Harnesses complete normally, inputs remain unchanged, and the guarded process
exits 1 because `--require-all-pass` rejects the two failures. This focused
static-server diagnostic establishes neither full WPT parity nor a browser
percentage comparison. All original expectations remain unchanged.

## Painting regression evidence

All 11 original SVG source-switch and paint-server mutation reftests pass with
zero differing pixels at 800×600. Captures use fresh native processes on the
test display, unchanged references and zero tolerances. The production image
contains the exact Typed OM/computed-style bridge sources being checked:

- Receipt: `20261109-155153-906097e7`.
- Executable SHA-256: `b794166cf036ebdeca48b7c69b27fe4e5a7a7158076bd8d531a8a728aac742e9`.
- Pixel guard: completed, browser/capture/diff/guard exits 0.

This painting result is separate from the native cohort and does not validate
later highlight or path changes absent from that production image. The three
original selection reftests remain pending on a matching completed production
image. Recent automatic builds (receipts `20261109-171656-fd6c144a` and
`20261109-172639-3b3bad04`) failed input verification because the shared
`tools/raster_tests.json` changed during compilation. No manual duplicate
production build was queued.

## Local evidence and reproduction

Raw results, all failed attempts, logs, selection receipts, compiler source
manifests and the pixel observer receipt remain local under
`/Users/alex/.cache/vox/wpt/batch701-800-20261109` including `completed-evidence/`; active
`Build/batch701-800-*` job directories retain only ongoing jobs. Completed
artifacts are relocated there with their receipts and compiler-consumed source
hashes, and their temporary generated C is removed. Generated measurement JSON and archives
are not committed.

After compiling the native entry point under the required guard, run:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-701-800-UNIQUE.lock \
  --report Build/ladybird-701-800-UNIQUE-guard.json -- \
  python3 tools/ladybird_native_cohort.py \
  --catalog Tests/Browser/ladybird-new-701-800-20261109.txt \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --native /Users/alex/.cache/vox/wpt/batch701-800-20261109/completed-evidence/round3/core/native-r13-prod \
  --output Build/ladybird-701-800-UNIQUE
```
