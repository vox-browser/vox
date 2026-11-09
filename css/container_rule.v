module css

import dom
import strings

pub struct StyleRangeValue {
pub:
	is_property bool
	property    ?PropertyNameAndID
	value       []ComponentValue
}

fn StyleRangeValue.from_property(property PropertyNameAndID) StyleRangeValue {
	return StyleRangeValue{
		is_property: true
		property:    property
	}
}

fn StyleRangeValue.from_value(value []ComponentValue) StyleRangeValue {
	return StyleRangeValue{
		value: value
	}
}

enum StyleRangeNumericType {
	number
	length
	percentage
	angle
	time
	frequency
	resolution
}

struct StyleRangeComparableValue {
	type_ StyleRangeNumericType
	value f64
}

fn (value StyleRangeValue) to_string() string {
	if value.is_property {
		return serialize_an_identifier((value.property or { return '' }).name())
	}
	return serialize_a_series_of_component_values(value.value)
}

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

	mut candidate := element.flat_tree_parent_element()
	for candidate != none {
		container := candidate or { break }
		if container_name_matches(container, container_name)
			&& container_satisfies_requirements(container, query.feature_requirements) {
			if query.contains_size_feature() {
				mut mutable_container := unsafe { &dom.Element(container) }
				mutable_container.set_is_size_query_container()
			}
			if query.contains_style_feature() {
				mut mutable_container := unsafe { &dom.Element(container) }
				mutable_container.set_is_style_query_container()
				if root := element.document().document_element() {
					mut mutable_root := unsafe { &dom.Element(root) }
					mutable_root.set_is_style_query_container()
				}
			}
			return query.condition.evaluate(BooleanExpressionEvaluationContext{
				document:            element.document()
				query_container:     container
				style_query_element: dom.AbstractElement.new(container, none)
			})
		}
		candidate = container.as_node().flat_tree_parent_element()
	}
	return .unknown
}

fn has_ancestor_container_with_name(element dom.AbstractElement, container_name string) bool {
	mut candidate := element.flat_tree_parent_element()
	for candidate != none {
		container := candidate or { break }
		if container_name_matches(container, container_name) {
			return true
		}
		candidate = container.as_node().flat_tree_parent_element()
	}
	return false
}

fn (rule &CSSRule) container_conditions_match(element dom.AbstractElement) bool {
	for condition in rule.container_conditions {
		if query := condition.container_query {
			if query.evaluate(element, condition.container_name) == .true_ {
				return true
			}
			continue
		}
		if name := condition.container_name {
			if has_ancestor_container_with_name(element, name) {
				return true
			}
		}
	}
	return false
}

pub fn (rule &CSSRule) container_rule_contains_scroll_state_feature() bool {
	for condition in rule.container_conditions {
		if query := condition.container_query {
			if query.feature_requirements.requires_scroll_state_container { return true }
		}
	}
	if parent := rule.parent_container_rule() { return parent.container_rule_contains_scroll_state_feature() }
	return false
}

fn (rule &CSSRule) parent_container_rule() ?&CSSRule {
	if rule.parent_container_rule_cache_valid {
		return rule.cached_parent_container_rule
	}

	mut result := ?&CSSRule(none)
	mut current_parent := rule.parent_rule
	mut current_style_sheet := rule.parent_style_sheet
	for {
		for current_parent != none {
			parent := current_parent or { break }
			if parent.type_ == .container_rule {
				result = parent
				break
			}
			current_parent = parent.parent_rule
		}
		if result != none {
			break
		}
		style_sheet := current_style_sheet or { break }
		owner_rule := style_sheet.owner_rule or { break }
		if owner_rule.type_ == .container_rule {
			result = owner_rule
			break
		}
		current_parent = owner_rule.parent_rule
		current_style_sheet = owner_rule.parent_style_sheet
	}

	mut mutable_rule := unsafe { &CSSRule(rule) }
	mutable_rule.cached_parent_container_rule = result
	mutable_rule.parent_container_rule_cache_valid = true
	return result
}

pub fn (rule &CSSRule) container_rule_matches(element dom.AbstractElement) bool {
	matched := rule.container_rule_matches_without_recording(element)
	if !disable_size_query_result_reuse && rule.container_rule_contains_size_feature() {
		bridge := element.document().style_computer()
		if bridge.css_handle != unsafe { nil } {
			mut computer := unsafe { &StyleComputer(bridge.css_handle) }
			computer.record_size_query_match(rule, element, matched)
		}
	}
	return matched
}

fn (rule &CSSRule) container_rule_matches_without_recording(element dom.AbstractElement) bool {
	if rule.type_ != .container_rule || !rule.container_conditions_match(element) {
		return false
	}
	if parent := rule.parent_container_rule() {
		return parent.container_rule_matches_without_recording(element)
	}
	return true
}

pub fn (rule &CSSRule) container_rule_contains_size_feature() bool {
	if rule.type_ != .container_rule {
		return false
	}
	for condition in rule.container_conditions {
		if query := condition.container_query {
			if query.contains_size_feature() {
				return true
			}
		}
	}
	if parent := rule.parent_container_rule() {
		return parent.container_rule_contains_size_feature()
	}
	return false
}

