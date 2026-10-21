module css

import dom

fn retained_length_old_public_oracle(style_value &dom.StyleValue, percentage_basis ?Length) Length {
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return Length.from_style_value_logic(parsed_value, percentage_basis)
	}
	if basis := percentage_basis { return basis }
	return Length.make_px(0)
}

fn test_retained_public_length_reads_all_units_with_typed_precedence() {
	for unit in [LengthUnit.cap, .ch, .cm, .cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw, .dvb, .dvh, .dvi, .dvmax, .dvmin, .dvw, .em, .ex, .ic, .in_, .lh, .lvb, .lvh, .lvi, .lvmax, .lvmin, .lvw, .mm, .pc, .pt, .px, .q, .rcap, .rch, .rem, .rex, .ric, .rlh, .svb, .svh, .svi, .svmax, .svmin, .svw, .vb, .vh, .vi, .vmax, .vmin, .vw] {
		for magnitude in [f64(-2.5), -0.0, 0.125, 100, 100000000] {
			mut value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(magnitude, unit))))
			value.css_text = '75% trailing'
			for with_basis in [false, true] {
				mut basis := ?Length(none)
				if with_basis { basis = Length.new(73, .em) }
				actual := Length.from_style_value(value, basis)
				assert actual == retained_length_old_public_oracle(value, basis)
				assert actual.raw_value() == magnitude && actual.unit() == unit
			}
		}
	}
}

fn test_retained_public_length_preserves_other_types_calculations_and_serialized_fallback() {
	for typed in [StyleValue(KeywordStyleValue.create(.auto)), StyleValue(NumberStyleValue.create(12)),
		StyleValue(IntegerStyleValue.create(7)), StyleValue(CustomIdentStyleValue.create('5px')),
		StyleValue(StringStyleValue.create('9px'))] {
		mut value := dom_style_value_from_value_logic(typed)
		value.css_text = '12px'
		assert Length.from_style_value(value, none) == Length.make_px(0)
		assert Length.from_style_value(value, Length.new(7, .em)) == Length.new(7, .em)
		assert Length.from_style_value(value, none) == retained_length_old_public_oracle(value, none)
	}
	percentage := dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(25))))
	assert Length.from_style_value(percentage, Length.new(80, .em)) == Length.new(20, .em)
	assert Length.from_style_value(percentage, Length.make_px(320)) == Length.make_px(80)
	calculated := parse_css_value(ParsingParams{}, 'calc(2px + 3px)', .width) or { panic('missing calculation') }
	assert Length.from_style_value(calculated, none) == Length.make_px(5)
	assert Length.from_style_value(calculated, none) == retained_length_old_public_oracle(calculated, none)
	for text in ['', 'auto', '12px trailing', '12px 5px', '/* comment */', '12px', '-2.5em', '25%', 'calc(2px + 3px)'] {
		value := &dom.StyleValue{ css_text: text }
		basis := Length.new(100, .px)
		assert Length.from_style_value(value, basis) == retained_length_old_public_oracle(value, basis)
	}
	assert Length.from_style_value(&dom.StyleValue{css_text:'12px'}, none) == Length.make_px(12)
	assert Length.from_style_value(&dom.StyleValue{css_text:'-2.5em'}, none) == Length.new(-2.5, .em)
}

fn test_retained_public_length_keeps_value_snapshots_after_handle_edits_and_collection() {
	retained := [dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(2.5, .em)))),
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto))),
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(-3, .rem))))]
	mut bridge := &dom.StyleValue{ css_text:'9px' }
	assert Length.from_style_value(bridge, none) == Length.make_px(9)
	for index, owner in retained {
		bridge.css_value_handle = owner.css_value_handle
		gc_collect()
		expected := if index == 0 {Length.new(2.5, .em)} else if index == 1 {Length.make_px(0)} else {Length.new(-3, .rem)}
		assert Length.from_style_value(bridge, none) == expected
		assert Length.from_style_value(bridge, none) == retained_length_old_public_oracle(bridge, none)
	}
	mut box := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	box.value = StyleValue(LengthStyleValue.create(Length.new(4.25, .cm)))
	result := Length.from_style_value(bridge, none)
	box.value = StyleValue(KeywordStyleValue.create(.normal))
	gc_collect()
	assert result == Length.new(4.25, .cm)
	assert Length.from_style_value(bridge, none) == Length.make_px(0)
	bridge.css_value_handle = unsafe { nil }
	assert Length.from_style_value(bridge, none) == Length.make_px(9)
}
