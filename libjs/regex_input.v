module libjs

// LibRegex/Rust/src/vm.rs::Input, its &[u16]/&[u8] implementations, and the
// input/capture primitives below them. These records retain read-only views;
// callers own the backing arrays and must keep them stable during execution.
pub type RegexInput = RegexUtf16Input | RegexAsciiInput

pub struct RegexUtf16Input {
pub:
	units []u16
}

pub struct RegexAsciiInput {
pub:
	bytes []u8
}

pub const regex_match_limit = u64(10_000_000)

pub enum RegexVmResult {
	match
	no_match
	limit_exceeded
}

pub fn (input RegexInput) len() uint {
	return match input {
		RegexUtf16Input { uint(input.units.len) }
		RegexAsciiInput { uint(input.bytes.len) }
	}
}

pub fn (input RegexInput) is_empty() bool {
	return input.len() == 0
}

pub fn (input RegexInput) code_unit(position uint) u16 {
	if position >= input.len() { panic('Regex input index out of bounds') }
	return match input {
		RegexUtf16Input { input.units[int(position)] }
		RegexAsciiInput { u16(input.bytes[int(position)]) }
	}
}

pub fn (input RegexInput) find_code_unit(start uint, end uint, unit u16) ?uint {
	if input is RegexAsciiInput && unit > 0x7f { return none }
	if start > end || end > input.len() { return none }
	for position := start; position < end; position++ {
		if input.code_unit(position) == unit { return position }
	}
	return none
}

pub fn (input RegexInput) next_literal_start(start uint, unit u16) ?uint {
	return input.find_code_unit(start, input.len(), unit)
}

pub fn (input RegexInput) matches_u16_at(position uint, needle []u16) bool {
	if position > input.len() || uint(needle.len) > input.len() - position { return false }
	for offset, expected in needle {
		if input is RegexAsciiInput && expected > 0x7f { return false }
		if input.code_unit(position + uint(offset)) != expected { return false }
	}
	return true
}

pub fn (input RegexInput) ends_with_u16(suffix []u16) bool {
	if uint(suffix.len) > input.len() { return false }
	return input.matches_u16_at(input.len() - uint(suffix.len), suffix)
}

pub fn (input RegexInput) ranges_equal(left_start uint, right_start uint, length uint) bool {
	left_valid := left_start <= input.len() && length <= input.len() - left_start
	right_valid := right_start <= input.len() && length <= input.len() - right_start
	if !left_valid || !right_valid {
		// The u16 override compares Optional slices, so None == None. The
		// u8 implementation inherits the trait's false-on-out-of-bounds path.
		return input is RegexUtf16Input && !left_valid && !right_valid
	}
	for offset := uint(0); offset < length; offset++ {
		if input.code_unit(left_start + offset) != input.code_unit(right_start + offset) {
			return false
		}
	}
	return true
}

pub fn regex_decode_code_point(unicode bool, input RegexInput, position uint) u32 {
	if unicode && is_utf16_high_surrogate(input.code_unit(position)) && position + 1 < input.len()
		&& is_utf16_low_surrogate(input.code_unit(position + 1)) {
		return 0x10000 + ((u32(input.code_unit(position)) - 0xd800) << 10) +
			(u32(input.code_unit(position + 1)) - 0xdc00)
	}
	return u32(input.code_unit(position))
}

pub fn regex_code_point_len(unicode bool, input RegexInput, position uint) uint {
	if unicode && is_utf16_high_surrogate(input.code_unit(position)) && position + 1 < input.len()
		&& is_utf16_low_surrogate(input.code_unit(position + 1)) {
		return 2
	}
	return 1
}

pub fn regex_copy_captures_to_out(registers []i32, capture_count u32, mut output []i32) {
	slots := (uint(capture_count) + 1) * 2
	buffer_len := if registers.len < output.len { registers.len } else { output.len }
	copy_len := if slots < uint(buffer_len) { int(slots) } else { buffer_len }
	for index in 0 .. copy_len {
		output[index] = registers[index]
	}
}

pub fn regex_next_search_position(match_start i32, match_end i32) uint {
	if match_end == match_start { return uint(match_end) + 1 }
	return uint(match_end)
}

pub fn regex_is_line_terminator(code_point u32) bool {
	return code_point in [u32(0xa), 0xd, 0x2028, 0x2029]
}

pub fn regex_is_whitespace(code_point u32) bool {
	return
		code_point in [u32(0x9), 0xa, 0xb, 0xc, 0xd, 0x20, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]
		|| (code_point >= 0x2000 && code_point <= 0x200a)
}
