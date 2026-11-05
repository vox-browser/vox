module layout

import html

fn test_sparse_scrolling_root_keeps_its_origin_around_atomic_svg_and_opacity() {
	for background in ['transparent', 'white'] {
		mut document := html.parse_document('<!doctype html><style>
   html,body{margin:0;background:${background}}body{height:4000px}
   .banner{height:48px;background:purple;position:relative}
   svg{position:absolute;left:20px;top:16px}
   main{position:absolute;top:96px;width:1024px;height:3000px;background:green}
   .card{position:absolute;left:4px;top:229.09375px;width:484px;height:663px;
    background:linear-gradient(0deg,rgba(0,0,0,.95),rgba(0,0,0,.25))}
   .fade{position:absolute;top:500px;left:900px;width:20px;height:20px;background:red;opacity:.5}
   </style><div class="banner"><svg width="16" height="16" viewBox="0 0 24 24">
   <defs><clipPath id="clip"><rect width="24" height="24"/></clipPath></defs><g clip-path="url(#clip)"><path fill="white" d="m13.06 12 6.44-6.44-1.06-1.06L12 10.94 5.56 4.5 4.5 5.56 10.94 12 4.5 18.44l1.06 1.06L12 13.06l6.44 6.44 1.06-1.06z"/>
   </g></svg></div><main></main><div class="card"></div><div class="fade"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 1024, 768}, mut plan)
		assert plan.has_paint_metadata
		mut gradients := 0
		mut scopes := 0
		mut owner := -1
		for index, command in commands {
			if command.kind == 'fill_gradient' {
				gradients++
				assert plan.command_layers[index] == 0
				assert plan.layers[0].bounds.y == 0
			}
			if command.visual_layer_data != none && command.kind.starts_with('begin_') {
				scopes++
				owner = plan.command_layers[index]
			}
			if owner >= 0 {
				assert plan.command_layers[index] == owner
				if command.visual_layer_data != none && command.kind.starts_with('end_') {
					owner = -1
				}
			}
		}
		assert gradients == 1
		assert scopes == 2
		assert owner == -1
	}
}

fn test_root_hit_test_metadata_retains_non_scrolling_and_unsupported_scale_policy() {
	for height in [100, 4000] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0;height:${height}px}
   .banner{height:48px;background:purple}main{height:40px;margin-top:48px;background:green}
   </style><div class="banner"></div><main></main>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		mut plan := ChromiumRasterLayerPlan{}
		for scale in [f64(1), 2] {
			update_chromium_raster_layer_plan_for_viewport(document, commands, scale, LayoutRect{0, 0, 1024, 768}, mut plan)
			assert plan.has_paint_metadata == (height == 4000 && scale == 1)
		}
	}
}

fn test_wider_root_overflow_keeps_the_vertical_cull_projection() {
	mut plan := ChromiumRasterLayerPlan{}
	viewport := LayoutRect{0, 0, 1024, 768}
	contents := LayoutRect{0, 0, 1044, 10000}
	cull := chromium_root_paint_cull(viewport, contents, 1, &plan) or { panic('missing cull') }
	assert cull == LayoutRect{0, 0, 1044, 4768}
	assert chromium_root_paint_cull(viewport, contents, 2, &plan) == none
}
