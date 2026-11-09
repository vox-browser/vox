module cpuraster

import math

// Reuse the contour measure used by dashing, including rational conics and
// reflected curves. SVG distance queries span all contours and clamp endpoints.
pub fn (path Path) point_at_distance(distance f64) Point {
	mut iterator := new_contour_measure_iter(path,1024)
	mut remaining := math.max(0,distance)
	mut last := if path.points.len > 0 { path.points[0] } else { Point{} }
	for {
		contour := iterator.next() or { return last }
		if contour.segments.len == 0 { continue }
		if remaining <= f64(contour.length) {
			index,t := contour.distance_to_segment(f32(remaining))
			return contour.position(contour.segments[index],t)
		}
		last = contour.position(contour.segments.last(),1)
		remaining -= contour.length
	}
	return last
}
