# EncryptedMediaExtensions module V translation — complete

Upstream reference:
`~/code/3rd/ladybird/Libraries/LibWeb/EncryptedMediaExtensions`

Translation workspace: `~/code/libweb_v/encryptedmediaextensions`
Audited: 2026-08-16

All three upstream EncryptedMediaExtensions `.cpp` implementation units have
an audited V implementation mapping. The associated headers and
`MediaKeySystemAccess.idl` dictionaries, enums, partial Navigator interface,
and access object are represented by typed V APIs.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Algorithms.cpp` | `algorithms.v`, `key_system.v`, `types.v` |
| `MediaKeySystemAccess.cpp` | `media_key_system_access.v` |
| `NavigatorEncryptedMediaExtensionsPartial.cpp` | `navigator_encrypted_media_extensions_partial.v` |

| Upstream declarations | V implementation |
| --- | --- |
| `Algorithms.h` | `algorithms.v` |
| `EncryptedMediaExtensions.h` | `types.v` |
| `KeySystem.h` | `key_system.v` |
| `MediaKeySystemAccess.h`, `MediaKeySystemAccess.idl` | `media_key_system_access.v`, `types.v` |
| `NavigatorEncryptedMediaExtensionsPartial.h` | `navigator_encrypted_media_extensions_partial.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `EncryptedMediaExtensions/` | 3 | 544 | 572 | 329 | Complete |

The translation covers Clear Key's exact key-system, init-data,
encryption-scheme, and robustness support; MIME parsing and encrypted media
capability filtering; supported-configuration accumulation; persistent-session
requirements and restriction handling; consent propagation; exact WebIDL enum
names and conversion; the `MediaKeySystemAccess` IDL surface; and Navigator's
synchronous security error, argument promise rejections, deferred candidate
selection, access resolution, and `NotSupportedError` paths. Deferred work
captures deep copies of WebIDL sequence/dictionary inputs and is deliberately
not gated on later Document activity, matching the upstream platform-deferred
callback.

`KeySystem` is the typed content-decryption-module boundary, and Navigator's
context explicitly supplies the document permission decision, origin, and
responsible HTML event loop. This keeps browser/platform integration out of the
pure selection algorithms. Ladybird's current `supports_container`,
playback-capability, and consent hooks retain their upstream provisional
behavior. `createMediaKeys()` remains an explicit rejected-promise
`NotSupportedError` boundary, preserving its IDL `Promise<MediaKeys>` shape
while matching the upstream method's unimplemented `[FIXME]` status.

## Verification

```text
$ /Users/alex/code/v/v test encryptedmediaextensions
Summary for all V _test.v files: 3 passed, 3 total.

$ /Users/alex/code/v/v fmt -verify encryptedmediaextensions
(no output; exit status 0)
```
