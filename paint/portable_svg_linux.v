module main

import cpuraster
import layout
import painting

fn (mut app BrowserApp) draw_portable_solid_svg_fill(command &layout.PaintCommand,
	data layout.PaintSVGPathData, page_x f32, page_y f32) bool {
	if command.color == '' || data.path_data.len < layout.compatibility_clip_path_segment_stride
		|| command.fill_linear_gradient() != none || command.fill_radial_gradient() != none
		|| data.fill_pattern != none {
		return false
	}
	// Tessellating each contour independently fills holes and breaks concave
	// paths. Rasterize the retained path as a unit with its SVG fill rule.
	path := cpuraster.canvas_path(data.path_data, data.fill_even_odd)
	rect := path.bounds() or { return false }
	local := painting.Rect{f64(rect.left), f64(rect.top), f64(rect.right - rect.left), f64(rect.bottom - rect.top)}
	scale := f64(app.ctx.scale)
	transform := portable_device_transform(multiply_paint_transforms(command.transform,
		data.path_transform), page_x, page_y, scale)
	bounds := portable_pixel_bounds(transform.map_rect(local).intersection(app.portable_device_viewport(page_y)))
	if bounds.is_empty() { return true }
	color := app.paint_colors.color_with_retained(command.color, command.opacity * data.fill_opacity,
		command.retained_svg_fill_color())
	if color.a == 0 { return true }
	argb := (u32(color.a) << 24) | (u32(color.r) << 16) | (u32(color.g) << 8) | u32(color.b)
	matrix := [f32(transform.a), f32(transform.b), f32(transform.c), f32(transform.d),
		f32(transform.e - f64(bounds.x)), f32(transform.f - f64(bounds.y))]!
	pitch := bounds.width * 4
	mut premultiplied := []u8{len: pitch * bounds.height}
	if !cpuraster.fill_canvas_path(mut premultiplied, bounds.width, bounds.height, pitch, 2,
		path, matrix, argb, none, 1, .src_over, 0, [], none) {
		return false
	}
	mut pixels := []u8{len: premultiplied.len}
	cpuraster.read_pixels(premultiplied, bounds.width, bounds.height, pitch, 2, mut pixels,
		bounds.width, bounds.height, pitch, 0, 0)
	app.draw_portable_raster_image(f32(f64(bounds.x) / scale), f32(f64(bounds.y) / scale),
		bounds.width, bounds.height, pixels)
	return true
}
