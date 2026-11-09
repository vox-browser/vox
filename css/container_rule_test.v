module css

import dom

struct ContainerRuleVisitCollector {
mut:
	types []CSSRuleType
}

fn parsed_single_container_query(source string) &ContainerQuery {
	rule := parse_css_rule_with_params(ParsingParams{}, '@container ${source} {}') or {
		panic('container rule did not parse: ${source}')
	}
	assert rule.container_conditions.len == 1
	return rule.container_conditions[0].container_query or {
		panic('container query is missing: ${source}')
	}
}

fn size_query_test_tree(container_style string, width f64, height f64, has_geometry bool) (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut container := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	container.set_attribute_value('style', container_style)
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	mut root := document.create_element('html') or { panic(err) }
	document_node.append_child(root.as_node()) or { panic(err) }
	root.as_node().append_child(container.as_node()) or { panic(err) }
	mut container_node := container.as_node()
	container_node.append_child(subject.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(document)
	container_computed := computer.compute_style(dom.AbstractElement.new(container, none))
	container.set_computed_properties(none, computed_properties_to_dom(container_computed))
	container_node.set_layout_node(&dom.LayoutNode{
		dom_node_: container.as_node()
		has_geometry_: has_geometry
		content_width_: width
		content_height_: height
	})
	return document, container, subject
}

fn test_container_rule_cssom_condition_accessors_and_serialization() {
	query := ContainerQuery.create(BooleanExpression.create_general_enclosed('(width > 10px)', .false_))
	child := CSSRule.create(.keyframes)
	rule := CSSRule.create_container([
		ContainerRuleCondition{
			container_name: 'card'
			container_query: query
		},
	], CSSRuleList.create([child]))

	assert rule.class_name() == 'CSSContainerRule'
	assert rule.container_name() == 'card'
	assert rule.container_query() == '(width > 10px)'
	assert rule.condition_text() == 'card (width > 10px)'
	assert rule.container_conditions_for_bindings() == [CSSContainerCondition{
		name: 'card'
		query: '(width > 10px)'
	}]
	assert rule.css_text() == '@container card (width > 10px) {\n  @keyframes "" { }\n}'
}

fn test_container_query_collects_unknown_feature_requirements_recursively() {
	unknown := BooleanExpression.create_general_enclosed('(future-feature: enabled)', .false_)
	condition := BooleanExpression.create_not(BooleanExpression.create_in_parens(unknown))
	query := ContainerQuery.create(condition)

	assert query.feature_requirements.has_unknown_or_unsupported_feature
	assert !query.contains_size_feature()
	assert !query.contains_style_feature()

	known_constant := ContainerQuery.create(BooleanExpression.create_constant(.true_))
	assert !known_constant.feature_requirements.has_unknown_or_unsupported_feature
}

fn test_container_query_selects_a_named_flat_tree_ancestor() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut outer := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	outer.set_attribute_value('style', 'container-name: outer')
	mut inner := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	inner.set_attribute_value('style', 'container-name: card')
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(outer.as_node()) or { panic('${err}') }
	mut outer_node := outer.as_node()
	outer_node.append_child(inner.as_node()) or { panic('${err}') }
	mut inner_node := inner.as_node()
	inner_node.append_child(subject.as_node()) or { panic('${err}') }

	computer := StyleComputer.new(document)
	outer_style := computer.compute_style(dom.AbstractElement.new(outer, none))
	outer.set_computed_properties(none, computed_properties_to_dom(outer_style))
	inner_style := computer.compute_style(dom.AbstractElement.new(inner, none))
	inner.set_computed_properties(none, computed_properties_to_dom(inner_style))

	query := ContainerQuery.create(BooleanExpression.create_constant(.true_))
	abstract_subject := dom.AbstractElement.new(subject, none)
	assert query.evaluate(abstract_subject, none) == .true_
	assert query.evaluate(abstract_subject, 'card') == .true_
	assert query.evaluate(abstract_subject, 'outer') == .true_
	assert query.evaluate(abstract_subject, 'missing') == .unknown

	unknown := ContainerQuery.create(BooleanExpression.create_general_enclosed('(future)', .false_))
	assert unknown.evaluate(abstract_subject, none) == .unknown
}

