// https://encoding.spec.whatwg.org/#gb18030-encoder, also the GBK encoder.
module encoding

import url

fn init() {
	// URL query strings of documents in these encodings are encoded with them.
	url.register_query_encoder('gb18030', fn (code_point u32) ?[]u8 {
		return gb18030_encode(code_point, false)
	})
	url.register_query_encoder('gbk', fn (code_point u32) ?[]u8 {
		return gb18030_encode(code_point, true)
	})
}

// https://encoding.spec.whatwg.org/#index-pointer for index gb18030.
fn gb18030_index_pointer(code_point u32) ?int {
	if code_point > 0xFFFF {
		return none
	}
	mut low := 0
	mut high := gb18030_encode_code_points.len - 1
	for low <= high {
		middle := (low + high) / 2
		value := u32(gb18030_encode_code_points[middle])
		if value == code_point {
			return int(gb18030_encode_pointers[middle])
		}
		if value < code_point {
			low = middle + 1
		} else {
			high = middle - 1
		}
	}
	return none
}

// https://encoding.spec.whatwg.org/#index-gb18030-ranges-pointer
fn gb18030_ranges_pointer(code_point u32) u32 {
	if code_point == 0xE7C7 {
		return 7457
	}
	if code_point >= 0x10000 {
		return 189000 + code_point - 0x10000
	}
	// The last range whose code point is less than or equal to code point.
	mut low := 0
	mut high := gb18030_range_code_points.len - 1
	for low < high {
		middle := (low + high + 1) / 2
		if gb18030_range_code_points[middle] <= code_point {
			low = middle
		} else {
			high = middle - 1
		}
	}
	return gb18030_range_pointers[low] + code_point - gb18030_range_code_points[low]
}

// Returns the bytes for code point, or none for an encoder error.
fn gb18030_encode(code_point u32, is_gbk bool) ?[]u8 {
	if code_point < 0x80 {
		return [u8(code_point)]
	}
	if code_point == 0xE5E5 {
		return none
	}
	if is_gbk && code_point == 0x20AC {
		return [u8(0x80)]
	}
	if pointer := gb18030_index_pointer(code_point) {
		lead := pointer / 190 + 0x81
		trail := pointer % 190
		offset := if trail < 0x3F { 0x40 } else { 0x41 }
		return [u8(lead), u8(trail + offset)]
	}
	if is_gbk {
		return none
	}
	mut pointer := gb18030_ranges_pointer(code_point)
	byte1 := pointer / (10 * 126 * 10)
	pointer = pointer % (10 * 126 * 10)
	byte2 := pointer / (10 * 126)
	pointer = pointer % (10 * 126)
	byte3 := pointer / 10
	byte4 := pointer % 10
	return [u8(byte1 + 0x81), u8(byte2 + 0x30), u8(byte3 + 0x81), u8(byte4 + 0x30)]
}
