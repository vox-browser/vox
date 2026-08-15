module geometry

import math

fn test_domquadinit_defaults() {
	// Each corner is a DOMPointInit, so w defaults to 1.
	init := DOMQuadInit{}
	assert init.p1.x == 0.0
	assert init.p1.w == 1.0
	assert init.p4.w == 1.0
}

fn test_construct_and_getters() {
	quad := DOMQuad.construct(DOMPointInit{ x: 1.0, y: 2.0 }, DOMPointInit{ x: 3.0, y: 4.0 },
		DOMPointInit{ x: 5.0, y: 6.0 }, DOMPointInit{ x: 7.0, y: 8.0 })
	assert quad.p1().x() == 1.0
	assert quad.p1().y() == 2.0
	assert quad.p2().x() == 3.0
	assert quad.p3().y() == 6.0
	assert quad.p4().x() == 7.0
	// Each corner defaults w to 1 (from DOMPointInit).
	assert quad.p1().w() == 1.0
}

fn test_create_empty() {
	quad := DOMQuad.create()
	// The empty points mirror DOMPoint.create() — all coordinates 0.
	assert quad.p1().x() == 0.0
	assert quad.p1().w() == 0.0
	assert quad.p4().y() == 0.0
}

fn test_from_rect_corners() {
	quad := DOMQuad.from_rect(DOMRectInit{ x: 10.0, y: 20.0, width: 30.0, height: 40.0 })
	// p1 top-left, p2 top-right, p3 bottom-right, p4 bottom-left.
	assert quad.p1().x() == 10.0 && quad.p1().y() == 20.0
	assert quad.p2().x() == 40.0 && quad.p2().y() == 20.0
	assert quad.p3().x() == 40.0 && quad.p3().y() == 60.0
	assert quad.p4().x() == 10.0 && quad.p4().y() == 60.0
}

fn test_from_quad() {
	quad := DOMQuad.from_quad(DOMQuadInit{
		p1: DOMPointInit{ x: 1.0, y: 1.0 }
		p2: DOMPointInit{ x: 2.0, y: 3.0 }
		p3: DOMPointInit{ x: 4.0, y: 7.0 }
		p4: DOMPointInit{ x: 0.0, y: 3.0 }
	})
	assert quad.p2().x() == 2.0
	assert quad.p3().y() == 7.0
}

fn test_get_bounds_matches_source_rect() {
	quad := DOMQuad.from_rect(DOMRectInit{ x: 10.0, y: 20.0, width: 30.0, height: 40.0 })
	bounds := quad.get_bounds()
	assert bounds.x() == 10.0
	assert bounds.y() == 20.0
	assert bounds.width() == 30.0
	assert bounds.height() == 40.0
}

fn test_get_bounds_arbitrary_quad() {
	// Points (1,1) (5,2) (4,7) (0,3): left=0, top=1, right=5, bottom=7.
	quad := DOMQuad.construct(DOMPointInit{ x: 1.0, y: 1.0 }, DOMPointInit{ x: 5.0, y: 2.0 },
		DOMPointInit{ x: 4.0, y: 7.0 }, DOMPointInit{ x: 0.0, y: 3.0 })
	bounds := quad.get_bounds()
	assert bounds.x() == 0.0
	assert bounds.y() == 1.0
	assert bounds.width() == 5.0 // right(5) - left(0)
	assert bounds.height() == 6.0 // bottom(7) - top(1)
}

fn test_get_bounds_nan_propagates() {
	nan := math.nan()
	// A NaN x on any corner makes the x-derived bounds NaN, while the finite y's stay finite.
	quad := DOMQuad.construct(DOMPointInit{ x: nan, y: 1.0 }, DOMPointInit{ x: 5.0, y: 2.0 },
		DOMPointInit{ x: 4.0, y: 7.0 }, DOMPointInit{ x: 0.0, y: 3.0 })
	bounds := quad.get_bounds()
	assert math.is_nan(bounds.x()) // left is NaN
	assert math.is_nan(bounds.width()) // right - left is NaN
	assert bounds.y() == 1.0
	assert bounds.height() == 6.0
}
