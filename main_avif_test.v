module main

import dom
import gg
import os

fn avif_test_bytes(name string) []u8 {
	return os.read_bytes(os.join_path(@DIR, 'Tests/Browser/Brave/resources/avif', name)) or { panic(err) }
}

fn test_avif_decoding_uses_bytes_even_for_jpeg_resource_urls() {
	$if macos { assert C.vox_avif_available() != 0 }
	if C.vox_avif_available() == 0 { return }
	for name in ['slate-hero.jpeg', 'slate-card.jpeg'] {
		bytes := avif_test_bytes(name)
		assert image_bytes_are_avif(bytes)
		decoded := browser_decoded_image_data(dom.URL{value: 'https://images.test/${name}'}, bytes)!
		frame := decoded.frame(0) or { panic('missing AVIF frame') }
		bitmap := frame.bitmap()
		assert bitmap.width == if name == 'slate-hero.jpeg' { 585 } else { 390 }
		assert bitmap.height == if name == 'slate-hero.jpeg' { 390 } else { 260 }
		assert bitmap.pitch == bitmap.width * 4 && bitmap.native_rows_are_top_down
	}
	for bytes in [[]u8{}, 'RIFF0000WEBP'.bytes(), [u8(0xff), 0xd8, 0xff], '0000ftypmp42'.bytes()] {
		assert !image_bytes_are_avif(bytes)
	}
}

fn test_avif_model_rows_and_native_paint_keep_their_alpha_conventions() {
	if C.vox_avif_available() == 0 { return }
	bytes := avif_test_bytes('alpha.avif')
	model := browser_decode_raster_image_bytes(bytes)!
	assert model.width == 32 && model.height == 16 && model.pitch == 128
	assert model.native_rows_are_top_down
	paint := browser_avif_bitmap(bytes, true)!
	for x in 0 .. 32 {
		alpha := [u8(0), 64, 128, 255][x / 8]
		assert model.data[x * 4 + 3] == alpha && paint.data[x * 4 + 3] == alpha
		assert model.data[x * 4 + 2] > model.data[x * 4]
		for c in 0 .. 3 { assert paint.data[x * 4 + c] <= alpha }
	}
	$if macos {
		mut app := BrowserApp{ctx: gg.new_context(native_rendering: true)}
		image := app.create_image_from_resource_bytes('https://images.test/photo.jpeg', bytes)!
		assert image.width == 32 && image.height == 16 && image.nr_channels == 7
		assert image.path == ''
		cached := app.ctx.get_cached_image_by_idx(image.id)
		assert unsafe { (&u8(cached.data)).vbytes(paint.data.len) } == paint.data
		path := os.join_path(os.temp_dir(), 'vox-avif-${os.getpid()}.jpeg')
		os.write_file_array(path, bytes)!
		defer { os.rm(path) or {} }
		local := app.create_local_image_with_profile('file://${path}', path)!
		assert local.width == 32 && local.height == 16 && local.nr_channels == 7
	}
}

fn test_avif_incomplete_and_unsupported_images_fail_without_a_bitmap() {
	if C.vox_avif_available() == 0 { return }
	for bytes in [avif_test_bytes('animated.avif'), avif_test_bytes('oversize.avif'),
		avif_test_bytes('icc.avif'), avif_test_bytes('red.avif')[..20]] {
		_ := browser_decode_raster_image_bytes(bytes) or { continue }
		assert false, 'Unsupported AVIF returned bitmap data'
	}
}
