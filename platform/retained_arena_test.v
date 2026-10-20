module platform

struct RetainedArenaTestNode {
	value int
}

fn test_retained_arena_waits_for_snapshot_and_scope() {
	mut storage := new_retained_arena('retained test')
	mut scope := storage.enter()
	value := &RetainedArenaTestNode{ value: 42 }
	storage.retain()
	storage.release() // Document retires while a scope and snapshot remain.
	scope.finish()
	assert value.value == 42
	$if prealloc {
		assert storage.arena.usage().used > 0
	}
	storage.release()
	assert storage.arena.usage().used == 0
}

fn test_retained_arena_preserves_nested_allocation_target() {
	mut storage := new_retained_arena('retained outer')
	mut scope := storage.enter()
	mut nested := storage.enter()
	value := &RetainedArenaTestNode{ value: 17 }
	$if prealloc {
		assert voidptr(current_retained_arena()) == voidptr(storage)
	}
	nested.finish()
	assert value.value == 17
	$if prealloc {
		assert storage.arena.contains(value)
	}
	scope.finish()
	assert current_retained_arena() == unsafe { nil }
	storage.release()
}
