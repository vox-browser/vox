module css

import dom

fn parsed_style_query(source string) &BooleanExpression {
	mut parser := Parser.from_css_text(source)
	mut tokens := SupportsTokenStream.from_values(parser.component_values)
	query := parser.parse_style_query(mut tokens, .false_) or {
		panic('style query did not parse: ${source}')
	}
	tokens.discard_whitespace()
	assert !tokens.has_next_token()
	return query
}

fn style_query_test_tree(css_text string) (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	parent.set_attribute_value('class', 'parent')
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic('${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, css_text)
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	return document, parent, target
}

fn evaluate_parsed_style_query(query &BooleanExpression, element &dom.Element) MatchResult {
	return query.evaluate(BooleanExpressionEvaluationContext{
		document:            element.document()
		style_query_element: dom.AbstractElement.new(element, none)
	})
}

fn test_style_features_parse_serialize_and_collect_requirements() {
	boolean := parsed_style_query('--theme')
	assert boolean.to_string() == '--theme'
	mut requirements := ContainerQueryFeatureRequirements{}
	boolean.collect_container_query_feature_requirements(mut requirements)
	assert requirements.requires_style_container
	assert !requirements.has_unknown_or_unsupported_feature

	plain := parsed_style_query('--theme: dark')
	assert plain.to_string() == '--theme: dark'
	logical := parsed_style_query('(--theme: dark) and (not (--disabled))')
	assert logical.to_string() == '(--theme: dark) and (not (--disabled))'

	ordinary_property := parsed_style_query('color: red')
	assert ordinary_property.to_string() == 'color: red'
	important := parsed_style_query('--theme: dark !important')
	assert important.to_string() == '--theme: dark'
	nested_comparison := parsed_style_query('--theme: token(1 > 0)')
	assert nested_comparison.to_string() == '--theme: token(1 > 0)'

	for invalid in ['unknown-property', '--theme: 1 < 2 > 3', '10px', ''] {
		mut parser := Parser.from_css_text(invalid)
		mut tokens := SupportsTokenStream.from_values(parser.component_values)
		assert parser.parse_style_query(mut tokens, .false_) == none, invalid
	}
}

fn test_style_features_evaluate_unregistered_custom_properties_and_css_wide_keywords() {
	_, _, target := style_query_test_tree('.parent { --theme: dark; } .target { --empty: initial; }')

	assert evaluate_parsed_style_query(parsed_style_query('--theme'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: dark'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: light'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: inherit'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: unset'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: initial'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('--missing'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('--empty'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('--theme: revert'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('color: black'), target) == .false_
}

fn test_style_features_compare_registered_typed_values() {
	mut document, _, target := style_query_test_tree('.target { --accent: #ff0000; --distance: 16px; }')
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--accent'
		syntax:        '<color>'
		inherits:      false
		initial_value: 'red'
	}) or { panic('${err}') }
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--distance'
		syntax:        '<length>'
		inherits:      false
		initial_value: '0px'
	}) or { panic('${err}') }
	document.needs_full_style_update = true
	document.update_style()

	assert evaluate_parsed_style_query(parsed_style_query('--accent: rgb(255 0 0)'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--accent: initial'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--accent'), target) == .false_
	assert evaluate_parsed_style_query(parsed_style_query('--distance: 1pc'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--distance: red'), target) == .false_
}

fn test_style_feature_marks_an_existing_property_substitution_context_cyclic() {
	_, _, target := style_query_test_tree('.target { --theme: dark; }')
	mut guarded_contexts := GuardedSubstitutionContexts{}
	mut outer_context := SubstitutionContext{
		dependency_type: .property
		first:           '--theme'
	}
	guarded_contexts.guard(mut outer_context)
	query := parsed_style_query('--theme: dark')
	result := query.evaluate(BooleanExpressionEvaluationContext{
		document:            target.document()
		style_query_element: dom.AbstractElement.new(target, none)
		guarded_contexts:    &guarded_contexts
	})
	assert result == .false_
	assert guarded_contexts.is_marked_cyclic(outer_context)
}

fn test_if_function_evaluates_style_queries_for_the_styled_element() {
	_, _, target := style_query_test_tree('.target {
		--theme: dark;
		color: if(style(--theme: dark): red; else: blue);
		width: if(style(--missing): 10px; else: 20px);
	}')
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	assert computed_value_for(target, .width) or { '' } == '20px'
}

fn test_if_style_query_cycle_makes_the_custom_property_invalid() {
	_, _, target := style_query_test_tree('.target {
		--theme: if(style(--theme: dark): red; else: blue);
		color: var(--theme, green);
	}')
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 128, 0)'
}

fn test_style_features_compare_calculated_registered_values() {
	mut document, _, target := style_query_test_tree('.target {
		--number: calc(1 + 2);
		--length: calc(1em + 14px);
		font-size: 16px;
	}')
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--number'
		syntax:        '<number>'
		inherits:      false
		initial_value: '0'
	}) or { panic('${err}') }
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--length'
		syntax:        '<length>'
		inherits:      false
		initial_value: '0px'
	}) or { panic('${err}') }
	document.needs_full_style_update = true
	document.update_style()

	assert evaluate_parsed_style_query(parsed_style_query('--number: 3'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--number: calc(1 + 2)'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--length: 30px'), target) == .true_
	assert evaluate_parsed_style_query(parsed_style_query('--length: calc(10px + 20px)'), target) == .true_
}

