module painting

fn test_fractional_collapsed_table_borders_snap_each_half_edge_at_device_scale() {
	border := BorderDataWithElementKind{
		border_data: BorderData{Color{0, 0, 255, 255}, .solid, 1}
	}
	cells := [TableCellPaintData{
		coordinates: TableCellCoordinates{0, 0, 1, 1}
		rect:        Rect{10.25, 20.25, 20.5, 10.5}
		borders:     BordersDataWithElementKind{border, border, border, border}
	}]
	for scale in [1.0, 2.0] {
		converter := new_device_pixel_converter(scale) or { panic(err) }
		commands := paint_table_borders_with_fractional_shares(cells, true, converter, true)
		assert commands.len == 4
		mut rects := []IntRect{}
		for command in commands {
			match command {
				FillRect { rects << command.rect }
				else {
					assert false
				}
			}
		}
		if scale == 1 {
			assert rects.contains(IntRect{10, 20, 1, 11})
			assert rects.contains(IntRect{30, 20, 1, 11})
			assert rects.contains(IntRect{10, 20, 21, 1})
			assert rects.contains(IntRect{10, 30, 21, 1})
		} else {
			assert rects.contains(IntRect{20, 40, 2, 23})
			assert rects.contains(IntRect{61, 40, 2, 23})
			assert rects.contains(IntRect{20, 40, 43, 2})
			assert rects.contains(IntRect{20, 61, 43, 2})
		}
	}
}

fn test_fractional_collapsed_borders_truncate_odd_layout_unit_halves_before_snapping() {
	border := BorderDataWithElementKind{
		border_data: BorderData{Color{0, 0, 255, 255}, .solid, 1.015625}
	}
	cells := [TableCellPaintData{
		coordinates: TableCellCoordinates{0, 0, 1, 1}
		rect:        Rect{10, 20, 20, 10}
		borders:     BordersDataWithElementKind{border, border, border, border}
	}]
	converter := new_device_pixel_converter(1) or { panic(err) }
	commands := paint_table_borders_with_fractional_shares(cells, true, converter, true)
	assert commands.len == 4
	mut rects := []IntRect{}
	for command in commands {
		match command {
			FillRect { rects << command.rect }
			else {
				assert false
			}
		}
	}
	assert rects.contains(IntRect{10, 20, 1, 11})
	assert rects.contains(IntRect{30, 20, 1, 11})
	assert rects.contains(IntRect{10, 20, 21, 1})
	assert rects.contains(IntRect{10, 30, 21, 1})
}
