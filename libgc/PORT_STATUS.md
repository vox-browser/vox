# LibGC storage translation status

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
This package translates primitive-storage ownership and allocation. The
LibGC collector remains separate, pending work under EX-03.

| Source | Translation | Covered behavior |
| --- | --- | --- |
| `ExternalEntityTable.{h,cpp}` | `external_entity_table.v` | Balanced eight-bit tags, entry generations, validity, free-list reuse and generation overflow |
| `PrimitiveStorage.cpp` private Allocator | `primitive_storage_allocator.v` | 4 TiB cage, page guard, 13 slab classes, free ranges, reservations, resize, reallocation and address containment |
| `PrimitiveStorage.{h,cpp}` public API | `primitive_storage.v` | Actual handles and allocation entries, all allocation/reservation/resize variants, size/capacity/offset/data getters and release |
| LibCore POSIX mapping and errno boundary | `primitive_storage_native.c.v`, `primitive_storage_host.h` | Actual OS page size, reserve/commit/decommit mappings, host diagnostics and the source cage-base scalar |

V owns the allocation algorithms. The native header supplies OS calls and the
cage-base scalar. Committing and decommitting pages use the source fixed mapping
operations. Small allocations retain slab pools and reuse slots; large
allocations preserve capacity and guard extents, coalesce released ranges and
reclaim the top of the cage. The process singleton retains its cage, as the
source `NeverDestroyed` record does.

V reserves `free()` for a zero-argument destructor. The source `free(handle)` is
named `free_handle(handle)` here. Overloaded handle operations use
`try_reserve_handle`, `data_at` and `contains_handle`; their algorithms are
unchanged. Source recoverable allocation/mapping errors retain host errno.
Language allocation panics during V vector growth are not recoverable in the
same way as AK allocation errors.

Focused tests exercise actual mappings, slab reuse and zero fill, guarded
growth, byte-preserving reallocation, range coalescing, generation rollover,
stale handles, source error ordering and the shared process cage. All three
test files have passing default-GC and `-gc none` evidence. POSIX mappings are
verified on macOS; the Windows LibCore mapping backend is not implemented.

Wasm `MemoryBuffer` and `MemoryInstance` now use these actual handles. Their
WebIDL memory wrappers and realm-specific buffer views also resolve this live
storage without byte snapshots. LibJS's translated `OwnedPrimitiveBackingStore`
uses the same allocator; its DataBlock integration is a separate pending slice.
Native-storage lifetime ends through explicit `destroy()` calls. Source
automatic owner destruction, `Heap`, roots, cross-heap members, collection and
the complete runtime lifetime graph are still open. This storage translation
does not establish collector parity or close EX-03.
