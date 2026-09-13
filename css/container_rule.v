module css

import dom
import strings

// https://drafts.csswg.org/css-conditional-5/#container-rule
@[heap]
pub struct ContainerQuery {
pub:
	condition            &BooleanExpression
	feature_requirements ContainerQueryFeatureRequirements
	matches_             bool
}

pub fn ContainerQuery.create(condition &BooleanExpression) &ContainerQuery {
	mut feature_requirements := ContainerQueryFeatureRequirements{}
	condition.collect_container_query_feature_requirements(mut feature_requirements)
	return &ContainerQuery{
		condition:            condition
		feature_requirements: feature_requirements
		matches_:             condition.evaluate_to_boolean(BooleanExpressionEvaluationContext{})
	}
}

pub fn (query &ContainerQuery) contains_size_feature() bool {
	return query.feature_requirements.contains_size_feature()
}

pub fn (query &ContainerQuery) contains_style_feature() bool {
	return query.feature_requirements.contains_style_feature()
}

fn container_satisfies_requirements(element &dom.Element, requirements ContainerQueryFeatureRequirements) bool {
	dom_style := element.el_computed_properties() or { return false }
	style := computed_properties_from_dom(dom_style) or { return false }
	container_type := style.container_type()
	inline_axis_horizontal := style.writing_mode() == .horizontal_tb

	if requirements.requires_width_container {
		if inline_axis_horizontal {
			if !(container_type.is_size_container || container_type.is_inline_size_container) {
				return false
			}
		} else if !container_type.is_size_container {
			return false
		}
	}
	if requirements.requires_height_container {
		if inline_axis_horizontal {
			if !container_type.is_size_container {
				return false
			}
		} else if !(container_type.is_size_container || container_type.is_inline_size_container) {
			return false
		}
	}
	if requirements.requires_inline_size_container
		&& !(container_type.is_size_container || container_type.is_inline_size_container) {
		return false
	}
	if requirements.requires_block_size_container && !container_type.is_size_container {
		return false
	}
	if requirements.requires_scroll_state_container && !container_type.is_scroll_state_container {
		return false
	}
	return true
}

pub fn container_name_matches(element &dom.Element, container_name ?string) bool {
	name := container_name or { return true }
	dom_style := element.el_computed_properties() or { return false }
	style := computed_properties_from_dom(dom_style) or { return false }
	return name in style.container_name()
}

// https://drafts.csswg.org/css-conditional-5/#container-rule
pub fn (query &ContainerQuery) evaluate(element dom.AbstractElement, container_name ?string) MatchResult {
	if query.feature_requirements.has_unknown_or_unsupported_feature {
		return .unknown
	}

	mut candidate := element.element().as_node().flat_tree_parent_element()
	for candidate != none {
		container := candidate or { break }
		if container_name_matches(container, container_name)
			&& container_satisfies_requirements(container, query.feature_requirements) {
			return query.condition.evaluate(BooleanExpressionEvaluationContext{
				document: element.document()
				query_container: container
			})
		}
		candidate = container.as_node().flat_tree_parent_element()
	}
	return .unknown
}

pub fn (query &ContainerQuery) matches() bool {
	return query.matches_
}

pub fn (query &ContainerQuery) to_string() string {
	return query.condition.to_string()
}

fn (mut parser Parser) parse_container_query_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, .false_, .container_query_feature)
}

fn (mut parser Parser) parse_container_query_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	// Size, style, scroll-state, and anchored query features are translated by
	// later upstream slices. Boolean parsing still preserves all of them as
	// <general-enclosed> in this initial implementation.
	_ = parser
	_ = tokens
	return none
}

fn (mut parser Parser) parse_container_query(mut tokens SupportsTokenStream) ?&ContainerQuery {
	condition := parser.parse_container_query_condition(mut tokens) or { return none }
	return ContainerQuery.create(condition)
}

fn parse_container_name(mut tokens SupportsTokenStream) ?string {
	mut transaction := tokens
	transaction.discard_whitespace()
	token := transaction.consume_a_token() or { return none }
	if !token.is(.ident) {
		return none
	}
	name := token.token().ident()
	if !is_valid_custom_ident(name, ['none', 'and', 'not', 'or']) {
		return none
	}
	tokens = transaction
	return name
}

pub struct ContainerRuleCondition {
pub:
	container_name  ?string
	container_query ?&ContainerQuery
}

pub struct CSSContainerCondition {
pub:
	name  string
	query string
}

pub fn (rule &CSSRule) container_conditions_for_bindings() []CSSContainerCondition {
	mut result := []CSSContainerCondition{cap: rule.container_conditions.len}
	for condition in rule.container_conditions {
		result << CSSContainerCondition{
			name: if name := condition.container_name { serialize_an_identifier(name) } else { '' }
			query: if query := condition.container_query { query.to_string() } else { '' }
		}
	}
	return result
}

fn (rule &CSSRule) container_condition_text() string {
	mut serialized := []string{cap: rule.container_conditions.len}
	for condition in rule.container_conditions_for_bindings() {
		serialized << if condition.name.len > 0 && condition.query.len > 0 {
			'${condition.name} ${condition.query}'
		} else {
			condition.name + condition.query
		}
	}
	return serialized.join(', ')
}

pub fn (rule &CSSRule) container_name() string {
	conditions := rule.container_conditions_for_bindings()
	if conditions.len == 1 {
		return conditions[0].name
	}
	return ''
}

pub fn (rule &CSSRule) container_query() string {
	conditions := rule.container_conditions_for_bindings()
	if conditions.len == 1 {
		return conditions[0].query
	}
	return ''
}

fn (rule &CSSRule) serialized_container_rule() string {
	mut builder := strings.new_builder(128)
	builder.write_string('@container ${rule.container_condition_text()} {\n')
	if rules := rule.rules {
		for child_rule in rules.rules {
			serialized := child_rule.css_text()
			if serialized.len > 0 {
				builder.write_string('  ${serialized}\n')
			}
		}
	}
	builder.write_u8(`}`)
	return builder.str()
}

fn (rule &CSSRule) for_each_globally_effective_container_child(order TraversalOrder, callback fn (&CSSRule)) {
	rules := rule.rules or { return }
	for child in rules.rules {
		if child.type_ !in [.counter_style, .font_face, .font_feature_values, .function_rule,
			.keyframes, .layer_block, .layer_statement, .margin, .page, .property] {
			continue
		}
		if order == .preorder {
			callback(child)
		}
		if child.type_ in css_grouping_rule_types {
			child.for_each_effective_rule(order, callback)
		}
		if order == .postorder {
			callback(child)
		}
	}
}
