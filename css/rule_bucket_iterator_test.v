module css

import dom
import platform

fn test_rule_bucket_iterator_borrows_ordered_vectors_and_keeps_empty_buckets() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('html')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	root.set_attribute_value('class', 'empty Card')
	root.set_attribute_value('id', 'TARGET')
	root.set_attribute_value('title', 'value')
	mut cache := RuleCache.new()
	cache.fold_id_and_class_name_case = true
	cache.rules_by_class['empty'] = []&MatchingRule{}
	cache.rules_by_class['card'] = [&MatchingRule{ rule_index: 1 }]
	cache.rules_by_id['target'] = [&MatchingRule{ rule_index: 2 }]
	cache.rules_by_tag_name['html'] = [&MatchingRule{ rule_index: 3 }]
	cache.rules_by_pseudo_element[.before] = [&MatchingRule{ rule_index: 4 }]
	cache.root_rules = [&MatchingRule{ rule_index: 5 }]
	cache.rules_by_attribute_name['title'] = [&MatchingRule{ rule_index: 6 }]
	cache.other_rules = [&MatchingRule{ rule_index: 7 }]
	mut iterator := rule_bucket_iterator(cache, dom.AbstractElement.new(root, dom.PseudoElement.before))
	assert iterator.next()?.len == 0
	for expected in 1 .. 8 {
		bucket := iterator.next()?
		assert bucket.len == 1
		assert bucket[0].rule_index == uint(expected)
		if expected == 7 {
			assert bucket.data == cache.other_rules.data
		}
	}
	assert iterator.next() == none
	assert iterator.next() == none
}

fn test_pseudo_class_rule_comparison_reuses_contexts_without_candidate_vectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := document.create_element('div')!
	computer := css_style_computer_for(document)
	mut cache := RuleCache.new()
	selectors := parse_selector_with_parser('div:hover', map[string]bool{}) or {
		panic('invalid hover fixture')
	}
	rule := &MatchingRule{ selector: selectors.selectors[0] }
	cache.rules_by_tag_name['div'] = []&MatchingRule{len: 256, init: rule}
	before_cache := &HasResultCache{}
	after_cache := &HasResultCache{}
	mut contexts := PseudoClassInvalidationContexts{}
	assert !pseudo_class_matches_different_rule_set_after_state_change(document, .hover, none, root, cache, computer, before_cache, after_cache, mut contexts)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 8 {
		assert !pseudo_class_matches_different_rule_set_after_state_change(document, .hover, none, root, cache, computer, before_cache, after_cache, mut contexts)
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 4096
	}
	assert document.pseudo_class_state_node(.hover) == none
	assert contexts.before.attempted_pseudo_class_matches.get(.hover)
	assert contexts.after.attempted_pseudo_class_matches.get(.hover)
}
