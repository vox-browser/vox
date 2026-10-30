module layout

import html

fn test_inline_rounded_background_pairs_without_insetting_its_outer_box() {
	for chromium in [true, false] {
		for radius in [0.5, 5.0] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0;font:16px/23.2px "Helvetica Neue",Arial,sans-serif}
				a{border:1px solid #f0b2b8;border-radius:${radius}px;background:#f9ddde;
				font-size:10.56px;padding:0 .4em 1px}
			</style><a>ask</a>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			root := layout_document_typed_in_viewport(document, 800, 600)
			commands := root.paint_commands()
			backgrounds := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(249 221 222)')
			assert backgrounds.len == 1
			background := backgrounds[0]
			assert background.underlays_next == chromium
			assert background.radius == radius
			if chromium {
				border := commands.filter(it.kind == 'paint_uniform_border')[0]
				assert background.x == border.x - 0.5
				assert background.y == border.y - 0.5
				assert background.width == border.width + 1
				assert background.height == border.height + 1
				assert border.corner_radii.top_left == CornerRadius{radius - 0.5, radius - 0.5}
			}
		}
	}
}

fn test_inline_background_pairing_keeps_intervening_paint_and_other_border_shapes() {
	for rule in ['background-image:linear-gradient(red,blue)', 'border-style:dashed',
		'border-radius:5px / 3px'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/24px Arial}
			a{border:1px solid #f0b2b8;border-radius:5px;background:#f9ddde;padding:0 4px;${rule}}
		</style><a>ask</a>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 800, 600)
		assert !root.paint_commands().any(it.underlays_next)
	}
}

fn test_translucent_block_border_keeps_its_distinct_background_painting() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}div{width:80px;height:30px;border:1px solid rgba(240,178,184,.5);
		border-radius:5px;background:#f9ddde}
	</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands()
	background := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(249 221 222)')[0]
	border := commands.filter(it.kind == 'paint_uniform_border')[0]
	assert !background.underlays_next
	assert background.radius == 5
	assert background.x == border.x - 0.5
	assert background.y == border.y - 0.5
}
