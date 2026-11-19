module main

import cpuraster
import gg
import layout
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
	$if linux {
		if !filled { filled = app.draw_portable_svg_fill(command, data, page_x, page_y) }
	}
	$if windows && vox_gg_svg ? {
		if !filled && portable_svg_gpu_enabled { filled = app.draw_portable_svg_fill(command, data, page_x, page_y) }
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
	mut cached_bounds := cpuraster.Rect{}
	mut geometry_slot := -1
	$if vox_gg_svg ? {
		if portable_svg_gpu_enabled && app.paint_effect_depth == 0 && app.paint_svg_mask_depth == 0 {
			cached_bounds, geometry_slot = portable_gpu_svg_local_bounds(data.path_data)
		}
	}
	mut decoded := ?cpuraster.Path(none)
	local := if geometry_slot >= 0 {
		cached_bounds
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
	color := app.paint_colors.color_with_retained(command.color, command.opacity * data.fill_opacity,
		command.retained_svg_fill_color())
	if color.a == 0 { return true }
	matrix := portable_svg_surface_matrix(transform, bounds)
	$if vox_gg_svg ? {
		if portable_svg_gpu_enabled && app.paint_effect_depth == 0 && app.paint_svg_mask_depth == 0
			&& draw_portable_gpu_svg_path(app.ctx.r, data, matrix, bounds, color, local,
				geometry_slot, PortableSVGStroke{}, unsafe { nil }) {
			return true
		}
	}
	// Rasterize the whole path with its fill rule, including concave contours
	// and holes. A GPU fallback only decodes the path if it reused the bounds.
	path := decoded or { cpuraster.canvas_path(data.path_data, data.fill_even_odd) }
	return app.draw_portable_svg_cpu_fill(path, bounds, matrix, portable_svg_argb(color), none, 1)
}

fn (mut app BrowserApp) draw_portable_svg_cpu_fill(path cpuraster.Path, bounds painting.IntRect,
	matrix [6]f32, color u32, style ?cpuraster.CanvasPaintStyle, opacity f32) bool {
	pitch := bounds.width * 4
	mut premultiplied := []u8{len: pitch * bounds.height}
	if !cpuraster.fill_canvas_path(mut premultiplied, bounds.width, bounds.height, pitch, 2,
		path, matrix, color, style, opacity,
		.src_over, 0, [], none) {
		return false
	}
	app.upload_portable_svg_pixels(bounds, premultiplied)
	return true
}

fn (mut app BrowserApp) upload_portable_svg_pixels(bounds painting.IntRect, premultiplied []u8) {
	pitch := bounds.width * 4
	mut pixels := []u8{len: premultiplied.len}
	cpuraster.read_pixels(premultiplied, bounds.width, bounds.height, pitch, 2, mut pixels,
		bounds.width, bounds.height, pitch, 0, 0)
	scale := f64(app.ctx.scale)
	app.draw_portable_raster_image(f32(f64(bounds.x) / scale), f32(f64(bounds.y) / scale),
		bounds.width, bounds.height, pixels)
}

fn portable_svg_path_bounds(path cpuraster.Path, transform painting.Affine, viewport painting.Rect) ?painting.Rect {
	rect := path.bounds() or { return none }
	return portable_svg_device_bounds(rect, transform, viewport)
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
