module layout

import html

// Brave 156/macOS, Arial 10pt. The longest unselected option contributes too;
// Blink rounds that complete advance after projection into native coordinates.
fn test_chromium_select_intrinsics_include_every_option_at_native_scale() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}select{font:10pt Arial}</style>
		<select id="order"><option>Bump order</option><option>Last reply</option><option>Creation date</option><option>Reply count</option></select>
		<select id="size"><option>Small</option><option>Large</option></select>
		<select id="teaser"><option>Off</option><option selected>On</option></select>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0, 1.0] {
		document.set_layout_coordinate_scale(scale)
		run_document_layout(document, 1024, 768) or { panic('layout') }
		for id, width in {
			'order':  if scale == 2 { 98.5 } else { 99.0 }
			'size':   if scale == 2 { 52.5 } else { 53.0 }
			'teaser': 36.0
		} {
			element := document.get_element_by_id(id) or { panic(id) }
			rect := element.get_bounding_client_rect()
			assert rect.width == width, '${id} at ${scale}x: ${rect.width}'
			assert rect.height == 19, '${id} at ${scale}x: ${rect.height}'
		}
	}
}

fn test_chromium_select_theme_keeps_authored_geometry_and_paint() {
	mut document := html.parse_document('<!doctype html><style>
		select{font:10pt Arial}#styled{width:120px;height:30px;border:3px solid red;background:blue;color:yellow}
		#plain{appearance:none;width:80px;height:40px;border:0;padding:0;background:lime}
	</style><select id="styled"><option>Small</option><option>Creation date</option></select>
	<select id="plain"><option>Small</option></select>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 600)
	for id, dimensions in {
		'styled': [120.0, 30.0]
		'plain':  [80.0, 40.0]
	} {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		assert rect.width == dimensions[0], '${id}: ${rect.width}'
		assert rect.height == dimensions[1], '${id}: ${rect.height}'
	}
	commands := root.paint_commands()
	assert commands.any(it.color == 'rgb(255 0 0)')
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 0 255)')
	assert commands.any(it.kind == 'fill_rect' && it.color == 'rgb(0 255 0)')
	// Only the styled, native-appearance select contributes an open chevron.
	assert commands.filter(it.kind == 'draw_svg_path' && it.stroke_color == 'rgb(255 255 0)').len == 1
}

fn test_chromium_select_zero_font_has_only_native_padding_and_borders() {
	mut document := html.parse_document('<!doctype html><style>select{font-size:0}</style>
		<select id="control"><option>Small</option><option>Creation date</option></select>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for scale in [1.0, 2.0] {
		document.set_layout_coordinate_scale(scale)
		run_document_layout(document, 800, 600) or { panic('zero font layout') }
		control := document.get_element_by_id('control') or { panic('control') }
		assert control.get_bounding_client_rect().height == 4
	}
}