pub fn (rule &CSSRule) container_rule_contains_style_feature() bool {
	if rule.type_ != .container_rule {
		return false
	}
	for condition in rule.container_conditions {
		if query := condition.container_query {
			if query.contains_style_feature() {
				return true
			}
		}
	}
	if parent := rule.parent_container_rule() {
		return parent.container_rule_contains_style_feature()
	}
	return false
}

pub fn (query &ContainerQuery) matches() bool {
	return query.matches_
}

pub fn (query &ContainerQuery) to_string() string {
	return query.condition.to_string()
}

fn (mut parser Parser) parse_container_query_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, .unknown, .container_query_feature)
}

fn (mut parser Parser) parse_style_query(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, result_for_general_enclosed, .style_feature)
}

fn next_style_query_token_is_comparison(tokens SupportsTokenStream) bool {
	mut transaction := SupportsTokenStream{
		values:              tokens.values.clone()
		index:               tokens.index
		declared_namespaces: tokens.declared_namespaces.clone()
	}
	return parse_media_feature_comparison(mut transaction) != none
}

fn style_query_values_contain_comparison_delimiter(values []ComponentValue) bool {
	for value in values {
		if value.is(.delim) && value.token().delim() in [`<`, `>`, `=`] {
			return true
		}
	}
	return false
}

fn parse_style_range_value(values []ComponentValue) ?StyleRangeValue {
	mut start := 0
	for start < values.len && values[start].is(.whitespace) {
		start++
	}
	mut end := values.len
	for end > start && values[end - 1].is(.whitespace) {
		end--
	}
	if start == end {
		return none
	}
	trimmed := values[start..end].clone()
	if trimmed.len == 1 && trimmed[0].is(.ident)
		&& is_a_custom_property_name_string(trimmed[0].token().ident()) {
		property := PropertyNameAndID.from_name(trimmed[0].token().ident()) or { return none }
		return StyleRangeValue.from_property(property)
	}
	if !is_valid_optional_declaration_value(trimmed) {
		return none
	}
	return StyleRangeValue.from_value(trimmed)
}

fn parse_style_range_value_until_comparison(mut tokens SupportsTokenStream) ?StyleRangeValue {
	start := tokens.index
	for tokens.has_next_token() {
		if next_style_query_token_is_comparison(tokens) {
			break
		}
		tokens.discard_a_token()
	}
	return parse_style_range_value(tokens.values[start..tokens.index])
}

fn parse_style_range(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := SupportsTokenStream{
		values:              tokens.values.clone()
		index:               tokens.index
		declared_namespaces: tokens.declared_namespaces.clone()
	}
	transaction.discard_whitespace()
	left := parse_style_range_value_until_comparison(mut transaction) or { return none }
	left_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	middle := parse_style_range_value_until_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	if !transaction.has_next_token() {
		tokens = transaction
		return BooleanExpression.create_style_range(left, left_comparison, middle, none,
			none)
	}

	right_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	right := parse_style_range_value_until_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token()
		|| !media_feature_comparisons_match(left_comparison, right_comparison)
		|| left_comparison == .equal {
		return none
	}
	tokens = transaction
	return BooleanExpression.create_style_range(left, left_comparison, middle,
		right_comparison, right)
}

// https://drafts.csswg.org/css-conditional-5/#typedef-style-feature
fn (mut parser Parser) parse_style_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	_ = parser

	// <style-range> = <style-range-value> <mf-comparison> <style-range-value>
	//               | <style-range-value> <mf-lt> <style-range-value> <mf-lt> <style-range-value>
	//               | <style-range-value> <mf-gt> <style-range-value> <mf-gt> <style-range-value>
	if range := parse_style_range(mut tokens) {
		return range
	}

	// <style-feature-plain> = <style-feature-name> : <style-feature-value>
	mut transaction := tokens.fork()
	transaction.discard_whitespace()
	name_token := transaction.consume_a_token() or { return none }
	if name_token.is(.ident) {
		property := PropertyNameAndID.from_name(name_token.token().ident()) or { return none }
		transaction.discard_whitespace()
		if colon := transaction.consume_a_token() {
			if colon.is(.colon) {
				transaction.discard_whitespace()
				mut declaration := Declaration{
					name:  property.name()
					value: transaction.values[transaction.index..].clone()
				}
				parser_strip_important(mut declaration)
				for declaration.value.len > 0
					&& declaration.value[declaration.value.len - 1].is(.whitespace) {
					declaration.value.delete(declaration.value.len - 1)
				}
				if !is_valid_optional_declaration_value(declaration.value) {
					return none
				}
				if style_query_values_contain_comparison_delimiter(declaration.value) {
					return none
				}
				transaction.index = transaction.values.len
				tokens = transaction
				mut original_value_text := ?string(none)
				if property.is_custom_property() {
					original_value_text = parser_component_values_original_text(declaration.value)
				}
				return BooleanExpression.create_style_feature(property, declaration.value,
					original_value_text)
			}
		}
	}

	// <style-feature-boolean> = <style-feature-name>
	transaction = SupportsTokenStream{
		values:              tokens.values.clone()
		index:               tokens.index
		declared_namespaces: tokens.declared_namespaces.clone()
	}
	transaction.discard_whitespace()
	boolean_name_token := transaction.consume_a_token() or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token() || !boolean_name_token.is(.ident) {
		return none
	}
	property := PropertyNameAndID.from_name(boolean_name_token.token().ident()) or { return none }
	tokens = transaction
	return BooleanExpression.create_style_feature(property, none, none)
}

