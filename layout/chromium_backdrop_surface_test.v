module layout

import html

fn test_backdrop_filter_foreground_keeps_an_independent_raster_origin() {
	for chromium in [false, true] {
		for filter in ['none', 'blur(0px)', 'blur(.1em)', 'opacity(.5)'] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}#outer{position:absolute;left:232.28125px;top:263px;
					width:559.4375px;height:373px;backdrop-filter:${filter};background:rgb(1 2 3)}
				#inner{width:100%;height:100%;background:rgb(4 5 6)}
			</style><div id="outer"><div id="inner"></div></div>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			_ = layout_document_typed_in_viewport(document, 1024, 768)
			commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
			groups := commands.filter(it.kind == 'begin_css_effect_layer')
			expected := chromium && filter != 'none'
			assert groups.len == if expected { 1 } else { 0 }, filter
			if !expected { continue }
			assert groups[0].visual_layer().opacity == 1
			plan := chromium_raster_layer_plan(document, commands, 1)
			mut owner := -1
			for index, command in commands {
				if command.color != 'rgb(4 5 6)' { continue }
				owner = plan.command_layers[index]
			}
			assert owner > 0
			layer := plan.layers[owner]
			assert layer.composited_contents && !layer.legacy_raster
			// The filter command encloses its rounded border box. The isolated
			// picture retains that box rather than a root tile at y=254.
			assert layer.bounds.x == 232 && layer.bounds.y == 263
			assert layer.bounds.width == 560 && layer.bounds.height == 373
		}
	}
}
