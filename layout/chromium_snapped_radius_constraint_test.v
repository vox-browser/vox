module layout

import html

// Brave 156: GitHub's topic pills are 25.5px tall with a 9999.01px radius. Blink
// constrains the radii against the pixel-snapped border box it paints, so
// the corners are 13px, not the 12.75px of the unsnapped layout height. At
// two device pixels per CSS pixel the box snaps to 25.5px and keeps 12.75px.
fn test_chromium_border_radii_are_constrained_by_the_snapped_border_box() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}a{position:absolute;left:10px;top:10px;width:54px;height:25.5px;
		border-radius:9999.01px;background:rgb(221,244,255)}
	</style><a></a>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for density in [f64(1), 2] {
		document.set_display_device_pixel_ratio(density)
		_ = layout_document_typed_in_viewport(document, 400, 300)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		fills := commands.filter(it.kind in ['fill_rect_with_rounded_corners', 'fill_rect'])
		assert fills.len == 1, commands.map(it.kind).str()
		expected := if density == 2 { 12.75 } else { 13.0 }
		assert fills[0].height == expected * 2
		assert fills[0].radius == expected, '${density}: ${fills[0].radius}'
	}
}

// Brave 156: GitHub's contributor avatars are squeezed to 26.109375x32 with
// 50% radii. They stay ovals of the 26x32 snapped box, and their box-shadow
// ring is the oval grown by its spread.
fn test_chromium_elliptical_radii_stay_an_oval_of_the_snapped_box() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}div{position:absolute;left:976px;top:241px;width:26.109375px;height:32px;
		border-radius:50%;box-shadow:0 0 0 1px rgba(31,35,40,.15);background:rgb(90,90,90)}
	</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	fills := commands.filter(it.kind == 'fill_rounded_rect')
	assert fills.len == 1, commands.map(it.kind).str()
	assert fills[0].width == 26 && fills[0].height == 32
	for corner in [fills[0].corner_radii.top_left, fills[0].corner_radii.bottom_right] {
		assert corner.x == 13 && corner.y == 16, '${corner}'
	}
	shadows := commands.filter(it.kind == 'paint_outer_box_shadow')
	assert shadows.len == 1
	assert shadows[0].corner_radii.top_left.x == 14 && shadows[0].corner_radii.top_left.y == 17,
		'${shadows[0].corner_radii.top_left}'
}
