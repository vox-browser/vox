# Crypto module V translation — implementation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Crypto`

Translation workspace: `~/code/vox2/webcrypto`
Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`
Latest focused verification: 2026-10-04

The numeric parameter and normalized key-usage slices now follow Ladybird
`2919bf87a5e5` (2026-11-08). Integer conversions enforce their WebIDL range,
and public generation/import results expose sorted usages without duplicates.
The older verification notes below retain their original source pins.

All six upstream Crypto `.cpp` implementation units have an audited V
implementation mapping. The V package is named `webcrypto` so that it can
import V's standard `crypto.*` primitives without shadowing that namespace.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Crypto.cpp` | `crypto.v` |
| `CryptoAlgorithms.cpp` | `crypto_algorithms.v`, `hmac.v`, `kdf.v`, `argon2.v`, `native_kdf.c.v`, `native_kdf.h`, `aes_ocb.v`, `cshake.v`, `kmac.v`, `native_crypto.c.v`, `native_crypto.h`, `exchange_curves.v`, `ed25519.v`, `ed448.v`, `native_edwards.c.v`, `native_edwards.h`, `mldsa.v`, `mlkem.v`, `native_ml.c.v`, `native_ml.h`, `rsa.v`, `rsa_key_formats.v`, `native_rsa.c.v`, `native_rsa.h`, `ec.v`, `ec_key_formats.v`, `native_ec.c.v`, `native_ec.h`, `okp_der.v` |
| `CryptoBindings.cpp` | `crypto_bindings.v` |
| `CryptoKey.cpp` | `crypto_key.v`, `crypto_key_objects.v`, `crypto_key_utf16.v`, `crypto_key_serialization.v`, `html/structured_crypto_key_codec.v` |
| `KeyAlgorithms.cpp` | `key_algorithms.v` |
| `SubtleCrypto.cpp` | `subtle_crypto.v`, `subtle_crypto_binding.v`, `html/crypto_operations.v` |
| concrete `AlgorithmMethods` subclasses | `upstream_algorithm_classes.v` |
| parameter parsing, DER/JWK helpers, registry and shared entry points | `crypto_protocol.v` |

Implementation-unit and function inventories establish source mapping; they do
not establish semantic parity. Registered algorithms with unavailable operation
bodies remain unfinished translation work.

The port covers secure random values and UUIDv4 generation, the WebCrypto IDL
enums and JWK conversion, key metadata, stable tagged structured serialization
for every internal key-handle and algorithm variant, secure handle clearing,
realm-scoped algorithm and frozen-usage binding caches, algorithm normalization
and per-operation registration, key-usage and extractability checks, raw and
JWK import/export, key generation and derivation, wrapping and unwrapping, and
typed encapsulation boundaries.

Available backends implement SHA-1, SHA-2, SHA-3, AES-CBC, AES-CTR,
general-IV/general-tag AES-GCM, AES-KW, AES-OCB, HMAC, HKDF, PBKDF2,
Argon2, Ed25519, Ed448, X25519, X448, ChaCha20-Poly1305, KMAC128/256, and cSHAKE128/256. AES-OCB
and KMAC use the native OpenSSL EVP operations called by upstream LibCrypto;
OpenSSL headers use Homebrew prefixes on macOS and `pkg-config openssl` on
other platforms. cSHAKE preserves upstream's
restriction to empty functionName/customization. Focused tests include all 18
upstream AES-OCB fixtures and six upstream SP 800-185 KMAC vectors.

X25519/X448 generation, public-key generation, and exchange use the same
upstream EdwardsCurve EVP calls. Ed448 generation/signing/verification preserve
its EVP context-string parameters. Completed key formats include each source
family's raw variants, SPKI, PKCS8, and JWK; JWK import checks the native derived
public key against the supplied x member. X448/Ed448 retain their source raw-only
public format (no raw-public alias). DER parsing preserves source scope behavior:
outer data and CurvePrivateKey octets require exact consumption, while upstream
Certificate parsing discards unread bytes inside no-parameter algorithm scopes
and does not apply raw/JWK length checks to DER key material. Focused tests use
both upstream RFC7748 exchanges and all nine upstream RFC8032 Ed448 fixtures,
including explicit contexts and the 1023-byte message.

