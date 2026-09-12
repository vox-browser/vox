# Crypto module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Crypto`

Translation workspace: `~/code/vox2/webcrypto`
Audited: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` on 2026-09-12

All six upstream Crypto `.cpp` implementation units have an audited V
implementation mapping. The V package is named `webcrypto` so that it can
import V's standard `crypto.*` primitives without shadowing that namespace.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Crypto.cpp` | `crypto.v` |
| `CryptoAlgorithms.cpp` | `crypto_algorithms.v` |
| `CryptoBindings.cpp` | `crypto_bindings.v` |
| `CryptoKey.cpp` | `crypto_key.v`, `crypto_key_objects.v`, `crypto_key_serialization.v` |
| `KeyAlgorithms.cpp` | `key_algorithms.v` |
| `SubtleCrypto.cpp` | `subtle_crypto.v` |
| concrete `AlgorithmMethods` subclasses | `upstream_algorithm_classes.v` |
| parameter parsing, DER/JWK helpers, registry and shared entry points | `crypto_protocol.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Crypto/` | 6 | 13,412 | 4,472 | 1,459 | Complete |

The function-level delta from the 2026-03-24 baseline through the audited
Ladybird revision has zero unmatched Crypto additions. The current-source
inventory also has zero unmatched Crypto functions. The shared protocol review
preserves the ordering and duplicates required by `usage_intersection` and the
mandatory one-octet representation of the integer zero.

The port covers secure random values and UUIDv4 generation, the WebCrypto IDL
enums and JWK conversion, key metadata, stable tagged structured serialization
for every internal key-handle and algorithm variant, secure handle clearing,
realm-scoped algorithm and frozen-usage binding caches, algorithm normalization
and per-operation registration, key-usage and extractability checks, raw and
JWK import/export, key generation and derivation, wrapping and unwrapping, and
typed encapsulation boundaries.

Available V backends provide real implementations for SHA-1, SHA-2, SHA-3,
AES-CBC, AES-CTR, general-IV/general-tag AES-GCM, AES-KW, HMAC, HKDF, PBKDF2,
Argon2, Ed25519, and ChaCha20-Poly1305. These paths are checked against NIST,
RFC 3394, RFC 4231, RFC 5869, RFC 6070, RFC 8032, and RFC 8439 vectors.
Algorithms registered upstream for which this runtime has no audited primitive
(including RSA, Ed448, ML-DSA, ML-KEM, and AES-OCB) retain normalization and
access checking and terminate at an explicit `NotSupportedError` backend
boundary instead of substituting an unsafe implementation.

Ladybird resolves WebIDL promises through its platform event loop. The V
translation exposes the same operation results synchronously through typed
`!` results; scheduling the work and settling a host promise is the embedder
boundary.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test webcrypto
Summary for all V _test.v files: 8 passed, 8 total.
```
