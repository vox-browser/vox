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
type CalcNode = CalcNumeric | CalcSum | CalcProduct | CalcNegate | CalcInvert | CalcFunction

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

fn calc_function_is_supported(name string) bool {
	return name in ['calc', 'min', 'max', 'clamp', 'hypot', 'abs', 'sign', 'sin', 'cos', 'tan',
		'asin', 'acos', 'atan', 'atan2', 'pow', 'sqrt', 'exp', 'log', 'mod', 'rem', 'round']
}

// Entry point: parse a `<calc-function>` component value into a CalculatedStyleValue.
// Returns none (leaving `tokens` untouched) if the next token is not a supported math
// function, or if the expression is type-invalid.
fn parse_calculated_value(mut tokens ComponentValueStream) ?StyleValue {
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
	parsed := parse_calc_function_node(component_value.function()) or { return none }
	// Compute the type before simplification (the simplified tree has the same type, but
	// this also rejects type-invalid expressions).
	numeric_type := parsed.numeric_type() or { return none }
	// Simplify the constant parts at parse time so the specified value matches upstream.
	node := simplify_calc(parsed)
	tokens = transaction
	return StyleValue(CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: numeric_type
		node:          [node]
	})
}

// The kinds of value a calc can be asked to resolve to (used to gate acceptance per
// producer, matching the C++ `calc->resolves_to_X()` checks).
enum CalcMatchKind {
	number
	integer
	length
	percentage
	angle
	time
	frequency
	resolution
	flex
	length_percentage
}

fn calc_type_matches(numeric_type NumericType, kind CalcMatchKind) bool {
	return match kind {
		.number { numeric_type.matches_number(none) }
		.integer { numeric_type.matches_number(none) }
		.length { numeric_type.matches_length(none) }
		.percentage { numeric_type.matches_percentage() }
		.angle { numeric_type.matches_angle(none) }
		.time { numeric_type.matches_time(none) }
		.frequency { numeric_type.matches_frequency(none) }
		.resolution { numeric_type.matches_resolution(none) }
		.flex { numeric_type.matches_flex(none) }
		// For <length-percentage>, percentages resolve against <length>: a mixed calc
		// like `calc(100% - 10px)` has a "length" percent hint, which only matches when
		// percentages_resolve_as is <length>.
		.length_percentage { numeric_type.matches_length_percentage(ValueType.length) }
	}
}

// Try to parse a calc that resolves to the given kind. Consumes from `tokens` only on success.
fn parse_calculated_value_of_kind(mut tokens ComponentValueStream, kind CalcMatchKind) ?StyleValue {
	mut transaction := tokens.clone()
	value := parse_calculated_value(mut transaction) or { return none }
	if value is CalculatedStyleValue {
		numeric_type := value.numeric_type() or { return none }
		if calc_type_matches(numeric_type, kind) {
			tokens = transaction
			return value
		}
	}
	return none
}

fn parse_calc_function_node(function Function) ?CalcNode {
	name := to_ascii_lowercase(function.name)
	if name == 'calc' {
		mut inner := ComponentValueStream.new(function.value)
		return parse_a_calculation(mut inner)
	}
	if name == 'round' {
		return parse_round_function(function.value)
	}
	if !calc_function_is_supported(name) {
		return none
	}
	arguments := parse_calc_arguments(function.value) or { return none }
	return build_calc_function(name, arguments, '')
}

fn calc_rounding_strategy_from_string(ident string) ?string {
	strategy := to_ascii_lowercase(ident)
	if strategy in ['nearest', 'up', 'down', 'to-zero'] {
		return strategy
	}
	return none
}

fn parse_round_function(values []ComponentValue) ?CalcNode {
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
	mut arguments := []CalcNode{}
	for argument in numeric_lists {
		mut stream := ComponentValueStream.new(argument)
		arguments << (parse_a_calculation(mut stream) or { return none })
	}
	return build_calc_function('round', arguments, strategy)
}

fn build_calc_function(name string, arguments []CalcNode, strategy string) ?CalcNode {
	valid_arity := match name {
		'min', 'max', 'hypot' { arguments.len >= 1 }
		'clamp' { arguments.len == 3 }
		'abs', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'exp' { arguments.len == 1 }
		'log' { arguments.len == 1 || arguments.len == 2 }
		'atan2', 'pow', 'mod', 'rem', 'round' { arguments.len == 2 }
		else { false }
	}
	if !valid_arity {
		return none
	}
	node := CalcNode(CalcFunction{
		name:     name
		strategy: strategy
		children: arguments
	})
	// Validate that the argument types satisfy the function and produce a valid result type.
	node.numeric_type() or { return none }
	return node
}

