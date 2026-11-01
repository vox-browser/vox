module platform

// Current V folds small literal repeat() calls into static strings. Ownership
// checks need an allocation made while the selected arena is actually entered.
@[noinline]
fn retained_redirect_runtime_string(value string, count int) string {
	return value.repeat(count)
}

fn retained_bytes_match(text string, byte u8) bool {
	return text.len > 0 && text[0] == byte && text[text.len - 1] == byte
}

fn test_retained_redirects_survive_nested_scratch_and_document_block_growth() {
	mut scratch := new_arena('retained redirect scratch')
	mut nested := new_arena('retained redirect nested')
	mut owner := new_retained_arena('retained redirect document')
	mut document := owner.enter()
	first := retained_redirect_runtime_string('a', 1024)
	entry := scratch.enter()
	_ = 'x'.repeat(1024 * 1024)
	mut retained := enter_retained_allocations()
	second := 'b'.repeat(6 * 1024 * 1024)
	nested_entry := nested.enter()
	_ = 'y'.repeat(1024 * 1024)
	mut nested_retained := enter_retained_allocations()
	third := 'c'.repeat(6 * 1024 * 1024)
	nested_retained.finish()
	_ = 'z'.repeat(1024 * 1024)
	nested.leave(nested_entry)
	fourth := 'd'.repeat(1024 * 1024)
	retained.finish()
	_ = 'q'.repeat(1024 * 1024)
	scratch.leave(entry)
	scratch.reset()
	nested.reset()
	last := 'e'.repeat(1024 * 1024)
	for index, text in [first, second, third, fourth, last] {
		assert retained_bytes_match(text, u8(`a` + index))
		$if prealloc {
			assert owner.arena.contains(text.str)
		}
	}
	document.finish()
	owner.release()
	scratch.release()
	nested.release()
	assert owner.arena.usage().used == 0
	assert sizeof(RetainedAllocationScope) <= 16
	assert sizeof(ArenaEntry) == 16
}

fn test_retained_redirect_from_persistent_preserves_both_latest_allocation_tails() {
	mut scratch := new_arena('persistent redirect scratch')
	mut owner := new_retained_arena('persistent redirect document')
	mut document := owner.enter()
	entry := scratch.enter()
	persistent := enter_persistent()
	base_first := 'f'.repeat(20 * 1024 * 1024)
	mut retained := enter_retained_allocations()
	durable := 'g'.repeat(6 * 1024 * 1024)
	inner_persistent := enter_persistent()
	base_second := 'h'.repeat(20 * 1024 * 1024)
	leave_persistent(inner_persistent)
	retained.finish()
	base_third := 'i'.repeat(1024 * 1024)
	leave_persistent(persistent)
	_ = 'j'.repeat(1024 * 1024)
	scratch.leave(entry)
	scratch.reset()
	assert retained_bytes_match(durable, `g`)
	$if prealloc {
		assert owner.arena.contains(durable.str)
	}
	document.finish()
	owner.release()
	scratch.release()
	assert retained_bytes_match(base_first, `f`)
	assert retained_bytes_match(base_second, `h`)
	assert retained_bytes_match(base_third, `i`)
}

fn test_retained_redirect_does_not_replace_a_thread_scratch_parent_tail() {
	mut owner := new_retained_arena('thread redirect document')
	mut document := owner.enter()
	before := retained_redirect_runtime_string('k', 1024)
	mut scratch := begin_thread_scratch('untracked scope around retained allocation')
	_ = 'l'.repeat(1024 * 1024)
	persistent := enter_persistent()
	base := 'm'.repeat(20 * 1024 * 1024)
	leave_persistent(persistent)
	mut retained := enter_retained_allocations()
	durable := 'n'.repeat(6 * 1024 * 1024)
	retained.finish()
	_ = 'o'.repeat(1024 * 1024)
	scratch.finish()
	after := 'p'.repeat(1024 * 1024)
	assert retained_bytes_match(before, `k`)
	assert retained_bytes_match(durable, `n`)
	assert retained_bytes_match(after, `p`)
	$if prealloc {
		assert owner.arena.contains(before.str)
		assert owner.arena.contains(durable.str)
		assert owner.arena.contains(after.str)
	}
	document.finish()
	owner.release()
	assert retained_bytes_match(base, `m`)
}
