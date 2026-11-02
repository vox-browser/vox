module layout

import html
import os

fn test_sticky_raster_bounds_include_the_live_horizontal_offset() {
	source := os.read_file('${@DIR}/../Tests/Browser/Brave/input/chromium-sticky-raster-space.html')!
	for hint in ['', '<style>.main{will-change:transform}</style>'] {
		mut document := html.parse_document(source + hint)
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		enable_native_paint_tree_storage(document)
		enable_native_static_svg_backgrounds(document)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing recording') })
		mut plan := ChromiumRasterLayerPlan{}
		update_chromium_raster_layer_plan_for_viewport(document, commands, 1,
			LayoutRect{0, 0, 1024, 768}, mut plan)
		mut bubble_owner := -1
		mut vector_owner := -1
		for index, command in commands {
			if command.kind == 'fill_rect' && command.width == 246 && command.height == 44 {
				bubble_owner = plan.command_layers[index]
				assert command.transform[4] == 260
			}
			if command.kind == 'draw_svg_path' { vector_owner = plan.command_layers[index] }
		}
		assert bubble_owner > 0
		assert bubble_owner == vector_owner
		assert plan.layers[bubble_owner].composited_contents
		assert plan.layers[bubble_owner].bounds.x == 260
		assert plan.layers[bubble_owner].bounds.y == 61
		assert plan.layers[bubble_owner].bounds.width == 764
		// The path's ink starts at x=370 after the sticky offset. It cannot be
		// culled against the clip at x=260 using its untranslated x=110.
		assert plan.layers[vector_owner].bounds.x <= 370
	}
}

fn test_explicit_raster_space_keeps_clip_and_ink_in_the_same_coordinates() {
	box := BlockBox{ x: 100, y: 140, width: 100, height: 100 }
	command := PaintCommand{
		kind: 'draw_svg_path'
		has_clip: true
		clip_x: 260
		clip_y: 61
		clip_width: 764
		clip_height: 945
	}
	assert chromium_raster_chunk_bounds_in_space(&box, &command, 0,
		[f64(1), 0, 0, 1, 260, 0]!) == LayoutRect{360, 140, 100, 100}
	// The existing retained-space API remains valid for unscrolled boxes.
	assert chromium_raster_chunk_bounds(&box, &command).width == 0
}
