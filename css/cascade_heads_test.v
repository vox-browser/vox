module css

fn cascade_heads_assert_map_equivalent(heads &CascadedPropertyHeads, expected map[PropertyID]int) {
	mut live := 0
	for index in 0 .. cascaded_property_head_count {
		id := unsafe { PropertyID(index) }
		assert heads.contains(id) == (id in expected)
		assert heads.get(id) == (expected[id] or { -1 })
		if expected[id] or { -1 } >= 0 { live++ }
	}
	assert heads.active.len == live
	mut seen := map[PropertyID]bool{}
	for id in heads.active {
		assert id !in seen
		seen[id] = true
		assert expected[id] or { -1 } >= 0
	}
}

fn test_cascade_heads_cover_every_generated_id_and_entry_zero() {
	assert cascaded_property_head_count <= 32767
	assert int(PropertyID.accent_color) == 0
	mut heads := CascadedPropertyHeads{}
	mut expected := map[PropertyID]int{}
	cascade_heads_assert_map_equivalent(&heads, expected)
	for index in 0 .. cascaded_property_head_count {
		id := unsafe { PropertyID(index) }
		heads.set(id, index)
		expected[id] = index
	}
	cascade_heads_assert_map_equivalent(&heads, expected)
	assert heads.get(.accent_color) == 0
	assert heads.get(.container) == cascaded_property_head_count - 1
	for index in 0 .. cascaded_property_head_count {
		id := unsafe { PropertyID(index) }
		heads.set(id, index + 1_000_000)
		expected[id] = index + 1_000_000
	}
	cascade_heads_assert_map_equivalent(&heads, expected)
}

fn test_cascade_heads_match_map_during_mixed_set_empty_delete_and_reset() {
	mut heads := CascadedPropertyHeads{}
	mut expected := map[PropertyID]int{}
	mut state := u64(0x5eed)
	for step in 0 .. 4096 {
		state = (state * 1664525 + 1013904223) & 0xffffffff
		id := unsafe { PropertyID(int(state % u64(cascaded_property_head_count))) }
		if step % 257 == 256 {
			heads.reset()
			for key, _ in expected { expected[key] = -1 }
		} else {
			match step % 7 {
				2 {
					heads.set(id, -1)
					expected[id] = -1
				}
				3, 6 {
					heads.delete(id)
					expected.delete(id)
				}
				else {
					heads.set(id, step)
					expected[id] = step
				}
			}
		}
		cascade_heads_assert_map_equivalent(&heads, expected)
	}
}

fn test_cascade_heads_revert_readd_and_reset_keep_active_storage_bounded() {
	mut heads := CascadedPropertyHeads{}
	heads.set(.color, 0)
	heads.set(.width, 1)
	capacity := heads.active.cap
	buffer := heads.active.data
	for _ in 0 .. 4096 {
		heads.set(.color, -1)
		assert heads.contains(.color)
		assert heads.get(.color) == -1
		assert heads.active.len == 1
		heads.set(.color, 0)
		assert heads.active.len == 2
		heads.delete(.width)
		assert !heads.contains(.width)
		heads.set(.width, 1)
		heads.reset()
		assert heads.active.len == 0
		assert heads.get(.color) == -1
		assert heads.get(.width) == -1
		heads.set(.width, 1)
		heads.set(.color, 0)
		assert heads.active.cap == capacity
		assert heads.active.data == buffer
	}
}

fn test_cascade_heads_known_empty_membership_does_not_imply_spare_active_capacity() {
	mut heads := CascadedPropertyHeads{active: []PropertyID{cap: 1}}
	heads.set(.width, 0)
	heads.reset()
	heads.set(.height, 0)
	heads.reset()
	assert heads.contains(.width) && heads.contains(.height)
	assert heads.active.cap == 1
	assert heads.can_set_without_allocation(.width)
	heads.set(.width, 0)
	assert heads.can_set_without_allocation(.width)
	assert !heads.can_set_without_allocation(.height)
	assert !heads.can_set_without_allocation(.color)
	heads.set(.width, -1)
	assert heads.can_set_without_allocation(.height)
}
