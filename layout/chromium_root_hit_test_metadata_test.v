module layout

import html

fn test_transparent_root_hit_test_geometry_keeps_sparse_content_in_its_document_raster() {
	for background in ['transparent', 'white'] {
		mut document := html.parse_document('<!doctype html><style>
        html,body{margin:0}body{background:${background};height:7065px}
        #lead{position:absolute;left:48px;top:162px;width:200px;height:24px;background:blue}
        #card{position:absolute;left:374px;top:516px;width:602px;height:433.328125px}
        #photo{position:absolute;top:32.546875px;width:602px;height:401.328125px;background:#ab23de}
        .scrim{position:fixed;inset:0;background:rgba(0,0,0,.25)}
        </style><div id="lead"></div><div id="card"><div id="photo"></div></div><div class="scrim"></div><div class="scrim"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 1024, 768}, mut plan)
		mut found := false
		for i, c in commands {
			if c.kind == 'fill_rect' && c.width == 602 {
				assert plan.command_layers[i] == 0
				found = true
			}
		}
		assert found
	}
}

fn test_root_hit_test_metadata_keeps_non_scrolling_and_unsupported_scale_policy() {
	for height in [400, 7065] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;height:${height}px}
        main{position:absolute;left:48px;top:120px;width:200px;height:40px;background:blue}
        aside{position:fixed;inset:0;background:rgba(0,0,0,.25)}</style><main></main><aside></aside>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		for scale in [f64(1), 2] {
			update_chromium_raster_layer_plan_for_viewport(document, commands, scale, LayoutRect{0, 0, 1024, 768}, mut plan)
			assert plan.has_paint_metadata == (height == 7065 && scale == 1)
			assert plan.command_layers.len == commands.len
			for i, owner in plan.command_layers {
				if owner >= 0 {
					assert i in plan.layers[owner].command_indices
				}
			}
		}
	}
}
