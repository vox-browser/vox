# Hostless storage adapter has no actual typed key

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/StorageAPI/StorageBottle.h:26–55,80–92,114–126` and
`StorageBottle.cpp:91–121`.

Source StorageBottle's base constructor owns quota only. The actual local and
session subclasses receive and retain their real Page, endpoint and StorageKey.
The V quota-only SessionStorageBottle constructor is an existing isolated
in-memory adapter, rather than that Source subclass constructor.

The first typed-key prerequisite incorrectly supplied this hostless adapter
with a constructed empty-scheme tuple Origin. Source review caught that invented
owner. The correction leaves the adapter's key slot absent and keeps its quota
and map behavior. Actual StorageBottle.create and LocalStorageBottle.create
still require a supplied typed key. Host-backed operations read that retained
key and fail if their constructor ownership invariant has been violated; they
never create or recover an origin.

Two focused cases check the adapter's absent key across quota rejection,
insertion/removal/clear, and the actual retained key/serialization passed to
the existing host callback boundary. Existing StorageAPI, real IndexedDB and
Page/Window/settings key-owner neighbors are rechecked. The earlier typed-key
test evidence remains scoped to its original record/operation checks and did
not establish this adapter's ownership correctness.

Default-GC checks passed the new file, existing StorageAPI models and genuine
IndexedDB binding (3/3 files, 167.366 seconds). GC-none checks passed those plus
the real Page/Window/settings key reassociation witness (4/4 files,
103.056 seconds). Both commands used
`VJOBS=1 /Users/alex/code/v/v -old-compiler -enable-globals test`, adding
`-gc none` for the latter. Retained logs are
`Build/audit-fixes/source-storage-key-hostless-owner-default.log` and
`source-storage-key-hostless-owner-gc-none.log` in the same directory.

The complete Source Page-owning subclass/native host proxy/GC graph and native
IPC remain separate. This correction preserves the explicit hostless adapter
without presenting it as a fabricated Source storage owner.
