# Layout module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Layout`

Re-audited: 2026-08-29

All 50 upstream Layout `.cpp` units are represented by the typed V Layout
implementation. The V source consolidates some C++ class/file boundaries where
the languages differ, but preserves the algorithms' branches, ordering,
fixed-point arithmetic, intrinsic-size rules, layout-tree fixups, and used-value
state transitions. There are no `FIXME` or `TODO` markers in `layout/*.v`.

The symbol-level audit now classifies all 1,000 extracted upstream Layout
implementations: 897 direct or consolidated V candidates, 66 constructors or
destructors, 22 namespace template specializations, 8 GC/runtime hooks, 4
language operators, and 3 language-provided traits, with zero unmatched
symbols. The class-shaped entry points for the V port's consolidated formatting
algorithms are in `upstream_formatting_context_entry_points.v`,
`upstream_node_entry_points.v`, `upstream_grid_item_entry_points.v`, and
`upstream_namespace_entry_points.v`.

## Translated coverage

The translated path includes the complete layout-node hierarchy and tree
builder; incremental style application and anonymous/table-wrapper propagation;
block, inline, flex, grid, table, fieldset, replaced-with-children, SVG, and
absolute-position formatting; floats, clearance, margin collapse, intrinsic
sizing, aspect-ratio constraint solving, line construction and breaking,
generated content and counters, list markers, relative positioning, overflow,
SVG natural metrics and transforms, typed used-value state, layout/DOM bridging,
debug dumps, and the typed layout-to-renderer adapter used by the executable.

The upstream Layout regression corpus is exercised directly by
`tools/layout_corpus.v`. It discovers every HTML or SVG input with a matching
expected snapshot and compares all three upstream sections exactly: layout tree,
paint tree, and text. The current checkout has 904 comparable cases; all 904
pass byte-for-byte.

The default-page spacing defect was caused by the old renderer transport
painting individually estimated word fragments. The typed adapter now preserves
the Layout run identity and coalesces each naturally spaced DOM text run before
native shaping, so spaces are neither expanded nor dropped.

## Verification

Verified on 2026-08-28 with `/Users/alex/code/v/v_old`:

```text
$ /Users/alex/code/v/v_old -enable-globals run tools/layout_corpus.v --all
Layout corpus: 904 passed, 0 failed, 904 total

$ /Users/alex/code/v/v_old -enable-globals test layout
Summary for all V _test.v files: 16 passed, 16 total.

$ /Users/alex/code/v/v_old -enable-globals test css
Summary for all V _test.v files: 17 passed, 17 total.

$ /Users/alex/code/v/v_old -enable-globals test integration
Summary for all V _test.v files: 2 passed, 2 total.

$ V_BIN=/Users/alex/code/v/v_old ./build_ladybird.sh
Built V-native Ladybird app: Build/v/Ladybird.app

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed
```

The repository-wide test command currently reports 324 passed and 11
compile-time failures in unrelated packages. None of those failures is in
Layout, CSS, or integration; they are V-compiler compatibility issues in
Encoding, Infra, Page, Platform, an SVG test, WebAssembly, WebDriver, and
WebIDL.

## Module boundary

Layout consumes state supplied by HTML media/navigable objects and produces
renderer-facing data consumed by Painting and the native shell. Loading video
frames, creating child browsing contexts, system typeface discovery, and native
rasterization remain responsibilities of those modules and platform hosts; they
are not omitted Layout algorithms.
