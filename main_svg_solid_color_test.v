module main

import css
import gg

fn test_retained_svg_replay_matches_serialized_colors_at_every_alpha_byte() {
	for alpha in 0 .. 256 {
		color := css.Color{12, 34, 56, u8(alpha)}
		serialized := color.serialize()
		for opacity in [f64(-1), 0, 0.003, 0.1, 0.5, 0.999, 1, 2] {
			assert paint_color_with_retained(serialized, opacity, color) == paint_color(serialized,
				opacity)
		}
	}
}

fn test_svg_replay_without_retained_color_preserves_parser_and_invalid_fallback() {
	for serialized in ['rgb(12 34 56 / .5)', '#abc', 'transparent', 'rebeccapurple', '', 'not-a-color',
		'none'] {
		for opacity in [f64(0), 0.5, 1, 2] {
			assert paint_color_with_retained(serialized, opacity, none) == paint_color(serialized,
				opacity)
		}
	}
	for invalid in ['', 'not-a-color', 'none'] {
		assert paint_color_with_retained(invalid, 0, none) == gg.rgba(15, 23, 42, 255)
	}
}
