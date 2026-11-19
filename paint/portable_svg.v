module main

import cpuraster
import gg
import layout
import math
import painting

fn (mut app BrowserApp) draw_portable_svg_path(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32, scroll_y f64) {
	has_stroke := command.stroke_width > 0
	if has_stroke && data.stroke_first {
		app.draw_portable_svg_path_stroke(command, data, page_x, page_y, scroll_y)
	}
	mut filled := false
	$if vox_gg_svg ? {
		if data.svg_gradient_data != none {
			filled = app.draw_portable_gpu_svg_gradient_fill(command, data, page_x, page_y)
		}
	}
	$if linux || windows {
		if !filled { filled = app.draw_portable_svg_fill(command, data, page_x, page_y) }
	}
	if !filled && command.color != '' {
		polygons := if data.path_polygons.len > 0 { data.path_polygons } else { [command.points] }
		fill := app.paint_colors.color_with_retained(command.color, command.opacity * data.fill_opacity,
			command.retained_svg_fill_color())
		for polygon in polygons {
			if polygon.len < 6 { continue }
			mut points := []f32{cap: polygon.len}
			for index := 0; index + 1 < polygon.len; index += 2 {
				x, y := paint_screen_point(*command, polygon[index], polygon[index + 1], page_x, page_y, scroll_y)
				points << x
				points << y
			}
			draw_browser_polygon(app.ctx, points, fill)
		}
	}
	if has_stroke && !data.stroke_first {
		app.draw_portable_svg_path_stroke(command, data, page_x, page_y, scroll_y)
	}
}

fn (mut app BrowserApp) draw_portable_svg_fill(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
	if data.svg_gradient_data != none && app.draw_portable_svg_raster_gradient_fill(command, data, page_x, page_y) {
		return true
	}
	if command.color == '' || data.path_data.len < layout.compatibility_clip_path_segment_stride
		|| command.fill_linear_gradient() != none || command.fill_radial_gradient() != none
		|| data.fill_pattern != none {
		return false
	}
	return app.draw_portable_svg_raster_fill(command, data, page_x, page_y, none, 1)
}

fn (mut app BrowserApp) draw_portable_svg_raster_fill(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32, gradient ?cpuraster.CanvasGradient,
	opacity f32) bool {
	mut try_gpu := false
	mut cached_bounds := cpuraster.Rect{}
	mut geometry_slot := -1
	$if vox_gg_svg ? {
		try_gpu = gradient == none && may_try_portable_svg_gpu() && app.paint_effect_depth == 0
			&& app.paint_svg_mask_depth == 0
		if try_gpu {
			cached_bounds, geometry_slot = portable_gpu_svg_local_bounds(data.path_data)
		}
	}
	mut cache_index := if try_gpu { -1 } else { app.portable_svg_raster_cache_index(data.path_data.len, 0, gradient) }
	mut entry := app.cached_portable_svg_raster(cache_index, data.path_data)
	mut decoded := ?cpuraster.Path(none)
	local := if geometry_slot >= 0 {
		cached_bounds
	} else if entry != unsafe { nil } {
		entry.local_bounds
	} else {
		path := cpuraster.canvas_path(data.path_data, data.fill_even_odd)
		decoded = path
		path.bounds() or { return false }
	}
	scale := f64(app.ctx.scale)
	transform := portable_device_transform(multiply_paint_transforms(command.transform,
		data.path_transform), page_x, page_y, scale)
	ink := portable_svg_device_bounds(local, transform, app.portable_device_viewport(page_y))
	bounds := portable_pixel_bounds(ink)
	if bounds.is_empty() { return true }
	matrix := portable_svg_surface_matrix(transform, bounds)
	mut argb := u32(0xff000000)
	if gradient == none {
		color := app.paint_colors.color_with_retained(command.color, command.opacity * data.fill_opacity,
			command.retained_svg_fill_color())
		if color.a == 0 { return true }
		$if vox_gg_svg ? {
			if try_gpu && draw_portable_gpu_svg_path(app.ctx.r, data, matrix, bounds, color, local,
				geometry_slot, PortableSVGStroke{}, unsafe { nil }) {
				return true
			}
		}
		argb = portable_svg_argb(color)
	}
	if try_gpu {
		cache_index = app.portable_svg_raster_cache_index(data.path_data.len, 0, gradient)
		entry = app.cached_portable_svg_raster(cache_index, data.path_data)
	}
	key := PortableSVGRasterKey{
		color: argb
		opacity_bits: math.f32_bits(opacity)
		even_odd: data.fill_even_odd
	}
	if app.draw_cached_portable_svg_raster(entry, key, matrix, bounds, data.stroke_dasharray,
		gradient, 'FILL', decoded == none) {
		return true
	}
	path := decoded or { cpuraster.canvas_path(data.path_data, data.fill_even_odd) }
	mut style := ?cpuraster.CanvasPaintStyle(none)
	if paint := gradient { style = cpuraster.CanvasPaintStyle(paint) }
	pitch := bounds.width * 4
	mut premultiplied := []u8{len: pitch * bounds.height}
	if !cpuraster.fill_canvas_path(mut premultiplied, bounds.width, bounds.height, pitch, 2,
		path, matrix, argb, style, opacity,
		.src_over, 0, [], none) {
		return false
	}
	retain_clip := app.can_retain_portable_svg_clip_variant(entry, key, matrix, bounds, gradient)
	app.upload_portable_svg_pixels(bounds, mut premultiplied, retain_clip)
	if cache_index >= 0 {
		app.remember_portable_svg_raster(cache_index, &data, key, matrix, local, gradient)
	}
	log_portable_svg_raster_cache('FILL', 'miss', bounds, gradient, '', false)
	return true
}

fn (mut app BrowserApp) upload_portable_svg_pixels(bounds painting.IntRect, mut pixels []u8,
	retain_clip bool) {
	cpuraster.unpremultiply_rgba_in_place(mut pixels)
	app.upload_portable_raster_texture(app.portable_svg_texture_destination(bounds), bounds.width,
		bounds.height, pixels, 255, retain_clip)
}

fn (app &BrowserApp) portable_svg_texture_destination(bounds painting.IntRect) gg.Rect {
	scale := f64(app.ctx.scale)
	return gg.Rect{f32(f64(bounds.x) / scale), f32(f64(bounds.y) / scale),
		f32(bounds.width) / app.ctx.scale, f32(bounds.height) / app.ctx.scale}
}

fn portable_svg_device_bounds(rect cpuraster.Rect, transform painting.Affine, viewport painting.Rect) painting.Rect {
	local := painting.Rect{f64(rect.left), f64(rect.top), f64(rect.right - rect.left), f64(rect.bottom - rect.top)}
	return transform.map_rect(local).intersection(viewport)
}

fn portable_svg_surface_matrix(transform painting.Affine, bounds painting.IntRect) [6]f32 {
	return [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
		f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))]!
}

fn portable_svg_argb(color gg.Color) u32 {
	return (u32(color.a) << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b)
}
