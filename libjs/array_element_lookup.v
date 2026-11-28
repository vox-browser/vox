module libjs

// Array index properties stay below the array's length: ArrayDefineOwnProperty
// and define_direct_property grow the length before an index is stored, and
// ArraySetLength deletes every index at or above a shorter length. Fresh and
// literal arrays also store element i at position i of the property vector.
// Index lookups on large arrays used the hashed position hints, and a miss
// (every push) scanned the whole vector. A key at or above the length is now
// absent at once, and a positional hit is verified against the live key; any
// other case keeps the hinted lookup.
//
// Every own property is appended through define_direct_property or the fresh
// index paths, so the array counts appended non-index keys. Deletion keeps the
// count, which then only over-estimates; with no named property, a name or
// symbol lookup (a.push, a[Symbol.iterator]) is absent without a scan.

const array_index_position_unknown = -2

$if test {
	__global array_index_positions_disabled bool
	pub fn set_array_index_positions_for_testing(enabled bool) {
		array_index_positions_disabled = !enabled
	}
}

@[inline]
fn is_array_index_key(key PropertyName) bool {
	return key.kind == .number_key && key.number != 0xffffffff
}

@[inline]
fn (mut object Object) count_appended_array_property(key PropertyName) {
	if is_array_index_key(key) { return }
	if mut array := object.array_object { array.named_properties++ }
}

@[inline]
fn (object &Object) array_index_position(key PropertyName) int {
	$if test {
		if array_index_positions_disabled { return array_index_position_unknown }
	}
	array := object.array_object or { return array_index_position_unknown }
	if !is_array_index_key(key) {
		return if array.named_properties == 0 { -1 } else { array_index_position_unknown }
	}
	if key.number >= array.length { return -1 }
	index := int(key.number)
	if index < object.properties.len {
		candidate := &object.properties[index]
		if candidate.key.kind == .number_key && candidate.key.number == key.number { return index }
	}
	return array_index_position_unknown
}
