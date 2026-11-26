module ggshape

import math

// CSS background gradients already draw their rectangular destination. An
// identical rectangular clip makes Graphite replace that geometry with a
// cover draw, changing interpolated gradient coordinates. Blink records only
// the destination and any enclosing rounded clip for this case. Keep this
// adjustment at the CSS boundary; SVG retains its own recording semantics.
pub fn css_gradient_without_redundant_rect_clip(path &C.VoxGraphitePath) C.VoxGraphitePath {
	if !gradient_rect_clip_is_redundant(path) { return unsafe { *path } }
	return C.VoxGraphitePath{ ...*path, has_clip: 0 }
}

fn gradient_rect_clip_is_redundant(path &C.VoxGraphitePath) bool {
	if path.gradient == 0 || path.stroke != 0 || path.has_clip == 0
		|| path.segments == unsafe { nil } || path.segment_count != 5 {
		return false
	}
	for value in path.clip {
		if !math.is_finite(value) { return false }
	}
	for index in 4 .. 12 {
		if path.clip[index] != 0 { return false }
	}
	if path.clip[2] <= 0 || path.clip[3] <= 0 { return false }
	left, top := path.clip[0], path.clip[1]
	right, bottom := left + path.clip[2], top + path.clip[3]
	mut corners := u32(0)
	for index in 0 .. 4 {
		point := unsafe { &path.segments[index * 12] }
		next := unsafe { &path.segments[((index + 1) % 4) * 12] }
		unsafe {
			if point[0] != f32(if index == 0 { 0 } else { 1 })
				|| (point[1] != left && point[1] != right)
				|| (point[2] != top && point[2] != bottom)
				|| (point[1] != next[1] && point[2] != next[2]) {
				return false
			}
			corner := u32(int(point[1] == right) + 2 * int(point[2] == bottom))
			corners |= u32(1) << corner
		}
	}
	return corners == 15 && unsafe { path.segments[48] } == 5
}
