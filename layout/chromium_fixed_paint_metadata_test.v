module layout

import html

fn test_fixed_hit_test_metadata_uses_the_same_raster_owner_as_its_paint() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;height:2000px}
		header{position:fixed;top:0;width:100%;height:64px;background:white}
		footer{position:fixed;bottom:0;width:100%;height:75px;background:#323232}
		.scroll{position:absolute;top:200px;width:180px;height:80px;overflow:auto}
		.scroll div{height:250px}
	</style><header><span>Header label</span></header>
	<footer><span>Banner label</span></footer><div class="scroll"><div>Scroll</div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1024, 768}, mut plan)
	assert plan.has_paint_metadata
	result := document_layout_result(document) or { panic('layout') }
	scratch := unsafe { &chromium_raster_plan_scratch_ }
	mut owners := []u64{}
	for label in ['Header label', 'Banner label'] {
		mut found := false
		for command in commands {
			if command.kind != 'draw_text' || command.text != label { continue }
			box := result.paint_order[command.paint_box_index].box
			_, metadata_state := chromium_metadata_state(box, result, scratch)
			owner := chromium_fixed_raster_owner(box)
			assert owner != 0
			assert metadata_state.fixed_to_viewport
			assert metadata_state.fixed_raster_owner == owner
			owners << owner
			found = true
		}
		assert found
	}
	assert owners.len == 2 && owners[0] != owners[1]
}

fn test_fixed_background_and_descendant_text_share_one_metadata_raster() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;height:2000px}
		footer{position:fixed;bottom:0;width:100%;height:75px;background:#323232;color:#bebebe}
		footer span{position:absolute;left:250px;top:16px}
		.scroll{position:absolute;top:200px;width:180px;height:80px;overflow:auto}
		.scroll div{height:250px}
	</style><footer><span>Banner label</span></footer><div class="scroll"><div>Scroll</div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1024, 768}, mut plan)
	assert plan.has_paint_metadata
	mut background := -1
	mut text := -1
	for index, command in commands {
		if command.kind == 'fill_rect' && command.y == 693 {
			background = plan.command_layers[index]
		}
		if command.kind == 'draw_text' && command.text == 'Banner label' {
			text = plan.command_layers[index]
		}
	}
	assert background > 0 && text > 0
	assert background == text
}
