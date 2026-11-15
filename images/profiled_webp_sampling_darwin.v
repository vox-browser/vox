module main

import gg
import crypto.sha256
import imageraster
import layout
import math
import os
import painting
import platform

// Profiled VP8 uses Chromium's RGB decode path even when its color space
// canonicalizes to sRGB. Upload selection must also preserve a larger decode
// already used in this raster scope.
fn profiled_webp_sampling_supported(bytes []u8, image &gg.Image) bool {
	if image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.height <= 0 || image.width > 4096 || image.height > 4096
		|| image.width * image.height > 4 * 1024 * 1024
		|| !imageraster.webp_srgb_profile(bytes) || imageraster.webp_lossless_srgb_profile(bytes) {
		return false
	}
	width := 1 + int(bytes[24]) + (int(bytes[25]) << 8) + (int(bytes[26]) << 16)
	height := 1 + int(bytes[27]) + (int(bytes[28]) << 8) + (int(bytes[29]) << 16)
	return image.width == width && image.height == height
}

struct ProfiledWebPUpload {
	image    &gg.Image
	gpu_mips bool
}

fn (mut app BrowserApp) sampled_profiled_webp_decode(url string, image &gg.Image,
	width f64, height f64) ?ProfiledWebPUpload {
	if !math.is_finite(width) || !math.is_finite(height) || width <= 0 || height <= 0
		|| width > 4096 || height > 4096 {
		return none
	}
	bytes := app.background_image_bytes(url) or { return none }
	if !profiled_webp_sampling_supported(bytes, image) { return none }
	mut dw, mut dh := image.width, image.height
	if width < image.width || height < image.height {
		tw, th := imageraster.decode_size(image.width, image.height, width, height) or { return none }
		// An exact half upload preserves the CPU mip's integer averages. Odd
		// rounded uploads and stronger reductions retain their existing path.
		if tw * 2 == image.width && th * 2 == image.height {
			dw, dh = tw, th
		}
	}
	key := '\x00profiled-webp-upload:${u64(voidptr(app.document))}:${app.navigation_generation}:${png_decode_scope.scope}:${url}:${sha256.hexhash(bytes.bytestr())}'
	if id := app.background_image_ids[key] {
		previous := app.ctx.get_cached_image_by_idx(id)
		if previous.ok && previous.data != unsafe { nil }
			&& previous.width >= dw && previous.height >= dh {
			return ProfiledWebPUpload{previous, previous.width == image.width && previous.height == image.height}
		}
	}
	if dw == image.width && dh == image.height {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		app.background_image_ids[key.clone()] = image.id
		return ProfiledWebPUpload{image, true}
	}
	mut scratch := platform.begin_thread_scratch('Profiled WebP half upload')
	defer { scratch.finish() }
	data := imageraster.decode_rgba(unsafe { (&u8(image.data)).vbytes(image.width * image.height * 4) },
		image.width, image.height, dw, dh) or { return none }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	retained := data.pixels.clone()
	mut decoded := gg.Image{ width: dw, height: dh, nr_channels: 5, ok: true, data: retained.data }
	decoded.id = app.ctx.cache_image(decoded)
	app.background_image_ids[key.clone()] = decoded.id
	return ProfiledWebPUpload{app.ctx.get_cached_image_by_idx(decoded.id), false}
}

fn (mut app BrowserApp) draw_profiled_webp(command &layout.PaintCommand, image &gg.Image,
	url string, destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| destination.width <= 0 || destination.height <= 0
		|| destination.width > 4096 || destination.height > 4096
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	upload := app.sampled_profiled_webp_decode(url, image, destination.width, destination.height) or { return false }
	decoded := upload.image
	mut clipping := clip
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	if os.getenv('VOX_DIAGNOSTIC_PNG') != '' {
		eprintln('VOX_PROFILED_WEBP ${image.width}x${image.height}->${decoded.width}x${decoded.height} gpu_mips=${upload.gpu_mips} dest=${destination.x},${destination.y},${destination.width},${destination.height}')
	}
	return C.native_draw_sampled_png(decoded.data, i32(decoded.width), i32(decoded.height),
		i32(image.width), i32(image.height), i32(upload.gpu_mips), f32(destination.x) + f32(matrix[4]),
		f32(destination.y) + f32(matrix[5]), f32(destination.width), f32(destination.height),
		&clipping[0], page_x, page_y, f32(scroll_y), f32(app.ctx.width), f32(app.ctx.height)) != 0
}
