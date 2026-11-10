module css

import math

// Parser + evaluator for CSS math functions: calc(), min(), max(), clamp(), and the
// stepped/trig/exponential functions (round, mod, rem, sin, cos, tan, asin, acos, atan,
// atan2, pow, sqrt, hypot, log, exp, abs, sign) plus the numeric constants (pi, e,
// infinity, -infinity, NaN).
//
// A CalcNode tree is built during parsing and stored on the CalculatedStyleValue. It is
// used to (a) compute the expression's NumericType (for property acceptance and type
// validation), (b) serialize back to a canonical, re-parseable string, and (c) resolve to
// a concrete value at computed/used-value time via resolve() using a
// CalculationResolutionContext (see resolve_calc_node in calc_resolve.v).

// A parsed math-function expression. Recursion runs through the child arrays.
type CalcNode = CalcNumeric
	| CalcSum
	| CalcProduct
	| CalcNegate
	| CalcInvert
	| CalcFunction
	| CalcRandom
	| CalcAnchor
	| CalcAnchorSize
	| CalcTreeCounting
	| CalcChannel

// The kind of a numeric leaf, mirroring the C++ NumericValue variant.
enum CalcNumericKind {
	number
	length
	angle
	time
	frequency
	resolution
	flex
	percentage
}

// A leaf: a number, dimension, or percentage literal (numeric constants like pi are folded
// into number leaves at parse time, matching C++). `value` is the raw value in `unit`
// (unit is '' for a number, '%' for a percentage, or the dimension unit e.g. 'px'/'deg').
struct CalcNumeric {
	kind  CalcNumericKind
	value f64
	unit  string
	type_ NumericType
}

// a + b + c. Subtraction is represented by a CalcNegate child.
struct CalcSum {
	children []CalcNode
}

// a * b * c. Division is represented by a CalcInvert child.
struct CalcProduct {
	children []CalcNode
}

// -x. Holds exactly one child in children[0].
struct CalcNegate {
	children []CalcNode
}

// 1/x. Holds exactly one child in children[0].
struct CalcInvert {
	children []CalcNode
}

// A named math function: min/max/clamp/hypot/abs/sign/sin/cos/tan/asin/acos/atan/atan2/
// pow/sqrt/exp/log/mod/rem/round. `strategy` is the rounding strategy for round() (one of
// nearest/up/down/to-zero), empty otherwise.
struct CalcFunction {
	name     string
	strategy string
	children []CalcNode
}

// random() has a non-calculation value-sharing argument followed by two or
// three calculations, so it cannot use CalcFunction's homogeneous child
// representation. This mirrors RandomCalculationNode.
struct CalcRandom {
	sharing  RandomValueSharingStyleValue
	children []CalcNode // minimum, maximum, and optional step
}

// CSS Values' tree-counting functions are non-math calculation leaves. Their
// value depends on the styled element, so they remain symbolic until computed
// value resolution.
struct CalcTreeCounting {
	style_value TreeCountingFunctionStyleValue
}

// A channel keyword of a relative color (`r`, `h`, `alpha`, ...). It is a
// <number> whose value comes from the origin color when the color resolves.
// https://drafts.csswg.org/css-color-5/#relative-colors
struct CalcChannel {
	name string
}

// anchor() is a non-math calculation leaf whose length is supplied by layout
// after the anchor box and the inset axis are known.
struct CalcAnchor {
	style_value AnchorStyleValue
}

struct CalcAnchorSize {
	style_value AnchorSizeStyleValue
}

pub fn (value CalculatedStyleValue) contains_anchor_functions() bool {
	for node in value.node {
		if calc_node_contains_anchor_functions(node) { return true }
	}
	return false
}

// Computed min/max sizes keep percentages symbolic after anchor substitution.
pub fn (value CalculatedStyleValue) resolved_anchor_sizes(context CalculationResolutionContext) ?StyleValue {
	if value.node.len != 1 { return none }
	node := simplify_calc_with_resolution(value.node[0],value.calculation_context,context)
	if calc_node_contains_anchor_functions(node) { return none }
	return StyleValue(CalculatedStyleValue{
		serialization:node.serialize_top()
		numeric_type_:calculated_numeric_type_storage(value.numeric_type())
		node:[node]
		calculation_context:value.calculation_context
	})
}

fn calc_node_contains_anchor_functions(node CalcNode) bool {
	match node {
		CalcAnchor, CalcAnchorSize { return true }
		CalcSum, CalcProduct, CalcNegate, CalcInvert, CalcFunction, CalcRandom {
			for child in node.children {
				if calc_node_contains_anchor_functions(child) { return true }
			}
		}
		else {}
	}
	return false
}

fn calc_function_is_supported(name string) bool {
	return name in ['calc', 'min', 'max', 'clamp', 'hypot', 'abs', 'sign', 'sin', 'cos', 'tan',
		'asin', 'acos', 'atan', 'atan2', 'pow', 'sqrt', 'exp', 'log', 'mod', 'rem', 'round', 'random', 'progress']
}

// Entry point: parse a `<calc-function>` component value into a CalculatedStyleValue.
// Returns none (leaving `tokens` untouched) if the next token is not a supported math
// function, or if the expression is type-invalid.
fn parse_calculated_value(mut tokens ComponentValueStream) ?StyleValue {
	mut parser := Parser{}
	return parser.parse_calculated_value_with_context(mut tokens, CalculationContext{}, true)
}

