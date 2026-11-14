module ggshape

import gg.canvas
import math

struct RotatedShadowLayer {
	mask   ShadowMask
	matrix [9]f32
}

pub fn rotated_filter_supported(shape &C.VoxGraphiteShape) bool {
	alpha := if shape.has_float_color != 0 { shape.float_color[3] } else { f32(shape.alpha) / 255 }
	if shape.fill != 10 || !ellipse_shadow(shape) || shape.rect[2] == shape.rect[3] || shape.anti_alias == 0
		|| math.is_nan(alpha) || math.is_inf(alpha, 0) || alpha <= 0 || alpha >= 1 {
		return false
	}
	if _ := shadow_filter_scale(shape) {
		m := shape.matrix
		return m[0] != 0 && m[1] != 0 && m[3] != 0 && m[4] != 0
			&& m[0] * m[4] - m[1] * m[3] > 0
	}
	return false
}

fn rotated_shadow_filter_layer(shape &C.VoxGraphiteShape, width int, height int) !RotatedShadowLayer {
	if width <= 0 || height <= 0 { return error('Empty rotated filter target') }
	if !rotated_filter_supported(shape) { return error('Unsupported rotated filter') }
	m := shape.matrix
	// SkMatrix::decomposeScale preserves the rounding of both squared terms.
	x_squared := m[0] * m[0]
	y_squared := m[3] * m[3]
	scale := f32(math.sqrt(f64(x_squared + y_squared)))
	rotation := canvas.Transform.new(canvas.Matrix.values([m[0] / scale, m[1] / scale, m[2],
		m[3] / scale, m[4] / scale, m[5], 0, 0, 1]!))
	if !rotation.valid() { return error('Invalid rotated filter mapping') }
	mut device_clip := canvas.Rect.ltrb(0, 0, f32(width), f32(height))
	if shape.has_filter_clip != 0 {
		c := shape.filter_clip
		for value in c {
			if math.is_nan(value) || math.is_inf(value, 0) { return error('Invalid filter clip') }
		}
		device_clip = device_clip.intersect(canvas.Rect.ltrb(c[0], c[1], c[2], c[3]))
	}
	if device_clip.width() <= 0 || device_clip.height() <= 0 { return error('Empty filter clip') }
	desired := rotation.inverse_map_rect(device_clip)
	pad := f32(math.ceil(f64(shape.thickness * f32(.5) * scale * f32(3))))
	left := math.max(f32(math.floor(f64(desired.left() + f32(.001)))), f32(math.floor(f64(shape.rect[0] * scale))) - pad)
	top := math.max(f32(math.floor(f64(desired.top() + f32(.001)))), f32(math.floor(f64(shape.rect[1] * scale))) - pad)
	right := math.min(f32(math.ceil(f64(desired.right() - f32(.001)))), f32(math.ceil(f64((shape.rect[0] + shape.rect[2]) * scale))) + pad)
	bottom := math.min(f32(math.ceil(f64(desired.bottom() - f32(.001)))), f32(math.ceil(f64((shape.rect[1] + shape.rect[3]) * scale))) + pad)
	w, h := int(right - left), int(bottom - top)
	if w <= 0 || h <= 0 || w > 4096 || h > 4096 || w * h > 8 * 1024 * 1024 {
		return error('Rotated shadow layer exceeds bounded size')
	}
	local := C.VoxGraphiteShape{ ...*shape, matrix: [scale, f32(0), -left, 0, scale, -top, 0, 0,
		1]! }
	mask := shadow_filter_mask(&local, w, h, none, canvas.Point{})!
	r := rotation.matrix.m
	return RotatedShadowLayer{
		mask:   ShadowMask{mask, w, h}
		matrix: [r[0], r[1], r[0] * left + (r[1] * top + r[2]), r[3], r[4],
			r[3] * left + (r[4] * top + r[5]), 0, 0, 1]!
	}
}
