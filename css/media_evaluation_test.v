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
