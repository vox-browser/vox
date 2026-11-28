module main

import math
import painting

struct SampledPNGGeometry {
	x      f32
	y      f32
	width  f32
	height f32
	clip   [12]f32
}

// Fold a uniform layout/capture scale into image geometry before selecting
// decode dimensions. The sampler receives device-space coordinates and radii.
fn sampled_png_paint_geometry(destination painting.IntRect, clip [12]f32, matrix [6]f64) ?SampledPNGGeometry {
	if matrix[0] <= 0 || matrix[0] != matrix[3] || matrix[1] != 0 || matrix[2] != 0
		|| destination.width <= 0 || destination.height <= 0 {
		return none
	}
	for value in matrix { if !math.is_finite(value) { return none } }
	for value in clip { if !math.is_finite(value) { return none } }
	scale := f32(matrix[0])
	mut clipping := clip
	for i in 0 .. 12 { clipping[i] *= scale }
	clipping[0] += f32(matrix[4])
	clipping[1] += f32(matrix[5])
	return SampledPNGGeometry{
		x:      f32(destination.x) * scale + f32(matrix[4])
		y:      f32(destination.y) * scale + f32(matrix[5])
		width:  f32(destination.width) * scale
		height: f32(destination.height) * scale
		clip:   clipping
	}
}
