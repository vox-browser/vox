module main

import adblock
import gg
import html
import os

fn test_first_webp_paint_uses_the_complete_body_after_chunked_transport() {
	$if macos {
		if C.native_webp_yuv_paint_supported() == 0 {
			eprintln('SKIP: native Skia image painting unavailable')
			return
		}
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-texture.webp'))!
		address := 'https://webp.test/stream.webp'
		mut document := html.parse_document('<!doctype html>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
		mut first_planes := []u8{}
		for delivered_prefix in [u64(0), 30, u64(bytes.len / 2)] {
			app.retain_navigation_resource(address, PreloadedResource{
				url:                               address
				body:                              bytes.bytestr()
				bytes_available_before_completion: delivered_prefix
			})
			body := app.background_image_bytes(address)!
			image := app.create_image_from_resource_bytes(address, body)!
			assert image.nr_channels == 8
			assert image.width == 140 && image.height == 94
			planes := unsafe { (&u8(image.data)).vbytes(140 * 94 + 2 * 70 * 47) }
			if delivered_prefix == 0 { first_planes = planes.clone() }
			assert planes == first_planes
		}
	}
}

fn test_complete_webp_publication_keeps_an_existing_rgb_paint_image() {
	$if macos {
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/decode-texture.webp'))!
		address := 'https://webp.test/retained.webp'
		mut document := html.parse_document('<!doctype html>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		bitmap := browser_decode_raster_image_bytes(bytes)!
		mut app := BrowserApp{ document: document, ctx: gg.new_context(native_rendering: true) }
		// A paint image that really exists must survive completion; network
		// delivery metadata alone must never invent this retained RGB state.
		rgb := gg.Image{
			width:       bitmap.width
			height:      bitmap.height
			nr_channels: 6
			ok:          true
			data:        bitmap.data.data
		}
		id := app.ctx.cache_image(rgb)
		key := document.url.serialize() + '\n' + adblock.is_enabled().str() + '\n' + address
		app.background_image_ids[key] = id
		app.retain_navigation_resource(address, PreloadedResource{
			url:                               address
			body:                              bytes.bytestr()
			bytes_available_before_completion: 128
		})
		retained := app.background_image_uncached(address) or { panic('missing cached image') }
		assert retained.id == id && retained.nr_channels == 6
		assert unsafe { (&u8(retained.data)).vbytes(bitmap.data.len) } == bitmap.data
	}
}
