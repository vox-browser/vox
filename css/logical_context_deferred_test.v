module css

import dom

// Prepared for the focused suite after the requested Brave performance gate.
fn logical_context_test_element(document &dom.Document, style string) dom.AbstractElement {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', style)
	return dom.AbstractElement.new(element, none)
}

fn logical_context_test_rule(text string) ScopedMatchingRule {
	mut parser := RuleSelectorParser.create(ParsingParams{}, text, 'utf-8')
	parser.defer_style_declarations = true
	sheet := parser.parse_as_css_stylesheet('https://example.test/style.css', none)
	rule := sheet.css_rules().item(0) or { panic('missing rule') }
	return ScopedMatchingRule{rule: &MatchingRule{rule: rule}}
}

fn test_physical_properties_still_compute_direction_and_writing_mode() {
	document := dom.Document.create(dom.url_about_blank())
	element := logical_context_test_element(document, 'direction:rtl;writing-mode:vertical-rl;margin-left:13px')
	computer := StyleComputer.new(document)
	rules := MatchingRuleSet{author_rules: [LayerMatchingRules{}]}
	assert !cascade_may_have_logical_aliases(element, rules)
	// The public context query must retain its own observable semantics.
	context := computer.compute_logical_alias_mapping_context(element, .normal, rules)
	assert context.direction == .rtl
	assert context.writing_mode == .vertical_rl
	computed := computer.compute_style(element)
	assert computed.direction() == .rtl
	assert computed.writing_mode() == .vertical_rl
	assert computed.property(.margin_left, .no)?.css_text == '13px'
}

fn test_logical_aliases_use_inherited_vertical_rtl_flow() {
	document := dom.Document.create(dom.url_about_blank())
	parent := logical_context_test_element(document, 'direction:rtl;writing-mode:vertical-rl')
	child := logical_context_test_element(document, 'margin-inline-start:17px; padding-block-start:9px')
	mut parent_node := parent.element().as_node()
	parent_node.append_child(child.element().as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	mut mutable_parent := parent
	mutable_parent.set_computed_properties(computed_properties_to_dom(computer.compute_style(parent)))
	assert cascade_may_have_logical_aliases(child, MatchingRuleSet{})
	computed := computer.compute_style(child)
	assert computed.property(.margin_bottom, .no)?.css_text == '17px'
	assert computed.property(.padding_right, .no)?.css_text == '9px'
}

fn test_lazy_logical_rules_in_each_cascade_origin_and_layer_keep_mapping() {
	document := dom.Document.create(dom.url_about_blank())
	element := logical_context_test_element(document, 'direction:rtl')
	rule := logical_context_test_rule('div { margin-inline-start: 19px !important; }')
	computer := StyleComputer.new(document)
	for origin in 0 .. 3 {
		mut rules := MatchingRuleSet{author_rules: [LayerMatchingRules{}]}
		if origin == 0 { rules.user_agent_rules = [rule] }
		if origin == 1 { rules.user_rules = [rule] }
		if origin == 2 { rules.author_rules << LayerMatchingRules{qualified_layer_name: 'layer' rules: [rule]} }
		assert cascade_may_have_logical_aliases(element, rules)
		context := computer.logical_alias_context_for_cascade(element, .normal, rules)
		assert context.direction == .rtl
		cascaded := computer.compute_cascaded_values(element, false, .normal, rules, context, [])
		assert cascaded.property(.margin_right)?.css_text == '19px'
	}
}

fn test_cssom_mutation_refreshes_alias_metadata_and_preserves_importance_mask() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('color', 'red', 'important')!
	assert !declaration_may_have_logical_aliases(declaration)
	assert declaration.typed_importance_mask_ == 2
	declaration.set_property('margin-inline-start', '7px', '')!
	assert declaration_may_have_logical_aliases(declaration)
	assert declaration.typed_importance_mask_ == 3
	declaration.remove_property('margin-inline-start')!
	assert !declaration_may_have_logical_aliases(declaration)
	assert declaration.typed_importance_mask_ == 2
}

fn test_unexpanded_variable_shorthand_and_pseudo_rules_stay_conservative() {
	mut declaration := CSSStyleProperties.create()
	declaration.properties << CSSStyleProperty{name: 'margin-inline' value: 'var(--gap)'}
	assert declaration_may_have_logical_aliases(declaration)
	document := dom.Document.create(dom.url_about_blank())
	base := logical_context_test_element(document, '')
	pseudo := dom.AbstractElement.new(base.element(), .before)
	rule := logical_context_test_rule('div::before { padding-inline-start: 11px; }')
	assert cascade_may_have_logical_aliases(pseudo, MatchingRuleSet{
		author_rules: [LayerMatchingRules{rules: [rule]}]
	})
	mut svg := document.create_element_ns('http://www.w3.org/2000/svg', 'rect') or { panic(err) }
	svg.set_attribute_value('width', '10')
	assert cascade_may_have_logical_aliases(dom.AbstractElement.new(svg, none), MatchingRuleSet{})
}

fn test_physical_html_presentational_hints_survive_fast_path() {
	document := dom.Document.create(dom.url_about_blank())
	mut cell := document.create_element_ns('http://www.w3.org/1999/xhtml', 'td') or { panic(err) }
	cell.set_attribute_value('width', '23')
	cell.set_attribute_value('bgcolor', '#112233')
	element := dom.AbstractElement.new(cell, none)
	assert !cascade_may_have_logical_aliases(element, MatchingRuleSet{})
	computer := StyleComputer.new(document)
	context := computer.logical_alias_context_for_cascade(element, .normal, MatchingRuleSet{})
	cascaded := computer.compute_cascaded_values(element, false, .normal, MatchingRuleSet{}, context, [])
	assert cascaded.property(.width)?.css_text == '23px'
	assert cascaded.property(.background_color)?.css_text == 'rgb(17, 34, 51)'
}
