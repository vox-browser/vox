module main

import cpuraster
import layout
import math
import painting

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
	return style.shared_tile_info() != none
}

fn svg_pattern_filter_crop(filter &layout.PaintSVGMaskFilter, width int, height int) ?painting.IntRect {
	full := painting.IntRect{0, 0, width, height}
	if rect := filter.bounds {
		if ![rect.x, rect.y, rect.right(), rect.bottom()]!.all(math.is_finite(it)) { return none }
		crop := rect.intersection(painting.Rect{0, 0, f64(width), f64(height)})
		// The native filter uses the source extent when no nonempty
		// bounds overlap the tile.
		if !crop.is_empty() {
			if ![crop.x, crop.y, crop.right(), crop.bottom()]!.all(math.floor(it) == it) { return none }
			return painting.IntRect{int(crop.x), int(crop.y), int(crop.width), int(crop.height)}
		}
		if filter.effect == none { return painting.IntRect{} }
	}
	return full
}

fn clear_svg_pattern_outside_crop(mut layer PortableSVGMaskLayer, width int, crop painting.IntRect) {
	if crop.x == 0 && crop.width == width && crop.y <= layer.rows.top
		&& crop.bottom() >= layer.rows.bottom { return }
	left := crop.x * 4
	right := crop.right() * 4
	bottom := crop.bottom()
	pitch := width * 4
	for y in layer.rows.top .. layer.rows.bottom {
		row := (y - layer.rows.top) * pitch
		unsafe {
			row_pixels := &u8(layer.pixels.data) + row
			if y < crop.y || y >= bottom {
				vmemset(row_pixels, 0, pitch)
			} else {
				vmemset(row_pixels, 0, left)
				vmemset(row_pixels + right, 0, pitch - right)
			}
		}
	}
}

fn apply_svg_pattern_filter(mut layer PortableSVGMaskLayer, width int, height int,
	filter &layout.PaintSVGMaskFilter, retain_color bool) bool {
	crop := svg_pattern_filter_crop(filter, width, height) or { return false }
	effect := filter.effect or {
		clear_svg_pattern_outside_crop(mut layer, width, crop)
		if filter.source_alpha && retain_color {
			// SourceAlpha keeps coverage and supplies black to color or luminance draws.
			for y in math.max(crop.y, layer.rows.top) .. math.min(crop.bottom(), layer.rows.bottom) {
				row := (y - layer.rows.top) * width
				for x in crop.x .. crop.right() {
					pixel := (row + x) * 4
					layer.pixels[pixel] = 0
					layer.pixels[pixel + 1] = 0
					layer.pixels[pixel + 2] = 0
				}
			}
		}
		return true
	}
	fills_clear := effect.fills_clear_pixels()
	// Filter only the retained crop. A filter that gives transparent black
	// coverage needs the crop applied after evaluation.
	if !fills_clear { clear_svg_pattern_outside_crop(mut layer, width, crop) }
	if retain_color {
		applied := match effect {
			painting.SVGSourceColorMatrix {
				cpuraster.apply_canvas_color_matrices_in_place(mut layer.pixels, width,
					layer.rows.height(), effect.stages, effect.linear_rgb)
			}
			painting.SVGSourceColorTable {
				cpuraster.apply_canvas_color_tables_in_place(mut layer.pixels, width,
					layer.rows.height(), effect.stages, effect.linear_rgb)
			}
			painting.SVGSourceColorChain {
				stages := effect.stages.map(cpuraster.CanvasColorStage{it.matrix, it.channels, it.is_table, it.linear_rgb})
				cpuraster.apply_canvas_color_chain_in_place(mut layer.pixels, width,
					layer.rows.height(), stages)
			}
		}
		if !applied { return false }
	}
	if fills_clear { clear_svg_pattern_outside_crop(mut layer, width, crop) }
	return true
}

fn (mut app BrowserApp) raster_svg_mask_pattern(style &painting.SVGPatternPaintStyle,
	matrix [6]f32, luminance bool, parent_space &PortableSVGTileStrokeSpace,
	mut budget PortableSVGMaskTileBudget) ?PortableSVGMaskPattern {
	if budget.depth >= painting.svg_pattern_tile_max_depth { return none }
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
		[sx, 0.0, 0.0, sy, 0.0, 0.0]!, painting.Rect{0, 0, width, height})?
	// A filter can read RGB to compute alpha. Keep the source colors,
	// including nested paint, even when the destination samples alpha alone.
	retain_color := luminance || operations.any(it.filter != unsafe { nil }
		&& it.filter.needs_source_color())
	mask := layout.PaintClip{mask_operations: operations, mask_luminance: retain_color}
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
