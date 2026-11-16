module ggshape

import gg.canvas
import math

#include "@DIR/rect_blur_darwin.m"

fn C.erff(f32) f32
fn C.vox_rect_blur_coverage(&u8, i32, &f32, i32, i32, &f32, f32, i32) i32

fn rectangular_shadow_supported(shape &C.VoxGraphiteShape) bool {
	return shape.fill == 10 && affine_shadow_supported(shape)
		&& shape.rect[2] > 0 && shape.rect[3] > 0 && shape.rect[4..12].all(it == 0)
}

// The integral profile represents a six-sigma Gaussian, with two texels per
// device pixel and power-of-two bins. Preserve float arithmetic before rounding.
fn rectangle_integral_table(six_sigma f32) []u8 {
	mut width := 32
	for width < 2 * int(math.ceil(six_sigma)) { width *= 2 }
	mut table := []u8{len: width}
	table[0] = 255
	inv_width := f32(1) / f32(width)
	for i in 1 .. width - 1 {
		t := (f32(i) + f32(.5)) * inv_width
		x := (-f32(6) * t + f32(3)) * f32(.7071067811865475244)
		integral := f32(.5) * (C.erff(x) + f32(1))
		table[i] = u8(math.floor(f32(255) * integral + f32(.5)))
	}
	return table
}

fn draw_rectangular_shadow(mut target canvas.GpuSurface, shape &C.VoxGraphiteShape,
	width int, height int, paint canvas.Paint) ! {
	if !rectangular_shadow_supported(shape) { return error('Unsupported rectangular blur') }
	m := shape.matrix
	sigma := shape.thickness * f32(.5) * m[0]
	pad := f32(3) * sigma
	// Edges stay in the destination tile's device space.
	inset := [shape.rect[0] * m[0] + m[2] + pad, shape.rect[1] * m[4] + m[5] + pad,
		(shape.rect[0] + shape.rect[2]) * m[0] + m[2] - pad,
		(shape.rect[1] + shape.rect[3]) * m[4] + m[5] - pad]!
	fast := inset[0] <= inset[2] && inset[1] <= inset[3]
	table := rectangle_integral_table(6 * sigma)
	mut coverage := []f32{len: width * height}
	if C.vox_rect_blur_coverage(table.data, i32(table.len), coverage.data, i32(width), i32(height),
		&inset[0], f32(1) / (f32(6) * sigma), i32(fast)) == 0 {
		return error('Rectangular blur GPU pass failed')
	}
	target.clip_rrect(rounded_rect(shape.underlay_rect), .difference, true)!
	target.set_matrix(canvas.Matrix.identity())
	target.draw_float_alpha_mask(coverage, width, height, paint)!
}
