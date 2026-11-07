// https://encoding.spec.whatwg.org/#gb18030-decoder, also the GBK decoder.
module encoding

struct Gb18030Decoder {
mut:
	first  u8
	second u8
	third  u8
}

// https://encoding.spec.whatwg.org/#index-gb18030-ranges-code-point
fn gb18030_ranges_code_point(pointer u32) ?u32 {
	if (pointer > 39419 && pointer < 189000) || pointer > 1237575 {
		return none
	}
	if pointer == 7457 {
		return 0xE7C7
	}
	if pointer >= 189000 {
		return 0x10000 + pointer - 189000
	}
	// The last range whose pointer is less than or equal to pointer.
	mut low := 0
	mut high := gb18030_range_pointers.len - 1
	for low < high {
		middle := (low + high + 1) / 2
		if gb18030_range_pointers[middle] <= pointer {
			low = middle
		} else {
			high = middle - 1
		}
	}
	return gb18030_range_code_points[low] + pointer - gb18030_range_pointers[low]
}

// Runs the decoder over the bytes of one queue item and, when `last` is set,
// over end-of-queue. Errors produce U+FFFD, or stop decoding when `fatal`.
fn (mut decoder Gb18030Decoder) decode_code_points(input []u8, last bool, fatal bool, mut output []u32) bool {
	// Bytes restored to the front of the queue.
	mut restored := []u8{}
	mut index := 0
	for {
		mut value := u8(0)
		if restored.len > 0 {
			value = restored[0]
			restored.delete(0)
		} else if index < input.len {
			value = input[index]
			index++
		} else if last {
			if decoder.first == 0 && decoder.second == 0 && decoder.third == 0 {
				return true
			}
			decoder.first, decoder.second, decoder.third = 0, 0, 0
			if fatal {
				return false
			}
			output << 0xFFFD
			return true
		} else {
			return true
		}
		mut failed := false
		if decoder.third != 0 {
			if value < 0x30 || value > 0x39 {
				restored.insert(0, [decoder.second, decoder.third, value])
				failed = true
			} else {
				pointer := (u32(decoder.first) - 0x81) * (10 * 126 * 10) +
					(u32(decoder.second) - 0x30) * (10 * 126) + (u32(decoder.third) - 0x81) * 10 +
					u32(value) - 0x30
				if code_point := gb18030_ranges_code_point(pointer) {
					output << code_point
				} else {
					failed = true
				}
			}
			decoder.first, decoder.second, decoder.third = 0, 0, 0
		} else if decoder.second != 0 {
			if value >= 0x81 && value <= 0xFE {
				decoder.third = value
				continue
			}
			restored.insert(0, [decoder.second, value])
			decoder.first, decoder.second = 0, 0
			failed = true
		} else if decoder.first != 0 {
			if value >= 0x30 && value <= 0x39 {
				decoder.second = value
				continue
			}
			lead := decoder.first
			decoder.first = 0
			offset := if value < 0x7F { u8(0x40) } else { u8(0x41) }
			if (value >= 0x40 && value <= 0x7E) || (value >= 0x80 && value <= 0xFE) {
				output << u32(gb18030_index[(int(lead) - 0x81) * 190 + int(value - offset)])
			} else {
				if value < 0x80 {
					restored.prepend(value)
				}
				failed = true
			}
		} else if value < 0x80 {
			output << u32(value)
		} else if value == 0x80 {
			output << 0x20AC
		} else if value <= 0xFE {
			decoder.first = value
		} else {
			failed = true
		}
		if failed {
			if fatal {
				return false
			}
			output << 0xFFFD
		}
	}
	return true
}

fn (mut decoder Gb18030Decoder) decode_owned_utf16(input []u8, last bool, fatal bool) (bool, []u16) {
	mut code_points := []u32{cap: input.len}
	ok := decoder.decode_code_points(input, last, fatal, mut code_points)
	mut units := []u16{cap: code_points.len}
	for code_point in code_points {
		if code_point >= 0x10000 {
			value := code_point - 0x10000
			units << u16(0xD800 + (value >> 10))
			units << u16(0xDC00 + (value & 0x3FF))
		} else {
			units << u16(code_point)
		}
	}
	return ok, units
}

fn (mut decoder Gb18030Decoder) decode_owned_utf8(input []u8, last bool, fatal bool) (bool, string) {
	mut code_points := []u32{cap: input.len}
	ok := decoder.decode_code_points(input, last, fatal, mut code_points)
	mut output := []u8{cap: code_points.len * 3}
	for code_point in code_points {
		append_utf8_code_point(mut output, code_point)
	}
	return ok, output.bytestr()
}

fn decode_gb18030(input []u8, fatal bool) !string {
	mut decoder := Gb18030Decoder{}
	ok, decoded := decoder.decode_owned_utf8(input, true, fatal)
	if !ok {
		return error('TypeError: Decoding failed')
	}
	return decoded
}
