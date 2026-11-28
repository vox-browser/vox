module libjs

// Colliding slots, updates, growth and clearing keep every stored position.
fn test_position_table_keeps_positions_through_collisions_and_growth() {
	mut table := PositionTable{}
	assert table.get(7) == none
	for index in 0 .. 1000 {
		// Keys that share their low bits collide in the first table.
		table.set(u64(index) << 40, index)
	}
	assert table.count == 1000
	for index in 0 .. 1000 {
		assert table.get(u64(index) << 40) or { -1 } == index
	}
	assert table.get(u64(1001) << 40) == none && table.get(0xffffffffffffffff) == none
	table.set(u64(5) << 40, 77)
	assert table.count == 1000 && table.get(u64(5) << 40) or { -1 } == 77
	table.set(0, 3)
	assert table.get(0) or { -1 } == 3
	table.clear()
	assert table.count == 0 && table.get(0) == none
	table.set(9, 1)
	assert table.get(9) or { -1 } == 1
}
