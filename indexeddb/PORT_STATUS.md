# IndexedDB module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/IndexedDB`

Translation workspace: `~/code/vox2/indexeddb`
Audited: 2026-09-12

All 19 upstream IndexedDB `.cpp` implementation units have an audited V
implementation mapping. The companion headers and all 12 IDL files are
represented by typed V APIs.

| Upstream implementation unit | V implementation |
| --- | --- |
| `IDBCursor.cpp` | `cursor.v`, `object_store.v`, `index.v` |
| `IDBDatabase.cpp` | `database.v`, `transaction.v` |
| `IDBFactory.cpp` | `factory.v`, `key.v` |
| `IDBIndex.cpp` | `index.v`, `records.v` |
| `Inspection.cpp` | `inspection.v`, `transaction_changes.v` |
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
| `Internal/MutationLog.cpp` | `internal_operations.v`, `transaction_changes.v` |
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
| `TransactionChanges.h` | `transaction_changes.v` |
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
| `IndexedDB/` | 19 | 6,991 | 5,211 | 1,086 | Audited |

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
boundaries. The current update also covers typed storage inspection, record and
schema change coalescing for DevTools notifications, realm propagation through
factory/database/request/transaction/store/index/cursor handles, request and
handle binding offsets, stored-record deserialization failures, and Blob/File
key-path properties.

The symbol audit covers 471 upstream implementation entries with zero
unmatched symbols.

`IDBFactory` is also the explicit storage-key/backend boundary. Its database
catalog is deliberately in memory, rather than being persisted by a browser
storage service. Browser realms, WebIDL JavaScript conversion/structured clone,
event-loop task dispatch, origin quota, and cross-process connection
coordination are represented by deterministic typed V calls and event logs;
they require the surrounding browser runtime and do not conceal unimplemented
record, index, transaction, or cursor operations. Blob/File values use a typed
standalone representation for their IndexedDB-visible metadata. Cursor entry
materialization and request-list dispatch are
synchronous standalone event-loop boundaries. Version upgrades remain active
after `open()` until `finish_upgrade()` or `abort_upgrade()`, directly modeling
the work normally performed inside the asynchronous `upgradeneeded` callback.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test indexeddb
Summary for all V _test.v files: 9 passed, 9 total.

$ git diff --check -- indexeddb
(no output; exit status 0)
```

## Browser request integration — 2026-10-25

`38a07d9b` adds ordered asynchronous object-store get/put/add requests to the
existing native transaction queue. Validation and value cloning happen when
the operation is called; completion reuses the original request. Success/error
listeners run with an active transaction, canceled errors allow subsequent
requests, and uncanceled errors or listener exceptions abort and roll back.
Upgrade completion waits for queued operations, including explicitly committed
transactions, and failed upgrades release their connection-queue entry.

`106cb5bb` connects the owning Window's factory to JavaScriptCore through native
request, database, transaction and store wrappers. It supplies trusted request
and upgrade events, live name lists, native receiver checks, exception identity,
and document-owned allocation for database tasks. The binding currently exposes
factory open/delete/cmp, database schema/transaction operations, transaction
completion and store get/put/add. It does not expose the complete typed module:
cursor/index operations, complete request-event bubbling, arbitrary structured
clone graphs, disk persistence, quota and cross-process coordination remain open.
The value adapter supports finite trees of primitives, plain objects, dense
arrays, dates and ArrayBuffers; unsupported records throw DataCloneError.

Focused checks: six new asynchronous core cases and ten existing store,
transaction-completion and factory cases pass with normal GC. Five new browser
binding cases pass with normal GC and with `-prealloc -gc none`, including
Promise continuations, request identity/order, call-time cloning, error
cancellation/rollback, upgrades and runtime shutdown. Evidence is retained in
`Build/pikabu-story-idb-core-stages.json`,
`Build/pikabu-story-idb-binding-stages.json` and the successful guarded job
`Build/pikabu-story-idb-core-job.json`; this is focused coverage, not a rerun of
every module test or full IndexedDB parity.

Scoped physical-LF inventory at `106cb5bb`: IndexedDB contains 20 implementation
files / 5,581 lines and 13 test files / 1,519 lines. The two feature commits add
117 IndexedDB implementation lines and 131 test lines, eight HTML implementation
lines, and 756 implementation / 169 test lines in browser/root support. The
per-parent 14-path inventory is `Build/pikabu-story-idb-inventory.json` (SHA-256
`ec81a39e733e55a4b7abc0fe6e91707c45189545aadb7b36cb41a9c5bdd13b81`).
The earlier audit table and global ownership inventories retain their original
dated pins; these counts add no behavioral parity credit.
