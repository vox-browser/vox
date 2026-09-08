module layout

import dom
import css
import painting

// LayoutState stores per-box UsedValues; UsedValues computes the box-model boxes from content + edges.
fn test_layout_state_used_values() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut box := NodeWithStyle.new(doc, none, style)

	mut state := LayoutState.new()
	if _ := state.try_get(box) {
		panic('should have no used values before get_mutable')
	}

	mut uv := state.get_mutable(box)
	uv2 := state.get_mutable(box)
	assert voidptr(uv) == voidptr(uv2) // idempotent
	uv_node := uv.node()
	assert voidptr(uv_node) == voidptr(box)

	uv.set_content_width(CSSPixels.nearest_value_for(100.0))
	uv.set_content_height(CSSPixels.nearest_value_for(50.0))
	uv.padding_left = CSSPixels.nearest_value_for(10.0)
	uv.padding_right = CSSPixels.nearest_value_for(10.0)
	uv.border_left = CSSPixels.nearest_value_for(2.0)
	uv.border_right = CSSPixels.nearest_value_for(2.0)
	uv.margin_left = CSSPixels.nearest_value_for(5.0)
	uv.margin_right = CSSPixels.nearest_value_for(5.0)

	assert uv.content_width().to_double() == 100.0
	assert uv.has_definite_width()
	// border box width = (2+10) + 100 + (10+2) = 124
	assert uv.border_box_width().to_double() == 124.0
	// margin box width = (5+2+10) + 100 + (10+2+5) = 134
	assert uv.margin_box_width().to_double() == 134.0

	found := state.try_get(box) or { panic('used values should exist after get_mutable') }
	assert voidptr(found) == voidptr(uv)
}

fn test_layout_state_collapsed_borders_use_rounded_half_width() {
	mut values := UsedValues{}
	values.set_content_width(CSSPixels.nearest_value_for(100))
	values.set_content_height(CSSPixels.nearest_value_for(50))
	values.margin_left = CSSPixels.nearest_value_for(5)
	values.margin_top = CSSPixels.nearest_value_for(7)
	values.border_left = CSSPixels.nearest_value_for(5)
	values.border_right = CSSPixels.nearest_value_for(3)
	values.border_top = CSSPixels.nearest_value_for(1)
	values.border_bottom = CSSPixels.nearest_value_for(2)
	values.padding_left = CSSPixels.nearest_value_for(10)
	values.padding_right = CSSPixels.nearest_value_for(11)
	values.padding_top = CSSPixels.nearest_value_for(12)
	values.padding_bottom = CSSPixels.nearest_value_for(13)

	assert values.border_box_width().to_double() == 129
	assert values.border_box_height().to_double() == 78
	values.set_override_borders_data(painting.BordersDataWithElementKind{})
	assert values.use_collapsing_borders_model()
	assert values.border_left_collapsed().to_double() == 3
	assert values.border_right_collapsed().to_double() == 2
	assert values.border_top_collapsed().to_double() == 1
	assert values.border_bottom_collapsed().to_double() == 1
	assert values.border_box_width().to_double() == 126
	assert values.border_box_height().to_double() == 77
	assert values.margin_box_left().to_double() == 18
	assert values.margin_box_top().to_double() == 20
}

// cumulative_offset sums a box's offset up the containing-block chain.
fn test_cumulative_offset() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut containing_block := NodeWithStyle.new(doc, none, style)
	mut child := NodeWithStyle.new(doc, none, style)
	containing_block.set_layout_index(0)
	child.set_layout_index(1)

	mut state := LayoutState.new()
	mut cb_uv := state.get_mutable(containing_block)
	cb_uv.set_content_offset(css.CSSPixelPoint.from_values(10.0, 20.0))
	mut child_uv := state.get_mutable(child)
	child_uv.set_content_offset(css.CSSPixelPoint.from_values(3.0, 4.0))
	child_uv.set_containing_block_used_values(cb_uv)

	cumulative := child_uv.cumulative_offset()
	assert cumulative.x().to_double() == 13.0
	assert cumulative.y().to_double() == 24.0

	// Indefinite content height until set.
	assert !child_uv.has_definite_height()
	child_uv.set_content_height(CSSPixels.nearest_value_for(7.0))
	assert !child_uv.has_definite_height()
	child_uv.set_has_definite_height(true)
	assert child_uv.has_definite_height()
}

fn test_layout_state_paged_store_and_layout_indices() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut root := NodeWithStyle.new(doc, none, style)
	mut child := NodeWithStyle.new(doc, none, style)
	mut page_two_child := NodeWithStyle.new(doc, none, style)
	root.append_child(unsafe { &Node(child) })
	child.append_child(unsafe { &Node(page_two_child) })

	assert assign_layout_indexes(unsafe { &Node(root) }) == 3
	assert root.layout_index() == 0
	assert child.layout_index() == 1
	assert page_two_child.layout_index() == 2

	// Exercise lazy allocation across the 16-entry page boundary.
	page_two_child.set_layout_index(16)
	mut state := LayoutState.new()
	state.ensure_capacity(17)
	mut root_values := state.get_mutable(root)
	mut distant_values := state.get_mutable(page_two_child)
	root_values.set_content_width(CSSPixels.new(10))
	distant_values.set_content_width(CSSPixels.new(20))
	if _ := state.try_get(child) {
		panic('unwritten index 1 unexpectedly present')
	}
	assert (state.try_get(root) or { panic('index 0 absent') }).content_width().to_double() == 10
	assert (state.try_get(page_two_child) or { panic('index 16 absent') }).content_width().to_double() == 20
}

