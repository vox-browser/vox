module layout

import css
import painting

fn test_chromium_dash_spacing_handles_short_thin_and_thick_open_lines() {
	assert chromium_border_dash_intervals(6, 1).len == 0
	assert chromium_border_dash_intervals(8, 1) == [f64(3), 2]
	assert chromium_border_dash_intervals(7, 1) == [f64(f32(2.625)), f64(f32(1.75))]
	assert chromium_border_dash_intervals(197, 1) == [f64(3), f64(f32(77) / 39)]
	assert chromium_border_dash_intervals(100, 4) == [f64(8), f64(3.5)]
}

fn test_single_dashed_sides_have_half_pixel_centerlines_and_stroke_payloads() {
	color := css.Color{34, 34, 34, 51}
	colors := BoxColors{color, color, color, color}
	for side in 0 .. 4 {
		border := match side { 0 { BoxEdges{top: 1} } 1 { BoxEdges{right: 1} } 2 { BoxEdges{bottom: 1} } else { BoxEdges{left: 1} } }
		styles := BoxBorderStyles{top: .dashed, right: .dashed, bottom: .dashed, left: .dashed}
		mut commands := []PaintCommand{}
		assert append_chromium_dashed_border(mut commands, border, colors, styles, BoxRadii{}, painting.IntRect{812, 343, 197, 73}, 1)
		assert commands.len == 1
		command := commands[0]
		assert command.color == '' && command.stroke_color == color.serialize()
		assert command.stroke_width == 1
		data := command.svg()
		assert data.path_data.len == 24
		assert data.path_data[0] == 0 && data.path_data[12] == 1
		if side in [0, 2] {
			assert data.path_data[2] == if side == 0 { f32(343.5) } else { f32(415.5) }
			assert data.stroke_dasharray == chromium_border_dash_intervals(197, 1)
		} else {
			assert data.path_data[1] == if side == 1 { f32(1008.5) } else { f32(812.5) }
		}
	}
}

fn test_dashed_border_keeps_rounded_joined_and_fractional_sides_on_existing_paths() {
	mut commands := []PaintCommand{}
	color := css.Color{1, 2, 3, 255}
	colors := BoxColors{color, color, color, color}
	styles := BoxBorderStyles{top: .dashed, right: .dashed}
	for border in [BoxEdges{top: 1, right: 1}, BoxEdges{top: 1.5}, BoxEdges{}] {
		assert !append_chromium_dashed_border(mut commands, border, colors, styles, BoxRadii{}, painting.IntRect{0, 0, 100, 50}, 1)
	}
	assert !append_chromium_dashed_border(mut commands, BoxEdges{top: 1}, colors, styles,
		BoxRadii{top_left: CornerRadius{2, 2}}, painting.IntRect{0, 0, 100, 50}, 1)
	assert commands.len == 0
}