fn (mut parser Parser) parse_calculated_value_with_context(mut tokens ComponentValueStream, context CalculationContext, allow_tree_counting_functions bool) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function() {
		return none
	}
	name := to_ascii_lowercase(component_value.function().name)
	if !calc_function_is_supported(name) {
		return none
	}
	parsed_without_context := parser.parse_calc_function_node(component_value.function(), allow_tree_counting_functions) or {
		return none
	}
	parsed := apply_calculation_context_to_calc_node(parsed_without_context, context)
	// Compute the type before simplification (the simplified tree has the same type, but
	// this also rejects type-invalid expressions).
	numeric_type := parsed.numeric_type() or { return none }
	// Simplify the constant parts at parse time so the specified value matches upstream.
	node := simplify_calc(parsed, context)
	tokens = transaction
	return StyleValue(CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: calculated_numeric_type_storage(numeric_type)
		node: [node]
		calculation_context: context
	})
}

// Build a typed calculation for expressions synthesized by other translated
// style-value algorithms. Those C++ call sites construct CalculationNode trees
// directly; parsing the deterministic serialization here produces the same V
// tree and avoids a string-only placeholder value.
fn calculated_style_value_from_text(serialization string) StyleValue {
	mut parser := Parser.from_css_text(serialization)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_calculated_value_with_context(mut tokens, CalculationContext{}, true) or {
		panic('generated an invalid CSS calculation: ${serialization}')
	}
	if tokens.has_more_tokens() {
		panic('generated a non-standalone CSS calculation: ${serialization}')
	}
	return value
}

// The kinds of value a calc can be asked to resolve to (used to gate acceptance per
// producer, matching the C++ `calc->resolves_to_X()` checks).
enum CalcMatchKind {
	number
	integer
	length
	percentage
	angle
	angle_percentage
	time
	time_percentage
	frequency
	frequency_percentage
	resolution
	flex
	length_percentage
}

fn calc_type_matches(numeric_type NumericType, kind CalcMatchKind, percentages_resolve_as ?ValueType) bool {
	return match kind {
		.number { numeric_type.matches_number(percentages_resolve_as) }
		.integer { numeric_type.matches_number(percentages_resolve_as) }
		.length { numeric_type.matches_length(percentages_resolve_as) }
		.percentage { numeric_type.matches_percentage() }
		.angle { numeric_type.matches_angle(percentages_resolve_as) }
		.angle_percentage { numeric_type.matches_angle_percentage(percentages_resolve_as) }
		.time { numeric_type.matches_time(percentages_resolve_as) }
		.time_percentage { numeric_type.matches_time_percentage(percentages_resolve_as) }
		.frequency { numeric_type.matches_frequency(percentages_resolve_as) }
		.frequency_percentage { numeric_type.matches_frequency_percentage(percentages_resolve_as) }
		.resolution { numeric_type.matches_resolution(percentages_resolve_as) }
		.flex { numeric_type.matches_flex(percentages_resolve_as) }
		// For <length-percentage>, percentages resolve against <length>: a mixed calc
		// like `calc(100% - 10px)` has a "length" percent hint, which only matches when
		// percentages_resolve_as is <length>.
		.length_percentage {
			if percentages_resolve_as == none {
				numeric_type.matches_length_percentage(ValueType.length)
			} else {
				numeric_type.matches_length_percentage(percentages_resolve_as)
			}
		}
	}
}

// Try to parse a calc that resolves to the given kind. Consumes from `tokens` only on success.
fn (mut parser Parser) parse_calculated_value_of_kind(mut tokens ComponentValueStream, kind CalcMatchKind) ?StyleValue {
	mut transaction := tokens.clone()
	context := parser.calculation_context()
	value := parser.parse_calculated_value_with_context(mut transaction, context, parser.context_allows_tree_counting_functions()) or { return none }
	if value is CalculatedStyleValue {
		numeric_type := value.numeric_type() or { return none }
		if !calc_kind_allows_percentages(kind, context.percentages_resolve_as) {
			for node in value.node {
				if calc_node_contains_percentage(node) {
					return none
				}
			}
		}
		if calc_type_matches(numeric_type, kind, context.percentages_resolve_as) {
			tokens = transaction
			return value
		}
	}
	return none
}

// A calculation for a dimension without a <percentage> alternative, such as
// the <angle> of rotate(), takes percentages only where the context resolves
// them against that dimension. Elsewhere a percentage has nothing to resolve
// against, so atan2(90px, 100%) is invalid there even though its arguments
// have a consistent type.
fn calc_kind_allows_percentages(kind CalcMatchKind, percentages_resolve_as ?ValueType) bool {
	dimension := match kind {
		.angle { ValueType.angle }
		.time { ValueType.time }
		.frequency { ValueType.frequency }
		.resolution { ValueType.resolution }
		.flex { ValueType.flex }
		else { return true }
	}
	resolves_as := percentages_resolve_as or { return false }
	return resolves_as == dimension
}

