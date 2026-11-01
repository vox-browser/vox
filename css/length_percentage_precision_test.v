module css

import dom

fn test_length_percentage_retains_precision_before_fixed_point_conversion() {
	reference := CSSPixels.new(4_753_650)
	resolved := LengthPercentage.from_percentage(Percentage.new(100)).to_px(LengthResolutionContext.default(),
		reference)
	assert resolved == reference
}

fn test_calculated_length_percentage_used_values_truncate() {
	parsed := parse_css_value_logic(.flex_basis, 'calc((100% - 32px) / 3)') or {
		panic('calculated flex basis did not parse')
	}
	assert parsed is CalculatedStyleValue
	length_percentage := LengthPercentage.from_style_value_logic(parsed)
	context := LengthResolutionContext.default()

	for width, expected_raw in {
		100: 1450
		101: 1472
		102: 1493
	} {
		used := length_percentage.to_px(context, CSSPixels.new(width))
		assert used.raw_value() == expected_raw
		assert used.times(CSSPixels.new(3)).plus(CSSPixels.new(32)).compare(CSSPixels.new(width)) <= 0
	}
}

fn test_size_uses_length_percentage_truncation() {
	calculated := parse_css_value_logic(.width, 'calc(2%)') or {
		panic('calculated width did not parse')
	}
	size := Size.make_calculated(calculated as CalculatedStyleValue)
	assert size.to_px(LengthResolutionContext.default(), CSSPixels.new(784)).raw_value() == 1003
}

fn test_chromium_calculated_lengths_convert_to_float_before_layout_units() {
	parsed := parse_css_value_logic(.flex_basis, 'calc((100% - 32px) / 3)') or { panic('calculated basis') }
	length := LengthPercentage.from_style_value_logic(parsed)
	context := LengthResolutionContext{ ...LengthResolutionContext.default(), use_chromium_geometry: true }
	for width, expected in {
		100:  1450
		101:  1472
		102:  1493
		1184: 24576
	} {
		assert length.to_px(context, CSSPixels.new(width)).raw_value() == expected
	}
	assert length.to_px(LengthResolutionContext.default(), CSSPixels.new(1184)).raw_value() == 24575
}

fn test_default_calculated_length_precision_survives_large_percentage_bases() {
	parsed := parse_css_value_logic(.width, 'calc(100% + .015625px)') or { panic('calculated width') }
	length := LengthPercentage.from_style_value_logic(parsed)
	basis := CSSPixels.new(4_753_650)
	context := LengthResolutionContext.default()
	assert length.to_px(context, basis).raw_value() == basis.raw_value() + 1
	chromium := LengthResolutionContext{ ...context, use_chromium_geometry: true }
	assert length.to_px(chromium, basis) == basis
}

fn test_document_length_context_carries_its_geometry_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	assert !LengthResolutionContext.for_document(document).use_chromium_geometry
	document.set_font_rendering_policy(.chromium)
	assert LengthResolutionContext.for_document(document).use_chromium_geometry
	document.set_font_rendering_policy(.libweb)
	assert !LengthResolutionContext.for_document(document).use_chromium_geometry
}
