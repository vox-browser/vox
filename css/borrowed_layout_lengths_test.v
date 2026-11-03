module css

import dom
import math

fn copied_layout_length_oracle(style &ComputedProperties, value &dom.StyleValue, basis f64) ?f64 {
	typed := style_value_logic_from_dom(.width, value) or { return none }
	if typed is LengthStyleValue && typed.length_.is_absolute() {
		return style.absolute_layout_length_to_px(typed.length_).to_double()
	}
	if typed is PercentageStyleValue {
		return LengthPercentage.from_style_value_logic(typed).to_px(LengthResolutionContext{},
			CSSPixels.nearest_value_for(basis)).to_double()
	}
	return none
}

fn test_borrowed_layout_lengths_preserve_absolute_units_rounding_and_clamps() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
		mut style := ComputedProperties.new()
		style.subject_element_ = element
		for unit in [LengthUnit.px, .cm, .mm, .q, .in_, .pt, .pc] {
			for number in [f64(-100000000), -31.9921875, -0.0078125, 0, 0.0078125, 1.125, 100000000, math.inf(1), math.inf(-1), math.f64_from_bits(u64(0x7ff8000000001234))] {
				value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.new(number, unit))))
				style.set_property(.width, value, .no, .no)
				assert style.length_percentage_to_px(.width, 123.125) == copied_layout_length_oracle(style, value, 123.125)
			}
		}
	}
}

fn test_borrowed_layout_percentages_keep_fractional_basis_and_negative_truncation() {
	mut style := ComputedProperties.new()
	for number in [f64(-150), -0.5, 0, 0.5, 33.333333, 100, 250] {
		value := dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(number))))
		style.set_property(.width, value, .no, .no)
		for basis in [f64(-100000000), -33.125, -0.0078125, 0, 0.0078125, 100.125, 100000000] {
			assert style.length_percentage_to_px(.width, basis) == copied_layout_length_oracle(style, value, basis)
		}
	}
}

fn test_borrowed_layout_lengths_observe_animated_values_and_important_overrides() {
	mut style := ComputedProperties.new()
	base := parse_css_value(ParsingParams{}, '10.125px', .width) or { panic('base') }
	animated := parse_css_value(ParsingParams{}, '25%', .width) or { panic('animation') }
	style.set_property(.width, base, .no, .no)
	style.set_animated_property(.width, animated, .no, .no)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 50
	style.set_property_important(.width, .yes)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 10.125
	style.set_animated_property(.width, animated, .yes, .no)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 50
	style.remove_animated_property(.width)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 10.125
}

fn test_borrowed_layout_length_reads_do_not_cache_mutable_payloads() {
	mut style := ComputedProperties.new()
	value := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(11))))
	style.set_property(.width, value, .no, .no)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 11
	mut box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	box.value = StyleValue(PercentageStyleValue.create(Percentage.new(25)))
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 50
	box.value = StyleValue(LengthStyleValue.create(Length.make_px(17)))
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 17
}

fn test_borrowed_layout_lengths_leave_untyped_values_and_context_consumers_to_fallback() {
	mut style := ComputedProperties.new()
	for text in ['12px', '25%', '2em', 'calc(2em + 25%)', 'auto'] {
		untyped := &dom.StyleValue{css_text: text}
		assert style.borrowed_scalar_layout_length_px(untyped, 100) == none
	}
	for text in ['2em', 'calc(2em + 25%)', 'auto'] {
		value := parse_css_value(ParsingParams{}, text, .width) or { panic(text) }
		assert style.borrowed_scalar_layout_length_px(value, 100) == none
	}
	style.set_property(.width, &dom.StyleValue{css_text: '25%'}, .no, .no)
	assert style.length_percentage_to_px(.width, 200) or { -1 } == 50
}
