module css

import dom
import math

fn test_borrowed_computed_colors_match_text_bridge_and_preserve_owners() {
	fallback := ComputedColor.rgba(7, 8, 9, 10)
	for text in ['rgb(17 34 51)', 'rgba(10.5, 20.25, 30.75, .25)',
		'rgb(10% 20% 30% / 25%)', 'rgb(calc(20 + 30) 0 255 / calc(50% / 2))',
		'hsl(120 100% 50% / .5)', 'hwb(240 0% 0%)', 'lab(50% 20 30)',
		'lch(50% 40 30)', 'oklab(0.5 0.1 0.1)', 'oklch(0.5 0.1 30)',
		'color(srgb 0.25 0.5 0.75)', 'color-mix(in srgb, red 25%, blue)',
		'light-dark(red, blue)', 'linktext', 'transparent'] {
		parsed := parse_css_value_logic(.color, text) or { panic(text) }
		serialized := parsed.serialize(.normal)
		owner := dom_style_value_from_value_logic(parsed)
		// The retained value is authoritative even when a bridge wrapper has
		// different text. This also checks that the borrowing path is exercised.
		wrapper := &dom.StyleValue{
			css_text: 'not a color'
			css_value_handle: owner.css_value_handle
		}
		mut typed := ComputedProperties.new()
		mut textual := ComputedProperties.new()
		typed.set_property(.color, wrapper, .no, .no)
		textual.set_property(.color, &dom.StyleValue{css_text: text}, .no, .no)
		gc_collect()
		for scheme in [PreferredColorScheme.light, .dark] {
			context := ColorResolutionContext{color_scheme: scheme}
			assert typed.color_or_fallback(.color, context, fallback) == textual.color_or_fallback(.color,
				context, fallback)
			assert typed.color_or_fallback(.color, context, fallback) != fallback
		}
		assert parsed.serialize(.normal) == serialized
		assert voidptr(typed.property(.color, .no)?) == voidptr(wrapper)
		assert owner.css_text == serialized
	}
}

fn test_borrowed_color_fallback_and_animated_precedence() {
	fallback := ComputedColor.rgba(7, 8, 9, 10)
	context := ColorResolutionContext{}
	mut style := ComputedProperties.new()
	assert style.color_or_fallback(.color, context, fallback) == fallback
	for value in [dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(1))),
		&dom.StyleValue{css_text: 'not a color'},
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))] {
		style.set_property(.color, value, .no, .no)
		assert style.color_or_fallback(.color, context, fallback) == fallback
	}
	red := parse_css_value(ParsingParams{}, 'red', .color)?
	blue := parse_css_value(ParsingParams{}, 'blue', .color)?
	style.set_property(.color, red, .no, .no)
	style.set_animated_property(.color, blue, .no, .no)
	assert style.color_or_fallback(.color, context, fallback) == ComputedColor.rgb(0, 0, 255)
	style.remove_animated_property(.color)
	assert style.color_or_fallback(.color, context, fallback) == ComputedColor.rgb(255, 0, 0)
}

fn test_borrowed_rgb_channels_keep_clamping_rounding_and_missing_values() {
	for channels, expected in {
		'rgba(-1, 255.5, 127.5, .5)': Color{0, 255, 128, 128}
		'rgb(100% 50% 0% / 25%)': Color{255, 128, 0, 64}
		'rgb(none none none / none)': Color{0, 0, 0, 0}
	} {
		value := parse_css_value_logic(.color, channels) or { panic(channels) }
		assert value.has_color()
		assert value.to_color(ColorResolutionContext{})? == expected
	}
	nonfinite := RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(math.nan())),
		StyleValue(NumberStyleValue.create(math.inf(1))),
		StyleValue(NumberStyleValue.create(math.inf(-1))),
		StyleValue(NumberStyleValue.create(math.nan())), .modern, none)
	assert nonfinite.to_color(ColorResolutionContext{})? == Color{0, 255, 0, 0}
}

fn test_borrowed_keyword_and_dimension_classification_keeps_tag_semantics() {
	for keyword in [Keyword.inherit, .initial, .revert, .revert_layer, .unset, .auto,
		.normal, .currentcolor] {
		value := StyleValue(KeywordStyleValue.create(keyword))
		assert value.type_() == .keyword
		assert value.is_keyword()
		assert value.to_keyword() == keyword
		assert value.is_css_wide_keyword() == (keyword in [.inherit, .initial, .revert,
			.revert_layer, .unset])
		assert value.has_auto() == (keyword == .auto)
		assert !value.is_dimension()
	}
	value := StyleValue(LengthStyleValue.create(Length.make_px(17)))
	assert value.type_() == .length
	assert value.is_dimension()
	assert !value.is_number()
	assert !value.has_color()
	assert !value.is_keyword()
	assert value.to_keyword() == .invalid
}
