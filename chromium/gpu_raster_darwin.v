module main

import cpuraster
import ggshape
import math
import os
import platform

struct DocumentGeometryGrid {
	width                 int
	height                int
	columns               int
	rows                  int
	origin_x              f64
	origin_y              f64
	cells                 []i32
	clips_negative_origin bool
}

__global document_geometry_grid = DocumentGeometryGrid{}

fn set_document_geometry_grid(grid ChromiumRasterGrid, origin_x f64, origin_y f64, content_height f64, scale f64, clips_negative_origin bool) {
	document_geometry_grid = DocumentGeometryGrid{
		width:                 grid.tile_width
		height:                grid.tile_height
		columns:               grid.columns
		rows:                  if grid.tile_height > 2 {
			math.max(1, int(math.ceil((content_height * scale - 2) / (grid.tile_height - 2))))
		} else {
			1
		}
		origin_x:              origin_x * scale
		origin_y:              origin_y * scale
		cells:                 grid.native_cells
		clips_negative_origin: clips_negative_origin
	}
}

fn geometry_tile_owner(coordinate int, size int, count int) int {
	return math.max(0, math.min(count - 1, if coordinate <= size - 2 {
		0
	} else {
		(coordinate - 1) / (size - 2)
	}))
}

// Native leaf readbacks add two pixels around ink. That padding can cross
// the compositor picture's origin; retain its tile and leave the outside
// fringe unchanged rather than changing the GPU raster coordinate space.
fn geometry_grid_covers_leaf(grid DocumentGeometryGrid, x int, y int, width int, height int) bool {
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
		|| grid.width * grid.height > 8 * 1024 * 1024 || width <= 0 || height <= 0 {
		return false
	}
	right := grid.columns * (grid.width - 2) + 2
	bottom := grid.rows * (grid.height - 2) + 2
	return x >= -2 && y >= -2 && x < right && y < bottom && x + width > 0 && y + height > 0
		&& x + width <= right + 2 && y + height <= bottom + 2
}

fn geometry_grid_intersects_leaf(grid DocumentGeometryGrid, x int, y int, width int, height int) bool {
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0
		|| width <= 0 || height <= 0 {
		return false
	}
	right := grid.columns * (grid.width - 2) + 2
	bottom := grid.rows * (grid.height - 2) + 2
	left, top := math.max(x, 0), math.max(y, 0)
	return geometry_grid_covers_leaf(grid, left, top, math.min(x + width, right) - left,
		math.min(y + height, bottom) - top)
}

