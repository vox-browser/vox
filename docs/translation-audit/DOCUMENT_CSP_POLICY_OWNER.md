# Document CSP policy-owner projection

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/BlockingAlgorithms.cpp:402–416`,
`DOM/Document.cpp:10717–10727` and
`TrustedTypes/TrustedTypePolicyFactory.cpp:245–246`.

The document inline CSP, initialization and Trusted Types policy projection
previously parsed only `Document.enforced_meta_csp_policies()` compatibility
strings. A genuine Window document therefore omitted response-derived header
policies even though Fetch and Base checks already used its actual settings
container. Combining both stores would also count a Meta policy twice once
concrete Meta insertion appends it to that actual container.

The shared projection now selects the current Document's real relevant settings
policy container whenever that owner exists. It reuses the existing CSP policy
conversion, retaining list order, source, disposition, directive values and
stored self-origin. Compatibility strings contribute no additional policy in
that path. Standalone DOM documents without relevant settings continue to use
the explicit Meta-string adapter. No policy matcher or parser is introduced.

Three focused cases in `html/csp_policy_owner_test.v` use genuine Page,
navigation Document, Window and response-derived policy owners. They prove
header enforcement despite a stale permissive Meta string, exactly one ordered
contribution per actual policy, enforce/report dispositions, stored tuple
origins and Trusted Types directive projection. Empty actual settings do not
inherit a restrictive compatibility string; replacing their actual container
changes enforcement, and real element adoption selects the destination
Document's settings. A standalone document retains both inline blocking and
Trusted Types Meta-string projection. Document CSP initialization is also
exercised through the shared projection.

The clean pre-fix run failed both genuine-owner cases and passed the standalone
case (`Build/audit-fixes/source-csp-policy-owner-original-default.log`). The
post-fix default run passed all three cases in 13.18 seconds
(`source-csp-policy-owner-default.log`). The initial GC-none neighbor batch
passed six of seven files but exposed two existing Trusted Types global
fixtures that attached a real Window and then modified only compatibility
strings (`source-csp-policy-owner-gc-none.log`). Those fixtures now install
response-derived policies in their genuine settings container, preserving the
real cached-factory and default-policy assertions.

That migration exposed a second provenance error: the global Trusted Types
factory projected its real realm settings list and then appended the document
helper's projection of the same list. The intermediate clean batch retained
six passing files but failed the exact-one-violation assertion with two
violations (`source-csp-policy-owner-clean-gc-none.log`). The global factory
now returns the one actual settings list immediately when available. Its
Window/document fallback remains explicit for construction without those
settings. The exact-one-violation assertion is preserved.

The final clean GC-none batch passed all seven files in 91.98 seconds:
new owner tests, existing inline CSP bridge, standalone Trusted Types bridge,
real global Trusted Types bindings, actual Base CSP owners, full-parser Base
ordering and the CSP blocking/violation engine
(`source-csp-policy-owner-final-gc-none.log`).

This is the single-owner projection prerequisite, not complete native policy
container translation. `dom.Document.policy_container()` remains a placeholder;
initialization obtains the available actual settings projection at that
boundary. HTML still stores serialized policy records and materializes CSP
engine lists for consumers, and its existing opaque-origin conversion does not
retain nonce identity. Inline violation reporting/global context fields and
the existing initialization directive representation remain open. Concrete
Meta insertion into that actual container is a separate feature.
