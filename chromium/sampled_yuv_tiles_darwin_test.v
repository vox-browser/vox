// vtest build: macos
module main

import crypto.sha256
import ggshape
import imageraster
import yuv

#flag darwin -L/opt/homebrew/lib -I/opt/homebrew/include -lwebpdecoder
#include <webp/decode.h>

fn C.WebPDecodeYUVInto(&u8, uint, &u8, uint, i32, &u8, uint, i32, &u8, uint, i32) &u8

fn C.WebPDecodeRGBAInto(&u8, uint, &u8, uint, i32) &u8

fn test_rounded_cpu_yuv_upload_uses_decoded_frame_coordinates() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/3b55183527c54f500074b88bd2e0fb0a9a976358fa04f5a5197b9d1314f005e8').to_bytes()
	mut planes := []u8{len: 480 * 270 * 3 / 2}
	decoded := unsafe {
		C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 480 * 270, 480,
			&planes[480 * 270], 240 * 135, 240, &planes[480 * 270 + 240 * 135], 240 * 135, 240)
	}
	assert decoded != unsafe { nil }
	upload := yuv.webp_minified_upload(planes, 480, 270, 120, 68) or { panic('rounded CPU upload') }
	assert sha256.sum(upload).hex() == 'd3592c9e72cd744fabe92d0ff512ce020e67a1ed53a6e39417907c9f9dee3163'
	document_geometry_grid = DocumentGeometryGrid{ width: 1024, height: 256, columns: 1, rows: 4, cells: [i32(2), 3] }
	clip := [f32(2), 2, 103, 58, 4, 4, 4, 4, 4, 4, 4, 4]!
	mut pixels := []u8{len: 107 * 41 * 4, init: 255}
	assert document_sampled_png_pixels(pixels.data, 107, 41, 428, 1, 331, 751, upload.data,
		120, 68, 480, 270, 3, 2, 2, 103, 58, &clip[0]) == 1
	swap_document_raster_channels(pixels.data, 107, 41, 428)
	// Independent native R8-plane frames, including ownership across a 4x MSAA seam.
	assert sha256.sum(pixels).hex() == '496cc60bd21aeb50fe399f94de9b8feca5a7db9b3959468533d17197267552f5'
	// Replacing the image frame must not admit invalid natural metadata.
	for natural in [[0, 270], [480, 0], [-1, 270], [480, -1], [4097, 270], [480, 4097]] {
		mut rejected := []u8{len: pixels.len, init: 97}
		assert document_sampled_png_pixels(rejected.data, 107, 41, 428, 1, 331, 751,
			upload.data, 120, 68, i32(natural[0]), i32(natural[1]), 3, 2, 2, 103, 58, &clip[0]) == 0
		assert rejected.all(it == 97)
	}
}

fn test_uniform_rgba_callback_preserves_owning_tile_samples() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/fbe3994f267a5bfabc1f8856b9adcce31ba8350b3853265605ecbeadc6a52d12').to_bytes()
	mut decoded := []u8{len: 780 * 438 * 4}
	assert C.WebPDecodeRGBAInto(bytes.data, uint(bytes.len), decoded.data, uint(decoded.len), 780 * 4) != unsafe { nil }
	image := imageraster.decode_rgba(decoded, 780, 438, 390, 219) or { panic('RGBA upload') }
	assert sha256.sum(image.pixels).hex() == '195df442a89e036cbff58b3abf90525de21b58d8988cf6407995a7ff2243ba83'
	document_geometry_grid = DocumentGeometryGrid{ width: 1024, height: 256, columns: 1, rows: 4 }
	clip := [f32(2), 2, 269, 151, 4, 4, 4, 4, 4, 4, 4, 4]!
	mut actual := []u8{len: 273 * 155 * 4, init: 255}
	assert document_sampled_png_pixels(actual.data, 273, 155, 1092, 1, 721, 343, image.pixels.data, 390, 219, 780, 438, 0, 2, 2, 269, 151, &clip[0]) == 1
	swap_document_raster_channels(actual.data, 273, 155, 1092)
	// Original Brave image pixels, including rounded coverage, on white padding.
	assert sha256.sum(actual).hex() == '7874f283117acce8eb15649c145686af0980098bfa52ef10aef1dbc0f88536d3'
	document_geometry_grid = DocumentGeometryGrid{}
	mut direct := []u8{len: actual.len, init: 255}
	mut fallback := direct.clone()
	assert ggshape.draw_sampled_rgba_clipped(direct.data, 273, 155, 1092, 1, image.pixels, 390, 219, 2, 2, 269, 151, 1, 780, 438, clip, false) == 1
	assert document_sampled_png_pixels(fallback.data, 273, 155, 1092, 1, 721, 343, image.pixels.data, 390, 219, 780, 438, 0, 2, 2, 269, 151, &clip[0]) == 1
	swap_document_raster_channels(fallback.data, 273, 155, 1092)
	assert sha256.sum(fallback) == sha256.sum(direct)
	// Mixed sample ownership retains the native fallback and its input pixels.
	document_geometry_grid = DocumentGeometryGrid{ width: 64, height: 64, columns: 2, rows: 2, cells: [i32(1)] }
	mut rejected := []u8{len: 130 * 130 * 4, init: 97}
	assert document_sampled_png_pixels(rejected.data, 130, 130, 520, 1, 0, 0, image.pixels.data, 390, 219, 780, 438, 0, 2, 2, 269, 151, &clip[0]) == 0
	assert rejected.all(it == 97)
}

