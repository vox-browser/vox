module css

import dom

fn empty_media_list_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	return document
}

fn test_empty_media_group_still_evaluates_its_own_condition_and_transitions() {
	mut document := empty_media_list_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (min-width:600px) {}', none)
	rule := sheet.rules.item(0) or { panic('media') }
	assert !rule.did_evaluate
	assert !sheet.rules.evaluate_media_queries(document)
	assert rule.did_evaluate && rule.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !rule.condition_matches()
	assert !sheet.rules.evaluate_media_queries(document)
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert rule.condition_matches()
}

fn test_empty_style_children_receive_later_insertions_and_removals() {
	mut document := empty_media_list_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('.outer {}', none)
	mut outer := sheet.rules.item(0) or { panic('style') }
	children := outer.css_rules() or { panic('style children') }
	assert children.length() == 0
	assert children.should_evaluate_nested_media_queries() == retain_empty_media_query_recursion
	assert !sheet.rules.evaluate_media_queries(document)
	outer.insert_rule('@media (min-width:600px) {}', 0)!
	assert children.should_evaluate_nested_media_queries()
	rule := children.item(0) or { panic('inserted media') }
	assert !rule.did_evaluate
	assert !sheet.rules.evaluate_media_queries(document)
	assert rule.did_evaluate && rule.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !rule.condition_matches()
	outer.delete_rule(0)!
	assert children.length() == 0
	assert !sheet.rules.evaluate_media_queries(document)
	outer.insert_rule('@media (min-width:600px) {}', 0)!
	replacement := children.item(0) or { panic('replacement media') }
	assert !sheet.rules.evaluate_media_queries(document)
	assert replacement.did_evaluate && !replacement.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert replacement.condition_matches()
}

fn test_inactive_supports_preserves_delayed_child_media_baselines() {
	mut document := empty_media_list_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@supports (display:not-a-display) {@media all {}}
		@supports (display:block) {@media all {}} @layer demo {} @scope (.scope) {}', none)
	inactive := sheet.rules.item(0) or { panic('inactive supports') }
	active := sheet.rules.item(1) or { panic('active supports') }
	inactive_media := (inactive.css_rules() or { panic('inactive children') }).item(0) or { panic('inactive media') }
	active_media := (active.css_rules() or { panic('active children') }).item(0) or { panic('active media') }
	assert !sheet.rules.evaluate_media_queries(document)
	assert !inactive_media.did_evaluate
	assert active_media.did_evaluate && active_media.condition_matches()
	assert !sheet.rules.evaluate_media_queries(document)
}

fn test_imported_empty_sheet_still_updates_its_media_match_state() {
	mut document := empty_media_list_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@import url(empty.css);', none)
	mut imported := parse_css_stylesheet_with_parser('', none)
	mut media := unsafe { &MediaList(imported.base.media) }
	media.set_media_text('(min-width:600px)')
	mut rule := sheet.rules.item(0) or { panic('import') }
	rule.set_style_sheet(imported)
	assert imported.did_match == none
	assert !sheet.rules.evaluate_media_queries(document)
	assert imported.did_match or { false }
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !(imported.did_match or { true })
	assert !sheet.rules.evaluate_media_queries(document)
}
