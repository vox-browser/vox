# HTML module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/HTML`

Translation workspace: `~/code/libweb_v/html`
Audited: 2026-09-04

All 261 upstream HTML `.cpp` implementation units have a V implementation
mapping. The audit deliberately ignores this status file when checking mappings,
so documentation cannot make an unimplemented source unit appear translated.

## Remaining modules

| Remaining upstream module | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC |
| --- | ---: | ---: | ---: |
| None | 0 | 0 | 0 |

## Upstream coverage

LOC is physical line count (`wc -l`), including comments and blank lines. V
implementation and test columns are disjoint. Shared support added to `dom` is
not included in the V counts below, so these figures describe the `html` module
itself.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Status |
| --- | ---: | ---: | --- |
| `HTML/` top level | 218 | 57,313 | Complete |
| `HTML/Canvas` | 7 | 1,101 | Complete |
| `HTML/CrossOrigin` | 2 | 358 | Complete |
| `HTML/CustomElements` | 5 | 587 | Complete |
| `HTML/EventLoop` | 3 | 1,017 | Complete |
| `HTML/Parser` | 7 | 9,635 | Complete |
| `HTML/Scripting` | 18 | 3,217 | Complete |
| `HTML/SyntaxHighlighter` | 1 | 206 | Complete |
| **Total** | **261** | **73,434** | **Complete** |

The translated module contains 147 implementation files (56,234 LOC) and 106
test files (11,896 LOC), containing 538 V test functions. Several V files
consolidate tightly coupled C++ classes, while parser and state-machine code is
split by responsibility; file and test counts are therefore not expected to
match one-to-one with the upstream layout.

The symbol audit inventories 4,226 upstream implementations from both `.cpp`
and inline header definitions. Its current result has zero unmatched entries:
3,378 direct candidate matches, 53 reviewed consolidated matches, 319 GC or
binding-runtime hooks, 403 language constructors/destructors, 62 namespace
template specializations, nine language template traits, and two language
operators. It also inventories 1,067 upstream HTML/WPT test inputs so changes to
the upstream corpus remain visible even though those JavaScript/browser tests
do not map one-to-one to V test functions.

## Verification

HTML verification:

```text
$ python3 tools/html_translation_audit.py
upstream .cpp files: 261
upstream methods: 4226
unmatched methods by class:

$ /Users/alex/code/v/v_old -enable-globals test html
Summary for all V _test.v files: 106 passed, 106 total.
```

Focused coverage includes the HTML tokenizer/tree builder, foreign and fragment
parsing, custom elements, forms and selected-content, media, canvas and
offscreen canvas, navigation/session history and same-document updates,
browsing contexts and cross-origin access, event loop and messaging, classic
and module-script fetching, workers and scripting environments, structured
serialization, rendering-thread command ordering, and syntax highlighting.

Responsive image source selection now delegates `sizes` to CSS's translated
component-value, media-condition, calculation, and viewport-length algorithms.
Picture-source media matching uses the same `MediaQuery.evaluate()` path, and
rendered `auto` sizes use the translated replaced-element default sizing
algorithm rather than a trailing-`px` parser and fixed numeric fallback.

`HTMLInputElement` checkedness, dirty checkedness, and indeterminate state now
live on the DOM element, matching C++, rather than being copied into a second
HTML model. `set_checked()` performs only the single-control transition and
style/repaint invalidation; binding and radio-group algorithms own exclusivity,
walk the current DOM root, and compare form owners instead of scanning a
process-global list of previously created models.

## Port boundary

The algorithms, state transitions, validation, error paths, and observable
ordering from LibWeb/HTML are translated. Operations owned by external runtime
subsystems—such as executing JavaScript bytecode, performing a platform fetch,
rasterizing through a native painter, IPC transport, or presenting a window—are
exposed as typed host hooks. Tests use deterministic hosts to verify the HTML
side of those boundaries. This keeps the module executable and testable without
pretending that the C++ LibJS, LibGfx, network, or embedder runtimes are V code.

## Conventions

- DOM-backed element algorithms use `html_<element>_<member>` functions over the
  corresponding `dom.HTML*Element` type.
- Stateful or host-bound objects use `*Model` types and explicit typed hooks.
- HTML event subclasses live in `dom/html_events.v` when dispatch identity must
  be shared with the DOM module.
- Translation implementation, tests, and status documentation live only in
  `~/code/libweb_v`; the Ladybird checkout remains the upstream reference.
