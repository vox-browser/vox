module main

import cpuraster
import layout
import math
import painting

const svg_mask_polygon_max_viewports = 8

fn svg_mask_rect_corners(rect painting.Rect, transform painting.Affine) [4]painting.Point {
	return [
		transform.map_point(painting.Point{rect.x, rect.y}),
		transform.map_point(painting.Point{rect.right(), rect.y}),
		transform.map_point(painting.Point{rect.right(), rect.bottom()}),
		transform.map_point(painting.Point{rect.x, rect.bottom()}),
	]!
}

fn svg_mask_viewport_polygon(rect painting.Rect, transform painting.Affine, opening &layout.PaintCommand,
	first &layout.PaintCommand, mask_transform [6]f64, page_x f32, page_y f32,
	scale f64) ?[]painting.Point {
	corners := svg_mask_rect_corners(rect, transform)
	if !svg_mask_finite_corners(corners) { return none }
	mut polygon := corners[..].clone()
	mut clip_count := 0
	for command in [opening, first]! {
		if command.clip_list == unsafe { nil } { continue }
		for clip in command.clip_list.items {
			if clip.corner_radii != layout.BoxRadii{} { continue }
			if clip.transform == mask_transform && (clip.transform[1] != 0 || clip.transform[2] != 0) {
				continue
			}
			clip_count++
			if clip_count > svg_mask_polygon_max_viewports { return none }
			local := painting.Rect{clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height}
			if local.is_empty() { return []painting.Point{} }
			device := portable_device_transform(clip.transform, page_x, page_y, scale)
			quad := svg_mask_rect_corners(local, device)
			if !svg_mask_finite_corners(quad) { return none }
			orientation := svg_mask_clip_edge_distance(quad[0], quad[1], quad[2])
			if orientation == 0 { return []painting.Point{} }
			winding := if orientation > 0 { 1.0 } else { -1.0 }
			for i in 0 .. quad.len {
				polygon = clip_svg_mask_polygon(polygon, quad[i], quad[(i + 1) % quad.len], winding)
				if polygon.len < 3 { return []painting.Point{} }
			}
		}
	}
	return polygon
}

fn apply_svg_mask_rounded_viewports(mut image PortableSVGGroupImage, opening &layout.PaintCommand,
	first &layout.PaintCommand, page_x f32, page_y f32, scale f64) bool {
	bounds := image.bounds
	mut coverage := []u8{len: bounds.width * bounds.height}
	// Only the initialized prefix is inspected.
	mut applied := unsafe { [svg_mask_polygon_max_viewports]&layout.PaintClip{} }
	mut count := 0
	for command in [opening, first]! {
		if command.clip_list == unsafe { nil } { continue }
		for i in 0 .. command.clip_list.items.len {
			clip := &command.clip_list.items[i]
			radii := clip.corner_radii
			if radii == layout.BoxRadii{} { continue }
			if applied[..count].any(same_svg_mask_viewport(it, clip)) { continue }
			if count == applied.len { return false }
			rect := clip.rect
			if rect.width <= 0 || rect.height <= 0 {
				unsafe { vmemset(image.pixels.data, 0, image.pixels.len) }
				return true
			}
			transform := portable_device_transform(clip.transform, page_x, page_y, scale)
			matrix := portable_svg_surface_matrix(transform, bounds)
			edges := [f32(rect.x), f32(rect.y), f32(rect.x + rect.width), f32(rect.y + rect.height)]!
			corners := [f32(radii.top_left.x), f32(radii.top_left.y),
				f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x),
				f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y)]!
			if !matrix.all(math.is_finite(f64(it))) || !edges.all(math.is_finite(f64(it)))
				|| !corners.all(math.is_finite(f64(it))) {
				return false
			}
			rounded := cpuraster.rounded_rect(cpuraster.Rect{edges[0], edges[1], edges[2], edges[3]}, corners)
			if count > 0 {
				unsafe { vmemset(coverage.data, 0, coverage.len) }
			}
			if !cpuraster.fill_opaque_coverage(mut coverage, bounds.width, bounds.height,
				rounded.path(), matrix) {
				return false
			}
			apply_portable_svg_clip_coverage(mut image, coverage)
			applied[count] = clip
			count++
		}
	}
	return true
}

fn svg_mask_finite_corners(corners [4]painting.Point) bool {
	for point in corners {
		// Keep the edge products within finite device-coordinate precision.
		if !(math.abs(point.x) < 1073741824 && math.abs(point.y) < 1073741824) { return false }
	}
	return true
}

@[inline]
fn svg_mask_clip_edge_distance(from painting.Point, to painting.Point, point painting.Point) f64 {
	return (to.x - from.x) * (point.y - from.y) - (to.y - from.y) * (point.x - from.x)
}

// Clip one convex polygon against a directed edge. Intersect the geometry
// before antialiasing so coincident edges contribute coverage only once.
fn clip_svg_mask_polygon(points []painting.Point, from painting.Point, to painting.Point,
	winding f64) []painting.Point {
	mut clipped := []painting.Point{cap: points.len + 1}
	mut previous := points.last()
	mut previous_distance := svg_mask_clip_edge_distance(from, to, previous) * winding
	for point in points {
		distance := svg_mask_clip_edge_distance(from, to, point) * winding
		if (previous_distance < 0 && distance > 0) || (previous_distance > 0 && distance < 0) {
			fraction := previous_distance / (previous_distance - distance)
			clipped << painting.Point{
				x: previous.x + (point.x - previous.x) * fraction
				y: previous.y + (point.y - previous.y) * fraction
			}
		}
		if distance >= 0 { clipped << point }
		previous = point
		previous_distance = distance
	}
	return clipped
}

fn svg_mask_polygon_bounds(polygon []painting.Point) painting.Rect {
	mut left := polygon[0].x
	mut top := polygon[0].y
	mut right := left
	mut bottom := top
	for point in polygon[1..] {
		left = math.min(left, point.x)
		top = math.min(top, point.y)
		right = math.max(right, point.x)
		bottom = math.max(bottom, point.y)
	}
	return painting.Rect{left, top, right - left, bottom - top}
}
