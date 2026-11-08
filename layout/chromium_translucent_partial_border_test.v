module layout

import html

fn test_translucent_partial_border_keeps_one_rounded_ring_and_computed_alpha() {
	for alpha in ['.08', '.3', '.501'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0;background:#f7f7f7}div{box-sizing:border-box;position:absolute;top:564px;width:704px;height:59px;background:white;border:1px solid rgb(0 0 0 / ${alpha});border-bottom:none;border-radius:4px 4px 0 0}</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 1024, 768)
		commands := root.paint_commands()
		borders := commands.filter(it.kind == 'paint_partial_rounded_border')
		assert borders.len == 1
		border := borders[0]
		assert border.points == [1.0, 1, 0, 1]
		assert border.srgb_color_data != unsafe { nil }
		assert border.srgb_color_data.components == [f64(0), 0, 0, alpha.f64()]!
		assert !commands.any(it.kind == 'draw_svg_path')
		assert rounded_single_border_fallback(border).len > 0
	}
}

fn test_translucent_capsule_labels_and_unequal_sides_keep_their_existing_fallback() {
	for extra in ['border-radius:0 15px 15px 0;border-left:0',
		'border-bottom:0;border-left-color:rgb(0 0 0 / .1)'] {
		mut document := html.parse_document('<!doctype html><style>div{width:110px;height:30px;border:2px solid rgb(0 0 0 / .08);border-radius:4px;${extra}}</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 800, 600)
		assert !root.paint_commands().any(it.kind == 'paint_partial_rounded_border')
	}
}
