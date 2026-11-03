module css

import dom
import math

fn borrowed_invalidation_oracle(old_value ?&dom.StyleValue, new_value ?&dom.StyleValue) bool {
	if old := old_value {
		if new := new_value {
			if left := typed_style_value_logic_from_dom(old) {
				if right := typed_style_value_logic_from_dom(new) { return !left.equals(right) }
			}
			return old.css_text != new.css_text
		}
		return true
	}
	return new_value != none
}

fn test_borrowed_invalidation_matches_deep_equality_for_scalar_tags_and_missing_values() {
	mut values := []&dom.StyleValue{}
	for text, id in {'normal':PropertyID.line_height,'none':.display,'inline flow-root':.display,
		'block flow':.display,'auto':.width,'12px':.width,'12pt':.width,'50%':.width,
		'red':.color,'blue':.color,'0.5':.opacity,'2':.order,'"caption"':.content} {
		value := parse_css_value(ParsingParams{}, text, id) or { panic('scalar fixture') }
		values << value
		typed := typed_style_value_logic_from_dom(value) or { panic('typed fixture') }
		values << dom_style_value_from_value_logic(typed)
	}
	values << dom_style_value_from_value_logic(StyleValue(StringStyleValue.create('caption')))
	values << dom_style_value_from_value_logic(StyleValue(CustomIdentStyleValue.create('caption')))
	values << &dom.StyleValue{css_text:'12px'}
	values << &dom.StyleValue{css_text:'normal'}
	for old in values {
		assert style_value_option_changed(old, none) == borrowed_invalidation_oracle(old, none)
		assert style_value_option_changed(none, old) == borrowed_invalidation_oracle(none, old)
		for new in values {
			assert style_value_option_changed(old, new) == borrowed_invalidation_oracle(old, new)
		}
	}
	assert !style_value_option_changed(none, none)
}

fn test_borrowed_invalidation_keeps_nan_signed_zero_and_random_scalar_equality() {
	mut bits := u64(0x4bce18a32876f13)
	for index in 0 .. 260 {
		bits = bits * u64(6364136223846793005) + u64(1442695040888963407)
		value := match index {
			0 { math.nan() }
			1 { math.inf(1) }
			2 { math.inf(-1) }
			3 { math.f64_from_bits(u64(1) << 63) }
			else { math.f64_from_bits(bits) }
		}
		for scalar in [StyleValue(NumberStyleValue.create(value)),
			StyleValue(LengthStyleValue.create(Length.new(value, .px))),
			StyleValue(PercentageStyleValue.create(Percentage.new(value)))] {
			old := dom_style_value_from_value_logic(scalar)
			new := dom_style_value_from_value_logic(scalar)
			alias := &dom.StyleValue{css_text:'different bridge text',css_value_handle:old.css_value_handle}
			for other in [old, new, alias] {
				assert style_value_option_changed(old, other) == borrowed_invalidation_oracle(old, other)
			}
		}
	}
}

fn test_borrowed_invalidation_reads_live_boxes_and_preserves_full_display_payload() {
	old := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12))))
	new := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(12))))
	mut box := unsafe { &TypedStyleValueBox(new.css_value_handle) }
	assert !style_value_option_changed(old, new)
	box.value = StyleValue(LengthStyleValue.create(Length.make_px(13)))
	assert style_value_option_changed(old, new)
	box.value = StyleValue(NumberStyleValue.create(12))
	assert style_value_option_changed(old, new)
	for outside in [DisplayOutside.inline_, .block] {
		for inside in [DisplayInside.flow, .flow_root, .flex, .grid] {
			left := StyleValue(DisplayStyleValue.create(Display.from_outside_inside(outside, inside)))
			for right_outside in [DisplayOutside.inline_, .block] {
				for right_inside in [DisplayInside.flow, .flow_root, .flex, .grid] {
					right := StyleValue(DisplayStyleValue.create(Display.from_outside_inside(right_outside, right_inside)))
					first := dom_style_value_from_value_logic(left)
					second := dom_style_value_from_value_logic(right)
					assert style_value_option_changed(first, second) == borrowed_invalidation_oracle(first, second)
				}
			}
		}
	}
	// Serialization hides inactive Display fields, while typed equality keeps
	// them. The borrowed comparison must preserve that complete payload.
	base := Display.from_short(.block)
	mut other := base
	other.internal_ = .table_cell
	left := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(base)))
	right := dom_style_value_from_value_logic(StyleValue(DisplayStyleValue.create(other)))
	assert left.css_text == right.css_text
	assert style_value_option_changed(left, right)
	assert style_value_option_changed(left, right) == borrowed_invalidation_oracle(left, right)
}

fn test_borrowed_invalidation_keeps_composite_value_semantics() {
	for number in [f64(1), math.nan()] {
		list := StyleValue(StyleValueList.create([StyleValue(NumberStyleValue.create(number)),
			StyleValue(KeywordStyleValue.create(.normal))], .space, .no))
		old := dom_style_value_from_value_logic(list)
		new := dom_style_value_from_value_logic(list)
		assert style_value_option_changed(old, old) == borrowed_invalidation_oracle(old, old)
		assert style_value_option_changed(old, new) == borrowed_invalidation_oracle(old, new)
	}
	for text in ['calc(25% + 3px)', 'rgb(25% 0% 0%)'] {
		id := if text.starts_with('calc') { PropertyID.width } else { PropertyID.color }
		old := parse_css_value(ParsingParams{}, text, id) or { panic('composite') }
		new := parse_css_value(ParsingParams{}, text, id) or { panic('composite') }
		assert style_value_option_changed(old, new) == borrowed_invalidation_oracle(old, new)
	}
}
