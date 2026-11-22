module main

import cpuraster
import layout
import math
import painting

const portable_svg_mask_pattern_max_operations = 64
// Match the retained SVG pattern serialization limit. All descendants
// still draw from the same operation and pixel budgets.
const portable_svg_mask_pattern_max_depth = 16

struct PortableSVGMaskTileBudget {
mut:
	pixels int = portable_svg_group_max_pixels
	depth  int
}

struct PortableSVGMaskPattern {
	pattern   cpuraster.CanvasPattern
	cacheable bool
}

struct PortableSVGTileStrokeSpace {
	to_device [6]f32
	to_tile   [6]f32
}

struct PortableSVGMaskPatternInfo {
	operations int
	has_images bool
}

fn portable_svg_tile_stroke_space(device [6]f64, sx f64, sy f64) ?PortableSVGTileStrokeSpace {
	// Only the linear part matters. Every copy of the tile uses the same
	// stroke metric, regardless of its placement or the current scroll.
	transform := painting.Affine{
		a: device[0] / sx
		b: device[1] / sx
		c: device[2] / sy
		d: device[3] / sy
	}
	inverse := transform.inverse()?
	to_device := [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d), 0, 0]!
	to_tile := [f32(inverse.a), f32(inverse.b), f32(inverse.c), f32(inverse.d), 0, 0]!
	if !to_device.all(math.is_finite(f64(it))) || !to_tile.all(math.is_finite(f64(it))) {
		return none
	}
	return PortableSVGTileStrokeSpace{to_device, to_tile}
}

fn portable_svg_mask_pattern_supported(style &painting.SVGPatternPaintStyle) bool {
	portable_svg_mask_pattern_info(style, portable_svg_mask_pattern_max_operations, 0) or {
		return false
	}
	return true
}

fn portable_svg_mask_pattern_info(style &painting.SVGPatternPaintStyle, limit int, depth int) ?PortableSVGMaskPatternInfo {
	tile := style.tile_rect
	if depth >= portable_svg_mask_pattern_max_depth || !(tile.width > 0 && tile.height > 0)
		|| ![tile.x, tile.y, tile.width, tile.height]!.all(math.is_finite(it)) {
		return none
	}
	list := style.tile_display_list?
	mut count := list.operations.len
	if count > limit { return none }
	mut has_images := false
	for index in 0 .. list.operations.len {
		operation := &list.operations[index]
		if operation.kind == .begin_filter {
			filter := operation.filter?
			if filter.opacity_filter_amount() == none {
				filter.source_color_matrix()?
			}
		}
		has_images = has_images || (operation.kind == .image && operation.opacity != 0)
		if pattern := operation.fill_pattern {
			info := portable_svg_mask_pattern_info(pattern, limit - count, depth + 1)?
			count += info.operations
			has_images = has_images || info.has_images
		}
		if pattern := operation.stroke_pattern {
			info := portable_svg_mask_pattern_info(pattern, limit - count, depth + 1)?
			count += info.operations
			has_images = has_images || info.has_images
		}
	}
	return PortableSVGMaskPatternInfo{count, has_images}
}

fn apply_svg_pattern_color_matrix(mut layer PortableSVGMaskLayer, width int, height int,
	filter &layout.PaintSVGMaskColorMatrix, luminance bool) bool {
	if rect := filter.bounds {
		if ![rect.x, rect.y, rect.right(), rect.bottom()]!.all(math.is_finite(it)) { return false }
		crop := rect.intersection(painting.Rect{0, 0, f64(width), f64(height)})
		// The native filter uses the source extent when no nonempty
		// bounds overlap the tile.
		if !crop.is_empty() {
			if ![crop.x, crop.y, crop.right(), crop.bottom()]!.all(math.floor(it) == it) { return false }
			left := int(crop.x) * 4
			right := int(crop.right()) * 4
			top := int(crop.y)
			bottom := int(crop.bottom())
			pitch := width * 4
			for y in layer.rows.top .. layer.rows.bottom {
				row := (y - layer.rows.top) * pitch
				unsafe {
					row_pixels := &u8(layer.pixels.data) + row
					if y < top || y >= bottom {
						vmemset(row_pixels, 0, pitch)
					} else {
						vmemset(row_pixels, 0, left)
						vmemset(row_pixels + right, 0, pitch - right)
					}
				}
			}
		}
	}
	return !luminance || cpuraster.apply_canvas_color_matrix_in_place(mut layer.pixels, width,
		layer.rows.height(), cpuraster.MatrixColorFilter{matrix: filter.matrix.values, clamp: true},
		filter.matrix.linear_rgb)
}

