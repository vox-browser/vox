module layout

import css
import dom

fn test_internal_scalar_updates_and_line_disposal_preserve_retained_fragments() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	container := BlockContainer.new(document, none, style)
	root := unsafe { &Node(container) }
	assign_layout_indexes(root)
	styled := root.as_node_with_style()?
	mut state := LayoutState.new()
	mut used := state.get_mutable(styled)
	lines := [LineBox{fragments_: [LineBoxFragment{inline_length_: CSSPixels.new(17)}]}]
	used.borrow_retained_line_boxes(lines)
	mut scalar := state.mutable_internal_box_values(styled)
	scalar.set_content_width(CSSPixels.new(80))
	assert scalar.line_boxes[0].fragments_[0].inline_length_ == CSSPixels.new(17)
	if !disable_lazy_internal_line_buffers {
		assert scalar.line_boxes.data == lines.data
		assert scalar.line_boxes_are_shared_
	}
	clear_intrinsic_flex_item_line_boxes(mut state, root)
	assert state.get(styled).line_boxes.len == 0
	assert lines.len == 1 && lines[0].fragments_.len == 1
	assert lines[0].fragments_[0].inline_length_ == CSSPixels.new(17)
	mut again := state.get(styled)
	again.borrow_retained_line_boxes(lines)
	mut public := state.get_mutable(styled)
	public.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(99)
	assert lines[0].fragments_[0].inline_length_ == CSSPixels.new(17)
}
