module css

import math

fn parsed_interpolation_test_color(text string) StyleValue {
	return parse_css_value_logic(.color, text) or { panic('${text} did not parse as a color') }
}

fn parsed_interpolation_test_color_mix(text string) ColorMixStyleValue {
	parsed := parsed_interpolation_test_color(text)
	if parsed is ColorMixStyleValue {
		return parsed
	}
	panic('${text} did not produce a color-mix value')
}

fn assert_interpolation_component_close(component StyleValue, expected f64) {
	assert component is NumberStyleValue
	assert math.abs(component.as_number().number() - expected) < 0.000001
}

fn test_legacy_colors_interpolate_in_srgb_and_keep_legacy_output() {
	interpolated := interpolate_style_values_color(parsed_interpolation_test_color('red'),
		parsed_interpolation_test_color('blue'), 0.5, none, ColorResolutionContext{}) or {
		panic('legacy colors did not interpolate')
	}
	assert interpolated is RGBColorStyleValue
	assert interpolated.serialize(.normal) == 'rgb(128, 0, 128)'
}

fn test_modern_colors_default_to_oklab_interpolation() {
	interpolated := interpolate_style_values_color(parsed_interpolation_test_color('oklab(1 0 0)'),
		parsed_interpolation_test_color('blue'), 0.5, none, ColorResolutionContext{}) or {
		panic('modern colors did not interpolate')
	}
	assert interpolated is OKLabColorStyleValue
}

fn test_style_value_interpolation_uses_component_preserving_colors() {
	interpolated := interpolate_style_value(InterpolationCalculationContext.for_property(.color),
		parsed_interpolation_test_color('oklab(1 0 0)'),
		parsed_interpolation_test_color('blue'), 0.5, .no) or {
		panic('style value colors did not interpolate')
	}
	assert interpolated is OKLabColorStyleValue
}

fn test_explicit_polar_interpolation_honors_the_hue_method() {
	from := parsed_interpolation_test_color('red')
	to := parsed_interpolation_test_color('blue')
	shorter_method := ColorInterpolationMethod(PolarColorInterpolationMethod{
		color_space: .hsl
		hue_interpolation_method: .shorter
	})
	longer_method := ColorInterpolationMethod(PolarColorInterpolationMethod{
		color_space: .hsl
		hue_interpolation_method: .longer
	})
	shorter := interpolate_style_values_color(from, to, 0.5, shorter_method,
		ColorResolutionContext{}) or { panic('shorter-hue colors did not interpolate') }
	longer := interpolate_style_values_color(from, to, 0.5, longer_method,
		ColorResolutionContext{}) or { panic('longer-hue colors did not interpolate') }
	shorter_color := shorter.to_color(ColorResolutionContext{}) or {
		panic('shorter-hue result did not resolve')
	}
	longer_color := longer.to_color(ColorResolutionContext{}) or {
		panic('longer-hue result did not resolve')
	}
	assert shorter_color.red() > 250
	assert shorter_color.green() < 5
	assert shorter_color.blue() > 250
	assert longer_color.red() < 5
	assert longer_color.green() > 250
	assert longer_color.blue() < 5
}

fn test_color_interpolation_substitutes_and_preserves_missing_components() {
	method := ColorInterpolationMethod(RectangularColorSpace.oklab)
	interpolated := interpolate_style_values_color(
		parsed_interpolation_test_color('oklab(none 0.2 0.1 / none)'),
		parsed_interpolation_test_color('oklab(0.8 none 0.3 / 0.5)'), 0.5, method,
		ColorResolutionContext{}) or { panic('colors with missing components did not interpolate') }
	assert interpolated is OKLabColorStyleValue
	oklab := interpolated as OKLabColorStyleValue
	assert_interpolation_component_close(oklab.l_.value, 0.8)
	assert_interpolation_component_close(oklab.a_.value, 0.2)
	assert_interpolation_component_close(oklab.b_.value, 0.2)
	assert_interpolation_component_close(oklab.alpha_.value, 0.5)

	both_missing := interpolate_style_values_color(
		parsed_interpolation_test_color('oklab(none 0.2 0.1)'),
		parsed_interpolation_test_color('oklab(none 0.4 0.3)'), 0.5, method,
		ColorResolutionContext{}) or { panic('colors with shared missing components did not interpolate') }
	assert both_missing is OKLabColorStyleValue
	assert style_value_is_none_keyword((both_missing as OKLabColorStyleValue).l_.value)
}