fn calc_node_contains_percentage(node CalcNode) bool {
	match node {
		CalcNumeric {
			return node.kind == .percentage
		}
		CalcSum, CalcProduct, CalcNegate, CalcInvert, CalcFunction, CalcRandom {
			for child in node.children {
				if calc_node_contains_percentage(child) {
					return true
				}
			}
		}
		else {}
	}
	return false
}

fn (mut parser Parser) parse_calc_function_node(function Function, allow_tree_counting_functions bool) ?CalcNode {
	name := to_ascii_lowercase(function.name)
	if name == 'calc' {
		mut inner := ComponentValueStream.new(function.value)
		return parser.parse_a_calculation(mut inner, allow_tree_counting_functions)
	}
	if name == 'round' {
		return parser.parse_round_function(function.value, allow_tree_counting_functions)
	}
	if name == 'random' {
		return parser.parse_random_function(function.value, allow_tree_counting_functions)
	}
	if !calc_function_is_supported(name) {
		return none
	}
	call_arguments := parser.parse_calc_arguments(function.value, allow_tree_counting_functions) or {
		return none
	}
	return build_calc_function(name, call_arguments, '')
}

fn calc_rounding_strategy_from_string(ident string) ?string {
	strategy := to_ascii_lowercase(ident)
	if strategy in ['nearest', 'up', 'down', 'to-zero'] {
		return strategy
	}
	return none
}

fn (mut parser Parser) parse_round_function(values []ComponentValue, allow_tree_counting_functions bool) ?CalcNode {
	argument_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
	mut strategy := 'nearest'
	mut numeric_lists := argument_lists.clone()

	// An optional leading <rounding-strategy> keyword.
	if argument_lists.len == 3 {
		first := argument_lists[0]
		mut probe := ComponentValueStream.new(first)
		probe.consume_whitespace()
		if keyword_token := probe.consume() {
			probe.consume_whitespace()
			if keyword_token.is(.ident) && !probe.has_more_tokens() {
				strategy = calc_rounding_strategy_from_string(keyword_token.token().ident()) or {
					return none
				}
				numeric_lists = argument_lists[1..].clone()
			} else {
				return none
			}
		}
	}

	if numeric_lists.len != 2 {
		return none
	}
	mut call_arguments := []CalcNode{}
	for argument in numeric_lists {
		mut stream := ComponentValueStream.new(argument)
		call_arguments << (parser.parse_a_calculation(mut stream, allow_tree_counting_functions) or {
			return none
		})
	}
	return build_calc_function('round', call_arguments, strategy)
}

// https://drafts.csswg.org/css-values-5/#typedef-random-value-sharing
fn (mut parser Parser) parse_random_value_sharing(mut tokens ComponentValueStream) ?RandomValueSharingStyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	if first := transaction.peek() {
		if first.is(.ident) && equals_ignoring_ascii_case(first.token().ident(), 'fixed') {
			transaction.consume()
			transaction.consume_whitespace()
			parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.random_value_sharing_fixed_value))
			fixed_value := parser.parse_number_value(mut transaction) or {
				parser.pop_temporary_value_parsing_context()
				return none
			}
			parser.pop_temporary_value_parsing_context()
			transaction.consume_whitespace()
			if transaction.has_more_tokens() {
				return none
			}
			if fixed_value is NumberStyleValue
				&& (fixed_value.number() < 0 || fixed_value.number() >= 1) {
				return none
			}
			tokens = transaction
			return RandomValueSharingStyleValue.create_fixed(fixed_value)
		}
	}

	mut has_explicit_auto := false
	mut dashed_ident := ?string(none)
	mut element_shared := false
	for transaction.has_more_tokens() {
		mut dashed_attempt := transaction.clone()
		if maybe_dashed_ident := parser.parse_dashed_ident_value(mut dashed_attempt, []) {
			if has_explicit_auto || dashed_ident != none {
				return none
			}
			dashed_ident = maybe_dashed_ident.as_custom_ident().custom_ident()
			transaction = dashed_attempt
			transaction.consume_whitespace()
			continue
		}

		mut keyword_attempt := transaction.clone()
		keyword_value := parser.parse_keyword_value(mut keyword_attempt) or { return none }
		keyword := keyword_value.to_keyword()
		if keyword == .auto {
			if has_explicit_auto || dashed_ident != none {
				return none
			}
			has_explicit_auto = true
		} else if keyword == .element_shared {
			if element_shared {
				return none
			}
			element_shared = true
		} else {
			return none
		}
		transaction = keyword_attempt
		transaction.consume_whitespace()
	}

	tokens = transaction
	if name := dashed_ident {
		return RandomValueSharingStyleValue.create_dashed_ident(name, element_shared)
	}
	return RandomValueSharingStyleValue.create_auto(parser.random_value_sharing_auto_name(), element_shared)
}

fn random_argument_type_is_accepted(type_ NumericType, percentages_resolve_as ?ValueType) bool {
	return type_.matches_number(percentages_resolve_as) || type_.matches_dimension()
		|| type_.matches_percentage()
}

