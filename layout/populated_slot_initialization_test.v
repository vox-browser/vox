module layout

import css
import dom

fn test_population_initializes_geometry_and_leaves_layout_only_state_absent() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(node)
	original.content_width_ = CSSPixels.new(101)
	original.content_height_ = CSSPixels.new(53)
	original.has_definite_width_ = true
	original.has_definite_height_ = true
	original.width_constraint = .min_content
	original.height_constraint = .max_content
	original.offset = css.CSSPixelPoint.new(CSSPixels.new(7), CSSPixels.new(11))
	original.margin_left = CSSPixels.new(1)
	original.margin_right = CSSPixels.new(2)
	original.margin_top = CSSPixels.new(3)
	original.margin_bottom = CSSPixels.new(4)
	original.border_left = CSSPixels.new(5)
	original.border_right = CSSPixels.new(6)
	original.border_top = CSSPixels.new(7)
	original.border_bottom = CSSPixels.new(8)
	original.padding_left = CSSPixels.new(9)
	original.padding_right = CSSPixels.new(10)
	original.padding_top = CSSPixels.new(11)
	original.padding_bottom = CSSPixels.new(12)
	original.inset_left = CSSPixels.new(13)
	original.inset_right = CSSPixels.new(14)
	original.inset_top = CSSPixels.new(15)
	original.inset_bottom = CSSPixels.new(16)
	original.containing_line_box_fragment = LineBoxFragmentCoordinate{line_box_index: 3, fragment_index: 5}
	original.scrollable_overflow_rect_ = css.CSSPixelRect.new(1, 2, 300, 400)
	original.has_scrollable_overflow_ = true
	original.line_boxes << LineBox.new(.rtl, .horizontal_tb)
	mut probe := LayoutState.new_for_subtree(node)
	mut copied := probe.populate_node_from(mut source, node)
	assert voidptr(copied.node()) == voidptr(node)
	assert copied.content_width() == CSSPixels.new(101)
	assert copied.content_height() == CSSPixels.new(53)
	assert copied.padding_box_width() == CSSPixels.new(120)
	assert copied.padding_box_height() == CSSPixels.new(76)
	assert copied.border_box_width() == CSSPixels.new(131)
	assert copied.border_box_height() == CSSPixels.new(91)
	assert copied.margin_box_width() == CSSPixels.new(134)
	assert copied.margin_box_height() == CSSPixels.new(98)
	assert copied.offset == css.CSSPixelPoint.new(CSSPixels.new(7), CSSPixels.new(11))
	assert copied.inset_left == CSSPixels.new(13)
	assert copied.inset_right == CSSPixels.new(14)
	assert copied.inset_top == CSSPixels.new(15)
	assert copied.inset_bottom == CSSPixels.new(16)
	assert copied.has_definite_width_ && copied.has_definite_height_
	assert !copied.has_definite_width() && !copied.has_definite_height()
	assert copied.width_constraint == .min_content && copied.height_constraint == .max_content
	assert copied.containing_block_used_values() == none
	assert copied.containing_line_box_fragment? == LineBoxFragmentCoordinate{line_box_index: 3, fragment_index: 5}
	assert copied.scrollable_overflow_rect() == none
	assert !copied.has_scrollable_overflow()
	assert !copied.has_rare_data()
	assert copied.line_boxes.len == 1 && copied.line_boxes[0].direction_ == .rtl
	assert copied.line_boxes.data != original.line_boxes.data
	copied.line_boxes[0].inline_length_ = CSSPixels.new(77)
	assert original.line_boxes[0].inline_length_ == CSSPixels.new(0)
	original.margin_left = CSSPixels.new(50)
	assert copied.margin_box_width() == CSSPixels.new(134)
	probe.release_measurement()
}

fn test_population_keeps_distinct_slots_across_sparse_page_and_chunk_boundaries() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut source := LayoutState.new()
	mut nodes := []&NodeWithStyle{}
	for index in 0 .. 65 {
		mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
		node.set_layout_index(u32(index * 17))
		mut value := source.get_mutable(node)
		value.set_content_width(CSSPixels.new(index + 30))
		nodes << node
	}
	mut probe := LayoutState.new_for_subtree(nodes[0])
	mut addresses := []voidptr{}
	for node in nodes { addresses << voidptr(probe.populate_node_from(mut source, node)) }
	gc_collect()
	for index, node in nodes {
		mut value := probe.get_mutable(node)
		assert voidptr(value) == addresses[index]
		assert value.content_width() == CSSPixels.new(index + 30)
		assert value.content_height() == CSSPixels.new(0)
		assert value.containing_block_used_values() == none
		assert value.scrollable_overflow_rect() == none
		assert !value.has_rare_data()
		assert value.line_boxes.len == 0
		value.line_boxes << LineBox.new(.rtl, .vertical_rl)
		assert value.line_boxes.len == 1
		assert source.get(node).line_boxes.len == 0
	}
	probe.release_measurement()
}

fn test_population_into_retained_state_owns_probe_snapshots_after_release() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut probe := LayoutState.new_for_subtree(node)
	mut original := probe.get_mutable(node)
	original.set_content_width(CSSPixels.new(113))
	original.set_inline_end_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(17, 29, 0, 0)})
	original.set_grid_template_columns([CSSPixels.new(41)])
	original.line_boxes << LineBox.new(.rtl, .horizontal_tb)
	mut retained := LayoutState.new()
	copied := retained.populate_node_from(mut probe, node)
	assert copied.inline_end_snapshot_arena_ == unsafe { nil }
	assert voidptr(copied.inline_end_static_position_snapshot_) != voidptr(original.inline_end_static_position_snapshot_)
	probe.release_measurement()
	gc_collect()
	assert copied.content_width() == CSSPixels.new(113)
	assert copied.inline_end_static_position_rect()?.rect.x.to_double() == 17
	assert copied.inline_end_static_position_rect()?.rect.y.to_double() == 29
	assert copied.grid_template_columns()[0] == CSSPixels.new(41)
	assert copied.line_boxes.len == 1
	mut next := LayoutState.new_for_subtree(node)
	mut fresh := next.populate_node_from(mut retained, node)
	fresh.set_inline_end_static_position_rect(StaticPositionRect{})
	fresh.set_grid_template_columns([CSSPixels.new(99)])
	next.release_measurement()
	assert copied.inline_end_static_position_rect()?.rect.x.to_double() == 17
	assert copied.grid_template_columns()[0] == CSSPixels.new(41)
}
