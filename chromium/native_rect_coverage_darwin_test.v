module main

import math

fn test_native_rectangle_shared_clip_edge_resolves_coverage_once() {
	// A 75.5-pixel tab and underline share their right clip edge. The clip
	// contributes the half pixel; the underline must fill the entire fringe.
	adjusted := native_rect_clip_coverage([f32(16), 624, 75.5, 2]!,
		[f32(16), 624, 75.5, 40]!, [f32(1), 0, 0, 1, 0, 0]!) or {
		panic('expected a shared fractional clip edge')
	}
	assert adjusted == [f32(16), 624, 76, 2]!
	// The identical logical bounds at scale two have an integer device edge.
	assert native_rect_clip_coverage([f32(16), 624, 75.5, 2]!,
		[f32(16), 624, 75.5, 40]!, [f32(2), 0, 0, 2, 0, 0]!) == none
}

fn test_native_rectangle_coverage_accounts_for_device_translation_and_y_flip() {
	translated := native_rect_clip_coverage([f32(4), 6, 12, 2]!,
		[f32(4), 6, 12, 8]!, [f32(1), 0, 0, 1, 0.5, 0]!) or {
		panic('expected translated device edges')
	}
	assert translated == [f32(3.5), 6, 13, 2]!
	flipped := native_rect_clip_coverage([f32(4), 6.5, 12, 2]!,
		[f32(4), 6.5, 12, 8]!, [f32(1), 0, 0, -1, 0, 20]!) or {
		panic('expected flipped shared device edge')
	}
	assert flipped == [f32(4), 6, 12, 2.5]!
}

fn test_native_rectangle_coverage_preserves_independent_fractional_edges() {
	assert native_rect_clip_coverage([f32(4.25), 6.25, 12.25, 2.25]!,
		[f32(0), 0, 20, 20]!, [f32(1), 0, 0, 1, 0, 0]!) == none
	assert native_rect_clip_coverage([f32(4), 6, 12, 2]!,
		[f32(4), 6, 12, 8]!, [f32(1), 0, 0, 1, 0, 0]!) == none
	// A close edge is still independent: no epsilon-based geometry snapping.
	assert native_rect_clip_coverage([f32(4), 6, 12.5, 2]!,
		[f32(4), 6, 12.5001, 8]!, [f32(1), 0, 0, 1, 0, 0]!) == none
}

fn test_native_rectangle_coverage_declines_non_axis_and_invalid_geometry() {
	for matrix in [[f32(1), 0.1, 0, 1, 0, 0]!, [f32(1), 0, 0.1, 1, 0, 0]!, [f32(0), 0, 0, 1, 0,
		0]!, [f32(1), 0, 0, 0, 0, 0]!, [f32(1), 0, 0, 1, f32(math.inf(1)), 0]!] {
		assert native_rect_clip_coverage([f32(4), 6, 12.5, 2]!,
			[f32(4), 6, 12.5, 8]!, matrix) == none
	}
	assert native_rect_clip_coverage([f32(4), 6, 0, 2]!,
		[f32(4), 6, 12.5, 8]!, [f32(1), 0, 0, 1, 0, 0]!) == none
	assert native_rect_clip_coverage([f32(4), 6, 12.5, 2]!,
		[f32(4), 6, 12.5, -1]!, [f32(1), 0, 0, 1, 0, 0]!) == none
	assert native_rect_clip_coverage([f32(3e38), 6, 3e38, 2]!,
		[f32(3e38), 6, 3e38, 8]!, [f32(2), 0, 0, 1, 0, 0]!) == none
	// Tiny finite scales must not publish an infinite inverse transform.
	assert native_rect_clip_coverage([f32(1), 6, 1, 2]!,
		[f32(1), 6, 1, 8]!, [f32(1e-40), 0, 0, 1, 0, 0]!) == none
	// A positive source extent can collapse in the device representation.
	assert native_rect_clip_coverage([f32(1.5), 6, 1e-40, 2]!,
		[f32(1.5), 6, 1e-40, 8]!, [f32(1), 0, 0, 1, 0, 0]!) == none
}
