module css

import math

// Shared representation for the upstream calculation-node subclasses. The
// subclass tag controls the operation while operands, unit and percentage
// metadata retain the calculation tree's observable state.
pub struct CalculationNodeFacade {
pub mut:
	kind            string = 'number'
	numeric_value_  f64
	unit            string
	operands        []f64
	has_percentage  bool
}

pub fn CalculationNodeFacade.create(value f64) CalculationNodeFacade {
	return CalculationNodeFacade{numeric_value_: value}
}

pub fn CalculationNodeFacade.from_value(value f64) CalculationNodeFacade {
	return CalculationNodeFacade.create(value)
}

pub fn CalculationNodeFacade.from_keyword(keyword string) CalculationNodeFacade {
	return CalculationNodeFacade{kind: keyword}
}

pub fn CalculationNodeFacade.from_style_value(value string) CalculationNodeFacade {
	return CalculationNodeFacade{kind: 'style-value', unit: value}
}

pub fn (node CalculationNodeFacade) value() f64 { return node.numeric_value_ }
pub fn (node CalculationNodeFacade) children() []f64 { return node.operands.clone() }
pub fn (node CalculationNodeFacade) child() f64 { return if node.operands.len > 0 { node.operands[0] } else { node.numeric_value_ } }
pub fn (node CalculationNodeFacade) contains_percentage() bool { return node.has_percentage }
pub fn (node CalculationNodeFacade) infinite_or_nan_value() bool { return math.is_inf(node.numeric_value_, 0) || math.is_nan(node.numeric_value_) }
pub fn (node CalculationNodeFacade) is_in_canonical_unit() bool { return node.unit in ['', 'px', 'deg', 's', 'hz', 'dppx'] }
pub fn (node CalculationNodeFacade) is_negative() bool { return node.numeric_value_ < 0 }
pub fn (node CalculationNodeFacade) is_operator_node() bool { return node.kind in ['sum', 'product', 'negate', 'invert'] }
pub fn (node CalculationNodeFacade) is_math_function_node() bool { return node.kind !in ['number', 'sum', 'product', 'negate', 'invert'] }
pub fn (node CalculationNodeFacade) is_calc_operator_node() bool { return node.is_operator_node() }
pub fn (node CalculationNodeFacade) numeric_type() string { return node.unit }
pub fn (node CalculationNodeFacade) type_() string { return node.kind }
pub fn (node CalculationNodeFacade) name() string { return node.kind }
pub fn (node CalculationNodeFacade) function() string { return node.kind }
pub fn (node CalculationNodeFacade) rounding_strategy() string { return node.kind }
pub fn (node CalculationNodeFacade) serialize_value() string { return node.value_to_string() }
pub fn (node CalculationNodeFacade) serialize() string { return node.to_string() }
pub fn (node CalculationNodeFacade) value_to_string() string { return node.numeric_value_.str() + node.unit }
pub fn (node CalculationNodeFacade) to_string() string {
	if node.operands.len == 0 { return node.value_to_string() }
	return node.kind + '(' + node.operands.map(it.str()).join(', ') + ')'
}
pub fn (node CalculationNodeFacade) dump() string { return node.to_string() }
pub fn (node CalculationNodeFacade) equals(other CalculationNodeFacade) bool {
	return node.kind == other.kind && node.numeric_value_ == other.numeric_value_ && node.unit == other.unit && node.operands == other.operands && node.has_percentage == other.has_percentage
}
pub fn (node CalculationNodeFacade) with_simplified_children() CalculationNodeFacade {
	mut result := node
	if result.operands.len == 1 { result.numeric_value_ = result.operands[0] }
	return result
}
pub fn (node CalculationNodeFacade) run_operation_if_possible() CalculationNodeFacade {
	mut result := node
	if node.operands.len == 0 { return result }
	match node.kind {
		'sum' { mut value := 0.0; for operand in node.operands { value += operand }; result.numeric_value_ = value }
		'product' { mut value := 1.0; for operand in node.operands { value *= operand }; result.numeric_value_ = value }
		'min' { mut v := node.operands[0]; for operand in node.operands { if operand < v { v = operand } }; result.numeric_value_ = v }
		'max' { mut v := node.operands[0]; for operand in node.operands { if operand > v { v = operand } }; result.numeric_value_ = v }
		'abs' { result.numeric_value_ = math.abs(node.operands[0]) }
		'sqrt' { result.numeric_value_ = math.sqrt(node.operands[0]) }
		'sin' { result.numeric_value_ = math.sin(node.operands[0]) }
		'cos' { result.numeric_value_ = math.cos(node.operands[0]) }
		'tan' { result.numeric_value_ = math.tan(node.operands[0]) }
		else { result.numeric_value_ = node.operands[0] }
	}
	return result
}
pub fn (node CalculationNodeFacade) reify() CalculationNodeFacade { return node.run_operation_if_possible() }
pub fn (node CalculationNodeFacade) negated() CalculationNodeFacade { return node.negate() }
pub fn (node CalculationNodeFacade) negate() CalculationNodeFacade { mut result := node; result.numeric_value_ = -result.numeric_value_; return result }
pub fn (node CalculationNodeFacade) invert() CalculationNodeFacade { mut result := node; result.numeric_value_ = 1.0 / result.numeric_value_; return result }
pub fn (node CalculationNodeFacade) add(other CalculationNodeFacade) CalculationNodeFacade { mut result := node; result.numeric_value_ += other.numeric_value_; return result }
pub fn (node CalculationNodeFacade) subtract(other CalculationNodeFacade) CalculationNodeFacade { mut result := node; result.numeric_value_ -= other.numeric_value_; return result }
pub fn (node CalculationNodeFacade) multiply_by(value f64) CalculationNodeFacade { mut result := node; result.numeric_value_ *= value; return result }
pub fn (node CalculationNodeFacade) divide_by(value f64) CalculationNodeFacade { mut result := node; result.numeric_value_ /= value; return result }
pub fn (node CalculationNodeFacade) calculation() CalculationNodeFacade { return node }
pub fn (node CalculationNodeFacade) resolves_to_angle_percentage() bool { return node.unit in ['deg', '%'] }
pub fn (node CalculationNodeFacade) resolves_to_dimension() bool { return node.unit != '' }
pub fn (node CalculationNodeFacade) resolves_to_flex() bool { return node.unit == 'fr' }
pub fn (node CalculationNodeFacade) resolves_to_frequency() bool { return node.unit in ['hz', 'khz'] }
pub fn (node CalculationNodeFacade) resolves_to_frequency_percentage() bool { return node.resolves_to_frequency() || node.has_percentage }
pub fn (node CalculationNodeFacade) resolves_to_resolution() bool { return node.unit in ['dpi', 'dpcm', 'dppx'] }
pub fn (node CalculationNodeFacade) resolves_to_time() bool { return node.unit in ['s', 'ms'] }
pub fn (node CalculationNodeFacade) resolves_to_time_percentage() bool { return node.resolves_to_time() || node.has_percentage }
