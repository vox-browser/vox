// vtest build: macos
module main

import os
import stbi

fn test_sampled_images_accept_only_a_two_pixel_readback_fringe() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	for samples in [i32(1), 4] {
		document_geometry_grid = DocumentGeometryGrid{
			width: 128
			height: 64
			columns: 1
			rows: 1
			origin_x: 460
			origin_y: 753
			cells: if samples == 4 { [i32(0)] } else { []i32{} }
		}
		// The browser's clipped WebP readback begins two pixels before its
		// compositor picture. Its visible pixels still belong to that picture.
		assert document_image_sample_count(458, 751, 108, 41) == samples
		assert document_image_sample_count(460, 753, 104, 59) == samples
		assert document_image_sample_count(586, 815, 4, 4) == samples
		for rect in [[457, 753, 20, 20], [460, 750, 20, 20], [460, 753, 131, 1],
			[460, 753, 1, 67], [458, 753, 2, 20], [460, 751, 20, 2],
			[588, 753, 1, 1], [460, 817, 1, 1], [460, 753, 0, 1]] {
			assert document_image_sample_count(i32(rect[0]), i32(rect[1]), i32(rect[2]),
				i32(rect[3])) == 0
		}
	}
}

fn test_sampled_image_fringe_preserves_mixed_tile_rejection() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{
		width: 64
		height: 64
		columns: 2
		rows: 2
		cells: [i32(3)]
	}
	assert document_image_sample_count(-2, -2, 40, 40) == 1
	assert document_image_sample_count(64, 64, 62, 62) == 4
	assert document_image_sample_count(124, 124, 4, 4) == 4
	for rect in [[60, 60, 8, 8], [61, 65, 4, 2], [-2, 65, 128, 2]] {
		assert document_image_sample_count(i32(rect[0]), i32(rect[1]), i32(rect[2]),
			i32(rect[3])) == 0
	}
}

fn test_sampled_webp_callback_matches_the_clipped_brave_picture() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572'))!
	bitmap := browser_decode_raster_image_bytes(bytes)!
	assert bitmap.width == 480 && bitmap.height == 270 && bitmap.pitch == 1920
	ref_bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/diagnostic/webp-srgb-table.png'))!
	reference := stbi.load_from_memory(ref_bytes.data, ref_bytes.len, desired_channels: 4)!
	defer { reference.free() }
	for samples in [1, 4] {
		document_geometry_grid = DocumentGeometryGrid{
			width: 128
			height: 64
			columns: 1
			rows: 1
			origin_x: 460
			origin_y: 753
			cells: if samples == 4 { [i32(0)] } else { []i32{} }
		}
		mut pixels := []u8{len: 108 * 41 * 4, init: 255}
		clip := [f32(2), 2, 104, 59, 0, 0, 0, 0, 0, 0, 0, 0]!
		assert document_sampled_png_pixels(pixels.data, 108, 41, 432, 1, 458, 751,
			bitmap.data.data, 480, 270, 480, 270, 1, 2, 2, 104, 59, &clip[0]) == 1
		mut different := 0
		for y in 0 .. 17 {
			for x in 0 .. 108 {
				for channel in 0 .. 4 {
					if pixels[(y * 108 + x) * 4 + channel] != unsafe {
						reference.data[((y + 751) * 1024 + x + 458) * 4 + channel]
					} { different++ }
				}
			}
		}
		assert different == 0, 'samples=${samples}, differing channels=${different}'
	}
}
