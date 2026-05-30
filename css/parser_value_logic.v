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
	if value := parser.parse_easing_value(mut tokens) {
		return value
	}
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
		return style_value_from_css_image_source_for_value_logic(value)
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
	return StyleValue(NumberStyleValue.create(number.value()))
}

fn (mut parser Parser) parse_number(mut tokens ComponentValueStream) ?Number {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	return component_value.token().number()
}

fn (mut parser Parser) parse_easing_number_value(mut tokens ComponentValueStream) ?StyleValue {
	number := parser.parse_number(mut tokens) or { return none }
	return StyleValue(NumberStyleValue.create(number.value()))
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

fn (mut parser Parser) parse_number_percentage_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<percentage> | <number> | none] (which is equivalent to [<alpha-value> | none])
	if value := parser.parse_number_value(mut tokens) {
		return value
	}
	if value := parser.parse_percentage_value(mut tokens) {
		return value
	}
	tokens.consume_whitespace()
	if value := tokens.peek() {
		if value.is(.ident) && equals_ignoring_ascii_case(value.token().ident(), 'none') {
			tokens.consume()
			return StyleValue(KeywordStyleValue.create(.none_))
		}
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

fn parse_a_comma_separated_list_of_component_values_for_value_logic(values []ComponentValue) [][]ComponentValue {
	mut lists := [][]ComponentValue{}
	mut current := []ComponentValue{}
	for value in values {
		if value.is(.comma) {
			lists << current
			current = []ComponentValue{}
			continue
		}
		current << value
	}
	lists << current
	return lists
}

fn remove_whitespace_from_component_values(values []ComponentValue) []ComponentValue {
	mut result := []ComponentValue{}
	for value in values {
		if value.is(.whitespace) {
			continue
		}
		result << value
	}
	return result
}

fn keyword_to_step_position_for_value_logic(name string) ?StepPosition {
	return match to_ascii_lowercase(name) {
		'jump-start' { StepPosition.jump_start }
		'jump-end' { StepPosition.jump_end }
		'jump-none' { StepPosition.jump_none }
		'jump-both' { StepPosition.jump_both }
		'start' { StepPosition.start }
		'end' { StepPosition.end }
		else { none }
	}
}

fn easing_integer_from_style_value(value StyleValue) ?i64 {
	return match value {
		IntegerStyleValue { value.integer() }
		else { none }
	}
}

fn easing_number_from_style_value(value StyleValue) ?f64 {
	return match value {
		NumberStyleValue { value.number() }
		else { none }
	}
}

fn style_value_resolves_to_percentage_for_value_logic(value StyleValue) bool {
	return value.is_percentage()
		|| (value.is_calculated() && value.as_calculated().resolves_to_percentage())
}

fn color_function_rectangular_color_space_from_string(value string) ?RectangularColorSpace {
	return match to_ascii_lowercase(value) {
		'srgb' { RectangularColorSpace.srgb }
		'srgb-linear' { RectangularColorSpace.srgb_linear }
		'display-p3' { RectangularColorSpace.display_p3 }
		'a98-rgb' { RectangularColorSpace.a98_rgb }
		'prophoto-rgb' { RectangularColorSpace.prophoto_rgb }
		'rec2020' { RectangularColorSpace.rec2020 }
		'lab' { RectangularColorSpace.lab }
		'oklab' { RectangularColorSpace.oklab }
		'xyz' { RectangularColorSpace.xyz_d65 }
		'xyz-d50' { RectangularColorSpace.xyz_d50 }
		'xyz-d65' { RectangularColorSpace.xyz_d65 }
		else { none }
	}
}

fn color_function_polar_color_space_from_string(value string) ?PolarColorSpace {
	return match to_ascii_lowercase(value) {
		'hsl' { PolarColorSpace.hsl }
		'hwb' { PolarColorSpace.hwb }
		'lch' { PolarColorSpace.lch }
		'oklch' { PolarColorSpace.oklch }
		else { none }
	}
}

fn color_function_hue_interpolation_method_from_string(value string) ?HueInterpolationMethod {
	return match to_ascii_lowercase(value) {
		'shorter' { HueInterpolationMethod.shorter }
		'longer' { HueInterpolationMethod.longer }
		'increasing' { HueInterpolationMethod.increasing }
		'decreasing' { HueInterpolationMethod.decreasing }
		else { none }
	}
}

fn color_function_supported_color_space(value string) bool {
	return to_ascii_lowercase(value) in ['srgb', 'srgb-linear', 'display-p3', 'a98-rgb',
		'prophoto-rgb', 'rec2020', 'xyz', 'xyz-d50', 'xyz-d65']
}

struct ParsedColorComponents {
	first  StyleValue
	second StyleValue
	third  StyleValue
	alpha  StyleValue
}

fn (mut parser Parser) parse_easing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()

	transaction.consume_whitespace()

	part := transaction.consume() or { return none }

	if part.is(.ident) {
		name := part.token().ident()
		maybe_simple_easing := if equals_ignoring_ascii_case(name, 'step-start') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position:            .start
			})))
		} else if equals_ignoring_ascii_case(name, 'step-end') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position:            .end
			})))
		} else {
			?EasingStyleValue(none)
		}

		easing := maybe_simple_easing or { return none }

		tokens = transaction
		return StyleValue(easing)
	}

	if !part.is_function() {
		return none
	}

	mut comma_separated_arguments :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	// Remove whitespace
	for i in 0 .. comma_separated_arguments.len {
		comma_separated_arguments[i] =
			remove_whitespace_from_component_values(comma_separated_arguments[i])
	}

	name := part.function().name

	if equals_ignoring_ascii_case(name, 'linear') {
		// linear() = linear( [ <number> && <percentage>{0,2} ]# )
		mut stops := []EasingLinearStop{}
		for argument in comma_separated_arguments {
			mut argument_tokens := ComponentValueStream.new(argument)

			mut output := ?StyleValue(none)
			mut first_input := ?StyleValue(none)
			mut second_input := ?StyleValue(none)

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				output = maybe_output
			}

			if maybe_first_input := parser.parse_percentage_value(mut argument_tokens) {
				first_input = maybe_first_input
				if maybe_second_input := parser.parse_percentage_value(mut argument_tokens) {
					second_input = maybe_second_input
				}
			}

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				if _ := output {
					return none
				}
				output = maybe_output
			}

			resolved_output := output or { return none }
			if argument_tokens.has_more_tokens() {
				return none
			}

			stops << EasingLinearStop{
				output: resolved_output
				input:  first_input
			}
			if resolved_second_input := second_input {
				stops << EasingLinearStop{
					output: resolved_output
					input:  resolved_second_input
				}
			}
		}

		if stops.len == 0 {
			return none
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingLinear{
			stops: stops
		})))
	}

	if equals_ignoring_ascii_case(name, 'cubic-bezier') {
		if comma_separated_arguments.len != 4 {
			return none
		}

		for argument in comma_separated_arguments {
			if argument.len != 1 {
				return none
			}
		}

		mut argument_tokens_0 := ComponentValueStream.new(comma_separated_arguments[0])
		mut argument_tokens_1 := ComponentValueStream.new(comma_separated_arguments[1])
		mut argument_tokens_2 := ComponentValueStream.new(comma_separated_arguments[2])
		mut argument_tokens_3 := ComponentValueStream.new(comma_separated_arguments[3])
		x1 := parser.parse_easing_number_value(mut argument_tokens_0) or { return none }
		y1 := parser.parse_easing_number_value(mut argument_tokens_1) or { return none }
		x2 := parser.parse_easing_number_value(mut argument_tokens_2) or { return none }
		y2 := parser.parse_easing_number_value(mut argument_tokens_3) or { return none }
		x1_number := easing_number_from_style_value(x1) or { return none }
		x2_number := easing_number_from_style_value(x2) or { return none }
		if x1_number < 0.0 || x1_number > 1.0 {
			return none
		}
		if x2_number < 0.0 || x2_number > 1.0 {
			return none
		}

		bezier := EasingCubicBezier{
			x1: x1
			y1: y1
			x2: x2
			y2: y2
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(bezier)))
	}

	if equals_ignoring_ascii_case(name, 'steps') {
		if comma_separated_arguments.len == 0 || comma_separated_arguments.len > 2 {
			return none
		}

		for argument in comma_separated_arguments {
			if argument.len != 1 {
				return none
			}
		}

		mut position := StepPosition.end

		if comma_separated_arguments.len == 2 {
			if comma_separated_arguments[1].len != 1 {
				return none
			}

			token := comma_separated_arguments[1][0]

			if !token.is(.ident) {
				return none
			}

			step_position := keyword_to_step_position_for_value_logic(token.token().ident()) or {
				return none
			}

			position = step_position
		}

		intervals_argument := comma_separated_arguments[0][0]
		mut intervals_token := ComponentValueStream.new([intervals_argument])
		intervals := parser.parse_integer_value(mut intervals_token) or { return none }

		// Perform extra validation
		// https://drafts.csswg.org/css-easing/#step-easing-functions
		// If the <step-position> is jump-none, the <integer> must be at least 2, or the function is invalid.
		// Otherwise, the <integer> must be at least 1, or the function is invalid.
		if integer := easing_integer_from_style_value(intervals) {
			if position == .jump_none {
				if integer <= 1 {
					return none
				}
			} else if integer <= 0 {
				return none
			}
		}

		tokens = transaction
		return StyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
			number_of_intervals: intervals
			position:            position
		})))
	}

	return none
}

