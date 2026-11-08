module css

import dom

fn common_subject_test_selector(text string) Selector {
	parsed := parse_selector_with_parser(text, map[string]bool{}) or { panic(text) }
	return parsed.selectors[0]
}

fn common_subject_test_matches(rule &MatchingRule, element &dom.Element) bool {
	mut context := MatchContext{ subject: unsafe { &dom.Element(element) } }
	return matches(rule.selector, element, none, mut context, none, none, .normal, none)
}

fn test_common_subject_buckets_preserve_full_selector_matches() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_document_type(.html)
		defer { document.finalize() }
		if quirks { document.set_quirks_mode(.yes) }
		mut parent := document.create_element('section')!
		parent.set_attribute_value('class', 'ancestor')
		mut target := document.create_element('div')!
		mut parent_node := parent.as_node()
		parent_node.append_child(target.as_node())!
		mut cache := RuleCache.new()
		cache.fold_id_and_class_name_case = quirks
		mut rules := []&MatchingRule{}
		for index, text in [':is(.card.active,.card[title])', ':where(.card.active,.card:not([hidden]))',
			':is(#target.active,#target[title])', ':is(div.active,div[title])',
			':is(.ancestor .active,.ancestor [title])', ':is(.card,.other)',
			':not(:is(.card.active,.card[title]))', ':is(.card + div,.card > div)',
			':is(.CaRD.active,.CaRD[title])'] {
			rule := &MatchingRule{ rule_index: uint(index), selector: common_subject_test_selector(text) }
			rules << rule
			cache.add_rule(rule, none, false)
		}
		for class_name in ['', 'card', 'card active', 'other', 'active', 'CaRD active'] {
			target.set_attribute_value('class', class_name)
			for with_title in [false, true] {
				if with_title {
					target.set_attribute_value('title', 'yes')
				} else {
					target.remove_attribute('title')
				}
				for id in ['', 'target', 'TARGET'] {
					target.set_attribute_value('id', id)
					mut expected := []uint{}
					for rule in rules {
						if common_subject_test_matches(rule, target) { expected << rule.rule_index }
					}
					mut actual := []uint{}
					for bucket in cache.matching_rule_buckets(dom.AbstractElement.new(target, none)) {
						for rule in bucket {
							if common_subject_test_matches(rule, target) {
								actual << rule.rule_index
							}
						}
					}
					actual.sort()
					assert actual == expected
				}
			}
		}
	}
}

fn test_common_subject_bucket_uses_only_positive_subject_conditions() {
	for text in [':is(.ancestor .left,.ancestor .right)', ':where(:not(.card),:not(.card.active))',
		':is(.left,.right)'] {
		selector := common_subject_test_selector(text)
		simple := selector.compound_selectors()[0].simple_selectors[0]
		assert style_scope_is_roundabout_selector_bucketable_as_something_simpler(simple) == none
	}
	selector := common_subject_test_selector(':is(.ancestor .card.active,.other .card[title])')
	simple := selector.compound_selectors()[0].simple_selectors[0]
	bucket := style_scope_is_roundabout_selector_bucketable_as_something_simpler(simple) or { panic('common subject') }
	assert bucket.type_ == .class && bucket.name == 'card'
}

fn test_common_subject_bucketing_keeps_is_and_where_specificity() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'card active')
	add_document_author_style_sheet(document,
		':is(.card.active,.card[title]){color:red}' +
			'.card{color:blue;padding:3px}' +
			':where(.card.active,.card[title]){padding:9px}')
	style := css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	assert style.property(.color, .no)?.css_text == 'rgb(255, 0, 0)'
	assert style.property(.padding_top, .no)?.css_text == '3px'
}