ML-KEM-512/768/1024 generation, encapsulation, and decapsulation now use the
upstream native EVP calls. Source key formats include raw-public, raw-seed,
SPKI, and PKCS8; the upstream JWK TODO remains unsupported. Tests include all
three upstream deterministic seed/public/DER fixtures and fixed ciphertext to
secret vectors, native implicit rejection, direct and asynchronous shared-key
imports, and copied ciphertext. The ASN.1 expandedKey/both branches retain the
current upstream constructed-scope nesting, including its rejection of ordinary
primitive expandedKey encodings. DER diagnostics use the V parser's messages.

ML-DSA-44/65/87 now perform native generation, context-aware message signing,
verification, and raw-public/raw-seed/SPKI/PKCS8/JWK operations. Fixed upstream
WPT signatures and seed-derived public keys pass for every parameter set.
Its JWK imports accept the signing use `sig` and reject unrelated declared uses,
following `2919bf87a5e5`. Raw/JWK metadata is
set by the SubtleCrypto import boundary; DER scope behavior matches ML-KEM.
Native failures in source MUST-wrapped raw-seed/JWK generation become explicit
OperationErrors rather than terminating the process.

RSA-OAEP, RSA-PSS, and RSASSA-PKCS1-v1_5 now perform native key generation,
OAEP label-aware encryption/decryption, PSS salt-aware signing/verification,
PKCS1 signing/verification, and SPKI/PKCS8/JWK import/export. Source BIGNUM
validity checks include CRT modular constraints and the first key representation.
Twenty upstream WPT operation vectors pass across all four RSA hashes, plus
exact DER round trips, JWK formats, native wrapping/unwrapping, validation and
Promise tests. Retained source quirks include OAEP decrypt's encrypt error text,
partial-CRT JWK requirement checks, unread inner RSA DER data, and the shared
key_ops helper rejecting mixed encrypt/wrap or decrypt/unwrap usages even in
exported JWKs. Exporting a private key without prime factors returns an explicit
OperationError instead of the source's MUST-style failure.

ECDSA/ECDH now use upstream's native EC key generation, generator/public-point
multiplication, signature operations, compressed-point decoding, and point/key
consistency checks for P-256/P-384/P-521. Raw/raw-public, SPKI, PKCS8, and JWK
formats reach those operations through typed and asynchronous dispatch. Tests
include all twelve upstream WPT ECDSA curve/hash signatures, exact DER fixtures,
all three LibCrypto shared-point vectors, nullable/zero/non-byte-aligned ECDH
lengths, real derived/wrapped keys, and deferred input copies. Fixed-width scalar
octets retain the source's key-handle serialization width.

Retained EC source quirks include verification ignoring an odd final signature
byte, raw point import skipping point/curve-width validation, compressed raw
decoding selecting a curve by encoded width, and PKCS8 private keys without an
optional public point skipping scalar validation. PKCS8 export preserves the
existing optional inner fields; private JWK export recomputes its public point.
Inner DER scope leftovers are discarded, while outer data must be exact. DER
diagnostics use the V parser's messages. Unsupported ECDH formats fail explicitly
instead of dereferencing the source's unset key/result.

HKDF/PBKDF2 now call the source EVP_KDF provider operations instead of local
derivation loops. Length, iterations, supported hashes, raw/raw-secret imports,
and validation order follow the source bodies; HKDF returns an empty result
before hash dispatch for zero length, while PBKDF2 delegates zero output to EVP.
The installed provider accepts that zero output. Tests include six upstream
HKDF and all seven upstream PBKDF2 vectors, native failure, validation order,
and deferred copied salts/zero-length settlement.

