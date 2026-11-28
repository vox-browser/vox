module cpuraster

import os

fn test_large_bilinear_resizes_match_serial() {
	const_control := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(const_control)
	defer {
		if value := previous {
			os.setenv(const_control, value, true)
		} else {
			os.unsetenv(const_control)
		}
	}

	source_width, source_height := 997, 701
	width, height := 1031, 559
	for format in [ImageResizeFormat.rgba, .r8, .gray8] {
		channels := if format == .rgba { 4 } else { 1 }
		mut source := []u8{len: source_width * source_height * channels}
		for y in 0 .. source_height {
			for x in 0 .. source_width {
				offset := (y * source_width + x) * channels
				alpha := (x * 43 + y * 91) & 255
				source[offset] = u8(alpha)
				if format == .rgba {
					source[offset] = u8(((x * 59 + y * 17) & 255) * alpha / 255)
					source[offset + 1] = u8(((x * 13 + y * 29) & 255) * alpha / 255)
					source[offset + 2] = u8(((x * 79 + y * 19) & 255) * alpha / 255)
					source[offset + 3] = u8(alpha)
				}
			}
		}
		original := source.clone()
		assert os.setenv(const_control, '1', true) == 0
		serial := resize_image_pixels(source, source_width, source_height, width, height, format) or {
			panic('serial resize failed')
		}
		assert os.unsetenv(const_control) == 0
		parallel := resize_image_pixels(source, source_width, source_height, width, height, format) or {
			panic('parallel resize failed')
		}
		pixels_match := parallel == serial
		source_unchanged := source == original
		assert pixels_match, '${format} resize pixels differ'
		assert source_unchanged
	}
}

fn test_large_mipmap_chain_matches_serial_with_padded_odd_source() {
	const_control := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(const_control)
	defer {
		if value := previous {
			os.setenv(const_control, value, true)
		} else {
			os.unsetenv(const_control)
		}
	}

	width, height := 1801, 1321
	pitch := width * 4 + 11
	source := []u8{len: pitch * height, init: u8((index * 19 + index / pitch * 47) & 255)}
	bitmap := CanvasBitmap{
		pixels:        source
		width:         width
		height:        height
		pitch:         pitch
		premultiplied: true
		display_p3:    true
	}
	original := source.clone()
	for level in [1, 2] {
		assert os.setenv(const_control, '1', true) == 0
		serial := build_image_mipmap(bitmap, level) or { panic('serial mipmap failed') }
		assert os.unsetenv(const_control) == 0
		parallel := build_image_mipmap(bitmap, level) or { panic('parallel mipmap failed') }
		assert parallel.width == width >> level
		assert parallel.height == height >> level
		assert parallel.pitch == parallel.width * 4
		assert parallel.premultiplied && parallel.display_p3
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match, 'mipmap pixels differ at level ${level}'
	}
	source_unchanged := source == original
	assert source_unchanged
}
