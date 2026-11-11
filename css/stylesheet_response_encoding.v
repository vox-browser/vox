module css

// Fetch adapters normally supply UTF-8 text. A UTF-16 BOM identifies a raw
// stylesheet response that still needs the CSS byte-stream decoder.
fn decode_stylesheet_response_text(source string) string {
	if source.len >= 2 && ((source[0] == 0xfe && source[1] == 0xff)
		|| (source[0] == 0xff && source[1] == 0xfe)) {
		return css_decode_bytes(none, none, source.bytes()) or { source.clone() }
	}
	return source.clone()
}
