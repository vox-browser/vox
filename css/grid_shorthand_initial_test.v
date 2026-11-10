module css

// Ladybird 779a304d4c87: initial shorthand values must survive the same
// property parser used when an animation expands a CSS-wide keyword.
fn test_grid_shorthand_initial_values_parse_and_expand() {
	for property in [PropertyID.grid, .grid_template] {
		initial := property_initial_value_string(property)
		value := parse_css_value_logic(property, initial) or {
			panic('unparseable initial value for ${property}: ${initial}')
		}
		assert value.serialize(.normal) == 'none'
		assert parse_css_value_logic(property, value.serialize(.normal)) != none
	}
}
