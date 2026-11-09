module css

fn test_calc_simplifies_a_single_anchor_size_function_without_a_wrapper() {
	value := parse_css_value_logic(.width,'calc(anchor-size(--foo width, 0))') or { panic('parse') }
	assert value.serialize(.normal) == 'anchor-size(--foo width, 0px)'
	mixed := parse_css_value_logic(.width,'calc(anchor-size(width) + 5px)') or { panic('parse') }
	assert mixed.serialize(.normal) == 'calc(5px + anchor-size(width))',mixed.serialize(.normal)
}
