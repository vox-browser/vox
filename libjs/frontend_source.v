module libjs

// ASCII script assets can widen directly into the lexer buffer. Keep the
// existing UTF-8 decoder for sources containing non-ASCII bytes.
@[direct_array_access]
fn source_utf16(source string) []u16 {
	for byte in source {
		if byte >= 0x80 { return utf16(source) }
	}
	mut units := []u16{len: source.len}
	for index, byte in source {
		units[index] = u16(byte)
	}
	return units
}
