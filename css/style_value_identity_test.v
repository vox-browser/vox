module css

import dom
import math

fn identity_legacy_option_changed(old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) bool {
	if old := old_value {
		if new := new_value {
			if old_typed := typed_style_value_logic_from_dom(old) {
				if new_typed := typed_style_value_logic_from_dom(new) {
					return !old_typed.equals(new_typed)
				}
			}
			return old.css_text != new.css_text
		}
		return true
	}
	return new_value != none
}

fn identity_test_shared_wrapper(value &dom.StyleValue) &dom.StyleValue {
	return &dom.StyleValue{
		css_text:         'deliberately different bridge text'
		css_value_handle: value.css_value_handle
		base_url:         'https://different.invalid/'
	}
}

fn identity_test_number_values(number f64) []StyleValue {
	return [StyleValue(NumberStyleValue.create(number)),
		StyleValue(LengthStyleValue.create(Length.make_px(number))),
		StyleValue(AngleStyleValue.create(Angle.make_degrees(number))),
		StyleValue(PercentageStyleValue.create(Percentage.new(number))),
		StyleValue(FlexStyleValue.create(Flex.make_fr(number))),
		StyleValue(FrequencyStyleValue.create(Frequency.make_hertz(number))),
		StyleValue(ResolutionStyleValue.create(Resolution.make_dots_per_pixel(number))),
		StyleValue(TimeStyleValue.create(Time.make_seconds(number)))]
}

fn identity_test_compare(old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) {
	assert style_value_option_changed(old_value, new_value) == identity_legacy_option_changed(old_value,
		new_value)
}

fn test_style_value_identity_preserves_option_and_distinct_value_comparisons() {
	values := [
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.normal))),
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))),
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12)))),
		dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(math.nan()))),
		&dom.StyleValue{
			css_text: 'normal'
		},
		&dom.StyleValue{
			css_text: 'normal'
		},
		&dom.StyleValue{
			css_text: '12px'
		},
	]
	identity_test_compare(none, none)
	for old in values {
		identity_test_compare(old, none)
		identity_test_compare(none, old)
		for new in values {
			identity_test_compare(old, new)
		}
		identity_test_compare(old, old)
		if old.css_value_handle != unsafe { nil } {
			identity_test_compare(old, identity_test_shared_wrapper(old))
		}
	}
	old := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12))))
	mut changed :=
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(13))))
	changed.css_text = old.css_text
	assert style_value_option_changed(old, changed)
	assert !style_value_option_changed(old,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12)))))
}

fn test_style_value_identity_keeps_nan_non_reflexive_in_scalars_lists_and_pending_values() {
	for scalar in identity_test_number_values(math.nan()) {
		value := dom_style_value_from_value_logic(scalar)
		assert identity_legacy_option_changed(value, value)
		assert style_value_option_changed(value, value)
		assert style_value_option_changed(value, identity_test_shared_wrapper(value))
		assert !style_value_identity_is_reflexive(scalar)
		list := StyleValue(StyleValueList.create([
			StyleValue(KeywordStyleValue.create(.normal)),
			scalar,
		], .space, .no))
		list_value := dom_style_value_from_value_logic(list)
		assert identity_legacy_option_changed(list_value, list_value)
		assert style_value_option_changed(list_value, list_value)
		assert style_value_option_changed(list_value, identity_test_shared_wrapper(list_value))
		pending :=
			dom_style_value_from_value_logic(StyleValue(PendingSubstitutionStyleValue.create(list)))
		assert identity_legacy_option_changed(pending, pending)
		assert style_value_option_changed(pending, pending)
		assert style_value_option_changed(pending, identity_test_shared_wrapper(pending))
	}
	for number in [f64(0), -0.0, 1.25, math.inf(1), math.inf(-1)] {
		for scalar in identity_test_number_values(number) {
			value := dom_style_value_from_value_logic(scalar)
			assert !identity_legacy_option_changed(value, value)
			assert !style_value_option_changed(value, value)
			assert !style_value_option_changed(value, identity_test_shared_wrapper(value))
			assert style_value_identity_is_reflexive(scalar)
		}
	}
}

