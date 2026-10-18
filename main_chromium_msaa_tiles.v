module main

import layout
import math

// Chromium rasterizes the root layer on the GPU in tiles as wide as the
// viewport. CalculateGpuTileSize() covers the viewport height with four
// tiles, adds one border texel on each side, rounds up to 32 rows and keeps at
// least 256, so a 768-row viewport uses 256-row tiles spaced 254 rows apart.
const chromium_min_gpu_raster_tile_rows = 256

fn chromium_gpu_raster_tile_rows(viewport_device_height int) int {
	quarter := (viewport_device_height + 3) / 4 + 2
	return math.max((quarter + 31) / 32 * 32, chromium_min_gpu_raster_tile_rows)
}

// Graphite multisamples a tile's whole render pass when any draw in it needs
// MSAA: an SVG path, or a draw clipped by two or more rectangles, such as a
// skip-ink underline crossing two glyphs. The tile's other anti-aliased shapes
// then take multisampled coverage too. Returns the indices of those tiles; a
// draw affects every tile whose raster rows, including border texels, it
// touches.
fn chromium_msaa_tiles(commands []layout.PaintCommand, device_scale f64, tile_rows int) []int {
	spacing := tile_rows - 2
	mut tiles := []int{}
	for command in commands {
		bounds := chromium_msaa_trigger_bounds(command) or { continue }
		top := bounds[0] * device_scale
		bottom := bounds[1] * device_scale
		if !(bottom > top) || math.is_nan(top) || math.is_inf(bottom, 0) {
			continue
		}
		// Tile k rasterizes rows [k * spacing, k * spacing + tile_rows).
		first := math.max(0, int(math.ceil((top - f64(tile_rows)) / f64(spacing))))
		last := int(math.floor(math.max(bottom - 1, 0) / f64(spacing)))
		for tile in first .. last + 1 {
			if f64(tile * spacing) < bottom && f64(tile * spacing + tile_rows) > top
				&& tile !in tiles {
				tiles << tile
			}
		}
	}
	tiles.sort()
	return tiles
}

// The document rows covered by a draw that makes Chromium's tile multisampled.
fn chromium_msaa_trigger_bounds(command layout.PaintCommand) ?[]f64 {
	match command.kind {
		'fill_rect' {
			if command.clip_outs.len < 8 {
				return none
			}
			return transformed_row_bounds(command.transform, command.x, command.y,
				command.width, command.height)
		}
		'draw_svg_path' {
			// Chromium paints CSS borders as rectangles and rounded rectangles;
			// only SVG content and other genuine paths take the path renderer.
			if command.force_dark_role == .border {
				return none
			}
			svg_data := command.svg()
			stride := layout.compatibility_clip_path_segment_stride
			if svg_data.path_data.len < stride {
				return none
			}
			mut min_x := math.inf(1)
			mut min_y := math.inf(1)
			mut max_x := math.inf(-1)
			mut max_y := math.inf(-1)
			for index := 0; index + stride <= svg_data.path_data.len; index += stride {
				// Each segment holds its end point; quadratic and cubic curves
				// follow it with one or two control points.
				kind := int(svg_data.path_data[index])
				if kind == 5 {
					continue
				}
				points := match kind {
					2 { 2 }
					3 { 3 }
					else { 1 }
				}
				// An arc can bulge up to its radius beyond its end point.
				bulge := if kind == 4 {
					math.max(math.abs(f64(svg_data.path_data[index + 7])), math.abs(f64(svg_data.path_data[index + 8])))
				} else {
					0.0
				}
				for point := 1; point < 1 + points * 2; point += 2 {
					x := f64(svg_data.path_data[index + point])
					y := f64(svg_data.path_data[index + point + 1])
					min_x = math.min(min_x, x - bulge)
					min_y = math.min(min_y, y - bulge)
					max_x = math.max(max_x, x + bulge)
					max_y = math.max(max_y, y + bulge)
				}
			}
			if !(max_y >= min_y) {
				return none
			}
			outset := math.max(command.stroke_width, 0) / 2 + 1
			matrix := multiply_paint_transforms(command.transform, svg_data.path_transform)
			return transformed_row_bounds(matrix, min_x - outset, min_y - outset,
				max_x - min_x + outset * 2, max_y - min_y + outset * 2)
		}
		else {
			return none
		}
	}
}

fn transformed_row_bounds(transform [6]f64, x f64, y f64, width f64, height f64) []f64 {
	matrix := normalized_paint_transform(transform)
	mut top := math.inf(1)
	mut bottom := math.inf(-1)
	for corner in [[x, y], [x + width, y], [x, y + height], [x + width, y + height]] {
		row := matrix[1] * corner[0] + matrix[3] * corner[1] + matrix[5]
		top = math.min(top, row)
		bottom = math.max(bottom, row)
	}
	return [top, bottom]
}

// Without the native GPU painter, the parts of an anti-aliased rectangle left
// between its clip-outs. A clip without antialiasing covers whole pixels, so
// each clip edge rounds to the nearest one.
fn clipped_out_rect_segments(command layout.PaintCommand) [][]f64 {
	mut clips := [][]f64{}
	for index := 0; index + 3 < command.clip_outs.len; index += 4 {
		clips << [math.round(command.clip_outs[index]), math.round(command.clip_outs[index + 2])]
	}
	clips.sort_with_compare(fn (a &[]f64, b &[]f64) int {
		first := unsafe { a[0] }
		second := unsafe { b[0] }
		return if first < second { -1 } else if first > second { 1 } else { 0 }
	})
	end := command.x + command.width
	mut segments := [][]f64{}
	mut start := command.x
	for clip in clips {
		if clip[0] > start {
			segments << [start, math.min(clip[0], end)]
		}
		start = math.max(start, clip[1])
	}
	if end > start {
		segments << [start, end]
	}
	return segments
}

fn (mut app BrowserApp) set_chromium_msaa_tiles() {
	$if macos {
		scale := C.native_display_device_pixel_ratio()
		tile_rows := chromium_gpu_raster_tile_rows(int(math.ceil(f64(app.viewport_height) * scale)))
		tiles := chromium_msaa_tiles(app.paint_commands, scale, tile_rows)
		tiles_pointer := if tiles.len > 0 { &tiles[0] } else { unsafe { &int(nil) } }
		C.native_set_chromium_raster_scroll_y(app.scroll_y)
		C.native_set_chromium_msaa_tiles(tiles_pointer, tiles.len, tile_rows)
	}
}
