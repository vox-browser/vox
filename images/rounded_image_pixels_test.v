module main

import crypto.sha256
import yuv

#flag darwin -DVOX_TEST_ROUNDED_IMAGE_PIXELS

fn C.vox_test_small_rounded_image_pixels(&u8, voidptr, i32, i32, i32, i32) i32

fn test_small_rounded_image_preserves_color_through_the_native_raster_boundary() {
	$if macos {
		mut source := []u8{}
		for y in 0 .. 16 {
			for x in 0 .. 16 {
				source << [u8(35 + x * 11), u8(40 + y * 10), u8(190 - x * 5), u8(255)]
			}
		}
		mut pixels := []u8{len: 16 * 16 * 4}
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 1, 0, 0, 255) == 1
		// Exact colored-avatar crop from Brave; includes all rounded boundaries.
		assert sha256.hexhash(pixels.bytestr()) == 'e7a82e63aadd6a30d875f6c404509f8eac99b7d8d0647b79fe2d61ece26ee868'
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 0, 0, 0, 255) == 0
		assert pixels.all(it == 255)
	}
}

fn test_small_rounded_jpeg_keeps_fractional_color_through_the_native_boundary() {
	$if macos {
		planes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/avatar-jpeg-420.yuv').to_bytes()
		colors := yuv.jpeg_bilinear_colors(planes, 16, 16, true) or { panic('JPEG planes') }
		mut pixels := []u8{len: 16 * 16 * 4}
		assert C.vox_test_small_rounded_image_pixels(pixels.data, colors.data, 1, 1, 0, 255) == 1
		assert sha256.hexhash(pixels.bytestr()) == '34616386a7a1045ce9a2eb5f1cc48ca1f9040987bfea9f9baaccfcd508eda52f'
	}
}

fn test_rounded_images_include_the_chrome_offset_in_native_raster_coordinates() {
	$if macos {
		mut source := []u8{}
		for y in 0 .. 16 {
			for x in 0 .. 16 {
				source << [u8(35 + x * 11), u8(40 + y * 10), u8(190 - x * 5), u8(255)]
			}
		}
		mut pixels := []u8{len: 16 * (16 + 60) * 4}
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 1, 0, 60, 255) == 1
		assert pixels[..60 * 16 * 4].all(it == 255)
		assert sha256.hexhash(pixels[60 * 16 * 4..].bytestr()) == 'e7a82e63aadd6a30d875f6c404509f8eac99b7d8d0647b79fe2d61ece26ee868'
	}
}

fn test_native_rounded_image_retains_the_document_multisample_selection() {
	$if macos {
		previous := document_geometry_grid
		defer { document_geometry_grid = previous }
		document_geometry_grid = DocumentGeometryGrid{ width: 256, height: 256, columns: 1, rows: 2, cells: [i32(0)] }
		assert document_image_sample_count(68, 99, 16, 16) == 4
		assert document_image_sample_count(68, 275, 16, 16) == 1
		assert document_image_sample_count(68, 250, 16, 16) == 0
		source := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/avatar-msaa-source.rgba').to_bytes()
		mut pixels := []u8{len: 16 * 16 * 4}
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 1, 0, 0, 254) == 1
		assert sha256.hexhash(pixels.bytestr()) == '8fd944d7da153d947457ec1f2a78b84173bb1253fdb8f05b939beda2a839834a'
		planes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/avatar-msaa-jpeg.yuv').to_bytes()
		colors := yuv.jpeg_bilinear_colors(planes, 16, 16, true) or { panic('JPEG planes') }
		assert C.vox_test_small_rounded_image_pixels(pixels.data, colors.data, 1, 1, 0, 254) == 1
		assert sha256.hexhash(pixels.bytestr()) == '4a30b8df6df2bfe7218db9bf1b8ec908e6ad09ace36e9215de9075ec4539357f'
	}
}
