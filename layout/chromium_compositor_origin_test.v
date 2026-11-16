module layout

import html

fn test_fractional_filtered_picture_keeps_origin_before_capture_enclosure() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}button{position:absolute;left:40.75px;top:30.25px;box-sizing:border-box;width:42px;height:36px;padding:0;border:1px solid black;backdrop-filter:blur(20px)}</style><button><svg width="16" height="16"><path d="M2 2L14 2L8 14Z"/></svg></button>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 120)
	commands := display_list_commands(document.record_display_list() or { panic('missing filtered paint') })
	mut plan := chromium_raster_layer_plan(document, commands, 1)
	mut owner := -1
	for index, command in commands {
		if command.kind == 'apply_backdrop_filter' { owner = plan.command_layers[index] }
	}
	assert owner > 0
	layer := plan.layers[owner]
	assert layer.composited_contents && !layer.legacy_raster
	origin := layer.compositor_origin or { panic('lost fractional compositor origin') }
	assert origin == [f64(40.75), 30.25]!
	assert layer.bounds.x == 40 && layer.bounds.y == 30

	// A reused plan must not attach the old effect origin to the root picture.
	mut plain := html.parse_document('<!doctype html><style>body{margin:0}</style><div style="width:42px;height:36px;background:red"></div>')
	defer { plain.finalize() }
	plain.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(plain, 200, 120)
	plain_commands := display_list_commands(plain.record_display_list() or { panic('missing plain paint') })
	update_chromium_raster_layer_plan(plain, plain_commands, 1, mut plan)
	assert plan.layers.len == 1
	assert plan.layers[0].compositor_origin == none
}
