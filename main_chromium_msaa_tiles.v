module main

import layout
import math
import painting

fn C.native_set_chromium_raster_layer_size(f64, f64)

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
struct ChromiumMSAATrigger {
	command_index int
	top           f64
	bottom        f64
	left          f64
	right         f64
}

struct ChromiumMSAAViewport {
	scroll_y f64
	height   f64
	fringe   f64
}

fn chromium_msaa_triggers(commands []layout.PaintCommand) []ChromiumMSAATrigger {
	return chromium_msaa_triggers_for_viewport(commands, none)
}

fn chromium_msaa_triggers_for_viewport(commands []layout.PaintCommand, viewport ?ChromiumMSAAViewport) []ChromiumMSAATrigger {
	mut triggers := []ChromiumMSAATrigger{}
	for index, command in commands {
		if rect := chromium_msaa_trigger_rect(command) {
			triggers << ChromiumMSAATrigger{index, rect.y, rect.y + rect.height, rect.x, rect.x + rect.width}
		} else if command.kind == 'draw_background_image' {
			if visible := viewport {
				if !chromium_svg_background_intersects_raster_viewport(command, visible) {
					continue
				}
			}
			for rect in chromium_svg_background_msaa_rects(command) {
				triggers << ChromiumMSAATrigger{index, rect.y, rect.y + rect.height, rect.x, rect.x + rect.width}
			}
		} else if command.kind == 'paint_nested_display_list' {
			paintable := command.nested_viewport_paintable or { continue }
			converter := painting.new_device_pixel_converter(1) or { continue }
			result := paintable.paint(converter) or { continue }
			mut nested := []layout.PaintCommand{cap: command.nested_viewport_commands.len}
			for path in command.nested_viewport_commands {
				nested << layout.paint_command_for_nested_viewport(path, command.transform,
					painting.IntPoint{result.nested_rect.x, result.nested_rect.y}, command.opacity)
			}
			for trigger in chromium_msaa_triggers_for_viewport(nested, viewport) {
				triggers << ChromiumMSAATrigger{index, trigger.top, trigger.bottom, trigger.left, trigger.right}
			}
		}
	}
	return triggers
}

