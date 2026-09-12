module css

fn parsed_view_function(text string) FunctionStyleValue {
	parsed := parse_css_value_logic(.animation_timeline, text) or {
		panic('${text} did not parse')
	}
	list := parsed as StyleValueList
	return list.value_at(0, false) as FunctionStyleValue
}

fn test_view_function_uses_a_sparse_generic_tuple() {
	defaults := parsed_view_function('view(block auto)')
	assert defaults.name() == 'view'
	assert defaults.serialize(.normal) == 'view()'
	default_arguments := defaults.value() as TupleStyleValue
	assert default_arguments.tuple().len == 2
	assert default_arguments.tuple()[tuple_view_function_axis_index] == none
	assert default_arguments.tuple()[tuple_view_function_inset_index] == none

	canonical := parsed_view_function('view(10px 20% x)')
	assert canonical.serialize(.normal) == 'view(x 10px 20%)'
	arguments := (canonical.value() as TupleStyleValue).tuple()
	axis := arguments[tuple_view_function_axis_index] or { panic('missing axis') }
	inset := arguments[tuple_view_function_inset_index] or { panic('missing inset') }
	assert axis.to_keyword() == .x
	assert inset.serialize(.normal) == '10px 20%'
}

fn test_view_function_rejects_duplicate_components() {
	assert parse_css_value_logic(.animation_timeline, 'view(x y)') == none
	assert parse_css_value_logic(.animation_timeline, 'view(auto 1px 2px)') == none
}