fn (mut parser Parser) parse_hue_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<hue> | none]
	//   <hue> = <number> | <angle>
	if angle := parser.parse_angle_value(mut tokens) {
		return angle
	}
	if number := parser.parse_number_value(mut tokens) {
		return number
	}
	tokens.consume_whitespace()
	if value := tokens.peek() {
		if value.is(.ident) && equals_ignoring_ascii_case(value.token().ident(), 'none') {
			tokens.consume()
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}
	return none
}

fn (mut parser Parser) parse_solidus_and_alpha_value(mut tokens ComponentValueStream) ?StyleValue {
	// [ / [<alpha-value> | none] ]?
	// <alpha-value> = <number> | <percentage>
	// Common to the modern-syntax color functions.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	solidus := transaction.consume() or { return none }
	if !solidus.is_delim(u32(`/`)) {
		return none
	}
	transaction.consume_whitespace()
	alpha := parser.parse_number_percentage_none_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	tokens = transaction
	return alpha
}

fn (mut parser Parser) parse_rgb_color_value(component_value ComponentValue) ?StyleValue {
	// rgb() = [ <legacy-rgb-syntax> | <modern-rgb-syntax> ]
	// rgba() = [ <legacy-rgba-syntax> | <modern-rgba-syntax> ]
	// <legacy-rgb-syntax> = rgb( <percentage>#{3} , <alpha-value>? ) |
	//                       rgb( <number>#{3} , <alpha-value>? )
	// <legacy-rgba-syntax> = rgba( <percentage>#{3} , <alpha-value>? ) |
	//                        rgba( <number>#{3} , <alpha-value>? )
	// <modern-rgb-syntax> = rgb(
	//     [ <number> | <percentage> | none]{3}
	//     [ / [<alpha-value> | none] ]?  )
	// <modern-rgba-syntax> = rgba(
	//     [ <number> | <percentage> | none]{3}
	//     [ / [<alpha-value> | none] ]?  )
	if !component_value.is_function_named('rgb') && !component_value.is_function_named('rgba') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	red := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }

	inner_tokens.consume_whitespace()
	legacy_syntax := if next := inner_tokens.peek() {
		next.is(.comma)
	} else {
		false
	}

	mut green := ?StyleValue(none)
	mut blue := ?StyleValue(none)
	mut alpha := ?StyleValue(none)

	if legacy_syntax {
		// Legacy syntax
		//   <percentage>#{3} , <alpha-value>?
		//   | <number>#{3} , <alpha-value>?
		// So, r/g/b can be numbers or percentages, as long as they're all the same type.
		//
		// We accepted the 'none' keyword when parsing the red value, but it's not allowed in the legacy syntax.
		if red.is_keyword() {
			return none
		}

		inner_tokens.consume()
		inner_tokens.consume_whitespace()
		green = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		comma := inner_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
		inner_tokens.consume_whitespace()
		blue = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha_comma := inner_tokens.consume() or { return none }
			if !alpha_comma.is(.comma) {
				return none
			}
			inner_tokens.consume_whitespace()
			alpha = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
			inner_tokens.consume_whitespace()
			if inner_tokens.has_more_tokens() {
				return none
			}
		}

		// Verify we're all percentages or all numbers.
		green_value := green or { return none }
		blue_value := blue or { return none }
		red_is_percentage := style_value_resolves_to_percentage_for_value_logic(red)
		green_is_percentage := style_value_resolves_to_percentage_for_value_logic(green_value)
		blue_is_percentage := style_value_resolves_to_percentage_for_value_logic(blue_value)
		if red_is_percentage != green_is_percentage || red_is_percentage != blue_is_percentage {
			return none
		}
	} else {
		// Modern syntax
		//   [ <number> | <percentage> | none]{3}  [ / [<alpha-value> | none] ]?
		green = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()
		blue = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	}

	return StyleValue(RGBColorStyleValue.create(red, green or { return none }, blue or {
		return none
	}, alpha or { StyleValue(NumberStyleValue.create(1)) }, if legacy_syntax {
		.legacy
	} else {
		.modern
	}, none))
}

