module main

import cpuraster
import layout
import math
import os
import platform

const portable_svg_stroke_slots = 16
const portable_svg_stroke_path_values = 64 * layout.compatibility_clip_path_segment_stride
const portable_svg_stroke_dash_values = 32
const disable_portable_svg_stroke_cache = os.getenv('VOX_DISABLE_GG_SVG_CACHE') == '1'
const portable_svg_stroke_diagnostics = os.getenv('VOX_GG_SVG_DIAGNOSTICS') == '1'

struct PortableSVGStrokeRasterKey {
	color       u32
	width_bits  u32
	miter_bits  u32
	cap         int
	join        int
	non_scaling bool
	dash_len    int
	offset_bits u64
}

struct PortableSVGStrokeRaster {
mut:
	key          PortableSVGStrokeRasterKey
	matrix       [6]f32
	local_bounds cpuraster.Rect
	path_len     int
	path         [portable_svg_stroke_path_values]f32
	dashes       [portable_svg_stroke_dash_values]f64
}

struct PortableSVGStrokeRasters {
mut:
	// Metadata follows the app's existing streaming image slots. The image
	// owns the pixels, and these bounded copies outlive document paint storage.
	entries [portable_svg_stroke_slots]PortableSVGStrokeRaster
}

fn portable_svg_stroke_raster_key(data &layout.PaintSVGPathData, color u32, width f32,
	miter f32) PortableSVGStrokeRasterKey {
	return PortableSVGStrokeRasterKey{
		color:       color
		width_bits:  math.f32_bits(width)
		miter_bits:  math.f32_bits(miter)
		cap:         data.stroke_linecap
		join:        data.stroke_linejoin
		non_scaling: data.non_scaling_stroke
		dash_len:    data.stroke_dasharray.len
		offset_bits: math.f64_bits(data.stroke_dashoffset)
	}
}

fn (entry &PortableSVGStrokeRaster) matches_path(values []f32) bool {
	return entry.path_len == values.len && unsafe {
		vmemcmp(&entry.path[0], values.data, values.len * int(sizeof(f32))) == 0
	}
}

fn (entry &PortableSVGStrokeRaster) matches_stroke(key PortableSVGStrokeRasterKey,
	matrix [6]f32, dashes []f64) bool {
	return key == entry.key && unsafe {
		vmemcmp(&entry.matrix[0], &matrix[0], 6 * int(sizeof(f32))) == 0
	} && (dashes.len == 0 || unsafe {
		vmemcmp(&entry.dashes[0], dashes.data, dashes.len * int(sizeof(f64))) == 0
	})
}

fn (mut app BrowserApp) remember_portable_svg_stroke(index int, data &layout.PaintSVGPathData,
	key PortableSVGStrokeRasterKey, matrix [6]f32, local cpuraster.Rect) {
	if app.portable_svg_stroke_rasters == unsafe { nil } {
		persistent := platform.enter_persistent()
		app.portable_svg_stroke_rasters = &PortableSVGStrokeRasters{}
		platform.leave_persistent(persistent)
	}
	mut entry := &app.portable_svg_stroke_rasters.entries[index]
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
}
