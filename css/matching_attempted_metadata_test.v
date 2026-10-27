module css

import dom

fn test_matching_rules_keep_attempted_metadata_across_states_and_subjects() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('html')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'card')
	other := document.create_element('span')!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	root_node.append_child(other.as_node())!
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	mut rules := []&MatchingRule{}
	for index, text in ['.card', '.card:hover', '.card:focus', '.card:not(:hover)'] {
		rules << &MatchingRule{
			rule_index: uint(index)
			selector: selector_from_text(text)
			cascade_origin: .author
		}
	}
	cache.rules_by_class['card'] = rules
	computer := StyleComputer.new(document)
	for hovered in [false, true, false] {
		if hovered { document.set_hovered_node(target.as_node()) }
		else { document.set_hovered_node(none) }
		mut attempted := PseudoClassBitmap{}
		attempted.set(.focus_within, true)
		attempted.set(.heading, true)
		actual := style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
		assert actual.len == 2
		assert voidptr(actual[0].rule) == voidptr(rules[0])
		expected_index := if hovered { 1 } else { 3 }
		assert voidptr(actual[1].rule) == voidptr(rules[expected_index])
		for pseudo in [PseudoClass.hover, .focus, .not_, .focus_within, .heading] {
			assert attempted.get(pseudo)
		}
		assert !attempted.get(.active)
		mut other_attempted := PseudoClassBitmap{}
		assert style_computer_collect_matching_rules_in_scope(computer,
			dom.AbstractElement.new(other, none), .author, mut other_attempted, none, scope).len == 0
		assert other_attempted.words == [u64(0), 0]!
		gc_collect()
		assert actual[1].rule.rule_index == uint(expected_index)
	}
}
