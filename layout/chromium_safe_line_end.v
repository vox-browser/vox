module layout

import platform

fn chromium_cached_safe_line_end(node &Node, start int, length int,
	run &platform.GlyphRun) ?f32 {
	if run.font().font_rendering_policy != .chromium || run.text_type() != .ltr
		|| run.face() != .document {
		return none
	}
	text_node := node.as_text_node() or { return none }
	text := text_node.text_for_rendering()
	// text_for_rendering() refreshes this fact together with the rendered text.
	if !text_node.rendered_text_is_ascii_ { return none }
	// A collapsed source map makes this query ineligible. Check that
	// condition before allocating the map and its collapsed text.
	if text_node.Node.computed_values().white_space_collapse() in [.collapse, .preserve_breaks]
		&& text.contains('  ') {
		return none
	}
	letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	return platform.shaped_text_safe_break_width(letter, word, text, start, length,
		run.font())
}
