# Queued CSP violation current Document owner

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Violation.cpp:267–315`, especially
the Window associated-document selection at lines 301–305.

The existing V settings-to-CSP projection captured the responsible Document
when the projection was created. Its eventual queued violation event therefore
kept targeting that Document after the actual Window association changed.
A projection constructed before the Window acquired a Document instead kept
the Window as the event target even after real Document construction.

`EnvironmentSettingsObject.fetch_request_client_csp_global` now retains the
actual global EventTarget identity and its Window/Worker kind. Its existing
unspecified-source, null-document task reads the genuine native Window's
current associated Document when executing, following the Source selection.
Workers retain their actual global EventTarget. The existing null-global or
unassociated-Window compatibility cases continue without dispatching to a
substitute owner. No new task transport, Realm, Window or Document is created.

Three focused cases in `html/csp_violation_document_owner_test.v` use the actual
navigation Document/Window/Page constructors and actual CSP blocking algorithm.
The replacement case queues an enforce-policy violation, changes the real
Window association, deactivates the old native navigable and proves the
null-document task remains runnable and reaches only the replacement Document.
The construction-order case creates a genuine Window/settings before its
Document, obtains the CSP projection, then completes the actual Document
constructor and verifies that the queued event targets that Document. The
Worker case proves the real worker target and a runnable null-document task.
All events remain deferred, trusted `securitypolicyviolation` events.

The initial fixture incorrectly propagated an Option from a Result-returning
helper; that compile diagnostic is retained in
`Build/audit-fixes/source-csp-violation-owner-original-default.log`. Its clean
pre-fix run compiled and failed the two actual Window cases while the Worker
case passed (`source-csp-violation-owner-clean-original-default.log`). The clean
post-fix default run passed all three cases in 18.51 seconds
(`source-csp-violation-owner-default.log`). The clean GC-none six-file batch
passed in 82.37 seconds, covering the new owner cases, actual fetch security,
Window/Document identity, UniversalGlobalScope queue ownership, Source timer
tasks and the existing CSP blocking/violation engine
(`source-csp-violation-owner-gc-none.log`).

This is the execution-time global/associated-document event-target prerequisite.
The existing CSP projection and Violation record still snapshot the URL and
construct event data before the queued task; Source `Violation::url` and the
event-initialization timing remain separate translation work. Referrer/status
projection, disconnected element retargeting, full Realm/time-stamp behavior,
report endpoint execution and native global-wrapper ownership also remain
outside this bounded change. The actual Base CSP condition and Meta policy
insertion into the genuine settings policy container are separate features.
