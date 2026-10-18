module main

import encoding.base64
import gg
import html
import os

fn test_network_webp_paint_keeps_its_decoded_rgba_frame() {
	$if macos {
		markup := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/webp-yuv.html'))!
		encoded := markup.all_after('base64,').all_before('"')
		bytes := base64.decode(encoded)
		decoded := browser_decode_raster_image_bytes(bytes)!
		mut document := html.parse_document('<!doctype html>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		mut app := BrowserApp{
			document: document
			ctx:      gg.new_context(native_rendering: true)
		}
		image := app.create_image_from_resource_bytes('https://webp.test/streamed.webp', bytes)!
		assert image.nr_channels == 7
		$if gcboehm ? { C.GC_gcollect() }
		cached := app.ctx.get_cached_image_by_idx(image.id)
		assert unsafe { (&u8(cached.data)).vbytes(decoded.data.len) } == decoded.data
		if C.native_webp_yuv_paint_supported() != 0 {
			atomic_image := app.create_image_from_resource_bytes('data:image/webp;base64,${encoded}',
				bytes)!
			assert atomic_image.nr_channels == 8
		}
	}
}
