// vtest build: macos
module main

import stbi

fn test_native_leaf_fringe_preserves_the_compositor_tile_origin() {
	old := document_geometry_grid
	defer { document_geometry_grid = old }
	document_geometry_grid = DocumentGeometryGrid{ width: 64, height: 64, columns: 1, rows: 1, origin_x: 760, origin_y: 16, cells: [i32(0)] }
	shape := C.VoxGraphiteShape{
		matrix:     [f32(1), 0, -759, 0, 1, -14, 0, 0, 1]!
		rect:       [
			f32(761.5),
			16.5,
			41,
			35,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
			5.5,
		]!
		fill:       0
		thickness:  1
		anti_alias: 1
		force_msaa: 1
		red:        53
		green:      61
		blue:       55
		alpha:      255
	}
	b := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/legacy-backdrop-border.png').to_bytes()
	ref := stbi.load_from_memory(b.data, b.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	for grouped in [false, true] {
		mut pixels := []u8{len: 46 * 40 * 4}
		for i in 0 .. 46 * 40 { pixels[i * 4 + 3] = 255 }
		result := if grouped {
			draw_document_shape_group_tiles(pixels.data, 46, 40, 184, 1, 759, 14, &shape, 1)
		} else {
			draw_document_shape_tiles(pixels.data, 46, 40, 184, 1, 759, 14, &shape)
		}
		assert result == 1
		mut n := 0
		for y in 0 .. 40 {
			for x in 0 .. 46 {
				if x > 8 && x < 38 && y > 8 && y < 32 { continue }
				i := (y * 46 + x) * 4
				j := ((y + 14) * 1024 + x + 759) * 4
				mut d := false
				for c in 0 .. 4 {
					ch := if c == 0 {
						2
					} else if c == 2 {
						0
					} else {
						c
					}
					if pixels[i + ch] != unsafe { ref.data[j + c] } { d = true }
				}
				if d { n++ }
			}
		}
		assert n == 0, 'border differences=${n}, grouped=${grouped}'
	}
}

fn test_native_geometry_fringe_requires_a_real_tile_intersection() {
	grid := DocumentGeometryGrid{ width: 64, height: 64, columns: 1, rows: 1 }
	assert geometry_grid_covers_leaf(grid, -2, -2, 66, 66)
	for rect in [[-3, 0, 20, 20], [0, -3, 20, 20], [-2, 0, 2, 20], [0, -2, 20, 2], [64, 0, 1, 1],
		[0, 64, 1, 1], [0, 0, 67, 1], [0, 0, 1, 67], [0, 0, 0, 1]] {
		assert !geometry_grid_covers_leaf(grid, rect[0], rect[1], rect[2], rect[3])
	}
	assert !geometry_grid_covers_leaf(DocumentGeometryGrid{}, 0, 0, 1, 1)
}

fn test_filter_fringe_only_uses_a_grid_containing_the_visible_clip() {
	grid := DocumentGeometryGrid{ width: 64, height: 64, columns: 1, rows: 1 }
	assert geometry_grid_intersects_leaf(grid, -50, -60, 114, 124)
	assert geometry_grid_covers_filter_output(grid, -50, -60, [f32(50), 60, 114, 124]!)
	for clip in [[f32(49), 60, 114, 124]!, [f32(50), 59, 114, 124]!, [f32(50), 60, 115, 124]!,
		[f32(50), 60, 114, 125]!, [f32(50), 60, 50, 124]!] {
		assert !geometry_grid_covers_filter_output(grid, -50, -60, clip)
	}
	for rect in [[-100, -100, 10, 10], [64, 0, 20, 20], [0, 64, 20, 20], [0, 0, 0, 20]] {
		assert !geometry_grid_intersects_leaf(grid, rect[0], rect[1], rect[2], rect[3])
	}
	assert !geometry_grid_intersects_leaf(DocumentGeometryGrid{}, 0, 0, 1, 1)
}

fn test_root_filter_fringe_preserves_the_picture_origin_and_outside_pixels() {
	old := document_geometry_grid
	defer { document_geometry_grid = old }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rotated-translucent-shadow.png').to_bytes()
	ref := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic('reference') }
	defer { ref.free() }
	shape := C.VoxGraphiteShape{
		matrix:          [f32(.9135454), .40673664, 65.970345, -.40673664, .9135454, 193.99567,
			0, 0, 1]!
		rect:            [f32(0), -15, 240, 120, 120, 60, 120, 60, 120, 60, 120, 60]!
		underlay_rect:   [f32(0), 0, 240, 120, 120, 60, 120, 60, 120, 60, 120, 60]!
		fill:            10
		thickness:       60
		anti_alias:      1
		has_float_color: 1
		float_color:     [f32(121) / 255, f32(168) / 255, f32(243) / 255, f32(9) / 255]!
		has_filter_clip: 1
		filter_clip:     [f32(0), 0, 400, 404]!
	}
	for root in [false, true] {
		for grouped in [false, true] {
			document_geometry_grid = DocumentGeometryGrid{ width: 416, height: 256, columns: 1, rows: 2, clips_negative_origin: root }
			mut pixels := []u8{len: 400 * 404 * 4}
			for i in 0 .. 400 * 404 {
				pixels[i * 4] = 15
				pixels[i * 4 + 1] = 11
				pixels[i * 4 + 2] = 9
				pixels[i * 4 + 3] = 255
			}
			result := if grouped {
				draw_document_shape_group_tiles(pixels.data, 400, 404, 1600, 1, 0, -60, &shape, 1)
			} else {
				draw_document_shape_tiles(pixels.data, 400, 404, 1600, 1, 0, -60, &shape)
			}
			assert result == 1
			mut different := 0
			for y in 0 .. 280 {
				for x in 0 .. 400 {
					mut differs := false
					for c in 0 .. 4 {
						ch := if c == 0 {
							2
						} else if c == 2 {
							0
						} else {
							c
						}
						if pixels[((y + 60) * 400 + x) * 4 + ch] != unsafe { ref.data[(y * 400 + x) * 4 + c] } {
							differs = true
						}
					}
					if differs { different++ }
				}
			}
			assert different == if root { 0 } else { 4 }, 'root=${root}, grouped=${grouped}, differences=${different}'
			if root {
				for i in 0 .. 400 * 60 {
					assert pixels[i * 4] == 15
					assert pixels[i * 4 + 1] == 11
					assert pixels[i * 4 + 2] == 9
					assert pixels[i * 4 + 3] == 255
				}
			}
		}
	}
}
