module layout

import css
import dom
import platform
import svg

fn test_ordinary_rare_geometry_copy_storage() {
	assert sizeof(UsedValuesRareData) <= 512
	mut values := UsedValues{}
	mut storage := platform.new_arena('ordinary rare geometry copies')
	entry := storage.enter()
	for index in 0 .. 1024 {
		values = UsedValues{}
		values.set_relative_inset_basis(CSSPixels.new(index), CSSPixels.new(20))
		values.set_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(3, 4, 20, 30)})
		rare := values.rare_?
		copy := rare.clone()
		assert copy.grid_geometry_ == none
		assert copy.svg_geometry_ == none
		assert copy.relative_inset_basis_width_?.raw_value() == CSSPixels.new(index).raw_value()
		assert copy.static_position_rect_?.rect.left_value() == 3
	}
	storage.leave(entry)
	used := storage.usage().used
	println('ordinary rare geometry: ${sizeof(UsedValuesRareData)} B per record, ${used} B in the fixture')
	$if prealloc {
		assert used <= 1024 * 1024
	}
	storage.release()
}

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

fn test_committed_layout_replay_shares_scalars_and_detaches_from_both_sides() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut before := LayoutState.new()
	mut original := before.get_mutable(node)
	original.set_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(3, 4, 20, 30)})
	original.set_has_line_clamp_point(true)
	mut after := LayoutState.new()
	mut restored := after.restore_layout_values(node, original, none, true)
	assert original.rare_is_shared_ && restored.rare_is_shared_
	assert voidptr(original.rare_?) == voidptr(restored.rare_?)
	original.set_has_line_clamp_point(false)
	assert restored.has_line_clamp_point()
	assert voidptr(original.rare_?) != voidptr(restored.rare_?)
	restored.set_static_position_rect(StaticPositionRect{rect: css.CSSPixelRect.new(7, 8, 20, 30)})
	assert restored.static_position() != original.static_position()
}

fn test_committed_layout_replay_owns_svg_and_grid_geometry() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut before := LayoutState.new()
	mut original := before.get_mutable(node)
	original.set_grid_template_columns([CSSPixels.new(10)])
	original.set_computed_svg_path(svg.Path{
		instructions: [svg.PathInstruction{type_: .move, data: [f64(7), 8]}]
	})
	mut after := LayoutState.new()
	restored := after.restore_layout_values(node, original, none, true)
	assert !restored.rare_is_shared_
	assert voidptr(original.rare_?) != voidptr(restored.rare_?)
	path := restored.computed_svg_path()?
	mut coordinates := unsafe { path.instructions[0].data }
	coordinates[0] = 99
	assert original.computed_svg_path()?.instructions[0].data[0] == 7
}
