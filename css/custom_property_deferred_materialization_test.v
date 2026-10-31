module css

import dom

fn deferred_property_test_bridge(tokens []ComponentValue) &dom.CSSStyleValue_ {
	return custom_property_bridge_value(dom_style_value_from_value_logic(StyleValue(
		UnresolvedStyleValue.create_with_presence(tokens, SubstitutionFunctionsPresence{}, none))))
}

fn test_deferred_custom_property_comparison_preserves_typed_token_equality() {
	tokens := parse_component_values_for_value_logic('red')
	mut tainted := tokens.clone()
	tainted[0].set_attr_tainted()
	mut moved := tokens.clone()
	mut token := moved[0].token()
	token.start_position_.column++
	moved[0] = ComponentValue.from_token(token)
	opaque := &dom.StyleValue{css_text: 'red'}
	parents := [
		deferred_property_test_bridge(tokens),
		deferred_property_test_bridge(tainted),
		deferred_property_test_bridge(moved),
		deferred_property_test_bridge(parse_component_values_for_value_logic('blue')),
		custom_property_bridge_value(dom_style_value_from_value_logic(StyleValue(
			GuaranteedInvalidStyleValue.create()))),
		custom_property_bridge_value(dom_style_value_from_value_logic(StyleValue(
			UnresolvedStyleValue.create_with_presence(tokens, SubstitutionFunctionsPresence{var: true},
				'different authored text')))),
		&dom.CSSStyleValue_{css_text: 'red', css_value_handle: voidptr(opaque)},
	]
	values := [
		ComputedCustomPropertyValue{kind: .substituted, tokens: tokens},
		ComputedCustomPropertyValue{kind: .substituted, tokens: tainted},
		ComputedCustomPropertyValue{kind: .substituted, tokens: moved},
		ComputedCustomPropertyValue{kind: .guaranteed_invalid},
		ComputedCustomPropertyValue{existing_value: parse_custom_property_value('red')},
		ComputedCustomPropertyValue{existing_value: opaque},
	]
	for value in values {
		materialized := custom_property_bridge_value(value.materialize())
		for parent in parents {
			actual := value.equals_typed_bridge(parent) or { panic('typed comparison missing') }
			assert actual == custom_property_bridge_values_equal(parent, materialized)
		}
	}
	plain := ComputedCustomPropertyValue{kind: .substituted, tokens: tokens}
	assert plain.equals_typed_bridge(parents[0])?
	assert !plain.equals_typed_bridge(parents[1])?
	assert !plain.equals_typed_bridge(parents[2])?
	assert plain.equals_typed_bridge(parents[5])?
}

fn test_deferred_custom_property_keeps_untyped_text_fallback_and_retained_importance() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	parent := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	parent_element := dom.AbstractElement.new(parent, none)
	child_element := dom.AbstractElement.new(child, none)
	parent_data := dom.CSSCustomPropertyData_.create({
		'--base': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('red'))}
		'--same': dom.CSSCustomProperty_{value: &dom.CSSStyleValue_{css_text: 'red'}}
		'--different': dom.CSSCustomProperty_{value: &dom.CSSStyleValue_{css_text: 'blue'}}
		'--invalid': dom.CSSCustomProperty_{value: &dom.CSSStyleValue_{guaranteed_invalid: true}}
	}, none)
	parent_element.set_custom_property_data(parent_data)
	child_element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--same': dom.CSSCustomProperty_{important: true, value: custom_property_bridge_value(parse_custom_property_value('var(--base)'))}
		'--different': dom.CSSCustomProperty_{important: true, value: custom_property_bridge_value(parse_custom_property_value('var(--base)'))}
		'--invalid': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--missing)'))}
	}, parent_data))
	probe := ComputedCustomPropertyValue{kind: .substituted, tokens: parse_component_values_for_value_logic('red')}
	assert probe.equals_typed_bridge(parent_data.get('--same')?) == none
	computer := StyleComputer.new(document)
	mut computed := ComputedProperties.new()
	computer.compute_custom_properties(mut computed, child_element)
	result := child_element.custom_property_data()?
	assert result.get('--same')? == parent_data.get('--same')?
	assert result.get('--invalid')? == parent_data.get('--invalid')?
	changed := result.get_property('--different')?
	assert changed.important
	assert changed.value.css_text == 'red'
	assert changed.value.css_value_handle != unsafe { nil }
	assert changed.value != parent_data.get('--different')?
	gc_collect()
	assert result.get('--different')?.css_text == 'red'
}

fn test_deferred_custom_property_materialization_preserves_initial_and_inherited_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	register_property_for_document(mut document, PropertyDefinition{
		name: '--registered'
		syntax: '*'
		inherits: true
		initial_value: 'green'
	})!
	parent := document.create_element('div')!
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	parent_element := dom.AbstractElement.new(parent, none)
	child_element := dom.AbstractElement.new(child, none)
	inherited := parse_custom_property_value('blue')
	parent_data := dom.CSSCustomPropertyData_.create({
		'--inherited': dom.CSSCustomProperty_{value: custom_property_bridge_value(inherited)}
	}, none)
	parent_element.set_custom_property_data(parent_data)
	child_element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--inherited': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('inherit'))}
		'--registered': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('initial'))}
		'--alias': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--registered)'))}
	}, parent_data))
	assert StyleComputer.compute_value_of_custom_property(child_element, '--inherited') == inherited
	assert StyleComputer.compute_value_of_custom_property(child_element, '--registered').css_text == 'green'
	assert StyleComputer.compute_value_of_custom_property(child_element, '--alias').css_text == 'green'
	missing := StyleComputer.compute_value_of_custom_property(child_element, '--missing')
	assert typed_style_value_logic_from_dom(missing)? is GuaranteedInvalidStyleValue
	assert missing.css_text == ''
}

fn test_deferred_custom_property_resolution_preserves_cycle_marking_and_cleanup() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	target := document.create_element('div')!
	element := dom.AbstractElement.new(target, none)
	element.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--a': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--b)'))}
		'--b': dom.CSSCustomProperty_{value: custom_property_bridge_value(parse_custom_property_value('var(--a)'))}
	}, none))
	mut contexts := GuardedSubstitutionContexts{}
	resolved := resolve_computed_custom_property_value(element, '--a', mut contexts)
	assert typed_style_value_logic_from_dom(resolved.materialize())? is GuaranteedInvalidStyleValue
	assert contexts.contexts.len == 0
	mut enclosing := SubstitutionContext{dependency_type: .property, first: '--a'}
	contexts.guard(mut enclosing)
	cyclic := resolve_computed_custom_property_value(element, '--a', mut contexts)
	assert typed_style_value_logic_from_dom(cyclic.materialize())? is GuaranteedInvalidStyleValue
	assert contexts.contexts.len == 1
	assert contexts.contexts[0].is_cyclic
	contexts.unguard(enclosing)
	assert contexts.contexts.len == 0
}