fn single_style_query_css_wide_keyword(value []ComponentValue) ?Keyword {
	mut tokens := SupportsTokenStream.from_values(value)
	tokens.discard_whitespace()
	token := tokens.consume_a_token() or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() || !token.is(.ident) {
		return none
	}
	keyword := keyword_from_string(token.token().ident()) or { return none }
	if keyword in [.initial, .inherit, .unset, .revert, .revert_layer] {
		return keyword
	}
	return none
}

fn style_query_computation_context(element dom.AbstractElement) ComputationContext {
	style_computer := css_style_computer_for(element.document())
	if dom_computed := element.computed_properties() {
		if computed := computed_properties_from_dom(dom_computed) {
			return style_computer.get_computation_context_for_property(.color, computed,
				element)
		}
	}
	if parent := element.element_to_inherit_style_from() {
		if dom_computed := parent.computed_properties() {
			if computed := computed_properties_from_dom(dom_computed) {
				return style_computer.get_computation_context_for_property(.color, computed,
					element)
			}
		}
	}
	return ComputationContext{
		length_resolution_context: LengthResolutionContext.for_element(&element)
		abstract_element:          element
	}
}

fn style_query_color_resolution_context(element dom.AbstractElement, computation_context ComputationContext) ColorResolutionContext {
	if dom_computed := element.computed_properties() {
		if computed := computed_properties_from_dom(dom_computed) {
			return color_resolution_context_for_computed_properties(computed,
				element.document(), CalculationResolutionContext{
					length_resolution_context: computation_context.length_resolution_context
					abstract_element:          element
				})
		}
	}
	if parent := element.element_to_inherit_style_from() {
		if dom_computed := parent.computed_properties() {
			if computed := computed_properties_from_dom(dom_computed) {
				return color_resolution_context_for_computed_properties(computed,
					element.document(), CalculationResolutionContext{
						length_resolution_context: computation_context.length_resolution_context
						abstract_element:          element
					})
			}
		}
	}
	return ColorResolutionContext{
		document:                       element.document()
		calculation_resolution_context: CalculationResolutionContext{
			length_resolution_context: computation_context.length_resolution_context
			abstract_element:          element
		}
	}
}

fn style_query_typed_value(value &dom.StyleValue) StyleValue {
	return typed_style_value_logic_from_dom(value) or {
		typed_style_value_logic_from_dom(parse_custom_property_value(value.css_text)) or {
			StyleValue(GuaranteedInvalidStyleValue.create())
		}
	}
}

fn style_query_registration_syntax(registration dom.CustomPropertyRegistration) ?SyntaxNode {
	return parse_as_syntax_with_ident_limit(
		parse_component_values_for_value_logic(registration.syntax), .yes)
}

fn style_query_comparable_custom_property_value(value &dom.StyleValue, registration ?dom.CustomPropertyRegistration, computation_context ComputationContext) StyleValue {
	mut typed := style_query_typed_value(value)
	if registered := registration {
		syntax := style_query_registration_syntax(registered) or { return typed }
		if syntax.type() != .universal && typed is UnresolvedStyleValue {
			typed = parse_with_a_syntax(typed.tokenize(), syntax)
		}
		if typed !is GuaranteedInvalidStyleValue && syntax.type() != .universal {
			typed = typed.absolutized(computation_context)
		}
	}
	return typed
}

fn style_query_initial_custom_property_value(document &dom.Document, property_name string, registration ?dom.CustomPropertyRegistration, computation_context ComputationContext) StyleValue {
	initial_text := document.custom_property_initial_value(property_name) or {
		return StyleValue(GuaranteedInvalidStyleValue.create())
	}
	initial_dom_value := parse_custom_property_value(initial_text)
	return style_query_comparable_custom_property_value(initial_dom_value, registration,
		computation_context)
}

fn style_query_inherited_custom_property_value(element dom.AbstractElement, property_name string, registration ?dom.CustomPropertyRegistration, computation_context ComputationContext, mut guarded_contexts GuardedSubstitutionContexts) StyleValue {
	if parent := element.element_to_inherit_style_from() {
		value := compute_value_of_custom_property_with_guarded_contexts(parent, property_name,
			mut guarded_contexts)
		return style_query_comparable_custom_property_value(value, registration,
			computation_context)
	}
	return style_query_initial_custom_property_value(element.document(), property_name,
		registration, computation_context)
}

