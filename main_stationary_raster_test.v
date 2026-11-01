module main

import layout

fn test_stationary_raster_excludes_independently_updated_content() {
	ordinary := [layout.PaintCommand{kind: 'fill_rect'},
		layout.PaintCommand{kind: 'draw_replaced_image'},
		layout.PaintCommand{kind: 'draw_svg_path'}]
	assert stationary_document_raster_eligible(ordinary)
	for kind in ['draw_canvas', 'draw_video', 'draw_nested_document', 'paint_nested_display_list'] {
		mut commands := ordinary.clone()
		commands << layout.PaintCommand{kind: kind}
		assert !stationary_document_raster_eligible(commands), kind
	}
}
