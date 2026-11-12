module main

import crypto.sha256
import gg
import platform
import yuv

// Unscaled rounded JPEG draws use Chromium's image-shader path, whose chroma
// samples differ from a direct libjpeg RGB image. Keep the ordinary image and
// decoder for other draws; this cached paint variant owns its own pixels.
fn (mut app BrowserApp) rounded_jpeg_paint_image(image_url string) ?&gg.Image {
	$if macos {
		if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium {
			return none
		}
		bytes := app.background_image_bytes(image_url) or { return none }
		if bytes.len < 4 || bytes[0] != 0xff || bytes[1] != 0xd8 || bytes[2] != 0xff { return none }
		// Retained bitmap wrappers have no cache ID. Sniff before lookup so a
		// non-JPEG can never reuse a photographic paint variant. Content identity
		// also invalidates this variant when a resource changes at the same URL.
		key := '\x00rounded-jpeg-bilinear:${sha256.hexhash(bytes.bytestr())}'
		if id := app.background_image_ids[key] { return app.ctx.get_cached_image_by_idx(id) }
		mut w, mut h, mut size, mut sampling := 0, 0, 0, 0
		planes := C.native_decode_jpeg_yuv(bytes.data, uint(bytes.len), &w, &h, &size, &sampling)
		if planes == unsafe { nil } { return none }
		defer { C.native_free_jpeg_pixels(planes) }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		data := yuv.jpeg_bilinear_rgba(unsafe { planes.vbytes(size) }, w, h, sampling == 2) or { return none }
		mut image := gg.Image{ width: w, height: h, nr_channels: 6, ok: true, data: data.data }
		image.id = app.ctx.cache_image(image)
		app.background_image_ids[key.clone()] = image.id
		return app.ctx.get_cached_image_by_idx(image.id)
	} $else {
		return none
	}
}
