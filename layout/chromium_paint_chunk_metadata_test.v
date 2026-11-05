module layout

import html
import css
import dom

fn test_root_paint_cull_retains_its_interest_rect_until_an_edge_moves_512_pixels() {
	contents := LayoutRect{0, 0, 1280, 18000}
	mut plan := ChromiumRasterLayerPlan{}
	first := chromium_root_paint_cull(LayoutRect{0, 6400, 1280, 800}, contents, 1, &plan) or {
		panic('vertical root cull')
	}
	assert first == LayoutRect{0, 2400, 1280, 8800}
	plan.paint_cull_rect = first
	plan.paint_cull_viewport_size = [f64(1280), 800]!
	plan.paint_cull_contents = contents
	assert chromium_root_paint_cull(LayoutRect{0, 6911, 1280, 800}, contents, 1, &plan)? == first
	assert chromium_root_paint_cull(LayoutRect{0, 6912, 1280, 800}, contents, 1, &plan)? ==
		LayoutRect{0, 2912, 1280, 8800}
	assert chromium_root_paint_cull(LayoutRect{0, 0, 1280, 800}, contents, 1, &plan)? ==
		LayoutRect{0, 0, 1280, 4800}
	assert chromium_root_paint_cull(LayoutRect{0, 17200, 1280, 800}, contents, 1, &plan)? ==
		LayoutRect{0, 13200, 1280, 4800}
	// Other backing scales keep the preceding planner. Horizontal overflow
	// still permits the finite vertical root projection at scale one.
	assert chromium_root_paint_cull(LayoutRect{0, 6400, 1280, 800}, contents, 2, &plan) == none
	assert chromium_root_paint_cull(LayoutRect{0, 6400, 1280, 800}, LayoutRect{0, 0, 1600, 18000}, 1, &plan)? == LayoutRect{0, 2400, 1600, 8800}
	assert chromium_root_paint_cull(LayoutRect{0, 0, 1280, 800}, LayoutRect{0, 0, 1280, 600}, 1, &plan)? ==
		LayoutRect{0, 0, 1280, 600}
	assert chromium_root_paint_cull(LayoutRect{0, 0, 1280, 800}, LayoutRect{0, 0, 1280, 600}, 2, &plan) == none
}

fn chunk_metadata_document_markup() string {
	return '<!doctype html><style>
		body{margin:0;background:#090b0f}
		.earlier{display:grid;height:200px}.earlier>div{background:#273c59}
		.gap{height:6000px}.cards{display:grid;grid-template-columns:1fr 1fr;margin:0 48px;gap:20px}
		.card{height:450px;background:linear-gradient(135deg,#121b288f,#10151e8f)}
		.before-scroll{height:2300px}.scroll{height:100px;margin:0 48px;overflow:auto;scrollbar-width:none}
		.wide{width:2400px;height:80px}.after-scroll{height:1700px;margin:0 48px}
		footer{height:100px;margin:0 48px;border-top:1px solid #273c59}
	</style><div class="earlier"><div></div></div><div class="gap"></div>
	<div class="cards"><div class="card"></div><div class="card"></div></div>
	<div class="before-scroll"></div><div class="scroll"><div class="wide"></div></div>
	<div class="after-scroll"></div><footer></footer>'
}

fn test_empty_scroll_hit_test_metadata_keeps_overlapping_grid_paint_on_one_raster() {
	mut document := html.parse_document(chunk_metadata_document_markup())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 6400, 1280, 800}, mut plan)
	gradients := commands.filter(it.kind == 'fill_gradient')
	assert gradients.len == 2
	mut layer := -1
	for index, command in commands {
		if command.kind != 'fill_gradient' { continue }
		assert plan.command_layers[index] > 0
		if layer >= 0 {
			assert plan.command_layers[index] == layer
		}
		layer = plan.command_layers[index]
	}
	assert plan.layers[layer].bounds.x == 48
	assert plan.layers[layer].bounds.y == 6200
	assert plan.layers[layer].bounds.width == 1184
	assert plan.layers.any(it.command_indices.len == 0 && it.bounds.y == 8950)
	assert plan.command_layers.any(it < 0)
	// Culled gaps do not become part of a merged chunk's command span.
	for index, owner in plan.command_layers {
		if owner < 0 {
			assert !plan.layers.any(index in it.command_indices)
		} else {
			assert index in plan.layers[owner].command_indices
		}
	}
	assert !chromium_raster_cull_changed(document, LayoutRect{0, 6500, 1280, 800}, 1, &plan)
	assert chromium_raster_cull_changed(document, LayoutRect{0, 0, 1280, 800}, 1, &plan)
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1280, 800}, mut plan)
	// With no interested compositor scrolls, a painted root retains its
	// established picture policy, including these ordinary offscreen commands.
	for index, command in commands {
		if command.kind == 'fill_gradient' {
			assert plan.command_layers[index] == 0
		}
	}
}

fn test_viewport_metadata_preserves_the_existing_plan_for_unsupported_root_scales() {
	mut document := html.parse_document(chunk_metadata_document_markup())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	control := chromium_raster_layer_plan(document, commands, 2)
	mut candidate := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 2,
		LayoutRect{0, 6400, 1280, 800}, mut candidate)
	assert control.command_layers == candidate.command_layers
	assert control.layers.map(it.bounds) == candidate.layers.map(it.bounds)
}

