# Source shared tuple origin for resource URLs

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibURL/URL.cpp:347–409`, especially `381–384`.

The pinned Source contains an explicit resource-scheme branch: internal
`resource:` URLs share a tuple origin with scheme `resource`, empty host and
null port. That origin is independent of the URL's own authority or path, so
internal documents and worker scripts pass the same-origin check. The V URL
record instead grouped `resource` with `file`, returning a newly created opaque
file origin on every invocation.

The URL origin body now translates Source's resource branch directly and
retains the separate default opaque-file branch for file URLs. The actual DOM
URL cache, typed Origin wrapper and CSP response projection consume this same
LibURL operation; no serialized origin reparse, nonce reconstruction or numeric
cast is introduced.

Focused cases in `dom/resource_url_origin_owner_test.v` inspect a genuinely
cached relative URL's authority/port and the resulting empty-host/null-port
tuple. They require shared identity across resource URLs while retaining
ordinary HTTPS host/port distinctions and default file/data opaque behavior.
`fetch/resource_response_policy_origin_test.v` consumes that actual cached URL
and HeaderList through a real Fetch Response, then checks both CSP policy
origins and cloned serialized metadata. Both focused files failed behaviorally
before the Source branch fix in 27.52 seconds
(`Build/audit-fixes/source-resource-url-origin-original-default.log`); the
default file/data/HTTPS control passed. The corrected default two-file batch
passed in 26.96 seconds (`source-resource-url-origin-default.log`). The GC-none
four-file batch passed in 45.28 seconds (`source-resource-url-origin-gc-none.log`),
covering both new consumers, existing URL origin behavior and genuine CSP
response owners. The original behavioral failures remain retained separately.

This completes the pinned resource-origin branch. Source's separate process-wide
file tuple-origin opt-in (`URL.cpp:335–345,400–401`) is not translated by this
change; the default file behavior is deliberately preserved. Blob URL entry
ownership, the compact DOM URL wrapper and full native Response/Policy/GC
ownership keep their existing boundaries. Other CSP matching helpers must be
audited against their own Source bodies rather than inferred from this branch.