// Generated from MathFunctions.json's random entry in the C++ build. The
// optional value-sharing argument is probed before the required numeric range.
fn (mut parser Parser) parse_random_function(values []ComponentValue, allow_tree_counting_functions bool) ?CalcNode {
	if !parser.context_allows_random_functions() {
		return none
	}
	parser.random_function_index++

	argument_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
	if argument_lists.len < 2 || argument_lists.len > 4 {
		return none
	}

	mut argument_index := 0
	mut sharing := RandomValueSharingStyleValue.create_auto(parser.random_value_sharing_auto_name(), false)
	mut sharing_tokens := ComponentValueStream.new(argument_lists[argument_index])
	if parsed_sharing := parser.parse_random_value_sharing(mut sharing_tokens) {
		sharing = parsed_sharing
		argument_index++
	}

	remaining_count := argument_lists.len - argument_index
	if remaining_count < 2 || remaining_count > 3 {
		return none
	}

	context := parser.calculation_context()
	mut children := []CalcNode{cap: remaining_count}
	mut determined_type := ?NumericType(none)
	for argument_lists_index := argument_index; argument_lists_index < argument_lists.len; argument_lists_index++ {
		mut argument_tokens := ComponentValueStream.new(argument_lists[argument_lists_index])
		child := parser.parse_a_calculation(mut argument_tokens, allow_tree_counting_functions) or {
			return none
		}
		child_type := child.numeric_type() or { return none }
		if !random_argument_type_is_accepted(child_type, context.percentages_resolve_as) {
			return none
		}
		if previous_type := determined_type {
			determined_type = previous_type.consistent_type(child_type) or { return none }
		} else {
			determined_type = child_type
		}
		children << child
	}

	return CalcNode(CalcRandom{
		sharing: sharing
		children: children
	})
}

fn build_calc_function(name string, arguments []CalcNode, strategy string) ?CalcNode {
	valid_arity := match name {
		'min', 'max', 'hypot' { arguments.len >= 1 }
		'clamp', 'progress' { arguments.len == 3 }
		'abs', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'exp' {
			arguments.len == 1
		}
		'log' { arguments.len == 1 || arguments.len == 2 }
		'atan2', 'pow', 'mod', 'rem', 'round' { arguments.len == 2 }
		else { false }
	}
	if !valid_arity {
		return none
	}
	if calc_function_requires_same_parameter_types(name) {
		mut determined_argument_type := ?NumericType(none)
		for argument in arguments {
			argument_type := argument.numeric_type() or { return none }
			if previous_type := determined_argument_type {
				if previous_type != argument_type {
					return none
				}
			} else {
				determined_argument_type = argument_type
			}
		}
	}
	node := CalcNode(CalcFunction{
		name: name
		strategy: strategy
		children: arguments
	})
	// Validate that the argument types satisfy the function and produce a valid result type.
	node.numeric_type() or { return none }
	return node
}

// Upstream's math-function parser is generated from MathFunctions.json, where each function
// carries a `parameter-validation` rule. `consistent` unifies the argument types through
// consistent_type(), while `same` requires every argument to have the exact same type -
// including its percent hint. mod(), rem(), and log() use `same`, so `mod(2em, 50%)` is
// invalid for a <length-percentage> property even though `min(2em, 50%)` is not.
fn calc_function_requires_same_parameter_types(name string) bool {
	return name in ['log', 'mod', 'rem']
}

fn (mut parser Parser) parse_calc_arguments(values []ComponentValue, allow_tree_counting_functions bool) ?[]CalcNode {
	argument_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
	mut result := []CalcNode{}
	for argument in argument_lists {
		mut stream := ComponentValueStream.new(argument)
		node := parser.parse_a_calculation(mut stream, allow_tree_counting_functions) or { return none }
		result << node
	}
	return result
}

// One entry in the flat operand/operator sequence collected from the token stream.
struct CalcTerm {
	is_operator bool
	operator    u8 // '+' '-' '*' '/' when is_operator
	node        CalcNode // the operand when !is_operator
}

// https://drafts.csswg.org/css-values-4/#parse-a-calculation
// Parses the tokens of a calc() body (or a parenthesised group / math-function argument)
// into a single CalcNode, honouring `*`/`/` binding tighter than `+`/`-`.
fn (mut parser Parser) parse_a_calculation(mut tokens ComponentValueStream, allow_tree_counting_functions bool) ?CalcNode {
	mut terms := []CalcTerm{}
	for {
		tokens.consume_whitespace()
		component_value := tokens.consume() or { break }
		if component_value.is_delim(u32(`+`)) || component_value.is_delim(u32(`-`)) || component_value.is_delim(u32(`*`)) || component_value.is_delim(u32(`/`)) {
			terms << CalcTerm{
				is_operator: true
				operator: u8(component_value.token().delim())
			}
		} else {
			leaf := parser.convert_calc_leaf(component_value, allow_tree_counting_functions) or {
				return none
			}
			terms << CalcTerm{
				is_operator: false
				node: leaf
			}
		}
	}

	// Must be a non-empty, alternating operand/operator/operand... sequence.
	if terms.len == 0 || terms.len % 2 == 0 {
		return none
	}
	for index, term in terms {
		expect_operator := (index % 2) == 1
		if term.is_operator != expect_operator {
			return none
		}
	}

	return fold_calc_terms(terms)
}

fn make_calc_product(factors []CalcNode) CalcNode {
	if factors.len == 1 {
		return factors[0]
	}
	return CalcNode(CalcProduct{
		children: factors
	})
}

