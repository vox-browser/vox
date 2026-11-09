# Ladybird import: cases 701–800

## Scope and acceptance

The fixed 100-case cohort from Ladybird's imported WPT tests passes
**98/100 pages and 5,354/5,356 assertions with its original assertions**.
A separately labelled diagnostic with two proposed expectation corrections
passes **100/100 pages and 5,356/5,356 assertions**. These cohort results do not
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
**5,356 assertions**. The unmodified runs leave fixtures, support resources,
assertions and deadlines unchanged. A separate proposed-errata diagnostic
changes two expected-value literals at serve time, as detailed below. The
original expectation names are compared as a multiset, including multiline names; missing assertions fail acceptance.

`tools/ladybird_native_cohort.py` exports and verifies the pinned fixtures and
runs a fresh `compact/upstream_testharness_test.v` process for every page. A case
passes only with a successful guarded process exit, a clean harness, every
expected assertion reported, and every reported assertion passing. The runner's
ten Python unit tests pass.

The native entry point exercises document navigation, parsing, resources,
JavaScriptCore, DOM, CSS and layout. It does not validate window painting.
Runtime jobs have a 3 GiB outer guard and a 2 GiB per-page guard. Compiler jobs
retain the default 12 GiB guard and V's `-memory-limit 10G`.

## Complete native runs with unmodified assertions

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
| r13, optimized prepared runtime | 97 / 100 | 5,353 / 5,356 | 0 |
| r15, first-line integration before storage fix | 97 / 100 | 5,310 / 5,312 | 44 |
| r16, first-line storage fix | **98 / 100** | **5,354 / 5,356** | **0** |

The baseline's 324 missing assertions came from the Typed OM page terminating
during setup. Every complete image from r6 onward reports and passes all
**325/325** of that page's assertions.
Registered-property computation passes **75/75**, and URL resolution passes
**18/18**, including the UTF-16 stylesheet. Every r16 page completes inside its
unchanged harness deadline, with harness status 0 and unchanged pinned runtime
inputs. The r16 cohort guard exits 1 because assertions remain failing; its
compiler guard exits 0. Both containment pages now pass: 48/48 and 42/42;
path interpolation passes 478/478. First-line property filtering and the nested
highlight-inheritance page also pass completely.

The r4 run was interrupted after 49 pages and has no terminal cohort receipt.
It is retained as partial evidence, without an aggregate pass-rate claim. The
r5 focused run reports 448/464 assertions across four pages, with three pages
passing; it predates the final stylesheet-base and linked-sheet decoding fixes.

The r16 executable SHA-256 is
`2349dc5c58f6e52176efe609641f98b61b99b0552a335c913de0be42f9beed18`.
The r15 image with the storage regression is
`2288bc2cb13b08f29c4d0af6370d57226b8a21db31fbfdc7c599a615ad90c41d`;
r13 is `f2bf011a660391394a0d6e51b83299ce4de40d4d7b385c639d0158d1b9fb6802`.
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
These optimized images use C, literal `-prod`, one C unit, and the prepared prealloc runtime with
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
together. The **two remaining r16 failures** are the mixed length/percentage
iteration cases described below. Both are marked `Fail` in the pinned Ladybird
expectations. Those expectations contain 102 recorded failures overall; Vox
passes 100 of them in r16, together with all 5,254 assertions recorded `Pass`.
Expected upstream failures are still failures in this cohort. The real
shadow-part first-line rendering gap is now fixed: the original page reports
and passes **44/44**, including the expected 106px first-line height.

## First-line integration

`5473d9d33` installs first-line styles during style updates and uses a separate
font cascade for first-line shaping, line metrics, color and paint commands.
It restores ordinary text after soft/forced breaks while preserving DOM text
identity and UTF-16 offsets. The initial slice handles direct text and break
nodes in horizontal block contexts. Descendant inline inheritance, transformed
source mappings, emergency word splitting and broader first-line property
coverage remain outside this slice.

All five initial focused test functions pass in the ordinary runtime, covering
both font policies, wrapping and viewport changes, shadow parts, empty lines,
preserved newlines, and inherited font changes. The optimized prepared-runtime
r15 run exposes a lifetime bug: the shadow-part page panics during paint
projection after temporary geometry storage retires, losing all 44 assertions.
That regression remains in the table. Follow-up `f64a625e7` moves the retained style
sources into document-owned storage, excludes pseudo styles from caches whose
input signatures do not record them, and adds a prepared-runtime ownership and
scratch-churn regression check. All **six focused test functions pass** with
the same optimized prepared prealloc compiler and `-gc none`; compile and
runtime guards both exit 0. The fresh r16 full cohort recovers every lost
assertion and passes the original shadow-part page completely.
The superseded r14 compilation was stopped with exit 143 before any cohort ran;
it receives no aggregate result.

## Mixed length/percentage accumulation diagnostic

