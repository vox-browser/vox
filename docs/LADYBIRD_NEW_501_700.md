# Ladybird newly imported tests 501–700

This batch continues the earlier 500 with the next **200 fixed test IDs** in
[the committed selection](../Tests/Browser/ladybird-new-501-700-20261109.txt).
They are discovery positions 501–700 newly imported between Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa` and fetched revision
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. Selection uses offset 500 and limit
200 before execution, with no overlap with the earlier 500 or filtering on
browser results. The upstream working checkout remains unchanged.

**Acceptance is incomplete; engine fixes and full-cohort validation are in progress.**

## Fixed cohort and baseline

| Group | Pages |
|---|---:|
| css-grid | 109 |
| css-highlight-api | 19 |
| css-images | 1 |
| css-inline | 15 |
| css-lists | 4 |
| css-logical | 1 |
| css-masking | 8 |
| css-multicol | 9 |
| css-overflow | 7 |
| css-overscroll-behavior | 6 |
| css-position | 19 |
| css-properties-values-api | 2 |
| Total | 200 |

The existing shared production executable, SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`, passes
50/200 pages in a complete run of this selection. Its build receipt requests
head `45375fcc55f6e885c9d4218fa926af1ccea1bf8d` and predates recent engine fixes.
It supplies baseline evidence only.

The current native baseline also passes 50/200 pages and 3,313/6,012 reported
assertions. Missing APIs abort registration on some pages, so 6,012 is the
observed baseline assertion count, not a final denominator. It reuses the
previous batch's sealed native executable, SHA-256
`e77c61dba584da41dffc190564de86d7afaa3691694798aff89b7bd1f1020c19`, with fresh
native navigation, DOM/CSS/layout, JavaScriptCore, HTML event loop and separate
profile per page at 800×600. It does not validate painting or the GUI.

Both complete baseline runs use original immutable fixtures through upstream
wptserve. The existing timeout normalization and collecting reporter preserve
assertions. All executable/controller/server and fixture checks stay pinned.
Failures, harness errors, timeouts and missing results remain failures.
Native pages use 2 GiB / 80 second guards; the outer 3 GiB guard completed
cleanly with 487,407,616 bytes peak RSS over 254.05 seconds.

## Provenance and reproduction

Fixtures are exported without changing the upstream checkout to
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
The exact selected objects and source pin are in
`~/.cache/vox/wpt/batch501-700-20261109/selection.json` and `source.json`.
Per-job outputs remain temporary under `Build/batch501-700-*` during active
work and will be archived outside `Build/` when complete.

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/UNIQUE.lock --report Build/UNIQUE-guard.json -- \
  python3 tools/wpt_compare.py --output Build/UNIQUE \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
  --offset 500 --limit 200 --browsers vox --chunk-size 10 \
  --width 800 --height 600 --browser-memory-gib 2 --require-all-pass \
  --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

Required Volt checks ran before the import commit: `make app` succeeds. The
direct `v -memory-limit 10G -enable-globals -o volt .` build reaches its
configured 10 GiB compiler physical-footprint limit. That limit is preserved.
