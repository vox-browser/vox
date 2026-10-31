module platform

fn test_persistent_allocations_escape_scratch_around_a_nested_retained_owner() {
	mut owner := new_retained_arena('nested persistent owner')
	mut scratch := begin_thread_scratch('persistent owner inside scratch')
	mut scope := owner.enter_nested()
	owned := 'owned'.repeat(100).clone()
	entry := enter_persistent()
	retained := 'r'.repeat(20 * 1024 * 1024).clone()
	leave_persistent(entry)
	after_persistent := 'still owned'.repeat(100).clone()
	scope.finish()
	_ = 'temporary caller resumed'.repeat(100)
	scratch.finish()
	$if prealloc {
		assert owner.arena.contains(owned.str)
		assert owner.arena.contains(after_persistent.str)
		assert !owner.arena.contains(retained.str)
	}
	owner.release()
	assert retained.len == 20 * 1024 * 1024
	assert retained[0] == `r` && retained[retained.len - 1] == `r`
}
