module layout

import html

fn hidden_scroll_metadata_markup(opacity string, inherited bool) string {
	outer := if inherited { 'opacity:${opacity}' } else { '' }
	inner := if inherited { '' } else { 'opacity:${opacity}' }
	return '<!doctype html><style>
		body{margin:0;background:white}.banner{height:48px;background:#5631ea}
		header{position:relative;z-index:999;height:68px;background:#212623}
		.wrapper{${outer}}
		.menu{position:absolute;top:55px;left:0;width:100%;height:822px;overflow:auto;
			pointer-events:none;z-index:-1;${inner}}
		.inside{height:1200px;background:red}
		main{height:811px;background:#0a8935}
		.card{position:absolute;left:4px;top:229.09375px;width:484px;height:663px;
			background:linear-gradient(0deg,rgba(0,0,0,.95),rgba(0,0,0,.25))}
		.spacer{height:2000px}
	</style><div class="banner"></div><header><div class="wrapper"><div class="menu">
		<div class="inside"></div></div></div></header><main><div class="card"></div></main>
		<div class="spacer"></div>'
}

fn test_zero_opacity_scroll_metadata_does_not_promote_visible_root_gradients() {
	for inherited in [false, true] {
		mut document := html.parse_document(hidden_scroll_metadata_markup('0', inherited))
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		assert !plan.has_paint_metadata
		mut gradients := 0
		for index, command in commands {
			if command.kind != 'fill_gradient' { continue }
			gradients++
			assert plan.command_layers[index] == 0
		}
		assert gradients == 1
	}
}

fn test_opaque_scroll_containers_keep_raster_metadata() {
	mut document := html.parse_document(hidden_scroll_metadata_markup('1', false))
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1024, 768}, mut plan)
	assert plan.has_paint_metadata
}

fn test_scroll_metadata_returns_after_zero_opacity_is_removed() {
	mut document := html.parse_document(hidden_scroll_metadata_markup('1', false))
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut menu := document.query_selector('.menu') or { panic('menu') }
	mut plan := ChromiumRasterLayerPlan{}
	for opacity in ['1', '0', '1', '0'] {
		menu.set_attribute_value('style', 'opacity:${opacity}')
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		assert plan.has_paint_metadata == (opacity != '0')
	}
}
