module css

struct GradientSkiaFixture {
	method RectangularColorSpace
	color  Color
}

fn color_channels_are_close(actual Color, expected Color, tolerance int) bool {
	channel_close := fn [tolerance] (actual u8, expected u8) bool {
		difference := int(actual) - int(expected)
		return difference >= -tolerance && difference <= tolerance
	}
	return channel_close(actual.r, expected.r) && channel_close(actual.g, expected.g)
		&& channel_close(actual.b, expected.b) && channel_close(actual.a, expected.a)
}

fn gradient_test_single_image(value StyleValue) StyleValue {
	if list := value.as_value_list() {
		return list.value_at(0, false)
	}
	return value
}

fn test_gradient_color_interpolation_matches_skia_spaces_and_premultiplication() {
	red := Color{255, 0, 0, 255}
	blue := Color{0, 0, 255, 255}
	transparent_blue := Color{0, 0, 255, 0}

	srgb := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(RectangularColorSpace.srgb))
	assert srgb == Color{128, 0, 128, 255}

	linear := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(RectangularColorSpace.srgb_linear))
	assert color_channels_are_close(linear, Color{188, 0, 188, 255}, 1)

	oklab := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(RectangularColorSpace.oklab))
	assert color_channels_are_close(oklab, Color{140, 83, 162, 255}, 1)

	// One-pixel midpoint results from the SkGradientShader configuration used
	// by the current upstream DisplayListPlayerSkia.
	for fixture in [
		GradientSkiaFixture{.lab, Color{193, 0, 136, 255}},
		GradientSkiaFixture{.display_p3, Color{128, 10, 145, 255}},
		GradientSkiaFixture{.a98_rgb, Color{128, 0, 128, 255}},
		GradientSkiaFixture{.prophoto_rgb, Color{186, 3, 157, 255}},
		GradientSkiaFixture{.rec2020, Color{162, 19, 147, 255}},
	] {
		actual := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(fixture.method))
		assert color_channels_are_close(actual, fixture.color, 1)
	}

	shorter_hsl := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(PolarColorInterpolationMethod{
		color_space: .hsl
		hue_interpolation_method: .shorter
	}))
	assert shorter_hsl == Color{255, 0, 255, 255}
	longer_hsl := interpolate_gradient_color(red, blue, 0.5, ColorInterpolationMethod(PolarColorInterpolationMethod{
		color_space: .hsl
		hue_interpolation_method: .longer
	}))
	assert longer_hsl == Color{0, 255, 0, 255}

	premultiplied := interpolate_gradient_color(red, transparent_blue, 0.5, ColorInterpolationMethod(RectangularColorSpace.srgb))
	assert premultiplied == Color{255, 0, 0, 128}

	// Skia treats the hue of an achromatic polar-space endpoint as powerless
	// and borrows the adjacent stop's hue instead of routing through 0deg.
	white := Color{255, 255, 255, 255}
	hsl_blue_to_white := interpolate_gradient_color(blue, white, 0.5, ColorInterpolationMethod(PolarColorInterpolationMethod{
		color_space: .hsl
		hue_interpolation_method: .shorter
	}))
	assert color_channels_are_close(hsl_blue_to_white, Color{159, 159, 223, 255}, 1)
}

fn test_gradient_rectangular_color_spaces_round_trip_srgb_endpoints() {
	first := Color{17, 123, 241, 91}
	second := Color{231, 77, 29, 203}
	methods := [
		ColorInterpolationMethod(RectangularColorSpace.srgb),
		ColorInterpolationMethod(RectangularColorSpace.srgb_linear),
		ColorInterpolationMethod(RectangularColorSpace.display_p3),
		ColorInterpolationMethod(RectangularColorSpace.a98_rgb),
		ColorInterpolationMethod(RectangularColorSpace.prophoto_rgb),
		ColorInterpolationMethod(RectangularColorSpace.rec2020),
		ColorInterpolationMethod(RectangularColorSpace.lab),
		ColorInterpolationMethod(RectangularColorSpace.oklab),
	]
	for method in methods {
		assert color_channels_are_close(interpolate_gradient_color(first, second, 0, method), first, 2)
		assert color_channels_are_close(interpolate_gradient_color(first, second, 1, method), second, 2)
	}

	// These are the explicit OKLab fallbacks in DisplayListPlayerSkia.
	oklab := interpolate_gradient_color(first, second, 0.5, ColorInterpolationMethod(RectangularColorSpace.oklab))
	for fallback in [RectangularColorSpace.display_p3_linear, .xyz_d50, .xyz_d65] {
		assert interpolate_gradient_color(first, second, 0.5, ColorInterpolationMethod(fallback)) == oklab
	}
}

