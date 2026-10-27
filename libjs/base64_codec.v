module libjs

// AK/Base64.cpp's backend translated from simdutf 7.4.0:
// src/scalar/base64.h, src/arm64/arm_base64.cpp::compress_decode_base64,
// and src/implementation.cpp::base64_to_binary_safe_impl.
// Copyright 2021 The simdutf authors. See licenses/simdutf-MIT.txt.
// SPDX-License-Identifier: MIT
// Only the two alphabets and three last-chunk modes used by LibJS are exposed.
// SIMD/table operations become scalar code-unit operations; block buffering
// and its observable consumed-input counts retain the macOS upstream path.
pub enum Base64Alphabet {
	base64
	base64url
}

pub enum Base64LastChunkHandling {
	loose
	strict
	stop_before_partial
	only_full_chunks // Internal mode of simdutf's safe first pass.
}

enum Base64CodecError {
	success
	output_buffer_too_small
	extra_bits
	input_remainder
	invalid_character
}

struct Base64CodecResult {
mut:
	read          uint
	bytes         []u8
	error         Base64CodecError
	padding_error bool
}

fn base64_code(unit u16, alphabet Base64Alphabet) u8 {
	return match unit {
		u16(`A`)...u16(`Z`) {
			u8(unit - u16(`A`))
		}
		u16(`a`)...u16(`z`) {
			u8(unit - u16(`a`) + 26)
		}
		u16(`0`)...u16(`9`) {
			u8(unit - u16(`0`) + 52)
		}
		u16(`+`) {
			if alphabet == .base64 {
				u8(62)
			} else {
				u8(255)
			}
		}
		u16(`/`) {
			if alphabet == .base64 {
				u8(63)
			} else {
				u8(255)
			}
		}
		u16(`-`) {
			if alphabet == .base64url {
				u8(62)
			} else {
				u8(255)
			}
		}
		u16(`_`) {
			if alphabet == .base64url {
				u8(63)
			} else {
				u8(255)
			}
		}
		u16(` `), u16(`\t`), u16(`\n`), u16(`\r`), u16(`\f`) {
			u8(64)
		}
		else {
			u8(255)
		}
	}
}

fn (handling Base64LastChunkHandling) is_partial() bool {
	return handling in [.stop_before_partial, .only_full_chunks]
}

// maximal_binary_length_from_base64. Whitespace is intentionally not removed
// for the allocation bound; only the final two adjacent padding signs count.
fn base64_decode_capacity(input []u16) uint {
	mut padding := 0
	if input.len > 0 && input[input.len - 1] == u16(`=`) {
		padding++
		if input.len > 1 && input[input.len - 2] == u16(`=`) { padding++ }
	}
	length := uint(input.len - padding)
	return if length % 4 <= 1 { length / 4 * 3 } else { length / 4 * 3 + length % 4 - 1 }
}

// base64_tail_decode_impl<true>. Integer offsets replace source/destination
// pointers; decoding tables become the equivalent compact alphabet mapping.
fn base64_tail_decode(input []u16, padding int, capacity uint, alphabet Base64Alphabet, handling Base64LastChunkHandling) Base64CodecResult {
	mut result := Base64CodecResult{}
	mut position := 0
	for {
		// Source's four-character table fast path: capacity is checked before
		// any output and before scanning the next chunk's whitespace.
		for position + 4 <= input.len {
			codes := [base64_code(input[position], alphabet),
				base64_code(input[position + 1], alphabet),
				base64_code(input[position + 2],
					alphabet),
				base64_code(input[position + 3], alphabet)]
			if codes.any(it > 63) { break
			 }
			if capacity - uint(result.bytes.len) < 3 {
				result.read = uint(position)
				result.error = .output_buffer_too_small
				return result
			}
			triple := (u32(codes[0]) << 18) | (u32(codes[1]) << 12) | (u32(codes[2]) << 6) | u32(codes[3])
			result.bytes << [u8(triple >> 16), u8(triple >> 8), u8(triple)]
			position += 4
		}
		start := position
		mut codes := []u8{cap: 4}
		for codes.len < 4 && position < input.len {
			code := base64_code(input[position], alphabet)
			if code <= 63 {
				codes << code
			} else if code > 64 {
				result.read = uint(position)
				result.error = .invalid_character
				return result
			}
			position++
		}
		count := codes.len
		if count != 4 {
			assert count < 4
			result.read = uint(position)
			if count + padding > 4
				|| (handling == .loose && count >= 2 && padding > 0 && (count + padding) % 4 != 0) {
				result.error = .invalid_character
				result.padding_error = true
				return result
			}
			if handling == .strict && count >= 2 && (count + padding) % 4 != 0 {
				result.error = .input_remainder
				result.padding_error = true
				return result
			}
			if (handling == .stop_before_partial && padding + count < 4 && count != 0 && (count >= 2
				|| padding == 0))
				|| (handling == .only_full_chunks && (count >= 2 || padding == 0)) {
				result.read = uint(start)
				return result
			}
			if count == 2 || count == 3 {
				mut triple := (u32(codes[0]) << 18) | (u32(codes[1]) << 12)
				if count == 3 { triple |= u32(codes[2]) << 6 }
				mask := if count == 2 { u32(0xffff) } else { u32(0xff) }
				if handling == .strict && triple & mask != 0 {
					result.error = .extra_bits
					return result
				}
				if capacity - uint(result.bytes.len) < uint(count - 1) {
					result.read = uint(start)
					result.error = .output_buffer_too_small
					return result
				}
				result.bytes << u8(triple >> 16)
				if count == 3 { result.bytes << u8(triple >> 8) }
			} else if count == 1 && (!handling.is_partial() || padding > 0) {
				result.error = .input_remainder
			} else if count == 0 && padding > 0 {
				result.error = .invalid_character
				result.padding_error = true
			}
			return result
		}
		if capacity - uint(result.bytes.len) < 3 {
			result.read = uint(start)
			result.error = .output_buffer_too_small
			return result
		}
		triple := (u32(codes[0]) << 18) | (u32(codes[1]) << 12) | (u32(codes[2]) << 6) | u32(codes[3])
		result.bytes << [u8(triple >> 16), u8(triple >> 8), u8(triple)]
	}
	return result
}

