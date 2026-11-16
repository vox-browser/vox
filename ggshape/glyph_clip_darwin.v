module ggshape

import gg.canvas
import math

// Glyph masks retain floating point clip coverage until the destination
// color write, rather than clipping an already resolved glyph bitmap.
pub fn draw_clipped_glyph_mask(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, mask []u8, color [4]f32, clip [4]f32, samples int) i32 {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || pitch < width * 4
		|| mask.len != int(width) * int(height) || samples !in [1, 4]
		|| C.pthread_main_np() == 0 || clip.any(!math.is_finite(f64(it)))
		|| color.any(!math.is_finite(f64(it)) || it < 0 || it > 1) { return 0 }
	mut ctx := context() or { return 0 }
	mut target := ctx.new_surface(width: int(width), height: int(height), sample_count: samples) or { return 0 }
	defer { target.free() }
	if backdrop != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	if samples == 4 { target.draw_msaa_trigger() }
	target.clip_rect(canvas.Rect.ltrb(clip[0], clip[1], clip[2], clip[3]), .intersect, true) or { return 0 }
	target.draw_alpha_mask(mask, int(width), int(height), canvas.Paint{
		color: canvas.Color4f{color[0], color[1], color[2], color[3]}
	}) or { return 0 }
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}
