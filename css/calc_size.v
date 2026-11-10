module css

// The calc-size() function.
// https://drafts.csswg.org/css-values-5/#calc-size
//
// Translated from Ladybird's Rust css/calc_size.rs. A calc-size() is retained
// as a FunctionStyleValue named calc-size holding a comma list of its basis and
// calculation, as upstream does.

const calc_size_function_name = 'calc-size'

// Properties whose grammar includes calc-size().
fn property_accepts_calc_size(property_id PropertyID) bool {
	return property_id in [.width, .height, .min_width, .min_height, .max_width, .max_height,
		.block_size, .inline_size, .min_block_size, .min_inline_size, .max_block_size,
		.max_inline_size, .flex_basis]
}

// <size-keyword> represents any sizing keywords allowed in the context where the
// function is used.
fn calc_size_basis_keyword_is_allowed(property_id PropertyID, keyword Keyword) bool {
	return match keyword {
		.any, .min_content, .max_content, .fit_content, .stretch { true }
		.auto { !property_is_max_size_for_value_logic(property_id) }
		.content { property_id == .flex_basis }
		else { false }
	}
}

// Parses a calc-size() function as the value of the sizing property `property_id`.
fn (mut parser Parser) parse_calc_size_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	if !property_accepts_calc_size(property_id) {
		return none
	}
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named(calc_size_function_name) {
		return none
	}
	value := parser.parse_calc_size_function(property_id, component_value.function()) or {
		return none
	}
	tokens = transaction
	return value
}

// <calc-size()> = calc-size( <calc-size-basis>, <calc-sum> )
fn (mut parser Parser) parse_calc_size_function(property_id PropertyID, function Function) ?StyleValue {
	arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(function.value)
	if arguments.len != 2 {
		return none
	}
	basis_values := trim_calc_size_argument(arguments[0])
	calculation_values := trim_calc_size_argument(arguments[1])
	if basis_values.len == 0 || calculation_values.len == 0 {
		return none
	}
	basis := parser.parse_calc_size_basis(property_id, basis_values) or { return none }
	// If the basis is any, it is a syntax error for size to appear in the
	// calc-size calculation.
	basis_is_any := basis is KeywordStyleValue && basis.keyword() == .any
	calculation := parser.parse_calc_size_sum(calculation_values, !basis_is_any) or { return none }
	return calc_size_function_value(basis, calculation)
}

// The calc-size() function value with the given basis and calculation. A third,
// derived list item retains the calculation the function acts as for a
// <calc-sum> or any basis, so layout does not rebuild it on every size query.
// Serialization and the arguments ignore it; absolutization keeps it in step.
fn calc_size_function_value(basis StyleValue, calculation StyleValue) StyleValue {
	mut values := [basis, calculation]
	arguments := StyleValue(FunctionStyleValue.create(calc_size_function_name, StyleValue(StyleValueList.create(values.clone(),
		.comma, .no))))
	if calc_size_basis_keyword(arguments) == none {
		if equivalent := calc_size_equivalent_calculation(arguments) {
			values << StyleValue(equivalent)
			return StyleValue(FunctionStyleValue.create(calc_size_function_name, StyleValue(StyleValueList.create(values,
				.comma, .no))))
		}
	}
	return arguments
}

// The retained calculation a calc-size() with a <calc-sum> or any basis acts as.
fn calc_size_retained_equivalent(value StyleValue) ?CalculatedStyleValue {
	if value is FunctionStyleValue && value.name_ == calc_size_function_name {
		list := value.value()
		if list is StyleValueList && list.values().len == 3 {
			equivalent := list.values()[2]
			if equivalent is CalculatedStyleValue {
				return equivalent
			}
		}
	}
	return calc_size_equivalent_calculation(value)
}

fn trim_calc_size_argument(values []ComponentValue) []ComponentValue {
	mut start := 0
	mut end := values.len
	for start < end && values[start].is(.whitespace) {
		start++
	}
	for end > start && values[end - 1].is(.whitespace) {
		end--
	}
	return values[start..end]
}

// <calc-size-basis> = [ <size-keyword> | <calc-sum> | <calc-size()> | any ]
fn (mut parser Parser) parse_calc_size_basis(property_id PropertyID, values []ComponentValue) ?StyleValue {
	if values.len == 1 {
		value := values[0]
		if value.is(.ident) {
			keyword := keyword_from_string(value.token().ident()) or { return none }
			if !calc_size_basis_keyword_is_allowed(property_id, keyword) {
				return none
			}
			return StyleValue(KeywordStyleValue.create(keyword))
		}
		if value.is_function_named(calc_size_function_name) {
			return parser.parse_calc_size_function(property_id, value.function())
		}
	}
	return parser.parse_calc_size_sum(values, false)
}

