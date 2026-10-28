module layout

// Chunk iteration retains the rendered text's immutable UTF-16 units. Line
// fitting asks for many ranges of the same text, so share that decoding just
// as LineBoxFragment.text() does. Refresh the text before consulting its cache.
fn (node &TextNode) rendered_substring_for_line_box(start int, length int) string {
	value := node.text_for_rendering()
	if node.rendered_text_is_ascii_ {
		return ascii_substring_for_line_box(value, start, length)
	}
	if units := node.cached_utf16_code_units_ {
		return utf16_substring_from_code_units_for_line_box(units, start, length)
	}
	return utf16_substring_for_line_box(value, start, length)
}
