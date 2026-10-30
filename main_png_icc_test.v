module main

import dom
import gg
import html
import os

fn test_native_local_icc_png_uses_the_resource_decoder() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><p>ICC image</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{
		ctx:      gg.new_context(native_rendering: true)
		document: document
	}
	path := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/icc-matrix-p3.png')
	address := 'file://${path}'
	bytes := os.read_bytes(path)!
	assert C.native_png_has_icc_profile(bytes.data, uint(bytes.len)) == 1
	assert !browser_raster_can_share_native_pixels(bytes)
	image := app.background_image_uncached(address) or { panic('missing ICC image') }
	assert image.ok
	assert image.path == ''
	assert C.native_png_icc_channel_marker() == 11
	assert image.nr_channels == 11
	assert image.width == 128 && image.height == 80
	pixels := unsafe { (&u8(image.data)).vbytes(4) }
	// Painting owns a separate converted raster; the decoded source stays raw.
	assert pixels == [u8(240), 40, 40, 255]
	decoded := browser_decoded_image_data(dom.URL{ value: address }, bytes)!
	frame := decoded.frame(0) or { panic('missing ICC frame') }
	assert !frame.bitmap().native_resource_replay_compatible
	assert native_png_channel_marker(frame.bitmap(), bytes, false) == 6
	plain := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/icc-matrix-untagged.png'))!
	assert native_png_channel_marker(frame.bitmap(), plain, true) == 6
}