fn style_query_values_are_equal(left StyleValue, right StyleValue, computation_context ComputationContext, color_resolution_context ColorResolutionContext) bool {
	left_is_invalid := left is GuaranteedInvalidStyleValue
	right_is_invalid := right is GuaranteedInvalidStyleValue
	if left_is_invalid || right_is_invalid {
		return left_is_invalid && right_is_invalid
	}

	left_absolutized := left.absolutized(computation_context)
	right_absolutized := right.absolutized(computation_context)
	left_color := left_absolutized.to_color(color_resolution_context)
	right_color := right_absolutized.to_color(color_resolution_context)
	if left_color != none || right_color != none {
		return left_color == right_color
	}

	calculation_resolution_context := CalculationResolutionContext.from_computation_context(computation_context,
		none)
	mut comparable_left := left_absolutized
	mut comparable_right := right_absolutized
	mut resolved_calculation := false
	if left_absolutized is CalculatedStyleValue {
		if resolved := left_absolutized.resolve_as_style_value(calculation_resolution_context) {
			comparable_left = resolved
			resolved_calculation = true
		}
	}
	if right_absolutized is CalculatedStyleValue {
		if resolved := right_absolutized.resolve_as_style_value(calculation_resolution_context) {
			comparable_right = resolved
			resolved_calculation = true
		}
	}
	if resolved_calculation {
		return comparable_left.equals(comparable_right)
	}
	return left_absolutized.equals(right_absolutized)
}

fn comparable_style_range_value(value StyleValue, computation_context ComputationContext) ?StyleRangeComparableValue {
	mut comparable := value.absolutized(computation_context)
	if comparable is CalculatedStyleValue {
		calculation_resolution_context := CalculationResolutionContext.from_computation_context(computation_context,
			none)
		comparable = comparable.resolve_as_style_value(calculation_resolution_context) or {
			return none
		}
	}

	return match comparable {
		IntegerStyleValue {
			StyleRangeComparableValue{
				type_: .number
				value: f64(comparable.integer())
			}
		}
		NumberStyleValue {
			StyleRangeComparableValue{
				type_: .number
				value: comparable.number()
			}
		}
		LengthStyleValue {
			if !comparable.length().is_absolute() {
				return none
			}
			StyleRangeComparableValue{
				type_: .length
				value: comparable.length().absolute_length_to_px_without_rounding()
			}
		}
		PercentageStyleValue {
			StyleRangeComparableValue{
				type_: .percentage
				value: comparable.percentage().value()
			}
		}
		AngleStyleValue {
			StyleRangeComparableValue{
				type_: .angle
				value: comparable.angle().to_degrees()
			}
		}
		TimeStyleValue {
			StyleRangeComparableValue{
				type_: .time
				value: comparable.time().to_seconds()
			}
		}
		FrequencyStyleValue {
			StyleRangeComparableValue{
				type_: .frequency
				value: comparable.frequency().to_hertz()
			}
		}
		ResolutionStyleValue {
			StyleRangeComparableValue{
				type_: .resolution
				value: comparable.resolution().to_dots_per_pixel()
			}
		}
		else {
			return none
		}
	}
}

fn style_range_numeric_type_is_dimension(type_ StyleRangeNumericType) bool {
	return type_ !in [.number, .percentage]
}

fn style_range_types_can_compare(left StyleRangeComparableValue, right StyleRangeComparableValue) bool {
	if left.type_ == right.type_ {
		return true
	}
	left_is_unitless_zero := left.type_ == .number && left.value == 0
	right_is_unitless_zero := right.type_ == .number && right.value == 0
	return (left_is_unitless_zero && style_range_numeric_type_is_dimension(right.type_))
		|| (right_is_unitless_zero && style_range_numeric_type_is_dimension(left.type_))
}

fn compare_style_range_values(left StyleRangeComparableValue, comparison MediaFeatureComparison, right StyleRangeComparableValue) bool {
	if !style_range_types_can_compare(left, right) {
		return false
	}
	return match comparison {
		.equal { left.value == right.value }
		.less_than { left.value < right.value }
		.less_than_or_equal { left.value <= right.value }
		.greater_than { left.value > right.value }
		.greater_than_or_equal { left.value >= right.value }
	}
}

fn parse_style_range_literal_value(tokens []ComponentValue) ?StyleValue {
	if contains_guaranteed_invalid_value(tokens) {
		return none
	}
	serialized_tokens := serialize_a_series_of_component_values(tokens)
	for value_type in [ValueType.number, .length, .percentage, .angle, .time, .frequency,
		.resolution] {
		mut parser := Parser.from_css_text(serialized_tokens)
		if value := parser.parse_entirely_as_type(value_type) {
			return value
		}
	}
	return none
}

fn record_style_range_attr_taint(tokens []ComponentValue, context BooleanExpressionEvaluationContext) {
	if !contains_attr_tainted_value(tokens) {
		return
	}
	if context.did_evaluate_attr_tainted_style_query != none {
		taint_flag := context.did_evaluate_attr_tainted_style_query or { return }
		unsafe {
			*taint_flag = true
		}
	}
}