Argon2d/i/id now call upstream's native EVP_KDF operations with nonce, lanes,
memory, passes, version, tag size, the native thread cap, and optional secret/
associated data. Source validation order, the 24-bit parallelism bound,
raw-secret-only imports, and integer-divided non-byte-aligned output lengths
are retained. All three upstream RFC9106 secret/associated-data vectors pass,
along with invalid parameters, native failure, 256-lane generation, real
deriveKey, and deferred BufferSource copy tests.

HMAC now uses the upstream EVP_MAC operation sequence. Generation, raw/raw-secret
and JWK imports/exports, and get-key-length preserve source hash restrictions,
validation order, the optional bit length, and the JWK `use: "sign"` rule.
Fractional-byte imports discard the trailing byte; generation retains the shared
u16 random-helper truncation while metadata keeps the requested u32 length.
Native failures that trigger source VERIFY/MUST failures become explicit
OperationErrors, including signing with a zero-byte key after fractional import.
Tests cover upstream SHA-1/SHA-256/SHA-512 MAC vectors, exact-block input,
truncated signatures, source metadata and JWK rules, and deferred copied imports
and signatures.

Ed25519 now uses upstream's EdwardsCurve EVP generation/signing/verification,
32-byte typed private seed handles, SPKI/PKCS8/raw/raw-public/JWK bodies, and the
exact twelve-entry source small-order blacklist for both the public key and R.
Tests include all five upstream RFC8032 fixtures (including the 1023-byte
message), the WPT DER/signature fixture, fourteen small/mixed-order WPT cases,
metadata/validation order, malformed DER scopes, source native failures,
structured serialization, and deferred copied DER/messages and wrapping.
The old V compiler's first-branch result hoisting is avoided through explicit
conditional returns in typed generation dispatch.

Existing typed V raw-seed/64-byte raw-private convenience formats remain as
explicit compatibility extensions; their handles now store the source seed
and expanded export derives the public half natively. These formats are absent
from the pinned ED25519 AlgorithmMethods and are rejected by asynchronous
import/export/wrap bindings. No browser/VM Promise parity is implied.

AES-CBC, AES-CTR, AES-GCM, and AES-KW operation bodies now follow
`CryptoAlgorithms.cpp` and `LibCrypto/Cipher/AES.cpp` through native EVP calls;
the handwritten CBC padding, CTR increment loop, GHash/authentication, and key
wrap rounds have been removed. CBC preserves source IV/length checks and native
PKCS7 errors. CTR preserves the pinned implementation's behavior: it validates
the requested counter width but passes the complete counter to EVP, so the
native cipher increments all 128 bits and does not reject repeated-block limits
based on the requested width. GCM retains each tag size, general IVs, optional
AAD, and native authentication failures. KW retains the source's modulo-eight
wrap check and less-than-eight unwrap check, then reports actual EVP failures;
empty wrap yields the native empty result, while eight-byte wrap fails.

Their generation/import/export/get-length bodies preserve usage-first checks,
source errors, raw/raw-secret aliases, and each JWK validation order. CBC accepts
absent `alg`; CTR/GCM require `k` then `alg`; KW requires `alg` before decoding
`k`. AlgorithmMethods import leaves extractable/usages at their source defaults
for the common SubtleCrypto boundary to install. Malformed JWK export handles
produce CBC's `unclear key size` error, whereas CTR/GCM/KW omit `alg`, exactly as
the source does. Tests use four source CBC fixtures, nine source CTR fixtures,
84 source WPT GCM parameter combinations, six source KW fixtures, provider
failure cases, every supported key width/format, copied deferred parameters,
and source metadata/error ordering.

