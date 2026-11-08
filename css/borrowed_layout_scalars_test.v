module css

import dom

fn test_borrowed_layout_scalars_match_owned_value_resolution_and_live_handles() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_font_rendering_policy(policy)
		defer { document.finalize() }
		element := document.create_element('div')!
		mut style := computed_properties_with_initial_values()
		style.subject_element_ = element
		for text in ['auto', 'none', '1.333px', '-2.25px', '0px', '2pt', '12.345%', '2em', 'calc(20% + 3px)'] {
			value := parse_css_value(ParsingParams{}, text, .width) or { continue }
			style.set_property_without_modifying_flags(.width, value)
			typed := style_value_logic_from_dom(.width, value)?
			for basis in [f64(0), 19.75, 4_753_650] {
				mut expected := ?f64(none)
				if typed is LengthStyleValue {
					if typed.length().is_absolute() {
						expected = style.absolute_layout_length_to_px(typed.length()).to_double()
					} else {
						expected = LengthPercentage.from_style_value_logic(typed).to_px(style.length_resolution_context(), CSSPixels.nearest_value_for(basis)).to_double()
					}
				} else if typed is PercentageStyleValue {
					expected = LengthPercentage.from_style_value_logic(typed).to_px(LengthResolutionContext{}, CSSPixels.nearest_value_for(basis)).to_double()
				} else if typed is CalculatedStyleValue {
					expected = LengthPercentage.from_style_value_logic(typed).to_px(style.length_resolution_context(), CSSPixels.nearest_value_for(basis)).to_double()
				}
				assert style.length_percentage_to_px(.width, basis) == expected
			}
		}
		mut bridge := &dom.StyleValue{css_text: '13px'}
		style.set_property_without_modifying_flags(.font_size, bridge)
		assert style.resolved_font_size_px() == 13
		for text in ['10.333px', '12pt', 'auto'] {
			owned := parse_css_value(ParsingParams{}, text, .font_size) or {
				dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))
			}
			bridge.css_value_handle = owned.css_value_handle
			gc_collect()
			expected := if length := computed_interpolation_length_from_dom_style_value(owned) {
				length.absolute_length_to_px_without_rounding()
			} else { 16.0 }
			assert style.resolved_font_size_px() == expected
		}
	}
}
