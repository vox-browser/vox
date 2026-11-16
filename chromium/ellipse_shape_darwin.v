module main

import layout
import math

// Predefined list discs are geometric ellipses. Raster them with the document
// shapes so their coverage follows the owning tile rather than CoreGraphics.
fn chromium_filled_ellipse_shape(command layout.PaintCommand) ?C.VoxGraphiteShape {
	if command.kind != 'fill_ellipse' || command.width <= 0 || command.height <= 0 {
		return none
	}
	for value in [command.x, command.y, command.width, command.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	rx, ry := f32(command.width / 2), f32(command.height / 2)
	return C.VoxGraphiteShape{
		rect: [f32(command.x), f32(command.y), f32(command.width), f32(command.height),
			rx, ry, rx, ry, rx, ry, rx, ry]!
		fill: 1
		anti_alias: 1
	}
}

fn (mut app BrowserApp) draw_chromium_filled_ellipse(command layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	mut shape := chromium_filled_ellipse_shape(command) or { return false }
	color := app.paint_colors.color(command.color, command.opacity)
	shape.red = color.r
	shape.green = color.g
	shape.blue = color.b
	shape.alpha = color.a
	m := normalized_paint_transform(command.transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), page_x + f32(m[4]),
		page_y - f32(scroll_y) + f32(m[5])]!
	return C.native_draw_document_shape(&shape, &matrix[0], f32(app.ctx.width),
		f32(app.ctx.height), page_x, page_y, f32(scroll_y)) != 0
}
