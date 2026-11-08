module layout

import html

fn test_atomic_blend_groups_preserve_surrounding_compositor_paint_metadata() {
	for blend in ['screen', 'multiply'] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}body{height:2000px}header{height:50px;background:linear-gradient(176.66deg,#f26b24 16.92%,#ffa011 66.81%)}
			#blend{position:absolute;left:8px;top:8px;width:34px;height:34px;background:#12578a;mix-blend-mode:${blend};z-index:1}
			#after{position:absolute;left:12px;top:8.5px;width:163px;height:33px;background:white;z-index:1}
			#hint{position:absolute;left:100px;top:8px;width:20px;height:20px;background:blue;will-change:opacity}
		</style><header><div id="blend"></div><div id="after"></div><div id="hint"></div></header>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing blend paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0,0,1024,768}, mut plan)
		assert plan.has_paint_metadata
		mut blend_owner := -1
		mut after_owner := -1
		mut boundaries := 0
		for index, command in commands {
			if layer := command.visual_layer_data {
				if layer.blend_mode != .normal {
					owner := plan.command_layers[index]
					assert owner > 0 && plan.layers[owner].legacy_raster
					if blend_owner >= 0 { assert owner == blend_owner }
					blend_owner = owner
					boundaries++
				}
			}
			if command.kind == 'fill_rect' && command.x == 12 && command.width == 163 {
				after_owner = plan.command_layers[index]
			}
		}
		assert boundaries == 2 && blend_owner > 0
		assert after_owner > 0 && after_owner != blend_owner
		assert plan.layers[after_owner].composited_contents
	}
}
