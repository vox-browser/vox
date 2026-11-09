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
| r6, optimized prepared runtime | **59 / 100** | **4,803 / 5,356** | **0** |

The missing assertions came from the Typed OM page terminating during setup.
The r6 image reports and passes all **325/325** of that page's assertions.
Registered-property computation passes **75/75**, and URL resolution passes
**18/18**, including the UTF-16 stylesheet. Every r6 page completes inside its
unchanged harness deadline, and all pinned runtime inputs remain unchanged.
The r6 cohort guard exits 1 because assertions remain failing; its compiler
guard exits 0.

The r4 run was interrupted after 49 pages and has no terminal cohort receipt.
It is retained as partial evidence, without an aggregate pass-rate claim. The
r5 focused run reports 448/464 assertions across four pages, with three pages
passing; it predates the final stylesheet-base and linked-sheet decoding fixes.

The r6 executable SHA-256 is
`9f754b9de64698545774c1e984fdc58b9124ae441d4e1c57597ee0d75d3bcec7`.
It uses C, literal `-prod`, one C unit, and the prepared prealloc runtime with
`-gc none`. Its compiler SHA-256 is
`baf5f3b4328f77b9dd8c49d2dc3b837b5c710d47d474ddd93ba3ad7a9d81591f`.
Compiler-consumed source manifests distinguish each image from later shared
checkout edits. Concurrent sessions have contributed other engine changes;
the table describes the pinned images, rather than attributing every gain to
one patch.

Regressions remain visible: `stretch-block-size-003` falls from 36/36 in r3 to
28/36 in r6, and `flex-line-003` falls from 3/4 to 1/4. They remain failures in
the fixed cohort and require correction.

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

The last highlight-inheritance, color-composition, path-interpolation and
contain-intrinsic changes have passing focused checks but postdate r6. An r7
optimized native build and complete cohort run are pending. The target remains
all 100 pages and all original expected assertions passing together.

## Painting regression evidence

All 11 original SVG source-switch and paint-server mutation reftests pass with
zero differing pixels at 800×600. Captures use fresh native processes on the
test display, unchanged references and zero tolerances. The production image
contains the exact Typed OM/computed-style bridge sources being checked:

- Receipt: `20261109-155153-906097e7`.
- Executable SHA-256: `b794166cf036ebdeca48b7c69b27fe4e5a7a7158076bd8d531a8a728aac742e9`.
- Pixel guard: completed, browser/capture/diff/guard exits 0.

This painting result is separate from the native cohort and does not validate
later highlight or path changes absent from that production image.

## Local evidence and reproduction

Raw results, all failed attempts, logs, selection receipts, compiler source
manifests and the pixel observer receipt remain local under
`/Users/alex/.cache/vox/wpt/batch701-800-20261109` and the active
`Build/batch701-800-*` job directories. Generated measurement JSON and archives
are not committed.

After compiling the native entry point under the required guard, run:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-701-800-UNIQUE.lock \
  --report Build/ladybird-701-800-UNIQUE-guard.json -- \
  python3 tools/ladybird_native_cohort.py \
  --catalog Tests/Browser/ladybird-new-701-800-20261109.txt \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --native Build/batch701-800-core/native-r6-prod \
  --output Build/ladybird-701-800-UNIQUE
```
