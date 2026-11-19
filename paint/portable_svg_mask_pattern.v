module main

import cpuraster
import layout
import math
import painting

struct PortableSVGMaskTileBudget {
mut:
	pixels int = portable_svg_group_max_pixels
}

struct PortableSVGMaskPattern {
	pattern   cpuraster.CanvasPattern
	cacheable bool
}

fn portable_svg_mask_pattern_supported(style &painting.SVGPatternPaintStyle) bool {
	tile := style.tile_rect
	if !(tile.width > 0 && tile.height > 0)
		|| ![tile.x, tile.y, tile.width, tile.height]!.all(math.is_finite(it)) {
		return false
	}
	list := style.tile_display_list or { return false }
	// Tiles replay with the mask layer compositor. Bound recursion and reject
	// filters before lowering, since the mask transport omits filter markers.
	return list.operations.len <= 64 && !list.operations.any(it.kind in [.begin_filter, .end_filter]
		|| it.fill_pattern != none || it.stroke_pattern != none)
}

fn (mut app BrowserApp) raster_svg_mask_pattern(style &painting.SVGPatternPaintStyle,
	matrix [6]f32, luminance bool, mut budget PortableSVGMaskTileBudget) ?PortableSVGMaskPattern {
	list := style.tile_display_list?
	tile := style.tile_rect
	pattern_transform := painting_affine_array(style.pattern_transform or { painting.Affine{} })
	device := multiply_paint_transforms([f64(matrix[0]), f64(matrix[1]), f64(matrix[2]),
		f64(matrix[3]), f64(matrix[4]), f64(matrix[5])]!, pattern_transform)
	width := math.ceil(tile.width * math.max(1.0, math.hypot(device[0], device[1])))
	height := math.ceil(tile.height * math.max(1.0, math.hypot(device[2], device[3])))
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
		[sx, 0.0, 0.0, sy, 0.0, 0.0]!)
	mask := layout.PaintClip{mask_operations: operations, mask_luminance: luminance}
	if !portable_svg_content_mask_supported(&mask, true) { return none }
	local := multiply_paint_transforms(pattern_transform, [1 / sx, 0.0, 0.0, 1 / sy, tile.x, tile.y]!)
	matrix32 := [f32(local[0]), f32(local[1]), f32(local[2]), f32(local[3]), f32(local[4]), f32(local[5])]!
	if !matrix32.all(math.is_finite(f64(it))) { return none }
	bounds := painting.IntRect{0, 0, int(width), int(height)}
	budget.pixels -= bounds.width * bounds.height
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	cacheable := app.raster_svg_mask_layers(mut pixels, bounds.width * 4, bounds, &mask,
		0, 0, 1)?
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