fn test_multiple_container_conditions_hide_legacy_singular_accessors() {
	rule := CSSRule.create_container([
		ContainerRuleCondition{ container_name: 'one' },
		ContainerRuleCondition{ container_name: 'two' },
	], CSSRuleList.create_empty())
	assert rule.condition_text() == 'one, two'
	assert rule.container_name() == ''
	assert rule.container_query() == ''
}

fn test_container_rule_exposes_all_children_for_element_dependent_matching() {
	style_rule := CSSRule.create(.style)
	keyframes_rule := CSSRule.create(.keyframes)
	rule := CSSRule.create_container([], CSSRuleList.create([style_rule, keyframes_rule]))
	mut collector := &ContainerRuleVisitCollector{}
	rule.for_each_effective_rule(.preorder, fn [mut collector] (child &CSSRule) {
		collector.types << child.type_
	})
	assert collector.types == [CSSRuleType.style, .keyframes]
}

fn test_nested_name_only_container_rules_filter_matching_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut outer := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	outer.set_attribute_value('style', 'container-name: outer')
	mut inner := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	inner.set_attribute_value('style', 'container-name: card')
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')
	mut outsider := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	outsider.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(outer.as_node()) or { panic('${err}') }
	mut outer_node := outer.as_node()
	outer_node.append_child(inner.as_node()) or { panic('${err}') }
	outer_node.append_child(outsider.as_node()) or { panic('${err}') }
	mut inner_node := inner.as_node()
	inner_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, '.target { color: blue } @container outer { @container card { .target { color: red } } }')

	computer := StyleComputer.new(document)
	outer_style := computer.compute_style(dom.AbstractElement.new(outer, none))
	outer.set_computed_properties(none, computed_properties_to_dom(outer_style))
	inner_style := computer.compute_style(dom.AbstractElement.new(inner, none))
	inner.set_computed_properties(none, computed_properties_to_dom(inner_style))
	target_style := computer.compute_style(dom.AbstractElement.new(target, none))
	outsider_style := computer.compute_style(dom.AbstractElement.new(outsider, none))

	assert (target_style.property(.color, .no) or { panic('target color missing') }).css_text == 'rgb(255, 0, 0)'
	assert (outsider_style.property(.color, .no) or { panic('outsider color missing') }).css_text == 'rgb(0, 0, 255)'
}

fn test_container_name_change_recomputes_descendant_container_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut container := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or {
		panic('${err}')
	}
	container.set_attribute_value('style', 'container-name: old')
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(container.as_node()) or { panic('${err}') }
	mut container_node := container.as_node()
	container_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, '.target { color: blue } @container old { .target { color: red } }')

	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'

	container.set_attribute_value('style', 'container-name: new')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
}

fn test_container_rule_parser_preserves_names_and_general_enclosed_queries() {
	rules := parse_css_stylesheet_contents_with_parser('@container card not (width <= 500px), (height: 100px) { .item { color: red; } }', map[string]bool{})
	assert rules.len == 1
	rule := rules[0]
	assert rule.type_ == .container_rule
	assert rule.condition_text() == 'card not (width <= 500px), (height: 100px)'
	assert rule.container_name() == ''
	assert rule.container_query() == ''
	assert rule.container_conditions_for_bindings() == [
		CSSContainerCondition{
			name: 'card'
			query: 'not (width <= 500px)'
		},
		CSSContainerCondition{
			query: '(height: 100px)'
		},
	]
	children := rule.rules or { panic('container rule has no child list') }
	assert children.length() == 1
	child := children.item(0) or { panic('container rule child is missing') }
	assert child.type_ == .style
}

