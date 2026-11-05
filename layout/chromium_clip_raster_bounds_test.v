module layout

import html
import dom

fn test_clipped_gradient_does_not_acquire_a_raster_from_its_invisible_overflow() {
	for offset in [0, 20] {
		for scroll_y in [0, 500] {
			mut document := html.parse_document('<!doctype html><style>
   html,body{margin:0;background:transparent}body{height:4000px}
   main{position:absolute;top:96px;width:1024px;height:3000px;background:green}
   .card{position:absolute;left:${772+offset}px;top:${229.09375 + scroll_y}px;width:242px;height:242px;overflow:hidden}
   .overlay{position:absolute;top:-242px;width:484px;height:484px;
    background:linear-gradient(0deg,rgba(0,0,0,.95),rgba(0,0,0,.25))}
   </style><main></main><div class="card"><div class="overlay"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			_ = layout_document_typed_in_viewport(document, 1024, 768)
			document.set_viewport_rect(dom.Rect{0, scroll_y, 1024, 768})
			commands := display_list_commands(document.record_viewport_display_list() or { panic('missing paint') })
			mut plan := ChromiumRasterLayerPlan{}
			update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, scroll_y, 1024, 768}, mut plan)
			assert plan.has_paint_metadata
			mut found := false
			for index, command in commands {
				if command.kind != 'fill_gradient' { continue }
				assert plan.command_layers[index] == 0
				assert !plan.layers[0].composited_contents
				found = true
			}
			assert found
		}
	}
}
