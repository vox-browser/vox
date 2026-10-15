module layout

import css
import dom

fn set_all_rare_flags(mut values UsedValues, value bool) {
	values.set_has_line_clamp_point(value)
	values.set_invisible_for_line_clamp(value)
	values.set_use_collapsing_borders_model(value)
	values.set_is_collapsed_borders_table_box(value)
	values.set_hidden_by_collapsed_columns(value)
	values.set_grid_subgridded_axes(value, value)
	values.set_svg_rendering_disabled(value)
}

fn assert_all_rare_flags(values &UsedValues, value bool) {
	assert values.has_line_clamp_point() == value
	assert values.is_invisible_for_line_clamp() == value
	assert values.use_collapsing_borders_model() == value
	assert values.is_collapsed_borders_table_box() == value
	assert values.hidden_by_collapsed_columns() == value
	assert values.grid_columns_are_subgrid() == value
	assert values.grid_rows_are_subgrid() == value
	assert values.svg_rendering_disabled() == value
}

fn test_default_rare_flags_do_not_materialize_optional_layout_state() {
	mut values := UsedValues{}
	set_all_rare_flags(mut values, false)
	assert_all_rare_flags(values, false)
	assert !values.has_rare_data()
	set_all_rare_flags(mut values, true)
	assert_all_rare_flags(values, true)
	set_all_rare_flags(mut values, false)
	assert_all_rare_flags(values, false)
}

fn test_unchanged_rare_flags_preserve_measurement_sharing_and_real_changes_detach() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(node)
	original.set_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(3, 4, 20, 30)})
	set_all_rare_flags(mut original, true)
	mut probe := LayoutState.new()
	mut copy := probe.populate_node_from(mut source, node)
	shared_rare := copy.rare_ or { panic('missing shared rare state') }
	set_all_rare_flags(mut copy, true)
	assert voidptr(copy.rare_ or { panic('lost rare state') }) == voidptr(shared_rare)
	assert copy.rare_is_shared_
	set_all_rare_flags(mut copy, false)
	assert_all_rare_flags(copy, false)
	assert_all_rare_flags(original, true)
	assert voidptr(copy.rare_ or { panic('lost detached state') }) != voidptr(shared_rare)
	assert copy.static_position() == original.static_position()
	set_all_rare_flags(mut original, false)
	assert_all_rare_flags(original, false)
	assert_all_rare_flags(copy, false)
}
