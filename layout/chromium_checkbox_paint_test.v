module layout

import painting
import html

// 4chan's post headers: Blink snaps each themed control edge to the nearest
// pixel, then fills a white 2px-radius background and strokes a #767676 border.
fn test_chromium_unchecked_checkbox_uses_blink_theme_geometry() {
	assert chromium_snapped_control_rect(62.49, 36.5, 13, 13) == painting.IntRect{62, 37, 13, 13}
	assert chromium_snapped_control_rect(62.5, 36.25, 13, 13) == painting.IntRect{63, 36, 13, 13}
	assert chromium_snapped_control_rect(41, 210.5, 26, 26) == painting.IntRect{41, 211, 26, 26}
	// A non-square control paints the largest centered square.
	assert chromium_snapped_control_rect(10, 10, 20, 13) == painting.IntRect{13, 10, 13, 13}
	mut commands := []PaintCommand{}
	append_chromium_unchecked_checkbox(mut commands, painting.IntRect{299, 625, 13, 13}, 1, 1)
	assert commands.len == 2
	assert commands[0].kind == 'fill_rect' && commands[0].radius == 2
	assert commands[0].color == 'rgb(255 255 255)'
	assert [commands[0].x, commands[0].y, commands[0].width, commands[0].height] == [299.2, 625.2,
		12.6, 12.6]
	// The border draws the background first in its own GPU pass.
	assert commands[0].underlays_next && !commands[1].underlays_next
	assert commands[1].kind == 'stroke_rounded_rect' && commands[1].radius == 2
	assert commands[1].stroke_width == 1 && commands[1].color == 'rgb(118 118 118)'
	assert [commands[1].x, commands[1].y, commands[1].width, commands[1].height] == [299.5, 625.5,
		12.0, 12.0]
	mut projected := []PaintCommand{}
	append_chromium_unchecked_checkbox(mut projected, painting.IntRect{598, 1250, 26, 26}, 2, 1)
	assert projected[0].radius == 4
	assert projected[1].stroke_width == 2 && projected[1].radius == 4
	assert [projected[1].x, projected[1].y, projected[1].width, projected[1].height] == [599.0,
		1251.0, 24.0, 24.0]
}

fn test_chromium_checked_checkbox_projects_theme_radius_and_check_path() {
	for scale in [1.0, 2.0] {
		mut commands := []PaintCommand{}
		append_chromium_checked_checkbox(mut commands,
			painting.IntRect{20 * int(scale), 30 * int(scale), 13 * int(scale), 13 * int(scale)},
			scale, 0.5)
		assert commands.len == 3
		assert commands[0].underlays_next
		assert commands[0].color == 'rgb(255 255 255)'
		assert commands[1].color == 'rgb(0 117 255)'
		assert commands[1].radius == 2 * scale && commands[1].opacity == 0.5
		assert commands[2].kind == 'draw_svg_path'
		assert commands[2].stroke_color == 'rgb(255 255 255)'
		assert commands[2].svg().path_data.len > 0
		assert commands[2].stroke_width == f64(f32(13) * f32(0.16) * f32(scale))
	}
}

fn test_chromium_checked_theme_preserves_author_accent_colors() {
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0 } #custom { accent-color:rgb(255,0,0) }
		</style><input id="automatic" type="checkbox" checked>
		<input id="custom" type="checkbox" checked>')
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		root := layout_document_typed_in_viewport(document, 320, 200)
		automatic := document.get_element_by_id('automatic') or { panic('automatic checkbox') }
		custom := document.get_element_by_id('custom') or { panic('custom checkbox') }
		automatic_box := root.find_box(i64(automatic.as_node().unique_id())) or { panic('automatic box') }
		custom_box := root.find_box(i64(custom.as_node().unique_id())) or { panic('custom box') }
		assert automatic_box.form_control_accent_is_auto
		assert !custom_box.form_control_accent_is_auto
		commands := root.paint_commands()
		assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 117 255)')
		assert commands.any(it.kind == 'fill_rounded_rect' && it.color == 'rgb(255 0 0)')
		document.finalize()
	}
}
