# CredentialManagement module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/CredentialManagement`

Translation workspace: `~/code/libweb_v/credentialmanagement`
Audited: 2026-08-16

All six upstream CredentialManagement `.cpp` implementation units have an
audited V implementation mapping. The associated headers, WebIDL dictionaries,
unions, enum, inheritance relationships, and mixin data are represented by
typed V records.

| Upstream implementation unit | V implementation |
| --- | --- |
| `Credential.cpp` | `credential.v` |
| `CredentialsContainer.cpp` | `credentials_container.v` |
| `FederatedCredential.cpp` | `federated_credential.v` |
| `FederatedCredentialOperations.cpp` | `federated_credential_operations.v` |
| `PasswordCredential.cpp` | `password_credential.v` |
| `PasswordCredentialOperations.cpp` | `password_credential_operations.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `CredentialManagement/` | 6 | 369 | 400 | 293 | Complete |

The port covers the Credential base and user-data mixin, conditional-mediation
capability result, mediation and request/creation option records, federated
provider validation and origin derivation, password credentials constructed
from both dictionaries and translated HTML form models, the complete
autocomplete-token extraction algorithm (including `new-password` precedence),
and all observable getters.

Ladybird's `CredentialsContainer` methods currently return rejected
`NotImplemented` promises rather than using a browser credential store. The V
translation deliberately preserves those four rejections. Constructor entry
points accept an explicit `dom.Origin`, which is the typed boundary for the
current principal settings object's origin supplied by LibJS upstream.

## Verification

```text
$ /Users/alex/code/v/v test credentialmanagement
Summary for all V _test.v files: 3 passed, 3 total.
```