fn test_culling_keeps_complete_nested_effect_scopes_for_escaping_visible_children() {
	for child_top in [200, 6400] {
		markup := chunk_metadata_document_markup() + '<div style="position:absolute;top:0;left:0;width:20px;height:10px;will-change:opacity"><div style="position:relative;height:10px;will-change:opacity"><div style="position:absolute;top:${child_top}px;width:20px;height:20px;background:red"></div></div></div>'
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1280, 800)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 6400, 1280, 800}, mut plan)
		mut boundaries := 0
		for index, command in commands {
			if command.kind !in ['begin_css_effect_layer', 'end_css_effect_layer'] { continue }
			boundaries++
			assert (plan.command_layers[index] >= 0) == (child_top == 6400)
		}
		assert boundaries == 4
	}
}

fn test_short_root_scroll_metadata_retains_the_empty_content_padding() {
	mut document := html.parse_document($embed_file('../Tests/Browser/Brave/input/compositor-css-gradients.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 0, 1024, 768}, mut plan)
	result := document_layout_result(document) or { panic('layout') }
	assert plan.has_paint_metadata, 'cull=${plan.paint_cull_rect}, contents=${result.paint_tree.scrollable_overflow}'
	mut found := false
	for index, command in commands {
		if command.kind != 'fill_gradient' || command.x < 500 { continue }
		layer := plan.command_layers[index]
		assert layer > 0
		assert plan.layers[layer].bounds.x == 528
		assert plan.layers[layer].bounds.y == 16
		assert plan.layers[layer].bounds.width == 480
		assert plan.layers[layer].bounds.height == 1120
		background := plan.layers[layer].scroll_background_command
		assert background >= 0
		assert commands[background].kind == 'fill_rect'
		color := css.parse_color_string(commands[background].color) or { panic('background color') }
		assert color == css.Color{14, 19, 26, 255}
		assert plan.command_layers[background] != layer
		found = true
	}
	assert found
}

fn test_scroll_background_duplication_rejects_images_transparency_and_inset_shadows() {
	for style in ['background:#123', 'background:#1238', 'background:#123;box-shadow:inset 0 1px white',
		'background:linear-gradient(red,blue)', 'background:#123;border-radius:5px'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}.scroll{width:200px;height:100px;overflow:auto;${style}}.child{height:400px;color:red}</style><div class="scroll"><div class="child">content</div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 400, 300)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 400, 300}, mut plan)
		assert plan.layers.any(it.scroll_contents)
		assert plan.layers.any(it.scroll_background_command >= 0) == (style == 'background:#123')
		update_chromium_raster_layer_plan(document, commands, 1, mut plan)
		assert plan.layers.all(it.scroll_background_command == -1)
	}
}

