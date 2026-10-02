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
Invalid union inputs retain the pinned generator's `No union types matched`
diagnostic. Required argument counting ignores extra arguments and does not
invoke an author-modified arguments iterator. Focused random tests verify these
behaviors alongside captured view brands and shadowed buffer/offset properties.

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
String algorithm identifiers now pass through the source-created ordinary
Algorithm dictionary. Its own `name` data property bypasses inherited setters,
while inherited parameter getters remain observable at the source read positions.
A focused native test verifies inherited cSHAKE length/buffer fields and the
original inherited name-getter exception for an author-supplied object.

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
engine exposes SharedArrayBuffer. Other SubtleCrypto method bindings remain
pending; no complete WebCrypto/LibJS parity is claimed.

Native CryptoKey wrappers now preserve actual source record identity and the
source secure-context interface, illegal constructor, tags, readonly attribute
descriptors, getter names, and receiver brands. Algorithm getters convert the
existing source metadata caches to actual mutable engine objects, including
nested hash objects and real Uint8Array RSA public exponents. Repeated getters
return the same actual object; native algorithm replacement invalidates that
cache, while author metadata edits do not alter the key's internal algorithm.
Usages are real frozen arrays and preserve the source cache after an internal
usage-vector change. Property construction and freezing use captured engine
intrinsics and avoid author setters or replaced Object methods.

All four focused key-wrapper cases pass with `-gc none`; the six-case native
digest regression also passes after the shared result-converter extension.
Tests cover every internal algorithm record shape, mutable nested metadata,
cache invalidation, frozen usages, brands/properties, poisoned setters/methods,
independent native globals, and secure-context exposure. Native wrapper/cache
roots currently survive until Runtime close. The owning native global supplies
the typed realm cache key; this does not reconstruct LibJS's WrapperWorld weak
cache graph or add native structured-clone wrapper deserialization.

SubtleCrypto.generateKey now performs the source IDL argument conversions,
normalizes actual algorithm property getters in source order, and invokes the
existing native algorithms on the owning deferred task. Its actual Promise
resolves to native CryptoKey wrappers or an ordinary key-pair object. Usage
sequence conversion precedes algorithm name reads, retains duplicates/order,
and follows the pinned generator's direct iterator loop, including its lack of
IteratorClose on an element-conversion failure. AES generation keeps the
supplied usage vector, as the source class body does. RSA validates the exponent
view before hash normalization and copies its bytes afterward, preserving hash
getter mutation. Numeric fields use source unsigned conversions and nested
hash dictionaries use the existing copied digest normalization.

Four focused native generation cases pass with `-gc none`, exercising all 24
registered generation names, source getter/iteration order, boolean/numeric
conversion, copied RSA exponent timing, metadata/usage filtering, and immediate
versus deferred rejection precedence. The source hash helper's assertion for
non-string/non-object input remains the typed adapter's explicit TypeError
instead of a native process abort. Iterator diagnostics safely represent
primitives, arrays, functions, and ordinary objects; uncommon engine-specific
class-name diagnostics remain part of the missing complete VM class graph.
Remaining native methods include import/export, encryption, signing,
derivation, wrapping, and KEM operations. Native generation does not supply
LibJS Promise/builtin/WrapperWorld parity.
