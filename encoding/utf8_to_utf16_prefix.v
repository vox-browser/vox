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

fn source_convert_utf8_to_utf16_up_to_invalid(input []u8, mut output []u16) (int, int) {
	return source_convert_utf8_to_utf16_up_to_invalid_at(input, 0, mut output, 0)
}

// utf_8.rs::convert_utf8_to_utf16_up_to_invalid. The manually inlined
// next-lead jumps return to the same outer iteration here, as in the
// translated validity helper. The destination's capacity remains in code
// units; an astral prefix needs two, while BMP fast-path output needs one.
fn source_convert_utf8_to_utf16_up_to_invalid_at(input []u8, input_start int, mut output []u16, output_start int) (int, int) {
	mut read := input_start
	mut written := output_start
	for {
		// ascii_to_basic_latin lowers the Source ASCII prefix to scalar
		// writes. SIMD's uncommitted destination slack is not represented.
		for read < input.len && written < output.len && input[read] < 0x80 {
			output[written] = u16(input[read])
			read++
			written++
		}
		if read == input.len || written == output.len {
			return read - input_start, written - output_start
		}
		byte := input[read]
		// Source's four-byte lookahead uses uint. Widen under V's
		// narrower array lengths before testing that exact bound.
		if u64(read) + 4 <= u64(input.len) {
			if utf8_in_inclusive_range8(byte, 0xc2, 0xdf) {
				second := input[read + 1]
				if !utf8_in_inclusive_range8(second, 0x80, 0xbf) {
					return read - input_start, written - output_start
				}
				output[written] = ((u16(byte) & 0x1f) << 6) | (u16(second) & 0x3f)
				read += 2
				written++
				continue
			}
			if byte < 0xf0 {
				second := input[read + 1]
				third := input[read + 2]
				if ((utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | (third >> 6)) != 2 {
					return read - input_start, written - output_start
				}
				output[written] = ((u16(byte) & 0xf) << 12) | ((u16(second) & 0x3f) << 6) | (u16(third) & 0x3f)
				read += 3
				written++
				continue
			}
			if written + 1 == output.len {
				return read - input_start, written - output_start
			}
			second := input[read + 1]
			third := input[read + 2]
			fourth := input[read + 3]
			if (u16(utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | u16(third >> 6) | (u16(fourth & 0xc0) << 2)) != 0x202 {
				return read - input_start, written - output_start
			}
			point := ((u32(byte) & 0x7) << 18) | ((u32(second) & 0x3f) << 12) | ((u32(third) & 0x3f) << 6) | (u32(fourth) & 0x3f)
			output[written] = u16(0xd7c0 + (point >> 10))
			output[written + 1] = u16(0xdc00 + (point & 0x3ff))
			read += 4
			written += 2
			continue
		}
		// Source's tail excludes four-byte leads and incomplete shorter
		// sequences. After a complete three-byte tail it exits directly.
		if utf8_in_inclusive_range8(byte, 0xc2, 0xdf) {
			if u64(read) + 2 > u64(input.len) {
				return read - input_start, written - output_start
			}
			second := input[read + 1]
			if !utf8_in_inclusive_range8(second, 0x80, 0xbf) {
				return read - input_start, written - output_start
			}
			output[written] = ((u16(byte) & 0x1f) << 6) | (u16(second) & 0x3f)
			read += 2
			written++
			continue
		}
		if byte < 0xf0 {
			if u64(read) + 3 > u64(input.len) {
				return read - input_start, written - output_start
			}
			second := input[read + 1]
			third := input[read + 2]
			if ((utf8_validity_masks[int(second)] & utf8_validity_masks[int(byte) + 0x80]) | (third >> 6)) != 2 {
				return read - input_start, written - output_start
			}
			output[written] = ((u16(byte) & 0xf) << 12) | ((u16(second) & 0x3f) << 6) | (u16(third) & 0x3f)
			read += 3
			written++
		}
		return read - input_start, written - output_start
	}
	return read - input_start, written - output_start
}