fn parse_calc_arguments(values []ComponentValue) ?[]CalcNode {
	argument_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
	mut result := []CalcNode{}
	for argument in argument_lists {
		mut stream := ComponentValueStream.new(argument)
		node := parse_a_calculation(mut stream) or { return none }
		result << node
	}
	return result
}

// One entry in the flat operand/operator sequence collected from the token stream.
struct CalcTerm {
	is_operator bool
	operator    u8       // '+' '-' '*' '/' when is_operator
	node        CalcNode // the operand when !is_operator
}

// https://drafts.csswg.org/css-values-4/#parse-a-calculation
// Parses the tokens of a calc() body (or a parenthesised group / math-function argument)
// into a single CalcNode, honouring `*`/`/` binding tighter than `+`/`-`.
fn parse_a_calculation(mut tokens ComponentValueStream) ?CalcNode {
	mut terms := []CalcTerm{}
	for {
		tokens.consume_whitespace()
		component_value := tokens.consume() or { break }
		if component_value.is_delim(u32(`+`)) || component_value.is_delim(u32(`-`))
			|| component_value.is_delim(u32(`*`)) || component_value.is_delim(u32(`/`)) {
			terms << CalcTerm{
				is_operator: true
				operator:    u8(component_value.token().delim())
			}
		} else {
			leaf := convert_calc_leaf(component_value) or { return none }
			terms << CalcTerm{
				is_operator: false
				node:        leaf
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

	// Split into operands and the operators between them.
	mut operands := []CalcNode{}
	mut operators := []u8{}
	for term in terms {
		if term.is_operator {
			operators << term.operator
		} else {
			operands << term.node
		}
	}

	// Fold products (`*` and `/`) first, leaving a sum-level operand list.
	mut sum_operands := []CalcNode{}
	mut sum_operators := []u8{}
	mut factors := [operands[0]]
	for index := 0; index < operators.len; index++ {
		operator := operators[index]
		right := operands[index + 1]
		if operator == u8(`*`) {
			factors << right
		} else if operator == u8(`/`) {
			factors << CalcNode(CalcInvert{
				children: [right]
			})
		} else {
			sum_operands << make_calc_product(factors)
			sum_operators << operator
			factors = [right]
		}
	}
	sum_operands << make_calc_product(factors)

	if sum_operands.len == 1 {
		return sum_operands[0]
	}

	// Fold the sum, wrapping subtracted operands in CalcNegate.
	mut sum_children := [sum_operands[0]]
	for index := 0; index < sum_operators.len; index++ {
		right := sum_operands[index + 1]
		if sum_operators[index] == u8(`-`) {
			sum_children << CalcNode(CalcNegate{
				children: [right]
			})
		} else {
			sum_children << right
		}
	}
	return CalcNode(CalcSum{
		children: sum_children
	})
}

fn make_calc_product(factors []CalcNode) CalcNode {
	if factors.len == 1 {
		return factors[0]
	}
	return CalcNode(CalcProduct{
		children: factors
	})
}

fn convert_calc_leaf(component_value ComponentValue) ?CalcNode {
	if component_value.is_block() {
		block := component_value.block()
		if !block.is_paren() {
			return none
		}
		mut inner := ComponentValueStream.new(block.value)
		return parse_a_calculation(mut inner)
	}
	if component_value.is_function() {
		name := to_ascii_lowercase(component_value.function().name)
		if !calc_function_is_supported(name) {
			return none
		}
		return parse_calc_function_node(component_value.function())
	}
	if component_value.is(.ident) {
		return calc_constant_from_ident(component_value.token().ident())
	}
	if component_value.is(.number) {
		number := component_value.token().number()
		return CalcNode(CalcNumeric{
			kind:  .number
			value: number.value()
			unit:  ''
			type_: NumericType.new()
		})
	}
	if component_value.is(.percentage) {
		return CalcNode(CalcNumeric{
			kind:  .percentage
			value: component_value.token().percentage()
			unit:  '%'
			type_: NumericType.with_type(.percent, 1)
		})
	}
	if component_value.is(.dimension) {
		unit := to_ascii_lowercase(component_value.token().dimension_unit())
		numeric_type := NumericType.create_from_unit(unit) or { return none }
		dimension := dimension_for_unit(unit) or { return none }
		return CalcNode(CalcNumeric{
			kind:  calc_numeric_kind_from_dimension(dimension)
			value: component_value.token().dimension_value()
			unit:  unit
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

// https://drafts.csswg.org/css-values-4/#calc-constants - resolved to number leaves at parse time.
fn calc_constant_from_ident(ident string) ?CalcNode {
	value := match to_ascii_lowercase(ident) {
		'e' { math.e }
		'pi' { math.pi }
		'infinity' { math.inf(1) }
		'-infinity' { math.inf(-1) }
		'nan' { math.nan() }
		else { return none }
	}
	return CalcNode(CalcNumeric{
		kind:  .number
		value: value
		unit:  ''
		type_: NumericType.new()
	})
}

// --- Numeric type computation ---

fn (node CalcNode) numeric_type() ?NumericType {
	match node {
		CalcNumeric {
			return node.type_
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

// The complete serialization, including the outer `calc(...)`/`min(...)`/... wrapper.
fn (node CalcNode) serialize_top() string {
	if node is CalcFunction {
		return node.serialize_function()
	}
	return 'calc(' + node.serialize_inner(true) + ')'
}

// The inner text of a node. `is_root` is true for the outermost expression of a calc()
// and for math-function arguments, where a top-level sum needs no parentheses. A nested
// sum (a parenthesised group used as a factor/operand) is parenthesised; products never
// need parentheses since `*`/`/` bind tighter than `+`/`-`.
fn (node CalcNode) serialize_inner(is_root bool) string {
	match node {
		CalcNumeric {
			return node.serialize_leaf()
		}
		CalcSum {
			serialized := serialize_calc_sum(node.children)
			return if is_root { serialized } else { '(' + serialized + ')' }
		}
		CalcProduct {
			return serialize_calc_product(node.children)
		}
		CalcNegate {
			return '-' + node.children[0].serialize_inner(false)
		}
		CalcInvert {
			return '1 / ' + node.children[0].serialize_inner(false)
		}
		CalcFunction {
			return node.serialize_function()
		}
	}
	return ''
}

fn (leaf CalcNumeric) serialize_leaf() string {
	if math.is_nan(leaf.value) {
		return leaf.serialize_non_finite('NaN')
	}
	if math.is_inf(leaf.value, 1) {
		return leaf.serialize_non_finite('infinity')
	}
	if math.is_inf(leaf.value, -1) {
		return leaf.serialize_non_finite('-infinity')
	}
	return serialize_a_number(leaf.value) + leaf.unit
}

// A non-finite dimension serializes as `<keyword> * 1<canonical-unit>` (e.g.
// `infinity * 1px`) so it stays typed and re-parses; a non-finite number is just the
// keyword. Mirrors upstream serialize_a_math_function.
fn (leaf CalcNumeric) serialize_non_finite(keyword string) string {
	if leaf.kind == .number {
		return keyword
	}
	return '${keyword} * 1${leaf.unit}'
}

fn serialize_calc_sum(children []CalcNode) string {
	mut serialized := children[0].serialize_inner(false)
	for index := 1; index < children.len; index++ {
		child := children[index]
		if child is CalcNegate {
			serialized += ' - ' + child.children[0].serialize_inner(false)
		} else if child is CalcNumeric && child.value < 0 {
			// A negative numeric leaf serializes as `- x`, not `+ -x`.
			negated := CalcNumeric{
				kind:  child.kind
				value: -child.value
				unit:  child.unit
				type_: child.type_
			}
			serialized += ' - ' + negated.serialize_leaf()
		} else {
			serialized += ' + ' + child.serialize_inner(false)
		}
	}
	return serialized
}

fn serialize_calc_product(children []CalcNode) string {
	mut serialized := children[0].serialize_inner(false)
	for index := 1; index < children.len; index++ {
		child := children[index]
		if child is CalcInvert {
			serialized += ' / ' + child.children[0].serialize_inner(false)
		} else {
			serialized += ' * ' + child.serialize_inner(false)
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
		parts << child.serialize_inner(true)
	}
	return node.name + '(' + parts.join(', ') + ')'
}