ChaCha20-Poly1305 now translates the source encrypt/decrypt/generate/import/
export/get-length bodies through `LibCrypto/Cipher/ChaCha.cpp` EVP calls. IV,
tag, short ciphertext, usage, JWK, and raw-secret checks retain source order and
errors. Provider failures carry the same operation expression text as upstream.
Its JWK branch admits decoded keys of any width, as the pinned source does;
actual encryption/decryption then reports the native 32-byte-key requirement.
Tests replay all 12 upstream WPT data/AAD fixtures and cover authentication,
empty data, copied deferred buffers, JWK ordering, and common metadata slots.
The earlier typed V `raw` import/export convenience alias remains explicitly
supported; source AlgorithmMethods and asynchronous import/export/wrap reject
that alias and accept raw-secret or JWK.

AES-OCB's further review preserves native EVP expression diagnostics,
usage-first generation/import, full length/contradiction errors, raw-secret-only
formats, default import slots until common metadata installation, omitted JWK
`alg` for malformed handles, and its distinct `Invalid key length: N` result.
The native adapter reports an OperationError for an invalid manually fabricated
key size where upstream GET_CIPHER asserts; it does not accept or operate on
that invalid key. Existing 18 source vectors and focused format/error/binding
checks pass.

AES CTR width, AES generation/derivation lengths, and AES-GCM/AEAD tag lengths
now use the translated LibJS StringToNumber and WebIDL integer operations for
primitive values, matching source wrapping/truncation/NaN/infinity handling.
Buffer reads retain source counter/IV/AAD-before-integer order. Explicitly
present undefined tagLength converts to zero, and undefined additionalData
fails BufferSource conversion instead of being omitted. Focused tests cover
negative/fractional/modulo values, boolean/null/string numeric inputs (including
radix literals and Unicode whitespace), omitted lengths, field presence, and
immediate/deferred error boundaries. Arbitrary JS object ToPrimitive/accessors
remain outside the json2/WebIDL typed host boundary pending the VM binding;
this change does not fabricate their execution.

EC DER lookahead now preserves the pinned decoder's initial high-tag-byte
condition and u8 kind truncation; shared sequence decoding retains the original
constructed bit even after consuming high-tag bytes. Focused tests include a
malformed optional curve tag that the source recognizes and rejects when it
contradicts the outer curve, avoiding the earlier skipped-validation behavior.
EC, Ed25519, Ed448 import, and X25519 format regression files pass.

KMAC import leaves usages/extractable at their source defaults until the
common public import or KEM boundary installs them. KEM imports invoke the
algorithm body directly and permit empty shared-key usages, including KMAC
and AES-OCB. Generation/import preserve quoted invalid-usage diagnostics and
source generation-before-common-empty-usage order. Focused tests cover bit
slicing, wrapped u16 generation sizes, class versus common metadata, copied
deferred imports, and real ML-KEM encapsulation/decapsulation.

RSA modulus/PSS salt lengths, PBKDF2 iterations, and optional HMAC/KMAC
lengths now preserve source ToUint32 wrapping, truncation, and undefined/null/
NaN/infinity behavior. PBKDF2 reads salt/iterations before hash; RSA reads
modulus/exponent before hash. Binding conversion retains integer presence and
source order, rejects BigInt, and copies buffers before deferral. Focused
tests exercise all affected parameter records and a real PBKDF2 derivation
with a wrapping iteration count; primitive object conversion remains bounded
by the explicit typed host limitation.

Argon2 parallelism/memory/passes/version and cSHAKE/KMAC output lengths now
use the source WebIDL EnforceRange conversion, including fractional truncation,
primitive string/boolean/null coercion, concrete range diagnostics, and
nonfinite/undefined rejection. Required and optional field presence follows
the source, and nonce/basic integers precede version/optional buffers. Tests
include copied native Argon2 RFC9106 output through fractional/string inputs,
range limits, required-member precedence, explicit undefined members, and
zero-length cSHAKE settlement.

X25519/X448 class imports now leave extractable/usages at the source defaults
for raw, raw-public where supported, SPKI, PKCS8, and JWK. The common typed and
asynchronous import boundaries install the final metadata and check requested
private usages after the source import body. Focused tests cover every source
format, class versus public slots, duplicate usages, and copied deferred DER
imports for both curves.

