module platform

struct RetainedArenaTestNode {
	value int
}

struct RetainedArenaCleanupProbe {
mut:
	calls int
	bytes_before_release i64
}

fn test_dependent_storage_retires_after_final_reader_before_payload_release() {
	mut storage := new_retained_arena('cleanup ordering')
	probe := &RetainedArenaCleanupProbe{}
	storage.add_cleanup(fn [storage, probe] () {
		mut observation := unsafe { &RetainedArenaCleanupProbe(probe) }
		observation.calls++
		observation.bytes_before_release = storage.arena.usage().used
	})
	mut scope := storage.enter()
	value := &RetainedArenaTestNode{value: 19}
	storage.retain()
	scope.finish()
	storage.release()
	assert probe.calls == 0 && value.value == 19
	storage.release()
	assert probe.calls == 1
	$if prealloc { assert probe.bytes_before_release > 0 }
	assert storage.arena.usage().used == 0
}

fn fill_cache_from_worker() bool {
	entry := enter_persistent()
	value := 'worker-owned allocation'.bytes()
	leave_persistent(entry)
	return value.len == 23 && current_retained_arena() == unsafe { nil }
}

fn test_persistent_cache_sections_do_not_enter_an_origin_arena_from_workers() {
	mut storage := new_retained_arena('origin cache')
	mut scope := storage.enter()
	worker := spawn fill_cache_from_worker()
	assert worker.wait()
	scope.finish()
	storage.release()
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