fn (mut parser Parser) convert_calc_leaf(component_value ComponentValue, allow_tree_counting_functions bool) ?CalcNode {
	if component_value.is_block() {
		block := component_value.block()
		if !block.is_paren() {
			return none
		}
		mut inner := ComponentValueStream.new(block.value)
		return parser.parse_a_calculation(mut inner, allow_tree_counting_functions)
	}
	if component_value.is_function() {
		name := to_ascii_lowercase(component_value.function().name)
		if name == 'anchor-size' {
			mut anchor_tokens := ComponentValueStream.new([component_value])
			anchor := parser.parse_anchor_size(mut anchor_tokens) or { return none }
			if anchor !is AnchorSizeStyleValue { return none }
			return CalcNode(CalcAnchorSize{style_value: anchor as AnchorSizeStyleValue})
		}
		if name == 'anchor' {
			mut anchor_tokens := ComponentValueStream.new([component_value])
			anchor := parser.parse_anchor(mut anchor_tokens) or { return none }
			if anchor !is AnchorStyleValue {
				return none
			}
			return CalcNode(CalcAnchor{
				style_value: anchor as AnchorStyleValue
			})
		}
		if name in ['sibling-count', 'sibling-index'] {
			mut tree_parser := Parser{}
			if !allow_tree_counting_functions {
				tree_parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.media_condition))
			}
			mut tree_tokens := ComponentValueStream.new([component_value])
			style_value := tree_parser.parse_tree_counting_function(mut tree_tokens, .number) or {
				return none
			}
			return CalcNode(CalcTreeCounting{
				style_value: style_value
			})
		}
		if !calc_function_is_supported(name) {
			return none
		}
		return parser.parse_calc_function_node(component_value.function(), allow_tree_counting_functions)
	}
	if component_value.is(.ident) {
		if parser.relative_color_channels.len > 0 {
			name := to_ascii_lowercase(component_value.token().ident())
			if name in parser.relative_color_channels {
				return CalcNode(CalcChannel{
					name: name
				})
			}
		}
		return calc_constant_from_ident(component_value.token().ident())
	}
	if component_value.is(.number) {
		number := component_value.token().number()
		return CalcNode(CalcNumeric{
			kind: .number
			value: number.value()
			unit: ''
			type_: NumericType.new()
		})
	}
	if component_value.is(.percentage) {
		return CalcNode(CalcNumeric{
			kind: .percentage
			value: component_value.token().percentage()
			unit: '%'
			type_: NumericType.with_type(.percent, 1)
		})
	}
	if component_value.is(.dimension) {
		unit := to_ascii_lowercase(component_value.token().dimension_unit())
		numeric_type := NumericType.create_from_unit(unit) or { return none }
		dimension := dimension_for_unit(unit) or { return none }
		return CalcNode(CalcNumeric{
			kind: calc_numeric_kind_from_dimension(dimension)
			value: component_value.token().dimension_value()
			unit: unit
			type_: numeric_type
		})
	}
	return none
}

fn calc_numeric_kind_from_dimension(dimension DimensionType) CalcNumericKind {
	return match dimension {
		.length { CalcNumericKind.length }
		.angle { CalcNumericKind.angle }
		.time { CalcNumericKind.time }
		.frequency { CalcNumericKind.frequency }
		.resolution { CalcNumericKind.resolution }
		.flex { CalcNumericKind.flex }
	}
}

fn calculation_percentage_numeric_type(context CalculationContext) NumericType {
	if resolves_as := context.percentages_resolve_as {
		if resolves_as != .number && resolves_as != .percentage {
			base_type := NumericType.base_type_from_value_type(resolves_as) or {
				return NumericType.with_type(.percent, 1)
			}
			mut result := NumericType.with_type(base_type, 1)
			result.percent_hint = base_type
			return result
		}
	}
	return NumericType.with_type(.percent, 1)
}

// Percentage leaf types depend on the context containing the math function. C++
// constructs every NumericCalculationNode with that CalculationContext; the V parser
// first builds its recursive tree, so apply the same typing in one post-parse walk.
fn apply_calculation_context_to_calc_node(node CalcNode, context CalculationContext) CalcNode {
	match node {
		CalcNumeric {
			if node.kind == .percentage {
				return CalcNode(CalcNumeric{
					kind: node.kind
					value: node.value
					unit: node.unit
					type_: calculation_percentage_numeric_type(context)
				})
			}
			return node
		}
		CalcTreeCounting, CalcChannel {
			return node
		}
		CalcAnchor, CalcAnchorSize {
			return node
		}
		CalcSum {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << apply_calculation_context_to_calc_node(child, context)
			}
			return CalcNode(CalcSum{
				children: children
			})
		}
		CalcProduct {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << apply_calculation_context_to_calc_node(child, context)
			}
			return CalcNode(CalcProduct{
				children: children
			})
		}
		CalcNegate {
			return CalcNode(CalcNegate{
				children: [
					apply_calculation_context_to_calc_node(node.children[0], context),
				]
			})
		}
		CalcInvert {
			return CalcNode(CalcInvert{
				children: [
					apply_calculation_context_to_calc_node(node.children[0], context),
				]
			})
		}
		CalcFunction {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << apply_calculation_context_to_calc_node(child, context)
			}
			return CalcNode(CalcFunction{
				name: node.name
				strategy: node.strategy
				children: children
			})
		}
		CalcRandom {
			mut children := []CalcNode{cap: node.children.len}
			for child in node.children {
				children << apply_calculation_context_to_calc_node(child, context)
			}
			return CalcNode(CalcRandom{
				sharing: node.sharing
				children: children
			})
		}
	}
}

