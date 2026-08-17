module layout

import dom
import css

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

// cumulative_offset sums a box's offset up the containing-block chain.
fn test_cumulative_offset() {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut containing_block := NodeWithStyle.new(doc, none, style)
	mut child := NodeWithStyle.new(doc, none, style)

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
