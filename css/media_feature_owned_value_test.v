module css

import dom

fn test_media_feature_retains_its_own_value_after_the_callers_union_changes() {
	mut source := StyleValue(LengthStyleValue.create(Length.make_px(12)))
	retained := media_feature_value_from_style_value('width', source)
	source = StyleValue(LengthStyleValue.create(Length.make_px(99)))
	assert source.serialize(.normal) == '99px'
	assert retained.text == '12px'
	assert query_feature_numeric_value(retained, LengthResolutionContext.default())? == 12
	for index in 1 .. 64 {
		other := media_feature_value_from_style_value('width',
			StyleValue(LengthStyleValue.create(Length.make_px(f64(index)))))
		assert query_feature_numeric_value(other, LengthResolutionContext.default())? == index
		assert query_feature_numeric_value(retained, LengthResolutionContext.default())? == 12
	}
}

fn test_parsed_media_values_survive_parser_churn_and_environment_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 800, 400})
	document.set_display_device_pixel_ratio(2)
	document.set_svg_image_color_scheme('dark')
	texts := ['(width >= 48rem)', '(height = calc(25rem))', '(aspect-ratio = 2 / 1)',
		'(resolution = 192dpi)', '(color = 8)', '(prefers-color-scheme: dark)']
	mut queries := []&MediaQuery{}
	for text in texts {
		queries << parse_media_query_from_text(text)?
	}
	for index in 0 .. 32 {
		other := parse_media_query_from_text('(width >= ${index}px)')?
		assert other.evaluate(document)
	}
	for query in queries {
		assert query.evaluate(document), query.to_string()
		assert parse_media_query_from_text(query.to_string())?.evaluate(document)
	}
	document.set_viewport_rect(dom.Rect{0, 0, 300, 300})
	document.set_display_device_pixel_ratio(1)
	document.set_svg_image_color_scheme('light')
	for index, query in queries {
		assert query.evaluate(document) == (index == 4), query.to_string()
	}
}
