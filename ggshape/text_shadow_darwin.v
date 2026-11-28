module ggshape

import cpuraster
import gg.canvas
import math

// Apply the glyph mask filter before tinting coverage in the destination blend.
// A translucent RGBA intermediate would quantize its coverage a second time.
pub fn draw_text_shadow_mask(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	source []u8, source_width int, source_height int, source_x f32, source_y f32,
	blur f32, color [4]f32) i32 {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| int(width) * int(height) > 4 * 1024 * 1024 || pitch < width * 4
		|| source_width <= 0 || source_height <= 0 || source_width > 4096 || source_height > 4096
		|| source.len != source_width * source_height || source.len > 4 * 1024 * 1024
		|| !math.is_finite(source_x) || !math.is_finite(source_y)
		|| !math.is_finite(blur) || blur < 0 || blur > 3 || C.pthread_main_np() == 0 {
		return 0
	}
	for component in color {
		if !math.is_finite(component) || component < 0 || component > 1 { return 0 }
	}
	filtered := cpuraster.blur_glyph_mask(source, source_width, source_height, blur) or { return 0 }
	image := ShadowMask{filtered, source_width, source_height}
	mask := shadow_mask_pass(image, int(width), int(height),
		[f32(1), 1, source_x, source_y]!, [56]f32{}, 0, 0) or { return 0 }
	mut ctx := context() or { return 0 }
	mut target := ctx.new_document_leaf_surface(int(width), int(height), 1) or { return 0 }
	defer { target.release_document_leaf_surface() }
	if backdrop != 0 {
		target.write_pixels(pixels, int(pitch)) or { return 0 }
	} else {
		target.clear(canvas.Color4f{})
	}
	target.draw_alpha_mask(mask.pixels, int(width), int(height), canvas.Paint{
		color: canvas.Color4f{color[0], color[1], color[2], color[3]}
	}) or { return 0 }
	target.read_pixels(pixels, int(pitch)) or { return 0 }
	return 1
}
