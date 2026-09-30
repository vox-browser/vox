module libjs

// Utf16String wraps []u16 to provide UTF-16 string functionality.
struct Utf16String {
mut:
	data []u16
}

fn Utf16String.new() Utf16String {
	return Utf16String{}
}

fn Utf16String.from_slice(s []u16) Utf16String {
	return Utf16String{
		data: s.clone()
	}
}

fn (u Utf16String) len() int {
	return u.data.len
}

fn (u Utf16String) is_empty() bool {
	return u.data.len == 0
}

fn (u Utf16String) as_slice() []u16 {
	return u.data
}

fn (u Utf16String) clone() Utf16String {
	return Utf16String{
		data: u.data.clone()
	}
}

// WTF-8 preserves even unpaired UTF-16 surrogates in internal map keys.
fn (u Utf16String) str() string {
	return encode_utf16(u.data, false)
}

fn (a Utf16String) == (b Utf16String) bool {
	return a.data == b.data
}

fn (a Utf16String) < (b Utf16String) bool {
	min_len := if a.data.len < b.data.len { a.data.len } else { b.data.len }
	for i in 0 .. min_len {
		if a.data[i] < b.data[i] {
			return true
		}
		if a.data[i] > b.data[i] {
			return false
		}
	}
	return a.data.len < b.data.len
}

fn utf16_equals(a []u16, b []u16) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// Source offsets remain UTF-16 code-unit offsets, including supplementary text.
pub fn utf16(s string) []u16 {
	mut result := []u16{cap: s.len}
	for character in s.runes() {
		code_point := u32(character)
		if code_point <= 0xFFFF {
			result << u16(code_point)
		} else {
			value := code_point - 0x10000
			result << u16(0xD800 + (value >> 10))
			result << u16(0xDC00 + (value & 0x3FF))
		}
	}
	return result
}

// ch converts an ASCII byte to a u16 code unit.
fn ch(c u8) u16 {
	return u16(c)
}

// Diagnostic text replaces unpaired surrogates, matching Rust from_utf16_lossy.
fn string_from_utf16_lossy(data []u16) string {
	return encode_utf16(data, true)
}

fn encode_utf16(data []u16, lossy bool) string {
	mut buf := []u8{cap: data.len}
	mut index := 0
	for index < data.len {
		unit := data[index]
		mut code_point := u32(unit)
		if is_utf16_high_surrogate(unit) && index + 1 < data.len
			&& is_utf16_low_surrogate(data[index + 1]) {
			code_point = 0x10000 + (u32(unit - 0xD800) << 10) + u32(data[index + 1] - 0xDC00)
			index++
		} else if lossy && (is_utf16_high_surrogate(unit) || is_utf16_low_surrogate(unit)) {
			code_point = 0xFFFD
		}
		if code_point < 0x80 {
			buf << u8(code_point)
		} else if code_point < 0x800 {
			buf << u8(0xC0 | (code_point >> 6))
			buf << u8(0x80 | (code_point & 0x3F))
		} else if code_point < 0x10000 {
			buf << u8(0xE0 | (code_point >> 12))
			buf << u8(0x80 | ((code_point >> 6) & 0x3F))
			buf << u8(0x80 | (code_point & 0x3F))
		} else {
			buf << u8(0xF0 | (code_point >> 18))
			buf << u8(0x80 | ((code_point >> 12) & 0x3F))
			buf << u8(0x80 | ((code_point >> 6) & 0x3F))
			buf << u8(0x80 | (code_point & 0x3F))
		}
		index++
	}
	return buf.bytestr()
}
