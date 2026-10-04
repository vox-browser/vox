# Storage API translation status

The canonical V workspace is `~/code/vox2`. The original inventory below is
retained as historical status; it does not establish complete Source parity.
The October 4, 2026 review identified actual origin ownership and native
Environment/Page/IPC boundaries in the earlier standalone model.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `NavigatorStorage.cpp` | `storage_models.v` |
| `StorageBottle.cpp` | `storage_models.v` |
| `StorageEndpoint.cpp` | `storage_endpoint.v` |
| `StorageKey.cpp` | `storage_models.v` |
| `StorageManager.cpp` | `storage_models.v` |
| `StorageShed.cpp` | `storage_models.v` |
| `StorageShelf.cpp` | `storage_models.v` |

The bounded [actual StorageKey origin proof](../docs/translation-audit/STORAGE_KEY_ACTUAL_ORIGIN_OWNER.md)
maps typed origin retention, same-origin equality, both non-storage key overloads,
the file override, opaque rejection and the disabled-storage FIXME. It identifies
the captured-value Environment and quota-only SessionStorageBottle adapters.
The legacy string/flag byte codec is isolated from that actual record and is
not native Source IPC.

StorageHost callbacks and the standalone in-memory shed remain explicit
compatibility boundaries. Actual native Page/Environment/GC ownership,
browser storage-jar proxies, persistence and complete Source IPC require further
translation and verification. Existing endpoint/quota/Navigator behavior is
preserved without a new blanket parity claim.

Original inventory and verification:

- Upstream: 7 `.cpp` files, 381 LOC; all 8 adjacent headers and 2 IDLs audited.
- V implementation: 342 LOC in 2 files.
- V tests: 146 LOC in 2 files (10 test functions).
- Verification: `v test storageapi` and `v fmt -verify storageapi`.
