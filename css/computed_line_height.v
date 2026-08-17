module css

import dom

// The approximation used for `line-height: normal` (the initial value). Real `normal` depends on the
// font's metrics; browsers land around 1.1–1.2× the font-size. FIXME: use real font metrics.
const normal_line_height_factor = 1.2

// Resolve the computed `line-height` of `element` to px (line-height is inherited, so the cascade
// already yields the effective specified value): `normal` -> ~1.2 * font-size; a unitless number ->
// number * font-size; a length -> px (em/rem against font-size); a percentage -> % * font-size.
pub fn computed_line_height_px(element &dom.Element, author_rules []&CSSRule) f64 {
	font_px := computed_font_size_px(element, author_rules)
	line_id := property_id_from_string('line-height') or {
		return font_px * normal_line_height_factor
	}
	specified := cascaded_value_with_ua(element, line_id, author_rules)
	if specified == 'normal' || specified == '' {
		return font_px * normal_line_height_factor
	}
	value := parse_css_value_logic(line_id, specified) or {
		return font_px * normal_line_height_factor
	}
	if value.is_number() {
		return value.as_number().number() * font_px
	}
	if value.is_percentage() {
		return font_px * value.as_percentage().percentage().value() / 100.0
	}
	if value.is_length() {
		length := value.as_length().length()
		if length.is_absolute() {
			return length.absolute_length_to_px().to_double()
		}
		raw := length.raw_value()
		unit := length.unit_name()
		if unit == 'em' {
			return raw * font_px
		}
		if unit == 'rem' {
			return raw * root_font_size_px(element, author_rules)
		}
		return font_px * normal_line_height_factor
	}
	return font_px * normal_line_height_factor
}
