module css

import dom

fn empty_cascade_test_elements() (&dom.Element, &dom.Element) {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }
	return parent, child
}

fn empty_cascade_test_data(value string) &dom.CSSCustomPropertyData_ {
	return dom.CSSCustomPropertyData_.create({
		'--accent': dom.CSSCustomProperty_{ value: &dom.CSSStyleValue_{ css_text: value } }
	}, none)
}

fn test_empty_custom_cascade_replaces_old_own_values_with_live_inheritance() {
	parent, child := empty_cascade_test_elements()
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	parent_data := empty_cascade_test_data('red')
	parent_abstract.set_custom_property_data(parent_data)
	child_abstract.set_custom_property_data(empty_cascade_test_data('blue'))
	rules := MatchingRuleSet{
		author_rules: [LayerMatchingRules{}]
	}
	install_custom_property_data_for_style(child_abstract, rules)
	assert child_abstract.custom_property_data()? == parent_data
	assert child_abstract.custom_property_data()?.get('--accent')?.css_text == 'red'
	parent_abstract.set_custom_property_data(none)
	install_custom_property_data_for_style(child_abstract, rules)
	assert child_abstract.custom_property_data() == none
}

fn test_empty_custom_cascade_keeps_inline_and_pseudo_ownership_distinct() {
	parent, mut child := empty_cascade_test_elements()
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	parent_abstract.set_custom_property_data(empty_cascade_test_data('green'))
	rules := MatchingRuleSet{
		author_rules: [LayerMatchingRules{}]
	}
	child.set_attribute_value('style', '--accent: blue; color: red')
	install_custom_property_data_for_style(child_abstract, rules)
	assert child_abstract.custom_property_data()?.get('--accent')?.css_text == 'blue'
	mut pseudo := dom.AbstractElement.new(child, dom.PseudoElement.before)
	install_custom_property_data_for_style(pseudo, rules)
	assert pseudo.custom_property_data()?.get('--accent')?.css_text == 'blue'
	child.set_attribute_value('style', 'color: red')
	install_custom_property_data_for_style(child_abstract, rules)
	assert child_abstract.custom_property_data()?.get('--accent')?.css_text == 'green'
	install_custom_property_data_for_style(pseudo, rules)
	assert pseudo.custom_property_data()?.get('--accent')?.css_text == 'green'
}

fn test_empty_custom_cascade_preserves_animation_overlay_when_base_changes() {
	parent, child := empty_cascade_test_elements()
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	parent_abstract.set_custom_property_data(empty_cascade_test_data('red'))
	animated := {
		'--animated': dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{
				css_text: '10px'
			}
		}
	}
	child_abstract.set_custom_property_data(dom.CSSCustomPropertyData_.create_animation_overlay(animated,
		empty_cascade_test_data('old')))
	rules := MatchingRuleSet{
		author_rules: [LayerMatchingRules{}, LayerMatchingRules{}]
	}
	install_custom_property_data_for_style(child_abstract, rules)
	data := child_abstract.custom_property_data()?
	assert data.is_animation_overlay()
	assert data.get('--animated')?.css_text == '10px'
	assert data.get('--accent')?.css_text == 'red'
	parent_abstract.set_custom_property_data(empty_cascade_test_data('green'))
	gc_collect()
	install_custom_property_data_for_style(child_abstract, rules)
	assert child_abstract.custom_property_data()?.get('--accent')?.css_text == 'green'
	assert child_abstract.custom_property_data()?.get('--animated')?.css_text == '10px'
}
