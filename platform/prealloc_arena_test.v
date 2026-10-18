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
		assert voidptr(second) == voidptr(first)
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

fn test_reset_keeps_one_block_sized_to_the_high_water_mark() {
	mut arena := new_arena('test')
	defer { arena.release() }
	for round in 0 .. 4 {
		entry := arena.enter()
		nodes := arena_test_allocate(20000)
		arena.leave(entry)
		assert nodes[19999].value == 19999
		$if prealloc {
			usage := arena.usage()
			if round >= 1 {
				// After the first reset one block covers a whole round.
				assert usage.blocks == 1
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
