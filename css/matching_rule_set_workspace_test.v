module css

import dom
import platform

fn rule_workspace_fixture() (&dom.Document, &dom.Element, &StyleComputer, &StyleScope) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut root := document.create_element('html') or { panic(err) }
	mut target := document.create_element('article') or { panic(err) }
	target.set_attribute_value('class', 'story')
	target.set_attribute_value('style', '--own:12px;margin-inline-start:var(--own)')
	mut doc_node := document.as_node()
	doc_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '@layer first,second;@layer first{.story{color:red;direction:rtl}}@layer second{article{opacity:.6}}.story::before{content:"before"}.story:hover{color:green}.story{padding:3px}')
	computer := StyleComputer.new(document)
	scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	return document, target, computer, scope
}

fn rule_workspace_snapshot(rules MatchingRuleSet) []string {
	mut result := []string{}
	for rule in rules.user_agent_rules { result << 'ua:${rule.rule.selector.serialize()}:${rule.rule.rule_index}' }
	for rule in rules.user_rules { result << 'user:${rule.rule.selector.serialize()}:${rule.rule.rule_index}' }
	for layer in rules.author_rules {
		result << 'layer:${layer.qualified_layer_name}'
		for rule in layer.rules { result << '${rule.rule.selector.serialize()}:${rule.rule.rule_index}:${rule.scope_proximity}' }
	}
	return result
}

fn test_matching_rule_workspace_preserves_layers_pseudo_rules_and_attempted_metadata() {
	document, target, computer, scope := rule_workspace_fixture()
	for pseudo in [?dom.PseudoElement(none), ?dom.PseudoElement(dom.PseudoElement.before), ?dom.PseudoElement(dom.PseudoElement.after)] {
		abstract := dom.AbstractElement.new(target, pseudo)
		mode := if pseudo == none { ComputeStyleMode.normal } else { ComputeStyleMode.create_pseudo_element_style_if_needed }
		mut expected_attempts := PseudoClassBitmap{}
		mut expected_did_match := false
		expected := computer.build_matching_rule_set(abstract, mut expected_attempts, &expected_did_match, mode, scope)
		mut workspace := computer.acquire_matching_rule_set_workspace()
		mut actual_attempts := PseudoClassBitmap{}
		mut actual_did_match := false
		actual := build_matching_rule_set_with_storage(computer, abstract, mut actual_attempts, &actual_did_match, mode, scope, workspace.arena)
		assert rule_workspace_snapshot(actual) == rule_workspace_snapshot(expected)
		assert actual_attempts == expected_attempts
		assert actual_did_match == expected_did_match
		$if prealloc {
			assert workspace.arena.contains(actual.author_rules.data)
			if actual.user_agent_rules.len > 0 { assert workspace.arena.contains(actual.user_agent_rules.data) }
		}
		workspace.finish()
		assert rule_workspace_snapshot(expected).len > 0
	}
	document.release_native_storage()
}

fn test_matching_rule_workspaces_preserve_outer_results_during_nested_style_queries() {
	document, target, computer, scope := rule_workspace_fixture()
	abstract := dom.AbstractElement.new(target, none)
	mut outer := computer.acquire_matching_rule_set_workspace()
	mut attempts := PseudoClassBitmap{}
	mut did_match := false
	rules := build_matching_rule_set_with_storage(computer, abstract, mut attempts, &did_match, .normal, scope, outer.arena)
	expected := rule_workspace_snapshot(rules)
	style := computer.compute_style(abstract)
	assert style.property(.margin_right, .no)?.css_text == '12px'
	assert style.direction() == .rtl
	assert style.opacity() == f32(.6)
	assert rule_workspace_snapshot(rules) == expected
	$if prealloc {
		assert computer.matching_rule_sets_.depth == 1
		assert computer.matching_rule_sets_.arenas.len >= 2
	}
	outer.finish()
	// Selected values and custom-property data must outlive every matched list.
	assert style.property(.margin_right, .no)?.css_text == '12px'
	assert abstract.custom_property_data()?.get_property('--own')?.value.css_text == '12px'
	document.release_native_storage()
}

fn test_matching_rule_lists_do_not_accumulate_in_the_document_arena() {
	$if !prealloc { return }
	mut document, target, computer, scope := rule_workspace_fixture()
	abstract := dom.AbstractElement.new(target, none)
	mut document_scope := document.enter_native_storage()
	mut attempts := PseudoClassBitmap{}
	mut did_match := false
	mut warm := computer.acquire_matching_rule_set_workspace()
	_ = build_matching_rule_set_with_storage(computer, abstract, mut attempts, &did_match, .normal, scope, warm.arena)
	warm.finish()
	expected_layer_count := computer.build_matching_rule_set(abstract, mut attempts, &did_match, .normal, scope).author_rules.len
	before := document.native_storage().arena.usage().used
	for _ in 0 .. 64 {
		mut workspace := computer.acquire_matching_rule_set_workspace()
		rules := build_matching_rule_set_with_storage(computer, abstract, mut attempts, &did_match, .normal, scope, workspace.arena)
		assert rules.author_rules.len == expected_layer_count
		workspace.finish()
	}
	actual := document.native_storage().arena.usage().used - before
	for _ in 0 .. 64 { _ = computer.build_matching_rule_set(abstract, mut attempts, &did_match, .normal, scope) }
	reference := document.native_storage().arena.usage().used - before - actual
	assert reference > 16 * 1024
	assert actual < reference / 4, '${actual} retained versus ${reference}'
	document_scope.finish()
	document.release_native_storage()
	for arena in computer.matching_rule_sets_.arenas { assert arena.usage().used == 0 }
}

fn test_public_matching_rule_results_survive_internal_workspace_reuse() {
	document, target, computer, scope := rule_workspace_fixture()
	mut attempts := PseudoClassBitmap{}
	mut did_match := false
	abstract := dom.AbstractElement.new(target, none)
	public_rules := computer.build_matching_rule_set(abstract, mut attempts, &did_match, .normal, scope)
	expected := rule_workspace_snapshot(public_rules)
	for _ in 0 .. 3 {
		_ = computer.compute_style(abstract)
		gc_collect()
		assert rule_workspace_snapshot(public_rules) == expected
	}
	document.release_native_storage()
}
