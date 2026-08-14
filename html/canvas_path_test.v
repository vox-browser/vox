module html

import math

fn test_move_and_line_build_segments() {
	mut p := CanvasPath.create()
	p.move_to(10, 20)
	p.line_to(30, 40)
	path := p.path()
	assert path.length() == 2
	assert path.segments()[0].kind == .move_to
	assert path.segments()[0].point == FloatPoint{10, 20}
	assert path.segments()[1].kind == .line_to
	assert path.last_point() == FloatPoint{30, 40}
}

fn test_non_finite_coordinates_are_ignored() {
	mut p := CanvasPath.create()
	p.move_to(math.inf(1), 0)
	p.line_to(math.nan(), 5)
	assert p.path().is_empty()
}

fn test_line_to_on_empty_path_ensures_subpath() {
	mut p := CanvasPath.create()
	// line_to on an empty path starts a subpath with a move_to.
	p.line_to(5, 5)
	assert p.path().length() == 1
	assert p.path().segments()[0].kind == .move_to
}

fn test_rect_builds_closed_subpath() {
	mut p := CanvasPath.create()
	p.rect(0, 0, 100, 50)
	segs := p.path().segments()
	// move, 3x line, close, move.
	assert segs.map(it.kind) == [PathSegmentKind.move_to, .line_to, .line_to, .line_to, .close_path,
		.move_to]
	assert segs[1].point == FloatPoint{100, 0}
	assert segs[2].point == FloatPoint{100, 50}
}

fn test_arc_negative_radius_errors() {
	mut p := CanvasPath.create()
	if _ := p.arc(0, 0, -5, 0, math.pi, false) {
		assert false, 'expected IndexSizeError for negative radius'
	}
}

fn test_arc_emits_move_and_arc() {
	mut p := CanvasPath.create()
	p.arc(50, 50, 20, 0, math.pi / 2, false)!
	segs := p.path().segments()
	// On an empty path the arc seeds a move_to at the start point then an elliptical arc.
	assert segs.len == 2
	assert segs[0].kind == .move_to
	assert segs[1].kind == .elliptical_arc_to
	assert segs[1].radii == FloatSize{20, 20}
}

fn test_arc_to_collinear_falls_back_to_line() {
	mut p := CanvasPath.create()
	p.move_to(0, 0)
	// (0,0), (10,0), (20,0) are collinear → arc_to adds a straight line to (10, 0).
	p.arc_to(10, 0, 20, 0, 5)!
	last := p.path().segments().last()
	assert last.kind == .line_to
	assert last.point == FloatPoint{10, 0}
}

fn test_round_rect_radius_count_validation() {
	mut p := CanvasPath.create()
	if _ := p.round_rect(0, 0, 10, 10, []) {
		assert false, 'expected RangeError for empty radii'
	}
	too_many := [RoundRectRadius{1, 1}, RoundRectRadius{1, 1},
		RoundRectRadius{1, 1}, RoundRectRadius{1, 1}, RoundRectRadius{1, 1}]
	if _ := p.round_rect(0, 0, 10, 10, too_many) {
		assert false, 'expected RangeError for >4 radii'
	}
}

fn test_round_rect_negative_radius_errors() {
	mut p := CanvasPath.create()
	if _ := p.round_rect(0, 0, 10, 10, [RoundRectRadius{-1, 2}]) {
		assert false, 'expected RangeError for negative radius'
	}
}

fn test_round_rect_single_radius_builds_path() {
	mut p := CanvasPath.create()
	p.round_rect(0, 0, 100, 100, [RoundRectRadius{10, 10}])!
	segs := p.path().segments()
	// 1 move + 4 (line, arc) pairs + close + move.
	assert segs.first().kind == .move_to
	assert segs.last().kind == .move_to
	assert segs.any(it.kind == .elliptical_arc_to)
	assert segs.any(it.kind == .close_path)
}

fn test_affine_transform_map_and_inverse() {
	// Scale by 2, translate by (5, 7).
	t := CanvasAffineTransform{
		a: 2
		d: 2
		e: 5
		f: 7
	}
	assert t.map(FloatPoint{1, 1}) == FloatPoint{7, 9}
	inv := t.inverse() or { panic('singular') }
	assert inv.map(FloatPoint{7, 9}) == FloatPoint{1, 1}
	// A singular matrix has no inverse.
	singular := CanvasAffineTransform{
		a: 0
		b: 0
		c: 0
		d: 0
	}
	assert singular.inverse() == none
}

fn test_path2d_copy_and_add_path() {
	mut source := Path2D.create()
	source.move_to(0, 0)
	source.line_to(10, 10)

	// Copy constructor duplicates the subpaths.
	copy := Path2D.create_from_path(source)
	assert copy.path().length() == 2

	// add_path appends a translated copy, then seeds a new subpath at its last point.
	mut target := Path2D.create()
	target.move_to(100, 100)
	translate := CanvasAffineTransform{
		e: 5
		f: 5
	}
	target.add_path(source, translate)
	segs := target.path().segments()
	// original move + appended (move, line) + trailing move.
	assert segs.len == 4
	// The appended line endpoint is translated by (5, 5): (10,10) → (15,15).
	assert segs[2].point == FloatPoint{15, 15}
	assert segs.last().kind == .move_to
	assert segs.last().point == FloatPoint{15, 15}
}
