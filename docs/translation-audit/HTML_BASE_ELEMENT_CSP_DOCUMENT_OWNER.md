# Actual HTMLBaseElement CSP Document owner

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLBaseElement.cpp:84–110` and
`ContentSecurityPolicy/BlockingAlgorithms.cpp:679–722`.

The native Base frozen-URL method omitted Source's CSP condition. Parsed
URLs therefore became the actual Document base even when its genuine Window
settings policy container blocked them with `base-uri`. Report-only policies
also produced no violation notification through this call path.

The existing native Document CSP boundary now has a typed Document/URL check.
The real Window/Document/settings attachment installs that check before any
parser is needed, preserving existing inline and initialization callbacks.
The ordinary parser CSP installer retains the same check. Its HTML callback
reads this actual Document's relevant settings object and uses the existing
settings policy-container projection and translated CSP blocking algorithm.
Raw Meta compatibility strings are not merged into that actual policy list.

The native frozen-URL method follows Source short-circuit order: parse failure,
`data:` and `javascript:` return the Document fallback without invoking CSP;
a CSP-blocked parsed URL also returns that fallback. Allowed URLs retain the
existing freeze and actual Document base-change response. Report-only failures
report through the existing queued violation path and continue to freeze the
URL. No new matching or URL-resolution algorithm is introduced.

Five focused cases in `html/base_csp_document_owner_test.v` create actual
Pages, navigation Documents, Windows, settings and response-derived header
policy containers. They prove enforce-policy blocking before any parser,
same-origin `'self'` matching and foreign-origin blocking, Source URL
short-circuit behavior with exactly one queued violation, report-only
notification with no `base-uri` default fallback from `default-src`, current
destination settings after real Base adoption between distinct Pages, and
callback retention through a real full parser followed by genuine
`head.innerHTML` fragment insertion. Real deferred, trusted violation events
carry `inline`, `base-uri` and their actual enforcement/report disposition.

The first fixture diagnostic was an old-compiler nested-unsafe restriction;
using a stable actual EventTarget handle corrected it without changing the
implementation. That log remains in
`Build/audit-fixes/source-base-csp-gate-original-default.log`. The clean
pre-fix run failed all five cases
(`source-base-csp-gate-clean-original-default.log`). The clean post-fix default
run passed all five cases in 37.99 seconds
(`source-base-csp-gate-default.log`). The clean GC-none batch passed all nine
files in 236.91 seconds, covering the new gate, queued violation owners,
existing inline CSP bridge, document elements, complete Window context suite,
creator base snapshot, native Base lifecycle, raw handler attributes and CSP
blocking/violation engine (`source-base-csp-gate-gc-none.log`).

This is the actual settings-owned Base CSP condition and installation.
Standalone DOM construction without an HTML relevant settings owner retains
its explicit allow compatibility path. Genuine Meta insertion into the
settings policy container remains separate. The existing full-parser final
Base replay remains pending a separate Source correction; the fragment case
does not claim it. Existing CSP Violation URL snapshots, event-initialization
timing, referrer/status projection, full Realm/clock behavior, disconnected
element retargeting and report endpoint execution remain open as documented
by the queued-violation owner prerequisite. No full CSP or parser parity is
claimed.
