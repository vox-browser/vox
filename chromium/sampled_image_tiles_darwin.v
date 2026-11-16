module main

import ggshape
import math
import os

enum DocumentSampledTileKind {
	yuv
	yuv_atlas
	jpeg
	rgba
	rgba_p3
	rgba_p3_shadow
	rgba_quad
	repeated_background
}

struct DocumentBitmapDecoration {
	color  [4]u8
	border C.VoxGraphiteShape
	shadow C.VoxGraphiteShape
}

// A cropped native readback can cross tiles with different sample counts.
// Draw the image in each tile's raster space, including its gutter,
// and publish only the pixels that tile owns. Keep the destination untouched
// if any tile fails, so the caller can safely use its existing fallback.
fn draw_document_sampled_image_tiles(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, first_x int, first_y int, source []u8, sw int, sh int,
	x f32, y f32, dw f32, dh f32, nw int, nh int, clip [12]f32, kind DocumentSampledTileKind, gpu_mips bool) i32 {
	return draw_document_sampled_image_tiles_with_decoration(pixels, width, height, pitch, backdrop, first_x, first_y,
		source, sw, sh, x, y, dw, dh, nw, nh, clip, kind, gpu_mips, DocumentBitmapDecoration{})
}

fn draw_document_sampled_image_tiles_with_decoration(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, first_x int, first_y int, source []u8, sw int, sh int,
	x f32, y f32, dw f32, dh f32, nw int, nh int, clip [12]f32, kind DocumentSampledTileKind, gpu_mips bool, decoration DocumentBitmapDecoration) i32 {
	grid := document_geometry_grid
	x0 := first_x - int(math.round(grid.origin_x))
	y0 := first_y - int(math.round(grid.origin_y))
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || width > 4096
		|| height > 4096 || int(width) * int(height) > 4 * 1024 * 1024
		|| pitch < width * 4 || pitch > 4096 * 4
		|| grid.width > 4096 || grid.height > 4096
		|| grid.width * grid.height > 4 * 1024 * 1024
		|| !geometry_grid_covers_leaf(grid, x0, y0, int(width), int(height)) {
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
			right := math.min(x0 + width, ox + grid.width)
			bottom := math.min(y0 + height, oy + grid.height)
			if right <= left || bottom <= top { continue }
			for py in top .. bottom {
				unsafe {
					vmemcpy(&tile[((py - oy) * grid.width + left - ox) * 4],
						pixels + (py - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4)
				}
			}
			dx, dy := f32(x0 - ox), f32(y0 - oy)
			mut local_clip := clip
			local_clip[0] += dx
			local_clip[1] += dy
			samples := if i32(row * grid.columns + col) in grid.cells { 4 } else { 1 }
			if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
				eprintln('VOX_YUV_TILE col=${col} row=${row} samples=${samples} origin=${grid.origin_x},${grid.origin_y}')
			}
			drawn := if kind == .repeated_background {
				mut border := decoration.border
				border.matrix[2] += dx
				border.matrix[5] += dy
				i32(ggshape.draw_repeated_background(tile.data, grid.width, grid.height, grid.width * 4,
					source, sw, sh, x + dx, y + dy, local_clip, samples, decoration.color, &border))
			} else if kind == .jpeg {
				ggshape.draw_sampled_jpeg_clipped(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip)
			} else if kind == .yuv_atlas {
				ggshape.draw_sampled_yuv_atlas_at_origin(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip, gpu_mips, [f32(ox), f32(oy)]!)
			} else if kind == .rgba_quad {
				ggshape.draw_sampled_image_quad_rgba(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, samples, local_clip)
			} else if kind == .rgba_p3_shadow {
				mut shadow := decoration.shadow
				shadow.matrix[2] += dx
				shadow.matrix[5] += dy
				ggshape.draw_sampled_srgb_gamut_with_shadow(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip, gpu_mips, document_srgb_to_p3_gamut, &shadow)
			} else if kind == .rgba_p3 {
				ggshape.draw_sampled_srgb_gamut_clipped(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip, gpu_mips, document_srgb_to_p3_gamut)
			} else if kind == .rgba {
				ggshape.draw_sampled_rgba_clipped(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip, gpu_mips)
			} else {
				ggshape.draw_sampled_yuv_with_mips_clipped(tile.data, i32(grid.width), i32(grid.height),
					i32(grid.width * 4), backdrop, source, sw, sh, x + dx, y + dy, dw, dh,
					samples, nw, nh, local_clip, gpu_mips)
			}
			if drawn == 0 {
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
			for py in publish_top .. publish_bottom {
				unsafe {
					vmemcpy(&result[(py - y0) * int(pitch) + (publish_left - x0) * 4],
						&tile[((py - oy) * grid.width + publish_left - ox) * 4],
						(publish_right - publish_left) * 4)
				}
			}
		}
	}
	unsafe { vmemcpy(pixels, result.data, result.len) }
	return 1
}
