module layout

// Decorations accumulate through inline ancestors. Their colors remain those
// of their decorating boxes, even when a nested link changes currentColor.
fn chromium_ancestor_text_decoration_commands(fragment TextFragment, opacity f64,
	phase TextDecorationPaintPhase) []PaintCommand {
	if !fragment.chromium_decorations || fragment.layout_handle == unsafe { nil } {
		return []PaintCommand{}
	}
	mut ancestor := unsafe { &Node(fragment.layout_handle) }.parent()
	mut skipped_nearest := false
	mut decorations := []TextFragment{}
	for ancestor != none {
		node := ancestor or { break }
		if !node.is_inline_node() || node.is_atomic_inline() { break }
		computed := node.computed_values()
		line := text_decoration_string(computed.text_decoration_line())
		if !computed.is_property_inherited(.text_decoration_line) && line != 'none' {
			if skipped_nearest {
				decorations << TextFragment{
					...fragment
					layout_handle:        unsafe { nil }
					decoration:           line
					decoration_color:     computed.text_decoration_color()
					decoration_color_set: true
					decoration_style:     computed_text_decoration_style(computed)
				}
			} else {
				skipped_nearest = true
			}
		}
		ancestor = node.parent()
	}
	mut commands := []PaintCommand{}
	for i := decorations.len - 1; i >= 0; i-- {
		commands << paint_text_decoration_for_phase(decorations[i], opacity, phase)
	}
	return commands
}
