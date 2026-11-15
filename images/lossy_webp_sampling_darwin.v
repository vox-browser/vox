module main

import crypto.sha256
import gg
import layout
import math
import painting
import platform
import yuv

fn lossy_webp_sampling_dimensions_match(bytes []u8, width int, height int) bool {
	// A simple VP8 key frame carries its 14-bit dimensions in its frame header.
	// Check them before allocating a second decoder's plane buffers.
	return bytes.len >= 30 && bytes[..4].bytestr() == 'RIFF'
		&& bytes[8..16].bytestr() == 'WEBPVP8 ' && bytes[20] & 1 == 0
		&& bytes[23..26] == [u8(0x9d), 1, 0x2a]
		&& (int(bytes[26]) | (int(bytes[27]) << 8)) & 0x3fff == width
		&& (int(bytes[28]) | (int(bytes[29]) << 8)) & 0x3fff == height
}

fn (mut app BrowserApp) sampled_lossy_webp_decode(url string, image &gg.Image,
	width int, height int) ?&gg.Image {
	if image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.height <= 0 || image.width > 4096 || image.height > 4096
		|| image.width * image.height > 4 * 1024 * 1024
		|| image.width % 2 != 0 || image.height % 2 != 0
		|| !((width == image.width && height == image.height)
			|| (width == image.width / 2 && height == image.height / 2)) {
		return none
	}
	bytes := app.background_image_bytes(url) or { return none }
	if !lossy_webp_sampling_dimensions_match(bytes, image.width, image.height)
		|| !app.webp_complete_yuv_allowed(url, bytes) {
		return none
	}
	key := '\x00sampled-lossy-webp:${u64(voidptr(app.document))}:${app.navigation_generation}:${png_decode_scope.scope}:${url}:${sha256.hexhash(bytes.bytestr())}:${width}x${height}'
	if id := app.background_image_ids[key] {
		previous := app.ctx.get_cached_image_by_idx(id)
		if previous.ok && previous.width == width && previous.height == height { return previous }
	}
	mut scratch := platform.begin_thread_scratch('Lossy WebP plane sampling and color conversion')
	defer { scratch.finish() }
	mut w, mut h, mut size := 0, 0, 0
	planes := C.native_decode_webp_yuv(bytes.data, uint(bytes.len), &w, &h, &size)
	if planes == unsafe { nil } { return none }
	defer { C.native_free_webp_pixels(planes) }
	if w != image.width || h != image.height { return none }
	colors := yuv.webp_sampled_colors(unsafe { planes.vbytes(size) }, w, h, width, height) or { return none }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	retained := colors.clone()
	mut result := gg.Image{
		width:       width
		height:      height
		nr_channels: int(C.native_float_image_channel_marker())
		ok:          true
		data:        retained.data
	}
	result.id = app.ctx.cache_image(result)
	app.background_image_ids[key.clone()] = result.id
	return app.ctx.get_cached_image_by_idx(result.id)
}

fn (mut app BrowserApp) draw_sampled_lossy_webp(command &layout.PaintCommand,
	image &gg.Image, url string, destination painting.IntRect, source [4]f32,
	clip [12]f32, matrix [6]f64, page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	offset_x := page_x + f32(matrix[4])
	offset_y := page_y + f32(matrix[5]) - f32(scroll_y)
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| !math.is_finite(offset_x) || !math.is_finite(offset_y)
		|| offset_x != math.floor(offset_x) || offset_y != math.floor(offset_y)
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	decoded := app.sampled_lossy_webp_decode(url, image, destination.width,
		destination.height) or { return false }
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	// The planes have already been sampled at the destination pixel centers.
	// Transfer floating RGB one-to-one so clip coverage precedes byte rounding.
	return C.native_draw_sampled_png(decoded.data, i32(decoded.width), i32(decoded.height),
		i32(decoded.width), i32(decoded.height), 2, f32(destination.x) + f32(matrix[4]),
		f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height),
		&clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
}
