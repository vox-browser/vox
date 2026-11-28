module ggshape

import cpuraster
import gg.canvas
import math

// Keep repeat filtering, rounded coverage and the adjacent border in one pass.
// A resolved image followed by a new border pass loses their shared samples.
pub fn draw_repeated_background(pixels &u8, width int, height int, pitch int,
	source []u8, sw int, sh int, x f32, y f32, clip [12]f32, samples int,
	background [4]u8, border &C.VoxGraphiteShape) bool {
	if pixels == unsafe { nil } || border == unsafe { nil } || width <= 0 || height <= 0
		|| width > 4096 || height > 4096 || width * height > 4 * 1024 * 1024
		|| pitch < width * 4 || sw <= 0 || sh <= 0 || sw > 4096 || sh > 4096
		|| sw * sh > 4 * 1024 * 1024 || source.len != sw * sh * 4 || samples !in [1, 4]
		|| C.pthread_main_np() == 0 || border.fill != 0 || border.alpha != 255
		|| background[3] != 255 || !supported(border) {
		return false
	}
	for value in [x, y, border.thickness] { if !math.is_finite(value) { return false } }
	for value in clip { if !math.is_finite(value) { return false } }
	for value in border.rect { if !math.is_finite(value) { return false } }
	for value in border.matrix { if !math.is_finite(value) { return false } }
	if clip[2] <= 0 || clip[3] <= 0 || clip[4..12].any(it < 0)
		|| border.rect[2] <= 0 || border.rect[3] <= 0 || border.thickness <= 0 {
		return false
	}
	rgba := cpuraster.premultiply_rgba_copy(source, sw, sh) or { return false }
	mut ctx := context() or { return false }
	mut target := ctx.new_document_leaf_surface(width, height, samples) or { return false }
	defer { target.release_document_leaf_surface() }
	target.write_pixels(pixels, pitch) or { return false }
	if samples == 4 { target.draw_msaa_trigger() }
	target.save()
	target.clip_rrect(rounded_rect(clip), .intersect, true) or { return false }
	rect := canvas.Rect.xywh(clip[0], clip[1], clip[2], clip[3])
	target.draw_rect(rect, canvas.Paint{ color: shape_color(background, false, [4]f32{}), anti_alias: true }) or { return false }
	target.draw_document_repeated_rgba(rgba, sw, sh, x, y, rect) or { return false }
	target.restore()
	draw_shape_descriptor(mut target, border, width, height) or { return false }
	target.read_pixels(pixels, pitch) or { return false }
	return true
}
