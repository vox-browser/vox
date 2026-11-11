module css

import dom

fn media_memo_document(width f64) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, width, 600})
	return document
}

fn test_media_memo_skips_repeated_evaluation_in_the_same_environment() {
	mut document := media_memo_document(800)
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (min-width:600px) { .a {} }', none)
	mut media := sheet.rules.rules[0]
	assert !sheet.evaluate_media_queries(document)
	assert media.did_evaluate && media.condition_matches()
	// An unchanged environment and rule structure needs no second evaluation.
	media.did_evaluate = false
	assert !sheet.evaluate_media_queries(document)
	if disable_media_evaluation_memo {
		assert media.did_evaluate
	} else {
		assert !media.did_evaluate
	}
	media.did_evaluate = true
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.evaluate_media_queries(document)
	assert !media.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 300})
	assert !sheet.evaluate_media_queries(document)
	document.set_viewport_rect(dom.Rect{0, 0, 700, 300})
	assert sheet.evaluate_media_queries(document)
	assert media.condition_matches()
}

fn test_media_memo_follows_color_scheme_and_document_changes() {
	mut document := media_memo_document(800)
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (prefers-color-scheme:dark) { .a {} }', none)
	media := sheet.rules.rules[0]
	assert !sheet.evaluate_media_queries(document)
	assert !media.condition_matches()
	document.set_svg_image_color_scheme('dark')
	assert sheet.evaluate_media_queries(document)
	assert media.condition_matches()
	mut other := media_memo_document(800)
	defer { other.finalize() }
	assert sheet.evaluate_media_queries(other)
	assert !media.condition_matches()
}

fn test_media_memo_reevaluates_after_media_list_and_rule_edits() {
	mut document := media_memo_document(400)
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (min-width:600px) { .a {} }', none)
	assert !sheet.evaluate_media_queries(document)
	// Sheet media: a new entry starts without match state. The edit itself
	// invalidates the sheet's owners; evaluation must still fill in the state.
	mut sheet_media := unsafe { &MediaList(sheet.base.media) }
	sheet_media.append_medium('(max-width:500px)')
	assert !sheet_media.matches()
	sheet.evaluate_media_queries(document)
	assert sheet_media.matches()
	// Rule media changed through CSSOM.
	media := sheet.rules.rules[0]
	mut rule_media := media.media or { panic('rule media') }
	rule_media.set_media_text('(max-width:500px)')
	assert sheet.evaluate_media_queries(document)
	assert media.condition_matches()
	// An inserted rule is evaluated before style uses it.
	sheet.insert_rule('@media (max-width:450px) { .b {} }', 1)!
	inserted := sheet.rules.rules[1]
	assert !inserted.did_evaluate
	assert !sheet.evaluate_media_queries(document)
	assert inserted.did_evaluate && inserted.condition_matches()
}

fn test_media_memo_visits_imports_attached_after_evaluation() {
	mut document := media_memo_document(400)
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@import url(late.css); .plain {}', none)
	assert !sheet.evaluate_media_queries(document)
	mut imported := parse_css_stylesheet_with_parser('@media (max-width:600px) {}', none)
	mut import_rule := sheet.rules.rules[0]
	import_rule.set_style_sheet(imported)
	assert !sheet.evaluate_media_queries(document)
	media := imported.rules.rules[0]
	assert media.did_evaluate && media.condition_matches()
}
