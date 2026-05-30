module css

import dom
import math
import strconv

// This file is a local V translation layer for the LibWeb parser logic in:
// - Libraries/LibWeb/CSS/Parser/ValueParsing.cpp
// - Libraries/LibWeb/CSS/Parser/PropertyParsing.cpp
// - Libraries/LibWeb/CSS/Parser/DescriptorParsing.cpp
// - Libraries/LibWeb/CSS/Parser/MediaParsing.cpp
// - Libraries/LibWeb/CSS/Parser/GradientParsing.cpp
//
// The upstream C++ parser depends on generated property grammar tables and on
// style/layout types that are not fully present in this port yet. Those gaps are
// intentionally represented by explicit stubs in this file instead of spreading
// parser-specific assumptions through parser_core.v.

pub struct Parser {
pub mut:
	component_values []ComponentValue
	context          ParsingParams
}

pub fn Parser.from_component_values(component_values []ComponentValue) Parser {
	return Parser{
		component_values: component_values.clone()
	}
}

pub fn Parser.from_css_text(text string) Parser {
	return Parser.from_component_values(parse_component_values_for_value_logic(text))
}

pub fn Parser.with_context(context ParsingParams, text string) Parser {
	return Parser{
		component_values: parse_component_values_for_value_logic(text)
		context:          context
	}
}

pub struct ComponentValueStream {
mut:
	values []ComponentValue
	index  int
}

fn ComponentValueStream.new(values []ComponentValue) ComponentValueStream {
	return ComponentValueStream{
		values: values.clone()
	}
}

fn (stream ComponentValueStream) clone() ComponentValueStream {
	return ComponentValueStream{
		values: stream.values.clone()
		index:  stream.index
	}
}

fn (stream ComponentValueStream) is_empty() bool {
	return stream.index >= stream.values.len
}

fn (stream ComponentValueStream) remaining_count() int {
	return stream.values.len - stream.index
}

fn (stream ComponentValueStream) peek() ?ComponentValue {
	if stream.is_empty() {
		return none
	}
	return stream.values[stream.index]
}

fn (mut stream ComponentValueStream) consume() ?ComponentValue {
	value := stream.peek() or { return none }
	stream.index++
	return value
}

fn (mut stream ComponentValueStream) reconsume() {
	if stream.index > 0 {
		stream.index--
	}
}

fn (mut stream ComponentValueStream) consume_whitespace() {
	for value := stream.peek() or { return }; value.is(.whitespace); value = stream.peek() or {
		return
	} {
		stream.index++
	}
}

fn (mut stream ComponentValueStream) consume_a_comma() bool {
	stream.consume_whitespace()
	value := stream.peek() or { return false }
	if !value.is(.comma) {
		return false
	}
	stream.index++
	stream.consume_whitespace()
	return true
}

fn (stream ComponentValueStream) has_more_tokens() bool {
	mut copy := stream
	copy.consume_whitespace()
	return !copy.is_empty()
}

fn (stream ComponentValueStream) has_one_token() bool {
	mut copy := stream
	copy.consume_whitespace()
	if copy.consume() == none {
		return false
	}
	copy.consume_whitespace()
	return copy.is_empty()
}

fn parse_component_values_for_value_logic(text string) []ComponentValue {
	tokens := tokenize_css(text, 'utf-8')
	mut state := ValueLogicTokenIndex{}
	return consume_component_value_list_for_value_logic(tokens, mut state, .end_of_file)
}

struct ValueLogicTokenIndex {
mut:
	value int
}

fn consume_component_value_list_for_value_logic(tokens []Token, mut state ValueLogicTokenIndex, ending TokenType) []ComponentValue {
	mut values := []ComponentValue{}
	for state.value < tokens.len {
		token := tokens[state.value]
		if token.is(.end_of_file) || (ending != .end_of_file && token.is(ending)) {
			break
		}
		state.value++
		if token.is(.open_curly) || token.is(.open_square) || token.is(.open_paren) {
			end_type := token.mirror_variant()
			block_values := consume_component_value_list_for_value_logic(tokens, mut state,
				end_type)
			mut end_token := Token.create(end_type, '')
			if state.value < tokens.len && tokens[state.value].is(end_type) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_block(SimpleBlock{
				token:     token
				value:     block_values
				end_token: end_token
			})
			continue
		}
		if token.is(.function) {
			function_values := consume_component_value_list_for_value_logic(tokens, mut state,
				.close_paren)
			mut end_token := Token.create(.close_paren, '')
			if state.value < tokens.len && tokens[state.value].is(.close_paren) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_function(Function{
				name:       token.function_name()
				value:      function_values
				name_token: token
				end_token:  end_token
			})
			continue
		}
		values << ComponentValue.from_token(token)
	}
	return values
}

