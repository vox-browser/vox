module ggshape

import math

// A recorded text picture owns local coordinates. Keep large page translations
// out of the gradient's inverse matrices instead of cancelling them in a vertex
// shader. Curved geometry, transformed pictures and other gradients keep replay.
pub fn localize_linear_gradient_path(path C.VoxGraphitePath, mut segments []f32) ?C.VoxGraphitePath {
	if path.gradient != 1 || path.stroke != 0 || path.segments == unsafe { nil }
		|| path.segment_count <= 0 || path.segment_count > 128
		|| path.matrix[0] != 1 || path.matrix[1] != 0 || path.matrix[3] != 0
		|| path.matrix[4] != 1 || path.matrix[6] != 0 || path.matrix[7] != 0
		|| path.matrix[8] != 1 {
		return none
	}
	for value in path.matrix { if !math.is_finite(value) { return none } }
	for value in path.gradient_matrix { if !math.is_finite(value) { return none } }
	if path.gradient_matrix[6] != 0 || path.gradient_matrix[7] != 0
		|| path.gradient_matrix[8] != 1 {
		return none
	}
	x, y := -path.matrix[2], -path.matrix[5]
	if x != math.round(x) || y != math.round(y) { return none }
	for i in 0 .. int(path.segment_count) {
		kind := unsafe { path.segments[i * 12] }
		if kind !in [f32(0), 1, 5] { return none }
		if kind != 5 {
			for c in 1 .. 3 {
				if !math.is_finite(unsafe { path.segments[i * 12 + c] }) { return none }
			}
		}
	}
	mut draw := path
	segments = unsafe { []f32{len: int(path.segment_count) * 12, init: path.segments[index]} }
	for i in 0 .. int(path.segment_count) {
		if segments[i * 12] != 5 {
			segments[i * 12 + 1] -= x
			segments[i * 12 + 2] -= y
			if !math.is_finite(segments[i * 12 + 1]) || !math.is_finite(segments[i * 12 + 2]) {
				return none
			}
		}
	}
	draw.segments = segments.data
	draw.matrix[2], draw.matrix[5] = 0, 0
	draw.gradient_matrix[2] -= x
	draw.gradient_matrix[5] -= y
	if draw.has_clip != 0 {
		draw.clip[0] -= x
		draw.clip[1] -= y
	}
	if draw.has_ancestor_clip != 0 {
		draw.ancestor_clip[0] -= x
		draw.ancestor_clip[1] -= y
	}
	for value in draw.gradient_matrix { if !math.is_finite(value) { return none } }
	if draw.has_clip != 0 {
		for value in draw.clip { if !math.is_finite(value) { return none } }
	}
	if draw.has_ancestor_clip != 0 {
		for value in draw.ancestor_clip { if !math.is_finite(value) { return none } }
	}
	return draw
}
