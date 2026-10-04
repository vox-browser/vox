# CSP policy origin record copying

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`ContentSecurityPolicy/Policy.cpp:147–160,199–213` and
`ContentSecurityPolicy/PolicyList.cpp:30–37`.

Upstream serializes and reconstructs policies by copying the actual Origin
record. The V settings-to-Fetch/CSP adapter previously replaced every opaque
origin with a zero standard nonce and reparsed tuple serialization as a URL.
That erased real opaque identities and file-origin types, and normalized an
explicit tuple port 443 into an absent port.

The existing DOM Origin typed accessor is now public. The adapter copies its
actual URL Origin directly, preserving nonce, opaque type and tuple fields.
The explicit untyped legacy opaque adapter keeps its prior zero standard
fallback; invalid non-opaque legacy input retains its fatal invariant. No new
origin identity, CSP parser or matching algorithm is introduced.

Three focused tests reconstruct response-derived policy records and verify
two distinct nonzero opaque identities for both standard and file types, an
explicit HTTPS port 443, unchanged serialized input, ordered disposition and
source metadata, raw policy text, and the existing legacy fallback.

The first attempted regression compiled but could not link because this
private worktree lacked its ignored native regex archive
(`source-csp-origin-original-default.log`); it is no behavioral result.
The repository's pinned backend builder then produced the archive. With that
backend present, the unmodified implementation failed both real-origin cases
and passed the legacy case
(`source-csp-origin-original-default-with-backend.log`,82.1s).
The corrected focused default run passes (`source-csp-origin-focused-default.log`,96.7s).
The final GC-none batch passes **3/3 files**: origin reconstruction, existing
CSP bridge and Fetch security policy
(`source-csp-origin-existing-neighbors-gc-none.log`,156.3s).
A nonexistent newer-neighbor invocation remains separately retained as
`source-csp-origin-owner-gc-none.log` and is not counted as a test run.
All these logs are in the private
`Build/audit-fixes/worktrees/root-source-memory-store/Build/audit-fixes/`.

HTML continues to store serialized policy records and materialize engine lists
for consumers. Native Document policy storage, full violation reporting,
Meta lifecycle insertion and complete realm/collector ownership retain their
separate audit boundaries. This slice fixes real origin record copying only.