pub fn (mut parser Parser) parse_css_value_for_property(property_id PropertyID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_css_value_for_property_tokens(property_id, mut tokens)
}

pub fn (mut parser Parser) parse_css_value(property_id PropertyID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_css_value_tokens(property_id, mut tokens)
}

fn (mut parser Parser) parse_css_value_tokens(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	// CSS-wide keywords can be used as the entire value of any property.
	if value := parser.parse_css_wide_keyword_value(mut tokens) {
		if !tokens.has_more_tokens() {
			return value
		}
		return none
	}

	value := parser.parse_css_value_for_property_tokens(property_id, mut tokens) or { return none }
	tokens.consume_whitespace()
	if !tokens.is_empty() {
		return none
	}
	return value
}

fn (mut parser Parser) parse_css_value_for_property_tokens(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	// FIXME: This switch mirrors the translated C++ dispatch points that can be
	// represented with the currently translated PropertyID enum. The generated
	// property grammar tables are not available in this V port yet.
	return match property_id {
		.color {
			parser.parse_color_value(mut tokens)
		}
		.color_scheme {
			parser.parse_color_scheme_value(mut tokens)
		}
		.content_visibility {
			parser.parse_keyword_value(mut tokens)
		}
		.animation_timeline {
			parser.parse_builtin_value(mut tokens)
		}
	}
}

fn (mut parser Parser) parse_css_wide_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	token := tokens.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	keyword := keyword_from_string(token.token().ident()) or { return none }
	if !keyword.is_css_wide_keyword() {
		return none
	}
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_builtin_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_keyword_value(mut tokens) {
		return value
	}
	if value := parser.parse_number_percentage_value(mut tokens) {
		return value
	}
	if value := parser.parse_length_percentage_value(mut tokens) {
		return value
	}
	if value := parser.parse_color_value(mut tokens) {
		return value
	}
	if value := parser.parse_string_value(mut tokens) {
		return StyleValue(value)
	}
	if value := parser.parse_image_value(mut tokens) {
		return StyleValue(StubStyleValue.create(.image, value.serialize(.normal)))
	}
	return none
}

fn (mut parser Parser) parse_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	number := component_value.token().number()
	if !number.is_integer() {
		return none
	}
	return StyleValue(IntegerStyleValue.create(number.integer_value()))
}

fn (mut parser Parser) parse_number_value(mut tokens ComponentValueStream) ?StyleValue {
	number := parser.parse_number(mut tokens) or { return none }
	return if number.is_integer() {
		StyleValue(IntegerStyleValue.create(number.integer_value()))
	} else {
		StyleValue(NumberStyleValue.create(number.value()))
	}
}

fn (mut parser Parser) parse_number(mut tokens ComponentValueStream) ?Number {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	return component_value.token().number()
}

fn (mut parser Parser) parse_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	percentage := parser.parse_percentage(mut tokens) or { return none }
	return StyleValue(PercentageStyleValue.create(percentage))
}

fn (mut parser Parser) parse_percentage(mut tokens ComponentValueStream) ?Percentage {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.percentage) {
		return none
	}
	return Percentage.new(component_value.token().percentage())
}

