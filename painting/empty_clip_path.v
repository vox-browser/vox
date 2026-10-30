module painting

import math

struct ClipPathExtent {
mut:
	has_point bool
	first     Point
	same_x    bool = true
	same_y    bool = true
}

fn (mut extent ClipPathExtent) include(point Point) bool {
	if math.is_nan(point.x) || math.is_inf(point.x, 0)
		|| math.is_nan(point.y) || math.is_inf(point.y, 0) {
		return false
	}
	if !extent.has_point {
		extent.first = point
		extent.has_point = true
	} else {
		extent.same_x = extent.same_x && point.x == extent.first.x
		extent.same_y = extent.same_y && point.y == extent.first.y
	}
	return true
}

// Basic-shape clips retain the reference box as their conservative bounds.
// An inset can still collapse to a point or line inside that nonempty box.
// Prove emptiness from exact path geometry, not flattened contours or signed
// area: curves can enclose ink between collinear endpoints, and intersecting
// contours can have zero signed area while retaining a visible fill.
fn clip_path_has_collapsed_axis(clip ClipPathVisualData) bool {
	mut extent := ClipPathExtent{}
	if clip.segments.len > 0 {
		for segment in clip.segments {
			if segment.kind == .close_path { continue }
			// Arc extrema are not bounded by their endpoints or control points.
			if segment.kind == .elliptical_arc_to { return false }
			if !extent.include(segment.point) { return false }
			if segment.kind in [.quadratic_bezier_curve_to, .cubic_bezier_curve_to]
				&& !extent.include(segment.control_point_0) {
				return false
			}
			if segment.kind == .cubic_bezier_curve_to
				&& !extent.include(segment.control_point_1) {
				return false
			}
		}
	} else if clip.polygons.len > 0 {
		for polygon in clip.polygons {
			for point in polygon {
				if !extent.include(point) { return false }
			}
		}
	} else {
		for point in clip.polygon {
			if !extent.include(point) { return false }
		}
	}
	return !extent.has_point || extent.same_x || extent.same_y
}