fn test_unsupported_container_features_evaluate_to_unknown() {
	rule := parse_css_rule_with_params(ParsingParams{}, '@container (future-feature: enabled) {}') or {
		panic('container rule did not parse')
	}
	query := rule.container_conditions[0].container_query or { panic('missing container query') }
	assert query.condition.evaluate(BooleanExpressionEvaluationContext{}) == .unknown
	assert query.feature_requirements.has_unknown_or_unsupported_feature
}

fn test_size_container_features_parse_serialize_and_collect_axis_requirements() {
	width := parsed_single_container_query('(width >= 300px)')
	assert width.to_string() == '(width >= 300px)'
	assert width.feature_requirements.requires_width_container
	assert !width.feature_requirements.requires_height_container
	assert !width.feature_requirements.has_unknown_or_unsupported_feature

	logical := parsed_single_container_query('(min-inline-size: 10em) and (max-block-size: 20px)')
	assert logical.to_string() == '(min-inline-size: 10em) and (max-block-size: 20px)'
	assert logical.feature_requirements.requires_inline_size_container
	assert logical.feature_requirements.requires_block_size_container

	ratio := parsed_single_container_query('(aspect-ratio: 16 / 9)')
	assert ratio.to_string() == '(aspect-ratio: 16 / 9)'
	assert ratio.feature_requirements.requires_width_container
	assert ratio.feature_requirements.requires_height_container

	orientation := parsed_single_container_query('(orientation: portrait)')
	assert orientation.feature_requirements.requires_width_container
	assert orientation.feature_requirements.requires_height_container

	range := parsed_single_container_query('(100px < width <= 400px)')
	assert range.to_string() == '(100px < width <= 400px)'
}

fn test_style_container_features_parse_serialize_and_collect_requirements() {
	plain := parsed_single_container_query('style(--theme: dark)')
	assert plain.to_string() == 'style(--theme: dark)'
	assert plain.contains_style_feature()
	assert !plain.contains_size_feature()
	assert !plain.feature_requirements.has_unknown_or_unsupported_feature

	logical := parsed_single_container_query('style(--theme: dark) and style(3 < --level <= 5)')
	assert logical.to_string() == 'style(--theme: dark) and style(3 < --level <= 5)'
	assert logical.contains_style_feature()
	assert !logical.feature_requirements.has_unknown_or_unsupported_feature

	unknown := parsed_single_container_query('style(future-style-feature)')
	assert unknown.to_string() == 'style(future-style-feature)'
	assert unknown.feature_requirements.has_unknown_or_unsupported_feature

	escaped_plain := parsed_single_container_query(r'style(--\{foo: bar)')
	assert escaped_plain.to_string() == r'style(--\{foo: bar)'
	escaped_range := parsed_single_container_query(r'style(100px > --\{foo > 10px)')
	assert escaped_range.to_string() == r'style(100px > --\{foo > 10px)'
	assert parsed_single_container_query('style(--foo:bar   baz)').to_string() == 'style(--foo: bar   baz)'
	assert parsed_single_container_query('style(--foo:2.100  )').to_string() == 'style(--foo: 2.100)'

	for invalid_operand in ['style(10px < 10em !)', 'style(10px ! < 10em)'] {
		query := parsed_single_container_query(invalid_operand)
		assert query.to_string() == invalid_operand
		assert query.evaluate(dom.AbstractElement{}, none) == .unknown
		assert query.feature_requirements.has_unknown_or_unsupported_feature
	}
}

fn test_style_container_features_evaluate_selected_ancestor_style() {
	_, _, subject := size_query_test_tree('--theme: dark; --level: 5', 0, 0, false)
	abstract_subject := dom.AbstractElement.new(subject, none)
	assert parsed_single_container_query('style(--theme: dark)').evaluate(abstract_subject,
		none) == .true_
	container := subject.as_node().parent_element() or { panic('missing query container') }
	assert container.is_style_query_container()
	root := subject.document().document_element() or { panic('missing document element') }
	assert root.is_style_query_container()
	assert parsed_single_container_query('style(--theme: light)').evaluate(abstract_subject,
		none) == .false_
	assert parsed_single_container_query('style(3 < --level <= 5)').evaluate(abstract_subject,
		none) == .true_
	assert parsed_single_container_query('style(--level > 5)').evaluate(abstract_subject,
		none) == .false_
}

