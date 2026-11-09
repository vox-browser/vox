module cpuraster

// Rectangle queries use the actual Bezier boundary, including rational conics.
// Control-point boxes alone give false positives in holes and near curves.
pub fn (path Path) relates_to_rect(rect Rect, enclosed bool) bool {
	if rect.right < rect.left || rect.bottom < rect.top { return false }
	edges := path_edges(path)
	if edges.len == 0 { return false }
	mut intersects := false
	for edge in edges {
		mut samples := [f32(0), 1]
		for horizontal in [true, false] {
			samples << region_edge_extrema(edge, horizontal)
			if !enclosed {
				for boundary in if horizontal {
					[rect.left, rect.right]
				} else {
					[rect.top, rect.bottom]
				} {
					samples << region_edge_roots(edge, horizontal, boundary)
				}
			}
		}
		for t in samples {
			x, y := region_edge_coordinate(edge, true, t), region_edge_coordinate(edge, false, t)
			inside := x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
			if enclosed && !inside { return false }
			if inside { intersects = true }
		}
	}
	if enclosed || intersects { return true }
	for point in [Point{rect.left, rect.top}, Point{rect.right, rect.top},
		Point{rect.left, rect.bottom}, Point{rect.right, rect.bottom}] {
		if path.contains(point.x, point.y) { return true }
	}
	return false
}

fn region_edge_values(edge PathEdge, horizontal bool) []f32 {
	return edge.pts.map(if horizontal { it.x } else { it.y })
}

fn region_edge_coordinate(edge PathEdge, horizontal bool, t f32) f32 {
	p := region_edge_values(edge, horizontal)
	u := 1 - t
	return match edge.verb {
		.line { u * p[0] + t * p[1] }
		.quad { u * u * p[0] + 2 * u * t * p[1] + t * t * p[2] }
		.conic { (u * u * p[0] + 2 * edge.weight * u * t * p[1] + t * t * p[2]) / (u * u + 2 * edge.weight * u * t + t * t) }
		.cubic { u * u * u * p[0] + 3 * u * u * t * p[1] + 3 * u * t * t * p[2] + t * t * t * p[3] }
		else { p[0] }
	}
}

fn region_edge_roots(edge PathEdge, horizontal bool, target f32) []f32 {
	p := region_edge_values(edge, horizontal)
	return match edge.verb {
		.line {
			if p[0] == p[1] {
				[]f32{}
			} else {
				t := (target - p[0]) / (p[1] - p[0])
				if t >= 0 && t <= 1 { [t] } else { []f32{} }
			}
		}
		.quad { find_unit_quad_roots(p[0] - 2 * p[1] + p[2], 2 * (p[1] - p[0]), p[0] - target) }
		.conic {
			find_unit_quad_roots(p[0] - 2 * edge.weight * p[1] + p[2] - 2 * target * (1 - edge.weight), 2 * (edge.weight * p[1] - p[0] - target * (edge.weight - 1)), p[0] - target)
		}
		.cubic {
			cubics_roots_valid_t(f64(-p[0] + 3 * p[1] - 3 * p[2] + p[3]), f64(3 * (p[0] - 2 * p[1] + p[2])), f64(3 * (p[1] - p[0])), f64(p[0] - target)).map(f32(it))
		}
		else { []f32{} }
	}
}

fn region_edge_extrema(edge PathEdge, horizontal bool) []f32 {
	p := region_edge_values(edge, horizontal)
	return match edge.verb {
		.quad { find_unit_quad_roots(0, 2 * (p[0] - 2 * p[1] + p[2]), 2 * (p[1] - p[0])) }
		.conic {
			a, b, c := p[0] - 2 * edge.weight * p[1] + p[2], 2 * (edge.weight * p[1] - p[0]), p[0]
			d, e := 2 * (1 - edge.weight), 2 * (edge.weight - 1)
			find_unit_quad_roots(a * e - b * d, 2 * (a - c * d), b - c * e)
		}
		.cubic { find_cubic_extrema(p[0], p[1], p[2], p[3]) }
		else { []f32{} }
	}
}
