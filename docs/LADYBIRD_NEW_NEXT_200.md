# Next 200 newly imported Ladybird tests

This batch continues the [first 100](LADYBIRD_NEW_FIRST_100.md): Ladybird
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`, newly imported since
`963d46a829f3e1b79f44dba9d02afb70654300fa`, discovery positions 101–300.
The immutable exported inputs and expectations come from the already fetched
upstream revision; the upstream working checkout remains unchanged.
The [200 case IDs](../Tests/Browser/ladybird-new-next200-20261108.txt) are fixed
before execution, including distinct worker and query variants.

**The batch remains incomplete.** Final native engine validation fully passes
**72/200 cases and 7,316/9,531 reported subtests**. The production baseline is
10/200. The selector, parser and layout fixes are committed; 128 native cases
still fail strict acceptance. No assertions or expectations were changed.

## Production baseline

**The full batch does not pass.** The available production executable,
SHA-256 `f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`,
fully passes **10/200 cases** and **5,832/9,681 reported subtests**.
There are 3,818 FAIL, 3 TIMEOUT and 28 NOTRUN subtests. Of 199 reporting
documents, 174 harnesses are OK, three ERROR and 22 TIMEOUT; one further
document never starts its harness. There are no browser crashes or browser
memory-limit stops. The strict runner and its memory supervisor exit 1.

| Group | Cases | Fully passing | Passing subtests |
|---|---:|---:|---:|
| Content Security Policy | 45 | 7 | 69/164 |
| CSS2 line boxes | 1 | 0 | 7/13 |
| CSS alignment | 80 | 2 | 882/2701 |
| CSS anchor positioning | 74 | 1 | 4874/6803 |

All cases use upstream wptserve handlers, substitutions and supporting resources.
The executable, libraries and fixture tree remain unchanged across 21 fresh
browser launches with private profiles and a 1024×768 viewport. The aggregate
3 GiB guard observes 1,655,603,200 bytes peak RSS; each browser has a 2 GiB cap.
This is an imported testharness subset, not the entire upstream WPT suite.

## Engine fixes

The continuation selector is committed as `866cd4a55`: `--offset` skips eligible
IDs after the new-since and include filters, before applying the limit. All 24
WPT tooling checks pass, including disjoint continuation and variant coverage.

CSS parsing now preserves safe/unsafe alignment qualifiers and last-baseline
alignment, canonicalizes first baseline and legacy ordering, and accepts
qualified place-content/items/self shorthands. Absolute layout applies explicit
self alignment in the containing block's writing mode and direction, honors
self-start/end, preserves auto margins, and uses the original containing block
for default overflow alignment. Anchor-center parsing and placement use the
resolved live anchor and respect the inset-modified containing rectangle.

The parser fix is `3e8269448`; the layout and anchor geometry fix is
`a81d71adc`. Three parser functions and three layout functions pass in the
final focused C builds and 3 GiB runtime guards. The layout checks cover
42 writing-mode/direction/alignment combinations, four default-overflow
sizes, and three live-anchor sizes. The final anchor regression exposed
relative offsets missing before the final relative-inset pass; anchor lookup
now applies the existing inset calculation along the anchor's ancestor chain.

The first native check of the unchanged absolute-alignment pages passes
**56/59 cases and 989/1004 subtests** on executable
`44f6e58b03c198a8f7cfe0d05688a707b25b84f2abc7dc76f77bc3fa9bf5aa15`.
All 56 positional, baseline, safe/unsafe and default-overflow pages pass. Three
stretch/intrinsic-size pages retain 15 failing assertions across aspect ratios
and orthogonal writing modes. This executable precedes the final shorthand
and anchor-center additions; it validates the initial alignment implementation.
These are fresh native Document/HTML/DOM/JSC processes, without GUI creation
or painting, and do not change the production baseline above.

## Final native cohort

Executable `5d76a6102b41ba3ebf3930b42fbe35d1be05bf6a4f960bb4bab16f135f377f2f`
checks all 200 IDs, retaining all ten baseline-passing IDs. There are 7,316 PASS,
2,145 FAIL, 14 TIMEOUT and 56 NOTRUN subtests; harness statuses are 154 OK,
two ERROR and 44 TIMEOUT. Every document reports. Ten TIMEOUT reports contain
no subtests, so those geometry assertions receive no coverage or pass credit.
These account for 156 names present in the production baseline; the native
cross-realm CSP case registers six additional names, yielding the different
9,531-subtest denominator. Font-ready and animation waits remain limitations
of this non-windowed validation.

| Group | Cases | Fully passing | Passing subtests |
|---|---:|---:|---:|
| Content Security Policy | 45 | 7 | 66/170 |
| CSS2 line boxes | 1 | 0 | 0/0 (harness TIMEOUT) |
| CSS alignment | 80 | 61 | 2368/2565 |
| CSS anchor positioning | 74 | 4 | 4882/6796 |

This is a disjoint composition of 158 cases and 42 remaining cases on the
same executable and fixtures. The first controller stops when another session
adds unrelated SVG pointer-event keywords to `css/style_values_core.v` after
compilation (subsequently committed as `1c3591c32`). Its 158 individual case results are retained, with no whole-run
credit. The continuation verifies the exact executable hash, immutable fixtures,
server tools and compiled-source hash record while checking the remaining IDs.
The later SVG changes remain unmodified and receive no validation credit.
Both supervisors exit 1; the original stops on its source-change assertion,
and the continuation fails its strict case gate. No all-pass result is claimed.

The [local manifest](performance/ladybird-new-next200-20261108.json) contains
all selected input/expectation hashes, 200 original browser records, 200 final
native records, scoped source identities, guards and the verified local raw
archive. Passing focused checks and failed/interrupted attempts remain separate.
The raw archive is `/Users/alex/.cache/vox/wpt/20261108-ladybird-new-next200.tar.gz`,
SHA-256 `c45db5b0621fa9d1c8317faca666064a9cb0a76faaf3cd3b9cea277998eac21b`.

Other remaining failures include nonce hiding, Trusted Types evaluation,
CSP violation dispatch, block content alignment, anchor sizes and scopes,
position-try rules/fallbacks, CSSPositionTryRule and computedStyleMap exposure.
Assertions and expected results are unchanged; none are skipped or weakened.

## Reproduction

Run from `/Users/alex/code/vox2`:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-next200-repeat.lock \
  --report Build/ladybird-next200-repeat-guard.json -- \
  python3 tools/wpt_compare.py --output Build/ladybird-next200-repeat \
    --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
    --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
    --offset 100 --limit 200 --browsers vox --chunk-size 10 \
    --browser-memory-gib 2 --require-all-pass \
    --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

The shared production build was already running; no duplicate was queued.
The latest completed production bundle still predates these changes at the
end of validation. A matching windowed production rerun remains pending.
The original Volt workspace's required `v -enable-globals -o volt .` check
fails in existing macOS struct declarations and then in its compatibility
compiler fallback. `make app` passes on its first attempt. These checks do
not validate Vox's engine or replace the required conformance results.
