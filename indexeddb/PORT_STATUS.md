# IndexedDB module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/IndexedDB`

Translation workspace: `~/code/libweb_v/indexeddb`
Audited: 2026-09-04

All 18 upstream IndexedDB `.cpp` implementation units have an audited V
implementation mapping. The companion headers and all 12 IDL files are
represented by typed V APIs.

| Upstream implementation unit | V implementation |
| --- | --- |
| `IDBCursor.cpp` | `cursor.v`, `object_store.v`, `index.v` |
| `IDBDatabase.cpp` | `database.v`, `transaction.v` |
| `IDBFactory.cpp` | `factory.v`, `key.v` |
| `IDBIndex.cpp` | `index.v`, `records.v` |
| `IDBKeyRange.cpp` | `key_range.v` |
| `IDBObjectStore.cpp` | `object_store.v`, `records.v`, `value.v` |
| `IDBOpenDBRequest.cpp` | `request.v`, `factory.v` |
| `IDBRecord.cpp` | `records.v` |
| `IDBRequest.cpp` | `request.v` |
| `IDBTransaction.cpp` | `transaction.v`, `database.v` |
| `IDBVersionChangeEvent.cpp` | `request.v` |
| `Internal/Algorithms.cpp` | `factory.v`, `key.v`, `value.v`, `object_store.v`, `index.v`, `cursor.v`, `transaction.v` |
| `Internal/Database.cpp` | `database.v`, `factory.v` |
| `Internal/Index.cpp` | `records.v`, `index.v` |
| `Internal/Key.cpp` | `key.v` |
| `Internal/MutationLog.cpp` | `transaction.v` |
| `Internal/ObjectStore.cpp` | `records.v`, `object_store.v` |
| `Internal/RequestList.cpp` | `request_list.v` |

| Upstream declarations | V implementation |
| --- | --- |
| `ConnectionState.h` | `database.v` |
| `IDBCursor.h`, `IDBCursor.idl`, `IDBCursorWithValue.h`, `IDBCursorWithValue.idl` | `cursor.v` |
| `IDBDatabase.h`, `IDBDatabase.idl` | `database.v`, `transaction.v` |
| `IDBFactory.h`, `IDBFactory.idl` | `factory.v` |
| `IDBIndex.h`, `IDBIndex.idl` | `index.v` |
| `IDBKeyRange.h`, `IDBKeyRange.idl` | `key_range.v` |
| `IDBObjectStore.h`, `IDBObjectStore.idl` | `object_store.v` |
| `IDBOpenDBRequest.h`, `IDBOpenDBRequest.idl` | `request.v` |
| `IDBRecord.h`, `IDBRecord.idl` | `records.v` |
| `IDBRequest.h`, `IDBRequest.idl` | `request.v` |
| `IDBTransaction.h`, `IDBTransaction.idl` | `transaction.v` |
| `IDBVersionChangeEvent.h`, `IDBVersionChangeEvent.idl` | `request.v` |
| `Internal/Algorithms.h` | all implementation files above |
| `Internal/ConnectionQueueHandler.h` | `factory.v` |
| `Internal/Database.h` | `database.v` |
| `Internal/Index.h` | `records.v` |
| `Internal/Key.h` | `key.v` |
| `Internal/KeyGenerator.h` | `records.v` |
| `Internal/MutationLog.h` | `transaction.v` |
| `Internal/ObjectStore.h` | `records.v` |
| `Internal/RequestList.h` | `request_list.v` |

The upstream inline accessor surfaces and shared algorithms are implemented in
`object_factories.v`, `handle_operations.v`, `internal_operations.v`, and
`algorithm_operations.v`.
The internal C++ `Database`, `ObjectStore`, and `Index` classes map to the V
`DatabaseData`, `ObjectStoreData`, and `IndexData` records respectively.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `IndexedDB/` | 18 | 6,449 | 4,364 | 682 | Audited |

The V implementation covers IndexedDB key construction and total ordering,
key/value conversion, compound and dotted key paths, generated-key injection,
open/version/delete flows, database information, schema upgrades, connection
states, transaction modes and durability, atomic abort restoration, request
state and event sequencing, object-store CRUD and range scans, key generators,
unique and multi-entry indexes, all/get/count/record query forms, forward,
reverse and unique cursors, cursor continuation/update/delete, version-change
events, and FIFO request-list bookkeeping. Stored values and keys are deep
cloned at the API boundary. The audit additionally verifies UTF-16 code-unit
ordering for keys and schema names, string/array `length` key paths,
multi-entry conversion that skips invalid array members, cursor source/state
validation and `continuePrimaryKey` ordering, direct-versionchange rejection,
live-upgrade transaction exclusion, and rollback of newly created databases.
Internal mutation logs retain inverse record, index, schema-name, and key
generator operations, including per-request rollback from a saved log
position. The audit replaced copied database, store, index, transaction, and
cursor state with stable heap-backed objects. Transactions now retain
per-store inverse mutation logs instead of cloning the complete database,
indexes are maintained incrementally instead of rebuilt after each write, and
cursors scan the live sorted source rather than eagerly materializing every
matching record. Shared storage-key registries and transaction-local handle
caches preserve database and handle identity at the standalone runtime
boundary. Stored values are cloned only at structured-storage and API-output
boundaries.

The symbol audit covers 425 upstream implementation entries with zero
unmatched symbols.

`IDBFactory` is also the explicit storage-key/backend boundary. Its database
catalog is deliberately in memory, rather than being persisted by a browser
storage service. Browser realms, WebIDL JavaScript conversion/structured clone,
event-loop task dispatch, origin quota, and cross-process connection
coordination are represented by deterministic typed V calls and event logs;
they require the surrounding browser runtime and do not conceal unimplemented
record, index, transaction, or cursor operations. Blob/File special key-path
properties require browser FileAPI values, which the standalone typed `Value`
does not represent. Cursor entry materialization and request-list dispatch are
synchronous standalone event-loop boundaries. Version upgrades remain active
after `open()` until `finish_upgrade()` or `abort_upgrade()`, directly modeling
the work normally performed inside the asynchronous `upgradeneeded` callback.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test indexeddb
Summary for all V _test.v files: 5 passed, 5 total.

$ git diff --check -- indexeddb
(no output; exit status 0)
```
