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
			if query.contains_size_feature() {
				mut mutable_container := unsafe { &dom.Element(container) }
				mutable_container.set_is_size_query_container()
			}
			return query.condition.evaluate(BooleanExpressionEvaluationContext{
				document: element.document()
				query_container: container
			})
		}
		candidate = container.as_node().flat_tree_parent_element()
	}
	return .unknown
}

fn has_ancestor_container_with_name(element dom.AbstractElement, container_name string) bool {
	mut candidate := element.element().as_node().flat_tree_parent_element()
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
	if rule.type_ != .container_rule || !rule.container_conditions_match(element) {
		return false
	}
	if parent := rule.parent_container_rule() {
		return parent.container_rule_matches(element)
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

pub fn (query &ContainerQuery) matches() bool {
	return query.matches_
}

pub fn (query &ContainerQuery) to_string() string {
	return query.condition.to_string()
}

fn (mut parser Parser) parse_container_query_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, .unknown, .container_query_feature)
}

fn (mut parser Parser) parse_container_query_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.next_token() or { return none }
	if !(first_token.is_block() && first_token.block().is_paren()) {
		return none
	}
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
	width := layout_node.content_width_
	height := layout_node.content_height_
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
		if !document.layout_is_up_to_date() || document.is_running_update_layout() {
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