// find_end, patch_tail_result, and the details/slow safe entry points. The
// slow entry intentionally differs in its empty-input and padding-error read.
fn base64_details(input []u16, capacity uint, alphabet Base64Alphabet, handling Base64LastChunkHandling, slow bool) Base64CodecResult {
	mut length := input.len
	for length > 0 && base64_code(input[length - 1], alphabet) == 64 {
		length--
	}
	mut equal_location := length
	mut padding := 0
	if length > 0 && input[length - 1] == u16(`=`) {
		equal_location = length - 1
		length--
		padding = 1
		for length > 0 && base64_code(input[length - 1], alphabet) == 64 {
			length--
		}
		if length > 0 && input[length - 1] == u16(`=`) {
			equal_location = length - 1
			length--
			padding = 2
		}
	}
	if length == 0 {
		return if padding > 0 {
			Base64CodecResult{
				read:  uint(equal_location)
				error: .invalid_character
			}
		} else {
			Base64CodecResult{
				read: if slow { uint(0) } else { uint(input.len) }
			}
		}
	}
	mut result := base64_tail_decode(input[..length], padding, capacity, alphabet, handling)
	if result.padding_error { result.read = uint(equal_location) }
	if result.error == .success && (!handling.is_partial() || result.bytes.len % 3 != 0) {
		result.read = uint(input.len)
	}
	if !handling.is_partial() && result.error == .success && padding > 0
		&& (result.bytes.len % 3 == 0 || result.bytes.len % 3 + 1 + padding != 4) {
		result.error = .invalid_character
		if !slow { result.read = uint(equal_location) }
	}
	if !slow && handling.is_partial() && result.error == .success && result.read < uint(input.len) {
		for result.read < uint(input.len) && base64_code(input[int(result.read)], alphabet) == 64 {
			result.read++
		}
		if result.read < uint(input.len) {
			for result.read > 0 && base64_code(input[int(result.read) - 1], alphabet) == 64 {
				result.read--
			}
		}
	}
	return result
}

