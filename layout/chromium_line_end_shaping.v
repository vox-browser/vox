module layout

import math
import platform

// A break before a collapsed space can cut an unsafe HarfBuzz boundary:
// e.g. Arial's Y-space kern changes Y's advance. Removing only the space
// retains that kern. Blink's ShapingLineBreaker reshapes the exposed boundary
// before measuring/alignment. Keep the same supported context-shaping scope,
// and leave bidi, fallback faces and ambiguous cluster coverage alone.
fn (fragment &LineBoxFragment) chromium_visible_line_end(at_break bool) ?string {
	run := fragment.glyph_run_ or { return none }
	if automatic_hyphen_character(run) != none { return none }
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
	if !isnil(fragment.intrinsic_glyph_runs_) {
		for borrowed in fragment.intrinsic_glyph_runs_.runs {
			if automatic_hyphen_character(borrowed) != none { return none }
			for glyph in borrowed.glyphs_ {
				covered += glyph.length_in_code_units
				has_glyph_indices = has_glyph_indices || glyph.glyph_index != 0
			}
		}
	} else {
		for glyph in run.glyphs_ {
			covered += glyph.length_in_code_units
			has_glyph_indices = has_glyph_indices || glyph.glyph_index != 0
		}
	}
	if covered != fragment.length_in_code_units_ || !has_glyph_indices { return none }
	text := fragment.text() or { return none }
	return utf16_substring_for_line_box(text, 0, length)
}

// Blink reshapes a line end within its script runs: spaces, digits and
// punctuation keep the script of the letter before them. Returns the UTF-16
// offset in `visible` where its final script run begins. A fragment merged
// from same-font chunks, such as the Latin-subset " VK" after Cyrillic text,
// keeps its leading space, shaped in the Cyrillic run, and reshapes only "VK".
fn (fragment &LineBoxFragment) chromium_line_end_script_tail(visible string) int {
	if visible.len == 0 { return 0 }
	if visible.is_ascii() {
		// Every ASCII letter is Latin: only leading common characters that
		// continue a preceding Cyrillic run can split this line end.
		for index in 0 .. visible.len {
			character := visible[index]
			if (character >= `A` && character <= `Z`) || (character >= `a` && character <= `z`) {
				return if index > 0 && fragment.chromium_script_before_fragment() == .cyrillic {
					index
				} else {
					0
				}
			}
		}
		return 0
	}
	mut script := ChromiumContextScript.common
	mut known := false
	mut start := 0
	mut offset := 0
	for character in visible.runes() {
		current := chromium_context_code_point_script(u32(character))
		if current != .common {
			if !known {
				// Leading common characters continue the run before the
				// fragment, or join this letter's run at the text start.
				known = true
				if offset > 0 {
					script = fragment.chromium_script_before_fragment()
				}
			}
			if script != .common && current != script { start = offset }
			script = current
		}
		offset += if u32(character) > 0xffff { 2 } else { 1 }
	}
	return start
}

// The exact pen of the glyph that begins `tail_start` code units into a
// fragment's merged run, as Blink sums its item advances. None unless a glyph
// starts there and the run's placement agrees with that pen.
fn (fragment &LineBoxFragment) chromium_line_end_prefix(run &platform.GlyphRun, tail_start int) ?ChromiumLineEndPrefix {
	mut covered := 0
	mut pen := f64(0)
	for index, glyph in run.glyphs_ {
		if covered == tail_start {
			placed := f64(glyph.position.x) - f64(glyph.offset_x) - f64(fragment.glyph_remainder_)
			if math.abs(placed - pen) > 0.01 { return none }
			return ChromiumLineEndPrefix{ glyphs: index, pen: pen }
		}
		if covered > tail_start { return none }
		covered += glyph.length_in_code_units
		pen += f64(glyph.advance)
	}
	return none
}

struct ChromiumLineEndPrefix {
	glyphs int
	pen    f64
}

// The script of the last Latin or Cyrillic letter before this fragment in its
// text node.
fn (fragment &LineBoxFragment) chromium_script_before_fragment() ChromiumContextScript {
	if fragment.start_ <= 0 || fragment.block_ellipsis_text_ != none { return .common }
	text_node := fragment.layout_node_.as_text_node() or { return .common }
	return chromium_script_before_offset(text_node, fragment.start_)
}

