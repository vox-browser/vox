module layout

import math
import platform
import svg

fn test_svg_path_bounds_keep_relative_segments_controls_and_arc_extrema() {
	assert svg_path_bounds(svg.parse_path_data('')) == none
	for index, text in [
		'M10 20 l30 -5 h-50 v25 z',
		'M0 0 C10 30 20 -10 30 0',
		'M0 0 Q10 30 20 0 T40 0',
		'M-10 0 A10 10 0 0 1 10 0',
		'M10 0 A10 10 0 0 1 0 10',
		'M1 2 A0 10 45 1 1 20 30',
	] {
		expected := [
			svg.Rect{x:-10, y:15, width:50, height:25},
			svg.Rect{x:0, y:-10, width:30, height:40},
			svg.Rect{x:0, y:-30, width:40, height:60},
			svg.Rect{x:-10, y:-10, width:20, height:10},
			svg.Rect{x:0, y:0, width:10, height:10},
			svg.Rect{x:1, y:2, width:19, height:28},
		][index]
		actual := svg_path_bounds(svg.parse_path_data(text))?
		assert math.abs(actual.x - expected.x) < 1e-10, text
		assert math.abs(actual.y - expected.y) < 1e-10, text
		assert math.abs(actual.width - expected.width) < 1e-10, text
		assert math.abs(actual.height - expected.height) < 1e-10, text
	}
}

fn test_svg_rotated_arc_bounds_preserve_translation_and_axis_reversal() {
	for flags in ['0 0', '0 1', '1 0', '1 1'] {
		base := svg_path_bounds(svg.parse_path_data('M3 7 A25 11 37 ${flags} 40 19'))?
		translated := svg_path_bounds(svg.parse_path_data('M103 -43 A25 11 37 ${flags} 140 -31'))?
		assert math.abs(base.x + 100 - translated.x) < 1e-10
		assert math.abs(base.y - 50 - translated.y) < 1e-10
		assert math.abs(base.width - translated.width) < 1e-10
		assert math.abs(base.height - translated.height) < 1e-10
	}
}

fn test_geometry_bounds_queries_do_not_accumulate_temporary_vectors() {
	path := svg.parse_path_data('M0 0 C10 30 20 -10 30 0 S45 20 50 0 A10 20 37 1 1 70 5 Z')
	radii := BoxRadii{
		top_left: CornerRadius{80, 40}
		top_right: CornerRadius{80, 40}
		bottom_left: CornerRadius{20, 20}
		bottom_right: CornerRadius{20, 20}
	}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		assert svg_path_bounds(path)?.width > 0
		normalized := normalize_box_radii(radii, 80, 40)
		assert normalized.top_left == CornerRadius{40, 20}
		assert normalized.bottom_right == CornerRadius{10, 10}
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
