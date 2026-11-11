module css

fn test_angle_calculations_reject_percentages_they_cannot_resolve() {
	// rotate() takes an <angle>; transform resolves percentages against
	// lengths, which an angle cannot use.
	assert parse_css_value_logic(.transform, 'rotate(atan2(90px, 100%))') == none
	assert parse_css_value_logic(.transform, 'rotate(atan2(2, 1%))') == none
	assert parse_css_value_logic(.transform, 'skewX(calc(10% * 1deg / 1%))') == none
	valid := parse_css_value_logic(.transform, 'rotate(atan2(90px, 100px))') or {
		panic('atan2() of two lengths is an angle')
	}
	assert valid.serialize(.normal).starts_with('rotate(')
	translated := parse_css_value_logic(.transform, 'translate(calc(100% - 10px))') or {
		panic('lengths still resolve percentages')
	}
	assert translated.serialize(.normal) == 'translate(calc(100% - 10px))'
}
