module css

import dom

fn environment_equivalence_bridge(tokens []ComponentValue, presence SubstitutionFunctionsPresence,
	original ?string, base ?string) &dom.CSSStyleValue_ {
	mut value := dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create_with_presence(
		tokens, presence, original)))
	value.base_url = base
	return custom_property_bridge_value(value)
}

fn test_custom_environment_equivalence_accepts_distinct_complete_unresolved_payloads() {
	tokens := parse_component_values_for_value_logic('url(relative.png)')
	left := environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{}, none,
		'https://same.example/styles/')
	right := environment_equivalence_bridge(tokens.clone(), SubstitutionFunctionsPresence{}, none,
		'https://same.example/styles/')
	assert left.css_value_handle != right.css_value_handle
	for _ in 0 .. 3 {
		gc_collect()
		assert custom_property_environment_values_equivalent(left, right)
		assert custom_property_environment_values_equivalent(left, left)
	}
	previous := dom.CSSCustomPropertyData_.create({'--image': dom.CSSCustomProperty_{value:left}}, none)
	current := dom.CSSCustomPropertyData_.create({'--image': dom.CSSCustomProperty_{value:right}}, none)
	assert reuse_unchanged_custom_property_environment(previous, current)? == previous
}

fn test_custom_environment_equivalence_rejects_context_serialization_presence_and_taint_changes() {
	tokens := parse_component_values_for_value_logic('red')
	left := environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{}, none,
		'https://same.example/')
	mut tainted := tokens.clone()
	tainted[0].set_attr_tainted()
	for right in [
		environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{}, none, none),
		environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{}, none, 'https://different.example/'),
		environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{}, 'red', 'https://same.example/'),
		environment_equivalence_bridge(tokens, SubstitutionFunctionsPresence{var:true}, none, 'https://same.example/'),
		environment_equivalence_bridge(tainted, SubstitutionFunctionsPresence{}, none, 'https://same.example/'),
		environment_equivalence_bridge(parse_component_values_for_value_logic('blue'), SubstitutionFunctionsPresence{}, none, 'https://same.example/'),
	] {
		assert !custom_property_environment_values_equivalent(left, right)
	}
	for changed in [
		&dom.CSSStyleValue_{...left,css_text:'different'},
		&dom.CSSStyleValue_{...left,guaranteed_invalid:true},
	] { assert !custom_property_environment_values_equivalent(left, changed) }
	mut retained := dom_style_value_from_custom_property_bridge(left)?
	right_dom := &dom.StyleValue{...retained,css_text:'different DOM serialization'}
	right := &dom.CSSStyleValue_{...left,css_value_handle:voidptr(right_dom)}
	assert !custom_property_environment_values_equivalent(left, right)
	assert !custom_property_environment_values_equivalent(left, &dom.CSSStyleValue_{css_text:left.css_text})
}

fn test_custom_environment_equivalence_keeps_other_distinct_types_and_overlays_separate() {
	first := custom_property_bridge_value(dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(7))))
	second := custom_property_bridge_value(dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(7))))
	assert custom_property_bridge_values_equal(first, second)
	assert !custom_property_environment_values_equivalent(first, second)
	base := dom.CSSCustomPropertyData_.create({'--value': dom.CSSCustomProperty_{value:first}}, none)
	left := dom.CSSCustomPropertyData_.create_animation_overlay({'--alias': dom.CSSCustomProperty_{value:first}}, base)
	right := dom.CSSCustomPropertyData_.create_animation_overlay({'--alias': dom.CSSCustomProperty_{value:first}}, base)
	assert reuse_unchanged_custom_property_environment(left, right)? == right
}

fn test_full_style_pass_reuses_fresh_resolved_aliases_and_replaces_changed_inheritance() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	add_document_author_style_sheet(document,
		'html{--base:red;--alias:var(--base);--a:1;--b:2;--c:3;--d:4;--e:5;--f:6;--g:7;--h:8;--i:9}span{color:var(--alias)}')
	css_style_computer_for(document)
	document.set_needs_full_style_update(true)
	document.update_style()
	root_abstract := dom.AbstractElement.new(root, none)
	child_abstract := dom.AbstractElement.new(child, none)
	initial := root_abstract.custom_property_data()?
	assert computed_value_for(child, .color)? == 'rgb(255, 0, 0)'
	for _ in 0 .. 3 {
		gc_collect()
		document.set_needs_full_style_update(true)
		document.update_style()
		assert root_abstract.custom_property_data()? == initial
		assert child_abstract.custom_property_data()? == initial
	}
	root.set_attribute_value('style', '--base:blue')
	document.update_style()
	changed := root_abstract.custom_property_data()?
	assert changed != initial
	assert child_abstract.custom_property_data()? == changed
	assert computed_value_for(child, .color)? == 'rgb(0, 0, 255)'
	document.set_needs_full_style_update(true)
	document.update_style()
	assert root_abstract.custom_property_data()? == changed
}
