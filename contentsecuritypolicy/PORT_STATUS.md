# ContentSecurityPolicy module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/ContentSecurityPolicy`

Translation workspace: `~/code/libweb_v/contentsecuritypolicy`
Audited: 2026-08-16

All 37 upstream ContentSecurityPolicy `.cpp` implementation units have an
audited V implementation mapping. Associated headers and
`SecurityPolicyViolationEvent.idl` are represented by typed V enums, records,
constructors, and accessors.

| Upstream implementation unit | V implementation |
| --- | --- |
| `BlockingAlgorithms.cpp` | `blocking_algorithms.v` |
| `Directives/BaseUriDirective.cpp` | `directive.v` |
| `Directives/ChildSourceDirective.cpp` | `directive.v` |
| `Directives/ConnectSourceDirective.cpp` | `directive.v` |
| `Directives/DefaultSourceDirective.cpp` | `directive.v` |
| `Directives/Directive.cpp` | `directive.v` |
| `Directives/DirectiveFactory.cpp` | `directive.v` |
| `Directives/DirectiveOperations.cpp` | `directive_operations.v` |
| `Directives/FontSourceDirective.cpp` | `directive.v` |
| `Directives/FormActionDirective.cpp` | `directive.v` |
| `Directives/FrameAncestorsDirective.cpp` | `directive.v` |
| `Directives/FrameSourceDirective.cpp` | `directive.v` |
| `Directives/ImageSourceDirective.cpp` | `directive.v` |
| `Directives/KeywordSources.cpp` | `names.v` |
| `Directives/KeywordTrustedTypes.cpp` | `names.v` |
| `Directives/ManifestSourceDirective.cpp` | `directive.v` |
| `Directives/MediaSourceDirective.cpp` | `directive.v` |
| `Directives/Names.cpp` | `names.v` |
| `Directives/ObjectSourceDirective.cpp` | `directive.v` |
| `Directives/ReportToDirective.cpp` | `directive.v` |
| `Directives/ReportUriDirective.cpp` | `directive.v` |
| `Directives/SandboxDirective.cpp` | `directive.v` |
| `Directives/ScriptSourceAttributeDirective.cpp` | `directive.v` |
| `Directives/ScriptSourceDirective.cpp` | `directive.v` |
| `Directives/ScriptSourceElementDirective.cpp` | `directive.v` |
| `Directives/SerializedDirective.cpp` | `serialization.v` |
| `Directives/SourceExpression.cpp` | `source_expression.v` |
| `Directives/StyleSourceAttributeDirective.cpp` | `directive.v` |
| `Directives/StyleSourceDirective.cpp` | `directive.v` |
| `Directives/StyleSourceElementDirective.cpp` | `directive.v` |
| `Directives/WebRTCDirective.cpp` | `directive.v` |
| `Directives/WorkerSourceDirective.cpp` | `directive.v` |
| `Policy.cpp` | `policy.v` |
| `PolicyList.cpp` | `policy.v` |
| `SecurityPolicyViolationEvent.cpp` | `security_policy_violation_event.v` |
| `SerializedPolicy.cpp` | `serialization.v` |
| `Violation.cpp` | `violation.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ContentSecurityPolicy/` | 37 | 4,653 | 2,404 | 389 | Complete |

The port covers serialized-policy parsing and response headers, duplicate
directive handling, the full directive factory and fallback graph, source
expression grammar, asymmetric scheme/host/port/path and `'self'` matching,
nonce/SRI/hash and inline-element checks, request/response/navigation/frame
ancestor/WebRTC/sandbox checks, integrity policy, string and Wasm compilation
gates, base URL checks, typed violations and violation events, legacy report
payloads and report endpoint requests, cloning, and deterministic binary
serialization.

Ladybird obtains Fetch, DOM, navigable, global-object, JS compilation, event
loop, and network state from the surrounding engine. The V translation exposes
the exact state consumed by CSP through typed records in `model.v`; generated
reports, events, and report requests are observable embedder outputs. This keeps
the module independent of incomplete engine bindings while preserving its
security decisions and ordering.

## Verification

```text
$ /Users/alex/code/v/v test contentsecuritypolicy
Summary for all V _test.v files: 5 passed, 5 total.
```
