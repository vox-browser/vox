module layout

import platform

fn text_node_hyphenation_language(node &Node) string {
	owner := node.dom_node() or { return '' }
	parent := owner.parent_or_shadow_host_element() or { return '' }
	return parent.lang() or { '' }
}

fn automatic_hyphen_character(run &platform.GlyphRun) ?rune {
	if run.glyphs_.len == 0 { return none }
	last := run.glyphs_.last()
	if last.is_automatic_hyphen && last.length_in_code_units == 0 && last.should_paint
		&& last.code_point in [u32(0x2010), u32(`-`)] {
		return rune(last.code_point)
	}
	return none
}

// Dictionary positions belong to the original whole word, including after an
// earlier line consumed a prefix. Never re-hyphenate a suffix as a new word.
fn (item &InlineLevelItem) automatic_hyphenation_boundaries() []int {
	node := item.node or { return []int{} }
	if node.computed_values().hyphens() != .auto_ || node.computed_values().direction() != .ltr
		|| node.computed_values().writing_mode() != .horizontal_tb {
		return []int{}
	}
	text := node.as_text_node() or { return []int{} }
	units := utf16_code_units_for_line_box(text.text_for_rendering())
	start := item.offset_in_node
	end := start + item.length_in_node
	if start < 0 || end > units.len || end <= start { return []int{} }
	mut word_start := start
	mut word_end := end
	for word_start > 0 {
		point := code_point_before_utf16(units, word_start)
		if !is_typographic_letter_unit(point) { break }
		word_start -= if point > 0xffff { 2 } else { 1 }
	}
	for word_end < units.len {
		point := code_point_at_utf16(units, word_end)
		if !is_typographic_letter_unit(point) { break }
		word_end += if point > 0xffff { 2 } else { 1 }
	}
	locations := platform.hyphenation_locations(units[word_start..word_end],
		text_node_hyphenation_language(node))
	graphemes := text.grapheme_boundaries_for_rendered_text()
	mut result := []int{cap: locations.len}
	for location in locations {
		boundary := word_start + location
		if boundary > start && boundary < end && has_sorted_grapheme_boundary(graphemes, boundary) {
			result << boundary
		}
	}
	return result
}

fn (item &InlineLevelItem) split_for_automatic_hyphenation(maximum_width CSSPixels,
	min_content bool) ?(InlineLevelItem, InlineLevelItem) {
	node := item.node or { return none }
	text := node.as_text_node() or { return none }
	run := item.glyph_run or { return none }
	if run.text_type() == .rtl || item.is_all_whitespace { return none }
	if !run.font().contains_glyph(0x2010) && !run.font().contains_glyph(u32(`-`)) { return none }
	boundaries := item.automatic_hyphenation_boundaries()
	if boundaries.len == 0 { return none }
	hyphen := if run.font().contains_glyph(0x2010) { '‐' } else { '-' }
	letter_spacing := f32(resolved_text_spacing_for_shaping(node, .letter_spacing))
	word_spacing := f32(resolved_text_spacing_for_shaping(node, .word_spacing))
	leading := css_pixels_sum3(item.margin_start, item.border_start, item.padding_start)
	for index in 0 .. boundaries.len {
		boundary := boundaries[if min_content { index } else { boundaries.len - 1 - index }]
		prefix := text.rendered_substring_for_line_box(item.offset_in_node, boundary - item.offset_in_node)
		mut prefix_run := shape_automatically_hyphenated_prefix(prefix, hyphen, run,
			letter_spacing, word_spacing)
		if prefix_run.glyphs_.len == 0 { continue }
		if !min_content && leading.plus(shaped_inline_width(prefix_run, 0)).raw_value() > maximum_width.raw_value() {
			continue
		}
		// The inserted paint glyph owns no DOM code units. Source ranges,
		// selection and the next line keep the original text-node offsets.
		prefix_run.invalidate_replay_data()
		prefix_run.glyphs_[prefix_run.glyphs_.len - 1].length_in_code_units = 0
		prefix_run.glyphs_[prefix_run.glyphs_.len - 1].is_automatic_hyphen = true
		remainder := text.rendered_substring_for_line_box(boundary,
			item.offset_in_node + item.length_in_node - boundary)
		remainder_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
			remainder, run.font(), run.text_type())
		return overflow_split_items(item, node, boundary, prefix_run,
			remainder_shape.glyph_run, TrailingWhitespace{},
			trailing_whitespace_from_shaped_text(remainder_shape))
	}
	return none
}

