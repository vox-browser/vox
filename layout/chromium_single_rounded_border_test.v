module layout

import css
import html
import painting

fn test_chromium_single_rounded_border_preserves_each_side_and_snapped_frame() {
	color := css.Color{66, 112, 162, 255}
	colors := BoxColors{color, color, color, color}
	radii := BoxRadii{CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}}
	for side in 0 .. 4 {
		border := BoxEdges{
			top:    if side == 0 { 4.0 } else { 0.0 }
			right:  if side == 1 { 4.0 } else { 0.0 }
			bottom: if side == 2 { 4.0 } else { 0.0 }
			left:   if side == 3 { 4.0 } else { 0.0 }
		}
		mut commands := []PaintCommand{}
		append_translated_border_commands(mut commands, border, colors, BoxBorderStyles{},
			radii, 2981.4375, 937, 329.125, 60, 1, true)
		assert commands.len == 1
		command := commands[0]
		assert rounded_single_border_mode(command.kind) == side + 2
		assert [command.x, command.y, command.width, command.height] == [2981.0, 937.0, 330.0,
			60.0]
		assert command.corner_radii == radii
		assert command.stroke_width == 4 && command.color == 'rgb(66 112 162)'
		assert command.force_dark_role == .border
		fallback := rounded_single_border_fallback(command)
		assert fallback.len > 0 && fallback.all(it.kind == 'draw_svg_path')
	}
}

fn test_chromium_single_rounded_border_retains_transparent_adjacent_insets() {
	color := css.Color{66, 112, 162, 255}
	mut commands := []PaintCommand{}
	radii := BoxRadii{CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}}
	assert append_chromium_single_rounded_border(mut commands, BoxEdges{2, 2, 4, 2},
		BoxColors{ top: css.Color{ a: 0 }, right: css.Color{ a: 0 }, bottom: color, left: css.Color{ a: 0 } }, BoxBorderStyles{}, radii, painting.IntRect{0, 0, 330, 60}, 1)
	assert commands.len == 1 && commands[0].kind == 'paint_rounded_border_bottom'
	assert commands[0].points == [2.0, 2.0, 4.0, 2.0]
	fallback := rounded_single_border_fallback(commands[0])
	assert fallback.len > 0
	assert fallback.any(it.color == color.serialize())
}

fn test_chromium_single_rounded_border_falls_back_for_complex_edges() {
	color := css.Color{66, 112, 162, 255}
	colors := BoxColors{color, color, color, color}
	radii := BoxRadii{CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}}
	mut commands := []PaintCommand{}
	rect := painting.IntRect{0, 0, 300, 60}
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{0, 0, 4, 0}, colors,
		BoxBorderStyles{}, BoxRadii{}, rect, 1)
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{4, 0, 4, 0}, colors,
		BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{0, 0, 4, 0}, colors,
		BoxBorderStyles{ bottom: .dashed }, radii, rect, 1)
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{0, 0, 4, 0},
		BoxColors{ bottom: css.Color{66, 112, 162, 128} }, BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{0, 0, 30, 0}, colors,
		BoxBorderStyles{}, radii, rect, 1)
	assert !append_chromium_single_rounded_border(mut commands, BoxEdges{0, 0, 4, 0}, colors,
		BoxBorderStyles{}, radii, painting.IntRect{0, 0, 30, 10}, 1)
	assert commands.len == 0
}

fn test_chromium_single_rounded_border_remains_visible_in_svg_export() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 } div { width:160px;height:30px;border-radius:3px;
		background:#4f86b5;border-bottom:2px solid #4270a2 }
	</style><div></div>')
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 320, 200)
	commands := root.paint_commands()
	assert commands.any(it.kind == 'paint_rounded_border_bottom')
	assert commands.any(it.kind == 'fill_rounded_rect' && !it.underlays_next)
	svg := root.render_svg(320, 200)
	assert svg.contains('fill="rgb(66 112 162)"')
	document.finalize()
}

