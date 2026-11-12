module main

import crypto.sha256
import gg
import ggshape
import imageraster
import layout
import painting
import platform

fn C.native_draw_sampled_png(&u8, i32, i32, i32, i32, i32, f32, f32, f32, f32, &f32, f32, f32, f32, f32, f32) i32

struct SampledPNGUpload {
	image    &gg.Image
	gpu_mips bool
}

struct PngDecodeScope {
mut:
	scope int
}

const png_decode_scope = &PngDecodeScope{}

// Unsupported color spaces and animations retain the existing decoder.
fn png_sampling_bytes_supported(bytes []u8) bool {
	_ := imageraster.png_sampling_profile(bytes) or { return false }
	return true
}

fn (mut app BrowserApp) sampled_png_decode(url string, image &gg.Image, width f64, height f64) ?SampledPNGUpload {
	if image.path != '' || image.nr_channels != 6 || image.data == unsafe { nil } { return none }
	dw, dh := imageraster.decode_size(image.width, image.height, width, height) or { return none }
	bytes := app.background_image_bytes(url) or { return none }
	profile := imageraster.png_sampling_profile(bytes) or { return none }
	key := '\x00sampled-png:${u64(voidptr(app.document))}:${app.navigation_generation}:${png_decode_scope.scope}:${url}:${sha256.hexhash(bytes.bytestr())}'
	if id := app.background_image_ids[key] {
		previous := app.ctx.get_cached_image_by_idx(id)
		if previous.ok && previous.width >= dw && previous.height >= dh {
			return SampledPNGUpload{ image: previous, gpu_mips: profile.gamma > 0 }
		}
	}
	mut scratch := platform.begin_thread_scratch('PNG upload resize and color conversion')
	defer { scratch.finish() }
	data := imageraster.decode_rgba(unsafe { (&u8(image.data)).vbytes(image.width * image.height * 4) },
		image.width, image.height, dw, dh) or { return none }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	retained := if profile.gamma > 0 {
		ggshape.convert_image_color(data, profile) or { return none }
	} else {
		data.pixels.clone()
	}
	mut result := gg.Image{ width: data.width, height: data.height, nr_channels: 5, ok: true, data: retained.data }
	result.id = app.ctx.cache_image(result)
	app.background_image_ids[key.clone()] = result.id
	return SampledPNGUpload{ image: app.ctx.get_cached_image_by_idx(result.id), gpu_mips: profile.gamma > 0 }
}

fn (mut app BrowserApp) draw_sampled_png(command &layout.PaintCommand, image &gg.Image, url string,
	destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]! {
		return false
	}
	upload := app.sampled_png_decode(url, image, f64(destination.width),
		f64(destination.height)) or { return false }
	decoded := upload.image
	mut translated_clip := clip
	translated_clip[0] += f32(matrix[4])
	translated_clip[1] += f32(matrix[5])
	return C.native_draw_sampled_png(decoded.data, i32(decoded.width), i32(decoded.height), i32(image.width), i32(image.height), i32(upload.gpu_mips),
		f32(destination.x) + f32(matrix[4]), f32(destination.y) + f32(matrix[5]),
		f32(destination.width), f32(destination.height), &translated_clip[0], page_x, page_y, f32(scroll_y),
		f32(app.ctx.width), f32(app.ctx.height)) != 0
}

@[export:'vox_document_sampled_png_pixels']
fn document_sampled_png_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, source &u8, source_width i32, source_height i32, natural_width i32, natural_height i32, gpu_mips i32,
	x f32, y f32, destination_width f32, destination_height f32, clip &f32) i32 {
	if source == unsafe { nil } || source_width <= 0 || source_height <= 0
		|| source_width > 4096 || source_height > 4096
		|| int(source_width) * int(source_height) > 4 * 1024 * 1024 {
		return 0
	}
	samples := document_image_sample_count(int(first_x), int(first_y), int(width), int(height))
	if samples == 0 { return 0 }
	if clip == unsafe { nil } { return 0 }
	mut clipping := [12]f32{}
	unsafe { vmemcpy(&clipping[0], clip, 12 * int(sizeof(f32))) }
	swap_document_raster_channels(pixels, width, height, pitch)
	result := ggshape.draw_sampled_rgba_clipped(pixels, width, height, pitch, backdrop,
		unsafe { source.vbytes(int(source_width) * int(source_height) * 4) }, source_width, source_height,
		x, y, destination_width, destination_height, int(samples), int(natural_width), int(natural_height), clipping, gpu_mips != 0)
	swap_document_raster_channels(pixels, width, height, pitch)
	return result
}