fn shape_automatically_hyphenated_prefix(prefix string, hyphen string,
	run &platform.GlyphRun, letter_spacing f32, word_spacing f32) &platform.GlyphRun {
	if run.font().font_rendering_policy != .chromium {
		return platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
			prefix + hyphen, run.font(), run.text_type()).glyph_run
	}
	// Blink shapes its inserted hyphen independently of the source text.
	// Shaping prefix+hyphen together kerns across that boundary (for example
	// SFNS's r-hyphen pair), shifting the hyphen and underestimating its fit.
	prefix_run := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
		prefix, run.font(), run.text_type()).glyph_run
	hyphen_run := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
		hyphen, run.font(), run.text_type()).glyph_run
	mut glyphs := prefix_run.glyphs_.clone()
	for source in hyphen_run.glyphs_ {
		mut glyph := source
		glyph.position.translate_by(prefix_run.width(), 0)
		glyphs << glyph
	}
	return platform.GlyphRun.new_with_face(run.font(), run.text_type(), glyphs, run.face())
}

fn (iterator &InlineLevelIterator) next_word_can_hyphenate(available CSSPixels) bool {
	if iterator.next_item_index >= iterator.items.len { return false }
	item := unsafe { &iterator.items[iterator.next_item_index] }
	if _, _ := item.split_for_automatic_hyphenation(available, false) { return true }
	return false
}

// A final word can wrap intact instead of filling the preceding line with a
// hyphenated prefix. Look across text-node boundaries in this inline paragraph;
// out-of-flow items do not turn a final word into a nonfinal one.
// This follows Blink's ShapingLineBreaker::ShouldHyphenate policy.
fn (iterator &InlineLevelIterator) has_in_flow_content_after(index int) bool {
	for i in index .. iterator.items.len {
		item := unsafe { &iterator.items[i] }
		if item.type_ == .block_level_box { return false }
		if item.type_ == .element || (item.type_ == .text && !item.is_all_whitespace) {
			return true
		}
	}
	return false
}

fn (iterator &InlineLevelIterator) is_paragraph_final_word(index int) bool {
	if index < 0 || index >= iterator.items.len { return false }
	// Reject nonfinal words before inspecting the text prefix, so a long
	// paragraph does not repeatedly copy every preceding code unit.
	if iterator.has_in_flow_content_after(index + 1) { return false }
	item := unsafe { &iterator.items[index] }
	node := item.node or { return false }
	text := node.as_text_node() or { return false }
	// Blink's line-start exception also applies when a new text range starts
	// inside an existing line, such as a word in a separate inline span.
	if item.offset_in_node == 0
		|| text.rendered_substring_for_line_box(0, item.offset_in_node).trim_space() == '' {
		return false
	}
	return true
}

fn break_automatically_hyphenated_item(mut builder LineBuilder, mut item InlineLevelItem,
	following []InlineLevelItem, final_word bool) {
	for {
		if final_word && !builder.available_width.is_min_content()
			&& !builder.current_line_is_empty() { return }
		remaining := builder.remaining_width_for_overflow_break() or { return }
		if builder.projected_text_sequence_width(item, following).raw_value() <= remaining.raw_value() {
			return
		}
		prefix, remainder := item.split_for_automatic_hyphenation(remaining,
			builder.available_width.is_min_content()) or { return }
		builder.append_text_item(prefix, (prefix.node or { return }).computed_values().line_height())
		builder.note_soft_wrap_opportunity()
		builder.break_line(.no, none)
		item = remainder
	}
}
