# HTML compatibility CSP string adapter uses the Source parser

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Policy.cpp:23–89` and
`Policy.cpp:199–213`.

HTML's pre-existing `parse_response_csp_policy()` helper manually split
semicolon fields into serialized policy records. It retained duplicate
directives, accepted non-ASCII tokens and missed Source's CR/form-feed value
separators. Its original text and supplied DOM Origin were already retained.

That compatibility helper now delegates directive parsing to the actual
translated Source String parser. It copies the resulting directive fields into
the existing serialized DOM record, retains its supplied actual DOM Origin and
original text, and preserves header source plus the requested disposition.
It does not reconstruct opaque origin nonces or add a policy parsing algorithm.
This adapter receives String input; the subsequent actual Fetch-response
factory will instead consume Source's byte-input response parser.

Four focused cases in `html/response_csp_string_adapter_test.v` witness first
duplicate preservation, all five ASCII whitespace characters, non-ASCII token
omission and exact original text/disposition/source/opaque-file origin identity.
Before the helper change, three focused cases failed behaviorally and the
origin/text control passed in 111.03 seconds
(`Build/audit-fixes/source-html-csp-string-adapter-original-default.log`).
The corrected focused file passed in the default compiler/GC mode in
80.24 seconds (`source-html-csp-string-adapter-default.log`). The GC-none
two-file batch passed in 162.56 seconds
(`source-html-csp-string-adapter-gc-none.log`), covering the new adapter cases
and the existing exact opaque/tuple-origin projection neighbors. The original
behavioral failures remain recorded separately.

The helper remains explicitly a compatibility fixture adapter, not a Source
Fetch Response or native PolicyList owner. Actual Fetch-response policy factory
selection, referrer extraction and the serialized DOM/native PolicyList/GC
boundary remain separate. It does not claim the full factory algorithm.
