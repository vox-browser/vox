module css

import dom

fn test_sparse_animation_maps_preserve_each_longhands_addition_replacement_and_removal() {
	old_value := &dom.StyleValue{
		css_text: 'old'
	}
	new_value := &dom.StyleValue{
		css_text: 'new'
	}
	empty := map[PropertyID]&dom.StyleValue{}
	for property_id in computed_interpolation_longhand_property_ids() {
		mut before := map[PropertyID]&dom.StyleValue{}
		mut after := map[PropertyID]&dom.StyleValue{}
		before[property_id] = old_value
		after[property_id] = new_value
		assert animated_property_maps_invalidation(empty, after) == compute_property_invalidation(property_id,
			none, new_value)
		assert animated_property_maps_invalidation(before, after) == compute_property_invalidation(property_id,
			old_value, new_value)
		assert animated_property_maps_invalidation(before, empty) == compute_property_invalidation(property_id,
			old_value, none)
	}
}

fn test_sparse_animation_maps_ignore_shorthands_and_unchanged_values() {
	value := &dom.StyleValue{
		css_text: 'same'
	}
	equal_value := &dom.StyleValue{
		css_text: 'same'
	}
	empty := map[PropertyID]&dom.StyleValue{}
	assert animated_property_maps_invalidation(empty, empty).is_none()
	mut before := map[PropertyID]&dom.StyleValue{}
	mut after := map[PropertyID]&dom.StyleValue{}
	for property_id in [PropertyID.margin, .padding, .border] {
		assert !computed_interpolation_is_longhand_property(property_id)
		before[property_id] = value
		after[property_id] = &dom.StyleValue{
			css_text: 'different'
		}
	}
	before[.opacity] = value
	after[.opacity] = equal_value
	assert animated_property_maps_invalidation(before, after).is_none()
	assert animated_property_maps_invalidation(before, before).is_none()
}

fn test_sparse_animation_maps_merge_work_independently_of_insertion_order() {
	block :=
		dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block))))
	no_display :=
		dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_))))
	old_value := &dom.StyleValue{
		css_text: 'old'
	}
	new_value := &dom.StyleValue{
		css_text: 'new'
	}
	mut before := map[PropertyID]&dom.StyleValue{}
	before[.display] = block
	before[.pointer_events] = old_value
	before[.content] = old_value
	mut after := map[PropertyID]&dom.StyleValue{}
	after[.content] = new_value
	after[.display] = no_display
	after[.container_type] = new_value
	mut expected := compute_property_invalidation(.display, block, no_display)
	expected = required_invalidation_after_style_change_or(expected, compute_property_invalidation(.content,
		old_value, new_value))
	expected = required_invalidation_after_style_change_or(expected, compute_property_invalidation(.pointer_events,
		old_value, none))
	expected = required_invalidation_after_style_change_or(expected, compute_property_invalidation(.container_type,
		none, new_value))
	actual := animated_property_maps_invalidation(before, after)
	assert actual == expected
	assert actual.layout_tree_rebuild_root() == .box_presence_change
	assert actual.affects_hit_testing
	assert actual.recompute_descendant_styles
	assert before.len == 3
	assert after.len == 3
}
