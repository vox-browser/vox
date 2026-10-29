module layout

import html

fn test_static_css_filters_do_not_promote_overlapping_ordinary_content() {
	for filter in ['blur(30px)', 'contrast(.7)', 'drop-shadow(1px 2px 4px red)'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0;background:#090b0f}#filtered{position:absolute;left:20px;top:30px;width:150px;height:90px;filter:${filter};background:red}#scene{position:absolute;left:60px;top:80px;width:180px;height:100px;background:linear-gradient(red,blue)}</style><div id="filtered"></div><div id="scene"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 240)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		plan := chromium_raster_layer_plan(document, commands, 1)
		assert commands.any(it.kind == 'begin_css_filter_layer')
		assert commands.any(it.kind == 'end_css_filter_layer')
		assert plan.layers.len == 1
		assert plan.command_layers.all(it == 0)
		assert !plan.layers[0].legacy_raster
	}
}

fn test_static_css_filters_keep_the_enclosing_compositor_surface() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}section{position:absolute;left:20px;top:30px;width:150px;height:90px;will-change:transform}#filtered{filter:blur(3px);background:red;width:80px;height:60px}#sibling{width:40px;height:20px;background:blue}</style><section><div id="filtered"></div><div id="sibling"></div></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	commands := display_list_commands(document.record_display_list() or { panic('missing surface paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut filter_layer := -1
	mut sibling_layer := -1
	mut depth := 0
	for index, command in commands {
		if command.kind == 'begin_css_filter_layer' {
			filter_layer = plan.command_layers[index]
			depth++
		}
		if depth > 0 {
			assert plan.command_layers[index] == filter_layer
		}
		if command.kind == 'end_css_filter_layer' {
			depth--
		}
		if command.color == 'rgb(0 0 255)' {
			sibling_layer = plan.command_layers[index]
		}
	}
	assert depth == 0
	assert filter_layer > 0
	assert filter_layer == sibling_layer
	assert !plan.layers[filter_layer].legacy_raster
}
