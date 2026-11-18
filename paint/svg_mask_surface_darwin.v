module main

import layout
import math
import os
import painting

const shared_svg_mask_raster_mode = os.getenv('VOX_SHARED_SVG_MASK_RASTER')
const shared_svg_mask_raster = shared_svg_mask_raster_mode in ['', '1']
const force_shared_svg_mask_raster = shared_svg_mask_raster_mode == '1'
const disable_shared_svg_mask_cache = os.getenv('VOX_DISABLE_SHARED_SVG_MASK_CACHE') == '1'
const eager_shared_svg_mask_bitmap = os.getenv('VOX_EAGER_SHARED_SVG_MASK_BITMAP') == '1'
const copy_shared_svg_mask_bitmap = os.getenv('VOX_COPY_SHARED_SVG_MASK_BITMAP') == '1'
const clip_shared_svg_mask_raster = os.getenv('VOX_CLIP_SHARED_SVG_MASK_RASTER') == '1'
const shared_svg_mask_cache_pixel_limit = 128 * 1024

fn C.native_prepare_svg_content_mask(u64, i32, f32, f32, &f32, &f32, f32, f32, f32) f64
fn C.native_begin_svg_content_mask_bitmap(f64, f32, &f32, &f32, f32, f32, f32)
fn C.native_svg_content_mask_geometry(f32, f64, &i32) i32
fn C.native_svg_content_mask_pixels(f64, i32, i32) &u8
fn C.native_discard_svg_mask_bitmap()
fn C.native_reuse_svg_mask_raster(u64, &i32) i32
fn C.native_can_admit_svg_mask_raster() i32
fn C.native_publish_svg_mask_raster(u64, i32, &i32) i32

fn shared_svg_mask_raster_key(mask &layout.PaintClip, area [4]i32, bounds painting.IntRect,
	page_x f32, page_y f32, scale f64) u64 {
	// Keep the native cache within its per-image memory budget. Both padding
	// and clipping are relative to the borrowed bitmap, which moves on scroll.
	if disable_shared_svg_mask_cache || mask.mask_raster_key == 0
		|| int(area[2]) * int(area[3]) > shared_svg_mask_cache_pixel_limit {
		return 0
	}
	mut key := mask.mask_raster_key
	for value in [int(area[2]), int(area[3]), bounds.x - int(area[0]), bounds.y - int(area[1]),
		bounds.width, bounds.height]! {
		key = (key ^ u64(value)) * u64(1099511628211)
	}
	key = (key ^ math.f64_bits(scale)) * u64(1099511628211)
	for index in 0 .. mask.mask_operations.len {
		operation := &mask.mask_operations[index]
		if operation.kind != .path { continue }
		transform := portable_device_transform(operation.transform, page_x, page_y, scale)
		// Hash the exact matrix passed to the CPU rasterizer, including the
		// subpixel phase of paths within an aligned mask region.
		for value in portable_svg_surface_matrix(transform, bounds) {
			key = (key ^ u64(math.f32_bits(value))) * u64(1099511628211)
		}
	}
	return key
}

fn (app &BrowserApp) shared_svg_mask_full_area(region painting.Rect, visible painting.Rect,
	scale f64) ?[4]i32 {
	if scale != math.floor(scale) { return none }
	// Match the one-CSS-pixel fringe of native_svg_mask_canvas_rect().
	full := painting.Rect{region.x - scale, region.y - scale, region.width + 2 * scale,
		region.height + 2 * scale}
	if full.width > 16384 || full.height > 16384
		|| full.width * full.height > shared_svg_mask_cache_pixel_limit {
		return none
	}
	canvas := painting.Rect{0, 0, f64(app.ctx.width) * scale, f64(app.ctx.height) * scale}
	if full.intersection(canvas) != visible { return none }
	return [i32(full.x), i32(full.y), i32(full.width), i32(full.height)]!
}

fn native_svg_mask_opacity_depth(operations []layout.PaintMaskOperation) int {
	if operations.len < 3 || operations.len > 2 * portable_svg_mask_max_opacity_depth + 2
		|| operations[0].kind != .begin_opacity {
		return 0
	}
	// Keep the groups nested around the same one or two aligned fills.
	mut depth := 0
	for depth < operations.len && operations[depth].kind == .begin_opacity {
		depth++
	}
	fills := operations.len - 2 * depth
	if depth > portable_svg_mask_max_opacity_depth || fills < 1 || fills > 2 { return 0 }
	for index in depth .. operations.len - depth {
		if operations[index].kind != .path { return 0 }
	}
	for index in operations.len - depth .. operations.len {
		if operations[index].kind != .end_opacity { return 0 }
	}
	return depth
}

