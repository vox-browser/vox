module css

// Parser for CSS math functions: calc(), min(), max(), clamp().
//
// The port stores a CalculatedStyleValue as a serialization string plus a NumericType
// (see css.v). Rather than carry a resolvable CalculationNode tree, this builds a
// lightweight parse tree only long enough to (a) validate type consistency and compute
// the NumericType (used for property acceptance, e.g. does this calc resolve to a
// <length>?) and (b) emit a canonical, re-parseable serialization.
//
// Deliberate boundaries (matching the port's existing CalculatedStyleValue design):
//   - No simplification. `calc(1px + 2px)` serializes as `calc(1px + 2px)`, not `calc(3px)`.
//     It still round-trips (parse -> serialize -> parse is stable).
//   - Only calc/min/max/clamp. The stepped/trig/exponential functions (round, mod, rem,
//     sin, cos, tan, pow, sqrt, hypot, abs, sign, log, exp, ...) and numeric constants
//     (pi, e, infinity, nan) are not parsed yet and fall through as unsupported.

// A parsed math-function expression. Recursion runs through the child arrays.
type CalcNode = CalcNumeric | CalcSum | CalcProduct | CalcNegate | CalcInvert | CalcMinMax | CalcClamp

// A leaf: a number, dimension, or percentage literal.
struct CalcNumeric {
	text  string      // canonical serialization, e.g. "1px", "100%", "2", "45deg"
	type_ NumericType // the leaf's numeric type
}

// a + b + c. Subtraction is represented by a CalcNegate child.
struct CalcSum {
	children []CalcNode
}

// a * b * c. Division is represented by a CalcInvert child.
struct CalcProduct {
	children []CalcNode
}

// -x. Holds exactly one child (in `children[0]`), only ever a CalcSum child.
struct CalcNegate {
	children []CalcNode
}

// 1/x. Holds exactly one child (in `children[0]`), only ever a CalcProduct child.
struct CalcInvert {
	children []CalcNode
}

// min(...) or max(...).
struct CalcMinMax {
	is_max   bool
	children []CalcNode
}

// clamp(min, center, max). Holds exactly three children.
struct CalcClamp {
	children []CalcNode
}

fn calc_function_is_supported(name string) bool {
	return name in ['calc', 'min', 'max', 'clamp']
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
	node := parse_calc_function_node(component_value.function()) or { return none }
	numeric_type := node.numeric_type() or { return none }
	tokens = transaction
	return StyleValue(CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: numeric_type
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
	match name {
		'calc' {
			mut inner := ComponentValueStream.new(function.value)
			return parse_a_calculation(mut inner)
		}
		'min', 'max' {
			arguments := parse_calc_arguments(function.value) or { return none }
			if arguments.len == 0 {
				return none
			}
			return CalcNode(CalcMinMax{
				is_max:   name == 'max'
				children: arguments
			})
		}
		'clamp' {
			arguments := parse_calc_arguments(function.value) or { return none }
			if arguments.len != 3 {
				return none
			}
			return CalcNode(CalcClamp{
				children: arguments
			})
		}
		else {
			return none
		}
	}
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
	operator    u8 // '+' '-' '*' '/' when is_operator
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
	if component_value.is(.number) {
		number := component_value.token().number()
		return CalcNode(CalcNumeric{
			text:  serialize_a_number(number.value())
			type_: NumericType.new()
		})
	}
	if component_value.is(.percentage) {
		return CalcNode(CalcNumeric{
			text:  serialize_a_number(component_value.token().percentage()) + '%'
			type_: NumericType.with_type(.percent, 1)
		})
	}
	if component_value.is(.dimension) {
		unit := to_ascii_lowercase(component_value.token().dimension_unit())
		numeric_type := NumericType.create_from_unit(unit) or { return none }
		return CalcNode(CalcNumeric{
			text:  serialize_a_number(component_value.token().dimension_value()) + unit
			type_: numeric_type
		})
	}
	return none
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
		CalcMinMax {
			mut result := node.children[0].numeric_type() or { return none }
			for index := 1; index < node.children.len; index++ {
				child_type := node.children[index].numeric_type() or { return none }
				result = result.consistent_type(child_type) or { return none }
			}
			return result
		}
		CalcClamp {
			mut result := node.children[0].numeric_type() or { return none }
			for index := 1; index < node.children.len; index++ {
				child_type := node.children[index].numeric_type() or { return none }
				result = result.consistent_type(child_type) or { return none }
			}
			return result
		}
	}
	return none
}

// --- Serialization ---

// The complete serialization, including the outer `calc(...)`/`min(...)`/... wrapper.
fn (node CalcNode) serialize_top() string {
	match node {
		CalcMinMax {
			return node.serialize_function()
		}
		CalcClamp {
			return node.serialize_function()
		}
		else {
			return 'calc(' + node.serialize_inner(true) + ')'
		}
	}
	return ''
}

// The inner text of a node. `is_root` is true for the outermost expression of a calc()
// and for math-function arguments, where a top-level sum needs no parentheses. A nested
// sum (a parenthesised group used as a factor/operand) is parenthesised; products never
// need parentheses since `*`/`/` bind tighter than `+`/`-`.
fn (node CalcNode) serialize_inner(is_root bool) string {
	match node {
		CalcNumeric {
			return node.text
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
		CalcMinMax {
			return node.serialize_function()
		}
		CalcClamp {
			return node.serialize_function()
		}
	}
	return ''
}

fn serialize_calc_sum(children []CalcNode) string {
	mut serialized := children[0].serialize_inner(false)
	for index := 1; index < children.len; index++ {
		child := children[index]
		if child is CalcNegate {
			serialized += ' - ' + child.children[0].serialize_inner(false)
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

fn (node CalcMinMax) serialize_function() string {
	name := if node.is_max { 'max' } else { 'min' }
	mut parts := []string{}
	for child in node.children {
		parts << child.serialize_inner(true)
	}
	return name + '(' + parts.join(', ') + ')'
}

fn (node CalcClamp) serialize_function() string {
	mut parts := []string{}
	for child in node.children {
		parts << child.serialize_inner(true)
	}
	return 'clamp(' + parts.join(', ') + ')'
}