fn test_pseudo_element_queries_include_the_originating_element_as_an_ancestor_container() {
	_, container, _ := size_query_test_tree('container-name: --target; --state: target',
		0, 0, false)
	pseudo_element := dom.AbstractElement.new(container, .before)
	query_parent := pseudo_element.flat_tree_parent_element() or { panic('missing query parent') }
	assert query_parent == container
	assert parsed_single_container_query('style(--state: target)').evaluate(pseudo_element,
		none) == .true_

	rule := parse_css_rule_with_params(ParsingParams{}, '@container --target {}') or {
		panic('named container rule did not parse')
	}
	assert rule.container_conditions_match(pseudo_element)
}

fn test_style_container_query_dependents_recompute_when_container_style_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mut container := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main') or {
		panic('${err}')
	}
	container.set_attribute_value('style', '--theme: dark')
	mut intermediate := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or {
		panic('${err}')
	}
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	target.set_attribute_value('class', 'target')
	mut unrelated := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	unrelated.set_attribute_value('class', 'unrelated')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(container.as_node()) or { panic('${err}') }
	mut container_node := container.as_node()
	container_node.append_child(intermediate.as_node()) or { panic('${err}') }
	container_node.append_child(unrelated.as_node()) or { panic('${err}') }
	mut intermediate_node := intermediate.as_node()
	intermediate_node.append_child(target.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, '.target { color: blue } @container style(--theme: dark) { .target { color: red } }')

	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	assert target.style_depends_on_style_container_query()
	assert !unrelated.style_depends_on_style_container_query()

	container.set_attribute_value('style', '--theme: light')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert target.style_depends_on_style_container_query()
}

fn test_size_container_features_select_eligible_ancestors_and_evaluate_geometry() {
	_, container, subject := size_query_test_tree('container-type: size; font-size: 16px', 320,
		180, true)
	abstract_subject := dom.AbstractElement.new(subject, none)
	assert parsed_single_container_query('(width >= 300px) and (height < 200px)').evaluate(abstract_subject,
		none) == .true_
	assert parsed_single_container_query('(100px < width <= 320px)').evaluate(abstract_subject,
		none) == .true_
	assert parsed_single_container_query('(aspect-ratio: 16 / 9)').evaluate(abstract_subject,
		none) == .true_
	assert parsed_single_container_query('(orientation: landscape)').evaluate(abstract_subject,
		none) == .true_
	assert parsed_single_container_query('(orientation: portrait)').evaluate(abstract_subject,
		none) == .false_
	assert parsed_single_container_query('(width: calc(10em + 160px))').evaluate(abstract_subject,
		none) == .true_
	assert container.is_size_query_container()

	_, vertical_container, vertical_subject := size_query_test_tree('container-type: inline-size; writing-mode: vertical-rl',
		320, 180, true)
	vertical_abstract := dom.AbstractElement.new(vertical_subject, none)
	assert parsed_single_container_query('(inline-size: 180px)').evaluate(vertical_abstract,
		none) == .true_
	assert parsed_single_container_query('(height: 180px)').evaluate(vertical_abstract,
		none) == .true_
	assert parsed_single_container_query('(width: 320px)').evaluate(vertical_abstract,
		none) == .unknown
	assert voidptr(vertical_container) != voidptr(container)
}

fn test_size_container_query_without_geometry_queues_post_layout_evaluation() {
	document, container, subject := size_query_test_tree('container-type: size', 320, 180,
		false)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	mutable_document.set_cached_navigable(&dom.Navigable{
		active_document_: document
	})
	assert !document.layout_is_up_to_date()
	query := parsed_single_container_query('(width: 320px)')
	assert query.evaluate(dom.AbstractElement.new(subject, none), none) == .unknown
	assert document.needs_container_query_evaluation_after_layout(container)
}

