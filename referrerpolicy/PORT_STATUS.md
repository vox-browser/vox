# Referrer Policy translation status

Complete, independently audited translation of `Libraries/LibWeb/ReferrerPolicy`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `referrer_policy.v` |
| `ReferrerPolicy.cpp` | `referrer_policy.v` |

The translated surface includes policy parsing, header extraction, redirect
updates, origin-only and URL stripping, client referrers, trustworthy-origin
checks, and the complete request referrer-policy matrix.

- Upstream: 2 `.cpp` files, 298 LOC; both adjacent headers audited.
- V implementation: 239 LOC in 1 file.
- V tests: 123 LOC in 1 file (14 test functions).
- Verification: `v test referrerpolicy` and `v fmt -verify referrerpolicy`.
