module css

import dom
import platform
import processmetrics

fn lazy_match_memo_fixture() (&dom.Document, &dom.Element, &StyleComputer, &StyleScope, &RuleCache) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut target := document.create_element('div') or { panic(err) }
	target.set_attribute_value('class', 'card')
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('author cache') }
	return document, target, StyleComputer.new(document), scope, cache
}

fn test_unique_selector_collection_preserves_results_and_scratch_lifetime() {
	mut document, target, computer, scope, mut cache := lazy_match_memo_fixture()
	defer { document.finalize() }
	rule := &MatchingRule{selector: selector_from_text('.card'), rule_index: 7, cascade_origin: .author}
	assert !rule.selector.data_.repeated_rule_parse
	cache.rules_by_class['card'] = [rule]
	mut attempted := PseudoClassBitmap{}
	attempted.set(.focus_within, true)
	before := attempted
	for _ in 0 .. 3 {
		actual := style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		assert actual.len == 1 && voidptr(actual[0].rule) == voidptr(rule)
		assert attempted == before
		assert computer.matching_rule_candidates_.active_depth == 0
		gc_collect()
		assert actual[0].rule.rule_index == 7
	}
	$if vox_lazy_match_memo_probe ? {
		for _ in 0 .. 8 {
			_ = style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		}
		gc_collect()
		arena_before := platform.thread_arena_usage().used
		mut checksum := 0
		start := processmetrics.instruction_snapshot()
		for _ in 0 .. 2048 {
			result := style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
			checksum += result.len
		}
		instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
		arena_growth := platform.thread_arena_usage().used - arena_before
		assert checksum == 2048 && attempted == before
		eprintln('VOX_LAZY_MATCH_MEMO kind=unique instructions=${instructions} checksum=${checksum} arena_growth=${arena_growth}')
	}
}

fn test_mixed_unique_and_repeated_selectors_keep_order_metadata_and_scope_lifetime() {
	mut document, target, computer, scope, mut cache := lazy_match_memo_fixture()
	defer { document.finalize() }
	unique := &MatchingRule{selector: selector_from_text('div.card'), rule_index: 1, cascade_origin: .author}
	hover := selector_from_text('.card:hover')
	matched := selector_from_text('.card')
	mut hover_data := unsafe { &SelectorData(hover.data_) }
	mut matched_data := unsafe { &SelectorData(matched.data_) }
	hover_data.repeated_rule_parse = true
	matched_data.repeated_rule_parse = true
	cache.other_rules = [unique,
		&MatchingRule{selector: hover, rule_index: 2, cascade_origin: .author},
		&MatchingRule{selector: hover, rule_index: 3, cascade_origin: .author},
		&MatchingRule{selector: matched, rule_index: 4, cascade_origin: .author},
		&MatchingRule{selector: matched, rule_index: 5, cascade_origin: .author}]
	for hovered in [false, true, false] {
		if hovered { document.set_hovered_node(target.as_node()) }
		else { document.set_hovered_node(none) }
		mut attempted := PseudoClassBitmap{}
		attempted.set(.focus_within, true)
		actual := style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		mut indices := []uint{}
		for entry in actual { indices << entry.rule.rule_index }
		assert indices == if hovered { [uint(1), 2, 3, 4, 5] } else { [uint(1), 4, 5] }
		assert attempted.get(.hover) && attempted.get(.focus_within)
		assert computer.matching_rule_candidates_.active_depth == 0
		gc_collect()
		assert actual[0].rule.rule_index == 1
	}

	$if vox_lazy_match_memo_probe ? {
		mut attempted := PseudoClassBitmap{}
		attempted.set(.focus_within, true)
		for _ in 0 .. 8 {
			_ = style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		}
		gc_collect()
		arena_before := platform.thread_arena_usage().used
		mut checksum := 0
		start := processmetrics.instruction_snapshot()
		for _ in 0 .. 2048 {
			result := style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
			checksum += result.len
		}
		instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
		arena_growth := platform.thread_arena_usage().used - arena_before
		assert checksum == 6144 && attempted.get(.hover) && attempted.get(.focus_within)
		eprintln('VOX_LAZY_MATCH_MEMO kind=repeated instructions=${instructions} checksum=${checksum} arena_growth=${arena_growth}')
	}
}
