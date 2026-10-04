# Document CSP initialization reads its own policy list

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/Document.cpp:10717–10728`,
`ContentSecurityPolicy/Directives/Directive.h:72–76`, and
`ContentSecurityPolicy/Directives/SandboxDirective.cpp:21–42`.

Source's Document initialization loop iterates the Document's own policy
container, then each policy's directives, initializes each with the Document
context, and verifies Allowed. The V callback reused the inline/global policy
helper. That helper intentionally reads relevant settings for genuine Windows
and standalone Meta strings without settings. Neither read is Source's
Document initialization owner.

The initialization projection now reads `document.policy_container().csp_list`
and uses the existing typed-origin-preserving CSP record projection. The
actual callback runs each directive with the Document context and retains
Source's production-active Allowed invariant. The global/inline helper keeps
its different, Source-required settings owner. No cached policy or fallback
string is merged into Document initialization.

Two focused cases use actual retained Document containers. A genuine Page and
Window case reassociates the original Window with another Document after
header, report-only and Meta policies are installed. Initialization still sees
the original three policies in Source order, their directive order, the real
tuple port and opaque Meta nonce; inline/global policy reads simultaneously
see the replacement container. Direct replacement of the original Document's
own container refreshes initialization independently. The second case gives a
Document without Window settings a real response-derived container and a
distinct stale compatibility Meta string; initialization reads only the actual
container. Both cases call the real Document initialization entry point.

Pinned Source's default directive initialization has no effect and returns
Allowed. Its sole Sandbox override also returns Allowed for Documents; only
an enforced Worker context can block. The tests preserve that distinction and
unchanged active sandbox flags. They do not add callbacks, counters, synthetic
directives or invented Document-side effects to manufacture an observable
initialization result.

The new initialization projection initially delegated to the existing helper,
retaining the original selection for the baseline. Both genuine owner cases
failed in 53.06 seconds
(`Build/audit-fixes/source-document-csp-initialization-original-default.log`):
the reassociated Document got two replacement policies instead of its own
three, and the Document without settings got its single compatibility string
instead of its two real header policies. The corrected two-case file passed
with default GC in 48.39 seconds
(`source-document-csp-initialization-default.log`). The final GC-none batch
passed all five files in 191.09 seconds
(`source-document-initialization-meta-settings-gc-none.log`): the new
initialization cases, current-settings Meta reassociation, existing inline
policy owner, Meta lifecycle and typed-origin projection. Actual initialization
and consumer ownership are checked without garbage collection.

The V bridge still materializes CSP engine lists from shared serialized records;
full GC policy-list identity and complete constructor/realm ownership remain
separate. This feature corrects the policy read and Source loop; it does not
claim full Document construction or all CSP parity. Meta CSP append remains
explicitly routed through relevant settings per `HTMLMetaElement.cpp:221`,
unlike this loop, Meta referrer and SourceSnapshot cloning.
