module main

import html
import layout

fn test_promoted_outer_shadow_keeps_the_root_scrollable_clip() {
	for width in [1024, 1200] {
		mut document := html.parse_document('<!doctype html><style>
 html,body{margin:0;background:#090b0f}body{height:2000px;min-width:${width}px}
 .scroller{position:absolute;left:60px;top:650px;width:200px;height:300px;overflow:scroll}
 .scroller div{width:400px;height:600px;background:#436995}
 main{position:absolute;left:32px;top:96px;width:960px;height:800px;
 box-shadow:0 24px 60px #0004;background:linear-gradient(130deg,#121b28,#172233)}
 </style><div class="scroller"><div></div></div><main></main>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
		commands := layout.display_list_commands(document.record_viewport_display_list() or { panic('missing paint') })
		mut plan := layout.ChromiumRasterLayerPlan{}
		layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			layout.LayoutRect{0, 0, 1024, 768}, mut plan)
		mut found := false
		for index, command in commands {
			if command.kind != 'fill_gradient' { continue }
			owner := plan.command_layers[index]
			assert owner > 0
			assert plan.layers[owner].bounds.x == 0
			assert plan.layers[owner].bounds.width == if width == 1024 { 1024.0 } else { 1082.0 }
			found = true
		}
		assert found
	}
}