fn (mut parser Parser) parse_number_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_number_value(mut copy) {
		tokens = copy
		return value
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_angle_value(mut tokens ComponentValueStream) ?StyleValue {
	angle := parser.parse_angle(mut tokens) or { return none }
	return StyleValue(AngleStyleValue.create(angle))
}

fn (mut parser Parser) parse_angle(mut tokens ComponentValueStream) ?Angle {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return Angle.make_degrees(0)
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_angle_unit(component_value.token().dimension_unit()) or { return none }
	return Angle.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_length_value(mut tokens ComponentValueStream) ?StyleValue {
	length := parser.parse_length(mut tokens) or { return none }
	return StyleValue(LengthStyleValue.create(length))
}

fn (mut parser Parser) parse_length(mut tokens ComponentValueStream) ?Length {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return Length.make_px(0)
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_length_unit(component_value.token().dimension_unit()) or { return none }
	return Length.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_length_value(mut copy) {
		tokens = copy
		return value
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_flex_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_flex_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(FlexStyleValue.create(Flex.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_frequency_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_frequency_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(FrequencyStyleValue.create(Frequency.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_resolution_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_resolution_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(ResolutionStyleValue.create(Resolution.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_time_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.number) && component_value.token().number_value() == 0 {
		return StyleValue(TimeStyleValue.create(Time.new(0, .s)))
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_time_unit(component_value.token().dimension_unit()) or { return none }
	return StyleValue(TimeStyleValue.create(Time.new(component_value.token().dimension_value(),
		unit)))
}

fn (mut parser Parser) parse_string_value(mut tokens ComponentValueStream) ?StringStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.string) {
		return none
	}
	return StringStyleValue.create(component_value.token().string_value())
}

fn (mut parser Parser) parse_color_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }

	if component_value.is(.hash) {
		color := parse_hash_color_for_value_logic(component_value.token().hash_value()) or {
			return none
		}
		return StyleValue(ColorStyleValue.create(color))
	}

	if component_value.is(.ident) {
		ident := component_value.token().ident()
		keyword := keyword_from_string(ident) or { return none }
		if KeywordStyleValue.is_color(keyword) {
			return StyleValue(KeywordStyleValue.create(keyword))
		}
		return none
	}

	if component_value.is_function_named('rgb') || component_value.is_function_named('rgba')
		|| component_value.is_function_named('hsl') || component_value.is_function_named('hsla')
		|| component_value.is_function_named('hwb') || component_value.is_function_named('lab')
		|| component_value.is_function_named('oklab') || component_value.is_function_named('lch')
		|| component_value.is_function_named('oklch') || component_value.is_function_named('color')
		|| component_value.is_function_named('color-mix')
		|| component_value.is_function_named('light-dark') {
		return StyleValue(StubStyleValue.create(.color, component_value.to_string()))
	}

	return none
}

fn parse_hash_color_for_value_logic(value string) ?Color {
	if value.len !in [3, 4, 6, 8] {
		return none
	}
	mut expanded := ''
	if value.len == 3 || value.len == 4 {
		for ch in value {
			expanded += '${rune(ch)}${rune(ch)}'
		}
	} else {
		expanded = value
	}
	r := strconv.parse_uint(expanded[0..2], 16, 8) or { return none }
	g := strconv.parse_uint(expanded[2..4], 16, 8) or { return none }
	b := strconv.parse_uint(expanded[4..6], 16, 8) or { return none }
	a := if expanded.len == 8 {
		strconv.parse_uint(expanded[6..8], 16, 8) or { return none }
	} else {
		u64(255)
	}
	return Color.rgba(u8(r), u8(g), u8(b), u8(a))
}

fn (mut parser Parser) parse_color_scheme_value(mut tokens ComponentValueStream) ?StyleValue {
	// Translated shape of parse_color_scheme_value(): accept normal, or an
	// optional "only" followed by one or more custom idents. The concrete
	// ColorSchemeStyleValue type exists outside StyleValue in this port, so keep
	// the parsed serialization in an explicit stub.
	tokens.consume_whitespace()
	first := tokens.consume() or { return none }
	if !first.is(.ident) {
		return none
	}
	if equals_ignoring_ascii_case(first.token().ident(), 'normal') {
		return StyleValue(KeywordStyleValue.create(Keyword.auto))
	}
	mut parts := []string{}
	if equals_ignoring_ascii_case(first.token().ident(), 'only') {
		parts << 'only'
	} else {
		parts << first.token().ident()
	}
	for tokens.has_more_tokens() {
		tokens.consume_whitespace()
		next := tokens.consume() or { break }
		if !next.is(.ident) {
			return none
		}
		parts << next.token().ident()
	}
	if parts.len == 1 && parts[0] == 'only' {
		return none
	}
	return StyleValue(StubStyleValue.create(.color_scheme, parts.join(' ')))
}

pub fn (mut parser Parser) parse_descriptor_value(at_rule_id AtRuleID, descriptor_id DescriptorID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_descriptor_value_tokens(at_rule_id, descriptor_id, mut tokens)
}

fn (mut parser Parser) parse_descriptor_value_tokens(at_rule_id AtRuleID, descriptor_id DescriptorID, mut tokens ComponentValueStream) ?StyleValue {
	mut maybe_value := ?StyleValue(none)
	match at_rule_id {
		.page {
			maybe_value = match descriptor_id {
				.margin {
					parser.parse_page_margin_shorthand_descriptor_value(mut tokens)
				}
				.margin_top, .margin_right, .margin_bottom, .margin_left {
					parser.parse_page_margin_longhand_descriptor_value(mut tokens)
				}
				.bleed {
					parser.parse_page_bleed_descriptor_value(mut tokens)
				}
				.size {
					parser.parse_page_size_descriptor_value(mut tokens)
				}
				.page_orientation {
					parser.parse_page_orientation_descriptor_value(mut tokens)
				}
				.marks {
					parser.parse_page_marks_descriptor_value(mut tokens)
				}
				.unknown {
					?StyleValue(none)
				}
			}
		}
		.font_face, .counter_style {
			maybe_value = parser.parse_builtin_value(mut tokens)
		}
	}

	value := maybe_value or { return none }
	if value.is_css_wide_keyword() || value.type_() == .unresolved {
		return none
	}

	tokens.consume_whitespace()
	if !tokens.is_empty() {
		return none
	}
	return value
}

fn descriptor_ident_style_value(value string) StyleValue {
	return StyleValue(StubStyleValue.create(.custom_ident, value))
}

fn descriptor_ident_list_style_value(values []string) StyleValue {
	mut style_values := []StyleValue{}
	for value in values {
		style_values << descriptor_ident_style_value(value)
	}
	return StyleValue(StyleValueList.create(style_values, .space, .yes))
}

fn consume_descriptor_ident(mut tokens ComponentValueStream) ?string {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	return component_value.token().ident().to_lower()
}

fn is_page_size_keyword(value string) bool {
	return value in ['a5', 'a4', 'a3', 'b5', 'b4', 'jis-b5', 'jis-b4', 'letter', 'legal', 'ledger']
}

fn is_page_size_orientation(value string) bool {
	return value == 'portrait' || value == 'landscape'
}

fn (mut parser Parser) parse_page_margin_component_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := parser.parse_length_percentage_value(mut copy) {
		tokens = copy
		return value
	}

	copy = tokens.clone()
	if value := consume_descriptor_ident(mut copy) {
		if value == 'auto' {
			tokens = copy
			return StyleValue(KeywordStyleValue.create(.auto))
		}
	}
	return none
}

fn (mut parser Parser) parse_page_margin_longhand_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_page_margin_component_value(mut tokens)
}

fn (mut parser Parser) parse_page_margin_shorthand_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut values := []StyleValue{}
	for values.len < 4 {
		mut copy := tokens.clone()
		value := parser.parse_page_margin_component_value(mut copy) or { break }
		values << value
		tokens = copy
		if !tokens.has_more_tokens() {
			break
		}
	}
	if values.len == 0 {
		return none
	}
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .no))
}