// The script of the last Latin or Cyrillic letter before UTF-16 offset
// `start` in a text node; scans back without copying the text.
fn chromium_script_before_offset(text_node &TextNode, start int) ChromiumContextScript {
	if start <= 0 { return .common }
	value := text_node.text_for_rendering()
	if text_node.rendered_text_is_ascii_ {
		mut index := math.min(start, value.len) - 1
		for index >= 0 {
			script := chromium_context_code_point_script(u32(value[index]))
			if script != .common { return script }
			index--
		}
		return .common
	}
	units := text_node.cached_utf16_code_units_ or { utf16_code_units_for_line_box(value) }
	mut index := math.min(start, units.len) - 1
	for index >= 0 {
		script := chromium_context_code_point_script(u32(units[index]))
		if script != .common { return script }
		index--
	}
	return .common
}

fn (fragment &LineBoxFragment) chromium_shape_without_trailing_whitespace(at_break bool) ?&platform.GlyphRun {
	visible := fragment.chromium_visible_line_end(at_break) or { return none }
	run := fragment.glyph_run_ or { return none }
	tail_start := fragment.chromium_line_end_script_tail(visible)
	if tail_start == 0 {
		return chromium_shape_line_end(fragment.layout_node_, visible, run, fragment.glyph_remainder_)
	}
	prefix := fragment.chromium_line_end_prefix(run, tail_start) or { return none }
	tail_text := utf16_substring_for_line_box(visible, tail_start,
		utf16_length_for_line_box(visible) - tail_start)
	tail := chromium_shape_line_end(fragment.layout_node_, tail_text, run, 0) or { return none }
	if tail.glyphs_.len == 0 { return none }
	// The tail slice starts at its first glyph's placement; restore its pen.
	origin := f64(tail.glyphs_[0].offset_x)
	base := prefix.pen + f64(fragment.glyph_remainder_) + origin
	mut glyphs := run.glyphs_[..prefix.glyphs].clone()
	for glyph in tail.glyphs_ {
		mut placed := glyph
		placed.position.x = f32(base + f64(glyph.position.x))
		glyphs << placed
	}
	return &platform.GlyphRun{
		font_:              run.font()
		text_type_:         .ltr
		face_:              run.face()
		width_:             f32(prefix.pen + f64(tail.width()))
		glyphs_:            glyphs
		space_width:        run.space_width
		replay_data_dirty_: true
	}
}

fn (fragment &LineBoxFragment) chromium_width_without_trailing_whitespace(at_break bool) ?f32 {
	visible := fragment.chromium_visible_line_end(at_break) or { return none }
	run := fragment.glyph_run_ or { return none }
	visible_length := fragment.length_in_code_units_ - fragment.trailing_whitespace_.length_in_code_units
	tail_start := fragment.chromium_line_end_script_tail(visible)
	if tail_start > 0 {
		prefix := fragment.chromium_line_end_prefix(run, tail_start) or { return none }
		tail_text := utf16_substring_for_line_box(visible, tail_start, visible_length - tail_start)
		tail_width := chromium_line_end_width(fragment.layout_node_, tail_text, run) or { return none }
		return f32(prefix.pen + f64(tail_width))
	}
	if width := chromium_cached_safe_line_end(fragment.layout_node_, fragment.start_, visible_length, run) {
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
	letter_spacing := f32(resolved_text_spacing_for_shaping(node, .letter_spacing))
	word_spacing := f32(resolved_text_spacing_for_shaping(node, .word_spacing))
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
	letter_spacing := f32(resolved_text_spacing_for_shaping(node, .letter_spacing))
	word_spacing := f32(resolved_text_spacing_for_shaping(node, .word_spacing))
	metrics := platform.shaped_text_context_metrics(letter_spacing, word_spacing, visible,
		run.font(), .ltr) or { return none }
	if metrics.face != run.face()
		|| metrics.length_in_code_units != utf16_length_for_line_box(visible) {
		return none
	}
	return metrics.width
}

fn (projection &ProjectedTextAdvance) chromium_line_end_correction() CSSPixels {
	if projection.run != unsafe { nil } && automatic_hyphen_character(projection.run) != none {
		return CSSPixels.new(0)
	}
	if projection.node == unsafe { nil } || projection.run == unsafe { nil }
		|| projection.segment_length <= 0
		|| projection.segment_start + projection.segment_length != projection.end {
		return CSSPixels.new(0)
	}
	text_node := projection.node.as_text_node() or { return CSSPixels.new(0) }
	advance := chromium_cached_safe_line_end(projection.node, projection.segment_start,
		projection.segment_length, projection.run) or {
		text := text_node.rendered_substring_for_line_box(
			projection.segment_start, projection.segment_length)
		chromium_line_end_width(projection.node, text, projection.run) or {
			return CSSPixels.new(0)
		}
	}
	width := inline_advance_to_css_pixels(projection.precise - projection.segment_width +
		f64(advance), projection.run.font())
	return width.minus(projection.rounded)
}
