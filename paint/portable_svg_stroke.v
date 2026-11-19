module main

import cpuraster
import gg
import layout
import math
import painting

fn portable_svg_stroke_outset(data &layout.PaintSVGPathData, width f32, miter f32) f64 {
	cap := if data.stroke_linecap == 2 { math.sqrt2 } else { 1.0 }
	join := if data.stroke_linejoin == 0 { math.max(1.0, f64(miter)) } else { 1.0 }
	return f64(width) * 0.5 * math.max(cap, join)
}

fn portable_svg_stroke_bounds(data &layout.PaintSVGPathData, local cpuraster.Rect,
	transform painting.Affine, viewport painting.Rect, width f32, miter f32) painting.IntRect {
	pad := portable_svg_stroke_outset(data, width, miter)
	rect := painting.Rect{f64(local.left), f64(local.top),
		f64(local.right) - f64(local.left), f64(local.bottom) - f64(local.top)}
	outline := if data.non_scaling_stroke {
		transform.map_rect(rect).inflated(pad, pad, pad, pad)
	} else {
		transform.map_rect(rect.inflated(pad, pad, pad, pad))
	}
	return portable_pixel_bounds(outline.inflated(1, 1, 1, 1).intersection(viewport))
}

fn (app &BrowserApp) portable_non_scaling_stroke_fringe(command &layout.PaintCommand) f32 {
	if command.kind != 'draw_svg_path' || command.stroke_width <= 0 {
		return 0
	}
	data := command.svg_data
	if data == unsafe { nil } || !data.non_scaling_stroke
		|| (command.stroke_color == '' && data.svg_gradient_data == none) {
		return 0
	}
	mut eligible := false
	$if vox_gg_svg ? {
		eligible = portable_svg_gpu_enabled
	}
	$if linux {
		eligible = true
	}
	if !eligible { return 0 }
	// Layout bounds are in CSS pixels and the stroke is evaluated in device pixels.
	pad := portable_svg_stroke_outset(data, f32(command.stroke_width), f32(data.stroke_miterlimit))
	return f32((pad + 1) / f64(app.ctx.scale))
}

// Place a local gradient in the same surface space as the transformed
// centerline of a non-scaling stroke.
fn portable_svg_surface_gradient_transform(surface [6]f32, local [6]f32) [6]f32 {
	m := multiply_paint_transforms(
		[f64(surface[0]), f64(surface[1]), f64(surface[2]), f64(surface[3]),
			f64(surface[4]), f64(surface[5])]!,
		[f64(local[0]), f64(local[1]), f64(local[2]), f64(local[3]), f64(local[4]), f64(local[5])]!)
	return [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5])]!
}

