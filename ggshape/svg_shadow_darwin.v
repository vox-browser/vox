module ggshape

import cpuraster
import gg.canvas
import math

@[typedef]
pub struct C.VoxGraphiteSvgShadow {
pub mut:
	path   C.VoxGraphitePath
	frame  [9]f32
	bounds [4]f32
	shadow [7]f32
}

pub fn draw_svg_shadow(pixels &u8, width int, height int, pitch int, samples int,
	data &C.VoxGraphiteSvgShadow) i32 {
	if data == unsafe { nil } || !path_supported(&data.path) || data.path.gradient != 0 || data.path.stroke != 0
		|| data.path.red != 0 || data.path.green != 0 || data.path.blue != 0
		|| data.path.alpha != 255 || data.path.opacity != 1 || data.path.has_float_color != 0
		|| data.path.has_clip != 0 || data.path.has_ancestor_clip != 0 {
		return 0
	}
	path := path_from_segments(data.path.segments, data.path.segment_count, data.path.even_odd != 0)
	return draw_svg_shadow_pixels(pixels, width, height, pitch, samples, path,
		data.path.matrix, data.frame, data.bounds, data.shadow)
}

// A single opaque black path, filtered before its quarter-turn transform.
fn draw_svg_shadow_pixels(pixels &u8, width int, height int, pitch int, samples int,
	path canvas.Path, source_matrix [9]f32, frame [9]f32, bounds [4]f32,
	shadow [7]f32) i32 {
	return svg_shadow_pixels(pixels, width, height, pitch, samples, path, source_matrix, frame, bounds, shadow) or { 0 }
}