fn (mut parser Parser) parse_hsl_color_value(component_value ComponentValue) ?StyleValue {
	// hsl() = [ <legacy-hsl-syntax> | <modern-hsl-syntax> ]
	// hsla() = [ <legacy-hsla-syntax> | <modern-hsla-syntax> ]
	if !component_value.is_function_named('hsl') && !component_value.is_function_named('hsla') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	hue := parser.parse_hue_none_value(mut inner_tokens) or { return none }

	inner_tokens.consume_whitespace()
	legacy_syntax := if next := inner_tokens.peek() {
		next.is(.comma)
	} else {
		false
	}

	mut saturation := ?StyleValue(none)
	mut lightness := ?StyleValue(none)
	mut alpha := ?StyleValue(none)

	if legacy_syntax {
		// Legacy syntax
		//   <hue>, <percentage>, <percentage>, <alpha-value>?
		//
		// We accepted the 'none' keyword when parsing the h value, but it's not allowed in the legacy syntax.
		if hue.is_keyword() {
			return none
		}

		inner_tokens.consume()
		inner_tokens.consume_whitespace()
		saturation = parser.parse_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		comma := inner_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
		inner_tokens.consume_whitespace()
		lightness = parser.parse_percentage_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha_comma := inner_tokens.consume() or { return none }
			if !alpha_comma.is(.comma) {
				return none
			}
			inner_tokens.consume_whitespace()
			alpha = parser.parse_number_percentage_value(mut inner_tokens) or { return none }
			inner_tokens.consume_whitespace()
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	} else {
		// Modern syntax
		//   [<hue> | none]
		//   [<percentage> | <number> | none]
		//   [<percentage> | <number> | none]
		//   [ / [<alpha-value> | none] ]?
		saturation = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()
		lightness = parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
		inner_tokens.consume_whitespace()

		if inner_tokens.has_more_tokens() {
			alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
			if inner_tokens.has_more_tokens() {
				return none
			}
		}
	}

	return StyleValue(HSLColorStyleValue.create(hue, saturation or { return none }, lightness or {
		return none
	}, alpha or { StyleValue(NumberStyleValue.create(1)) }, if legacy_syntax {
		.legacy
	} else {
		.modern
	}))
}

fn (mut parser Parser) parse_hwb_color_value(component_value ComponentValue) ?StyleValue {
	// hwb() = hwb(
	//     [<hue> | none]
	//     [<percentage> | <number> | none]
	//     [<percentage> | <number> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named('hwb') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	hue := parser.parse_hue_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	whiteness := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	blackness := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return StyleValue(HWBColorStyleValue.create(hue, whiteness, blackness, alpha or {
		StyleValue(NumberStyleValue.create(1))
	}, .modern))
}