// https://drafts.csswg.org/css-values-4/#calc-constants - resolved to number leaves at parse time.
fn calc_constant_from_ident(ident string) ?CalcNode {
	value := match to_ascii_lowercase(ident) {
		'e' { math.e }
		'pi' { math.pi }
		'infinity' { math.inf(1) }
		'-infinity' { math.inf(-1) }
		'nan' { math.nan() }
		else {
			return none
		}
	}
	return CalcNode(CalcNumeric{
		kind: .number
		value: value
		unit: ''
		type_: NumericType.new()
	})
}

// --- Numeric type computation ---
fn (node CalcNode) numeric_type() ?NumericType {
	match node {
		CalcNumeric {
			return node.type_
		}
		CalcTreeCounting, CalcChannel {
			return NumericType.new()
		}
		CalcAnchor, CalcAnchorSize {
			return NumericType.with_type(.length, 1)
		}
		CalcSum {
			mut result := node.children[0].numeric_type() or { return none }
			for index := 1; index < node.children.len; index++ {
				child_type := node.children[index].numeric_type() or { return none }
				result = result.added_to(child_type) or { return none }
			}
			return result
		}
		CalcProduct {
			mut result := node.children[0].numeric_type() or { return none }
			for index := 1; index < node.children.len; index++ {
				child_type := node.children[index].numeric_type() or { return none }
				result = result.multiplied_by(child_type) or { return none }
			}
			return result
		}
		CalcNegate {
			return node.children[0].numeric_type()
		}
		CalcInvert {
			child_type := node.children[0].numeric_type() or { return none }
			return child_type.inverted()
		}
		CalcFunction {
			return calc_function_numeric_type(node.name, node.children)
		}
		CalcRandom {
			return calc_consistent_children_type(node.children)
		}
	}
	return none
}

// The consistent type of all children (used by min/max/clamp/hypot/round/mod/rem/abs/atan2).
fn calc_consistent_children_type(children []CalcNode) ?NumericType {
	mut result := children[0].numeric_type() or { return none }
	for index := 1; index < children.len; index++ {
		child_type := children[index].numeric_type() or { return none }
		result = result.consistent_type(child_type) or { return none }
	}
	return result
}

fn calc_function_numeric_type(name string, children []CalcNode) ?NumericType {
	match name {
		'min', 'max', 'clamp', 'hypot', 'abs', 'mod', 'rem', 'round' {
			// Type-preserving: the result has the consistent type of the arguments.
			return calc_consistent_children_type(children)
		}
		'progress' {
			calc_consistent_children_type(children) or { return none }
			return NumericType.new()
		}
		'sign' {
			// <number>|<dimension>|<percentage> in, <number> out.
			children[0].numeric_type() or { return none }
			return NumericType.new()
		}
		'sin', 'cos', 'tan' {
			// <number>|<angle> in, <number> out.
			child_type := children[0].numeric_type() or { return none }
			if !child_type.matches_number(none) && !child_type.matches_angle(none) {
				return none
			}
			return NumericType.new()
		}
		'asin', 'acos', 'atan' {
			// <number> in, <angle> out.
			child_type := children[0].numeric_type() or { return none }
			if !child_type.matches_number(none) {
				return none
			}
			return NumericType.with_type(.angle, 1)
		}
		'atan2' {
			// consistent <number>|<dimension>|<percentage> in, <angle> out.
			calc_consistent_children_type(children) or { return none }
			return NumericType.with_type(.angle, 1)
		}
		'pow', 'sqrt', 'exp', 'log' {
			// <number> in, <number> out.
			for child in children {
				child_type := child.numeric_type() or { return none }
				if !child_type.matches_number(none) {
					return none
				}
			}
			return NumericType.new()
		}
		else {
			return none
		}
	}
}

// --- Serialization ---

// https://drafts.csswg.org/css-values-4/#serialize-a-math-function
// The complete serialization, including the outer `calc(...)`/`min(...)`/... wrapper.
fn (node CalcNode) serialize_top() string {
	// 2. If the root represents an infinite or NaN value, serialize the corresponding
	//    keyword; a non-<number> type additionally multiplies it by one canonical unit so
	//    the serialization keeps its type. This step only applies to the root: a non-finite
	//    leaf nested inside the tree serializes through its ordinary numeric rules.
	if node is CalcNumeric {
		if keyword := node.non_finite_keyword() {
			return 'calc(' + node.serialize_non_finite(keyword) + ')'
		}
	}

	if node is CalcAnchorSize { return node.style_value.serialize(.normal) }

	// AD-HOC: random() is serialized directly because its value-sharing argument is not a
	//         calculation node and its step is optional.
	if node is CalcRandom {
		return node.serialize_function()
	}

	// 3. A numeric value or calc-operator root is wrapped in `calc(`; a math function uses
	//    its own name and comma-separated arguments.
	if node is CalcFunction {
		return node.serialize_function()
	}

	// 4. The root's own outer parentheses are supplied by the `calc(...)` wrapper.
	return 'calc(' + serialize_a_calculation_tree(node, false) + ')'
}

