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

The generated JsonWebKey conversion now creates present members in the pinned
IDL parser's lexicographic order, including `d,r,t` for RSA other-prime records.
Absent fields remain absent, and false booleans/empty sequences remain present.
The focused dictionary-order test passes for both the typed dictionary object
and the Promise result DTO. This corrects observable native `Object.keys`
order without sorting unrelated key-algorithm metadata objects.

SubtleCrypto.exportKey now converts the actual KeyFormat enum before checking
the CryptoKey brand, and returns an actual owning Promise. The source service
performs internal algorithm normalization, extractability validation, and native
format export inside its deferred work task. Results become actual ArrayBuffers
or ordinary JWK objects with source data descriptors and property order; neither
author edits to key metadata nor edits to exported bytes alter internal keys.

All three focused export cases pass with `-gc none`, covering raw-secret/JWK
results, getter and enum failures, original thrown objects, missing arguments,
receiver/key brands, immediate/deferred error precedence, captured property
construction, task ownership, and pending settlement after Runtime close.
The existing host deferred-task and Promise relay adaptation remains explicit;
this slice does not reconstruct the missing complete LibJS runtime graph.
Remaining native methods include import, encryption, signing, derivation,
wrapping, and KEM operations.

Concrete import bodies now decode the already-converted JsonWebKey DTO without
applying the separate CryptoBindings JSON parser's mandatory-kty rule. Source
importKey dictionaries allow absent optional members and let class usage/type
validation decide the error. Public parse_json_web_key/unwrap retains its source
mandatory-kty check. Two focused cases pass, checking that boundary and source
AES/HMAC/KMAC/RSA/EC/Ed25519 class validation for absent key type.

SubtleCrypto.importKey now follows the pinned generated BufferSource/JsonWebKey
union, KeyFormat enum, dictionary, boolean, AlgorithmIdentifier, and KeyUsage
sequence conversions using actual engine values. Optional JWK members are read
in lexical order and use source DOMString/boolean/sequence conversions, including
nested RSA other-prime dictionaries and original thrown objects. The source
ImplementedInBindings format/union check runs after every argument conversion.
Raw SharedArrayBuffer follows the pinned generator's dictionary fallback;
shared views and resizable buffers retain generated binding restrictions.

Raw bytes are copied after usage iteration and before algorithm getters.
Normalized parameters are copied in source order before the owning deferred
import operation, preserving nested hash and unsigned-length conversion.
The actual Promise resolves to a native CryptoKey wrapper; common metadata
installation preserves the source sorted usage vector and empty-usage rejection.
All five focused native import cases pass with `-gc none`, including all 29
registered import names, source-supported raw/public/SPKI formats, JWK coercion,
validation precedence, getter mutation, detached-buffer boundaries, and optional
shared/resizable cases when exposed by the engine. ML-KEM JWK remains the pinned
source's unsupported operation. The existing task/Promise relay, typed UTF-8
string DTO, assertion/error, and WrapperWorld GC boundaries remain explicit.
Remaining native methods include encryption, signing, derivation, wrapping,
and KEM operations; this slice does not claim complete LibJS runtime parity.

Native SubtleCrypto.encrypt/decrypt now convert actual receiver/key/buffer
brands, normalize RSA-OAEP/AES/ChaCha parameter getters in source order, copy
parameters and input bytes, and invoke the owning native source service.
Deferred work is followed by the source crypto settlement task and existing
owner Promise relay. RSA labels retain nullish omission; AEAD optional fields
use property presence, copied buffers, and modulo unsigned tag lengths.

All three focused cipher cases pass with `-gc none`: a known AES-GCM vector
checks getter order, copied IV/input timing, actual ArrayBuffer results, and
separate work/crypto task settlement; all six registered cipher names perform
native encrypt/decrypt round trips; binding failures preserve original throws
and source immediate/deferred algorithm/usage/authentication error precedence.
Signing, derivation, wrapping, and KEM native method bindings remain pending.
Documented native task/Promise, UTF-8 DTO, assertion, and wrapper GC boundaries
continue to apply; no JavaScript substitute cryptography is introduced.

Native SubtleCrypto.sign/verify now convert actual key/buffer brands and source
RSA-PSS, ECDSA, Ed448/ML-DSA context, and KMAC parameter getters before copying
inputs. Verify copies the signature before the message, matching the pinned
body; the typed service copy order is corrected as well. Results settle through
the owning work/crypto tasks as actual ArrayBuffers or boolean Promise values.
KMAC output length uses required-member presence and EnforceRange conversion;
context/customization buffers retain source presence/copy semantics.

All three focused signature cases pass with `-gc none`, covering upstream HMAC
and NIST KMAC vectors, source getter/copy timing, explicit crypto settlement,
original thrown values, generated argument error order, and deferred key/usage
validation. All 11 registered signature names produce real native signatures,
verify successfully, and reject modified signatures with false. Derivation,
wrapping, and KEM native method bindings remain pending. Existing host/VM,
string DTO, assertion, and wrapper GC limits remain documented.

Native deriveBits/deriveKey now perform source argument, nullable unsigned
length, key brand, and actual KDF/exchange parameter conversions. HKDF/PBKDF2
preserve their distinct hash/buffer/numeric read order; Argon2 uses required
property presence, EnforceRange, and optional copied inputs. ECDH/X25519/X448
retain real public CryptoKey records, including source ToObject nullish errors.
Omitted optional length is supplied as undefined without reading inherited
argument properties. Source deferred settlement does not add a crypto task.

Derived-key import and key-length normalization now retain separate snapshots
from two reads of the original actual destination object. Changing name/hash
getters therefore affects each source stage independently. The existing typed
API delegates unchanged values to the same source operation body.

All four focused native derivation cases pass with `-gc none`, covering all
eight registered derivation names, RFC HKDF/PBKDF2/Argon2 vectors, bilateral
EC/X exchange results, distinct destination snapshots, copied inputs, boolean/
unsigned/optional conversions, original throws, and immediate/deferred error
order. The five-case typed SubtleCrypto binding regression also passes.
Wrapping and KEM native methods remain pending; existing host/VM/DTO/wrapper
limits continue to apply.

Native wrapKey/unwrapKey now perform source enum, key/buffer, algorithm,
boolean, and usage conversions and enter the owning deferred operation.
Wrap/unwrap normalization retries the original actual algorithm through
source encrypt/decrypt fallback after any first-pass error, preserving repeated
name reads and getters that change or initially throw. Unwrap copies wrapped
bytes after destination normalization. Source's current FIXME settlement runs
directly in deferred work, without adding a crypto settlement task.

The typed operation now explicitly normalizes export after extractability and
parses unwrap JWK JSON before class import, preserving the mandatory-kty parser
rule distinct from ordinary optional-field import dictionaries. All four
focused host cases pass with `-gc none`: RFC 3394, all seven supported wrapping
operations, real key/byte results, JWK round trips, fallback/copy getter order,
binding versus deferred validation, and unwrap JSON parse precedence.
The four KEM native methods remain pending; documented VM, DTO, host scheduling,
assertion, and wrapper ownership limits continue to apply.
