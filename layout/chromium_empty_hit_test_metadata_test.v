module layout

import html
import os

fn test_collapsed_clip_paths_exclude_hit_test_metadata_but_keep_thin_visible_clips() {
	for inset in ['50%', '49%'] {
		mut document := html.parse_document('<!doctype html><style>
		body{margin:0;height:2000px}header{position:fixed;inset:0 0 auto;height:56px;background:white}
		a{position:absolute;left:-1px;top:29px;width:1px;height:1px;clip-path:inset(${inset});background:black}
		</style><header><a>Hidden label</a></header>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 800, 600}, mut plan)
		assert plan.has_paint_metadata
		scratch := unsafe { &chromium_raster_plan_scratch_ }
		assert scratch.paint_metadata.any(it.bounds.x == -1) == (inset == '49%')
	}
}

fn test_fully_clipped_fixed_boxes_do_not_contribute_hit_test_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;height:2000px}aside{position:fixed;inset:0;clip-path:inset(50%)}
		</style><aside><div>Clipped fixed descendants</div></aside>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 800, 600}, mut plan)
	assert plan.has_paint_metadata
	scratch := unsafe { &chromium_raster_plan_scratch_ }
	assert !scratch.paint_metadata.any(it.state.fixed_to_viewport)
}

fn test_collapsed_accessibility_label_does_not_expand_its_fixed_header_raster() {
	source := os.read_file('Tests/Browser/Brave/input/stackoverflow-empty-accessibility-clip.html') or { panic(err) }
	for input in [source, source.replace('<a class="sr">Skip to main content</a>', '')] {
		mut document := html.parse_document(input)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1, LayoutRect{0, 0, 800, 600}, mut plan)
		mut headers := 0
		for index, command in commands {
			if command.kind != 'fill_rect' || command.width != 800 || command.height != 56 { continue }
			headers++
			owner := plan.command_layers[index]
			assert owner > 0
			assert plan.layers[owner].bounds.x == 0
			assert plan.layers[owner].bounds.width == 800
		}
		assert headers == 1
	}
}
