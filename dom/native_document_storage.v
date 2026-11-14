module dom

import platform

// Native navigation keeps Document/Window/context identity in ordinary
// storage. Parsing and rendering payloads have this explicitly opted-in owner.
// General DOM APIs retain their existing allocation and snapshot lifetimes.
pub fn (mut d Document) enable_native_storage() {
	$if prealloc {
		if d.native_storage_ == unsafe { nil } {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut storage := platform.new_retained_arena('native document')
			d.native_storage_ = storage
			storage.add_cleanup(fn [storage] () {
				retire_ranges_in_native_storage(storage)
			})
		} else if d.native_storage_borrowed_ {
			// An embedder can explicitly keep an inert template owner separately.
			d.native_storage_.retain()
			d.native_storage_borrowed_ = false
		}
		// An explicit native owner uses the embedder's retirement boundary.
		d.native_storage_adoption_owner_ = false
	}
}

// Inert documents can borrow this arena, and adoption can share its lifetime
// with another document. A range's current node document therefore need not
// be the document that owns the nodes' allocation. Prune these weak registry
// entries at the last storage lease, while every member's payload is readable.
fn retire_ranges_in_native_storage(storage &platform.RetainedArena) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for key in dom_live_ranges.keys() {
		range := dom_live_ranges[key] or { continue }
		if storage.arena.contains(voidptr(range.start_container()))
			|| storage.arena.contains(voidptr(range.end_container())) {
			dom_live_ranges.delete(key)
		}
	}
}

pub fn (d &Document) native_storage() &platform.RetainedArena { return d.native_storage_ }

// Inert parser documents have their own DOM identity, but their nodes belong
// to the containing document's allocation lifetime and return to it on adoption.
pub fn (mut d Document) borrow_native_storage(source &Document) {
	assert d.native_storage_ == unsafe { nil }
	d.native_storage_ = source.native_storage_
	d.native_storage_borrowed_ = d.native_storage_ != unsafe { nil }
}

pub fn (d &Document) enter_native_storage() platform.RetainedArenaScope {
	mut storage := d.native_storage_
	if storage == unsafe { nil } { return platform.RetainedArenaScope{} }
	return storage.enter()
}

// A destination keeps all allocations behind adopted node identities. Sharing
// whole arena lifetimes also preserves nodes previously adopted from a third
// document, without creating reference cycles on reciprocal adoption.
fn (mut d Document) share_adopted_native_storage(source &Document) {
	d.share_native_storage_lifetime(source.native_storage_)
}

// Retained native identities can outlive their source Document's storage
// field. Their allocation owner remains a live group member while another
// document or reader holds a lease, so it can be shared directly on adoption.
pub fn (mut d Document) share_native_storage_lifetime(storage &platform.RetainedArena) {
	if storage == unsafe { nil } || voidptr(storage) == voidptr(d.native_storage_)
		|| storage.arena.contains(voidptr(&d)) {
		return
	}
	if d.native_storage_ == unsafe { nil } {
		d.enable_native_storage()
		// General DOM documents have no shell calling release_native_storage.
		// Finalization owns the matching release unless an embedder later
		// explicitly enables native storage and takes over that responsibility.
		d.native_storage_adoption_owner_ = d.native_storage_ != unsafe { nil }
	}
	mut destination := d.native_storage_
	if destination != unsafe { nil } { destination.share_lifetime(storage) }
}

// Retire document-owned services before dropping this document's storage lease.
// In contrast to RetainedArena.add_cleanup, these callbacks do not wait for
// retained frames or adopted nodes. That lets a child release its own lease
// even when its allocation lifetime is shared with the parent document.
// Registration transfers ownership of the callback closure.
pub fn (mut d Document) add_native_storage_cleanup(callback fn ()) {
	persistent := platform.enter_persistent()
	d.native_storage_cleanup_ << callback
	platform.leave_persistent(persistent)
}

// Layout supplies the concrete retirement operation through its existing DOM
// hook. Detach before calling it, because retirement can reenter document
// cleanup. Ordinary, non-native layout snapshots keep their existing lifetime.
fn (mut d Document) retire_native_layout() {
	mut storage := d.native_storage_
	if storage == unsafe { nil } { return }
	handle := d.layout_engine_handle_
	d.layout_engine_handle_ = unsafe { nil }
	d.cached_display_list_ = unsafe { nil }
	if handle == unsafe { nil } { return }
	hook := d.layout_update_hook_ or { return }
	if hook.retire_native_layout == unsafe { nil } { return }
	// A reentrant release can drop the document's lease while the concrete
	// callback still reads its layout payload. Keep that payload until return.
	storage.retain()
	hook.retire_native_layout(handle)
	storage.release()
}

// The caller first closes the realm, cancels resource callbacks and removes
// this document's event-loop tasks. Retire any remaining layout publisher
// before dropping the document's own storage lease; retained geometry/scenes
// can still keep the payload arena alive afterwards.
pub fn (mut d Document) release_native_storage() {
	d.retire_native_layout()
	d.rule_selector_memo_handle_ = unsafe { nil }
	mut storage := d.native_storage_
	d.native_storage_ = unsafe { nil }
	borrowed := d.native_storage_borrowed_
	d.native_storage_borrowed_ = false
	d.native_storage_adoption_owner_ = false
	// Detach before invoking callbacks, so recursive retirement is harmless.
	cleanup := d.native_storage_cleanup_
	d.native_storage_cleanup_ = []fn (){}
	for callback in cleanup {
		callback()
		platform.release_closure(voidptr(callback))
	}
	if borrowed { return }
	if storage != unsafe { nil } {
		// The translated range registry is process-wide (weak upstream).
		// Native runtime closure has removed every script owner at this point.
		for key in dom_live_ranges.keys() {
			range := dom_live_ranges[key] or { continue }
			if voidptr(range.start_container().document()) == voidptr(&d) {
				dom_live_ranges.delete(key)
			}
		}
		storage.release()
	}
}