fn evaluate_style_range_value(range_value StyleRangeValue, element dom.AbstractElement, document &dom.Document, computation_context ComputationContext, context BooleanExpressionEvaluationContext, mut guarded_contexts GuardedSubstitutionContexts) ?StyleRangeComparableValue {
	if range_value.is_property {
		property := range_value.property or { return none }
		if !property.is_custom_property() {
			return none
		}
		property_name := property.name()
		if guarded_contexts.mark_existing_as_cyclic(SubstitutionContext{
			dependency_type: .property
			first:           property_name
		}) {
			return none
		}

		computed_dom_value := compute_value_of_custom_property_with_guarded_contexts(element,
			property_name, mut guarded_contexts)
		computed_tokens := style_query_typed_value(computed_dom_value).tokenize()
		record_style_range_attr_taint(computed_tokens, context)
		registration := document.get_registered_custom_property(property_name)
		mut comparable_value := style_query_comparable_custom_property_value(computed_dom_value,
			registration, computation_context)
		if comparable_value is GuaranteedInvalidStyleValue {
			return none
		}
		if registration == none || comparable_value is UnresolvedStyleValue {
			comparable_value = parse_style_range_literal_value(computed_tokens) or { return none }
		}
		return comparable_style_range_value(comparable_value, computation_context)
	}

	record_style_range_attr_taint(range_value.value, context)
	parsed_value := parse_style_range_literal_value(range_value.value) or { return none }
	return comparable_style_range_value(parsed_value, computation_context)
}

fn evaluate_style_range_with_guarded_contexts(range &BooleanExpression, context BooleanExpressionEvaluationContext, mut guarded_contexts GuardedSubstitutionContexts) MatchResult {
	element := context.style_query_element or { return .unknown }
	document := context.document or { element.document() }
	computation_context := style_query_computation_context(element)

	left := evaluate_style_range_value(range.style_range_left, element, document,
		computation_context, context, mut guarded_contexts) or { return .false_ }
	middle := evaluate_style_range_value(range.style_range_middle, element, document,
		computation_context, context, mut guarded_contexts) or { return .false_ }
	if !compare_style_range_values(left, range.style_range_left_comparison, middle) {
		return .false_
	}
	if !range.style_range_has_right {
		return .true_
	}
	right := evaluate_style_range_value(range.style_range_right, element, document,
		computation_context, context, mut guarded_contexts) or { return .false_ }
	return as_match_result(compare_style_range_values(middle,
		range.style_range_right_comparison, right))
}

fn evaluate_style_range(range &BooleanExpression, context BooleanExpressionEvaluationContext) MatchResult {
	if mut guarded_contexts := context.guarded_contexts {
		return evaluate_style_range_with_guarded_contexts(range, context, mut guarded_contexts)
	}
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return evaluate_style_range_with_guarded_contexts(range, context, mut guarded_contexts)
}

fn evaluate_style_feature_with_guarded_contexts(property PropertyNameAndID, has_value bool, query_value []ComponentValue, context BooleanExpressionEvaluationContext, mut guarded_contexts GuardedSubstitutionContexts) MatchResult {
	element := context.style_query_element or { return .unknown }
	if !property.is_custom_property() {
		// if() is evaluated before the element's own non-custom computed values exist.
		return .false_
	}

	property_name := property.name()
	if guarded_contexts.mark_existing_as_cyclic(SubstitutionContext{
		dependency_type: .property
		first:           property_name
	}) {
		return .false_
	}

	mut query_css_wide_keyword := ?Keyword(none)
	if has_value {
		if contains_guaranteed_invalid_value(query_value) {
			return .false_
		}
		if keyword := single_style_query_css_wide_keyword(query_value) {
			if keyword in [.revert, .revert_layer] {
				return .false_
			}
			query_css_wide_keyword = keyword
		}
	}

	document := context.document or { element.document() }
	computed_dom_value := compute_value_of_custom_property_with_guarded_contexts(element,
		property_name, mut guarded_contexts)
	computed_tokens := style_query_typed_value(computed_dom_value).tokenize()
	if context.did_evaluate_attr_tainted_style_query != none {
		taint_flag := context.did_evaluate_attr_tainted_style_query or { return .false_ }
		if contains_attr_tainted_value(computed_tokens) {
			unsafe {
				*taint_flag = true
			}
		}
	}
	registration := document.get_registered_custom_property(property_name)
	computation_context := style_query_computation_context(element)
	color_resolution_context := style_query_color_resolution_context(element,
		computation_context)
	computed_value := style_query_comparable_custom_property_value(computed_dom_value,
		registration, computation_context)

	if !has_value {
		initial_value := style_query_initial_custom_property_value(document, property_name,
			registration, computation_context)
		return as_match_result(!style_query_values_are_equal(computed_value, initial_value,
			computation_context, color_resolution_context))
	}

	if keyword := query_css_wide_keyword {
		expected_value := match keyword {
			.initial {
				style_query_initial_custom_property_value(document, property_name, registration,
					computation_context)
			}
			.inherit {
				style_query_inherited_custom_property_value(element, property_name, registration,
					computation_context, mut guarded_contexts)
			}
			.unset {
				if registered := registration {
					if registered.inherits {
						style_query_inherited_custom_property_value(element, property_name,
							registration, computation_context, mut guarded_contexts)
					} else {
						style_query_initial_custom_property_value(document, property_name,
							registration, computation_context)
					}
				} else {
					style_query_inherited_custom_property_value(element, property_name,
						registration, computation_context, mut guarded_contexts)
				}
			}
			else { return .false_ }
		}
		return as_match_result(style_query_values_are_equal(computed_value, expected_value,
			computation_context, color_resolution_context))
	}

	if computed_value is GuaranteedInvalidStyleValue {
		return .false_
	}
	if registered := registration {
		syntax := style_query_registration_syntax(registered) or { return .false_ }
		mut parsed_query_value := parse_with_a_syntax(query_value, syntax)
		if parsed_query_value is GuaranteedInvalidStyleValue {
			return .false_
		}
		if syntax.type() != .universal {
			parsed_query_value = parsed_query_value.absolutized(computation_context)
		}
		return as_match_result(style_query_values_are_equal(computed_value,
			parsed_query_value, computation_context, color_resolution_context))
	}

	computed_value_string := serialize_a_series_of_component_values(computed_tokens).trim_space()
	query_value_string := serialize_a_series_of_component_values(query_value).trim_space()
	return as_match_result(computed_value_string == query_value_string)
}

