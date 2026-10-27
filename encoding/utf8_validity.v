// Copyright Mozilla Foundation
//
// Permission is hereby granted, free of charge, to any
// person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the
// Software without restriction, including without
// limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice
// shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
// ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
// SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
// IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
module encoding

// Source lib.rs::in_inclusive_range8 uses wrapping_sub, including for inputs
// below the lower bound. Keep its actual unsigned-byte classification.
fn utf8_in_inclusive_range8(value u8, start u8, end u8) bool {
	return u8(value - start) <= end - start
}

// Scalar encoding_rs utf_8.rs::utf8_valid_up_to. Source's manually inlined
// next-lead continuations return to this loop; break 'outer returns read.
// Its ASCII acceleration is lowered to the same scalar prefix scan, while
// the exact Source mask predicates and four-byte/tail branch order remain.
fn source_utf8_valid_up_to(input []u8) int {
	mut read := 0
	for {
		// ascii.rs::validate_ascii: stop at the first non-ASCII byte or
		// report the complete remaining ASCII input as valid.
		for read < input.len && input[read] < 0x80 {
			read++
		}
		if read == input.len {
			return input.len
		}
		byte := input[read]
		// Source uses uint positions. Widen this lookahead sum to retain
		// its non-overflowing bound under V's narrower int array lengths.
		if u64(read) + 4 <= u64(input.len) {
			if utf8_in_inclusive_range8(byte, 0xc2, 0xdf) {
				second := input[read + 1]
				if !utf8_in_inclusive_range8(second, 0x80, 0xbf) {
					return read
				}
				read += 2
				continue
			}
			if byte < 0xf0 {
				second := input[read + 1]
				third := input[read + 2]
				if ((utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | (third >> 6)) != 2 {
					return read
				}
				read += 3
				continue
			}
			second := input[read + 1]
			third := input[read + 2]
			fourth := input[read + 3]
			if (u16(utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | u16(third >> 6) | (u16(fourth & 0xc0) << 2)) != 0x202 {
				return read
			}
			read += 4
			continue
		}
		// Source tail handles only complete shorter sequences. This loop
		// already consumed tail ASCII before reaching its non-ASCII byte.
		if utf8_in_inclusive_range8(byte, 0xc2, 0xdf) {
			if u64(read) + 2 > u64(input.len) {
				return read
			}
			second := input[read + 1]
			if !utf8_in_inclusive_range8(second, 0x80, 0xbf) {
				return read
			}
			read += 2
			continue
		}
		if byte < 0xf0 {
			if u64(read) + 3 > u64(input.len) {
				return read
			}
			second := input[read + 1]
			third := input[read + 2]
			if ((utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | (third >> 6)) != 2 {
				return read
			}
			read += 3
			return read
		}
		return read
	}
	return read
}
