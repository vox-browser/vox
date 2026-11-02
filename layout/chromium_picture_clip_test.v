module layout

import html
import os
import painting

fn test_rounded_image_picture_clips_follow_metadata_paint_order() {
	for name, local_clip in {
		'pikabu-direct-composited-image':  false
		'pikabu-picture-local-image-clip': true
		'pikabu-hoisted-image-clip':       false
	} {
		markup := os.read_file('${@DIR}/../Tests/Browser/Brave/input/${name}.html')!
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		assert plan.has_picture_clip_metadata
		assert !plan.has_paint_metadata
		mut images := 0
		for index, command in commands {
			if command.kind != 'draw_replaced_image' { continue }
			images++
			owner := plan.command_layers[index]
			assert owner > 0
			assert plan.layers[owner].composited_contents
			assert plan.layers[owner].picture_local_rounded_clip == local_clip, name
		}
		assert images == 1
	}
}

fn test_picture_clip_state_resets_when_the_layer_plan_is_reused() {
	mut plan := ChromiumRasterLayerPlan{}
	for name in ['pikabu-picture-local-image-clip', 'pikabu-hoisted-image-clip',
		'pikabu-picture-local-image-clip'] {
		markup := os.read_file('${@DIR}/../Tests/Browser/Brave/input/${name}.html')!
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		for index, command in commands {
			if command.kind == 'draw_replaced_image' {
				assert plan.layers[plan.command_layers[index]].picture_local_rounded_clip ==
					(name == 'pikabu-picture-local-image-clip')
			}
		}
	}
}

fn test_equal_clip_geometry_keeps_distinct_property_tree_identity() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.clip{position:absolute;left:10px;top:20px;width:100px;height:80px;
		overflow:hidden;border-radius:12px}.child{height:200px;background:red}
		</style><div class="clip"><div class="child"></div></div>
		<div class="clip"><div class="child"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	result := document_layout_result(document) or { panic('layout') }
	mut clips := []int{}
	for index, node in result.visual_context_tree.nodes {
		if node.data is painting.ClipVisualData {
			if node.data.corner_radii.has_any_radius() { clips << index }
		}
	}
	assert clips.len == 2
	left := clips[0]
	right := clips[1]
	parent := result.visual_context_tree.nodes[left].parent_index
	assert result.visual_context_tree.nodes[right].parent_index == parent
	assert chromium_common_recording_context(result, left, left) == left
	assert chromium_common_recording_context(result, left, parent) == parent
	assert chromium_common_recording_context(result, left, right) == parent
	assert chromium_common_recording_context(result, right, left) == parent
}

fn test_clip_metadata_preserves_existing_no_scroll_raster_geometry() {
	for name in ['pikabu-picture-local-image-clip', 'pikabu-hoisted-image-clip'] {
		markup := os.read_file('${@DIR}/../Tests/Browser/Brave/input/${name}.html')!
		mut document := html.parse_document(markup)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		baseline := chromium_raster_layer_plan(document, commands, 1)
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		assert plan.has_picture_clip_metadata
		assert !plan.has_paint_metadata
		assert plan.command_layers == baseline.command_layers
		assert plan.layers.len == baseline.layers.len
		for index, layer in plan.layers {
			assert layer.bounds == baseline.layers[index].bounds
			assert layer.command_indices == baseline.layers[index].command_indices
		}
	}
}
