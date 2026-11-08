module css

import dom

fn test_disjunctive_subject_masks_keep_matches_order_and_one_candidate_per_rule() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_document_type(.html)
		if quirks { document.set_quirks_mode(.yes) }
		defer { document.finalize() }
		mut element := document.create_element('div')!
		computer := css_style_computer_for(document)
		mut cache := RuleCache.new()
		cache.fold_id_and_class_name_case = quirks
		cache.disjunctive_subject_masks_trusted_ = true
		for index, source in [':is(.one,.two)', ':where(.one,#named)',
			':is(span.flag,div.other)', ':is([title],.one)', ':not(.missing)',
			':is(.ONE,.two)'] {
			selector := parse_selector_with_parser(source, map[string]bool{})?.selectors[0]
			cache.add_rule(&MatchingRule{selector:selector, rule_index:uint(index)}, none, false)
		}
		for classes in ['', 'one', 'two', 'one two', 'other', 'ONE'] {
			element.set_attribute_value('class', classes)
			element.set_attribute_value('id', 'named')
			for title in [false, true] {
				if title { element.set_attribute_value('title', 'yes') }
				else { element.remove_attribute('title') }
				subject := dom.AbstractElement.new(element, none)
				mut expected := []ScopedMatchingRule{}
				style_scope_add_rules_to_run(computer, subject, cache.other_rules, none, none, none, mut expected)
				mut actual := []ScopedMatchingRule{}
				style_scope_add_masked_other_rules(computer, subject, cache, none, none, none, mut actual)
				mut expected_matches := []uint{}
				mut actual_matches := []uint{}
				mut emitted := map[uint]bool{}
				for entry in expected {
					mut context := MatchContext{has_result_cache: unsafe { nil }}
					if matches(entry.rule.selector, element, none, mut context, none, none, .normal, none) {
						expected_matches << entry.rule.rule_index
					}
				}
				for entry in actual {
					assert !emitted[entry.rule.rule_index]
					emitted[entry.rule.rule_index] = true
					mut context := MatchContext{has_result_cache: unsafe { nil }}
					if matches(entry.rule.selector, element, none, mut context, none, none, .normal, none) {
						actual_matches << entry.rule.rule_index
					}
				}
				assert actual_matches == expected_matches
			}
		}
	}
}

fn test_disjunctive_subject_masks_preserve_manually_mutated_other_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	computer := css_style_computer_for(document)
	mut cache := RuleCache.new()
	mut rule := &MatchingRule{selector:parse_selector_with_parser(':is(.one,.two)', map[string]bool{})?.selectors[0]}
	cache.add_rule(rule, none, false)
	rule.selector = parse_selector_with_parser('*', map[string]bool{})?.selectors[0]
	mut actual := []ScopedMatchingRule{}
	style_scope_add_masked_other_rules(computer, dom.AbstractElement.new(element, none), cache, none, none, none, mut actual)
	assert actual.len == 1 && voidptr(actual[0].rule) == voidptr(rule)
}
