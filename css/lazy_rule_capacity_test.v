module css

import dom

fn lazy_capacity_fixture() (&dom.Document, &dom.Element, &StyleComputer, &StyleScope) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut root := document.create_element('html') or { panic('capacity fixture failed') }
	mut target := document.create_element('article') or { panic('capacity fixture failed') }
	target.set_attribute_value('class', 'target')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic('capacity fixture failed') }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic('capacity fixture failed') }
	scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	return document, target, StyleComputer.new(document), scope
}

fn test_matching_result_growth_keeps_rule_order_identity_metadata_and_owners() {
	mut document, target, computer, scope := lazy_capacity_fixture()
	defer { document.finalize() }
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	for count in [1, 2, 7, 8, 9, 33] {
		for is_pseudo in [false, true] {
			text := if is_pseudo { '.target::before' } else { '.target' }
			mut expected := []&MatchingRule{}
			for index in 0 .. count {
				expected << &MatchingRule{
					rule_index: usize(index)
					selector: selector_from_text(text)
					cascade_origin: .author
					contains_pseudo_element: is_pseudo
					pseudo_element: if is_pseudo { ?PseudoElement(PseudoElement.before) } else { none }
				}
			}
			miss := &MatchingRule{
				selector: selector_from_text(if is_pseudo { '.target:hover::before' } else { '.target:hover' })
				cascade_origin: .author
				contains_pseudo_element: is_pseudo
				pseudo_element: if is_pseudo { ?PseudoElement(PseudoElement.before) } else { none }
			}
			cache.rules_by_class['target'] = [miss]
			cache.rules_by_class['target'] << expected
			abstract := dom.AbstractElement.new(target, if is_pseudo { ?dom.PseudoElement(dom.PseudoElement.before) } else { none })
			mut public_attempts := PseudoClassBitmap{}
			public_rules := style_computer_collect_matching_rules_in_scope(computer, abstract, .author, mut public_attempts, none, scope)
			assert public_rules.len == count
			assert public_attempts.get(.hover)
			mut workspace := computer.acquire_matching_rule_set_workspace()
			mut owned_attempts := PseudoClassBitmap{}
			owned_rules := collect_matching_rules_with_storage(computer, abstract, .author, mut owned_attempts, none, scope, workspace.arena)
			assert owned_rules.len == count
			assert owned_attempts == public_attempts
			$if prealloc { assert workspace.arena.contains(owned_rules.data) }
			for index, rule in expected {
				assert voidptr(public_rules[index].rule) == voidptr(rule)
				assert voidptr(owned_rules[index].rule) == voidptr(rule)
				assert public_rules[index].shadow_root == none
				assert owned_rules[index].resolved_scope_root == none
				assert owned_rules[index].scope_proximity == public_rules[index].scope_proximity
			}
			workspace.finish()
			gc_collect()
			for index, rule in expected {
				assert voidptr(public_rules[index].rule) == voidptr(rule)
				assert public_rules[index].rule.rule_index == usize(index)
			}
		}
	}
}

fn test_unmatched_candidate_lists_keep_empty_results_unallocated_and_observe_later_state() {
	mut document, target, computer, scope := lazy_capacity_fixture()
	defer { document.finalize() }
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('missing cache') }
	mut expected := []&MatchingRule{}
	for index in 0 .. 33 {
		expected << &MatchingRule{
			rule_index: usize(index)
			selector: selector_from_text('.target:hover')
			cascade_origin: .author
		}
	}
	cache.rules_by_class['target'] = expected
	abstract := dom.AbstractElement.new(target, none)
	for hovered in [false, true, false] {
		if hovered { document.set_hovered_node(target.as_node()) } else { document.set_hovered_node(none) }
		mut workspace := computer.acquire_matching_rule_set_workspace()
		mut attempts := PseudoClassBitmap{}
		rules := collect_matching_rules_with_storage(computer, abstract, .author, mut attempts, none, scope, workspace.arena)
		assert attempts.get(.hover)
		assert rules.len == if hovered { 33 } else { 0 }
		if hovered {
			for index, rule in expected { assert voidptr(rules[index].rule) == voidptr(rule) }
			$if prealloc { assert workspace.arena.contains(rules.data) }
		} else {
			assert rules.data == unsafe { nil }
			assert rules.cap == 0
		}
		workspace.finish()
		gc_collect()
	}
}
