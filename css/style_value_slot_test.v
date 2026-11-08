module css

import platform

fn slot_lifetime_rgb() RGBColorStyleValue {
	return RGBColorStyleValue.create(StyleValue(NumberStyleValue.create(12)),
		StyleValue(NumberStyleValue.create(34)), StyleValue(NumberStyleValue.create(56)),
		StyleValue(NumberStyleValue.create(0.5)), .modern, none)
}

fn test_exported_color_slots_own_their_headers_and_children_after_producer_retirement() {
	mut input := platform.new_arena('recursive color producer')
	entry := input.enter()
	mut source := slot_lifetime_rgb()
	input.leave(entry)
	owned := export_property_value(StyleValue(source))
	source.r_.value = StyleValue(NumberStyleValue.create(199))
	input.release()
	gc_collect()
	assert owned.serialize(.normal) == slot_lifetime_rgb().serialize(.normal)
	color := owned as RGBColorStyleValue
	assert color.r_.len == 1 && color.g_.len == 1 && color.b_.len == 1 && color.alpha_.len == 1
	red := color.r_.value as NumberStyleValue
	assert red.value_ == 12
}

fn test_replacing_child_slots_preserves_value_copies_and_optional_accessors() {
	mut first := slot_lifetime_rgb()
	second := first
	first.r_ = style_value_slot(StyleValue(NumberStyleValue.create(77)))
	assert second.serialize(.normal) == slot_lifetime_rgb().serialize(.normal)
	mut child := second.r_.value
	if mut child is NumberStyleValue { child.value_ = 88 }
	red := second.r_.value as NumberStyleValue
	assert red.value_ == 12
	assert style_value_from_optional_storage(unsafe { nil }) == none
	mut optional_child := optional_style_value_storage(StyleValue(IntegerStyleValue.create(9)))
	old_child := optional_child
	optional_child = optional_style_value_storage(none)
	assert optional_child == unsafe { nil }
	assert (style_value_from_optional_storage(old_child)? as IntegerStyleValue).value_ == 9
}

fn test_separate_recursive_slots_compare_by_child_value() {
	first := slot_lifetime_rgb()
	second := slot_lifetime_rgb()
	assert voidptr(first.r_) != voidptr(second.r_)
	assert first == second
	assert StyleValue(first) == StyleValue(second)
	assert StyleValue(first).equals(&StyleValue(second))
	mut changed := slot_lifetime_rgb()
	changed.r_.value = StyleValue(NumberStyleValue.create(99))
	assert first != changed
	assert StyleValue(first) != StyleValue(changed)
	assert style_value_slots_equal(unsafe { nil }, unsafe { nil })
	assert !style_value_slots_equal(first.r_, unsafe { nil })
	assert !style_value_slots_equal(unsafe { nil }, second.r_)
}

fn test_default_slots_preserve_the_keyword_child_and_cardinality() {
	color := RGBColorStyleValue{}
	for child in [color.r_, color.g_, color.b_, color.alpha_] {
		assert child.len == 1
		assert child.value is KeywordStyleValue
		if child.value is KeywordStyleValue {
			assert child.value.keyword_ == KeywordStyleValue{}.keyword_
		}
	}
}

fn test_separately_parsed_colors_gradients_and_shadow_children_compare_by_value() {
	for id, texts in {
		PropertyID.color: ['rgb(12 34 56 / .5)', 'hsl(120 30% 40% / .5)',
			'hwb(120 10% 20% / .5)', 'lab(50% 10 20 / .5)', 'lch(50% 20 30 / .5)',
			'oklab(50% .1 .2 / .5)', 'oklch(50% .2 30 / .5)', 'color(display-p3 .1 .2 .3 / .5)']
		PropertyID.background_image: ['radial-gradient(circle, red, blue)',
			'conic-gradient(from 20deg, red, blue)']
		PropertyID.box_shadow: ['1px 2px 3px 4px rgb(12 34 56 / .5)']
		PropertyID.font_style: ['oblique 12deg']
		PropertyID.object_position: ['left 10px top 20px']
	} {
		for text in texts {
			first := parse_css_value_logic(id, text) or { panic(text) }
			second := parse_css_value_logic(id, text) or { panic(text) }
			assert first == second, text
			assert first.equals(second), text
		}
	}
}

fn slot_equality_additional_values() []StyleValue {
	child := StyleValue(NumberStyleValue.create(3))
	return [StyleValue(AnchorStyleValue.create('--anchor',
		StyleValue(KeywordStyleValue.create(.left)), child)),
		StyleValue(AnchorSizeStyleValue.create('--anchor', none, child)),
		StyleValue(CursorStyleValue.create(CursorImageValue{}, child, child)),
		StyleValue(RandomValueSharingStyleValue.create_fixed(child))]
}

fn test_nullable_recursive_slots_keep_structural_equality_and_presence() {
	first := slot_equality_additional_values()
	second := slot_equality_additional_values()
	for index in 0 .. first.len {
		assert first[index] == second[index]
		assert first[index].equals(second[index])
	}
	zero := StyleValue(NumberStyleValue.create(0))
	assert CursorStyleValue.create(CursorImageValue{}, none, none)
		!= CursorStyleValue.create(CursorImageValue{}, zero, zero)
	assert RandomValueSharingStyleValue.create_fixed(zero)
		!= RandomValueSharingStyleValue.create_fixed(StyleValue(NumberStyleValue.create(3)))
}