struct NativeSVGMaskFillCounts {
	fills     int
	gradients int
}

fn native_svg_mask_fill_counts(operations []layout.PaintMaskOperation) NativeSVGMaskFillCounts {
	// Bound the amount of work on a cache miss. The shared validator checks
	// that the opacity scopes balance and fit the rasterizer's layer limit.
	if operations.len > 12 { return NativeSVGMaskFillCounts{} }
	mut fills := 0
	mut gradients := 0
	for index in 0 .. operations.len {
		operation := &operations[index]
		match operation.kind {
			.path {
				// Radial fills retain the narrower nested-group eligibility.
				if operation.fill_radial_gradient != none { return NativeSVGMaskFillCounts{} }
				if operation.fill_linear_gradient != none {
					gradients++
				}
				fills++
			}
			.begin_opacity, .end_opacity {}
			.image { return NativeSVGMaskFillCounts{} }
		}
	}
	if fills > 6 || gradients > 2 { return NativeSVGMaskFillCounts{} }
	return NativeSVGMaskFillCounts{fills, gradients}
}

fn (mut app BrowserApp) raster_native_svg_content_mask(mask &layout.PaintClip, page_x f32,
	page_y f32, scale f64) bool {
	can_keep_full_raster := !clip_shared_svg_mask_raster && !disable_shared_svg_mask_cache
		&& !eager_shared_svg_mask_bitmap && mask.mask_raster_key != 0
	operations := mask.mask_operations
	counts := if force_shared_svg_mask_raster || can_keep_full_raster {
		native_svg_mask_fill_counts(operations)
	} else {
		NativeSVGMaskFillCounts{}
	}
	standalone_fills := counts.fills > 0 && counts.fills == operations.len
	// Single gradients keep their strip, diagonal and radial paths.
	automatic_fills := !force_shared_svg_mask_raster && can_keep_full_raster && standalone_fills
		&& (counts.gradients == 0 || counts.fills > 1)
	grouped_fills := counts.fills > 0 && counts.fills < operations.len
	automatic_opacity_group := !force_shared_svg_mask_raster && can_keep_full_raster
		&& (grouped_fills || native_svg_mask_opacity_depth(operations) > 0)
	mut automatic_radial := false
	mut automatic_diagonal := false
	if !force_shared_svg_mask_raster && !automatic_opacity_group && !automatic_fills {
		if mask.mask_operations.len != 1 { return false }
		operation := &mask.mask_operations[0]
		if linear := operation.fill_linear_gradient {
			if disable_svg_mask_ramp { return false }
			automatic_diagonal = can_keep_full_raster
				&& f32(linear.start_point.x) != f32(linear.end_point.x)
				&& f32(linear.start_point.y) != f32(linear.end_point.y)
		} else {
			automatic_radial = can_keep_full_raster && operation.fill_radial_gradient != none
			if !automatic_radial { return false }
		}
	}
	if scale == 0 { return true }
	mut area := [4]i32{}
	if C.native_svg_content_mask_geometry(f32(app.ctx.height), scale, &area[0]) == 0 {
		return false
	}
	if !portable_svg_content_mask_supported(mask) {
		return false
	}
	if counts.fills == 0
		&& !mask.mask_operations.any(it.fill_linear_gradient != none || it.fill_radial_gradient != none) {
		return false
	}
	transform := portable_device_transform(mask.transform, page_x, page_y, scale)
	rect := mask.rect
	region := transform.map_rect(painting.Rect{rect.x, rect.y, rect.width, rect.height})
	image := painting.Rect{f64(area[0]), f64(area[1]), f64(area[2]), f64(area[3])}
	// Borrow only the integer mask area. Quartz retains fractional coverage
	// and the transparent padding around the bitmap.
	for edge in [region.x, region.y, region.right(), region.bottom()]! {
		if !math.is_finite(edge) || edge != math.floor(edge) { return false }
	}
	mut bounds := portable_pixel_bounds(region.intersection(image))
	if bounds.is_empty() { return true }
	mut raster_area := area
	mut crop_area := [4]i32{}
	mut keeps_full_raster := false
	if can_keep_full_raster {
		if full := app.shared_svg_mask_full_area(region, image, scale) {
			keeps_full_raster = true
			if full != area {
				raster_area = full
				bounds = portable_pixel_bounds(region)
				crop_area = [area[0] - full[0], area[1] - full[1], area[2], area[3]]!
			}
		}
	}
	cropped := crop_area[2] != 0
	requires_cache := automatic_radial || automatic_diagonal || automatic_opacity_group || automatic_fills
	if requires_cache && !keeps_full_raster { return false }
	if automatic_radial {
		if svg_background_rectangle_path(operations[0].path_data) == none { return false }
	} else if requires_cache || (counts.fills > 0 && counts.gradients == 0) {
		for index in 0 .. operations.len {
			operation := &operations[index]
			if operation.kind != .path { continue }
			device := portable_device_transform(operation.transform, page_x, page_y, scale)
			if svg_mask_aligned_rect(operation, portable_svg_surface_matrix(device, bounds)) == none {
				return false
			}
		}
	} else if !force_shared_svg_mask_raster {
		if int(raster_area[2]) * int(raster_area[3]) > shared_svg_mask_cache_pixel_limit {
			return false
		}
		ramp := svg_mask_ramp(mask, bounds, page_x, page_y, scale) or { return false }
		// Keep Quartz's sampling for reflected alpha gradients at low backing scale.
		if !mask.mask_luminance && scale < 2 && (ramp.transform[0] < 0 || ramp.transform[3] < 0) {
			return false
		}
	}
	raster_key := shared_svg_mask_raster_key(mask, raster_area, bounds, page_x, page_y, scale)
	if raster_key != 0 {
		hit := C.native_reuse_svg_mask_raster(raster_key, &crop_area[0])
		if hit != 0 {
			if portable_svg_mask_diagnostics {
				eprintln('VOX_SHARED_SVG_MASK_CACHE_HIT luminance=${mask.mask_luminance} surface=${bounds.width}x${bounds.height} viewport_crop=${cropped} bitmap_allocated=${hit == 2}')
			}
			return true
		}
	}
	if requires_cache && (raster_key == 0 || C.native_can_admit_svg_mask_raster() == 0) {
		if portable_svg_mask_diagnostics {
			kind := if automatic_fills {
				if counts.gradients == 0 { 'SOLID' } else { 'GRADIENT' }
			} else if automatic_radial {
				'RADIAL'
			} else if automatic_opacity_group {
				'OPACITY'
			} else {
				'DIAGONAL'
			}
			eprintln('VOX_SHARED_SVG_MASK_SKIP_${kind}_CACHE')
		}
		return false
	}
	data := C.native_svg_content_mask_pixels(scale, raster_area[2], raster_area[3])
	if data == unsafe { nil } {
		if cropped { C.native_discard_svg_mask_bitmap() }
		return false
	}
	pitch := int(raster_area[2]) * 4
	offset := (bounds.y - int(raster_area[1])) * pitch + (bounds.x - int(raster_area[0])) * 4
	length := (bounds.height - 1) * pitch + bounds.width * 4
	mut pixels := unsafe { (data + offset).vbytes(length) }
	if !app.raster_svg_content_mask(mut pixels, pitch, bounds, mask, page_x, page_y, scale) {
		if cropped {
			C.native_discard_svg_mask_bitmap()
			return false
		}
		for y in 0 .. bounds.height {
			unsafe { vmemset(data + offset + y * pitch, 0, bounds.width * 4) }
		}
		return false
	}
	published := C.native_publish_svg_mask_raster(raster_key, i32(!copy_shared_svg_mask_bitmap), &crop_area[0])
	if cropped && published == 0 { return false }
	if portable_svg_mask_diagnostics {
		eprintln('VOX_SHARED_SVG_MASK luminance=${mask.mask_luminance} operations=${mask.mask_operations.len} surface=${bounds.width}x${bounds.height} viewport_crop=${cropped} resource_key=${mask.mask_raster_key} bitmap_reused=${published == 2}')
	}
	return true
}
