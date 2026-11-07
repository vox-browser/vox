module main

import os
import dom
import gg

fn jpegxl_test_bytes(name string) []u8 {
	return os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', name)) or { panic(err) }
}

fn test_jpegxl_sniffing_uses_codestream_and_container_signatures() {
	assert image_bytes_are_jpegxl(jpegxl_test_bytes('rgba.jxl'))
	assert image_bytes_are_jpegxl(jpegxl_test_bytes('rgba-container.jxl'))
	for bytes in [[]u8{}, [u8(0xff)], [u8(0xff), 0xd8, 0xff], 'GIF89a'.bytes(),
		[u8(0), 0, 0, 12, 0x4a, 0x58, 0x4c, 0x20, 13, 10, 0x87]] {
		assert !image_bytes_are_jpegxl(bytes)
	}
}

fn test_jpegxl_model_decode_keeps_exact_alpha_orientation_and_top_down_rows() {
	$if macos {
		assert C.vox_jpegxl_available() != 0
	}
	if C.vox_jpegxl_available() == 0 { return }
	bitmap := browser_decode_raster_image_bytes(jpegxl_test_bytes('rgba.jxl'))!
	assert bitmap.width == 3 && bitmap.height == 2 && bitmap.pitch == 12
	assert bitmap.native_rows_are_top_down
	assert bitmap.data == [u8(255), 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 0, 20, 80, 160, 128,
		250, 200, 100, 255, 255, 255, 255, 255]
	container := browser_decode_raster_image_bytes(jpegxl_test_bytes('rgba-container.jxl'))!
	assert container.data == bitmap.data
	rotated := browser_decode_raster_image_bytes(jpegxl_test_bytes('orientation-6.jxl'))!
	assert rotated.width == 2 && rotated.height == 3 && rotated.pitch == 8
	assert rotated.data[..8] == [u8(20), 80, 160, 128, 255, 0, 0, 255]
	decoded := browser_decoded_image_data(dom.URL{ value: 'https://images.test/photo.jpg' }, jpegxl_test_bytes('rgba.jxl'))!
	frame := decoded.frame(0) or { panic('decoded frame') }
	assert frame.bitmap().data == bitmap.data
	$if macos {
		assert !frame.bitmap().native_resource_replay_compatible
	}
}

fn test_jpegxl_paint_cache_preserves_decoder_premultiplication_before_quantizing() {
	$if macos {
		bytes := jpegxl_test_bytes('rgba.jxl')
		bitmap := browser_decode_raster_image_bytes(bytes)!
		mut app := BrowserApp{ ctx: gg.new_context(native_rendering: true) }
		image := app.create_image_from_resource_bytes('https://images.test/photo.jpg', bytes)!
		assert image.width == 3 && image.height == 2 && image.nr_channels == 7 && image.path == ''
		directory := os.join_path(os.temp_dir(), 'vox-jpegxl-${os.getpid()}')
		os.mkdir_all(directory)!
		defer { os.rmdir_all(directory) or {} }
		path := os.join_path(directory, 'photo.jpg')
		os.write_file_array(path, bytes)!
		local := app.create_local_image_with_profile('file://${path}', path)!
		assert local.width == 3 && local.height == 2 && local.nr_channels == 7 && local.path == ''
		cached := app.ctx.get_cached_image_by_idx(image.id)
		assert unsafe { (&u8(cached.data)).vbytes(bitmap.data.len) } == [u8(255), 0, 0, 255,
			0, 128, 0, 128, 0, 0, 0, 0, 10, 40, 81, 128, 250, 200, 100, 255, 255, 255, 255, 255]
	}
}

fn test_jpegxl_incomplete_and_unsupported_streams_fail_without_bitmap_data() {
	if C.vox_jpegxl_available() == 0 { return }
	for bytes in [jpegxl_test_bytes('animated.jxl'), jpegxl_test_bytes('wide-gamut.jxl'),
		jpegxl_test_bytes('rgba.jxl')[..5], [u8(0xff), 0x0a]] {
		_ := browser_decode_raster_image_bytes(bytes) or { continue }
		assert false, 'Unsupported or truncated JPEG XL was decoded'
	}
}
