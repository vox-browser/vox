/*
 * Copyright (c) 2021-2025, Sam Atkins <sam@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// Translated from:
// - Libraries/LibWeb/CSS/BooleanExpression.cpp/.h
// - Libraries/LibWeb/CSS/Supports.cpp/.h
module css

import dom
import strings

// Corresponds to Kleene 3-valued logic.
pub enum MatchResult {
	false_
	true_
	unknown
}

pub fn match_result_and(a MatchResult, b MatchResult) MatchResult {
	// If either is false, false.
	if a == .false_ || b == .false_ {
		return .false_
	}
	// If both are true, true.
	if a == .true_ && b == .true_ {
		return .true_
	}
	// Otherwise, unknown.
	return .unknown
}

pub fn match_result_or(a MatchResult, b MatchResult) MatchResult {
	// If either is true, true.
	if a == .true_ || b == .true_ {
		return .true_
	}
	// If both are false, false.
	if a == .false_ && b == .false_ {
		return .false_
	}
	// Otherwise, unknown.
	return .unknown
}

pub fn as_match_result(value bool) MatchResult {
	if value {
		return .true_
	}
	return .false_
}

pub fn negate_match_result(value MatchResult) MatchResult {
	return match value {
		.false_ { .true_ }
		.true_ { .false_ }
		.unknown { .unknown }
	}
}

pub struct BooleanExpressionEvaluationContext {
pub:
	document                              ?&dom.Document
	query_container                       ?&dom.Element
	style_query_element                   ?dom.AbstractElement
	guarded_contexts                      ?&GuardedSubstitutionContexts
	did_evaluate_attr_tainted_style_query ?&bool
}

pub struct ContainerQueryFeatureRequirements {
pub mut:
	requires_width_container           bool
	requires_height_container          bool
	requires_inline_size_container     bool
	requires_block_size_container      bool
	requires_style_container           bool
	requires_scroll_state_container    bool
	has_unknown_or_unsupported_feature bool
}

pub fn (requirements ContainerQueryFeatureRequirements) contains_size_feature() bool {
	return requirements.requires_width_container || requirements.requires_height_container
		|| requirements.requires_inline_size_container
		|| requirements.requires_block_size_container
}

pub fn (requirements ContainerQueryFeatureRequirements) contains_style_feature() bool {
	return requirements.requires_style_container
}

pub fn (result MatchResult) to_string() string {
	return match result {
		.false_ { 'false' }
		.true_ { 'true' }
		.unknown { 'unknown' }
	}
}

// The contents of this file implement the `<boolean-expr>` concept.
// https://drafts.csswg.org/css-values-5/#typedef-boolean-expr
pub enum BooleanExpressionKind {
	general_enclosed
	not
	in_parens
	and
	or
	constant
	supports_declaration
	supports_selector
	supports_font_tech
	supports_font_format
	supports_env
	supports_at_rule
	style_query_function
	scroll_state_query_function
}

@[heap]
pub struct BooleanExpression {
pub mut:
	kind                           BooleanExpressionKind
	text                           string
	matches                        MatchResult = .unknown
	children                       []&BooleanExpression
	scroll_state_feature_name      string
	scroll_state_feature_value     string
	size_feature_name              string
	media_feature_name             string
	media_feature_kind             MediaFeatureEvalKind
	media_feature_value            ?MediaFeatureValueLocal
	media_feature_comparison       ?MediaFeatureComparison
	media_feature_right_comparison ?MediaFeatureComparison
	media_feature_right_value      ?MediaFeatureValueLocal
	style_feature_property            ?PropertyNameAndID
	style_feature_has_value           bool
	style_feature_value               []ComponentValue
	style_feature_original_value_text ?string
	style_feature_is_range            bool
	style_range_left                  StyleRangeValue
	style_range_left_comparison       MediaFeatureComparison
	style_range_middle                StyleRangeValue
	style_range_has_right             bool
	style_range_right_comparison      MediaFeatureComparison
	style_range_right                 StyleRangeValue
}

pub fn BooleanExpression.create_general_enclosed(serialized_contents string, matches MatchResult) &BooleanExpression {
	return &BooleanExpression{
		kind:    .general_enclosed
		text:    serialized_contents
		matches: matches
	}
}

fn BooleanExpression.create_media_feature(serialized_contents string, feature_name string, kind MediaFeatureEvalKind, value ?MediaFeatureValueLocal, comparison ?MediaFeatureComparison, right_comparison ?MediaFeatureComparison, right_value ?MediaFeatureValueLocal) &BooleanExpression {
	return &BooleanExpression{
		kind:                           .general_enclosed
		text:                           serialized_contents
		matches:                        evaluate_media_feature(feature_name, kind, value,
			comparison, right_comparison, right_value, none)
		media_feature_name:             feature_name
		media_feature_kind:             kind
		media_feature_value:            value
		media_feature_comparison:       comparison
		media_feature_right_comparison: right_comparison
		media_feature_right_value:      right_value
	}
}

fn BooleanExpression.create_size_feature(serialized_contents string, feature_name string, kind MediaFeatureEvalKind, value ?MediaFeatureValueLocal, comparison ?MediaFeatureComparison, right_comparison ?MediaFeatureComparison, right_value ?MediaFeatureValueLocal) &BooleanExpression {
	return &BooleanExpression{
		kind:                           .general_enclosed
		text:                           serialized_contents
		size_feature_name:              feature_name
		media_feature_kind:             kind
		media_feature_value:            value
		media_feature_comparison:       comparison
		media_feature_right_comparison: right_comparison
		media_feature_right_value:      right_value
	}
}

fn BooleanExpression.create_style_feature(property PropertyNameAndID, value ?[]ComponentValue, original_value_text ?string) &BooleanExpression {
	if feature_value := value {
		serialized_value := original_value_text or {
			serialize_a_series_of_component_values(feature_value)
		}
		return &BooleanExpression{
			kind:                              .general_enclosed
			text:                              '${serialize_an_identifier(property.name())}: ${serialized_value}'
			style_feature_property:            property
			style_feature_has_value:           true
			style_feature_value:               feature_value
			style_feature_original_value_text: original_value_text
		}
	}
	return &BooleanExpression{
		kind:                   .general_enclosed
		text:                   serialize_an_identifier(property.name())
		style_feature_property: property
	}
}

fn BooleanExpression.create_style_range(left StyleRangeValue, left_comparison MediaFeatureComparison, middle StyleRangeValue, right_comparison ?MediaFeatureComparison, right ?StyleRangeValue) &BooleanExpression {
	if comparison := right_comparison {
		right_value := right or { StyleRangeValue{} }
		return &BooleanExpression{
			kind:                         .general_enclosed
			text:                         '${left.to_string()} ${media_feature_comparison_to_string(left_comparison)} ${middle.to_string()} ${media_feature_comparison_to_string(comparison)} ${right_value.to_string()}'
			style_feature_is_range:       true
			style_range_left:             left
			style_range_left_comparison:  left_comparison
			style_range_middle:           middle
			style_range_has_right:        true
			style_range_right_comparison: comparison
			style_range_right:            right_value
		}
	}
	return &BooleanExpression{
		kind:                        .general_enclosed
		text:                        '${left.to_string()} ${media_feature_comparison_to_string(left_comparison)} ${middle.to_string()}'
		style_feature_is_range:      true
		style_range_left:            left
		style_range_left_comparison: left_comparison
		style_range_middle:          middle
	}
}

pub fn BooleanExpression.create_not(child &BooleanExpression) &BooleanExpression {
	return &BooleanExpression{
		kind:     .not
		children: [child]
	}
}

pub fn BooleanExpression.create_in_parens(child &BooleanExpression) &BooleanExpression {
	return &BooleanExpression{
		kind:     .in_parens
		children: [child]
	}
}

fn BooleanExpression.create_style_query_function(query &BooleanExpression) &BooleanExpression {
	return &BooleanExpression{
		kind:     .style_query_function
		children: [query]
	}
}

pub fn BooleanExpression.create_and(children []&BooleanExpression) &BooleanExpression {
	return &BooleanExpression{
		kind:     .and
		children: children
	}
}

pub fn BooleanExpression.create_or(children []&BooleanExpression) &BooleanExpression {
	return &BooleanExpression{
		kind:     .or
		children: children
	}
}

pub fn BooleanExpression.create_constant(value MatchResult) &BooleanExpression {
	return &BooleanExpression{
		kind:    .constant
		matches: value
	}
}

pub fn BooleanExpression.create_supports_declaration(declaration string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_declaration
		text:    declaration
		matches: as_match_result(matches)
	}
}

pub fn BooleanExpression.create_supports_selector(selector string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_selector
		text:    selector
		matches: as_match_result(matches)
	}
}

pub fn BooleanExpression.create_supports_font_tech(tech string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_font_tech
		text:    tech
		matches: as_match_result(matches)
	}
}

pub fn BooleanExpression.create_supports_font_format(format string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_font_format
		text:    format
		matches: as_match_result(matches)
	}
}

pub fn BooleanExpression.create_supports_env(variable_name string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_env
		text:    variable_name
		matches: as_match_result(matches)
	}
}

pub fn BooleanExpression.create_supports_at_rule(name string, matches bool) &BooleanExpression {
	return &BooleanExpression{
		kind:    .supports_at_rule
		text:    name
		matches: as_match_result(matches)
	}
}

pub fn (expression &BooleanExpression) evaluate_to_boolean(context BooleanExpressionEvaluationContext) bool {
	return expression.evaluate(context) == .true_
}

pub fn boolean_expression_indent(levels int) string {
	mut builder := strings.new_builder(levels * 2)
	for _ in 0 .. levels {
		builder.write_string('  ')
	}
	return builder.str()
}

pub fn (expression &BooleanExpression) evaluate(context BooleanExpressionEvaluationContext) MatchResult {
	match expression.kind {
		.general_enclosed, .constant, .supports_declaration, .supports_selector,
		.supports_font_tech, .supports_font_format, .supports_env, .supports_at_rule {
			if expression.scroll_state_feature_name != '' {
				return evaluate_scroll_state_feature(expression, context)
			}
			if expression.style_feature_is_range {
				return evaluate_style_range(expression, context)
			}
			if property := expression.style_feature_property {
				return evaluate_style_feature(property, expression.style_feature_has_value,
					expression.style_feature_value, context)
			}
			if expression.kind == .general_enclosed && expression.size_feature_name.len > 0 {
				return evaluate_size_feature(expression.size_feature_name,
					expression.media_feature_kind, expression.media_feature_value,
					expression.media_feature_comparison, expression.media_feature_right_comparison,
					expression.media_feature_right_value, context)
			}
			if expression.kind == .general_enclosed && expression.media_feature_name.len > 0 {
				return evaluate_media_feature(expression.media_feature_name,
					expression.media_feature_kind, expression.media_feature_value,
					expression.media_feature_comparison, expression.media_feature_right_comparison,
					expression.media_feature_right_value, context.document)
			}
			return expression.matches
		}
		.not {
			// https://drafts.csswg.org/css-values-5/#boolean-logic
			// `not test` evaluates to true if its contained test is false, false if it's true, and unknown if it's unknown.
			if expression.children.len == 0 {
				return .unknown
			}
			return negate_match_result(expression.children[0].evaluate(context))
		}
		.in_parens {
			if expression.children.len == 0 {
				return .unknown
			}
			return expression.children[0].evaluate(context)
		}
		.and {
			// https://drafts.csswg.org/css-values-5/#boolean-logic
			// Multiple tests connected with `and` evaluate to true if all of those tests are true, false if any of them are
			// false, and unknown otherwise (i.e. if at least one unknown, but no false).
			mut true_results := 0
			for child in expression.children {
				child_match := child.evaluate(context)
				if child_match == .false_ {
					return .false_
				}
				if child_match == .true_ {
					true_results++
				}
			}
			if true_results == expression.children.len {
				return .true_
			}
			return .unknown
		}
		.or {
			// https://drafts.csswg.org/css-values-5/#boolean-logic
			// Multiple tests connected with `or` evaluate to true if any of those tests are true, false if all of them are
			// false, and unknown otherwise (i.e. at least one unknown, but no true).
			mut false_results := 0
			for child in expression.children {
				child_match := child.evaluate(context)
				if child_match == .true_ {
					return .true_
				}
				if child_match == .false_ {
					false_results++
				}
			}
			if false_results == expression.children.len {
				return .false_
			}
			return .unknown
		}
		.style_query_function, .scroll_state_query_function {
			if expression.children.len == 0 {
				return .unknown
			}
			return expression.children[0].evaluate(context)
		}
	}
}

pub fn (expression &BooleanExpression) collect_container_query_feature_requirements(mut requirements ContainerQueryFeatureRequirements) {
	match expression.kind {
		.general_enclosed {
			if expression.scroll_state_feature_name != '' {
				requirements.requires_scroll_state_container = true
			} else if expression.style_feature_is_range {
				requirements.requires_style_container = true
			} else if _ := expression.style_feature_property {
				requirements.requires_style_container = true
			} else if expression.size_feature_name.len > 0 {
				collect_size_feature_requirements(expression.size_feature_name, mut requirements)
			} else {
				requirements.has_unknown_or_unsupported_feature = true
			}
		}
		.not, .in_parens, .and, .or, .style_query_function, .scroll_state_query_function {
			for child in expression.children {
				child.collect_container_query_feature_requirements(mut requirements)
			}
		}
		else {}
	}
}

pub fn (expression &BooleanExpression) to_string() string {
	return match expression.kind {
		.general_enclosed {
			expression.text
		}
		.not {
			if expression.children.len == 0 {
				'not <missing>'
			} else {
				'not ${expression.children[0].to_string()}'
			}
		}
		.in_parens {
			if expression.children.len == 0 {
				'()'
			} else {
				'(${expression.children[0].to_string()})'
			}
		}
		.and {
			boolean_expression_children_to_string(expression.children, ' and ')
		}
		.or {
			boolean_expression_children_to_string(expression.children, ' or ')
		}
		.scroll_state_query_function {
			'scroll-state(${expression.children[0].to_string()})'
		}
		.style_query_function {
			if expression.children.len == 0 {
				'style()'
			} else {
				'style(${expression.children[0].to_string()})'
			}
		}
		.constant {
			expression.matches.to_string()
		}
		.supports_declaration {
			expression.text
		}
		.supports_selector {
			'selector(${expression.text})'
		}
		.supports_font_tech {
			'font-tech(${expression.text})'
		}
		.supports_font_format {
			'font-format(${expression.text})'
		}
		.supports_env {
			'env(${serialize_an_identifier(expression.text)})'
		}
		.supports_at_rule {
			'at-rule(@${serialize_an_identifier(expression.text)})'
		}
	}
}

fn boolean_expression_children_to_string(children []&BooleanExpression, separator string) string {
	mut serialized := []string{}
	for child in children {
		serialized << child.to_string()
	}
	return serialized.join(separator)
}

pub fn (expression &BooleanExpression) dump(indent_levels int) string {
	mut builder := strings.new_builder(64)
	indent := boolean_expression_indent(indent_levels)
	match expression.kind {
		.general_enclosed {
			builder.write_string('${indent}GeneralEnclosed: ${expression.to_string()}\n')
		}
		.not {
			builder.write_string('${indent}NOT:\n')
			for child in expression.children {
				builder.write_string(child.dump(indent_levels + 1))
			}
		}
		.in_parens {
			builder.write_string('${indent}(\n')
			for child in expression.children {
				builder.write_string(child.dump(indent_levels + 1))
			}
			builder.write_string('${indent})\n')
		}
		.and {
			builder.write_string('${indent}AND:\n')
			for child in expression.children {
				builder.write_string(child.dump(indent_levels + 1))
			}
		}
		.or {
			builder.write_string('${indent}OR:\n')
			for child in expression.children {
				builder.write_string(child.dump(indent_levels + 1))
			}
		}
		.scroll_state_query_function {
			builder.write_string('${indent}ScrollStateQueryFunction:\n')
			for child in expression.children { builder.write_string(child.dump(indent_levels + 1)) }
		}
		.style_query_function {
			builder.write_string('${indent}StyleQueryFunction:\n')
			for child in expression.children {
				builder.write_string(child.dump(indent_levels + 1))
			}
		}
		.constant {
			builder.write_string('${indent}CONSTANT: ${expression.to_string()}\n')
		}
		.supports_declaration {
			builder.write_string('${indent}Declaration: `${expression.text}`, matches=${expression.matches == .true_}\n')
		}
		.supports_selector {
			builder.write_string('${indent}Selector: `${expression.text}` matches=${expression.matches == .true_}\n')
		}
		.supports_font_tech {
			builder.write_string('${indent}FontTech: `${expression.text}` matches=${expression.matches == .true_}\n')
		}
		.supports_font_format {
			builder.write_string('${indent}FontFormat: `${expression.text}` matches=${expression.matches == .true_}\n')
		}
		.supports_env {
			builder.write_string('${indent}Env: `${expression.text}` matches=${expression.matches == .true_}\n')
		}
		.supports_at_rule {
			builder.write_string('${indent}AtRule: `@${expression.text}` matches=${expression.matches == .true_}\n')
		}
	}

	return builder.str()
}