fn (mut parser Parser) parse_lab_like_color_value(component_value ComponentValue, function_name string) ?ParsedColorComponents {
	// This helper is designed to be compatible with lab and oklab and parses a function with a form like:
	// f() = f( [ <percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named(function_name) {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	first := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	second := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	third := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return ParsedColorComponents{
		first:  first
		second: second
		third:  third
		alpha:  alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

fn (mut parser Parser) parse_lch_like_color_value(component_value ComponentValue, function_name string) ?ParsedColorComponents {
	// This helper is designed to be compatible with lch and oklch and parses a function with a form like:
	// f() = f( [<percentage> | <number> | none]
	//     [ <percentage> | <number> | none]
	//     [ <hue> | none]
	//     [ / [<alpha-value> | none] ]? )
	if !component_value.is_function_named(function_name) {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	first := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	second := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	third := parser.parse_hue_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return ParsedColorComponents{
		first:  first
		second: second
		third:  third
		alpha:  alpha or { StyleValue(NumberStyleValue.create(1)) }
	}
}

fn (mut parser Parser) parse_color_function(component_value ComponentValue) ?StyleValue {
	// color() = color( <colorspace-params> [ / [ <alpha-value> | none ] ]? )
	//     <colorspace-params> = [ <predefined-rgb-params> | <xyz-params>]
	//     <predefined-rgb-params> = <predefined-rgb> [ <number> | <percentage> | none ]{3}
	//     <predefined-rgb> = srgb | srgb-linear | display-p3 | a98-rgb | prophoto-rgb | rec2020
	//     <xyz-params> = <xyz-space> [ <number> | <percentage> | none ]{3}
	//     <xyz-space> = xyz | xyz-d50 | xyz-d65
	if !component_value.is_function_named('color') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	maybe_color_space := inner_tokens.consume() or { return none }
	if !maybe_color_space.is(.ident) {
		return none
	}
	color_space := to_ascii_lowercase(maybe_color_space.token().ident())
	if !color_function_supported_color_space(color_space) {
		return none
	}

	inner_tokens.consume_whitespace()
	c1 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	c2 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	c3 := parser.parse_number_percentage_none_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()

	mut alpha := ?StyleValue(none)
	if inner_tokens.has_more_tokens() {
		alpha = parser.parse_solidus_and_alpha_value(mut inner_tokens) or { return none }
		if inner_tokens.has_more_tokens() {
			return none
		}
	}

	return StyleValue(ColorFunctionStyleValue.create(color_space, c1, c2, c3, alpha or {
		StyleValue(NumberStyleValue.create(1))
	}))
}

fn (mut parser Parser) parse_color_interpolation_method_value(mut tokens ComponentValueStream) ?ColorInterpolationMethodStyleValue {
	// <rectangular-color-space> = srgb | srgb-linear | display-p3 | display-p3-linear | a98-rgb | prophoto-rgb | rec2020 | lab | oklab | <xyz-space>
	// <polar-color-space> = hsl | hwb | lch | oklch
	// <custom-color-space> = <dashed-ident>
	// <hue-interpolation-method> = [ shorter | longer | increasing | decreasing ] hue
	// <color-interpolation-method> = in [ <rectangular-color-space> | <polar-color-space> <hue-interpolation-method>? | <custom-color-space> ]
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	in_token := transaction.consume() or { return none }
	if !in_token.is(.ident) || !equals_ignoring_ascii_case(in_token.token().ident(), 'in') {
		return none
	}

	transaction.consume_whitespace()
	color_space_token := transaction.consume() or { return none }
	if !color_space_token.is(.ident) {
		return none
	}
	color_space_name := color_space_token.token().ident()

	if rectangular_color_space := color_function_rectangular_color_space_from_string(color_space_name) {
		tokens = transaction
		return ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(rectangular_color_space))
	}

	if polar_color_space := color_function_polar_color_space_from_string(color_space_name) {
		mut hue_interpolation_method := HueInterpolationMethod.shorter
		transaction.consume_whitespace()
		if maybe_hue_method_token := transaction.peek() {
			if maybe_hue_method_token.is(.ident) {
				if maybe_hue_method := color_function_hue_interpolation_method_from_string(maybe_hue_method_token.token().ident()) {
					transaction.consume()
					hue_interpolation_method = maybe_hue_method
					transaction.consume_whitespace()
					hue_token := transaction.consume() or { return none }
					if !hue_token.is(.ident)
						|| !equals_ignoring_ascii_case(hue_token.token().ident(), 'hue') {
						return none
					}
				}
			}
		}

		tokens = transaction
		return ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(PolarColorInterpolationMethod{
			color_space:              polar_color_space
			hue_interpolation_method: hue_interpolation_method
		}))
	}

	// TODO: Support <custom-color-space> once we support @color-profile rules.
	return none
}

fn (mut parser Parser) parse_color_mix_component(mut tokens ComponentValueStream) ?ColorMixComponent {
	tokens.consume_whitespace()
	mut percentage_style_value := ?StyleValue(none)
	if percentage := parser.parse_percentage_value(mut tokens) {
		percentage_style_value = percentage
	}
	tokens.consume_whitespace()

	color_style_value := parser.parse_color_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if percentage_style_value == none {
		if percentage := parser.parse_percentage_value(mut tokens) {
			percentage_style_value = percentage
			tokens.consume_whitespace()
		}
	}

	mut percentage_or_calculated := ?PercentageOrCalculated(none)
	if percentage_value := percentage_style_value {
		if !percentage_value.is_calculated() {
			percentage := percentage_value.as_percentage().percentage().value()
			if percentage < 0 || percentage > 100 {
				return none
			}
			percentage_or_calculated =
				PercentageOrCalculated.from_percentage(percentage_value.as_percentage().percentage())
		} else {
			percentage_or_calculated =
				PercentageOrCalculated.from_calculated(percentage_value.as_calculated())
		}
	}

	return ColorMixComponent{
		color:      color_style_value
		percentage: percentage_or_calculated
	}
}

