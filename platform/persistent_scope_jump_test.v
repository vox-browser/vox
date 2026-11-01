module platform

fn assert_scope_jump_matches_linear_walk() {
	$if prealloc {
		block := unsafe { &PreallocBlockView(current_block()) }
		mut expected := unsafe { block }
		for expected != unsafe { nil } && expected.is_scope { expected = expected.previous }
		assert voidptr(persistent_parent_outside_scopes(block, true)) == voidptr(expected)
		assert voidptr(persistent_parent_outside_scopes(block, false)) == voidptr(expected)
	}
}

fn test_persistent_scope_jump_matches_linear_parent_after_growth_and_detachment() {
	mut arena := new_arena('persistent scope jump equivalence')
	defer { arena.release() }
	entry := arena.enter()
	mut sum := 0
	for index in 0 .. 24 {
		value := u8(index)
		bytes := []u8{len: 1024 * 1024, init: value}
		sum += bytes[0]
	}
	assert_scope_jump_matches_linear_walk()
	mut outer := begin_thread_scratch('scope jump outer raw scratch')
	for _ in 0 .. 8 { _ = []u8{len: 1024 * 1024, init: 61} }
	assert_scope_jump_matches_linear_walk()
	mut inner := begin_thread_scratch('scope jump inner raw scratch')
	for _ in 0 .. 8 { _ = []u8{len: 1024 * 1024, init: 73} }
	assert_scope_jump_matches_linear_walk()
	persistent := enter_persistent()
	kept := []u8{len: 4 * 1024 * 1024, init: 83}
	assert_scope_jump_matches_linear_walk()
	leave_persistent(persistent)
	assert_scope_jump_matches_linear_walk()
	inner.finish()
	assert_scope_jump_matches_linear_walk()
	outer.finish()
	assert_scope_jump_matches_linear_walk()
	marker := []u8{len: 1024, init: 29}
	$if prealloc {
		assert arena.contains(marker.data)
		assert !arena.contains(kept.data)
	}
	arena.leave(entry)
	arena.reset()
	assert sum == 276
	assert kept[0] == 83 && kept[kept.len - 1] == 83
	// Raw scopes rooted in the real base retain a non-nil parent instead.
	mut base_scratch := begin_thread_scratch('scope jump raw base parent')
	for _ in 0 .. 8 { _ = []u8{len: 1024 * 1024, init: 47} }
	assert_scope_jump_matches_linear_walk()
	base_scratch.finish()
}
