module main

import cpuraster
import gg
import layout
import math
import os
import painting
import platform

const portable_svg_raster_slots = 16
const portable_svg_raster_path_values = 64 * layout.compatibility_clip_path_segment_stride
const portable_svg_stroke_dash_values = 32
const portable_svg_raster_gradient_values = 16 * 5
const disable_portable_svg_raster_cache = os.getenv('VOX_DISABLE_GG_SVG_CACHE') == '1'
const portable_svg_raster_diagnostics = os.getenv('VOX_GG_SVG_DIAGNOSTICS') == '1'

struct PortableSVGRasterKey {
	color       u32
	opacity_bits u32
	even_odd    bool
	// Fills leave the stroke fields zero. Strokes always have a positive width.
	width_bits  u32
	miter_bits  u32
	cap         int
	join        int
	non_scaling bool
	dash_len    int
	offset_bits u64
}

struct PortableSVGRasterGradientKey {
	kind          int
	spread        cpuraster.CanvasGradientSpread
	geometry      [7]u32
	has_transform bool
	transform     [6]u32
	stop_len      int
}

struct PortableSVGRaster {
mut:
	key          PortableSVGRasterKey
	matrix       [6]f32
	local_bounds cpuraster.Rect
	path_len     int
	path         [portable_svg_raster_path_values]f32
	dashes       [portable_svg_stroke_dash_values]f64
	gradient_key PortableSVGRasterGradientKey
	stops        [portable_svg_raster_gradient_values]f32
}

struct PortableSVGRasters {
mut:
	// Metadata follows the app's existing streaming image slots. The image
	// owns the pixels, and these bounded copies outlive document paint storage.
	entries [portable_svg_raster_slots]PortableSVGRaster
}

fn portable_svg_stroke_raster_key(data &layout.PaintSVGPathData, color u32, opacity f32, width f32,
	miter f32) PortableSVGRasterKey {
	return PortableSVGRasterKey{
		color:       color
		opacity_bits: math.f32_bits(opacity)
		width_bits:  math.f32_bits(width)
		miter_bits:  math.f32_bits(miter)
		cap:         data.stroke_linecap
		join:        data.stroke_linejoin
		non_scaling: data.non_scaling_stroke
		dash_len:    data.stroke_dasharray.len
		offset_bits: math.f64_bits(data.stroke_dashoffset)
	}
}

fn (entry &PortableSVGRaster) matches_path(values []f32) bool {
	return entry.path_len == values.len && unsafe {
		vmemcmp(&entry.path[0], values.data, values.len * int(sizeof(f32))) == 0
	}
}

fn (entry &PortableSVGRaster) matches_raster(key PortableSVGRasterKey,
	matrix [6]f32, dashes []f64) bool {
	return key == entry.key && unsafe {
		vmemcmp(&entry.matrix[0], &matrix[0], 6 * int(sizeof(f32))) == 0
	} && (key.dash_len == 0 || unsafe {
		vmemcmp(&entry.dashes[0], dashes.data, key.dash_len * int(sizeof(f64))) == 0
	})
}

fn portable_svg_raster_gradient_key(paint &cpuraster.CanvasGradient) PortableSVGRasterGradientKey {
	local := paint.local_transform or { [f32(0), 0, 0, 0, 0, 0]! }
	return PortableSVGRasterGradientKey{
		kind: paint.kind
		spread: paint.spread
		geometry: [math.f32_bits(paint.x0), math.f32_bits(paint.y0), math.f32_bits(paint.r0),
			math.f32_bits(paint.x1), math.f32_bits(paint.y1), math.f32_bits(paint.r1),
			math.f32_bits(paint.angle)]!
		has_transform: paint.local_transform != none
		transform: [math.f32_bits(local[0]), math.f32_bits(local[1]), math.f32_bits(local[2]),
			math.f32_bits(local[3]), math.f32_bits(local[4]), math.f32_bits(local[5])]!
		stop_len: paint.stops.len
	}
}