// https://drafts.csswg.org/css-conditional-5/#style-container
fn evaluate_style_feature(property PropertyNameAndID, has_value bool, query_value []ComponentValue, context BooleanExpressionEvaluationContext) MatchResult {
	if mut guarded_contexts := context.guarded_contexts {
		return evaluate_style_feature_with_guarded_contexts(property, has_value, query_value,
			context, mut guarded_contexts)
	}
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return evaluate_style_feature_with_guarded_contexts(property, has_value, query_value,
		context, mut guarded_contexts)
}

fn (mut parser Parser) parse_container_query_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.next_token() or { return none }

	if first_token.is_function() && first_token.function().name.to_lower() == 'scroll-state' {
		function := first_token.function()
		mut inner := SupportsTokenStream.from_values(function.value)
		mut condition := parser.parse_scroll_state_feature(mut inner)
		inner.discard_whitespace()
		if condition == none || inner.has_next_token() {
			inner = SupportsTokenStream.from_values(function.value)
			condition = parser.parse_boolean_expression(mut inner, .unknown, .scroll_state_feature)
		}
		child := condition or { return none }
		inner.discard_whitespace()
		if inner.has_next_token() { return none }
		mut requirements := ContainerQueryFeatureRequirements{}
		child.collect_container_query_feature_requirements(mut requirements)
		if requirements.has_unknown_or_unsupported_feature { return none }
		transaction.discard_a_token()
		tokens = transaction
		return &BooleanExpression{kind: .scroll_state_query_function, children: [child]}
	}

	// `style( <style-query> )`
	if first_token.is_function() && first_token.function().name.to_lower() == 'style' {
		function := first_token.function()
		transaction.discard_a_token()
		mut inner_tokens := SupportsTokenStream.from_values(function.value)
		style_query := parser.parse_style_query(mut inner_tokens, .unknown) or { return none }
		inner_tokens.discard_whitespace()
		if inner_tokens.has_next_token() {
			return none
		}
		tokens = transaction
		return BooleanExpression.create_style_query_function(style_query)
	}

	if first_token.is_block() && first_token.block().is_paren() {
		transaction.discard_a_token()

		mut inner_tokens := SupportsTokenStream.from_values(first_token.block().value)
		feature := parser.parse_size_feature(mut inner_tokens) or { return none }
		inner_tokens.discard_whitespace()
		if inner_tokens.has_next_token() {
			return none
		}

		tokens = transaction
		return feature
	}
	return none
}

fn size_feature_is_known(name string) bool {
	return name.to_lower() in [
		'aspect-ratio',
		'block-size',
		'height',
		'inline-size',
		'orientation',
		'width',
	]
}

fn size_feature_type_is_range_name(name string) bool {
	return name.to_lower() in [
		'aspect-ratio',
		'block-size',
		'height',
		'inline-size',
		'width',
	]
}

fn parse_size_feature_name(mut tokens SupportsTokenStream, allow_min_max_prefix bool) ?MediaFeatureName {
	mut transaction := tokens
	token := transaction.consume_a_token() or { return none }
	if !token.is(.ident) {
		return none
	}

	lower := token.token().ident().to_lower()
	if size_feature_is_known(lower) {
		tokens = transaction
		return MediaFeatureName{
			name: lower
			prefix: .normal
		}
	}

	if allow_min_max_prefix && (lower.starts_with('min-') || lower.starts_with('max-')) {
		adjusted_name := lower[4..]
		if size_feature_is_known(adjusted_name) && size_feature_type_is_range_name(adjusted_name) {
			tokens = transaction
			return MediaFeatureName{
				name: adjusted_name
				prefix: if lower.starts_with('min-') { MediaFeatureNamePrefix.min } else { MediaFeatureNamePrefix.max }
			}
		}
	}
	return none
}

