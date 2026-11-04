module layout

import html
import os

fn test_relative_clients_keep_disjoint_columns_on_the_root_raster() {
	mut document := html.parse_document(os.read_file('Tests/Browser/Brave/input/relative-paint-client-chunks.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 1024, 768}, mut plan)
	mut found := false
	for i, c in commands {
		if c.kind == 'draw_text' && c.text == 'SECOND AUTHOR' {
			found = true
			assert plan.command_layers[i] == 0
		}
	}
	assert found
	assert plan.has_paint_metadata
}
