module platform

#include "@DIR/arena_page_retirement_test.h"

fn C.vox_arena_test_resident_bytes(start voidptr, bytes uint) uint

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