fn test_rectangular_color_interpolation_premultiplies_alpha() {
	method := ColorInterpolationMethod(RectangularColorSpace.srgb)
	interpolated := interpolate_style_values_color(
		parsed_interpolation_test_color('rgb(255 0 0 / 0.2)'),
		parsed_interpolation_test_color('rgb(0 0 255 / 0.8)'), 0.5, method,
		ColorResolutionContext{}) or { panic('alpha colors did not interpolate') }
	assert interpolated is ColorFunctionStyleValue
	color_function := interpolated as ColorFunctionStyleValue
	assert_interpolation_component_close(color_function.channels_[0], 0.2)
	assert_interpolation_component_close(color_function.channels_[1], 0)
	assert_interpolation_component_close(color_function.channels_[2], 0.8)
	assert_interpolation_component_close(color_function.alpha_.value, 0.5)
}

fn test_color_mix_uses_its_explicit_interpolation_space() {
	shorter := parsed_interpolation_test_color_mix('color-mix(in hsl shorter hue, red, blue)').to_color(ColorResolutionContext{}) or {
		panic('shorter-hue color-mix did not resolve')
	}
	longer := parsed_interpolation_test_color_mix('color-mix(in hsl longer hue, red, blue)').to_color(ColorResolutionContext{}) or {
		panic('longer-hue color-mix did not resolve')
	}
	assert shorter.red() > 250
	assert shorter.green() < 5
	assert shorter.blue() > 250
	assert longer.red() < 5
	assert longer.green() > 250
	assert longer.blue() < 5
}

fn test_transparent_endpoint_borrows_the_other_colors_components() {
	interpolated := parsed_interpolation_test_color_mix('color-mix(in oklab, red 10%, transparent)').absolutized(ComputationContext{})
	assert interpolated is OKLabColorStyleValue
	oklab := interpolated as OKLabColorStyleValue
	assert math.abs(oklab.l_.value.as_number().number() - 0.627956) < 0.00001
	assert math.abs(oklab.a_.value.as_number().number() - 0.224863) < 0.00001
	assert math.abs(oklab.b_.value.as_number().number() - 0.125846) < 0.00001
	assert_interpolation_component_close(oklab.alpha_.value, 0.1)
}

fn test_color_mix_without_an_explicit_method_defaults_to_oklab() {
	mix := parsed_interpolation_test_color_mix('color-mix(white, blue)')
	absolutized := mix.absolutized(ComputationContext{})
	assert absolutized is OKLabColorStyleValue
	color := mix.to_color(ColorResolutionContext{}) or {
		panic('default-method color-mix did not resolve')
	}
	assert color.red() == 116
	assert color.green() == 163
	assert color.blue() == 255
}

fn test_color_mix_applies_its_alpha_multiplier_before_color_conversion() {
	mix := parsed_interpolation_test_color_mix('color-mix(in oklab, red 12.5%, blue 37.5%)')
	absolutized := mix.absolutized(ComputationContext{})
	assert absolutized is OKLabColorStyleValue
	assert_interpolation_component_close((absolutized as OKLabColorStyleValue).alpha_.value, 0.5)
	color := mix.to_color(ColorResolutionContext{}) or {
		panic('alpha-multiplied color-mix did not resolve')
	}
	assert color.alpha() == 128
}
