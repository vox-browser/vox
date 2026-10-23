module css

import dom

fn checked_bucket_rule(index usize, text string) &MatchingRule {
	mut rule := &MatchingRule{
		rule_index: index
		selector: selector_from_text(text)
		cascade_origin: .author
	}
	if text == '*::before' {
		rule.contains_pseudo_element = true
		rule.pseudo_element = PseudoElement.before
	}
	return rule
}

fn test_cached_rule_buckets_observe_empty_replaced_and_removed_entries() {
	document := dom.Document.create(dom.url_about_blank())
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'card missing')
	target.set_attribute_value('id', 'target')
	target.set_attribute_value('title', 'value')
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	computer := StyleComputer.new(document)
	element := dom.AbstractElement.new(target, none)
	pseudo := dom.AbstractElement.new(target, dom.PseudoElement.before)
	mut attempted := PseudoClassBitmap{}
	for generation in 0 .. 3 {
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author,
			mut attempted, none, scope).len == 0
		assert style_computer_collect_matching_rules_in_scope(computer, pseudo, .author,
			mut attempted, none, scope).len == 0
		assert cache.rules_by_class.len == 0
		assert cache.rules_by_id.len == 0
		assert cache.rules_by_tag_name.len == 0
		assert cache.rules_by_attribute_name.len == 0
		assert cache.rules_by_pseudo_element.len == 0

		cache.rules_by_class['card'] = []&MatchingRule{}
		cache.rules_by_id['target'] = []&MatchingRule{}
		cache.rules_by_tag_name['div'] = []&MatchingRule{}
		cache.rules_by_attribute_name['title'] = []&MatchingRule{}
		cache.rules_by_pseudo_element[.before] = []&MatchingRule{}
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author,
			mut attempted, none, scope).len == 0
		assert style_computer_collect_matching_rules_in_scope(computer, pseudo, .author,
			mut attempted, none, scope).len == 0

		base := usize(generation * 10)
		class_rule := checked_bucket_rule(base + 1, '.card')
		id_rule := checked_bucket_rule(base + 2, '#target')
		tag_rule := checked_bucket_rule(base + 3, 'div')
		attribute_rule := checked_bucket_rule(base + 4, '[title]')
		pseudo_rule := checked_bucket_rule(base + 5, '*::before')
		cache.rules_by_class['card'] = [class_rule]
		cache.rules_by_id['target'] = [id_rule]
		cache.rules_by_tag_name['div'] = [tag_rule]
		cache.rules_by_attribute_name['title'] = [attribute_rule]
		cache.rules_by_pseudo_element[.before] = [pseudo_rule]
		actual := style_computer_collect_matching_rules_in_scope(computer, element, .author,
			mut attempted, none, scope)
		actual_pseudo := style_computer_collect_matching_rules_in_scope(computer, pseudo, .author,
			mut attempted, none, scope)
		assert actual.len == 4
		for i, rule in [class_rule, id_rule, tag_rule, attribute_rule] {
			assert voidptr(actual[i].rule) == voidptr(rule)
			assert actual[i].rule.rule_index == base + usize(i) + 1
		}
		assert actual_pseudo.len == 1
		assert voidptr(actual_pseudo[0].rule) == voidptr(pseudo_rule)
		assert 'missing' !in cache.rules_by_class

		cache.rules_by_class.delete('card')
		cache.rules_by_id.delete('target')
		cache.rules_by_tag_name.delete('div')
		cache.rules_by_attribute_name.delete('title')
		cache.rules_by_pseudo_element.delete(PseudoElement.before)
		gc_collect()
		assert actual.len == 4
		for i in 0 .. 4 {
			assert actual[i].rule.rule_index == base + usize(i) + 1
		}
		assert actual_pseudo[0].rule.rule_index == base + 5
	}
}
