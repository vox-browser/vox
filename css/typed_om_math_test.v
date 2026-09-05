module css

fn test_typed_om_math_builds_a_typed_calculation_tree_without_reparsing() {
	one_px := CSSUnitValue.create(1, 'px')
	two_px := CSSUnitValue.create(2, 'px')
	sum := CSSMathSum.construct_impl([
		CSSNumberish(one_px),
		CSSNumberish(two_px),
	]) or { panic('${err}') }
	node := sum.create_calculation_node(CalculationContext{}) or { panic('${err}') }
	assert node.node.len == 1
	assert node.node[0] is CalcSum
	assert (node.node[0] as CalcSum).children.len == 2
	assert node.serialization == 'calc(1px + 2px)'

	calculated := CalculatedStyleValue.create(node, sum.type_, CalculationContext{})
	assert calculated.node.len == 1
	resolved := calculated.resolve_length(CalculationResolutionContext{}) or {
		panic('typed sum did not resolve')
	}
	assert resolved.to_px(LengthResolutionContext.default()).to_double() == 3.0
}

fn test_typed_om_min_max_and_clamp_keep_typed_children() {
	min_value := CSSMathMin.construct_impl([
		CSSNumberish(CSSUnitValue.create(10, 'px')),
		CSSNumberish(CSSUnitValue.create(20, 'px')),
	]) or { panic('${err}') }
	min_node := min_value.create_calculation_node(CalculationContext{}) or { panic('${err}') }
	assert min_node.node[0] is CalcFunction
	assert (min_node.node[0] as CalcFunction).name == 'min'

	clamp_value := CSSMathClamp.construct_impl(
		CSSNumberish(CSSUnitValue.create(0, 'px')),
		CSSNumberish(CSSUnitValue.create(15, 'px')),
		CSSNumberish(CSSUnitValue.create(10, 'px')),
	) or { panic('${err}') }
	clamp_node := clamp_value.create_calculation_node(CalculationContext{}) or {
		panic('${err}')
	}
	assert clamp_node.node[0] is CalcFunction
	function := clamp_node.node[0] as CalcFunction
	assert function.name == 'clamp'
	assert function.children.len == 3
	assert clamp_node.serialization == 'clamp(0px, 15px, 10px)'
}

fn test_css_numeric_value_parse_reifies_the_translated_calculation_tree() {
	sum_value := CSSNumericValue.parse('calc(1px + 2%)') or { panic('${err}') }
	assert sum_value is CSSMathSum
	sum := sum_value as CSSMathSum
	assert sum.values().length() == 2
	assert sum.type_.matches_length_percentage(.length)

	product_value := CSSNumericValue.parse('calc(2 * 1em)') or { panic('${err}') }
	assert product_value is CSSMathProduct
	product := product_value as CSSMathProduct
	assert product.values().length() == 2

	min_value := CSSNumericValue.parse('min(1em, 1px)') or { panic('${err}') }
	assert min_value is CSSMathMin
	assert (min_value as CSSMathMin).values().length() == 2

	clamp_value := CSSNumericValue.parse('clamp(1em, 2px, 3em)') or { panic('${err}') }
	assert clamp_value is CSSMathClamp
	clamp := clamp_value as CSSMathClamp
	assert clamp.lower() is CSSUnitValue
	assert clamp.value() is CSSUnitValue
	assert clamp.upper() is CSSUnitValue
}

fn test_css_numeric_value_parse_rejects_non_reifiable_math_nodes() {
	CSSNumericValue.parse('abs(1em)') or {
		assert err.msg().contains('Unable to reify this math function')
		return
	}
	assert false
}