fn (entry &PortableSVGRaster) matches_gradient(gradient ?cpuraster.CanvasGradient) bool {
	if paint := gradient {
		return entry.gradient_key == portable_svg_raster_gradient_key(&paint) && unsafe {
			vmemcmp(&entry.stops[0], paint.stops.data, paint.stops.len * int(sizeof(f32))) == 0
		}
	}
	return entry.gradient_key.kind == 0
}

fn (app &BrowserApp) portable_svg_raster_cache_index(path_len int, dash_len int,
	gradient ?cpuraster.CanvasGradient) int {
	index := app.portable_raster_image_index
	if disable_portable_svg_raster_cache || index >= portable_svg_raster_slots
		|| path_len > portable_svg_raster_path_values || dash_len > portable_svg_stroke_dash_values {
		return -1
	}
	if paint := gradient {
		if paint.stops.len > portable_svg_raster_gradient_values { return -1 }
	}
	return index
}

fn (app &BrowserApp) cached_portable_svg_raster(index int, values []f32) &PortableSVGRaster {
	if index < 0 || index >= app.portable_raster_images.len || app.portable_svg_rasters == unsafe { nil } {
		return unsafe { nil }
	}
	entry := &app.portable_svg_rasters.entries[index]
	return if entry.matches_path(values) { entry } else { unsafe { nil } }
}

fn (mut app BrowserApp) draw_cached_portable_svg_raster(entry &PortableSVGRaster,
	key PortableSVGRasterKey, matrix [6]f32, bounds painting.IntRect, dashes []f64,
	gradient ?cpuraster.CanvasGradient) bool {
	if entry == unsafe { nil } || !entry.matches_raster(key, matrix, dashes)
		|| !entry.matches_gradient(gradient) {
		return false
	}
	slot := app.portable_raster_images[app.portable_raster_image_index]
	if slot.width != bounds.width || slot.height != bounds.height { return false }
	app.portable_raster_image_index++
	app.ctx.draw_image_with_config(img_id: slot.image_id,
		img_rect: app.portable_svg_texture_destination(bounds), color: gg.Color{255, 255, 255, 255})
	return true
}

fn (mut app BrowserApp) remember_portable_svg_raster(index int, data &layout.PaintSVGPathData,
	key PortableSVGRasterKey, matrix [6]f32, local cpuraster.Rect, gradient ?cpuraster.CanvasGradient) {
	if app.portable_svg_rasters == unsafe { nil } {
		persistent := platform.enter_persistent()
		app.portable_svg_rasters = &PortableSVGRasters{}
		platform.leave_persistent(persistent)
	}
	mut entry := &app.portable_svg_rasters.entries[index]
	entry.key = key
	entry.matrix = matrix
	entry.local_bounds = local
	entry.path_len = data.path_data.len
	unsafe {
		vmemcpy(&entry.path[0], data.path_data.data, entry.path_len * int(sizeof(f32)))
		if key.dash_len > 0 {
			vmemcpy(&entry.dashes[0], data.stroke_dasharray.data, key.dash_len * int(sizeof(f64)))
		}
	}
	if paint := gradient {
		entry.gradient_key = portable_svg_raster_gradient_key(&paint)
		unsafe { vmemcpy(&entry.stops[0], paint.stops.data, paint.stops.len * int(sizeof(f32))) }
	} else {
		entry.gradient_key = PortableSVGRasterGradientKey{}
	}
}

fn log_portable_svg_raster_cache(operation string, result string, bounds painting.IntRect,
	gradient ?cpuraster.CanvasGradient) {
	if portable_svg_raster_diagnostics {
		kind := if paint := gradient { paint.kind } else { 0 }
		eprintln('VOX_CPU_SVG_${operation} draw=${bounds.width}x${bounds.height} cache=${result} gradient=${kind}')
	}
}
