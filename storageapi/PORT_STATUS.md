# Storage API translation status

Complete, independently audited translation of `Libraries/LibWeb/StorageAPI`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `NavigatorStorage.cpp` | `storage_models.v` |
| `StorageBottle.cpp` | `storage_models.v` |
| `StorageEndpoint.cpp` | `storage_endpoint.v` |
| `StorageKey.cpp` | `storage_models.v` |
| `StorageManager.cpp` | `storage_models.v` |
| `StorageShed.cpp` | `storage_models.v` |
| `StorageShelf.cpp` | `storage_models.v` |

The storage key/bottle/bucket/shelf/shed model, endpoint registry, quota
handling and Navigator `[SameObject]` manager are typed V code. Local-storage
persistence is exposed through `StorageHost` callbacks corresponding to
Ladybird's PageClient boundary; session storage remains in the translated
storage shed with upstream `OrderedHashMap` key ordering.

- Upstream: 7 `.cpp` files, 381 LOC; all 8 adjacent headers and 2 IDLs audited.
- V implementation: 342 LOC in 2 files.
- V tests: 146 LOC in 2 files (10 test functions).
- Verification: `v test storageapi` and `v fmt -verify storageapi`.
