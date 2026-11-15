// vtest build: macos
module main

import ggshape

fn test_yuv_readback_preserves_each_tiles_sample_count_and_backdrop_fringe() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{
		width:    64
		height:   64
		columns:  2
		rows:     2
		origin_x: 31
		origin_y: -7
		cells:    [i32(1), 2]
	}
	assert document_image_sample_count(29, -9, 130, 130) == 0
	mut source := []u8{}
	for _ in 0 .. 16 {
		source << [u8(128), 120, 145, 255]
	}
	clip := [f32(12), 15, 95, 90, 0, 0, 0, 0, 0, 0, 0, 0]!
	// Render the whole leaf once in each mode. Tile ownership alone chooses
	// between those independent coverage results, including both crossing seams.
	mut single := []u8{len: 130 * 532, init: 173}
	mut multisampled := single.clone()
	mut pixels := single.clone()
	assert ggshape.draw_sampled_yuv_clipped(single.data, 130, 130, 532, 1,
		source, 4, 4, 20.375, 22.375, 79.25, 77.25, 1, 16, 16, clip) == 1
	assert ggshape.draw_sampled_yuv_clipped(multisampled.data, 130, 130, 532, 1,
		source, 4, 4, 20.375, 22.375, 79.25, 77.25, 4, 16, 16, clip) == 1
	assert single != multisampled
	assert draw_document_sampled_yuv_tiles(pixels.data, 130, 130, 532, 1,
		29, -9, source, 4, 4, 20.375, 22.375, 79.25, 77.25, 16, 16, clip, false, false) == 1
	for py in 0 .. 130 {
		for px in 0 .. 133 {
			for c in 0 .. 4 {
				i := py * 532 + px * 4 + c
				if px < 2 || py < 2 || px >= 128 || py >= 128 {
					assert pixels[i] == 173
				} else if (px >= 65) != (py >= 65) {
					assert pixels[i] == multisampled[i], 'MSAA pixel ${px},${py},${c}'
				} else {
					assert pixels[i] == single[i], 'single pixel ${px},${py},${c}'
				}
			}
		}
	}
	// Exercise the actual native callback, including its channel conversion.
	mut callback := []u8{len: 130 * 532, init: 173}
	assert document_sampled_png_pixels(callback.data, 130, 130, 532, 1, 29, -9,
		source.data, 4, 4, 16, 16, 3, 20.375, 22.375, 79.25, 77.25, &clip[0]) == 1
	swap_document_raster_channels(callback.data, 130, 130, 532)
	assert callback == pixels
	// The native mip flag must also reach both sample modes across the seams.
	// Constant planes isolate routing/coverage from texture reconstruction.
	for source_size in [128, 256] {
		mut mip_source := []u8{cap: source_size * source_size * 4}
		for _ in 0 .. source_size * source_size { mip_source << [u8(128), 120, 145, 255] }
		for flag in [i32(4), 5] {
			mut mip_callback := []u8{len: 130 * 532, init: 173}
			assert document_sampled_png_pixels(mip_callback.data, 130, 130, 532, 1, 29, -9,
				mip_source.data, i32(source_size), i32(source_size), i32(source_size), i32(source_size), flag,
				20.375, 22.375, 79.25, 77.25, &clip[0]) == 1
			swap_document_raster_channels(mip_callback.data, 130, 130, 532)
			assert mip_callback == pixels
		}
	}
}

fn test_yuv_tile_rejection_leaves_the_native_destination_unchanged() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{
		width:   64
		height:  64
		columns: 2
		rows:    1
		cells:   [i32(1)]
	}
	mut pixels := []u8{len: 16 * 16 * 4, init: 97}
	for first_x in [0, 60, 124, -3] {
		assert draw_document_sampled_yuv_tiles(pixels.data, 16, 16, 64, 1,
			first_x, 0, [u8(80), 128, 128, 0], 1, 1, 0, 0, 16, 16,
			1, 1, [12]f32{}, false, false) == 0
		assert pixels.all(it == 97)
	}
	assert document_sampled_png_pixels(pixels.data, 16, 16, 64, 1, 60, 0,
		[u8(80), 128, 128, 0].data, 1, 1, 1, 1, 3, 0, 0, 16, 16,
		&[12]f32{}[0]) == 0
	assert pixels.all(it == 97)
}
