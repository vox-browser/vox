module libjs

// Utf16String wraps []u16 to provide UTF-16 string functionality. Public
// intrinsic-operation dependencies can return it without exposing its storage.
pub struct Utf16String {
	// AK's unchecked ASCII constructor owns bytes independently of their
	// code-unit projection. Utf16View::to_utf8 returns these bytes verbatim.
	ascii_bytes_ ?[]u8
mut:
	data []u16
	// IPC strings retain their actual ASCII/UTF16 storage form even when all
	// units happen to be ASCII. Ordinary standalone strings infer the form.
	ascii_storage_ ?bool
}

fn Utf16String.new() Utf16String {
	return Utf16String{}
}

fn Utf16String.from_slice(s []u16) Utf16String {
	return Utf16String{
		data: s.clone()
	}
}

// AK/Utf16String's unvalidated code-unit construction/span at the embedding
// boundary. Preserve unpaired surrogates and give callers an owned slice.
pub fn utf16_string_from_code_units(units []u16) Utf16String {
	// AK/Utf16String::from_utf16 delegates long input to
	// Utf16StringData::from_utf16, which also compresses all-ASCII code units.
	mut text := Utf16String.from_slice(units)
	text.ascii_storage_ = text.has_ascii_storage()
	return text
}

pub fn (text Utf16String) code_units() []u16 {
	return text.data.clone()
}

// AK/Utf16String{,Data}::from_ipc_stream retains the encoded storage form.
pub fn utf16_string_from_code_units_with_storage(units []u16, ascii bool) !Utf16String {
	if ascii {
		for unit in units {
			if unit >= 128 { return error('Stream contains invalid ASCII data') }
		}
	}
	return Utf16String{data: units.clone(), ascii_storage_: ascii}
}

pub fn (text Utf16String) has_ascii_storage() bool {
	if text.ascii_bytes_ != none {
		if _ := text.retained_ascii_bytes() { return true }
	} else if storage := text.ascii_storage_ { return storage }
	for unit in text.data { if unit >= 128 { return false } }
	return true
}

pub fn (text Utf16String) has_short_ascii_storage() bool {
	// AK/StringData.h::MAX_SHORT_STRING_BYTE_COUNT and Utf16String.h's
	// actual ASCII inline-storage predicate, including IPC storage metadata.
	return text.has_ascii_storage() && text.data.len <= int(sizeof(voidptr)) - int(sizeof(u8))
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
	mut ascii_bytes := ?[]u8(none)
	if bytes := u.retained_ascii_bytes() { ascii_bytes = bytes.clone() }
	mut storage := u.ascii_storage_
	if u.ascii_bytes_ != none { storage = u.has_ascii_storage() }
	return Utf16String{
		data: u.data.clone()
		ascii_storage_: storage
		ascii_bytes_: ascii_bytes
	}
}

// WTF-8 preserves even unpaired UTF-16 surrogates in internal map keys.
pub fn (u Utf16String) str() string {
	if bytes := u.retained_ascii_bytes() { return bytes.bytestr() }
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
	if !disable_utf16_ascii_prefix && data.len == 0 { return '' }
	mut buf := []u8{len: data.len}
	mut index := if disable_utf16_ascii_prefix { 0 } else { utf16_copy_ascii_prefix(data, mut buf) }
	// Only the prefix is initialized output. The existing encoder appends the
	// remaining Unicode/WTF-8 bytes using the same capacity as before.
	buf.trim(index)
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
