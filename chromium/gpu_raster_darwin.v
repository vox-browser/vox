module main

import ggshape
import math

struct DocumentGeometryGrid {
	width    int
	height   int
	columns  int
	rows     int
	origin_x f64
	origin_y f64
	cells    []i32
}

__global document_geometry_grid = DocumentGeometryGrid{}

fn set_document_geometry_grid(grid ChromiumRasterGrid, origin_x f64, origin_y f64, content_height f64, scale f64) {
	document_geometry_grid = DocumentGeometryGrid{
		width:    grid.tile_width
		height:   grid.tile_height
		columns:  grid.columns
		rows:     if grid.tile_height > 2 {
			math.max(1, int(math.ceil((content_height * scale - 2) / (grid.tile_height - 2))))
		} else {
			1
		}
		origin_x: origin_x * scale
		origin_y: origin_y * scale
		cells:    grid.native_cells
	}
}

fn geometry_tile_owner(coordinate int, size int, count int) int {
	return math.max(0, math.min(count - 1, if coordinate <= size - 2 {
		0
	} else {
		(coordinate - 1) / (size - 2)
	}))
}

fn draw_document_shape_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x int, first_y int, shape &C.VoxGraphiteShape) i32 {
	grid := document_geometry_grid
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
		|| x0 < 0 || y0 < 0 || x0 + width > grid.columns * (grid.width - 2) + 2
		|| y0 + height > grid.rows * (grid.height - 2) + 2
		|| grid.width * grid.height > 8 * 1024 * 1024 {
		return ggshape.draw(pixels, width, height, pitch, backdrop, shape)
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
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			mut draw := *shape
			draw.matrix[2] += f32(x0 - ox)
			draw.matrix[5] += f32(y0 - oy)
			draw.force_msaa = i32(i32(row * grid.columns + col) in grid.cells)
			if ggshape.draw(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, &draw) == 0 {
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

fn draw_document_shape_group_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x int, first_y int, shapes &C.VoxGraphiteShape, count i32) i32 {
	grid := document_geometry_grid
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
		|| x0 < 0 || y0 < 0 || x0 + width > grid.columns * (grid.width - 2) + 2
		|| y0 + height > grid.rows * (grid.height - 2) + 2
		|| grid.width * grid.height > 8 * 1024 * 1024 {
		return ggshape.draw_shapes(pixels, width, height, pitch, backdrop, shapes, count)
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
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			mut draws := []C.VoxGraphiteShape{cap: int(count)}
			for i in 0 .. int(count) {
				mut draw := unsafe { shapes[i] }
				draw.matrix[2] += f32(x0 - ox)
				draw.matrix[5] += f32(y0 - oy)
				draw.force_msaa = i32(i32(row * grid.columns + col) in grid.cells)
				draws << draw
			}
			if ggshape.draw_shapes(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, draws.data, count) == 0 {
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

// Quartz uses RGBA, while gg.canvas's GPU surface transports BGRA.
fn swap_document_raster_channels(pixels &u8, width i32, height i32, pitch i32) {
	unsafe {
		for y in 0 .. int(height) {
			for x in 0 .. int(width) {
				i := y * int(pitch) + x * 4
				red := pixels[i]
				pixels[i] = pixels[i + 2]
				pixels[i + 2] = red
			}
		}
	}
}

@[export: 'vox_draw_document_shape_pixels']
fn draw_document_shape_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, shape &C.VoxGraphiteShape) i32 {
	swap_document_raster_channels(pixels, width, height, pitch)
	result := draw_document_shape_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, shape)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

@[export: 'vox_draw_document_path_pixels']
fn draw_document_path_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	path &C.VoxGraphitePath) i32 {
	swap_document_raster_channels(pixels, width, height, pitch)
	result := ggshape.draw_path(pixels, width, height, pitch, backdrop, path)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

@[export: 'vox_draw_document_shape_group_pixels']
fn draw_document_shape_group_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32, first_x i32, first_y i32, shapes &C.VoxGraphiteShape, count i32) i32 {
	swap_document_raster_channels(pixels, width, height, pitch)
	result := draw_document_shape_group_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, shapes, count)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}
