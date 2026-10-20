module platform

fn make_arena_metadata_callback(value int) fn () int {
	return fn [value] () int { return value }
}

fn test_runtime_closure_directory_outlives_the_callers_allocation_arena() {
	mut arena := new_arena('closure contexts')
	mut callbacks := []fn () int{cap: 4096}
	entry := arena.enter()
	for value in 0 .. 4096 { callbacks << make_arena_metadata_callback(value) }
	for index, callback in callbacks {
		assert callback() == index
		release_closure(voidptr(callback))
	}
	arena.leave(entry)
	callbacks.clear()
	arena.release()
	// Live-directory capacity and executable-page descriptors must still be
	// valid even though every closure from the retired arena was destroyed.
	again := make_arena_metadata_callback(73)
	assert again() == 73
	release_closure(voidptr(again))
}
