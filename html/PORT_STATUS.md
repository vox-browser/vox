# HTML module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/HTML`

Translation workspace: `~/code/libweb_v/html`
Audited: 2026-08-17

All 261 upstream HTML `.cpp` implementation units have a V implementation
mapping. The audit deliberately ignores this status file when checking mappings,
so documentation cannot make an unimplemented source unit appear translated.

## Remaining modules

| Remaining upstream module | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC |
| --- | ---: | ---: | ---: |
| None | 0 | 0 | 0 |

## Coverage and LOC

LOC is physical line count (`wc -l`), including comments and blank lines. V
implementation and test columns are disjoint. Shared support added to `dom` is
not included in the V counts below, so these figures describe the `html` module
itself.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `HTML/` top level | 218 | 57,313 | 23,090 | 5,185 | Complete |
| `HTML/Canvas` | 7 | 1,101 | 1,173 | 389 | Complete |
| `HTML/CrossOrigin` | 2 | 358 | 174 | 51 | Complete |
| `HTML/CustomElements` | 5 | 587 | 940 | 102 | Complete |
| `HTML/EventLoop` | 3 | 1,017 | 357 | 62 | Complete |
| `HTML/Parser` | 7 | 9,635 | 8,593 | 1,107 | Complete |
| `HTML/Scripting` | 18 | 3,217 | 1,852 | 413 | Complete |
| `HTML/SyntaxHighlighter` | 1 | 206 | 271 | 82 | Complete |
| **Total** | **261** | **73,434** | **36,891** | **7,611** | **Complete** |

The translated module contains 131 implementation files and 92 test files.
Several V files consolidate tightly coupled C++ classes, while parser and state
machine code is split by responsibility; file counts are therefore not expected
to match one-to-one.

## Verification

Full workspace verification:

```text
$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 324 passed, 324 total.
```

Focused coverage includes the HTML tokenizer/tree builder, foreign and fragment
parsing, custom elements, forms and selected-content, media, canvas and
offscreen canvas, navigation/session history, browsing contexts and
cross-origin access, event loop and messaging, workers and scripting
environments, structured serialization, rendering-thread command ordering, and
syntax highlighting.

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