// https://drafts.csswg.org/css-values-4/#serialize-a-calculation-tree
// `emit_outer_parentheses` is false only where the caller already supplies the enclosing
// delimiters: the root of a math function and each of its comma-separated arguments. Every
// nested Sum, Product, Negate, and Invert is parenthesised, which is what keeps a
// serialization re-parseable as the same tree (`1px / (1em / 1vw)` is not `1px / 1em / 1vw`).
fn serialize_a_calculation_tree(node CalcNode, emit_outer_parentheses bool) string {
	match node {
		// 2. A numeric value, or a non-math function, serializes per the normal rules for it.
		CalcNumeric {
			return node.serialize_leaf()
		}
		CalcTreeCounting {
			return node.style_value.serialize(.normal)
		}
		CalcChannel {
			return node.name
		}
		CalcAnchor {
			return node.style_value.serialize(.normal)
		}
		CalcAnchorSize {
			return node.style_value.serialize(.normal)
		}

		// 3. Anything that is not a calc-operator node serializes as a math function.
		CalcFunction {
			return node.serialize_function()
		}
		CalcRandom {
			return node.serialize_function()
		}

		// 4. A Negate node serializes as a multiplication by -1.
		CalcNegate {
			return wrap_a_calculation_tree('-1 * ' + serialize_a_calculation_tree(node.children[0], true), emit_outer_parentheses)
		}

		// 5. An Invert node serializes as a division of 1.
		CalcInvert {
			return wrap_a_calculation_tree('1 / ' + serialize_a_calculation_tree(node.children[0], true), emit_outer_parentheses)
		}

		// 6. / 7. Sum and Product nodes serialize their sorted children.
		CalcSum {
			return wrap_a_calculation_tree(serialize_calc_sum(node.children), emit_outer_parentheses)
		}
		CalcProduct {
			return wrap_a_calculation_tree(serialize_calc_product(node.children), emit_outer_parentheses)
		}
	}
	return ''
}

fn wrap_a_calculation_tree(serialized string, emit_outer_parentheses bool) string {
	return if emit_outer_parentheses { '(' + serialized + ')' } else { serialized }
}

// Mirrors NumericCalculationNode::serialize_value: the leaf is serialized by its own value
// type. Only <number> spells its non-finite values as keywords (`Number::serialize`);
// percentages and dimensions print the raw number, so they serialize as `infpx`/`inf%`.
fn (leaf CalcNumeric) serialize_leaf() string {
	if leaf.kind == .number {
		if keyword := leaf.non_finite_keyword() {
			return keyword
		}
	}
	return serialize_a_number(leaf.value) + leaf.unit
}

// Mirrors NumericCalculationNode::infinite_or_nan_value(), spelled as the keyword that
// represents it.
fn (leaf CalcNumeric) non_finite_keyword() ?string {
	if math.is_nan(leaf.value) {
		return 'NaN'
	}
	if math.is_inf(leaf.value, 1) {
		return 'infinity'
	}
	if math.is_inf(leaf.value, -1) {
		return '-infinity'
	}
	return none
}

