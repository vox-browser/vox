module css

// Ladybird 80f89cee2ac8: a shorthand with one CSS-wide value still
// represents a keyword when it crosses the Typed OM boundary.
fn test_css_wide_shorthand_reifies_as_keyword() {
	for property in [PropertyID.margin, .margin_inline, .inset_block, .border_inline_width] {
		longhands := generated_expanded_longhands_for_shorthand(property)
		for keyword in [Keyword.initial, .inherit, .unset, .revert, .revert_layer] {
			mut values := []StyleValue{cap: longhands.len}
			for _ in longhands {
				values << StyleValue(KeywordStyleValue.create(keyword))
			}
			value := StyleValue(ShorthandStyleValue.create(property, longhands, values))
			reified := value.reify(string_from_property_id(property))
			assert reified.kind_ == .keyword
			assert (reified.keyword_value_ or { panic('missing CSSKeywordValue') }).value_ == string_from_keyword(keyword)
			assert reified.to_string()! == string_from_keyword(keyword)
		}
	}
}

fn test_css_wide_shorthand_round_trips_through_style_property_map() {
	for property in ['margin', 'margin-inline', 'inset-block', 'border-inline-width'] {
		for keyword in ['initial', 'inherit', 'unset', 'revert', 'revert-layer'] {
			mut declaration := CSSStyleProperties.create()
			mut style_map := MutableStylePropertyMap.create(declaration)
			style_map.set(property, [MutableStylePropertyMapValue(CSSStyleValue.from_keyword(
				CSSKeywordValue.create(keyword),
			))])!
			mut read_only := StylePropertyMapReadOnly.create_for_declaration(declaration)
			reified := read_only.get(property) or { panic('missing ${property}') }
			assert reified.kind_ == .keyword
			assert reified.to_string()! == keyword
			values := read_only.get_all(property)
			assert values.len == 1
			assert values[0].kind_ == .keyword
			assert values[0].to_string()! == keyword
		}
	}
}

fn test_non_css_wide_shorthand_stays_a_css_style_value() {
	for source in ['1px', '1px 2px', 'auto'] {
		reified := CSSStyleValue.parse('margin', source)!
		assert reified.kind_ == .style
		assert reified.to_string()! == source
	}
}
