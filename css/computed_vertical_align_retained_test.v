module css

import dom

fn retained_vertical_align_oracle(style &ComputedProperties) ?LengthPercentage {
	value := style.property(.vertical_align, .yes) or { return none }
	typed := style_value_logic_from_dom(.vertical_align, value) or { return none }
	return match typed {
		LengthStyleValue, PercentageStyleValue, CalculatedStyleValue {
			LengthPercentage.from_style_value_logic(typed)
		}
		else { none }
	}
}

fn retained_vertical_align_check_oracle(style &ComputedProperties) {
	expected := retained_vertical_align_oracle(style) or {
		assert style.vertical_align_length_percentage() == none
		return
	}
	actual := style.vertical_align_length_percentage() or { panic('missing numeric vertical-align') }
	assert actual == expected
	assert actual.to_string() == expected.to_string()
}

fn test_retained_vertical_align_keeps_numeric_units_calculations_and_results() {
	mut style := ComputedProperties.new()
	for unit in [LengthUnit.cap, .ch, .cm, .cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw,
		.dvb, .dvh, .dvi, .dvmax, .dvmin, .dvw, .em, .ex, .ic, .in_, .lh, .lvb, .lvh,
		.lvi, .lvmax, .lvmin, .lvw, .mm, .pc, .pt, .px, .q, .rcap, .rch, .rem, .rex,
		.ric, .rlh, .svb, .svh, .svi, .svmax, .svmin, .svw, .vb, .vh, .vi, .vmax,
		.vmin, .vw] {
		for magnitude in [f64(-2.5), -0.0, 0.125, 100, 100000000] {
			mut owner := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(
				Length.new(magnitude, unit))))
			owner.css_text = 'baseline trailing'
			style.set_property(.vertical_align, owner, .no, .no)
			actual := style.vertical_align_length_percentage() or { panic('missing length') }
			assert actual.is_length()
			assert actual.length() == Length.new(magnitude, unit)
			retained_vertical_align_check_oracle(style)
		}
	}
	for source in ['-25%', '0%', '12.5%', 'calc(2px + 3%)', 'calc(1em - 2px)'] {
		mut owner := parse_css_value(ParsingParams{}, source, .vertical_align) or {
			panic('missing ${source}')
		}
		owner.css_text = 'top'
		style.set_property(.vertical_align, owner, .no, .no)
		retained_vertical_align_check_oracle(style)
		first := style.vertical_align_length_percentage() or { panic('missing numeric value') }
		first_text := first.to_string()
		style.set_property(.vertical_align, dom_style_value_from_value_logic(StyleValue(
			KeywordStyleValue.create(.baseline))), .no, .no)
		gc_collect()
		assert first.to_string() == first_text
		assert style.vertical_align_length_percentage() == none
	}
}

fn test_retained_vertical_align_keeps_authoritative_types_and_text_fallbacks() {
	mut style := ComputedProperties.new()
	assert style.vertical_align_length_percentage() == none
	for typed in [StyleValue(KeywordStyleValue.create(.baseline)),
		StyleValue(KeywordStyleValue.create(.top)), StyleValue(NumberStyleValue.create(3)),
		StyleValue(IntegerStyleValue.create(2)), StyleValue(StringStyleValue.create('12px')),
		StyleValue(CustomIdentStyleValue.create('7px'))] {
		mut owner := dom_style_value_from_value_logic(typed)
		owner.css_text = '12px'
		style.set_property(.vertical_align, owner, .no, .no)
		assert style.vertical_align_length_percentage() == none
		retained_vertical_align_check_oracle(style)
	}
	for source in ['', 'baseline', 'sub', 'super', 'text-top', 'text-bottom', 'middle',
		'top', 'bottom', '12px', '-2.5em', '25%', 'calc(2px + 3%)', '12px trailing',
		'12px 5px', 'bogus'] {
		owner := &dom.StyleValue{css_text: source}
		style.set_property(.vertical_align, owner, .no, .no)
		retained_vertical_align_check_oracle(style)
		gc_collect()
		retained_vertical_align_check_oracle(style)
		assert owner.css_value_handle == unsafe { nil }
	}
	style.set_property(.vertical_align, &dom.StyleValue{css_text: '12px'}, .no, .no)
	assert (style.vertical_align_length_percentage() or { panic('missing fallback') }).length() == Length.make_px(12)
}

fn test_retained_vertical_align_observes_animation_precedence_and_owner_edits() {
	mut style := ComputedProperties.new()
	mut base := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(
		Length.new(2.5, .em))))
	animated := dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(
		Percentage.new(42))))
	for important in [Important.no, .yes] {
		for transition in [AnimatedPropertyResultOfTransition.no, .yes] {
			style.set_property(.vertical_align, base, .yes, important)
			style.set_animated_property(.vertical_align, animated, transition, .yes)
			actual := style.vertical_align_length_percentage() or { panic('missing animation') }
			expected := if important == .no || transition == .yes {
				LengthPercentage.from_percentage(Percentage.new(42))
			} else {
				LengthPercentage.from_length(Length.new(2.5, .em))
			}
			assert actual == expected
			retained_vertical_align_check_oracle(style)
			assert voidptr(style.property(.vertical_align, .no)?) == voidptr(base)
			assert style.is_property_important(.vertical_align) == (important == .yes)
			style.remove_animated_property(.vertical_align)
			gc_collect()
			assert actual == expected
			assert (style.vertical_align_length_percentage() or { panic('missing base') }).length() == Length.new(2.5, .em)
		}
	}
	for important in [Important.no, .yes] {
		for transition in [AnimatedPropertyResultOfTransition.no, .yes] {
			style.set_property(.vertical_align, base, .no, important)
			style.set_animated_property(.vertical_align, &dom.StyleValue{css_text: 'top'}, transition, .no)
			retained_vertical_align_check_oracle(style)
			if important == .no || transition == .yes {
				assert style.vertical_align_length_percentage() == none
			} else {
				assert (style.vertical_align_length_percentage() or { panic('missing important base') }).length() == Length.new(2.5, .em)
			}
			style.remove_animated_property(.vertical_align)
		}
	}
	first := style.vertical_align_length_percentage() or { panic('missing old value') }
	mut owner := unsafe { &TypedStyleValueBox(base.css_value_handle) }
	owner.value = StyleValue(PercentageStyleValue.create(Percentage.new(19)))
	gc_collect()
	assert (style.vertical_align_length_percentage() or { panic('missing edited owner') }).percentage() == Percentage.new(19)
	assert first.length() == Length.new(2.5, .em)
	replacement := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(-3, .rem))))
	base.css_value_handle = replacement.css_value_handle
	gc_collect()
	assert (style.vertical_align_length_percentage() or { panic('missing replacement') }).length() == Length.new(-3, .rem)
	base.css_value_handle = unsafe { nil }
	base.css_text = '17px'
	assert (style.vertical_align_length_percentage() or { panic('missing edited fallback') }).length() == Length.make_px(17)
}