fn (mut parser Parser) parse_color_mix_function(component_value ComponentValue) ?StyleValue {
	// color-mix() = color-mix( <color-interpolation-method>? , [ <color> && <percentage [0,100]>? ]#)
	// FIXME: Update color-mix to accept 1+ colors instead of exactly 2.
	if !component_value.is_function_named('color-mix') {
		return none
	}

	mut function_tokens := ComponentValueStream.new(component_value.function().value)
	mut color_interpolation_method := ?ColorInterpolationMethodStyleValue(none)
	if method := parser.parse_color_interpolation_method_value(mut function_tokens) {
		color_interpolation_method = method
		function_tokens.consume_whitespace()
		comma := function_tokens.consume() or { return none }
		if !comma.is(.comma) {
			return none
		}
	}

	first_component := parser.parse_color_mix_component(mut function_tokens) or { return none }
	function_tokens.consume_whitespace()
	comma := function_tokens.consume() or { return none }
	if !comma.is(.comma) {
		return none
	}
	second_component := parser.parse_color_mix_component(mut function_tokens) or { return none }

	if first_percentage := first_component.percentage {
		if second_percentage := second_component.percentage {
			if !first_percentage.is_calculated() && !second_percentage.is_calculated()
				&& first_percentage.value().value() == 0 && second_percentage.value().value() == 0 {
				return none
			}
		}
	}

	function_tokens.consume_whitespace()
	if function_tokens.has_more_tokens() {
		return none
	}

	return StyleValue(ColorMixStyleValue.create(color_interpolation_method, first_component,
		second_component))
}

fn (mut parser Parser) parse_light_dark_color_value(component_value ComponentValue) ?StyleValue {
	if !component_value.is_function_named('light-dark') {
		return none
	}

	mut inner_tokens := ComponentValueStream.new(component_value.function().value)
	inner_tokens.consume_whitespace()
	light := parser.parse_color_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	comma := inner_tokens.consume() or { return none }
	if !comma.is(.comma) {
		return none
	}
	inner_tokens.consume_whitespace()
	dark := parser.parse_color_value(mut inner_tokens) or { return none }
	inner_tokens.consume_whitespace()
	if inner_tokens.has_more_tokens() {
		return none
	}
	return StyleValue(LightDarkStyleValue.create(light, dark))
}