fn test_matching_size_container_rule_marks_dependency_after_selector_matches() {
	_, container, subject_ref := size_query_test_tree('container-type: size', 320, 180, true)
	mut subject := unsafe { &dom.Element(subject_ref) }
	subject.set_attribute_value('class', 'target')
	add_document_author_style_sheet(subject.document(), '.target { color: blue } @container (width >= 300px) { .target { color: red } }')
	assert css_style_scope_for(dom.AbstractElement.new(subject, none)).have_size_container_queries()

	computer := StyleComputer.new(subject.document())
	style := computer.compute_style(dom.AbstractElement.new(subject, none))
	assert (style.property(.color, .no) or { panic('target color missing') }).css_text == 'rgb(255, 0, 0)'
	assert subject.style_depends_on_size_container_query()
	assert container.is_size_query_container()

	mut outsider := subject.document().create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	outsider.set_attribute_value('class', 'other')
	mut container_node := container.as_node()
	container_node.append_child(outsider.as_node()) or { panic('${err}') }
	_ = computer.compute_style(dom.AbstractElement.new(outsider, none))
	assert !outsider.style_depends_on_size_container_query()
}

fn test_container_rule_parser_accepts_name_only_and_query_only_conditions() {
	name_rule := parse_css_rule_with_params(ParsingParams{}, '@container --card {}') or {
		panic('name-only container rule did not parse')
	}
	assert name_rule.container_name() == '--card'
	assert name_rule.container_query() == ''

	query_rule := parse_css_rule_with_params(ParsingParams{}, '@container foo(width) {}') or {
		panic('query-only container rule did not parse')
	}
	assert query_rule.container_name() == ''
	assert query_rule.container_query() == 'foo(width)'
}

fn test_container_rule_parser_rejects_invalid_preludes_and_statements() {
	for source in [
		'@container;',
		'@container {}',
		'@container none {}',
		'@container and {}',
		'@container (width), {}',
		'@container ,(width) {}',
		'@container (width),,(height) {}',
		'@container card extra {}',
	] {
		assert parse_css_rule_with_params(ParsingParams{}, source) == none, source
	}
}

fn test_container_rules_can_be_nested_in_style_rules() {
	rule := parse_css_rule_with_params(ParsingParams{}, '.card { @container (width) { color: red; .child { color: blue; } } }') or {
		panic('nested container rule did not parse')
	}
	outer_children := rule.rules or { panic('style rule has no child list') }
	assert outer_children.length() == 1
	container := outer_children.item(0) or { panic('style rule child is missing') }
	assert container.type_ == .container_rule
	container_children := container.rules or { panic('container rule has no child list') }
	assert container_children.length() == 2
	first_child := container_children.item(0) or { panic('first container child is missing') }
	second_child := container_children.item(1) or { panic('second container child is missing') }
	assert first_child.type_ == .nested_declarations
	assert second_child.type_ == .style
}

fn test_container_rules_can_be_nested_in_function_rules() {
	rule := parse_css_rule_with_params(ParsingParams{}, '@function --size() { @container (width) { result: 10px; } result: 20px; }') or {
		panic('function with a container rule did not parse')
	}
	function_children := rule.rules or { panic('function rule has no child list') }
	assert function_children.length() == 2
	container := function_children.item(0) or { panic('container child is missing') }
	assert container.type_ == .container_rule
	container_children := container.rules or { panic('container rule has no child list') }
	assert container_children.length() == 1
	declarations := container_children.item(0) or { panic('function declarations are missing') }
	assert declarations.type_ == .function_declarations
}

fn test_size_queries_stop_at_ineligible_principal_boxes() {
 for display in ['inline','table','table-cell','contents','none'] {
  document,_,subject := size_query_test_tree('display:${display};container-type:size',320,180,true)
  defer { document.finalize() }
  assert parsed_single_container_query('(width >= 0px)').evaluate(dom.AbstractElement.new(subject,none),none) == .unknown,display
 }
}