Ed448 raw/SPKI/PKCS8/JWK class imports likewise retain default metadata until
the outer SubtleCrypto import boundary installs it. Normalized asynchronous
import now invokes Ed448's class body directly. Focused tests cover all formats,
empty private usage checks, duplicate common usages, and native DER key handles.

ML-KEM class import preserves its source distinction: SPKI explicitly sets
supplied metadata, while raw-public/raw-seed/PKCS8 keep default slots. Common
public import installs normalized usages/extractability afterward. Focused
tests cover every parameter set and source format, duplicate/common usages,
empty private versus public usages, exact native handles, and copied deferred
seed import.

Buffer field normalization now retains source required-member ordering and
NotAnObjectOfType diagnostics. Present Ed448/ML-DSA contexts require a real
BufferSource, including undefined/null rejection; RSA-OAEP instead accepts
nullish labels as empty and rejects other invalid values. RSA publicExponent
requires the source Uint8Array brand and copies only the view's bytes. Focused
tests cover brands, offset views, optional/required presence, and earlier
buffer errors before invalid numeric fields. The native RSA generation test
now supplies and mutates an actual offset Uint8Array view.

EC namedCurve dictionaries now use source primitive ToString, including
omitted/undefined, null, boolean, numeric and BigInt binding inputs. Unsupported
curves reject during the actual deferred operation. Nested hash identifiers
normalize at their source read position, preserve source name diagnostics, and
validate cSHAKE parameters before discarding them for the hash-name record.
Focused tests cover primitive names, omitted curves, immediate nested errors
before later fields, and deferred curve failures. Arbitrary object ToPrimitive
and accessor execution remains an explicit typed host/VM boundary.

The synchronous typed generation boundary now performs the actual operation
before its common empty-usage check, including HMAC, RSA, EC, Ed/ML families,
exchange curves, and ChaCha20-Poly1305. Class methods still permit empty usages;
public generation rejects successful empty secret/private results. Focused
tests verify HMAC length/hash, EC curve, and native RSA generation errors win
before the common check, while successful empty generation remains rejected.

The compact native bridge now exposes Crypto random operations, the owning
SubtleCrypto record, and actual asynchronous digest with ArrayBuffer results.
Six focused native digest cases pass with `-gc none`, including original engine
exceptions, getter-before-copy ordering, parameter normalization, native
Promise/task settlement, and independent Window/Worker ownership. The native
Promise bridge adds its owning HTML microtask relay before engine reactions;
other SubtleCrypto script method bindings remain unfinished. Actual native
CryptoKey wrappers now preserve source record brands and the cached mutable
algorithm/frozen usages values, including real RSA Uint8Array exponents. Four
focused native wrapper cases pass with `-gc none`, and native digest regression
passes after the result-converter extension. Wrapper roots remain Runtime-owned;
LibJS WrapperWorld weak caching and native clone reconstruction remain distinct
runtime work.

Native generateKey now reaches all 24 registered algorithm names through the
existing source-derived native generation bodies. Four focused actual-engine
cases pass with `-gc none`, covering source IDL/property/parameter order,
RSA exponent copy timing, real key/pair metadata, and rejection precedence.
Source assertion edges use the existing explicit typed adapter rejection;
uncommon iterator diagnostic class labels still depend on the complete VM
class graph. Other native SubtleCrypto methods remain pending.
Native backend availability does not establish complete WebCrypto/VM parity.

`SubtleCryptoBinding` implements the asynchronous WebIDL operation boundary.
It copies input data and registered algorithm BufferSource fields before
returning; errors from normalization reject immediately. Digest, encryption,
signing, verification, and KEM operations queue separate crypto settlement
tasks. Generation, import, export, derivation, wrapping, and unwrapping settle
in deferred work, following the current C++ bodies, including their wrapping
task-source FIXMEs. Promise reactions enter the owning global's microtask queue.
Window/Worker global Crypto getters now return concrete Crypto operations.

