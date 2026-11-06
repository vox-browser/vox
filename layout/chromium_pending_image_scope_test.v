module layout

import html

fn test_pending_zero_size_images_keep_their_complete_offscreen_effect_scope() {
	for size in [0, 20] {
		markup := '<!doctype html><style>body{margin:0;height:18000px;background:#1a2081}.fixed{position:fixed;top:0;width:100px;height:20px;background:white}.pending{position:absolute;top:16000px;width:30px;height:30px;will-change:opacity}.pending img{width:${size}px;height:${size}px}</style><div class="fixed"></div><div class="pending"><img src="https://example.test/pending.webp"></div>'
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		assert plan.has_paint_metadata
		mut open := []int{}
		mut pending := -1
		mut pending_open := -1
		mut pending_close := -1
		for index, command in commands {
			if command.kind == 'begin_css_effect_layer' { open << index }
			if command.kind == 'draw_replaced_image' && command.image().image_url == 'https://example.test/pending.webp' {
				pending = index
				assert open.len > 0
				pending_open = open.last()
			}
			if command.kind == 'end_css_effect_layer' {
				assert open.len > 0
				begin := open.pop()
				if begin == pending_open { pending_close = index }
				assert (plan.command_layers[begin] >= 0) == (plan.command_layers[index] >= 0)
			}
		}
		assert open.len == 0
		assert pending >= 0 && pending_open >= 0 && pending_close > pending
		assert (plan.command_layers[pending] >= 0) == (size == 0)
		assert (plan.command_layers[pending_open] >= 0) == (size == 0)
		assert (plan.command_layers[pending_close] >= 0) == (size == 0)
	}
}
