module layout

import painting

// 4chan's post headers: Blink snaps each themed control edge to the nearest
// pixel, then fills a white 2px-radius background and strokes a #767676 border.
fn test_chromium_unchecked_checkbox_uses_blink_theme_geometry() {
	assert chromium_snapped_control_rect(62.49, 36.5, 13, 13) == painting.IntRect{62, 37, 13, 13}
	assert chromium_snapped_control_rect(62.5, 36.25, 13, 13) == painting.IntRect{63, 36, 13, 13}
	// A non-square control paints the largest centered square.
	assert chromium_snapped_control_rect(10, 10, 20, 13) == painting.IntRect{13, 10, 13, 13}
	mut commands := []PaintCommand{}
	append_chromium_unchecked_checkbox(mut commands, painting.IntRect{299, 625, 13, 13}, 1)
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
}
