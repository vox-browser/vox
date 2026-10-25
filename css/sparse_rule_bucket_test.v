module css

import dom

fn sparse_bucket_rule(index usize, source string, pseudo bool) &MatchingRule {
	return &MatchingRule{
		rule_index: index
		selector: selector_from_text(source)
		cascade_origin: .author
		contains_pseudo_element: pseudo
		pseudo_element: if pseudo { ?PseudoElement(PseudoElement.before) } else { none }
	}
}

fn test_sparse_candidate_buckets_keep_order_identity_and_scope_for_every_combination() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	root.set_attribute_value('class', 'Mixed card absent')
	root.set_attribute_value('id', 'TARGET')
	root.set_attribute_value('title', 'value')
	root.set_attribute_value_ns('É', 'value', 'x', 'urn:sparse')
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	computer := StyleComputer.new(document)
	sentinel := sparse_bucket_rule(99, '*', false)
	for folded in [false, true] {
		for queried_pseudo in [false, true] {
			abstract_element := if queried_pseudo {
				dom.AbstractElement.new(root, dom.PseudoElement.before)
			} else { dom.AbstractElement.new(root, none) }
			source := if queried_pseudo { '*::before' } else { '*' }
			mut rules := []&MatchingRule{}
			for index in 1 .. 9 { rules << sparse_bucket_rule(usize(index), source, queried_pseudo) }
			excluded := &MatchingRule{
				selector: selector_from_text(source)
				cascade_origin: .author
				contains_pseudo_element: queried_pseudo
				default_namespace: 'urn:excluded'
			}
			for mask in 0 .. 64 {
				mut cache := RuleCache.new()
				cache.fold_id_and_class_name_case = folded
				mut expected := [usize(99)]
				if mask & 1 != 0 {
					cache.rules_by_class[if folded { 'mixed' } else { 'Mixed' }] = [rules[0]]
					cache.rules_by_class['card'] = [rules[0]]
					cache.rules_by_class['absent'] = []&MatchingRule{}
					expected << [usize(1), 1]
				}
				if mask & 2 != 0 {
					cache.rules_by_id[if folded { 'target' } else { 'TARGET' }] = [rules[1]]
					expected << 2
				}
				if mask & 4 != 0 {
					cache.rules_by_tag_name['html'] = [rules[2]]
					expected << 3
				}
				if mask & 8 != 0 {
					cache.rules_by_pseudo_element[.before] = [rules[3]]
					if queried_pseudo { expected << 4 }
				}
				if mask & 16 != 0 {
					cache.root_rules = [rules[4]]
					expected << 5
				}
				if mask & 32 != 0 {
					cache.rules_by_attribute_name['title'] = [rules[5], excluded]
					cache.rules_by_attribute_name['x:é'] = [rules[6]]
					cache.rules_by_attribute_name['missing'] = []&MatchingRule{}
					expected << [usize(6), 7]
				}
				cache.other_rules = [rules[7]]
				expected << 8
				seed := ScopedMatchingRule{
					rule: sentinel
					shadow_root: shadow
				}
				mut actual := [seed]
				mut oracle := [seed]
				style_scope_add_cached_rules_to_run(computer, abstract_element, cache, none, none, none, mut actual)
				// Keep the public bucket traversal as an independent ordering oracle.
				for bucket in cache.matching_rule_buckets(abstract_element) {
					style_scope_add_rules_to_run(computer, abstract_element, bucket, none, none, none, mut oracle)
				}
				assert actual.len == expected.len
				assert actual.len == oracle.len
				mut indices := []usize{}
				for index, rule in actual {
					indices << rule.rule.rule_index
					assert voidptr(rule.rule) == voidptr(oracle[index].rule)
					assert style_scope_optional_shadow_root_equal(rule.shadow_root, oracle[index].shadow_root)
					if index > 0 { assert rule.shadow_root == none }
				}
				assert indices == expected
				assert voidptr(actual[0].shadow_root or { panic('lost shadow scope') }) == voidptr(shadow)
				assert 'absent' !in cache.rules_by_class || cache.rules_by_class['absent'].len == 0
				assert 'missing' !in cache.rules_by_attribute_name || cache.rules_by_attribute_name['missing'].len == 0
			}
		}
	}
}

fn test_sparse_root_buckets_observe_live_attachment_population_and_removal() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut document_node := document.as_node()
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	computer := StyleComputer.new(document)
	element := dom.AbstractElement.new(root, none)
	mut attempted := PseudoClassBitmap{}
	for generation in 0 .. 3 {
		rule := sparse_bucket_rule(usize(40 + generation), ':root', false)
		cache.root_rules = [rule]
		assert !root.is_document_element()
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author, mut attempted, none, scope).len == 0
		document_node.append_child(root.as_node())!
		assert root.is_document_element()
		cache.root_rules = []&MatchingRule{}
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author, mut attempted, none, scope).len == 0
		cache.root_rules = [rule]
		retained := style_computer_collect_matching_rules_in_scope(computer, element, .author, mut attempted, none, scope)
		assert retained.len == 1
		assert retained[0].resolved_scope_root == none
		assert retained[0].scope_proximity == 0x3fffffff
		assert voidptr(retained[0].rule) == voidptr(rule)
		cache.root_rules = []&MatchingRule{}
		gc_collect()
		assert retained[0].rule.rule_index == usize(40 + generation)
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author, mut attempted, none, scope).len == 0
		cache.root_rules = [rule]
		document_node.remove_child(root.as_node())!
		assert !root.is_document_element()
		assert style_computer_collect_matching_rules_in_scope(computer, element, .author, mut attempted, none, scope).len == 0
		assert root.attributes_ == none
	}
}
