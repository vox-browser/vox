module layout

import math
import os

const viewport_rect_culling_diagnostics = os.getenv('VOX_VIEWPORT_RECT_CULLING_DIAGNOSTICS') != ''
__global viewport_rect_culling_calls_ = u64(0)

// The fill-rectangle case of paint_leaf_is_outside_canvas, without constructing
// a full PaintCommand for every cached ink rectangle. Keep its exact precision
// limits, affine mapping and fringe; uncertain geometry stays in the replay.
fn viewport_rect_outside_native_canvas(rect LayoutRect, transform [6]f64,
	width f64, height f64) bool {
	if viewport_rect_culling_diagnostics {
		viewport_rect_culling_calls_++
		if viewport_rect_culling_calls_ % 4096 == 1 {
			eprintln('VOX_VIEWPORT_RECT_CULLING calls=${viewport_rect_culling_calls_}')
		}
	}
	if width <= 0 || height <= 0 { return false }
	for value in [width, height]! {
		if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 1_000_000 { return false }
	}
	matrix := normalized_affine(transform)
	mut scale := f64(1)
	for index in 0 .. 6 {
		if math.is_nan(matrix[index]) || math.is_inf(matrix[index], 0) { return false }
		if index < 4 { scale = math.max(scale, math.abs(matrix[index])) }
	}
	if math.abs(matrix[4]) > 1_000_000 || math.abs(matrix[5]) > 1_000_000 { return false }
	for value in [rect.x, rect.y, rect.x + rect.width, rect.y + rect.height]! {
		if math.abs(value) * scale > 1_000_000 { return false }
	}
	bounds := compatibility_affine_map_rect(transform, rect)
	for value in [bounds.x, bounds.y, bounds.width, bounds.height]! {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	if bounds.width <= 0 || bounds.height <= 0 { return false }
	return bounds.x > width + 3 || bounds.y > height + 3
		|| bounds.x + bounds.width < -3 || bounds.y + bounds.height < -3
}
