module main

import gg
import html
import os

fn test_srgb_table_webp_keeps_raw_decoder_rows_without_enabling_planar_uploads() {
	$if !macos { return }
	path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572')
	bytes := os.read_bytes(path)!
	bitmap := browser_decode_raster_image_bytes(bytes)!
	mut width, mut height, mut pitch := 0, 0, 0
	raw := C.native_decode_webp_raw_rgba(bytes.data, uint(bytes.len), &width, &height, &pitch)
	assert raw != unsafe { nil }
	defer { C.native_free_webp_pixels(raw) }
	assert width == 480 && height == 270 && pitch == 1920
	assert bitmap.native_rows_are_top_down && bitmap.data == unsafe { raw.vbytes(pitch * height) }
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
	image := app.create_image_from_resource_bytes(path, bytes)!
	assert image.nr_channels == 7
	assert unsafe { (&u8(image.data)).vbytes(bitmap.data.len) } == bitmap.data
	assert profiled_webp_sampling_supported(bytes, &image)
	assert app.sampled_lossless_webp_decode(path, &image, 480, 270) == none
	assert app.sampled_lossy_webp_decode(path, &image, 480, 270) == none
	for mode in 0 .. 4 {
		mut invalid := image
		match mode {
			0 { invalid.nr_channels = 6 }
			1 { invalid.width++ }
			2 { invalid.height++ }
			else { invalid.path = 'native-file' }
		}
		assert !profiled_webp_sampling_supported(bytes, &invalid)
	}
}
