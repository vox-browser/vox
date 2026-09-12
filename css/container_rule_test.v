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