fn test_gradient_parsers_retain_interpolation_methods_and_upstream_stop_shapes() {
	linear_value := parse_css_value_logic(.background_image, 'linear-gradient(30deg in srgb-linear, red 10% 20%, 35%, blue)') or {
		panic('linear interpolation method did not parse')
	}
	linear := gradient_test_single_image(linear_value).as_linear_gradient() or {
		panic('not a linear gradient')
	}
	assert linear.interpolation_method() == ColorInterpolationMethod(RectangularColorSpace.srgb_linear)
	assert linear.color_stop_list_.len == 2
	assert linear.color_stop_list_[0].color_stop.second_position != none
	assert linear.color_stop_list_[1].transition_hint != none
	assert linear.color_stop_list_[1].color_stop.color.to_color(ColorResolutionContext{}) or {
		Color{}
	} == Color{0, 0, 255, 255}

	position_first := parse_css_value_logic(.background_image, 'linear-gradient(20% red, blue)') or { panic('position-first stop did not parse') }
	position_first_gradient := gradient_test_single_image(position_first).as_linear_gradient() or {
		panic('not a gradient')
	}
	assert position_first_gradient.color_stop_list_[0].color_stop.position != none

	radial_value := parse_css_value_logic(.background_image, 'radial-gradient(in hsl longer hue circle at 25% 75%, red, blue)') or {
		panic('radial interpolation method did not parse')
	}
	radial := gradient_test_single_image(radial_value).as_radial_gradient() or {
		panic('not a radial gradient')
	}
	radial_method := radial.interpolation_method()
	assert radial_method is PolarColorInterpolationMethod
	assert (radial_method as PolarColorInterpolationMethod).color_space == .hsl
	assert (radial_method as PolarColorInterpolationMethod).hue_interpolation_method == .longer

	conic_value := parse_css_value_logic(.background_image, 'conic-gradient(in oklch decreasing hue from 0 at 20% 30%, red, blue)') or {
		panic('conic interpolation method did not parse')
	}
	conic := gradient_test_single_image(conic_value).as_conic_gradient() or {
		panic('not a conic gradient')
	}
	conic_method := conic.interpolation_method()
	assert conic_method is PolarColorInterpolationMethod
	assert (conic_method as PolarColorInterpolationMethod).color_space == .oklch
	assert (conic_method as PolarColorInterpolationMethod).hue_interpolation_method == .decreasing
	assert parse_css_value_logic(.background_image, 'conic-gradient(red 0, blue 1turn)') != none
}

fn test_modern_gradient_colors_default_to_oklab_like_cpp_style_values() {
	modern_value := parse_css_value_logic(.background_image, 'linear-gradient(color(srgb 1 0 0), blue)') or { panic('modern gradient did not parse') }
	modern := gradient_test_single_image(modern_value).as_linear_gradient() or {
		panic('not a linear gradient')
	}
	assert modern.color_syntax_ == .modern
	assert modern.interpolation_method() == ColorInterpolationMethod(RectangularColorSpace.oklab)

	legacy_value := parse_css_value_logic(.background_image, 'linear-gradient(red, blue)') or {
		panic('legacy gradient did not parse')
	}
	legacy := gradient_test_single_image(legacy_value).as_linear_gradient() or {
		panic('not a linear gradient')
	}
	assert legacy.color_syntax_ == .legacy
	assert legacy.interpolation_method() == ColorInterpolationMethod(RectangularColorSpace.srgb)
}
