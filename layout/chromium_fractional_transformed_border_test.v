module layout

import html
import math

fn fractional_transformed_border_commands(chromium bool, transform string) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:99.203125px;top:10.40625px;width:76.796875px;height:27.1875px;border:1px solid white;transform:${transform}}</style><div></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	return display_list_commands(document.record_display_list() or { panic('paint') })
		.filter(it.kind == 'paint_uniform_border')
}

fn test_fractional_skewed_border_snaps_dimensions_in_local_paint_coordinates() {
	commands := fractional_transformed_border_commands(true, 'skew(-20deg)')
	assert commands.len == 1
	command := commands[0]
	assert command.x == 0.5 && command.y == 0.5
	assert command.width == 78 && command.height == 28
	assert command.stroke_width == 1
	data := command.local_border_data
	assert data != unsafe { nil }
	assert data.origin_x == 99.203125 && data.origin_y == 10.40625
	// The skew changes x while the transformed box origin snaps on both axes.
	assert math.abs(command.transform[2] + math.tan(20 * math.pi / 180)) < 1e-12
	assert math.abs(command.transform[5] - 10) < 1e-12
}

fn test_fractional_border_translation_keeps_absolute_edge_snapping() {
	commands := fractional_transformed_border_commands(true, 'translate(.25px,.5px)')
	assert commands.len == 1
	command := commands[0]
	assert command.x == 99.5 && command.y == 10.5
	assert command.width == 78 && command.height == 29
	assert command.local_border_data == unsafe { nil }
}

fn test_libweb_fractional_transformed_border_keeps_its_existing_paint_paths() {
	assert fractional_transformed_border_commands(false, 'skew(-20deg)').len == 0
}
