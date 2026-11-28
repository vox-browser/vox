module dom

import platform

fn (mut invalidator StyleInvalidator) plan_storage_for_document(document &Document) &platform.Arena {
	$if prealloc {
		mut owner := document.native_storage()
		if owner != unsafe { nil } && !document.native_storage_borrowed_ {
			if invalidator.pending_plan_arena == unsafe { nil } {
				mut scope := owner.enter_nested()
				invalidator.pending_plan_arena = platform.new_arena('pending style invalidations')
				scope.finish()
			}
			return invalidator.pending_plan_arena
		}
	}
	return unsafe { nil }
}

// Sibling rules can enqueue descendant rules for a later branch in the
// traversal. Retire the batch only after its last reader is gone.
fn (mut invalidator StyleInvalidator) reset_consumed_plan_storage() {
	mut storage := invalidator.pending_plan_arena
	if storage != unsafe { nil } && !invalidator.has_pending_invalidations()
		&& invalidator.active_descendant_invalidations.len == 0 && storage.usage().used > 0 {
		storage.reset()
	}
}

fn (mut d Document) release_pending_style_invalidation_storage() {
	mut invalidator := d.style_invalidator_
	if invalidator == unsafe { nil } || d.native_storage_ == unsafe { nil } {
		return
	}
	d.style_invalidator_ = unsafe { nil }
	mut storage := invalidator.pending_plan_arena
	if storage == unsafe { nil } {
		return
	}
	invalidator.pending_invalidations.clear()
	invalidator.active_descendant_invalidations.clear()
	invalidator.pending_plan_arena = unsafe { nil }
	storage.release()
}
