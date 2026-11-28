module main

import layout
import painting

// layout/scroll_raster_backdrop.v: a backdrop filter's key ink is the region
// it reads. Pixels it samples outside the damage would come from the retained
// frame, which holds what was painted after it as well as its own previous
// output, so any damage touching that region repaints all of it: a clipped
// replay then paints everything the filter samples in paint order, as a
// complete replay does. Repeat until no further region is touched, since a
// repainted region can reach another backdrop.
fn scroll_raster_backdrop_regions(current []ScrollRasterCommandKey, width f64, height f64) []layout.LayoutRect {
	if layout.retain_backdrop_raster_rejection { return []layout.LayoutRect{} }
	viewport := layout.LayoutRect{0, 0, width, height}
	mut regions := []layout.LayoutRect{}
	for key in current {
		if key.kind != 'apply_backdrop_filter' || !key.has_ink { continue }
		fringed := scroll_raster_inflate(key.ink, scroll_raster_damage_fringe)
		visible := layout.scroll_raster_rect_intersect(fringed, viewport)
		if visible.width <= 0 || visible.height <= 0 { continue }
		regions << scroll_raster_snap_rect(visible)
	}
	return regions
}

// Adds each region that `damage` or the exposed strip touches; whether any
// region was added.
fn scroll_raster_extend_backdrop_damage(mut damage []layout.LayoutRect, regions []layout.LayoutRect,
	strip []layout.LayoutRect, mut added []bool) bool {
	mut grew := false
	for {
		mut changed := false
		for index, region in regions {
			if added[index] { continue }
			if damage.any(scroll_raster_rects_overlap(it, region))
				|| strip.any(scroll_raster_rects_overlap(it, region)) {
				damage << region
				added[index] = true
				changed = true
				grew = true
			}
		}
		if !changed { break }
	}
	return grew
}

// The exposed strip, widened by a pixel for the whole-pixel shift the native
// ring applies to the retained frame.
fn scroll_raster_backdrop_strip(delta f64, width f64, height f64) []layout.LayoutRect {
	return scroll_raster_strip_region(delta, width, height).map(scroll_raster_inflate(it, 2.0))
}

// Backdrop filters enter the key by value, so an unchanged filter recorded
// again does not damage its region on every frame.
fn srk_backdrop_filter(h u64, filter &painting.GfxFilter) u64 {
	if filter.nodes.len > 0 || filter.root_id != none { return srk_ptr(h, voidptr(filter)) }
	mut result := srk_int(h, filter.operations.len)
	for operation in filter.operations {
		result = srk_str(result, operation.kind)
		result = srk_f64(result, operation.first)
		result = srk_f64(result, operation.second)
		result = srk_f64(result, operation.third)
		result = srk_int(result, int(operation.color_operation))
		result = srk_int(result, int(operation.color.r) | int(operation.color.g) << 8
			| int(operation.color.b) << 16 | int(operation.color.a) << 24)
	}
	return result
}
