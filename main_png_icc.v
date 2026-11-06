module main

import gg
import os
import dom

// PNG iCCP metadata is a zlib stream, decoded by the native PNG profile bridge.
#flag darwin -lz

fn C.native_png_has_icc_profile(bytes &u8, length uint) int
fn C.native_png_icc_channel_marker() int

fn native_png_channel_marker(bitmap &dom.Bitmap_, bytes []u8, chromium bool) int {
	$if macos {
		if chromium && bitmap.native_rows_are_top_down
			&& C.native_png_has_icc_profile(bytes.data, uint(bytes.len)) != 0 {
			return C.native_png_icc_channel_marker()
		}
	}
	return native_bitmap_channel_marker(bitmap, false)
}

fn (mut app BrowserApp) create_local_image_with_profile(image_url string, path string) !gg.Image {
	mut file := os.open(path) or { return app.ctx.create_image(path) }
	prefix := file.read_bytes(144)
	file.close()
	if image_bytes_are_jpegxl(prefix) {
		return app.create_jpegxl_resource_image(app.background_image_bytes(image_url)!)
	}
	if image_bytes_are_avif(prefix) {
		return app.create_avif_resource_image(app.background_image_bytes(image_url)!)
	}
	$if macos {
		if app.ctx.native_rendering && path.to_lower().ends_with('.png')
			&& app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium {
			bytes := app.background_image_bytes(image_url) or { return app.ctx.create_image(path) }
			// ColorSync also interprets PNG gamma/chromaticity metadata without
			// an ICC chunk. Keep file and fetched PNG pixels and tagging alike.
			return app.create_image_from_resource_bytes(image_url, bytes)
		}
	}
	return app.ctx.create_image(path)
}
