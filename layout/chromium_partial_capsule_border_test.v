module layout

import css
import html
import painting

fn test_three_equal_opaque_sides_keep_touching_capsule_corners_in_native_border_replay() {
	color := css.Color{224, 223, 224, 255}
	for side in ['left', 'right'] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}
			div{position:absolute;left:22px;top:94px;box-sizing:border-box;width:110.4375px;
			height:30px;border:2px solid #e0dfe0;border-${side}:0;
			border-radius:${if side == 'left' { '0 448px 448px 0' } else { '448px 0 0 448px' }}}
			</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 1024, 768)
		commands := root.paint_commands()
		borders := commands.filter(it.kind == 'paint_partial_rounded_border')
		assert borders.len == 1
		border := borders[0]
		assert border.height == 30 && border.color == color.serialize()
		assert border.srgb_color_data != unsafe { nil }
		assert border.srgb_color_data.components == [224.0 / 255, 223.0 / 255, 224.0 / 255, 1.0]!
		assert border.srgb_color_data.serialized == border.color
		assert border.points == if side == 'left' { [2.0, 2.0, 2.0, 0.0] } else { [2.0, 0.0, 2.0, 2.0] }
		assert rounded_single_border_fallback(border).len > 0
	}
}

fn test_capsule_border_preserves_the_partial_border_color_and_width_guards() {
	color := css.Color{224, 223, 224, 255}
	colors := BoxColors{color, color, color, color}
	radii := BoxRadii{top_right: CornerRadius{15, 15}, bottom_right: CornerRadius{15, 15}}
	rect := painting.IntRect{22, 94, 110, 30}
	mut commands := []PaintCommand{}
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{2, 2, 2, 0},
		BoxColors{color, css.Color{224, 223, 224, 128}, color, color}, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{2, 2, 2, 0},
		colors, BoxBorderStyles{right: .dashed}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 2, 0, 0},
		colors, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{2, 2, 2, 2},
		colors, BoxBorderStyles{}, radii, rect, 1)
	assert commands.len == 0
}
