module layout

import dom
import platform

// A published tree owns its slots and style-to-paint projections. Geometry
// caches allocate their reusable templates independently; scenes retain this
// owner while their command payloads still refer to a particular projection.
@[heap]
struct PaintTreeStorage {
mut:
	arena      &platform.Arena       = unsafe { nil }
	pool       &PaintTreeStoragePool = unsafe { nil }
	references int
	document_storage &platform.RetainedArena = unsafe { nil }
}

@[heap]
struct PaintTreeStoragePool {
mut:
	document &dom.Document = unsafe { nil }
	free     []&PaintTreeStorage
	live     []&PaintTreeStorage
	retired bool
}

const paint_tree_storage_spares = 2

// Opt in only for the native shell, whose snapshots have explicit release
// points. General layout APIs continue to return process-lifetime snapshots
// under -prealloc. Hosted scenes retain these slots through their scene leases.
pub fn enable_native_paint_tree_storage(document &dom.Document) {
	$if prealloc {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.recycle_native_paint_trees = true
	}
}

fn (mut result DocumentLayoutResult) acquire_paint_tree_storage(document &dom.Document) &PaintTreeStorage {
	$if prealloc {
		if document == unsafe { nil } || !document.recycle_native_paint_trees {
			return unsafe { nil }
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		if result.paint_tree_pool == unsafe { nil } {
			result.paint_tree_pool = &PaintTreeStoragePool{ document: document }
		}
		mut pool := result.paint_tree_pool
		mut storage := if pool.free.len > 0 {
			pool.free.pop()
		} else {
			&PaintTreeStorage{ arena: platform.new_arena('paint tree projections'), pool: pool }
		}
		storage.references = 1
		storage.document_storage = document.native_storage()
		if storage.document_storage != unsafe { nil } { storage.document_storage.retain() }
		pool.live << storage
		return storage
	}
	return unsafe { nil }
}

fn (mut storage PaintTreeStorage) retain() {
	storage.references++
}

fn (mut storage PaintTreeStorage) release() {
	storage.references--
	if storage.references > 0 { return }
	if storage.references < 0 { panic('paint tree released too often') }
	mut pool := storage.pool
	for index, live in pool.live {
		if voidptr(live) == voidptr(storage) {
			pool.live.delete(index)
			break
		}
	}
	if pool.retired || pool.free.len >= paint_tree_storage_spares {
		storage.arena.release()
	} else {
		storage.arena.reset()
		persistent := platform.enter_persistent()
		pool.free << storage
		platform.leave_persistent(persistent)
	}
	mut document_storage := storage.document_storage
	storage.document_storage = unsafe { nil }
	if document_storage != unsafe { nil } { document_storage.release() }
}

// The shell keeps its geometry independently of its currently adopted scene.
// Retain before copying result.paint_tree, release after replacing that copy.
pub fn retain_document_paint_tree(document &dom.Document) voidptr {
	result := document_layout_result(document) or { return unsafe { nil } }
	mut storage := result.paint_tree_storage
	if storage != unsafe { nil } { storage.retain() }
	return voidptr(storage)
}

pub fn release_paint_tree(handle voidptr) {
	if handle == unsafe { nil } { return }
	mut storage := unsafe { &PaintTreeStorage(handle) }
	storage.release()
}

fn (mut result DocumentLayoutResult) retire_paint_tree_storage() {
	storage := result.paint_tree_storage
	result.paint_tree_storage = unsafe { nil }
	release_paint_tree(voidptr(storage))
}
