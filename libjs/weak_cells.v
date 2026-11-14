// SPDX-License-Identifier: BSD-2-Clause
module libjs

$if gcboehm ? {
	#include "@VMODROOT/libjs/weak_cells.h"
	fn C.vox_libjs_weak_cell_new(target voidptr) voidptr
	fn C.vox_libjs_weak_cell_read(slot voidptr) voidptr
	fn C.vox_libjs_weak_cell_epoch() u64
}

// The encoded identity cannot root a cell in a conservative scan. Non-collecting
// builds keep that identity directly; they do not pretend to collect weak keys.
struct WeakCellReference {
	encoded u64
	slot voidptr
}

fn WeakCellReference.create(cell voidptr) !WeakCellReference {
	if cell == unsafe { nil } { return WeakCellReference{} }
	$if gcboehm ? {
		slot := C.vox_libjs_weak_cell_new(cell)
		if slot == unsafe { nil } { return error('Unable to allocate weak cell reference') }
		return WeakCellReference{ encoded: ~u64(cell), slot: slot }
	}
	return WeakCellReference{ encoded: ~u64(cell) }
}

fn (reference WeakCellReference) cell() voidptr {
	if reference.encoded == 0 { return unsafe { nil } }
	$if gcboehm ? { return C.vox_libjs_weak_cell_read(reference.slot) }
	return unsafe { voidptr(~reference.encoded) }
}

fn weak_cell_epoch() u64 {
	$if gcboehm ? { return C.vox_libjs_weak_cell_epoch() }
	return 0
}

@[heap]
struct WeakCollectionRegistry {
mut:
	collections []WeakCellReference
	epoch u64
}

// Upstream Heap owns the WeakContainer list. This VM-backed collector adapter
// keeps weak container references and retires dead entries at execution
// checkpoints and before collection operations following a GC. Values are
// visited strongly, matching Runtime/WeakMap.cpp rather than adding ephemerons.
fn (mut vm VM) sweep_weak_collections() {
	$if !gcboehm ? { return }
	mut registry := vm.weak_collection_registry or { return }
	epoch := weak_cell_epoch()
	if epoch == registry.epoch { return }
	registry.epoch = epoch
	mut live := 0
	for reference in registry.collections {
		cell := reference.cell()
		if cell == unsafe { nil } { continue }
		mut collection := unsafe { &WeakMapObject(cell) }
		collection.remove_dead_cells()
		registry.collections[live] = reference
		live++
	}
	for index in live .. registry.collections.len { registry.collections[index] = WeakCellReference{} }
	registry.collections.trim(live)
}