fn (mut parser Parser) parse_page_bleed_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if value := consume_descriptor_ident(mut copy) {
		if value == 'auto' {
			tokens = copy
			return StyleValue(KeywordStyleValue.create(.auto))
		}
	}
	return parser.parse_length_value(mut tokens)
}

fn (mut parser Parser) parse_page_marks_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	first := consume_descriptor_ident(mut tokens) or { return none }
	if first == 'none' {
		return descriptor_ident_style_value('none')
	}
	if first != 'crop' && first != 'cross' {
		return none
	}

	tokens.consume_whitespace()
	if !tokens.has_more_tokens() {
		return descriptor_ident_style_value(first)
	}

	second := consume_descriptor_ident(mut tokens) or { return none }
	if second != 'crop' && second != 'cross' {
		return none
	}
	if second == first {
		return none
	}

	return descriptor_ident_list_style_value(['crop', 'cross'])
}

fn (mut parser Parser) parse_page_orientation_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	value := consume_descriptor_ident(mut tokens) or { return none }
	if value !in ['upright', 'rotate-left', 'rotate-right'] {
		return none
	}
	return descriptor_ident_style_value(value)
}

fn (mut parser Parser) parse_page_size_descriptor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens.clone()
	if first_length := parser.parse_length_value(mut copy) {
		if first_length.is_length() && first_length.as_length().raw_value() < 0 {
			return none
		}

		copy.consume_whitespace()
		if second_length := parser.parse_length_value(mut copy) {
			if second_length.is_length() && second_length.as_length().raw_value() < 0 {
				return none
			}
			tokens = copy
			return StyleValue(StyleValueList.create([first_length, second_length], .space, .yes))
		}

		tokens = copy
		return first_length
	}

	first := consume_descriptor_ident(mut tokens) or { return none }
	if first == 'auto' {
		return StyleValue(KeywordStyleValue.create(.auto))
	}

	mut page_size := ''
	mut orientation := ''
	if is_page_size_orientation(first) {
		orientation = first
	} else if is_page_size_keyword(first) {
		page_size = first
	} else {
		return none
	}

	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		second := consume_descriptor_ident(mut tokens) or { return none }
		if orientation.len == 0 && is_page_size_orientation(second) {
			orientation = second
		} else if page_size.len == 0 && is_page_size_keyword(second) {
			page_size = second
		} else {
			return none
		}

		// Portrait is considered the default orientation, so don't include it.
		if orientation == 'portrait' {
			return descriptor_ident_style_value(page_size)
		}
		return descriptor_ident_list_style_value([page_size, orientation])
	}

	if page_size.len != 0 {
		return descriptor_ident_style_value(page_size)
	}
	return descriptor_ident_style_value(orientation)
}

