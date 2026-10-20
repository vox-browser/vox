module main

import encoding.base64
import gg

$if macos {
	#include "@VMODROOT/tools/native_image_upload_test.h"
	fn C.native_image_test_start_gpu() bool
	fn C.native_image_test_stop_gpu()
}

const asymmetric_raster_png = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR4nGP4z8DwHwSZGME0AwMAPu0F/jV/xAYAAAAASUVORK5CYII='

fn test_raster_decoder_preserves_asymmetric_top_and_bottom_rows_for_native_paint() {
	bitmap := browser_decode_raster_image_bytes(base64.decode(asymmetric_raster_png))!
	assert bitmap.width == 2
	assert bitmap.height == 2
	assert bitmap.pitch == 8
	assert bitmap.data == [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
	assert bitmap.native_rows_are_top_down
	assert native_bitmap_channel_marker(bitmap, false) == 6
	assert native_bitmap_channel_marker(bitmap, true) == 7
	clone := bitmap.clone()
	assert clone.native_rows_are_top_down
	assert clone.data == bitmap.data
}

fn test_native_resource_image_cache_retains_asymmetric_rows_for_actual_image_paint() {
	$if !macos { return }
	mut app := BrowserApp{
		ctx: gg.new_context(native_rendering: true)
	}
	image := app.create_image_from_resource_bytes('https://image-order.test/two-rows.png',
		base64.decode(asymmetric_raster_png))!
	assert image.width == 2
	assert image.height == 2
	assert image.nr_channels == 6
	cached := app.ctx.get_cached_image_by_idx(image.id)
	assert cached.nr_channels == 6
	assert cached.data == image.data
	pixels := unsafe { (&u8(cached.data)).vbytes(16) }
	// The top-left red and bottom-left blue pixels must reach native paint in
	// that order. A symmetric one-pixel decode cannot catch a vertical flip.
	assert pixels[0..4] == [u8(255), 0, 0, 255]
	assert pixels[8..12] == [u8(0), 0, 255, 255]
	assert app.ctx.pipeline == unsafe { nil }
}

fn test_native_byte_images_do_not_create_unused_sokol_textures() {
	$if macos {
		assert C.native_image_test_start_gpu()
		defer { C.native_image_test_stop_gpu() }
		mut app := BrowserApp{ctx: gg.new_context(native_rendering: true)}
		for _ in 0 .. 4 {
			image := app.create_image_from_resource_bytes('data:image/png;base64,' + asymmetric_raster_png,
				base64.decode(asymmetric_raster_png))!
			assert image.ok && image.nr_channels == 6
			assert image.simg.id == 0 && image.ssmp.id == 0 && !image.simg_ok
			cached := app.ctx.get_cached_image_by_idx(image.id)
			assert cached.simg.id == 0 && cached.ssmp.id == 0
			assert unsafe { (&u8(cached.data)).vbytes(4) } == [u8(255), 0, 0, 255]
		}
	}
}
