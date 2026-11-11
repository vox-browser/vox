# Ladybird newly imported tests 801–1000

This batch continues the earlier 800 with the next **200 fixed test IDs** in
[the committed selection](../Tests/Browser/ladybird-new-801-1000-20261110.txt).
They are discovery positions 801–1000 among the 3,063 tests newly imported
between Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` and
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. Selection uses offset 800 and limit
200 before execution, with no overlap with the earlier 800 and no filtering on
browser results. Regenerating offsets 500/200 and 700/100 with the same code
reproduces the committed 501–700 and 701–800 catalogs exactly.

- Catalog SHA-256: `035de9473fe12af7cb1145546292e3eb5f6eae932763bfcc70980259a31ad1a4`.
- Selection JSON SHA-256: `7adc7b58e6a061e51a2e0d31137d491a61f4efe98ade163bc659b97d56372ce4`.

## Fixed cohort

| Group | Pages |
|---|---:|
| css-sizing | 8 |
| css-tables | 11 |
| css-text | 37 |
| css-text-decor | 4 |
| css-transforms | 12 |
| css-transitions | 3 |
| css-typed-om | 110 |
| css-ui | 3 |
| css-values | 12 |
| Total | 200 |

Their Ladybird expectations contain **12,225 assertions**, 554 of which
Ladybird itself records as `Fail`. Acceptance requires every page to report
every expected assertion name and pass all of them; expected upstream failures
remain failures here.

## Baseline

The native baseline (r0) passes **30/200 pages** and **2,935 assertions**;
5,861 expected assertions are missing because pages abort before registering
tests. Its executable SHA-256 is
`d43ef0b42ef12e91dfa8a93e699785060bcb367030c7bce82571c2433773e5d0`, compiled
from the shared checkout with the C backend at `-O1`. Each page runs in a fresh
native process (navigation, DOM/CSS/layout, JavaScriptCore, HTML event loop) at
800×600 with a separate profile; it does not validate painting or the GUI.

| Area | Pages passing | Assertions passing |
|---|---:|---:|
| css-sizing | 8 / 8 | 307 / 307 |
| css-tables | 1 / 11 | 25 / 46 |
| css-text | 14 / 37 | 673 / 1,285 |
| css-text-decor | 1 / 4 | 257 / 353 |
| css-transforms | 4 / 12 | 1,108 / 1,395 |
| css-transitions | 1 / 3 | 51 / 72 |
| css-typed-om | 0 / 110 | 5 / 5,876 |
| css-ui | 1 / 3 | 7 / 11 |
| css-values (calc-size) | 0 / 11 | 440 / 2,817 |
| css-values (other) | 0 / 1 | 62 / 63 |

The main gaps at baseline:

- Every Typed OM property page aborts while loading its shared test suite:
  `CSSTranslate`, `CSSMatrixComponent` and the other transform components are
  not defined.
- `calc-size()` and `interpolate-size` are not implemented.
- `hyphenate-character`, `text-align-last`, `text-emphasis-position` and
  `field-sizing` are not supported properties.
- `line-break: strict` and `loose` do not follow the CJK rules; table part
  bounding boxes, caption margins, collapsed columns and fractional percentage
  widths differ; several 3D transform interpolation and composition results
  differ.

## Provenance and reproduction

Fixtures are exported from the upstream checkout without changing it to
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
The selection and baseline evidence are under
`~/.cache/vox/wpt/batch801-1000-20261110/`.

After compiling `compact/upstream_testharness_test.v` under the memory guard:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-801-1000-UNIQUE.lock \
  --report Build/ladybird-801-1000-UNIQUE-guard.json -- \
  python3 tools/ladybird_native_cohort.py \
  --catalog Tests/Browser/ladybird-new-801-1000-20261110.txt \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --native PATH/TO/native-tests \
  --output Build/ladybird-801-1000-UNIQUE
```
