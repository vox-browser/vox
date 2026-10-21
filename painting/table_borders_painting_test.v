module painting

fn table_test_border(color Color, width f64, style LineStyle, kind ConflictingElementKind) BorderDataWithElementKind {
	return BorderDataWithElementKind{
		border_data: BorderData{
			color: color
			width: width
			line_style: style
		}
		element_kind: kind
	}
}

fn table_test_borders(color Color, width f64, style LineStyle) BordersDataWithElementKind {
	border := table_test_border(color, width, style, .cell)
	return BordersDataWithElementKind{border, border, border, border}
}

fn table_test_command_color(command DisplayListCommand) Color {
	return match command {
		DrawLine { command.color }
		FillRect { command.color }
		else { Color{} }
	}
}

fn test_collapsed_table_borders_collect_each_shared_edge_once() {
	red := Color{255, 0, 0, 255}
	cells := [
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 1}
			rect: Rect{10, 10, 20, 10}
			borders: table_test_borders(red, 2, .solid)
		},
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 1, 1, 1}
			rect: Rect{30, 10, 20, 10}
			borders: table_test_borders(red, 2, .solid)
		},
	]
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders(cells, true, converter)
	// Two top + two bottom + the two outside verticals + one shared edge.
	assert commands.len == 7
	mut shared_edges := 0
	for command in commands {
		match command {
			FillRect {
				if command.rect.x == 29 && command.rect.width == 2 && command.rect.height == 12 {
					shared_edges++
				}
			}
			else {}
		}
	}
	assert shared_edges == 1
}

fn test_collapsed_table_borders_snap_spans_to_shared_grid_lines() {
	blue := Color{0, 0, 255, 255}
	cells := [
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 2}
			rect: Rect{10.2, 10.2, 40.1, 10.1}
			borders: table_test_borders(blue, 1, .solid)
		},
		TableCellPaintData{
			coordinates: TableCellCoordinates{1, 0, 1, 1}
			rect: Rect{10.1, 20.3, 20.2, 9.8}
			borders: table_test_borders(blue, 1, .solid)
		},
		TableCellPaintData{
			coordinates: TableCellCoordinates{1, 1, 1, 1}
			rect: Rect{30.3, 20.3, 20, 9.8}
			borders: table_test_borders(blue, 1, .solid)
		},
	]
	converter := new_device_pixel_converter(1) or { panic(err) }
	rects := snap_cells_to_device_coordinates(cells, 2, 2, converter)
	spanning := rects[cell_coordinates_key(0, 0)]
	left_bottom := rects[cell_coordinates_key(1, 0)]
	right_bottom := rects[cell_coordinates_key(1, 1)]
	assert spanning.x == left_bottom.x
	assert spanning.right() == right_bottom.right()
	assert spanning.bottom() == left_bottom.y
}

fn test_collapsed_table_borders_split_in_css_pixels_before_device_snapping() {
	blue := Color{0, 0, 255, 255}
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders([
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 1}
			rect: Rect{10.25, 20.25, 20.5, 10.25}
			borders: table_test_borders(blue, 1.5, .solid)
		},
	], true, converter)
	assert commands.len == 4
	mut rects := []IntRect{}
	for command in commands {
		match command {
			FillRect { rects << command.rect }
			else { assert false }
		}
	}
	// The 1.5 CSS-pixel border has no whole pixel after the grid line and
	// keeps the remaining 1.5 pixels before it. Snapping those CSS edges
	// independently may produce one or two device pixels depending on the
	// fractional grid-line position.
	assert rects.any(it.x == 9 && it.width == 1)
	assert rects.any(it.x == 29 && it.width == 2)
	assert rects.any(it.y == 19 && it.height == 1)
	assert rects.any(it.y == 29 && it.height == 2)
}

