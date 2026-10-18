module layout

import platform

// A set of layout node addresses that keeps its storage when cleared.
// Animated samples refill the same sets every frame; V's map.clear() shrinks
// the index, so every refill would grow (and, under -prealloc, reallocate) it
// again.
struct HandleSet {
mut:
	// Open addressing with linear probing; zero marks an empty slot. The
	// length is zero or a power of two.
	slots []u64
	// Members in insertion order.
	items []u64
}

fn handle_set_slot(handle u64, mask u64) u64 {
	// Node addresses are aligned; mix the high bits into the low ones.
	mut hash := handle ^ (handle >> 29)
	hash *= u64(0xbf58476d1ce4e5b9)
	return (hash ^ (hash >> 32)) & mask
}

fn (set &HandleSet) len() int {
	return set.items.len
}

fn (set &HandleSet) contains(handle u64) bool {
	if set.items.len == 0 || handle == 0 {
		return false
	}
	mask := u64(set.slots.len - 1)
	mut index := handle_set_slot(handle, mask)
	for {
		slot := set.slots[index]
		if slot == handle {
			return true
		}
		if slot == 0 {
			return false
		}
		index = (index + 1) & mask
	}
	return false
}

fn (mut set HandleSet) add(handle u64) {
	if handle == 0 {
		return
	}
	if (set.items.len + 1) * 2 > set.slots.len || set.items.len == set.items.cap {
		if set.contains(handle) {
			return
		}
		set.grow()
	}
	mask := u64(set.slots.len - 1)
	mut index := handle_set_slot(handle, mask)
	for {
		slot := set.slots[index]
		if slot == handle {
			return
		}
		if slot == 0 {
			set.slots[index] = handle
			set.items << handle
			return
		}
		index = (index + 1) & mask
	}
}

// The set belongs to retained layout state, whatever arena its caller is in.
fn (mut set HandleSet) grow() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut capacity := if set.slots.len == 0 { 16 } else { set.slots.len * 2 }
	for (set.items.len + 1) * 2 > capacity {
		capacity *= 2
	}
	mut items := []u64{cap: capacity / 2}
	items << set.items
	set.slots = []u64{len: capacity}
	set.items = items
	mask := u64(capacity - 1)
	for handle in set.items {
		mut index := handle_set_slot(handle, mask)
		for set.slots[index] != 0 {
			index = (index + 1) & mask
		}
		set.slots[index] = handle
	}
}

// clear empties the set and keeps its storage.
fn (mut set HandleSet) clear() {
	if set.items.len == 0 {
		return
	}
	unsafe { vmemset(set.slots.data, 0, set.slots.len * int(sizeof(u64))) }
	set.items.clear()
}
