# TrustedTypes port status

Audit snapshot: Ladybird `Libraries/LibWeb/TrustedTypes` on 2026-08-17.

## Inventory

- Upstream: 7 `.cpp` files, 1,108 implementation LOC; 7 headers; 5 IDLs.
- V: 3 implementation files, 722 LOC; 2 test files, 168 LOC, 9 tests.

## Source mapping

| Upstream source | LOC | V translation |
| --- | ---: | --- |
| `InjectionSink.cpp`, `InjectionSink.h` | 26 | `factory_csp.v` |
| `RequireTrustedTypesForDirective.cpp`, `.h` | 192 | `factory_csp.v` |
| `TrustedHTML.cpp`, `.h`, `.idl` | 43 | `trusted_values.v` |
| `TrustedScript.cpp`, `.h`, `.idl` | 43 | `trusted_values.v` |
| `TrustedScriptURL.cpp`, `.h`, `.idl` | 43 | `trusted_values.v` |
| `TrustedTypePolicy.cpp`, `.h`, `.idl` | 423 | `policy.v` |
| `TrustedTypePolicyFactory.cpp`, `.h`, `.idl` | 338 | `factory_csp.v` |

All current `.cpp`, header and IDL files are accounted for.

## Coverage and boundaries

Portable behavior includes policy callbacks and default-policy conversion,
policy-name/duplicate CSP enforcement, 40-code-point violation samples, sink
requirements, JavaScript navigation checks, property tables, XLink SVG script
URLs, and every current global/window event-handler attribute in the HTML, SVG
and MathML namespaces. Attribute-mutation compliance is exposed through
`get_trusted_types_compliant_attribute_value`.

DOM documents, realms and CSP reporting events are embedding boundaries. The V
factory stores deterministic violation records instead of dispatching browser
CSP reports. Upstream gives every event-handler attribute its own generated
`InjectionSink` enum value; V compresses those values to
`element_event_handler` while retaining the full lookup table and enforcement
semantics. Its diagnostic label is consequently `Element event handler` rather
than `Element on<event>`.
