module ggshape

import gg.canvas
import imageraster
import math

// Convert a decoded premultiplied upload into an 8-bit sRGB texture before
// its final image filtering. Alpha stays unchanged across the color transform.
pub fn convert_image_color(source imageraster.Image, profile imageraster.PNGSamplingProfile) ?[]u8 {
	if source.width <= 0 || source.height <= 0 || source.width > 4096 || source.height > 4096
		|| source.width * source.height > 4 * 1024 * 1024
		|| source.pixels.len != source.width * source.height * 4
		|| !math.is_finite(profile.gamma) || profile.gamma < 0.1 || profile.gamma > 10
		|| C.pthread_main_np() == 0 {
		return none
	}
	for value in profile.gamut { if !math.is_finite(value) { return none } }
	mut ctx := context() or { return none }
	mut target := ctx.new_surface(width: source.width, height: source.height) or { return none }
	defer { target.free() }
	target.draw_document_color_rgba([source.pixels], source.width, source.height,
		source.width, source.height, 0, 0, f32(source.width), f32(source.height),
		canvas.DocumentImageColorTransform{ gamma: profile.gamma, gamut: profile.gamut }) or { return none }
	mut pixels := []u8{len: source.pixels.len}
	target.read_pixels(pixels.data, source.width * 4) or { return none }
	for i in 0 .. source.width * source.height {
		pixels[i * 4], pixels[i * 4 + 2] = pixels[i * 4 + 2], pixels[i * 4]
	}
	return pixels
}

// A color-converted texture regenerates its mip levels on the GPU. Odd-sized
// levels use a linear rescale, rather than the CPU mipmap's three-tap kernel.
fn gpu_image_mip_chain(source imageraster.Image) ?[]imageraster.Image {
	mut levels := [source]
	mut ctx := context() or { return none }
	for levels.last().width > 1 || levels.last().height > 1 {
		previous := levels.last()
		width, height := math.max(1, previous.width / 2), math.max(1, previous.height / 2)
		mut target := ctx.new_surface(width: width, height: height) or { return none }
		target.draw_document_scaled_rgba([previous.pixels], previous.width, previous.height,
			previous.width, previous.height, 0, 0, f32(width), f32(height)) or {
			target.free()
			return none
		}
		mut pixels := []u8{len: width * height * 4}
		target.read_pixels(pixels.data, width * 4) or {
			target.free()
			return none
		}
		target.free()
		for i in 0 .. width * height {
			pixels[i * 4], pixels[i * 4 + 2] = pixels[i * 4 + 2], pixels[i * 4]
		}
		levels << imageraster.Image{ width: width, height: height, pixels: pixels }
	}
	return levels
}
