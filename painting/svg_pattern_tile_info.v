module painting

import math

const svg_pattern_tile_max_operations = 64
// Match the retained serialization limit, including the root tile.
pub const svg_pattern_tile_max_depth = 16

pub struct SVGPatternTileInfo {
pub:
	has_images bool
mut:
	operations int
	depth      int
}

// Retain the replay summary with the immutable operation stream.
pub fn SVGPatternDisplayList.from_operations(operations []SVGMaskPaintOperation) &SVGPatternDisplayList {
	return &SVGPatternDisplayList{
		operations: operations
		tile_info: svg_pattern_operations_tile_info(operations, svg_pattern_tile_max_operations, 0)
		tile_info_ready: true
	}
}

pub fn (style &SVGPatternPaintStyle) shared_tile_info() ?SVGPatternTileInfo {
	return svg_pattern_style_tile_info(style, svg_pattern_tile_max_operations, 0)
}

fn svg_pattern_style_tile_info(style &SVGPatternPaintStyle, limit int, ancestors int) ?SVGPatternTileInfo {
	tile := style.tile_rect
	if ancestors >= svg_pattern_tile_max_depth || !(tile.width > 0 && tile.height > 0)
		|| ![tile.x, tile.y, tile.width, tile.height]!.all(math.is_finite(it)) { return none }
	list := style.tile_display_list?
	if list.tile_info_ready {
		info := list.tile_info?
		if info.operations > limit || info.depth > svg_pattern_tile_max_depth - ancestors { return none }
		return info
	}
	return svg_pattern_operations_tile_info(list.operations, limit, ancestors)
}

fn svg_pattern_operations_tile_info(operations []SVGMaskPaintOperation, limit int,
	ancestors int) ?SVGPatternTileInfo {
	if operations.len > limit { return none }
	mut count := operations.len
	mut depth := 1
	mut has_images := false
	for index in 0 .. operations.len {
		operation := &operations[index]
		if operation.kind == .begin_filter {
			filter := operation.filter?
			if filter.opacity_filter_amount() == none && !filter.supports_source_color_filter() {
				return none
			}
		}
		has_images = has_images || (operation.kind == .image && operation.opacity != 0)
		if pattern := operation.fill_pattern {
			child := svg_pattern_style_tile_info(pattern, limit - count, ancestors + 1)?
			count += child.operations
			depth = math.max(depth, child.depth + 1)
			has_images = has_images || child.has_images
		}
		if pattern := operation.stroke_pattern {
			child := svg_pattern_style_tile_info(pattern, limit - count, ancestors + 1)?
			count += child.operations
			depth = math.max(depth, child.depth + 1)
			has_images = has_images || child.has_images
		}
	}
	return SVGPatternTileInfo{operations: count, depth: depth, has_images: has_images}
}