fn test_used_values_clamp_sizes_and_propagate_intrinsic_constraints() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	box := NodeWithStyle.new(doc, none, style)
	mut state := LayoutState.new()
	mut values := state.get_mutable(box)
	values.set_content_width(CSSPixels.nearest_value_for(-5))
	values.set_content_height(CSSPixels.nearest_value_for(-7))
	assert values.content_width().to_double() == 0
	assert values.content_height().to_double() == 0
	assert values.has_definite_width()
	assert !values.has_definite_height()
	inner := values.available_inner_space_or_constraints_from(AvailableSpace.new(AvailableSize.make_min_content(),
		AvailableSize.make_max_content()))
	assert inner.width.is_definite()
	assert inner.height.is_max_content()
}

fn test_used_values_static_position_uses_margin_box_size() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	box := NodeWithStyle.new(doc, none, style)
	mut state := LayoutState.new()
	mut values := state.get_mutable(box)
	values.set_content_width(CSSPixels.nearest_value_for(20))
	values.set_content_height(CSSPixels.nearest_value_for(10))
	values.margin_left = CSSPixels.nearest_value_for(5)
	values.margin_right = CSSPixels.nearest_value_for(5)
	values.set_static_position_rect(StaticPositionRect{
		rect:                 css.CSSPixelRect.new(10, 20, 100, 80)
		horizontal_alignment: .center
		vertical_alignment:   .end
	})
	position := values.static_position()
	assert position.x().to_double() == 45
	assert position.y().to_double() == 90
}

fn test_used_values_resolve_definite_percentage_from_containing_block() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	child.set_attribute_value('style',
		'width: 50%; min-width: 0; max-width: none; height: 25%; min-height: 0; max-height: none')
	mut document_node := unsafe { &dom.Node(doc) }
	document_node.append_child(html.as_node()) or { panic('${err}') }
	mut html_node := html.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	viewport := root.as_node_with_style() or { panic('viewport has no style') }
	html_box := root.first_child() or { panic('no html box') }
	child_box := html_box.first_child() or { panic('no child box') }
	html_styled := html_box.as_node_with_style() or { panic('html has no style') }
	child_styled := child_box.as_node_with_style() or { panic('child has no style') }
	assert viewport.layout_index() == 0
	assert html_styled.layout_index() == 1
	assert child_styled.layout_index() == 2
	assert child_styled.computed_values().size_value(.width).is_percentage()
	child_containing_block := child_box.containing_block() or {
		panic('child has no containing block')
	}
	assert voidptr(child_containing_block) == voidptr(html_box)

	mut state := LayoutState.new()
	mut viewport_values := state.get_mutable(viewport)
	viewport_values.set_content_width(CSSPixels.new(800))
	viewport_values.set_content_height(CSSPixels.new(600))
	viewport_values.set_has_definite_height(true)
	mut html_values := state.get_mutable(html_styled)
	assert html_values.has_definite_width()
	assert html_values.content_width().to_double() == 800
	// Give the percentage-height containing block a definite height, as a
	// formatting context does after resolving its own auto height.
	html_values.set_content_height(CSSPixels.new(400))
	html_values.set_has_definite_height(true)
	child_values := state.get_mutable(child_styled)
	assert voidptr(child_values.node()) == voidptr(child_styled)
	assert child_values.has_definite_width()
	assert child_values.has_definite_height()
	assert child_values.content_width().to_double() == 400
	assert child_values.content_height().to_double() == 100
}

fn test_layout_state_populate_node_from_copies_values_without_ancestor_chain() {
	mut document := dom.Document.create(dom.url_about_blank())
	computed := css.ComputedProperties.new()
	mut root := BlockContainer.new(document, none, computed)
	mut child := BlockContainer.new(document, none, computed)
	mut root_node := unsafe { &Node(root) }
	child_node := unsafe { &Node(child) }
	root_node.append_child(child_node)
	assign_layout_indexes(unsafe { &Node(root) })
	recompute_containing_blocks(unsafe { &Node(root) })

	mut source := LayoutState.new()
	mut root_values := source.get_mutable(unsafe { &NodeWithStyle(root) })
	root_values.set_content_width(CSSPixels.new(321))
	root_values.set_content_height(CSSPixels.new(123))
	root_values.margin_left = CSSPixels.new(7)
	root_values.line_boxes << LineBox.new(.ltr, .horizontal_tb)

	mut subtree := LayoutState.new_for_subtree(unsafe { &NodeWithStyle(child) })
	copied := subtree.populate_node_from(mut source, unsafe { &NodeWithStyle(root) })
	assert copied.content_width().to_double() == 321
	assert copied.content_height().to_double() == 123
	assert copied.margin_left.to_double() == 7
	assert copied.line_boxes.len == 1
	assert copied.containing_block_used_values() == none

	mut child_values := subtree.get_mutable(unsafe { &NodeWithStyle(child) })
	containing := child_values.containing_block_used_values() or {
		assert false
		return
	}
	assert voidptr(containing) == voidptr(copied)
	assert containing.content_width().to_double() == 321
}
