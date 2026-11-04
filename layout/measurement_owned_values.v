module layout

import svg

// Shape-generated paths can belong to the producer's scratch arena. Own both
// array levels; a restored consumer also gets its own writable path arrays.
fn own_measurement_svg_path(path svg.Path) svg.Path {
	mut instructions := []svg.PathInstruction{cap: path.instructions.len}
	for instruction in path.instructions {
		instructions << svg.PathInstruction{ ...instruction, data: instruction.data.clone() }
	}
	return svg.Path{ instructions: instructions }
}

// The caller enters document-retained allocations. No cached descendant may
// retain a producer's scratch glyphs, nested line names or inline-end rectangle.
fn append_owned_measurement_values(mut snapshots []RetainedBlockValues,
	node &NodeWithStyle, values &UsedValues) {
	append_retained_block_snapshot(mut snapshots, node, values)
	mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
	snapshot.line_boxes = own_inline_layout_lines(values.line_boxes)
	snapshot.inline_end_static_position_snapshot_ = unsafe { nil }
	snapshot.inline_end_snapshot_arena_ = unsafe { nil }
	if position := values.inline_end_static_position_rect() {
		snapshot.set_inline_end_static_position_rect(position)
	}
	if mut rare := snapshot.rare_ {
		if path := rare.computed_svg_path_ {
			rare.computed_svg_path_ = own_measurement_svg_path(path)
		}
		rare.used_grid_column_line_names = own_grid_line_names(rare.used_grid_column_line_names)
		rare.used_grid_row_line_names = own_grid_line_names(rare.used_grid_row_line_names)
	}
}
