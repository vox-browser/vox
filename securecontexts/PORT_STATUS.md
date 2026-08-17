# SecureContexts translation status

Upstream: `Libraries/LibWeb/SecureContexts`

| Upstream unit | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `abstract_operations.v` |

- Upstream: 1 `.cpp` file, 88 physical LOC.
- V implementation: 63 LOC.
- V tests: 13 LOC in 1 file.
- Status: complete.

Opaque/file origins, authenticated schemes, current Ladybird IPv4 mask
semantics, IPv6 loopback, localhost suffixes, resource/file URLs, and the
about/data URL exceptions are covered.

Verification: `v test securecontexts`, `v fmt -verify securecontexts`, and
scoped `git diff --check` pass.