fn test_style_features_compare_attr_tainted_registered_values() {
	mut document, _, mut target := style_query_test_tree('.target {
		--length: attr(data-length type(<length>));
		color: if(style(--length: 30px): red; else: blue);
	}')
	target.set_attribute_value('data-length', '30px')
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--length'
		syntax:        '<length>'
		inherits:      false
		initial_value: '0px'
	}) or { panic('${err}') }
	document.needs_full_style_update = true
	document.update_style()

	assert evaluate_parsed_style_query(parsed_style_query('--length: 30px'), target) == .true_
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}

fn test_style_ranges_parse_serialize_and_collect_requirements() {
	for source in [
		'5 > 3',
		'0 = 0px',
		'--length >= calc(1em + 2px)',
		'3 < --number <= 5',
		'10px <= calc(10em + 20em) < 400px',
	] {
		range := parsed_style_query(source)
		assert range.to_string() == source
		assert range.style_feature_is_range
		mut requirements := ContainerQueryFeatureRequirements{}
		range.collect_container_query_feature_requirements(mut requirements)
		assert requirements.requires_style_container
		assert !requirements.has_unknown_or_unsupported_feature
		assert range.evaluate(BooleanExpressionEvaluationContext{}) == .unknown
	}

	for invalid in [
		'1 < 2 > 3',
		'1 = 2 = 3',
		'--value: 1 < 2 > 3',
		'> 3',
		'3 <',
	] {
		mut parser := Parser.from_css_text(invalid)
		mut tokens := SupportsTokenStream.from_values(parser.component_values)
		assert parser.parse_style_query(mut tokens, .false_) == none, invalid
	}
}

fn test_style_ranges_evaluate_numeric_values_and_custom_properties() {
	mut document, _, mut target := style_query_test_tree('.target {
		font-size: 16px;
		--x: 5;
		--y: 3;
		--length: 11px;
		--angle: 1deg;
		--time: 1s;
		--resolution: 96dpi;
		--registered-length: calc(1em + 14px);
		--attr-length: attr(data-length type(<length>));
		color: if(style(--attr-length >= 30px): red; else: blue);
		width: if(style(calc(var(--x) + 1) >= var(--y)): 10px; else: 20px);
	}')
	target.set_attribute_value('data-length', '30px')
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--registered-length'
		syntax:        '<length>'
		inherits:      false
		initial_value: '0px'
	}) or { panic('${err}') }
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--attr-length'
		syntax:        '<length>'
		inherits:      false
		initial_value: '0px'
	}) or { panic('${err}') }
	document.needs_full_style_update = true
	document.update_style()

	for query in [
		'5 > 3',
		'0 = 0',
		'0 = 0px',
		'0 < 3px',
		'5.5 > 3.3',
		'10em > 3px',
		'3turn > 3deg',
		'3% >= 3%',
		'3s > 3ms',
		'3khz > 30hz',
		'3dppx > 96dpi',
		'--x <= 5',
		'--x >= --y',
		'--length > 3px',
		'--angle < 1turn',
		'--time <= 1000ms',
		'3dppx > --resolution',
		'--x >= calc(3 + 2)',
		'--registered-length >= 30px',
		'--attr-length >= 30px',
		'10px <= 10px < 11px',
		'3 < --x <= 5',
	] {
		assert evaluate_parsed_style_query(parsed_style_query(query), target) == .true_, query
	}

	for query in [
		'0 = 0%',
		'3px > 3',
		'3em > 3deg',
		'1px >= 1%',
		'--length > 3',
		'--x + 1 >= --y',
		'--x >= --y + 1',
		'--x >= --y > --x',
	] {
		assert evaluate_parsed_style_query(parsed_style_query(query), target) == .false_, query
	}

	mut did_evaluate_attr_tainted_style_query := false
	assert parsed_style_query('--attr-length >= 30px').evaluate(BooleanExpressionEvaluationContext{
		document:                              document
		style_query_element:                   dom.AbstractElement.new(target, none)
		did_evaluate_attr_tainted_style_query: &did_evaluate_attr_tainted_style_query
	}) == .true_
	assert did_evaluate_attr_tainted_style_query
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	assert computed_value_for(target, .width) or { '' } == '10px'
}

fn test_style_range_cycle_marks_existing_property_context_cyclic() {
	_, _, target := style_query_test_tree('.target { --x: 5; }')
	mut guarded_contexts := GuardedSubstitutionContexts{}
	mut outer_context := SubstitutionContext{
		dependency_type: .property
		first:           '--x'
	}
	guarded_contexts.guard(mut outer_context)
	result := parsed_style_query('--x > 3').evaluate(BooleanExpressionEvaluationContext{
		document:            target.document()
		style_query_element: dom.AbstractElement.new(target, none)
		guarded_contexts:    &guarded_contexts
	})
	assert result == .false_
	assert guarded_contexts.is_marked_cyclic(outer_context)
}