// A <calc-sum> given without a calc() around it, which must match
// <length-percentage>.
fn (mut parser Parser) parse_calc_size_sum(values []ComponentValue, allow_size_keyword bool) ?StyleValue {
	previous := parser.allow_calc_size_keyword
	parser.allow_calc_size_keyword = allow_size_keyword
	defer {
		parser.allow_calc_size_keyword = previous
	}
	mut context := parser.calculation_context()
	context.percentages_resolve_as = .length
	mut tokens := ComponentValueStream.new(values)
	parsed_without_context := parser.parse_a_calculation(mut tokens, parser.context_allows_tree_counting_functions()) or {
		return none
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	parsed := apply_calculation_context_to_calc_node(parsed_without_context, context)
	numeric_type := parsed.numeric_type() or { return none }
	if !calc_type_matches(numeric_type, .length_percentage, context.percentages_resolve_as) {
		return none
	}
	node := simplify_calc(parsed, context)
	return StyleValue(CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: calculated_numeric_type_storage(numeric_type)
		node: [node]
		calculation_context: context
	})
}

// The basis and calculation of a calc-size() function value.
fn calc_size_arguments(value StyleValue) ?(StyleValue, StyleValue) {
	if value !is FunctionStyleValue {
		return none
	}
	function := value as FunctionStyleValue
	if function.name() != calc_size_function_name {
		return none
	}
	list := function.value()
	if list !is StyleValueList {
		return none
	}
	values := (list as StyleValueList).values()
	if values.len != 2 && values.len != 3 {
		return none
	}
	return values[0], values[1]
}

pub fn style_value_is_calc_size(value StyleValue) bool {
	_, _ := calc_size_arguments(value) or { return false }
	return true
}

// The sizing keyword a calc-size() acts as, after following nested calc-size()
// bases: auto, min-content, max-content, fit-content, stretch or content, or
// none when its basis is any or a calculation.
fn calc_size_basis_keyword(value StyleValue) ?Keyword {
	basis, _ := calc_size_arguments(value) or { return none }
	if basis is KeywordStyleValue {
		keyword := basis.keyword()
		return if keyword == .any { none } else { keyword }
	}
	if basis is FunctionStyleValue {
		return calc_size_basis_keyword(basis)
	}
	return none
}

// Serializes both arguments as calculations given without a calc() around them.
fn serialize_calc_size_function(function FunctionStyleValue, mode SerializationMode) string {
	basis, calculation := calc_size_arguments(StyleValue(function)) or {
		return '${function.name_}(${function.value_[0].serialize(mode)})'
	}
	return 'calc-size(${serialize_calc_size_argument(basis, mode)}, ${serialize_calc_size_argument(calculation,
		mode)})'
}

fn serialize_calc_size_argument(value StyleValue, mode SerializationMode) string {
	if value is CalculatedStyleValue && value.node.len > 0 {
		return serialize_a_calculation_tree(value.node[0], false)
	}
	return value.serialize(mode)
}

// The calculation that a calc-size() with a <calc-sum> or any basis acts as for
// every purpose other than resolving the size: its calculation with the size
// keyword standing for the basis (or zero for any).
// https://drafts.csswg.org/css-values-5/#valdef-calc-size-calc-sum
fn calc_size_equivalent_calculation(value StyleValue) ?CalculatedStyleValue {
	basis, calculation := calc_size_arguments(value) or { return none }
	basis_node := calc_size_basis_node(basis) or { return none }
	if calculation !is CalculatedStyleValue {
		return none
	}
	calculated := calculation as CalculatedStyleValue
	if calculated.node.len == 0 {
		return none
	}
	context := calculated.calculation_context
	substituted := calc_node_substitute_size_keyword(calculated.node[0], basis_node) or { return none }
	numeric_type := substituted.numeric_type() or { return none }
	node := simplify_calc(substituted, context)
	return CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: calculated_numeric_type_storage(numeric_type)
		node: [node]
		calculation_context: context
	}
}

fn calc_size_basis_node(basis StyleValue) ?CalcNode {
	if basis is KeywordStyleValue {
		if basis.keyword() == .any {
			return CalcNode(CalcNumeric{
				kind: .length
				value: 0
				unit: 'px'
				type_: NumericType.with_type(.length, 1)
			})
		}
		return none
	}
	if basis is FunctionStyleValue {
		equivalent := calc_size_equivalent_calculation(StyleValue(basis)) or { return none }
		return equivalent.node[0]
	}
	// Any other <calc-sum> basis, including the plain lengths and percentages
	// that interpolation produces.
	return length_percentage_calc_node(basis)
}

// Nested calc-size() functions that each refer to the size more than once grow
// the substituted calculation exponentially, so a calculation too large to walk
// is refused, as upstream does.
// https://github.com/w3c/csswg-drafts/issues/10369
const calc_size_maximum_expanded_node_count = u64(1) << 16

// The node count of `node` once each size keyword in it is replaced by a tree
// of `replacement_count` nodes, saturating above the maximum.
fn calc_node_expanded_count(node CalcNode, replacement_count u64) u64 {
	mut count := u64(1)
	children := match node {
		CalcSizeKeyword { return replacement_count }
		CalcSum, CalcProduct, CalcNegate, CalcInvert, CalcFunction { node.children }
		else { []CalcNode{} }
	}
	for child in children {
		count += calc_node_expanded_count(child, replacement_count)
		if count > calc_size_maximum_expanded_node_count {
			return calc_size_maximum_expanded_node_count + 1
		}
	}
	return count
}

