module ui2

// Generic vector decoration, expressed in an element's local coordinates.
// Backends paint it behind the element's content and ordinary UI2 actions.
pub struct VectorPoint {
pub:
	x f64
	y f64
}

pub struct VectorPath {
pub:
	points       []VectorPoint
	closed       bool = true
	fill_enabled bool = true
	fill         u32
	stroke       u32
	stroke_width f64
}

fn vector_cross(a VectorPoint, b VectorPoint, c VectorPoint) f64 {
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

// Ear clipping supports concave silhouettes without filling their cutouts.
// The returned triples index the original contour, in either winding order.
@[manualfree]
pub fn (path VectorPath) triangles() []int {
	if !path.closed || !path.fill_enabled || path.points.len < 3 { return []int{} }
	points := path.points
	mut area := 0.0
	for i, point in points {
		next := points[(i + 1) % points.len]
		area += point.x * next.y - next.x * point.y
	}
	if area == 0 { return []int{} }
	winding := if area > 0 { 1.0 } else { -1.0 }
	mut remaining := []int{len: points.len, init: index}
	defer { unsafe { remaining.free() } }
	mut result := []int{cap: (points.len - 2) * 3}
	for remaining.len > 2 {
		mut clipped := false
		for i, index in remaining {
			previous := remaining[(i + remaining.len - 1) % remaining.len]
			next := remaining[(i + 1) % remaining.len]
			a, b, c := points[previous], points[index], points[next]
			if vector_cross(a, b, c) * winding <= 0.00000001 { continue }
			mut contains := false
			for other in remaining {
				if other == previous || other == index || other == next { continue }
				p := points[other]
				if vector_cross(a, b, p) * winding >= -0.00000001
					&& vector_cross(b, c, p) * winding >= -0.00000001
					&& vector_cross(c, a, p) * winding >= -0.00000001 {
					contains = true
					break
				}
			}
			if contains { continue }
			result << previous
			result << index
			result << next
			remaining.delete(i)
			clipped = true
			break
		}
		if !clipped { break }
	}
	return result
}
