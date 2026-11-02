module layout

import html
import math

fn plain_background_command(style string, chromium bool) PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{position:absolute;background:rgb(9 8 7);${style}}</style><div id="target"></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	for command in commands {
		if command.kind == 'fill_rect' && command.color == 'rgb(9 8 7)' { return command }
	}
	panic('missing background')
}

fn test_rotated_plain_background_snaps_in_the_box_paint_offset_space() {
	command := plain_background_command('left:73px;top:40.890625px;width:6px;height:6px;transform:rotate(45deg)', true)
	assert command.x == 0 && command.y == 0
	assert command.width == 6 && command.height == 6
	m := command.transform
	assert math.abs(m[0] * 3 + m[2] * 3 + m[4] - 76) < 1e-10
	assert math.abs(m[1] * 3 + m[3] * 3 + m[5] - 44) < 1e-10
}

fn test_fractional_plain_background_sizes_snap_locally_even_with_padding() {
	for padding in ['', 'box-sizing:border-box;padding:2.25px;border:1px solid transparent;'] {
		command := plain_background_command('left:400.5px;top:250.25px;width:41.5px;height:17.75px;transform-origin:0 0;transform:rotate(90deg);${padding}', true)
		assert command.x == 0 && command.y == 0
		assert command.width == 42 && command.height == 18
		assert math.abs(command.transform[4] - 401) < 1e-10
		assert math.abs(command.transform[5] - 250) < 1e-10
	}
}

fn test_libweb_plain_background_keeps_unsnapped_absolute_coordinates() {
	command := plain_background_command('left:73px;top:40.890625px;width:6px;height:6px;transform:rotate(45deg)', false)
	assert command.x == 73 && command.y == 40.890625
	assert command.width == 6 && command.height == 6
	assert command.local_border_data == unsafe { nil }
}

fn test_translation_only_plain_backgrounds_snap_before_the_css_translation() {
	for transform in ['translateY(-50%)', 'rotate(0deg) translateY(-50%)',
		'scale(1) translateY(-50%)', 'matrix(1,0,0,1,0,-15)'] {
		command := plain_background_command('left:737.921875px;top:102px;width:1px;height:30px;transform:${transform}', true)
		assert command.x == 738 && command.y == 102
		assert command.width == 1 && command.height == 30
		assert command.transform == [f64(1), 0, 0, 1, 0, -15]!
		assert command.local_border_data == unsafe { nil }
	}
	// Retain the author's fractional translation after snapping the layout box.
	command := plain_background_command('left:737.921875px;top:102px;width:1px;height:30px;transform:translate(.25px,-50%)', true)
	assert command.x == 738 && command.y == 102
	assert command.transform == [f64(1), 0, 0, 1, .25, -15]!
}

fn test_translation_only_background_dimensions_snap_both_absolute_edges() {
	command := plain_background_command('left:737.921875px;top:102.25px;width:41.5px;height:17.75px;transform:translateY(-50%)', true)
	assert command.x == 738 && command.y == 102
	assert command.width == 41 && command.height == 18
	assert command.local_border_data == unsafe { nil }
}

fn local_background_commands(chromium bool) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.circle{position:absolute;left:1212px;top:132px;width:22px;height:22px;border-radius:50%;background:#fafafa}#local{transform:translateX(0)}#global{top:180px}</style><div class="circle" id="local"></div><div class="circle" id="global"></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	return display_list_commands(document.record_display_list() or { panic('missing paint') }).filter((it.kind == 'fill_rect' && it.radius > 0) || it.kind == 'fill_rounded_rect')
}

fn test_identity_css_transform_retains_local_rounded_background_geometry() {
	commands := local_background_commands(true)
	assert commands.len == 2
	assert commands[0].x == 0 && commands[0].y == 0
	assert commands[0].width == 22 && commands[0].height == 22
	assert commands[0].transform == [f64(1), 0, 0, 1, 1212, 132]!
	assert commands[0].local_border_data != unsafe { nil }
	assert commands[1].x == 1212 && commands[1].y == 180
	assert commands[1].local_border_data == unsafe { nil }
}

fn test_libweb_rounded_background_coordinates_are_preserved() {
	commands := local_background_commands(false)
	assert commands.len == 2
	assert commands[0].x == 1212 && commands[0].y == 132
	assert commands[0].local_border_data == unsafe { nil }
}