fn chromium_msaa_tiles_for_triggers(triggers []ChromiumMSAATrigger, origin_y f64,
	device_scale f64, tile_rows int) []int {
	spacing := tile_rows - 2
	mut tiles := []int{}
	for trigger in triggers {
		top := (trigger.top - origin_y) * device_scale
		bottom := (trigger.bottom - origin_y) * device_scale
		if !(bottom > top) || math.is_nan(top) || math.is_inf(bottom, 0) {
			continue
		}
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

fn chromium_msaa_tiles(commands []layout.PaintCommand, device_scale f64, tile_rows int) []int {
	return chromium_msaa_tiles_for_triggers(chromium_msaa_triggers(commands), 0, device_scale,
		tile_rows)
}

// The document rows covered by a draw that makes Chromium's tile multisampled.
fn chromium_msaa_trigger_bounds(command layout.PaintCommand) ?[]f64 {
	rect := chromium_msaa_trigger_rect(command) or { return none }
	return [rect.y, rect.y + rect.height]
}

fn chromium_msaa_trigger_rect(command layout.PaintCommand) ?layout.LayoutRect {
	match command.kind {
		'fill_rect' {
			if command.clip_outs.len < 8 {
				return none
			}
			return transformed_raster_bounds(command.transform, command.x, command.y, command.width,
				command.height)
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
				// Curves hold an end point followed by their controls. Explicit
				// ellipses instead hold both LTRB corners in these coordinate slots.
				kind := int(svg_data.path_data[index])
				if kind == 5 {
					continue
				}
				points := match kind {
					2, 6 { 2 }
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
			return transformed_raster_bounds(matrix, min_x - outset, min_y - outset, max_x - min_x +
				outset * 2, max_y - min_y + outset * 2)
		}
		else {
			return none
		}
	}
}

fn transformed_row_bounds(transform [6]f64, x f64, y f64, width f64, height f64) []f64 {
	rect := transformed_raster_bounds(transform, x, y, width, height)
	return [rect.y, rect.y + rect.height]
}

fn transformed_raster_bounds(transform [6]f64, x f64, y f64, width f64, height f64) layout.LayoutRect {
	matrix := normalized_paint_transform(transform)
	mut left := math.inf(1)
	mut top := math.inf(1)
	mut right := math.inf(-1)
	mut bottom := math.inf(-1)
	for corner in [[x, y], [x + width, y], [x, y + height], [x + width, y + height]] {
		column := matrix[0] * corner[0] + matrix[2] * corner[1] + matrix[4]
		row := matrix[1] * corner[0] + matrix[3] * corner[1] + matrix[5]
		left = math.min(left, column)
		right = math.max(right, column)
		top = math.min(top, row)
		bottom = math.max(bottom, row)
	}
	return layout.LayoutRect{ x: left, y: top, width: right - left, height: bottom - top }
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
		return if first < second {
			-1
		} else if first > second {
			1
		} else {
			0
		}
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

// Classify paths in their owning layer. A path in the document's root tile
// does not force an overlapping scroll button's independent tile to use MSAA.
fn chromium_msaa_layer_tiles(commands []layout.PaintCommand, layer layout.ChromiumRasterLayer,
	device_scale f64, tile_rows int, root bool) []int {
	triggers := chromium_msaa_triggers(commands).filter(it.command_index in layer.command_indices)
	origin_y := if root { 0.0 } else { math.floor(layer.bounds.y * device_scale) / device_scale }
	return chromium_msaa_tiles_for_triggers(triggers, origin_y, device_scale, tile_rows)
}

fn (mut app BrowserApp) set_chromium_msaa_tiles() {
	$if macos {
		scale := C.native_display_device_pixel_ratio()
		tile_rows := chromium_gpu_raster_tile_rows(int(math.ceil(f64(app.viewport_height) * scale)))
		app.chromium_raster_tiles = [][]int{cap: app.chromium_raster_plan.layers.len}
		app.chromium_raster_grids = []ChromiumRasterGrid{cap: app.chromium_raster_plan.layers.len}
		triggers := chromium_msaa_triggers_for_viewport(app.paint_commands, ChromiumMSAAViewport{
			scroll_y: app.scroll_y
			height:   f64(app.viewport_height)
			fringe:   f64(tile_rows) / scale
		})
		legacy_tiles := chromium_msaa_tiles_for_triggers(triggers, 0, scale, tile_rows)
		for index, layer in app.chromium_raster_plan.layers {
			selected := triggers.filter(it.command_index < app.chromium_raster_plan.command_layers.len
				&& app.chromium_raster_plan.command_layers[it.command_index] == index)
			root := index == 0
			content_width := if root {
				math.max(f64(app.viewport_width), layer.bounds.x + layer.bounds.width)
			} else {
				layer.bounds.width
			}
			content_height := if root {
				math.max(f64(app.viewport_height), layer.bounds.y + layer.bounds.height)
			} else {
				layer.bounds.height
			}
			app.chromium_raster_grids << if layer.legacy_raster {
				ChromiumRasterGrid{}
			} else {
				chromium_raster_grid(selected, app.viewport_width, app.viewport_height, content_width, content_height,
					if root { 0.0 } else { math.floor(layer.bounds.x * scale) / scale },
					if root { -app.scroll_y } else { math.floor(layer.bounds.y * scale) / scale }, scale)
			}
			if layer.legacy_raster {
				app.chromium_raster_tiles << legacy_tiles
			} else {
				origin_y := if index == 0 {
					0.0
				} else {
					math.floor(layer.bounds.y * scale) / scale
				}
				app.chromium_raster_tiles << chromium_msaa_tiles_for_triggers(selected, origin_y,
					scale, tile_rows)
			}
		}
		C.native_set_chromium_raster_scroll_y(app.scroll_y)
		C.native_set_chromium_raster_layer(0, 0, 1)
		C.native_set_chromium_msaa_tiles(unsafe { nil }, 0, tile_rows)
	}
}

fn (mut app BrowserApp) select_chromium_raster_layer(index int) {
	$if macos {
		if index < 0 || index >= app.chromium_raster_plan.layers.len
			|| index >= app.chromium_raster_tiles.len {
			return
		}
		layer := app.chromium_raster_plan.layers[index]
		scale := C.native_display_device_pixel_ratio()
		x := if index == 0 || layer.legacy_raster {
			0.0
		} else {
			math.floor(layer.bounds.x * scale) / scale
		}
		y := if index == 0 || layer.legacy_raster {
			0.0
		} else {
			math.floor(layer.bounds.y * scale) / scale
		}
		C.native_set_chromium_raster_layer(x, y, int(index == 0 || layer.legacy_raster))
		C.native_set_chromium_raster_layer_size(layer.bounds.width, layer.bounds.height)
		tiles := app.chromium_raster_tiles[index]
		pointer := if tiles.len > 0 { &tiles[0] } else { unsafe { &int(nil) } }
		rows := chromium_gpu_raster_tile_rows(int(math.ceil(f64(app.viewport_height) * scale)))
		C.native_set_chromium_msaa_tiles(pointer, tiles.len, rows)
		if index < app.chromium_raster_grids.len {
			grid := app.chromium_raster_grids[index]
			if grid.columns > 0 {
				cell_pointer := if grid.cells.len > 0 {
					&grid.cells[0]
				} else {
					unsafe { &int(nil) }
				}
				C.native_set_chromium_msaa_grid(cell_pointer, grid.cells.len, grid.tile_width, grid.tile_height, grid.columns)
			}
		}
	}
}
