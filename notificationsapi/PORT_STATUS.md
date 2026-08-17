# NotificationsAPI translation status

Upstream: `Libraries/LibWeb/NotificationsAPI`

| Upstream unit | V implementation |
| --- | --- |
| `Notification.cpp` | `notification.v` |

- Upstream: 1 `.cpp` file, 249 physical LOC.
- V implementation: 278 LOC.
- V tests: 68 LOC in 1 file.
- Status: complete.

Notification creation, structured storage data, URL resolution, timestamp and
option validation, action projection, enum conversions, constructor restrictions,
and the current upstream FIXME boundaries are represented.

Verification: `v test notificationsapi`, `v fmt -verify notificationsapi`, and
scoped `git diff --check` pass.
