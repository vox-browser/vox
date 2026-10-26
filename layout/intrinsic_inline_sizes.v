module layout

// Upstream Rust layout/intrinsic_sizing.rs measures supported inline content
// without producing line fragments. Keep the translated path conservative:
// only ordinary horizontal text participates, and both widths share one item
// iterator. Atomic boxes and block interruptions still need subtree layout.
struct IntrinsicInlineWidths {
	minimum CSSPixels
	maximum CSSPixels
}

struct IntrinsicTextLine {
mut:
	advance       ProjectedTextAdvance
	width         CSSPixels
	visible_width CSSPixels
	has_content   bool
	ends_in_space bool
}

fn (mut line IntrinsicTextLine) append(item &InlineLevelItem) {
	if item.is_collapsible_whitespace && (!line.has_content || line.ends_in_space) {
		return
	}
	if node := item.node {
		// Collapsed source spaces can leave a gap between shaped chunks while
		// both chunks still belong to the same rounded Chromium text item.
		if line.advance.node != unsafe { nil } && layout_nodes_same(line.advance.node, node)
			&& chromium_text_item_continues(node, line.advance.end, item.offset_in_node) {
			line.advance.end = item.offset_in_node
		}
	}
	line.width = line.width.plus(line.advance.append(item))
	line.has_content = true
	line.ends_in_space = item.is_all_whitespace
	if !item.is_all_whitespace {
		// Snapshot before a trailing space joins the precise text advance.
		// Subtracting the individually rounded space would lose a LayoutUnit.
		line.visible_width = line.width
	}
}

fn intrinsic_inline_text_topology(node &Node) bool {
	for child in node.children() {
		if child.is_out_of_flow() || child.is_atomic_inline() || child.is_box()
			|| child.is_svg_box() || child.is_list_item_marker_box()
			|| (!child.is_inline() && !child.is_text_node() && !child.is_break_node()) {
			return false
		}
		if text := child.as_text_node() {
			if text.first_letter_ != none || text.source_range_length_ != none
				|| text.is_empty_editable_ || text.produces_line_box_fragment_when_empty_
				|| text.text_for_rendering().contains('\t') || text_may_require_bidi_processing(text) {
				return false
			}
		}
		if !intrinsic_inline_text_topology(child) { return false }
	}
	return true
}

fn calculate_inline_intrinsic_widths(mut source_state LayoutState, box &Box) ?IntrinsicInlineWidths {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	indent := computed.text_indent().length_percentage
	if node.document().font_rendering_policy() != .chromium
		|| !node.children_are_inline() || node.is_table_wrapper() || node.is_fieldset_box()
		|| node_uses_button_layout(node) || node.is_scroll_container()
		|| node.has_size_containment() || node.has_inline_size_containment()
		|| node.is_list_item_box() || node.is_svg_box() || node.is_replaced_box()
		|| node.display().is_flex_inside() || node.display().is_grid_inside()
		|| node.display().is_table_inside() || node.document().cursor_position() != none
		|| computed.writing_mode() != .horizontal_tb || computed.direction() != .ltr
		|| computed.unicode_bidi() !in [.normal, .isolate] || computed.max_lines() != none
		|| computed.content_visibility() != .visible
		|| computed.continue_value() in [.collapse, .discard]
		|| computed.establishes_multi_column_container()
		|| !indent.is_length() || !indent.length().is_absolute()
		|| indent.length().raw_value() != 0 || !intrinsic_inline_text_topology(node) {
		return none
	}
	container := node.as_block_container() or { return none }
	styled := node.as_node_with_style() or { return none }
	mut measurement := source_state.new_measurement_for_subtree(styled)
	defer { measurement.release_measurement() }
	mut used := measurement.get_mutable(styled)
	used.width_constraint = .max_content
	used.set_indefinite_content_width()
	mut buffers := acquire_inline_item_buffers(node.document())
	mut iterator := new_inline_iterator_with_item_storage(mut measurement, container, used,
		.intrinsic_sizing, AvailableSpace.new(AvailableSize.make_max_content(),
			AvailableSize.make_indefinite()), none, buffers.arena)
	defer {
		if buffers.arena == unsafe { nil } { unsafe { iterator.items.free() } }
		buffers.finish()
	}
	mut minimum := CSSPixels.new(0)
	mut maximum := CSSPixels.new(0)
	mut min_line := IntrinsicTextLine{}
	mut max_line := IntrinsicTextLine{}
	for item in iterator.items {
		if item.border_box_width() != item.width || item.margin_start.raw_value() != 0
			|| item.margin_end.raw_value() != 0 {
			return none
		}
		if item.type_ == .forced_break {
			minimum = css_pixels_max(minimum, min_line.visible_width)
			maximum = css_pixels_max(maximum, max_line.visible_width)
			min_line = IntrinsicTextLine{}
			max_line = IntrinsicTextLine{}
			continue
		}
		if item.type_ != .text { return none }
		text_node := item.node or { return none }
		style := text_node.computed_values()
		run := item.glyph_run or { return none }
		if style.writing_mode() != .horizontal_tb || style.direction() != .ltr
			|| style.unicode_bidi() !in [.normal, .isolate] || style.text_align() == .justify
			|| style.white_space_collapse() !in [.collapse, .preserve_breaks]
			|| style.word_break() != .normal || style.overflow_wrap() != .normal
			|| run.font().font_rendering_policy != .chromium || run.text_type() == .rtl
			|| run.glyphs_.len == 0 || run.glyphs_[0].position.x != 0
			|| item.width != shaped_inline_width(run, 0)
			|| (!item.is_all_whitespace && item.trailing_whitespace.length_in_code_units != 0) {
			return none
		}
		max_line.append(&item)
		if style.text_wrap_mode() == .wrap {
			if item.is_all_whitespace {
				minimum = css_pixels_max(minimum, min_line.visible_width)
				min_line = IntrinsicTextLine{}
				continue
			}
			if item.can_break_before && min_line.has_content {
				minimum = css_pixels_max(minimum, min_line.visible_width)
				min_line = IntrinsicTextLine{}
			}
		}
		min_line.append(&item)
	}
	return IntrinsicInlineWidths{
		minimum: clamp_to_max_dimension_value(css_pixels_max(minimum, min_line.visible_width))
		maximum: clamp_to_max_dimension_value(css_pixels_max(maximum, max_line.visible_width))
	}
}
