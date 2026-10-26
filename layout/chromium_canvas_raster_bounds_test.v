module layout

import html

fn test_canvas_raster_bounds_include_the_painted_scrollable_area() {
	box := BlockBox{
		x:           0
		y:           0
		width:       300
		height:      200
		canvas_data: retained_block_box_canvas(BlockBoxCanvasData{
			paints_canvas_background: true
			canvas_x:                 -20
			canvas_y:                 0
			canvas_width:             520
			canvas_height:            1800
		})
	}
	assert chromium_raster_chunk_bounds(&box, &PaintCommand{}) == LayoutRect{-20, 0, 520, 1800}
	for phase in [CompatibilityPaintPhase.border, .foreground, .outline] {
		assert chromium_raster_chunk_bounds(&box, &PaintCommand{ paint_phase: phase }) == LayoutRect{0, 0, 300, 200}
	}
	// Ordinary boxes retain their border-box bounds.
	ordinary := BlockBox{ x: 10, y: 20, width: 30, height: 40 }
	assert chromium_raster_chunk_bounds(&ordinary, &PaintCommand{}) == LayoutRect{10, 20, 30, 40}
}

fn test_canvas_background_keeps_distant_page_content_in_the_root_raster() {
	for scale in [1.0, 2.0] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}html{height:30px}body{background:white}
			header{height:0}
			main{width:380px;height:1800px}
			aside{position:absolute;left:400px;top:20px;width:100px;height:1200px;background:rgb(1 2 3)}
		</style><header></header><main></main><aside></aside>')
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(scale)
		root := layout_document_typed_in_viewport(document, 500, 200)
		assert root.border_box().height == 30 * scale
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		plan := chromium_raster_layer_plan(document, commands, 2)
		assert plan.layers.len == 1
		assert plan.layers[0].bounds.height == 1800
		for layer in plan.command_layers {
			assert layer == 0
		}
		document.finalize()
	}
}