// compress_decode_base64's block control flow. Keep the 64-code-unit blocks,
// 576-code flush and tail backtracking even though vector loads and decode
// tables are scalar here. The source can omit trailing whitespace from Read
// when no scalar tail runs; replacing this with the scalar entry changes Read.
fn base64_fast_details(input []u16, capacity uint, alphabet Base64Alphabet, handling Base64LastChunkHandling) Base64CodecResult {
	mut length := input.len
	for length > 0 && base64_code(input[length - 1], alphabet) == 64 {
		length--
	}
	mut equal_location := length
	mut padding := 0
	if length > 0 && input[length - 1] == u16(`=`) {
		equal_location = length - 1
		length--
		padding = 1
		for length > 0 && base64_code(input[length - 1], alphabet) == 64 {
			length--
		}
		if length > 0 && input[length - 1] == u16(`=`) {
			equal_location = length - 1
			length--
			padding = 2
		}
	}
	if length == 0 {
		return if padding > 0 {
			Base64CodecResult{
				read:  uint(equal_location)
				error: .invalid_character
			}
		} else {
			Base64CodecResult{
				read: uint(input.len)
			}
		}
	}
	mut result := Base64CodecResult{}
	mut position := 0
	mut buffered := []u8{}
	for position + 64 <= length {
		for index in position .. position + 64 {
			code := base64_code(input[index], alphabet)
			if code > 64 {
				result.read = uint(index)
				result.error = .invalid_character
				return result
			}
			if code < 64 { buffered << code }
		}
		position += 64
		if buffered.len >= 576 {
			for index := 0; index < 576; index += 4 {
				triple := (u32(buffered[index]) << 18) | (u32(buffered[index + 1]) << 12) | (u32(buffered[
					index + 2]) << 6) | u32(buffered[index + 3])
				result.bytes << [u8(triple >> 16), u8(triple >> 8), u8(triple)]
			}
			buffered = buffered[576..].clone()
		}
	}
	last_block := buffered.len % 64
	if last_block != 0 && length - position + last_block >= 64 {
		for buffered.len % 64 != 0 && position < length {
			code := base64_code(input[position], alphabet)
			if code > 64 {
				result.read = uint(position)
				result.error = .invalid_character
				return result
			}
			if code < 64 { buffered << code }
			position++
		}
	}
	mut index := 0
	for index + 4 <= buffered.len {
		triple := (u32(buffered[index]) << 18) | (u32(buffered[index + 1]) << 12) | (u32(buffered[
			index + 2]) << 6) | u32(buffered[index + 3])
		result.bytes << [u8(triple >> 16), u8(triple >> 8), u8(triple)]
		index += 4
	}
	for leftover := buffered.len - index; leftover > 0; leftover-- {
		for base64_code(input[position - 1], alphabet) == 64 {
			position--
		}
		position--
	}
	if position < length + padding {
		tail := base64_tail_decode(input[position..length], padding,
			capacity - uint(result.bytes.len), alphabet, handling)
		result.bytes << tail.bytes
		result.error = tail.error
		result.read = uint(position) + tail.read
		if tail.padding_error { result.read = uint(equal_location) }
		if result.error == .success && (!handling.is_partial() || result.bytes.len % 3 != 0) {
			result.read = uint(input.len)
		}
		if handling.is_partial() && result.error == .success && result.read < uint(input.len) {
			for result.read < uint(input.len)
				&& base64_code(input[int(result.read)], alphabet) == 64 {
				result.read++
			}
			if result.read < uint(input.len) {
				for result.read > 0 && base64_code(input[int(result.read) - 1], alphabet) == 64 {
					result.read--
				}
			}
		}
		return result
	}
	if padding > 0 && (result.bytes.len % 3 == 0 || result.bytes.len % 3 + 1 + padding != 4) {
		result.error = .invalid_character
		result.read = uint(equal_location)
		return result
	}
	result.read = uint(length)
	return result
}

// base64_to_binary_safe_impl with decode_up_to_bad_char=true, as in AK.
fn decode_base64_codec(input []u16, capacity uint, alphabet Base64Alphabet, handling Base64LastChunkHandling) Base64CodecResult {
	safe_input := if uint(input.len) < capacity / 3 * 4 { input.len } else { int(capacity / 3 * 4) }
	done := safe_input == input.len
	mut result := base64_fast_details(input[..safe_input], capacity, alphabet, if done {
		handling
	} else {
		Base64LastChunkHandling.only_full_chunks
	})
	if result.error != .success {
		return if result.error == .invalid_character {
			base64_details(input, capacity, alphabet, handling, true)
		} else {
			result
		}
	}
	if done { return result }
	tail := base64_details(input[int(result.read)..], capacity - uint(result.bytes.len), alphabet,
		handling, false)
	result.read += tail.read
	result.bytes << tail.bytes
	result.error = tail.error
	if result.error != .success {
		return if result.error == .invalid_character {
			base64_details(input, capacity, alphabet, handling, true)
		} else {
			result
		}
	}
	if result.read < uint(input.len) {
		for result.read > 0 && base64_code(input[int(result.read) - 1], alphabet) == 64 {
			result.read--
		}
	}
	return result
}

// tail_encode_base64. Compact alphabet indexing replaces e0/e1/e2 tables;
// the byte shifts, final chunk and padding steps follow the source directly.
fn encode_base64_codec(bytes []u8, alphabet Base64Alphabet, omit_padding bool) Utf16String {
	alphabet_string := if alphabet == .base64 {
		'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	} else {
		'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
	}
	mut out := []u16{}
	mut position := 0
	for position + 2 < bytes.len {
		first, second, third := bytes[position], bytes[position + 1], bytes[position + 2]
		out << [u16(alphabet_string[first >> 2]),
			u16(alphabet_string[((first & 3) << 4) | (second >> 4)]),
			u16(alphabet_string[((second & 15) << 2) | (third >> 6)]),
			u16(alphabet_string[third & 63])]
		position += 3
	}
	if bytes.len - position == 1 {
		first := bytes[position]
		out << [u16(alphabet_string[first >> 2]), u16(alphabet_string[(first & 3) << 4])]
		if !omit_padding { out << [u16(`=`), u16(`=`)] }
	} else if bytes.len - position == 2 {
		first, second := bytes[position], bytes[position + 1]
		out << [u16(alphabet_string[first >> 2]),
			u16(alphabet_string[((first & 3) << 4) | (second >> 4)]),
			u16(alphabet_string[(second & 15) << 2])]
		if !omit_padding { out << u16(`=`) }
	}
	return Utf16String.from_slice(out)
}
