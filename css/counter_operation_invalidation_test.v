module css

fn test_counter_operation_changes_rebuild_generated_content_and_equal_values_do_not() {
	for property in [PropertyID.counter_increment, .counter_reset, .counter_set] {
		left := dom_style_value_from_value_logic(parse_css_value_logic(property, 'item 1') or { panic('invalid fixture') })
		right := dom_style_value_from_value_logic(parse_css_value_logic(property, 'item 2') or { panic('invalid fixture') })
		assert compute_property_invalidation(property, left, right).needs_layout_tree_rebuild()
		assert compute_property_invalidation(property, left, left).is_none()
	}
}
