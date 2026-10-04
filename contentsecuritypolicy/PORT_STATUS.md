# ContentSecurityPolicy module V translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/ContentSecurityPolicy`

Translation workspace: `~/code/vox2/contentsecuritypolicy`
Historical mapping audit: 2026-08-16. Source repair review: 2026-10-04.

The historical inventory below mapped 37 upstream implementation units. That
inventory and its LOC counts are preserved as dated records, not current parity
or closure evidence. The earlier "complete" claim was incorrect: focused Source
comparison subsequently found missing byte-input decoding, wrong ASCII token
rules and copied-header/tuple-origin response behavior.

Completed bounded repairs and their actual default/GC-none evidence are recorded
in [ASCII token rules](../docs/translation-audit/CSP_ASCII_TOKEN_PARSING.md),
[byte input](../docs/translation-audit/CSP_SERIALIZED_BYTE_INPUT.md),
[actual response owners](../docs/translation-audit/CSP_RESPONSE_ACTUAL_HEADER_OWNER.md),
[HTML String adapter](../docs/translation-audit/HTML_CSP_STRING_ADAPTER_SOURCE_PARSER.md),
and [Fetch-response factory](../docs/translation-audit/FETCH_RESPONSE_POLICY_CONTAINER_FACTORY.md).
Those documents retain pre-fix failures and intermediate diagnostics separately
from clean passing runs. They do not establish complete native PolicyList/GC,
Realm, report-delivery or surrounding runtime parity.

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
| `ContentSecurityPolicy/` | 37 | 4,653 | 2,404 | 389 | Historical mapping; parity incomplete |

The historical inventory listed serialized-policy parsing and response headers,
duplicate directive handling, directive factory and fallback graph, source
expression grammar, asymmetric scheme/host/port/path and `'self'` matching,
nonce/SRI/hash and inline-element checks, request/response/navigation/frame
ancestor/WebRTC/sandbox checks, integrity policy, string and Wasm compilation
gates, base URL checks, typed violations and violation events, legacy report
payloads and report endpoint requests, cloning, and deterministic binary
serialization. This list describes mapped areas and is not a blanket assertion
that every Source method, owner and caller in those areas has been verified.

`frame-ancestors` derives its in-process ancestor origins by walking logical
parent navigables through their remote-safe origin accessors. Detached callers
can still supply the serialized ancestor-origin list at the process boundary.

Ladybird obtains Fetch, DOM, navigable, global-object, JS compilation, event
loop and network state from the surrounding engine. V retains acyclic typed
projections in `model.v`. Genuine Fetch response projections now retain the
actual HeaderList and current typed URL value; standalone map inputs remain an
explicit compatibility adapter. Document PolicyContainer still owns serialized
DOM policies projected to translated native PolicyList objects. That storage
boundary and complete Source GC/Realm/runtime/report ownership remain open;
observable embedder outputs alone do not prove Source dispatch or delivery.

## Historical verification (2026-08-16)

This preserved five-file result predates the above Source repairs and is not
the current test inventory. Current focused commands and outcomes are linked
in each repair document.

```text
$ /Users/alex/code/v/v test contentsecuritypolicy
Summary for all V _test.v files: 5 passed, 5 total.
```
