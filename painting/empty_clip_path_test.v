module painting

import math

fn collapsed_clip_test_path(points []Point) ClipPathVisualData {
	mut segments := []ClipPathSegment{}
	for index, point in points {
		segments << ClipPathSegment{ kind: if index == 0 { .move_to } else { .line_to }, point: point }
	}
	segments << ClipPathSegment{ kind: .close_path }
	return ClipPathVisualData{ bounding_rect: IntRect{0, 0, 100, 100}, segments: segments, polygon: points }
}

fn test_collapsed_clip_geometry_propagates_and_discards_paint_before_replay() {
	for points in [[Point{.5, .5}, Point{.5, .5}, Point{.5, .5}],
		[Point{.5, 0}, Point{.5, 1}, Point{.5, 2}], [Point{0, .5}, Point{1, .5}, Point{2, .5}]] {
		for rule in [WindingRule.nonzero, WindingRule.even_odd] {
			clip := ClipPathVisualData{ ...collapsed_clip_test_path(points), fill_rule: rule }
			mut list := DisplayList{}
			index := list.visual_context_tree.append(clip, 0)
			child := list.visual_context_tree.append(EffectsVisualData{ opacity: .5 }, index)
			assert list.visual_context_tree.has_empty_effective_clip(index)
			assert list.visual_context_tree.has_empty_effective_clip(child)
			assert !list.append(FillRect{ rect: IntRect{0, 0, 100, 100} }, child)
			assert list.commands.len == 0
			assert list.append(FillRect{ rect: IntRect{0, 0, 100, 100} }, 0)
		}
	}
}

fn test_collapsed_clip_test_retains_thin_and_crossing_fills() {
	for points in [[Point{0, 0}, Point{1, 0}, Point{1, 1e-12}],
		[Point{0, 0}, Point{1, 1}, Point{0, 1}, Point{1, 0}]] {
		clip := collapsed_clip_test_path(points)
		assert !clip_path_has_collapsed_axis(clip)
		mut tree := AccumulatedVisualContextTree.create()
		index := tree.append(clip, 0)
		assert !tree.has_empty_effective_clip(index)
	}
}

fn test_collapsed_clip_test_uses_curve_controls_and_retains_arcs() {
	base := collapsed_clip_test_path([Point{0, 0}, Point{1, 0}, Point{2, 0}])
	for kind in [ClipPathSegmentKind.quadratic_bezier_curve_to, .cubic_bezier_curve_to] {
		mut segments := base.segments.clone()
		segments[1] = ClipPathSegment{
			kind:            kind
			point:           Point{1, 0}
			control_point_0: Point{.5, 0}
			control_point_1: Point{1.5, 0}
		}
		assert clip_path_has_collapsed_axis(ClipPathVisualData{ ...base, segments: segments })
		segments[1] = ClipPathSegment{ ...segments[1], control_point_0: Point{.5, 1} }
		assert !clip_path_has_collapsed_axis(ClipPathVisualData{ ...base, segments: segments })
		if kind == .cubic_bezier_curve_to {
			segments[1] = ClipPathSegment{ ...segments[1], control_point_0: Point{.5, 0}, control_point_1: Point{1.5, 1} }
			assert !clip_path_has_collapsed_axis(ClipPathVisualData{ ...base, segments: segments })
		}
	}
	arc := ClipPathSegment{ kind: .elliptical_arc_to, point: Point{1, 0}, radii: Size{1, 1} }
	assert !clip_path_has_collapsed_axis(ClipPathVisualData{ ...base, segments: [
		base.segments[0],
		arc,
	] })
}

fn test_collapsed_clip_test_preserves_nonfinite_geometry_and_polygon_fallbacks() {
	for value in [math.nan(), math.inf(1), math.inf(-1)] {
		assert !clip_path_has_collapsed_axis(collapsed_clip_test_path([Point{0, 0}, Point{value, 0},
			Point{1, 0}]))
	}
	points := [Point{0, .5}, Point{1, .5}, Point{2, .5}]
	assert clip_path_has_collapsed_axis(ClipPathVisualData{ polygon: points })
	assert clip_path_has_collapsed_axis(ClipPathVisualData{ polygons: [points] })
	assert !clip_path_has_collapsed_axis(ClipPathVisualData{ polygons: [points,
		[Point{0, 0}, Point{1, 0}, Point{1, 1}]] })
}
