module ggshape

import gg.canvas
import imageraster
import math

pub fn draw_sampled_rgba(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, source_width int, source_height int, x f32, y f32,
	destination_width f32, destination_height f32, samples int, natural_width int, natural_height int) i32 {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| int(width) * int(height) > 4 * 1024 * 1024 || pitch < width * 4 || samples !in [
		1,
		4,
	]
		|| C.pthread_main_np() == 0 {
		return 0
	}
	if natural_width <= 0 || natural_height <= 0 || natural_width > 4096 || natural_height > 4096
		|| destination_width <= 0 || destination_height <= 0
		|| math.is_nan(x) || math.is_nan(y) || math.is_nan(destination_width) || math.is_nan(destination_height)
		|| math.is_inf(x, 0) || math.is_inf(y, 0) || math.is_inf(destination_width, 0) || math.is_inf(destination_height, 0) {
		return 0
	}
	extent_x := f32(natural_width) * (f32(source_width) / f32(natural_width))
	extent_y := f32(natural_height) * (f32(source_height) / f32(natural_height))
	mut levels := [source]
	if destination_width < source_width && destination_height < source_height
		&& extent_x >= source_width && extent_y >= source_height {
		chain := imageraster.mip_chain(imageraster.Image{ width: source_width, height: source_height, pixels: source }) or { return 0 }
		levels = chain.map(it.pixels)
	}
	mut ctx := context() or { return 0 }
	mut surface := ctx.new_surface(width: width, height: height, sample_count: samples) or { return 0 }
	defer { surface.free() }
	if backdrop != 0 {
		surface.write_pixels(pixels, pitch) or { return 0 }
	} else {
		surface.clear(canvas.Color4f{})
	}
	surface.draw_document_scaled_rgba(levels, source_width, source_height, natural_width, natural_height, x, y,
		destination_width, destination_height) or { return 0 }
	surface.read_pixels(pixels, pitch) or { return 0 }
	return 1
}
