module libjs

// An open-addressing table from 64-bit key hashes to positions, for the
// lookup caches (own-property hints, complete key indexes, binding hints).
// They already hash their keys; V's map hashed the hash again and probed
// its own buckets, the costliest step of a cached lookup.
struct PositionTable {
mut:
	keys      []u64
	positions []i32 // -1 marks an empty slot.
	count     int
}

@[direct_array_access; inline]
fn (table &PositionTable) get(key u64) ?int {
	if table.count == 0 { return none }
	mask := u64(table.keys.len - 1)
	mut slot := (key ^ (key >> 31)) & mask
	for {
		position := table.positions[slot]
		if position < 0 { return none }
		if table.keys[slot] == key { return int(position) }
		slot = (slot + 1) & mask
	}
	return none
}

@[direct_array_access]
fn (mut table PositionTable) set(key u64, position int) {
	if (table.count + 1) * 4 > table.keys.len * 3 { table.grow() }
	mask := u64(table.keys.len - 1)
	mut slot := (key ^ (key >> 31)) & mask
	for {
		current := table.positions[slot]
		if current < 0 {
			table.keys[slot] = key
			table.positions[slot] = i32(position)
			table.count++
			return
		}
		if table.keys[slot] == key {
			table.positions[slot] = i32(position)
			return
		}
		slot = (slot + 1) & mask
	}
}

fn (mut table PositionTable) grow() {
	capacity := if table.keys.len == 0 { 16 } else { table.keys.len * 2 }
	old_keys := table.keys
	old_positions := table.positions
	table.keys = []u64{len: capacity}
	table.positions = []i32{len: capacity, init: -1}
	table.count = 0
	for slot, position in old_positions {
		if position >= 0 { table.set(old_keys[slot], int(position)) }
	}
}

fn (mut table PositionTable) clear() {
	table.keys = []u64{}
	table.positions = []i32{}
	table.count = 0
}
