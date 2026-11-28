module main

import math
import os

const native_rect_coverage_diagnostics = os.getenv('VOX_DIAGNOSTIC_RECT_CLIP_COVERAGE') == '1'

// A rectangle edge that coincides with its native clip is redundant geometry.
// Extend it into the device-pixel fringe so the clip resolves its coverage once.
fn native_rect_clip_coverage(rect [4]f32, clip [4]f32, matrix [6]f32) ?[4]f32 {
	if rect[2] <= 0 || rect[3] <= 0 || clip[2] <= 0 || clip[3] <= 0
		|| matrix[0] == 0 || matrix[3] == 0 || matrix[1] != 0 || matrix[2] != 0 {
		return none
	}
	for value in rect { if !math.is_finite(value) { return none } }
	for value in clip { if !math.is_finite(value) { return none } }
	for value in matrix { if !math.is_finite(value) { return none } }
	mut result := rect
	mut changed := false
	for axis in 0 .. 2 {
		scale := matrix[axis * 3]
		translation := matrix[axis + 4]
		a := rect[axis] * scale + translation
		b := (rect[axis] + rect[axis + 2]) * scale + translation
		ca := clip[axis] * scale + translation
		cb := (clip[axis] + clip[axis + 2]) * scale + translation
		for value in [a, b, ca, cb] {
			if !math.is_finite(value) { return none }
		}
		if a == b || ca == cb { return none }
		left, right := math.min(a, b), math.max(a, b)
		clip_left, clip_right := math.min(ca, cb), math.max(ca, cb)
		new_left := if left == clip_left { f32(math.floor(left)) } else { left }
		new_right := if right == clip_right { f32(math.ceil(right)) } else { right }
		if left == new_left && right == new_right { continue }
		result[axis] = ((if scale > 0 { new_left } else { new_right }) - translation) / scale
		result[axis + 2] = (new_right - new_left) / math.abs(scale)
		if !math.is_finite(result[axis]) || !math.is_finite(result[axis + 2]) { return none }
		changed = true
	}
	return if changed { result } else { none }
}

@[export: 'vox_condition_native_rect_coverage']
fn condition_native_rect_coverage(rect &f32, clip &f32, matrix &f32) {
	if rect == unsafe { nil } || clip == unsafe { nil } || matrix == unsafe { nil } { return }
	mut bounds := [4]f32{}
	mut clipping := [4]f32{}
	mut transform := [6]f32{}
	unsafe {
		for i in 0 .. 4 {
			bounds[i] = rect[i]
			clipping[i] = clip[i]
		}
		for i in 0 .. 6 { transform[i] = matrix[i] }
	}
	if adjusted := native_rect_clip_coverage(bounds, clipping, transform) {
		unsafe {
			for i in 0 .. 4 { rect[i] = adjusted[i] }
		}
		if native_rect_coverage_diagnostics {
			eprintln('VOX_RECT_CLIP_COVERAGE before=${bounds} after=${adjusted} clip=${clipping} matrix=${transform}')
		}
	}
}
