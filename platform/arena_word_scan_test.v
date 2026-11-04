module platform

fn arena_word_scan_oracle(arena &Arena, words []voidptr, size int) bool {
	for index in 0 .. size / int(sizeof(voidptr)) {
		if arena.contains(words[index]) { return true }
	}
	return false
}

fn test_arena_word_scan_matches_scalar_ownership_at_every_buffer_boundary() {
	mut arena := new_arena('word scan owner')
	defer { arena.release() }
	mut other := new_arena('word scan unrelated')
	defer { other.release() }
	entry := arena.enter()
	first := []u8{len: 256 * 1024, init: 17}
	second := []u8{len: 1024 * 1024, init: 31}
	third := []u8{len: 1024 * 1024, init: 47}
	arena.leave(entry)
	unrelated_entry := other.enter()
	unrelated := []u8{len: 256 * 1024, init: 53}
	other.leave(unrelated_entry)
	assert first[0] == 17 && second[0] == 31 && third[0] == 47 && unrelated[0] == 53
	mut candidates := [voidptr(unsafe { nil }), voidptr(first.data), voidptr(second.data),
		voidptr(third.data), voidptr(unrelated.data)]
	$if prealloc {
		mut block := arena.scope.first
		mut blocks := 0
		for block != unsafe { nil } && block.scope == voidptr(arena.scope) {
			blocks++
			// Only the buffer is dereferenced, never these synthesized candidate
			// addresses. Include both sides of every real allocation boundary.
			for address in [uint(block.start) - 1, uint(block.start), uint(block.stop) - 1,
				uint(block.stop), uint(block.stop) + 1] {
				candidates << unsafe { voidptr(address) }
			}
			block = block.next
		}
		assert blocks >= 2
	}
	for address in [u64(1), u64(0x80000000), u64(0x7fffffffffffffff), ~u64(0)] {
		candidates << unsafe { voidptr(address) }
	}
	mut words := []voidptr{len: 17, init: unsafe { nil }}
	for candidate in candidates {
		for position in 0 .. words.len {
			words[position] = candidate
			for size in 0 .. words.len * int(sizeof(voidptr)) + 1 {
				actual := unsafe { arena.contains_any_word(words.data, size) }
				assert actual == arena_word_scan_oracle(arena, words, size)
			}
			words[position] = unsafe { nil }
		}
	}
	assert !unsafe { arena.contains_any_word(unsafe { nil }, 1024) }
	assert !unsafe { arena.contains_any_word(words.data, -1) }
}

fn test_arena_word_scan_handles_empty_reset_and_released_scopes() {
	mut arena := new_arena('word scan lifecycle')
	mut words := [voidptr(unsafe { nil }), unsafe { voidptr(u64(1)) }]
	assert !unsafe { arena.contains_any_word(words.data, words.len * int(sizeof(voidptr))) }
	entry := arena.enter()
	payload := []u8{len: 128, init: 19}
	arena.leave(entry)
	words[1] = payload.data
	assert unsafe { arena.contains_any_word(words.data, words.len * int(sizeof(voidptr))) } == arena.contains(payload.data)
	arena.reset()
	assert unsafe { arena.contains_any_word(words.data, words.len * int(sizeof(voidptr))) } == arena.contains(payload.data)
	arena.release()
	assert !unsafe { arena.contains_any_word(words.data, words.len * int(sizeof(voidptr))) }
}
