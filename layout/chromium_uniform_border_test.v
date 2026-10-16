module layout

import css
import painting

fn test_chromium_uniform_border_keeps_analytic_rounded_geometry() {
	color := css.Color{255, 136, 0, 255}
	colors := BoxColors{color, color, color, color}
	radii :=
		BoxRadii{CornerRadius{3, 3}, CornerRadius{3, 3}, CornerRadius{0, 0}, CornerRadius{0, 0}}
	mut commands := []PaintCommand{}
	append_translated_border_commands(mut commands, BoxEdges{1, 1, 1, 1}, colors, BoxBorderStyles{},
		radii, 30, 90.796875, 300, 29, 1, true)
	assert commands.len == 1
	command := commands[0]
	assert command.kind == 'paint_uniform_border'
	assert command.x == 30.5 && command.y == 91.5
	assert command.width == 299 && command.height == 28
	assert command.corner_radii.top_left == CornerRadius{2.5, 2.5}
	assert command.corner_radii.bottom_left == CornerRadius{}
	assert command.stroke_width == 1
	assert command.force_dark_role == .border
	for chromium in [false, true] {
		mut fallback := []PaintCommand{}
		append_translated_border_commands(mut fallback, BoxEdges{1, 1, 1, if chromium {
			2.0
		} else {
			1.0
		}}, colors, BoxBorderStyles{}, radii, 30, 20, 300, 29, 1, chromium)
		assert fallback.all(it.kind != 'paint_uniform_border')
	}
	mut fallback := []PaintCommand{}
	assert !append_chromium_uniform_border(mut fallback, BoxEdges{1, 1, 1, 1}, colors, BoxBorderStyles{
		top: painting.LineStyle.dashed
	}, radii, painting.IntRect{0, 0, 30, 30}, 1)
}

fn test_chromium_opaque_rounded_background_avoids_border_bleeding() {
	color := css.Color{255, 136, 0, 255}
	colors := BoxColors{color, color, color, color}
	radii :=
		BoxRadii{CornerRadius{3, 3}, CornerRadius{3, 3}, CornerRadius{3, 3}, CornerRadius{3, 3}}
	rect := LayoutRect{30, 91, 300, 29}
	shrunk, inner := chromium_background_under_opaque_border(rect, radii, BoxEdges{1, 1, 1, 1},
		colors, BoxBorderStyles{})
	assert shrunk == LayoutRect{30.5, 91.5, 299, 28}
	assert inner.top_left == CornerRadius{2.5, 2.5}
	fallback, original := chromium_background_under_opaque_border(rect, radii, BoxEdges{1, 1, 1, 1}, BoxColors{
		top: css.Color{255, 136, 0, 128}
	}, BoxBorderStyles{})
	assert fallback == rect && original == radii
}
