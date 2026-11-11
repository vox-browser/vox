module css

import dom

// Interpolation and composition of sizing values through calc-size().
// https://drafts.csswg.org/css-values-5/#interpolate-calc-size
//
// Translated from combine_calc_size() and prepared_calc_size() in Ladybird's
// Rust css/animation.rs and the calc-size helpers in css/calc.rs.

// The computed style whose interpolate-size governs the animation being
// sampled: the in-progress style for keyframes, the after-change style for
// transitions. Unset outside those passes, when the element's own computed
// style is used instead.
__global calc_size_interpolation_style voidptr

// Whether the computed interpolate-size lets sizing keywords interpolate with
// lengths.
// https://drafts.csswg.org/css-values-5/#valdef-interpolate-size-allow-keywords
fn allows_keyword_size_interpolation(element &dom.Element) bool {
	style := if calc_size_interpolation_style != unsafe { nil } {
		unsafe { &ComputedProperties(calc_size_interpolation_style) }
	} else {
		if isnil(element) {
			return false
		}
		computed_properties_for_element(element) or { return false }
	}
	value := style.property(.interpolate_size, .yes) or { return false }
	return value.css_text == 'allow-keywords'
}

// Makes `style` supply interpolate-size, returning the previous style to
// restore when the pass ends.
fn enter_calc_size_interpolation_style(style &ComputedProperties) voidptr {
	previous := calc_size_interpolation_style
	calc_size_interpolation_style = voidptr(style)
	return previous
}

fn leave_calc_size_interpolation_style(previous voidptr) {
	calc_size_interpolation_style = previous
}

enum CalcSizeCombinationKind {
	keyword
	calc_size
	length_percentage
}

fn calc_size_combination_kind(value StyleValue) ?CalcSizeCombinationKind {
	if value is KeywordStyleValue {
		if value.keyword() in [.auto, .min_content, .max_content, .fit_content, .stretch, .content] {
			return .keyword
		}
		return none
	}
	if style_value_is_calc_size(value) {
		return .calc_size
	}
	if value is LengthStyleValue || value is PercentageStyleValue || value is CalculatedStyleValue {
		return .length_percentage
	}
	return none
}

// Combines two sizes where one is a sizing keyword or a calc-size() as
// calc-size() values, or returns none where they cannot combine that way.
// `combine` receives the two prepared calculations.
fn combine_calc_size(property_id PropertyID, from StyleValue, to StyleValue, allow_keywords bool, combine fn (CalcNode, CalcNode) CalcNode) ?StyleValue {
	from_kind := calc_size_combination_kind(from) or { return none }
	to_kind := calc_size_combination_kind(to) or { return none }
	// NB: Two keywords never interpolate: the same keyword stays itself, and
	//     different keywords are not compatible.
	if from_kind == to_kind && from_kind != .calc_size {
		return none
	}
	// Sizing values can also be combined if one of them is an <size-keyword>
	// and the other is a <length-percentage>.
	keyword_and_length := (from_kind == .keyword || to_kind == .keyword)
		&& (from_kind == .length_percentage || to_kind == .length_percentage)
	if keyword_and_length && !allow_keywords {
		return none
	}
	from_basis, from_calculation := prepared_calc_size_operand(from, from_kind) or { return none }
	to_basis, to_calculation := prepared_calc_size_operand(to, to_kind) or { return none }
	from_is_any := from_basis is KeywordStyleValue && from_basis.keyword() == .any
	to_is_any := to_basis is KeywordStyleValue && to_basis.keyword() == .any
	basis := if from_basis.equals(to_basis) || to_is_any {
		from_basis
	} else if from_is_any {
		to_basis
	} else {
		return none
	}
	mut context := CalculationContext.for_property(PropertyNameAndID.from_id(property_id))
	context.percentages_resolve_as = .length
	combined := apply_calculation_context_to_calc_node(combine(from_calculation, to_calculation), context)
	numeric_type := combined.numeric_type() or { return none }
	node := simplify_calc(combined, context)
	calculation := StyleValue(CalculatedStyleValue{
		serialization: node.serialize_top()
		numeric_type_: calculated_numeric_type_storage(numeric_type)
		node: [node]
		calculation_context: context
	})
	return calc_size_function_value(basis, calculation)
}

// Treats a non-calc-size() value as calc-size(any, value) if it is a
// <calc-sum>, or as calc-size(value, size) otherwise.
fn prepared_calc_size_operand(value StyleValue, kind CalcSizeCombinationKind) ?(StyleValue, CalcNode) {
	return match kind {
		.keyword { value, CalcNode(CalcSizeKeyword{}) }
		.length_percentage { StyleValue(KeywordStyleValue.create(.any)), length_percentage_calc_node(value)? }
		.calc_size { prepared_calc_size(value)? }
	}
}

