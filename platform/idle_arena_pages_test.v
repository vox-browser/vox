module platform

#include "@DIR/arena_page_retirement_test.h"

fn C.vox_arena_test_resident_bytes(start voidptr, bytes usize) usize

fn test_idle_trim_preserves_live_and_entered_arenas_then_discards_reset_pages() {
	$if !prealloc { return }
	mut arena := new_arena('small idle payload')
	defer { arena.release() }
	entry := arena.enter()
	assert !arena.trim_empty_pages()
	bytes := []u8{len:128 * 1024, init:91}
	arena.leave(entry)
	assert !arena.trim_empty_pages()
	assert bytes[0] == 91 && bytes[bytes.len - 1] == 91
	capacity := arena.usage().capacity
	data := bytes.data
	arena.reset()
	assert arena.trim_empty_pages()
	assert arena.usage().capacity == capacity && arena.usage().used == 0
	if !arenas_poisoned() {
		assert C.vox_arena_test_resident_bytes(data, 128 * 1024) == 0
	}
	again := arena.enter()
	replacement := []u8{len:128 * 1024, init:37}
	assert replacement[0] == 37 && replacement[replacement.len - 1] == 37
	arena.leave(again)
}

fn test_idle_maintenance_discards_only_the_recycle_cache_payload() {
	$if !prealloc { return }
	// Force a freshly written standard scope block into the recycle cache.
	scratch := begin_thread_scratch('recycled idle payload')
	bytes := []u8{len:128 * 1024, init:83}
	assert bytes[0] == 83 && bytes[bytes.len - 1] == 83
	scratch.finish()
	if arenas_poisoned() { return }
	block := unsafe { &PreallocBlockView(current_block()) }
	cache := unsafe { &PreallocRecycleCacheView(block.recycle_cache) }
	assert cache.count > 0
	count := cache.count
	capacity := cache.bytes
	live := []u8{len:1024, init:19}
	release_unused_browser_memory()
	assert cache.count == count && cache.bytes == capacity
	for index in 0 .. count {
		assert C.vox_arena_test_resident_bytes(cache.starts[index], usize(cache.sizes[index])) == 0
	}
	assert live[0] == 19 && live[1023] == 19
	refill := begin_thread_scratch('recycled idle refill')
	replacement := []u8{len:128 * 1024, init:47}
	assert replacement[0] == 47 && replacement[replacement.len - 1] == 47
	refill.finish()
}