fn (mut app BrowserApp) raster_svg_mask_pattern(style &painting.SVGPatternPaintStyle,
	matrix [6]f32, luminance bool, parent_space &PortableSVGTileStrokeSpace,
	mut budget PortableSVGMaskTileBudget) ?PortableSVGMaskPattern {
	if budget.depth >= portable_svg_mask_pattern_max_depth { return none }
	list := style.tile_display_list?
	tile := style.tile_rect
	pattern_transform := painting_affine_array(style.pattern_transform or { painting.Affine{} })
	raster := multiply_paint_transforms([f64(matrix[0]), f64(matrix[1]), f64(matrix[2]),
		f64(matrix[3]), f64(matrix[4]), f64(matrix[5])]!, pattern_transform)
	width := math.ceil(tile.width * math.max(1.0, math.hypot(raster[0], raster[1])))
	height := math.ceil(tile.height * math.max(1.0, math.hypot(raster[2], raster[3])))
	if !(width > 0 && width <= 8191 && height > 0 && height <= 8191
		&& width * height <= f64(budget.pixels)) {
		return none
	}
	sx := width / tile.width
	sy := height / tile.height
	if !math.is_finite(f64(f32(sx))) || !math.is_finite(f64(f32(sy))) { return none }
	// Tile operations are already normalized into the cell's coordinate
	// system. The shader maps the raster back to the exact SVG cell period.
	operations := layout.compatibility_lower_svg_mask_operations(list.operations,
		[sx, 0.0, 0.0, sy, 0.0, 0.0]!, true)
	mask := layout.PaintClip{mask_operations: operations, mask_luminance: luminance}
	if !portable_svg_content_mask_supported(&mask, true) { return none }
	local := multiply_paint_transforms(pattern_transform, [1 / sx, 0.0, 0.0, 1 / sy, tile.x, tile.y]!)
	matrix32 := [f32(local[0]), f32(local[1]), f32(local[2]), f32(local[3]), f32(local[4]), f32(local[5])]!
	if !matrix32.all(math.is_finite(f64(it))) { return none }
	bounds := painting.IntRect{0, 0, int(width), int(height)}
	stroke_space := if style.has_non_scaling_stroke {
		// Child samples land in the parent bitmap. Stroke widths use the
		// physical device metric reached through the parent's linear map.
		device := if parent_space == unsafe { nil } {
			raster
		} else {
			parent := parent_space.to_device
			multiply_paint_transforms([f64(parent[0]), f64(parent[1]), f64(parent[2]),
				f64(parent[3]), 0.0, 0.0]!, raster)
		}
		space := portable_svg_tile_stroke_space(device, sx, sy)?
		&PortableSVGTileStrokeSpace{...space}
	} else {
		unsafe { nil }
	}
	budget.pixels -= bounds.width * bounds.height
	budget.depth++
	defer { budget.depth-- }
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	cacheable := app.raster_svg_mask_layers(mut pixels, bounds.width * 4, bounds, &mask,
		0, 0, 1, stroke_space, mut budget)?
	return PortableSVGMaskPattern{
		pattern: cpuraster.CanvasPattern{
			pixels: pixels
			width: bounds.width
			height: bounds.height
			pitch: bounds.width * 4
			premultiplied: true
			nearest: true
			transform: matrix32
		}
		cacheable: cacheable
	}
}
