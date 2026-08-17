# XPath module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XPath`

Translation workspace: `~/code/libweb_v/xpath`
Audited: 2026-08-17

All five implementation units, five headers, and four WebIDL definitions were
audited.

| Upstream implementation | V implementation |
| --- | --- |
| `XPath.cpp`, `XPathEvaluator.cpp`, `XPathExpression.cpp`, `XPathNSResolver.cpp` | `evaluator.v` |
| `XPathResult.cpp` | `result.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `XPath/` | 5 | 438 | 407 | 83 | Complete |

Associated declarations comprise 5 headers / 188 LOC and 4 IDL files / 62 LOC.
Mapping completeness is 5/5 implementation units, 5/5 headers, and 4/4 IDL
definitions audited.

The port represents expression/evaluator/resolver lifetimes, the mirrored DOM
subtree boundary, path/descendant/attribute selection, predicates, scalar
functions and literals, reusable results, all ten WebIDL result types,
iteration/snapshots, native result-type behavior, and evaluation-time syntax
errors. As in current upstream, namespace resolver callbacks are retained but
not registered with the evaluator. Native libxml allocation is replaced by a
typed traversal of the translated DOM.

Verification: `v test xpath` passes 1/1; formatting and scoped diff checks pass.
