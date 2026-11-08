module platform

// A document owns one reference; exported snapshots and entered scopes own
// additional references. The owner object itself always lives in base storage.
@[heap]
pub struct RetainedArena {
pub:
	arena &Arena = unsafe { nil }
mut:
	references int = 1
	lifetime   &RetainedArenaLifetime = unsafe { nil }
	cleanup []fn ()
}

// Adoption preserves node identity, so allocations cannot be moved between
// arenas. Aliased arenas instead share one final release boundary. Only
// callers' references count: sharing adds no reference and cannot form a
// cycle, including when nodes are adopted back into their original document.
@[heap]
struct RetainedArenaLifetime {
mut:
	references int
	members []&RetainedArena
}

pub fn new_retained_arena(label string) &RetainedArena {
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	return &RetainedArena{ arena: new_arena(label) }
}

pub fn (mut storage RetainedArena) retain() {
	assert storage.is_live()
	storage.references++
	if storage.lifetime != unsafe { nil } { storage.lifetime.references++ }
}

pub fn (mut storage RetainedArena) release() {
	assert storage.references > 0
	storage.references--
	mut lifetime := storage.lifetime
	if lifetime != unsafe { nil } {
		assert lifetime.references > 0
		lifetime.references--
		if lifetime.references > 0 { return }
		// A cleanup may still read another member's adopted nodes or policy
		// objects. Finish every cleanup before releasing any member payload.
		for mut member in lifetime.members {
			assert member.references == 0
			member.run_cleanup()
		}
		for member in lifetime.members {
			mut arena := member.arena
			arena.release()
		}
		lifetime.members.clear()
		return
	}
	if storage.references > 0 { return }
	storage.run_cleanup()
	mut arena := storage.arena
	arena.release()
}

fn (storage &RetainedArena) is_live() bool {
	if storage.lifetime != unsafe { nil } { return storage.lifetime.references > 0 }
	return storage.references > 0
}

fn (mut storage RetainedArena) run_cleanup() {
	for callback in storage.cleanup {
		callback()
		release_closure(voidptr(callback))
	}
	storage.cleanup.clear()
}

fn (mut storage RetainedArena) lifetime_group() &RetainedArenaLifetime {
	if storage.lifetime == unsafe { nil } {
		storage.lifetime = &RetainedArenaLifetime{
			references: storage.references
			members: [unsafe { &RetainedArena(storage) }]
		}
	}
	return storage.lifetime
}

// Promote two indivisible allocation owners to a shared lifetime. All their
// existing and future leases remain balanced; the final lease releases every
// arena in the group. Repeated, reciprocal and transitive sharing adds no
// references. A member with no local leases can still be shared or retained
// while another member keeps the group alive.
pub fn (mut storage RetainedArena) share_lifetime(other &RetainedArena) {
	assert storage.is_live() && other.is_live()
	if voidptr(&storage) == voidptr(other) { return }
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	mut destination := storage.lifetime_group()
	mut other_storage := unsafe { &RetainedArena(other) }
	mut source := other_storage.lifetime_group()
	if voidptr(destination) == voidptr(source) { return }
	// Move the smaller group, so repeated adoption into fresh documents does
	// not repeatedly traverse all previously shared allocation owners.
	if destination.members.len < source.members.len {
		temporary := destination
		destination = source
		source = temporary
	}
	destination.references += source.references
	for mut member in source.members {
		member.lifetime = destination
		destination.members << member
	}
	source.members.clear()
	source.references = 0
}

// Dependent arenas (such as animation samples) remain readable by snapshots
// for exactly as long as the document payload, and retire before that payload.
// Registration transfers ownership of a closure; its capture is released
// after cleanup so the runtime's closure directory cannot keep owners alive.
pub fn (mut storage RetainedArena) add_cleanup(callback fn ()) {
	assert storage.is_live()
	persistent := enter_persistent()
	storage.cleanup << callback
	leave_persistent(persistent)
}

// Only the arena's originating thread manipulates leases. Workers receive a
// lease retained on the origin thread and return it for release there.
pub fn current_retained_arena() &RetainedArena {
	$if prealloc {
		if arena_thread_state.owner == u64(C.pthread_self()) {
			return arena_thread_state.retained
		}
	}
	return unsafe { nil }
}

pub struct RetainedArenaScope {
mut:
	storage &RetainedArena = unsafe { nil }
	entry   ArenaEntry
	previous &RetainedArena = unsafe { nil }
	redirect RetainedAllocationScope
}

pub fn (mut storage RetainedArena) enter() RetainedArenaScope {
	$if prealloc {
		// Preserve nested sample/scene arenas and persistent cache sections.
		if arena_state().depth != 0 { return RetainedArenaScope{} }
		storage.retain()
		arena_thread_state.retained = storage
		return RetainedArenaScope{ storage: storage, entry: storage.arena.enter() }
	}
	return RetainedArenaScope{}
}

// An independently owned embedded document can be parsed or laid out while
// its host's frame workspace is entered. This explicit boundary switches the
// owner too; ordinary enter() continues to preserve arbitrary nested scratch.
pub fn (mut storage RetainedArena) enter_nested() RetainedArenaScope {
	$if prealloc {
		mut state := arena_state()
		if storage.arena.entered {
			assert voidptr(state.retained) == voidptr(storage)
			return RetainedArenaScope{redirect: enter_retained_allocations()}
		}
		storage.retain()
		previous := state.retained
		state.retained = storage
		return RetainedArenaScope{storage:storage, previous:previous, entry:storage.arena.enter()}
	}
	return RetainedArenaScope{}
}

pub fn (mut scope RetainedArenaScope) finish() {
	scope.redirect.finish()
	if scope.storage == unsafe { nil } { return }
	mut storage := scope.storage
	scope.storage = unsafe { nil }
	mut arena := storage.arena
	arena.leave(scope.entry)
	$if prealloc {
		arena_thread_state.retained = scope.previous
	}
	storage.release()
}
