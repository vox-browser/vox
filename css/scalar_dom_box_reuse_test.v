module css

import math
import platform

fn test_reused_scalar_payloads_outlive_input_and_keep_dom_wrappers_independent() {
	for source in [StyleValue(KeywordStyleValue.create(.block)),
		StyleValue(LengthStyleValue.create(Length.make_px(12.25))),
		StyleValue(NumberStyleValue.create(0.125)),
		StyleValue(IntegerStyleValue.create(17)),
		StyleValue(PercentageStyleValue.create(Percentage.new(62.5))),
		StyleValue(ColorStyleValue.create(Color.rgba(17, 23, 191, 128)))] {
		expected := source.serialize(.normal)
		mut scratch := platform.begin_thread_scratch('scalar producer')
		temporary := export_property_value(source)
		scratch.leave()
		mut first := dom_style_value_from_value_logic(temporary)
		scratch.finish()
		gc_collect()
		mut second := dom_style_value_from_value_logic(source)
		assert voidptr(first) != voidptr(second)
		assert first.css_text == expected && second.css_text == expected
		assert typed_style_value_logic_from_dom(first)?.equals(source)
		first.css_text = 'changed by caller'
		first.base_url = 'https://one.example/'
		first.css_value_handle = unsafe { nil }
		second.base_url = 'https://two.example/'
		third := dom_style_value_from_value_logic(source)
		assert second.css_text == expected && third.css_text == expected
		assert second.base_url? == 'https://two.example/'
		assert third.base_url == none
		assert typed_style_value_logic_from_dom(third)?.equals(source)
	}
}

fn test_scalar_box_fallback_preserves_precision_units_and_negative_zero() {
	for source in [StyleValue(NumberStyleValue.create(0.1)),
		StyleValue(NumberStyleValue.create(math.f64_from_bits(u64(1) << 63))),
		StyleValue(NumberStyleValue.create(1025)),
		StyleValue(LengthStyleValue.create(Length.new(1.25, .em))),
		StyleValue(IntegerStyleValue.create(5000))] {
		wrapped := dom_style_value_from_value_logic(source)
		assert wrapped.css_text == source.serialize(.normal)
		assert typed_style_value_logic_from_dom(wrapped)?.equals(source)
	}
}
