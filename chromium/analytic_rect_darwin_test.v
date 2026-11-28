module main

import math

fn test_document_analytic_rect_preserves_conditioned_clip_extent_and_flips_y_once() {
	identity := [f32(1), 0, 0, 1, 0, 0]!
	assert document_analytic_rect_geometry([f32(16), 624, 76, 2]!,
		[f32(16), 624, 75.5, 2]!, identity, 1024, 792)? == [f32(16), 166, 76, 2]!
	assert document_analytic_rect_geometry([f32(720), 328.5, 107.46875, 1.5]!,
		[f32(720), 328.5, 107.46875, 1.5]!, identity, 1024, 768)? ==
		[f32(720), 438, 107.46875, 1.5]!
}

fn test_document_analytic_rect_keeps_unrelated_and_invalid_geometry_on_existing_path() {
	identity := [f32(1), 0, 0, 1, 0, 0]!
	for rect in [[f32(0), 0, 1024, 768]!, [f32(0), 0, 50, 2]!,
		[f32(0), 0, -1, 2]!, [f32(math.nan()), 0, 1.5, 2]!,
		[f32(0), 0, f32(math.inf(1)), 2]!] {
		assert document_analytic_rect_geometry(rect, rect, identity, 1024, 768) == none
	}
	assert document_analytic_rect_geometry([f32(0), 0, 1.5, 2]!,
		[f32(0), 0, 1.5, 2]!, [f32(2), 0, 0, 2, 0, 0]!, 1024, 768) == none
}
