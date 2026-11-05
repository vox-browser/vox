module css

import dom
import platform

fn media_group_leaf(text string) &CSSRule {
	mut media := MediaList.create_empty()
	media.set_media_text(text)
	return CSSRule.create_media(media, CSSRuleList.create_empty())
}

fn media_group_nested(leaf &CSSRule) &CSSRule {
	mut rule := leaf
	for type_ in [CSSRuleType.container_rule, .function_rule, .layer_block, .scope, .style] {
		rule = CSSRule.create_grouping(type_, CSSRuleList.create([rule]))
	}
	return rule
}

fn test_media_group_candidates_flatten_all_unconditional_types_in_order() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	first := media_group_leaf('(min-width:600px)')
	second := media_group_leaf('(max-width:600px)')
	last := media_group_leaf('all')
	group := CSSRule.create_grouping(.layer_block, CSSRuleList.create([
		media_group_nested(first), media_group_nested(second),
	]))
	mut list := CSSRuleList.create([group, last])
	assert !list.evaluate_media_queries(document)
	assert first.did_evaluate && second.did_evaluate && last.did_evaluate
	assert first.condition_matches() && !second.condition_matches() && last.condition_matches()
	if !disable_media_rule_candidates && !retain_media_group_recursion {
		// A multi-candidate group remains a boundary. Its single-candidate
		// child chains collapse without widening either retained vector.
		outer_candidates := list.media_evaluation_candidates()
		assert outer_candidates.len == 2
		assert voidptr(outer_candidates[0]) == voidptr(group)
		assert voidptr(outer_candidates[1]) == voidptr(last)
		mut child_list := group.rules or { panic('group children') }
		candidates := child_list.media_evaluation_candidates()
		assert candidates.len == 2
		assert voidptr(candidates[0]) == voidptr(first)
		assert voidptr(candidates[1]) == voidptr(second)
		assert child_list.media_evaluation_flattened_groups_
	}
	document.set_viewport_rect(dom.Rect{width:400, height:600})
	assert list.evaluate_media_queries(document)
	assert !first.condition_matches() && second.condition_matches()
	assert !list.evaluate_media_queries(document)
}

fn test_media_group_flattening_preserves_live_guards_and_delayed_first_evaluation() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut sheet := parse_css_stylesheet_with_parser('@layer outer {
		@media (max-width:600px) {.inside {@media (min-width:300px) {}}}
		@supports (display:not-a-display) {.hidden {@media all {}}}
		@supports (display:block) {.shown {@media (prefers-color-scheme:dark) {}}}
	}', none)
	group := sheet.rules.rules[0]
	children := group.rules or { panic('layer') }
	outer := children.rules[0]
	inner := (((outer.rules or { panic('media children') }).rules[0].rules) or { panic('style children') }).rules[0]
	hidden := (((children.rules[1].rules or { panic('supports children') }).rules[0].rules) or { panic('hidden children') }).rules[0]
	shown := (((children.rules[2].rules or { panic('supports children') }).rules[0].rules) or { panic('shown children') }).rules[0]
	assert !sheet.rules.evaluate_media_queries(document)
	assert outer.did_evaluate && !inner.did_evaluate && !hidden.did_evaluate && shown.did_evaluate
	document.set_svg_image_color_scheme('dark')
	assert sheet.rules.evaluate_media_queries(document)
	assert shown.condition_matches() && !hidden.did_evaluate
	document.set_viewport_rect(dom.Rect{width:400, height:600})
	assert sheet.rules.evaluate_media_queries(document)
	assert inner.did_evaluate && inner.condition_matches() && !hidden.did_evaluate
	mut media := outer.media or { panic('outer media') }
	media.set_media_text('(max-width:200px)')
	assert !sheet.rules.evaluate_media_queries(document)
	assert !outer.condition_matches()
	document.set_viewport_rect(dom.Rect{width:100, height:600})
	assert sheet.rules.evaluate_media_queries(document)
	assert !inner.condition_matches() && !hidden.did_evaluate
}

