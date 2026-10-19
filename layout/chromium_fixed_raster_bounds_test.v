module layout

import html

fn test_fixed_raster_includes_unpainted_container_space() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#fixed{position:fixed;left:10px;bottom:10px;width:64px;height:128px;display:flex;align-items:flex-end}#paint{width:50px;height:67.34375px;background:rgb(1 2 3)}</style><div id="fixed"><div id="paint"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut found := false
	for index, command in commands {
		if command.color != 'rgb(1 2 3)' { continue }
		assert command.fixed_to_viewport
		layer := plan.layers[plan.command_layers[index]]
		assert layer.bounds == LayoutRect{ x: 10, y: 662, width: 64, height: 128 }
		found = true
	}
	assert found
}