fn (mut parser Parser) parse_color_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }

	// Keywords: <system-color> | <deprecated-color> | currentColor
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if keyword := keyword_from_string(ident) {
			if KeywordStyleValue.is_color(keyword) {
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
		if color := named_css_color_for_value_logic(ident) {
			return StyleValue(ColorStyleValue.create_from_color(color, .legacy, ident))
		}
		return none
	}

	// Functions
	if color := parser.parse_color_function(component_value) {
		return color
	}
	if color := parser.parse_color_mix_function(component_value) {
		return color
	}
	if rgb := parser.parse_rgb_color_value(component_value) {
		return rgb
	}
	if hsl := parser.parse_hsl_color_value(component_value) {
		return hsl
	}
	if hwb := parser.parse_hwb_color_value(component_value) {
		return hwb
	}
	if lab_values := parser.parse_lab_like_color_value(component_value, 'lab') {
		return StyleValue(LabColorStyleValue.create(lab_values.first, lab_values.second,
			lab_values.third, lab_values.alpha))
	}
	if lch_values := parser.parse_lch_like_color_value(component_value, 'lch') {
		return StyleValue(LCHColorStyleValue.create(lch_values.first, lch_values.second,
			lch_values.third, lch_values.alpha))
	}
	if oklab_values := parser.parse_lab_like_color_value(component_value, 'oklab') {
		return StyleValue(OKLabColorStyleValue.create(oklab_values.first, oklab_values.second,
			oklab_values.third, oklab_values.alpha))
	}
	if oklch_values := parser.parse_lch_like_color_value(component_value, 'oklch') {
		return StyleValue(OKLCHColorStyleValue.create(oklch_values.first, oklch_values.second,
			oklch_values.third, oklch_values.alpha))
	}
	if light_dark := parser.parse_light_dark_color_value(component_value) {
		return light_dark
	}

	if component_value.is(.hash) {
		color := parse_hash_color_for_value_logic(component_value.token().hash_value()) or {
			return none
		}
		return StyleValue(ColorStyleValue.create_from_color(color, .legacy, none))
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

fn color_from_rgb_hex_for_value_logic(value int) Color {
	return Color.rgb(u8((value >> 16) & 0xff), u8((value >> 8) & 0xff), u8(value & 0xff))
}

fn named_css_color_for_value_logic(value string) ?Color {
	if equals_ignoring_ascii_case(value, 'transparent') {
		return Color.rgba(0, 0, 0, 0)
	}

	return match to_ascii_lowercase(value) {
		// CSS Level 1
		'black' { color_from_rgb_hex_for_value_logic(0x000000) }
		'silver' { color_from_rgb_hex_for_value_logic(0xc0c0c0) }
		'gray' { color_from_rgb_hex_for_value_logic(0x808080) }
		'white' { color_from_rgb_hex_for_value_logic(0xffffff) }
		'maroon' { color_from_rgb_hex_for_value_logic(0x800000) }
		'red' { color_from_rgb_hex_for_value_logic(0xff0000) }
		'purple' { color_from_rgb_hex_for_value_logic(0x800080) }
		'fuchsia' { color_from_rgb_hex_for_value_logic(0xff00ff) }
		'green' { color_from_rgb_hex_for_value_logic(0x008000) }
		'lime' { color_from_rgb_hex_for_value_logic(0x00ff00) }
		'olive' { color_from_rgb_hex_for_value_logic(0x808000) }
		'yellow' { color_from_rgb_hex_for_value_logic(0xffff00) }
		'navy' { color_from_rgb_hex_for_value_logic(0x000080) }
		'blue' { color_from_rgb_hex_for_value_logic(0x0000ff) }
		'teal' { color_from_rgb_hex_for_value_logic(0x008080) }
		'aqua' { color_from_rgb_hex_for_value_logic(0x00ffff) }
		// CSS Level 2 (Revision 1)
		'orange' { color_from_rgb_hex_for_value_logic(0xffa500) }
		// CSS Color Module Level 3
		'aliceblue' { color_from_rgb_hex_for_value_logic(0xf0f8ff) }
		'antiquewhite' { color_from_rgb_hex_for_value_logic(0xfaebd7) }
		'aquamarine' { color_from_rgb_hex_for_value_logic(0x7fffd4) }
		'azure' { color_from_rgb_hex_for_value_logic(0xf0ffff) }
		'beige' { color_from_rgb_hex_for_value_logic(0xf5f5dc) }
		'bisque' { color_from_rgb_hex_for_value_logic(0xffe4c4) }
		'blanchedalmond' { color_from_rgb_hex_for_value_logic(0xffebcd) }
		'blueviolet' { color_from_rgb_hex_for_value_logic(0x8a2be2) }
		'brown' { color_from_rgb_hex_for_value_logic(0xa52a2a) }
		'burlywood' { color_from_rgb_hex_for_value_logic(0xdeb887) }
		'cadetblue' { color_from_rgb_hex_for_value_logic(0x5f9ea0) }
		'chartreuse' { color_from_rgb_hex_for_value_logic(0x7fff00) }
		'chocolate' { color_from_rgb_hex_for_value_logic(0xd2691e) }
		'coral' { color_from_rgb_hex_for_value_logic(0xff7f50) }
		'cornflowerblue' { color_from_rgb_hex_for_value_logic(0x6495ed) }
		'cornsilk' { color_from_rgb_hex_for_value_logic(0xfff8dc) }
		'crimson' { color_from_rgb_hex_for_value_logic(0xdc143c) }
		'cyan' { color_from_rgb_hex_for_value_logic(0x00ffff) }
		'darkblue' { color_from_rgb_hex_for_value_logic(0x00008b) }
		'darkcyan' { color_from_rgb_hex_for_value_logic(0x008b8b) }
		'darkgoldenrod' { color_from_rgb_hex_for_value_logic(0xb8860b) }
		'darkgray' { color_from_rgb_hex_for_value_logic(0xa9a9a9) }
		'darkgreen' { color_from_rgb_hex_for_value_logic(0x006400) }
		'darkgrey' { color_from_rgb_hex_for_value_logic(0xa9a9a9) }
		'darkkhaki' { color_from_rgb_hex_for_value_logic(0xbdb76b) }
		'darkmagenta' { color_from_rgb_hex_for_value_logic(0x8b008b) }
		'darkolivegreen' { color_from_rgb_hex_for_value_logic(0x556b2f) }
		'darkorange' { color_from_rgb_hex_for_value_logic(0xff8c00) }
		'darkorchid' { color_from_rgb_hex_for_value_logic(0x9932cc) }
		'darkred' { color_from_rgb_hex_for_value_logic(0x8b0000) }
		'darksalmon' { color_from_rgb_hex_for_value_logic(0xe9967a) }
		'darkseagreen' { color_from_rgb_hex_for_value_logic(0x8fbc8f) }
		'darkslateblue' { color_from_rgb_hex_for_value_logic(0x483d8b) }
		'darkslategray' { color_from_rgb_hex_for_value_logic(0x2f4f4f) }
		'darkslategrey' { color_from_rgb_hex_for_value_logic(0x2f4f4f) }
		'darkturquoise' { color_from_rgb_hex_for_value_logic(0x00ced1) }
		'darkviolet' { color_from_rgb_hex_for_value_logic(0x9400d3) }
		'deeppink' { color_from_rgb_hex_for_value_logic(0xff1493) }
		'deepskyblue' { color_from_rgb_hex_for_value_logic(0x00bfff) }
		'dimgray' { color_from_rgb_hex_for_value_logic(0x696969) }
		'dimgrey' { color_from_rgb_hex_for_value_logic(0x696969) }
		'dodgerblue' { color_from_rgb_hex_for_value_logic(0x1e90ff) }
		'firebrick' { color_from_rgb_hex_for_value_logic(0xb22222) }
		'floralwhite' { color_from_rgb_hex_for_value_logic(0xfffaf0) }
		'forestgreen' { color_from_rgb_hex_for_value_logic(0x228b22) }
		'gainsboro' { color_from_rgb_hex_for_value_logic(0xdcdcdc) }
		'ghostwhite' { color_from_rgb_hex_for_value_logic(0xf8f8ff) }
		'gold' { color_from_rgb_hex_for_value_logic(0xffd700) }
		'goldenrod' { color_from_rgb_hex_for_value_logic(0xdaa520) }
		'greenyellow' { color_from_rgb_hex_for_value_logic(0xadff2f) }
		'grey' { color_from_rgb_hex_for_value_logic(0x808080) }
		'honeydew' { color_from_rgb_hex_for_value_logic(0xf0fff0) }
		'hotpink' { color_from_rgb_hex_for_value_logic(0xff69b4) }
		'indianred' { color_from_rgb_hex_for_value_logic(0xcd5c5c) }
		'indigo' { color_from_rgb_hex_for_value_logic(0x4b0082) }
		'ivory' { color_from_rgb_hex_for_value_logic(0xfffff0) }
		'khaki' { color_from_rgb_hex_for_value_logic(0xf0e68c) }
		'lavender' { color_from_rgb_hex_for_value_logic(0xe6e6fa) }
		'lavenderblush' { color_from_rgb_hex_for_value_logic(0xfff0f5) }
		'lawngreen' { color_from_rgb_hex_for_value_logic(0x7cfc00) }
		'lemonchiffon' { color_from_rgb_hex_for_value_logic(0xfffacd) }
		'lightblue' { color_from_rgb_hex_for_value_logic(0xadd8e6) }
		'lightcoral' { color_from_rgb_hex_for_value_logic(0xf08080) }
		'lightcyan' { color_from_rgb_hex_for_value_logic(0xe0ffff) }
		'lightgoldenrodyellow' { color_from_rgb_hex_for_value_logic(0xfafad2) }
		'lightgray' { color_from_rgb_hex_for_value_logic(0xd3d3d3) }
		'lightgreen' { color_from_rgb_hex_for_value_logic(0x90ee90) }
		'lightgrey' { color_from_rgb_hex_for_value_logic(0xd3d3d3) }
		'lightpink' { color_from_rgb_hex_for_value_logic(0xffb6c1) }
		'lightsalmon' { color_from_rgb_hex_for_value_logic(0xffa07a) }
		'lightseagreen' { color_from_rgb_hex_for_value_logic(0x20b2aa) }
		'lightskyblue' { color_from_rgb_hex_for_value_logic(0x87cefa) }
		'lightslategray' { color_from_rgb_hex_for_value_logic(0x778899) }
		'lightslategrey' { color_from_rgb_hex_for_value_logic(0x778899) }
		'lightsteelblue' { color_from_rgb_hex_for_value_logic(0xb0c4de) }
		'lightyellow' { color_from_rgb_hex_for_value_logic(0xffffe0) }
		'limegreen' { color_from_rgb_hex_for_value_logic(0x32cd32) }
		'linen' { color_from_rgb_hex_for_value_logic(0xfaf0e6) }
		'magenta' { color_from_rgb_hex_for_value_logic(0xff00ff) }
		'mediumaquamarine' { color_from_rgb_hex_for_value_logic(0x66cdaa) }
		'mediumblue' { color_from_rgb_hex_for_value_logic(0x0000cd) }
		'mediumorchid' { color_from_rgb_hex_for_value_logic(0xba55d3) }
		'mediumpurple' { color_from_rgb_hex_for_value_logic(0x9370db) }
		'mediumseagreen' { color_from_rgb_hex_for_value_logic(0x3cb371) }
		'mediumslateblue' { color_from_rgb_hex_for_value_logic(0x7b68ee) }
		'mediumspringgreen' { color_from_rgb_hex_for_value_logic(0x00fa9a) }
		'mediumturquoise' { color_from_rgb_hex_for_value_logic(0x48d1cc) }
		'mediumvioletred' { color_from_rgb_hex_for_value_logic(0xc71585) }
		'midnightblue' { color_from_rgb_hex_for_value_logic(0x191970) }
		'mintcream' { color_from_rgb_hex_for_value_logic(0xf5fffa) }
		'mistyrose' { color_from_rgb_hex_for_value_logic(0xffe4e1) }
		'moccasin' { color_from_rgb_hex_for_value_logic(0xffe4b5) }
		'navajowhite' { color_from_rgb_hex_for_value_logic(0xffdead) }
		'oldlace' { color_from_rgb_hex_for_value_logic(0xfdf5e6) }
		'olivedrab' { color_from_rgb_hex_for_value_logic(0x6b8e23) }
		'orangered' { color_from_rgb_hex_for_value_logic(0xff4500) }
		'orchid' { color_from_rgb_hex_for_value_logic(0xda70d6) }
		'palegoldenrod' { color_from_rgb_hex_for_value_logic(0xeee8aa) }
		'palegreen' { color_from_rgb_hex_for_value_logic(0x98fb98) }
		'paleturquoise' { color_from_rgb_hex_for_value_logic(0xafeeee) }
		'palevioletred' { color_from_rgb_hex_for_value_logic(0xdb7093) }
		'papayawhip' { color_from_rgb_hex_for_value_logic(0xffefd5) }
		'peachpuff' { color_from_rgb_hex_for_value_logic(0xffdab9) }
		'peru' { color_from_rgb_hex_for_value_logic(0xcd853f) }
		'pink' { color_from_rgb_hex_for_value_logic(0xffc0cb) }
		'plum' { color_from_rgb_hex_for_value_logic(0xdda0dd) }
		'powderblue' { color_from_rgb_hex_for_value_logic(0xb0e0e6) }
		'rosybrown' { color_from_rgb_hex_for_value_logic(0xbc8f8f) }
		'royalblue' { color_from_rgb_hex_for_value_logic(0x4169e1) }
		'saddlebrown' { color_from_rgb_hex_for_value_logic(0x8b4513) }
		'salmon' { color_from_rgb_hex_for_value_logic(0xfa8072) }
		'sandybrown' { color_from_rgb_hex_for_value_logic(0xf4a460) }
		'seagreen' { color_from_rgb_hex_for_value_logic(0x2e8b57) }
		'seashell' { color_from_rgb_hex_for_value_logic(0xfff5ee) }
		'sienna' { color_from_rgb_hex_for_value_logic(0xa0522d) }
		'skyblue' { color_from_rgb_hex_for_value_logic(0x87ceeb) }
		'slateblue' { color_from_rgb_hex_for_value_logic(0x6a5acd) }
		'slategray' { color_from_rgb_hex_for_value_logic(0x708090) }
		'slategrey' { color_from_rgb_hex_for_value_logic(0x708090) }
		'snow' { color_from_rgb_hex_for_value_logic(0xfffafa) }
		'springgreen' { color_from_rgb_hex_for_value_logic(0x00ff7f) }
		'steelblue' { color_from_rgb_hex_for_value_logic(0x4682b4) }
		'tan' { color_from_rgb_hex_for_value_logic(0xd2b48c) }
		'thistle' { color_from_rgb_hex_for_value_logic(0xd8bfd8) }
		'tomato' { color_from_rgb_hex_for_value_logic(0xff6347) }
		'turquoise' { color_from_rgb_hex_for_value_logic(0x40e0d0) }
		'violet' { color_from_rgb_hex_for_value_logic(0xee82ee) }
		'wheat' { color_from_rgb_hex_for_value_logic(0xf5deb3) }
		'whitesmoke' { color_from_rgb_hex_for_value_logic(0xf5f5f5) }
		'yellowgreen' { color_from_rgb_hex_for_value_logic(0x9acd32) }
		// CSS Color Module Level 4
		'rebeccapurple' { color_from_rgb_hex_for_value_logic(0x663399) }
		else { none }
	}
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

fn style_value_from_css_image_source_for_value_logic(value CSSImageSourceStyleValue) StyleValue {
	return match value {
		ConicGradientStyleValue { StyleValue(value) }
		ImageStyleValue { StyleValue(value) }
		LinearGradientStyleValue { StyleValue(value) }
		RadialGradientStyleValue { StyleValue(value) }
		StyleValue { value }
	}
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

fn (mut parser Parser) parse_transform_parameter_value(parameter TransformFunctionParameter, mut tokens ComponentValueStream) ?StyleValue {
	match parameter.type_ {
		.angle {
			// These are `<angle> | <zero>` in the spec, so we have to check for both kinds.
			if angle_value := parser.parse_angle_value(mut tokens) {
				return angle_value
			}
			if next := tokens.peek() {
				if next.is(.number) && next.token().number_value() == 0 {
					tokens.consume()
					return StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
				}
			}
			return none
		}
		.length, .length_none {
			if length_value := parser.parse_length_value(mut tokens) {
				return length_value
			}
			if parameter.type_ == .length_none {
				if next := tokens.peek() {
					if next.is(.ident) && equals_ignoring_ascii_case(next.token().ident(), 'none') {
						tokens.consume()
						return StyleValue(KeywordStyleValue.create(.none_))
					}
				}
			}
			return none
		}
		.length_percentage {
			return parser.parse_length_percentage_value(mut tokens)
		}
		.number {
			return parser.parse_number_value(mut tokens)
		}
		.number_percentage {
			return parser.parse_number_percentage_value(mut tokens)
		}
	}
}

// https://drafts.csswg.org/css-transforms-1/#typedef-transform-function
fn (mut parser Parser) parse_transform_function_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	part := transaction.consume() or { return none }
	if !part.is_function() {
		return none
	}
	function := transform_function_from_string(part.function().name) or { return none }

	function_metadata := transform_function_metadata(function)
	mut arguments :=
		parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	if arguments.len > function_metadata.parameters.len {
		return none
	}

	if arguments.len < function_metadata.parameters.len
		&& function_metadata.parameters[arguments.len].required {
		return none
	}

	mut values := StyleValueVector{}
	for argument_index in 0 .. arguments.len {
		mut argument_tokens := ComponentValueStream.new(arguments[argument_index])
		argument_tokens.consume_whitespace()
		value := parser.parse_transform_parameter_value(function_metadata.parameters[argument_index], mut
			argument_tokens) or { return none }
		values << value
		if argument_tokens.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.transform, function, values))
}

// https://drafts.csswg.org/css-transforms-1/#typedef-transform-list
fn (mut parser Parser) parse_transform_list_value(mut tokens ComponentValueStream) ?StyleValue {
	// <transform-list> = <transform-function>+
	// https://www.w3.org/TR/css-transforms-1/#transform-property
	mut transaction := tokens.clone()
	mut transformations := StyleValueVector{}
	for transaction.has_more_tokens() {
		if maybe_function := parser.parse_transform_function_value(mut transaction) {
			transformations << maybe_function
			transaction.consume_whitespace()
			continue
		}
		break
	}
	if transformations.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(transformations, .space, .yes))
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