// https://drafts.csswg.org/css-values-4/#serialize-a-math-function
// Step 1 of "serialize a math function": when the root of the calculation tree is a numeric
// value and the serialization is of a computed value or later, the value is clamped to the
// range its context allows before being serialized. clamp_and_censor_numeric_value().
fn (leaf CalcNumeric) clamp_and_censor(context CalculationContext) CalcNumeric {
	value_type := match leaf.kind {
		.number {
			if context.resolve_numbers_as_integers { ValueType.integer } else { ValueType.number }
		}
		.length { ValueType.length }
		.angle { ValueType.angle }
		.time { ValueType.time }
		.frequency { ValueType.frequency }
		.resolution { ValueType.resolution }
		.flex { ValueType.flex }
		.percentage { ValueType.percentage }
	}
	accepted_range := context.accepted_type_ranges[value_type] or {
		if value_type == .integer {
			AcceptedTypeRange{
				min: f64(-2147483647 - 1)
				max: f64(2147483647)
			}
		} else {
			AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
	}

	// An integer context rounds before censoring, so an infinite value saturates at the
	// integer range rather than at the accepted floating-point one.
	mut value := if leaf.kind == .number && context.resolve_numbers_as_integers {
		f64(Number.with_type(.number, leaf.value).integer_value())
	} else {
		leaf.value
	}

	// https://drafts.csswg.org/css-values/#calc-ieee
	// NaN does not escape a top-level calculation; it is censored into a zero value.
	if math.is_nan(value) {
		value = 0
	}

	// https://drafts.csswg.org/css-values/#calc-range
	// The value resulting from a top-level calculation must be clamped to the range allowed
	// in the target context.
	if value < accepted_range.min {
		value = accepted_range.min
	}
	if value > accepted_range.max {
		value = accepted_range.max
	}

	return CalcNumeric{
		kind: leaf.kind
		value: value
		unit: leaf.unit
		type_: leaf.type_
	}
}

// Mirrors `clamped_value.visit([&](auto const& value) { value.serialize(builder, mode); })`:
// the leaf is serialized by its own numeric type, so a resolved value also converts a
// non-canonical unit to the canonical one.
fn (leaf CalcNumeric) serialize_numeric_value(mode SerializationMode) string {
	match leaf.kind {
		.number {
			return Number.with_type(.number, leaf.value).serialize(mode)
		}
		.percentage {
			return Percentage.new(leaf.value).serialize(mode)
		}
		.length {
			if unit := string_to_length_unit(leaf.unit) {
				return Length.new(leaf.value, unit).serialize(mode)
			}
		}
		.angle {
			if unit := string_to_angle_unit(leaf.unit) {
				return Angle.new(leaf.value, unit).serialize(mode)
			}
		}
		.time {
			if unit := string_to_time_unit(leaf.unit) {
				return Time.new(leaf.value, unit).serialize(mode)
			}
		}
		.frequency {
			if unit := string_to_frequency_unit(leaf.unit) {
				return Frequency.new(leaf.value, unit).serialize(mode)
			}
		}
		.resolution {
			if unit := string_to_resolution_unit(leaf.unit) {
				return Resolution.new(leaf.value, unit).serialize(mode)
			}
		}
		.flex {
			if unit := string_to_flex_unit(leaf.unit) {
				return Flex.new(leaf.value, unit).serialize(mode)
			}
		}
	}
	return leaf.serialize_leaf()
}

// Step 3 of "serialize a math function": a non-finite <number> is just the keyword, while
// any other type is multiplied by one unit in the canonical unit for that type (such as
// `infinity * 1px` for a <length>), so the serialization stays typed and re-parses.
fn (leaf CalcNumeric) serialize_non_finite(keyword string) string {
	if leaf.kind == .number {
		return keyword
	}
	return '${keyword} * 1${calc_numeric_canonical_unit(leaf.kind)}'
}

fn calc_dimension_unit(node CalcNode) ?string {
	if node is CalcNumeric && node.kind != .number && node.kind != .percentage {
		return node.unit
	}
	return none
}

// https://drafts.csswg.org/css-values-4/#sort-a-calculations-children
// Keep serialization deterministic and aligned with C++: one number first, then one
// percentage, dimensions ordered by unit, followed by operator/function nodes in their
// original order. Sum/product simplification guarantees at most one numeric child per unit.
fn sort_a_calculations_children(children []CalcNode) []CalcNode {
	mut number_index := -1
	mut percentage_index := -1
	for index, child in children {
		if child is CalcNumeric {
			if child.kind == .number && number_index < 0 {
				number_index = index
			} else if child.kind == .percentage && percentage_index < 0 {
				percentage_index = index
			}
		}
	}

	mut dimensions := []CalcNode{}
	mut remaining := []CalcNode{}
	for index, child in children {
		if index == number_index || index == percentage_index {
			continue
		}
		if unit := calc_dimension_unit(child) {
			mut insertion_index := dimensions.len
			for dimension_index, dimension in dimensions {
				existing_unit := calc_dimension_unit(dimension) or { continue }
				if unit < existing_unit {
					insertion_index = dimension_index
					break
				}
			}
			dimensions.insert(insertion_index, child)
		} else {
			remaining << child
		}
	}

	mut sorted := []CalcNode{cap: children.len}
	if number_index >= 0 {
		sorted << children[number_index]
	}
	if percentage_index >= 0 {
		sorted << children[percentage_index]
	}
	sorted << dimensions
	sorted << remaining
	return sorted
}

fn serialize_calc_sum(children []CalcNode) string {
	sorted_children := sort_a_calculations_children(children)
	mut serialized := serialize_a_calculation_tree(sorted_children[0], true)
	for index := 1; index < sorted_children.len; index++ {
		child := sorted_children[index]
		if child is CalcNegate {
			serialized += ' - ' + serialize_a_calculation_tree(child.children[0], true)
		} else if child is CalcNumeric && child.value < 0 {
			// A negative numeric leaf serializes as `- x`, not `+ -x`.
			negated := CalcNumeric{
				kind: child.kind
				value: -child.value
				unit: child.unit
				type_: child.type_
			}
			serialized += ' - ' + serialize_a_calculation_tree(CalcNode(negated), true)
		} else {
			serialized += ' + ' + serialize_a_calculation_tree(child, true)
		}
	}
	return serialized
}

fn serialize_calc_product(children []CalcNode) string {
	sorted_children := sort_a_calculations_children(children)
	mut serialized := serialize_a_calculation_tree(sorted_children[0], true)
	for index := 1; index < sorted_children.len; index++ {
		child := sorted_children[index]
		if child is CalcInvert {
			serialized += ' / ' + serialize_a_calculation_tree(child.children[0], true)
		} else {
			serialized += ' * ' + serialize_a_calculation_tree(child, true)
		}
	}
	return serialized
}

fn (node CalcFunction) serialize_function() string {
	mut parts := []string{}
	if node.name == 'round' {
		parts << node.strategy
	}
	for child in node.children {
		parts << serialize_a_calculation_tree(child, false)
	}
	return node.name + '(' + parts.join(', ') + ')'
}

fn (node CalcRandom) serialize_function() string {
	mut parts := []string{}
	sharing := node.sharing.serialize(.normal)
	if sharing.len > 0 {
		parts << sharing
	}
	for child in node.children {
		parts << serialize_a_calculation_tree(child, false)
	}
	return 'random(' + parts.join(', ') + ')'
}
