module main

import gg
import html
import os
import platform

fn test_opaque_lossless_webp_sampling_rejects_other_formats_and_alpha() {
	$if macos {
		mut bytes := []u8{len: 25}
		for i, v in 'RIFF'.bytes() { bytes[i] = v }
		for i, v in 'WEBPVP8L'.bytes() { bytes[i + 8] = v }
		bytes[20] = 0x2f
		assert opaque_lossless_webp_sampling_supported(bytes)
		assert !opaque_lossless_webp_sampling_supported(bytes[..24])
		for flag in [u8(16), 32, 64, 128] {
			mut other := bytes.clone()
			other[24] = flag
			assert !opaque_lossless_webp_sampling_supported(other)
		}
		for kind in ['VP8 ', 'VP8X'] {
			mut other := bytes.clone()
			for i, v in kind.bytes() { other[i + 12] = v }
			assert !opaque_lossless_webp_sampling_supported(other)
		}
	}
}

fn test_lossless_webp_upload_keeps_owned_pixels_and_decode_scope() {
	$if macos {
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
		fixture := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/webp-rgba-mip-blend.html'))!
		address := fixture.all_after('src="').all_before('"')
		bytes := app.background_image_bytes(address)!
		image := app.create_image_from_resource_bytes(address, bytes)!
		assert image.width == 960 && image.height == 540 && image.nr_channels == 7
		previous := png_decode_scope.scope
		defer { set_chromium_image_decode_scope(previous) }
		set_chromium_image_decode_scope(0)
		cached := app.sampled_lossless_webp_decode(address, &image, 320, 180) or { panic('upload') }
		assert cached.width == 480 && cached.height == 270
		expected := unsafe { (&u8(cached.data)).vbytes(480 * 270 * 4).clone() }
		mut scratch := platform.begin_thread_scratch('lossless WebP cache ownership regression')
		_ = []u8{len: 1024 * 1024, init: 197}
		scratch.finish()
		assert unsafe { (&u8(cached.data)).vbytes(expected.len) } == expected
		assert (app.sampled_lossless_webp_decode(address, &image, 240, 135) or { panic('reuse') }).id == cached.id
		set_chromium_image_decode_scope(1)
		separate := app.sampled_lossless_webp_decode(address, &image, 240, 135) or { panic('separate scope') }
		assert separate.width == 240 && separate.height == 135 && separate.id != cached.id
		assert app.sampled_lossless_webp_decode(address, &image, 960, 540) == none
	}
}
