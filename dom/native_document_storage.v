module dom

import platform

// Native navigation keeps Document/Window/context identity in ordinary
// storage. Parsing and rendering payloads have this explicitly opted-in owner.
// General DOM APIs retain their existing allocation and snapshot lifetimes.
pub fn (mut d Document) enable_native_storage() {
	$if prealloc {
		if d.native_storage_ == unsafe { nil } {
			d.native_storage_ = platform.new_retained_arena('native document')
		} else if d.native_storage_borrowed_ {
			// An embedder can explicitly keep an inert template owner separately.
			d.native_storage_.retain()
			d.native_storage_borrowed_ = false
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

// The caller first closes the realm, cancels resource callbacks, removes this
// document's event-loop tasks and releases the layout publisher. Retained
// native geometry/scenes can still keep the payload arena alive afterwards.
pub fn (mut d Document) release_native_storage() {
	mut storage := d.native_storage_
	d.native_storage_ = unsafe { nil }
	if d.native_storage_borrowed_ {
		d.native_storage_borrowed_ = false
		return
	}
	if storage != unsafe { nil } {
		// The translated range registry is process-wide (weak upstream).
		// Native runtime closure has removed every script owner at this point.
		for key in dom_live_ranges.keys() {
			range := dom_live_ranges[key]
			if voidptr(range.start_container().document()) == voidptr(&d) {
				dom_live_ranges.delete(key)
			}
		}
		if d.paint_borrowed_by_host { storage.pin() }
		storage.release()
	}
}
