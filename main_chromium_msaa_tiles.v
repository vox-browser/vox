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
// MSAA: an SVG path, a CSS border with diagonal corner clips, or a draw clipped
// by two or more rectangles, such as a skip-ink underline crossing two glyphs.
// The tile's other anti-aliased shapes then take multisampled coverage too.
// Returns the indices of those tiles; a draw affects every tile whose raster
// rows, including border texels, it touches.
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
	append_chromium_msaa_triggers(commands, viewport, mut triggers)
	return triggers
}

fn append_chromium_msaa_triggers(commands []layout.PaintCommand,
	viewport ?ChromiumMSAAViewport, mut triggers []ChromiumMSAATrigger) {
	for index in 0 .. commands.len {
		append_chromium_msaa_trigger(commands[index], index, viewport, mut triggers)
	}
}

fn append_chromium_msaa_trigger(command layout.PaintCommand, index int,
	viewport ?ChromiumMSAAViewport, mut triggers []ChromiumMSAATrigger) {
	if rect := chromium_msaa_trigger_rect(command) {
		triggers << ChromiumMSAATrigger{index, rect.y, rect.y + rect.height, rect.x, rect.x + rect.width}
	} else if command.kind == 'draw_background_image' {
		if visible := viewport {
			if !chromium_svg_background_intersects_raster_viewport(command, visible) { return }
		}
		append_chromium_svg_background_msaa_triggers(command, index, mut triggers)
	} else if command.kind == 'paint_nested_display_list' {
		paintable := command.nested_viewport_paintable or { return }
		converter := painting.new_device_pixel_converter(1) or { return }
		result := paintable.paint(converter) or { return }
		for path in command.nested_viewport_commands {
			transformed := layout.paint_command_for_nested_viewport(path, command.transform,
				painting.IntPoint{result.nested_rect.x, result.nested_rect.y}, command.opacity)
			append_chromium_msaa_trigger(transformed, index, viewport, mut triggers)
		}
	}
}

fn chromium_msaa_tiles_for_triggers(triggers []ChromiumMSAATrigger, origin_y f64,
	device_scale f64, tile_rows int) []int {
	mut tiles := []i32{}
	chromium_msaa_tiles_for_triggers_into(triggers, origin_y, device_scale, tile_rows, mut tiles)
	return tiles.map(int(it))
}

fn chromium_msaa_tiles_for_triggers_into(triggers []ChromiumMSAATrigger, origin_y f64,
	device_scale f64, tile_rows int, mut tiles []i32) {
	spacing := tile_rows - 2
	tiles.clear()
	for trigger in triggers {
		top := (trigger.top - origin_y) * device_scale
		bottom := (trigger.bottom - origin_y) * device_scale
		if !(bottom > top) || math.is_nan(top) || math.is_inf(bottom, 0) {
			continue
		}
		first := math.max(0, int(math.ceil((top - f64(tile_rows)) / f64(spacing))))
		last := int(math.floor(math.max(bottom - 1, 0) / f64(spacing)))
		for tile in first .. last + 1 {
			if f64(tile * spacing) >= bottom || f64(tile * spacing + tile_rows) <= top { continue }
			// Keep the vector sorted while inserting unique indices. Both V's
			// i32 sort and comparator sort reserve a fresh merge buffer.
			mut position := 0
			for position < tiles.len && tiles[position] < tile { position++ }
			if position == tiles.len {
				tiles << i32(tile)
			} else if tiles[position] != tile {
				tiles.insert(position, i32(tile))
			}
		}
	}
}

$if test {
	fn chromium_msaa_tiles(commands []layout.PaintCommand, device_scale f64, tile_rows int) []int {
		return chromium_msaa_tiles_for_triggers(chromium_msaa_triggers(commands), 0, device_scale,
			tile_rows)
	}
}

// The document rows covered by a draw that makes Chromium's tile multisampled.
$if test {
	fn chromium_msaa_trigger_bounds(command layout.PaintCommand) ?[]f64 {
		rect := chromium_msaa_trigger_rect(command) or { return none }
		return [rect.y, rect.y + rect.height]
	}
}

