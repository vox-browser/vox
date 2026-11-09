module cpuraster

fn hit_test_rectangle(reverse bool) Path {
	mut b := PathBuilder{}
	b.move_to(0, 0)
	if reverse {
		b.line_to(0, 10)
		b.line_to(10, 10)
		b.line_to(10, 0)
	} else {
		b.line_to(10, 0)
		b.line_to(10, 10)
		b.line_to(0, 10)
	}
	b.close()
	return b.detach()
}

fn test_contains_boundaries_fill_rules_and_coincident_tangents() {
	rect := hit_test_rectangle(false)
	for point in [Point{5, 5}, Point{0, 0}, Point{10, 10}, Point{0, 5}] {
		assert rect.contains(point.x, point.y)
	}
	assert !rect.contains(10.001, 5)
	assert !Path{}.contains(0, 0)
	assert Path{ fill_type: .inverse_winding }.contains(0, 0)
	for reverse in [false, true] {
		other := hit_test_rectangle(reverse)
		compound := Path{
			verbs:  [...rect.verbs, ...other.verbs]
			points: [...rect.points, ...other.points]
		}
		assert compound.contains(5, 5) == !reverse
		assert compound.contains(0, 5) == !reverse
		assert compound.contains(0, 0) == !reverse
		odd := Path{ ...compound, fill_type: .even_odd }
		assert !odd.contains(5, 5)
		assert !odd.contains(0, 5)
	}
}

fn test_contains_monotonic_curve_crossings_and_extrema() {
	mut b := PathBuilder{}
	b.move_to(0, 0)
	b.quad_to(5, 10, 10, 0)
	b.close()
	quad := b.detach()
	assert quad.contains(5, 2)
	assert quad.contains(5, 5)
	assert !quad.contains(5, 6)
	b.move_to(0, 0)
	b.cubic_to(0, 10, 10, 10, 10, 0)
	b.close()
	cubic := b.detach()
	assert cubic.contains(5, 5)
	assert cubic.contains(5, 7.5)
	assert !cubic.contains(5, 8)
	b.move_to(0, 0)
	b.conic_to(5, 10, 10, 0, .5)
	b.close()
	conic := b.detach()
	assert conic.contains(5, 2)
	assert !conic.contains(5, 4)
}

fn test_path_hit_regions_caps_dashes_and_non_scaling_strokes() {
	mut b := PathBuilder{}
	b.move_to(0, 0)
	b.line_to(20, 0)
	line := b.detach()
	base := PathHitTest{ path: line, areas: 2, width: 4 }
	assert !path_hit_test(PathHitTest{ ...base, x: -1 })
	assert path_hit_test(PathHitTest{ ...base, x: -1, cap: .round })
	assert !path_hit_test(PathHitTest{ ...base, x: 7, dashes: [f32(5), 5] })
	assert path_hit_test(PathHitTest{ ...base, x: 2, dashes: [f32(5), 5] })
	assert path_hit_test(PathHitTest{ ...base, x: 10, y: 1.5 })
	assert !path_hit_test(PathHitTest{
		...base
		x:           20
		y:           3
		non_scaling: true
		transform:   [f32(2), 0, 0, 2, 0, 0]!
	})
	assert path_hit_test(PathHitTest{
		...base
		x:           30
		y:           1
		non_scaling: true
		transform:   [f32(2), 0, 0, 2, 0, 0]!
	})
	rect := hit_test_rectangle(false)
	assert path_hit_test(PathHitTest{ path: rect, x: 5, y: 5, areas: 1 })
	assert !path_hit_test(PathHitTest{ path: rect, x: 5, y: 5, areas: 2, width: 4 })
	assert path_hit_test(PathHitTest{ path: rect, x: -1, y: -1, areas: 2, width: 4 })
	assert !path_hit_test(PathHitTest{ path: rect, x: -1.9, y: -1.9, areas: 2, width: 4, join: .round })
}

fn hit_test_curve_segments(kind int, reverse bool) []f32 {
	mut segments := []f32{len: 36}
	segments[1] = if reverse { f32(10) } else { f32(0) }
	segments[12] = f32(kind)
	segments[13] = if reverse { f32(0) } else { f32(10) }
	if kind == 2 {
		segments[15], segments[16] = 5, 10
	} else if kind == 3 {
		segments[15] = if reverse { f32(10) } else { f32(0) }
		segments[16] = 10
		segments[17] = if reverse { f32(0) } else { f32(10) }
		segments[18] = 10
	} else {
		segments[19], segments[20] = 5, 5
		segments[23] = if reverse { f32(0) } else { f32(1) }
	}
	segments[24] = 5
	return segments
}

// Captured by native_path_hit_fixtures.py. Coincident boundary tangents
// deliberately retain the native numerical behavior for every fill rule.
fn test_contains_coincident_curve_native_fixtures() {
	expected := '111000000111000000111111111000000111100000011111011000100111000000111111'
	mut index := 0
	for kind in [2, 3, 4] {
		mid_y := if kind == 2 {
			f32(5)
		} else if kind == 3 {
			f32(7.5)
		} else {
			f32(-5)
		}
		for reverse in [false, true] {
			mut segments := hit_test_curve_segments(kind, false)
			segments << hit_test_curve_segments(kind, reverse)
			base := canvas_path(segments, false)
			for fill in 0 .. 4 {
				path := Path{ ...base, fill_type: unsafe { PathFillType(fill) } }
				for point in [Point{5, mid_y}, Point{0, 0},
					Point{5, if kind == 4 { f32(-1) } else { f32(1) }}] {
					assert path.contains(point.x, point.y) == (expected[index] == 49), 'native boundary case ${index}'
					index++
				}
			}
		}
	}
	assert index == expected.len
}
