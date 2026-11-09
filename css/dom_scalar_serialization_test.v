module css

import math
import platform

fn test_dom_color_formatting_matches_every_alpha_and_channel_digit_width() {
	mut retained := []string{}
	mut expected := []string{}
	for alpha in 0 .. 256 {
		for channel in [u8(0), 1, 9, 10, 99, 100, 254, 255] {
			color := Color.rgba(channel, 255 - channel, u8((u32(channel) * 13) % 256), u8(alpha))
			actual := serialize_dom_color(color)
			ordinary := color.serialize()
			assert actual == ordinary
			retained << actual
			expected << ordinary
		}
	}
	mut reuse := platform.begin_thread_scratch('reuse scalar formatting stack')
	_ = []u8{len: 64 * 1024, init: 0xa5}
	reuse.finish()
	gc_collect()
	assert retained == expected
}

fn test_dom_exact_integer_formats_numbers_percentages_and_limits() {
	for raw in [-2147483648.0, -1000.0, -1.0, -0.0, 0.0, 1.0, 400.0, 2147483647.0] {
		for suffix in ['', '%'] {
			assert serialize_dom_exact_integer(raw, suffix)? == serialize_a_number(raw) + suffix
		}
	}
	for raw in [-2147483649.0, 2147483648.0, .125, math.inf(1), math.inf(-1), math.nan()] {
		assert serialize_dom_exact_integer(raw, '') == none
	}
	for value in [StyleValue(NumberStyleValue.create(400)),
		StyleValue(IntegerStyleValue.create(-123)),
		StyleValue(PercentageStyleValue.create(Percentage.new(100))),
		StyleValue(ColorStyleValue.create(Color.rgba(12, 34, 56, 128)))] {
		wrapped := dom_style_value_from_value_logic(value)
		assert wrapped.css_text == value.serialize(.normal)
		assert typed_style_value_logic_from_dom(wrapped)?.equals(value)
	}
}

fn test_dom_color_text_preserves_modern_syntax_and_full_alpha_precision() {
	color := Color.rgba(12, 34, 56, 128)
	wrapped := dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create(color)))
	assert wrapped.css_text == 'rgb(12 34 56 / 0.501961)'
	parsed := parse_css_value_logic(.color, wrapped.css_text) or { panic('color roundtrip') }
	assert parsed.to_color(ColorResolutionContext{})? == color
	assert serialize_dom_color(Color.rgba(12, 34, 56, 0)) == 'rgb(12 34 56 / 0)'
	assert serialize_dom_color(Color.rgb(12, 34, 56)) == 'rgb(12 34 56)'
}