fn (mut app BrowserApp) draw_portable_svg_raster_stroke(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
	if (command.stroke_color == '' && data.svg_gradient_data == none) || data.stroke_pattern != none
		|| data.path_data.len < layout.compatibility_clip_path_segment_stride {
		return false
	}
	width := f32(command.stroke_width)
	miter := f32(if data.stroke_miterlimit > 1 { data.stroke_miterlimit } else { 1.0 })
	if !(width > 0) || !math.is_finite(f64(width)) || !math.is_finite(f64(miter)) {
		return false
	}
	mut opacity := f32(clamp(command.opacity * data.stroke_opacity, 0.0, 1.0))
	if opacity == 0 { return true }
	mut color := u32(0xff000000)
	mut gradient := ?cpuraster.CanvasGradient(none)
	if command.stroke_color == '' {
		gradient = portable_svg_visible_gradient(command, true) or { return false }
	} else {
		stroke := app.paint_colors.color_with_retained(command.stroke_color,
			command.opacity * data.stroke_opacity, command.retained_svg_stroke_color())
		if stroke.a == 0 { return true }
		color = portable_svg_argb(stroke)
		opacity = 1
	}
	cache_index := app.portable_svg_raster_cache_index(data.path_data.len, data.stroke_dasharray.len, gradient)
	entry := app.cached_portable_svg_raster(cache_index, data.path_data)
	mut decoded := ?cpuraster.Path(none)
	local := if entry != unsafe { nil } {
		entry.local_bounds
	} else {
		path := cpuraster.canvas_path(data.path_data, false)
		decoded = path
		path.bounds() or { return false }
	}
	transform := portable_device_transform(multiply_paint_transforms(command.transform,
		data.path_transform), page_x, page_y, f64(app.ctx.scale))
	bounds := portable_svg_stroke_bounds(&data, local, transform, app.portable_device_viewport(page_y), width, miter)
	if bounds.is_empty() { return true }
	surface_matrix := portable_svg_surface_matrix(transform, bounds)
	if !surface_matrix.all(math.is_finite(f64(it))) { return false }
	key := if cache_index >= 0 {
		portable_svg_stroke_raster_key(&data, color, opacity, width, miter)
	} else {
		PortableSVGRasterKey{}
	}
	if app.draw_cached_portable_svg_raster(entry, key, surface_matrix, bounds, data.stroke_dasharray, gradient, 'STROKE') {
		return true
	}
	mut path := decoded or { cpuraster.canvas_path(data.path_data, false) }
	mut matrix := surface_matrix
	mut style := ?cpuraster.CanvasPaintStyle(none)
	if paint := gradient {
		if data.non_scaling_stroke {
			local_transform := paint.local_transform or { [f32(1), 0, 0, 1, 0, 0]! }
			style = cpuraster.CanvasPaintStyle(cpuraster.CanvasGradient{
				...paint
				local_transform: portable_svg_surface_gradient_transform(matrix, local_transform)
			})
		} else {
			style = cpuraster.CanvasPaintStyle(paint)
		}
	}
	if data.non_scaling_stroke {
		path = path.transform(cpuraster.Matrix{matrix[0], matrix[1], matrix[2], matrix[3], matrix[4], matrix[5]})
		matrix = [f32(1), 0, 0, 1, 0, 0]!
	}
	cap := match data.stroke_linecap {
		1 { cpuraster.StrokeCap.round }
		2 { .square }
		else { .butt }
	}
	join := match data.stroke_linejoin {
		1 { cpuraster.StrokeJoin.round }
		2 { .bevel }
		else { .miter }
	}
	pitch := bounds.width * 4
	mut pixels := []u8{len: pitch * bounds.height}
	if !cpuraster.stroke_canvas_path(mut pixels, bounds.width, bounds.height, pitch, 2, path,
		matrix, color, style, opacity, .src_over, 0, width,
		cap, join, miter, data.stroke_dasharray.map(f32(it)), f32(data.stroke_dashoffset), [], none) {
		return false
	}
	app.upload_portable_svg_pixels(bounds, pixels, false)
	if cache_index >= 0 {
		app.remember_portable_svg_raster(cache_index, &data, key, surface_matrix, local, gradient)
	}
	log_portable_svg_raster_cache('STROKE', 'miss', bounds, gradient, '')
	return true
}

fn (mut app BrowserApp) draw_portable_svg_path_stroke(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32, scroll_y f64) {
	$if vox_gg_svg ? {
		if app.draw_portable_gpu_svg_stroke(command, data, page_x, page_y) { return }
	}
	$if linux {
		if app.draw_portable_svg_raster_stroke(command, data, page_x, page_y) { return }
	}
	$if windows && vox_gg_svg ? {
		if portable_svg_gpu_enabled && app.draw_portable_svg_raster_stroke(command, data, page_x, page_y) { return }
	}
	if command.stroke_color == '' { return }
	points := if data.path_polygons.len > 0 { data.path_polygons[0] } else { command.points }
	if points.len < 4 { return }
	stroke := app.paint_colors.color_with_retained(command.stroke_color, command.opacity * data.stroke_opacity,
		command.retained_svg_stroke_color())
	mut x, mut y := paint_screen_point(*command, points[0], points[1], page_x, page_y, scroll_y)
	for index := 2; index + 1 < points.len; index += 2 {
		next_x, next_y := paint_screen_point(*command, points[index], points[index + 1], page_x, page_y, scroll_y)
		draw_browser_line(app.ctx, x, y, next_x, next_y, gg.PenConfig{
			color: stroke
			thickness: f32(command.stroke_width)
		})
		x, y = next_x, next_y
	}
}
