module platform

fn test_persistent_allocations_preserve_tracked_and_raw_scope_ownership_after_growth() {
	original_disabled := arena_state().disable_tracked_persistent_shortcut
	defer {
		mut state := arena_state()
		state.disable_tracked_persistent_shortcut = original_disabled
	}
	for disabled in [false, true] {
		mut arena := new_arena('tracked persistent caller regression')
		$if prealloc {
			mut state := arena_state()
			state.disable_tracked_persistent_shortcut = disabled
		}
		entry := arena.enter()
		mut sum := 0
		for index in 0 .. 32 {
			value := u8(index)
			bytes := []u8{len: 1024 * 1024, init: value}
			sum += bytes[0]
		}
		persistent := enter_persistent()
		kept := []u8{len: 2 * 1024 * 1024, init: 71}
		leave_persistent(persistent)
		marker := []u8{len: 1024, init: 29}
		$if prealloc {
			assert arena.contains(marker.data)
			assert !arena.contains(kept.data)
			assert arena_entered()
		}
		mut scratch := begin_thread_scratch('raw child of tracked caller')
		temporary := []u8{len: 1024 * 1024, init: 43}
		nested_persistent := enter_persistent()
		nested_kept := []u8{len: 3 * 1024 * 1024, init: 83}
		leave_persistent(nested_persistent)
		assert temporary[0] == 43
		$if prealloc { assert !arena.contains(nested_kept.data) }
		scratch.finish()
		after := []u8{len: 1024, init: 31}
		$if prealloc { assert arena.contains(after.data) }
		assert marker[0] == 29 && after[0] == 31
		arena.leave(entry)
		arena.reset()
		assert sum == 496
		assert kept[0] == 71 && kept[kept.len - 1] == 71
		assert nested_kept[0] == 83 && nested_kept[nested_kept.len - 1] == 83
		arena.release()
	}
}
