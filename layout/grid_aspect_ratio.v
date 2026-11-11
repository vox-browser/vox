// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css

fn grid_item_width_from_definite_height(item &Node, item_state &UsedValues, containing_height ?CSSPixels) ?CSSPixels {
 box := item.as_box() or { return none }
 if !box.has_preferred_aspect_ratio() { return none }
 height := item.computed_values().size_value(.height)
 if height.is_auto() || height.is_intrinsic_sizing_constraint()
  || (height.contains_percentage() && containing_height == none) { return none }
 basis := containing_height or { CSSPixels.new(0) }
 resolved := resolve_layout_content_size(item,height,basis,item_state,false) or { return none }
 definite_height := clamp_layout_content_size(item,resolved,basis,item_state,false)
 return intrinsic_content_width_from_aspect_ratio(box,item_state,definite_height)
}

fn grid_item_has_preferred_aspect_ratio(item &Node) bool {
	box := item.as_box() or { return false }
	return box.has_preferred_aspect_ratio()
}

// Ladybird 8660dc09cd3c and 56f9461b3d6d: normal alignment follows block
// sizing for an item with an aspect ratio. An independently definite height
// supplies its automatic width; an automatic height follows that width.
fn grid_normal_alignment_stretches(item &Node, columns bool, percentage_height_basis ?CSSPixels) bool {
	if !grid_item_has_preferred_aspect_ratio(item) { return true }
	if !columns { return false }
	height := item.computed_values().size_value(.height)
	block_size_is_definite := !height.is_auto() && !height.is_intrinsic_sizing_constraint()
		&& (!height.contains_percentage() || percentage_height_basis != none)
	return !block_size_is_definite
}

fn grid_fixed_row_span_size(rows []GridTrack, placement GridItemPlacement, gap CSSPixels) ?CSSPixels {
	if placement.row < 0 || placement.row + placement.row_span > rows.len { return none }
	for row in rows[placement.row..placement.row + placement.row_span] {
		if row.intrinsic || row.flexible || row.flex > 0 || !row.fixed_max { return none }
	}
	return grid_track_range_size(rows, placement.row, placement.row_span, gap)
}