fn test_style_value_identity_rechecks_mutated_legacy_bridges_and_live_typed_handles() {
	mut bridge := &dom.StyleValue{
		css_text: 'normal'
	}
	assert !style_value_option_changed(bridge, bridge)
	bridge.css_text = 'changed in place'
	assert !style_value_option_changed(bridge, bridge)
	assert style_value_option_changed(bridge, &dom.StyleValue{
		css_text: 'normal'
	})
	mut typed := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(12)))
	wrapper := identity_test_shared_wrapper(typed)
	assert !style_value_option_changed(typed, wrapper)
	mut box := unsafe { &TypedStyleValueBox(typed.css_value_handle) }
	box.value = StyleValue(NumberStyleValue.create(math.nan()))
	assert style_value_option_changed(typed, typed)
	assert style_value_option_changed(typed, wrapper)
	box.value = StyleValue(StringStyleValue.create('current payload'))
	assert !style_value_option_changed(typed, wrapper)
	typed.css_value_handle = unsafe { nil }
	typed.css_text = 'plain bridge'
	identity_test_compare(typed, wrapper)
	assert style_value_option_changed(typed, wrapper)
}

fn test_style_value_identity_preserves_complex_substitution_and_calculation_semantics() {
	first :=
		dom_style_value_from_value_logic(StyleValue(PendingSubstitutionStyleValue.create(StyleValue(StringStyleValue.create('var(--first)')))))
	mut second :=
		dom_style_value_from_value_logic(StyleValue(PendingSubstitutionStyleValue.create(StyleValue(StringStyleValue.create('var(--second)')))))
	second.css_text = first.css_text
	assert !style_value_identity_is_reflexive(typed_style_value_logic_from_dom(first)?)
	assert !style_value_option_changed(first, first)
	assert !style_value_option_changed(first, identity_test_shared_wrapper(first))
	assert style_value_option_changed(first, second)
	calc := parse_css_value(ParsingParams{}, 'calc(1em + NaN * 1px)', .width) or { panic('calc') }
	assert !style_value_identity_is_reflexive(typed_style_value_logic_from_dom(calc)?)
	identity_test_compare(calc, calc)
	identity_test_compare(calc, identity_test_shared_wrapper(calc))
}

fn test_style_value_identity_preserves_property_invalidation_and_animation_precedence() {
	mut style := computed_properties_with_initial_values()
	base :=
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12))))
	animated :=
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(14))))
	transitioned :=
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(16))))
	style.set_property(.width, base, .no, .yes)
	style.set_animated_property(.width, animated, .no, .no)
	assert !compute_property_invalidation(.width, base, style.property(.width, .yes)).needs_relayout()
	style.set_animated_property(.width, transitioned, .yes, .no)
	assert compute_property_invalidation(.width, base, style.property(.width, .yes)).needs_relayout()
	assert !compute_property_invalidation(.width, transitioned, style.property(.width, .yes)).needs_relayout()
	style.remove_animated_property(.width)
	assert !compute_property_invalidation(.width, base, style.property(.width, .yes)).needs_relayout()
	nan := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(math.nan())))
	assert compute_property_invalidation(.opacity, nan, nan).needs_repaint()
	assert !compute_property_invalidation(.opacity, base, base).needs_repaint()
}

fn test_style_value_identity_matches_old_helper_for_all_initial_property_handles() {
	initial := computed_properties_with_initial_values()
	mut eligible := 0
	for property in computed_interpolation_longhand_property_ids() {
		value := initial.property(property, .no) or { continue }
		identity_test_compare(value, value)
		identity_test_compare(value, identity_test_shared_wrapper(value))
		if typed := typed_style_value_logic_from_dom(value) {
			if style_value_identity_is_reflexive(typed) { eligible++ }
			distinct := dom_style_value_from_value_logic(typed)
			identity_test_compare(value, distinct)
		}
	}
	assert eligible > 100
}
