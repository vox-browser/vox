module layout

import html
import css
import math

// Brave 156 draws a rotate(90deg) octicon at x=247.15625 exactly as at
// x=247: the rotated path's top edge stays on the pixel boundary at y=32.
fn test_chromium_rotated_svg_discards_subpixel_offset() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		svg{position:absolute;top:26px;left:247.15625px;transform:rotate(90deg)}</style>
		<svg viewBox="0 0 16 16" width="16" height="16"><path d="M6 4L10 8L6 12Z"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	t := paths[0].transform
	svg_data := paths[0].svg()
	p := svg_data.path_transform
	// Map the path's flat edge start (6, 4) through the path and visual
	// transforms; Blink rotates (253, 30) about (255, 34) to (259, 32).
	px := p[0] * 6 + p[2] * 4 + p[4]
	py := p[1] * 6 + p[3] * 4 + p[5]
	x := t[0] * px + t[2] * py + t[4]
	y := t[1] * px + t[3] * py + t[5]
	assert math.abs(x - 259) < 1e-6, '${x},${y}'
	assert math.abs(y - 32) < 1e-6, '${x},${y}'
}

fn test_chromium_scaled_transform_keeps_subpixel_offset_on_unscaled_axes() {
	mut scale_x := css.FloatMatrix4x4.identity()
	scale_x.m11 = 2
	dx, dy := chromium_discarded_transform_subpixel_offset(scale_x, 10.25, 3.75, 1)
	assert dx == -0.25 && dy == 0
	tx, ty := chromium_discarded_transform_subpixel_offset(css.FloatMatrix4x4.identity(), 10.25, 3.75, 1)
	assert tx == 0 && ty == 0
}
