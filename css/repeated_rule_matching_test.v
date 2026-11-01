module css

import dom

fn repeated_rule_fixture() (&dom.Document, &dom.Element, &StyleComputer, &StyleScope) {
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

fn repeated_rule_snapshot(rules MatchingRuleSet) []string {
	mut result := []string{}
	for rule in rules.user_agent_rules { result << 'ua:${rule.rule.selector.serialize()}:${rule.rule.rule_index}' }
	for rule in rules.user_rules { result << 'user:${rule.rule.selector.serialize()}:${rule.rule.rule_index}' }
	for layer in rules.author_rules {
		result << 'layer:${layer.qualified_layer_name}'
		for rule in layer.rules { result << '${rule.rule.selector.serialize()}:${rule.rule.rule_index}:${rule.scope_proximity}' }
	}
	return result
}

fn repeated_rule_element(document &dom.Document, tag string, class_name string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	element.set_attribute_value('class', class_name)
	return element
}

fn repeated_rule_append(parent &dom.Node, child &dom.Element) {
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(child.as_node()) or { panic(err) }
}


fn test_repeated_rule_matches_preserve_order_pseudo_rules_and_attempted_state_metadata() {
	mut document, target, computer, scope := repeated_rule_fixture()
	defer { document.release_native_storage() }
	add_document_author_style_sheet(document,
		'.story:hover{color:red}.story:hover{padding:2px}.story{height:3px}.story{width:4px}.story::before{color:blue}.story::before{padding:1px}')
	for pseudo in [?dom.PseudoElement(none), ?dom.PseudoElement(dom.PseudoElement.before)] {
		abstract := dom.AbstractElement.new(target, pseudo)
		mode := if pseudo == none { ComputeStyleMode.normal } else { ComputeStyleMode.create_pseudo_element_style_if_needed }
		mut attempts := PseudoClassBitmap{}
		mut did_match := false
		actual := computer.build_matching_rule_set(abstract, mut attempts, &did_match, mode, scope)
		mut graphs := []&SelectorData{}
		for layer in actual.author_rules {
			for rule in layer.rules {
				if rule.rule.selector.data_.repeated_rule_parse {
					graphs << rule.rule.selector.data_
				}
			}
		}
		assert graphs.len >= 2
		for mut graph in graphs { graph.repeated_rule_parse = false }
		mut oracle_attempts := PseudoClassBitmap{}
		mut oracle_did_match := false
		oracle := computer.build_matching_rule_set(abstract, mut oracle_attempts, &oracle_did_match, mode, scope)
		assert repeated_rule_snapshot(actual) == repeated_rule_snapshot(oracle)
		assert attempts == oracle_attempts
		assert did_match == oracle_did_match
		for mut graph in graphs { graph.repeated_rule_parse = true }
	}
}

fn test_repeated_selector_matches_expire_between_style_updates_and_keep_has_involvement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	css_style_computer_for(document)
	root := repeated_rule_element(document, 'html', '')
	anchor := repeated_rule_element(document, 'section', 'anchor')
	trigger := repeated_rule_element(document, 'button', 'trigger')
	target := repeated_rule_element(document, 'span', 'story')
	repeated_rule_append(document.as_node(), root)
	repeated_rule_append(root.as_node(), anchor)
	repeated_rule_append(anchor.as_node(), trigger)
	repeated_rule_append(anchor.as_node(), target)
	add_document_author_style_sheet(document,
		'.story{color:blue}.anchor:has(.trigger:hover) .story{color:red}.anchor:has(.trigger:hover) .story{padding:3px}')
	document.update_style()
	assert target.affected_by_pseudo_class(.hover)
	assert computed_value_for(target, .color)? == 'rgb(0, 0, 255)'
	document.set_hovered_node(trigger.as_node())
	document.update_style()
	assert computed_value_for(target, .color)? == 'rgb(255, 0, 0)'
	document.set_hovered_node(none)
	document.update_style()
	assert computed_value_for(target, .color)? == 'rgb(0, 0, 255)'
}

fn test_repeated_match_sheet_identity_keeps_default_namespace_decisions_separate() {
	document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	first := parse_css_stylesheet_with_parser('@namespace url("http://www.w3.org/1999/xhtml");div{}', none)
	second := parse_css_stylesheet_with_parser('@namespace url("http://www.w3.org/2000/svg");div{}', none)
	selector := selector_from_text('div')
	mut graph := unsafe { &SelectorData(selector.data_) }
	graph.repeated_rule_parse = true
	mut memo := map[u64]RepeatedRuleMatch{}
	mut first_context := MatchContext{style_sheet_for_rule:first}
	mut second_context := MatchContext{style_sheet_for_rule:second}
	assert match_repeated_rule_selector(selector, element, none, mut first_context, mut memo, unsafe { nil })
	assert !match_repeated_rule_selector(selector, element, none, mut second_context, mut memo, unsafe { nil })
}
