# PermissionsAPI translation status

Status: **Complete** (2026-09-11)

The post-March `PermissionsAPI` module is translated in `permissions.v`:
permission descriptors and states, same-origin permission keys, the process
permission store, secure-context state lookup, permission requests,
`Permissions.query()`, and queued `PermissionStatus` change updates.

The JS promise and current-settings-object integration is represented by the
typed `PermissionEnvironment` boundary. Focused verification is
`v -enable-globals test permissionsapi`.
