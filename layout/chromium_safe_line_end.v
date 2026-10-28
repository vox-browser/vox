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
	mut mutable_text := unsafe { &TextNode(text_node) }
	if isnil(mutable_text.safe_break_width_cache_) {
		persistent := platform.enter_persistent()
		mutable_text.safe_break_width_cache_ = &platform.SafeBreakWidthCache{}
		platform.leave_persistent(persistent)
	}
	collapses_spaces := text_node.Node.computed_values().white_space_collapse() in [.collapse, .preserve_breaks]
	letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	return platform.shaped_text_safe_break_width_cached(mut mutable_text.safe_break_width_cache_,
		letter, word, text, start, length, run.font(), collapses_spaces)
}
