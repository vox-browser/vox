module layout

import html
import painting
import platform
import svg

fn test_svg_paint_projection_retires_contours_after_copying_exact_segments_and_bounds() {
	path := svg.parse_path_data('M0 0 ' + 'c1.25 2.5 -3.75 4.125 5.5 6.25 '.repeat(1024) + 'z')
	visual := painting_clip_path_from_canvas_path(html.canvas_gfx_path_from_svg_path(path), .even_odd)
	expected := compatibility_pack_clip_path_segments(visual)
	bounds := painting_clip_path_bounds(visual) or { panic('missing reference bounds') }
	before := platform.thread_arena_usage().used
	actual := svg_paint_path_projection(path, .even_odd, true)
	after := platform.thread_arena_usage().used
	$if prealloc { assert after - before < actual.packed_segments.len * sizeof(f32) + 1024 }
	mut reuse := platform.begin_thread_scratch('reuse paint projection workspace')
	_ = []u8{len: expected.len * 32, init: 0xa5}
	reuse.finish()
	assert actual.packed_segments == expected
	actual_bounds := actual.bounds or { panic('missing owned bounds') }
	assert actual_bounds == bounds
}

fn test_svg_bounds_without_segment_packing_and_empty_paths_preserve_results() {
	projection := svg_paint_path_projection(svg.parse_path_data('M1 2H11V22Z'), .nonzero, false)
	assert projection.packed_segments.len == 0
	bounds := projection.bounds or { panic('missing bounds') }
	assert bounds == painting.Rect{1, 2, 10, 20}
	empty := svg_paint_path_projection(svg.Path{}, .nonzero, true)
	assert empty.packed_segments.len == 0
	assert empty.bounds == none
}
