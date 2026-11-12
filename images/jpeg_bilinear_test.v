module main

import crypto.sha256
import gg
import html
import os

fn test_rounded_jpeg_variants_use_content_identity_and_reject_png_after_cache_hit() {
	$if macos {
		mut document := html.parse_document('<!doctype html>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut app := BrowserApp{document: document, ctx: gg.new_context(native_rendering: true)}
		photo := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/avatar-jpeg-source.jpg')
		png := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/avatar-clip-black.png')
		first := app.rounded_jpeg_paint_image(photo) or { panic('JPEG variant missing') }
		id := first.id
		assert first.width == 16 && first.height == 16 && first.nr_channels == 6
		pixels := unsafe { (&u8(first.data)).vbytes(16 * 16 * 4) }
		mut interior := []u8{}
		for y in 3 .. 13 { interior << pixels[(y * 16 + 3) * 4..(y * 16 + 13) * 4] }
		assert sha256.hexhash(interior.bytestr()) == '8f84886ae7dcfda00219977ebc5bc2472585d6e2968e9a1361424660b8229e0f'
		assert app.rounded_jpeg_paint_image(png) == none
		again := app.rounded_jpeg_paint_image(photo) or { panic('cached JPEG variant missing') }
		assert again.id == id
		assert app.background_image_ids.len == 1
	}
}
