module main

import adblock
import gg
import html
import os
import platform

fn test_background_raster_reuses_retained_bytes_across_reads_and_cache_replacement() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	address := 'https://image.test/large.jpg'
	mut app := BrowserApp{}
	body := '\xff\xd8\x00\x01'.repeat(64 * 1024)
	app.retain_navigation_resource(address, persistent_preloaded_resource(PreloadedResource{
		url: address
		body: body
	}))
	retained := app.resource_cache[address].body
	mut caller := platform.new_arena('background raster lookup test')
	defer { caller.release() }
	entry := caller.enter()
	defer { caller.leave(entry) }
	before := caller.usage().used
	for _ in 0 .. 16 {
		view := app.background_image_decode_bytes(address)!
		assert view.data == retained.str
		assert view.len == body.len
		assert view[..4] == [u8(0xff), 0xd8, 0, 1]
	}
	lookup_growth := caller.usage().used - before
	$if prealloc { assert lookup_growth < 128 * 1024 }
	// Script and favicon callers continue to receive independently writable data.
	mut owned := app.background_image_bytes(address)!
	assert owned.data != retained.str
	owned[2] = 3
	view := app.background_image_decode_bytes(address)!
	assert view[2] == 0
	app.retain_navigation_resource(address, persistent_preloaded_resource(PreloadedResource{
		url: address
		body: '\xff\xd8\x02\x01'
	}))
	replacement := app.background_image_decode_bytes(address)!
	assert replacement.data != view.data
	assert replacement == [u8(0xff), 0xd8, 2, 1]
	assert view[..4] == [u8(0xff), 0xd8, 0, 1]
}

fn test_background_raster_copies_short_lived_resource_bytes() {
	filtering := adblock.is_enabled()
	adblock.set_enabled(false)
	defer { adblock.set_enabled(filtering) }
	address := 'https://image.test/temporary.png'
	mut app := BrowserApp{}
	scratch := platform.begin_thread_scratch('temporary background response test')
	defer { scratch.finish() }
	body := '\x89PNG\x00'.clone()
	scratch.leave()
	app.retain_navigation_resource(address, PreloadedResource{url: address, body: body})
	bytes := app.background_image_decode_bytes(address)!
	assert bytes.data != body.str
	app.resource_cache.delete(address)
	scratch.finish()
	assert bytes == [u8(0x89), `P`, `N`, `G`, 0]
}

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
			app.retain_navigation_resource(address, persistent_preloaded_resource(PreloadedResource{
				url:                               address
				body:                              bytes.bytestr()
				bytes_available_before_completion: delivered_prefix
			}))
			body := app.background_image_decode_bytes(address)!
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
