module main

import layout
import math
import os
import painting

const shared_svg_mask_raster = os.getenv('VOX_SHARED_SVG_MASK_RASTER') == '1'

fn C.native_svg_content_mask_surface(f32, &i32, &f32, &&u8) i32

fn (mut app BrowserApp) raster_native_svg_content_mask(mask &layout.PaintClip, page_x f32,
	page_y f32) bool {
	if !shared_svg_mask_raster { return false }
	mut area := [4]i32{}
	mut backing_scale := f32(0)
	mut data := &u8(unsafe { nil })
	status := C.native_svg_content_mask_surface(f32(app.ctx.height), &area[0], &backing_scale, &data)
	if status != 1 { return status == 2 }
	if !portable_svg_content_mask_supported(mask) {
		return false
	}
	if !mask.mask_operations.any(it.fill_linear_gradient != none || it.fill_radial_gradient != none) {
		return false
	}
	scale := f64(backing_scale)
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
	if portable_svg_mask_diagnostics {
		eprintln('VOX_SHARED_SVG_MASK luminance=${mask.mask_luminance} operations=${mask.mask_operations.len} surface=${bounds.width}x${bounds.height}')
	}
	return true
}
