module layout

fn test_upstream_flex_state_distributes_free_space_and_cross_constraints() {
	mut context := FormattingContextState.create(.flex, 100, 60)
	context.main_size_value = 100
	context.item_sizes = [20.0, 30.0]
	context.main_gap_value = 10
	context.determine_available_space_for_items()
	assert context.get_free_space() == 40
	context.resolve_flexible_lengths()
	assert context.item_sizes == [40.0, 50.0]
	assert context.content_size_suggestion() == 100
	context.cross_min_value = 10
	context.cross_max_value = 30
	context.main_max_value = 50
	assert context.adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(50, 2) == 25
}

fn test_upstream_grid_and_table_state_keep_track_distribution_exact() {
	mut grid := FormattingContextState.create(.grid, 100, 80)
	grid.available_width = 100
	grid.main_gap_value = 10
	grid.initialize_grid_tracks_from_definition([20.0, 30.0])
	grid.maximize_tracks()
	assert grid.track_sizes == [40.0, 50.0]
	assert grid.calculate_grid_container_maximum_size() == 100

	mut table := FormattingContextState.create(.table, 120, 60)
	table.main_gap_value = 10
	table.column_sizes = [20.0, 30.0]
	table.distribute_width_to_columns(120)
	assert table.compute_columns_total_used_width() == 120
}

fn test_upstream_layout_node_unifies_special_box_and_paintable_state() {
	mut node := LayoutNodeState.create('image-1', 'image')
	node.intrinsic_width = 320
	node.intrinsic_height = 200
	node.default_bitmap_id = 'fallback'
	assert node.is_replaced_box()
	assert !node.can_have_children()
	width, height := node.natural_size()
	assert width == 320
	assert height == 200
	assert node.default_image_bitmap_sized(width, height)? == 'fallback'
	paintable := node.create_paintable()
	assert paintable == 'image-1:paintable'
	assert node.first_paintable()? == paintable
	node.clear_paintables()
	assert node.paintables().len == 0
}

fn test_upstream_grid_item_occupation_and_flex_line_state() {
	item := LayoutItemState{row: 1, column: 2, row_span: 2, column_span: 2, flex_base: 20, used_margin_start_value: 3, used_margin_end_value: 4}
	assert item.outer_flex_base_size() == 27
	mut occupation := LayoutGridState{}
	occupation.calculate_row_column_grid([item])
	assert occupation.is_area_occupied(1, 2, 2, 2)
	assert occupation.row_count() == 3
	assert occupation.column_count() == 4
	row, column := occupation.find_unoccupied_place(1, 1)
	assert !occupation.is_occupied(row, column)
	line := LayoutFlexLineState{grow_factors: [1.0, 2.0], shrink_factors: [1.0, 0.5], bases: [20.0, 40.0]}
	assert line.sum_of_flex_factor_of_unfrozen_items() == 3
	assert line.sum_of_scaled_flex_shrink_factor_of_unfrozen_items() == 40
}

fn test_upstream_tree_used_values_and_namespace_fixups_are_stateful() {
	mut builder := LayoutTreeBuilder.create()
	assert builder.build('root') == ['root']
	builder.push_parent('root')
	assert builder.pop_parent()? == 'root'
	assert builder.create_pseudo_element_if_needed('root', true)? == 'root::pseudo'
	builder.fixup_tables()
	assert 'fixup-tables' in builder.steps

	mut values := UsedValuesFacade{}
	values.add_floating_descendant('float')
	values.set_grid_template_columns([10.0, 20.0])
	values.set_table_cell_coordinates(3, 4)
	assert values.floating_descendants() == ['float']
	assert values.grid_template_columns() == [10.0, 20.0]
	row_index, column_index := values.table_cell_coordinates()
	assert row_index == 3
	assert column_index == 4

	assert fixup_row(['cell'], 3) == ['cell', 'anonymous-table-cell', 'anonymous-table-cell']
	assert is_proper_table_child('table-row')
	assert is_ignorable_whitespace(' \t\n')
}
