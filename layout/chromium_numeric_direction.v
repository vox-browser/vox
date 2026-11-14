module layout


// Weak Arabic-script numbers need their resolved paragraph levels, including
// the separators and surrounding neutrals, before shaping/font fragmentation.
fn chromium_text_has_arabic_number(text string) bool {
	if text.is_ascii() { return false }
	for r in text.runes() {
		cp := u32(r)
		if cp in u32(0x0660) .. u32(0x066a) || cp in u32(0x06f0) .. u32(0x06fa) { return true }
	}
	return false
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
