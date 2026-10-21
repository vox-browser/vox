module layout

import math
import svg

// Path::getBounds includes control points. Accumulate those same points in
// visitation order without retaining a growing vector for every bounds query.
struct SVGPathBounds {
mut:
	initialized bool
	min_x f64
	max_x f64
	min_y f64
	max_y f64
}

fn (bounds SVGPathBounds) including(point svg.Point) SVGPathBounds {
	if !bounds.initialized {
		return SVGPathBounds{
			initialized: true
			min_x: point.x
			max_x: point.x
			min_y: point.y
			max_y: point.y
		}
	}
	return SVGPathBounds{
		initialized: true
		min_x: math.min(bounds.min_x, point.x)
		max_x: math.max(bounds.max_x, point.x)
		min_y: math.min(bounds.min_y, point.y)
		max_y: math.max(bounds.max_y, point.y)
	}
}

fn (bounds SVGPathBounds) rect() ?svg.Rect {
	if !bounds.initialized { return none }
	return svg.Rect{
		x: bounds.min_x
		y: bounds.min_y
		width: bounds.max_x - bounds.min_x
		height: bounds.max_y - bounds.min_y
	}
}
