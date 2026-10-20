module css

import dom
import math

// The unchanged public conversion from before direct retained-owner dispatch.
fn length_typed_dispatch_old_oracle(value &dom.StyleValue, basis ?Length) Length {
	if value.css_value_handle != unsafe { nil } {
		typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if typed.value is LengthStyleValue {
			return typed.value.length()
		}
	}
	if parsed := parsed_length_percentage_style_value_from_dom_style_value(value) {
		return Length.from_style_value_logic(parsed, basis)
	}
	if fallback := basis { return fallback }
	return Length.make_px(0)
}

fn test_length_typed_dispatch_rejects_other_types_without_reading_stale_serialization() {
	for typed in [StyleValue(KeywordStyleValue.create(.normal)),
		StyleValue(KeywordStyleValue.create(.auto)), StyleValue(KeywordStyleValue.create(.block)),
		StyleValue(NumberStyleValue.create(12)), StyleValue(IntegerStyleValue.create(7)),
		StyleValue(CustomIdentStyleValue.create('5px')), StyleValue(StringStyleValue.create('9px'))] {
		mut value := dom_style_value_from_value_logic(typed)
		for spelling in ['12px', '25%', 'calc(2px + 3px)', 'invalid trailing'] {
			value.css_text = spelling
			assert Length.from_style_value(value, none) == Length.make_px(0)
			assert Length.from_style_value(value, Length.new(7, .em)) == Length.new(7, .em)
			assert Length.from_style_value(value, none) == length_typed_dispatch_old_oracle(value, none)
			assert Length.from_style_value(value, Length.new(7, .em)) ==
				length_typed_dispatch_old_oracle(value, Length.new(7, .em))
		}
	}
}

fn test_length_typed_dispatch_preserves_percentages_and_calculation_resolution() {
	for unit in [LengthUnit.px, .em, .ch, .vw] {
		for magnitude in [f64(-80), -0.0, 0, 80, 256] {
			basis := Length.new(magnitude, unit)
			for percent in [f64(-25), 0, 25, 125] {
				mut value := dom_style_value_from_value_logic(StyleValue(
					PercentageStyleValue.create(Percentage.new(percent))))
				value.css_text = 'not a percentage'
				actual := Length.from_style_value(value, basis)
				expected := magnitude * (percent / 100)
				assert actual.unit() == unit
				assert math.f64_bits(actual.raw_value()) == math.f64_bits(expected)
				assert actual == length_typed_dispatch_old_oracle(value, basis)
			}
		}
	}
	mut absolute := parse_css_value(ParsingParams{}, 'calc(2px + 3px)', .width) or {
		panic('expected valid absolute calculation')
	}
	absolute.css_text = '99em'
	assert Length.from_style_value(absolute, none) == Length.make_px(5)
	assert Length.from_style_value(absolute, none) == length_typed_dispatch_old_oracle(absolute, none)
	mut relative := parse_css_value(ParsingParams{}, 'calc(25% + 2px)', .width) or {
		panic('expected valid percentage calculation')
	}
	relative.css_text = '99em'
	assert Length.from_style_value(relative, Length.make_px(80)) == Length.make_px(22)
	assert Length.from_style_value(relative, Length.make_px(80)) ==
		length_typed_dispatch_old_oracle(relative, Length.make_px(80))
}

fn test_length_typed_dispatch_keeps_the_complete_serialized_fallback() {
	for spelling in ['', 'auto', 'normal', '12px trailing', '12px 5px', '12px, 5px',
		'/* comment */', '12px', '-2.5em', '25%', 'calc(2px + 3px)', 'calc(25% + 2px)'] {
		value := &dom.StyleValue{css_text: spelling}
		assert Length.from_style_value(value, Length.make_px(80)) ==
			length_typed_dispatch_old_oracle(value, Length.make_px(80))
	}
	assert Length.from_style_value(&dom.StyleValue{css_text: '12px'}, none) == Length.make_px(12)
	assert Length.from_style_value(&dom.StyleValue{css_text: '-2.5em'}, none) == Length.new(-2.5, .em)
	assert Length.from_style_value(&dom.StyleValue{css_text: '25%'}, Length.make_px(80)) == Length.make_px(20)
	assert Length.from_style_value(&dom.StyleValue{css_text: '12px trailing'}, Length.new(7, .em)) == Length.new(7, .em)
}

fn test_length_typed_dispatch_observes_handle_edits_and_keeps_old_snapshots_alive() {
	calculated := parse_css_value(ParsingParams{}, 'calc(2px + 3px)', .width) or {
		panic('expected valid calculation owner')
	}
	owners := [dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(-3, .rem)))),
		dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(25)))),
		calculated, dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.normal)))]
	expected := [Length.new(-3, .rem), Length.make_px(20), Length.make_px(5), Length.make_px(80)]
	mut bridge := &dom.StyleValue{css_text: '17px'}
	mut snapshots := []Length{}
	for index, owner in owners {
		bridge.css_value_handle = owner.css_value_handle
		gc_collect()
		actual := Length.from_style_value(bridge, Length.make_px(80))
		assert actual == expected[index]
		assert actual == length_typed_dispatch_old_oracle(bridge, Length.make_px(80))
		snapshots << actual
	}
	mut box := unsafe { &TypedStyleValueBox(bridge.css_value_handle) }
	box.value = StyleValue(PercentageStyleValue.create(Percentage.new(50)))
	assert Length.from_style_value(bridge, Length.make_px(80)) == Length.make_px(40)
	box.value = StyleValue(NumberStyleValue.create(9))
	assert Length.from_style_value(bridge, none) == Length.make_px(0)
	bridge.css_value_handle = unsafe { nil }
	gc_collect()
	assert Length.from_style_value(bridge, none) == Length.make_px(17)
	assert snapshots == expected
}
