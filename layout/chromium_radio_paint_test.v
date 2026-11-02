module layout

import html

fn test_radio_intrinsic_size_follows_document_policy_and_capture_scale() {
	for chromium in [false, true] {
		for scale in [1.0, 2.0] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><input id="radio" type="radio"><input id="authored" type="radio" style="width:21px;height:17px">')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			document.set_layout_coordinate_scale(scale)
			root := layout_document_typed_in_viewport(document, 320, 200)
			element := document.get_element_by_id('radio') or { panic('radio') }
			box := root.find_box(i64(element.as_node().unique_id())) or { panic('box') }
			expected := if chromium { 13.0 } else { 12.0 }
			assert box.width == expected * scale
			assert box.height == expected * scale
			authored := document.get_element_by_id('authored') or { panic('authored') }
			authored_box := root.find_box(i64(authored.as_node().unique_id())) or { panic('authored box') }
			assert authored_box.width == 21 * scale
			assert authored_box.height == 17 * scale
		}
	}
}

fn test_unchecked_light_radio_keeps_the_chromium_ring_and_white_background() {
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}input{margin:0;position:absolute;left:20px;top:30px}</style><input type="radio">')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		root := layout_document_typed_in_viewport(document, 320, 200)
		commands := root.paint_commands()
		backgrounds := commands.filter(it.kind == 'fill_rect' && it.checkbox_theme_data != unsafe { nil })
		borders := commands.filter(it.kind == 'stroke_rounded_rect' && it.color == 'rgb(118 118 118)')
		assert backgrounds.len == 1
		assert borders.len == 1
		assert backgrounds[0].color == 'rgb(255 255 255)'
		assert backgrounds[0].underlays_next
		assert backgrounds[0].radius == 6.5 * scale
		assert borders[0].radius == 6.5 * scale
		mut replay := borders[0]
		replay.resolve_chromium_checkbox_geometry()
		assert replay.checkbox_theme_data == unsafe { nil }
		assert replay.radius == 6.5
		assert replay.stroke_width == 1
		assert replay.width == 12
	}
}

fn test_other_radio_states_keep_the_existing_theme_path() {
	for attributes in ['checked', 'disabled', 'style="color-scheme:dark"',
		'style="appearance:none;width:20px;height:20px"'] {
		mut document := html.parse_document('<!doctype html><input type="radio" ${attributes}>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 320, 200)
		assert !root.paint_commands().any(it.checkbox_theme_data != unsafe { nil })
	}
}

fn test_nonsquare_radio_keeps_the_half_pixel_center_after_native_replay() {
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>input{position:absolute;left:40px;top:30px;margin:0;width:40px;height:13px}</style><input type="radio">')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		root := layout_document_typed_in_viewport(document, 320, 200)
		borders := root.paint_commands().filter(it.kind == 'stroke_rounded_rect' && it.checkbox_theme_data != unsafe { nil })
		assert borders.len == 1
		assert borders[0].x == 53.5 * scale + 0.5 * scale
		assert borders[0].width == 12 * scale
		mut replay := borders[0]
		replay.resolve_chromium_checkbox_geometry()
		// The transport already maps device geometry back to CSS pixels.
		assert replay.x * replay.transform[0] + replay.transform[4] == 54
		assert replay.radius == 6.5
	}
}
