module css

// PropertyID is a bounded dense enum, including unresolved shorthands. Keep
// head lookup separate from the entry chains so every declaration and property
// query can use an indexed read instead of hashing the enum.
const cascaded_property_head_count = int(PropertyID.container) + 1

struct CascadedPropertyHeads {
mut:
	// Zero represents an empty head; entry zero is encoded as one. Positions
	// distinguish an absent key (0), a retained empty key (-1), and a live head
	// (its one-based active-vector position). The distinction preserves reads
	// and reverts even when a caller has changed the public presence bitmap.
	heads [cascaded_property_head_count]int
	positions [cascaded_property_head_count]i16
	active []PropertyID
}

@[inline]
fn (heads &CascadedPropertyHeads) get(id PropertyID) int {
	return heads.heads[int(id)] - 1
}

@[inline]
fn (heads &CascadedPropertyHeads) contains(id PropertyID) bool {
	return heads.positions[int(id)] != 0
}

@[inline]
fn (heads &CascadedPropertyHeads) can_set_without_allocation(id PropertyID) bool {
	return heads.positions[int(id)] > 0 || heads.active.len < heads.active.cap
}

fn (mut heads CascadedPropertyHeads) set(id PropertyID, head int) {
	assert head >= -1
	index := int(id)
	if head < 0 {
		heads.remove_active(id)
		heads.positions[index] = -1
	} else if heads.positions[index] <= 0 {
		heads.active << id
		heads.positions[index] = i16(heads.active.len)
	}
	heads.heads[index] = head + 1
}

fn (mut heads CascadedPropertyHeads) delete(id PropertyID) {
	heads.remove_active(id)
	heads.heads[int(id)] = 0
	heads.positions[int(id)] = 0
}

fn (mut heads CascadedPropertyHeads) remove_active(id PropertyID) {
	position := int(heads.positions[int(id)]) - 1
	if position < 0 { return }
	last := heads.active.pop()
	if position < heads.active.len {
		heads.active[position] = last
		heads.positions[int(last)] = i16(position + 1)
	}
}

fn (mut heads CascadedPropertyHeads) reset() {
	// Scratch leases retain the empty membership, as the old hash map did,
	// but the next cascade iterates only its own live heads. No values or
	// sources live in this index, and clear() keeps the active-vector capacity.
	for id in heads.active {
		heads.heads[int(id)] = 0
		heads.positions[int(id)] = -1
	}
	heads.active.clear()
}
