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
	if !text.is_ascii() { return none }
	context := chromium_collapsed_context_text(text_node, text)
	if context.source_offsets.len > 0 { return none }
	letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	return platform.shaped_text_safe_break_width(letter, word, context.text, start, length,
		run.font())
}
