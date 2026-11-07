module layout

import platform

// Exact equality of published inline layout, used to keep the previous pass's
// immutable lines when a context lays out to the same result again. Compare
// every field of LineBox, LineBoxFragment and StaticPositionMarker, and glyph
// runs by content (their replay buffers derive from the glyphs). Layout nodes
// and fonts compare by identity. Extend these when a field is added.

fn optional_pixels_equal(a ?CSSPixels, b ?CSSPixels) bool {
	if x := a {
		if y := b { return x == y }
		return false
	}
	return b == none
}

fn optional_f64_equal(a ?f64, b ?f64) bool {
	if x := a {
		if y := b { return x == y }
		return false
	}
	return b == none
}

fn optional_string_equal(a ?string, b ?string) bool {
	if x := a {
		if y := b { return x == y }
		return false
	}
	return b == none
}

fn published_glyph_runs_equal(a &platform.GlyphRun, b &platform.GlyphRun) bool {
	if voidptr(a) == voidptr(b) { return true }
	return voidptr(a.font_) == voidptr(b.font_) && a.text_type_ == b.text_type_
		&& a.face_ == b.face_ && a.width_ == b.width_ && a.space_width == b.space_width
		&& a.glyphs_ == b.glyphs_
}

fn line_box_fragments_equal(a &LineBoxFragment, b &LineBoxFragment) bool {
	if voidptr(a.layout_node_) != voidptr(b.layout_node_)
		|| voidptr(a.style_source_) != voidptr(b.style_source_)
		|| !optional_string_equal(a.block_ellipsis_text_, b.block_ellipsis_text_)
		|| a.is_block_ellipsis_ != b.is_block_ellipsis_ || a.start_ != b.start_
		|| a.length_in_code_units_ != b.length_in_code_units_
		|| a.inline_offset_ != b.inline_offset_ || a.block_offset_ != b.block_offset_
		|| a.inline_length_ != b.inline_length_ || a.block_length_ != b.block_length_
		|| a.border_box_top_ != b.border_box_top_ || a.baseline_ != b.baseline_
		|| a.direction_ != b.direction_ || a.writing_mode_ != b.writing_mode_
		|| a.insert_position_ != b.insert_position_
		|| a.current_insert_direction != b.current_insert_direction
		|| a.has_trailing_whitespace_ != b.has_trailing_whitespace_
		|| a.trailing_whitespace_ != b.trailing_whitespace_
		|| a.has_soft_wrap_opportunity_after_ != b.has_soft_wrap_opportunity_after_
		|| a.is_fully_truncated_ != b.is_fully_truncated_
		|| !optional_f64_equal(a.precise_inline_length_, b.precise_inline_length_)
		|| a.chains_item_ != b.chains_item_ || a.item_width_ != b.item_width_
		|| a.item_prefix_ != b.item_prefix_ || a.item_offset_ != b.item_offset_
		|| a.glyph_remainder_ != b.glyph_remainder_
		|| !isnil(a.intrinsic_glyph_runs_) || !isnil(b.intrinsic_glyph_runs_) {
		return false
	}
	if x := a.glyph_run_ {
		y := b.glyph_run_ or { return false }
		return published_glyph_runs_equal(x, y)
	}
	return b.glyph_run_ == none
}

fn static_position_markers_equal(a []StaticPositionMarker, b []StaticPositionMarker) bool {
	if a.len != b.len { return false }
	for index in 0 .. a.len {
		x := unsafe { &a[index] }
		y := unsafe { &b[index] }
		if voidptr(x.box) != voidptr(y.box) || x.inline_offset != y.inline_offset
			|| x.block_offset != y.block_offset || x.writing_mode != y.writing_mode
			|| x.preceded_by_in_flow_content != y.preceded_by_in_flow_content {
			return false
		}
	}
	return true
}

fn published_line_boxes_equal(a []LineBox, b []LineBox) bool {
	if a.len != b.len { return false }
	for line_index in 0 .. a.len {
		x := unsafe { &a[line_index] }
		y := unsafe { &b[line_index] }
		if x.fragments_.len != y.fragments_.len || x.inline_length_ != y.inline_length_
			|| !optional_pixels_equal(x.inline_length_before_block_ellipsis_, y.inline_length_before_block_ellipsis_)
			|| x.block_length_ != y.block_length_ || x.bottom_ != y.bottom_
			|| x.baseline_ != y.baseline_
			|| !optional_pixels_equal(x.font_box_baseline_, y.font_box_baseline_)
			|| x.trimmed_block_start_ != y.trimmed_block_start_
			|| x.direction_ != y.direction_ || x.writing_mode_ != y.writing_mode_
			|| x.original_available_width_ != y.original_available_width_
			|| x.has_break_ != y.has_break_ || x.has_forced_break_ != y.has_forced_break_
			|| x.has_block_level_box_ != y.has_block_level_box_
			|| x.block_level_box_bottom_margin_ != y.block_level_box_bottom_margin_
			|| x.intrinsic_width_only_ != y.intrinsic_width_only_
			|| !static_position_markers_equal(x.static_position_markers_, y.static_position_markers_) {
			return false
		}
		for fragment_index in 0 .. x.fragments_.len {
			if !line_box_fragments_equal(unsafe { &x.fragments_[fragment_index] },
				unsafe { &y.fragments_[fragment_index] }) {
				return false
			}
		}
	}
	return true
}

// The same box's lines from the previous document layout pass, if any.
fn previous_pass_line_boxes(state &LayoutState, containing_block &BlockContainer) ?[]LineBox {
	if isnil(state.previous_state_) || state.subtree_root != none { return none }
	styled := unsafe { &Node(containing_block) }.as_node_with_style() or { return none }
	for index in [styled.layout_index(), styled.previous_layout_index_] {
		previous := state.previous_state_.used_values_store.get(index) or { continue }
		if voidptr(previous.node_) != voidptr(styled) { continue }
		if previous.line_boxes.len == 0 { return none }
		return previous.line_boxes
	}
	return none
}
