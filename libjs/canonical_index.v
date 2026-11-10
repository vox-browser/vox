module libjs

// Runtime/CanonicalIndex.h and AbstractOperations.cpp::CanonicalNumericIndexString.
// The pinned source distinguishes stored u32 indices from numeric strings which
// round-trip but are not indices; the latter deliberately retain a zero payload.
pub enum CanonicalIndexType {
	index
	numeric
	undefined
}

pub struct CanonicalIndex {
pub:
	kind CanonicalIndexType = .undefined
mut:
	index u32
}

pub fn CanonicalIndex.create(kind CanonicalIndexType, index u32) CanonicalIndex {
	return CanonicalIndex{
		kind:  kind
		index: index
	}
}

pub fn CanonicalIndex.from_double(mut vm VM, kind CanonicalIndexType, index f64) !CanonicalIndex {
	if index < 0 || index > 4294967295.0 {
		return vm.throw_error_type(.range_error, .typed_array_invalid_integer_index,
			format_f64_value(index))
	}
	return CanonicalIndex.create(kind, u32(index))
}

pub fn (index CanonicalIndex) is_index() bool {
	return index.kind == .index
}

pub fn (index CanonicalIndex) is_undefined() bool {
	return index.kind == .undefined
}

pub fn (index CanonicalIndex) as_index() u32 {
	assert index.is_index()
	return index.index
}

pub enum CanonicalIndexMode {
	detect_numeric_roundtrip
	ignore_numeric_roundtrip
}

pub fn canonical_numeric_index_string(key PropertyName, mode CanonicalIndexMode) CanonicalIndex {
	assert key.is_string() || key.is_number()
	if key.is_number() { return CanonicalIndex.create(.index, key.number) }
	if mode != .detect_numeric_roundtrip { return CanonicalIndex{} }
	argument := key.as_string()
	if argument.is_empty() { return CanonicalIndex{} }
	mut cursor := 0
	if argument.data[cursor] == `-` {
		cursor++
		if cursor == argument.len() { return CanonicalIndex{} }
	}
	if argument.data[cursor] == `0` {
		cursor++
		if cursor == argument.len() { return CanonicalIndex.create(.numeric, 0) }
		if argument.data[cursor] != `.` { return CanonicalIndex{} }
		cursor++
		if cursor == argument.len() { return CanonicalIndex{} }
	}
	if argument.str() in ['Infinity', '-Infinity', 'NaN'] {
		return CanonicalIndex.create(.numeric, 0)
	}
	if argument.data[cursor] < `0` || argument.data[cursor] > `9` { return CanonicalIndex{} }
	// StringToNumber's whitespace trimming cannot admit extra keys: the final
	// UTF-16 comparison enforces the source's untrimmed numeric round trip.
	number := string_to_number(argument)
	if utf16_string(format_f64_value(number)) == argument {
		// Array indices below 2^32 - 1 use numeric PropertyNames. The last
		// u32 value remains a string key, but is still a typed-array index.
		if number == 4294967295.0 {
			return CanonicalIndex.create(.index, u32(4294967295))
		}
		return CanonicalIndex.create(.numeric, 0)
	}
	return CanonicalIndex{}
}