fn test_media_group_flattening_bounds_expansion_and_rechecks_nested_replacement() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut children := CSSRuleList.create_empty()
	mut leaves := []&CSSRule{}
	for _ in 0 .. 257 {
		leaves << media_group_leaf('(min-width:600px)')
	}
	children.set_rules(leaves)
	group := CSSRule.create_grouping(.layer_block, children)
	mut list := CSSRuleList.create([group])
	assert !list.evaluate_media_queries(document)
	assert list.media_evaluation_candidates().len == 1
	assert voidptr(list.media_evaluation_candidates()[0]) == voidptr(group)
	assert !list.media_evaluation_flattened_groups_
	for leaf in leaves { assert leaf.did_evaluate && leaf.condition_matches() }
	children.set_rules([leaves[0]])
	assert !list.evaluate_media_queries(document)
	if !disable_media_rule_candidates && !retain_media_group_recursion {
		assert voidptr(list.media_evaluation_candidates()[0]) == voidptr(leaves[0])
		assert list.media_evaluation_flattened_groups_
	}
	document.set_viewport_rect(dom.Rect{width:400, height:600})
	assert list.evaluate_media_queries(document)
	assert !leaves[0].condition_matches() && leaves[1].condition_matches()
	children.set_rules([])
	assert !list.evaluate_media_queries(document)
	if !disable_media_rule_candidates {
		assert list.media_evaluation_candidates().len == 0
		assert !list.media_evaluation_flattened_groups_
	}
}

fn test_media_group_flattening_keeps_import_media_and_late_sheet_identity() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut source := parse_css_stylesheet_with_parser('@import url(late.css);', none)
	mut import_rule := source.rules.rules[0]
	mut list := CSSRuleList.create([media_group_nested(import_rule)])
	assert !list.evaluate_media_queries(document)
	mut imported := parse_css_stylesheet_with_parser('@layer child {@media (min-width:600px) {}}', none)
	import_rule.set_style_sheet(imported)
	assert !list.evaluate_media_queries(document)
	leaf := ((imported.rules.rules[0].rules) or { panic('imported layer') }).rules[0]
	assert leaf.did_evaluate && leaf.condition_matches()
	document.set_viewport_rect(dom.Rect{width:400, height:600})
	assert list.evaluate_media_queries(document)
	assert !leaf.condition_matches()
	// The imported sheet's media remains a live gate, including its own match state.
	imported.set_media('(min-width:500px)')
	// CSSOM invalidation resets the sheet's comparison baseline.
	assert !list.evaluate_media_queries(document)
	assert !list.evaluate_media_queries(document)
	document.set_viewport_rect(dom.Rect{width:550, height:600})
	assert list.evaluate_media_queries(document)
	assert !leaf.condition_matches()
	document.set_viewport_rect(dom.Rect{width:400, height:600})
	assert list.evaluate_media_queries(document)
	document.set_viewport_rect(dom.Rect{width:800, height:600})
	assert list.evaluate_media_queries(document)
	assert leaf.condition_matches()
}

fn test_media_group_candidate_vector_keeps_owner_and_reuses_warm_storage() {
	mut document := media_candidate_document()
	defer { document.finalize() }
	mut owner := platform.new_retained_arena('flattened media author')
	mut entered := owner.enter()
	mut sheet := parse_css_stylesheet_with_parser('@layer one {.outer {@media all {}}}', none)
	leaf := (((sheet.rules.rules[0].rules or { panic('layer') }).rules[0].rules) or { panic('style') }).rules[0]
	work := platform.begin_thread_scratch('flattened media summary')
	assert !sheet.rules.evaluate_media_queries(document)
	work.finish()
	churn := platform.begin_thread_scratch('flattened media overwrite')
	_ = []u8{len:128*1024, init:u8(0xa5)}
	churn.finish()
	if !disable_media_rule_candidates {
		$if prealloc { assert owner.arena.contains(sheet.rules.media_evaluation_candidates_.data) }
	}
	if !disable_media_rule_candidates && !retain_media_group_recursion {
		assert voidptr(sheet.rules.media_evaluation_candidates()[0]) == voidptr(leaf)
	}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 64 { _ = sheet.rules.media_evaluation_candidates() }
	$if prealloc { assert platform.thread_arena_usage().used == before }
	// The temporary query document is not retained by the candidate vector.
	assert leaf.did_evaluate
	entered.finish()
	owner.release()
}
