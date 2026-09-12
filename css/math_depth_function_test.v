module css

fn test_math_depth_add_uses_a_generic_function_value() {
	parsed := parse_css_value_logic(.math_depth, 'add(-3)') or {
		panic('math-depth add() did not parse')
	}
	assert parsed is FunctionStyleValue
	function := parsed as FunctionStyleValue
	assert function.name() == 'add'
	assert function.value() == StyleValue(IntegerStyleValue.create(-3))
	assert function.serialize(.normal) == 'add(-3)'
}

fn test_math_depth_computation_reads_the_generic_function_argument() {
	computed := StyleComputer.compute_math_depth(dom_style_value_from_value_logic(StyleValue(FunctionStyleValue.create('add', StyleValue(IntegerStyleValue.create(4))))), none)
	assert computed.css_text == '4'
}
