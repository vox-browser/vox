module main

import ggshape
import math

// A background-text gradient is recorded into its own clipped layer. Dither
// coordinates start at that layer's device origin, rather than the page tile.
// Higher backing scales retain the page grid until their layer/tile mapping is ported.
fn gradient_text_raster_grid(bounds ?[5]f32) ?DocumentGeometryGrid {
	b := bounds or { return none }
	for value in b { if !math.is_finite(value) { return none } }
	if b[4] != 1 { return none }
	if b[2] <= 0 || b[3] <= 0 || b[2] > 4094 || b[3] > 4094 { return none }
	width, height := int(math.ceil(b[2])) + 2, int(math.ceil(b[3])) + 2
	if width * height > 8 * 1024 * 1024 { return none }
	return DocumentGeometryGrid{
		width: width
		height: height
		columns: 1
		rows: 1
		origin_x: b[0]
		origin_y: b[1]
	}
}

// CSS gradient dithering uses the compositor tile's coordinates. Keep its
// gutter and sample count while crossing the cropped native pixel boundary.
fn draw_document_gradient_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x int, first_y int, path &C.VoxGraphitePath, grid DocumentGeometryGrid, clip_to_grid bool) i32 {
	if pixels == unsafe { nil } || path == unsafe { nil } || width <= 0 || height <= 0 || pitch < width * 4 {
		return 0
	}
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
		|| (!clip_to_grid && (x0 < -2 || y0 < -2
			|| x0 + width > grid.columns * (grid.width - 2) + 2
			|| y0 + height > grid.rows * (grid.height - 2) + 2))
		|| grid.width * grid.height > 8 * 1024 * 1024 {
		return 0
	}
	mut result := []u8{len: int(height) * int(pitch)}
	unsafe { vmemcpy(result.data, pixels, result.len) }
	mut tile := []u8{len: grid.width * grid.height * 4}
	for row in geometry_tile_owner(y0, grid.height, grid.rows) .. geometry_tile_owner(y0 + height - 1, grid.height, grid.rows) + 1 {
		oy := row * (grid.height - 2)
		for col in geometry_tile_owner(x0, grid.width, grid.columns) .. geometry_tile_owner(x0 + width - 1, grid.width, grid.columns) + 1 {
			ox := col * (grid.width - 2)
			for i in 0 .. tile.len { tile[i] = 0 }
			left, top := math.max(x0, ox), math.max(y0, oy)
			right, bottom := math.min(x0 + width, ox + grid.width), math.min(y0 + height, oy + grid.height)
			if right <= left || bottom <= top { continue }
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			mut draw := unsafe { *path }
			draw.matrix[2] += f32(x0 - ox)
			draw.matrix[5] += f32(y0 - oy)
			parent := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			viewport := [f32(0), 0, f32(grid.width), f32(grid.height)]!
			flags := (if backdrop != 0 { i32(1) } else { i32(0) }) | 4 |
				if i32(row * grid.columns + col) in grid.cells { i32(2) } else { i32(0) }
			if ggshape.draw_svg_image(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4),
				flags, &draw, 1, &parent[0], &viewport[0], unsafe { nil }) == 0 {
				return 0
			}

			publish_left := math.max(x0, ox + if col > 0 { 1 } else { 0 })
			publish_top := math.max(y0, oy + if row > 0 { 1 } else { 0 })
			publish_right := math.min(x0 + width, ox + grid.width - if col + 1 < grid.columns {
				1
			} else {
				0
			})
			publish_bottom := math.min(y0 + height, oy + grid.height - if row + 1 < grid.rows {
				1
			} else {
				0
			})
			for y in publish_top .. publish_bottom {
				unsafe {
					vmemcpy(&result[(y - y0) * int(pitch) + (publish_left - x0) * 4],
						&tile[((y - oy) * grid.width + publish_left - ox) * 4], (publish_right - publish_left) * 4)
				}
			}
		}
	}
	unsafe { vmemcpy(pixels, result.data, result.len) }
	return 1
}

@[export: 'vox_draw_document_gradient_pixels']
fn draw_document_gradient_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, path &C.VoxGraphitePath, text_bounds &f32) i32 {
	mut bounds := ?[5]f32(none)
	if text_bounds != unsafe { nil } {
		bounds = unsafe { [text_bounds[0], text_bounds[1], text_bounds[2], text_bounds[3], text_bounds[4]]! }
	}
	text_grid := gradient_text_raster_grid(bounds)
	grid := text_grid or { document_geometry_grid }
	swap_document_raster_channels(pixels, width, height, pitch)
	// The native leaf has two logical pixels of padding, which can span more
	// device pixels. Only the text mask's grid can contribute through its clip.
	result := draw_document_gradient_tiles(pixels, width, height, pitch, backdrop, int(first_x), int(first_y), path, grid, text_grid != none)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}
