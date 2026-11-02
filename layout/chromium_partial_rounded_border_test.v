module layout

import css
import html
import painting

fn test_chromium_partial_border_keeps_curves_and_all_visible_sides() {
	markup := '<!doctype html><style>
		html,body{margin:0}article{position:absolute;left:701px;top:92px;
		box-sizing:border-box;width:298px;height:560.453125px;background:#e6e6e6;
		border:solid #ccc;border-width:0 1px 1px;border-radius:0 10px 0 10px}
	</style><article></article>'
	mut document := html.parse_document(markup)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 1024, 768)
	borders := root.paint_commands().filter(it.kind == 'paint_partial_rounded_border')
	assert borders.len == 1
	border := borders[0]
	assert [border.x, border.y, border.width, border.height] == [701.0, 92.0, 298.0, 560.0]
	assert border.points == [0.0, 1.0, 1.0, 1.0]
	assert border.corner_radii == BoxRadii{CornerRadius{}, CornerRadius{10, 10}, CornerRadius{}, CornerRadius{10, 10}}
	assert border.color == 'rgb(204 204 204)'
	assert border.force_dark_role == .border
	assert root.render_svg(1024, 768).contains('fill="rgb(204 204 204)"')

	mut original := html.parse_document(markup)
	defer { original.finalize() }
	original.set_font_rendering_policy(.libweb)
	ordinary := layout_document_typed_in_viewport(original, 1024, 768)
	assert !ordinary.paint_commands().any(it.kind == 'paint_partial_rounded_border')
}

fn test_partial_rounded_border_supports_each_missing_side_and_opposite_sides() {
	color := css.Color{204, 204, 204, 255}
	colors := BoxColors{color, color, color, color}
	radii := BoxRadii{CornerRadius{6, 8}, CornerRadius{10, 8}, CornerRadius{}, CornerRadius{7, 9}}
	for widths in [[0.0, 2.0, 3.0, 4.0], [2.0, 0.0, 3.0, 4.0],
		[2.0, 3.0, 0.0, 4.0], [2.0, 3.0, 4.0, 0.0], [2.0, 0.0, 4.0, 0.0],
		[0.0, 2.0, 3.0, 0.0]] {
		mut commands := []PaintCommand{}
		assert append_chromium_partial_rounded_border(mut commands,
			BoxEdges{widths[0], widths[1], widths[2], widths[3]}, colors,
			BoxBorderStyles{}, radii, painting.IntRect{20, 30, 100, 80}, 1)
		assert commands.len == 1
		assert commands[0].points == widths
		assert rounded_single_border_mode(commands[0].kind) == 8
		fallback := rounded_single_border_fallback(commands[0])
		assert fallback.len > 0 && fallback.all(it.kind == 'draw_svg_path')
		assert fallback.all(it.color == color.serialize())
	}
}

fn test_partial_rounded_border_retains_other_painting_paths_for_complex_edges() {
	color := css.Color{204, 204, 204, 255}
	colors := BoxColors{color, color, color, color}
	radii := BoxRadii{CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}}
	rect := painting.IntRect{20, 30, 100, 80}
	mut commands := []PaintCommand{}
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 0, 2, 0}, colors, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{2, 2, 2, 2}, colors, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 2, 2, 2}, colors, BoxBorderStyles{bottom: .dashed}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 2, 2, 2},
		BoxColors{...colors, bottom: css.Color{204, 204, 204, 128}}, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 2, 2, 2},
		BoxColors{...colors, bottom: css.Color{10, 20, 30, 255}}, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_partial_rounded_border(mut commands, BoxEdges{0, 2, 2, 2}, colors, BoxBorderStyles{}, radii, painting.IntRect{0, 0, 10, 10}, 1)
	assert commands.len == 0
}
