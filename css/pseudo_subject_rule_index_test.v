module css

import dom

fn test_pseudo_subject_index_preserves_matches_candidate_presence_and_order() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'card active')
	target.set_attribute_value('id', 'target')
	target.set_attribute_value('title', 'value')
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('cache') }
	for index, text in ['.card', '.card::before', '#target::after', 'div[title]::before', '*::after',
		'.active:hover::before', '.absent::marker', '.card::before::marker'] {
		selector := selector_from_text(text)
		mut pseudo := ?PseudoElement(none)
		if terminal := selector.data_.pseudo_element { pseudo = terminal.type_ }
		// Chained pseudo rules record the first target for the coarse existence
		// query, while selector matching uses the terminal pseudo-element.
		if text == '.card::before::marker' { pseudo = PseudoElement.before }
		rule := &MatchingRule{
			rule_index:              uint(index)
			selector:                selector
			cascade_origin:          .author
			contains_pseudo_element: pseudo != none
			pseudo_element:          pseudo
		}
		cache.add_rule(rule, pseudo, false)
		cache.index_pseudo_subject_rule(rule, pseudo, false)
	}
	computer := StyleComputer.new(document)
	for class_name in ['card active', 'absent', 'other'] {
		target.set_attribute_value('class', class_name)
		for pseudo in [?dom.PseudoElement(none), ?dom.PseudoElement(dom.PseudoElement.before),
			?dom.PseudoElement(dom.PseudoElement.after), ?dom.PseudoElement(dom.PseudoElement.marker),
			?dom.PseudoElement(dom.PseudoElement.backdrop)] {
			abstract := dom.AbstractElement.new(target, pseudo)
			mut actual_attempted := PseudoClassBitmap{}
			actual := style_computer_collect_matching_rules_in_scope(computer, abstract,
				.author, mut actual_attempted, none, scope)
			for kind in [PseudoElement.before, .after, .marker, .backdrop] {
				assert cache.has_candidate_rule_for_pseudo_element(abstract, kind) ==
					cache.has_pseudo_subject_candidate(abstract, kind)
			}
			cache.pseudo_subject_index_ready_ = false
			mut expected_attempted := PseudoClassBitmap{}
			expected := style_computer_collect_matching_rules_in_scope(computer, abstract,
				.author, mut expected_attempted, none, scope)
			cache.pseudo_subject_index_ready_ = true
			assert actual.map(u64(voidptr(it.rule))) == expected.map(u64(voidptr(it.rule)))
			assert actual_attempted == expected_attempted
		}
	}
}

fn test_pseudo_subject_index_leaves_manual_caches_and_scope_crossing_rules_available() {
	mut cache := RuleCache.new()
	selector := selector_from_text('.card::before')
	rule := &MatchingRule{
		selector:                selector
		contains_pseudo_element: true
		pseudo_element:          PseudoElement.before
	}
	cache.add_rule(rule, PseudoElement.before, false)
	assert !cache.pseudo_subject_index_ready_
	assert voidptr(pseudo_subject_rule_cache_for_type(cache, .before) or { panic('fallback') }) == voidptr(cache)
	for slotted in [true, false] {
		crossing := &MatchingRule{
			selector:                     selector
			contains_pseudo_element:      true
			pseudo_element:               PseudoElement.before
			slotted:                      slotted
			contains_part_pseudo_element: !slotted
		}
		cache.add_rule(crossing, PseudoElement.before, false)
		cache.index_pseudo_subject_rule(crossing, PseudoElement.before, false)
	}
	assert cache.slotted_rules.len == 1
	assert cache.part_rules.len == 1
	assert cache.pseudo_subject_rules_.len == 0
}
