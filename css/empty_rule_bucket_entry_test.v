module css

import dom

fn empty_bucket_selector(source string) Selector {
	list := parse_selector_with_parser(source, map[string]bool{}) or { panic(err) }
	return list.selectors[0]
}

fn test_empty_rule_buckets_preserve_existing_scoped_results() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	computer := StyleComputer.new(document)
	empty := []&MatchingRule{}
	for namespace in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg',
		'http://www.w3.org/1998/Math/MathML', 'urn:empty-bucket'] {
		element := document.create_element_ns(namespace, 'div')!
		rule := &MatchingRule{ selector: empty_bucket_selector('*'), cascade_origin: .author }
		for abstract_element in [dom.AbstractElement.new(element, none),
			dom.AbstractElement.new(element, dom.PseudoElement.before),
			dom.AbstractElement.new(element, dom.PseudoElement.selection)] {
			mut output := [ScopedMatchingRule{
				rule: rule
				shadow_root: shadow
				resolved_scope_root: element
				scope_proximity: 7
			}]
			for _ in 0 .. 3 {
				style_scope_add_rules_to_run(computer, abstract_element, empty, none, none, none,
					mut output)
				style_scope_add_rules_to_run(computer, abstract_element, empty, shadow, shadow,
					shadow, mut output)
				gc_collect()
				assert output.len == 1
				assert voidptr(output[0].rule) == voidptr(rule)
				actual_shadow := output[0].shadow_root or { panic('missing retained shadow root') }
				actual_scope := output[0].resolved_scope_root or { panic('missing retained scope root') }
				assert voidptr(actual_shadow) == voidptr(shadow)
				assert voidptr(actual_scope) == voidptr(element)
				assert output[0].scope_proximity == 7
			}
		}
	}
}

fn test_empty_rule_buckets_observe_later_cache_population_and_removal() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	computer := StyleComputer.new(document)
	abstract_element := dom.AbstractElement.new(element, none)
	mut attempted := PseudoClassBitmap{}
	for _ in 0 .. 3 {
		cache.other_rules = []&MatchingRule{}
		assert style_computer_collect_matching_rules_in_scope(computer, abstract_element, .author,
			mut attempted, none, scope).len == 0
		rule := &MatchingRule{
			selector: empty_bucket_selector('*')
			cascade_origin: .author
			rule_index: 17
		}
		cache.other_rules = [rule]
		actual := style_computer_collect_matching_rules_in_scope(computer, abstract_element, .author,
			mut attempted, none, scope)
		assert actual.len == 1
		assert voidptr(actual[0].rule) == voidptr(rule)
		assert actual[0].rule.rule_index == 17
		cache.other_rules = []&MatchingRule{}
		gc_collect()
		assert actual.len == 1
		assert voidptr(actual[0].rule) == voidptr(rule)
		assert style_computer_collect_matching_rules_in_scope(computer, abstract_element, .author,
			mut attempted, none, scope).len == 0
	}
}
