module css

import dom
import platform

fn media_candidate_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	return document
}

fn test_media_candidates_filter_only_branches_without_media_effects() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('.plain {color:red}
		.outer { .inner { color:blue } }
		@layer empty { .child {} } @media (min-width:600px) {}', none)
	candidates := sheet.rules.media_evaluation_candidates()
	if !disable_media_rule_candidates {
		assert candidates.len == 1
		assert voidptr(candidates[0]) == voidptr(sheet.rules.rules[3])
		assert sheet.rules.media_evaluation_generation_ != 0
	}
	assert !sheet.rules.evaluate_media_queries(document)
	media := sheet.rules.rules[3]
	assert media.did_evaluate && media.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !media.condition_matches()
	assert !sheet.rules.evaluate_media_queries(document)
}

fn test_media_candidates_invalidate_detached_shared_ancestors_after_nested_edits() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut group := CSSRule.create_grouping(.layer_block, CSSRuleList.create_empty())
	mut first := CSSRuleList.create([group])
	mut second := CSSRuleList.create([group])
	assert !first.evaluate_media_queries(document)
	assert !second.evaluate_media_queries(document)
	mut children := group.css_rules() or { panic('children') }
	children.insert_a_css_rule_from_text('@media (min-width:600px) {}', 0, .yes, map[string]bool{})!
	media := children.item(0) or { panic('media') }
	assert !first.evaluate_media_queries(document)
	assert media.did_evaluate && media.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert second.evaluate_media_queries(document)
	assert !media.condition_matches()
	children.remove_a_css_rule(0)!
	assert !first.evaluate_media_queries(document)
	assert !second.evaluate_media_queries(document)
	if !disable_media_rule_candidates {
		assert first.media_evaluation_candidates().len == 0
		assert second.media_evaluation_candidates().len == 0
	}
}

fn test_media_candidates_same_length_replacement_discards_removed_rules() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (min-width:600px) {}', none)
	old := sheet.rules.rules[0]
	assert !sheet.rules.evaluate_media_queries(document)
	replacement := CSSRule.create_media(MediaList.create_empty(), CSSRuleList.create_empty())
	sheet.rules.set_rules([replacement])
	assert !replacement.did_evaluate
	assert !sheet.rules.evaluate_media_queries(document)
	assert replacement.did_evaluate && replacement.condition_matches()
	assert voidptr(sheet.rules.media_evaluation_candidates()[0]) == voidptr(replacement)
	sheet.rules.set_rules([CSSRule.create(.style)])
	assert !sheet.rules.evaluate_media_queries(document)
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert !sheet.rules.evaluate_media_queries(document)
	assert old.condition_matches() && replacement.condition_matches()
	if !disable_media_rule_candidates { assert sheet.rules.media_evaluation_candidates_.len == 0 }
}

fn test_media_candidates_keep_inactive_ancestors_and_live_condition_changes() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@media (max-width:600px) {
		.layer { @media (min-width:300px) {} }
	} @supports (display:not-a-display) { @media all {} }', none)
	outer := sheet.rules.rules[0]
	style := (outer.rules or { panic('outer children') }).rules[0]
	inner := (style.rules or { panic('inner children') }).rules[0]
	inactive := ((sheet.rules.rules[1].rules or { panic('supports') }).rules[0])
	assert !sheet.rules.evaluate_media_queries(document)
	assert outer.did_evaluate && !inner.did_evaluate && !inactive.did_evaluate
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert inner.did_evaluate && inner.condition_matches()
	mut media := outer.media or { panic('media') }
	media.set_media_text('(max-width:200px)')
	assert !sheet.rules.evaluate_media_queries(document)
	assert !outer.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 100, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !inner.condition_matches() && !inactive.did_evaluate
}

fn test_media_candidates_keep_imports_before_the_sheet_arrives() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@import url(late.css); .plain {}', none)
	assert !sheet.rules.evaluate_media_queries(document)
	mut imported := parse_css_stylesheet_with_parser('@media (min-width:600px) {}', none)
	mut import_rule := sheet.rules.rules[0]
	import_rule.set_style_sheet(imported)
	assert !sheet.rules.evaluate_media_queries(document)
	media := imported.rules.rules[0]
	assert media.did_evaluate && media.condition_matches()
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !media.condition_matches()
}

fn test_media_candidates_preserve_ignored_grouping_rule_types() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	for type_ in [CSSRuleType.page, .keyframes, .margin] {
		media := CSSRule.create_media(MediaList.create_empty(), CSSRuleList.create_empty())
		ignored := CSSRule.create_grouping(type_, CSSRuleList.create([media]))
		mut list := CSSRuleList.create([ignored])
		assert !list.evaluate_media_queries(document)
		assert !media.did_evaluate
	}
}

__global media_candidate_callback_list &CSSRuleList = unsafe { nil }
__global media_candidate_callback_observed bool

fn media_candidate_changed() {
	assert media_candidate_callback_list.media_evaluation_candidates().len == 1
	media_candidate_callback_observed = true
}

fn test_media_candidates_invalidate_before_change_callbacks() {
	mut list := CSSRuleList.create_empty()
	assert list.media_evaluation_candidates().len == 0
	media_candidate_callback_list = list
	media_candidate_callback_observed = false
	list.on_change = media_candidate_changed
	list.insert_a_css_rule(CSSRule.create_media(MediaList.create_empty(), CSSRuleList.create_empty()), 0, .no, map[string]bool{})!
	assert media_candidate_callback_observed
	media_candidate_callback_list = unsafe { nil }
}

fn test_media_candidate_storage_survives_scratch_and_document_retirement() {
	$if prealloc {
		mut shared := parse_css_stylesheet_with_parser('@layer outer {@media all {}}', none)
		shared.process_lifetime = true
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		mut author := parse_css_stylesheet_with_parser('@layer author {@media all {}}', none)
		scratch := platform.begin_thread_scratch('media candidate publication test')
		assert shared.rules.media_evaluation_candidates().len == 1
		assert author.rules.media_evaluation_candidates().len == 1
		scratch.finish()
		assert !document.native_storage().arena.contains(shared.rules.media_evaluation_candidates_.data)
		if !disable_media_rule_candidates {
			assert document.native_storage().arena.contains(author.rules.media_evaluation_candidates_.data)
		}
		author_expected := if disable_media_rule_candidates || retain_media_group_recursion {
			author.rules.rules[0]
		} else { (author.rules.rules[0].rules or { panic('author layer') }).rules[0] }
		assert voidptr(author.rules.media_evaluation_candidates()[0]) == voidptr(author_expected)
		owner.finish()
		document.release_native_storage()
		shared_expected := if disable_media_rule_candidates || retain_media_group_recursion {
			shared.rules.rules[0]
		} else { (shared.rules.rules[0].rules or { panic('shared layer') }).rules[0] }
		assert voidptr(shared.rules.media_evaluation_candidates()[0]) == voidptr(shared_expected)
		mut child := shared.rules.rules[0].rules or { panic('shared layer') }
		assert child.media_evaluation_candidates().len == 1
		assert child.media_evaluation_candidates()[0].type_ == .media
	}
}
