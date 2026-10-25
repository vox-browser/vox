module css

import dom

fn pseudo_element_filter_test_selector(source string) Selector {
	list := parse_selector_with_parser(source, map[string]bool{}) or {
		panic('failed to parse ${source}')
	}
	return list.selectors[0]
}

fn test_candidate_rules_are_filtered_by_target_pseudo_element() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('invalid pseudo-element fixture')
	}
	element.set_attribute_value('class', 'target')
	computer := StyleComputer.new(document)
	before_rule := &MatchingRule{
		selector: pseudo_element_filter_test_selector('.target::before')
		cascade_origin: .author
		contains_pseudo_element: true
	}
	after_rule := &MatchingRule{
		selector: pseudo_element_filter_test_selector('.target::after')
		cascade_origin: .author
		contains_pseudo_element: true
	}
	ordinary_rule := &MatchingRule{
		selector: pseudo_element_filter_test_selector('.target')
		cascade_origin: .author
	}
	mut rules_to_run := []MatchingRuleCandidate{}
	style_scope_add_rules_to_run(computer, dom.AbstractElement.new(element, .before), [before_rule,
		after_rule, ordinary_rule], none, none, none, mut rules_to_run)

	assert rules_to_run.len == 1
	assert voidptr(rules_to_run[0].rule) == voidptr(before_rule)
}
