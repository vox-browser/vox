module css

import dom

fn attribute_tag_rule(index uint, text string, pseudo bool) &MatchingRule {
	return &MatchingRule{
		rule_index: index
		selector: selector_from_text(text)
		cascade_origin: .author
		contains_pseudo_element: pseudo
		pseudo_element: if pseudo { ?PseudoElement(PseudoElement.before) } else { none }
	}
}

fn test_attribute_tag_bucket_avoids_unrelated_elements_but_keeps_full_matching() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	rule := attribute_tag_rule(1, 'div[id^="ad-"]', false)
	cache.add_rule(rule, none, false)
	computer := StyleComputer.new(document)
	for name in ['div', 'span'] {
		mut target := document.create_element(name)!
		abstract := dom.AbstractElement.new(target, none)
		for value in ['', 'content', 'ad-banner', 'content-again'] {
			if value == '' { target.remove_attribute('id') } else { target.set_attribute_value('id', value) }
			buckets := cache.matching_rule_buckets(abstract)
			candidates := buckets.filter(it.len > 0)
			expected_candidate := if disable_attribute_tag_buckets { name == 'div' } else { value != '' }
			assert candidates.len == if expected_candidate { 1 } else { 0 }
			mut attempted := PseudoClassBitmap{}
			actual := style_computer_collect_matching_rules_in_scope(computer, abstract, .author,
				mut attempted, none, scope)
			assert actual.len == if name == 'div' && value == 'ad-banner' { 1 } else { 0 }
			if actual.len > 0 { assert voidptr(actual[0].rule) == voidptr(rule) }
		}
	}
}

fn test_attribute_tag_bucket_preserves_class_id_and_namespace_dependent_buckets() {
	for text in ['div.card[title]', 'div#target[title]', 'div:is(.card)[title]', 'div:where(#target)[title]'] {
		mut cache := RuleCache.new()
		rule := attribute_tag_rule(1, text, false)
		cache.add_rule(rule, none, false)
		assert cache.rules_by_attribute_name.len == 0
		assert cache.rules_by_class.len + cache.rules_by_id.len == 1
	}
	for text in ['svg[*|href]', 'svg[x|href]', 'svg[xml\\:lang]'] {
		mut cache := RuleCache.new()
		rule := attribute_tag_rule(1, text, false)
		cache.add_rule(rule, none, false)
		assert cache.rules_by_attribute_name.len == 0
		assert cache.rules_by_tag_name['svg'].len == 1
	}
}

fn test_attribute_tag_bucket_keeps_pseudo_candidates_and_live_attribute_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	rules := [attribute_tag_rule(1, 'div[data-kind="card"]', false),
		attribute_tag_rule(2, 'div[data-kind="card"]::before', true),
		attribute_tag_rule(3, 'div[data-kind="other"]', false)]
	for rule in rules { cache.add_rule(rule, rule.pseudo_element, false) }
	computer := StyleComputer.new(document)
	mut target := document.create_element('div')!
	for value in ['', 'card', 'other', 'card'] {
		if value == '' { target.remove_attribute('data-kind') } else { target.set_attribute_value('data-kind', value) }
		for pseudo in [false, true] {
			abstract := dom.AbstractElement.new(target, if pseudo { ?dom.PseudoElement(dom.PseudoElement.before) } else { none })
			mut attempted := PseudoClassBitmap{}
			actual := style_computer_collect_matching_rules_in_scope(computer, abstract, .author,
				mut attempted, none, scope)
			mut expected := []uint{}
			for rule in rules {
				if rule.contains_pseudo_element != pseudo { continue }
				mut context := MatchContext{}
				if matches(rule.selector, target, none, mut context,
					if pseudo { ?PseudoElement(PseudoElement.before) } else { none }, none, .normal, none) {
					expected << rule.rule_index
				}
			}
			assert actual.map(it.rule.rule_index) == expected
		}
		// Candidate discovery may overestimate value matches but must keep every
		// potentially applicable pseudo rule after live attribute changes.
		if value == 'card' {
			assert scope.has_candidate_rule_for_pseudo_element(dom.AbstractElement.new(target, none), .before)
		}
	}
}
