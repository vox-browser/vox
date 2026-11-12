module layout

import dom

// Arabic-script decimal numbers have even bidi levels and retain their logical
// digit order. HarfBuzz's Arabic script guess otherwise shapes a weak-only run
// right-to-left when this approximate iterator finds no strong text in it.
fn chromium_arabic_number_chunk(text string) bool {
	if text.is_ascii() { return false }
	mut has_digit := false
	for r in text.runes() {
		cp := u32(r)
		if cp in u32(0x0660) .. u32(0x066a) || cp in u32(0x06f0) .. u32(0x06fa) { has_digit = true }
		match dom.unicode_bidirectional_class(cp) {
			.european_number, .arabic_number, .common_number_separator,
			.european_number_separator, .european_number_terminator,
			.white_space_neutral, .dir_non_spacing_mark {
			}
			else { return false }
		}
	}
	return has_digit
}

fn chromium_numeric_direction_is_not_overridden(text_node &TextNode) bool {
	mut parent := unsafe { &Node(text_node) }.parent()
	for parent != none {
		node := parent or { break }
		if styled := node.as_node_with_style() {
			if styled.computed_values().unicode_bidi() in [.bidi_override, .isolate_override] {
				return false
			}
		}
		if !node.is_inline() { break }
		parent = node.parent()
	}
	return true
}
