module css

import dom

fn retained_length_auto_old_oracle(style_value &dom.StyleValue) LengthPercentageOrAuto {
	if keyword := computed_interpolation_style_value_keyword(style_value) {
		if keyword == .auto { return LengthPercentageOrAuto.make_auto() }
	}
	if parsed_value := parsed_length_percentage_style_value_from_dom_style_value(style_value) {
		return LengthPercentageOrAuto.from_style_value_logic(parsed_value)
	}
	return LengthPercentageOrAuto.make_auto()
}

fn test_retained_length_auto_keeps_units_values_and_owner_precedence() {
	for unit in [LengthUnit.cap, .ch, .cm, .cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw, .dvb, .dvh, .dvi, .dvmax, .dvmin, .dvw, .em, .ex, .ic, .in_, .lh, .lvb, .lvh, .lvi, .lvmax, .lvmin, .lvw, .mm, .pc, .pt, .px, .q, .rcap, .rch, .rem, .rex, .ric, .rlh, .svb, .svh, .svi, .svmax, .svmin, .svw, .vb, .vh, .vi, .vmax, .vmin, .vw] {
		for magnitude in [f64(-2.5), -0.0, 0.125, 100, 100000000] {
			mut bridge := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(magnitude, unit))))
			bridge.css_text = 'auto trailing'
			actual := LengthPercentageOrAuto.from_style_value(bridge)
			assert actual == retained_length_auto_old_oracle(bridge)
			assert actual.is_length()
			assert actual.length_percentage().length() == Length.new(magnitude, unit)
		}
	}
}

fn test_retained_length_auto_preserves_other_types_and_strict_serialized_fallback() {
	for source in ['auto', '25%', 'calc(2px + 3%)', '-2.5em'] {
		bridge := parse_css_value(ParsingParams{}, source, .margin_left) or { panic('missing ${source}') }
		assert LengthPercentageOrAuto.from_style_value(bridge) == retained_length_auto_old_oracle(bridge)
	}
	for typed in [StyleValue(KeywordStyleValue.create(.normal)), StyleValue(NumberStyleValue.create(3)),
		StyleValue(IntegerStyleValue.create(2)), StyleValue(StringStyleValue.create('12px')),
		StyleValue(CustomIdentStyleValue.create('7px'))] {
		mut bridge := dom_style_value_from_value_logic(typed)
		bridge.css_text = '12px'
		assert LengthPercentageOrAuto.from_style_value(bridge).is_auto()
		assert LengthPercentageOrAuto.from_style_value(bridge) == retained_length_auto_old_oracle(bridge)
	}
	for source in ['', 'auto', '12px', '-2.5em', '25%', 'calc(2px + 3%)', '12px trailing', '12px 5px', 'bogus'] {
		bridge := &dom.StyleValue{css_text: source}
		assert LengthPercentageOrAuto.from_style_value(bridge) == retained_length_auto_old_oracle(bridge)
	}
	assert LengthPercentageOrAuto.from_style_value(&dom.StyleValue{css_text:'auto'}).is_auto()
	assert LengthPercentageOrAuto.from_style_value(&dom.StyleValue{css_text:'12px trailing'}).is_auto()
	assert LengthPercentageOrAuto.from_style_value(&dom.StyleValue{css_text:'12px'}).length_percentage().length() == Length.make_px(12)
	assert LengthPercentageOrAuto.from_style_value(&dom.StyleValue{css_text:'25%'}).length_percentage().percentage() == Percentage.new(25)
}

fn test_retained_length_auto_observes_owner_edits_and_preserves_old_results() {
	mut bridge := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(2.5, .em))))
	first := LengthPercentageOrAuto.from_style_value(bridge)
	assert first.length_percentage().length() == Length.new(2.5, .em)
	mut owner := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	owner.value = StyleValue(PercentageStyleValue.create(Percentage.new(42)))
	gc_collect()
	assert LengthPercentageOrAuto.from_style_value(bridge).length_percentage().percentage() == Percentage.new(42)
	assert first.length_percentage().length() == Length.new(2.5, .em)
	replacement := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(-3, .rem))))
	bridge.css_value_handle = replacement.css_value_handle
	gc_collect()
	assert LengthPercentageOrAuto.from_style_value(bridge).length_percentage().length() == Length.new(-3, .rem)
	mut replacement_owner := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	replacement_owner.value = StyleValue(KeywordStyleValue.create(.auto))
	assert LengthPercentageOrAuto.from_style_value(bridge).is_auto()
	bridge.css_value_handle = unsafe { nil }
	bridge.css_text = '17px'
	assert LengthPercentageOrAuto.from_style_value(bridge).length_percentage().length() == Length.make_px(17)
	assert first.length_percentage().length() == Length.new(2.5, .em)
}
