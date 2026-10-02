# Crypto module V translation — implementation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Crypto`

Translation workspace: `~/code/vox2/webcrypto`
Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`
Latest focused verification: 2026-10-02

All six upstream Crypto `.cpp` implementation units have an audited V
implementation mapping. The V package is named `webcrypto` so that it can
import V's standard `crypto.*` primitives without shadowing that namespace.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Crypto.cpp` | `crypto.v` |
| `CryptoAlgorithms.cpp` | `crypto_algorithms.v`, `aes_ocb.v`, `cshake.v`, `kmac.v`, `native_crypto.c.v`, `native_crypto.h`, `exchange_curves.v`, `ed448.v`, `native_edwards.c.v`, `native_edwards.h`, `mldsa.v`, `mlkem.v`, `native_ml.c.v`, `native_ml.h`, `rsa.v`, `rsa_key_formats.v`, `native_rsa.c.v`, `native_rsa.h`, `okp_der.v` |
| `CryptoBindings.cpp` | `crypto_bindings.v` |
| `CryptoKey.cpp` | `crypto_key.v`, `crypto_key_objects.v`, `crypto_key_serialization.v` |
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
OpenSSL is resolved through `pkg-config openssl`. cSHAKE preserves upstream's
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
Its key-format bodies preserve source quirks: repeated usage entries remain
repeated; the current JWK use equality test rejects `sig`; raw/JWK metadata is
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

ECDSA/ECDH still contain
unavailable operation bodies. Their normalization and parameter binding do not
make their cryptographic operations complete. Key-format and validation parity
outside the completed families also require further source review.

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

## Verification

The 22 WebCrypto test files and all six WebIDL test files passed using direct
`v -old-compiler -enable-globals -path 'WORKTREE|@vlib|@vmodules' FILE_test.v`
invocations. The focused HTML Crypto, environments, and global-scope tests also
passed. These checks cover copied views/parameters/usages, immediate versus
deferred rejection, source key-generation validation order, key binding
identity, operation results, independent window/worker task ownership, chained
and late Promise reactions, and observers. They do not establish browser JS
Promise integration or completion of the remaining algorithm families.
