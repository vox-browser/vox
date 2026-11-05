module css

import dom
import platform

fn assert_animation_scan_matches_original(old_values map[PropertyID]&dom.StyleValue,
	new_values map[PropertyID]&dom.StyleValue) {
	actual := scan_animated_property_changes(old_values, new_values)
	expected := animated_property_maps_invalidation(old_values, new_values)
	local, background := animated_changes_are_local_paint(old_values, new_values)
	assert actual.invalidation == expected
	assert actual.compositor_only == animated_changes_are_compositor_only(old_values, new_values)
	assert actual.local_paint == local
	assert actual.background_only == background
}

fn test_animation_single_scan_matches_every_longhands_addition_change_and_removal() {
	old := &dom.StyleValue{ css_text: 'old' }
	changed := &dom.StyleValue{ css_text: 'changed' }
	equal := &dom.StyleValue{ css_text: 'old' }
	empty := map[PropertyID]&dom.StyleValue{}
	assert_animation_scan_matches_original(empty, empty)
	for property in computed_interpolation_longhand_property_ids() {
		before := {
			property: old
		}
		after := {
			property: changed
		}
		assert_animation_scan_matches_original(empty, after)
		assert_animation_scan_matches_original(before, after)
		assert_animation_scan_matches_original(before, empty)
		assert_animation_scan_matches_original(before, {
			property: equal
		})
	}
}

fn test_animation_single_scan_preserves_non_longhand_and_added_key_classification() {
	value := &dom.StyleValue{ css_text: 'same' }
	equal := &dom.StyleValue{ css_text: 'same' }
	empty := map[PropertyID]&dom.StyleValue{}
	for property in [PropertyID.margin, .padding, .border, .all] {
		assert !computed_interpolation_is_longhand_property(property)
		before := {
			property: value
		}
		after := {
			property: equal
		}
		assert_animation_scan_matches_original(before, after)
		assert_animation_scan_matches_original(empty, after)
		assert_animation_scan_matches_original(before, empty)
		added := scan_animated_property_changes(empty, after)
		assert added.invalidation.is_none()
		assert !added.compositor_only && !added.local_paint && !added.background_only
		unchanged := scan_animated_property_changes(before, after)
		assert unchanged.compositor_only && unchanged.local_paint && unchanged.background_only
	}
}

fn test_animation_single_scan_matches_mixed_maps_in_both_insertion_orders() {
	properties := computed_interpolation_longhand_property_ids()
	values := [
		&dom.StyleValue{ css_text: 'same' },
		&dom.StyleValue{ css_text: 'changed' },
		dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.5))),
		dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.5))),
		dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.block)))),
		dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(Display.from_short(.none_)))),
	]
	for seed in 0 .. 64 {
		for reverse in [false, true] {
			mut before := map[PropertyID]&dom.StyleValue{}
			mut after := map[PropertyID]&dom.StyleValue{}
			for step in 0 .. 24 {
				index := if reverse { 23 - step } else { step }
				property := properties[(index * 173 + seed * 31) % properties.len]
				if index % 3 != 0 { before[property] = values[(index + seed) % values.len] }
				if index % 5 != 0 { after[property] = values[(index * 3 + seed) % values.len] }
			}
			before[.margin] = values[0]
			after[.margin] = values[1]
			assert_animation_scan_matches_original(before, after)
		}
	}
}

fn test_animation_single_snapshot_results_and_public_snapshots_keep_their_ownership() {
	mut computed := computed_properties_with_initial_values()
	one := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(1)))
	half := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.5)))
	computed.set_animated_property(.opacity, one, .no, .no)
	mut previous := computed.animated_property_values()
	computed.set_animated_property(.opacity, half, .no, .no)
	mut temporary := platform.new_arena('animation change scan caller')
	entry := temporary.enter()
	changes := sampled_animation_property_changes(previous, computed)
	temporary.leave(entry)
	temporary.release()
	assert changes.compositor_only && !changes.local_paint && !changes.background_only
	assert changes.invalidation.needs_repaint()
	assert voidptr(previous[PropertyID.opacity] or { panic('missing old opacity') }) == voidptr(one)
	previous.clear()
	assert voidptr(computed.animated_property_value(.opacity)?) == voidptr(half)
	mut current_snapshot := computed.animated_property_values()
	current_snapshot.clear()
	assert voidptr(computed.animated_property_value(.opacity)?) == voidptr(half)
}
