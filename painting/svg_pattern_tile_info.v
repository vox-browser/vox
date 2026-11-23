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

// Match the shared bitmap compositor's f32 opacity byte for valid opacities.
pub fn svg_pattern_opacity_is_transparent(opacity f64) bool {
	return opacity >= 0 && f32(opacity) * f32(255) < 1
}

pub fn svg_pattern_scope_end(operations []SVGMaskPaintOperation, start int) ?int {
	if start < 0 || start >= operations.len { return none }
	mut ends := [svg_pattern_tile_max_operations]SVGMaskPaintOperationKind{}
	ends[0] = match operations[start].kind {
		.begin_opacity { .end_opacity }
		.begin_filter { .end_filter }
		else { return none }
	}
	mut depth := 1
	for index in start + 1 .. operations.len {
		kind := operations[index].kind
		match kind {
			.begin_opacity, .begin_filter {
				if depth == ends.len { return none }
				ends[depth] = if kind == .begin_opacity { .end_opacity } else { .end_filter }
				depth++
			}
			.end_opacity, .end_filter {
				depth--
				if kind != ends[depth] { return none }
				if depth == 0 { return index }
			}
			else {}
		}
	}
	return none
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
	for index := 0; index < operations.len; index++ {
		operation := &operations[index]
		mut skip_scope := operation.kind == .begin_opacity
			&& svg_pattern_opacity_is_transparent(operation.opacity)
		if operation.kind == .begin_filter {
			filter := operation.filter?
			if opacity := filter.opacity_filter_amount() {
				skip_scope = svg_pattern_opacity_is_transparent(opacity)
			} else if filter.source_pattern_offset() == none
				&& !filter.supports_source_color_filter() {
				return none
			}
		}
		if skip_scope {
			index = svg_pattern_scope_end(operations, index)?
			continue
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
