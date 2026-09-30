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

// str converts to a V string for display/map keys.
// Only handles BMP characters (good enough for ASCII identifiers).
fn (u Utf16String) str() string {
	mut buf := []u8{cap: u.data.len}
	for ch in u.data {
		if ch < 128 {
			buf << u8(ch)
		} else {
			buf << u8('?'[0])
		}
	}
	return buf.bytestr()
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

// utf16 converts an ASCII string to []u16 (compile-time-like helper).
fn utf16(s string) []u16 {
	mut result := []u16{cap: s.len}
	for b in s.bytes() {
		result << u16(b)
	}
	return result
}

// ch converts an ASCII byte to a u16 code unit.
fn ch(c u8) u16 {
	return u16(c)
}

// string_from_utf16_lossy converts a []u16 to a V string, replacing non-ASCII with '?'.
fn string_from_utf16_lossy(data []u16) string {
	mut buf := []u8{cap: data.len}
	for unit in data {
		if unit < 128 {
			buf << u8(unit)
		} else {
			buf << u8('?'[0])
		}
	}
	return buf.bytestr()
}
