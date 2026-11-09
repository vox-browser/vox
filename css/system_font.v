module css

const system_font_keywords = ['caption', 'icon', 'menu', 'message-box', 'small-caption', 'status-bar']

// Use the platform's system-ui cascade, with the smaller caption variant. The
// parsed longhands remain ordinary typed font values for layout and animation.
fn (mut parser Parser) parse_system_font_value(name string) ?StyleValue {
	font := if name == 'small-caption' { '11px system-ui' } else { '13px system-ui' }
	mut tokens := ComponentValueStream.new(parse_component_values_for_value_logic(font))
	value := parser.parse_font_value(mut tokens) or { return none }
	if value is ShorthandStyleValue {
		return StyleValue(ShorthandStyleValue{ ...value, system_font_: name })
	}
	return none
}

fn system_font_name_for_declarations(declarations []StyleProperty) ?string {
	if declarations.len != cssom_expanded_longhands_for_shorthand(.font).len { return none }
	name := declarations[0].value.system_font
	if name == '' { return none }
	for declaration in declarations {
		if declaration.value.system_font != name || declaration.important != declarations[0].important { return none }
	}
	return name
}
