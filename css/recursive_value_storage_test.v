module css

fn recursive_storage_nested_shape(percentage f64) StyleValue {
	leaf := StyleValue(PercentageStyleValue.create(Percentage.new(percentage)))
	fallback := StyleValue(FunctionStyleValue.create('inner', leaf))
	anchor := StyleValue(AnchorSizeStyleValue.create('--card', .width, fallback))
	shape := BasicShapeStyleValue.create(BasicShapeCircle{ radius: anchor })
	return StyleValue(FunctionStyleValue.create('outer', StyleValue(shape)))
}

fn test_recursive_style_values_preserve_nested_values_and_structural_equality() {
	first := recursive_storage_nested_shape(12)
	second := recursive_storage_nested_shape(12)
	assert first == second
	assert first.equals(second)
	assert first != recursive_storage_nested_shape(13)
	assert !first.equals(recursive_storage_nested_shape(13))
	assert first.serialize(.normal) == 'outer(circle(anchor-size(--card width, inner(12%))))'

	assert first is FunctionStyleValue
	shape_value := first.value()
	assert shape_value is BasicShapeStyleValue
	shape := shape_value.basic_shape()
	assert shape is BasicShapeCircle
	assert shape.radius is AnchorSizeStyleValue
	assert shape.radius.fallback_value()? is FunctionStyleValue
}

fn test_recursive_storage_keeps_parsed_css_values_equal() {
	cases := {
		PropertyID.color:                     [
			'rgb(1 2 3 / 0.5)',
			'hsl(30 40% 50% / 0.5)',
			'hwb(30 20% 10% / 0.5)',
			'lab(50% 10 20 / 0.5)',
			'lch(50% 10 20 / 0.5)',
			'oklab(50% 0.1 0.2 / 0.5)',
			'oklch(50% 0.1 20 / 0.5)',
			'color(srgb 0.1 0.2 0.3 / 0.5)',
			'color-mix(in oklab, rgb(1 2 3) 25%, blue)',
			'light-dark(rgb(1 2 3), rgb(4 5 6))',
		]
		PropertyID.background_image:          [
			'linear-gradient(30deg, red, blue)',
			'radial-gradient(circle at 20% 30%, red, blue)',
			'conic-gradient(from 30deg at 20% 30%, red, blue)',
		]
		PropertyID.background_position:       ['left 10px top 5%']
		PropertyID.background_size:           ['20% 30px']
		PropertyID.border_radius:             ['1px 2px 3px 4px / 5px 6px']
		PropertyID.border_image_slice:        ['10% fill']
		PropertyID.clip:                      ['rect(1px, auto, 3px, 4px)']
		PropertyID.clip_path:                 ['circle(10px at 20% 30%)']
		PropertyID.animation_timing_function: ['cubic-bezier(0.1, 0.2, 0.3, 0.4)', 'steps(3, start)']
		PropertyID.font_style:                ['oblique 12deg']
		PropertyID.grid_row_start:            ['span 2']
		PropertyID.aspect_ratio:              ['16 / 9']
		PropertyID.text_indent:               ['5% hanging']
		PropertyID.scrollbar_color:           ['red blue']
		PropertyID.box_shadow:                ['red 1px 2px 3px 4px']
	}
	for property, texts in cases {
		for text in texts {
			first := parse_css_value_logic(property, text) or { panic('could not parse ${text}') }
			second := parse_css_value_logic(property, text) or { panic('could not parse ${text}') }
			assert first == second, '${property}: ${text}'
			assert first.equals(second), '${property}: ${text}'
			assert first.serialize(.normal) == second.serialize(.normal)
		}
	}
}

fn test_recursive_cursor_storage_preserves_image_ownership_and_hotspots() {
	// Images retain resource identity; compare cursors with the same image owner.
	image := CursorImageValue.create(CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string('cursor.png')))
	first := StyleValue(CursorStyleValue.create(image, StyleValue(NumberStyleValue.create(2)),
		StyleValue(NumberStyleValue.create(3))))
	second := StyleValue(CursorStyleValue.create(image, StyleValue(NumberStyleValue.create(2)),
		StyleValue(NumberStyleValue.create(3))))
	assert first == second
	assert first.equals(second)
	assert first != StyleValue(CursorStyleValue.create(image, StyleValue(NumberStyleValue.create(4)),
		StyleValue(NumberStyleValue.create(3))))
	assert first.serialize(.normal) == 'url("cursor.png") 2 3'
	assert first is CursorStyleValue
	assert first.image().value is ImageStyleValue
	assert first.x()?.as_number().number() == 2
	assert first.y()?.as_number().number() == 3
}

fn test_recursive_numeric_storage_retains_nested_math_values() ! {
	unit := CSSNumberish(CSSUnitValue.create(2, 'px'))
	negated := CSSMathNegate.construct_impl(unit)
	inverted := CSSMathInvert.construct_impl(CSSNumberish(negated))
	value := CSSNumericValue(CSSMathClamp.construct_impl(CSSNumberish(inverted),
		CSSNumberish(inverted), CSSNumberish(inverted))!)
	same_negated := CSSMathNegate.construct_impl(unit)
	same_inverted := CSSMathInvert.construct_impl(CSSNumberish(same_negated))
	same := CSSNumericValue(CSSMathClamp.construct_impl(CSSNumberish(same_inverted),
		CSSNumberish(same_inverted), CSSNumberish(same_inverted))!)
	assert value == same
	assert value.is_equal_numeric_value(same)
	assert value is CSSMathClamp
	assert value.lower() is CSSMathInvert
	assert inverted.value() is CSSMathNegate
	assert negated.value() is CSSUnitValue
	assert !value.is_equal_numeric_value(CSSNumericValue(negated))
}

fn test_recursive_storage_preserves_default_construction() {
	assert RGBColorStyleValue{}.r() is KeywordStyleValue
	assert RatioStyleValue{}.numerator() is KeywordStyleValue
	assert BasicShapeStyleValue{}.basic_shape() is BasicShapeCircle
	assert LinearGradientStyleValue{}.direction_[0] == LinearGradientDirection(LinearGradientSideOrCorner.top)
	assert CSSMathNegate{}.value() is CSSUnitValue
	assert AnchorSizeStyleValue{}.fallback_value() == none
}
