module layout

import dom
import html

// Parsing and the live select model build different UA trees. Creating the
// persistent tree must preserve the selected label's position and theme.
fn test_chromium_select_shadow_creation_preserves_label_geometry() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}select{font:10pt Arial;position:absolute}
		#small{left:20px;top:20px}#tall{left:160px;top:60px;width:100px;height:40px}
		#rtl{left:20px;top:120px;direction:rtl}
		#plain{left:160px;top:160px;appearance:none;width:100px;height:40px}
	</style><select id="small"><option>Small</option><option>Large</option></select>
	<select id="tall"><option>Last reply</option><option>Creation date</option></select>
	<select id="rtl"><option>On</option><option>Off</option></select>
	<select id="plain"><option>Plain label</option></select>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	initial_list := document.record_display_list() or { panic('missing initial paint') }
	initial_lease := retain_display_list_scene(initial_list)
	defer { release_display_list_scene(initial_lease) }
	initial_commands := display_list_commands(initial_list)
	mut positions := map[string][]f64{}
	mut clips := map[string][]f64{}
	for label in ['Small', 'Last reply', 'On', 'Plain label'] {
		commands := initial_commands.filter(it.kind == 'draw_text' && it.text == label)
		assert commands.len == 1, label
		positions[label] = [commands[0].x, commands[0].y]
		assert commands[0].has_clip, label
		clips[label] = [commands[0].clip_x, commands[0].clip_y, commands[0].clip_width,
			commands[0].clip_height]
	}
	mut rectangles := map[string][]f64{}
	for id in ['small', 'tall', 'rtl', 'plain'] {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		rectangles[id] = [rect.x, rect.y, rect.width, rect.height]
		mut model := html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
		model.create_shadow_tree_if_needed()
	}
	_ = layout_document_typed_in_viewport(document, 800, 600)
	updated_list := document.record_display_list() or { panic('missing updated paint') }
	updated_commands := display_list_commands(updated_list)
	for label, expected in positions {
		commands := updated_commands.filter(it.kind == 'draw_text' && it.text == label)
		assert commands.len == 1, label
		assert commands[0].x == expected[0], '${label}: x ${commands[0].x}, expected ${expected[0]}'
		assert commands[0].y == expected[1], '${label}: y ${commands[0].y}, expected ${expected[1]}'
		assert commands[0].has_clip, label
		assert commands[0].clip_x == clips[label][0], label
		assert commands[0].clip_y == clips[label][1], label
		assert commands[0].clip_width == clips[label][2], label
		assert commands[0].clip_height == clips[label][3], label
	}
	for id, expected in rectangles {
		element := document.get_element_by_id(id) or { panic(id) }
		rect := element.get_bounding_client_rect()
		assert rect.x == expected[0], id
		assert rect.y == expected[1], id
		assert rect.width == expected[2], id
		assert rect.height == expected[3], id
	}
	assert initial_commands.filter(it.kind == 'draw_svg_path').len == 3
	assert updated_commands.filter(it.kind == 'draw_svg_path').len == 3
}
