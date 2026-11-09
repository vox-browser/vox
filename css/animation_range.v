// Attachment-range parsing and declaration serialization from
// https://drafts.csswg.org/scroll-animations-1/#animation-range.
module css

import dom

const animation_range_names = ['cover', 'contain', 'entry', 'exit', 'entry-crossing', 'exit-crossing']

fn animation_range_name(value StyleValue) ?string {
	if value is CustomIdentStyleValue { return value.custom_ident() }
	if value is StyleValueList && value.size() == 2 {
		return animation_range_name(value.value_at(0, false))
	}
	return none
}

fn (mut parser Parser) parse_animation_range_endpoint(mut tokens ComponentValueStream, start bool) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component := transaction.peek() {
		if component.is(.ident) {
			name := to_ascii_lowercase(component.token().ident())
			if name == 'normal' {
				transaction.consume()
				tokens = transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
			if name !in animation_range_names { return none }
			transaction.consume()
			mut with_offset := transaction.clone()
			if offset := parser.parse_length_percentage_value(mut with_offset) {
				transaction = with_offset
				tokens = transaction
				if offset is PercentageStyleValue && offset.percentage().value() == (if start { 0.0 } else { 100.0 }) {
					return StyleValue(CustomIdentStyleValue.create(name))
				}
				return StyleValue(StyleValueList.create([StyleValue(CustomIdentStyleValue.create(name)), offset], .space, .no))
			}
			tokens = transaction
			return StyleValue(CustomIdentStyleValue.create(name))
		}
	}
	value := parser.parse_length_percentage_value(mut transaction) or { return none }
	tokens = transaction
	return value
}

fn (mut parser Parser) parse_animation_range_value(property PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	components := transaction.consume_remaining_component_values()
	mut starts := []StyleValue{}
	mut ends := []StyleValue{}
	for entry in parse_a_comma_separated_list_of_component_values_for_value_logic(components) {
		mut stream := ComponentValueStream.new(entry)
		start := parser.parse_animation_range_endpoint(mut stream, property != .animation_range_end) or { return none }
		starts << start
		stream.consume_whitespace()
		if property == .animation_range {
			if stream.has_more_tokens() {
				ends << parser.parse_animation_range_endpoint(mut stream, false) or { return none }
			} else if name := animation_range_name(start) {
				ends << StyleValue(CustomIdentStyleValue.create(name))
			} else {
				ends << StyleValue(KeywordStyleValue.create(.normal))
			}
		}
		stream.consume_whitespace()
		if stream.has_more_tokens() { return none }
	}
	if starts.len == 0 { return none }
	tokens = transaction
	start_list := StyleValue(StyleValueList.create(starts, .comma, .yes))
	if property != .animation_range { return start_list }
	return StyleValue(ShorthandStyleValue.create(.animation_range, [.animation_range_start, .animation_range_end],
		[start_list, StyleValue(StyleValueList.create(ends, .comma, .yes))]))
}

fn (value ShorthandStyleValue) serialize_animation_range(mode SerializationMode) ?string {
	if value.shorthand_ != .animation_range { return none }
	start_value := value.coordinating_longhand_value(.animation_range_start) or { return '' }
	end_value := value.coordinating_longhand_value(.animation_range_end) or { return '' }
	if start_value !is StyleValueList || end_value !is StyleValueList {
		// CSS-wide shorthand keywords are stored without the list wrapper.
		start := start_value.serialize(mode)
		return if start == end_value.serialize(mode) { start } else { '' }
	}
	starts := start_value as StyleValueList
	ends := end_value as StyleValueList
	if starts.size() != ends.size() { return '' }
	mut entries := []string{}
	for index in 0 .. starts.size() {
		start := starts.value_at(index, false)
		end := ends.value_at(index, false)
		mut omit_end := false
		if name := animation_range_name(start) {
			omit_end = end is CustomIdentStyleValue && end.custom_ident() == name
		} else {
			omit_end = end.to_keyword() == .normal || (end is PercentageStyleValue && end.percentage().value() == 100)
		}
		entries << if omit_end { start.serialize(mode) } else { start.serialize(mode) + ' ' + end.serialize(mode) }
	}
	return entries.join(', ')
}

fn compute_animation_range_endpoint(value &dom.StyleValue, start bool) &dom.StyleValue {
	typed := typed_style_value_logic_from_dom(value) or { return unsafe { value } }
	if typed !is StyleValueList { return unsafe { value } }
	mut entries := []StyleValue{}
	for index in 0 .. typed.size() {
		entry := typed.value_at(index, false)
		if entry is StyleValueList && entry.size() == 2 {
			offset := entry.value_at(1, false)
			percentage := if offset is PercentageStyleValue { offset.percentage().value() }
				else if offset is CalculatedStyleValue { (offset.resolve_percentage(CalculationResolutionContext{}) or { Percentage{value_: -1} }).value() }
				else { -1.0 }
			if percentage == (if start { 0.0 } else { 100.0 }) {
				entries << entry.value_at(0, false)
				continue
			}
		}
		entries << entry
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(entries, .comma, .yes)))
}
