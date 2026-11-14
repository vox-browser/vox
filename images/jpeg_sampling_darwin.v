module main

import crypto.sha256
import gg
import imageraster
import layout
import painting
import platform
import yuv
import os

// The plane-scaling path is limited to small circular minified avatars.
// Other image geometry, color profiles and sampling modes retain replay.
fn (mut app BrowserApp) draw_sampled_jpeg(command &layout.PaintCommand, image &gg.Image, url string,
	destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]!
		|| destination.width != destination.height || destination.width > 32 || destination.width <= 0
		|| image.width < destination.width * 2 || image.height < destination.height * 2
		|| clip[0] != f32(destination.x) || clip[1] != f32(destination.y)
		|| clip[2] != f32(destination.width) || clip[3] != f32(destination.height) {
		return false
	}
	for radius in clip[4..] { if radius != f32(destination.width) * .5 { return false } }
	dw, dh := imageraster.decode_size(image.width, image.height, f64(destination.width), f64(destination.height)) or { return false }
	bytes := app.background_image_bytes(url) or { return false }
	if !yuv.jpeg_plane_orientation_supported(bytes) { return false }
	key := '\x00scaled-jpeg:${sha256.hexhash(bytes.bytestr())}:${dw}x${dh}'
	mut decoded := &gg.Image{}
	if id := app.background_image_ids[key] {
		decoded = app.ctx.get_cached_image_by_idx(id)
	} else {
		mut w, mut h, mut size, mut sampling := 0, 0, 0, 0
		planes := C.native_decode_jpeg_yuv(bytes.data, uint(bytes.len), &w, &h, &size, &sampling)
		if planes == unsafe { nil } { return false }
		defer { C.native_free_jpeg_pixels(planes) }
		if w != image.width || h != image.height { return false }
		pixels := yuv.jpeg_scaled_rgba(unsafe { planes.vbytes(size) }, w, h, dw, dh, sampling == 2) or { return false }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		retained := pixels.clone()
		mut uploaded := gg.Image{ width: dw, height: dh, nr_channels: 6, ok: true, data: retained.data }
		uploaded.id = app.ctx.cache_image(uploaded)
		app.background_image_ids[key.clone()] = uploaded.id
		decoded = app.ctx.get_cached_image_by_idx(uploaded.id)
	}
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	drawn := C.native_draw_sampled_png(decoded.data, i32(dw), i32(dh), i32(image.width), i32(image.height), 0,
		f32(destination.x) + f32(matrix[4]), f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height), &clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
	if drawn && os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_SCALED_JPEG ${image.width}x${image.height}->${dw}x${dh}')
	}
	return drawn
}