pub fn parse_css_descriptor_value_logic(at_rule_id AtRuleID, descriptor_id DescriptorID, value string) ?StyleValue {
	mut parser := Parser.from_css_text(value)
	return parser.parse_descriptor_value(at_rule_id, descriptor_id)
}

pub fn parse_css_media_query_list_value_logic(text string) []&MediaQuery {
	mut parser := Parser.from_css_text(text)
	return parser.parse_as_media_query_list()
}

pub fn (mut parser Parser) parse_as_media_query_list() []&MediaQuery {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_a_media_query_list(mut tokens)
}

fn (mut parser Parser) parse_a_media_query_list(mut tokens ComponentValueStream) []&MediaQuery {
	// Parse a comma-separated media query list. Invalid entries become "not all",
	// matching the C++ parser's error recovery shape.
	mut queries := []&MediaQuery{}
	for {
		query := parser.parse_media_query_tokens(mut tokens) or {
			&MediaQuery{
				text:    'not all'
				matches: false
			}
		}
		queries << query
		if !tokens.consume_a_comma() {
			break
		}
	}
	return queries
}

fn (mut parser Parser) parse_media_query_tokens(mut tokens ComponentValueStream) ?&MediaQuery {
	tokens.consume_whitespace()
	mut parts := []string{}
	for tokens.has_more_tokens() {
		value := tokens.consume() or { break }
		if value.is(.comma) {
			tokens.reconsume()
			break
		}
		parts << value.to_string()
	}
	text := parts.join('').trim_space()
	if text.len == 0 {
		return none
	}
	return parse_media_query_from_text(text)
}

fn (mut parser Parser) parse_media_type(mut tokens ComponentValueStream) ?MediaQueryKnownMediaType {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	return media_type_from_string(component_value.token().ident())
}

fn (mut parser Parser) parse_media_feature_value(media_feature string, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_known_media_feature_value(media_feature, mut transaction) {
		transaction.consume_whitespace()

		// Only return the value if there are no trailing tokens.
		// Otherwise, the transaction gets reverted and we consume all the value tokens below.
		if !media_feature_stream_has_value_token(transaction) {
			tokens = transaction
			return value
		}
	}

	// Parsing failed somehow, so wrap all the tokens into an "unknown" MediaFeatureValue if possible.
	mut unknown_transaction := tokens.clone()
	unknown_transaction.consume_whitespace()
	mut unknown_tokens := []ComponentValue{}

	// Consume any tokens that could be part of a value.
	for unknown_transaction.has_more_tokens() {
		next := unknown_transaction.peek() or { break }
		if !is_media_feature_value_token(next) {
			break
		}
		unknown_tokens << unknown_transaction.consume() or { break }
	}

	if unknown_tokens.len != 0 {
		tokens = unknown_transaction
		return StyleValue(UnresolvedStyleValue.create(unknown_tokens))
	}

	return none
}

