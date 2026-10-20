module platform

struct ArenaTestNode {
	value int
	name  string
}

fn arena_test_allocate(count int) []&ArenaTestNode {
	mut nodes := []&ArenaTestNode{cap: count}
	for index in 0 .. count {
		nodes << &ArenaTestNode{
			value: index
			name:  'node ${index}'
		}
	}
	return nodes
}

fn test_entered_arena_receives_allocations_and_reset_reuses_them() {
	mut arena := new_arena('test')
	defer { arena.release() }
	entry := arena.enter()
	first := &ArenaTestNode{
		value: 1
	}
	arena.leave(entry)
	outside := &ArenaTestNode{
		value: 2
	}
	$if prealloc {
		assert arena.contains(voidptr(first))
		assert !arena.contains(voidptr(outside))
		assert arena.usage().used > 0
		arena.reset()
		assert arena.usage().used == 0
		again := arena.enter()
		second := &ArenaTestNode{
			value: 3
		}
		arena.leave(again)
		if arenas_poisoned() {
			assert voidptr(second) != voidptr(first)
		} else {
			assert voidptr(second) == voidptr(first)
		}
	} $else {
		assert !arena.contains(voidptr(first))
		assert arena.usage().used == 0
	}
}

fn test_persistent_allocations_escape_the_entered_arena() {
	mut arena := new_arena('test')
	defer { arena.release() }
	before := thread_arena_usage()
	entry := arena.enter()
	scratch := &ArenaTestNode{
		value: 1
	}
	persistent_entry := enter_persistent()
	kept := &ArenaTestNode{
		value: 2
	}
	leave_persistent(persistent_entry)
	more_scratch := &ArenaTestNode{
		value: 3
	}
	arena.leave(entry)
	$if prealloc {
		assert arena.contains(voidptr(scratch))
		assert arena.contains(voidptr(more_scratch))
		assert !arena.contains(voidptr(kept))
		assert thread_arena_usage().used > before.used
	}
	assert kept.value == 2
}

fn test_nested_persistent_sections_stay_in_the_base_arena() {
	mut arena := new_arena('test')
	defer { arena.release() }
	entry := arena.enter()
	outer := enter_persistent()
	// Grow the base arena past its saved tail before the nested section.
	grown := []u8{len: 64 * 1024 * 1024}
	inner := enter_persistent()
	nested := &ArenaTestNode{
		value: 1
	}
	$if prealloc {
		assert !arena_entered()
	}
	leave_persistent(inner)
	after_inner := &ArenaTestNode{
		value: 2
	}
	leave_persistent(outer)
	scratch := &ArenaTestNode{
		value: 3
	}
	arena.leave(entry)
	$if prealloc {
		assert !arena.contains(voidptr(nested))
		assert !arena.contains(voidptr(after_inner))
		assert arena.contains(voidptr(scratch))
		assert !arena_entered()
	}
	assert grown.len == 64 * 1024 * 1024
	assert nested.value + after_inner.value + scratch.value == 6
}

fn test_no_reuse_label_poisons_only_that_arena() {
	mut reused := new_arena('test reused')
	mut kept := new_arena('test no reuse')
	defer {
		reused.release()
		kept.release()
	}
	$if prealloc {
		mut state := arena_state()
		if state.poison { return }
		state.no_reuse = ['test no reuse']
	}
	first_entry := reused.enter()
	first := &ArenaTestNode{ value: 1 }
	reused.leave(first_entry)
	kept_entry := kept.enter()
	old := &ArenaTestNode{ value: 2 }
	kept.leave(kept_entry)
	reused.reset()
	kept.reset()
	again := reused.enter()
	second := &ArenaTestNode{ value: 3 }
	reused.leave(again)
	kept_again := kept.enter()
	fresh := &ArenaTestNode{ value: 4 }
	kept.leave(kept_again)
	$if prealloc {
		arena_state().no_reuse = []string{}
		assert voidptr(second) == voidptr(first)
		assert voidptr(fresh) != voidptr(old)
		assert !kept.contains(voidptr(old))
	}
	assert second.value + fresh.value == 7
}

fn test_reset_reuses_the_blocks_of_the_high_water_mark() {
	mut arena := new_arena('test')
	defer { arena.release() }
	mut settled := ArenaUsage{}
	for round in 0 .. 4 {
		entry := arena.enter()
		nodes := arena_test_allocate(20000)
		arena.leave(entry)
		assert nodes[19999].value == 19999
		$if prealloc {
			usage := arena.usage()
			if round == 1 {
				settled = usage
			} else if round > 1 {
				// The rewound blocks hold a whole round: nothing new is mapped.
				assert usage.capacity == settled.capacity
				assert usage.blocks == settled.blocks
			}
		}
		arena.reset()
	}
	assert arena.reset_count() == $if prealloc { u64(4) } $else { u64(0) }
}

fn test_nested_arenas_restore_their_targets() {
	mut outer := new_arena('outer')
	mut inner := new_arena('inner')
	defer {
		inner.release()
		outer.release()
	}
	outer_entry := outer.enter()
	a := &ArenaTestNode{
		value: 1
	}
	inner_entry := inner.enter()
	b := &ArenaTestNode{
		value: 2
	}
	persistent_entry := enter_persistent()
	c := &ArenaTestNode{
		value: 3
	}
	leave_persistent(persistent_entry)
	inner.leave(inner_entry)
	d := &ArenaTestNode{
		value: 4
	}
	outer.leave(outer_entry)
	$if prealloc {
		assert outer.contains(voidptr(a))
		assert inner.contains(voidptr(b))
		assert !outer.contains(voidptr(c)) && !inner.contains(voidptr(c))
		assert outer.contains(voidptr(d))
	}
	assert a.value + b.value + c.value + d.value == 10
}

fn test_arena_entered_from_persistent_section_restores_depth_and_latest_base_tail() {
	mut outer := new_arena('outer durable owner')
	mut inner := new_arena('nested temporary')
	outer_entry := outer.enter()
	persistent := enter_persistent()
	inner_entry := inner.enter()
	inside := &ArenaTestNode{ value: 17 }
	nested_persistent := enter_persistent()
	grown := []u8{len: 32 * 1024 * 1024, init: 19}
	$if prealloc {
		assert !arena_entered()
	}
	leave_persistent(nested_persistent)
	$if prealloc {
		assert arena_entered()
	}
	inner.leave(inner_entry)
	$if prealloc {
		assert !arena_entered()
		assert current_block() == arena_state().base_tail
		assert inner.contains(inside)
	}
	base_tail := current_block()
	leave_persistent(persistent)
	after := &ArenaTestNode{ value: 23 }
	$if prealloc {
		assert outer.contains(after)
	}
	outer.leave(outer_entry)
	$if prealloc {
		assert current_block() == base_tail
	}
	inner.release()
	outer.release()
	assert grown[0] == 19 && grown[grown.len - 1] == 19
	assert !arena_entered()
}
