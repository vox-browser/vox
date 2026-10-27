module layout

import platform

// A break before a collapsed space can cut an unsafe HarfBuzz boundary:
// e.g. Arial's Y-space kern changes Y's advance. Removing only the space
// retains that kern. Blink's ShapingLineBreaker reshapes the exposed boundary
// before measuring/alignment. Keep the same supported context-shaping scope,
// and leave bidi, fallback faces and ambiguous cluster coverage alone.
fn (fragment &LineBoxFragment) chromium_visible_line_end(at_break bool) ?string {
	run := fragment.glyph_run_ or { return none }
	if run.font().font_rendering_policy != .chromium || run.text_type() != .ltr
		|| fragment.direction_ != .ltr || fragment.precise_inline_length_ == none
		|| run.face() != .document {
		return none
	}
	trailing := fragment.trailing_whitespace_.length_in_code_units
	length := fragment.length_in_code_units_ - trailing
	// A wrapping space can be discarded before a fragment is appended. Its
	// preceding letter still retains that space's shaping context.
	if (trailing <= 0 && !at_break) || length <= 0 { return none }
	mut covered := 0
	mut has_glyph_indices := false
	for glyph in run.glyphs_ {
		covered += glyph.length_in_code_units
		has_glyph_indices = has_glyph_indices || glyph.glyph_index != 0
	}
	if covered != fragment.length_in_code_units_ || !has_glyph_indices { return none }
	text := fragment.text() or { return none }
	return utf16_substring_for_line_box(text, 0, length)
}

fn (fragment &LineBoxFragment) chromium_shape_without_trailing_whitespace(at_break bool) ?&platform.GlyphRun {
	visible := fragment.chromium_visible_line_end(at_break) or { return none }
	run := fragment.glyph_run_ or { return none }
	return chromium_shape_line_end(fragment.layout_node_, visible, run, fragment.glyph_remainder_)
}

fn (fragment &LineBoxFragment) chromium_width_without_trailing_whitespace(at_break bool) ?f32 {
	visible := fragment.chromium_visible_line_end(at_break) or { return none }
	run := fragment.glyph_run_ or { return none }
	if width := chromium_cached_safe_line_end(fragment.layout_node_, fragment.start_, visible.len, run) {
		return width
	}
	return chromium_line_end_width(fragment.layout_node_, visible, run)
}

fn chromium_shape_line_end(node &Node, visible string, run &platform.GlyphRun,
	remainder f32) ?&platform.GlyphRun {
	if run.font().font_rendering_policy != .chromium || run.text_type() != .ltr
		|| run.face() != .document {
		return none
	}
	if !chromium_context_has_single_supported_script(visible) { return none }
	letter_spacing := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word_spacing := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing, visible, run.font(), .ltr)
	if shape.glyph_run.face() != run.face() { return none }
	length := utf16_length_for_line_box(visible)
	mut shaped_coverage := 0
	for glyph in shape.glyph_run.glyphs_ { shaped_coverage += glyph.length_in_code_units }
	if shaped_coverage != length { return none }
	// Reconstruct exact local sums, rather than accumulating float pens across
	// the line. Retain the item's finer-than-LayoutUnit leading remainder.
	mut result := chromium_context_slice(shape.glyph_run, TextNodeChunk{ length: length }) or { return none }
	if remainder != 0 {
		result.glyph_run.invalidate_replay_data()
		for mut glyph in result.glyph_run.glyphs_ {
			glyph.position.x += remainder
		}
	}
	return result.glyph_run
}

// Fit the candidate with the boundary that painting will use. An unsafe
// letter-space kern can otherwise accept a word whose reshaped line overflows.
fn chromium_line_end_width(node &Node, visible string, run &platform.GlyphRun) ?f32 {
	if run.font().font_rendering_policy != .chromium || run.text_type() != .ltr
		|| run.face() != .document || !chromium_context_has_single_supported_script(visible) {
		return none
	}
	letter_spacing := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
	word_spacing := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
	metrics := platform.shaped_text_context_metrics(letter_spacing, word_spacing, visible,
		run.font(), .ltr) or { return none }
	if metrics.face != run.face()
		|| metrics.length_in_code_units != utf16_length_for_line_box(visible) {
		return none
	}
	return metrics.width
}

fn (projection &ProjectedTextAdvance) chromium_line_end_correction() CSSPixels {
	if projection.node == unsafe { nil } || projection.run == unsafe { nil }
		|| projection.segment_length <= 0
		|| projection.segment_start + projection.segment_length != projection.end {
		return CSSPixels.new(0)
	}
	text_node := projection.node.as_text_node() or { return CSSPixels.new(0) }
	advance := chromium_cached_safe_line_end(projection.node, projection.segment_start,
		projection.segment_length, projection.run) or {
		text := utf16_substring_for_line_box(text_node.text_for_rendering(),
			projection.segment_start, projection.segment_length)
		chromium_line_end_width(projection.node, text, projection.run) or {
			return CSSPixels.new(0)
		}
	}
	width := inline_advance_to_css_pixels(projection.precise - projection.segment_width +
		f64(advance), projection.run.font())
	return width.minus(projection.rounded)
}
