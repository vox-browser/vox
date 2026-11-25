module css

// Fetch adapters normally supply UTF-8 text. A UTF-16 BOM identifies a raw
// stylesheet response that still needs the CSS byte-stream decoder.
fn decode_stylesheet_response_text(source string, own_unchanged_text bool) string {
	if source.len >= 2 && ((source[0] == 0xfe && source[1] == 0xff)
		|| (source[0] == 0xff && source[1] == 0xfe)) {
		if decoded := css_decode_bytes(none, none, source.bytes()) {
			return decoded
		}
	}
	return if own_unchanged_text { source.clone() } else { source }
}
