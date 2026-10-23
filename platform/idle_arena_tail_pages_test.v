module platform

#include "@DIR/arena_page_retirement_test.h"

fn C.vox_arena_test_unused_resident_bytes(start voidptr, bytes usize) usize

fn test_idle_tail_trim_preserves_live_bytes_and_allocator_cursors_across_refills() {
	$if !prealloc {
		return
	}
	mut arena := new_arena('live idle tail')
	defer { arena.release() }
	warm := arena.enter()
	first := []u8{len: 200 * 1024, init: 71}
	second := []u8{len: 460 * 1024, init: 89}
	assert first[0] == 71 && second[second.len - 1] == 89
	arena.leave(warm)
	arena.reset()
	entry := arena.enter()
	live := []u8{len: 17 * 1024 + 3, init: 43}
	assert !arena.trim_unused_pages()
	arena.leave(entry)
	before := arena.usage()
	first_block := arena.scope.first
	cursor := first_block.current
	next := first_block.next
	tail := arena.tail
	if !arenas_poisoned() {
		assert before.blocks >= 2
		assert C.vox_arena_test_unused_resident_bytes(cursor,
			usize(first_block.stop) - usize(cursor)) > 0
	}
	assert arena.trim_unused_pages()
	assert arena.usage().used == before.used
	assert arena.usage().capacity == before.capacity
	assert arena.usage().blocks == before.blocks
	assert voidptr(arena.scope.first) == voidptr(first_block)
	assert voidptr(arena.tail) == voidptr(tail)
	assert first_block.current == cursor && voidptr(first_block.next) == voidptr(next)
	assert live.all(it == 43)
	mut block := arena.scope.first
	for block != unsafe { nil } && block.scope == voidptr(arena.scope) {
		assert C.vox_arena_test_unused_resident_bytes(block.current,
			usize(block.stop) - usize(block.current)) == 0
		block = block.next
	}
	refill := arena.enter()
	replacement := []u8{len: 300 * 1024, init: 19}
	arena.leave(refill)
	assert replacement.all(it == 19)
	assert live.all(it == 43)
	assert arena.trim_unused_pages()
	assert replacement.all(it == 19) && live.all(it == 43)
}
