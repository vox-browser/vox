module css

import dom
import platform
import processmetrics

fn empty_match_collection_fixture() (&dom.Document, &dom.Element, &StyleComputer, &StyleScope, &RuleCache) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	target := document.create_element('div') or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('author cache') }
	return document, target, StyleComputer.new(document), scope, cache
}

fn test_empty_match_collection_preserves_attempts_and_releases_candidate_scratch() {
	mut document, target, computer, scope, _ := empty_match_collection_fixture()
	defer { document.finalize() }
	mut attempted := PseudoClassBitmap{}
	attempted.set(.focus_within, true)
	before := attempted
	for pseudo in [?dom.PseudoElement(none), ?dom.PseudoElement(dom.PseudoElement.before)] {
		for _ in 0 .. 3 {
			actual := style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, pseudo), .author, mut attempted, none, scope)
			assert actual.len == 0
			assert attempted == before
			assert computer.matching_rule_candidates_.active_depth == 0
			assert computer.matching_rule_candidates_.buffers[0].rules.len == 0
			assert computer.matching_rule_candidates_.buffers[0].context.subject == none
			gc_collect()
		}
	}
	$if vox_empty_collector_probe ? {
		for _ in 0 .. 8 {
			_ = style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		}
		gc_collect()
		arena_before := platform.thread_arena_usage().used
		mut checksum := 0
		start := processmetrics.begin_instructions()
		for _ in 0 .. 2048 {
			result := style_computer_collect_matching_rules_in_scope(computer,
				dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
			checksum += result.len + 1
		}
		instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
		arena_growth := platform.thread_arena_usage().used - arena_before
		assert checksum == 2048
		assert attempted == before
		eprintln('VOX_EMPTY_COLLECTOR instructions=${instructions} checksum=${checksum} arena_growth=${arena_growth}')
	}
}

fn test_empty_match_collection_distinguishes_no_candidates_from_nonmatching_selectors() {
	mut document, target, computer, scope, mut cache := empty_match_collection_fixture()
	defer { document.finalize() }
	mut attempted := PseudoClassBitmap{}
	mut node := unsafe { &dom.Element(target) }
	node.set_attribute_value('class', 'card')
	rule := &MatchingRule{selector: selector_from_text('.card:hover'), rule_index: 42, cascade_origin: .author}
	for _ in 0 .. 3 {
		cache.other_rules = [rule]
		actual := style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		assert actual.len == 0
		assert attempted.get(.hover)
		cache.other_rules = []&MatchingRule{}
		retained_attempts := attempted
		empty := style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		assert empty.len == 0
		assert attempted == retained_attempts
		assert computer.matching_rule_candidates_.active_depth == 0
		gc_collect()
	}
}