The HTML adapter runs deferred work as an owning-loop unspecified task instead
of Core/EventLoopPlugin deferred invocation, preserving the separate crypto
task and its order. Promise/Value objects, relevant-global identity, and key
bindings use the translated WebIDL records. They are not LibJS VM Promises,
realm objects, or TemporaryExecutionContext; that runtime integration remains
dependent on unfinished LibJS work. Synchronous typed `SubtleCrypto` operations
remain available below the binding.

Shared JWK validation now retains the pinned helper's duplicate, unrelated
operation, use-category, and first missing-usage diagnostics. Focused tests
exercise optional/unknown operations, source validation precedence, and the
actual AES, HMAC, and EC import paths. The helper intentionally preserves the
source's rejection of mixed encryption/wrapping operation groups.

## Verification

The 48 WebCrypto test files and all eight WebIDL test files passed using direct
`v -old-compiler -enable-globals -path 'WORKTREE|@vlib|@vmodules' FILE_test.v`
invocations. The focused HTML Crypto, environments, and global-scope tests also
passed. These checks cover copied views/parameters/usages, immediate versus
deferred rejection, source key-generation validation order, key binding
identity, operation results, independent window/worker task ownership, chained
and late Promise reactions, and observers. They do not establish browser JS
Promise integration or completion of the remaining algorithm families.

Generated JWK result dictionaries now preserve lexicographic member creation
order from the pinned IDL parser and GenerateToValue converter, including nested
RSA other-prime dictionaries. `jwk_dictionary_order_test.v` passes for optional
fields, false booleans, empty sequences, and exported Promise result DTOs.

Native SubtleCrypto.exportKey is connected to the actual owning source service
and Promise bridge. Its fixed-argument wrapper preserves KeyFormat-before-key
conversion, deferred algorithm/extractability checks, actual ArrayBuffer/JWK
results, and original engine exceptions. All three native export host tests
pass with `-gc none`; other native method bindings and complete LibJS wrapper/
Promise graph parity remain pending.

Algorithm JWK import adapters now distinguish serialized dictionary transport
from CryptoBindings::parse_json_web_key. Missing optional kty reaches concrete
usage/type validation; public JSON parsing and unwrap retain the mandatory-kty
source rule. Both focused jwk_import_dictionary_test cases pass across symmetric,
RSA, EC, and Ed25519 import paths.

Native SubtleCrypto.importKey now connects actual engine dictionary/buffer/enum
values to the owning source service and actual Promise/CryptoKey wrappers.
Lexical JWK getter order, DOMString sequences, nested RSA dictionaries, argument
conversion before format checks, copied bytes before normalization, source
parameter conversion, and common sorted usages are covered. All five focused
native import cases pass with `-gc none`, exercising every one of the 29
registered import names. Pinned ML-KEM JWK TODOs and documented host/VM/string/
wrapper boundaries remain; encryption, signing, derivation, wrapping, and KEM
native method bindings are still pending.

Native encrypt/decrypt method bindings now call the actual owning source service
for all six registered names. Source parameter getter order, optional-field
presence, unsigned tag conversion, copied input spans, work/crypto settlement,
real buffers, and immediate/deferred validation are exercised. All three focused
cipher host cases pass with `-gc none`, including an AES-GCM known vector and
native AES-CBC/CTR/GCM/OCB, ChaCha20-Poly1305, and RSA-OAEP round trips. Remaining
native methods include signing, derivation, wrapping, and KEM operations.

Native sign/verify bindings now use source parameter conversion and the actual
owning work/crypto Promise path. All three focused signature host cases pass
with `-gc none`, including upstream HMAC/NIST KMAC vectors and valid/tampered
verification for all 11 registered names. Source key/argument/parameter error
order, required KMAC EnforceRange length, context copying, and signature-before-
message copy order are retained. Derivation, wrapping, and KEM native methods
remain pending alongside documented host/VM/DTO/wrapper boundaries.

