module main

import layout
import math
import os
import painting

const shared_svg_mask_raster = os.getenv('VOX_SHARED_SVG_MASK_RASTER') == '1'
const disable_shared_svg_mask_cache = os.getenv('VOX_DISABLE_SHARED_SVG_MASK_CACHE') == '1'
const eager_shared_svg_mask_bitmap = os.getenv('VOX_EAGER_SHARED_SVG_MASK_BITMAP') == '1'
const copy_shared_svg_mask_bitmap = os.getenv('VOX_COPY_SHARED_SVG_MASK_BITMAP') == '1'

fn C.native_prepare_svg_content_mask(u64, i32, f32, f32, &f32, &f32, f32, f32, f32) f64
fn C.native_begin_svg_content_mask_bitmap(f64, f32, &f32, &f32, f32, f32, f32)
fn C.native_svg_content_mask_geometry(f32, f64, &i32) i32
fn C.native_svg_content_mask_pixels(f64, i32) &u8
fn C.native_reuse_svg_mask_raster(u64) i32
fn C.native_publish_svg_mask_raster(u64, i32) i32

fn shared_svg_mask_raster_key(mask &layout.PaintClip, area [4]i32, bounds painting.IntRect,
	page_x f32, page_y f32, scale f64) u64 {
	// Keep the native cache within its per-image memory budget. Both padding
	// and clipping are relative to the borrowed bitmap, which moves on scroll.
	if disable_shared_svg_mask_cache || mask.mask_raster_key == 0
		|| int(area[2]) * int(area[3]) > 128 * 1024 {
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

fn (mut app BrowserApp) raster_native_svg_content_mask(mask &layout.PaintClip, page_x f32,
	page_y f32, scale f64) bool {
	if scale == 0 { return true }
	mut area := [4]i32{}
	if C.native_svg_content_mask_geometry(f32(app.ctx.height), scale, &area[0]) == 0 {
		return false
	}
	if !portable_svg_content_mask_supported(mask) {
		return false
	}
	if !mask.mask_operations.any(it.fill_linear_gradient != none || it.fill_radial_gradient != none) {
		return false
	}
	transform := portable_device_transform(mask.transform, page_x, page_y, scale)
	rect := mask.rect
	region := transform.map_rect(painting.Rect{rect.x, rect.y, rect.width, rect.height})
	image := painting.Rect{f64(area[0]), f64(area[1]), f64(area[2]), f64(area[3])}
	// Borrow only the integer mask area. Quartz retains fractional coverage
	// and the transparent padding around the bitmap.
	if ![region.x, region.y, region.right(), region.bottom()]!.all(math.is_finite(it)
		&& it == math.floor(it)) {
		return false
	}
	bounds := portable_pixel_bounds(region.intersection(image))
	if bounds.is_empty() { return true }
	raster_key := shared_svg_mask_raster_key(mask, area, bounds, page_x, page_y, scale)
	if raster_key != 0 {
		hit := C.native_reuse_svg_mask_raster(raster_key)
		if hit != 0 {
			if portable_svg_mask_diagnostics {
				eprintln('VOX_SHARED_SVG_MASK_CACHE_HIT luminance=${mask.mask_luminance} surface=${bounds.width}x${bounds.height} bitmap_allocated=${hit == 2}')
			}
			return true
		}
	}
	data := C.native_svg_content_mask_pixels(scale, area[2])
	if data == unsafe { nil } { return false }
	pitch := int(area[2]) * 4
	offset := (bounds.y - int(area[1])) * pitch + (bounds.x - int(area[0])) * 4
	length := (bounds.height - 1) * pitch + bounds.width * 4
	mut pixels := unsafe { (data + offset).vbytes(length) }
	if !app.raster_svg_content_mask(mut pixels, pitch, bounds, mask, page_x, page_y, scale) {
		for y in 0 .. bounds.height {
			unsafe { vmemset(data + offset + y * pitch, 0, bounds.width * 4) }
		}
		return false
	}
	published := C.native_publish_svg_mask_raster(raster_key, i32(!copy_shared_svg_mask_bitmap))
	if portable_svg_mask_diagnostics {
		eprintln('VOX_SHARED_SVG_MASK luminance=${mask.mask_luminance} operations=${mask.mask_operations.len} surface=${bounds.width}x${bounds.height} bitmap_reused=${published == 2}')
	}
	return true
}
