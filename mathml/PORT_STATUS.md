# MathML module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/MathML`

Translation workspace: `~/code/libweb_v/mathml`
Audited: 2026-08-16

All five upstream MathML `.cpp` implementation units have audited V mappings.
Their headers and IDL are represented by typed names, element records, roles,
attributes, and presentational-hint results.

| Upstream implementation unit | V implementation |
| --- | --- |
| `AttributeNames.cpp` | `names.v` |
| `TagNames.cpp` | `names.v` |
| `MathMLElement.cpp` | `elements.v` |
| `MathMLMiElement.cpp` | `elements.v` |
| `MathMLMspaceElement.cpp` | `elements.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `MathML/` | 5 | 292 | 361 | 75 | Complete |

The port covers all 11 attribute and 32 tag names, the `<math>` default ARIA
role, common MathML presentation attributes, signed and absolute script levels,
the `mi` `mathvariant=normal` behavior, and `mspace` width/height/depth parsing
and combination. It delegates CSS value acceptance and serialization to the
translated CSS parser. The upstream requested-line-ascent step remains FIXME
and is deliberately not fabricated. DOM allocation/prototype/mixin mechanics
belong to the existing DOM and binding layers; this package owns the observable
MathML-specific algorithms.

## Verification

```text
$ /Users/alex/code/v/v test mathml
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify mathml
(no output; exit status 0)
```