fn parse_size_feature_value_with_parser(mut parser Parser, feature_name string, mut tokens SupportsTokenStream) ?MediaFeatureValueLocal {
	media_feature_name := match feature_name {
		'aspect-ratio' { 'aspect-ratio' }
		'orientation' { 'orientation' }
		else { 'width' }
	}
	return parse_media_feature_value_with_parser(mut parser, media_feature_name, mut tokens)
}

fn (mut parser Parser) parse_size_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	if feature := parse_size_feature_boolean(mut parser, mut tokens) {
		return feature
	}
	if feature := parse_size_feature_plain(mut parser, mut tokens) {
		return feature
	}
	if feature := parse_size_feature_range(mut parser, mut tokens) {
		return feature
	}
	return none
}

fn parse_size_feature_boolean(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	_ = parser
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_size_feature_name(mut transaction, false) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	return BooleanExpression.create_size_feature('(${name.name})', name.name, .is_true,
		none, none, none, none)
}

fn parse_size_feature_plain(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_size_feature_name(mut transaction, true) or { return none }
	transaction.discard_whitespace()
	if !(transaction.consume_a_token() or { return none }).is(.colon) {
		return none
	}
	transaction.discard_whitespace()
	value := parse_size_feature_value_with_parser(mut parser, name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	match name.prefix {
		.normal {
			return BooleanExpression.create_size_feature('(${name.name}: ${value.text})',
				name.name, .exact_value, value, none, none, none)
		}
		.min {
			return BooleanExpression.create_size_feature('(min-${name.name}: ${value.text})',
				name.name, .min_value, value, none, none, none)
		}
		.max {
			return BooleanExpression.create_size_feature('(max-${name.name}: ${value.text})',
				name.name, .max_value, value, none, none, none)
		}
	}
}

fn find_size_feature_name_after_comparison(tokens SupportsTokenStream) ?MediaFeatureName {
	mut temp := tokens
	for temp.has_next_token() {
		if _ := parse_media_feature_comparison(mut temp) {
			temp.discard_whitespace()
			return parse_size_feature_name(mut temp, false)
		}
		temp.discard_a_token()
		temp.discard_whitespace()
	}
	return none
}

fn parse_size_feature_range(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	if name := parse_size_feature_name(mut transaction, false) {
		if !size_feature_type_is_range_name(name.name) {
			return none
		}
		transaction.discard_whitespace()
		if comparison := parse_media_feature_comparison(mut transaction) {
			transaction.discard_whitespace()
			if value := parse_size_feature_value_with_parser(mut parser, name.name, mut transaction) {
				transaction.discard_whitespace()
				if !transaction.has_next_token() && value.kind != .ident {
					tokens = transaction
					text := '(${name.name} ${media_feature_comparison_to_string(comparison)} ${value.text})'
					return BooleanExpression.create_size_feature(text, name.name,
						.half_range_query_left, value, comparison, none, none)
				}
			}
		}
	}

	transaction = SupportsTokenStream{
		values: tokens.values.clone()
		index: tokens.index
	}
	transaction.discard_whitespace()
	maybe_name := find_size_feature_name_after_comparison(transaction) or { return none }
	if !size_feature_type_is_range_name(maybe_name.name) {
		return none
	}
	left_value := parse_size_feature_value_with_parser(mut parser, maybe_name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	left_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	name_token := transaction.consume_a_token() or { return none }
	if !name_token.is(.ident)
		|| !equals_ignoring_ascii_case(name_token.token().ident(), maybe_name.name) {
		return none
	}
	transaction.discard_whitespace()

	if !transaction.has_next_token() {
		tokens = transaction
		text := '(${left_value.text} ${media_feature_comparison_to_string(left_comparison)} ${maybe_name.name})'
		return BooleanExpression.create_size_feature(text, maybe_name.name,
			.half_range_query_right, left_value, left_comparison, none, none)
	}

	right_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	right_value := parse_size_feature_value_with_parser(mut parser, maybe_name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	if transaction.has_next_token()
		|| !media_feature_comparisons_match(left_comparison, right_comparison)
		|| left_comparison == .equal || left_value.kind == .ident || right_value.kind == .ident {
		return none
	}

	tokens = transaction
	text := '(${left_value.text} ${media_feature_comparison_to_string(left_comparison)} ${maybe_name.name} ${media_feature_comparison_to_string(right_comparison)} ${right_value.text})'
	return BooleanExpression.create_size_feature(text, maybe_name.name, .range, left_value,
		left_comparison, right_comparison, right_value)
}

fn collect_size_feature_requirements(feature_name string, mut requirements ContainerQueryFeatureRequirements) {
	match feature_name {
		'aspect-ratio', 'orientation' {
			requirements.requires_width_container = true
			requirements.requires_height_container = true
		}
		'block-size' {
			requirements.requires_block_size_container = true
		}
		'height' {
			requirements.requires_height_container = true
		}
		'inline-size' {
			requirements.requires_inline_size_container = true
		}
		'width' {
			requirements.requires_width_container = true
		}
		else {
			requirements.has_unknown_or_unsupported_feature = true
		}
	}
}

fn size_feature_value_for_query_container(feature_name string, container &dom.Element) ?MediaFeatureValueLocal {
	layout_node := container.as_node().unsafe_layout_node() or { return none }
	if !layout_node.has_geometry_ {
		return none
	}
	dom_style := container.el_computed_properties() or { return none }
	style := computed_properties_from_dom(dom_style) or { return none }
	display := style.display()
	// Select the nearest declared container first. An ineligible principal box
	// makes this feature unknown; it must not fall through to an outer container.
	if display.is_none() || display.is_contents() || display.is_table_inside() || display.is_internal_table() { return none }
	if container.is_svg_element() && !is_outermost_svg_element_for_css_box_layout(container) { return none }
	if display.is_inline_outside() && display.is_flow_inside() && !layout_node.is_replaced_box_ && !container.is_svg_element() { return none }
	width := layout_node.content_width_ / container.document().layout_coordinate_scale()
	height := layout_node.content_height_ / container.document().layout_coordinate_scale()
	inline_axis_horizontal := style.writing_mode() == .horizontal_tb
	return match feature_name {
		'aspect-ratio' {
			media_feature_ratio_value(if height != 0 { width / height } else { 0.0 })
		}
		'block-size' {
			media_feature_length_value(if inline_axis_horizontal { height } else { width })
		}
		'height' {
			media_feature_length_value(height)
		}
		'inline-size' {
			media_feature_length_value(if inline_axis_horizontal { width } else { height })
		}
		'orientation' {
			media_feature_ident_value(if height >= width { 'portrait' } else { 'landscape' })
		}
		'width' {
			media_feature_length_value(width)
		}
		else {
			none
		}
	}
}

fn compare_size_feature_values(left MediaFeatureValueLocal, comparison MediaFeatureComparison, right MediaFeatureValueLocal, context LengthResolutionContext) MatchResult {
	if left.kind == .unknown || right.kind == .unknown {
		return .unknown
	}
	if left.kind != right.kind {
		return .false_
	}
	if left.kind == .ident {
		if comparison == .equal {
			return as_match_result(left.name == right.name)
		}
		return .false_
	}
	left_value := query_feature_numeric_value(left, context) or { return .false_ }
	right_value := query_feature_numeric_value(right, context) or { return .false_ }
	return match comparison {
		.equal { as_match_result(left_value == right_value) }
		.less_than { as_match_result(left_value < right_value) }
		.less_than_or_equal { as_match_result(left_value <= right_value) }
		.greater_than { as_match_result(left_value > right_value) }
		.greater_than_or_equal { as_match_result(left_value >= right_value) }
	}
}

fn evaluate_size_feature(feature_name string, kind MediaFeatureEvalKind, value ?MediaFeatureValueLocal, comparison ?MediaFeatureComparison, right_comparison ?MediaFeatureComparison, right_value ?MediaFeatureValueLocal, evaluation_context BooleanExpressionEvaluationContext) MatchResult {
	container := evaluation_context.query_container or { return .unknown }
	queried_value := size_feature_value_for_query_container(feature_name, container) or {
		mut document := unsafe { &dom.Document(container.document()) }
		// A container can remain boxless after layout (for example inside a
		// display:none subtree). Only defer while geometry can still change;
		// the stabilization loop itself does not imply unfinished layout.
		if !document.layout_is_up_to_date() {
			document.set_needs_container_query_evaluation_after_layout(container)
		}
		return .unknown
	}
	layout_node := container.as_node().unsafe_layout_node() or { return .unknown }
	length_context := length_resolution_context_from_layout_node(layout_node) or {
		LengthResolutionContext.for_document(container.document())
	}
	match kind {
		.is_true {
			return evaluate_media_feature_value_as_boolean(feature_name, queried_value,
				evaluation_context.document)
		}
		.exact_value {
			return compare_size_feature_values(queried_value, .equal,
				value or { return .unknown }, length_context)
		}
		.min_value {
			return compare_size_feature_values(queried_value, .greater_than_or_equal,
				value or { return .unknown }, length_context)
		}
		.max_value {
			return compare_size_feature_values(queried_value, .less_than_or_equal,
				value or { return .unknown }, length_context)
		}
		.half_range_query_left {
			return compare_size_feature_values(queried_value,
				comparison or { return .unknown }, value or { return .unknown }, length_context)
		}
		.half_range_query_right {
			return compare_size_feature_values(value or { return .unknown },
				comparison or { return .unknown }, queried_value, length_context)
		}
		.range {
			left_result := compare_size_feature_values(value or { return .unknown },
				comparison or { return .unknown }, queried_value, length_context)
			if left_result != .true_ {
				return left_result
			}
			return compare_size_feature_values(queried_value,
				right_comparison or { return .unknown }, right_value or { return .unknown },
				length_context)
		}
	}
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
