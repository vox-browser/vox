module layout

import css
import dom

fn rare_measurement_test_box() &NodeWithStyle {
	document := dom.Document.create(dom.url_about_blank())
	return NodeWithStyle.new(document, none, css.ComputedProperties.new())
}

fn test_measurement_rare_scalars_keep_independent_snapshots_after_either_owner_changes() {
	box := rare_measurement_test_box()
	mut source := LayoutState.new()
	mut original := source.get_mutable(box)
	original.set_derived_baselines(CSSPixels.new(10), CSSPixels.new(20))
	mut first := LayoutState.new_for_subtree(box)
	mut a := first.populate_node_from(mut source, box)
	mut second := LayoutState.new_for_subtree(box)
	mut b := second.populate_node_from(mut source, box)
	original.set_derived_baselines(CSSPixels.new(30), CSSPixels.new(40))
	assert a.derived_first_baseline()?.to_double() == 10
	assert b.derived_last_baseline()?.to_double() == 20
	a.set_derived_baselines(CSSPixels.new(50), CSSPixels.new(60))
	a.set_use_collapsing_borders_model(true)
	gc_collect()
	assert original.derived_first_baseline()?.to_double() == 30
	assert b.derived_first_baseline()?.to_double() == 10
	assert !original.use_collapsing_borders_model()
	assert !b.use_collapsing_borders_model()
	assert a.derived_last_baseline()?.to_double() == 60
	first.release_measurement()
	second.release_measurement()
	assert original.derived_last_baseline()?.to_double() == 40
}

fn test_measurement_grid_array_borrows_remain_independent_across_population() {
	box := rare_measurement_test_box()
	mut source := LayoutState.new()
	mut original := source.get_mutable(box)
	original.set_grid_template_columns([CSSPixels.new(40)])
	mut borrowed := original.grid_template_columns()
	mut probe := LayoutState.new_for_subtree(box)
	mut copied := probe.populate_node_from(mut source, box)
	borrowed[0] = CSSPixels.new(70)
	assert original.grid_template_columns()[0].to_double() == 70
	assert copied.grid_template_columns()[0].to_double() == 40
	mut other_borrow := copied.grid_template_columns()
	other_borrow[0] = CSSPixels.new(90)
	gc_collect()
	assert original.grid_template_columns()[0].to_double() == 70
	assert copied.grid_template_columns()[0].to_double() == 90
	probe.release_measurement()
}

fn test_measurement_empty_reserved_array_borrows_do_not_share_writable_capacity() {
	box := rare_measurement_test_box()
	mut source := LayoutState.new()
	mut original := source.get_mutable(box)
	original.rare_ = &UsedValuesRareData{
		used_grid_template_columns: []CSSPixels{cap: 4}
	}
	mut borrowed := original.grid_template_columns()
	assert borrowed.len == 0 && borrowed.cap >= 4
	mut probe := LayoutState.new_for_subtree(box)
	copied := probe.populate_node_from(mut source, box)
	mut other_borrow := copied.grid_template_columns()
	borrowed << CSSPixels.new(11)
	other_borrow << CSSPixels.new(22)
	assert borrowed[0].to_double() == 11
	assert other_borrow[0].to_double() == 22
	assert original.grid_template_columns().len == 0
	assert copied.grid_template_columns().len == 0
	probe.release_measurement()
}