fn geometry_grid_covers_filter_output(grid DocumentGeometryGrid, x int, y int, clip [4]f32) bool {
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0 { return false }
	for value in clip {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	right := grid.columns * (grid.width - 2) + 2
	bottom := grid.rows * (grid.height - 2) + 2
	if clip[2] <= clip[0] || clip[3] <= clip[1]
		|| clip[2] + f32(x) > right || clip[3] + f32(y) > bottom {
		return false
	}
	// The root picture clips negative document coordinates before publication.
	// Offscreen readbacks can include that invisible fringe in their own clip.
	if grid.clips_negative_origin {
		return clip[2] + f32(x) > 0 && clip[3] + f32(y) > 0
	}
	return clip[0] + f32(x) >= 0 && clip[1] + f32(y) >= 0
}

// VOX_GG_FULL_TILE_TRANSFERS=1 restores whole-tile uploads and readbacks for
// every leaf, for matched comparisons.
const full_tile_leaf_transfers = os.getenv('VOX_GG_FULL_TILE_TRANSFERS') != ''

// A leaf is drawn on a surface of its compositor tile's size, which keeps the
// tile's sample positions, but it can change only its own rows. LeafTileRows
// holds the leaf's part of one tile: the backdrop to upload and, after the
// draw, the pixels to publish. A tile is megabytes; a typical leaf is a few
// kilobytes.
struct LeafTileRows {
	region ggshape.SurfaceRegion
	pitch  int
	pixels []u8
}

// The rows of `pixels` (a leaf at x0, y0) inside the tile at ox, oy. Returns
// none when the leaf's whole-tile path has to handle this tile.
fn leaf_tile_rows(grid DocumentGeometryGrid, pixels &u8, pitch int, backdrop i32, x0 int, y0 int,
	ox int, oy int, left int, top int, right int, bottom int) ?LeafTileRows {
	if full_tile_leaf_transfers || right <= left || bottom <= top { return none }
	row_bytes := (right - left) * 4
	mut storage := []u8{len: row_bytes * (bottom - top)}
	if backdrop != 0 {
		for y in top .. bottom {
			unsafe {
				vmemcpy(&storage[(y - top) * row_bytes],
					pixels + (y - y0) * pitch + (left - x0) * 4, row_bytes)
			}
		}
	}
	return LeafTileRows{
		region: ggshape.SurfaceRegion{
			surface_width:  grid.width
			surface_height: grid.height
			x:              left - ox
			y:              top - oy
			width:          right - left
			height:         bottom - top
		}
		pitch:  row_bytes
		pixels: storage
	}
}

// Copy the published part of a drawn leaf region into the leaf's result.
fn (rows &LeafTileRows) publish(mut result []u8, pitch int, x0 int, y0 int, left int, top int,
	publish_left int, publish_top int, publish_right int, publish_bottom int) {
	if publish_right <= publish_left { return }
	source := unsafe { &u8(rows.pixels.data) }
	for y in publish_top .. publish_bottom {
		unsafe {
			vmemcpy(&result[(y - y0) * pitch + (publish_left - x0) * 4],
				source + (y - top) * rows.pitch + (publish_left - left) * 4,
				(publish_right - publish_left) * 4)
		}
	}
}

fn draw_document_shape_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x int, first_y int, shape &C.VoxGraphiteShape) i32 {
	grid := document_geometry_grid
	if os.getenv('VOX_GG_DIAGNOSTICS') == '1' {
		eprintln('VOX_GEOMETRY target=${width}x${height} first=${first_x},${first_y} grid=${grid.width}x${grid.height}/${grid.columns},${grid.rows} origin=${grid.origin_x},${grid.origin_y} filter_clip=${shape.has_filter_clip}:${shape.filter_clip}')
	}
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if !geometry_grid_covers_leaf(grid, x0, y0, int(width), int(height))
		&& !(shape.has_filter_clip != 0 && ggshape.rotated_filter_supported(shape)
			&& geometry_grid_covers_filter_output(grid, x0, y0, shape.filter_clip)
			&& geometry_grid_intersects_leaf(grid, x0, y0, int(width), int(height))) {
		return ggshape.draw(pixels, width, height, pitch, backdrop, shape)
	}
	mut result := []u8{len: int(height) * int(pitch)}
	unsafe { vmemcpy(result.data, pixels, result.len) }
	// Allocated by the first tile that needs whole-tile transfers.
	mut tile := []u8{}
	for row in geometry_tile_owner(y0, grid.height, grid.rows) .. geometry_tile_owner(y0 + height - 1, grid.height, grid.rows) + 1 {
		oy := row * (grid.height - 2)
		for col in geometry_tile_owner(x0, grid.width, grid.columns) .. geometry_tile_owner(x0 + width - 1, grid.width, grid.columns) + 1 {
			ox := col * (grid.width - 2)
			left, top := math.max(x0, ox), math.max(y0, oy)
			right, bottom := math.min(x0 + width, ox + grid.width), math.min(y0 + height, oy + grid.height)
			mut draw := *shape
			draw.matrix[2] += f32(x0 - ox)
			draw.matrix[5] += f32(y0 - oy)
			if draw.has_filter_clip != 0 {
				draw.filter_clip[0] += f32(x0 - ox)
				draw.filter_clip[2] += f32(x0 - ox)
				draw.filter_clip[1] += f32(y0 - oy)
				draw.filter_clip[3] += f32(y0 - oy)
			}
			if grid.origin_x != 0 || grid.origin_y != 0 {
				draw = ggshape.localize_rounded_shape(draw, -(draw.matrix[2] + f32(ox)) / draw.matrix[0], -(draw.matrix[5] + f32(oy)) / draw.matrix[4])
			}
			draw.force_msaa = i32(i32(row * grid.columns + col) in grid.cells)
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
			// A filter layer reads the pixels around its output; keep its
			// whole-tile backdrop.
			if draw.has_filter_clip == 0 {
				if rows := leaf_tile_rows(grid, pixels, int(pitch), backdrop, x0, y0, ox, oy,
					left, top, right, bottom) {
					if ggshape.draw_region(rows.pixels.data, i32(rows.pitch), rows.region, backdrop, &draw) != 0 {
						rows.publish(mut result, int(pitch), x0, y0, left, top, publish_left,
							publish_top, publish_right, publish_bottom)
						continue
					}
				}
			}
			if tile.len == 0 { tile = []u8{len: grid.width * grid.height * 4} }
			for i in 0 .. tile.len { tile[i] = 0 }
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			if ggshape.draw(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, &draw) == 0 {
				return 0
			}
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

// Replay SVG leaves in the owning picture tile, including its sample count.
fn draw_document_path_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x int, first_y int, path &C.VoxGraphitePath) i32 {
	if pixels == unsafe { nil } || path == unsafe { nil }
		|| width <= 0 || height <= 0 || pitch < width * 4 {
		return 0
	}
	grid := document_geometry_grid
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if !geometry_grid_covers_leaf(grid, x0, y0, int(width), int(height)) {
		return ggshape.draw_path(pixels, width, height, pitch, backdrop, path)
	}
	mut result := []u8{len: int(height) * int(pitch)}
	unsafe { vmemcpy(result.data, pixels, result.len) }
	// Allocated by the first tile that needs whole-tile transfers.
	mut tile := []u8{}
	for row in geometry_tile_owner(y0, grid.height, grid.rows) .. geometry_tile_owner(y0 + height - 1, grid.height, grid.rows) + 1 {
		oy := row * (grid.height - 2)
		for col in geometry_tile_owner(x0, grid.width, grid.columns) .. geometry_tile_owner(x0 + width - 1, grid.width, grid.columns) + 1 {
			ox := col * (grid.width - 2)
			left, top := math.max(x0, ox), math.max(y0, oy)
			right, bottom := math.min(x0 + width, ox + grid.width), math.min(y0 + height, oy + grid.height)
			mut draw := *path
			draw.matrix[2] += f32(x0 - ox)
			draw.matrix[5] += f32(y0 - oy)
			multisampled := i32(row * grid.columns + col) in grid.cells
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
			if rows := leaf_tile_rows(grid, pixels, int(pitch), backdrop, x0, y0, ox, oy,
				left, top, right, bottom) {
				if ggshape.draw_path_region(rows.pixels.data, i32(rows.pitch), rows.region, backdrop, &draw, multisampled) != 0 {
					rows.publish(mut result, int(pitch), x0, y0, left, top, publish_left,
						publish_top, publish_right, publish_bottom)
					continue
				}
			}
			if tile.len == 0 { tile = []u8{len: grid.width * grid.height * 4} }
			for i in 0 .. tile.len { tile[i] = 0 }
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			result_code := if multisampled {
				ggshape.draw_multisampled_path(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, &draw)
			} else {
				ggshape.draw_path(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, &draw)
			}
			if result_code == 0 { return 0 }
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
	return draw_document_shape_glyph_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, shapes, count, [])
}

fn draw_document_shape_glyph_tiles(pixels &u8, width i32, height i32, pitch i32, backdrop i32, first_x int, first_y int, shapes &C.VoxGraphiteShape, count i32, glyphs []ggshape.GlyphCoverage) i32 {
	if width <= 0 || height <= 0 || pitch < width * 4 || glyphs.len > 16 { return 0 }
	for glyph in glyphs { if glyph.pixels.len != int(width) * int(height) { return 0 } }
	grid := document_geometry_grid
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	mut clipped_filter := false
	for i in 0 .. int(count) {
		shape := unsafe { &shapes[i] }
		clipped_filter = clipped_filter || (shape.has_filter_clip != 0 && ggshape.rotated_filter_supported(shape)
			&& geometry_grid_covers_filter_output(grid, x0, y0, shape.filter_clip))
	}
	if !geometry_grid_covers_leaf(grid, x0, y0, int(width), int(height))
		&& !(clipped_filter && geometry_grid_intersects_leaf(grid, x0, y0, int(width), int(height))) {
		return ggshape.draw_shapes_with_glyphs(pixels, width, height, pitch, backdrop, shapes, count, glyphs)
	}
	mut result := []u8{len: int(height) * int(pitch)}
	unsafe { vmemcpy(result.data, pixels, result.len) }
	// Allocated by the first tile that needs whole-tile transfers.
	mut tile := []u8{}
	for row in geometry_tile_owner(y0, grid.height, grid.rows) .. geometry_tile_owner(y0 + height - 1, grid.height, grid.rows) + 1 {
		oy := row * (grid.height - 2)
		for col in geometry_tile_owner(x0, grid.width, grid.columns) .. geometry_tile_owner(x0 + width - 1, grid.width, grid.columns) + 1 {
			ox := col * (grid.width - 2)
			left, top := math.max(x0, ox), math.max(y0, oy)
			right, bottom := math.min(x0 + width, ox + grid.width), math.min(y0 + height, oy + grid.height)
			mut draws := []C.VoxGraphiteShape{cap: int(count)}
			mut filtered := false
			for i in 0 .. int(count) {
				mut draw := unsafe { shapes[i] }
				draw.matrix[2] += f32(x0 - ox)
				draw.matrix[5] += f32(y0 - oy)
				if draw.has_filter_clip != 0 {
					filtered = true
					draw.filter_clip[0] += f32(x0 - ox)
					draw.filter_clip[2] += f32(x0 - ox)
					draw.filter_clip[1] += f32(y0 - oy)
					draw.filter_clip[3] += f32(y0 - oy)
				}
				draw.force_msaa = i32(i32(row * grid.columns + col) in grid.cells)
				draws << draw
			}
			// Glyph coverage is a whole-tile mask, and a filter layer reads the
			// pixels around its output; both keep whole-tile transfers.
			if glyphs.len == 0 && !filtered {
				if rows := leaf_tile_rows(grid, pixels, int(pitch), backdrop, x0, y0, ox, oy,
					left, top, right, bottom) {
					if ggshape.draw_shapes_region(rows.pixels.data, i32(rows.pitch), rows.region, backdrop,
						draws.data, count) != 0 {
						rows.publish(mut result, int(pitch), x0, y0, left, top,
							math.max(x0, ox + if col > 0 { 1 } else { 0 }),
							math.max(y0, oy + if row > 0 { 1 } else { 0 }),
							math.min(x0 + width, ox + grid.width - if col + 1 < grid.columns { 1 } else { 0 }),
							math.min(y0 + height, oy + grid.height - if row + 1 < grid.rows { 1 } else { 0 }))
						continue
					}
				}
			}
			if tile.len == 0 { tile = []u8{len: grid.width * grid.height * 4} }
			for i in 0 .. tile.len { tile[i] = 0 }
			for y in top .. bottom {
				unsafe {
					vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4],
						pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			mut masks := []ggshape.GlyphCoverage{}
			for glyph in glyphs {
				mut mask := []u8{len: grid.width * grid.height}
				for y in top .. bottom {
					for x in left .. right {
						mask[(y - oy) * grid.width + x - ox] = glyph.pixels[(y - y0) * int(width) + x - x0]
					}
				}
				masks << ggshape.GlyphCoverage{ pixels: mask, color: glyph.color }
			}
			if ggshape.draw_shapes_with_glyphs(tile.data, i32(grid.width), i32(grid.height), i32(grid.width * 4), backdrop, draws.data, count, masks) == 0 {
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
	unsafe { cpuraster.swap_rgba_red_blue(pixels, width, height, pitch) }
}

@[export: 'vox_draw_document_shape_pixels']
fn draw_document_shape_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, shape &C.VoxGraphiteShape) i32 {
	// Deferred pictures and chrome can call outside the frame replay arena.
	// All raster work is synchronous; only the caller-owned pixels survive.
	work := platform.begin_thread_scratch('native raster callback')
	defer { work.finish() }
	swap_document_raster_channels(pixels, width, height, pitch)
	draw := document_p3_shape(*shape)
	if draw_bounded_compositor_phase_shape(pixels, width, height, pitch, first_x, first_y, &draw) {
		swap_document_raster_channels(pixels, width, height, pitch)
		return 1
	}
	result := draw_document_shape_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, &draw)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

@[export: 'vox_draw_document_tiled_path_pixels']
fn draw_document_tiled_path_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, path &C.VoxGraphitePath) i32 {
	// Deferred pictures and chrome can call outside the frame replay arena.
	// All raster work is synchronous; only the caller-owned pixels survive.
	work := platform.begin_thread_scratch('native raster callback')
	defer { work.finish() }
	swap_document_raster_channels(pixels, width, height, pitch)
	draw := if document_paths_use_p3(path, 1) != 0 { document_p3_path(*path) } else { *path }
	if draw_compositor_phase_path(pixels, width, height, pitch, &draw) {
		swap_document_raster_channels(pixels, width, height, pitch)
		return 1
	}
	result := draw_document_path_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, &draw)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

@[export: 'vox_draw_document_path_pixels']
fn draw_document_path_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	path &C.VoxGraphitePath) i32 {
	// Deferred pictures and chrome can call outside the frame replay arena.
	// All raster work is synchronous; only the caller-owned pixels survive.
	work := platform.begin_thread_scratch('native raster callback')
	defer { work.finish() }
	// GG reads the incoming pixels only when it draws over a backdrop.
	if backdrop != 0 {
		swap_document_raster_channels(pixels, width, height, pitch)
	}
	draw := if document_paths_use_p3(path, 1) != 0 { document_p3_path(*path) } else { *path }
	result := ggshape.draw_path(pixels, width, height, pitch, backdrop, &draw)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

// Adjacent SVG paints keep their samples until the shared resolve. The native
// boundary supplies only destination pixels and retained descriptors.
@[export: 'vox_draw_document_svg_pixels']
fn draw_document_svg_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	paths &C.VoxGraphitePath, count i32, parent &f32, viewport &f32, rounded_clip &f32) i32 {
	// Deferred pictures and chrome can call outside the frame replay arena.
	// All raster work is synchronous; only the caller-owned pixels survive.
	work := platform.begin_thread_scratch('native raster callback')
	defer { work.finish() }
	swap_document_raster_channels(pixels, width, height, pitch)
	mut converted := []C.VoxGraphitePath{}
	if document_paths_use_p3(paths, count) != 0 {
		for i in 0 .. int(count) { converted << document_p3_path(unsafe { paths[i] }) }
	}
	draws := if converted.len > 0 { converted.data } else { paths }
	if draw_compositor_phase_svg(pixels, width, height, pitch, draws, count, parent, viewport, rounded_clip) {
		swap_document_raster_channels(pixels, width, height, pitch)
		return 1
	}
	result := ggshape.draw_svg_image(pixels, width, height, pitch, (if backdrop != 0 {
		i32(1)
	} else {
		i32(0)
	}) | 2 | 4, draws, count, parent, viewport, rounded_clip)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}

@[export: 'vox_draw_document_shape_group_pixels']
fn draw_document_shape_group_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32, first_x i32, first_y i32, shapes &C.VoxGraphiteShape, count i32) i32 {
	// Deferred pictures and chrome can call outside the frame replay arena.
	// All raster work is synchronous; only the caller-owned pixels survive.
	work := platform.begin_thread_scratch('native raster callback')
	defer { work.finish() }
	swap_document_raster_channels(pixels, width, height, pitch)
	mut converted := []C.VoxGraphiteShape{}
	if C.native_document_raster_uses_p3() != 0 {
		for i in 0 .. int(count) { converted << document_p3_shape(unsafe { shapes[i] }) }
	}
	draws := if converted.len > 0 { converted.data } else { shapes }
	result := draw_document_shape_group_tiles(pixels, width, height, pitch, backdrop, first_x, first_y, draws, count)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}
