module layout

import html

fn test_scroll_raster_promotion_requires_overflow_on_a_user_scrollable_axis() {
	for overflow_x in ['hidden', 'auto'] {
		for overflow_y in ['hidden', 'auto'] {
			for size in [[100, 30], [112, 30], [100, 60], [112, 60]] {
				mut document := html.parse_document('<!doctype html><style>
					html,body{margin:0}#scroll{width:100px;height:30px;
					padding:4px;overflow-x:${overflow_x};overflow-y:${overflow_y}}
					#ink{width:${size[0]}px;height:${size[1]}px;background:rgb(1 2 3)}
				</style><div id="scroll"><div id="ink"></div></div>')
				defer { document.finalize() }
				document.set_font_rendering_policy(.chromium)
				_ = layout_document_typed_in_viewport(document, 300, 200)
				commands := display_list_commands(document.record_display_list() or { panic('paint') })
				plan := chromium_raster_layer_plan(document, commands, 1)
				mut index := -1
				for i, command in commands {
					if command.color == 'rgb(1 2 3)' { index = i; break }
				}
				assert index >= 0
				owner := plan.command_layers[index]
				expected := (overflow_x == 'auto' && size[0] > 100)
					|| (overflow_y == 'auto' && size[1] > 30)
				assert plan.layers[owner].scroll_contents == expected
			}
		}
	}
}
