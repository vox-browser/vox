module layout

import html

fn test_computed_corner_shapes_reach_solid_decorations_without_local_translation() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		div{position:absolute;left:40px;top:50px;width:300px;height:52px;
		border:1px solid #0002;border-radius:28px;background:white;
		corner-shape:superellipse(1.1);box-shadow:0 4px 80px 8px #0001}
	</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands()
	mut count := 0
	for command in commands {
		if command.kind !in ['fill_rect', 'paint_outer_box_shadow', 'paint_uniform_border']
			|| command.local_border_data == unsafe { nil } {
			continue
		}
		data := command.local_border_data
		assert data.corner_shapes == [f64(1.1), 1.1, 1.1, 1.1]!
		assert !data.has_local_geometry
		assert data.shape_border_rect.x == 40 && data.shape_border_rect.y == 50
		assert command.transform == [f64(0), 0, 0, 0, 0, 0]!
		count++
	}
	assert count == 3
}

fn test_corner_shape_parameters_follow_physical_and_logical_cascade() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		div{width:100px;height:40px;border-radius:10px;background:red;
		corner-shape:round bevel squircle superellipse(1.25);corner-start-start-shape:superellipse(.98)}
	</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	commands := layout_document_typed_in_viewport(document, 800, 600).paint_commands()
	data := commands.filter(it.local_border_data != unsafe { nil })[0].local_border_data
	assert data.corner_shapes == [f64(.98), 0, 2, 1.25]!
}
