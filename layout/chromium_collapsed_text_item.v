module layout

// Collapsing whitespace leaves gaps in the source offsets, but does not start
// a new shaping item. Carry the fractional pen across those gaps while keeping
// the fragments separate for DOM ranges and glyph cluster indices.
fn chromium_text_item_continues(node &Node, end int, start int) bool {
	if end == start { return true }
	if end > start || end < 0 { return false }
	collapse := node.computed_values().white_space_collapse()
	if collapse !in [.collapse, .preserve_breaks] { return false }
	text := node.as_text_node() or { return false }
	units := text.cached_utf16_code_units_ or {
		utf16_code_units_for_line_box(text.text_for_rendering())
	}
	if start > units.len { return false }
	for unit in units[end..start] {
		if !is_ascii_space_code_point(u32(unit))
			|| (collapse == .preserve_breaks && unit in [u16(`\n`), u16(`\r`)]) {
			return false
		}
	}
	return true
}