fn (mut parser Parser) parse_known_media_feature_value(media_feature string, mut tokens ComponentValueStream) ?StyleValue {
	feature_name := media_feature.to_lower()

	// One branch for each member of the MediaFeatureValueType enum:
	// Identifiers
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if token := transaction.peek() {
		if token.is(.ident) {
			ident := token.token().ident().to_lower()
			if media_feature_accepts_keyword_name(feature_name, ident) {
				transaction.consume()
				tokens = transaction
				if keyword := keyword_from_string(ident) {
					return StyleValue(KeywordStyleValue.create(keyword))
				}
				return StyleValue(CustomIdentStyleValue.create(ident))
			}
		}
	}

	// Boolean (<mq-boolean> in the spec: a 1 or 0)
	if media_feature_accepts_type_name(feature_name, .boolean) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_integer_value(mut transaction) {
			integer := value.as_integer().integer()
			if integer == 0 || integer == 1 {
				tokens = transaction
				return value
			}
		}
	}

	// Integer
	if media_feature_accepts_type_name(feature_name, .integer) {
		transaction = tokens.clone()
		if value := parser.parse_integer_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Length
	if media_feature_accepts_type_name(feature_name, .length) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_length_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Ratio
	if media_feature_accepts_type_name(feature_name, .ratio) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_ratio_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	// Resolution
	if media_feature_accepts_type_name(feature_name, .resolution) {
		transaction = tokens.clone()
		transaction.consume_whitespace()
		if value := parser.parse_resolution_value(mut transaction) {
			tokens = transaction
			return value
		}
	}

	return none
}

fn media_feature_stream_has_value_token(stream ComponentValueStream) bool {
	mut copy := stream
	copy.consume_whitespace()
	next := copy.peek() or { return false }
	return is_media_feature_value_token(next)
}

fn (mut parser Parser) parse_ratio_value(mut tokens ComponentValueStream) ?StyleValue {
	mut copy := tokens
	left := parser.parse_number(mut copy) or { return none }
	copy.consume_whitespace()
	if !copy.has_more_tokens() {
		tokens = copy
		return StyleValue(StubStyleValue.create(.ratio, left.serialize(.normal)))
	}
	solidus := copy.consume() or { return none }
	if !solidus.is_delim(u32(`/`)) {
		return none
	}
	right := parser.parse_number(mut copy) or { return none }
	if left.value() < 0 || right.value() < 0 {
		return none
	}
	tokens = copy
	return StyleValue(StubStyleValue.create(.ratio,
		'${left.serialize(.normal)} / ${right.serialize(.normal)}'))
}

fn (mut parser Parser) parse_image_value(mut tokens ComponentValueStream) ?CSSImageSourceStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.url) {
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(component_value.token().url()))
	}
	if component_value.is_function_named('url') {
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(component_value.function().value.map(it.to_string()).join('')))
	}
	if component_value.is_function_named('linear-gradient')
		|| component_value.is_function_named('repeating-linear-gradient')
		|| component_value.is_function_named('-webkit-linear-gradient')
		|| component_value.is_function_named('-webkit-repeating-linear-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_linear_gradient_function(component_value.function().name, mut
			inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('radial-gradient')
		|| component_value.is_function_named('repeating-radial-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_radial_gradient_function(component_value.function().name, mut
			inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('conic-gradient')
		|| component_value.is_function_named('repeating-conic-gradient') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_conic_gradient_function(component_value.function().name, mut inner) or {
			return none
		}
		return CSSImageSourceStyleValue(gradient)
	}
	return none
}

fn (mut parser Parser) parse_linear_gradient_function(function_name string, mut tokens ComponentValueStream) ?LinearGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	gradient_type := if function_name.starts_with('-webkit-') {
		LinearGradientType.webkit
	} else {
		LinearGradientType.standard
	}
	mut direction := LinearGradientDirection(LinearGradientSideOrCorner.bottom)

	mut probe := tokens
	probe.consume_whitespace()
	if first := probe.consume() {
		if first.is(.ident) && equals_ignoring_ascii_case(first.token().ident(), 'to') {
			side := parser.parse_linear_gradient_side_or_corner(mut probe) or { return none }
			direction = LinearGradientDirection(side)
			if !probe.consume_a_comma() {
				return none
			}
			tokens = probe
		} else if first.is(.dimension) {
			probe.reconsume()
			angle_value := parser.parse_angle_value(mut probe) or { return none }
			direction = LinearGradientDirection(angle_value)
			if !probe.consume_a_comma() {
				return none
			}
			tokens = probe
		}
	}

	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return LinearGradientStyleValue.create(direction, color_stops, gradient_type, repeating, none)
}

