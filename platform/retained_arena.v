module platform

// A document owns one reference; exported snapshots and entered scopes own
// additional references. The owner object itself always lives in base storage.
@[heap]
pub struct RetainedArena {
pub:
	arena &Arena = unsafe { nil }
mut:
	references int = 1
	pinned     bool
	cleanup []fn ()
}

pub fn new_retained_arena(label string) &RetainedArena {
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	return &RetainedArena{ arena: new_arena(label) }
}

pub fn (mut storage RetainedArena) retain() {
	assert storage.references > 0
	storage.references++
}

pub fn (mut storage RetainedArena) release() {
	assert storage.references > 0
	storage.references--
	if storage.references == 0 && !storage.pinned {
		for callback in storage.cleanup { callback() }
		storage.cleanup.clear()
		mut arena := storage.arena
		arena.release()
	}
}

// Dependent arenas (such as animation samples) remain readable by snapshots
// for exactly as long as the document payload, and retire before that payload.
pub fn (mut storage RetainedArena) add_cleanup(callback fn ()) {
	assert storage.references > 0
	persistent := enter_persistent()
	storage.cleanup << callback
	leave_persistent(persistent)
}

// Cross-document adoption or an untracked host borrower conservatively keeps
// the allocation owner alive. Those references have no native release boundary.
pub fn (mut storage RetainedArena) pin() { storage.pinned = true }

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

pub fn (mut scope RetainedArenaScope) finish() {
	if scope.storage == unsafe { nil } { return }
	mut storage := scope.storage
	scope.storage = unsafe { nil }
	mut arena := storage.arena
	arena.leave(scope.entry)
	$if prealloc {
		arena_thread_state.retained = unsafe { nil }
	}
	storage.release()
}
