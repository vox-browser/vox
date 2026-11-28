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

fn (bounds SVGPathBounds) including_quadratic(start svg.Point, control svg.Point, end svg.Point) SVGPathBounds {
	left, right := svg.quadratic_bezier_bounds(start.x, control.x, end.x)
	top, bottom := svg.quadratic_bezier_bounds(start.y, control.y, end.y)
	return bounds.including(svg.Point{left, top}).including(svg.Point{right, bottom})
}

fn (bounds SVGPathBounds) including_cubic(start svg.Point, first svg.Point, second svg.Point,
	end svg.Point) SVGPathBounds {
	left, right := svg.cubic_bezier_bounds(start.x, first.x, second.x, end.x)
	top, bottom := svg.cubic_bezier_bounds(start.y, first.y, second.y, end.y)
	return bounds.including(svg.Point{left, top}).including(svg.Point{right, bottom})
}