Native deriveBits/deriveKey bindings now call source KDF/exchange operations
through the actual owning deferred Promise path. All four focused host cases
pass with `-gc none`, including all eight registered names, RFC known vectors,
EC/X bilateral results, unsigned/optional conversion, and independent destination
import/key-length getter snapshots. All five typed binding regression cases
pass after the snapshot adapter. Native wrap/unwrap and KEM methods remain
pending alongside documented host/VM/string/wrapper boundaries.

Native wrapKey/unwrapKey now retain source actual enum/brand conversion,
normalization fallback reads, copied wrapped bytes, deferred work settlement,
export validation, and separate JWK JSON parse order. All four focused host
cases pass with `-gc none`, covering RFC 3394 and all seven supported wrapping
operations, real CryptoKey results, JWK round trips, source getter/error order,
and mandatory-kty unwrap parsing. The four KEM native bindings remain pending;
source FIXME task behavior and documented host/VM/DTO/wrapper limits are retained.

All four modern KEM methods now expose the actual owning source operations to
native browser scripts. Four focused host cases pass with `-gc none` across
ML-KEM-512/768/1024, real byte/key results, implicit rejection, ciphertext copy
before normalization, generated argument conversion, source usage validation,
and work/crypto settlement. All 16 pinned SubtleCrypto method bindings are now
present. Complete LibJS VM/WrapperWorld parity, arbitrary UTF-16 DTO strings,
and the documented host scheduler/GC boundaries remain separate limitations;
pinned ML-KEM JWK source TODOs are preserved.


The source CryptoKey HTML IPC/storage payload now uses its own translated HTML
encoder rather than the standalone compatibility codec. Seven algorithm and
eleven handle tags, raw UTF-16 strings, stable storage enum identifiers, source
integer/vector sizes, optional EC fields, RSA numeric zero and EC scalar-width
padding have exact byte goldens in both GC modes. Actual native algorithm
getters preserve raw UTF-16 name/hash/curve strings and cached mutable object
identity. Four focused files pass with default GC and six source/native
neighbors pass with GC disabled. Actual native clone projection and exposure
now use genuine owning wrapper records and secure installed target prototypes; full LibJS WrapperWorld/GC, JSON DTO strings and the
other documented assertion/scheduler boundaries remain open. Detailed source
locations, evidence and limits are recorded in
[the clone codec status](../docs/translation-audit/STRUCTURED_CLONE_SOURCE_CODEC.md).


The HMAC plain algorithm record and legacy binding constructor now retain the
source empty name default. Generation and import explicitly assign `HMAC` at
the source steps, so actual operation keys remain unchanged. The default-record,
HMAC source-vector and core test files pass 3/3 in both GC modes; no implicit
algorithm name is introduced into an otherwise empty source record.

The native KDF provider adapter preserves present empty input parameters with
non-null zero-length octet spans (`1485745ff`). This fixes HKDF empty key material
and PBKDF2 empty passwords/salts without changing algorithm validation. Six
typed checks pass in both normal GC and preallocated GC-none modes, including
16 official empty-key HKDF vectors and eight independent PBKDF2 vectors.
The four original official HKDF HTTPS Window variants pass 3,664/3,664 in native
Page checks, gaining 272 passes over the earlier pinned Window results. All
four Worker variants initially time out before subtest reporting, retaining the
7,328 expected assertions and strict exit 1. Those timeouts are subsequently
traced to the WPT server's missing direct-HTTPS TLS shutdown. With that adapter
repair, the same matching production browser passes all eight original variants,
7,328/7,328, with strict exits 0 and unchanged executable/library hashes. The
recovered Worker assertions are a measurement repair, not additional engine
conformance credit. This finite selection does not establish full WebCrypto or
WPT parity. See
[WPT progress](../docs/WPT_CONFORMANCE_PROGRESS.md).