fn (mut parser Parser) parse_linear_gradient_side_or_corner(mut tokens ComponentValueStream) ?LinearGradientSideOrCorner {
	tokens.consume_whitespace()
	first := tokens.consume() or { return none }
	if !first.is(.ident) {
		return none
	}
	first_ident := first.token().ident().to_lower()
	mut second_ident := ''
	mut copy := tokens
	copy.consume_whitespace()
	if second := copy.consume() {
		if second.is(.ident) {
			second_ident = second.token().ident().to_lower()
			tokens = copy
		}
	}
	if second_ident.len == 0 {
		return match first_ident {
			'top' { LinearGradientSideOrCorner.top }
			'bottom' { LinearGradientSideOrCorner.bottom }
			'left' { LinearGradientSideOrCorner.left }
			'right' { LinearGradientSideOrCorner.right }
			else { none }
		}
	}
	return match '${first_ident} ${second_ident}' {
		'top left', 'left top' { LinearGradientSideOrCorner.top_left }
		'top right', 'right top' { LinearGradientSideOrCorner.top_right }
		'bottom left', 'left bottom' { LinearGradientSideOrCorner.bottom_left }
		'bottom right', 'right bottom' { LinearGradientSideOrCorner.bottom_right }
		else { none }
	}
}

fn (mut parser Parser) parse_linear_color_stop_list(mut tokens ComponentValueStream) ?[]ColorStopListElement {
	return parser.parse_color_stop_list(mut tokens, false)
}

fn (mut parser Parser) parse_angular_color_stop_list(mut tokens ComponentValueStream) ?[]ColorStopListElement {
	return parser.parse_color_stop_list(mut tokens, true)
}

fn (mut parser Parser) parse_color_stop_list(mut tokens ComponentValueStream, angular bool) ?[]ColorStopListElement {
	// <linear-color-stop>#{2,}. Transition hints are represented by a
	// ColorStopListElement with transition_hint populated, as in LibWeb.
	mut elements := []ColorStopListElement{}
	for {
		mut copy := tokens
		if hint := parser.parse_color_stop_position(mut copy, angular) {
			if copy.consume_a_comma() {
				elements << ColorStopListElement{
					transition_hint: hint
				}
				tokens = copy
				continue
			}
		}

		color := parser.parse_color_value(mut tokens) or { return none }
		position := parser.parse_color_stop_position(mut tokens, angular)
		second_position := parser.parse_color_stop_position(mut tokens, angular)
		elements << ColorStopListElement{
			color_stop: ColorStop{
				color:           color
				position:        position
				second_position: second_position
			}
		}
		if !tokens.consume_a_comma() {
			break
		}
	}
	if elements.len < 2 {
		return none
	}
	return elements
}

fn (mut parser Parser) parse_color_stop_position(mut tokens ComponentValueStream, angular bool) ?StyleValue {
	mut copy := tokens.clone()
	if angular {
		if value := parser.parse_angle_value(mut copy) {
			tokens = copy
			return value
		}
	} else {
		if value := parser.parse_length_percentage_value(mut copy) {
			tokens = copy
			return value
		}
	}
	copy = tokens.clone()
	if value := parser.parse_percentage_value(mut copy) {
		tokens = copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_radial_gradient_function(function_name string, mut tokens ComponentValueStream) ?RadialGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return RadialGradientStyleValue.create(.ellipse, StyleValue(KeywordStyleValue.create(.auto)),
		PositionStyleValue.create_center(), color_stops, repeating, none)
}

fn (mut parser Parser) parse_conic_gradient_function(function_name string, mut tokens ComponentValueStream) ?ConicGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	color_stops := parser.parse_angular_color_stop_list(mut tokens) or { return none }
	return ConicGradientStyleValue.create(none, PositionStyleValue.create_center(), color_stops,
		repeating, none)
}

pub fn parse_css_value_logic(property_id PropertyID, text string) ?StyleValue {
	mut parser := Parser.from_css_text(text)
	return parser.parse_css_value(property_id)
}

pub fn parse_css_image_value_logic(text string) ?CSSImageSourceStyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_image_value(mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

pub fn parse_css_media_feature_value_logic(media_feature string, text string) ?StyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_media_feature_value(media_feature, mut tokens) or { return none }
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn value_logic_round_to_u8(value f64) u8 {
	return u8(int(math.max(0.0, math.min(255.0, math.round(value)))))
}

fn dom_style_value_from_value_logic(value StyleValue) &dom.StyleValue {
	_ = value
	return &dom.StyleValue{}
}
