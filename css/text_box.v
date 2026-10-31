module css

// CSS Inline Layout 3, text-box-trim and text-box-edge. Horizontal Latin
// metrics are implemented by layout/text_box_trim.v; unsupported ideographic
// edge metrics are deliberately rejected until the font bridge exposes them.
pub enum TextBoxTrim as u8 {
	none_
	trim_start
	trim_end
	trim_both
}

pub enum TextBoxOverEdge as u8 {
	text
	cap
	ex
}

pub struct TextBoxEdge {
pub:
	over             TextBoxOverEdge = .text
	alphabetic_under bool
}

fn (mut parser Parser) parse_text_box_edge(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut parts := []string{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() { break }
		component := transaction.consume() or { return none }
		if !component.is(.ident) || parts.len == 2 { return none }
		parts << to_ascii_lowercase(component.token().ident())
	}
	if parts.len == 0 { return none }
	if parts[0] == 'auto' {
		if parts.len != 1 { return none }
	} else if parts[0] !in ['text', 'cap', 'ex']
		|| (parts.len == 2 && parts[1] !in ['text', 'alphabetic']) {
		return none
	}
	mut values := []StyleValue{}
	for part in parts {
		values << StyleValue(KeywordStyleValue.create(keyword_from_string(part) or { return none }))
	}
	tokens = transaction
	if values.len == 1 { return values[0] }
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

pub fn (style &ComputedProperties) text_box_trim() TextBoxTrim {
	value := style.property(.text_box_trim, .yes) or { return .none_ }
	return match value.css_text {
		'trim-start' { TextBoxTrim.trim_start }
		'trim-end' { TextBoxTrim.trim_end }
		'trim-both' { TextBoxTrim.trim_both }
		else { TextBoxTrim.none_ }
	}
}

pub fn (style &ComputedProperties) text_box_edge() TextBoxEdge {
	value := style.property(.text_box_edge, .yes) or { return TextBoxEdge{} }
	parts := value.css_text.split(' ')
	return TextBoxEdge{
		over:             match parts[0] {
			'cap' { TextBoxOverEdge.cap }
			'ex' { TextBoxOverEdge.ex }
			else { TextBoxOverEdge.text }
		}
		alphabetic_under: parts.len == 2 && parts[1] == 'alphabetic'
	}
}