// Substitutes `replacement` for each size keyword, or returns none when the
// result would exceed the maximum expanded node count.
fn calc_node_substitute_size_keyword(node CalcNode, replacement CalcNode) ?CalcNode {
	if calc_node_expanded_count(node, calc_node_expanded_count(replacement, 1)) > calc_size_maximum_expanded_node_count {
		return none
	}
	return calc_node_replace_size_keyword(node, replacement)
}

fn calc_node_replace_size_keyword(node CalcNode, replacement CalcNode) CalcNode {
	return match node {
		CalcSizeKeyword {
			replacement
		}
		CalcSum {
			CalcNode(CalcSum{
				children: node.children.map(calc_node_replace_size_keyword(it, replacement))
			})
		}
		CalcProduct {
			CalcNode(CalcProduct{
				children: node.children.map(calc_node_replace_size_keyword(it, replacement))
			})
		}
		CalcNegate {
			CalcNode(CalcNegate{
				children: node.children.map(calc_node_replace_size_keyword(it, replacement))
			})
		}
		CalcInvert {
			CalcNode(CalcInvert{
				children: node.children.map(calc_node_replace_size_keyword(it, replacement))
			})
		}
		CalcFunction {
			CalcNode(CalcFunction{
				name: node.name
				strategy: node.strategy
				children: node.children.map(calc_node_replace_size_keyword(it, replacement))
			})
		}
		else {
			node
		}
	}
}

// Whether a calc-size() has a <calc-sum> basis, after following nested
// calc-size() bases.
fn calc_size_has_calc_sum_basis(value StyleValue) bool {
	basis, _ := calc_size_arguments(value) or { return false }
	if basis is KeywordStyleValue {
		return false
	}
	if basis is FunctionStyleValue {
		return calc_size_has_calc_sum_basis(StyleValue(basis))
	}
	return true
}

// Whether this size is a calc-size() whose calculation layout applies to the
// size its basis keyword (or the automatic size, for any) resolves to. A
// calc-size() with a <calc-sum> basis acts as that calculation instead.
pub fn (s Size) has_resolvable_calc_size() bool {
	calc_size := s.calc_size_ or { return false }
	return !calc_size_has_calc_sum_basis(StyleValue(calc_size))
}

// The Size a calc-size() value acts as: its basis keyword, or the equivalent
// calculation for any other basis. The function is retained for resolving the
// used size.
fn size_from_calc_size(value FunctionStyleValue) Size {
	keyword := calc_size_basis_keyword(StyleValue(value)) or {
		equivalent := calc_size_retained_equivalent(StyleValue(value)) or { return Size.make_auto() }
		mut size := Size.make_calculated(equivalent)
		size.calc_size_ = value
		return size
	}
	mut size := match keyword {
		.min_content { Size.make_min_content() }
		.max_content { Size.make_max_content() }
		.fit_content { Size.make_fit_content_without_available_space() }
		.stretch { Size.make_stretch() }
		else { Size.make_auto() }
	}
	size.calc_size_ = value
	return size
}

// The calc-size() function this size was given as, if any. It acts as its basis
// for all purposes other than resolving the size.
pub fn (s Size) calc_size() ?FunctionStyleValue {
	return s.calc_size_
}

// An auto size that is not the basis of a calc-size().
pub fn (s Size) is_plain_auto() bool {
	return s.is_auto() && s.calc_size_ == none
}

// Resolves a calc-size() to pixels at used-value time.
// `keyword_size` is the used size of its sizing-keyword basis. Percentages
// resolve against `percentage_basis`, or against zero when that is indefinite.
// https://drafts.csswg.org/css-values-5/#resolving-calc-size
pub fn resolve_calc_size(value FunctionStyleValue, percentage_basis ?f64, keyword_size f64, context LengthResolutionContext) ?f64 {
	basis, calculation := calc_size_arguments(StyleValue(value)) or { return none }
	size := if basis is KeywordStyleValue {
		if basis.keyword() == .any { 0.0 } else { keyword_size }
	} else if basis is FunctionStyleValue {
		resolve_calc_size(basis, percentage_basis, keyword_size, context) or { return none }
	} else {
		resolve_calc_size_length_percentage(basis, percentage_basis, none, context) or { return none }
	}
	return resolve_calc_size_length_percentage(calculation, percentage_basis, size, context)
}

fn resolve_calc_size_length_percentage(value StyleValue, percentage_basis ?f64, size ?f64, context LengthResolutionContext) ?f64 {
	if value is CalculatedStyleValue {
		length := value.resolve_length(CalculationResolutionContext{
			percentage_basis: Length.make_px(percentage_basis or { 0.0 })
			length_resolution_context: context
			calc_size_px: size
		}) or { return none }
		return length.to_px_without_rounding(context)
	}
	if value is LengthStyleValue {
		return value.length().to_px_without_rounding(context)
	}
	if value is PercentageStyleValue {
		return (percentage_basis or { 0.0 }) * value.raw_value() / 100.0
	}
	return none
}