fn test_chromium_single_opaque_side_insets_its_background_without_a_shared_layer() {
	for side in ['top', 'right', 'bottom', 'left'] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}div{position:absolute;left:20.71875px;top:134.5px;
			box-sizing:border-box;width:164.5625px;height:30px;border-radius:3px;
			background:#4f86b5;border-${side}:2px solid #4270a2}
		</style><div></div>')
		document.set_font_rendering_policy(.chromium)
		document.set_layout_coordinate_scale(2)
		// Scaled layout represents a matching 2x display in this raster test.
		document.set_display_device_pixel_ratio(2)
		root := layout_document_typed_in_viewport(document, 800, 600)
		commands := root.paint_commands()
		backgrounds := commands.filter(it.kind == 'fill_rounded_rect')
		assert backgrounds.len == 1
		background := backgrounds[0]
		assert !background.underlays_next
		assert [background.x, background.y, background.width, background.height] ==
			[if side == 'left' { 43.0 } else { 41.0 }, if side == 'top' { 271.0 } else { 269.0 },
				if side in ['left', 'right'] { 328.0 } else { 330.0 },
				if side in ['top', 'bottom'] { 58.0 } else { 60.0 }]
		assert background.corner_radii.top_left == CornerRadius{if side == 'left' {
			4.0
		} else {
			6.0
		}, if side == 'top' { 4.0 } else { 6.0 }}
		assert background.corner_radii.bottom_right == CornerRadius{if side == 'right' {
			4.0
		} else {
			6.0
		}, if side == 'bottom' { 4.0 } else { 6.0 }}
		assert commands.filter(it.kind == 'paint_rounded_border_${side}').len == 1
		document.finalize()
	}
}

fn test_chromium_single_border_background_pair_requires_matching_decoration_geometry() {
	radii := BoxRadii{CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}, CornerRadius{6, 6}}
	background := PaintCommand{
		kind:    'fill_rect'
		x:       10
		y:       20
		width:   100
		height:  40
		radius:  6
		color:   'rgb(79 134 181)'
		opacity: 1
	}
	border := PaintCommand{
		kind:         'paint_rounded_border_bottom'
		x:            10
		y:            20
		width:        100
		height:       40
		corner_radii: radii
		opacity:      1
	}
	mut paired := [background, border]
	chromium_pair_rounded_border_background(mut paired, 0, 1, 2, false)
	assert paired[0].underlays_next
	for incompatible in [PaintCommand{ ...background, x: 11 },
		PaintCommand{ ...background, radius: 5 }, PaintCommand{ ...background, opacity: 0.5 },
		PaintCommand{ ...background, kind: 'fill_gradient' }] {
		mut commands := [incompatible, border]
		chromium_pair_rounded_border_background(mut commands, 0, 1, 2, false)
		assert !commands[0].underlays_next
	}
	mut interrupted := [background, PaintCommand{ kind: 'draw_background_image' }, border]
	chromium_pair_rounded_border_background(mut interrupted, 0, 2, 3, false)
	assert !interrupted[0].underlays_next
}

fn test_chromium_transparent_adjacent_sides_keep_the_shared_background_layer() {
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}div{width:160px;height:30px;border-radius:3px;
		background:#4f86b5;border:1px solid transparent;border-bottom:2px solid #4270a2}
	</style><div></div>')
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands()
	backgrounds := commands.filter(it.kind == 'fill_rect' && it.underlays_next)
	borders := commands.filter(it.kind == 'paint_rounded_border_bottom')
	assert backgrounds.len == 1 && borders.len == 1
	background := backgrounds[0]
	border := borders[0]
	assert [background.x, background.y, background.width, background.height] ==
		[border.x, border.y, border.width, border.height]
	assert border.points == [2.0, 2.0, 4.0, 2.0]
	document.finalize()
}

fn test_uniform_rounded_border_keeps_its_background_in_the_same_native_pass() {
	mut document := html.parse_document('<!doctype html><style>
 html,body{margin:0}div{width:160px;height:16px;border:1px solid #373c3f;
 border-radius:2px;background:#373c3f}
 </style><div></div>')
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(2)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands()
	backgrounds := commands.filter(it.kind == 'fill_rect' && it.underlays_next)
	borders := commands.filter(it.kind == 'paint_uniform_border')
	assert backgrounds.len == 1 && borders.len == 1
	background := backgrounds[0]
	border := borders[0]
	assert [background.x, background.y, background.width, background.height] ==
		[border.x, border.y, border.width, border.height]
	assert background.radius == 3
	assert border.corner_radii.top_left == CornerRadius{3, 3}
	document.finalize()
}
