module main

import gg
import html
import os

fn test_canonical_srgb_webp_preserves_straight_decoder_rows_and_borrowed_paint_rows() {
	$if !macos { return }
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-alpha-tagged.webp'))!
	bitmap := browser_decode_raster_image_bytes(bytes)!
	assert bitmap.native_rows_are_top_down && bitmap.width == 4 && bitmap.height == 2
	assert bitmap.data == [u8(254), 128, 1, 128, 23, 57, 91, 137, 0, 255, 64, 100,
		255, 255, 255, 255, 119, 61, 201, 39, 87, 253, 7, 229, 0, 0, 0, 0, 32, 64, 128, 255]
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
	path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-alpha-tagged.webp')
	local := app.create_local_image_with_profile('file://${path}', path)!
	fetched := app.create_image_from_resource_bytes(path, bytes)!
	assert local.nr_channels == 7 && fetched.nr_channels == 7
	assert unsafe { (&u8(local.data)).vbytes(32) } == unsafe { (&u8(fetched.data)).vbytes(32) }
	assert unsafe { (&u8(fetched.data)).vbytes(32) } == chromium_webp_paint_pixels(bitmap.data)
	upload := app.sampled_lossless_webp_decode(path, &fetched, 76, 38) or { panic('missing sRGB upload') }
	assert upload.id == fetched.id && voidptr(upload.data) == voidptr(fetched.data)
	assert app.sampled_lossless_webp_decode(path, &fetched, 2, 1) == none
	assert app.sampled_lossless_webp_decode(path, &fetched, 4097, 40) == none
}

fn test_non_srgb_webp_retains_the_color_managed_decoder_and_paint_path() {
	$if !macos { return }
	mut bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-alpha-tagged.webp'))!
	// Change the rXYZ tag's first coordinate, not a description or hash.
	bytes[38 + 460 + 9] ^= 32
	assert !chromium_webp_premultiplies_at_decode(bytes)
	bitmap := browser_decode_raster_image_bytes(bytes)!
	assert bitmap.width == 4 && bitmap.height == 2 && bitmap.data.len == 32
	mut document := html.parse_document('<!doctype html>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
	image := app.create_image_from_resource_bytes('non-srgb.webp', bytes)!
	assert image.nr_channels == 6
	assert unsafe { (&u8(image.data)).vbytes(32) } == bitmap.data
}
