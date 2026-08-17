# PermissionsPolicy translation status

Upstream: `Libraries/LibWeb/PermissionsPolicy`

| Upstream unit | V implementation |
| --- | --- |
| `AutoplayAllowlist.cpp` | `autoplay_allowlist.v` |

- Upstream: 1 `.cpp` file, 98 physical LOC.
- V implementation: 79 LOC.
- V tests: 21 LOC in 1 file.
- Status: complete.

Default-self, global, parsed-origin, invalid-origin, and opaque-file autoplay
allowlist behavior is implemented with the upstream Decision ordering.

Verification: `v test permissionspolicy`, `v fmt -verify permissionspolicy`,
and scoped `git diff --check` pass.