fn svg_shadow_pixels(pixels &u8, width int, height int, pitch int, samples int,
	path canvas.Path, source_matrix [9]f32, frame [9]f32, bounds [4]f32,
	shadow [7]f32) !i32 {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || pitch < width * 4 || samples !in [1, 4]
		|| frame.any(!math.is_finite(it)) || source_matrix.any(!math.is_finite(it))
		|| bounds.any(!math.is_finite(it)) || shadow.any(!math.is_finite(it))
		|| frame[0] != 0 || frame[4] != 0 || math.abs(frame[1]) != 1 || frame[3] != -frame[1]
		|| frame[6] != 0 || frame[7] != 0 || frame[8] != 1
		|| source_matrix[1] != 0 || source_matrix[3] != 0 || source_matrix[0] <= 0
		|| source_matrix[0] != source_matrix[4] || source_matrix[6] != 0
		|| source_matrix[7] != 0 || source_matrix[8] != 1
		|| bounds[2] <= bounds[0] || bounds[3] <= bounds[1]
		|| bounds[2] - bounds[0] > 4096 || bounds[3] - bounds[1] > 4096
		|| (bounds[2] - bounds[0]) * (bounds[3] - bounds[1]) > 4 * 1024 * 1024
		|| shadow[2] < .5 || shadow[2] > 135 || shadow[3..].any(it < 0 || it > 1) {
		return error('Unsupported SVG drop shadow')
	}
	// A viewport-sized source must enclose the filled geometry. Overflowing
	// paths retain native clipping rather than losing ink at the filter edge.
	ink := canvas.Transform.new(canvas.Matrix.values(source_matrix)).map_rect(path.bounds())
	for value in [ink.left(), ink.top(), ink.right(), ink.bottom()] {
		if !math.is_finite(value) { return error('Invalid SVG source bounds') }
	}
	if ink.left() < bounds[0] - f32(.001) || ink.top() < bounds[1] - f32(.001)
		|| ink.right() > bounds[2] + f32(.001) || ink.bottom() > bounds[3] + f32(.001) {
		return error('SVG source overflows its viewport')
	}
	rotation := canvas.Transform.new(canvas.Matrix.values(frame))
	if !rotation.valid() { return error('Invalid SVG frame') }
	desired := rotation.inverse_map_rect(canvas.Rect.ltrb(0, 0, f32(width), f32(height)))
	left, top := f32(math.floor(desired.left() + f32(.001))), f32(math.floor(desired.top() + f32(.001)))
	right, bottom := f32(math.ceil(desired.right() - f32(.001))), f32(math.ceil(desired.bottom() - f32(.001)))
	w, h := int(right - left), int(bottom - top)
	if w <= 0 || h <= 0 || w > 4096 || h > 4096 || w * h > 4 * 1024 * 1024 {
		return error('SVG filter bounds')
	}
	shape := C.VoxGraphiteShape{
		matrix:     [f32(1), 0, -left + shadow[0], 0, 1, -top + shadow[1], 0, 0, 1]!
		rect:       [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1], f32(0),
			0, 0, 0, 0, 0, 0, 0]!
		thickness:  shadow[2] * 2
		anti_alias: 1
		fill:       10
	}
	blurred := shadow_filter_layer_with_path_matrix(&shape, w, h, path, canvas.Point{}, none, source_matrix, true)!
	mut ctx := context()!
	mut target := ctx.new_surface(width: width, height: height, sample_count: samples)!
	defer { target.free() }
	target.write_pixels(pixels, pitch)!
	if samples == 4 { target.draw_msaa_trigger() }
	// FilterResult::AutoSurface preserves a transparent pixel around the merge
	// and allocates an approximate backing texture. The device origin changes
	// with that border; both affect the interpolated filter sample coordinates.
	mut merged := ctx.new_filter_surface(w + 2, h + 2)!
	defer { merged.free() }
	merged.clear(canvas.Color4f{})
	merged.clip_rect(canvas.Rect.xywh(1, 1, f32(w), f32(h)), .intersect, false)!
	merged.set_matrix(canvas.Matrix.values([blurred.scale.x, f32(0), blurred.origin.x + 1, 0,
		blurred.scale.y, blurred.origin.y + 1, 0, 0, 1]!))
	merged.draw_linear_alpha_mask(blurred.mask.pixels, blurred.mask.width, blurred.mask.height,
		canvas.Paint{ color: canvas.Color4f{shadow[3], shadow[4], shadow[5], shadow[6]}, anti_alias: true })!
	// Resolve source edge coverage in the filter's local space before rotation.
	sx, sy := f32(math.floor(bounds[0] + f32(.001))), f32(math.floor(bounds[1] + f32(.001)))
	sw, sh := int(math.ceil(bounds[2] - f32(.001)) - sx), int(math.ceil(bounds[3] - f32(.001)) - sy)
	if sw <= 0 || sh <= 0 || sw > 4096 || sh > 4096 || sw * sh > 4 * 1024 * 1024 {
		return error('SVG source exceeds bounded size')
	}
	mut source := ctx.new_surface(width: sw, height: sh)!
	defer { source.free() }
	source.clear(canvas.Color4f{})
	source.set_matrix(canvas.Matrix.translate(-sx, -sy))
	source.concat(canvas.Matrix.values(source_matrix))
	source.draw_path(path, canvas.Paint{ color: canvas.Color4f{1, 1, 1, 1}, anti_alias: true })!
	mut rgba := []u8{len: sw * sh * 4}
	source.read_pixels(rgba.data, sw * 4)!
	alpha := cpuraster.copy_rgba_alpha(rgba)
	merged.set_matrix(canvas.Matrix.translate(sx - left + 1, sy - top + 1))
	merged.draw_linear_alpha_mask(alpha, sw, sh, canvas.Paint{ color: canvas.Color4f{0, 0, 0, 1}, anti_alias: true })!
	// Snap the logical subset, excluding the guaranteed transparent border.
	mut combined := []u8{len: w * h * 4}
	mut padded := []u8{len: (w + 2) * (h + 2) * 4}
	merged.read_pixels(padded.data, (w + 2) * 4)!
	for y in 0 .. h {
		copy(mut combined[y * w * 4..(y + 1) * w * 4], padded[((y + 1) * (w + 2) + 1) * 4..((y + 1) * (w + 2) + 1 + w) * 4])
	}
	target.set_matrix(canvas.Matrix.values(frame))
	target.concat(canvas.Matrix.translate(left, top))
	target.draw_linear_premultiplied_layer(combined, w, h, true)!
	target.read_pixels(pixels, pitch)!
	return 1
}
