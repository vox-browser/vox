module main

import layout
import math

// Blink draws a square caster with a rounded hole, offset inside the padding
// clip. The finite caster must contain both the clip and the shifted hole.
fn unblurred_inner_shadow_shape(command layout.PaintCommand) ?C.VoxGraphiteShape {
	if command.kind != 'paint_inner_box_shadow' || command.blur != 0
		|| command.box_shadow_data == unsafe { nil } || command.has_clip
		|| command.clip_list != unsafe { nil } || command.recording_clip != none
		|| command.clip_outs.len != 0 {
		return none
	}
	b := command.box_shadow()
	c := b.content_rect
	h := b.inner_rect
	if c.width <= 0 || c.height <= 0 || h.width <= 0 || h.height <= 0
		|| b.content_radii != b.clip_radii
		|| c.width - h.width != c.height - h.height {
		return none
	}
	for v in [c.x, c.y, c.width, c.height, h.x, h.y, h.width, h.height] {
		if math.is_nan(v) || math.is_inf(v, 0) { return none }
	}
	dx := h.x + (h.width - c.width) / 2 - c.x
	dy := h.y + (h.height - c.height) / 2 - c.y
	outset := math.max(0, (h.width - c.width) / 2)
	x := c.x - outset + math.min(0, dx)
	y := c.y - outset + math.min(0, dy)
	return C.VoxGraphiteShape{
		rect:                  [f32(x), f32(y), f32(c.width + 2 * outset + math.abs(dx)),
			f32(c.height + 2 * outset + math.abs(dy)), 0, 0, 0, 0, 0, 0, 0, 0]!
		underlay_rect:         document_shadow_rect(h.x, h.y, h.width, h.height, b.inner_radii)
		contour_reference:     document_shadow_rect(c.x, c.y, c.width, c.height, b.content_radii)
		has_contour_reference: 1
		fill:                  14
		anti_alias:            1
	}
}

fn (mut app BrowserApp) draw_chromium_inner_shadow(command layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	mut shape := unblurred_inner_shadow_shape(command) or { return false }
	fill := app.paint_colors.color(command.color, command.opacity)
	precise := chromium_retained_paint_color(command)
	shape.red = fill.r
	shape.green = fill.g
	shape.blue = fill.b
	shape.alpha = fill.a
	shape.has_float_color = i32(precise != none)
	shape.float_color = precise or { [f32(0), 0, 0, 0]! }
	m := normalized_paint_transform(command.transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), page_x + f32(m[4]),
		page_y - f32(scroll_y) + f32(m[5])]!
	return C.native_draw_document_shape(&shape, &matrix[0], f32(app.ctx.width), f32(app.ctx.height), page_x, page_y, f32(scroll_y)) != 0
}
