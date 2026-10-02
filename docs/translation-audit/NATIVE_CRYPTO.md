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

SubtleCrypto.digest now uses the actual owning native service, its source
normalization and cryptographic backend, and a real engine Promise. Generated
binding receiver/argument errors become Promise rejections; actual engine
getter and conversion failures retain their original thrown value. Primitive
AlgorithmIdentifier string conversion and top-level BufferSource conversion
precede normalization. Algorithm name/cSHAKE getters execute before the source
data copy. Copies consult captured engine internal-slot operations and preserve
offset views, detached/out-of-bounds empty input, and the source difference
between restricted IDL arguments and unrestricted algorithm buffer fields.

Successful digest results are actual ArrayBuffer objects. Deferred operation
work and the crypto settlement task remain separate on the owning HTML loop.
The existing native Promise capability bridge relays settlement through an
owning HTML microtask before JavaScriptCore's own Promise reactions; this is an
explicit native host adaptation, as is the owning unspecified task replacing
EventLoopPlugin deferred invocation. Neither changes the native digest backend
or runs a JavaScript replacement hash algorithm.

All six focused native digest cases pass with `-gc none`. They cover known
SHA-256/cSHAKE vectors, copied DataView offsets, getter mutation/detachment,
buffer/view detachment, original thrown objects, missing arguments/receiver
brands, Symbol/BigInt conversion, source normalization/parameter order, deferred
operation errors, poisoned engine builtins, independent worker ownership, and
pending settlement after Runtime close. Shared-buffer cases execute when the
engine exposes SharedArrayBuffer. Other SubtleCrypto method bindings and native
CryptoKey wrappers remain pending; no complete WebCrypto/LibJS parity is claimed.
