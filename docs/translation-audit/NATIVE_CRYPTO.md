# Native Crypto binding translation

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The native QuotaExceededError binding translates the source constructor and
nullable quota/requested attributes. It wraps the actual WebIDL record through
the shared DOMException identity map, retains its subclass prototype, and
preserves original engine exceptions during dictionary property reads and
primitive conversion. Numeric conversion uses the real engine ToNumber
operation, including BigInt rejection, before the source range checks.

Focused native tests cover defaults, subclass construction, source field order,
range/nonfinite errors, original thrown-value identity, and repeated wrapping
of the same native exception record. Wrapper records remain rooted until the
owning Runtime closes. This native JavaScriptCore adapter does not establish
LibJS builtin/realm parity or native structured-clone wrapper reconstruction.

CryptoHost binds the owning Window/Worker scope's concrete Crypto service.
Its actual engine objects retain the same native Crypto/SubtleCrypto identities,
source prototypes, tags, illegal-constructor and receiver checks. Secure-context
exposure controls subtle/randomUUID. getRandomValues validates real engine view
brands, shared/resizable backing restrictions from the pinned IDL generator,
and detached-view witnesses, then invokes the source random-byte operation and
overwrites only the actual view span. It returns the original input object.

Focused host tests cover every integer typed-array kind, offset writes, shadowed
properties, native record identity, UUID format, unsupported brands/kinds,
detached/resized views, actual quota subclass fields, secure-context exposure,
and independent global records. The existing typed Crypto core tests also pass.
SubtleCrypto operation exposure is the next independent binding slice; the host
currently exposes its owning same-object record without claiming its methods.
