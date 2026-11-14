module main

import ggshape
import layout

fn C.native_draw_document_shape(&C.VoxGraphiteShape, &f32, f32, f32, f32, f32, f32) i32

fn document_shadow_rect(x f64, y f64, width f64, height f64, radii layout.BoxRadii) [12]f32 {
	return [f32(x), f32(y), f32(width), f32(height), f32(radii.top_left.x), f32(radii.top_left.y),
		f32(radii.top_right.x), f32(radii.top_right.y), f32(radii.bottom_right.x),
		f32(radii.bottom_right.y), f32(radii.bottom_left.x), f32(radii.bottom_left.y)]!
}

fn (mut app BrowserApp) draw_chromium_outer_shadow(command layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	if command.kind != 'paint_outer_box_shadow' { return false }
	box := command.box_shadow()
	fill := app.paint_colors.color(command.color, command.opacity)
	color := chromium_retained_paint_color(command) or {
		[f32(fill.r) / 255, f32(fill.g) / 255, f32(fill.b) / 255, f32(fill.a) / 255]!
	}
	shape := C.VoxGraphiteShape{
		rect:            document_shadow_rect(command.x, command.y, command.width, command.height, command.corner_radii)
		underlay_rect:   document_shadow_rect(box.content_rect.x, box.content_rect.y,
			box.content_rect.width, box.content_rect.height, box.content_radii)
		fill:            if command.blur > 0 { 10 } else { 9 }
		thickness:       f32(command.blur)
		anti_alias:      1
		has_float_color: 1
		float_color:     color
	}
	m := if command.transform == [6]f64{} { [f64(1), 0, 0, 1, 0, 0]! } else { command.transform }
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), page_x + f32(m[4]),
		page_y - f32(scroll_y) + f32(m[5])]!
	return C.native_draw_document_shape(&shape, &matrix[0], f32(app.ctx.width),
		f32(app.ctx.height), page_x, page_y, f32(scroll_y)) != 0
}