fn chromium_msaa_trigger_rect(command layout.PaintCommand) ?layout.LayoutRect {
	match command.kind {
		'paint_rounded_border_top', 'paint_rounded_border_right', 'paint_rounded_border_bottom', 'paint_rounded_border_left' {
			// A single rounded side is filled through intersecting outer and
			// inner clips (and corner miters), requiring a multisampled pass.
			return transformed_raster_bounds(command.transform, command.x, command.y,
				command.width, command.height)
		}
		'fill_rect' {
			if command.clip_outs.len < 8 {
				return none
			}
			return transformed_raster_bounds(command.transform, command.x, command.y, command.width,
				command.height)
		}
		'draw_svg_path' {
			// Uniform CSS borders use rectangles. Differently colored sides
			// also need diagonal corner clips, which take the path renderer.
			if command.force_dark_role == .border && !chromium_border_has_diagonal_path(command) {
				return none
			}
			// Read the payload directly: calling an accessor on this by-value
			// command makes current V move the command to the heap on every call.
			if command.svg_data == unsafe { nil } {
				return none
			}
			svg_data := command.svg_data
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

fn chromium_border_has_diagonal_path(command layout.PaintCommand) bool {
	if command.svg_data == unsafe { nil } { return false }
	data := command.svg_data.path_data
	stride := layout.compatibility_clip_path_segment_stride
	mut x := f32(0)
	mut y := f32(0)
	mut start_x := f32(0)
	mut start_y := f32(0)
	mut has_point := false
	for index := 0; index + stride <= data.len; index += stride {
		kind := int(data[index])
		if kind == 5 {
			if has_point && x != start_x && y != start_y { return true }
			x = start_x
			y = start_y
			continue
		}
		if kind > 1 { return true }
		next_x := data[index + 1]
		next_y := data[index + 2]
		if kind == 0 {
			start_x = next_x
			start_y = next_y
		} else if has_point && next_x != x && next_y != y {
			return true
		}
		x = next_x
		y = next_y
		has_point = true
	}
	return false
}

fn transformed_raster_bounds(transform [6]f64, x f64, y f64, width f64, height f64) layout.LayoutRect {
	matrix := normalized_paint_transform(transform)
	mut left := math.inf(1)
	mut top := math.inf(1)
	mut right := math.inf(-1)
	mut bottom := math.inf(-1)
	// The four corners, without allocating a list of them for every command.
	for corner in 0 .. 4 {
		corner_x := if corner & 1 == 0 { x } else { x + width }
		corner_y := if corner < 2 { y } else { y + height }
		column := matrix[0] * corner_x + matrix[2] * corner_y + matrix[4]
		row := matrix[1] * corner_x + matrix[3] * corner_y + matrix[5]
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
$if test {
	fn chromium_msaa_layer_tiles(commands []layout.PaintCommand, layer layout.ChromiumRasterLayer,
		device_scale f64, tile_rows int, root bool) []int {
		triggers := chromium_msaa_triggers(commands).filter(it.command_index in layer.command_indices)
		origin_y := if root { 0.0 } else { math.floor(layer.bounds.y * device_scale) / device_scale }
		return chromium_msaa_tiles_for_triggers(triggers, origin_y, device_scale, tile_rows)
	}
}

// The triggers of each raster layer, in paint order. One pass: filtering
// them for every layer reserved room for all of them each time.
$if test {
	fn chromium_msaa_triggers_by_layer(triggers []ChromiumMSAATrigger, plan layout.ChromiumRasterLayerPlan) [][]ChromiumMSAATrigger {
		mut by_layer := [][]ChromiumMSAATrigger{len: plan.layers.len}
		for trigger in triggers {
			if trigger.command_index < plan.command_layers.len {
				layer := plan.command_layers[trigger.command_index]
				if layer >= 0 && layer < by_layer.len {
					by_layer[layer] << trigger
				}
			}
		}
		return by_layer
	}
}

// Each layer keeps its own vectors, including while temporarily inactive.
// Native setters copy their inputs before returning; the next preparation is
// the only writer of these shell-owned buffers.
struct ChromiumMSAAStorage {
mut:
	triggers []ChromiumMSAATrigger
	by_layer [][]ChromiumMSAATrigger
	legacy_tiles []i32
	tiles [][]i32
	grids []ChromiumRasterGrid
}

fn (mut storage ChromiumMSAAStorage) update(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, viewport_width int, viewport_height int,
	scroll_y f64, scale f64) {
	storage.update_for_device_viewport(commands, plan, viewport_width, viewport_height,
		viewport_width, viewport_height, scroll_y, scale)
}

fn (mut storage ChromiumMSAAStorage) update_for_device_viewport(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, viewport_width int, viewport_height int,
	device_viewport_width int, device_viewport_height int, scroll_y f64, scale f64) {
	tile_rows := chromium_gpu_raster_tile_rows(int(math.ceil(f64(viewport_height) * scale)))
	storage.triggers.clear()
	append_chromium_msaa_triggers(commands, ChromiumMSAAViewport{
		scroll_y: scroll_y
		height: f64(viewport_height)
		fringe: f64(tile_rows) / scale
	}, mut storage.triggers)
	chromium_msaa_tiles_for_triggers_into(storage.triggers, 0, scale, tile_rows, mut storage.legacy_tiles)
	for storage.by_layer.len < plan.layers.len {
		storage.by_layer << []ChromiumMSAATrigger{}
		storage.tiles << []i32{}
		storage.grids << ChromiumRasterGrid{}
	}
	for index in 0 .. storage.by_layer.len { storage.by_layer[index].clear() }
	for trigger in storage.triggers {
		if trigger.command_index >= 0 && trigger.command_index < plan.command_layers.len {
			layer := plan.command_layers[trigger.command_index]
			if layer >= 0 && layer < plan.layers.len { storage.by_layer[layer] << trigger }
		}
	}
	for index, layer in plan.layers {
		selected := storage.by_layer[index]
		root := index == 0
		if layer.legacy_raster {
			storage.grids[index].columns = 0
			storage.tiles[index].clear()
			storage.tiles[index] << storage.legacy_tiles
		} else {
			content_width := if root { math.max(f64(viewport_width), layer.bounds.x + layer.bounds.width) } else { layer.bounds.width }
			content_height := if root { math.max(f64(viewport_height), layer.bounds.y + layer.bounds.height) } else { layer.bounds.height }
			update_chromium_raster_grid(selected, device_viewport_width, device_viewport_height, content_width, content_height,
				if root { 0.0 } else { math.floor(layer.bounds.x * scale) / scale },
				if root { -scroll_y } else { math.floor(layer.bounds.y * scale) / scale }, scale,
				mut storage.grids[index])
			origin_y := if root { 0.0 } else { math.floor(layer.bounds.y * scale) / scale }
			chromium_msaa_tiles_for_triggers_into(selected, origin_y, scale, tile_rows, mut storage.tiles[index])
		}
	}
}

fn (mut app BrowserApp) set_chromium_msaa_tiles() {
	$if macos {
		scale := C.native_display_device_pixel_ratio()
		layout_scale := if app.document != unsafe { nil } { app.document.layout_coordinate_scale() } else { 1.0 }
		app.chromium_msaa_storage.update_for_device_viewport(app.paint_commands, app.chromium_raster_plan,
			app.viewport_width, app.viewport_height,
			int(math.ceil(app.viewport_width * layout_scale)), int(math.ceil(app.viewport_height * layout_scale)),
			app.scroll_y, scale)
		count := app.chromium_raster_plan.layers.len
		app.chromium_raster_tiles = app.chromium_msaa_storage.tiles[..count]
		app.chromium_raster_grids = app.chromium_msaa_storage.grids[..count]
		C.native_set_chromium_raster_scroll_y(app.scroll_y)
		C.native_set_chromium_raster_layer(0, 0, 1)
		C.native_set_chromium_msaa_tiles(unsafe { nil }, 0,
			chromium_gpu_raster_tile_rows(int(math.ceil(f64(app.viewport_height) * scale))))
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
		C.native_set_chromium_layer_shared_recording(i32(app.page_zoom == 1 && chromium_shared_recording_layer_supported(app.paint_commands, app.chromium_raster_plan, index)))
		tiles := app.chromium_raster_tiles[index]
		pointer := if tiles.len > 0 { &tiles[0] } else { unsafe { &i32(nil) } }
		rows := chromium_gpu_raster_tile_rows(int(math.ceil(f64(app.viewport_height) * scale)))
		C.native_set_chromium_msaa_tiles(pointer, tiles.len, rows)
		if index < app.chromium_raster_grids.len {
			grid := app.chromium_raster_grids[index]
			if grid.columns > 0 {
				cell_pointer := if grid.native_cells.len > 0 {
					&grid.native_cells[0]
				} else {
					unsafe { &i32(nil) }
				}
				C.native_set_chromium_msaa_grid(cell_pointer, grid.native_cells.len, grid.tile_width, grid.tile_height, grid.columns)
			}
		}
	}
}
