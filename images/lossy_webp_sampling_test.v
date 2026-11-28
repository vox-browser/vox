module main

import gg
import html
import os
import platform

fn test_lossy_webp_sampling_checks_dimensions_before_decoding() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-texture.webp'))!
		assert lossy_webp_sampling_dimensions_match(bytes, 140, 94)
		assert !lossy_webp_sampling_dimensions_match(bytes, 138, 94)
		assert !lossy_webp_sampling_dimensions_match(bytes, 140, 92)
		for end in 0 .. 30 {
			assert !lossy_webp_sampling_dimensions_match(bytes[..end], 140, 94)
		}
		mut other := bytes.clone()
		other[23] = 0
		assert !lossy_webp_sampling_dimensions_match(other, 140, 94)
	}
}

fn test_lossy_webp_upload_owns_fractional_colors_and_separates_sizes_and_scopes() {
	$if macos {
		if C.native_webp_yuv_decoder_available() == 0 { return }
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
		path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-texture.webp')
		bytes := app.background_image_bytes(path)!
		image := app.create_image_from_resource_bytes(path, bytes)!
		assert image.width == 140 && image.height == 94 && image.nr_channels == 7
		previous := png_decode_scope.scope
		defer { set_chromium_image_decode_scope(previous) }
		set_chromium_image_decode_scope(0)
		cached := app.sampled_lossy_webp_decode(path, &image, 140, 94) or { panic('native upload') }
		assert cached.width == 140 && cached.height == 94
		assert cached.nr_channels == int(C.native_float_image_channel_marker())
		expected := unsafe { (&u8(cached.data)).vbytes(140 * 94 * 4 * int(sizeof(f32))).clone() }
		mut scratch := platform.begin_thread_scratch('lossy WebP upload ownership regression')
		_ = []u8{len: 1024 * 1024, init: 197}
		scratch.finish()
		assert unsafe { (&u8(cached.data)).vbytes(expected.len) } == expected
		assert (app.sampled_lossy_webp_decode(path, &image, 140, 94) or { panic('reuse') }).id == cached.id
		half := app.sampled_lossy_webp_decode(path, &image, 70, 47) or { panic('half upload') }
		assert half.width == 70 && half.height == 47 && half.id != cached.id
		set_chromium_image_decode_scope(1)
		assert (app.sampled_lossy_webp_decode(path, &image, 140, 94) or { panic('separate scope') }).id != cached.id
		assert app.sampled_lossy_webp_decode(path, &image, 100, 67) == none
		assert app.sampled_lossy_webp_decode(path, &image, 280, 188) == none
		// A historical incremental-RGB selection must not be bypassed by cache reuse.
		app.retain_navigation_resource(path, PreloadedResource{ url: path, body: bytes.bytestr(), bytes_available_before_completion: 30 })
		if retain_incremental_webp_paint_policy {
			assert app.sampled_lossy_webp_decode(path, &image, 140, 94) == none
		}
	}
}