fn test_uniform_yuv_callback_preserves_native_tile_coordinate_space() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/781d2b9c3ec6b401a4b2e9dbdce964f4ba3f6ecdb9880466d85dc30df6227139').to_bytes()
	mut planes := []u8{len: 960 * 540 * 3 / 2}
	decoded := unsafe {
		C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 960 * 540, 960,
			&planes[960 * 540], 480 * 270, 480, &planes[960 * 540 + 480 * 270], 480 * 270, 480)
	}
	assert decoded != unsafe { nil }
	atlas := yuv.webp_420_atlas_upload(planes, 960, 540) or { panic('native atlas') }
	clip := [f32(2), 2, 269, 151, 4, 4, 4, 4, 4, 4, 4, 4]!
	document_geometry_grid = DocumentGeometryGrid{
		width:   1024
		height:  256
		columns: 1
		rows:    4
	}
	assert document_image_sample_count(30, 125, 273, 155) == 1
	mut actual := []u8{len: 273 * 155 * 4, init: 255}
	assert document_sampled_png_pixels(actual.data, 273, 155, 1092, 1, 30, 125,
		atlas.data, 960, 540, 960, 540, 5, 2, 2, 269, 151, &clip[0]) == 1
	swap_document_raster_channels(actual.data, 273, 155, 1092)
	// Crop of independently rendered native Graphite/Metal R8-plane tiles.
	// Tile zero owns rows through 254; tile one starts publication at 255.
	assert sha256.sum(actual).hex() == 'a35a8597defe242feac2eb5ef0677e97b6286dfa3b18f450acd80cf4a260fdd2'

	// Without document geometry, the uniform callback retains direct drawing.
	document_geometry_grid = DocumentGeometryGrid{}
	mut fallback := []u8{len: actual.len, init: 255}
	mut direct := fallback.clone()
	assert ggshape.draw_sampled_yuv_atlas_clipped(direct.data, 273, 155, 1092, 1,
		atlas, 960, 540, 2, 2, 269, 151, 1, 960, 540, clip) == 1
	assert document_sampled_png_pixels(fallback.data, 273, 155, 1092, 1, 30, 125,
		atlas.data, 960, 540, 960, 540, 5, 2, 2, 269, 151, &clip[0]) == 1
	swap_document_raster_channels(fallback.data, 273, 155, 1092)
	assert fallback == direct
}

