module layout

import css
import dom

fn test_retained_value_restore_keeps_record_identity_and_rebinds_independent_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computed := css.ComputedProperties.new()
	root := BlockContainer.new(document, none, computed)
	child := BlockContainer.new(document, none, computed)
	mut root_node := unsafe { &Node(root) }
	child_node := unsafe { &Node(child) }
	root_node.append_child(child_node)
	assign_layout_indexes(root_node)
	recompute_containing_blocks(root_node)
	root_style := unsafe { &NodeWithStyle(root) }
	child_style := unsafe { &NodeWithStyle(child) }
	mut previous := LayoutState.new()
	mut old_parent := previous.get_mutable(root_style)
	old_parent.set_content_width(CSSPixels.new(200))
	old_parent.set_has_definite_width(true)
	old_parent.offset = css.CSSPixelPoint.new(CSSPixels.new(2), CSSPixels.new(4))
	mut old_child := previous.get_mutable(child_style)
	old_child.set_content_width(CSSPixels.new(71))
	old_child.set_content_height(CSSPixels.new(19))
	old_child.offset = css.CSSPixelPoint.new(CSSPixels.new(3), CSSPixels.new(5))
	old_child.set_grid_template_columns([CSSPixels.new(19)])
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.fragments_ << LineBoxFragment{inline_length_: CSSPixels.new(31)}
	old_child.line_boxes << line
	mut snapshot := *old_child
	snapshot.containing_block_used_values_ = none
	snapshot.line_boxes = copy_retained_inline_lines(old_child.line_boxes)
	if rare := snapshot.rare_ { snapshot.rare_ = rare.clone() }
	old_offset := old_child.cumulative_offset()
	for preexisting in [false, true] {
		mut current := LayoutState.new()
		mut parent := current.get_mutable(root_style)
		parent.set_content_width(CSSPixels.new(200))
		parent.set_has_definite_width(true)
		parent.offset = css.CSSPixelPoint.new(CSSPixels.new(12), CSSPixels.new(24))
		mut address := voidptr(0)
		if preexisting { address = voidptr(current.get_mutable(child_style)) }
		restored := current.restore_retained_values(child_style, &snapshot, parent)
		if preexisting { assert voidptr(restored) == address }
		assert voidptr(current.try_get(child_style)?) == voidptr(restored)
		assert voidptr(restored.containing_block_used_values()?) == voidptr(parent)
		assert restored.content_width() == CSSPixels.new(71)
		assert restored.content_height() == CSSPixels.new(19)
		assert restored.cumulative_offset().x() == old_offset.x().plus(CSSPixels.new(10))
		assert restored.cumulative_offset().y() == old_offset.y().plus(CSSPixels.new(20))
		assert restored.line_boxes.data == snapshot.line_boxes.data
		mut writable := current.get_mutable(child_style)
		writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(777)
		writable.set_grid_template_columns([CSSPixels.new(47)])
		assert snapshot.line_boxes[0].fragments_[0].inline_length_ == CSSPixels.new(31)
		assert old_child.line_boxes[0].fragments_[0].inline_length_ == CSSPixels.new(31)
		assert snapshot.grid_template_columns()[0] == CSSPixels.new(19)
		assert old_child.grid_template_columns()[0] == CSSPixels.new(19)
		assert old_child.cumulative_offset() == old_offset
	}
}