The comma-list and space-list pages each retain one failing iteration-accumulation
assertion. Their original expectation contains `calc(25% + 50px)`; Vox produces
`calc(25% + 250px)`. Applying two copies of the 100px final keyframe before
interpolating the interval endpoints appears to require the latter result under
the [Web Animations iteration-composition procedure](https://drafts.csswg.org/web-animations-2/#iteration-composition)
and [CSS numeric accumulation](https://drafts.csswg.org/css-values-4/#combining-values).
This is a suspected expectation inconsistency, not a passing result. For the second list
item, the accumulated endpoints are `calc(50% + 200px)` and `300px`;
their midpoint is `calc(25% + 250px)`. The original 50px component omits
the two accumulated 100px contributions.

A separate fresh-process diagnostic on the same two unchanged imported pages
in installed **Brave 157.1.99.55** also reports 10/12 assertions, with both
iteration cases failing. Brave produces `50%` in the first list item where
the test expects `250%`, and retains the expected 50px component in the second
item; its output differs from Vox. Its executable SHA-256 is
`4772b8898cc23f044c134b75a494ddc9053f58d5ea8cd1acb6f60762292df513`.
Harnesses complete normally, inputs remain unchanged, and the guarded process
exits 1 because `--require-all-pass` rejects the two failures. This focused
static-server diagnostic establishes neither full WPT parity nor a browser
percentage comparison. The original exported expectations remain unchanged.

## Proposed expectation corrections

The [proposed manifest](../Tests/Browser/ladybird-new-701-800-expectation-errata.json)
changes the second component's expected `calc(25% + 50px)` to
`calc(25% + 250px)` in the comma-list and space-list pages. The first component
remains `250%`. Commit `894767217` records both exact original source hashes,
the original/corrected lines and the numeric derivation. These are proposed
corrections; upstream acceptance is not established.

Historical WebKit source helps explain the asymmetry:
[`blendMixedTypes()`](https://github.com/WebKit/WebKit/blob/c0462225cee0519a9a1dd0c406448a56456ad523/Source/WebCore/platform/Length.cpp#L299-L315)
constructs a mixed-value blend using progress alone, whereas its
[numeric blending path](https://github.com/WebKit/WebKit/blob/c0462225cee0519a9a1dd0c406448a56456ad523/Source/WebCore/platform/animation/AnimationUtilities.h#L83-L105)
applies iteration increments. A zero length can take the numeric path while a
nonzero mixed-unit pair takes the other path. This is an archived implementation
comparison, not a measurement of current Safari behavior.

Two fresh, serial full-cohort runs use the **same r16 executable** and identical
common pinned input hashes:

| Served fixture inputs | Passing pages | Passing / reported assertions | Missing | Guard exit |
| --- | ---: | ---: | ---: | ---: |
| Unmodified upstream | 98 / 100 | 5,354 / 5,356 | 0 | 1 |
| Two explicit proposed expectation corrections | **100 / 100** | **5,356 / 5,356** | **0** | **0** |

All 100 page processes and harnesses exit successfully in both runs. Every
original expected name remains present, and exactly two assertion outcomes
change from FAIL to PASS. The exported upstream files remain byte-identical;
the server substitutes only the two documented literals. No engine behavior
was changed to obtain this corrected-fixture result. The **unmodified upstream
result remains 98/100**.

The correction manifest SHA-256 is
`ee5087112aab485a5b68c65734dcf272faa897b3b1e41e2cc3ad193d01968720`.
The run identity records each original and served file hash. The runner defaults
to `unmodified-upstream`; `--expectation-errata` explicitly labels the other
variant `proposed-expectation-errata` and leaves
`unmodified_upstream_all_pass` unknown for that run. An erratum must match the
pinned revision and source hash, replace exactly one complete literal expected
line, and identify a selected test HTML page. Harness/control-flow edits,
ambiguous replacements and corrections shared by unlisted query variants fail
validation. All ten tooling unit tests pass. After the query-variant guard was
added, both corrected pages also pass a fresh focused run: **12/12 assertions**,
zero missing, with identical served hashes to the full corrected run.

## Painting regression evidence

All 11 original SVG source-switch and paint-server mutation reftests pass with
zero differing pixels at 800×600. Captures use fresh native processes on the
test display, unchanged references and zero tolerances. The production image
contains the exact Typed OM/computed-style bridge sources being checked:

- Receipt: `20261109-155153-906097e7`.
- Executable SHA-256: `b794166cf036ebdeca48b7c69b27fe4e5a7a7158076bd8d531a8a728aac742e9`.
- Pixel guard: completed, browser/capture/diff/guard exits 0.

The three original selection reftests also pass with **zero differing pixels**
at 800×600, including focus changes, insertion between boundaries, and movement
between subtrees. Each input/reference capture and exact diff exits 0; the
3 GiB guard exits 0 and all pinned inputs remain unchanged.

- Receipt: `20261109-185423-29c286ec`.
- Executable SHA-256: `d582a08966a8006580040af3e834ca84aa3a75e5530f8a91f27a1a533757dd0f`.

These are separate painting cohorts. The earlier SVG image contains the
Typed OM/computed-style bridge fixes; the later selection image contains the
highlight-inheritance and first-line integration sources. The selection
fixtures do not exercise first-line styling or its subsequent storage fix.
Earlier observer attempts and automatic build failures remain retained; the
matching completed build was leased directly without copying an app bundle or
queuing a manual production build.

## Local evidence and reproduction

Raw results, all failed attempts, logs, selection receipts, compiler source
manifests and the pixel observer receipt remain local under
`/Users/alex/.cache/vox/wpt/batch701-800-20261109` including `completed-evidence/`; active
`Build/batch701-800-*` job directories retain only ongoing jobs. Completed
artifacts are relocated there with their receipts and compiler-consumed source
hashes, and their temporary generated C is removed. The paired expectation
recheck evidence is under `iteration-recheck/`. Generated measurement JSON and
archives are not committed.

After compiling the native entry point under the required guard, run:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-701-800-UNIQUE.lock \
  --report Build/ladybird-701-800-UNIQUE-guard.json -- \
  python3 tools/ladybird_native_cohort.py \
  --catalog Tests/Browser/ladybird-new-701-800-20261109.txt \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --native /Users/alex/.cache/vox/wpt/batch701-800-20261109/completed-evidence/final/core/native-r16-prod \
  --output Build/ladybird-701-800-UNIQUE
```

For the separately labelled corrected-fixture diagnostic, add
`--expectation-errata Tests/Browser/ladybird-new-701-800-expectation-errata.json`
to that command and choose fresh lock, report and output paths. Omitting the
option runs the original assertions and retains the two failures.
