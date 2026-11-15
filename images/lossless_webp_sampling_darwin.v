module main

import crypto.sha256
import gg
import imageraster
import layout
import math
import painting
import platform

// Simple VP8L streams have no color profile or animation. Alpha is bit 28;
// bits 29..31 encode the format version.
fn lossless_webp_sampling_supported(bytes []u8) bool {
	return bytes.len >= 25 && bytes[..4].bytestr() == 'RIFF'
		&& bytes[8..16].bytestr() == 'WEBPVP8L' && bytes[20] == 0x2f
		&& bytes[24] & 0xe0 == 0
}

fn opaque_lossless_webp_sampling_supported(bytes []u8) bool {
	return lossless_webp_sampling_supported(bytes) && bytes[24] & 0x10 == 0
}

fn (mut app BrowserApp) sampled_lossless_webp_decode(url string, image &gg.Image,
	width f64, height f64) ?&gg.Image {
	if image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.height <= 0 || image.width > 4096 || image.height > 4096
		|| image.width * image.height > 4 * 1024 * 1024
		|| !math.is_finite(width) || !math.is_finite(height) || width <= 0 || height <= 0 {
		return none
	}
	bytes := app.background_image_bytes(url) or { return none }
	if !lossless_webp_sampling_supported(bytes) { return none }
	if width >= image.width && height >= image.height {
		if width > 4096 || height > 4096 { return none }
		// Marker 7 already owns libwebp-style premultiplied rows. Sample them
		// directly, including alpha; premultiplying again darkens edge colors.
		return image
	}
	// The existing resize path takes straight, opaque input. Alpha minification
	// needs its own verified filtering path instead of another multiplication.
	if !opaque_lossless_webp_sampling_supported(bytes) { return none }
	dw, dh := imageraster.decode_size(image.width, image.height, width, height) or { return none }
	key := '\x00sampled-lossless-webp:${u64(voidptr(app.document))}:${app.navigation_generation}:${png_decode_scope.scope}:${url}:${sha256.hexhash(bytes.bytestr())}'
	if id := app.background_image_ids[key] {
		previous := app.ctx.get_cached_image_by_idx(id)
		if previous.ok && previous.width >= dw && previous.height >= dh { return previous }
	}
	mut scratch := platform.begin_thread_scratch('Opaque lossless WebP upload resize')
	defer { scratch.finish() }
	// Opaque rows need no second alpha multiplication before filtering.
	source := unsafe { (&u8(image.data)).vbytes(image.width * image.height * 4) }
	for offset := 3; offset < source.len; offset += 4 {
		if source[offset] != 255 { return none }
	}
	data := imageraster.decode_rgba(source, image.width, image.height, dw, dh) or { return none }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	retained := data.pixels.clone()
	mut result := gg.Image{ width: data.width, height: data.height, nr_channels: 5, ok: true, data: retained.data }
	result.id = app.ctx.cache_image(result)
	app.background_image_ids[key.clone()] = result.id
	return app.ctx.get_cached_image_by_idx(result.id)
}

fn (mut app BrowserApp) draw_sampled_lossless_webp(command &layout.PaintCommand,
	image &gg.Image, url string, destination painting.IntRect, source [4]f32,
	clip [12]f32, matrix [6]f64, page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	decoded := app.sampled_lossless_webp_decode(url, image, f64(destination.width),
		f64(destination.height)) or { return false }
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	return C.native_draw_sampled_png(decoded.data, i32(decoded.width), i32(decoded.height),
		i32(image.width), i32(image.height), 0, f32(destination.x) + f32(matrix[4]),
		f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height),
		&clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
}