fn test_live_scrolled_clips_and_fixed_content_survive_document_space_culling() {
	mut document := html.parse_document(chunk_metadata_document_markup() +
		'<pre style="position:absolute;left:96px;top:6560px;width:480px;height:170px;overflow:hidden;color:cyan">clipped code</pre><div style="position:fixed;left:0;top:10px;width:100px;height:20px;background:lime">fixed</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	document.set_viewport_rect(dom.Rect{0, 6400, 1280, 800})
	commands := display_list_commands(document.record_viewport_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 6400, 1280, 800}, mut plan)
	assert plan.has_paint_metadata
	mut clipped := false
	mut fixed := false
	for index, command in commands {
		if command.text == 'clipped code' {
			assert command.has_clip && command.clip_y < 800
			assert plan.command_layers[index] >= 0
			clipped = true
		}
		if command.text == 'fixed' {
			assert command.fixed_to_viewport
			assert plan.command_layers[index] > 0
			fixed = true
		}
	}
	assert clipped && fixed
}

fn test_atomic_masks_keep_complete_scopes_without_disabling_sibling_paint_metadata() {
	for top in [200, 6400] {
		mut document := html.parse_document(chunk_metadata_document_markup() +
			'<svg style="position:absolute;left:80px;top:${top}px" width="40" height="40"><defs><mask id="mask"><rect width="40" height="40" fill="white"/></mask></defs><g mask="url(#mask)"><rect width="40" height="40" fill="red"/></g></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1280, 800)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 6400, 1280, 800}, mut plan)
		assert plan.has_paint_metadata
		mut mask_owner := -1
		mut in_mask := false
		mut masks := 0
		for index, command in commands {
			if command.kind == 'begin_svg_mask_layer' {
				masks++
				in_mask = true
				mask_owner = plan.command_layers[index]
				assert (mask_owner >= 0) == (top == 6400)
			}
			if in_mask { assert plan.command_layers[index] == mask_owner }
			if command.kind == 'end_svg_mask_layer' { in_mask = false }
		}
		assert masks == 1 && !in_mask
		assert plan.layers.any(it.command_indices.len == 0 && it.bounds.y == 8950)
		for index, command in commands {
			if command.kind == 'fill_gradient' { assert plan.command_layers[index] > 0 }
		}
	}
}

fn test_viewport_culling_keeps_unsized_generated_images_until_they_can_request_their_source() {
	mut document := html.parse_document(chunk_metadata_document_markup() +
		'<style>.pending:before{content:url(https://pending-image.test/play.svg)}</style><span class="pending" style="position:absolute;top:6500px">duration</span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1280, 800)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0, 6400, 1280, 800}, mut plan)
	assert plan.has_paint_metadata
	mut pending := 0
	for index, command in commands {
		if command.kind != 'draw_replaced_image' || command.image_data == unsafe { nil }
			|| command.image_data.image_url != 'https://pending-image.test/play.svg' { continue }
		assert command.width == 0 || command.height == 0
		assert plan.command_layers[index] >= 0
		pending++
	}
	assert pending == 1
}

fn test_atomic_mask_does_not_split_its_opaque_sticky_parent_raster() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}header{position:sticky;top:0;background:white;height:40px}header i{position:absolute;left:100px;top:10px;width:16px;height:16px;background:black;mask-image:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'16\' height=\'16\'%3E%3Ccircle cx=\'8\' cy=\'8\' r=\'8\'/%3E%3C/svg%3E")}header span{position:absolute;right:20px;top:5px;width:70px;height:30px;background:white}.scroll{height:30px;overflow:auto}.scroll div{width:2000px}</style><header><i></i><span></span></header><div class="scroll"><div>news</div></div><div style="height:6000px"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := ChromiumRasterLayerPlan{}
	update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		LayoutRect{0,0,1024,768}, mut plan)
	assert plan.has_paint_metadata
	mut header := -1
	mut resumed := -1
	mut masks := 0
	for index, command in commands {
		if command.kind == 'begin_svg_mask_layer' { masks++ }
		if command.kind == 'fill_rect' {
			if command.width == 1024 && command.height == 40 { header = plan.command_layers[index] }
			if command.width == 70 && command.height == 30 { resumed = plan.command_layers[index] }
		}
	}
	assert masks == 1, 'mask count=${masks}'
	assert header > 0 && resumed == header, 'parent=${header}, resumed=${resumed}'
}
