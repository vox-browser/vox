module main

import cpuraster
import layout
import math
import painting

struct PortableSVGMaskTileBudget {
mut:
	pixels int = portable_svg_group_max_pixels
	depth  int
	last   PortableSVGMaskTileReuse
}

// The caller owns the style throughout replay. Use its address only for identity.
struct PortableSVGMaskTileReuse {
	style      voidptr
	pattern    cpuraster.CanvasPattern
	metric     PortableSVGTileStrokeSpace
	pixel_cost int
	depth      int
	luminance  bool
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

fn apply_svg_pattern_color_filter(mut layer PortableSVGMaskLayer, pitch int, clip cpuraster.IRect,
	effect painting.SVGSourceColorFilter) bool {
	start := clip.top * pitch + clip.left * 4
	mut pixels := layer.pixels[start..]
	width := clip.right - clip.left
	height := clip.bottom - clip.top
	return match effect {
		painting.SVGSourceColorMatrix {
			cpuraster.apply_canvas_color_matrices_in_place(mut pixels, width, height,
				effect.stages, effect.linear_rgb, pitch: pitch)
		}
		painting.SVGSourceColorTable {
			cpuraster.apply_canvas_color_tables_in_place(mut pixels, width, height,
				effect.stages, effect.linear_rgb, pitch: pitch)
		}
		painting.SVGSourceColorChain {
			stages := effect.stages.map(cpuraster.CanvasColorStage{it.matrix, it.channels, it.is_table, it.linear_rgb})
			cpuraster.apply_canvas_color_chain_in_place(mut pixels, width, height, stages,
				pitch: pitch)
		}
	}
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
	metric := if style.has_non_scaling_stroke {
		// Child samples land in the parent bitmap. Stroke widths use the
		// physical device metric reached through the parent's linear map.
		device := if parent_space == unsafe { nil } {
			raster
		} else {
			parent := parent_space.to_device
			multiply_paint_transforms([f64(parent[0]), f64(parent[1]), f64(parent[2]),
				f64(parent[3]), 0.0, 0.0]!, raster)
		}
		portable_svg_tile_stroke_space(device, sx, sy)?
	} else {
		PortableSVGTileStrokeSpace{}
	}
	bounds := painting.IntRect{0, 0, int(width), int(height)}
	if budget.last.style == voidptr(style)
		&& budget.last.pattern.width == bounds.width && budget.last.pattern.height == bounds.height
		&& budget.last.depth == budget.depth && budget.last.luminance == luminance
		&& budget.last.metric == metric {
		// Charge the original subtree cost, including child tiles.
		if budget.last.pixel_cost > budget.pixels { return none }
		budget.pixels -= budget.last.pixel_cost
		if portable_svg_raster_diagnostics {
			eprintln('VOX_SVG_TILE_RASTER reuse=hit depth=${budget.depth} tile=${bounds.width}x${bounds.height}')
		}
		return PortableSVGMaskPattern{pattern: budget.last.pattern, cacheable: true}
	}
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
	stroke_space := if style.has_non_scaling_stroke {
		&metric
	} else {
		unsafe { nil }
	}
	pixels_before := budget.pixels
	budget.pixels -= bounds.width * bounds.height
	budget.depth++
	if portable_svg_raster_diagnostics {
		eprintln('VOX_SVG_TILE_RASTER reuse=miss depth=${budget.depth - 1} tile=${bounds.width}x${bounds.height}')
	}
	mut pixels := []u8{len: bounds.width * bounds.height * 4}
	result := app.raster_svg_mask_layers(mut pixels, bounds.width * 4, bounds, &mask,
		0, 0, 1, stroke_space, mut budget)
	budget.depth--
	cacheable := result?
	pattern := cpuraster.CanvasPattern{
		pixels: pixels
		width: bounds.width
		height: bounds.height
		pitch: bounds.width * 4
		premultiplied: true
		nearest: true
		transform: matrix32
	}
	if cacheable && !disable_portable_svg_raster_cache {
		if info := style.shared_tile_info() {
			if !info.has_images {
				budget.last = PortableSVGMaskTileReuse{
					style: voidptr(style)
					pattern: pattern
					metric: metric
					pixel_cost: pixels_before - budget.pixels
					depth: budget.depth
					luminance: luminance
				}
			}
		}
	}
	return PortableSVGMaskPattern{pattern: pattern, cacheable: cacheable}
}
