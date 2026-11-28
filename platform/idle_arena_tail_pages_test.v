module platform

#include "@DIR/arena_page_retirement_test.h"

fn C.vox_arena_test_unused_resident_bytes(start voidptr, bytes uint) uint

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
			uint(first_block.stop) - uint(cursor)) > 0
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
			uint(block.stop) - uint(block.current)) == 0
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

fn test_new_arena_retires_the_unused_suffix_of_a_recycled_large_block() {
	$if prealloc {
		if arenas_poisoned() { return }
		unsafe {
			prealloc_block_pool_set_limit(0)
			prealloc_block_pool_set_limit(256 * 1024 * 1024)
		}
		// Release both a standard first block and a dirty oversized block.
		seed := unsafe { prealloc_scope_begin() }
		payload := []u8{len: 2 * 1024 * 1024, init: 73}
		large := unsafe { &PreallocBlockView(current_block()) }
		start := large.start
		capacity := uint(large.stop) - uint(start)
		assert large.mmap_allocated
		assert payload[0] == 73 && payload[payload.len - 1] == 73
		unsafe { prealloc_scope_end(seed) }

		// Reserve the smaller mapping so the detached arena takes the large one.
		warm := unsafe { prealloc_scope_begin() }
		defer { unsafe { prealloc_scope_end(warm) } }
		mut arena := new_arena('oversized recycled test block')
		defer { arena.release() }
		assert arena.scope.first.start == start
		assert arena.usage().capacity == i64(capacity)
		assert arena.usage().used == 0
		cold_start := unsafe { start + arena_warm_reset_bytes }
		cold_bytes := capacity - uint(arena_warm_reset_bytes)
		resident := C.vox_arena_test_unused_resident_bytes(cold_start, cold_bytes)
		if keep_oversized_arena_pages {
			assert resident > 1024 * 1024
		} else {
			assert resident == 0
		}

		entry := arena.enter()
		replacement := []u8{len: 1536 * 1024, init: 37}
		arena.leave(entry)
		assert replacement.all(it == 37)
		assert arena.usage().blocks == 1
	}
}