fn test_near_half_yuv_callback_retains_cpu_upload_mips() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/64c0bec89a02c6abf49a57bc3a3723f395d6cb2b7ef76ab0a0d429bf33b2dd8f').to_bytes()
	mut planes := []u8{len: 256 * 144 * 3 / 2}
	decoded := unsafe { C.WebPDecodeYUVInto(bytes.data, uint(bytes.len), planes.data, 256 * 144, 256, &planes[256 * 144], 128 * 72, 128, &planes[256 * 144 + 128 * 72], 128 * 72, 128) }
	assert decoded != unsafe { nil }
	atlas := yuv.webp_420_atlas_upload(planes, 256, 144) or { panic('native CPU atlas') }
	document_geometry_grid = DocumentGeometryGrid{ width: 1024, height: 256, columns: 1, rows: 4 }
	clip := [f32(2), 2, 130, 73, 4, 4, 4, 4, 4, 4, 4, 4]!
	mut pixels := []u8{len: 134 * 77 * 4, init: 255}
	assert document_sampled_png_pixels(pixels.data, 134, 77, 536, 1, 721, 627, atlas.data, 256, 144, 256, 144, 5, 2, 2, 130, 73, &clip[0]) == 1
	swap_document_raster_channels(pixels.data, 134, 77, 536)
	assert sha256.sum(pixels).hex() == 'fcfdf9b06b11cbcbfbe9f8afe3a1447aba2349179c7fc2d1bee67eccb5d8f5e8'
	// CPU mip selection also survives the direct fallback without a grid.
	document_geometry_grid = DocumentGeometryGrid{}
	mut direct := []u8{len: pixels.len, init: 255}
	mut fallback := direct.clone()
	assert ggshape.draw_sampled_yuv_atlas_with_mips_clipped(direct.data, 134, 77, 536, 1, atlas, 256, 144, 2, 2, 130, 73, 1, 256, 144, clip, false) == 1
	assert document_sampled_png_pixels(fallback.data, 134, 77, 536, 1, 721, 627, atlas.data, 256, 144, 256, 144, 5, 2, 2, 130, 73, &clip[0]) == 1
	swap_document_raster_channels(fallback.data, 134, 77, 536)
	assert sha256.sum(fallback) == sha256.sum(direct)
}

fn test_jpeg_native_callback_preserves_full_range_color_and_tile_sample_ownership() {
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
	source := []u8{len: 4 * 4 * 4, init: [u8(128), 120, 145, 255][index % 4]}
	clip := [f32(12), 15, 95, 90, 0, 0, 0, 0, 0, 0, 0, 0]!
	mut single := []u8{len: 130 * 532, init: 173}
	mut multi := single.clone()
	assert ggshape.draw_sampled_jpeg_clipped(single.data, 130, 130, 532, 1,
		source, 4, 4, 20.375, 22.375, 79.25, 77.25, 1, 16, 16, clip) == 1
	assert ggshape.draw_sampled_jpeg_clipped(multi.data, 130, 130, 532, 1,
		source, 4, 4, 20.375, 22.375, 79.25, 77.25, 4, 16, 16, clip) == 1
	assert single != multi
	mut actual := []u8{len: 130 * 532, init: 173}
	assert document_sampled_png_pixels(actual.data, 130, 130, 532, 1, 29, -9,
		source.data, 4, 4, 16, 16, 6, 20.375, 22.375, 79.25, 77.25, &clip[0]) == 1
	swap_document_raster_channels(actual.data, 130, 130, 532)
	for y in 0 .. 130 {
		for x in 0 .. 133 {
			for c in 0 .. 4 {
				i := y * 532 + x * 4 + c
				if x < 2 || y < 2 || x >= 128 || y >= 128 {
					assert actual[i] == 173
				} else {
					expected := if (x >= 65) != (y >= 65) { multi[i] } else { single[i] }
					assert actual[i] == expected, 'pixel ${x},${y},${c}'
				}
			}
		}
	}
}

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
		29, -9, source, 4, 4, 20.375, 22.375, 79.25, 77.25, 16, 16, clip, false, false, false) == 1
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
			1, 1, [12]f32{}, false, false, false) == 0
		assert pixels.all(it == 97)
	}
	assert document_sampled_png_pixels(pixels.data, 16, 16, 64, 1, 60, 0,
		[u8(80), 128, 128, 0].data, 1, 1, 1, 1, 3, 0, 0, 16, 16,
		&[12]f32{}[0]) == 0
	assert pixels.all(it == 97)
	assert document_sampled_png_pixels(pixels.data, 16, 16, 64, 1, 60, 0,
		[u8(80), 128, 128, 0].data, 1, 1, 1, 1, 6, 0, 0, 16, 16,
		&[12]f32{}[0]) == 0
	assert pixels.all(it == 97)
}
