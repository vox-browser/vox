module platform

#include "@DIR/arena_page_retirement_test.h"

fn C.vox_arena_test_resident_bytes(start voidptr, bytes uint) uint

fn test_reset_retirement_requires_large_capacity_and_a_cycle_beyond_one_scope_block() {
	mib := i64(1024 * 1024)
	// Per-element scratch cycles in pooled megabyte blocks stay warm.
	assert !arena_reset_retires_pages(0, 4 * mib)
	assert !arena_reset_retires_pages(300, mib)
	assert !arena_reset_retires_pages(arena_warm_reset_bytes, 4 * mib)
	assert arena_reset_retires_pages(arena_warm_reset_bytes + 1, 4 * mib)
	assert arena_reset_retires_pages(4 * mib, 4 * mib)
	// Small arenas keep their pages regardless of usage.
	assert !arena_reset_retires_pages(mib - 1, mib - 1)
}

fn test_small_reset_cycles_reuse_resident_pages() {
	mut arena := new_arena('small warm scratch')
	defer { arena.release() }
	$if prealloc {
		mut previous := unsafe { nil }
		for _ in 0 .. 3 {
			entry := arena.enter()
			small := []u8{len: 4096, init: 7}
			arena.leave(entry)
			if !arenas_poisoned() {
				assert previous == unsafe { nil } || small.data == previous
			}
			previous = small.data
			arena.reset()
			assert arena.usage().used == 0
			if !arenas_poisoned() {
				assert C.vox_arena_test_resident_bytes(small.data, 4096) >= 4096
			}
		}
	}
}

fn test_large_reset_arenas_keep_capacity_and_reuse_addresses_without_retaining_physical_pages() {
	mut arena := new_arena('large empty payload')
	defer { arena.release() }
	entry := arena.enter()
	mut bytes := []u8{len: 4 * 1024 * 1024, init: 91}
	data := bytes.data
	arena.leave(entry)
	$if prealloc {
		capacity := arena.usage().capacity
		before := C.vox_arena_test_resident_bytes(data, uint(bytes.len))
		assert before >= uint(bytes.len)
		arena.reset()
		assert arena.usage().used == 0
		if !arenas_poisoned() {
			assert arena.usage().capacity == capacity
			// Ask the kernel about the dead mapping without dereferencing it.
			assert C.vox_arena_test_resident_bytes(data, 4 * 1024 * 1024) < 512 * 1024
		}
		again := arena.enter()
		mut replacement := []u8{len: 4 * 1024 * 1024, init: 37}
		if !arenas_poisoned() {
			assert replacement.data == data
		}
		replacement[0] = 13
		replacement[replacement.len - 1] = 19
		assert replacement[4096] == 37
		assert replacement[0] == 13 && replacement[replacement.len - 1] == 19
		arena.leave(again)
	}
}