fn test_collapsed_table_border_sort_paints_stronger_and_top_left_edges_last() {
	weak := BorderEdgePaintingInfo{
		rect: IntRect{0, 0, 10, 1}
		border_data_with_element_kind: BorderDataWithElementKind{
			border_data: BorderData{Color{1, 0, 0, 255}, .dashed, 1}
			element_kind: .cell
		}
		direction: .horizontal
		row: 1
		column: 1
	}
	strong_later_coordinate := BorderEdgePaintingInfo{
		...weak
		border_data_with_element_kind: BorderDataWithElementKind{
			border_data: BorderData{Color{2, 0, 0, 255}, .solid, 2}
			element_kind: .cell
		}
	}
	strong_top_left := BorderEdgePaintingInfo{
		...strong_later_coordinate
		border_data_with_element_kind: BorderDataWithElementKind{
			border_data: BorderData{Color{3, 0, 0, 255}, .solid, 2}
			element_kind: .cell
		}
		row: 0
		column: 0
	}
	mut edges := [strong_top_left, weak, strong_later_coordinate]
	commands := paint_collected_edges(mut edges)
	assert commands.len == 3
	assert commands[0] is DrawLine
	assert table_test_command_color(commands[0]).r == 1
	assert commands[1] is FillRect
	assert table_test_command_color(commands[1]).r == 2
	assert commands[2] is FillRect
	assert table_test_command_color(commands[2]).r == 3
}

fn test_collapsed_table_border_preserves_dotted_and_dashed_lines() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	for style in [LineStyle.dotted, .dashed] {
		commands := paint_table_borders([
			TableCellPaintData{
				coordinates: TableCellCoordinates{0, 0, 1, 1}
				rect: Rect{10, 10, 20, 10}
				borders: table_test_borders(Color{7, 8, 9, 255}, 2, style)
			},
		], true, converter)
		assert commands.len == 4
		for command in commands {
			match command {
				DrawLine {
					assert command.line_style == style
				}
				else {
					assert false
				}
			}
		}
	}
}

fn test_separate_table_borders_use_snapped_cells_and_hide_empty_cells() {
	red := Color{255, 0, 0, 255}
	cells := [
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 1}
			rect: Rect{10.2, 10.2, 20.1, 10.1}
			borders: table_test_borders(red, 2, .solid)
			empty_cells_hide: true
		},
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 1, 1, 1}
			rect: Rect{30.3, 10.2, 20, 10.1}
			borders: table_test_borders(red, 2, .solid)
			empty_cells_hide: true
			has_children: true
		},
	]
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders(cells, false, converter)
	// paint_all_borders() batches adjacent same-colored solid edges into one path.
	assert commands.len == 1
	for command in commands {
		assert command is FillPath
		match command {
			FillPath {
				assert command.path_bounding_rect.x >= 30
				assert command.winding_rule == .even_odd
			}
			else {}
		}
	}
}

fn test_separate_table_borders_retain_rounded_cell_clip() {
	red := Color{255, 0, 0, 255}
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders([
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 1}
			rect: Rect{10, 20, 30, 15}
			borders: table_test_borders(red, 2, .solid)
			radii: BorderRadiiData{
				top_left: BorderRadiusData{6, 4}
			}
		},
	], false, converter)
	assert commands.len == 1
	assert commands[0] is FillPath
	command := DisplayListCommand(commands[0])
	match command {
		FillPath {
			assert command.path_bounding_rect == IntRect{10, 20, 30, 15}
			assert command.path.segments.any(it.kind == .elliptical_arc_to
				&& it.radii == Size{6, 4})
			assert command.winding_rule == .even_odd
		}
		else {
			assert false
		}
	}
}

fn test_collapsed_table_borders_repaint_radiused_cells_after_collected_edges() {
	red := Color{255, 0, 0, 255}
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders([
		TableCellPaintData{
			coordinates: TableCellCoordinates{0, 0, 1, 1}
			rect: Rect{10, 20, 30, 15}
			borders: table_test_borders(red, 2, .solid)
			radii: BorderRadiiData{
				top_right: BorderRadiusData{5, 5}
			}
		},
	], true, converter)
	// Four collected outside edges, followed by paint_all_borders()'s exact
	// same-color joined path for the radiused cell.
	assert commands.len == 5
	assert commands[4] is FillPath
	command := DisplayListCommand(commands[4])
	match command {
		FillPath {
			assert command.path.segments.any(it.kind == .elliptical_arc_to
				&& it.radii == Size{5, 5})
		}
		else {
			assert false
		}
	}
}
