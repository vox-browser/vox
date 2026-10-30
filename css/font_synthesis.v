module css

import platform

const font_synthesis_longhands = [PropertyID.font_synthesis_weight, .font_synthesis_style,
	.font_synthesis_small_caps, .font_synthesis_position]
const font_synthesis_names = ['weight', 'style', 'small-caps', 'position']

fn (mut parser Parser) parse_font_synthesis(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut allowed := [false, false, false, false]
	mut count := 0
	mut none_seen := false
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() { break }
		component := transaction.consume() or { return none }
		if !component.is(.ident) { return none }
		name := to_ascii_lowercase(component.token().ident())
		if name == 'none' {
			if count != 0 { return none }
			none_seen = true
		} else {
			if none_seen { return none }
			index := font_synthesis_names.index(name)
			if index < 0 || allowed[index] { return none }
			allowed[index] = true
		}
		count++
	}
	if count == 0 { return none }
	mut values := []StyleValue{cap: 4}
	for value in allowed {
		values << StyleValue(KeywordStyleValue.create(if value { .auto } else { .none_ }))
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.font_synthesis, font_synthesis_longhands, values))
}

fn (value ShorthandStyleValue) serialize_font_synthesis(mode SerializationMode) ?string {
	if value.shorthand_ != .font_synthesis { return none }
	if value.values_.len != 4 || value.sub_properties_.len != 4 { return '' }
	serialized := value.values_.map(it.serialize(mode))
	if serialized.all(it == serialized[0]) && serialized[0] in ['inherit', 'initial', 'unset',
		'revert', 'revert-layer'] {
		return serialized[0]
	}
	mut parts := []string{}
	for index, property in font_synthesis_longhands {
		position := value.sub_properties_.index(property)
		if position < 0 || serialized[position] !in ['auto', 'none'] { return '' }
		if serialized[position] == 'auto' { parts << font_synthesis_names[index] }
	}
	return if parts.len == 0 { 'none' } else { parts.join(' ') }
}

fn (c &ComputedProperties) disabled_font_synthesis() u8 {
	mut disabled := u8(0)
	for index, property in font_synthesis_longhands {
		value := c.property(property, .yes) or { continue }
		keyword := keyword_from_string(value.css_text) or { continue }
		if keyword == .none_ {
			disabled |= u8(1 << index)
		} else if property == .font_synthesis_style && keyword == .oblique_only {
			style := c.property(.font_style, .yes) or { continue }
			parsed := style_value_logic_from_dom(.font_style, style) or { continue }
			if parsed is FontStyleStyleValue && parsed.font_style() == .italic {
				disabled |= platform.font_synthesis_style_disabled
			}
		}
	}
	return disabled
}
