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
		prefix_shape := platform.shape_text_with_spacing(0, letter_spacing, word_spacing,
			prefix + hyphen, run.font(), run.text_type())
		mut prefix_run := prefix_shape.glyph_run
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

fn (iterator &InlineLevelIterator) next_word_can_hyphenate(available CSSPixels) bool {
	if iterator.next_item_index >= iterator.items.len { return false }
	item := unsafe { &iterator.items[iterator.next_item_index] }
	if _, _ := item.split_for_automatic_hyphenation(available, false) { return true }
	return false
}

fn break_automatically_hyphenated_item(mut builder LineBuilder, mut item InlineLevelItem,
	following []InlineLevelItem) {
	for {
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
