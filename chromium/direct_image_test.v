module main

import html
import layout
import os
import painting

fn direct_image_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{ command_indices: [0] },
			layout.ChromiumRasterLayer{ composited_contents: true, command_indices: [1] }]
		command_layers: [0, 1]
	}
}

fn test_direct_image_layer_requires_one_owned_replaced_image() {
	commands := [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'draw_replaced_image', image_paintable: &painting.ImagePaintable{} }]
	plan := direct_image_test_plan()
	assert chromium_direct_image_layer_supported(commands, plan, 1)
	assert !chromium_direct_image_layer_supported(commands, plan, 0)
	assert !chromium_direct_image_layer_supported(commands, plan, -1)
	assert !chromium_direct_image_layer_supported(commands, plan, 2)
	for variant in 0 .. 4 {
		mut changed := direct_image_test_plan()
		match variant {
			0 { changed.layers[1].legacy_raster = true }
			1 { changed.layers[1].composited_contents = false }
			2 { changed.layers[1].command_indices = [0, 1] }
			else { changed.command_layers[1] = 0 }
		}
		assert !chromium_direct_image_layer_supported(commands, changed, 1)
	}
	for command in [
		layout.PaintCommand{ kind: 'draw_background_image', image_paintable: &painting.ImagePaintable{} },
		layout.PaintCommand{ kind: 'draw_replaced_image', opacity: .5, image_paintable: &painting.ImagePaintable{} },
		layout.PaintCommand{ kind: 'draw_replaced_image', group_opacity: .5, image_paintable: &painting.ImagePaintable{} },
		layout.PaintCommand{ kind: 'begin_css_effect_layer', image_paintable: &painting.ImagePaintable{} },
		layout.PaintCommand{ kind: 'draw_replaced_image', blur: 1, image_paintable: &painting.ImagePaintable{} },
		layout.PaintCommand{ kind: 'draw_replaced_image' },
		layout.PaintCommand{ kind: 'draw_replaced_image', image_paintable: &painting.ImagePaintable{ border_radii: painting.BorderRadiiData{ top_left: painting.BorderRadiusData{ horizontal: 12, vertical: 12 } } } },
	] {
		assert !chromium_direct_image_layer_supported([commands[0], command], plan, 1)
	}
}

fn test_paused_transform_overlap_promotes_the_direct_image_fixture() {
	markup := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/pikabu-direct-composited-image.html'))!
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	plan := layout.chromium_raster_layer_plan(document, commands, 1)
	mut seen := false
	for index, command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		seen = true
		owner := plan.command_layers[index]
		assert chromium_direct_image_layer_supported(commands, plan, owner)
		assert plan.layers[owner].bounds.x == 125
		assert plan.layers[owner].bounds.y == 429
		assert plan.layers[owner].bounds.width == 577.796875
		assert plan.layers[owner].bounds.height == 435.9375
	}
	assert seen
}

fn test_new_rounded_clip_keeps_the_single_image_on_its_picture_path() {
	markup := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/pikabu-picture-local-image-clip.html'))!
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	plan := layout.chromium_raster_layer_plan(document, commands, 1)
	mut seen := false
	for index, command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		seen = true
		owner := plan.command_layers[index]
		assert owner > 0
		assert !chromium_direct_image_layer_supported(commands, plan, owner)
	}
	assert seen
}

fn test_metadata_keeps_the_hoisted_image_clip_outside_its_picture() {
	markup := os.read_file(os.join_path(@VMODROOT, 'Tests/Browser/Brave/input/pikabu-hoisted-image-clip.html'))!
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
		layout.LayoutRect{0, 0, 1024, 768}, mut plan)
	assert plan.has_picture_clip_metadata
	mut seen := false
	for index, command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		seen = true
		owner := plan.command_layers[index]
		assert owner > 0
		assert !plan.layers[owner].picture_local_rounded_clip
		assert chromium_direct_image_layer_supported(commands, plan, owner)
		// The preceding layer has another clip state: the old approximation
		// incorrectly rejects this image despite its own complete clip metadata.
		fallback := layout.ChromiumRasterLayerPlan{ ...plan, has_picture_clip_metadata: false }
		assert !chromium_direct_image_layer_supported(commands, fallback, owner)
	}
	assert seen
}
