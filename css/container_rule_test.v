module css

struct ContainerRuleVisitCollector {
mut:
	types []CSSRuleType
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

fn test_multiple_container_conditions_hide_legacy_singular_accessors() {
	rule := CSSRule.create_container([
		ContainerRuleCondition{ container_name: 'one' },
		ContainerRuleCondition{ container_name: 'two' },
	], CSSRuleList.create_empty())
	assert rule.condition_text() == 'one, two'
	assert rule.container_name() == ''
	assert rule.container_query() == ''
}

fn test_container_rule_only_exposes_globally_effective_children() {
	style_rule := CSSRule.create(.style)
	keyframes_rule := CSSRule.create(.keyframes)
	rule := CSSRule.create_container([], CSSRuleList.create([style_rule, keyframes_rule]))
	mut collector := &ContainerRuleVisitCollector{}
	rule.for_each_effective_rule(.preorder, fn [mut collector] (child &CSSRule) {
		collector.types << child.type_
	})
	assert collector.types == [CSSRuleType.keyframes]
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
