module css

import dom

fn test_first_media_rule_evaluation_establishes_a_baseline() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('@media (min-width: 600px) { div { color: red } }') or { panic(err) }
	media_rule := sheet.rules.item(0) or { panic('missing @media rule') }
	assert !media_rule.did_evaluate

	assert !sheet.rules.evaluate_media_queries(document)
	assert media_rule.did_evaluate
	document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !sheet.rules.evaluate_media_queries(document)
}

fn test_prefers_color_scheme_uses_an_svg_image_document_override() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_svg_image_color_scheme('dark')
	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('@media (prefers-color-scheme: dark) { path { fill: red } }') or {
		panic(err)
	}
	media_rule := sheet.rules.item(0) or { panic('missing @media rule') }

	sheet.rules.evaluate_media_queries(document)
	assert media_rule.condition_matches()
	document.set_svg_image_color_scheme('light')
	assert sheet.rules.evaluate_media_queries(document)
	assert !media_rule.condition_matches()
}

fn test_media_numeric_environment_values_keep_fractional_units_and_query_serialization() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 800.5, 400.25})
	for name, expected in {'width': 800.5, 'height': 400.25, 'aspect-ratio': 2.0,
		'resolution': 1.0, 'color': 8.0} {
		value := query_media_feature(name, document) or { panic('missing ${name}') }
		assert media_feature_numeric_value(value, document)? == expected
	}
	for text in ['(width > 800px)', '(height = 400.25px)', '(aspect-ratio = 2 / 1)',
		'(resolution = 96dpi)', '(color = 8)'] {
		query := parse_media_query(ParsingParams{}, text) or { panic('invalid ${text}') }
		serialized := query.to_string()
		assert query.evaluate(document), text
		reparsed := parse_media_query(ParsingParams{}, serialized) or { panic('invalid serialization') }
		assert reparsed.evaluate(document), serialized
	}
	query := parse_media_query(ParsingParams{}, '(width > 801px)') or { panic('invalid query') }
	assert !query.evaluate(document)
}