// A calc-size() prepared for interpolation, as its basis and its calculation,
// with any basis other than a sizing keyword or any substituted into the
// calculation.
// https://drafts.csswg.org/css-values-5/#calc-size-prepared-for-interpolation
fn prepared_calc_size(value StyleValue) ?(StyleValue, CalcNode) {
	basis, calculation := calc_size_arguments(value) or { return none }
	calculation_node := length_percentage_calc_node(calculation) or { return none }
	if basis is KeywordStyleValue {
		return basis, calculation_node
	}
	// A nested calc-size() stands for its own calculation, against its own basis.
	if basis is FunctionStyleValue {
		inner_basis, inner_calculation := prepared_calc_size(StyleValue(basis)) or { return none }
		return inner_basis, calc_node_substitute_size_keyword(calculation_node, inner_calculation)?
	}
	// A <calc-sum> basis with no percentage present is substituted into the
	// calculation, leaving a basis of any. Any other <calc-sum> basis is
	// replaced with 100%, after being de-percentified and substituted.
	basis_node := length_percentage_calc_node(basis) or { return none }
	if !calc_node_contains_percentage_leaf(basis_node) {
		return StyleValue(KeywordStyleValue.create(.any)), calc_node_substitute_size_keyword(calculation_node,
			basis_node)?
	}
	return StyleValue(PercentageStyleValue.create(Percentage.new(100))), calc_node_substitute_size_keyword(calculation_node,
		de_percentify_calc_size_node(basis_node))?
}

fn length_percentage_calc_node(value StyleValue) ?CalcNode {
	if value is CalculatedStyleValue {
		if value.node.len == 0 {
			return none
		}
		return value.node[0]
	}
	if value is LengthStyleValue {
		length := value.length()
		return CalcNode(CalcNumeric{
			kind: .length
			value: length.raw_value()
			unit: length.unit_name()
			type_: NumericType.with_type(.length, 1)
		})
	}
	if value is PercentageStyleValue {
		return CalcNode(CalcNumeric{
			kind: .percentage
			value: value.raw_value()
			unit: '%'
			type_: NumericType.with_type(.percent, 1)
		})
	}
	return none
}

fn calc_node_contains_percentage_leaf(node CalcNode) bool {
	return match node {
		CalcNumeric { node.kind == .percentage }
		CalcSum, CalcProduct, CalcNegate, CalcInvert, CalcFunction { node.children.any(calc_node_contains_percentage_leaf(it)) }
		else { false }
	}
}

// Replaces each percentage with (size * N), where N is the percentage's value
// divided by 100.
// https://drafts.csswg.org/css-values-5/#de-percentify-a-calc-size-calculation
fn de_percentify_calc_size_node(node CalcNode) CalcNode {
	return match node {
		CalcNumeric {
			if node.kind == .percentage {
				CalcNode(CalcProduct{
					children: [CalcNode(CalcSizeKeyword{}), calc_canonical_leaf(.number, node.value / 100.0)]
				})
			} else {
				CalcNode(node)
			}
		}
		CalcSum {
			CalcNode(CalcSum{
				children: node.children.map(de_percentify_calc_size_node(it))
			})
		}
		CalcProduct {
			CalcNode(CalcProduct{
				children: node.children.map(de_percentify_calc_size_node(it))
			})
		}
		CalcNegate {
			CalcNode(CalcNegate{
				children: node.children.map(de_percentify_calc_size_node(it))
			})
		}
		CalcInvert {
			CalcNode(CalcInvert{
				children: node.children.map(de_percentify_calc_size_node(it))
			})
		}
		CalcFunction {
			CalcNode(CalcFunction{
				name: node.name
				strategy: node.strategy
				children: node.children.map(de_percentify_calc_size_node(it))
			})
		}
		else {
			node
		}
	}
}

// If they can be interpolated, the result's calc-size calculation is the
// interpolation of the two input calc-size calculations, calc((1 - p) * A + p * B).
fn interpolate_calc_size_values(element &dom.Element, property_id PropertyID, from &dom.StyleValue, to &dom.StyleValue, delta f64) ?&dom.StyleValue {
	from_value := style_value_logic_from_dom(property_id, from) or { return none }
	to_value := style_value_logic_from_dom(property_id, to) or { return none }
	result := combine_calc_size(property_id, from_value, to_value, allows_keyword_size_interpolation(element),
		fn [delta] (a CalcNode, b CalcNode) CalcNode {
		return CalcNode(CalcSum{
			children: [
				CalcNode(CalcProduct{
					children: [a, calc_canonical_leaf(.number, 1 - delta)]
				}),
				CalcNode(CalcProduct{
					children: [b, calc_canonical_leaf(.number, delta)]
				}),
			]
		})
	}) or { return none }
	return dom_style_value_from_value_logic(result)
}

// Addition of math functions is defined as Vresult = calc(VA + VB).
fn composite_calc_size_values(property_id PropertyID, underlying StyleValue, animated StyleValue) ?StyleValue {
	return combine_calc_size(property_id, underlying, animated, allows_keyword_size_interpolation(unsafe { nil }),
		fn (a CalcNode, b CalcNode) CalcNode {
		return CalcNode(CalcSum{
			children: [a, b]
		})
	})
}
