module css

import dom
import platform
import math
import strconv
import svg

// This file is a local V translation layer for the LibWeb parser logic in:
// - Libraries/LibWeb/CSS/Parser/ValueParsing.cpp
// - Libraries/LibWeb/CSS/Parser/PropertyParsing.cpp
// - Libraries/LibWeb/CSS/Parser/DescriptorParsing.cpp
// - Libraries/LibWeb/CSS/Parser/MediaParsing.cpp
// - Libraries/LibWeb/CSS/Parser/GradientParsing.cpp
//
// Generated property grammar and metadata are emitted from Ladybird's JSON
// sources. This file keeps the translated value/property algorithms together;
// parser_core.v owns only CSS Syntax tokenization and component-value handling.
pub struct Parser {
pub mut:
	component_values      []ComponentValue
	context               ParsingParams
	value_context         []ValueParsingContext
	random_function_index uint
	// The channel keywords of the relative color being parsed, which its
	// components and their math functions may reference.
	relative_color_channels []string
}

pub fn Parser.from_component_values(component_values []ComponentValue) Parser {
	return Parser{
		component_values: component_values.clone()
	}
}

// Internal parsing reads an immutable span. Its owner must keep the array
// unchanged for the parse; the public constructor still provides a snapshot
// for callers which can subsequently replace their component slots.
fn Parser.from_component_span(component_values []ComponentValue) Parser {
	return Parser{component_values: component_values}
}

pub fn Parser.from_css_text(text string) Parser {
	return Parser.from_component_span(parse_component_values_for_value_logic(text))
}

pub fn Parser.with_context(context ParsingParams, text string) Parser {
	return Parser{
		component_values: parse_component_values_for_value_logic(text)
		context: context
		value_context: context.value_context.clone()
	}
}

fn (parser Parser) in_quirks_mode() bool {
	return parser.context.document != unsafe { nil }
		&& parser.context.document.in_quirks_mode()
}

fn (parser Parser) is_parsing_svg_presentation_attribute() bool {
	return parser.context.mode == .svg_presentation_attribute
}

fn (mut parser Parser) push_temporary_value_parsing_context(context ValueParsingContext) {
	parser.value_context << context
}

fn (mut parser Parser) pop_temporary_value_parsing_context() {
	removed_context := parser.value_context.pop()
	if removed_context is PropertyID {
		for context in parser.value_context {
			if context is PropertyID {
				return
			}
		}
		parser.random_function_index = 0
	}
}

fn (parser Parser) context_allows_quirky_length() bool {
	if !parser.in_quirks_mode() {
		return false
	}

	if parser.value_context.len == 0 {
		return false
	}
	top_level_context := parser.value_context[0]
	top_level_property := match top_level_context {
		PropertyID { top_level_context }
		else {
			return false
		}
	}
	if !property_has_quirk(top_level_property, .unitless_length) {
		return false
	}

	for i := 1; i < parser.value_context.len; i++ {
		context := parser.value_context[i]
		match context {
			PropertyID {
				if !property_has_quirk(context, .unitless_length) {
					return false
				}
			}
			FunctionContext {
				if !equals_ignoring_ascii_case(context.name, 'rect')
					|| top_level_property != .clip {
					return false
				}
			}
			else {
				return false
			}
		}
	}
	return true
}

fn (parser Parser) context_allows_tree_counting_functions() bool {
	for context in parser.value_context {
		match context {
			DescriptorContext {
				return false
			}
			SpecialContext {
				if context in [.canvas_context_generic_value, .dom_matrix_init_string, .media_condition] {
					return false
				}
			}
			else {}
		}
	}
	return true
}

fn (parser Parser) context_allows_random_functions() bool {
	// Rust value_parser.rs: CanvasContextGenericValue forbids random().
	if parser.value_context.len > 0 {
		first := parser.value_context[0]
		if first is SpecialContext && first == .canvas_context_generic_value {
			return false
		}
	}
	for context in parser.value_context {
		if context is PropertyID {
			return true
		}
	}
	return false
}

fn (parser Parser) random_value_sharing_auto_name() string {
	for context in parser.value_context {
		if context is PropertyID {
			return '${string_from_property_id(context)} ${parser.random_function_index}'
		}
	}
	return ''
}

fn accepted_calculation_range(min f64, max f64) AcceptedTypeRange {
	return AcceptedTypeRange{
		min: min
		max: max
	}
}

// Translate the nearest value context into the CalculationContext used by
// LibWeb. Unrecognized functions inherit their parent's context; descriptors
// and every special context establish a new one, even when it is empty.
fn (parser Parser) calculation_context() CalculationContext {
	for i := parser.value_context.len - 1; i >= 0; i-- {
		value_context := parser.value_context[i]
		match value_context {
			PropertyID {
				return CalculationContext.for_property(PropertyNameAndID.from_id(value_context))
			}
			FunctionContext {
				name := to_ascii_lowercase(value_context.name)
				if name in ['linear-gradient', 'repeating-linear-gradient', '-webkit-radial-gradient',
					'-webkit-repeating-radial-gradient', 'radial-gradient',
					'repeating-radial-gradient', 'conic-gradient', 'repeating-conic-gradient',
					'circle', 'ellipse', 'inset', 'polygon', 'rect', 'xywh', 'view'] {
					return CalculationContext{
						percentages_resolve_as: ValueType.length
					}
				}
				if name in ['scale', 'scalex', 'scaley', 'scalez', 'scale3d', 'rgb', 'rgba', 'hsl',
					'hsla', 'hwb', 'lab', 'lch', 'oklab', 'oklch', 'color'] {
					return CalculationContext{}
				}
				if name in ['grayscale', 'invert', 'opacity', 'sepia'] {
					return CalculationContext{
						accepted_type_ranges: {
							ValueType.number:     accepted_calculation_range(0, 1)
							ValueType.percentage: accepted_calculation_range(0, 100)
						}
					}
				}
				if name in ['brightness', 'contrast', 'saturate'] {
					return CalculationContext{
						accepted_type_ranges: {
							ValueType.number:     accepted_calculation_range(0, math.max_f32)
							ValueType.percentage: accepted_calculation_range(0, math.max_f32)
						}
					}
				}
				if name == 'blur' {
					return CalculationContext{
						accepted_type_ranges: {
							ValueType.length: accepted_calculation_range(0, math.max_f32)
						}
					}
				}
			}
			DescriptorContext {
				// V currently exposes only @page descriptors. When counter-style
				// descriptors are translated, additive-symbols and pad establish
				// the non-negative integer context handled by C++ here.
				return CalculationContext{}
			}
			SyntaxParsingContext {
				return match value_context.type_ {
					.angle_percentage {
						CalculationContext{
							percentages_resolve_as: ValueType.angle
						}
					}
					.frequency_percentage {
						CalculationContext{
							percentages_resolve_as: ValueType.frequency
						}
					}
					.length_percentage {
						CalculationContext{
							percentages_resolve_as: ValueType.length
						}
					}
					.time_percentage {
						CalculationContext{
							percentages_resolve_as: ValueType.time
						}
					}
					else { CalculationContext{} }
				}
			}
			SpecialContext {
				return match value_context {
					.angular_color_stop_list {
						CalculationContext{
							percentages_resolve_as: ValueType.angle
						}
					}
					.border_radius {
						CalculationContext{
							percentages_resolve_as: ValueType.length
							accepted_type_ranges: {
								ValueType.length:     accepted_calculation_range(0, math.max_f32)
								ValueType.percentage: accepted_calculation_range(0, math.max_f32)
							}
						}
					}
					.cubic_bezier_function_x_coordinate {
						CalculationContext{
							accepted_type_ranges: {
								ValueType.number: accepted_calculation_range(0, 1)
							}
						}
					}
					.font_style_angle {
						CalculationContext{
							accepted_type_ranges: {
								ValueType.angle: accepted_calculation_range(-90, 90)
							}
						}
					}
					.grid_track_repeat_count {
						CalculationContext{
							resolve_numbers_as_integers: true
							accepted_type_ranges: {
								ValueType.integer: accepted_calculation_range(1, f64(2147483647))
							}
						}
					}
					.radial_size_length_percentage {
						CalculationContext{
							percentages_resolve_as: ValueType.length
							accepted_type_ranges: {
								ValueType.length: accepted_calculation_range(0, math.max_f32)
							}
						}
					}
					.random_value_sharing_fixed_value {
						CalculationContext{
							accepted_type_ranges: {
								ValueType.number: accepted_calculation_range(0, 0.999999)
							}
						}
					}
					.steps_intervals_jump_none {
						CalculationContext{
							resolve_numbers_as_integers: true
							accepted_type_ranges: {
								ValueType.integer: accepted_calculation_range(2, f64(2147483647))
							}
						}
					}
					.steps_intervals_normal {
						CalculationContext{
							resolve_numbers_as_integers: true
							accepted_type_ranges: {
								ValueType.integer: accepted_calculation_range(1, f64(2147483647))
							}
						}
					}
					.shadow_blur_radius {
						CalculationContext{
							accepted_type_ranges: {
								ValueType.length: accepted_calculation_range(0, math.max_f32)
							}
						}
					}
					else { CalculationContext{} }
				}
			}
		}
	}
	return CalculationContext{}
}

fn (parser Parser) context_allows_quirky_color() bool {
	if !parser.in_quirks_mode() || parser.value_context.len == 0 {
		return false
	}
	for context in parser.value_context {
		if context is PropertyID {
			if !property_has_quirk(context, .hashless_hex_color) {
				return false
			}
		} else {
			return false
		}
	}
	return true
}

fn (parser Parser) parse_dimension(component_value ComponentValue) ?Dimension {
	if component_value.is(.dimension) {
		numeric_value := component_value.token().dimension_value()
		unit_string := component_value.token().dimension_unit()
		if unit := string_to_length_unit(unit_string) {
			return Dimension(Length.new(numeric_value, unit))
		}
		if unit := string_to_angle_unit(unit_string) {
			return Dimension(Angle.new(numeric_value, unit))
		}
		if unit := string_to_flex_unit(unit_string) {
			return Dimension(Flex.new(numeric_value, unit))
		}
		if unit := string_to_frequency_unit(unit_string) {
			return Dimension(Frequency.new(numeric_value, unit))
		}
		if unit := string_to_resolution_unit(unit_string) {
			return Dimension(Resolution.new(numeric_value, unit))
		}
		if unit := string_to_time_unit(unit_string) {
			return Dimension(Time.new(numeric_value, unit))
		}
	}

	if component_value.is(.percentage) {
		return Dimension(Percentage.new(component_value.token().percentage()))
	}

	if component_value.is(.number) {
		numeric_value := component_value.token().number_value()
		if numeric_value == 0 || parser.context_allows_quirky_length() {
			return Dimension(Length.make_px(numeric_value))
		}
	}

	return none
}

pub struct ComponentValueStream {
mut:
	values []ComponentValue
	index  int
}

fn ComponentValueStream.new(values []ComponentValue) ComponentValueStream {
	return ComponentValueStream{
		values: values
	}
}

fn (stream ComponentValueStream) clone() ComponentValueStream {
	// Parser transactions move only their cursor. Component values are read
	// through this stream and remain owned by the parser's traced input graph.
	return ComponentValueStream{
		values: stream.values
		index: stream.index
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
	for {
		value := stream.peek() or { return }
		if !value.is(.whitespace) {
			return
		}
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
	mut working_copy := stream
	working_copy.consume_whitespace()
	return !working_copy.is_empty()
}

fn (stream ComponentValueStream) has_one_token() bool {
	mut working_copy := stream
	working_copy.consume_whitespace()
	if working_copy.consume() == none {
		return false
	}
	working_copy.consume_whitespace()
	return working_copy.is_empty()
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
			block_values := consume_component_value_list_for_value_logic(tokens, mut state, end_type)
			mut end_token := Token.create(end_type, '')
			if state.value < tokens.len && tokens[state.value].is(end_type) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_block(SimpleBlock{
				token: token
				value: block_values
				end_token: end_token
			})
			continue
		}
		if token.is(.function) {
			function_values := consume_component_value_list_for_value_logic(tokens, mut state, .close_paren)
			mut end_token := Token.create(.close_paren, '')
			if state.value < tokens.len && tokens[state.value].is(.close_paren) {
				end_token = tokens[state.value]
				state.value++
			}
			values << ComponentValue.from_function(Function{
				name: token.function_name()
				value: function_values
				name_token: token
				end_token: end_token
			})
			continue
		}
		values << ComponentValue.from_token(token)
	}
	return values
}

// The property selected by the generated grammar metadata together with the
// value parsed for it. This is Parser::PropertyAndValue in Ladybird.
struct PropertyAndValue {
	property    PropertyID
	style_value StyleValue
}

fn first_property_accepting_type(property_ids []PropertyID, value_type ValueType) ?PropertyID {
	for property_id in property_ids {
		if property_accepts_type(property_id, value_type) {
			return property_id
		}
	}
	return none
}

fn first_property_accepting_keyword(property_ids []PropertyID, keyword Keyword) ?PropertyID {
	for property_id in property_ids {
		if property_accepts_keyword(property_id, keyword) {
			return property_id
		}
	}
	return none
}

fn property_accepts_parsed_numeric_value(property_id PropertyID, value_type ValueType, value StyleValue) bool {
	return match value_type {
		.integer {
			match value {
				IntegerStyleValue { property_accepts_integer(property_id, value.integer()) }
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.number {
			match value {
				NumberStyleValue { property_accepts_number(property_id, value.number()) }
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.angle {
			match value {
				AngleStyleValue { property_accepts_angle(property_id, value.angle()) }
				PercentageStyleValue {
					property_accepts_percentage(property_id, value.percentage())
				}
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.flex {
			match value {
				FlexStyleValue { property_accepts_flex(property_id, value.flex()) }
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.frequency {
			match value {
				FrequencyStyleValue { property_accepts_frequency(property_id, value.frequency()) }
				PercentageStyleValue {
					property_accepts_percentage(property_id, value.percentage())
				}
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.length {
			match value {
				LengthStyleValue { property_accepts_length(property_id, value.length()) }
				PercentageStyleValue {
					property_accepts_percentage(property_id, value.percentage())
				}
				CalculatedStyleValue, AnchorSizeStyleValue { true }
				else { false }
			}
		}
		.resolution {
			match value {
				ResolutionStyleValue {
					property_accepts_resolution(property_id, value.resolution())
				}
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.time {
			match value {
				TimeStyleValue { property_accepts_time(property_id, value.time()) }
				PercentageStyleValue {
					property_accepts_percentage(property_id, value.percentage())
				}
				CalculatedStyleValue { true }
				else { false }
			}
		}
		.percentage {
			match value {
				PercentageStyleValue {
					property_accepts_percentage(property_id, value.percentage())
				}
				CalculatedStyleValue { true }
				else { false }
			}
		}
		else {
			false
		}
	}
}

fn (mut parser Parser) parse_first_property_accepting_type(property_ids []PropertyID, value_type ValueType, mut tokens ComponentValueStream) ?PropertyAndValue {
	property_id := first_property_accepting_type(property_ids, value_type) or { return none }
	parser.push_temporary_value_parsing_context(ValueParsingContext(property_id))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	mut transaction := tokens.clone()
	value := parser.parse_value(value_type, mut transaction) or { return none }
	tokens = transaction
	return PropertyAndValue{
		property: property_id
		style_value: value
	}
}

fn (mut parser Parser) parse_first_property_accepting_numeric_type(property_ids []PropertyID, value_type ValueType, mut tokens ComponentValueStream) ?PropertyAndValue {
	property_id := first_property_accepting_type(property_ids, value_type) or { return none }
	parser.push_temporary_value_parsing_context(ValueParsingContext(property_id))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	// Angle/frequency/length/time percentages share one grammar production in
	// Ladybird. Probe it first whenever the selected property also accepts a
	// percentage, then fall back to the plain dimension parser.
	if property_accepts_type(property_id, .percentage) && value_type in [.angle, .frequency, .length,
		.time] {
		mut percentage_transaction := tokens.clone()
		mut percentage_value := ?StyleValue(none)
		match value_type {
			.angle {
				percentage_value = parser.parse_angle_percentage_value(mut percentage_transaction)
			}
			.frequency {
				percentage_value = parser.parse_frequency_percentage_value(mut percentage_transaction)
			}
			.length {
				percentage_value = parser.parse_length_percentage_value(mut percentage_transaction)
			}
			.time {
				percentage_value = parser.parse_time_percentage_value(mut percentage_transaction)
			}
			else {}
		}
		if value := percentage_value {
			if property_accepts_parsed_numeric_value(property_id, value_type, value) {
				tokens = percentage_transaction
				return PropertyAndValue{
					property: property_id
					style_value: value
				}
			}
		}
	}

	mut transaction := tokens.clone()
	value := parser.parse_value(value_type, mut transaction) or { return none }
	if !property_accepts_parsed_numeric_value(property_id, value_type, value) {
		return none
	}
	tokens = transaction
	return PropertyAndValue{
		property: property_id
		style_value: value
	}
}

// PropertyParsing.cpp: Parser::parse_css_value_for_properties. Keep the
// upstream type order: it is observable for ambiguous unitless zeroes and for
// coordinated shorthands whose longhands accept overlapping grammars.
fn (mut parser Parser) parse_css_value_for_properties(property_ids []PropertyID, mut tokens ComponentValueStream) ?PropertyAndValue {
	tokens.consume_whitespace()
	peek := tokens.peek() or { return none }

	if peek.is(.ident) {
		if keyword := keyword_from_string(peek.token().ident()) {
			if property_id := first_property_accepting_keyword(property_ids, keyword) {
				tokens.consume()
				resolved_keyword := resolve_legacy_value_alias(property_id, keyword) or { keyword }
				return PropertyAndValue{
					property: property_id
					style_value: StyleValue(KeywordStyleValue.create(resolved_keyword))
				}
			}
		}

		if property_id := first_property_accepting_type(property_ids, .custom_ident) {
			parser.push_temporary_value_parsing_context(ValueParsingContext(property_id))
			defer {
				parser.pop_temporary_value_parsing_context()
			}
			mut transaction := tokens.clone()
			if custom_ident := parser.parse_custom_ident_value(mut transaction, property_custom_ident_blacklist(property_id)) {
				tokens = transaction
				return PropertyAndValue{
					property: property_id
					style_value: StyleValue(custom_ident)
				}
			}
		}
	}

	for value_type in [ValueType.color, .corner_shape, .counter, .counter_style, .dashed_ident,
		.easing_function, .font_style, .font_variant_alternates, .font_variant_east_asian,
		.font_variant_ligatures, .font_variant_numeric, .image, .position, .background_position,
		.basic_shape, .ratio, .opacity, .opentype_tag, .rect, .scroll_function, .string,
		.transform_function, .transform_list, .url, .view_function, .view_timeline_inset] {
		if parsed := parser.parse_first_property_accepting_type(property_ids, value_type, mut tokens) {
			return parsed
		}
	}

	// Integer and number precede length so that an ambiguous unitless zero is
	// assigned to the numeric longhand, exactly as in Ladybird.
	for value_type in [ValueType.integer, .number, .angle, .flex, .frequency] {
		if parsed := parser.parse_first_property_accepting_numeric_type(property_ids, value_type, mut tokens) {
			return parsed
		}
	}

	if parsed := parser.parse_first_property_accepting_type(property_ids, .fit_content, mut tokens) {
		return parsed
	}

	for value_type in [ValueType.length, .resolution, .time, .percentage] {
		if parsed := parser.parse_first_property_accepting_numeric_type(property_ids, value_type, mut tokens) {
			return parsed
		}
	}

	for value_type in [ValueType.paint, .anchor] {
		if parsed := parser.parse_first_property_accepting_type(property_ids, value_type, mut tokens) {
			return parsed
		}
	}

	return none
}

// PropertyParsing.cpp: Parser::parse_positional_value_list_shorthand.
fn (mut parser Parser) parse_positional_value_list_shorthand(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	longhands := generated_longhands_for_shorthand(property_id)
	mut parsed_values := []StyleValue{}
	mut transaction := tokens.clone()

	for {
		property_and_value := parser.parse_css_value_for_properties([property_id], mut transaction) or { break }
		parsed_values << property_and_value.style_value
	}

	if parsed_values.len == 0 || parsed_values.len > longhands.len {
		return none
	}

	mut longhand_values := []StyleValue{}
	match longhands.len {
		2 {
			match parsed_values.len {
				1 {
					longhand_values = [parsed_values[0], parsed_values[0]]
				}
				2 {
					longhand_values = parsed_values.clone()
				}
				else {
					return none
				}
			}
		}
		4 {
			match parsed_values.len {
				1 {
					longhand_values = [parsed_values[0], parsed_values[0], parsed_values[0],
						parsed_values[0]]
				}
				2 {
					longhand_values = [parsed_values[0], parsed_values[1], parsed_values[0],
						parsed_values[1]]
				}
				3 {
					longhand_values = [parsed_values[0], parsed_values[1], parsed_values[2],
						parsed_values[1]]
				}
				4 {
					longhand_values = parsed_values.clone()
				}
				else {
					return none
				}
			}
		}
		else {
			return none
		}
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(property_id, longhands, longhand_values))
}

// PropertyParsing.cpp: Parser::parse_simple_comma_separated_value_list.
fn (mut parser Parser) parse_simple_comma_separated_value_list(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	for {
		property_and_value := parser.parse_css_value_for_properties([property_id], mut transaction) or { return none }
		values << property_and_value.style_value
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		if !transaction.consume_a_comma() || !transaction.has_more_tokens() {
			return none
		}
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(values, .comma, .yes))
}

fn property_uses_special_coordinating_list_parser(property_id PropertyID) bool {
	return property_id in [.background_attachment, .background_blend_mode, .background_clip,
		.background_image, .background_origin, .background_position_x, .background_position_y,
		.background_repeat, .background_size, .mask_clip, .mask_composite, .mask_image, .mask_mode,
		.mask_origin, .mask_position, .mask_repeat, .mask_size, .transition_property,
		.animation_range_start, .animation_range_end]
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
	parser.push_temporary_value_parsing_context(ValueParsingContext(property_id))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	// Properties containing syntactically valid var()/attr()/env()/if()/inherit()
	// are resolved after the custom-property cascade. Invalid argument grammars
	// are rejected now rather than becoming guaranteed-invalid at computed time.
	// Validation only reads this span. Only an unresolved result publishes the
	// vector, so resolved scalar values need no input-sized allocation.
	remaining := if disable_component_input_reuse {
		tokens.values[tokens.index..].clone()
	} else {
		tokens.values[tokens.index..]
	}
	mut substitution_presence := SubstitutionFunctionsPresence{}
	for token in remaining {
		if token.is(.semicolon) {
			return none
		}
		collect_arbitrary_substitution_function_presence_from_component(token, mut substitution_presence) or {
			return none
		}
	}
	if substitution_presence.has_any() {
		owned := if disable_component_input_reuse { remaining } else { remaining.clone() }
		return StyleValue(UnresolvedStyleValue.create_with_presence(owned, substitution_presence, none))
	}
	// CSS-wide keywords can be used as the entire value of any property.
	if value := parse_css_wide_keyword_value(mut tokens) {
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
	// parse_css_value() establishes the top-level property context; each grammar
	// probe establishes the property whose type metadata selected that probe.
	// This second layer is intentional and mirrors parse_css_value_for_properties()
	// in C++, including when a shorthand probes one of its longhands.
	parser.push_temporary_value_parsing_context(ValueParsingContext(property_id))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	if property_id == .contain_intrinsic_size {
		return parser.parse_contain_intrinsic_size_shorthand(mut tokens)
	}
	if property_id in [.contain_intrinsic_block_size, .contain_intrinsic_height,
		.contain_intrinsic_inline_size, .contain_intrinsic_width] {
		return parser.parse_contain_intrinsic_size_value(mut tokens)
	}
	// Inset components also accept anchor(). The generated positional type
	// metadata only describes their numeric values, so use the inset grammar.
	if property_is_positional_value_list_shorthand(property_id)
		&& property_id !in [.inset,.inset_block,.inset_inline] {
		return parser.parse_positional_value_list_shorthand(property_id, mut tokens)
	}
	if property_multiplicity(property_id) == .coordinating_list
		&& !property_is_shorthand(property_id)
		&& !property_uses_special_coordinating_list_parser(property_id) {
		return parser.parse_simple_comma_separated_value_list(property_id, mut tokens)
	}
	// FIXME: This switch mirrors the translated C++ dispatch points that can be
	// represented with the currently translated PropertyID enum. The generated
	// property grammar tables are not available in this V port yet.
	match property_id {
		.forced_color_adjust, .text_orientation { return parse_property_keyword_value_from_metadata(property_id, mut tokens) }
		.font_size_adjust { return parser.parse_font_size_adjust_value(mut tokens) }
		.font_palette { return parser.parse_font_palette_value(mut tokens) }
		.page_break_after, .page_break_before, .page_break_inside {
			return parser.parse_page_break_legacy_shorthand(property_id, mut tokens)
		}
		.line_clamp, .webkit_line_clamp {
			return parser.parse_line_clamp_shorthand(property_id, mut tokens)
		}
		.contain_intrinsic_size {
			return parser.parse_contain_intrinsic_size_shorthand(mut tokens)
		}
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width {
			return parser.parse_contain_intrinsic_size_value(mut tokens)
		}
		.accent_color, .caret_color {
			return parser.parse_auto_or_color_value(mut tokens)
		}
		.anchor_name {
			return parser.parse_anchor_name_value(mut tokens)
		}
		.anchor_scope {
			return parser.parse_anchor_scope_value(mut tokens)
		}
		.background_attachment {
			return parser.parse_background_attachment_value(mut tokens)
		}
		.background_blend_mode {
			return parser.parse_background_blend_mode_value(mut tokens)
		}
		.background_clip, .background_origin {
			return parser.parse_background_box_value(mut tokens)
		}
		.background_position_x, .background_position_y {
			return parser.parse_background_position_axis_list_value(property_id, mut tokens)
		}
		.background_repeat {
			return parser.parse_repeat_style_list_value(.background_repeat, mut tokens)
		}
		.background_size {
			return parser.parse_background_size_list_value(.background_size, mut tokens)
		}
		.animation_composition {
			return parser.parse_animation_composition_value(mut tokens)
		}
		.animation_delay {
			return parser.parse_animation_delay_value(mut tokens)
		}
		.animation_direction {
			return parser.parse_animation_direction_value(mut tokens)
		}
		.animation_duration {
			return parser.parse_animation_duration_value(mut tokens)
		}
		.animation_fill_mode {
			return parser.parse_animation_fill_mode_value(mut tokens)
		}
		.animation_iteration_count {
			return parser.parse_animation_iteration_count_value(mut tokens)
		}
		.animation_name {
			return parser.parse_animation_name_value(mut tokens)
		}
		.animation_play_state {
			return parser.parse_animation_play_state_value(mut tokens)
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_left_width, .border_right_width, .border_top_width, .column_rule_width, .outline_width {
			return parser.parse_border_or_outline_width_value(property_id, mut tokens)
		}
		.border_block_end_style, .border_block_start_style, .border_bottom_style, .border_inline_end_style, .border_inline_start_style, .border_left_style, .border_right_style, .border_top_style, .column_rule_style {
			return parser.parse_line_style_value(mut tokens)
		}
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius {
			return parser.parse_border_radius_value(mut tokens)
		}
		.border_image_outset {
			return parser.parse_border_image_outset_value(mut tokens)
		}
		.border_image_repeat {
			return parser.parse_border_image_repeat_value(mut tokens)
		}
		.border_shape { return parser.parse_border_shape_value(mut tokens) }
		.border_image_slice {
			return parser.parse_border_image_slice_value(mut tokens)
		}
		.border_image_width {
			return parser.parse_border_image_width_value(mut tokens)
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size, .min_width, .width, .max_block_size, .max_height, .max_inline_size, .max_width {
			return parser.parse_sizing_value(property_id, mut tokens)
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .right, .top {
			return parser.parse_inset_value(mut tokens)
		}
		.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top {
			return parser.parse_margin_value(mut tokens)
		}
		.padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top {
			return parser.parse_padding_value(mut tokens)
		}
		.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			return parser.parse_length_value(mut tokens)
		}
		.scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			return parser.parse_auto_or_nonnegative_length_percentage_value(mut tokens)
		}
		.border_spacing {
			return parser.parse_border_spacing_value(mut tokens)
		}
		.border_collapse {
			return parser.parse_border_collapse_value(mut tokens)
		}
		.box_decoration_break, .break_after, .break_before, .break_inside, .column_fill, .continue_, .webkit_box_orient {
			return parse_property_keyword_value_from_metadata(property_id, mut tokens)
		}
		.block_ellipsis {
			return parser.parse_block_ellipsis_value(mut tokens)
		}
		.max_lines {
			return parser.parse_max_lines_value(mut tokens)
		}
		.box_sizing {
			return parser.parse_box_sizing_value(mut tokens)
		}
		.outline_offset {
			return parser.parse_length_value(mut tokens)
		}
		.outline_style {
			return parser.parse_outline_style_value(mut tokens)
		}
		.object_position, .perspective_origin {
			return parser.parse_css_position_value(mut tokens, .normal)
		}
		.overflow_block, .overflow_inline, .overflow_x, .overflow_y {
			return parser.parse_overflow_value(property_id, mut tokens)
		}
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top {
			return parser.parse_overflow_clip_margin_value(mut tokens)
		}
		.overflow_wrap {
			return parser.parse_overflow_wrap_value(mut tokens)
		}
		.paint_order {
			return parser.parse_paint_order_value(mut tokens)
		}
		.perspective {
			return parser.parse_perspective_value(mut tokens)
		}
		.pointer_events {
			return parser.parse_pointer_events_value(mut tokens)
		}
		.position {
			return parser.parse_position_value(mut tokens)
		}
		.position_anchor {
			return parser.parse_position_anchor_value(mut tokens)
		}
		.position_area {
			return parser.parse_position_area_value(mut tokens)
		}
		.position_try_fallbacks {
			return parser.parse_position_try_fallbacks_value(mut tokens)
		}
		.position_try_order {
			return parser.parse_position_try_order_value(mut tokens)
		}
		.position_try {
			return parser.parse_position_try_shorthand(mut tokens)
		}
		.position_visibility {
			return parser.parse_position_visibility_value(mut tokens)
		}
		.background_color, .border_block_end_color, .border_block_start_color, .border_bottom_color, .border_inline_end_color, .border_inline_start_color, .border_left_color, .border_right_color, .border_top_color, .color, .column_rule_color, .flood_color, .outline_color, .stop_color, .webkit_text_fill_color {
			return parser.parse_color_value(mut tokens)
		}
		.color_scheme {
			return parser.parse_color_scheme_value(mut tokens)
		}
		.content_visibility {
			return parser.parse_content_visibility_value(mut tokens)
		}
		.contain {
			return parser.parse_contain_value(mut tokens)
		}
		.container {
			return parser.parse_container_value(mut tokens)
		}
		.container_name {
			return parser.parse_container_name_value(mut tokens)
		}
		.container_type {
			return parser.parse_container_type_value(mut tokens)
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape {
			return parser.parse_corner_shape_value(mut tokens)
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity, .stroke_opacity {
			return parser.parse_opacity_value(mut tokens)
		}
		.animation_timeline {
			return parser.parse_animation_timeline_value(mut tokens)
		}
		.animation_range, .animation_range_start, .animation_range_end {
			return parser.parse_animation_range_value(property_id, mut tokens)
		}
		.animation_timing_function {
			return parser.parse_animation_timing_function_value(mut tokens)
		}
		.aspect_ratio {
			return parser.parse_aspect_ratio_value(mut tokens)
		}
		.align_content {
			return parser.parse_align_content_value(mut tokens)
		}
		.align_items {
			return parser.parse_align_items_value(mut tokens)
		}
		.align_self {
			return parser.parse_align_self_value(mut tokens)
		}
		.appearance {
			return parser.parse_appearance_value(mut tokens)
		}
		.background_image, .mask_image {
			return parser.parse_image_or_none_list_value(mut tokens)
		}
		.font_feature_settings {
			return parser.parse_font_feature_settings_value(mut tokens)
		}
		.font_kerning {
			return parser.parse_font_kerning_value(mut tokens)
		}
		.webkit_font_smoothing {
			return parser.parse_webkit_font_smoothing_value(mut tokens)
		}
		.font_language_override {
			return parser.parse_font_language_override_value(mut tokens)
		}
		.font_optical_sizing {
			return parser.parse_font_optical_sizing_value(mut tokens)
		}
		.font_style {
			return parser.parse_font_style_value(mut tokens)
		}
		.font_variant_caps {
			return parser.parse_font_variant_caps_value(mut tokens)
		}
		.font_variant_emoji {
			return parser.parse_font_variant_emoji_value(mut tokens)
		}
		.font_variant_position {
			return parser.parse_font_variant_position_value(mut tokens)
		}
		.font_variation_settings {
			return parser.parse_font_variation_settings_value(mut tokens)
		}
		.font_weight {
			return parser.parse_font_weight_value(mut tokens)
		}
		.font_width {
			return parser.parse_font_width_value(mut tokens)
		}
		.flex_direction {
			return parser.parse_flex_direction_value(mut tokens)
		}
		.flex_wrap {
			return parser.parse_flex_wrap_value(mut tokens)
		}
		.column_span {
			return parser.parse_column_span_value(mut tokens)
		}
		.column_count {
			return parser.parse_auto_or_positive_integer_value(mut tokens)
		}
		.column_width, .column_height {
			return parser.parse_auto_or_nonnegative_length_value(mut tokens)
		}
		.column_gap, .row_gap {
			return parser.parse_gap_value(mut tokens)
		}
		.flex_grow, .flex_shrink {
			return parser.parse_nonnegative_number_value(mut tokens)
		}
		.image_rendering {
			return parser.parse_image_rendering_value(mut tokens)
		}
		.justify_content {
			return parser.parse_justify_content_value(mut tokens)
		}
		.justify_items {
			return parser.parse_justify_items_value(mut tokens)
		}
		.justify_self {
			return parser.parse_justify_self_value(mut tokens)
		}
		.isolation {
			return parser.parse_isolation_value(mut tokens)
		}
		.letter_spacing, .word_spacing {
			return parser.parse_letter_or_word_spacing_value(mut tokens)
		}
		.line_height {
			return parser.parse_line_height_value(mut tokens)
		}
		.list_style_position {
			return parser.parse_list_style_position_value(mut tokens)
		}
		.order {
			return parser.parse_integer_value(mut tokens)
		}
		.orphans, .widows {
			return parser.parse_positive_integer_value(mut tokens)
		}
		.border_image_source, .list_style_image {
			return parser.parse_image_or_none_value(mut tokens)
		}
		.caption_side {
			return parser.parse_caption_side_value(mut tokens)
		}
		.clear {
			return parser.parse_clear_value(mut tokens)
		}
		.clip_rule {
			return parser.parse_fill_rule_value(mut tokens)
		}
		.color_interpolation, .color_interpolation_filters {
			return parser.parse_color_interpolation_value(mut tokens)
		}
		.d {
			mut keyword_attempt := tokens.clone()
			if value := parse_property_keyword_value(mut keyword_attempt, ['none']) {
				tokens = keyword_attempt
				return value
			}
			value := parser.parse_basic_shape_value(mut tokens) or { return none }
			if value is BasicShapeStyleValue && value.basic_shape() is BasicShapePath {
				return value
			}
			return none
		}
		.direction {
			return parser.parse_direction_value(mut tokens)
		}
		.empty_cells {
			return parser.parse_empty_cells_value(mut tokens)
		}
		.fill_rule {
			return parser.parse_fill_rule_value(mut tokens)
		}
		.float_ {
			return parser.parse_float_value(mut tokens)
		}
		.dominant_baseline {
			return parser.parse_dominant_baseline_value(mut tokens)
		}
		.display {
			return parser.parse_display_value(mut tokens)
		}
		.flex_basis {
			return parser.parse_flex_basis_value(mut tokens)
		}
		.quotes {
			return parser.parse_quotes_value(mut tokens)
		}
		.box_shadow {
			return parser.parse_box_shadow_value(mut tokens)
		}
		.text_shadow {
			return parser.parse_text_shadow_value(mut tokens)
		}
		.list_style_type {
			return parser.parse_list_style_type_value(mut tokens)
		}
		.clip {
			return parser.parse_clip_value(mut tokens)
		}
		.stroke_dasharray {
			return parser.parse_stroke_dasharray_value(mut tokens)
		}
		.font_family {
			return parser.parse_font_family_value(mut tokens)
		}
		.grid_column_start, .grid_column_end, .grid_row_start, .grid_row_end {
			return parser.parse_grid_track_placement(mut tokens)
		}
		.grid_auto_flow {
			return parser.parse_grid_auto_flow_value(mut tokens)
		}
		.grid_auto_columns, .grid_auto_rows {
			return parser.parse_grid_auto_track_sizes(mut tokens)
		}
		.grid_template_columns, .grid_template_rows {
			return parser.parse_grid_track_size_list(mut tokens)
		}
		.grid_template_areas {
			return parser.parse_grid_template_areas_value(mut tokens)
		}
		.filter, .backdrop_filter {
			return parser.parse_filter_value_list_value(mut tokens)
		}
		.counter_increment {
			return parser.parse_counter_increment_value(mut tokens)
		}
		.counter_reset {
			return parser.parse_counter_reset_value(mut tokens)
		}
		.counter_set {
			return parser.parse_counter_set_value(mut tokens)
		}
		.cursor {
			return parser.parse_cursor_value(mut tokens)
		}
		.font_size {
			return parser.parse_font_size_value(mut tokens)
		}
		.fill, .stroke {
			return parser.parse_paint_value(mut tokens)
		}
		.font_variant_ligatures {
			return parser.parse_font_variant_ligatures_value(mut tokens)
		}
		.font_variant_numeric {
			return parser.parse_font_variant_numeric_value(mut tokens)
		}
		.font_variant_east_asian {
			return parser.parse_font_variant_east_asian_value(mut tokens)
		}
		.clip_path {
			return parser.parse_clip_path_value(mut tokens)
		}
		.shape_outside {
			return parser.parse_shape_outside_value(mut tokens)
		}
		.content {
			return parser.parse_content_value(mut tokens)
		}
		.font_variant_alternates {
			return parser.parse_font_variant_alternates_value(mut tokens)
		}
		.overflow {
			return parser.parse_overflow_shorthand(mut tokens)
		}
		.gap {
			return parser.parse_gap_shorthand(mut tokens)
		}
		.place_items {
			return parser.parse_place_items_value(mut tokens)
		}
		.place_content {
			return parser.parse_place_content_value(mut tokens)
		}
		.place_self {
			return parser.parse_place_self_value(mut tokens)
		}
		.flex_flow {
			return parser.parse_flex_flow_value(mut tokens)
		}
		.columns {
			return parser.parse_columns_value(mut tokens)
		}
		.text_wrap {
			return parser.parse_text_wrap_shorthand(mut tokens)
		}
		.margin {
			return parser.parse_margin_shorthand(mut tokens)
		}
		.padding {
			return parser.parse_padding_shorthand(mut tokens)
		}
		.inset {
			return parser.parse_inset_shorthand(mut tokens)
		}
		.margin_block {
			return parser.parse_margin_block_shorthand(mut tokens)
		}
		.margin_inline {
			return parser.parse_margin_inline_shorthand(mut tokens)
		}
		.padding_block {
			return parser.parse_padding_block_shorthand(mut tokens)
		}
		.padding_inline {
			return parser.parse_padding_inline_shorthand(mut tokens)
		}
		.scroll_margin {
			return parser.parse_scroll_margin_shorthand(mut tokens)
		}
		.scroll_margin_block {
			return parser.parse_scroll_margin_block_shorthand(mut tokens)
		}
		.scroll_margin_inline {
			return parser.parse_scroll_margin_inline_shorthand(mut tokens)
		}
		.scroll_padding {
			return parser.parse_scroll_padding_shorthand(mut tokens)
		}
		.scroll_padding_block {
			return parser.parse_scroll_padding_block_shorthand(mut tokens)
		}
		.scroll_padding_inline {
			return parser.parse_scroll_padding_inline_shorthand(mut tokens)
		}
		.inset_block {
			return parser.parse_inset_block_shorthand(mut tokens)
		}
		.inset_inline {
			return parser.parse_inset_inline_shorthand(mut tokens)
		}
		.border_color {
			return parser.parse_border_color_shorthand(mut tokens)
		}
		.border_style {
			return parser.parse_border_style_shorthand(mut tokens)
		}
		.border_width {
			return parser.parse_border_width_shorthand(mut tokens)
		}
		.border_block_color {
			return parser.parse_border_block_color_shorthand(mut tokens)
		}
		.border_inline_color {
			return parser.parse_border_inline_color_shorthand(mut tokens)
		}
		.border_block_style {
			return parser.parse_border_block_style_shorthand(mut tokens)
		}
		.border_inline_style {
			return parser.parse_border_inline_style_shorthand(mut tokens)
		}
		.border_block_width {
			return parser.parse_border_block_width_shorthand(mut tokens)
		}
		.border_inline_width {
			return parser.parse_border_inline_width_shorthand(mut tokens)
		}
		.border_top {
			return parser.parse_border_top_shorthand(mut tokens)
		}
		.border_right {
			return parser.parse_border_right_shorthand(mut tokens)
		}
		.border_bottom {
			return parser.parse_border_bottom_shorthand(mut tokens)
		}
		.border_left {
			return parser.parse_border_left_shorthand(mut tokens)
		}
		.border_block_start {
			return parser.parse_border_block_start_shorthand(mut tokens)
		}
		.border_block_end {
			return parser.parse_border_block_end_shorthand(mut tokens)
		}
		.border_inline_start {
			return parser.parse_border_inline_start_shorthand(mut tokens)
		}
		.border_inline_end {
			return parser.parse_border_inline_end_shorthand(mut tokens)
		}
		.border {
			return parser.parse_border_value(.border, mut tokens)
		}
		.border_block {
			return parser.parse_border_value(.border_block, mut tokens)
		}
		.border_inline {
			return parser.parse_border_value(.border_inline, mut tokens)
		}
		.outline {
			return parser.parse_outline_shorthand(mut tokens)
		}
		.column_rule {
			return parser.parse_column_rule_shorthand(mut tokens)
		}
		.list_style {
			return parser.parse_list_style_value(mut tokens)
		}
		.text_decoration {
			return parser.parse_text_decoration_value(mut tokens)
		}
		.font_variant {
			return parser.parse_font_variant(mut tokens)
		}
		.font_synthesis {
			return parser.parse_font_synthesis(mut tokens)
		}
		.font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position {
			return parse_property_keyword_value_from_metadata(property_id, mut tokens)
		}
		.flex {
			return parser.parse_flex_shorthand_value(mut tokens)
		}
		.corner_shape {
			return parser.parse_corner_shape_shorthand(mut tokens)
		}
		.corner_top_shape {
			return parser.parse_corner_top_shape_shorthand(mut tokens)
		}
		.corner_bottom_shape {
			return parser.parse_corner_bottom_shape_shorthand(mut tokens)
		}
		.corner_left_shape {
			return parser.parse_corner_left_shape_shorthand(mut tokens)
		}
		.corner_right_shape {
			return parser.parse_corner_right_shape_shorthand(mut tokens)
		}
		.corner_block_start_shape {
			return parser.parse_corner_block_start_shape_shorthand(mut tokens)
		}
		.corner_block_end_shape {
			return parser.parse_corner_block_end_shape_shorthand(mut tokens)
		}
		.corner_inline_start_shape {
			return parser.parse_corner_inline_start_shape_shorthand(mut tokens)
		}
		.corner_inline_end_shape {
			return parser.parse_corner_inline_end_shape_shorthand(mut tokens)
		}
		.grid_row {
			return parser.parse_grid_track_placement_shorthand_value(.grid_row, mut tokens)
		}
		.grid_column {
			return parser.parse_grid_track_placement_shorthand_value(.grid_column, mut tokens)
		}
		.grid_area {
			return parser.parse_grid_area_shorthand_value(mut tokens)
		}
		.white_space {
			return parser.parse_white_space_shorthand(mut tokens)
		}
		.overflow_clip_margin {
			return parser.parse_overflow_clip_margin_shorthand(mut tokens, .overflow_clip_margin, [
				PropertyID.overflow_clip_margin_top,
				PropertyID.overflow_clip_margin_right,
				PropertyID.overflow_clip_margin_bottom,
				PropertyID.overflow_clip_margin_left,
			])
		}
		.overflow_clip_margin_block {
			return parser.parse_overflow_clip_margin_shorthand(mut tokens, .overflow_clip_margin_block, [
				PropertyID.overflow_clip_margin_block_start,
				PropertyID.overflow_clip_margin_block_end,
			])
		}
		.overflow_clip_margin_inline {
			return parser.parse_overflow_clip_margin_shorthand(mut tokens, .overflow_clip_margin_inline, [
				PropertyID.overflow_clip_margin_inline_start,
				PropertyID.overflow_clip_margin_inline_end,
			])
		}
		.all {
			// `all` only accepts the CSS-wide keywords, which are handled before this dispatch.
			return none
		}
		.border_radius {
			return parser.parse_border_radius_shorthand_value(mut tokens)
		}
		.transition {
			return parser.parse_transition_value(mut tokens)
		}
		.animation {
			return parser.parse_animation_value(mut tokens)
		}
		.scroll_timeline {
			return parser.parse_scroll_timeline_value(mut tokens)
		}
		.view_timeline {
			return parser.parse_view_timeline_value(mut tokens)
		}
		.border_image {
			return parser.parse_border_image_value(mut tokens)
		}
		.background_position {
			return parser.parse_background_position_value(mut tokens)
		}
		.grid_template {
			return parser.parse_grid_track_size_list_shorthand_value(.grid_template, mut tokens, false)
		}
		.grid {
			return parser.parse_grid_shorthand_value(mut tokens)
		}
		.font {
			return parser.parse_font_value(mut tokens)
		}
		.background {
			return parser.parse_background_value(mut tokens)
		}
		.mask {
			return parser.parse_mask_value(mut tokens)
		}
		.math_depth {
			return parser.parse_math_depth_value(mut tokens)
		}
		.math_shift {
			return parser.parse_math_shift_value(mut tokens)
		}
		.math_style {
			return parser.parse_math_style_value(mut tokens)
		}
		.mask_type {
			return parser.parse_mask_type_value(mut tokens)
		}
		.mask_composite {
			return parser.parse_mask_composite_value(mut tokens)
		}
		.mask_clip {
			return parser.parse_mask_clip_value(mut tokens)
		}
		.mask_mode {
			return parser.parse_mask_mode_value(mut tokens)
		}
		.mask_origin {
			return parser.parse_mask_origin_value(mut tokens)
		}
		.mask_position {
			return parser.parse_position_list_value(mut tokens, .normal)
		}
		.mask_repeat {
			return parser.parse_repeat_style_list_value(.mask_repeat, mut tokens)
		}
		.mask_size {
			return parser.parse_background_size_list_value(.mask_size, mut tokens)
		}
		.mix_blend_mode {
			return parser.parse_mix_blend_mode_value(mut tokens)
		}
		.object_fit {
			return parser.parse_object_fit_value(mut tokens)
		}
		.rotate {
			return parser.parse_rotate_value(mut tokens)
		}
		.scale {
			return parser.parse_scale_value(mut tokens)
		}
		.scrollbar_color {
			return parser.parse_scrollbar_color_value(mut tokens)
		}
		.scrollbar_gutter {
			return parser.parse_scrollbar_gutter_value(mut tokens)
		}
		.scrollbar_width {
			return parser.parse_scrollbar_width_value(mut tokens)
		}
		.shape_rendering {
			return parser.parse_shape_rendering_value(mut tokens)
		}
		.shape_margin, .r {
			return parser.parse_nonnegative_length_percentage_value(mut tokens)
		}
		.cx, .cy, .x, .y {
			return parser.parse_length_percentage_value(mut tokens)
		}
		.rx, .ry {
			return parser.parse_auto_or_nonnegative_length_percentage_value(mut tokens)
		}
		.scroll_timeline_name {
			return parser.parse_timeline_name_value(mut tokens)
		}
		.scroll_timeline_axis, .view_timeline_axis {
			return parser.parse_timeline_axis_value(mut tokens)
		}
		.scroll_behavior {
			return parser.parse_scroll_behavior_value(mut tokens)
		}
		.scroll_snap_align {
			return parser.parse_scroll_snap_align_value(mut tokens)
		}
		.scroll_snap_stop {
			return parser.parse_scroll_snap_stop_value(mut tokens)
		}
		.scroll_snap_type {
			return parser.parse_scroll_snap_type_value(mut tokens)
		}
		.stroke_linecap {
			return parser.parse_stroke_linecap_value(mut tokens)
		}
		.stroke_linejoin {
			return parser.parse_stroke_linejoin_value(mut tokens)
		}
		.stroke_miterlimit {
			return parser.parse_nonnegative_number_value(mut tokens)
		}
		.stroke_width, .stroke_dashoffset {
			return parser.parse_nonnegative_number_or_length_percentage_value(mut tokens)
		}
		.table_layout {
			return parser.parse_table_layout_value(mut tokens)
		}
		.tab_size {
			return parser.parse_tab_size_value(mut tokens)
		}
		.text_align {
			return parser.parse_text_align_value(mut tokens)
		}
		.text_anchor {
			return parser.parse_text_anchor_value(mut tokens)
		}
		.text_decoration_line {
			return parser.parse_text_decoration_line_value(mut tokens)
		}
		.text_decoration_skip_ink {
			return parse_property_keyword_value(mut tokens, ['all', 'auto', 'none'])
		}
		.text_decoration_style {
			return parser.parse_text_decoration_style_value(mut tokens)
		}
		.text_decoration_color {
			return parser.parse_color_value(mut tokens)
		}
		.text_decoration_thickness {
			return parser.parse_text_decoration_thickness_value(mut tokens)
		}
		.text_underline_offset {
			return parser.parse_auto_or_length_percentage_value(mut tokens)
		}
		.text_underline_position {
			return parser.parse_text_underline_position_value(mut tokens)
		}
		.text_indent {
			return parser.parse_text_indent_value(mut tokens)
		}
		.text_justify {
			return parser.parse_text_justify_value(mut tokens)
		}
		.text_overflow {
			return parser.parse_text_overflow_value(mut tokens)
		}
		.text_rendering {
			return parser.parse_text_rendering_value(mut tokens)
		}
		.text_transform {
			return parser.parse_text_transform_value(mut tokens)
		}
		.text_wrap_mode {
			return parser.parse_text_wrap_mode_value(mut tokens)
		}
		.text_wrap_style {
			return parser.parse_text_wrap_style_value(mut tokens)
		}
		.text_box_trim {
			return parse_property_keyword_value(mut tokens, ['none', 'trim-start', 'trim-end', 'trim-both'])
		}
		.text_box_edge {
			return parser.parse_text_box_edge(mut tokens)
		}
		.transform {
			return parser.parse_transform_value(mut tokens)
		}
		.transform_box {
			return parser.parse_transform_box_value(mut tokens)
		}
		.transform_origin {
			return parser.parse_transform_origin_value(mut tokens)
		}
		.transform_style {
			return parser.parse_transform_style_value(mut tokens)
		}
		.backface_visibility {
			return parser.parse_backface_visibility_value(mut tokens)
		}
		.transition_behavior {
			return parser.parse_transition_behavior_value(mut tokens)
		}
		.transition_delay {
			return parser.parse_transition_time_list_value(mut tokens, false)
		}
		.transition_duration {
			return parser.parse_transition_time_list_value(mut tokens, true)
		}
		.transition_property {
			return parser.parse_transition_property_value(mut tokens)
		}
		.transition_timing_function {
			return parser.parse_transition_timing_function_value(mut tokens)
		}
		.translate {
			return parser.parse_translate_value(mut tokens)
		}
		.timeline_scope {
			return parser.parse_timeline_scope_value(mut tokens)
		}
		.touch_action {
			return parser.parse_touch_action_value(mut tokens)
		}
		.unicode_bidi {
			return parser.parse_unicode_bidi_value(mut tokens)
		}
		.user_select {
			return parser.parse_user_select_value(mut tokens)
		}
		.vector_effect {
			return parse_property_keyword_value(mut tokens, ['none', 'non-scaling-stroke'])
		}
		.view_timeline_inset {
			return parser.parse_view_timeline_inset_list_value(mut tokens)
		}
		.view_timeline_name {
			return parser.parse_timeline_name_value(mut tokens)
		}
		.view_transition_name {
			return parser.parse_view_transition_name_value(mut tokens)
		}
		.visibility {
			return parser.parse_visibility_value(mut tokens)
		}
		.vertical_align {
			return parser.parse_vertical_align_value(mut tokens)
		}
		.will_change {
			return parser.parse_will_change_value(mut tokens)
		}
		.writing_mode {
			return parser.parse_writing_mode_value(mut tokens)
		}
		.white_space_collapse {
			return parser.parse_white_space_collapse_value(mut tokens)
		}
		.white_space_trim {
			return parser.parse_white_space_trim_value(mut tokens)
		}
		.word_break {
			return parser.parse_word_break_value(mut tokens)
		}
		.hyphens {
			return parse_property_keyword_value(mut tokens, ['none', 'manual', 'auto'])
		}
		.z_index {
			return parser.parse_z_index_value(mut tokens)
		}
		.resize {
			return parser.parse_resize_value(mut tokens)
		}
	}

	return none
}

// https://drafts.csswg.org/css-break-3/#page-break-properties
fn (mut parser Parser) parse_page_break_legacy_shorthand(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component := tokens.consume() or { return none }
	if !component.is(.ident) {
		return none
	}
	longhand := match property_id {
		.page_break_after { PropertyID.break_after }
		.page_break_before { PropertyID.break_before }
		.page_break_inside { PropertyID.break_inside }
		else {
			return none
		}
	}
	ident := to_ascii_lowercase(component.token().ident())
	keyword := match ident {
		'auto' { Keyword.auto }
		'avoid' { Keyword.avoid }
		'always' {
			if longhand == .break_inside {
				return none
			}
			Keyword.page
		}
		'left' {
			if longhand == .break_inside {
				return none
			}
			Keyword.left
		}
		'right' {
			if longhand == .break_inside {
				return none
			}
			Keyword.right
		}
		else {
			return none
		}
	}
	return StyleValue(ShorthandStyleValue.create(property_id, [longhand], [
		StyleValue(KeywordStyleValue.create(keyword)),
	]))
}

fn (mut parser Parser) parse_block_ellipsis_value(mut tokens ComponentValueStream) ?StyleValue {
	mut keyword_attempt := tokens.clone()
	if value := parse_property_keyword_value_from_metadata(.block_ellipsis, mut keyword_attempt) {
		tokens = keyword_attempt
		return value
	}
	if value := parser.parse_string_value(mut tokens) {
		return StyleValue(value)
	}
	return none
}

fn (mut parser Parser) parse_max_lines_value(mut tokens ComponentValueStream) ?StyleValue {
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}
	mut integer_attempt := tokens.clone()
	value := parser.parse_integer_value(mut integer_attempt) or { return none }
	if value is IntegerStyleValue && value.integer() >= 1 {
		tokens = integer_attempt
		return value
	}
	return none
}

// https://drafts.csswg.org/css-overflow-4/#line-clamp
// none | [ <integer [1,inf]> || <'block-ellipsis'> ] -webkit-legacy?
fn (mut parser Parser) parse_line_clamp_shorthand(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	if property_id !in [.line_clamp, .webkit_line_clamp] {
		return none
	}
	mut none_attempt := tokens.clone()
	if _ := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return StyleValue(ShorthandStyleValue.create(property_id, [
			PropertyID.max_lines,
			.block_ellipsis,
			.continue_,
		], [
			parser.longhand_initial_typed_value(.max_lines) or { return none },
			parser.longhand_initial_typed_value(.block_ellipsis) or { return none },
			parser.longhand_initial_typed_value(.continue_) or { return none },
		]))
	}

	if property_id == .webkit_line_clamp {
		value := parser.parse_max_lines_value(mut tokens) or { return none }
		if value.to_keyword() == .none_ {
			return none
		}
		return StyleValue(ShorthandStyleValue.create(property_id, [
			PropertyID.max_lines,
			.block_ellipsis,
			.continue_,
		], [
			value,
			StyleValue(KeywordStyleValue.create(.auto)),
			StyleValue(KeywordStyleValue.create(.webkit_legacy)),
		]))
	}

	mut transaction := tokens.clone()
	mut max_lines := ?StyleValue(none)
	mut block_ellipsis := ?StyleValue(none)
	mut use_webkit_legacy := false
	mut component_count := 0
	for {
		transaction.consume_whitespace()
		peek := transaction.peek() or { break }
		if peek.is(.ident)
			&& equals_ignoring_ascii_case(peek.token().ident(), '-webkit-legacy') {
			transaction.consume()
			transaction.consume_whitespace()
			if component_count == 0 || transaction.has_more_tokens() {
				return none
			}
			use_webkit_legacy = true
			break
		}
		if max_lines == none {
			mut attempt := transaction.clone()
			if value := parser.parse_max_lines_value(mut attempt) {
				if value.to_keyword() != .none_ {
					max_lines = value
					transaction = attempt
					component_count++
					continue
				}
			}
		}
		if block_ellipsis == none {
			mut attempt := transaction.clone()
			if value := parser.parse_block_ellipsis_value(mut attempt) {
				block_ellipsis = value
				transaction = attempt
				component_count++
				continue
			}
		}
		return none
	}
	if component_count == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(property_id, [PropertyID.max_lines, .block_ellipsis,
		.continue_], [
		max_lines or { parser.longhand_initial_typed_value(.max_lines) or { return none } },
		block_ellipsis or { StyleValue(KeywordStyleValue.create(.auto)) },
		StyleValue(KeywordStyleValue.create(if use_webkit_legacy {
			Keyword.webkit_legacy
		} else {
			Keyword.collapse
		})),
	]))
}

fn parse_css_wide_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	// Use a transaction so the tokens are only consumed on success; otherwise a
	// failed CSS-wide-keyword probe would swallow the first token of the value.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	keyword := keyword_from_string(token.token().ident()) or { return none }
	if !keyword.is_css_wide_keyword() {
		return none
	}
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_builtin_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	component_value := transaction.consume() or { return none }
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if keyword := keyword_from_string(ident) {
			if keyword.is_css_wide_keyword() {
				tokens = transaction
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
	}
	return none
}

// https://www.w3.org/TR/css-values-4/#typedefs
fn (mut parser Parser) parse_value(type_ ValueType, mut tokens ComponentValueStream) ?StyleValue {
	return match type_ {
		.anchor {
			parser.parse_anchor(mut tokens)
		}
		.anchor_size {
			parser.parse_anchor_size(mut tokens)
		}
		.angle {
			parser.parse_angle_value(mut tokens)
		}
		.angle_percentage {
			parser.parse_angle_percentage_value(mut tokens)
		}
		.background_position {
			parser.parse_css_position_value(mut tokens, .background_position)
		}
		.basic_shape {
			parser.parse_basic_shape_value(mut tokens)
		}
		.color {
			parser.parse_color_value(mut tokens)
		}
		.corner_shape {
			parser.parse_corner_shape_value(mut tokens)
		}
		.counter {
			parser.parse_counter_value(mut tokens)
		}
		.counter_style {
			if value := parser.parse_counter_style_value(mut tokens) {
				StyleValue(value)
			} else {
				none
			}
		}
		.custom_ident {
			if value := parser.parse_custom_ident_value(mut tokens, []) {
				StyleValue(value)
			} else {
				none
			}
		}
		.dashed_ident {
			parser.parse_dashed_ident_value(mut tokens, [])
		}
		.easing_function {
			parser.parse_easing_value(mut tokens)
		}
		.filter_value_list {
			parser.parse_filter_value_list_value(mut tokens)
		}
		.fit_content {
			parser.parse_fit_content_value(mut tokens)
		}
		.flex {
			parser.parse_flex_value(mut tokens)
		}
		.font_style {
			parser.parse_font_style_value(mut tokens)
		}
		.font_variant_alternates {
			parser.parse_font_variant_alternates_value(mut tokens)
		}
		.font_variant_east_asian {
			parser.parse_font_variant_east_asian_value(mut tokens)
		}
		.font_variant_ligatures {
			parser.parse_font_variant_ligatures_value(mut tokens)
		}
		.font_variant_numeric {
			parser.parse_font_variant_numeric_value(mut tokens)
		}
		.frequency {
			parser.parse_frequency_value(mut tokens)
		}
		.frequency_percentage {
			parser.parse_frequency_percentage_value(mut tokens)
		}
		.image {
			if value := parser.parse_image_value(mut tokens) {
				style_value_from_css_image_source_for_value_logic(value)
			} else {
				none
			}
		}
		.integer {
			parser.parse_integer_value(mut tokens)
		}
		.length {
			parser.parse_length_value(mut tokens)
		}
		.length_percentage {
			parser.parse_length_percentage_value(mut tokens)
		}
		.number {
			parser.parse_number_value(mut tokens)
		}
		.opacity {
			parser.parse_opacity_value(mut tokens)
		}
		.opentype_tag {
			if value := parser.parse_opentype_tag_value(mut tokens) {
				StyleValue(value)
			} else {
				none
			}
		}
		.paint {
			parser.parse_paint_value(mut tokens)
		}
		.percentage {
			parser.parse_percentage_value(mut tokens)
		}
		.position {
			parser.parse_css_position_value(mut tokens, .normal)
		}
		.ratio {
			parser.parse_ratio_value(mut tokens)
		}
		.rect {
			parser.parse_rect_value(mut tokens)
		}
		.resolution {
			parser.parse_resolution_value(mut tokens)
		}
		.scroll_function {
			mut transaction := tokens.clone()
			transaction.consume_whitespace()
			component_value := transaction.consume() or { return none }
			value := parser.parse_scroll_function_value(component_value) or { return none }
			tokens = transaction
			StyleValue(value)
		}
		.string {
			if value := parser.parse_string_value(mut tokens) {
				StyleValue(value)
			} else {
				none
			}
		}
		.time {
			parser.parse_time_value(mut tokens)
		}
		.time_percentage {
			parser.parse_time_percentage_value(mut tokens)
		}
		.transform_function {
			parser.parse_transform_function_value(mut tokens)
		}
		.transform_list {
			parser.parse_transform_list_value(mut tokens)
		}
		.url {
			parser.parse_url_value(mut tokens)
		}
		.view_function {
			mut transaction := tokens.clone()
			transaction.consume_whitespace()
			component_value := transaction.consume() or { return none }
			value := parser.parse_view_function_value(component_value) or { return none }
			tokens = transaction
			StyleValue(value)
		}
		.view_timeline_inset {
			parser.parse_view_timeline_inset_value(mut tokens)
		}
	}
}

pub fn (mut parser Parser) parse_as_type(type_ ValueType) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_value(type_, mut tokens)
}

pub fn (mut parser Parser) parse_entirely_as_type(type_ ValueType) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_value(type_, mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn (mut stream ComponentValueStream) consume_remaining_component_values() []ComponentValue {
	remaining_values := stream.values[stream.index..].clone()
	stream.index = stream.values.len
	return remaining_values
}

fn parse_animation_keyword_list_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut keywords := []StyleValue{}
	for value in values {
		mut keyword_tokens := ComponentValueStream.new(value)
		keyword_tokens.consume_whitespace()
		token := keyword_tokens.consume() or { return none }
		if !token.is(.ident) {
			return none
		}
		keyword_text := to_ascii_lowercase(token.token().ident())
		if keyword_text !in allowed_keywords {
			return none
		}
		keyword := keyword_from_string(keyword_text) or { return none }
		keyword_tokens.consume_whitespace()
		if keyword_tokens.has_more_tokens() {
			return none
		}
		keywords << StyleValue(KeywordStyleValue.create(keyword))
	}

	if keywords.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(keywords, .comma, .yes))
}

fn (mut parser Parser) parse_animation_composition_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-2/#animation-composition
	// replace | add | accumulate
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['replace', 'add', 'accumulate'])
}

fn (mut parser Parser) parse_animation_delay_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_transition_time_list_value(mut tokens, false)
}

fn (mut parser Parser) parse_animation_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-direction
	// normal | reverse | alternate | alternate-reverse
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['normal', 'reverse', 'alternate',
		'alternate-reverse'])
}

fn (mut parser Parser) parse_animation_duration_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-animations-2/#animation-duration
	// auto | <time [0s,∞]>
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut durations := []StyleValue{}
	for value in values {
		mut duration_tokens := ComponentValueStream.new(value)
		duration_tokens.consume_whitespace()
		if token := duration_tokens.peek() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'auto') {
				duration_tokens.consume()
				duration_tokens.consume_whitespace()
				if duration_tokens.has_more_tokens() {
					return none
				}
				durations << StyleValue(KeywordStyleValue.create(.auto))
				continue
			}
		}

		time_value := parser.parse_time_value(mut duration_tokens) or { return none }
		duration_tokens.consume_whitespace()
		if duration_tokens.has_more_tokens() {
			return none
		}
		if time_value is TimeStyleValue && time_value.time().to_seconds() < 0 {
			return none
		}
		durations << time_value
	}

	if durations.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(durations, .comma, .yes))
}

fn (mut parser Parser) parse_animation_fill_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-fill-mode
	// none | forwards | backwards | both
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['none', 'forwards', 'backwards',
		'both'])
}

fn (mut parser Parser) parse_animation_iteration_count_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-animations-1/#animation-iteration-count
	// infinite | <number [0,∞]>
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut iteration_counts := []StyleValue{}
	for value in values {
		mut iteration_tokens := ComponentValueStream.new(value)
		iteration_tokens.consume_whitespace()
		if token := iteration_tokens.peek() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'infinite') {
				iteration_tokens.consume()
				iteration_tokens.consume_whitespace()
				if iteration_tokens.has_more_tokens() {
					return none
				}
				iteration_counts << StyleValue(KeywordStyleValue.create(.infinite))
				continue
			}
		}

		number_value := parser.parse_number_value(mut iteration_tokens) or { return none }
		iteration_tokens.consume_whitespace()
		if iteration_tokens.has_more_tokens() {
			return none
		}
		if number_value is NumberStyleValue && number_value.number() < 0 {
			return none
		}
		iteration_counts << number_value
	}

	if iteration_counts.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(iteration_counts, .comma, .yes))
}

fn (mut parser Parser) parse_animation_play_state_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-play-state
	// running | paused
	return parse_animation_keyword_list_for_value_logic(mut tokens, ['running', 'paused'])
}

fn (mut parser Parser) parse_animation_timing_function_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_transition_timing_function_value(mut tokens)
}

fn parse_animation_name_entry_for_value_logic(values []ComponentValue) ?StyleValue {
	mut tokens := ComponentValueStream.new(values)
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	result := if component_value.is(.ident) {
		ident := component_value.token().ident()
		if equals_ignoring_ascii_case(ident, 'none') {
			StyleValue(KeywordStyleValue.create(.none_))
		} else {
			StyleValue(CustomIdentStyleValue.create(ident))
		}
	} else if component_value.is(.string) {
		StyleValue(StringStyleValue.create(component_value.token().string_value()))
	} else {
		return none
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return result
}

fn (mut parser Parser) parse_animation_name_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-animations-1/#animation-name
	// list, each item either a case-sensitive css identifier or the keyword none
	mut transaction := tokens.clone()
	name_values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut names := []StyleValue{}
	for values in name_values {
		names << (parse_animation_name_entry_for_value_logic(values) or { return none })
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(names, .comma, .yes))
}

fn (mut parser Parser) parse_aspect_ratio_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://www.w3.org/TR/css-sizing-4/#aspect-ratio
	// `auto || <ratio>`
	mut transaction := tokens.clone()
	mut auto_value := ?StyleValue(none)
	mut ratio_value := ?StyleValue(none)
	mut auto_value_set := false
	mut ratio_value_set := false

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		mut value_transaction := transaction.clone()
		if value := parser.parse_ratio_value(mut value_transaction) {
			if ratio_value_set {
				return none
			}
			ratio_value = value
			ratio_value_set = true
			transaction = value_transaction
			continue
		}

		value_transaction = transaction.clone()
		if value := parser.parse_keyword_value(mut value_transaction) {
			if value.to_keyword() == .auto {
				if auto_value_set {
					return none
				}
				auto_value = value
				auto_value_set = true
				transaction = value_transaction
				continue
			}
		}

		return none
	}

	if resolved_auto := auto_value {
		if resolved_ratio := ratio_value {
			tokens = transaction
			return StyleValue(StyleValueList.create([resolved_auto, resolved_ratio], .space, .yes))
		}
		tokens = transaction
		return resolved_auto
	}

	if resolved_ratio := ratio_value {
		tokens = transaction
		return resolved_ratio
	}

	return none
}

// PropertyParsing.cpp: Parser::parse_all_as_single_keyword_value.
fn (mut parser Parser) parse_all_as_single_keyword_value(mut tokens ComponentValueStream, keyword Keyword) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) || !equals_ignoring_ascii_case(token.token().ident(), string_from_keyword(keyword)) {
		return none
	}
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

// https://www.w3.org/TR/css-values-4/#typedef-dashed-ident
fn (mut parser Parser) parse_dashed_ident(mut tokens ComponentValueStream) ?string {
	mut transaction := tokens.clone()
	custom_ident := parser.parse_custom_ident(mut transaction, []) or { return none }
	if !custom_ident.starts_with('--') {
		return none
	}
	tokens = transaction
	return custom_ident
}

fn (mut parser Parser) parse_dashed_ident_value(mut tokens ComponentValueStream, blacklist []string) ?StyleValue {
	if blacklist.len == 0 {
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		custom_ident := parser.parse_dashed_ident(mut transaction) or { return none }
		tokens = transaction
		return StyleValue(CustomIdentStyleValue.create(custom_ident))
	}

	value := parser.parse_custom_ident_value(mut tokens, blacklist) or { return none }
	if !value.custom_ident().starts_with('--') {
		return none
	}
	return StyleValue(value)
}

fn (mut parser Parser) parse_dashed_ident_comma_list_value(mut tokens ComponentValueStream, blacklist []string) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut idents := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		ident := parser.parse_dashed_ident_value(mut item_tokens, blacklist) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		idents << ident
	}

	if idents.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(idents, .comma, .yes))
}

fn (mut parser Parser) parse_anchor_name_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#name
	// none | <dashed-ident>#
	if none_value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return none_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none'])
}

fn (mut parser Parser) parse_anchor_scope_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#anchor-scope
	// none | all | <dashed-ident>#
	if none_value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return none_value
	}

	if all_value := parser.parse_all_as_single_keyword_value(mut tokens, .all) {
		return all_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none', 'all'])
}

fn (mut parser Parser) parse_position_anchor_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-anchor-position/#position-anchor
	// normal | none | auto | <anchor-name>
	if normal_value := parser.parse_all_as_single_keyword_value(mut tokens, .normal) {
		return normal_value
	}

	if none_value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return none_value
	}

	if auto_value := parser.parse_all_as_single_keyword_value(mut tokens, .auto) {
		return auto_value
	}

	// <anchor-name> = <dashed-ident>
	return parser.parse_dashed_ident_value(mut tokens, ['normal', 'none', 'auto'])
}

fn (mut parser Parser) parse_timeline_name_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <dashed-ident>#
	if none_value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return none_value
	}

	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none'])
}

fn (mut parser Parser) parse_view_timeline_inset_list_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut insets := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		inset := parser.parse_view_timeline_inset_value(mut item_tokens) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		insets << inset
	}

	if insets.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(insets, .comma, .yes))
}

fn (mut parser Parser) parse_transition_property_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-transitions/#transition-property-property
	// none | <single-transition-property>#
	mut none_transaction := tokens.clone()
	none_transaction.consume_whitespace()
	if none_token := none_transaction.consume() {
		if none_token.is(.ident) && equals_ignoring_ascii_case(none_token.token().ident(), 'none') {
			none_transaction.consume_whitespace()
			if !none_transaction.has_more_tokens() {
				tokens = none_transaction
				return StyleValue(StyleValueList.create([
					StyleValue(KeywordStyleValue.create(.none_)),
				], .comma, .yes))
			}
		}
	}

	mut transaction := tokens.clone()
	transition_property_values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut transition_properties := []StyleValue{}
	for value in transition_property_values {
		mut transition_property_tokens := ComponentValueStream.new(value)
		custom_ident := parser.parse_custom_ident_value(mut transition_property_tokens, [
			'none',
		]) or { return none }
		transition_property_tokens.consume_whitespace()
		if transition_property_tokens.has_more_tokens() {
			return none
		}
		transition_properties << StyleValue(custom_ident)
	}

	if transition_properties.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(transition_properties, .comma, .yes))
}

fn (mut parser Parser) parse_transition_time_list_value(mut tokens ComponentValueStream, non_negative bool) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut times := []StyleValue{}
	for value in values {
		mut time_tokens := ComponentValueStream.new(value)
		time_value := parser.parse_time_value(mut time_tokens) or { return none }
		time_tokens.consume_whitespace()
		if time_tokens.has_more_tokens() {
			return none
		}
		if non_negative && time_value is TimeStyleValue && time_value.time().to_seconds() < 0 {
			return none
		}
		times << time_value
	}

	if times.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(times, .comma, .yes))
}

fn parse_transition_timing_keyword(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	keyword := transition_timing_keyword_from_string(token.token().ident()) or { return none }

	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_transition_timing_function_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut timing_functions := []StyleValue{}
	for value in values {
		mut timing_tokens := ComponentValueStream.new(value)
		mut timing_function := ?StyleValue(none)
		if easing := parser.parse_easing_value(mut timing_tokens) {
			timing_function = easing
		} else if keyword := parse_transition_timing_keyword(mut timing_tokens) {
			timing_function = keyword
		} else {
			return none
		}
		timing_tokens.consume_whitespace()
		if timing_tokens.has_more_tokens() {
			return none
		}
		timing_functions << timing_function or { return none }
	}

	if timing_functions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(timing_functions, .comma, .yes))
}

fn (mut parser Parser) parse_transition_behavior_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut behaviors := []StyleValue{}
	for value in values {
		mut behavior_tokens := ComponentValueStream.new(value)
		behavior_tokens.consume_whitespace()
		token := behavior_tokens.consume() or { return none }
		if !token.is(.ident) {
			return none
		}
		keyword := transition_behavior_keyword_from_string(token.token().ident()) or { return none }

		behavior_tokens.consume_whitespace()
		if behavior_tokens.has_more_tokens() {
			return none
		}
		behaviors << StyleValue(KeywordStyleValue.create(keyword))
	}

	if behaviors.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(behaviors, .comma, .yes))
}

fn transition_timing_keyword_from_string(value string) ?Keyword {
	return match to_ascii_lowercase(value) {
		'linear' { Keyword.linear }
		'ease' { Keyword.ease }
		'ease-in' { Keyword.ease_in }
		'ease-out' { Keyword.ease_out }
		'ease-in-out' { Keyword.ease_in_out }
		else { none }
	}
}

fn transition_behavior_keyword_from_string(value string) ?Keyword {
	return match to_ascii_lowercase(value) {
		'normal' { Keyword.normal }
		'allow-discrete' { Keyword.allow_discrete }
		else { none }
	}
}

fn parse_keyword_as_custom_ident_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	// Use a transaction (commit only on success) and do NOT reject trailing tokens:
	// this is also used as a component parser inside shorthands (e.g. `thick` in
	// `outline: thick solid green`). Whole-value callers rely on the top-level
	// leftover-token check in parse_css_value_tokens.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed_keywords {
		return none
	}
	tokens = transaction
	return StyleValue(CustomIdentStyleValue.create(ident))
}

fn numeric_style_value_from_css_text_for_value_logic(text string) ?StyleValue {
	numeric_value := CSSNumericValue.parse(text) or { return none }
	return computed_interpolation_style_value_from_css_numeric_value(numeric_value)
}

// <line-width> = <length [0,inf]> | thin | medium | thick. The generic property
// parser rejects a length outside the declared range; a negative border or
// outline width is therefore not a valid declaration.
fn (mut parser Parser) parse_border_or_outline_width_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_length_value(mut transaction) {
		if property_accepts_parsed_numeric_value(property_id, .length, value) {
			tokens = transaction
			return value
		}
		return none
	}
	return parse_keyword_as_custom_ident_for_value_logic(mut tokens, ['thin', 'medium', 'thick'])
}

fn (mut parser Parser) parse_outline_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'none', 'dotted', 'dashed', 'solid',
		'double', 'groove', 'ridge', 'inset', 'outset'])
}

fn (mut parser Parser) parse_line_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'hidden', 'dotted', 'dashed', 'solid',
		'double', 'groove', 'ridge', 'inset', 'outset'])
}

fn (mut parser Parser) parse_overflow_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value_from_metadata(property_id, mut tokens)
}

fn (mut parser Parser) parse_overflow_wrap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['anywhere', 'break-word', 'normal'])
}

fn (mut parser Parser) parse_pointer_events_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value_from_metadata(.pointer_events, mut tokens)
}

fn (mut parser Parser) parse_clear_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'left', 'right', 'both', 'inline-start',
		'inline-end'])
}

fn (mut parser Parser) parse_float_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'left', 'right', 'inline-start',
		'inline-end'])
}

fn (mut parser Parser) parse_dominant_baseline_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'text-bottom', 'alphabetic',
		'ideographic', 'middle', 'central', 'mathematical', 'hanging', 'text-top'])
}

fn (mut parser Parser) parse_box_shadow_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_shadow_value(mut tokens, .normal)
}

fn (mut parser Parser) parse_text_shadow_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_shadow_value(mut tokens, .text)
}

// https://drafts.csswg.org/css-backgrounds/#propdef-box-shadow
// https://drafts.csswg.org/css-text-decor/#propdef-text-shadow
fn (mut parser Parser) parse_shadow_value(mut tokens ComponentValueStream, shadow_type ShadowType) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut shadows := []StyleValue{}
	for value in values {
		mut shadow_tokens := ComponentValueStream.new(value)
		shadow := parser.parse_single_shadow_value(mut shadow_tokens, shadow_type) or {
			return none
		}
		shadows << shadow
	}
	if shadows.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(shadows, .comma, .yes))
}

fn (mut parser Parser) parse_single_shadow_value(mut tokens ComponentValueStream, shadow_type ShadowType) ?StyleValue {
	mut transaction := tokens.clone()

	mut color := ?StyleValue(none)
	mut offset_x := ?StyleValue(none)
	mut offset_y := ?StyleValue(none)
	mut blur_radius := ?StyleValue(none)
	mut spread_distance := ?StyleValue(none)
	mut placement := ?ShadowPlacement(none)

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		if maybe_color := parser.parse_color_value(mut transaction) {
			if color != none {
				return none
			}
			color = maybe_color
			continue
		}

		if maybe_offset_x := parser.parse_length_value(mut transaction) {
			if offset_x != none {
				return none
			}
			offset_x = maybe_offset_x

			// Vertical offset is required.
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				return none
			}
			offset_y = parser.parse_length_value(mut transaction) or { return none }

			// Blur radius (optional).
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				break
			}
			parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.shadow_blur_radius))
			maybe_blur_value := parser.parse_length_value(mut transaction)
			parser.pop_temporary_value_parsing_context()
			maybe_blur := maybe_blur_value or { continue }
			if maybe_blur is LengthStyleValue && maybe_blur.raw_value() < 0 {
				return none
			}
			blur_radius = maybe_blur

			// Spread distance (optional, not allowed for text shadows).
			transaction.consume_whitespace()
			if !transaction.has_more_tokens() {
				break
			}
			maybe_spread := parser.parse_length_value(mut transaction) or { continue }
			if shadow_type == .text {
				return none
			}
			spread_distance = maybe_spread
			continue
		}

		token := transaction.peek() or { return none }
		if shadow_type == .normal && token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'inset') {
			if placement != none {
				return none
			}
			placement = ShadowPlacement.inner
			transaction.consume()
			continue
		}

		if token.is(.comma) {
			break
		}

		return none
	}

	// x/y offsets are required.
	resolved_offset_x := offset_x or { return none }
	resolved_offset_y := offset_y or { return none }
	resolved_placement := placement or { ShadowPlacement.outer }

	tokens = transaction
	return StyleValue(ShadowStyleValue.create(shadow_type, color, resolved_offset_x, resolved_offset_y, blur_radius, spread_distance, resolved_placement))
}

const content_quote_keywords = ['open-quote', 'close-quote', 'no-open-quote', 'no-close-quote']

// https://drafts.csswg.org/css-content/#propdef-content
// normal | none | [ <content-list> ] [ / [ <string> | <counter> ]+ ]?
// The C++ parser currently reaches the same accepted content types through Properties.json;
// attr() is handled earlier as an arbitrary substitution function.
fn (mut parser Parser) parse_content_value(mut tokens ComponentValueStream) ?StyleValue {
	mut keyword_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut keyword_attempt, ['none', 'normal']) {
		tokens = keyword_attempt
		return value
	}

	mut transaction := tokens.clone()
	mut content_values := []StyleValue{}
	mut alt_text_values := []StyleValue{}
	mut in_alt_text := false

	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		next := transaction.peek() or { break }
		// '/' separates the content from the alt-text.
		if next.is_delim(u32(`/`)) {
			if in_alt_text || content_values.len == 0 {
				return none
			}
			in_alt_text = true
			transaction.consume()
			transaction.consume_whitespace()
			continue
		}

		item := parser.parse_content_item(mut transaction) or { return none }
		if in_alt_text {
			// The alt-text accepts <string> and <counter>.
			if item !is StringStyleValue && item !is CounterStyleValue {
				return none
			}
			alt_text_values << item
		} else {
			content_values << item
		}
		transaction.consume_whitespace()
	}

	if content_values.len == 0 {
		return none
	}
	if in_alt_text && alt_text_values.len == 0 {
		return none
	}

	mut alt_text := ?StyleValueList(none)
	if alt_text_values.len != 0 {
		alt_text = StyleValueList.create(alt_text_values, .space, .yes)
	}

	tokens = transaction
	return StyleValue(ContentStyleValue.create(StyleValueList.create(content_values, .space, .yes), alt_text))
}

fn (mut parser Parser) parse_content_item(mut tokens ComponentValueStream) ?StyleValue {
	// <string>
	mut string_attempt := tokens.clone()
	if string_value := parser.parse_string_value(mut string_attempt) {
		tokens = string_attempt
		return StyleValue(string_value)
	}

	// <quote> = open-quote | close-quote | no-open-quote | no-close-quote
	mut keyword_attempt := tokens.clone()
	keyword_attempt.consume_whitespace()
	if peek := keyword_attempt.peek() {
		if peek.is(.ident) {
			ident := to_ascii_lowercase(peek.token().ident())
			if ident in content_quote_keywords {
				keyword := keyword_from_string(ident) or { return none }
				keyword_attempt.consume()
				tokens = keyword_attempt
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
	}

	// <counter> = counter() | counters()
	mut counter_attempt := tokens.clone()
	if counter := parser.parse_counter_value(mut counter_attempt) {
		tokens = counter_attempt
		return counter
	}

	// <image>
	mut image_attempt := tokens.clone()
	if image := parser.parse_image_value(mut image_attempt) {
		tokens = image_attempt
		return style_value_from_css_image_source_for_value_logic(image)
	}

	return none
}

// https://drafts.csswg.org/css-lists-3/#counter-functions
// counter() = counter( <counter-name>, <counter-style>? )
// counters() = counters( <counter-name>, <string>, <counter-style>? )
fn (mut parser Parser) parse_counter_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function() {
		return none
	}
	function_name := to_ascii_lowercase(component_value.function().name)
	call_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(component_value.function().value)
	default_counter_style := CounterStyleStyleValue.create_named('decimal')

	if function_name == 'counter' {
		if call_arguments.len < 1 || call_arguments.len > 2 {
			return none
		}
		counter_name := parser.parse_counter_name_argument(call_arguments[0]) or { return none }
		mut counter_style := default_counter_style
		if call_arguments.len == 2 {
			counter_style = parser.parse_counter_style_argument(call_arguments[1]) or { return none }
		}
		tokens = transaction
		return StyleValue(CounterStyleValue.create_counter(counter_name, counter_style))
	}

	if function_name == 'counters' {
		if call_arguments.len < 2 || call_arguments.len > 3 {
			return none
		}
		counter_name := parser.parse_counter_name_argument(call_arguments[0]) or { return none }
		mut join_stream := ComponentValueStream.new(call_arguments[1])
		join_stream.consume_whitespace()
		join_value := parser.parse_string_value(mut join_stream) or { return none }
		join_stream.consume_whitespace()
		if join_stream.has_more_tokens() {
			return none
		}
		mut counter_style := default_counter_style
		if call_arguments.len == 3 {
			counter_style = parser.parse_counter_style_argument(call_arguments[2]) or { return none }
		}
		tokens = transaction
		return StyleValue(CounterStyleValue.create_counters(counter_name, join_value.string_value(), counter_style))
	}

	return none
}

// <counter-name> is a <custom-ident> that is not `none`.
fn (mut parser Parser) parse_counter_name_argument(argument []ComponentValue) ?string {
	mut stream := ComponentValueStream.new(argument)
	stream.consume_whitespace()
	custom_ident := parser.parse_custom_ident_value(mut stream, ['none']) or { return none }
	stream.consume_whitespace()
	if stream.has_more_tokens() {
		return none
	}
	return custom_ident.custom_ident()
}

fn (mut parser Parser) parse_counter_style_argument(argument []ComponentValue) ?CounterStyleStyleValue {
	mut stream := ComponentValueStream.new(argument)
	value := parser.parse_counter_style_value(mut stream) or { return none }
	stream.consume_whitespace()
	if stream.has_more_tokens() {
		return none
	}
	return value
}

// <counter-style> = <counter-style-name> | <symbols()>
// <symbols()> = symbols( <symbols-type>? [ <string> | <image> ]+ )
// The C++ implementation likewise intentionally accepts only <string> symbols for now.
fn (mut parser Parser) parse_counter_style_value(mut tokens ComponentValueStream) ?CounterStyleStyleValue {
	// <counter-style-name> (a <custom-ident> that is not `none`).
	mut name_attempt := tokens.clone()
	if custom_ident := parser.parse_custom_ident_value(mut name_attempt, ['none']) {
		tokens = name_attempt
		return CounterStyleStyleValue.create_named(custom_ident.custom_ident())
	}

	// symbols( <symbols-type>? [ <string> ]+ )
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('symbols') {
		return none
	}
	mut call_arguments := ComponentValueStream.new(component_value.function().value)

	// <symbols-type>? (defaults to symbolic). A leading ident must be a valid symbols-type.
	mut symbols_type := SymbolsType.symbolic
	call_arguments.consume_whitespace()
	if peek := call_arguments.peek() {
		if peek.is(.ident) {
			symbols_type = symbols_type_from_string(peek.token().ident()) or { return none }
			call_arguments.consume() or { return none }
		}
	}

	// [ <string> ]+
	mut symbols := []string{}
	for {
		call_arguments.consume_whitespace()
		if !call_arguments.has_more_tokens() {
			break
		}
		string_value := parser.parse_string_value(mut call_arguments) or { return none }
		symbols << string_value.string_value()
	}

	// At least one <string>; alphabetic/numeric systems require at least two.
	if symbols.len == 0 {
		return none
	}
	if (symbols_type == .alphabetic || symbols_type == .numeric) && symbols.len < 2 {
		return none
	}

	tokens = transaction
	return CounterStyleStyleValue.create_symbols(symbols_type, symbols)
}

fn radial_extent_from_string(ident string) ?RadialExtent {
	return match ident {
		'closest-corner' { RadialExtent.closest_corner }
		'closest-side' { RadialExtent.closest_side }
		'farthest-corner' { RadialExtent.farthest_corner }
		'farthest-side' { RadialExtent.farthest_side }
		else { none }
	}
}

// <radial-size> = [ <radial-extent> | <length-percentage [0,∞]> ]{1,2}
fn (mut parser Parser) parse_radial_size(mut tokens ComponentValueStream) ?RadialSizeStyleValue {
	parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.radial_size_length_percentage))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	mut transaction := tokens.clone()
	mut values := []RadialSizeStyleValueComponent{}
	for transaction.has_more_tokens() && values.len < 2 {
		transaction.consume_whitespace()
		if peek := transaction.peek() {
			if peek.is(.ident) {
				if extent := radial_extent_from_string(to_ascii_lowercase(peek.token().ident())) {
					transaction.consume()
					values << RadialSizeStyleValueComponent(RadialExtentComponent{
						extent: extent
					})
					continue
				}
			}
		}
		mut length_attempt := transaction.clone()
		if length_percentage := parser.parse_length_percentage_value(mut length_attempt) {
			if length_percentage is LengthStyleValue && length_percentage.raw_value() < 0 {
				return none
			}
			if length_percentage is PercentageStyleValue && length_percentage.raw_value() < 0 {
				return none
			}
			values << RadialSizeStyleValueComponent(length_percentage)
			transaction = length_attempt
			continue
		}
		break
	}

	if values.len == 0 {
		return none
	}
	tokens = transaction
	return RadialSizeStyleValue.create(values)
}

fn basic_shape_fill_rule_from_components(components []ComponentValue) ?FillRule {
	mut tokens := ComponentValueStream.new(components)
	tokens.consume_whitespace()
	token := tokens.consume() or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() || !token.is(.ident) {
		return none
	}
	return match to_ascii_lowercase(token.token().ident()) {
		'nonzero' { FillRule.nonzero }
		'evenodd' { FillRule.evenodd }
		else { none }
	}
}

// https://drafts.csswg.org/css-shapes/#typedef-basic-shape
// Parse the optional `[ round <'border-radius'> ]?` tail of inset()/xywh()/rect(). When no
// `round` keyword is present, `zero_radius` is returned and nothing is consumed.
fn (mut parser Parser) parse_basic_shape_round_clause(mut args ComponentValueStream, zero_radius StyleValue) ?StyleValue {
	args.consume_whitespace()
	next := args.peek() or { return zero_radius }
	if !(next.is(.ident) && equals_ignoring_ascii_case(next.token().ident(), 'round')) {
		return zero_radius
	}
	args.consume() or { return none } // 'round'
	return parser.parse_border_radius_rect_value(mut args)
}

// Parse a `<'border-radius'>` value: `<length-percentage>{1,4} [ / <length-percentage>{1,4} ]?`
// into a BorderRadiusRectStyleValue (top-left, top-right, bottom-right, bottom-left).
fn (mut parser Parser) parse_border_radius_rect_value(mut args ComponentValueStream) ?StyleValue {
	groups := grid_split_by_slash(args.consume_remaining_component_values())
	if groups.len < 1 || groups.len > 2 {
		return none
	}
	horizontals := parser.parse_border_radius_lp_list(groups[0]) or { return none }
	mut verticals := horizontals.clone()
	if groups.len == 2 {
		verticals = parser.parse_border_radius_lp_list(groups[1]) or { return none }
	}
	return StyleValue(BorderRadiusRectStyleValue.create(StyleValue(BorderRadiusStyleValue.create(horizontals[0], verticals[0])), StyleValue(BorderRadiusStyleValue.create(horizontals[1], verticals[1])), StyleValue(BorderRadiusStyleValue.create(horizontals[2], verticals[2])), StyleValue(BorderRadiusStyleValue.create(horizontals[3], verticals[3]))))
}

// FIXME: path() stores the raw string without SVG path-data validation.
fn (mut parser Parser) parse_basic_shape_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function() {
		return none
	}
	function_name := to_ascii_lowercase(component_value.function().name)
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: function_name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	function_values := component_value.function().value
	zero_radius := StyleValue(BorderRadiusRectStyleValue.create_zero())

	if function_name == 'shape' {
		value := parser.parse_linear_shape_function(function_values) or { return none }
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(value)))
	}
	if function_name == 'inset' {
		// inset( <length-percentage>{1,4} [ round <'border-radius'> ]? )
		mut args := ComponentValueStream.new(function_values)
		args.consume_whitespace()
		top := parser.parse_length_percentage_value(mut args) or { return none }
		args.consume_whitespace()
		right := parser.parse_length_percentage_value(mut args) or { top }
		args.consume_whitespace()
		bottom := parser.parse_length_percentage_value(mut args) or { top }
		args.consume_whitespace()
		left := parser.parse_length_percentage_value(mut args) or { right }
		border_radius := parser.parse_basic_shape_round_clause(mut args, zero_radius) or {
			return none
		}
		args.consume_whitespace()
		if args.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeInset{
			top: top
			right: right
			bottom: bottom
			left: left
			border_radius: border_radius
		})))
	}

	if function_name == 'xywh' {
		// xywh( <length-percentage>{2} <length-percentage [0,∞]>{2} [ round <'border-radius'> ]? )
		mut args := ComponentValueStream.new(function_values)
		args.consume_whitespace()
		x := parser.parse_length_percentage_value(mut args) or { return none }
		args.consume_whitespace()
		y := parser.parse_length_percentage_value(mut args) or { return none }
		args.consume_whitespace()
		width := parser.parse_length_percentage_value(mut args) or { return none }
		args.consume_whitespace()
		height := parser.parse_length_percentage_value(mut args) or { return none }
		border_radius := parser.parse_basic_shape_round_clause(mut args, zero_radius) or {
			return none
		}
		args.consume_whitespace()
		if args.has_more_tokens() {
			return none
		}
		if width is LengthStyleValue && width.raw_value() < 0 {
			return none
		}
		if width is PercentageStyleValue && width.raw_value() < 0 {
			return none
		}
		if height is LengthStyleValue && height.raw_value() < 0 {
			return none
		}
		if height is PercentageStyleValue && height.raw_value() < 0 {
			return none
		}
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeXywh{
			x: x
			y: y
			width: width
			height: height
			border_radius: border_radius
		})))
	}

	if function_name == 'rect' {
		// rect( [ <length-percentage> | auto ]{4} [ round <'border-radius'> ]? )
		mut args := ComponentValueStream.new(function_values)
		top := parser.parse_length_percentage_or_auto(mut args) or { return none }
		right := parser.parse_length_percentage_or_auto(mut args) or { return none }
		bottom := parser.parse_length_percentage_or_auto(mut args) or { return none }
		left := parser.parse_length_percentage_or_auto(mut args) or { return none }
		border_radius := parser.parse_basic_shape_round_clause(mut args, zero_radius) or {
			return none
		}
		args.consume_whitespace()
		if args.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeRect{
			top: top
			right: right
			bottom: bottom
			left: left
			border_radius: border_radius
		})))
	}

	if function_name == 'circle' {
		// circle( <radial-size>? [ at <position> ]? )
		mut args := ComponentValueStream.new(function_values)
		mut radius := ?RadialSizeStyleValue(none)
		mut radius_attempt := args.clone()
		if parsed := parser.parse_radial_size(mut radius_attempt) {
			if parsed.components().len != 1 {
				return none
			}
			radius = parsed
			args = radius_attempt
		}
		resolved_radius := radius or {
			RadialSizeStyleValue.create([
				RadialSizeStyleValueComponent(RadialExtentComponent{
					extent: .closest_side
				}),
			])
		}

		position := parser.parse_basic_shape_at_position(mut args) or { return none }
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeCircle{
			radius: StyleValue(resolved_radius)
			position: position.value
		})))
	}

	if function_name == 'ellipse' {
		// ellipse( <radial-size>? [ at <position> ]? )
		mut args := ComponentValueStream.new(function_values)
		mut radius := ?RadialSizeStyleValue(none)
		mut radius_attempt := args.clone()
		if parsed := parser.parse_radial_size(mut radius_attempt) {
			if parsed.components().len != 2 {
				return none
			}
			radius = parsed
			args = radius_attempt
		}
		resolved_radius := radius or {
			RadialSizeStyleValue.create([
				RadialSizeStyleValueComponent(RadialExtentComponent{
					extent: .closest_side
				}),
				RadialSizeStyleValueComponent(RadialExtentComponent{
					extent: .closest_side
				}),
			])
		}

		position := parser.parse_basic_shape_at_position(mut args) or { return none }
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapeEllipse{
			radius: StyleValue(resolved_radius)
			position: position.value
		})))
	}

	if function_name == 'polygon' {
		// polygon( <'fill-rule'>? , [ <length-percentage> <length-percentage> ]# )
		call_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(function_values)
		if call_arguments.len < 1 {
			return none
		}
		mut fill_rule := FillRule.nonzero
		mut point_arguments := call_arguments.clone()
		if parsed_fill_rule := basic_shape_fill_rule_from_components(call_arguments[0]) {
			fill_rule = parsed_fill_rule
			point_arguments = call_arguments[1..].clone()
		}
		if point_arguments.len < 1 {
			return none
		}
		mut points := []BasicShapePolygonPoint{}
		for argument in point_arguments {
			mut argument_tokens := ComponentValueStream.new(argument)
			argument_tokens.consume_whitespace()
			x_pos := parser.parse_length_percentage_value(mut argument_tokens) or { return none }
			argument_tokens.consume_whitespace()
			y_pos := parser.parse_length_percentage_value(mut argument_tokens) or { return none }
			argument_tokens.consume_whitespace()
			if argument_tokens.has_more_tokens() {
				return none
			}
			points << BasicShapePolygonPoint{
				x: x_pos
				y: y_pos
			}
		}
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapePolygon{
			fill_rule: fill_rule
			points: points
		})))
	}

	if function_name == 'path' {
		// path( <'fill-rule'>?, <string> )
		call_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(function_values)
		if call_arguments.len < 1 || call_arguments.len > 2 {
			return none
		}
		mut fill_rule := FillRule.nonzero
		if call_arguments.len == 2 {
			fill_rule = basic_shape_fill_rule_from_components(call_arguments[0]) or { return none }
		}
		mut string_tokens := ComponentValueStream.new(call_arguments[call_arguments.len - 1])
		string_tokens.consume_whitespace()
		string_token := string_tokens.consume() or { return none }
		string_tokens.consume_whitespace()
		if !string_token.is(.string) || string_tokens.has_more_tokens() {
			return none
		}
		path_data := svg.parse_path_data(string_token.token().string_value())
		if path_data.instructions.len == 0 {
			return none
		}
		tokens = transaction
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapePath{
			fill_rule: fill_rule
			path_instructions: path_data.serialize()
		})))
	}

	return none
}

fn (mut parser Parser) parse_length_percentage_or_auto(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	if value := parser.parse_length_percentage_value(mut tokens) {
		return value
	}
	mut auto_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut auto_attempt, ['auto']) {
		tokens = auto_attempt
		return value
	}
	return none
}

struct BasicShapePositionResult {
	value ?StyleValue
}

// [ at <position> ]?  -- returns the optional position (none result = parse error; the wrapped
// `.value` is the optional position, absent when there is no `at` clause).
fn (mut parser Parser) parse_basic_shape_at_position(mut tokens ComponentValueStream) ?BasicShapePositionResult {
	tokens.consume_whitespace()
	mut position := ?StyleValue(none)
	if peek := tokens.peek() {
		if peek.is(.ident) && equals_ignoring_ascii_case(peek.token().ident(), 'at') {
			tokens.consume()
			tokens.consume_whitespace()
			parsed_position := parser.parse_css_position_value(mut tokens, .normal) or {
				return none
			}
			position = parsed_position
		}
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return BasicShapePositionResult{
		value: position
	}
}

// https://drafts.fxtf.org/css-masking/#the-clip-path  ->  none | <basic-shape> || <geometry-box> | <url>
// NOTE: upstream's clip-path accepts only <basic-shape>, <url> and none (no <geometry-box>).
fn (mut parser Parser) parse_clip_path_value(mut tokens ComponentValueStream) ?StyleValue {
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}
	// <url> reference to an SVG <clipPath>.
	mut url_attempt := tokens.clone()
	if url := parse_url_function(mut url_attempt) {
		tokens = url_attempt
		return StyleValue(URLStyleValue.create(url))
	}
	return parser.parse_basic_shape_value(mut tokens)
}

// https://drafts.csswg.org/css-shapes/#propdef-shape-outside  ->  none | [ <basic-shape> || <shape-box> ] | <image>
fn (mut parser Parser) parse_shape_outside_value(mut tokens ComponentValueStream) ?StyleValue {
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}

	mut image_attempt := tokens.clone()
	if image := parser.parse_image_value(mut image_attempt) {
		tokens = image_attempt
		return style_value_from_css_image_source_for_value_logic(image)
	}

	mut transaction := tokens.clone()
	mut basic_shape := ?StyleValue(none)
	mut shape_box := ?StyleValue(none)
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		mut shape_attempt := transaction.clone()
		if value := parser.parse_basic_shape_value(mut shape_attempt) {
			if basic_shape != none {
				return none
			}
			basic_shape = value
			transaction = shape_attempt
			continue
		}
		mut box_attempt := transaction.clone()
		if value := parse_property_keyword_value(mut box_attempt, ['margin-box', 'border-box',
			'padding-box', 'content-box']) {
			if shape_box != none {
				return none
			}
			shape_box = value
			transaction = box_attempt
			continue
		}
		return none
	}
	if basic_shape == none && shape_box == none {
		return none
	}
	tokens = transaction
	if shape := basic_shape {
		if box := shape_box {
			return StyleValue(StyleValueList.create([shape, box], .space, .yes))
		}
		return shape
	}
	return shape_box
}

// Parses a `||` combination of font-variant keywords into a fixed-size tuple, where
// `slot_for` maps a lowercased ident to its canonical tuple slot (or none if not a member).
fn (mut parser Parser) parse_font_variant_tuple(mut tokens ComponentValueStream, slot_count int, slot_for fn (string) ?int) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut slots := []?StyleValue{}
	for _ in 0 .. slot_count {
		slots << ?StyleValue(none)
	}

	for {
		transaction.consume_whitespace()
		peek := transaction.peek() or { break }
		if !peek.is(.ident) {
			break
		}
		ident := to_ascii_lowercase(peek.token().ident())
		slot := slot_for(ident) or { break }
		if slots[slot] != none {
			return none
		}
		keyword := keyword_from_string(ident) or { break }
		transaction.consume()
		slots[slot] = StyleValue(KeywordStyleValue.create(keyword))
	}

	mut any_filled := false
	for maybe_value in slots {
		if maybe_value != none {
			any_filled = true
			break
		}
	}
	if !any_filled {
		return none
	}

	// Do NOT reject trailing tokens here: as a `||` component (e.g. inside the font-variant
	// shorthand) this parser must leave the tokens for the next component. The no-leftover
	// rule is enforced at the top level.
	tokens = transaction
	return StyleValue(TupleStyleValue.create(slots))
}

enum BoxSideKind {
	margin
	padding
	scroll_margin
	scroll_padding
	inset
	border_color
	border_style
	border_width
	corner_shape
}

fn (mut parser Parser) parse_box_side_value(mut tokens ComponentValueStream, kind BoxSideKind) ?StyleValue {
	return match kind {
		.margin { parser.parse_margin_value(mut tokens) }
		.padding { parser.parse_padding_value(mut tokens) }
		.scroll_margin { parser.parse_length_value(mut tokens) }
		.scroll_padding { parser.parse_auto_or_nonnegative_length_percentage_value(mut tokens) }
		.inset { parser.parse_inset_value(mut tokens) }
		.border_color { parser.parse_color_value(mut tokens) }
		.border_style { parser.parse_line_style_value(mut tokens) }
		.border_width { parser.parse_border_or_outline_width_value(.border_top_width, mut tokens) }
		.corner_shape { parser.parse_corner_shape_value(mut tokens) }
	}
}

// <v>{1,4} expanded to [ top, right, bottom, left ] like the margin shorthand.
fn (mut parser Parser) parse_box_4_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, longhands []PropertyID, kind BoxSideKind) ?StyleValue {
	mut values := []StyleValue{}
	for values.len < 4 {
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			break
		}
		value := parser.parse_box_side_value(mut tokens, kind) or { break }
		values << value
	}
	if values.len == 0 {
		return none
	}
	top := values[0]
	right := if values.len > 1 { values[1] } else { top }
	bottom := if values.len > 2 { values[2] } else { top }
	left := if values.len > 3 { values[3] } else { right }
	return StyleValue(ShorthandStyleValue.create(shorthand, longhands, [top, right, bottom, left]))
}

// <v>{1,2} expanded to [ start, end ] (the logical block/inline shorthands).
fn (mut parser Parser) parse_box_2_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, longhands []PropertyID, kind BoxSideKind) ?StyleValue {
	start := parser.parse_box_side_value(mut tokens, kind) or { return none }
	mut end := start
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		end = parser.parse_box_side_value(mut transaction, kind) or { return none }
		tokens = transaction
	}
	return StyleValue(ShorthandStyleValue.create(shorthand, longhands, [start, end]))
}

fn (mut parser Parser) parse_margin_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .margin, [PropertyID.margin_top,
		PropertyID.margin_right, PropertyID.margin_bottom, PropertyID.margin_left], .margin)
}

fn (mut parser Parser) parse_padding_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .padding, [PropertyID.padding_top,
		PropertyID.padding_right, PropertyID.padding_bottom, PropertyID.padding_left], .padding)
}

fn (mut parser Parser) parse_inset_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .inset, [PropertyID.top, PropertyID.right,
		PropertyID.bottom, PropertyID.left], .inset)
}

fn (mut parser Parser) parse_margin_block_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .margin_block, [
		PropertyID.margin_block_start,
		PropertyID.margin_block_end,
	], .margin)
}

fn (mut parser Parser) parse_margin_inline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .margin_inline, [
		PropertyID.margin_inline_start,
		PropertyID.margin_inline_end,
	], .margin)
}

fn (mut parser Parser) parse_padding_block_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .padding_block, [
		PropertyID.padding_block_start,
		PropertyID.padding_block_end,
	], .padding)
}

fn (mut parser Parser) parse_padding_inline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .padding_inline, [
		PropertyID.padding_inline_start,
		PropertyID.padding_inline_end,
	], .padding)
}

fn (mut parser Parser) parse_scroll_margin_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .scroll_margin, [
		PropertyID.scroll_margin_top,
		PropertyID.scroll_margin_right,
		PropertyID.scroll_margin_bottom,
		PropertyID.scroll_margin_left,
	], .scroll_margin)
}

fn (mut parser Parser) parse_scroll_margin_block_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .scroll_margin_block, [
		PropertyID.scroll_margin_block_start,
		PropertyID.scroll_margin_block_end,
	], .scroll_margin)
}

fn (mut parser Parser) parse_scroll_margin_inline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .scroll_margin_inline, [
		PropertyID.scroll_margin_inline_start,
		PropertyID.scroll_margin_inline_end,
	], .scroll_margin)
}

fn (mut parser Parser) parse_scroll_padding_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .scroll_padding, [
		PropertyID.scroll_padding_top,
		PropertyID.scroll_padding_right,
		PropertyID.scroll_padding_bottom,
		PropertyID.scroll_padding_left,
	], .scroll_padding)
}

fn (mut parser Parser) parse_scroll_padding_block_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .scroll_padding_block, [
		PropertyID.scroll_padding_block_start,
		PropertyID.scroll_padding_block_end,
	], .scroll_padding)
}

fn (mut parser Parser) parse_scroll_padding_inline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .scroll_padding_inline, [
		PropertyID.scroll_padding_inline_start,
		PropertyID.scroll_padding_inline_end,
	], .scroll_padding)
}

fn (mut parser Parser) parse_inset_block_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .inset_block, [
		PropertyID.inset_block_start,
		PropertyID.inset_block_end,
	], .inset)
}

fn (mut parser Parser) parse_inset_inline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .inset_inline, [
		PropertyID.inset_inline_start,
		PropertyID.inset_inline_end,
	], .inset)
}

fn (mut parser Parser) parse_border_color_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .border_color, [
		PropertyID.border_top_color,
		PropertyID.border_right_color,
		PropertyID.border_bottom_color,
		PropertyID.border_left_color,
	], .border_color)
}

fn (mut parser Parser) parse_border_style_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .border_style, [
		PropertyID.border_top_style,
		PropertyID.border_right_style,
		PropertyID.border_bottom_style,
		PropertyID.border_left_style,
	], .border_style)
}

fn (mut parser Parser) parse_border_width_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .border_width, [
		PropertyID.border_top_width,
		PropertyID.border_right_width,
		PropertyID.border_bottom_width,
		PropertyID.border_left_width,
	], .border_width)
}

fn (mut parser Parser) parse_border_block_color_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_block_color, [
		PropertyID.border_block_start_color,
		PropertyID.border_block_end_color,
	], .border_color)
}

fn (mut parser Parser) parse_border_inline_color_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_inline_color, [
		PropertyID.border_inline_start_color,
		PropertyID.border_inline_end_color,
	], .border_color)
}

fn (mut parser Parser) parse_border_block_style_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_block_style, [
		PropertyID.border_block_start_style,
		PropertyID.border_block_end_style,
	], .border_style)
}

fn (mut parser Parser) parse_border_inline_style_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_inline_style, [
		PropertyID.border_inline_start_style,
		PropertyID.border_inline_end_style,
	], .border_style)
}

fn (mut parser Parser) parse_border_block_width_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_block_width, [
		PropertyID.border_block_start_width,
		PropertyID.border_block_end_width,
	], .border_width)
}

fn (mut parser Parser) parse_border_inline_width_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .border_inline_width, [
		PropertyID.border_inline_start_width,
		PropertyID.border_inline_end_width,
	], .border_width)
}

// Returns the longhand's retained typed initial value.
fn (mut parser Parser) longhand_initial_typed_value(property_id PropertyID) ?StyleValue {
	_ = parser
	dom_initial := computed_interpolation_property_initial_value(property_id)
	return style_value_logic_from_dom(property_id, dom_initial)
}

// property_initial_value() also accepts shorthands in Ladybird and returns a
// recursively retained shorthand value. Build the same shape from generated
// longhand metadata instead of reparsing a convenient-looking spelling.
fn (mut parser Parser) shorthand_initial_typed_value(property_id PropertyID) ?StyleValue {
	if !property_is_shorthand(property_id) {
		return parser.longhand_initial_typed_value(property_id)
	}
	longhands := generated_longhands_for_shorthand(property_id)
	if longhands.len == 0 {
		return none
	}
	mut values := []StyleValue{cap: longhands.len}
	for longhand in longhands {
		values << parser.shorthand_initial_typed_value(longhand) or { return none }
	}
	return StyleValue(ShorthandStyleValue.create(property_id, longhands, values))
}

// Returns a single-value initial for a coordinated (list-valued) longhand: the first element of its
// initial list, or the initial value itself when it is not a list.
fn (mut parser Parser) longhand_initial_first_value(property_id PropertyID) ?StyleValue {
	initial := parser.longhand_initial_typed_value(property_id) or { return none }
	if initial is StyleValueList {
		values := initial.values()
		if values.len == 0 {
			return none
		}
		return values[0]
	}
	return initial
}

// PropertyParsing.cpp: Parser::parse_coordinating_value_list_shorthand.
// Each comma-separated item is a `||` of longhand components. Selection is
// delegated to the same generated property metadata as standalone values.
fn (mut parser Parser) parse_coordinating_value_list_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, longhand_ids []PropertyID, reset_only_longhand_ids []PropertyID) ?StyleValue {
	mut longhand_vectors := [][]StyleValue{}
	for _ in longhand_ids {
		longhand_vectors << []StyleValue{}
	}

	mut transaction := tokens.clone()
	for {
		mut remaining_longhands := longhand_ids.clone()
		mut parsed := []?StyleValue{}
		for _ in longhand_ids {
			parsed << ?StyleValue(none)
		}
		mut any_parsed := false

		for {
			transaction.consume_whitespace()
			next := transaction.peek() or { break }
			if next.is(.comma) {
				break
			}
			property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
			mut longhand_index := -1
			for i, longhand_id in longhand_ids {
				if longhand_id == property_and_value.property {
					longhand_index = i
					break
				}
			}
			if longhand_index < 0 {
				return none
			}
			parsed[longhand_index] = property_and_value.style_value
			for i, remaining_longhand in remaining_longhands {
				if remaining_longhand == property_and_value.property {
					remaining_longhands.delete(i)
					break
				}
			}
			any_parsed = true
		}

		if !any_parsed {
			return none
		}
		for i, longhand_id in longhand_ids {
			maybe := parsed[i]
			if value := maybe {
				longhand_vectors[i] << value
			} else {
				longhand_vectors[i] << parser.longhand_initial_first_value(longhand_id) or {
					return none
				}
			}
		}

		transaction.consume_whitespace()
		next := transaction.peek() or { break }
		if !next.is(.comma) {
			return none
		}
		transaction.consume()
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	mut all_longhand_ids := longhand_ids.clone()
	all_longhand_ids << reset_only_longhand_ids
	mut longhand_values := []StyleValue{}
	for i, _ in longhand_ids {
		longhand_values << StyleValue(StyleValueList.create(longhand_vectors[i], .comma, .yes))
	}
	for reset_only_longhand_id in reset_only_longhand_ids {
		longhand_values << parser.longhand_initial_typed_value(reset_only_longhand_id) or {
			return none
		}
	}
	return StyleValue(ShorthandStyleValue.create(shorthand, all_longhand_ids, longhand_values))
}

const animation_shorthand_longhands = [PropertyID.animation_duration,
	PropertyID.animation_timing_function, PropertyID.animation_delay,
	PropertyID.animation_iteration_count, PropertyID.animation_direction,
	PropertyID.animation_fill_mode, PropertyID.animation_play_state, PropertyID.animation_name]

// https://drafts.csswg.org/css-animations/#propdef-animation
fn (mut parser Parser) parse_animation_value(mut tokens ComponentValueStream) ?StyleValue {
	// Timeline and attachment ranges are reset-only sub-properties and are not
	// accepted as a component of the animation shorthand.
	return parser.parse_coordinating_value_list_shorthand(mut tokens, .animation, animation_shorthand_longhands, [
		PropertyID.animation_timeline,
		PropertyID.animation_range_start, PropertyID.animation_range_end,
	])
}

// https://drafts.csswg.org/scroll-animations-1/#scroll-timeline-shorthand
// PropertyParsing.cpp: Parser::parse_scroll_timeline_value.
fn (mut parser Parser) parse_scroll_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	mut names := []StyleValue{}
	mut axes := []StyleValue{}
	default_axis := parser.longhand_initial_first_value(.scroll_timeline_axis) or { return none }
	mut transaction := tokens.clone()

	for {
		transaction.consume_whitespace()
		name := parser.parse_css_value_for_properties([
			PropertyID.scroll_timeline_name,
		], mut transaction) or { return none }
		names << name.style_value

		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			axes << default_axis
			break
		}
		if next := transaction.peek() {
			if next.is(.comma) {
				axes << default_axis
				transaction.consume()
				transaction.consume_whitespace()
				if !transaction.has_more_tokens() {
					return none
				}
				continue
			}
		}

		axis := parser.parse_css_value_for_properties([
			PropertyID.scroll_timeline_axis,
		], mut transaction) or { return none }
		axes << axis.style_value
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		next := transaction.peek() or { break }
		if !next.is(.comma) {
			return none
		}
		transaction.consume()
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.scroll_timeline, [
		PropertyID.scroll_timeline_name,
		PropertyID.scroll_timeline_axis,
	], [
		StyleValue(StyleValueList.create(names, .comma, .yes)),
		StyleValue(StyleValueList.create(axes, .comma, .yes)),
	]))
}

// https://drafts.csswg.org/scroll-animations-1/#view-timeline-shorthand
// PropertyParsing.cpp: Parser::parse_view_timeline_value.
fn (mut parser Parser) parse_view_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	mut names := []StyleValue{}
	mut axes := []StyleValue{}
	mut insets := []StyleValue{}
	default_axis := parser.longhand_initial_first_value(.view_timeline_axis) or { return none }
	default_inset := parser.longhand_initial_first_value(.view_timeline_inset) or { return none }
	mut transaction := tokens.clone()

	for {
		transaction.consume_whitespace()
		name := parser.parse_css_value_for_properties([PropertyID.view_timeline_name], mut transaction) or { return none }
		names << name.style_value

		mut axis := ?StyleValue(none)
		mut inset := ?StyleValue(none)
		mut remaining_longhands := [PropertyID.view_timeline_axis, PropertyID.view_timeline_inset]
		transaction.consume_whitespace()
		for transaction.has_more_tokens() {
			next := transaction.peek() or { break }
			if next.is(.comma) {
				break
			}
			property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
			for i, property_id in remaining_longhands {
				if property_id == property_and_value.property {
					remaining_longhands.delete(i)
					break
				}
			}
			match property_and_value.property {
				.view_timeline_axis {
					axis = property_and_value.style_value
				}
				.view_timeline_inset {
					inset = property_and_value.style_value
				}
				else {
					return none
				}
			}
			transaction.consume_whitespace()
		}

		axes << (axis or { default_axis })
		insets << (inset or { default_inset })
		if !transaction.has_more_tokens() {
			break
		}
		next := transaction.peek() or { break }
		if !next.is(.comma) {
			return none
		}
		transaction.consume()
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.view_timeline, [
		PropertyID.view_timeline_name,
		PropertyID.view_timeline_axis,
		PropertyID.view_timeline_inset,
	], [
		StyleValue(StyleValueList.create(names, .comma, .yes)),
		StyleValue(StyleValueList.create(axes, .comma, .yes)),
		StyleValue(StyleValueList.create(insets, .comma, .yes)),
	]))
}

struct BorderImageSlicePortion {
	slice  StyleValue
	width  ?StyleValue
	outset ?StyleValue
}

// <'border-image-slice'> [ / <'border-image-width'> | / <'border-image-width'>? / <'border-image-outset'> ]?
fn (mut parser Parser) parse_border_image_slice_portion(mut tokens ComponentValueStream) ?BorderImageSlicePortion {
	tokens.consume_whitespace()
	slice := parser.parse_border_image_slice_value(mut tokens) or { return none }
	mut width := ?StyleValue(none)
	mut outset := ?StyleValue(none)
	tokens.consume_whitespace()
	mut first_slash := false
	if peek := tokens.peek() {
		first_slash = peek.is_delim(u32(`/`))
	}
	if first_slash {
		tokens.consume()
		tokens.consume_whitespace()
		mut have_width := false
		if w := parser.parse_border_image_width_value(mut tokens) {
			width = w
			have_width = true
			tokens.consume_whitespace()
		}
		mut second_slash := false
		if peek := tokens.peek() {
			second_slash = peek.is_delim(u32(`/`))
		}
		if !have_width && !second_slash {
			// A '/' was present but neither a width nor a second '/' for outset followed.
			return none
		}
		if second_slash {
			tokens.consume()
			tokens.consume_whitespace()
			outset = parser.parse_border_image_outset_value(mut tokens) or { return none }
			tokens.consume_whitespace()
		}
	}
	return BorderImageSlicePortion{
		slice: slice
		width: width
		outset: outset
	}
}

// https://drafts.csswg.org/css-backgrounds/#the-border-image
// <'border-image-source'> || <'border-image-slice'> [ / <'border-image-width'> | / <'border-image-width'>? / <'border-image-outset'> ]? || <'border-image-repeat'>
// PropertyParsing.cpp: Parser::parse_border_image_value.
fn (mut parser Parser) parse_border_image_value(mut tokens ComponentValueStream) ?StyleValue {
	mut source := ?StyleValue(none)
	mut slice := ?StyleValue(none)
	mut width := ?StyleValue(none)
	mut outset := ?StyleValue(none)
	mut repeat := ?StyleValue(none)
	mut transaction := tokens.clone()

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		if source == none {
			mut attempt := transaction.clone()
			if value := parser.parse_image_or_none_value(mut attempt) {
				source = value
				transaction = attempt
				continue
			}
		}
		if repeat == none {
			mut attempt := transaction.clone()
			if value := parser.parse_border_image_repeat_value(mut attempt) {
				repeat = value
				transaction = attempt
				continue
			}
		}
		if slice == none {
			mut attempt := transaction.clone()
			if portion := parser.parse_border_image_slice_portion(mut attempt) {
				slice = portion.slice
				if w := portion.width {
					width = w
				}
				if o := portion.outset {
					outset = o
				}
				transaction = attempt
				continue
			}
		}
		break
	}

	if source == none && slice == none && width == none && outset == none && repeat == none {
		return none
	}

	component_ids := [PropertyID.border_image_source, PropertyID.border_image_slice,
		PropertyID.border_image_width, PropertyID.border_image_outset,
		PropertyID.border_image_repeat]
	resolved := [
		source or { parser.longhand_initial_typed_value(.border_image_source) or { return none } },
		slice or { parser.longhand_initial_typed_value(.border_image_slice) or { return none } },
		width or { parser.longhand_initial_typed_value(.border_image_width) or { return none } },
		outset or { parser.longhand_initial_typed_value(.border_image_outset) or { return none } },
		repeat or { parser.longhand_initial_typed_value(.border_image_repeat) or { return none } },
	]
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.border_image, component_ids, resolved))
}

// https://drafts.csswg.org/css-backgrounds/#propdef-background-position
// <bg-position># — each layer's position is split into its x and y edges, producing
// coordinated comma-separated background-position-x and background-position-y lists.
fn (mut parser Parser) parse_background_position_value(mut tokens ComponentValueStream) ?StyleValue {
	list_value := parser.parse_position_list_value(mut tokens, .background_position) or {
		return none
	}
	list := list_value as StyleValueList
	mut xs := []StyleValue{}
	mut ys := []StyleValue{}
	for position in list.values() {
		pos := position as PositionStyleValue
		xs << StyleValue(pos.edge_x())
		ys << StyleValue(pos.edge_y())
	}
	return StyleValue(ShorthandStyleValue.create(.background_position, [
		PropertyID.background_position_x,
		PropertyID.background_position_y,
	], [
		StyleValue(StyleValueList.create(xs, .comma, .yes)),
		StyleValue(StyleValueList.create(ys, .comma, .yes)),
	]))
}

// none
// | <'grid-template-rows'> / <'grid-template-columns'>
// | [ <line-names>? <string> <track-size>? <line-names>? ]+ [ / <explicit-track-list> ]?
// When include_grid_auto_properties is set (the `grid` shorthand), grid-auto-flow/rows/columns
// are prepended as initial values.
// PropertyParsing.cpp: Parser::parse_grid_track_size_list_shorthand_value.
fn (mut parser Parser) parse_grid_track_size_list_shorthand_value(property_id PropertyID, mut tokens ComponentValueStream, include_grid_auto_properties bool) ?StyleValue {
	mut sub_properties := []PropertyID{}
	mut auto_values := []StyleValue{}
	if include_grid_auto_properties {
		sub_properties << PropertyID.grid_auto_flow
		sub_properties << PropertyID.grid_auto_rows
		sub_properties << PropertyID.grid_auto_columns
		auto_values << parser.longhand_initial_typed_value(.grid_auto_flow) or { return none }
		auto_values << parser.longhand_initial_typed_value(.grid_auto_rows) or { return none }
		auto_values << parser.longhand_initial_typed_value(.grid_auto_columns) or { return none }
	}
	sub_properties << PropertyID.grid_template_areas
	sub_properties << PropertyID.grid_template_rows
	sub_properties << PropertyID.grid_template_columns

	initial_areas := parser.longhand_initial_typed_value(.grid_template_areas) or { return none }
	initial_rows := parser.longhand_initial_typed_value(.grid_template_rows) or { return none }
	initial_columns := parser.longhand_initial_typed_value(.grid_template_columns) or {
		return none
	}

	// none
	mut none_attempt := tokens.clone()
	none_attempt.consume_whitespace()
	if _ := parse_property_keyword_value(mut none_attempt, ['none']) {
		none_attempt.consume_whitespace()
		if !none_attempt.has_more_tokens() {
			tokens = none_attempt
			mut resolved := auto_values.clone()
			resolved << initial_areas
			resolved << initial_rows
			resolved << initial_columns
			return StyleValue(ShorthandStyleValue.create(property_id, sub_properties, resolved))
		}
	}

	// <'grid-template-rows'> / <'grid-template-columns'>
	mut rows_columns_attempt := tokens.clone()
	if rows := parser.parse_grid_track_size_list(mut rows_columns_attempt) {
		rows_columns_attempt.consume_whitespace()
		mut slash := false
		if peek := rows_columns_attempt.peek() {
			slash = peek.is_delim(u32(`/`))
		}
		if slash {
			rows_columns_attempt.consume()
			rows_columns_attempt.consume_whitespace()
			if columns := parser.parse_grid_track_size_list(mut rows_columns_attempt) {
				tokens = rows_columns_attempt
				mut resolved := auto_values.clone()
				resolved << initial_areas
				resolved << rows
				resolved << columns
				return StyleValue(ShorthandStyleValue.create(property_id, sub_properties, resolved))
			}
		}
	}

	// [ <line-names>? <string> <track-size>? <line-names>? ]+ [ / <explicit-track-list> ]?
	mut areas_attempt := tokens.clone()
	mut track_list := GridTrackSizeList{}
	mut area_tokens := []ComponentValue{}
	mut parsed_track_count := 0
	areas_attempt.consume_whitespace()
	for areas_attempt.has_more_tokens() {
		mut row_transaction := areas_attempt.clone()
		line_names := parser.parse_grid_line_names(mut row_transaction) or { break }
		row_transaction.consume_whitespace()
		string_token := row_transaction.peek() or { break }
		if !string_token.is(.string) {
			break
		}
		row_transaction.consume()
		row_transaction.consume_whitespace()
		mut track := ExplicitGridTrack.from_grid_size(GridSize.make_auto())
		if parsed_track := parser.parse_grid_track_size(mut row_transaction) {
			track = parsed_track
		}
		row_transaction.consume_whitespace()
		mut trailing_names := GridLineNames{}
		if trailing := parser.parse_grid_line_names(mut row_transaction) {
			trailing_names = trailing
		}

		if !line_names.is_empty() {
			track_list.append_line_names(line_names)
		}
		track_list.append_explicit_track(track)
		if !trailing_names.is_empty() {
			track_list.append_line_names(trailing_names)
		}
		area_tokens << string_token
		areas_attempt = row_transaction
		parsed_track_count++
		areas_attempt.consume_whitespace()
	}
	if parsed_track_count > 0 {
		mut area_stream := ComponentValueStream.new(area_tokens)
		grid_areas := parser.parse_grid_template_areas_value(mut area_stream) or { return none }
		rows_value := StyleValue(GridTrackSizeListStyleValue.create(track_list))
		areas_attempt.consume_whitespace()
		mut columns_value := initial_columns
		mut has_columns_slash := false
		if peek := areas_attempt.peek() {
			has_columns_slash = peek.is_delim(u32(`/`))
		}
		if has_columns_slash {
			areas_attempt.consume()
			areas_attempt.consume_whitespace()
			columns_list := parser.parse_explicit_track_list(mut areas_attempt) or { return none }
			columns_value = StyleValue(GridTrackSizeListStyleValue.create(columns_list))
		} else if areas_attempt.has_more_tokens() {
			return none
		}
		tokens = areas_attempt
		mut resolved := auto_values.clone()
		resolved << grid_areas
		resolved << rows_value
		resolved << columns_value
		return StyleValue(ShorthandStyleValue.create(property_id, sub_properties, resolved))
	}

	return none
}

// [ auto-flow && dense? ]  (auto-flow is a literal keyword; axis is fixed by the caller).
fn parse_grid_auto_flow_and_dense(mut tokens ComponentValueStream, axis GridAutoFlowAxis) ?StyleValue {
	mut transaction := tokens.clone()
	mut found_auto_flow := false
	mut dense := GridAutoFlowDense.no
	for _ in 0 .. 2 {
		transaction.consume_whitespace()
		token := transaction.peek() or { break }
		if !token.is(.ident) {
			break
		}
		ident := to_ascii_lowercase(token.token().ident())
		if ident == 'auto-flow' && !found_auto_flow {
			transaction.consume()
			found_auto_flow = true
		} else if ident == 'dense' && dense == .no {
			transaction.consume()
			dense = .yes
		} else {
			break
		}
	}
	if !found_auto_flow {
		return none
	}
	tokens = transaction
	return StyleValue(GridAutoFlowStyleValue.create(axis, dense))
}

const grid_shorthand_longhands = [PropertyID.grid_auto_flow, PropertyID.grid_auto_rows,
	PropertyID.grid_auto_columns, PropertyID.grid_template_areas, PropertyID.grid_template_rows,
	PropertyID.grid_template_columns]

// https://drafts.csswg.org/css-grid/#grid-shorthand
// <'grid-template'>
// | [ auto-flow && dense? ] <'grid-auto-rows'>? / <'grid-template-columns'>
// | <'grid-template-rows'> / [ auto-flow && dense? ] <'grid-auto-columns'>?
// PropertyParsing.cpp: Parser::parse_grid_shorthand_value.
fn (mut parser Parser) parse_grid_shorthand_value(mut tokens ComponentValueStream) ?StyleValue {
	mut template_attempt := tokens.clone()
	if grid_template := parser.parse_grid_track_size_list_shorthand_value(.grid, mut template_attempt, true) {
		tokens = template_attempt
		return grid_template
	}

	// [ auto-flow && dense? ] <'grid-auto-rows'>? / <'grid-template-columns'>
	mut branch1 := tokens.clone()
	branch1.consume_whitespace()
	if grid_auto_flow := parse_grid_auto_flow_and_dense(mut branch1, .row) {
		grid_auto_rows := parser.parse_grid_auto_track_sizes(mut branch1) or {
			parser.longhand_initial_typed_value(.grid_auto_rows) or { return none }
		}
		branch1.consume_whitespace()
		mut slash := false
		if peek := branch1.peek() {
			slash = peek.is_delim(u32(`/`))
		}
		if slash {
			branch1.consume()
			branch1.consume_whitespace()
			if grid_template_columns := parser.parse_grid_track_size_list(mut branch1) {
				tokens = branch1
				return StyleValue(ShorthandStyleValue.create(.grid, grid_shorthand_longhands, [
					grid_auto_flow,
					grid_auto_rows,
					parser.longhand_initial_typed_value(.grid_auto_columns) or { return none },
					parser.longhand_initial_typed_value(.grid_template_areas) or { return none },
					parser.longhand_initial_typed_value(.grid_template_rows) or { return none },
					grid_template_columns,
				]))
			}
		}
	}

	// <'grid-template-rows'> / [ auto-flow && dense? ] <'grid-auto-columns'>?
	mut branch2 := tokens.clone()
	branch2.consume_whitespace()
	if grid_template_rows := parser.parse_grid_track_size_list(mut branch2) {
		branch2.consume_whitespace()
		mut slash := false
		if peek := branch2.peek() {
			slash = peek.is_delim(u32(`/`))
		}
		if slash {
			branch2.consume()
			branch2.consume_whitespace()
			if grid_auto_flow := parse_grid_auto_flow_and_dense(mut branch2, .column) {
				grid_auto_columns := parser.parse_grid_auto_track_sizes(mut branch2) or {
					parser.longhand_initial_typed_value(.grid_auto_columns) or { return none }
				}
				tokens = branch2
				return StyleValue(ShorthandStyleValue.create(.grid, grid_shorthand_longhands, [
					grid_auto_flow,
					parser.longhand_initial_typed_value(.grid_auto_rows) or { return none },
					grid_auto_columns,
					parser.longhand_initial_typed_value(.grid_template_areas) or { return none },
					grid_template_rows,
					parser.longhand_initial_typed_value(.grid_template_columns) or { return none },
				]))
			}
		}
	}

	return none
}

const font_variant_longhands = [PropertyID.font_variant_alternates, PropertyID.font_variant_caps,
	PropertyID.font_variant_east_asian, PropertyID.font_variant_emoji,
	PropertyID.font_variant_ligatures, PropertyID.font_variant_numeric,
	PropertyID.font_variant_position]

// Keep FontVariant as the nested shorthand it is in Ladybird. Property application recursively
// expands this representation, so retaining it avoids reparsing or duplicating the C++ shape.
fn (mut parser Parser) font_variant_with_caps(caps StyleValue) ?StyleValue {
	mut values := []StyleValue{cap: font_variant_longhands.len}
	for longhand in font_variant_longhands {
		if longhand == .font_variant_caps {
			values << caps
		} else {
			values << parser.longhand_initial_typed_value(longhand) or { return none }
		}
	}
	return StyleValue(ShorthandStyleValue.create(.font_variant, font_variant_longhands, values))
}

const font_shorthand_longhands = [PropertyID.font_family, PropertyID.font_size,
	PropertyID.font_width, PropertyID.font_style, PropertyID.font_variant, PropertyID.font_weight,
	PropertyID.line_height, PropertyID.font_feature_settings, PropertyID.font_kerning,
	PropertyID.font_language_override, PropertyID.font_optical_sizing,
	PropertyID.font_variation_settings, PropertyID.font_size_adjust]

// https://drafts.csswg.org/css-fonts/#font-prop
// [ [ <'font-style'> || <font-variant-css2> || <'font-weight'> || <font-width-css3> ]? <'font-size'> [ / <'line-height'> ]? <'font-family'># ]
// A system-font keyword supplies every font longhand as one indivisible value.
// PropertyParsing.cpp: Parser::parse_font_value.
fn (mut parser Parser) parse_font_value(mut tokens ComponentValueStream) ?StyleValue {
	mut system_tokens := tokens.clone()
	system_tokens.consume_whitespace()
	if first := system_tokens.peek() {
		system_tokens.consume()
		if first.is(.ident) && to_ascii_lowercase(first.token().ident()) in system_font_keywords {
			system_tokens.consume_whitespace()
			if system_tokens.has_more_tokens() { return none }
			value := parser.parse_system_font_value(to_ascii_lowercase(first.token().ident())) or { return none }
			tokens = system_tokens
			return value
		}
	}
	mut font_style := ?StyleValue(none)
	mut font_variant := ?StyleValue(none)
	mut font_weight := ?StyleValue(none)
	mut font_width := ?StyleValue(none)
	mut font_size := ?StyleValue(none)
	mut line_height := ?StyleValue(none)
	mut font_families := ?StyleValue(none)
	mut normal_count := 0
	mut remaining_longhands := [PropertyID.font_size, PropertyID.font_style, PropertyID.font_weight]

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		peek := transaction.peek() or { break }
		if peek.is(.ident) {
			ident := to_ascii_lowercase(peek.token().ident())
			if ident == 'normal' {
				normal_count++
				transaction.consume()
				transaction.consume_whitespace()
				continue
			}
			// <font-variant-css2> = normal | small-caps.
			if font_variant == none && ident == 'small-caps' {
				transaction.consume()
				font_variant = parser.font_variant_with_caps(StyleValue(KeywordStyleValue.create(.small_caps))) or {
					return none
				}
				transaction.consume_whitespace()
				continue
			}
			// <font-width-css3> is keyword-only here; percentages are accepted by the
			// longhand but not by the font shorthand grammar.
			if font_width == none && ident in ['ultra-condensed', 'extra-condensed', 'condensed',
				'semi-condensed', 'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded'] {
				keyword := keyword_from_string(ident) or { return none }
				transaction.consume()
				font_width = StyleValue(KeywordStyleValue.create(keyword))
				transaction.consume_whitespace()
				continue
			}
		}

		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or {
			return none
		}
		for i, longhand in remaining_longhands {
			if longhand == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		match property_and_value.property {
			.font_size {
				font_size = property_and_value.style_value
				transaction.consume_whitespace()
				if maybe_slash := transaction.peek() {
					if maybe_slash.is_delim(u32(`/`)) {
						transaction.consume()
						line_height = parser.parse_css_value_for_property_tokens(.line_height, mut transaction) or {
							return none
						}
						transaction.consume_whitespace()
					}
				}
				font_families = parser.parse_font_family_value(mut transaction) or { return none }
				transaction.consume_whitespace()
				if transaction.has_more_tokens() {
					return none
				}
			}
			.font_style {
				font_style = property_and_value.style_value
				transaction.consume_whitespace()
			}
			.font_weight {
				font_weight = property_and_value.style_value
				transaction.consume_whitespace()
			}
			else {
				return none
			}
		}
	}

	mut unset_value_count := 0
	if font_style == none {
		unset_value_count++
	}
	if font_weight == none {
		unset_value_count++
	}
	if font_variant == none {
		unset_value_count++
	}
	if font_width == none {
		unset_value_count++
	}
	if unset_value_count < normal_count {
		return none
	}

	size_value := font_size or { return none }
	families_value := font_families or { return none }

	values := [
		families_value,
		size_value,
		font_width or { parser.longhand_initial_typed_value(.font_width) or { return none } },
		font_style or { parser.longhand_initial_typed_value(.font_style) or { return none } },
		font_variant or { parser.shorthand_initial_typed_value(.font_variant) or { return none } },
		font_weight or { parser.longhand_initial_typed_value(.font_weight) or { return none } },
		line_height or { parser.longhand_initial_typed_value(.line_height) or { return none } },
		parser.longhand_initial_typed_value(.font_feature_settings) or { return none },
		parser.longhand_initial_typed_value(.font_kerning) or { return none },
		parser.longhand_initial_typed_value(.font_language_override) or { return none },
		parser.longhand_initial_typed_value(.font_optical_sizing) or { return none },
		parser.longhand_initial_typed_value(.font_variation_settings) or { return none },
		parser.longhand_initial_typed_value(.font_size_adjust) or { return none },
	]

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.font, font_shorthand_longhands, values))
}

struct BackgroundLayer {
	image      StyleValue
	position_x StyleValue
	position_y StyleValue
	size       StyleValue
	repeat     StyleValue
	attachment StyleValue
	origin     StyleValue
	clip       StyleValue
}

// Resolve one background layer's per-longhand values, applying the origin/clip defaulting rule:
// if only one <box> is given it sets both origin and clip; if none are given both use their initial.
fn (mut parser Parser) complete_background_layer(image ?StyleValue, position_x ?StyleValue, position_y ?StyleValue, size ?StyleValue, repeat ?StyleValue, attachment ?StyleValue, origin_in ?StyleValue, clip_in ?StyleValue) ?BackgroundLayer {
	mut origin := origin_in
	mut clip := clip_in
	if origin == none && clip == none {
		origin = parser.longhand_initial_first_value(.background_origin) or { return none }
		clip = parser.longhand_initial_first_value(.background_clip) or { return none }
	} else if clip == none {
		clip = origin
	}
	return BackgroundLayer{
		image: image or {
			parser.longhand_initial_first_value(.background_image) or { return none }
		}
		position_x: position_x or {
			parser.longhand_initial_first_value(.background_position_x) or { return none }
		}
		position_y: position_y or {
			parser.longhand_initial_first_value(.background_position_y) or { return none }
		}
		size: size or {
			parser.longhand_initial_first_value(.background_size) or { return none }
		}
		repeat: repeat or {
			parser.longhand_initial_first_value(.background_repeat) or { return none }
		}
		attachment: attachment or {
			parser.longhand_initial_first_value(.background_attachment) or { return none }
		}
		origin: origin or { return none }
		clip: clip or { return none }
	}
}

// PropertyParsing.cpp: Parser::parse_background_value.
fn (mut parser Parser) parse_background_value(mut tokens ComponentValueStream) ?StyleValue {
	mut layers := []BackgroundLayer{}
	mut background_color := ?StyleValue(none)

	mut image := ?StyleValue(none)
	mut position_x := ?StyleValue(none)
	mut position_y := ?StyleValue(none)
	mut size := ?StyleValue(none)
	mut repeat := ?StyleValue(none)
	mut attachment := ?StyleValue(none)
	mut origin := ?StyleValue(none)
	mut clip := ?StyleValue(none)
	mut remaining_layer_properties := [PropertyID.background_attachment, PropertyID.background_clip,
		PropertyID.background_color, PropertyID.background_image, PropertyID.background_origin,
		PropertyID.background_position, PropertyID.background_repeat]

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		peek := transaction.peek() or { break }
		if peek.is(.comma) {
			if background_color != none {
				return none
			}
			if !(image != none || position_x != none || position_y != none || size != none || repeat != none || attachment != none || origin != none || clip != none) {
				return none
			}
			layer := parser.complete_background_layer(image, position_x, position_y, size, repeat, attachment, origin, clip) or { return none }
			layers << layer
			image = none
			position_x = none
			position_y = none
			size = none
			repeat = none
			attachment = none
			origin = none
			clip = none
			remaining_layer_properties = [PropertyID.background_attachment,
				PropertyID.background_clip, PropertyID.background_color, PropertyID.background_image,
				PropertyID.background_origin, PropertyID.background_position,
				PropertyID.background_repeat]
			transaction.consume()
			transaction.consume_whitespace()
			continue
		}

		mut component_start := transaction.clone()
		property_and_value := parser.parse_css_value_for_properties(remaining_layer_properties, mut transaction) or { return none }
		for i, property_id in remaining_layer_properties {
			if property_id == property_and_value.property {
				remaining_layer_properties.delete(i)
				break
			}
		}
		match property_and_value.property {
			.background_attachment {
				attachment = property_and_value.style_value
			}
			.background_color {
				background_color = property_and_value.style_value
			}
			.background_image {
				image = property_and_value.style_value
			}
			.background_clip, .background_origin {
				// The first <box> sets origin and the second sets clip, regardless
				// of which equivalent grammar entry selected the token.
				if origin == none {
					origin = property_and_value.style_value
				} else if clip == none {
					clip = property_and_value.style_value
				} else {
					return none
				}
			}
			.background_position {
				if property_and_value.style_value !is PositionStyleValue {
					return none
				}
				position := property_and_value.style_value as PositionStyleValue
				position_x = StyleValue(position.edge_x())
				position_y = StyleValue(position.edge_y())

				mut size_attempt := transaction.clone()
				size_attempt.consume_whitespace()
				if maybe_slash := size_attempt.peek() {
					if maybe_slash.is_delim(u32(`/`)) {
						size_attempt.consume()
						size_attempt.consume_whitespace()
						size = parser.parse_single_background_size_value(mut size_attempt) or {
							return none
						}
						transaction = size_attempt
					}
				}
			}
			.background_repeat {
				// The metadata selector consumes the first repeat keyword. Reparse
				// from the component start to collect its optional second keyword.
				repeat = parser.parse_single_repeat_style_value(.background_repeat, mut component_start) or { return none }
				transaction = component_start
			}
			else {
				return none
			}
		}
		transaction.consume_whitespace()
	}

	// The final layer additionally allows background-color.
	if background_color == none && !(image != none || position_x != none || position_y != none || size != none || repeat != none || attachment != none || origin != none || clip != none) {
		return none
	}
	final_layer := parser.complete_background_layer(image, position_x, position_y, size, repeat, attachment, origin, clip) or { return none }
	layers << final_layer

	color_value := background_color or {
		parser.longhand_initial_typed_value(.background_color) or { return none }
	}

	mut images := []StyleValue{}
	mut xs := []StyleValue{}
	mut ys := []StyleValue{}
	mut sizes := []StyleValue{}
	mut repeats := []StyleValue{}
	mut attachments := []StyleValue{}
	mut origins := []StyleValue{}
	mut clips := []StyleValue{}
	for layer in layers {
		images << layer.image
		xs << layer.position_x
		ys << layer.position_y
		sizes << layer.size
		repeats << layer.repeat
		attachments << layer.attachment
		origins << layer.origin
		clips << layer.clip
	}

	position_value := StyleValue(ShorthandStyleValue.create(.background_position, [
		PropertyID.background_position_x,
		PropertyID.background_position_y,
	], [
		StyleValue(StyleValueList.create(xs, .comma, .yes)),
		StyleValue(StyleValueList.create(ys, .comma, .yes)),
	]))
	sub_properties := [PropertyID.background_color, PropertyID.background_image,
		PropertyID.background_position, PropertyID.background_size, PropertyID.background_repeat,
		PropertyID.background_attachment, PropertyID.background_origin, PropertyID.background_clip]
	values := [
		color_value,
		StyleValue(StyleValueList.create(images, .comma, .yes)),
		position_value,
		StyleValue(StyleValueList.create(sizes, .comma, .yes)),
		StyleValue(StyleValueList.create(repeats, .comma, .yes)),
		StyleValue(StyleValueList.create(attachments, .comma, .yes)),
		StyleValue(StyleValueList.create(origins, .comma, .yes)),
		StyleValue(StyleValueList.create(clips, .comma, .yes)),
	]
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.background, sub_properties, values))
}

struct MaskLayer {
	image     StyleValue
	position  StyleValue
	size      StyleValue
	repeat    StyleValue
	origin    StyleValue
	clip      StyleValue
	composite StyleValue
	mode      StyleValue
}

// Resolve one mask layer's per-longhand values. If no <geometry-box> was given, mask-origin uses
// its initial; mask-clip defaults to whatever mask-origin resolved to (unless set via no-clip).
fn (mut parser Parser) complete_mask_layer(image ?StyleValue, position ?StyleValue, size ?StyleValue, repeat ?StyleValue, origin_in ?StyleValue, clip_in ?StyleValue, composite ?StyleValue, mode ?StyleValue) ?MaskLayer {
	mut origin := origin_in
	mut clip := clip_in
	if origin == none {
		origin = parser.longhand_initial_first_value(.mask_origin) or { return none }
	}
	if clip == none {
		clip = origin
	}
	return MaskLayer{
		image: image or { parser.longhand_initial_first_value(.mask_image) or { return none } }
		position: position or {
			parser.longhand_initial_first_value(.mask_position) or { return none }
		}
		size: size or { parser.longhand_initial_first_value(.mask_size) or { return none } }
		repeat: repeat or {
			parser.longhand_initial_first_value(.mask_repeat) or { return none }
		}
		origin: origin or { return none }
		clip: clip or { return none }
		composite: composite or {
			parser.longhand_initial_first_value(.mask_composite) or { return none }
		}
		mode: mode or { parser.longhand_initial_first_value(.mask_mode) or { return none } }
	}
}

// PropertyParsing.cpp: Parser::parse_mask_value.
fn (mut parser Parser) parse_mask_value(mut tokens ComponentValueStream) ?StyleValue {
	mut layers := []MaskLayer{}

	mut image := ?StyleValue(none)
	mut position := ?StyleValue(none)
	mut size := ?StyleValue(none)
	mut repeat := ?StyleValue(none)
	mut origin := ?StyleValue(none)
	mut clip := ?StyleValue(none)
	mut composite := ?StyleValue(none)
	mut mode := ?StyleValue(none)
	mut remaining_layer_properties := [PropertyID.mask_image, PropertyID.mask_position,
		PropertyID.mask_repeat, PropertyID.mask_origin, PropertyID.mask_clip,
		PropertyID.mask_composite, PropertyID.mask_mode]

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		peek := transaction.peek() or { break }
		if peek.is(.comma) {
			if !(image != none || position != none || size != none || repeat != none || origin != none || clip != none || composite != none || mode != none) {
				return none
			}
			layer := parser.complete_mask_layer(image, position, size, repeat, origin, clip, composite, mode) or { return none }
			layers << layer
			image = none
			position = none
			size = none
			repeat = none
			origin = none
			clip = none
			composite = none
			mode = none
			remaining_layer_properties = [PropertyID.mask_image, PropertyID.mask_position,
				PropertyID.mask_repeat, PropertyID.mask_origin, PropertyID.mask_clip,
				PropertyID.mask_composite, PropertyID.mask_mode]
			transaction.consume()
			transaction.consume_whitespace()
			continue
		}

		mut component_start := transaction.clone()
		property_and_value := parser.parse_css_value_for_properties(remaining_layer_properties, mut transaction) or { return none }
		for i, property_id in remaining_layer_properties {
			if property_id == property_and_value.property {
				remaining_layer_properties.delete(i)
				break
			}
		}
		match property_and_value.property {
			.mask_image {
				image = property_and_value.style_value
			}
			.mask_position {
				position = property_and_value.style_value
				mut size_attempt := transaction.clone()
				size_attempt.consume_whitespace()
				if maybe_slash := size_attempt.peek() {
					if maybe_slash.is_delim(u32(`/`)) {
						size_attempt.consume()
						size_attempt.consume_whitespace()
						size = parser.parse_single_background_size_value(mut size_attempt) or {
							return none
						}
						transaction = size_attempt
					}
				}
			}
			.mask_repeat {
				repeat = parser.parse_single_repeat_style_value(.mask_repeat, mut component_start) or {
					return none
				}
				transaction = component_start
			}
			.mask_origin, .mask_clip {
				if property_and_value.style_value.to_keyword() == .no_clip {
					if clip != none {
						return none
					}
					clip = property_and_value.style_value
				} else if origin == none {
					origin = property_and_value.style_value
				} else if clip == none {
					clip = property_and_value.style_value
				} else {
					return none
				}
			}
			.mask_composite {
				composite = property_and_value.style_value
			}
			.mask_mode {
				mode = property_and_value.style_value
			}
			else {
				return none
			}
		}
		transaction.consume_whitespace()
	}

	if !(image != none || position != none || size != none || repeat != none || origin != none || clip != none || composite != none || mode != none) {
		return none
	}
	final_layer := parser.complete_mask_layer(image, position, size, repeat, origin, clip, composite, mode) or { return none }
	layers << final_layer

	mut images := []StyleValue{}
	mut positions := []StyleValue{}
	mut sizes := []StyleValue{}
	mut repeats := []StyleValue{}
	mut origins := []StyleValue{}
	mut clips := []StyleValue{}
	mut composites := []StyleValue{}
	mut modes := []StyleValue{}
	for layer in layers {
		images << layer.image
		positions << layer.position
		sizes << layer.size
		repeats << layer.repeat
		origins << layer.origin
		clips << layer.clip
		composites << layer.composite
		modes << layer.mode
	}

	sub_properties := [PropertyID.mask_image, PropertyID.mask_position, PropertyID.mask_size,
		PropertyID.mask_repeat, PropertyID.mask_origin, PropertyID.mask_clip,
		PropertyID.mask_composite, PropertyID.mask_mode]
	values := if layers.len > 1 {
		[
			StyleValue(StyleValueList.create(images, .comma, .yes)),
			StyleValue(StyleValueList.create(positions, .comma, .yes)),
			StyleValue(StyleValueList.create(sizes, .comma, .yes)),
			StyleValue(StyleValueList.create(repeats, .comma, .yes)),
			StyleValue(StyleValueList.create(origins, .comma, .yes)),
			StyleValue(StyleValueList.create(clips, .comma, .yes)),
			StyleValue(StyleValueList.create(composites, .comma, .yes)),
			StyleValue(StyleValueList.create(modes, .comma, .yes)),
		]
	} else {
		[images[0], positions[0], sizes[0], repeats[0], origins[0], clips[0], composites[0],
			modes[0]]
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.mask, sub_properties, values))
}

// https://drafts.csswg.org/css-transitions/#propdef-transition
fn (mut parser Parser) parse_transition_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_coordinating_value_list_shorthand(mut tokens, .transition, [
		PropertyID.transition_property,
		PropertyID.transition_duration,
		PropertyID.transition_timing_function,
		PropertyID.transition_delay,
		PropertyID.transition_behavior,
	], []) or { return none }

	// If there is more than one transition and any has a `none` transition-property, it is invalid.
	if value is ShorthandStyleValue {
		if property_list := value.longhand(.transition_property) {
			if property_list is StyleValueList {
				entries := property_list.values()
				if entries.len > 1 {
					for entry in entries {
						if entry is KeywordStyleValue && entry.keyword() == .none_ {
							return none
						}
					}
				}
			}
		}
	}
	return value
}

// Parses a `||` combination of longhand components in any order (each parsed via its own longhand
// grammar). Omitted components fall back to their initial value.
fn (mut parser Parser) parse_double_bar_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, component_ids []PropertyID) ?StyleValue {
	mut values := []?StyleValue{}
	for _ in component_ids {
		values << ?StyleValue(none)
	}

	for {
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			break
		}
		mut matched := false
		for i, component_id in component_ids {
			if values[i] != none {
				continue
			}
			mut attempt := tokens.clone()
			if value := parser.parse_css_value_for_property_tokens(component_id, mut attempt) {
				values[i] = value
				tokens = attempt
				matched = true
				break
			}
		}
		if !matched {
			break
		}
	}

	mut any_matched := false
	for value in values {
		if value != none {
			any_matched = true
			break
		}
	}
	if !any_matched {
		return none
	}

	mut resolved := []StyleValue{}
	for i, component_id in component_ids {
		if value := values[i] {
			resolved << value
		} else {
			resolved << parser.longhand_initial_typed_value(component_id) or { return none }
		}
	}
	return StyleValue(ShorthandStyleValue.create(shorthand, component_ids, resolved))
}

struct BorderEdgeComponents {
	width StyleValue
	style StyleValue
	color StyleValue
}

// <line-width> || <line-style> || <color>  (omitted components fall back to their initial values).
fn (mut parser Parser) parse_border_edge_components(mut tokens ComponentValueStream) ?BorderEdgeComponents {
	mut width := ?StyleValue(none)
	mut style := ?StyleValue(none)
	mut color := ?StyleValue(none)
	for {
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			break
		}
		if width == none {
			mut attempt := tokens.clone()
			if value := parser.parse_border_or_outline_width_value(.border_top_width, mut attempt) {
				width = value
				tokens = attempt
				continue
			}
		}
		if style == none {
			mut attempt := tokens.clone()
			if value := parser.parse_line_style_value(mut attempt) {
				style = value
				tokens = attempt
				continue
			}
		}
		if color == none {
			mut attempt := tokens.clone()
			if value := parser.parse_color_value(mut attempt) {
				color = value
				tokens = attempt
				continue
			}
		}
		break
	}
	if width == none && style == none && color == none {
		return none
	}
	return BorderEdgeComponents{
		width: width or { StyleValue(KeywordStyleValue.create(.medium)) }
		style: style or { StyleValue(KeywordStyleValue.create(.none_)) }
		color: color or { StyleValue(KeywordStyleValue.create(.currentcolor)) }
	}
}

fn (mut parser Parser) parse_border_edge_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, width_id PropertyID, style_id PropertyID, color_id PropertyID) ?StyleValue {
	c := parser.parse_border_edge_components(mut tokens) or { return none }
	return StyleValue(ShorthandStyleValue.create(shorthand, [width_id, style_id, color_id], [
		c.width,
		c.style,
		c.color,
	]))
}

fn (mut parser Parser) parse_border_top_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_top, .border_top_width, .border_top_style, .border_top_color)
}

fn (mut parser Parser) parse_border_right_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_right, .border_right_width, .border_right_style, .border_right_color)
}

fn (mut parser Parser) parse_border_bottom_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_bottom, .border_bottom_width, .border_bottom_style, .border_bottom_color)
}

fn (mut parser Parser) parse_border_left_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_left, .border_left_width, .border_left_style, .border_left_color)
}

fn (mut parser Parser) parse_border_block_start_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_block_start, .border_block_start_width, .border_block_start_style, .border_block_start_color)
}

fn (mut parser Parser) parse_border_block_end_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_block_end, .border_block_end_width, .border_block_end_style, .border_block_end_color)
}

fn (mut parser Parser) parse_border_inline_start_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_inline_start, .border_inline_start_width, .border_inline_start_style, .border_inline_start_color)
}

fn (mut parser Parser) parse_border_inline_end_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_border_edge_shorthand(mut tokens, .border_inline_end, .border_inline_end_width, .border_inline_end_style, .border_inline_end_color)
}

fn single_value_shorthand(property_id PropertyID, value StyleValue) ?StyleValue {
	longhands := generated_longhands_for_shorthand(property_id)
	if longhands.len == 0 {
		return none
	}
	mut values := []StyleValue{cap: longhands.len}
	for _ in longhands {
		values << value
	}
	return StyleValue(ShorthandStyleValue.create(property_id, longhands, values))
}

// PropertyParsing.cpp: Parser::parse_border_value.
fn (mut parser Parser) parse_border_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut color_property := PropertyID.border_color
	mut style_property := PropertyID.border_style
	mut width_property := PropertyID.border_width
	match property_id {
		.border {}
		.border_block {
			color_property = .border_block_color
			style_property = .border_block_style
			width_property = .border_block_width
		}
		.border_inline {
			color_property = .border_inline_color
			style_property = .border_inline_style
			width_property = .border_inline_width
		}
		else {
			return none
		}
	}

	mut border_width := ?StyleValue(none)
	mut border_color := ?StyleValue(none)
	mut border_style := ?StyleValue(none)
	mut remaining_longhands := [width_property, color_property, style_property]
	mut transaction := tokens.clone()
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
		for i, remaining_longhand in remaining_longhands {
			if remaining_longhand == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		nested := single_value_shorthand(property_and_value.property, property_and_value.style_value) or { return none }
		if property_and_value.property == width_property {
			border_width = nested
		} else if property_and_value.property == color_property {
			border_color = nested
		} else if property_and_value.property == style_property {
			border_style = nested
		} else {
			return none
		}
	}

	resolved_width := border_width or {
		parser.shorthand_initial_typed_value(width_property) or { return none }
	}
	resolved_style := border_style or {
		parser.shorthand_initial_typed_value(style_property) or { return none }
	}
	resolved_color := border_color or {
		parser.shorthand_initial_typed_value(color_property) or { return none }
	}
	tokens = transaction
	if property_id in [PropertyID.border_block, .border_inline] {
		return StyleValue(ShorthandStyleValue.create(property_id, [width_property, style_property,
			color_property], [resolved_width, resolved_style, resolved_color]))
	}

	border_image := parser.shorthand_initial_typed_value(.border_image) or { return none }
	return StyleValue(ShorthandStyleValue.create(.border, [width_property, style_property,
		color_property, PropertyID.border_image], [resolved_width, resolved_style, resolved_color,
		border_image]))
}

// https://drafts.csswg.org/css-ui/#propdef-outline  ->  <'outline-color'> || <'outline-style'> || <'outline-width'>
fn (mut parser Parser) parse_outline_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_double_bar_shorthand(mut tokens, .outline, [
		PropertyID.outline_color,
		PropertyID.outline_style,
		PropertyID.outline_width,
	])
}

// https://drafts.csswg.org/css-multicol/#propdef-column-rule
// <'column-rule-width'> || <'column-rule-style'> || <'column-rule-color'>
fn (mut parser Parser) parse_column_rule_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_double_bar_shorthand(mut tokens, .column_rule, [
		PropertyID.column_rule_width,
		PropertyID.column_rule_style,
		PropertyID.column_rule_color,
	])
}

// PropertyParsing.cpp: Parser::parse_list_style_value.
fn (mut parser Parser) parse_list_style_value(mut tokens ComponentValueStream) ?StyleValue {
	mut position := ?StyleValue(none)
	mut image := ?StyleValue(none)
	mut type_ := ?StyleValue(none)
	mut found_nones := 0
	mut remaining := [PropertyID.list_style_image, PropertyID.list_style_position,
		PropertyID.list_style_type]
	mut transaction := tokens.clone()

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		if peek := transaction.peek() {
			if peek.is(.ident) && equals_ignoring_ascii_case(peek.token().ident(), 'none') {
				transaction.consume()
				found_nones++
				continue
			}
		}

		property_and_value := parser.parse_css_value_for_properties(remaining, mut transaction) or {
			return none
		}
		transaction.consume_whitespace()
		for i, property_id in remaining {
			if property_id == property_and_value.property {
				remaining.delete(i)
				break
			}
		}
		match property_and_value.property {
			.list_style_position {
				position = property_and_value.style_value
			}
			.list_style_image {
				image = property_and_value.style_value
			}
			.list_style_type {
				type_ = property_and_value.style_value
			}
			else {
				return none
			}
		}
	}

	if found_nones > 2 {
		return none
	}
	none_value := StyleValue(KeywordStyleValue.create(.none_))
	if found_nones == 2 {
		if image != none || type_ != none {
			return none
		}
		image = none_value
		type_ = none_value
	} else if found_nones == 1 {
		if image != none && type_ != none {
			return none
		}
		if image == none {
			image = none_value
		}
		if type_ == none {
			type_ = none_value
		}
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.list_style, [
		PropertyID.list_style_position,
		PropertyID.list_style_image,
		PropertyID.list_style_type,
	], [
		position or { parser.longhand_initial_typed_value(.list_style_position) or { return none } },
		image or { parser.longhand_initial_typed_value(.list_style_image) or { return none } },
		type_ or { parser.longhand_initial_typed_value(.list_style_type) or { return none } },
	]))
}

// PropertyParsing.cpp: Parser::parse_text_decoration_value.
fn (mut parser Parser) parse_text_decoration_value(mut tokens ComponentValueStream) ?StyleValue {
	mut decoration_line := ?StyleValue(none)
	mut decoration_thickness := ?StyleValue(none)
	mut decoration_style := ?StyleValue(none)
	mut decoration_color := ?StyleValue(none)
	mut remaining_longhands := [PropertyID.text_decoration_color, PropertyID.text_decoration_line,
		PropertyID.text_decoration_style, PropertyID.text_decoration_thickness]
	mut transaction := tokens.clone()

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		mut component_start := transaction.clone()
		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
		for i, property_id in remaining_longhands {
			if property_id == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		match property_and_value.property {
			.text_decoration_color {
				decoration_color = property_and_value.style_value
			}
			.text_decoration_line {
				line := parser.parse_text_decoration_line_value(mut component_start) or {
					return none
				}
				decoration_line = line
				transaction = component_start
			}
			.text_decoration_thickness {
				decoration_thickness = property_and_value.style_value
			}
			.text_decoration_style {
				decoration_style = property_and_value.style_value
			}
			else {
				return none
			}
		}
	}

	resolved_line := decoration_line or {
		parser.longhand_initial_typed_value(.text_decoration_line) or { return none }
	}
	resolved_thickness := decoration_thickness or {
		parser.longhand_initial_typed_value(.text_decoration_thickness) or { return none }
	}
	resolved_style := decoration_style or {
		parser.longhand_initial_typed_value(.text_decoration_style) or { return none }
	}
	resolved_color := decoration_color or {
		parser.longhand_initial_typed_value(.text_decoration_color) or { return none }
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.text_decoration, [
		PropertyID.text_decoration_line,
		PropertyID.text_decoration_thickness,
		PropertyID.text_decoration_style,
		PropertyID.text_decoration_color,
	], [resolved_line, resolved_thickness, resolved_style, resolved_color]))
}

// https://drafts.csswg.org/css-fonts/#propdef-font-variant
// PropertyParsing.cpp: Parser::parse_font_variant.
fn (mut parser Parser) parse_font_variant(mut tokens ComponentValueStream) ?StyleValue {
	mut alternates_value := ?StyleValue(none)
	mut caps_value := ?StyleValue(none)
	mut east_asian_value := ?StyleValue(none)
	mut emoji_value := ?StyleValue(none)
	mut ligatures_value := ?StyleValue(none)
	mut numeric_value := ?StyleValue(none)
	mut position_value := ?StyleValue(none)

	mut transaction := tokens.clone()
	mut matched_single_keyword := false
	if _ := parser.parse_all_as_single_keyword_value(mut transaction, .normal) {
		matched_single_keyword = true
	} else if none_value := parser.parse_all_as_single_keyword_value(mut transaction, .none_) {
		ligatures_value = none_value
		matched_single_keyword = true
	}

	if !matched_single_keyword {
		for transaction.has_more_tokens() {
			if value := parser.parse_font_variant_ligatures_value(mut transaction) {
				if ligatures_value != none {
					return none
				}
				ligatures_value = value
				continue
			}
			if value := parser.parse_font_variant_alternates_value(mut transaction) {
				if alternates_value != none {
					return none
				}
				alternates_value = value
				continue
			}
			if value := parser.parse_font_variant_numeric_value(mut transaction) {
				if numeric_value != none {
					return none
				}
				numeric_value = value
				continue
			}
			if value := parser.parse_font_variant_east_asian_value(mut transaction) {
				if east_asian_value != none {
					return none
				}
				east_asian_value = value
				continue
			}

			value := parser.parse_keyword_value(mut transaction) or { return none }
			match value.to_keyword() {
				.small_caps, .all_small_caps, .petite_caps, .all_petite_caps, .unicase, .titling_caps {
					if caps_value != none {
						return none
					}
					caps_value = value
				}
				.text, .emoji, .unicode {
					if emoji_value != none {
						return none
					}
					emoji_value = value
				}
				.sub, .super {
					if position_value != none {
						return none
					}
					position_value = value
				}
				else {
					return none
				}
			}
		}
	}

	normal := StyleValue(KeywordStyleValue.create(.normal))
	values := [
		alternates_value or { normal },
		caps_value or { normal },
		east_asian_value or { normal },
		emoji_value or { normal },
		ligatures_value or { normal },
		numeric_value or { normal },
		position_value or { normal },
	]
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.font_variant, font_variant_longhands, values))
}

fn flex_shorthand_value(grow StyleValue, shrink StyleValue, basis StyleValue) StyleValue {
	return StyleValue(ShorthandStyleValue.create(.flex, [PropertyID.flex_grow,
		PropertyID.flex_shrink, PropertyID.flex_basis], [grow, shrink, basis]))
}

// PropertyParsing.cpp: Parser::parse_flex_shorthand_value.
fn (mut parser Parser) parse_flex_shorthand_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()

	if transaction.has_one_token() {
		property_and_value := parser.parse_css_value_for_properties([
			PropertyID.flex_grow,
			PropertyID.flex_basis,
			PropertyID.flex,
		], mut transaction) or { return none }
		one := StyleValue(NumberStyleValue.create(1))
		match property_and_value.property {
			.flex_grow {
				tokens = transaction
				return flex_shorthand_value(property_and_value.style_value, one, StyleValue(PercentageStyleValue.create(Percentage.new(0))))
			}
			.flex_basis {
				tokens = transaction
				return flex_shorthand_value(one, one, property_and_value.style_value)
			}
			.flex {
				if property_and_value.style_value.to_keyword() != .none_ {
					return none
				}
				zero := StyleValue(NumberStyleValue.create(0))
				tokens = transaction
				return flex_shorthand_value(zero, zero, StyleValue(KeywordStyleValue.create(.auto)))
			}
			else {
				return none
			}
		}
	}

	mut flex_grow := ?StyleValue(none)
	mut flex_shrink := ?StyleValue(none)
	mut flex_basis := ?StyleValue(none)
	mut remaining_longhands := [PropertyID.flex_grow, PropertyID.flex_basis]

	for transaction.has_more_tokens() {
		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
		for i, remaining_longhand in remaining_longhands {
			if remaining_longhand == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		match property_and_value.property {
			.flex_grow {
				flex_grow = property_and_value.style_value
				if shrink := parser.parse_css_value_for_properties([
					PropertyID.flex_shrink,
				], mut transaction) {
					flex_shrink = shrink.style_value
				}
			}
			.flex_basis {
				flex_basis = property_and_value.style_value
			}
			else {
				return none
			}
		}
	}

	resolved_grow := flex_grow or {
		parser.longhand_initial_typed_value(.flex_grow) or { return none }
	}
	resolved_shrink := flex_shrink or {
		parser.longhand_initial_typed_value(.flex_shrink) or { return none }
	}
	resolved_basis := flex_basis or {
		StyleValue(PercentageStyleValue.create(Percentage.new(0)))
	}
	tokens = transaction
	return flex_shorthand_value(resolved_grow, resolved_shrink, resolved_basis)
}

// https://drafts.csswg.org/css-text-4/#propdef-white-space
// normal | pre | pre-wrap | pre-line | <'white-space-collapse'> || <'text-wrap-mode'> || <'white-space-trim'>
fn (mut parser Parser) parse_white_space_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	mut keyword_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut keyword_attempt, ['normal', 'pre', 'pre-wrap',
		'pre-line']) {
		if value is KeywordStyleValue {
			mut collapse := Keyword.collapse
			mut mode := Keyword.wrap
			match value.keyword() {
				.pre {
					collapse = .preserve
					mode = .nowrap
				}
				.pre_wrap {
					collapse = .preserve
					mode = .wrap
				}
				.pre_line {
					collapse = .preserve_breaks
					mode = .wrap
				}
				else {}
			}
			tokens = keyword_attempt
			return StyleValue(ShorthandStyleValue.create(.white_space, [
				PropertyID.white_space_collapse,
				PropertyID.text_wrap_mode,
				PropertyID.white_space_trim,
			], [
				StyleValue(KeywordStyleValue.create(collapse)),
				StyleValue(KeywordStyleValue.create(mode)),
				StyleValue(KeywordStyleValue.create(.none_)),
			]))
		}
	}

	return parser.parse_double_bar_shorthand(mut tokens, .white_space, [
		PropertyID.white_space_collapse,
		PropertyID.text_wrap_mode,
		PropertyID.white_space_trim,
	])
}

// {1,4} non-negative <length-percentage>s expanded to corner order [ TL, TR, BR, BL ].
fn (mut parser Parser) parse_border_radius_lp_list(group []ComponentValue) ?[]StyleValue {
	mut stream := ComponentValueStream.new(group)
	mut parsed := []StyleValue{}
	for parsed.len < 4 {
		stream.consume_whitespace()
		if !stream.has_more_tokens() {
			break
		}
		value := parser.parse_nonnegative_length_percentage_value(mut stream) or { break }
		parsed << value
	}
	stream.consume_whitespace()
	if parsed.len == 0 || stream.has_more_tokens() {
		return none
	}
	tl := parsed[0]
	tr := if parsed.len > 1 { parsed[1] } else { tl }
	br := if parsed.len > 2 { parsed[2] } else { tl }
	bl := if parsed.len > 3 { parsed[3] } else { tr }
	return [tl, tr, br, bl]
}

// PropertyParsing.cpp: Parser::parse_border_radius_shorthand_value.
fn (mut parser Parser) parse_border_radius_shorthand_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_border_radius_rect_value(mut transaction) or { return none }
	if value !is BorderRadiusRectStyleValue {
		return none
	}
	border_radius_rect := value as BorderRadiusRectStyleValue
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.border_radius, [
		PropertyID.border_top_left_radius,
		PropertyID.border_top_right_radius,
		PropertyID.border_bottom_right_radius,
		PropertyID.border_bottom_left_radius,
	], [
		border_radius_rect.top_left(),
		border_radius_rect.top_right(),
		border_radius_rect.bottom_right(),
		border_radius_rect.bottom_left(),
	]))
}

// overflow-clip-margin* — a single `<visual-box> || <length [0,∞]>` applied to every referenced edge.
fn (mut parser Parser) parse_overflow_clip_margin_shorthand(mut tokens ComponentValueStream, shorthand PropertyID, longhands []PropertyID) ?StyleValue {
	value := parser.parse_overflow_clip_margin_value(mut tokens) or { return none }
	mut values := []StyleValue{}
	for _ in longhands {
		values << value
	}
	return StyleValue(ShorthandStyleValue.create(shorthand, longhands, values))
}

fn grid_split_by_slash(values []ComponentValue) [][]ComponentValue {
	mut groups := [][]ComponentValue{}
	mut current := []ComponentValue{}
	for value in values {
		if value.is_delim(u32(`/`)) {
			groups << current
			current = []ComponentValue{}
		} else {
			current << value
		}
	}
	groups << current
	return groups
}

struct GridPlacementParse {
	placement ?GridTrackPlacement // none = the group was empty (caller substitutes the default)
}

fn (mut parser Parser) parse_grid_placement_group(group []ComponentValue) ?GridPlacementParse {
	mut stream := ComponentValueStream.new(group)
	stream.consume_whitespace()
	if !stream.has_more_tokens() {
		return GridPlacementParse{
			placement: none
		}
	}
	value := parser.parse_grid_track_placement(mut stream) or { return none }
	stream.consume_whitespace()
	if stream.has_more_tokens() {
		return none
	}
	if value is GridTrackPlacementStyleValue {
		return GridPlacementParse{
			placement: value.grid_track_placement()
		}
	}
	return none
}

// <grid-line> [ / <grid-line> ]?  (grid-row / grid-column)
// PropertyParsing.cpp: Parser::parse_grid_track_placement_shorthand_value.
fn (mut parser Parser) parse_grid_track_placement_shorthand_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	start_id := if property_id == .grid_column {
		PropertyID.grid_column_start
	} else {
		PropertyID.grid_row_start
	}
	end_id := if property_id == .grid_column {
		PropertyID.grid_column_end
	} else {
		PropertyID.grid_row_end
	}
	mut transaction := tokens.clone()
	groups := grid_split_by_slash(transaction.consume_remaining_component_values())
	if groups.len < 1 || groups.len > 2 {
		return none
	}

	start_result := parser.parse_grid_placement_group(groups[0]) or { return none }
	start_placement := start_result.placement or { return none }

	mut end_placement := GridTrackPlacement.make_auto()
	if groups.len == 2 {
		end_result := parser.parse_grid_placement_group(groups[1]) or { return none }
		end_placement = end_result.placement or { return none }
	} else if start_placement.is_custom_ident() {
		// An omitted end with a <custom-ident> start copies the start; otherwise it is `auto`.
		end_placement = start_placement
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(property_id, [start_id, end_id], [
		StyleValue(GridTrackPlacementStyleValue.create(start_placement)),
		StyleValue(GridTrackPlacementStyleValue.create(end_placement)),
	]))
}

// <grid-line> [ / <grid-line> ]{0,3}  (grid-area)
// PropertyParsing.cpp: Parser::parse_grid_area_shorthand_value.
fn (mut parser Parser) parse_grid_area_shorthand_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	groups := grid_split_by_slash(transaction.consume_remaining_component_values())
	if groups.len < 1 || groups.len > 4 {
		return none
	}

	mut placements := []?GridTrackPlacement{}
	for group in groups {
		result := parser.parse_grid_placement_group(group) or { return none }
		placements << result.placement
	}
	for placements.len < 4 {
		placements << ?GridTrackPlacement(none)
	}

	mut row_start := GridTrackPlacement.make_auto()
	if maybe := placements[0] {
		row_start = maybe
	}
	mut column_start := GridTrackPlacement.make_auto()
	if maybe := placements[1] {
		column_start = maybe
	} else if row_start.is_custom_ident() {
		column_start = row_start
	}
	mut row_end := GridTrackPlacement.make_auto()
	if maybe := placements[2] {
		row_end = maybe
	} else if row_start.is_custom_ident() {
		row_end = row_start
	}
	mut column_end := GridTrackPlacement.make_auto()
	if maybe := placements[3] {
		column_end = maybe
	} else if column_start.is_custom_ident() {
		column_end = column_start
	}

	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.grid_area, [
		PropertyID.grid_row_start,
		PropertyID.grid_column_start,
		PropertyID.grid_row_end,
		PropertyID.grid_column_end,
	], [
		StyleValue(GridTrackPlacementStyleValue.create(row_start)),
		StyleValue(GridTrackPlacementStyleValue.create(column_start)),
		StyleValue(GridTrackPlacementStyleValue.create(row_end)),
		StyleValue(GridTrackPlacementStyleValue.create(column_end)),
	]))
}

fn (mut parser Parser) parse_corner_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_4_shorthand(mut tokens, .corner_shape, [
		PropertyID.corner_top_left_shape,
		PropertyID.corner_top_right_shape,
		PropertyID.corner_bottom_right_shape,
		PropertyID.corner_bottom_left_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_top_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_top_shape, [
		PropertyID.corner_top_left_shape,
		PropertyID.corner_top_right_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_bottom_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_bottom_shape, [
		PropertyID.corner_bottom_left_shape,
		PropertyID.corner_bottom_right_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_left_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_left_shape, [
		PropertyID.corner_top_left_shape,
		PropertyID.corner_bottom_left_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_right_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_right_shape, [
		PropertyID.corner_top_right_shape,
		PropertyID.corner_bottom_right_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_block_start_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_block_start_shape, [
		PropertyID.corner_start_start_shape,
		PropertyID.corner_start_end_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_block_end_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_block_end_shape, [
		PropertyID.corner_end_start_shape,
		PropertyID.corner_end_end_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_inline_start_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_inline_start_shape, [
		PropertyID.corner_start_start_shape,
		PropertyID.corner_end_start_shape,
	], .corner_shape)
}

fn (mut parser Parser) parse_corner_inline_end_shape_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_box_2_shorthand(mut tokens, .corner_inline_end_shape, [
		PropertyID.corner_start_end_shape,
		PropertyID.corner_end_end_shape,
	], .corner_shape)
}

// PropertyParsing.cpp: Parser::parse_flex_flow_value.
fn (mut parser Parser) parse_flex_flow_value(mut tokens ComponentValueStream) ?StyleValue {
	mut flex_direction := ?StyleValue(none)
	mut flex_wrap := ?StyleValue(none)
	mut remaining_longhands := [PropertyID.flex_direction, PropertyID.flex_wrap]
	mut transaction := tokens.clone()

	for transaction.has_more_tokens() {
		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
		for i, remaining_longhand in remaining_longhands {
			if remaining_longhand == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		match property_and_value.property {
			.flex_direction {
				flex_direction = property_and_value.style_value
			}
			.flex_wrap {
				flex_wrap = property_and_value.style_value
			}
			else {
				return none
			}
		}
	}

	resolved_direction := flex_direction or {
		parser.longhand_initial_typed_value(.flex_direction) or { return none }
	}
	resolved_wrap := flex_wrap or {
		parser.longhand_initial_typed_value(.flex_wrap) or { return none }
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.flex_flow, [
		PropertyID.flex_direction,
		PropertyID.flex_wrap,
	], [resolved_direction, resolved_wrap]))
}

// PropertyParsing.cpp: Parser::parse_columns_value.
fn (mut parser Parser) parse_columns_value(mut tokens ComponentValueStream) ?StyleValue {
	mut column_count := ?StyleValue(none)
	mut column_width := ?StyleValue(none)
	mut column_height := ?StyleValue(none)
	mut remaining_longhands := [PropertyID.column_count, PropertyID.column_width]
	mut found_autos := 0
	mut values_read := 0

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		if peek := transaction.peek() {
			if peek.is_delim(u32(`/`)) {
				if values_read == 0 {
					return none
				}
				transaction.consume()
				transaction.consume_whitespace()
				property_and_value := parser.parse_css_value_for_properties([
					PropertyID.column_height,
				], mut transaction) or { return none }
				column_height = property_and_value.style_value
				transaction.consume_whitespace()
				if transaction.has_more_tokens() {
					return none
				}
				break
			}
		}

		if values_read == 2 {
			return none
		}
		values_read++

		property_and_value := parser.parse_css_value_for_properties(remaining_longhands, mut transaction) or { return none }
		transaction.consume_whitespace()
		if property_and_value.style_value.has_auto() {
			found_autos++
			continue
		}

		for i, remaining_longhand in remaining_longhands {
			if remaining_longhand == property_and_value.property {
				remaining_longhands.delete(i)
				break
			}
		}
		match property_and_value.property {
			.column_count {
				column_count = property_and_value.style_value
			}
			.column_width {
				column_width = property_and_value.style_value
			}
			else {
				return none
			}
		}
	}

	if found_autos == 2 {
		column_count = StyleValue(KeywordStyleValue.create(.auto))
		column_width = StyleValue(KeywordStyleValue.create(.auto))
	}
	if found_autos == 1 {
		if column_count == none {
			column_count = StyleValue(KeywordStyleValue.create(.auto))
		}
		if column_width == none {
			column_width = StyleValue(KeywordStyleValue.create(.auto))
		}
	}

	resolved_count := column_count or {
		parser.longhand_initial_typed_value(.column_count) or { return none }
	}
	resolved_width := column_width or {
		parser.longhand_initial_typed_value(.column_width) or { return none }
	}
	resolved_height := column_height or {
		parser.longhand_initial_typed_value(.column_height) or { return none }
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.columns, [
		PropertyID.column_count,
		PropertyID.column_width,
		PropertyID.column_height,
	], [resolved_count, resolved_width, resolved_height]))
}

// https://drafts.csswg.org/css-text-4/#propdef-text-wrap  ->  <'text-wrap-mode'> || <'text-wrap-style'>
fn (mut parser Parser) parse_text_wrap_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	mut mode := ?StyleValue(none)
	mut style := ?StyleValue(none)
	for {
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			break
		}
		if mode == none {
			mut attempt := tokens.clone()
			if value := parser.parse_text_wrap_mode_value(mut attempt) {
				mode = value
				tokens = attempt
				continue
			}
		}
		if style == none {
			mut attempt := tokens.clone()
			if value := parser.parse_text_wrap_style_value(mut attempt) {
				style = value
				tokens = attempt
				continue
			}
		}
		break
	}
	if mode == none && style == none {
		return none
	}
	resolved_mode := mode or { StyleValue(KeywordStyleValue.create(.wrap)) }
	resolved_style := style or { StyleValue(KeywordStyleValue.create(.auto)) }
	return StyleValue(ShorthandStyleValue.create(.text_wrap, [
		PropertyID.text_wrap_mode,
		PropertyID.text_wrap_style,
	], [resolved_mode, resolved_style]))
}

// https://drafts.csswg.org/css-align/#propdef-gap  ->  <'row-gap'> <'column-gap'>?
fn (mut parser Parser) parse_gap_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	row := parser.parse_gap_value(mut tokens) or { return none }
	mut column := row
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		column = parser.parse_gap_value(mut transaction) or { return none }
		tokens = transaction
	}
	return StyleValue(ShorthandStyleValue.create(.gap, [PropertyID.row_gap, PropertyID.column_gap], [
		row,
		column,
	]))
}

// PropertyParsing.cpp: Parser::parse_place_items_value.
fn (mut parser Parser) parse_place_items_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	align := parser.parse_align_items_value(mut transaction) or {
		return none
	}
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(ShorthandStyleValue.create(.place_items, [
			PropertyID.align_items,
			PropertyID.justify_items,
		], [align, align]))
	}

	justify := parser.parse_justify_items_value(mut transaction) or {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.place_items, [
		PropertyID.align_items,
		PropertyID.justify_items,
	], [align, justify]))
}

// PropertyParsing.cpp: Parser::parse_place_content_value.
fn (mut parser Parser) parse_place_content_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	align := parser.parse_align_content_value(mut transaction) or {
		return none
	}
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		justify := if align.to_keyword() == .baseline || align.to_string() == 'last baseline' {
			StyleValue(KeywordStyleValue.create(.start))
		} else { align }
		tokens = transaction
		return StyleValue(ShorthandStyleValue.create(.place_content, [
			PropertyID.align_content,
			PropertyID.justify_content,
		], [align, justify]))
	}

	justify := parser.parse_justify_content_value(mut transaction) or {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.place_content, [
		PropertyID.align_content,
		PropertyID.justify_content,
	], [align, justify]))
}

// PropertyParsing.cpp: Parser::parse_place_self_value.
fn (mut parser Parser) parse_place_self_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	align := parser.parse_align_self_value(mut transaction) or {
		return none
	}
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(ShorthandStyleValue.create(.place_self, [
			PropertyID.align_self,
			PropertyID.justify_self,
		], [align, align]))
	}

	justify := parser.parse_justify_self_value(mut transaction) or {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.place_self, [PropertyID.align_self,
		PropertyID.justify_self], [align, justify]))
}

// https://drafts.csswg.org/css-overflow/#propdef-overflow  ->  <'overflow-x'> <'overflow-y'>?
fn (mut parser Parser) parse_overflow_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	x := parser.parse_overflow_value(.overflow_x, mut tokens) or { return none }
	mut y := x
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		y = parser.parse_overflow_value(.overflow_y, mut transaction) or { return none }
		tokens = transaction
	}
	return StyleValue(ShorthandStyleValue.create(.overflow, [PropertyID.overflow_x,
		PropertyID.overflow_y], [x, y]))
}

// https://drafts.csswg.org/css-fonts/#font-variant-alternates-prop
// normal | [ stylistic() || historical-forms || styleset() || character-variant() || swash() || ornaments() || annotation() ]
fn (mut parser Parser) parse_font_variant_alternates_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_all_as_single_keyword_value(mut tokens, .normal) {
		return value
	}

	mut transaction := tokens.clone()
	mut stylistic := ?StyleValue(none)
	mut historical_forms := ?StyleValue(none)
	mut styleset := ?StyleValue(none)
	mut character_variant := ?StyleValue(none)
	mut swash := ?StyleValue(none)
	mut ornaments := ?StyleValue(none)
	mut annotation := ?StyleValue(none)

	for {
		transaction.consume_whitespace()
		peek := transaction.peek() or { break }

		// historical-forms
		if peek.is(.ident) && equals_ignoring_ascii_case(peek.token().ident(), 'historical-forms') {
			if historical_forms != none {
				return none
			}
			keyword := keyword_from_string('historical-forms') or { return none }
			transaction.consume()
			historical_forms = StyleValue(KeywordStyleValue.create(keyword))
			continue
		}

		if !peek.is_function() {
			break
		}
		function := peek.function()
		function_name := to_ascii_lowercase(function.name)
		call_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(function.value)
		if call_arguments.len == 0 {
			break
		}

		// <feature-value-name># = <ident>#
		mut feature_value_names := []StyleValue{}
		for argument in call_arguments {
			mut argument_tokens := ComponentValueStream.new(argument)
			ident := parser.parse_custom_ident_value(mut argument_tokens, []) or { return none }
			argument_tokens.consume_whitespace()
			if argument_tokens.has_more_tokens() {
				return none
			}
			feature_value_names << StyleValue(ident)
		}

		match function_name {
			'stylistic' {
				if feature_value_names.len != 1 || stylistic != none {
					return none
				}
				transaction.consume()
				stylistic = StyleValue(FunctionStyleValue.create('stylistic', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			'styleset' {
				if styleset != none {
					return none
				}
				transaction.consume()
				styleset = StyleValue(FunctionStyleValue.create('styleset', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			'character-variant' {
				if character_variant != none {
					return none
				}
				transaction.consume()
				character_variant = StyleValue(FunctionStyleValue.create('character-variant', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			'swash' {
				if feature_value_names.len != 1 || swash != none {
					return none
				}
				transaction.consume()
				swash = StyleValue(FunctionStyleValue.create('swash', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			'ornaments' {
				if feature_value_names.len != 1 || ornaments != none {
					return none
				}
				transaction.consume()
				ornaments = StyleValue(FunctionStyleValue.create('ornaments', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			'annotation' {
				if feature_value_names.len != 1 || annotation != none {
					return none
				}
				transaction.consume()
				annotation = StyleValue(FunctionStyleValue.create('annotation', StyleValue(StyleValueList.create(feature_value_names, .comma, .yes))))
			}
			else {
				break
			}
		}
	}

	// Assemble the non-empty components in canonical order.
	mut values := []StyleValue{}
	if value := stylistic {
		values << value
	}
	if value := historical_forms {
		values << value
	}
	if value := styleset {
		values << value
	}
	if value := character_variant {
		values << value
	}
	if value := swash {
		values << value
	}
	if value := ornaments {
		values << value
	}
	if value := annotation {
		values << value
	}

	if values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn font_variant_ligatures_slot(ident string) ?int {
	return match ident {
		'common-ligatures', 'no-common-ligatures' { 0 }
		'discretionary-ligatures', 'no-discretionary-ligatures' { 1 }
		'historical-ligatures', 'no-historical-ligatures' { 2 }
		'contextual', 'no-contextual' { 3 }
		else { none }
	}
}

fn font_variant_numeric_slot(ident string) ?int {
	return match ident {
		'lining-nums', 'oldstyle-nums' { 0 }
		'proportional-nums', 'tabular-nums' { 1 }
		'diagonal-fractions', 'stacked-fractions' { 2 }
		'ordinal' { 3 }
		'slashed-zero' { 4 }
		else { none }
	}
}

fn font_variant_east_asian_slot(ident string) ?int {
	return match ident {
		'jis78', 'jis83', 'jis90', 'jis04', 'simplified', 'traditional' { 0 }
		'full-width', 'proportional-width' { 1 }
		'ruby' { 2 }
		else { none }
	}
}

// https://drafts.csswg.org/css-fonts/#propdef-font-variant-ligatures  ->  normal | none | [ ... ]
fn (mut parser Parser) parse_font_variant_ligatures_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_all_as_single_keyword_value(mut tokens, .normal) {
		return value
	}
	if value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return value
	}
	return parser.parse_font_variant_tuple(mut tokens, 4, font_variant_ligatures_slot)
}

// https://drafts.csswg.org/css-fonts/#propdef-font-variant-numeric  ->  normal | [ ... ]
fn (mut parser Parser) parse_font_variant_numeric_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_all_as_single_keyword_value(mut tokens, .normal) {
		return value
	}
	return parser.parse_font_variant_tuple(mut tokens, 5, font_variant_numeric_slot)
}

// https://drafts.csswg.org/css-fonts/#propdef-font-variant-east-asian  ->  normal | [ ... ]
fn (mut parser Parser) parse_font_variant_east_asian_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_all_as_single_keyword_value(mut tokens, .normal) {
		return value
	}
	return parser.parse_font_variant_tuple(mut tokens, 3, font_variant_east_asian_slot)
}

// https://svgwg.org/svg2-draft/painting.html#SpecifyingFillPaint
// <paint> = none | <color> | <url> [none | <color>]? | context-fill | context-stroke
fn (mut parser Parser) parse_paint_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parser.parse_paint_color_or_none(mut tokens) {
		return value
	}

	// <url> [none | <color>]?  — a paint server reference with an optional fallback.
	mut transaction := tokens.clone()
	url := parse_url_function(mut transaction) or { return none }
	transaction.consume_whitespace()
	mut values := [StyleValue(URLStyleValue.create(url))]

	if transaction.has_more_tokens() {
		mut color_attempt := transaction.clone()
		if color := parser.parse_color_value(mut color_attempt) {
			tokens = color_attempt
			values << color
			return StyleValue(StyleValueList.create(values, .space, .no))
		}
		// A `none` fallback is valid but ignored.
		mut none_attempt := transaction.clone()
		if _ := parse_property_keyword_value(mut none_attempt, ['none']) {
			tokens = none_attempt
			return StyleValue(StyleValueList.create(values, .space, .no))
		}
		// Any other trailing token is an invalid fallback.
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .no))
}

// Parse the `<color> | none` alternatives shared by <paint>. Returns none when there is
// nothing color-like to consume (so the caller can try <url>).
fn (mut parser Parser) parse_paint_color_or_none(mut tokens ComponentValueStream) ?StyleValue {
	if color := parser.parse_color_value(mut tokens) {
		return color
	}
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}
	return none
}

// https://drafts.csswg.org/css-fonts/#propdef-font-size
// <absolute-size> | <relative-size> | <length-percentage [0,∞]> | math
fn (mut parser Parser) parse_font_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, font_size_keywords) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

const font_size_keywords = ['xx-small', 'x-small', 'small', 'medium', 'large', 'x-large', 'xx-large',
	'xxx-large', 'larger', 'smaller', 'math']

// https://drafts.csswg.org/css-ui/#cursor
// [ <cursor-image> , ]* <cursor-predefined>   where <cursor-image> = <image> <number>{2}?
// (a comma-separated list of custom cursors and then a mandatory predefined keyword).
fn (mut parser Parser) parse_cursor_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	parts := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	if parts.len == 0 {
		return none
	}

	mut cursors := []StyleValue{}
	for index, part in parts {
		mut part_tokens := ComponentValueStream.new(part)
		part_tokens.consume_whitespace()

		if index == parts.len - 1 {
			// The mandatory trailing predefined cursor keyword.
			keyword := parse_property_keyword_value(mut part_tokens, cursor_predefined_keywords) or {
				return none
			}
			part_tokens.consume_whitespace()
			if part_tokens.has_more_tokens() {
				return none
			}
			cursors << keyword
			continue
		}

		// <cursor-image> = <image> <number>{2}?  (the two numbers are the hotspot x/y).
		image := parser.parse_image_value(mut part_tokens) or { return none }
		cursor_image := CursorImageValue.create(image)
		part_tokens.consume_whitespace()
		if part_tokens.has_more_tokens() {
			x := parser.parse_number_value(mut part_tokens) or { return none }
			part_tokens.consume_whitespace()
			y := parser.parse_number_value(mut part_tokens) or { return none }
			part_tokens.consume_whitespace()
			if part_tokens.has_more_tokens() {
				return none
			}
			cursors << StyleValue(CursorStyleValue.create(cursor_image, x, y))
		} else {
			cursors << StyleValue(CursorStyleValue.create(cursor_image, none, none))
		}
	}

	tokens = transaction
	if cursors.len == 1 {
		return cursors[0]
	}
	return StyleValue(StyleValueList.create(cursors, .comma, .yes))
}

const cursor_predefined_keywords = ['auto', 'default', 'none', 'context-menu', 'help', 'pointer',
	'progress', 'wait', 'cell', 'crosshair', 'text', 'vertical-text', 'alias', 'copy', 'move',
	'no-drop', 'not-allowed', 'grab', 'grabbing', 'e-resize', 'n-resize', 'ne-resize', 'nw-resize',
	's-resize', 'se-resize', 'sw-resize', 'w-resize', 'ew-resize', 'ns-resize', 'nesw-resize',
	'nwse-resize', 'col-resize', 'row-resize', 'all-scroll', 'zoom-in', 'zoom-out']

// https://drafts.csswg.org/css-lists-3/#propdef-counter-increment  ->  [ <counter-name> <integer>? ]+ | none
fn (mut parser Parser) parse_counter_increment_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_counter_definitions_value(mut tokens, false, 1)
}

fn (mut parser Parser) parse_counter_reset_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_counter_definitions_value(mut tokens, true, 0)
}

fn (mut parser Parser) parse_counter_set_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_counter_definitions_value(mut tokens, false, 0)
}

fn (mut parser Parser) parse_counter_definitions_value(mut tokens ComponentValueStream, allow_reversed bool, default_value int) ?StyleValue {
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut counter_definitions := []CounterDefinition{}
	for transaction.has_more_tokens() {
		mut counter_name := ''
		mut is_reversed := false
		// <counter-name> | <reversed-counter-name>
		if name := parser.parse_custom_ident(mut transaction, ['none']) {
			counter_name = name
		} else if allow_reversed {
			component_value := transaction.peek() or { break }
			if !component_value.is_function_named('reversed') {
				break
			}
			transaction.consume()
			mut function_tokens := ComponentValueStream.new(component_value.function().value)
			function_tokens.consume_whitespace()
			counter_name = parser.parse_custom_ident(mut function_tokens, ['none']) or { break }
			function_tokens.consume_whitespace()
			if function_tokens.has_more_tokens() {
				break
			}
			is_reversed = true
		} else {
			break
		}
		transaction.consume_whitespace()

		// <integer>?
		mut value := ?StyleValue(none)
		mut int_attempt := transaction.clone()
		if integer_value := parser.parse_integer_value(mut int_attempt) {
			value = integer_value
			transaction = int_attempt
		} else if !is_reversed {
			value = StyleValue(IntegerStyleValue.create(i64(default_value)))
		}

		counter_definitions << CounterDefinition{
			name: counter_name
			is_reversed: is_reversed
			value: value
		}
		transaction.consume_whitespace()
	}

	if counter_definitions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(CounterDefinitionsStyleValue.create(counter_definitions))
}

fn color_filter_type_from_string(name string) ?ColorFilterType {
	return match name {
		'brightness' { ColorFilterType.brightness }
		'contrast' { ColorFilterType.contrast }
		'grayscale' { ColorFilterType.grayscale }
		'invert' { ColorFilterType.invert }
		'opacity' { ColorFilterType.opacity }
		'saturate' { ColorFilterType.saturate }
		'sepia' { ColorFilterType.sepia }
		else { none }
	}
}

// https://drafts.fxtf.org/filter-effects/#FilterProperty  ->  none | <filter-value-list>
fn (mut parser Parser) parse_filter_value_list_value(mut tokens ComponentValueStream) ?StyleValue {
	mut none_attempt := tokens.clone()
	if value := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return value
	}

	// <filter-value-list> = [ <filter-function> | <url> ]+
	mut transaction := tokens.clone()
	mut filter_value_list := []FilterStyleValue{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		if url := parse_url_function(mut transaction) {
			filter_value_list << FilterStyleValue(url)
			continue
		}
		token := transaction.consume() or { break }
		if !token.is_function() {
			return none
		}
		filter_value := parser.parse_filter_function(to_ascii_lowercase(token.function().name), token.function().value) or { return none }
		filter_value_list << filter_value
	}

	if filter_value_list.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(FilterValueListStyleValue.create(filter_value_list))
}

fn (mut parser Parser) parse_filter_function(name string, function_values []ComponentValue) ?FilterStyleValue {
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	mut tokens := ComponentValueStream.new(function_values)
	tokens.consume_whitespace()

	if name == 'blur' {
		// blur( <length>? )
		if !tokens.has_more_tokens() {
			return FilterStyleValue(FilterOperationBlur{
				radius: StyleValue(LengthStyleValue.create(Length.make_px(0)))
			})
		}
		blur_radius := parser.parse_length_value(mut tokens) or { return none }
		if blur_radius is LengthStyleValue && blur_radius.raw_value() < 0 {
			return none
		}
		tokens.consume_whitespace()
		if tokens.has_more_tokens() {
			return none
		}
		return FilterStyleValue(FilterOperationBlur{
			radius: blur_radius
		})
	}

	if name == 'drop-shadow' {
		// drop-shadow( [ <color>? && <length>{2,3} ] )
		if !tokens.has_more_tokens() {
			return none
		}
		mut maybe_color := ?StyleValue(none)
		if color := parser.parse_color_value(mut tokens) {
			maybe_color = color
		}
		tokens.consume_whitespace()
		x_offset := parser.parse_length_value(mut tokens) or { return none }
		tokens.consume_whitespace()
		if !tokens.has_more_tokens() {
			return none
		}
		y_offset := parser.parse_length_value(mut tokens) or { return none }
		tokens.consume_whitespace()

		mut maybe_radius := ?StyleValue(none)
		if tokens.has_more_tokens() {
			if radius := parser.parse_length_value(mut tokens) {
				maybe_radius = radius
			}
			tokens.consume_whitespace()
			if maybe_color == none && (maybe_radius == none || tokens.has_more_tokens()) {
				color := parser.parse_color_value(mut tokens) or { return none }
				maybe_color = color
			} else if maybe_radius == none {
				return none
			}
		}

		tokens.consume_whitespace()
		if tokens.has_more_tokens() {
			return none
		}
		return FilterStyleValue(FilterOperationDropShadow{
			offset_x: x_offset
			offset_y: y_offset
			radius: maybe_radius
			color: maybe_color
		})
	}

	if name == 'hue-rotate' {
		// hue-rotate( [ <angle> | <zero> ]? )
		if !tokens.has_more_tokens() {
			return FilterStyleValue(FilterOperationHueRotate{
				angle: StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
			})
		}
		if next := tokens.peek() {
			if next.is(.number) {
				number_token := tokens.consume() or { return none }
				number := number_token.token().number()
				if number.is_integer() && number.integer_value() == 0 {
					tokens.consume_whitespace()
					if tokens.has_more_tokens() {
						return none
					}
					return FilterStyleValue(FilterOperationHueRotate{
						angle: StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
					})
				}
				return none
			}
		}
		angle := parser.parse_angle_value(mut tokens) or { return none }
		tokens.consume_whitespace()
		if tokens.has_more_tokens() {
			return none
		}
		return FilterStyleValue(FilterOperationHueRotate{
			angle: angle
		})
	}

	// Simple color filters: brightness/contrast/grayscale/invert/opacity/saturate/sepia( <number-percentage>? )
	color_type := color_filter_type_from_string(name) or { return none }
	if !tokens.has_more_tokens() {
		return FilterStyleValue(FilterOperationColor{
			operation: color_type
			amount: StyleValue(NumberStyleValue.create(1))
		})
	}

	amount_value := parser.parse_number_percentage_value(mut tokens) or { return none }
	if amount_value is PercentageStyleValue {
		if amount_value.percentage().value() < 0 {
			return none
		}
	}
	if amount_value is NumberStyleValue {
		if amount_value.number() < 0 {
			return none
		}
	}

	mut final_amount := amount_value
	if color_type in [ColorFilterType.grayscale, .invert, .opacity, .sepia] {
		if amount_value is PercentageStyleValue {
			if amount_value.percentage().value() > 100 {
				final_amount = StyleValue(PercentageStyleValue.create(Percentage.new(100)))
			}
		}
		if amount_value is NumberStyleValue {
			if amount_value.number() > 1 {
				final_amount = StyleValue(NumberStyleValue.create(1))
			}
		}
	}

	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return FilterStyleValue(FilterOperationColor{
		operation: color_type
		amount: final_amount
	})
}

// https://www.w3.org/TR/css-grid-2/#grid-template-areas-property  ->  none | <string>+
fn (mut parser Parser) parse_grid_template_areas_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut none_attempt := tokens.clone()
	if _ := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return StyleValue(GridTemplateAreaStyleValue.create(map[string]GridArea{}, 0, 0))
	}

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut grid_area_rows := [][]string{}
	mut has_column_count := false
	mut column_count := 0
	for {
		token := transaction.peek() or { break }
		if !token.is(.string) {
			break
		}
		transaction.consume()
		columns := grid_template_area_columns_from_string(token.token().string_value()) or {
			return none
		}
		if columns.len == 0 {
			return none
		}
		if has_column_count {
			if columns.len != column_count {
				return none
			}
		} else {
			has_column_count = true
			column_count = columns.len
		}
		grid_area_rows << columns
		transaction.consume_whitespace()
	}

	if grid_area_rows.len == 0 {
		return none
	}

	// Pre-compute occurrence counts for each named area.
	mut name_counts := map[string]int{}
	for row in grid_area_rows {
		for cell in row {
			if cell != '.' {
				name_counts[cell] = name_counts[cell] + 1
			}
		}
	}

	mut grid_areas := map[string]GridArea{}
	for y in 0 .. grid_area_rows.len {
		for x in 0 .. grid_area_rows[y].len {
			name := grid_area_rows[y][x]
			if name == '.' || name in grid_areas {
				continue
			}

			mut x_end := x
			for x_end < grid_area_rows[y].len && grid_area_rows[y][x_end] == name {
				x_end++
			}
			mut y_end := y
			for y_end < grid_area_rows.len && grid_area_rows[y_end][x] == name {
				y_end++
			}

			// Verify the bounding rectangle is fully filled with this name.
			for check_y in y .. y_end {
				for check_x in x .. x_end {
					if grid_area_rows[check_y][check_x] != name {
						return none
					}
				}
			}

			// Verify there are no occurrences of this name outside the rectangle.
			expected_count := (x_end - x) * (y_end - y)
			if name_counts[name] != expected_count {
				return none
			}

			grid_areas[name] = GridArea{
				row_start: uint(y)
				row_end: uint(y_end)
				column_start: uint(x)
				column_end: uint(x_end)
			}
		}
	}

	tokens = transaction
	return StyleValue(GridTemplateAreaStyleValue.create(grid_areas, uint(grid_area_rows.len), uint(column_count)))
}

// Splits one grid-template-areas string into its column cell names (or '.' for a null cell).
fn grid_template_area_columns_from_string(input string) ?[]string {
	mut columns := []string{}
	runes := input.runes()
	mut i := 0
	for i < runes.len {
		if is_whitespace(u32(runes[i])) {
			for i < runes.len && is_whitespace(u32(runes[i])) {
				i++
			}
		} else if runes[i] == `.` {
			for i < runes.len && runes[i] == `.` {
				i++
			}
			columns << '.'
		} else if is_ident_code_point(u32(runes[i])) {
			start := i
			for i < runes.len && is_ident_code_point(u32(runes[i])) {
				i++
			}
			columns << runes[start..i].string()
		} else {
			return none
		}
	}
	return columns
}

// https://www.w3.org/TR/css-grid-2/#auto-tracks  ->  <track-size>+
fn (mut parser Parser) parse_grid_auto_track_sizes(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut track_list := GridTrackSizeList{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		track_size := parser.parse_grid_track_size(mut transaction) or { break }
		track_list.append_explicit_track(track_size)
	}
	if track_list.is_empty() {
		return none
	}

	tokens = transaction
	return StyleValue(GridTrackSizeListStyleValue.create(track_list))
}

// <track-size> = <track-breadth> | minmax( <inflexible-breadth> , <track-breadth> )
//              | fit-content( <length-percentage [0,∞]> )
fn (mut parser Parser) parse_grid_track_size(mut tokens ComponentValueStream) ?ExplicitGridTrack {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	if peek := transaction.peek() {
		if peek.is_function_named('minmax') {
			// minmax( <inflexible-breadth> , <track-breadth> )
			minmax := parser.parse_grid_minmax_kinds(mut transaction, .inflexible, .track) or {
				return none
			}
			tokens = transaction
			return minmax
		}
		if peek.is_function_named('fit-content') {
			parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
				name: peek.function().name
			}))
			defer {
				parser.pop_temporary_value_parsing_context()
			}
			mut fit_tokens := ComponentValueStream.new(peek.function().value)
			fit_tokens.consume_whitespace()
			length_percentage := parser.parse_grid_fixed_breadth(mut fit_tokens) or { return none }
			fit_tokens.consume_whitespace()
			if fit_tokens.has_more_tokens() {
				return none
			}
			transaction.consume()
			tokens = transaction
			return ExplicitGridTrack.from_grid_size(GridSize.from_size(Size.make_fit_content(length_percentage)))
		}
	}

	track_breadth := parser.parse_grid_track_breadth(mut transaction) or { return none }
	tokens = transaction
	return ExplicitGridTrack.from_grid_size(track_breadth)
}

// <track-breadth> = <length-percentage [0,∞]> | <flex [0,∞]> | min-content | max-content | auto
fn (mut parser Parser) parse_grid_track_breadth(mut tokens ComponentValueStream) ?GridSize {
	if inflexible := parser.parse_grid_inflexible_breadth(mut tokens) {
		return inflexible
	}

	mut flex_attempt := tokens.clone()
	if flex_value := parser.parse_flex_value(mut flex_attempt) {
		if flex_value is FlexStyleValue {
			flex := flex_value.flex()
			if flex.raw_value() >= 0 {
				tokens = flex_attempt
				return GridSize.from_flex(flex)
			}
		}
		if flex_value is CalculatedStyleValue {
			if flex := flex_value.resolve_flex(CalculationResolutionContext{}) {
				if flex.raw_value() >= 0 {
					tokens = flex_attempt
					return GridSize.from_calculated(flex_value)
				}
			}
		}
	}

	return none
}

// <inflexible-breadth> = <length-percentage [0,∞]> | min-content | max-content | auto
fn (mut parser Parser) parse_grid_inflexible_breadth(mut tokens ComponentValueStream) ?GridSize {
	if fixed := parser.parse_grid_fixed_breadth(mut tokens) {
		return GridSize.from_size(Size.make_length_percentage(fixed))
	}

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	result := match to_ascii_lowercase(token.token().ident()) {
		'max-content' { GridSize.from_size(Size.make_max_content()) }
		'min-content' { GridSize.from_size(Size.make_min_content()) }
		'auto' { GridSize.make_auto() }
		else {
			return none
		}
	}
	tokens = transaction
	return result
}

// <fixed-breadth> = <length-percentage [0,∞]>
fn (mut parser Parser) parse_grid_fixed_breadth(mut tokens ComponentValueStream) ?LengthPercentage {
	mut transaction := tokens.clone()
	value := parser.parse_length_percentage_value(mut transaction) or { return none }
	if value is LengthStyleValue && value.raw_value() < 0 {
		return none
	}
	if value is PercentageStyleValue && value.raw_value() < 0 {
		return none
	}
	tokens = transaction
	return LengthPercentage.from_style_value_logic(value)
}

enum GridBreadthKind {
	track
	inflexible
	fixed
}

fn (mut parser Parser) parse_grid_breadth(mut tokens ComponentValueStream, kind GridBreadthKind) ?GridSize {
	match kind {
		.track {
			return parser.parse_grid_track_breadth(mut tokens)
		}
		.inflexible {
			return parser.parse_grid_inflexible_breadth(mut tokens)
		}
		.fixed {
			fixed := parser.parse_grid_fixed_breadth(mut tokens) or { return none }
			return GridSize.from_size(Size.make_length_percentage(fixed))
		}
	}
}

fn (mut parser Parser) parse_grid_minmax_kinds(mut tokens ComponentValueStream, min_kind GridBreadthKind, max_kind GridBreadthKind) ?ExplicitGridTrack {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('minmax') {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: component_value.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	parts := parse_a_comma_separated_list_of_component_values_for_value_logic(component_value.function().value)
	if parts.len != 2 {
		return none
	}

	mut min_tokens := ComponentValueStream.new(parts[0])
	min_tokens.consume_whitespace()
	min_value := parser.parse_grid_breadth(mut min_tokens, min_kind) or { return none }
	min_tokens.consume_whitespace()
	if min_tokens.has_more_tokens() {
		return none
	}

	mut max_tokens := ComponentValueStream.new(parts[1])
	max_tokens.consume_whitespace()
	max_value := parser.parse_grid_breadth(mut max_tokens, max_kind) or { return none }
	max_tokens.consume_whitespace()
	if max_tokens.has_more_tokens() {
		return none
	}

	tokens = transaction
	return ExplicitGridTrack.from_minmax(GridMinMax.new(min_value, max_value))
}

// <fixed-size> = <fixed-breadth> | minmax( <fixed-breadth> , <track-breadth> )
//              | minmax( <inflexible-breadth> , <fixed-breadth> )
fn (mut parser Parser) parse_grid_fixed_size(mut tokens ComponentValueStream) ?ExplicitGridTrack {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	if peek := transaction.peek() {
		if peek.is_function_named('minmax') {
			if result := parser.parse_grid_minmax_kinds(mut transaction, .fixed, .track) {
				tokens = transaction
				return result
			}
			if result := parser.parse_grid_minmax_kinds(mut transaction, .inflexible, .fixed) {
				tokens = transaction
				return result
			}
			return none
		}
	}

	fixed := parser.parse_grid_fixed_breadth(mut transaction) or { return none }
	tokens = transaction
	return ExplicitGridTrack.from_grid_size(GridSize.from_size(Size.make_length_percentage(fixed)))
}

// <line-names> = '[' <custom-ident>* ']'
// Returns an (possibly empty) GridLineNames when there is no square block (without consuming),
// the parsed names when there is a valid block, or `none` when the block has invalid content.
fn (mut parser Parser) parse_grid_line_names(mut tokens ComponentValueStream) ?GridLineNames {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return GridLineNames{} }
	if !token.is_block() || !token.block().is_square() {
		return GridLineNames{}
	}

	mut line_names := GridLineNames{}
	mut block_tokens := ComponentValueStream.new(token.block().value)
	block_tokens.consume_whitespace()
	for block_tokens.has_more_tokens() {
		ident := parser.parse_custom_ident(mut block_tokens, ['span', 'auto']) or { return none }
		line_names.append(ident)
		block_tokens.consume_whitespace()
	}

	tokens = transaction
	return line_names
}

enum GridTrackKind {
	track_size_or_repeat
	fixed_size_or_repeat
	track_size_only
	fixed_size_only
}

fn (mut parser Parser) parse_grid_track_for_kind(mut tokens ComponentValueStream, kind GridTrackKind) ?ExplicitGridTrack {
	match kind {
		.track_size_or_repeat {
			if repeat := parser.parse_grid_track_repeat(mut tokens) {
				return ExplicitGridTrack.from_repeat(repeat)
			}
			return parser.parse_grid_track_size(mut tokens)
		}
		.fixed_size_or_repeat {
			if repeat := parser.parse_grid_fixed_repeat(mut tokens) {
				return ExplicitGridTrack.from_repeat(repeat)
			}
			return parser.parse_grid_fixed_size(mut tokens)
		}
		.track_size_only {
			return parser.parse_grid_track_size(mut tokens)
		}
		.fixed_size_only {
			return parser.parse_grid_fixed_size(mut tokens)
		}
	}
}

// [ <line-names>? <track> ]+ <line-names>?  (AllowTrailingLineNamesForEachTrack::No)
fn (mut parser Parser) parse_track_list_impl(mut tokens ComponentValueStream, mut output GridTrackSizeList, kind GridTrackKind) int {
	mut parsed_tracks_count := 0
	tokens.consume_whitespace()
	for tokens.has_more_tokens() {
		mut transaction := tokens.clone()
		line_names := parser.parse_grid_line_names(mut transaction) or { break }
		transaction.consume_whitespace()
		track := parser.parse_grid_track_for_kind(mut transaction, kind) or { break }
		transaction.consume_whitespace()

		if !line_names.is_empty() {
			output.append_line_names(line_names)
		}
		output.append_explicit_track(track)

		tokens = transaction
		parsed_tracks_count++
		tokens.consume_whitespace()
	}

	// Trailing <line-names>?
	mut trailing_transaction := tokens.clone()
	if trailing := parser.parse_grid_line_names(mut trailing_transaction) {
		if !trailing.is_empty() {
			output.append_line_names(trailing)
			tokens = trailing_transaction
		}
	}

	return parsed_tracks_count
}

enum GridRepeatCountKind {
	fixed_integer
	auto
}

fn (mut parser Parser) parse_grid_repeat_params(mut tokens ComponentValueStream, count_kind GridRepeatCountKind) ?GridRepeatParams {
	match count_kind {
		.fixed_integer {
			mut int_attempt := tokens.clone()
			parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.grid_track_repeat_count))
			integer_value := parser.parse_integer_value(mut int_attempt) or {
				parser.pop_temporary_value_parsing_context()
				return none
			}
			parser.pop_temporary_value_parsing_context()
			if integer_value is IntegerStyleValue {
				if integer_value.integer() < 1 {
					return none
				}
			}
			tokens = int_attempt
			return GridRepeatParams{
				type_: .fixed
				count: integer_value
			}
		}
		.auto {
			mut transaction := tokens.clone()
			transaction.consume_whitespace()
			token := transaction.consume() or { return none }
			if !token.is(.ident) {
				return none
			}
			result := match to_ascii_lowercase(token.token().ident()) {
				'auto-fill' {
					GridRepeatParams{
						type_: .auto_fill
					}
				}
				'auto-fit' {
					GridRepeatParams{
						type_: .auto_fit
					}
				}
				else {
					return none
				}
			}
			tokens = transaction
			return result
		}
	}
}

fn (mut parser Parser) parse_grid_track_repeat_impl(mut tokens ComponentValueStream, count_kind GridRepeatCountKind, inner_kind GridTrackKind) ?GridRepeat {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('repeat') {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: component_value.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	parts := parse_a_comma_separated_list_of_component_values_for_value_logic(component_value.function().value)
	if parts.len != 2 {
		return none
	}

	mut first_arg_tokens := ComponentValueStream.new(parts[0])
	first_arg_tokens.consume_whitespace()
	if !first_arg_tokens.has_more_tokens() {
		return none
	}
	repeat_params := parser.parse_grid_repeat_params(mut first_arg_tokens, count_kind) or {
		return none
	}
	first_arg_tokens.consume_whitespace()
	if first_arg_tokens.has_more_tokens() {
		return none
	}

	mut second_arg_tokens := ComponentValueStream.new(parts[1])
	second_arg_tokens.consume_whitespace()
	mut track_list := GridTrackSizeList{}
	parsed_track_count := parser.parse_track_list_impl(mut second_arg_tokens, mut track_list, inner_kind)
	if parsed_track_count == 0 || second_arg_tokens.has_more_tokens() {
		return none
	}

	tokens = transaction
	return GridRepeat.from_params(track_list, repeat_params)
}

// <track-repeat> = repeat( [ <integer [1,∞]> ] , [ <line-names>? <track-size> ]+ <line-names>? )
fn (mut parser Parser) parse_grid_track_repeat(mut tokens ComponentValueStream) ?GridRepeat {
	return parser.parse_grid_track_repeat_impl(mut tokens, .fixed_integer, .track_size_only)
}

// <fixed-repeat> = repeat( [ <integer [1,∞]> ] , [ <line-names>? <fixed-size> ]+ <line-names>? )
fn (mut parser Parser) parse_grid_fixed_repeat(mut tokens ComponentValueStream) ?GridRepeat {
	return parser.parse_grid_track_repeat_impl(mut tokens, .fixed_integer, .fixed_size_only)
}

// <auto-repeat> = repeat( [ auto-fill | auto-fit ] , [ <line-names>? <fixed-size> ]+ <line-names>? )
fn (mut parser Parser) parse_grid_auto_repeat(mut tokens ComponentValueStream) ?GridRepeat {
	return parser.parse_grid_track_repeat_impl(mut tokens, .auto, .fixed_size_only)
}

// <name-repeat> = repeat( [ <integer [1,infinity]> | auto-fill ] , <line-names>+ )
fn (mut parser Parser) parse_grid_name_repeat(mut tokens ComponentValueStream) ?GridRepeat {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('repeat') {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: component_value.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	parts := parse_a_comma_separated_list_of_component_values_for_value_logic(component_value.function().value)
	if parts.len != 2 {
		return none
	}
	mut first_arg_tokens := ComponentValueStream.new(parts[0])
	first_arg_tokens.consume_whitespace()
	mut repeat_params := parser.parse_grid_repeat_params(mut first_arg_tokens, .fixed_integer) or {
		mut auto_tokens := ComponentValueStream.new(parts[0])
		auto_tokens.consume_whitespace()
		params := parser.parse_grid_repeat_params(mut auto_tokens, .auto) or { return none }
		if params.type_ != .auto_fill {
			return none
		}
		auto_tokens.consume_whitespace()
		if auto_tokens.has_more_tokens() {
			return none
		}
		params
	}
	first_arg_tokens.consume_whitespace()
	if repeat_params.type_ == .fixed && first_arg_tokens.has_more_tokens() {
		return none
	}

	mut second_arg_tokens := ComponentValueStream.new(parts[1])
	mut line_name_list := GridTrackSizeList.make_line_name_list()
	mut parsed_line_name_count := 0
	second_arg_tokens.consume_whitespace()
	for second_arg_tokens.has_more_tokens() {
		peek := second_arg_tokens.peek() or { return none }
		if !peek.is_block() || !peek.block().is_square() {
			return none
		}
		line_names := parser.parse_grid_line_names(mut second_arg_tokens) or { return none }
		line_name_list.append_line_names(line_names)
		parsed_line_name_count++
		second_arg_tokens.consume_whitespace()
	}
	if parsed_line_name_count == 0 {
		return none
	}
	tokens = transaction
	return GridRepeat.from_params(line_name_list, repeat_params)
}

// <track-list> = [ <line-names>? [ <track-size> | <track-repeat> ] ]+ <line-names>?
fn (mut parser Parser) parse_grid_track_list(mut tokens ComponentValueStream) ?GridTrackSizeList {
	mut transaction := tokens.clone()
	mut track_list := GridTrackSizeList{}
	parsed_track_count := parser.parse_track_list_impl(mut transaction, mut track_list, .track_size_or_repeat)
	if parsed_track_count == 0 {
		return none
	}
	tokens = transaction
	return track_list
}

// <explicit-track-list> = [ <line-names>? <track-size> ]+ <line-names>?
// ValueParsing.cpp: Parser::parse_explicit_track_list.
fn (mut parser Parser) parse_explicit_track_list(mut tokens ComponentValueStream) ?GridTrackSizeList {
	mut transaction := tokens.clone()
	mut track_list := GridTrackSizeList{}
	parsed_track_count := parser.parse_track_list_impl(mut transaction, mut track_list, .track_size_only)
	if parsed_track_count == 0 {
		return none
	}
	tokens = transaction
	return track_list
}

// <auto-track-list> = [ <line-names>? [ <fixed-size> | <fixed-repeat> ] ]* <line-names>? <auto-repeat>
//                     [ <line-names>? [ <fixed-size> | <fixed-repeat> ] ]* <line-names>?
fn (mut parser Parser) parse_grid_auto_track_list(mut tokens ComponentValueStream) ?GridTrackSizeList {
	mut transaction := tokens.clone()
	mut track_list := GridTrackSizeList{}

	parser.parse_track_list_impl(mut transaction, mut track_list, .fixed_size_or_repeat)

	transaction.consume_whitespace()
	auto_repeat := parser.parse_grid_auto_repeat(mut transaction) or { return none }
	track_list.append_explicit_track(ExplicitGridTrack.from_repeat(auto_repeat))

	parser.parse_track_list_impl(mut transaction, mut track_list, .fixed_size_or_repeat)

	tokens = transaction
	return track_list
}

// none | <track-list> | <auto-track-list> | subgrid <line-name-list>?
fn (mut parser Parser) parse_grid_track_size_list(mut tokens ComponentValueStream) ?StyleValue {
	mut none_attempt := tokens.clone()
	if _ := parse_property_keyword_value(mut none_attempt, ['none']) {
		tokens = none_attempt
		return StyleValue(GridTrackSizeListStyleValue.make_none())
	}

	mut subgrid_attempt := tokens.clone()
	subgrid_attempt.consume_whitespace()
	if first := subgrid_attempt.peek() {
		if first.is(.ident) && to_ascii_lowercase(first.token().ident()) == 'subgrid' {
			subgrid_attempt.consume()
			mut track_list := GridTrackSizeList.make_subgrid()
			mut has_auto_fill_repeat := false
			subgrid_attempt.consume_whitespace()
			for subgrid_attempt.has_more_tokens() {
				component := subgrid_attempt.peek() or { return none }
				if component.is_block() && component.block().is_square() {
					line_names := parser.parse_grid_line_names(mut subgrid_attempt) or { return none }
					track_list.append_line_names(line_names)
				} else if repeat := parser.parse_grid_name_repeat(mut subgrid_attempt) {
					if repeat.is_auto_fill() {
						if has_auto_fill_repeat {
							return none
						}
						has_auto_fill_repeat = true
					}
					track_list.append_explicit_track(ExplicitGridTrack.from_repeat(repeat))
				} else {
					return none
				}
				subgrid_attempt.consume_whitespace()
			}
			tokens = subgrid_attempt
			return StyleValue(GridTrackSizeListStyleValue.create(track_list))
		}
	}

	mut auto_attempt := tokens.clone()
	if auto_track_list := parser.parse_grid_auto_track_list(mut auto_attempt) {
		tokens = auto_attempt
		return StyleValue(GridTrackSizeListStyleValue.create(auto_track_list))
	}

	mut track_attempt := tokens.clone()
	if track_list := parser.parse_grid_track_list(mut track_attempt) {
		tokens = track_attempt
		return StyleValue(GridTrackSizeListStyleValue.create(track_list))
	}

	return none
}

// https://www.w3.org/TR/css-grid-2/#grid-auto-flow-property  ->  [ row | column ] || dense
fn (mut parser Parser) parse_grid_auto_flow_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	mut has_axis := false
	mut axis := GridAutoFlowAxis.row
	mut has_dense := false

	if parsed_axis := parse_grid_auto_flow_axis(mut transaction) {
		has_axis = true
		axis = parsed_axis
		if parse_grid_auto_flow_dense(mut transaction) {
			has_dense = true
		}
	} else if parse_grid_auto_flow_dense(mut transaction) {
		has_dense = true
		if parsed_axis := parse_grid_auto_flow_axis(mut transaction) {
			has_axis = true
			axis = parsed_axis
		}
	}

	if !has_axis && !has_dense {
		return none
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	dense := if has_dense { GridAutoFlowDense.yes } else { GridAutoFlowDense.no }
	tokens = transaction
	return StyleValue(GridAutoFlowStyleValue.create(axis, dense))
}

fn parse_grid_auto_flow_axis(mut tokens ComponentValueStream) ?GridAutoFlowAxis {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	axis := match to_ascii_lowercase(token.token().ident()) {
		'row' { GridAutoFlowAxis.row }
		'column' { GridAutoFlowAxis.column }
		else {
			return none
		}
	}
	tokens = transaction
	return axis
}

fn parse_grid_auto_flow_dense(mut tokens ComponentValueStream) bool {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	token := transaction.consume() or { return false }
	if !token.is(.ident) || !equals_ignoring_ascii_case(token.token().ident(), 'dense') {
		return false
	}
	tokens = transaction
	return true
}

// https://www.w3.org/TR/css-grid-2/#line-placement
// <grid-line> = auto | <custom-ident> | [ [ <integer> ] && <custom-ident>? ] | [ span && [ <integer> || <custom-ident> ] ]
fn (mut parser Parser) parse_grid_track_placement(mut tokens ComponentValueStream) ?StyleValue {
	mut auto_attempt := tokens.clone()
	if _ := parse_property_keyword_value(mut auto_attempt, ['auto']) {
		tokens = auto_attempt
		return StyleValue(GridTrackPlacementStyleValue.create(GridTrackPlacement.make_auto()))
	}

	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	mut is_span := false
	mut parsed_custom_ident := ?string(none)
	mut parsed_integer := ?StyleValue(none)

	for transaction.has_more_tokens() {
		peek := transaction.peek() or { break }

		// span
		if peek.is(.ident) && equals_ignoring_ascii_case(peek.token().ident(), 'span') {
			if is_span {
				return none
			}
			transaction.consume()
			transaction.consume_whitespace()
			// "span" must not appear in between <custom-ident> and <integer>.
			if transaction.has_more_tokens() && (parsed_custom_ident != none || parsed_integer != none) {
				return none
			}
			is_span = true
			continue
		}

		// <custom-ident> (excluding `auto`)
		mut ident_attempt := transaction.clone()
		if custom_ident := parser.parse_custom_ident(mut ident_attempt, ['auto']) {
			if parsed_custom_ident != none {
				return none
			}
			parsed_custom_ident = custom_ident
			ident_attempt.consume_whitespace()
			transaction = ident_attempt
			continue
		}

		// <integer>
		mut int_attempt := transaction.clone()
		if integer_value := parser.parse_integer_value(mut int_attempt) {
			if parsed_integer != none {
				return none
			}
			parsed_integer = integer_value
			int_attempt.consume_whitespace()
			transaction = int_attempt
			continue
		}

		return none
	}

	// <custom-ident> | [ [ <integer ≠ 0> ] && <custom-ident>? ]
	if !is_span && (parsed_integer != none || parsed_custom_ident != none) {
		mut valid := true
		if integer := parsed_integer {
			if integer.is_integer() && integer.as_integer().integer() == 0 {
				valid = false
			}
		}
		if valid {
			tokens = transaction
			return StyleValue(GridTrackPlacementStyleValue.create(GridTrackPlacement.make_line(parsed_integer, parsed_custom_ident)))
		}
	}

	// [ span && [ <integer [1,∞]> || <custom-ident> ] ]
	if is_span && (parsed_integer != none || parsed_custom_ident != none) {
		mut valid := true
		if integer := parsed_integer {
			if integer.is_integer() && integer.as_integer().integer() <= 0 {
				valid = false
			}
		}
		if valid {
			// If the <integer> is omitted, it defaults to 1.
			span_value := parsed_integer or { StyleValue(IntegerStyleValue.create(1)) }
			tokens = transaction
			return StyleValue(GridTrackPlacementStyleValue.create(GridTrackPlacement.make_span(span_value, parsed_custom_ident)))
		}
	}

	return none
}

// https://drafts.csswg.org/css-fonts/#propdef-font-family
// [ <family-name> | <generic-family> ]#
fn (mut parser Parser) parse_font_family_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut families := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		family := parser.parse_font_family_item(mut item_tokens) or { return none }
		families << family
	}
	if families.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(families, .comma, .yes))
}

fn (mut parser Parser) parse_font_family_item(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()

	// <generic-family> is a keyword that occupies the whole comma-segment on its own.
	if peek := tokens.peek() {
		if peek.is(.ident) {
			ident := to_ascii_lowercase(peek.token().ident())
			if is_generic_font_family_name(ident) {
				tokens.consume()
				tokens.consume_whitespace()
				if tokens.has_more_tokens() {
					return none
				}
				if keyword := keyword_from_string(ident) {
					return StyleValue(KeywordStyleValue.create(keyword))
				}
				// Some generic family names, such as system-ui and fangsong, are not
				// represented in the generated CSS keyword enum.
				return StyleValue(CustomIdentStyleValue.create(ident))
			}
		}
	}

	// <family-name>
	return parser.parse_family_name_value(mut tokens)
}

// <family-name> = <string> | <custom-ident>+
fn (mut parser Parser) parse_family_name_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	tokens.consume_whitespace()
	mut parts := []string{}
	for {
		peek := tokens.peek() or { break }
		if peek.is(.string) {
			// `font-family: my cool "font";` is invalid.
			if parts.len != 0 {
				return none
			}
			tokens.consume()
			tokens.consume_whitespace()
			if tokens.has_more_tokens() {
				return none
			}
			return StyleValue(StringStyleValue.create(peek.token().string_value()))
		}
		if peek.is(.ident) {
			component_value := tokens.consume() or { break }
			parts << component_value.token().ident()
			tokens.consume_whitespace()
			continue
		}
		break
	}

	if parts.len == 0 || tokens.has_more_tokens() {
		return none
	}

	if parts.len == 1 {
		// <generic-family> and the CSS-wide keywords (and `default`) are not <family-name>s.
		first := to_ascii_lowercase(parts[0])
		if is_css_wide_keyword_string(first) || first == 'default' || is_generic_font_family_name(first) {
			return none
		}
	}

	complete_name := parts.join(' ')
	return StyleValue(CustomIdentStyleValue{
		custom_ident_: complete_name
		family_identifiers_: if parts.len > 1 { parts } else { []string{} }
	})
}

// https://svgwg.org/svg2-draft/painting.html#StrokeDashing
// none | <dasharray>  where  <dasharray> = [ [ <length-percentage> | <number> ]+ ]#
fn (mut parser Parser) parse_stroke_dasharray_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	mut dashes := []StyleValue{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		// <number> (non-negative). parse_number_value is not transaction-safe, so try a clone.
		mut number_attempt := transaction.clone()
		if number := parser.parse_number_value(mut number_attempt) {
			if number is NumberStyleValue && number.number() < 0 {
				return none
			}
			dashes << number
			transaction = number_attempt
		} else {
			value := parser.parse_length_percentage_value(mut transaction) or { return none }
			if value is PercentageStyleValue && value.raw_value() < 0 {
				return none
			}
			if value is LengthStyleValue && value.raw_value() < 0 {
				return none
			}
			dashes << value
		}

		transaction.consume_whitespace()
		if next := transaction.peek() {
			if next.is(.comma) {
				transaction.consume()
			}
		}
	}

	if dashes.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(dashes, .comma, .yes))
}

// https://drafts.csswg.org/css2/#clipping  ->  auto | rect(<top>, <right>, <bottom>, <left>)
fn (mut parser Parser) parse_clip_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_rect_value(mut tokens)
}

// https://www.w3.org/TR/CSS2/visufx.html#value-def-shape
fn (mut parser Parser) parse_rect_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('rect') {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: 'rect'
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut params := []StyleValue{}
	// Unknown -> 0, RequiresCommas -> 1, RequiresNoCommas -> 2
	mut comma_requirement := 0
	for side in 0 .. 4 {
		argument_tokens.consume_whitespace()
		next := argument_tokens.peek() or { return none }
		// Each side is either 'auto' or a <length>. Negative lengths are permitted.
		if next.is(.ident) && equals_ignoring_ascii_case(next.token().ident(), 'auto') {
			argument_tokens.consume()
			params << StyleValue(KeywordStyleValue.create(.auto))
		} else {
			length := parser.parse_length_value(mut argument_tokens) or { return none }
			params << length
		}
		argument_tokens.consume_whitespace()

		if side == 3 {
			if argument_tokens.has_more_tokens() {
				return none
			}
			break
		}

		next_token := argument_tokens.peek() or { return none }
		next_is_comma := next_token.is(.comma)
		if comma_requirement == 0 {
			comma_requirement = if next_is_comma { 1 } else { 2 }
		}
		if comma_requirement == 1 {
			if next_is_comma {
				argument_tokens.consume()
			} else {
				return none
			}
		} else {
			if next_is_comma {
				return none
			}
		}
	}

	tokens = transaction
	return StyleValue(RectStyleValue.create(params[0], params[1], params[2], params[3]))
}

// https://drafts.csswg.org/css-lists-3/#propdef-list-style-type
fn (mut parser Parser) parse_list_style_type_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	// <string>
	transaction = tokens.clone()
	if string_value := parser.parse_string_value(mut transaction) {
		tokens = transaction
		return StyleValue(string_value)
	}

	// <counter-style> = <counter-style-name> | symbols()
	transaction = tokens.clone()
	if counter_style := parser.parse_counter_style_value(mut transaction) {
		tokens = transaction
		return StyleValue(counter_style)
	}

	return none
}

// https://drafts.csswg.org/css-content/#propdef-quotes
fn (mut parser Parser) parse_quotes_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'none']) {
		tokens = transaction
		return value
	}

	// [ <string> <string> ]+
	transaction = tokens.clone()
	mut strings := []StyleValue{}
	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
		string_value := parser.parse_string_value(mut transaction) or { return none }
		strings << StyleValue(string_value)
	}
	if strings.len == 0 || strings.len % 2 != 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(strings, .space, .no))
}

// https://drafts.csswg.org/css-flexbox-1/#propdef-flex-basis
fn (mut parser Parser) parse_flex_basis_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'content']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parse_keyword_from_set_for_value_logic(mut transaction, [
		'max-content',
		'min-content',
	]) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_fit_content_value(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

// https://drafts.csswg.org/css-display/#the-display-properties
fn (mut parser Parser) parse_display_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut idents := []string{}
	for {
		transaction.consume_whitespace()
		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		idents << to_ascii_lowercase(component_value.token().ident())
	}
	if idents.len == 0 {
		return none
	}

	display := if idents.len == 1 {
		display_from_single_keyword_string(idents[0]) or { return none }
	} else {
		display_from_multi_keyword_strings(idents) or { return none }
	}

	tokens = transaction
	return StyleValue(DisplayStyleValue.create(display))
}

fn (mut parser Parser) parse_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['absolute', 'fixed', 'relative', 'static',
		'sticky'])
}

fn (mut parser Parser) parse_caption_side_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['top', 'bottom'])
}

fn (mut parser Parser) parse_border_collapse_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'separate'])
}

fn (mut parser Parser) parse_box_sizing_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['border-box', 'content-box'])
}

fn (mut parser Parser) parse_fill_rule_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['nonzero', 'evenodd'])
}

fn (mut parser Parser) parse_color_interpolation_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'linearrgb', 'srgb'])
}

fn (mut parser Parser) parse_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['ltr', 'rtl'])
}

fn (mut parser Parser) parse_empty_cells_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['show', 'hide'])
}

fn (mut parser Parser) parse_isolation_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'isolate'])
}

fn (mut parser Parser) parse_list_style_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['inside', 'outside'])
}

fn (mut parser Parser) parse_mask_type_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['luminance', 'alpha'])
}

fn (mut parser Parser) parse_shape_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'optimizespeed', 'crispedges',
		'geometricprecision'])
}

fn (mut parser Parser) parse_stroke_linecap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['butt', 'round', 'square'])
}

fn (mut parser Parser) parse_stroke_linejoin_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['miter', 'round', 'bevel'])
}

fn (mut parser Parser) parse_table_layout_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'fixed'])
}

fn (mut parser Parser) parse_text_anchor_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['start', 'middle', 'end'])
}

fn (mut parser Parser) parse_text_align_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['center', 'justify', 'start', 'end', 'left',
		'right', 'match-parent', '-libweb-center', '-libweb-inherit-or-center', '-libweb-left',
		'-libweb-right'])
}

fn (mut parser Parser) parse_text_justify_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value_from_metadata(.text_justify, mut tokens)
}

fn (mut parser Parser) parse_text_overflow_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['clip', 'ellipsis'])
}

fn (mut parser Parser) parse_text_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'optimizespeed', 'optimizelegibility',
		'geometricprecision'])
}

fn (mut parser Parser) parse_text_transform_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['capitalize', 'full-size-kana', 'full-width',
		'lowercase', 'math-auto', 'none', 'uppercase'])
}

fn (mut parser Parser) parse_text_wrap_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['wrap', 'nowrap'])
}

fn (mut parser Parser) parse_text_wrap_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'balance', 'stable', 'pretty'])
}

fn (mut parser Parser) parse_transform_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['flat', 'preserve-3d'])
}

fn (mut parser Parser) parse_backface_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['visible', 'hidden'])
}

fn (mut parser Parser) parse_unicode_bidi_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['bidi-override', 'embed', 'isolate',
		'isolate-override', 'normal', 'plaintext'])
}

fn (mut parser Parser) parse_user_select_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['all', 'auto', 'contain', 'none', 'text'])
}

fn (mut parser Parser) parse_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'hidden', 'visible'])
}

fn (mut parser Parser) parse_white_space_collapse_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['collapse', 'discard', 'preserve',
		'preserve-breaks', 'preserve-spaces', 'break-spaces'])
}

fn (mut parser Parser) parse_white_space_trim_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	if value := parse_property_keyword_value(mut tokens, ['none']) {
		return value
	}

	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	mut discard_before := false
	mut discard_after := false
	mut discard_inner := false

	for {
		transaction.consume_whitespace()
		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		keyword := match ident {
			'discard-before' {
				if discard_before {
					return none
				}
				discard_before = true
				Keyword.discard_before
			}
			'discard-after' {
				if discard_after {
					return none
				}
				discard_after = true
				Keyword.discard_after
			}
			'discard-inner' {
				if discard_inner {
					return none
				}
				discard_inner = true
				Keyword.discard_inner
			}
			else {
				return none
			}
		}

		values << StyleValue(KeywordStyleValue.create(keyword))
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	if values.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_word_break_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'keep-all', 'break-all', 'break-word'])
}

fn (mut parser Parser) parse_z_index_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	return parser.parse_integer_value(mut tokens)
}

fn (mut parser Parser) parse_mix_blend_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, [
		'normal',
		'multiply',
		'screen',
		'overlay',
		'darken',
		'lighten',
		'color-dodge',
		'color-burn',
		'hard-light',
		'soft-light',
		'difference',
		'exclusion',
		'hue',
		'saturation',
		'color',
		'luminosity',
		'plus-darker',
		'plus-lighter',
	])
}

fn (mut parser Parser) parse_object_fit_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['fill', 'contain', 'cover', 'none', 'scale-down'])
}

fn (mut parser Parser) parse_align_content_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['normal', 'start', 'flex-start', 'flow-start', 'end',
		'flex-end', 'flow-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch', 'baseline', 'safe', 'unsafe'])
}

fn (mut parser Parser) parse_align_items_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['anchor-center', 'baseline', 'center', 'end', 'flex-end', 'flow-end',
		'flex-start', 'flow-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe'])
}

fn (mut parser Parser) parse_align_self_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['anchor-center', 'auto', 'baseline', 'center', 'end', 'flex-end', 'flow-end',
		'flex-start', 'flow-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe'])
}

fn (mut parser Parser) parse_appearance_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'button', 'checkbox', 'listbox',
		'menulist', 'meter', 'menulist-button', 'none', 'push-button', 'progress-bar', 'radio',
		'searchfield', 'slider-horizontal', 'square-button', 'textarea', 'textfield'])
}

fn (mut parser Parser) parse_column_span_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'all'])
}

fn (mut parser Parser) parse_flex_direction_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['row', 'row-reverse', 'column', 'column-reverse'])
}

fn (mut parser Parser) parse_flex_wrap_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['nowrap', 'wrap', 'wrap-reverse'])
}

fn (mut parser Parser) parse_image_rendering_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'crisp-edges', 'high-quality',
		'pixelated', 'smooth', 'optimizespeed', 'optimizequality'])
}

fn (mut parser Parser) parse_justify_content_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['normal', 'start', 'end', 'flex-start', 'flow-start',
		'flex-end', 'flow-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch', 'left',
		'right', 'safe', 'unsafe'])
}

fn (mut parser Parser) parse_justify_items_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['anchor-center', 'baseline', 'center', 'end', 'flex-end', 'flow-end',
		'flex-start', 'flow-start', 'legacy', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch',
		'unsafe', 'left', 'right'])
}

fn (mut parser Parser) parse_justify_self_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_alignment_keyword_value(mut tokens, ['anchor-center', 'auto', 'baseline', 'center', 'end', 'flex-end', 'flow-end',
		'flex-start', 'flow-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe',
		'left', 'right'])
}

fn (mut parser Parser) parse_transform_box_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['content-box', 'border-box', 'fill-box',
		'stroke-box', 'view-box'])
}

fn (mut parser Parser) parse_writing_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['horizontal-tb', 'vertical-rl', 'vertical-lr',
		'sideways-rl', 'sideways-lr'])
}

fn (mut parser Parser) parse_scrollbar_width_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'thin', 'none'])
}

fn (mut parser Parser) parse_scroll_behavior_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'smooth'])
}

// https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-align
fn (mut parser Parser) parse_scroll_snap_align_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	first := parse_keyword_from_set_for_value_logic(mut tokens, ['none', 'start', 'end', 'center']) or { return none }
	mut transaction := tokens.clone()
	second := parse_keyword_from_set_for_value_logic(mut transaction, ['none', 'start', 'end',
		'center']) or { return first }
	tokens = transaction
	return StyleValue(StyleValueList.create([first, second], .space, .yes))
}

// https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-stop
fn (mut parser Parser) parse_scroll_snap_stop_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'always'])
}

// https://drafts.csswg.org/css-scroll-snap-1/#scroll-snap-type
fn (mut parser Parser) parse_scroll_snap_type_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// none | [ x | y | block | inline | both ] [ mandatory | proximity ]?
	mut none_transaction := tokens.clone()
	if none_value := parse_keyword_from_set_for_value_logic(mut none_transaction, [
		'none',
	]) {
		tokens = none_transaction
		return none_value
	}
	axis := parse_keyword_from_set_for_value_logic(mut tokens, ['x', 'y', 'block', 'inline', 'both']) or { return none }
	mut strictness_transaction := tokens.clone()
	strictness := parse_keyword_from_set_for_value_logic(mut strictness_transaction, [
		'mandatory',
		'proximity',
	]) or { return axis }
	tokens = strictness_transaction
	// Proximity is the default strictness and is omitted from the shortest
	// serialization, matching upstream's computed value representation.
	if strictness.to_keyword() == .proximity {
		return axis
	}
	return StyleValue(StyleValueList.create([axis, strictness], .space, .yes))
}

fn (mut parser Parser) parse_resize_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['none', 'both', 'horizontal', 'vertical',
		'inline', 'block'])
}

// https://drafts.csswg.org/css-overflow-4/#overflow-clip-margin
fn (mut parser Parser) parse_overflow_clip_margin_value(mut tokens ComponentValueStream) ?StyleValue {
	// <visual-box> || <length [0,∞]>
	// FIXME: Implement the <visual-box> part of this.
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_perspective_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_tab_size_value(mut tokens ComponentValueStream) ?StyleValue {
	// <number> is tried before <length> so a unitless `0` stays a number.
	mut transaction := tokens.clone()
	if value := parser.parse_nonnegative_number_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_vertical_align_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, [
		'baseline',
		'sub',
		'super',
		'text-top',
		'text-bottom',
		'middle',
		'top',
		'bottom',
	]) {
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_scrollbar_color_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	thumb_color := parser.parse_color_value(mut transaction) or { return none }
	track_color := parser.parse_color_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(ScrollbarColorStyleValue.create(thumb_color, track_color))
}

fn parse_scrollbar_gutter_ident_for_value_logic(mut tokens ComponentValueStream, ident string) bool {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return false }
	if !component_value.is(.ident) || !equals_ignoring_ascii_case(component_value.token().ident(), ident) {
		return false
	}
	tokens = transaction
	return true
}

fn (mut parser Parser) parse_scrollbar_gutter_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// auto | stable && both-edges?
	mut transaction := tokens.clone()
	mut stable := ?bool(none)
	mut both_edges := ?bool(none)

	if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'auto') {
		stable = false
	} else if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'stable') {
		stable = true
		if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'both-edges') {
			both_edges = true
		}
	} else if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'both-edges') {
		both_edges = true
		if !parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'stable') {
			return none
		}
		stable = true
	}

	transaction.consume_whitespace()
	if stable == none || transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	if both_edges != none {
		return StyleValue(ScrollbarGutterStyleValue.create(.both_edges))
	}
	if stable or { false } {
		return StyleValue(ScrollbarGutterStyleValue.create(.stable))
	}
	return StyleValue(ScrollbarGutterStyleValue.create(.auto_))
}

// https://drafts.csswg.org/css-text-decor-4/#text-underline-position-property
fn (mut parser Parser) parse_text_underline_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// auto | [ from-font | under ] || [ left | right ]
	mut transaction := tokens.clone()
	if parse_scrollbar_gutter_ident_for_value_logic(mut transaction, 'auto') {
		transaction.consume_whitespace()
		if transaction.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(TextUnderlinePositionStyleValue.create(.auto_, .auto_))
	}

	transaction = tokens.clone()
	mut horizontal_value := TextUnderlinePositionHorizontal.auto_
	mut vertical_value := TextUnderlinePositionVertical.auto_
	mut has_horizontal := false
	mut has_vertical := false
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		component_value := transaction.consume() or { return none }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		match ident {
			'from-font' {
				if has_horizontal {
					return none
				}
				horizontal_value = .from_font
				has_horizontal = true
			}
			'under' {
				if has_horizontal {
					return none
				}
				horizontal_value = .under
				has_horizontal = true
			}
			'left' {
				if has_vertical {
					return none
				}
				vertical_value = .left
				has_vertical = true
			}
			'right' {
				if has_vertical {
					return none
				}
				vertical_value = .right
				has_vertical = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	if !has_horizontal && !has_vertical {
		return none
	}
	tokens = transaction
	return StyleValue(TextUnderlinePositionStyleValue.create(horizontal_value, vertical_value))
}

fn position_area_keywords_for_value_logic() []string {
	return [
		'left',
		'center',
		'right',
		'span-left',
		'span-right',
		'x-start',
		'x-end',
		'span-x-start',
		'span-x-end',
		'self-x-start',
		'self-x-end',
		'span-self-x-start',
		'span-self-x-end',
		'span-all',
		'top',
		'bottom',
		'span-top',
		'span-bottom',
		'y-start',
		'y-end',
		'span-y-start',
		'span-y-end',
		'self-y-start',
		'self-y-end',
		'span-self-y-start',
		'span-self-y-end',
		'block-start',
		'block-end',
		'span-block-start',
		'span-block-end',
		'inline-start',
		'inline-end',
		'span-inline-start',
		'span-inline-end',
		'self-block-start',
		'self-block-end',
		'span-self-block-start',
		'span-self-block-end',
		'self-inline-start',
		'self-inline-end',
		'span-self-inline-start',
		'span-self-inline-end',
		'start',
		'end',
		'span-start',
		'span-end',
		'self-start',
		'self-end',
		'span-self-start',
		'span-self-end',
	]
}

fn position_area_is_x_keyword(keyword Keyword) bool {
	return keyword in [.left, .center, .right, .span_left, .span_right, .x_start, .x_end,
		.span_x_start, .span_x_end, .self_x_start, .self_x_end, .span_self_x_start, .span_self_x_end,
		.span_all]
}

fn position_area_is_y_keyword(keyword Keyword) bool {
	return keyword in [.top, .center, .bottom, .span_top, .span_bottom, .y_start, .y_end,
		.span_y_start, .span_y_end, .self_y_start, .self_y_end, .span_self_y_start, .span_self_y_end,
		.span_all]
}

fn position_area_is_block_keyword(keyword Keyword) bool {
	return keyword in [.block_start, .center, .block_end, .span_block_start, .span_block_end,
		.span_all]
}

fn position_area_is_inline_keyword(keyword Keyword) bool {
	return keyword in [.inline_start, .center, .inline_end, .span_inline_start, .span_inline_end,
		.span_all]
}

fn position_area_is_self_block_keyword(keyword Keyword) bool {
	return keyword in [.self_block_start, .center, .self_block_end, .span_self_block_start,
		.span_self_block_end, .span_all]
}

fn position_area_is_self_inline_keyword(keyword Keyword) bool {
	return keyword in [.self_inline_start, .center, .self_inline_end, .span_self_inline_start,
		.span_self_inline_end, .span_all]
}

fn position_area_is_start_end_keyword(keyword Keyword) bool {
	return keyword in [.start, .center, .end_, .span_start, .span_end, .span_all]
}

fn position_area_is_self_start_end_keyword(keyword Keyword) bool {
	return keyword in [.self_start, .center, .self_end, .span_self_start, .span_self_end, .span_all]
}

fn position_area_is_axis_ambiguous(keyword Keyword) bool {
	return keyword in [.center, .span_all, .start, .end_, .self_start, .self_end, .span_start,
		.span_end, .span_self_start, .span_self_end]
}

fn position_area_keyword_list(first StyleValue, second StyleValue) StyleValue {
	first_keyword := first.as_keyword().keyword()
	second_keyword := second.as_keyword().keyword()
	// If one keyword unambiguously identifies its axis, the other axis's
	// explicit span-all is implied and omitted from serialization.
	if !position_area_is_axis_ambiguous(first_keyword) && second_keyword == .span_all {
		return first
	}
	if !position_area_is_axis_ambiguous(second_keyword) && first_keyword == .span_all {
		return second
	}
	return StyleValue(StyleValueList.create([first, second], .space, .yes))
}

// https://drafts.csswg.org/css-anchor-position/#position-area-syntax
fn (mut parser Parser) parse_position_area(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	first_value := parse_keyword_from_set_for_value_logic(mut transaction, position_area_keywords_for_value_logic()) or { return none }
	transaction.consume_whitespace()
	second_value := parse_keyword_from_set_for_value_logic(mut transaction, position_area_keywords_for_value_logic()) or {
		tokens = transaction
		return first_value
	}

	first_keyword := first_value.as_keyword().keyword()
	second_keyword := second_value.as_keyword().keyword()
	mut result := ?StyleValue(none)
	if position_area_is_x_keyword(first_keyword) && position_area_is_y_keyword(second_keyword) {
		result = position_area_keyword_list(first_value, second_value)
	} else if position_area_is_y_keyword(first_keyword)
		&& position_area_is_x_keyword(second_keyword) {
		result = position_area_keyword_list(second_value, first_value)
	} else if position_area_is_block_keyword(first_keyword)
		&& position_area_is_inline_keyword(second_keyword) {
		result = position_area_keyword_list(first_value, second_value)
	} else if position_area_is_inline_keyword(first_keyword)
		&& position_area_is_block_keyword(second_keyword) {
		result = position_area_keyword_list(second_value, first_value)
	} else if position_area_is_self_block_keyword(first_keyword)
		&& position_area_is_self_inline_keyword(second_keyword) {
		result = position_area_keyword_list(first_value, second_value)
	} else if position_area_is_self_inline_keyword(first_keyword)
		&& position_area_is_self_block_keyword(second_keyword) {
		result = position_area_keyword_list(second_value, first_value)
	} else if position_area_is_start_end_keyword(first_keyword)
		&& position_area_is_start_end_keyword(second_keyword) {
		result = position_area_keyword_list(first_value, second_value)
	} else if position_area_is_self_start_end_keyword(first_keyword)
		&& position_area_is_self_start_end_keyword(second_keyword) {
		result = position_area_keyword_list(first_value, second_value)
	}

	parsed := result or { return none }
	tokens = transaction
	return parsed
}

fn (mut parser Parser) parse_position_area_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <position-area>
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}
	return parser.parse_position_area(mut tokens)
}

fn (mut parser Parser) parse_try_tactic_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	mut seen := map[string]bool{}
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		mut keyword_transaction := transaction.clone()
		value := parse_keyword_from_set_for_value_logic(mut keyword_transaction,
			['flip-block','flip-inline','flip-start','flip-x','flip-y']) or { break }
		word := value.serialize(.normal)
		if word in seen { return none }
		seen[word] = true
		values << value
		transaction = keyword_transaction
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_single_position_try_fallbacks_value(mut tokens ComponentValueStream) ?StyleValue {
	// [<dashed-ident> || <try-tactic>] | <position-area>
	mut transaction := tokens.clone()
	if value := parser.parse_position_area(mut transaction) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	mut dashed_ident := ?StyleValue(none)
	mut try_tactic := ?StyleValue(none)
	mut has_dashed_ident := false
	mut has_try_tactic := false
	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		mut try_transaction := transaction.clone()
		if value := parser.parse_try_tactic_value(mut try_transaction) {
			if has_try_tactic {
				return none
			}
			try_tactic = value
			has_try_tactic = true
			transaction = try_transaction
			transaction.consume_whitespace()
			continue
		}
		mut dashed_transaction := transaction.clone()
		if value := parser.parse_dashed_ident_value(mut dashed_transaction, []) {
			if has_dashed_ident {
				return none
			}
			dashed_ident = value
			has_dashed_ident = true
			transaction = dashed_transaction
			transaction.consume_whitespace()
			continue
		}
		return none
	}

	mut values := []StyleValue{}
	if value := dashed_ident {
		values << value
	}
	if value := try_tactic {
		values << value
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_position_try_fallbacks_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | [ [<dashed-ident> || <try-tactic>] | <position-area> ]#
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut fallbacks := []StyleValue{}
	for value in values {
		mut fallback_tokens := ComponentValueStream.new(value)
		fallback := parser.parse_single_position_try_fallbacks_value(mut fallback_tokens) or {
			return none
		}
		fallback_tokens.consume_whitespace()
		if fallback_tokens.has_more_tokens() {
			return none
		}
		fallbacks << fallback
	}
	if fallbacks.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(fallbacks, .comma, .yes))
}

fn (mut parser Parser) parse_position_try_order_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_keyword_from_set_for_value_logic(mut tokens, [
		'normal',
		'most-width',
		'most-height',
		'most-block-size',
		'most-inline-size',
	])
}

fn (mut parser Parser) parse_timeline_scope_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['none', 'all']) {
		tokens = transaction
		return value
	}
	return parser.parse_dashed_ident_comma_list_value(mut tokens, ['none', 'all'])
}

fn parse_will_change_feature_for_value_logic(mut parser Parser, values []ComponentValue) ?StyleValue {
	mut tokens := ComponentValueStream.new(values)
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	if ident in ['scroll-position', 'contents'] {
		keyword := keyword_from_string(ident) or { return none }
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	if ident in ['all', 'auto', 'none', 'will-change'] || is_css_wide_keyword_string(ident) {
		return none
	}
	mut ident_tokens := ComponentValueStream.new(values)
	custom_ident := parser.parse_custom_ident_value(mut ident_tokens, [
		'all',
		'auto',
		'contents',
		'none',
		'scroll-position',
		'will-change',
	]) or { return none }
	ident_tokens.consume_whitespace()
	if ident_tokens.has_more_tokens() {
		return none
	}
	return StyleValue(custom_ident)
}

fn (mut parser Parser) parse_will_change_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())
	mut features := []StyleValue{}
	for value in values {
		feature := parse_will_change_feature_for_value_logic(mut parser, value) or { return none }
		features << feature
	}
	if features.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(features, .comma, .yes))
}

fn (mut parser Parser) parse_view_transition_name_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parse_property_keyword_value(mut tokens, ['none']) {
		return value
	}
	value := parser.parse_custom_ident_value(mut tokens, ['auto', 'none']) or { return none }
	return StyleValue(value)
}

fn parse_single_keyword_from_set_for_value_logic(mut tokens ComponentValueStream, allowed []string) ?Keyword {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed {
		return none
	}
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return keyword
}

fn parse_keyword_from_set_for_value_logic(mut tokens ComponentValueStream, allowed []string) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed {
		return none
	}
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_contain_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// none | strict | content | [ [size | inline-size] || layout || style || paint ]
	if value := parse_property_keyword_value(mut tokens, ['none', 'strict', 'content']) {
		return value
	}

	mut transaction := tokens.clone()
	mut size_value := ?StyleValue(none)
	mut layout_value := ?StyleValue(none)
	mut style_value := ?StyleValue(none)
	mut paint_value := ?StyleValue(none)
	mut size_value_set := false
	mut layout_value_set := false
	mut style_value_set := false
	mut paint_value_set := false

	for {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'size',
			'inline-size',
			'layout',
			'style',
			'paint',
		]) or { break }
		match keyword {
			.size, .inline_size {
				if size_value_set {
					return none
				}
				size_value = StyleValue(KeywordStyleValue.create(keyword))
				size_value_set = true
			}
			.layout {
				if layout_value_set {
					return none
				}
				layout_value = StyleValue(KeywordStyleValue.create(keyword))
				layout_value_set = true
			}
			.style {
				if style_value_set {
					return none
				}
				style_value = StyleValue(KeywordStyleValue.create(keyword))
				style_value_set = true
			}
			.paint {
				if paint_value_set {
					return none
				}
				paint_value = StyleValue(KeywordStyleValue.create(keyword))
				paint_value_set = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	mut containment_values := []StyleValue{}
	if value := size_value {
		containment_values << value
	}
	if value := layout_value {
		containment_values << value
	}
	if value := style_value {
		containment_values << value
	}
	if value := paint_value {
		containment_values << value
	}
	if containment_values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(containment_values, .space, .yes))
}

// https://drafts.csswg.org/css-conditional-5/#propdef-container-name
fn (mut parser Parser) parse_container_name_value(mut tokens ComponentValueStream) ?StyleValue {
	if value := parse_property_keyword_value(mut tokens, ['none']) {
		return value
	}

	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut names := []StyleValue{}
	for transaction.has_more_tokens() {
		if next := transaction.peek() {
			if next.is_delim(u32(`/`)) {
				break
			}
		}
		name := parser.parse_custom_ident_value(mut transaction, ['none', 'and', 'not', 'or']) or { break }
		names << StyleValue(name)
		transaction.consume_whitespace()
	}
	if names.len == 0 {
		return none
	}

	tokens = transaction
	if names.len == 1 {
		return names[0]
	}
	return StyleValue(StyleValueList.create(names, .space, .no))
}

// https://drafts.csswg.org/css-conditional-5/#propdef-container
fn (mut parser Parser) parse_container_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	name := parser.parse_container_name_value(mut transaction) or { return none }
	transaction.consume_whitespace()

	mut type_ := StyleValue(KeywordStyleValue.create(.normal))
	if transaction.has_more_tokens() {
		solidus := transaction.consume() or { return none }
		if !solidus.is_delim(u32(`/`)) {
			return none
		}
		transaction.consume_whitespace()
		type_ = parser.parse_container_type_value(mut transaction) or { return none }
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.container, [.container_name, .container_type], [
		name,
		type_,
	]))
}

fn (mut parser Parser) parse_container_type_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// normal | [ [ size | inline-size ] || scroll-state ]
	if value := parse_property_keyword_value(mut tokens, ['normal']) {
		return value
	}

	mut transaction := tokens.clone()
	mut size_value := ?StyleValue(none)
	mut scroll_state_value := ?StyleValue(none)
	mut size_value_set := false
	mut scroll_state_value_set := false

	for {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'size',
			'inline-size',
			'scroll-state',
		]) or { break }
		match keyword {
			.size, .inline_size {
				if size_value_set {
					return none
				}
				size_value = StyleValue(KeywordStyleValue.create(keyword))
				size_value_set = true
			}
			.scroll_state {
				if scroll_state_value_set {
					return none
				}
				scroll_state_value = StyleValue(KeywordStyleValue.create(keyword))
				scroll_state_value_set = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	mut containment_values := []StyleValue{}
	if value := size_value {
		containment_values << value
	}
	if value := scroll_state_value {
		containment_values << value
	}
	if containment_values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(containment_values, .space, .yes))
}

struct PaintOrderParseState {
mut:
	has_fill    bool
	has_stroke  bool
	has_markers bool
}

fn parse_paint_order_keyword_for_value_logic(mut tokens ComponentValueStream, mut state PaintOrderParseState) ?StyleValue {
	keyword := parse_single_keyword_from_set_for_value_logic(mut tokens, [
		'fill',
		'markers',
		'stroke',
	]) or { return none }

	match keyword {
		.fill {
			if state.has_fill {
				return none
			}
			state.has_fill = true
		}
		.markers {
			if state.has_markers {
				return none
			}
			state.has_markers = true
		}
		.stroke {
			if state.has_stroke {
				return none
			}
			state.has_stroke = true
		}
		else {
			return none
		}
	}

	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_paint_order_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	if normal := parse_property_keyword_value(mut tokens, ['normal']) {
		return normal
	}

	mut transaction := tokens.clone()
	mut state := PaintOrderParseState{}

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		return none
	}

	first_keyword_value := parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or {
		return none
	}

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_keyword_value
	}

	second_keyword_value := parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or {
		return none
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		// The third keyword is parsed to ensure it is valid, but it doesn't get added to the list. This follows the
		// shortest-serialization principle, as the value can always be inferred.
		_ = parse_paint_order_keyword_for_value_logic(mut transaction, mut state) or { return none }
		transaction.consume_whitespace()
		if transaction.has_more_tokens() {
			return none
		}
	}

	tokens = transaction
	mut expected_second_keyword := Keyword.fill
	if first_keyword_value.to_keyword() == .fill {
		expected_second_keyword = .stroke
	}

	if expected_second_keyword == second_keyword_value.to_keyword() {
		return first_keyword_value
	}

	return StyleValue(StyleValueList.create([first_keyword_value, second_keyword_value], .space, .yes))
}

fn (mut parser Parser) parse_text_decoration_line_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	mut has_underline := false
	mut has_overline := false
	mut has_line_through := false
	mut has_blink := false
	mut has_spelling_error := false
	mut has_grammar_error := false
	mut style_values_count := 0
	mut includes_spelling_or_grammar_error_value := false

	for {
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}

		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'none',
			'underline',
			'overline',
			'line-through',
			'blink',
			'spelling-error',
			'grammar-error',
		]) or { break }

		match keyword {
			.none_ {
				if style_values_count != 0 {
					return none
				}
				tokens = transaction
				return StyleValue(KeywordStyleValue.create(keyword))
			}
			.underline {
				if has_underline {
					return none
				}
				has_underline = true
			}
			.overline {
				if has_overline {
					return none
				}
				has_overline = true
			}
			.line_through {
				if has_line_through {
					return none
				}
				has_line_through = true
			}
			.blink {
				if has_blink {
					return none
				}
				has_blink = true
			}
			.spelling_error {
				if has_spelling_error {
					return none
				}
				has_spelling_error = true
				includes_spelling_or_grammar_error_value = true
			}
			.grammar_error {
				if has_grammar_error {
					return none
				}
				has_grammar_error = true
				includes_spelling_or_grammar_error_value = true
			}
			else {
				return none
			}
		}

		style_values_count++
	}

	// Do not reject trailing tokens: this is a component parser used inside the
	// `text-decoration` shorthand (e.g. `underline` in `underline dotted red`).
	if style_values_count == 0 {
		return none
	}

	// These can only appear on their own.
	if style_values_count > 1 && includes_spelling_or_grammar_error_value {
		return none
	}

	mut style_values := []StyleValue{}
	if has_underline {
		style_values << StyleValue(KeywordStyleValue.create(.underline))
	}
	if has_overline {
		style_values << StyleValue(KeywordStyleValue.create(.overline))
	}
	if has_line_through {
		style_values << StyleValue(KeywordStyleValue.create(.line_through))
	}
	if has_blink {
		style_values << StyleValue(KeywordStyleValue.create(.blink))
	}
	if has_spelling_error {
		style_values << StyleValue(KeywordStyleValue.create(.spelling_error))
	}
	if has_grammar_error {
		style_values << StyleValue(KeywordStyleValue.create(.grammar_error))
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(style_values, .space, .yes))
}

fn (mut parser Parser) parse_text_decoration_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['dashed', 'dotted', 'double', 'solid', 'wavy'])
}

fn parse_property_keyword_value(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in allowed_keywords {
		return none
	}
	// Do NOT reject trailing tokens here: this helper is also used as a component
	// parser inside `||`/`&&` shorthands (e.g. `solid` in `border: 1px solid red`),
	// where more tokens legitimately follow. Whole-value callers rely on the
	// top-level leftover-token check in parse_css_value_tokens instead.
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

// Rust value_parser.rs parse_alignment_property(): preserve the overflow and
// baseline qualifiers, and canonicalize first baseline and legacy ordering.
fn parse_alignment_keyword_value(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	first := transaction.consume() or { return none }
	if !first.is(.ident) { return none }
	mut words := [first.token().ident().to_lower()]
	if words[0] in ['safe', 'unsafe', 'first', 'last', 'legacy'] {
		mut second_stream := transaction.clone()
		second_stream.consume_whitespace()
		if second := second_stream.consume() {
			if !second.is(.ident) { return none }
			words << second.token().ident().to_lower()
			transaction = second_stream
		} else if words[0] != 'legacy' { return none }
	} else if 'legacy' in allowed_keywords && words[0] in ['left', 'right', 'center'] {
		mut second_stream := transaction.clone()
		second_stream.consume_whitespace()
		if second := second_stream.consume() {
			if second.is(.ident) && second.token().ident().to_lower() == 'legacy' {
				words << 'legacy'
				transaction = second_stream
			}
		}
	}
	if words.len == 1 {
		if words[0] !in allowed_keywords || words[0] in ['safe', 'unsafe'] { return none }
	} else if words.len == 2 {
		if words[0] in ['first', 'last'] && words[1] == 'baseline' {
			if 'baseline' !in allowed_keywords { return none }
			if words[0] == 'first' { words = ['baseline'] }
		} else if words[0] in ['safe', 'unsafe'] {
			if words[1] !in allowed_keywords || (words[1] !in ['start', 'end', 'center',
				'flex-start', 'flex-end', 'flow-start', 'flow-end', 'self-start', 'self-end', 'left', 'right']
				&& !(words[1] == 'normal' && 'auto' in allowed_keywords)) { return none }
		} else if 'legacy' in allowed_keywords && 'legacy' in words {
			position := if words[0] == 'legacy' { words[1] } else { words[0] }
			if position !in ['left', 'right', 'center'] { return none }
			words = ['legacy', position]
		} else { return none }
	} else { return none }
	mut values := []StyleValue{}
	for word in words {
		values << StyleValue(KeywordStyleValue.create(keyword_from_string(word) or { return none }))
	}
	tokens = transaction
	return if values.len == 1 { values[0] } else { StyleValue(StyleValueList.create(values, .space, .yes)) }
}

fn parse_property_keyword_value_from_metadata(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	if !property_accepts_keyword(property_id, keyword) {
		return none
	}
	resolved_keyword := resolve_legacy_value_alias(property_id, keyword) or { keyword }
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(resolved_keyword))
}

fn parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens ComponentValueStream, allowed_keywords []string) ?StyleValue {
	return parse_animation_keyword_list_for_value_logic(mut tokens, allowed_keywords)
}

fn (mut parser Parser) parse_background_attachment_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'fixed',
		'local',
		'scroll',
	])
}

fn (mut parser Parser) parse_background_blend_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'normal',
		'multiply',
		'screen',
		'overlay',
		'darken',
		'lighten',
		'color-dodge',
		'color-burn',
		'hard-light',
		'soft-light',
		'difference',
		'exclusion',
		'hue',
		'saturation',
		'color',
		'luminosity',
		'plus-darker',
		'plus-lighter',
	])
}

fn (mut parser Parser) parse_background_box_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'border-box',
		'content-box',
		'padding-box',
		'text',
	])
}

enum PositionParsingMode {
	normal
	background_position
}

struct PositionAndLengthForValueLogic {
	position PositionEdge
	length   StyleValue
}

struct PositionAndMaybeLengthForValueLogic {
	position PositionEdge
	length   ?StyleValue
}

fn keyword_to_position_edge_for_value_logic(keyword Keyword) ?PositionEdge {
	return match keyword {
		.center { PositionEdge.center }
		.left { PositionEdge.left }
		.right { PositionEdge.right }
		.top { PositionEdge.top }
		.bottom { PositionEdge.bottom }
		else { none }
	}
}

fn parse_position_edge_for_value_logic(mut tokens ComponentValueStream) ?PositionEdge {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	edge := keyword_to_position_edge_for_value_logic(keyword) or { return none }
	tokens = transaction
	return edge
}

fn position_edge_is_horizontal_for_value_logic(edge PositionEdge, accept_center bool) bool {
	return match edge {
		.left, .right { true }
		.center { accept_center }
		else { false }
	}
}

fn position_edge_is_vertical_for_value_logic(edge PositionEdge, accept_center bool) bool {
	return match edge {
		.top, .bottom { true }
		.center { accept_center }
		else { false }
	}
}

fn (mut parser Parser) parse_position_or_length_for_value_logic(mut tokens ComponentValueStream, as_horizontal bool) ?EdgeStyleValue {
	tokens.consume_whitespace()

	mut edge_transaction := tokens.clone()
	if position := parse_position_edge_for_value_logic(mut edge_transaction) {
		valid := if as_horizontal {
			position_edge_is_horizontal_for_value_logic(position, true)
		} else {
			position_edge_is_vertical_for_value_logic(position, true)
		}
		if !valid {
			return none
		}
		tokens = edge_transaction
		return EdgeStyleValue.create(position, none)
	}

	mut length_transaction := tokens.clone()
	maybe_length := parser.parse_length_percentage_value(mut length_transaction) or { return none }
	tokens = length_transaction
	return EdgeStyleValue.create(none, maybe_length)
}

fn (mut parser Parser) parse_position_and_length_for_value_logic(mut tokens ComponentValueStream) ?PositionAndLengthForValueLogic {
	tokens.consume_whitespace()
	position := parse_position_edge_for_value_logic(mut tokens) or { return none }
	tokens.consume_whitespace()
	length := parser.parse_length_percentage_value(mut tokens) or { return none }
	return PositionAndLengthForValueLogic{
		position: position
		length: length
	}
}

fn (mut parser Parser) parse_position_and_maybe_length_for_value_logic(mut tokens ComponentValueStream) ?PositionAndMaybeLengthForValueLogic {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	position := parse_position_edge_for_value_logic(mut transaction) or { return none }
	transaction.consume_whitespace()
	mut length := ?StyleValue(none)
	if maybe_length := parser.parse_length_percentage_value(mut transaction) {
		// 'center' cannot be followed by a <length-percentage>
		if position == .center {
			return none
		}
		length = maybe_length
	}
	tokens = transaction
	return PositionAndMaybeLengthForValueLogic{
		position: position
		length: length
	}
}

fn (mut parser Parser) parse_css_position_value(mut tokens ComponentValueStream, position_parsing_mode PositionParsingMode) ?StyleValue {
	// <position> = [
	//   [ left | center | right | top | bottom | <length-percentage> ]
	// |
	//   [ left | center | right ] && [ top | center | bottom ]
	// |
	//   [ left | center | right | <length-percentage> ]
	//   [ top | center | bottom | <length-percentage> ]
	// |
	//   [ [ left | right ] <length-percentage> ] &&
	//   [ [ top | bottom ] <length-percentage> ]
	// ]

	// [ [ left | right ] <length-percentage> ] &&
	// [ [ top | bottom ] <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if group1 := parser.parse_position_and_length_for_value_logic(mut transaction) {
			if group2 := parser.parse_position_and_length_for_value_logic(mut transaction) {
				if position_edge_is_horizontal_for_value_logic(group1.position, false) && position_edge_is_vertical_for_value_logic(group2.position, false) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(group1.position, group1.length), EdgeStyleValue.create(group2.position, group2.length)))
				}
				if position_edge_is_vertical_for_value_logic(group1.position, false) && position_edge_is_horizontal_for_value_logic(group2.position, false) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(group2.position, group2.length), EdgeStyleValue.create(group1.position, group1.length)))
				}
			}
		}
	}

	// The extra 3-value syntax that's allowed for background-position:
	// [ center | [ left | right ] <length-percentage>? ] &&
	// [ center | [ top | bottom ] <length-percentage>? ]
	if position_parsing_mode == .background_position {
		mut transaction := tokens.clone()
		if group1_value := parser.parse_position_and_maybe_length_for_value_logic(mut transaction) {
			if group2_value := parser.parse_position_and_maybe_length_for_value_logic(mut transaction) {
				mut group1 := group1_value
				mut group2 := group2_value

				// 2-value or 4-value if both <length-percentage>s are present or missing.
				if !((group1.length != none && group2.length != none) || (group1.length == none && group2.length == none)) {
					// If 'left' or 'right' is given, that position is X and the other is Y.
					// Conversely -
					// If 'top' or 'bottom' is given, that position is Y and the other is X.
					if position_edge_is_vertical_for_value_logic(group1.position, false) || position_edge_is_horizontal_for_value_logic(group2.position, false) {
						tmp := group1
						group1 = group2
						group2 = tmp
					}

					// [ center | [ left | right ] ]
					if position_edge_is_horizontal_for_value_logic(group1.position, true) && position_edge_is_vertical_for_value_logic(group2.position, true) {
						edge_x := if group1.position == .center {
							EdgeStyleValue.create(PositionEdge.center, none)
						} else {
							EdgeStyleValue.create(group1.position, group1.length)
						}
						edge_y := if group2.position == .center {
							EdgeStyleValue.create(PositionEdge.center, none)
						} else {
							EdgeStyleValue.create(group2.position, group2.length)
						}
						tokens = transaction
						return StyleValue(PositionStyleValue.create(edge_x, edge_y))
					}
				}
			}
		}
	}

	// [ left | center | right | <length-percentage> ]
	// [ top | center | bottom | <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if horizontal_edge := parser.parse_position_or_length_for_value_logic(mut transaction, true) {
			if vertical_edge := parser.parse_position_or_length_for_value_logic(mut transaction, false) {
				tokens = transaction
				return StyleValue(PositionStyleValue.create(horizontal_edge, vertical_edge))
			}
		}
	}

	// [ left | center | right ] && [ top | center | bottom ]
	{
		mut transaction := tokens.clone()
		if first_edge_value := parse_position_edge_for_value_logic(mut transaction) {
			mut first_edge := first_edge_value
			transaction.consume_whitespace()
			if second_edge_value := parse_position_edge_for_value_logic(mut transaction) {
				mut second_edge := second_edge_value

				// If 'left' or 'right' is given, that position is X and the other is Y.
				// Conversely -
				// If 'top' or 'bottom' is given, that position is Y and the other is X.
				if position_edge_is_vertical_for_value_logic(first_edge, false) || position_edge_is_horizontal_for_value_logic(second_edge, false) {
					tmp := first_edge
					first_edge = second_edge
					second_edge = tmp
				}
				if position_edge_is_horizontal_for_value_logic(first_edge, true) && position_edge_is_vertical_for_value_logic(second_edge, true) {
					tokens = transaction
					return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(first_edge, none), EdgeStyleValue.create(second_edge, none)))
				}
			}
		}
	}

	// [ left | center | right | top | bottom | <length-percentage> ]
	{
		mut transaction := tokens.clone()
		if edge := parse_position_edge_for_value_logic(mut transaction) {
			tokens = transaction
			if position_edge_is_horizontal_for_value_logic(edge, false) {
				return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(edge, none), EdgeStyleValue.create(PositionEdge.center, none)))
			}
			if position_edge_is_vertical_for_value_logic(edge, false) {
				return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(PositionEdge.center, none), EdgeStyleValue.create(edge, none)))
			}
			return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(PositionEdge.center, none), EdgeStyleValue.create(PositionEdge.center, none)))
		}

		mut length_transaction := tokens.clone()
		if maybe_percentage := parser.parse_length_percentage_value(mut length_transaction) {
			tokens = length_transaction
			return StyleValue(PositionStyleValue.create(EdgeStyleValue.create(none, maybe_percentage), EdgeStyleValue.create(PositionEdge.center, none)))
		}
	}

	return none
}

fn (mut parser Parser) parse_position_list_value(mut tokens ComponentValueStream, position_parsing_mode PositionParsingMode) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut positions := []StyleValue{}
	for value in values {
		mut position_tokens := ComponentValueStream.new(value)
		position_value := parser.parse_css_position_value(mut position_tokens, position_parsing_mode) or { return none }
		position_tokens.consume_whitespace()
		if position_tokens.has_more_tokens() {
			return none
		}
		positions << position_value
	}

	if positions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(positions, .comma, .yes))
}

fn (mut parser Parser) parse_single_background_position_x_or_y_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut relative_edge := ?PositionEdge(none)

	mut keyword_transaction := transaction.clone()
	if keyword := parse_single_keyword_from_set_for_value_logic(mut keyword_transaction, if property_id == .background_position_x {
		['center', 'left', 'right']
	} else {
		['center', 'bottom', 'top']
	}) {
		if keyword == .center {
			tokens = keyword_transaction
			return StyleValue(EdgeStyleValue.create(PositionEdge.center, none))
		}
		relative_edge = keyword_to_position_edge_for_value_logic(keyword) or { return none }
		transaction = keyword_transaction
		if value := parser.parse_length_percentage_value(mut transaction) {
			tokens = transaction
			return StyleValue(EdgeStyleValue.create(relative_edge, value))
		}
		tokens = transaction
		return StyleValue(EdgeStyleValue.create(relative_edge, none))
	}

	value := parser.parse_length_percentage_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(EdgeStyleValue.create(relative_edge, value))
}

fn (mut parser Parser) parse_background_position_axis_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut positions := []StyleValue{}
	for value in values {
		mut position_tokens := ComponentValueStream.new(value)
		position_value := parser.parse_single_background_position_x_or_y_value(property_id, mut position_tokens) or { return none }
		position_tokens.consume_whitespace()
		if position_tokens.has_more_tokens() {
			return none
		}
		positions << position_value
	}

	if positions.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(positions, .comma, .yes))
}

fn (mut parser Parser) parse_background_size_component_value(mut tokens ComponentValueStream, allow_cover_contain bool) ?StyleValue {
	mut transaction := tokens.clone()
	allowed_keywords := if allow_cover_contain {
		['auto', 'cover', 'contain']
	} else {
		['auto']
	}
	if value := parse_property_keyword_value(mut transaction, allowed_keywords) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_single_background_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	x_value := parser.parse_background_size_component_value(mut transaction, true) or {
		return none
	}
	if x_value.to_keyword() in [.cover, .contain] {
		tokens = transaction
		return x_value
	}

	y_value := parser.parse_background_size_component_value(mut transaction, false) or {
		tokens = transaction
		return StyleValue(BackgroundSizeStyleValue.create(x_value, StyleValue(KeywordStyleValue.create(.auto))))
	}
	tokens = transaction
	return StyleValue(BackgroundSizeStyleValue.create(x_value, y_value))
}

fn (mut parser Parser) parse_background_size_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	_ = property_id
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut sizes := []StyleValue{}
	for value in values {
		mut size_tokens := ComponentValueStream.new(value)
		size_value := parser.parse_single_background_size_value(mut size_tokens) or { return none }
		size_tokens.consume_whitespace()
		if size_tokens.has_more_tokens() {
			return none
		}
		sizes << size_value
	}

	if sizes.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(sizes, .comma, .yes))
}

fn parse_border_image_fill_for_value_logic(mut tokens ComponentValueStream) bool {
	mut transaction := tokens.clone()
	component_value := transaction.consume() or { return false }
	if !component_value.is(.ident) {
		return false
	}
	if !equals_ignoring_ascii_case(component_value.token().ident(), 'fill') {
		return false
	}
	tokens = transaction
	return true
}

// https://drafts.csswg.org/css-backgrounds/#border-image-slice
fn (mut parser Parser) parse_border_image_slice_value(mut tokens ComponentValueStream) ?StyleValue {
	// [<number [0,+infinity]> | <percentage [0,+infinity]>]{1,4} && fill?
	mut transaction := tokens.clone()
	mut fill := false

	transaction.consume_whitespace()
	if parse_border_image_fill_for_value_logic(mut transaction) {
		fill = true
	}
	transaction.consume_whitespace()

	mut number_percentages := []StyleValue{}
	for number_percentages.len <= 4 && transaction.has_more_tokens() {
		number_percentage := parser.parse_number_percentage_value(mut transaction) or { break }
		if style_value_numeric_component_is_negative_for_value_logic(number_percentage) {
			return none
		}
		number_percentages << number_percentage
		transaction.consume_whitespace()
	}

	mut expanded_values := []StyleValue{}
	match number_percentages.len {
		1 {
			expanded_values = [
				number_percentages[0],
				number_percentages[0],
				number_percentages[0],
				number_percentages[0],
			]
		}
		2 {
			expanded_values = [
				number_percentages[0],
				number_percentages[1],
				number_percentages[0],
				number_percentages[1],
			]
		}
		3 {
			expanded_values = [
				number_percentages[0],
				number_percentages[1],
				number_percentages[2],
				number_percentages[1],
			]
		}
		4 {
			expanded_values = number_percentages.clone()
		}
		else {
			return none
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() && parse_border_image_fill_for_value_logic(mut transaction) {
		if fill {
			return none
		}
		fill = true
		transaction.consume_whitespace()
	}

	tokens = transaction
	return StyleValue(BorderImageSliceStyleValue.create(expanded_values[0], expanded_values[1], expanded_values[2], expanded_values[3], fill))
}

fn (mut parser Parser) parse_border_radius_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-borders-4/#typedef-border-radius
	// <border-radius> = <slash-separated-border-radius-syntax> | <legacy-border-radius-syntax>
	// <slash-separated-border-radius-syntax> = <length-percentage [0,+infinity]> [ / <length-percentage [0,+infinity]> ]?
	// <legacy-border-radius-syntax> = <length-percentage [0,+infinity]>{1,2}
	// NB: So, 1 or 2 `<length-percentage>`s, optionally separated with a `/`.
	parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.border_radius))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	horizontal := parser.parse_nonnegative_length_percentage_value(mut transaction) or {
		return none
	}
	transaction.consume_whitespace()

	if next_token := transaction.peek() {
		if next_token.is_delim(u32(`/`)) {
			transaction.consume()
			transaction.consume_whitespace()
		}
	}

	if vertical := parser.parse_nonnegative_length_percentage_value(mut transaction) {
		tokens = transaction
		return StyleValue(BorderRadiusStyleValue.create(horizontal, vertical))
	}

	tokens = transaction
	return StyleValue(BorderRadiusStyleValue.create(horizontal, horizontal))
}

fn (mut parser Parser) parse_border_image_outset_component_value(mut tokens ComponentValueStream) ?StyleValue {
	// <number> is tried before <length> so a unitless `0` stays a number.
	mut transaction := tokens.clone()
	if value := parser.parse_nonnegative_number_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_border_image_width_component_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	// <number> is tried before <length> so a unitless `0` stays a number.
	if value := parser.parse_nonnegative_number_value(mut transaction) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_border_image_outset_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	for values.len < 4 && transaction.has_more_tokens() {
		value := parser.parse_border_image_outset_component_value(mut transaction) or { break }
		values << value
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn (mut parser Parser) parse_border_image_width_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	mut values := []StyleValue{}
	for values.len < 4 && transaction.has_more_tokens() {
		value := parser.parse_border_image_width_component_value(mut transaction) or { break }
		values << value
		transaction.consume_whitespace()
	}
	if values.len == 0 {
		return none
	}
	tokens = transaction
	if values.len == 1 {
		return values[0]
	}
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

// https://drafts.csswg.org/css-anchor-position-1/#funcdef-anchor
fn anchor_allowed_for_property(property_id PropertyID) bool {
	return property_id in [.inset, .top, .right, .bottom, .left, .inset_block, .inset_block_start,
		.inset_block_end, .inset_inline, .inset_inline_start, .inset_inline_end]
}

fn (mut parser Parser) parse_anchor(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('anchor') {
		return none
	}
	mut property_context := ?PropertyID(none)
	for value_context in parser.value_context {
		if value_context is PropertyID {
			property_context = value_context
		}
	}
	if property_id := property_context {
		if !anchor_allowed_for_property(property_id) {
			return none
		}
	} else {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: component_value.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut anchor_name := ?string(none)
	mut anchor_side := ?StyleValue(none)
	for _ in 0 .. 2 {
		argument_tokens.consume_whitespace()
		peek := argument_tokens.peek() or { break }
		if peek.is(.ident) && peek.token().ident().starts_with('--') {
			if anchor_name != none {
				return none
			}
			anchor_name = peek.token().ident()
			argument_tokens.consume()
			continue
		}

		if anchor_side != none {
			break
		}
		mut keyword_attempt := argument_tokens.clone()
		if value := parser.parse_keyword_value(mut keyword_attempt) {
			if value.to_keyword() !in [.inside, .outside, .top, .left, .right, .bottom, .start,
				.end_, .self_start, .self_end, .center] {
				return none
			}
			anchor_side = value
			argument_tokens = keyword_attempt
			continue
		}

		mut percentage_attempt := argument_tokens.clone()
		value := parser.parse_length_percentage_value(mut percentage_attempt) or { return none }
		if value.is_length() {
			return none
		}
		anchor_side = value
		argument_tokens = percentage_attempt
	}

	mut fallback_value := ?StyleValue(none)
	if argument_tokens.consume_a_comma() {
		mut fallback_attempt := argument_tokens.clone()
		if value := parser.parse_length_percentage_value(mut fallback_attempt) {
			fallback_value = value
			argument_tokens = fallback_attempt
		} else {
			fallback_value = parser.parse_anchor(mut argument_tokens) or { return none }
		}
	}
	argument_tokens.consume_whitespace()
	if argument_tokens.has_more_tokens() {
		return none
	}
	resolved_side := anchor_side or { return none }
	tokens = transaction
	return StyleValue(AnchorStyleValue.create(anchor_name, resolved_side, fallback_value))
}

fn anchor_size_allowed_for_property(property_id PropertyID) bool {
	return property_id in [.inset, .top, .right, .bottom, .left, .inset_block, .inset_block_start,
		.inset_block_end, .inset_inline, .inset_inline_start, .inset_inline_end, .margin, .margin_top,
		.margin_right, .margin_bottom, .margin_left, .margin_block, .margin_block_start,
		.margin_block_end, .margin_inline, .margin_inline_start, .margin_inline_end, .width,
		.min_width, .max_width, .height, .min_height, .max_height, .block_size, .min_block_size,
		.max_block_size, .inline_size, .min_inline_size, .max_inline_size, .align_self, .justify_self,
		.place_self]
}

fn anchor_size_from_keyword(keyword Keyword) ?AnchorSize {
	return match keyword {
		.width { .width }
		.height { .height }
		.block { .block }
		.inline_ { .inline_ }
		.self_block { .self_block }
		.self_inline { .self_inline }
		else { none }
	}
}

// https://drafts.csswg.org/css-anchor-position-1/#sizing
fn (mut parser Parser) parse_anchor_size(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is_function_named('anchor-size') {
		return none
	}
	mut valid_property_context := false
	for value_context in parser.value_context {
		match value_context {
			PropertyID {
				if !anchor_size_allowed_for_property(value_context) {
					valid_property_context = false
					break
				}
				valid_property_context = true
			}
			else {}
		}
	}
	if !valid_property_context {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: component_value.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut anchor_name := ?string(none)
	mut anchor_size := ?AnchorSize(none)
	for _ in 0 .. 2 {
		argument_tokens.consume_whitespace()
		peek := argument_tokens.peek() or { break }
		if !peek.is(.ident) {
			break
		}
		ident := peek.token().ident()
		if ident.starts_with('--') {
			if anchor_name != none {
				return none
			}
			anchor_name = ident
			argument_tokens.consume()
			continue
		}
		keyword := keyword_from_string(ident) or { return none }
		resolved_size := anchor_size_from_keyword(keyword) or { return none }
		if anchor_size != none {
			return none
		}
		anchor_size = resolved_size
		argument_tokens.consume()
	}

	argument_tokens.consume_whitespace()
	has_name_or_size := anchor_name != none || anchor_size != none
	comma_present := argument_tokens.consume_a_comma()
	if comma_present && !has_name_or_size {
		return none
	}

	mut fallback_value := ?StyleValue(none)
	mut nested_attempt := argument_tokens.clone()
	if nested := parser.parse_anchor_size(mut nested_attempt) {
		fallback_value = nested
		argument_tokens = nested_attempt
	} else {
		mut fallback_attempt := argument_tokens.clone()
		if fallback := parser.parse_length_percentage_value(mut fallback_attempt) {
			fallback_value = fallback
			argument_tokens = fallback_attempt
		}
	}
	if fallback_value == none && comma_present {
		return none
	}
	if fallback_value != none && !comma_present && has_name_or_size {
		return none
	}
	argument_tokens.consume_whitespace()
	if argument_tokens.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(AnchorSizeStyleValue.create(anchor_name, anchor_size, fallback_value))
}

fn (mut parser Parser) parse_fit_content_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'fit-content') {
		tokens = transaction
		return StyleValue(KeywordStyleValue.create(.fit_content))
	}
	if component_value.is_function_named('fit-content') {
		parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
			name: component_value.function().name
		}))
		defer {
			parser.pop_temporary_value_parsing_context()
		}
		mut function_tokens := ComponentValueStream.new(component_value.function().value)
		length_percentage := parser.parse_nonnegative_length_percentage_value(mut function_tokens) or {
			return none
		}
		function_tokens.consume_whitespace()
		if function_tokens.has_more_tokens() {
			return none
		}
		tokens = transaction
		return StyleValue(FunctionStyleValue.create('fit-content', length_percentage))
	}
	return none
}

fn property_is_max_size_for_value_logic(property_id PropertyID) bool {
	return property_id in [.max_block_size, .max_height, .max_inline_size, .max_width]
}

fn (mut parser Parser) parse_sizing_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	allowed_keywords := if property_is_max_size_for_value_logic(property_id) {
		['max-content', 'min-content', 'none']
	} else {
		['auto', 'max-content', 'min-content']
	}
	if value := parse_property_keyword_value(mut transaction, allowed_keywords) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parse_keyword_from_set_for_value_logic(mut transaction, [
		'max-content',
		'min-content',
	]) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_fit_content_value(mut transaction) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor_size(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_inset_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_margin_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}

	transaction = tokens.clone()
	if value := parser.parse_anchor_size(mut transaction) {
		tokens = transaction
		return value
	}

	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_padding_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_border_spacing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	first_value := parser.parse_nonnegative_length_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_value
	}

	second_value := parser.parse_nonnegative_length_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create([first_value, second_value], .space, .yes))
}

fn (mut parser Parser) parse_border_image_repeat_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	first_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'stretch',
		'repeat',
		'round',
		'space',
	]) or { return none }
	first_value := StyleValue(KeywordStyleValue.create(first_keyword))

	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return first_value
	}

	second_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'stretch',
		'repeat',
		'round',
		'space',
	]) or { return none }
	second_value := StyleValue(KeywordStyleValue.create(second_keyword))

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create([first_value, second_value], .space, .yes))
}

fn repetition_from_keyword_for_value_logic(keyword Keyword) ?Repetition {
	return match keyword {
		.no_repeat { Repetition.no_repeat }
		.repeat { Repetition.repeat }
		.round { Repetition.round }
		.space { Repetition.space }
		else { none }
	}
}

fn (mut parser Parser) parse_single_repeat_style_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	_ = property_id
	mut transaction := tokens.clone()

	x_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'no-repeat',
		'repeat',
		'round',
		'space',
		'repeat-x',
		'repeat-y',
	]) or { return none }

	if x_keyword == .repeat_x {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(.repeat, .no_repeat))
	}
	if x_keyword == .repeat_y {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(.no_repeat, .repeat))
	}

	x_repeat := repetition_from_keyword_for_value_logic(x_keyword) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(x_repeat, x_repeat))
	}

	y_keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
		'no-repeat',
		'repeat',
		'round',
		'space',
	]) or {
		// The following token is not a second repeat keyword (e.g. it's the next
		// component of a `background`/`mask` layer). A single value applies to both
		// axes; leave the trailing tokens for the caller.
		tokens = transaction
		return StyleValue(RepeatStyleStyleValue.create(x_repeat, x_repeat))
	}
	y_repeat := repetition_from_keyword_for_value_logic(y_keyword) or { return none }

	tokens = transaction
	return StyleValue(RepeatStyleStyleValue.create(x_repeat, y_repeat))
}

fn (mut parser Parser) parse_repeat_style_list_value(property_id PropertyID, mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut repeat_styles := []StyleValue{}
	for value in values {
		mut repeat_tokens := ComponentValueStream.new(value)
		repeat_value := parser.parse_single_repeat_style_value(property_id, mut repeat_tokens) or {
			return none
		}
		repeat_tokens.consume_whitespace()
		if repeat_tokens.has_more_tokens() {
			return none
		}
		repeat_styles << repeat_value
	}

	if repeat_styles.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(repeat_styles, .comma, .yes))
}

fn (mut parser Parser) parse_mask_clip_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'content-box',
		'padding-box',
		'border-box',
		'fill-box',
		'stroke-box',
		'view-box',
		'no-clip',
	])
}

fn (mut parser Parser) parse_mask_composite_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'add',
		'subtract',
		'intersect',
		'exclude',
	])
}

fn (mut parser Parser) parse_mask_mode_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'alpha',
		'luminance',
		'match-source',
	])
}

fn (mut parser Parser) parse_mask_origin_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'content-box',
		'padding-box',
		'border-box',
		'fill-box',
		'stroke-box',
		'view-box',
	])
}

fn (mut parser Parser) parse_timeline_axis_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_simple_comma_separated_keyword_list_for_value_logic(mut tokens, [
		'block',
		'inline',
		'x',
		'y',
	])
}

fn (mut parser Parser) parse_position_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// always | [ anchors-valid || anchors-visible || no-overflow ]
	if always := parse_property_keyword_value(mut tokens, ['always']) {
		return always
	}

	mut transaction := tokens.clone()
	mut anchors_valid_value := ?StyleValue(none)
	mut anchors_visible_value := ?StyleValue(none)
	mut no_overflow_value := ?StyleValue(none)
	mut has_anchors_valid := false
	mut has_anchors_visible := false
	mut has_no_overflow := false

	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		keyword := parse_single_keyword_from_set_for_value_logic(mut transaction, [
			'anchors-valid',
			'anchors-visible',
			'no-overflow',
		]) or { return none }

		match keyword {
			.anchors_valid {
				if has_anchors_valid {
					return none
				}
				anchors_valid_value = StyleValue(KeywordStyleValue.create(keyword))
				has_anchors_valid = true
			}
			.anchors_visible {
				if has_anchors_visible {
					return none
				}
				anchors_visible_value = StyleValue(KeywordStyleValue.create(keyword))
				has_anchors_visible = true
			}
			.no_overflow {
				if has_no_overflow {
					return none
				}
				no_overflow_value = StyleValue(KeywordStyleValue.create(keyword))
				has_no_overflow = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	mut values := []StyleValue{}
	if value := anchors_valid_value {
		values << value
	}
	if value := anchors_visible_value {
		values << value
	}
	if value := no_overflow_value {
		values << value
	}
	if values.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(values, .space, .yes))
}

fn parse_touch_action_single_keyword_for_value_logic(mut tokens ComponentValueStream) ?Keyword {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	ident := to_ascii_lowercase(component_value.token().ident())
	if ident !in ['pan-x', 'pan-left', 'pan-right', 'pan-y', 'pan-up', 'pan-down'] {
		return none
	}
	keyword := keyword_from_string(ident) or { return none }
	tokens = transaction
	return keyword
}

fn (mut parser Parser) parse_touch_action_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://www.w3.org/TR/pointerevents/#the-touch-action-css-property
	// auto | none | [ [ pan-x | pan-left | pan-right ] || [ pan-y | pan-up | pan-down ] ] | manipulation
	if value := parse_property_keyword_value(mut tokens, ['auto', 'none', 'manipulation']) {
		return value
	}

	mut transaction := tokens.clone()
	mut parsed_values := []StyleValue{}
	mut has_horizontal := false
	mut has_vertical := false
	mut swap_order := false

	for {
		keyword := parse_touch_action_single_keyword_for_value_logic(mut transaction) or { break }
		match keyword {
			.pan_x, .pan_left, .pan_right {
				if has_horizontal {
					return none
				}
				if has_vertical {
					swap_order = true
				}
				has_horizontal = true
			}
			.pan_y, .pan_up, .pan_down {
				if has_vertical {
					return none
				}
				has_vertical = true
			}
			else {
				return none
			}
		}

		parsed_values << StyleValue(KeywordStyleValue.create(keyword))
		transaction.consume_whitespace()
		if !transaction.has_more_tokens() {
			break
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() || parsed_values.len == 0 {
		return none
	}
	if swap_order && parsed_values.len == 2 {
		first := parsed_values[0]
		parsed_values[0] = parsed_values[1]
		parsed_values[1] = first
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(parsed_values, .space, .yes))
}

// https://drafts.csswg.org/css-borders-4/#typedef-corner-shape-value
fn (mut parser Parser) parse_corner_shape_value(mut tokens ComponentValueStream) ?StyleValue {
	// <corner-shape-value> = round | scoop | bevel | notch | square | squircle | <superellipse()>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.ident) {
		ident := to_ascii_lowercase(component_value.token().ident())
		keyword := keyword_from_string(ident) or { return none }
		if keyword !in [.round, .scoop, .bevel, .notch, .square, .squircle] {
			return none
		}
		tokens = transaction
		return StyleValue(KeywordStyleValue.create(keyword))
	}

	if component_value.is_function_named('superellipse') {
		// superellipse() = superellipse(<number> | infinity | -infinity)
		mut function_tokens := ComponentValueStream.new(component_value.function().value)
		function_tokens.consume_whitespace()
		if token := function_tokens.consume() {
			if token.is(.ident) {
				ident := to_ascii_lowercase(token.token().ident())
				function_tokens.consume_whitespace()
				if function_tokens.has_more_tokens() {
					return none
				}
				keyword := keyword_from_string(ident) or { return none }
				if keyword == .negative_infinity {
					tokens = transaction
					return StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(math.inf(-1)))))
				}
				if keyword == .infinity {
					tokens = transaction
					return StyleValue(SuperellipseStyleValue.create(StyleValue(NumberStyleValue.create(math.inf(1)))))
				}
				return none
			}
			function_tokens.reconsume()
			number_value := parser.parse_number_value(mut function_tokens) or { return none }
			function_tokens.consume_whitespace()
			if function_tokens.has_more_tokens() {
				return none
			}
			tokens = transaction
			return StyleValue(SuperellipseStyleValue.create(number_value))
		}
	}

	return none
}

fn font_style_keyword_from_string(value string) ?FontStyleKeyword {
	return match to_ascii_lowercase(value) {
		'normal' { FontStyleKeyword.normal }
		'italic' { FontStyleKeyword.italic }
		'left' { FontStyleKeyword.left }
		'right' { FontStyleKeyword.right }
		'oblique' { FontStyleKeyword.oblique }
		else { none }
	}
}

fn (mut parser Parser) parse_font_kerning_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'normal', 'none'])
}

fn (mut parser Parser) parse_webkit_font_smoothing_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'none', 'antialiased',
		'subpixel-antialiased'])
}

fn (mut parser Parser) parse_font_language_override_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['normal']) {
		tokens = transaction
		return value
	}
	if value := parser.parse_string_value(mut tokens) {
		return StyleValue(value)
	}
	return none
}

fn (mut parser Parser) parse_font_optical_sizing_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['auto', 'none'])
}

fn (mut parser Parser) parse_font_variant_caps_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'small-caps', 'all-small-caps',
		'petite-caps', 'all-petite-caps', 'unicase', 'titling-caps'])
}

fn (mut parser Parser) parse_font_variant_emoji_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'text', 'emoji', 'unicode'])
}

fn (mut parser Parser) parse_font_variant_position_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'sub', 'super'])
}

fn (mut parser Parser) parse_font_style_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-fonts/#font-style-prop
	// normal | italic | left | right | oblique <angle [-90deg,90deg]>?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	font_style := font_style_keyword_from_string(component_value.token().ident()) or { return none }
	transaction.consume_whitespace()
	if transaction.has_more_tokens() && font_style == .oblique {
		// The angle is optional: in the font shorthand the font size can
		// follow oblique directly.
		mut angle_transaction := transaction.clone()
		parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.font_style_angle))
		maybe_angle_value := parser.parse_angle_value(mut angle_transaction)
		parser.pop_temporary_value_parsing_context()
		if angle_value := maybe_angle_value {
			if angle_value is AngleStyleValue {
				angle_degrees := angle_value.angle().to_degrees()
				if angle_degrees < -90 || angle_degrees > 90 {
					return none
				}
			}
			tokens = angle_transaction
			return StyleValue(FontStyleStyleValue.create(font_style, angle_value))
		}
	}
	tokens = transaction
	return StyleValue(FontStyleStyleValue.create(font_style, none))
}

fn (mut parser Parser) parse_font_weight_value(mut tokens ComponentValueStream) ?StyleValue {
	mut keyword_transaction := tokens.clone()
	keyword_transaction.consume_whitespace()
	if component_value := keyword_transaction.consume() {
		if component_value.is(.ident) {
			ident := to_ascii_lowercase(component_value.token().ident())
			keyword := keyword_from_string(ident) or { return none }
			if keyword in [.normal, .bold, .bolder, .lighter] {
				tokens = keyword_transaction
				return StyleValue(KeywordStyleValue.create(keyword))
			}
		}
	}

	mut number_transaction := tokens.clone()
	if value := parser.parse_number_value(mut number_transaction) {
		if value is NumberStyleValue {
			number := value.number()
			if number < 1 || number > 1000 {
				return none
			}
		}
		tokens = number_transaction
		return value
	}

	mut numeric_transaction := tokens.clone()
	remaining_text := serialize_a_series_of_component_values(numeric_transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		if value is NumberStyleValue {
			number := value.number()
			if number < 1 || number > 1000 {
				return none
			}
			tokens = numeric_transaction
			return value
		}
	}
	return none
}

fn (mut parser Parser) parse_font_width_value(mut tokens ComponentValueStream) ?StyleValue {
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		tokens = percentage_transaction
		return value
	}
	mut transaction := tokens.clone()
	remaining_text := serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		if value is PercentageStyleValue {
			tokens = transaction
			return value
		}
	}
	return parse_property_keyword_value(mut tokens, [
		'ultra-condensed',
		'extra-condensed',
		'condensed',
		'semi-condensed',
		'normal',
		'semi-expanded',
		'expanded',
		'extra-expanded',
		'ultra-expanded',
	])
}

fn (mut parser Parser) parse_line_height_value(mut tokens ComponentValueStream) ?StyleValue {
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		// The font shorthand continues with the font family after the
		// line height, so the keyword need not end the stream.
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			tokens = normal_transaction
			return StyleValue(KeywordStyleValue.create(.normal))
		}
	}

	// Parser::parse_value_for_property() tries <integer>/<number> before
	// <length> "so that 0 is not interpreted as a <length> in case both are
	// allowed", and rejects any component outside the property's declared range.
	mut number_transaction := tokens.clone()
	if value := parser.parse_number_value(mut number_transaction) {
		if property_accepts_parsed_numeric_value(.line_height, .number, value) {
			tokens = number_transaction
			return value
		}
	}
	mut length_transaction := tokens.clone()
	if value := parser.parse_length_value(mut length_transaction) {
		if property_accepts_parsed_numeric_value(.line_height, .length, value) {
			tokens = length_transaction
			return value
		}
	}
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		if property_accepts_parsed_numeric_value(.line_height, .percentage, value) {
			tokens = percentage_transaction
			return value
		}
	}

	mut transaction := tokens.clone()
	remaining_text := serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		match value {
			NumberStyleValue {
				if property_accepts_parsed_numeric_value(.line_height, .number, value) {
					tokens = transaction
					return value
				}
			}
			LengthStyleValue {
				if property_accepts_parsed_numeric_value(.line_height, .length, value) {
					tokens = transaction
					return value
				}
			}
			PercentageStyleValue {
				if property_accepts_parsed_numeric_value(.line_height, .percentage, value) {
					tokens = transaction
					return value
				}
			}
			else {}
		}
	}
	return none
}

fn (mut parser Parser) parse_letter_or_word_spacing_value(mut tokens ComponentValueStream) ?StyleValue {
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut length_transaction := tokens.clone()
	if value := parser.parse_length_value(mut length_transaction) {
		tokens = length_transaction
		return value
	}
	mut percentage_transaction := tokens.clone()
	if value := parser.parse_percentage_value(mut percentage_transaction) {
		tokens = percentage_transaction
		return value
	}

	mut transaction := tokens.clone()
	remaining_text := serialize_a_series_of_component_values(transaction.consume_remaining_component_values())
	if value := numeric_style_value_from_css_text_for_value_logic(remaining_text) {
		match value {
			LengthStyleValue, PercentageStyleValue {
				tokens = transaction
				return value
			}
			else {}
		}
	}
	return none
}

fn (mut parser Parser) parse_math_depth_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://w3c.github.io/mathml-core/#propdef-math-depth
	// auto-add | add(<integer>) | <integer>
	mut keyword_transaction := tokens.clone()
	keyword_transaction.consume_whitespace()
	if component_value := keyword_transaction.consume() {
		if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'auto-add') {
			keyword_transaction.consume_whitespace()
			if !keyword_transaction.has_more_tokens() {
				tokens = keyword_transaction
				return StyleValue(KeywordStyleValue.create(.auto_add))
			}
		}
	}

	mut add_transaction := tokens.clone()
	add_transaction.consume_whitespace()
	if component_value := add_transaction.consume() {
		if component_value.is_function_named('add') {
			mut add_tokens := ComponentValueStream.new(component_value.function().value)
			add_tokens.consume_whitespace()
			integer_value := parser.parse_integer_value(mut add_tokens) or { return none }
			add_tokens.consume_whitespace()
			if add_tokens.has_more_tokens() {
				return none
			}
			add_transaction.consume_whitespace()
			if add_transaction.has_more_tokens() {
				return none
			}
			tokens = add_transaction
			return StyleValue(FunctionStyleValue.create('add', integer_value))
		}
	}

	mut integer_transaction := tokens.clone()
	if integer_value := parser.parse_integer_value(mut integer_transaction) {
		tokens = integer_transaction
		return integer_value
	}
	return none
}

fn (mut parser Parser) parse_math_style_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := match to_ascii_lowercase(component_value.token().ident()) {
		'normal' { Keyword.normal }
		'compact' { Keyword.compact }
		else {
			return none
		}
	}

	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_math_shift_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_property_keyword_value(mut tokens, ['normal', 'compact'])
}

fn (mut parser Parser) parse_font_feature_settings_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-fonts/#propdef-font-feature-settings
	// normal | <feature-tag-value>#
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	tag_values := parse_a_comma_separated_list_of_component_values_for_value_logic(component_values)
	mut feature_tags := []StyleValue{}
	for values in tag_values {
		feature_tags << StyleValue(computed_interpolation_parse_font_feature_settings_entry(values) or {
			return none
		})
	}
	if feature_tags.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(feature_tags, .comma, .yes))
}

fn (mut parser Parser) parse_font_variation_settings_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	// https://drafts.csswg.org/css-fonts/#propdef-font-variation-settings
	// normal | [ <opentype-tag> <number> ]#
	mut normal_transaction := tokens.clone()
	normal_transaction.consume_whitespace()
	if token := normal_transaction.consume() {
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			normal_transaction.consume_whitespace()
			if !normal_transaction.has_more_tokens() {
				tokens = normal_transaction
				return StyleValue(KeywordStyleValue.create(.normal))
			}
		}
	}

	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	tag_values := parse_a_comma_separated_list_of_component_values_for_value_logic(component_values)
	mut axis_tags := []StyleValue{}
	for values in tag_values {
		axis_tags << StyleValue(computed_interpolation_parse_font_variation_settings_entry(values) or {
			return none
		})
	}
	if axis_tags.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(axis_tags, .comma, .yes))
}

fn (mut parser Parser) parse_single_animation_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	// animation-timeline = auto | none | <dashed-ident> | scroll() | view()
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is(.ident) {
		ident := component_value.token().ident()
		if equals_ignoring_ascii_case(ident, 'auto') {
			return StyleValue(KeywordStyleValue.create(.auto))
		}
		if equals_ignoring_ascii_case(ident, 'none') {
			return StyleValue(KeywordStyleValue.create(.none_))
		}
		if ident.starts_with('--') {
			return StyleValue(CustomIdentStyleValue.create(ident))
		}
		return none
	}
	if scroll_function := parser.parse_scroll_function_value(component_value) {
		return StyleValue(scroll_function)
	}
	if view_function := parser.parse_view_function_value(component_value) {
		return StyleValue(view_function)
	}
	return none
}

fn (mut parser Parser) parse_animation_timeline_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	mut timelines := []StyleValue{}
	for values in parse_a_comma_separated_list_of_component_values_for_value_logic(component_values) {
		mut value_tokens := ComponentValueStream.new(values)
		value := parser.parse_single_animation_timeline_value(mut value_tokens) or { return none }
		value_tokens.consume_whitespace()
		if value_tokens.has_more_tokens() {
			return none
		}
		timelines << value
	}
	if timelines.len == 0 {
		return none
	}
	tokens = transaction
	return StyleValue(StyleValueList.create(timelines, .comma, .yes))
}

fn axis_from_identifier_for_value_logic(value string) ?Axis {
	return match to_ascii_lowercase(value) {
		'block' { Axis.block }
		'inline' { Axis.inline_ }
		'x' { Axis.x }
		'y' { Axis.y }
		else { none }
	}
}

fn scroller_from_identifier_for_value_logic(value string) ?Scroller {
	return match to_ascii_lowercase(value) {
		'root' { Scroller.root }
		'nearest' { Scroller.nearest }
		'self' { Scroller.self_ }
		else { none }
	}
}

fn (mut parser Parser) parse_scroll_function_value(component_value ComponentValue) ?FunctionStyleValue {
	// <scroll()> = scroll( [ <scroller> || <axis> ]? )
	if !component_value.is_function_named('scroll') {
		return none
	}
	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut call_arguments := [?StyleValue(none), ?StyleValue(none)]
	mut has_scroller := false
	mut has_axis := false
	for argument_tokens.has_more_tokens() {
		argument_tokens.consume_whitespace()
		token := argument_tokens.consume() or { break }
		if !token.is(.ident) {
			return none
		}
		ident := token.token().ident()
		if maybe_scroller := scroller_from_identifier_for_value_logic(ident) {
			if has_scroller {
				return none
			}
			if maybe_scroller != .nearest {
				keyword := keyword_from_string(to_ascii_lowercase(ident)) or { return none }
				call_arguments[tuple_scroll_function_scroller_index] = StyleValue(KeywordStyleValue.create(keyword))
			}
			has_scroller = true
			continue
		}
		if maybe_axis := axis_from_identifier_for_value_logic(ident) {
			if has_axis {
				return none
			}
			if maybe_axis != .block {
				keyword := keyword_from_string(to_ascii_lowercase(ident)) or { return none }
				call_arguments[tuple_scroll_function_axis_index] = StyleValue(KeywordStyleValue.create(keyword))
			}
			has_axis = true
			continue
		}
		return none
	}

	return FunctionStyleValue.create('scroll', StyleValue(TupleStyleValue.create(call_arguments)))
}

fn (mut parser Parser) parse_view_timeline_inset_value(mut tokens ComponentValueStream) ?StyleValue {
	// [ [ auto | <length-percentage> ]{1,2} ]
	mut transaction := tokens.clone()
	mut inset_values := []StyleValue{}
	for transaction.has_more_tokens() && inset_values.len < 2 {
		transaction.consume_whitespace()
		if token := transaction.peek() {
			if token.is_ident('auto') {
				transaction.consume()
				inset_values << StyleValue(KeywordStyleValue.create(.auto))
				continue
			}
		}
		if length_percentage := parser.parse_length_percentage_value(mut transaction) {
			inset_values << length_percentage
			continue
		}
		break
	}
	if inset_values.len == 0 {
		return none
	}
	tokens = transaction
	if inset_values.len == 1 {
		inset_values << inset_values[0]
	}
	return StyleValue(StyleValueList.create(inset_values, .space, .yes))
}

fn (mut parser Parser) parse_view_function_value(component_value ComponentValue) ?FunctionStyleValue {
	// <view()> = view( [ <axis> || <'view-timeline-inset'> ]? )
	if !component_value.is_function_named('view') {
		return none
	}
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: 'view'
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	mut argument_tokens := ComponentValueStream.new(component_value.function().value)
	mut call_arguments := [?StyleValue(none), ?StyleValue(none)]
	mut has_axis := false
	mut has_inset := false
	for argument_tokens.has_more_tokens() {
		if inset_value := parser.parse_view_timeline_inset_value(mut argument_tokens) {
			if has_inset {
				return none
			}
			inset_values := (inset_value as StyleValueList).values()
			if inset_values[0].to_keyword() != .auto || inset_values[1].to_keyword() != .auto {
				call_arguments[tuple_view_function_inset_index] = inset_value
			}
			has_inset = true
			continue
		}

		argument_tokens.consume_whitespace()
		token := argument_tokens.consume() or { break }
		if !token.is(.ident) {
			return none
		}
		maybe_axis := axis_from_identifier_for_value_logic(token.token().ident()) or { return none }
		if has_axis {
			return none
		}
		if maybe_axis != .block {
			keyword := keyword_from_string(to_ascii_lowercase(token.token().ident())) or { return none }
			call_arguments[tuple_view_function_axis_index] = StyleValue(KeywordStyleValue.create(keyword))
		}
		has_axis = true
	}

	return FunctionStyleValue.create('view', StyleValue(TupleStyleValue.create(call_arguments)))
}

fn (mut parser Parser) parse_keyword_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if !component_value.is(.ident) {
		return none
	}
	keyword := keyword_from_string(component_value.token().ident()) or { return none }
	tokens.consume()
	return StyleValue(KeywordStyleValue.create(keyword))
}

fn (mut parser Parser) parse_auto_or_color_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if keyword := parser.parse_keyword_value(mut transaction) {
		if keyword.to_keyword() == .auto {
			tokens = transaction
			return keyword
		}
	}

	return parser.parse_color_value(mut tokens)
}

fn (mut parser Parser) parse_content_visibility_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_keyword_value(mut transaction) or { return none }
	if value is KeywordStyleValue {
		if value.keyword() in [.visible, .auto, .hidden] {
			tokens = transaction
			return value
		}
	}
	return none
}

// https://drafts.csswg.org/css-sizing-4/#intrinsic-size-override
// auto? [ none | <length [0,∞]> ]
fn (mut parser Parser) parse_contain_intrinsic_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	mut has_auto := false
	if component := transaction.peek() {
		if component.is_ident('auto') {
			transaction.consume()
			has_auto = true
		}
	}
	transaction.consume_whitespace()
	mut size := ?StyleValue(none)
	if component := transaction.peek() {
		if component.is_ident('none') {
			transaction.consume()
			size = StyleValue(KeywordStyleValue.create(.none_))
		}
	}
	if size == none {
		mut length_transaction := transaction.clone()
		length := parser.parse_length_value(mut length_transaction) or { return none }
		if length is LengthStyleValue && length.raw_value() < 0 {
			return none
		}
		if length is CalculatedStyleValue {
			if raw_length := length.resolve_raw_length(CalculationResolutionContext{}) {
				if raw_length < 0 || math.is_inf(raw_length, 0) {
					return none
				}
			}
		}
		transaction = length_transaction
		size = length
	}
	parsed_size := size or { return none }
	tokens = transaction
	if !has_auto {
		return parsed_size
	}
	return StyleValue(StyleValueList.create([
		StyleValue(KeywordStyleValue.create(.auto)),
		parsed_size,
	], .space, .no))
}

// https://drafts.csswg.org/css-sizing-4/#propdef-contain-intrinsic-size
// A component can consume two tokens (`auto 10px`), so this cannot use the
// generic positional shorthand splitter.
fn (mut parser Parser) parse_contain_intrinsic_size_shorthand(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	first := parser.parse_contain_intrinsic_size_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	mut second := first
	if transaction.has_more_tokens() {
		second = parser.parse_contain_intrinsic_size_value(mut transaction) or { return none }
	}
	transaction.consume_whitespace()
	if transaction.has_more_tokens() {
		return none
	}
	tokens = transaction
	return StyleValue(ShorthandStyleValue.create(.contain_intrinsic_size, [
		PropertyID.contain_intrinsic_width,
		PropertyID.contain_intrinsic_height,
	], [first, second]))
}

fn (mut parser Parser) parse_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.number) && component_value.token().number().is_integer() {
		tokens.consume()
		return StyleValue(IntegerStyleValue.create(component_value.token().number().integer_value()))
	}

	if value := parser.parse_calculated_value_of_kind(mut tokens, .integer) {
		return value
	}

	if value := parser.parse_tree_counting_function(mut tokens, .integer) {
		return StyleValue(value)
	}

	return none
}

fn (mut parser Parser) parse_number_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.number) {
		tokens.consume()
		return StyleValue(NumberStyleValue.create(component_value.token().number_value()))
	}

	if value := parser.parse_calculated_value_of_kind(mut tokens, .number) {
		return value
	}

	if value := parser.parse_tree_counting_function(mut tokens, .number) {
		return StyleValue(value)
	}

	return none
}

fn (mut parser Parser) parse_number(mut tokens ComponentValueStream) ?Number {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.number) {
		return none
	}
	tokens = transaction
	return component_value.token().number()
}

fn (mut parser Parser) parse_easing_number_value(mut tokens ComponentValueStream) ?StyleValue {
	return parser.parse_number_value(mut tokens)
}

fn (mut parser Parser) parse_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.percentage) {
		tokens.consume()
		return StyleValue(PercentageStyleValue.create(Percentage.new(component_value.token().percentage())))
	}

	return parser.parse_calculated_value_of_kind(mut tokens, .percentage)
}

fn (mut parser Parser) parse_percentage(mut tokens ComponentValueStream) ?Percentage {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.percentage) {
		return none
	}
	tokens = transaction
	return Percentage.new(component_value.token().percentage())
}

fn (mut parser Parser) parse_number_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut working_copy := tokens.clone()
	if value := parser.parse_number_value(mut working_copy) {
		tokens = working_copy
		return value
	}
	working_copy = tokens.clone()
	if value := parser.parse_percentage_value(mut working_copy) {
		tokens = working_copy
		return value
	}
	return none
}

fn style_value_numeric_component_is_negative_for_value_logic(value StyleValue) bool {
	return match value {
		LengthStyleValue { value.length().raw_value() < 0 }
		NumberStyleValue { value.number() < 0 }
		PercentageStyleValue { value.percentage().value() < 0 }
		else { false }
	}
}

fn (mut parser Parser) parse_nonnegative_number_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_number_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_positive_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_integer_value(mut tokens) or { return none }
	if value is IntegerStyleValue {
		if value.integer() < 1 {
			return none
		}
	}
	return value
}

fn (mut parser Parser) parse_auto_or_positive_integer_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_positive_integer_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_length_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_length_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_auto_or_nonnegative_length_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_length_percentage_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_auto_or_nonnegative_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_auto_or_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto']) {
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_nonnegative_number_or_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parser.parse_number_value(mut transaction) {
		if style_value_numeric_component_is_negative_for_value_logic(value) {
			return none
		}
		tokens = transaction
		return value
	}
	value := parser.parse_length_percentage_value(mut tokens) or { return none }
	if style_value_numeric_component_is_negative_for_value_logic(value) {
		return none
	}
	return value
}

fn (mut parser Parser) parse_gap_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['normal']) {
		tokens = transaction
		return value
	}
	return parser.parse_nonnegative_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_text_decoration_thickness_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	if value := parse_property_keyword_value(mut transaction, ['auto', 'from-font']) {
		tokens = transaction
		return value
	}
	return parser.parse_length_percentage_value(mut tokens)
}

fn (mut parser Parser) parse_text_indent_value(mut tokens ComponentValueStream) ?StyleValue {
	// https://drafts.csswg.org/css-text-3/#text-indent-property
	// [ <length-percentage> ] && hanging? && each-line?
	mut transaction := tokens.clone()
	mut length_percentage := ?StyleValue(none)
	mut has_hanging := false
	mut has_each_line := false

	transaction.consume_whitespace()
	for transaction.has_more_tokens() {
		if length_percentage == none {
			mut length_transaction := transaction.clone()
			if parsed := parser.parse_length_percentage_value(mut length_transaction) {
				length_percentage = parsed
				transaction = length_transaction
				transaction.consume_whitespace()
				continue
			}
		}

		component_value := transaction.consume() or { break }
		if !component_value.is(.ident) {
			return none
		}
		ident := to_ascii_lowercase(component_value.token().ident())
		match ident {
			'hanging' {
				if has_hanging {
					return none
				}
				has_hanging = true
			}
			'each-line' {
				if has_each_line {
					return none
				}
				has_each_line = true
			}
			else {
				return none
			}
		}

		transaction.consume_whitespace()
	}

	length_value := length_percentage or { return none }
	tokens = transaction
	return StyleValue(TextIndentStyleValue.create(length_value, if has_hanging {
		TextIndentHanging.yes
	} else {
		TextIndentHanging.no
	}, if has_each_line { TextIndentEachLine.yes } else { TextIndentEachLine.no }))
}

// https://drafts.csswg.org/css-color-4/#typedef-opacity-opacity-value
fn (mut parser Parser) parse_opacity_value(mut tokens ComponentValueStream) ?StyleValue {
	value := parser.parse_number_percentage_value(mut tokens) or { return none }

	// Percentages map to the range [0,1] for opacity values
	if value is PercentageStyleValue {
		return StyleValue(NumberStyleValue.create(value.percentage().as_fraction()))
	}

	return value
}

fn (mut parser Parser) parse_number_percentage_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<percentage> | <number> | none] (which is equivalent to [<alpha-value> | none])
	if channel := parser.parse_relative_color_channel_keyword(mut tokens) {
		return channel
	}
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
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_angle_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(AngleStyleValue.create(Angle.new(dimension.token().dimension_value(), unit)))
	}

	// SVG presentation attributes accept a unitless number as degrees.
	if component_value.is(.number) && parser.is_parsing_svg_presentation_attribute() {
		tokens.consume()
		return StyleValue(AngleStyleValue.create(Angle.make_degrees(component_value.token().number_value())))
	}

	return parser.parse_calculated_value_of_kind(mut tokens, .angle)
}

fn (mut parser Parser) parse_angle_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_angle_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(AngleStyleValue.create(Angle.new(dimension.token().dimension_value(), unit)))
	}
	if component_value.is(.percentage) {
		tokens.consume()
		return StyleValue(PercentageStyleValue.create(Percentage.new(component_value.token().percentage())))
	}
	if component_value.is(.number) && parser.is_parsing_svg_presentation_attribute() {
		tokens.consume()
		return StyleValue(AngleStyleValue.create(Angle.make_degrees(component_value.token().number_value())))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .angle_percentage)
}

fn (mut parser Parser) parse_angle(mut tokens ComponentValueStream) ?Angle {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.number) && parser.is_parsing_svg_presentation_attribute() {
		tokens = transaction
		return Angle.make_degrees(component_value.token().number_value())
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_angle_unit(component_value.token().dimension_unit()) or { return none }
	tokens = transaction
	return Angle.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_length_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_length_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(LengthStyleValue.create(Length.new(dimension.token().dimension_value(), unit)))
	}
	if component_value.is(.number) {
		mut transaction := tokens.clone()
		number := transaction.consume() or { return none }
		numeric_value := number.token().number_value()
		if numeric_value == 0 || parser.context_allows_quirky_length()
			|| parser.is_parsing_svg_presentation_attribute() {
			tokens = transaction
			return StyleValue(LengthStyleValue.create(Length.make_px(numeric_value)))
		}
	}
	if component_value.is_function_named('anchor-size') {
		return parser.parse_anchor_size(mut tokens)
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .length)
}

fn (mut parser Parser) parse_length(mut tokens ComponentValueStream) ?Length {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if component_value.is(.number) {
		numeric_value := component_value.token().number_value()
		if numeric_value == 0 || parser.context_allows_quirky_length()
			|| parser.is_parsing_svg_presentation_attribute() {
			tokens = transaction
			return Length.make_px(numeric_value)
		}
	}
	if !component_value.is(.dimension) {
		return none
	}
	unit := string_to_length_unit(component_value.token().dimension_unit()) or { return none }
	tokens = transaction
	return Length.new(component_value.token().dimension_value(), unit)
}

fn (mut parser Parser) parse_source_size_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident)
			&& equals_ignoring_ascii_case(component_value.token().ident(), 'auto') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.auto))
		}
	}

	transaction = tokens.clone()
	if length := parser.parse_length_value(mut transaction) {
		if length is LengthStyleValue && length.raw_value() < 0 {
			return none
		}
		if length is CalculatedStyleValue {
			if raw_length := length.resolve_raw_length(CalculationResolutionContext{}) {
				if math.is_inf(raw_length, 0) {
					return none
				}
			}
		}
		tokens = transaction
		return length
	}
	return none
}

fn unicode_range_ending_component_value(component_value ?ComponentValue) bool {
	value := component_value or { return true }
	return value.is(.comma) || value.is(.semicolon) || value.is(.whitespace)
}

// https://www.w3.org/TR/css-syntax-3/#urange-syntax
fn (mut parser Parser) parse_unicode_range(mut tokens ComponentValueStream) ?UnicodeRange {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	// <urange> =
	//  u '+' <ident-token> '?'* |
	//  u <dimension-token> '?'* |
	//  u <number-token> '?'* |
	//  u <number-token> <dimension-token> |
	//  u <number-token> <number-token> |
	//  u '+' '?'+
	u := transaction.consume() or { return none }
	if !u.is_ident('u') {
		return none
	}

	second_token := transaction.consume() or { return none }

	// u '+' <ident-token> '?'* | u '+' '?'+
	if second_token.is_delim(u32(`+`)) {
		mut text := second_token.token().original_source_text()
		third_token := transaction.consume() or { return none }
		if third_token.is(.ident) || third_token.is_delim(u32(`?`)) {
			text += third_token.token().original_source_text()
			for {
				next := transaction.peek() or { break }
				if !next.is_delim(u32(`?`)) {
					break
				}
				text += transaction.consume()?.token().original_source_text()
			}
			if unicode_range_ending_component_value(transaction.peek()) {
				unicode_range := parse_unicode_range('U${text}') or { return none }
				tokens = transaction
				return unicode_range
			}
		}
		return none
	}

	// u <dimension-token> '?'*
	if second_token.is(.dimension) {
		mut text := second_token.token().original_source_text()
		for {
			next := transaction.peek() or { break }
			if !next.is_delim(u32(`?`)) {
				break
			}
			text += transaction.consume()?.token().original_source_text()
		}
		if unicode_range_ending_component_value(transaction.peek()) {
			unicode_range := parse_unicode_range('U${text}') or { return none }
			tokens = transaction
			return unicode_range
		}
		return none
	}

	// u <number-token> '?'* | u <number-token> <dimension-token> |
	// u <number-token> <number-token>
	if second_token.is(.number) {
		mut text := second_token.token().original_source_text()
		if unicode_range_ending_component_value(transaction.peek()) {
			unicode_range := parse_unicode_range('U${text}') or { return none }
			tokens = transaction
			return unicode_range
		}

		third_token := transaction.consume() or { return none }
		if third_token.is_delim(u32(`?`)) {
			text += third_token.token().original_source_text()
			for {
				next := transaction.peek() or { break }
				if !next.is_delim(u32(`?`)) {
					break
				}
				text += transaction.consume()?.token().original_source_text()
			}
		} else if third_token.is(.dimension) || third_token.is(.number) {
			text += third_token.token().original_source_text()
		} else {
			return none
		}
		if unicode_range_ending_component_value(transaction.peek()) {
			unicode_range := parse_unicode_range('U${text}') or { return none }
			tokens = transaction
			return unicode_range
		}
	}

	return none
}

fn (mut parser Parser) parse_unicode_ranges(mut tokens ComponentValueStream) []UnicodeRange {
	mut unicode_ranges := []UnicodeRange{}
	range_token_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(tokens.consume_remaining_component_values())
	for range_tokens in range_token_lists {
		mut range_token_stream := ComponentValueStream.new(range_tokens)
		unicode_range := parser.parse_unicode_range(mut range_token_stream) or {
			return []UnicodeRange{}
		}
		range_token_stream.consume_whitespace()
		if range_token_stream.has_more_tokens() {
			return []UnicodeRange{}
		}
		unicode_ranges << unicode_range
	}
	return unicode_ranges
}

fn (mut parser Parser) parse_unicode_range_value(mut tokens ComponentValueStream) ?StyleValue {
	unicode_range := parser.parse_unicode_range(mut tokens) or { return none }
	return StyleValue(UnicodeRangeStyleValue.create(unicode_range))
}

// https://html.spec.whatwg.org/multipage/images.html#parsing-a-sizes-attribute
fn (mut parser Parser) parse_as_sizes_attribute(element &dom.Element, rendered_auto_width ?f64) StyleValue {
	mut unparsed_sizes_list := parse_a_comma_separated_list_of_component_values_for_value_logic(parser.component_values)
	for index := 0; index < unparsed_sizes_list.len; index++ {
		mut unparsed_size := unparsed_sizes_list[index].clone()
		for unparsed_size.len > 0 && unparsed_size.last().is(.whitespace) {
			unparsed_size.pop()
		}
		if unparsed_size.len == 0 {
			continue
		}

		mut last_value_stream := ComponentValueStream.new([unparsed_size.last()])
		mut size := parser.parse_source_size_value(mut last_value_stream) or { continue }
		unparsed_size.pop()

		if size.has_auto() {
			if auto_width := rendered_auto_width {
				size = StyleValue(LengthStyleValue.create(Length.make_px(auto_width)))
			}
		}

		for unparsed_size.len > 0 && unparsed_size.last().is(.whitespace) {
			unparsed_size.pop()
		}
		if unparsed_size.len == 0 {
			if !size.has_auto() {
				return size
			}
			continue
		}

		mut condition_tokens := ComponentValueStream.new(unparsed_size)
		condition := parser.parse_media_condition(mut condition_tokens) or { continue }
		condition_tokens.consume_whitespace()
		if condition_tokens.has_more_tokens() || !condition.evaluate_to_boolean(BooleanExpressionEvaluationContext{
			document: element.document()
		}) {
			continue
		}
		if !size.has_auto() {
			return size
		}
	}

	return StyleValue(LengthStyleValue.create(Length.new(100, .vw)))
}

pub fn parse_sizes_attribute_style_value(element &dom.Element, sizes string, rendered_auto_width ?f64) StyleValue {
	mut parser := Parser.with_context(ParsingParams{
		document: element.document()
	}, sizes)
	return parser.parse_as_sizes_attribute(element, rendered_auto_width)
}

// Resolve the translated sizes-attribute result to the numeric CSS-pixel source
// size consumed by HTML::SourceSet.
pub fn parse_sizes_attribute_source_size(element &dom.Element, sizes string, rendered_auto_width ?f64) f64 {
	value := parse_sizes_attribute_style_value(element, sizes, rendered_auto_width)
	return resolve_sizes_attribute_style_value(element, value)
}

pub fn resolve_sizes_attribute_style_value(element &dom.Element, value StyleValue) f64 {
	resolution_context := length_resolution_context_from_document(element.document())
	absolutized := value.absolutized(ComputationContext{
		length_resolution_context: resolution_context
	})
	return Length.from_style_value_logic(absolutized, none).absolute_length_to_px_without_rounding()
}

fn (mut parser Parser) parse_length_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_length_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(LengthStyleValue.create(Length.new(dimension.token().dimension_value(), unit)))
	}
	if component_value.is(.percentage) {
		tokens.consume()
		return StyleValue(PercentageStyleValue.create(Percentage.new(component_value.token().percentage())))
	}
	if component_value.is(.number) {
		mut transaction := tokens.clone()
		number := transaction.consume() or { return none }
		numeric_value := number.token().number_value()
		if numeric_value == 0 || parser.context_allows_quirky_length()
			|| parser.is_parsing_svg_presentation_attribute() {
			tokens = transaction
			return StyleValue(LengthStyleValue.create(Length.make_px(numeric_value)))
		}
	}
	if component_value.is_function_named('anchor-size') {
		return parser.parse_anchor_size(mut tokens)
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .length_percentage)
}

fn (mut parser Parser) parse_flex_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_flex_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(FlexStyleValue.create(Flex.new(dimension.token().dimension_value(), unit)))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .flex)
}

fn (mut parser Parser) parse_frequency_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_frequency_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(FrequencyStyleValue.create(Frequency.new(dimension.token().dimension_value(), unit)))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .frequency)
}

fn (mut parser Parser) parse_frequency_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_frequency_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(FrequencyStyleValue.create(Frequency.new(dimension.token().dimension_value(), unit)))
	}
	if component_value.is(.percentage) {
		tokens.consume()
		return StyleValue(PercentageStyleValue.create(Percentage.new(component_value.token().percentage())))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .frequency_percentage)
}

fn (mut parser Parser) parse_resolution_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		if component_value.token().dimension_value() < 0 {
			return none
		}
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_resolution_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(ResolutionStyleValue.create(Resolution.new(dimension.token().dimension_value(), unit)))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .resolution)
}

fn (mut parser Parser) parse_time_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_time_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(TimeStyleValue.create(Time.new(dimension.token().dimension_value(), unit)))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .time)
}

fn (mut parser Parser) parse_time_percentage_value(mut tokens ComponentValueStream) ?StyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if component_value.is(.dimension) {
		mut transaction := tokens.clone()
		dimension := transaction.consume() or { return none }
		unit := string_to_time_unit(dimension.token().dimension_unit()) or { return none }
		tokens = transaction
		return StyleValue(TimeStyleValue.create(Time.new(dimension.token().dimension_value(), unit)))
	}
	if component_value.is(.percentage) {
		tokens.consume()
		return StyleValue(PercentageStyleValue.create(Percentage.new(component_value.token().percentage())))
	}
	return parser.parse_calculated_value_of_kind(mut tokens, .time_percentage)
}

fn (mut parser Parser) parse_string_value(mut tokens ComponentValueStream) ?StringStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.peek() or { return none }
	if !component_value.is(.string) {
		return none
	}
	tokens.consume()
	return StringStyleValue.create(component_value.token().string_value())
}

// https://drafts.csswg.org/css-values-5/#tree-counting
fn (mut parser Parser) parse_tree_counting_function(mut tokens ComponentValueStream, computed_type TreeCountingComputedType) ?TreeCountingFunctionStyleValue {
	if !parser.context_allows_tree_counting_functions() {
		return none
	}

	mut transaction := tokens.clone()
	token := transaction.consume() or { return none }
	if !token.is_function() {
		return none
	}
	for argument in token.function().value {
		if !argument.is(.whitespace) {
			return none
		}
	}

	function := match to_ascii_lowercase(token.function().name) {
		'sibling-count' { TreeCountingFunction.sibling_count }
		'sibling-index' { TreeCountingFunction.sibling_index }
		else {
			return none
		}
	}

	tokens = transaction
	return TreeCountingFunctionStyleValue.create(function, computed_type)
}

// https://drafts.csswg.org/css-fonts/#typedef-opentype-tag
fn (mut parser Parser) parse_opentype_tag_value(mut tokens ComponentValueStream) ?StringStyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_string_value(mut transaction) or { return none }
	text := value.string_value()
	if text.len != 4 {
		return none
	}
	for character in text.bytes() {
		if character < 0x20 || character > 0x7e {
			return none
		}
	}
	tokens = transaction
	return value
}

// https://drafts.csswg.org/css-fonts/#font-face-src-parsing
// <font-src> = <url> [ format(<font-format>)]? [ tech(<font-tech>#)]? | local(<family-name>)
fn (mut parser Parser) parse_font_source_value(mut tokens ComponentValueStream) ?FontSourceStyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	// local(<family-name>)
	if next := transaction.peek() {
		if next.is_function_named('local') {
			function := transaction.consume()?.function()
			mut function_tokens := ComponentValueStream.new(function.value)
			family_name := parser.parse_family_name_value(mut function_tokens) or { return none }
			tokens = transaction
			return FontSourceStyleValue.create(FontSourceLocal{
				name: family_name
			}, ?string(none), []FontTech{})
		}
	}

	// <url> [ format(<font-format>)]? [ tech(<font-tech>#)]?
	url := parse_url_function(mut transaction) or { return none }
	mut format := ?string(none)
	mut tech := []FontTech{}

	transaction.consume_whitespace()
	if next := transaction.peek() {
		if next.is_function_named('format') {
			function := transaction.consume()?.function()
			parsed_format := parser.parse_font_format_function(function.value) or { return none }
			format = parsed_format.name
			tech << parsed_format.implied_tech
		}
	}

	transaction.consume_whitespace()
	if next := transaction.peek() {
		if next.is_function_named('tech') {
			function := transaction.consume()?.function()
			parsed_tech := parser.parse_font_tech_function(function.value) or { return none }
			tech << parsed_tech
		}
	}

	tokens = transaction
	return FontSourceStyleValue.create(url, format, tech)
}

fn (mut parser Parser) parse_font_format_function(values []ComponentValue) ?NormalizedFontFormatName {
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: 'format'
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	mut tokens := ComponentValueStream.new(values)
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	format := if component_value.is(.ident) {
		NormalizedFontFormatName{
			name: component_value.token().ident()
		}
	} else if component_value.is(.string) {
		normalize_legacy_font_format_name(component_value.token().string_value()) or {
			return none
		}
	} else {
		return none
	}

	if !font_format_is_supported(format.name) {
		return none
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return format
}

fn (mut parser Parser) parse_font_tech_function(values []ComponentValue) ?[]FontTech {
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: 'tech'
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	items := parse_a_comma_separated_list_of_component_values_for_value_logic(values)
	if items.len == 0 {
		return none
	}

	mut tech := []FontTech{}
	for item in items {
		mut item_tokens := ComponentValueStream.new(item)
		item_tokens.consume_whitespace()
		component_value := item_tokens.consume() or { return none }
		if !component_value.is(.ident) {
			return none
		}
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}

		font_tech := font_tech_from_string(component_value.token().ident()) or { return none }
		if !font_tech_is_supported(font_tech) {
			return none
		}
		tech << font_tech
	}
	if tech.len == 0 {
		return none
	}
	return tech
}

// DescriptorParsing.cpp parses each comma-separated component independently,
// retaining supported entries and dropping malformed or unsupported fallbacks.
fn (mut parser Parser) parse_font_source_values(mut tokens ComponentValueStream) []FontSourceStyleValue {
	mut sources := []FontSourceStyleValue{}
	component_value_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(tokens.consume_remaining_component_values())
	for component_values in component_value_lists {
		mut source_tokens := ComponentValueStream.new(component_values)
		source := parser.parse_font_source_value(mut source_tokens) or { continue }
		source_tokens.consume_whitespace()
		if source_tokens.has_more_tokens() {
			continue
		}
		sources << source
	}
	return sources
}

fn (mut parser Parser) parse_url_value(mut tokens ComponentValueStream) ?StyleValue {
	_ = parser
	return parse_url_value_for_syntax(mut tokens)
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
	return value.is_percentage() || (value.is_calculated() && value.as_calculated().resolves_to_percentage())
}

fn color_function_rectangular_color_space_from_string(value string) ?RectangularColorSpace {
	return match to_ascii_lowercase(value) {
		'srgb' { RectangularColorSpace.srgb }
		'srgb-linear' { RectangularColorSpace.srgb_linear }
		'display-p3' { RectangularColorSpace.display_p3 }
		'display-p3-linear' { RectangularColorSpace.display_p3_linear }
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
	return to_ascii_lowercase(value) in ['srgb', 'srgb-linear', 'display-p3', 'display-p3-linear', 'a98-rgb',
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
		// Simple keyword easings: linear | ease | ease-in | ease-out | ease-in-out.
		if easing_keyword := transition_timing_keyword_from_string(name) {
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(easing_keyword))
		}
		maybe_simple_easing := if equals_ignoring_ascii_case(name, 'step-start') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position: .start
			})))
		} else if equals_ignoring_ascii_case(name, 'step-end') {
			?EasingStyleValue(EasingStyleValue.create(EasingStyleValueFunction(EasingSteps{
				number_of_intervals: StyleValue(IntegerStyleValue.create(1))
				position: .end
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

	mut comma_separated_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	// Remove whitespace
	for i in 0 .. comma_separated_arguments.len {
		comma_separated_arguments[i] = remove_whitespace_from_component_values(comma_separated_arguments[i])
	}

	name := part.function().name
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	if equals_ignoring_ascii_case(name, 'linear') {
		// linear() = linear( [ <number> && <percentage>{0,2} ]# )
		mut stops := []EasingLinearStop{}
		for argument in comma_separated_arguments {
			mut argument_tokens := ComponentValueStream.new(argument)

			mut output := ?StyleValue(none)
			mut output_set := false
			mut first_input := ?StyleValue(none)
			mut second_input := ?StyleValue(none)

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				output = maybe_output
				output_set = true
			}

			if maybe_first_input := parser.parse_percentage_value(mut argument_tokens) {
				first_input = maybe_first_input
				if maybe_second_input := parser.parse_percentage_value(mut argument_tokens) {
					second_input = maybe_second_input
				}
			}

			if maybe_output := parser.parse_easing_number_value(mut argument_tokens) {
				if output_set {
					return none
				}
				output = maybe_output
				output_set = true
			}

			resolved_output := output or { return none }
			if argument_tokens.has_more_tokens() {
				return none
			}

			stops << EasingLinearStop{
				output: resolved_output
				input: first_input
			}
			if resolved_second_input := second_input {
				stops << EasingLinearStop{
					output: resolved_output
					input: resolved_second_input
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
		parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.cubic_bezier_function_x_coordinate))
		maybe_x1 := parser.parse_easing_number_value(mut argument_tokens_0)
		maybe_x2 := parser.parse_easing_number_value(mut argument_tokens_2)
		parser.pop_temporary_value_parsing_context()
		x1 := maybe_x1 or { return none }
		x2 := maybe_x2 or { return none }
		y1 := parser.parse_easing_number_value(mut argument_tokens_1) or { return none }
		y2 := parser.parse_easing_number_value(mut argument_tokens_3) or { return none }
		if x1_number := easing_number_from_style_value(x1) {
			if x1_number < 0.0 || x1_number > 1.0 {
				return none
			}
		}
		if x2_number := easing_number_from_style_value(x2) {
			if x2_number < 0.0 || x2_number > 1.0 {
				return none
			}
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
		interval_context := if position == .jump_none {
			SpecialContext.steps_intervals_jump_none
		} else {
			SpecialContext.steps_intervals_normal
		}
		parser.push_temporary_value_parsing_context(ValueParsingContext(interval_context))
		maybe_intervals := parser.parse_integer_value(mut intervals_token)
		parser.pop_temporary_value_parsing_context()
		intervals := maybe_intervals or { return none }

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
			position: position
		})))
	}

	return none
}

fn (mut parser Parser) parse_hue_none_value(mut tokens ComponentValueStream) ?StyleValue {
	// Parses [<hue> | none]
	//   <hue> = <number> | <angle>
	if channel := parser.parse_relative_color_channel_keyword(mut tokens) {
		return channel
	}
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

	green_value := green or { return none }
	blue_value := blue or { return none }
	return StyleValue(RGBColorStyleValue.create(red, green_value, blue_value, alpha, if legacy_syntax {
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

	saturation_value := saturation or { return none }
	lightness_value := lightness or { return none }
	return StyleValue(HSLColorStyleValue.create(hue, saturation_value, lightness_value, alpha, if legacy_syntax {
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

	return StyleValue(HWBColorStyleValue.create(hue, whiteness, blackness, alpha, .modern))
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
		first: first
		second: second
		third: third
		alpha: alpha or { StyleValue(NumberStyleValue.create(1)) }
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
		first: first
		second: second
		third: third
		alpha: alpha or { StyleValue(NumberStyleValue.create(1)) }
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

	return StyleValue(ColorFunctionStyleValue.create(color_space, c1, c2, c3, alpha))
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
					if !hue_token.is(.ident) || !equals_ignoring_ascii_case(hue_token.token().ident(), 'hue') {
						return none
					}
				}
			}
		}

		tokens = transaction
		return ColorInterpolationMethodStyleValue.create(ColorInterpolationMethod(PolarColorInterpolationMethod{
			color_space: polar_color_space
			hue_interpolation_method: hue_interpolation_method
		}))
	}

	// TODO: Support <custom-color-space> once we support @color-profile rules.
	return none
}

fn (mut parser Parser) parse_color_mix_component(mut tokens ComponentValueStream) ?ColorMixComponent {
	tokens.consume_whitespace()
	mut parsed_percentage_value := ?StyleValue(none)
	if percentage := parser.parse_percentage_value(mut tokens) {
		parsed_percentage_value = percentage
	}
	tokens.consume_whitespace()

	color_style_value := parser.parse_color_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if parsed_percentage_value == none {
		if percentage := parser.parse_percentage_value(mut tokens) {
			parsed_percentage_value = percentage
			tokens.consume_whitespace()
		}
	}

	if percentage_value := parsed_percentage_value {
		if !percentage_value.is_calculated() {
			percentage := percentage_value.as_percentage().percentage().value()
			if percentage < 0 || percentage > 100 {
				return none
			}
		}
	}

	return ColorMixComponent{
		color: color_style_value
		percentage: parsed_percentage_value
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
	if !function_tokens.has_more_tokens() {
		return single_color_mix_value(color_interpolation_method,first_component)
	}
	comma := function_tokens.consume() or { return none }
	if !comma.is(.comma) {
		return none
	}
	second_component := parser.parse_color_mix_component(mut function_tokens) or { return none }

	if first_percentage := first_component.percentage {
		if second_percentage := second_component.percentage {
			if first_percentage.is_percentage() && second_percentage.is_percentage()
				&& first_percentage.as_percentage().percentage().value() == 0
				&& second_percentage.as_percentage().percentage().value() == 0 {
				return none
			}
		}
	}

	function_tokens.consume_whitespace()
	if function_tokens.has_more_tokens() {
		return none
	}

	return StyleValue(ColorMixStyleValue.create(color_interpolation_method, first_component, second_component))
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
	// Transactional: only advance `tokens` on success, so a failed color probe
	// (e.g. on a leading `<length>`) does not swallow the token. Callers such as
	// the shadow parser rely on this to try color/length in either order.
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	result := parser.parse_color_from_component_value(component_value) or { return none }
	tokens = transaction
	return result
}

fn (mut parser Parser) parse_color_from_component_value(component_value ComponentValue) ?StyleValue {
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
	}

	// Functions
	if component_value.is_function() {
		parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
			name: component_value.function().name
		}))
		defer {
			parser.pop_temporary_value_parsing_context()
		}

		if alpha := parser.parse_alpha_color_function(component_value) { return alpha }

		if relative := parser.parse_relative_color_function(component_value) {
			return relative
		}

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
			return StyleValue(LabColorStyleValue.create(lab_values.first, lab_values.second, lab_values.third, lab_values.alpha))
		}
		if lch_values := parser.parse_lch_like_color_value(component_value, 'lch') {
			return StyleValue(LCHColorStyleValue.create(lch_values.first, lch_values.second, lch_values.third, lch_values.alpha))
		}
		if oklab_values := parser.parse_lab_like_color_value(component_value, 'oklab') {
			return StyleValue(OKLabColorStyleValue.create(oklab_values.first, oklab_values.second, oklab_values.third, oklab_values.alpha))
		}
		if oklch_values := parser.parse_lch_like_color_value(component_value, 'oklch') {
			return StyleValue(OKLCHColorStyleValue.create(oklch_values.first, oklch_values.second, oklch_values.third, oklch_values.alpha))
		}
		if light_dark := parser.parse_light_dark_color_value(component_value) {
			return light_dark
		}
	}

	if component_value.is(.hash) {
		color := parse_hash_color_for_value_logic(component_value.token().hash_value()) or {
			return none
		}
		return StyleValue(ColorStyleValue.create_from_color(color, .legacy, none))
	}

	// https://drafts.csswg.org/css-color-4/#quirky-color
	if parser.context_allows_quirky_color() {
		mut serialization := ''
		if component_value.is(.number) || component_value.is(.dimension) {
			number := component_value.token().number()
			if !number.is_integer() {
				return none
			}
			value := if component_value.is(.number) {
				component_value.token().to_integer()
			} else {
				component_value.token().dimension_value_int()
			}
			if value < 0 {
				return none
			}
			serialization = value.str()
			if component_value.is(.dimension) {
				serialization += component_value.token().dimension_unit()
			}
			if serialization.len < 6 {
				serialization = '0'.repeat(6 - serialization.len) + serialization
			}
		} else if component_value.is(.ident) {
			serialization = component_value.token().ident()
		} else {
			return none
		}

		if serialization.len !in [3, 6] {
			return none
		}
		color := parse_hash_color_for_value_logic(serialization) or { return none }
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
	// normal | [ light | dark | <custom-ident> ]+ && only?

	// normal
	{
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		token := transaction.consume() or { return none }
		if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'normal') {
			if transaction.has_more_tokens() {
				return none
			}
			tokens = transaction
			return StyleValue(ColorSchemeStyleValue.normal())
		}
	}

	mut only := false
	mut schemes := []string{}

	// only? && (..)
	{
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		if token := transaction.consume() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'only') {
				only = true
				tokens = transaction
			}
		}
	}

	// [ light | dark | <custom-ident> ]+
	tokens.consume_whitespace()
	for tokens.has_more_tokens() {
		mut transaction := tokens.clone()

		// The 'normal', 'light', 'dark', and 'only' keywords are not valid <custom-ident>s in this property.
		// Note: only 'normal' is blacklisted here because 'light' and 'dark' aren't parsed differently and 'only' is checked for afterwards
		ident := parser.parse_custom_ident_value(mut transaction, ['normal']) or { return none }

		if ident.custom_ident() == 'only' {
			break
		}

		schemes << ident.custom_ident()
		transaction.consume_whitespace()
		tokens = transaction
	}

	// (..) && only?
	if !only {
		mut transaction := tokens.clone()
		transaction.consume_whitespace()
		if token := transaction.consume() {
			if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'only') {
				only = true
				tokens = transaction
			}
		}
	}

	tokens.consume_whitespace()
	if tokens.has_more_tokens() || schemes.len == 0 {
		return none
	}

	return StyleValue(ColorSchemeStyleValue.create(schemes, only))
}

pub fn (mut parser Parser) parse_descriptor_value(at_rule_id AtRuleID, descriptor_id DescriptorID) ?StyleValue {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_descriptor_value_tokens(at_rule_id, descriptor_id, mut tokens)
}

fn (mut parser Parser) parse_descriptor_value_tokens(at_rule_id AtRuleID, descriptor_id DescriptorID, mut tokens ComponentValueStream) ?StyleValue {
	parser.push_temporary_value_parsing_context(ValueParsingContext(DescriptorContext{
		at_rule: at_rule_id
		descriptor: descriptor_id
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	// Descriptor CSSOM setters parse the complete supplied value. A top-level
	// semicolon cannot terminate it and leave a suffix to be silently ignored.
	for token in tokens.values[tokens.index..] {
		if token.is(.semicolon) {
			return none
		}
	}
	descriptor_values := tokens.values[tokens.index..].clone()
	mut substitution_presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(descriptor_values, mut substitution_presence) or {
		return none
	}
	if substitution_presence.has_any() {
		// Property values admit arbitrary substitution functions by default;
		// descriptors do not. @function result/custom descriptors explicitly opt
		// in because their values are substituted when the function is invoked.
		if at_rule_id != .function_rule {
			return none
		}
		return StyleValue(UnresolvedStyleValue.create_with_presence(descriptor_values, substitution_presence, none))
	}

	mut maybe_value := ?StyleValue(none)
	match at_rule_id {
		.function_rule {
			if descriptor_id !in [.custom, .result] {
				return none
			}
			remaining := tokens.consume_remaining_component_values()
			if !is_valid_optional_declaration_value(remaining) {
				return none
			}
			return StyleValue(UnresolvedStyleValue.create(remaining))
		}
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
				.unknown, .custom, .result {
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
	return StyleValue(CustomIdentStyleValue.create(value))
}

// https://www.w3.org/TR/css-values-4/#custom-idents
fn (mut parser Parser) parse_custom_ident(mut tokens ComponentValueStream, blacklist []string) ?string {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	token := transaction.consume() or { return none }
	if !token.is(.ident) {
		return none
	}
	custom_ident := token.token().ident()

	if !is_valid_custom_ident(custom_ident, blacklist) {
		return none
	}

	tokens = transaction
	return custom_ident
}

fn (mut parser Parser) parse_custom_ident_value(mut tokens ComponentValueStream, blacklist []string) ?CustomIdentStyleValue {
	custom_ident := parser.parse_custom_ident(mut tokens, blacklist) or { return none }
	return CustomIdentStyleValue.create(custom_ident)
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
	mut working_copy := tokens.clone()
	if value := parser.parse_length_percentage_value(mut working_copy) {
		tokens = working_copy
		return value
	}

	working_copy = tokens.clone()
	if value := consume_descriptor_ident(mut working_copy) {
		if value == 'auto' {
			tokens = working_copy
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
		mut working_copy := tokens.clone()
		value := parser.parse_page_margin_component_value(mut working_copy) or { break }
		values << value
		tokens = working_copy
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
	mut working_copy := tokens.clone()
	if value := consume_descriptor_ident(mut working_copy) {
		if value == 'auto' {
			tokens = working_copy
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
	mut working_copy := tokens.clone()
	if first_length := parser.parse_length_value(mut working_copy) {
		if first_length.is_length() && first_length.as_length().raw_value() < 0 {
			return none
		}

		working_copy.consume_whitespace()
		if second_length := parser.parse_length_value(mut working_copy) {
			if second_length.is_length() && second_length.as_length().raw_value() < 0 {
				return none
			}
			tokens = working_copy
			return StyleValue(StyleValueList.create([first_length, second_length], .space, .yes))
		}

		tokens = working_copy
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

pub fn (mut parser Parser) parse_as_supports() ?&Supports {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_a_supports(mut tokens)
}

fn (mut parser Parser) parse_a_supports(mut tokens ComponentValueStream) ?&Supports {
	mut transaction := tokens.clone()
	component_values := transaction.consume_remaining_component_values()
	mut condition_tokens := SupportsTokenStream.from_values_with_namespaces(component_values, parser.context.declared_namespaces)
	condition := parser.parse_supports_condition(mut condition_tokens) or { return none }
	condition_tokens.discard_whitespace()
	if condition_tokens.has_next_token() {
		return none
	}
	tokens = transaction
	return Supports.create(condition)
}

pub fn (mut parser Parser) parse_as_media_query_list() []&MediaQuery {
	mut tokens := ComponentValueStream.new(parser.component_values)
	return parser.parse_a_media_query_list(mut tokens)
}

fn (mut parser Parser) parse_a_media_query_list(mut tokens ComponentValueStream) []&MediaQuery {
	// AD-HOC: Ignore whitespace-only queries, making `@media { ... }`
	// equivalent to `@media all { ... }`.
	tokens.consume_whitespace()
	if !tokens.has_more_tokens() {
		return []
	}

	comma_separated_lists := parse_a_comma_separated_list_of_component_values_for_value_logic(tokens.consume_remaining_component_values())
	mut queries := []&MediaQuery{cap: comma_separated_lists.len}
	for media_query_parts in comma_separated_lists {
		mut stream := ComponentValueStream.new(media_query_parts)
		queries << parser.parse_media_query(mut stream)
	}
	return queries
}

pub fn (mut parser Parser) parse_as_media_query() ?&MediaQuery {
	media_query_list := parser.parse_as_media_query_list()
	if media_query_list.len == 0 {
		return MediaQuery.create_not_all()
	}
	if media_query_list.len == 1 {
		return media_query_list[0]
	}
	return none
}

// `<media-query>`, https://www.w3.org/TR/mediaqueries-4/#typedef-media-query
fn (mut parser Parser) parse_media_query(mut tokens ComponentValueStream) &MediaQuery {
	mut condition_transaction := tokens.clone()
	if media_condition := parser.parse_media_condition(mut condition_transaction) {
		condition_transaction.consume_whitespace()
		if !condition_transaction.has_more_tokens() {
			tokens = condition_transaction
			mut media_query := MediaQuery.create()
			media_query.media_condition = media_condition
			media_query.text = media_query.to_string()
			media_query.matches = media_query.evaluate(none)
			return media_query
		}
	}

	mut media_query := MediaQuery.create()
	tokens.consume_whitespace()

	// `[ not | only ]?`
	mut modifier_transaction := tokens.clone()
	modifier_transaction.consume_whitespace()
	if modifier := modifier_transaction.consume() {
		if modifier.is(.ident) {
			ident := modifier.token().ident().to_lower()
			if ident == 'not' || ident == 'only' {
				media_query.negated = ident == 'not'
				tokens = modifier_transaction
				tokens.consume_whitespace()
			}
		}
	}

	// `<media-type>`
	media_type := parser.parse_media_type(mut tokens) or {
		return MediaQuery.create_not_all()
	}
	media_query.media_type = media_type
	tokens.consume_whitespace()

	if !tokens.has_more_tokens() {
		media_query.text = media_query.to_string()
		media_query.matches = media_query.evaluate(none)
		return media_query
	}

	// `[ and <media-condition-without-or> ]?`
	maybe_and := tokens.consume() or { return MediaQuery.create_not_all() }
	if !maybe_and.is_ident('and') {
		return MediaQuery.create_not_all()
	}

	media_condition := parser.parse_media_condition(mut tokens) or {
		return MediaQuery.create_not_all()
	}
	if media_condition.kind == .or {
		return MediaQuery.create_not_all()
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return MediaQuery.create_not_all()
	}

	media_query.media_condition = media_condition
	media_query.text = media_query.to_string()
	media_query.matches = media_query.evaluate(none)
	return media_query
}

// `<media-condition>`, https://www.w3.org/TR/mediaqueries-4/#typedef-media-condition
fn (mut parser Parser) parse_media_condition(mut tokens ComponentValueStream) ?&BooleanExpression {
	_ = parser
	mut transaction := tokens.clone()
	mut condition_tokens := SupportsTokenStream.from_values(transaction.values[transaction.index..])
	condition := parse_media_condition_with_parser(mut parser, mut condition_tokens) or {
		return none
	}
	transaction.index += condition_tokens.index
	tokens = transaction
	return condition
}

fn (mut parser Parser) parse_media_type(mut tokens ComponentValueStream) ?MediaQueryType {
	_ = parser
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	component_value := transaction.consume() or { return none }
	if !component_value.is(.ident) {
		return none
	}

	name := component_value.token().ident()
	if name.to_lower() in ['layer', 'not', 'and', 'only', 'or'] {
		return none
	}

	tokens = transaction
	return MediaQueryType{
		name: name
		known_type: media_type_from_string(name)
	}
}

fn (mut parser Parser) parse_media_feature_value(media_feature string, mut tokens ComponentValueStream) ?StyleValue {
	parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.media_condition))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

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
		return StyleValue(UnresolvedStyleValue.create_with_presence(unknown_tokens, SubstitutionFunctionsPresence{}, none))
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

		transaction = tokens.clone()
		transaction.consume_whitespace()
		component_value := transaction.consume() or { return none }
		mut calculated_tokens := ComponentValueStream.new([component_value])
		if calculated := parse_calculated_value(mut calculated_tokens) {
			if calculated is CalculatedStyleValue && calculated.resolves_to_number() {
				if number := calculated.resolve_number(CalculationResolutionContext{}) {
					if number == 0 {
						tokens = transaction
						return StyleValue(LengthStyleValue.create(Length.make_px(0)))
					}
				}
			}
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
	mut working_copy := stream
	working_copy.consume_whitespace()
	next := working_copy.peek() or { return false }
	return is_media_feature_value_token(next)
}

fn (mut parser Parser) parse_ratio_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	// `<ratio> = <number [0,+inf]> [ / <number [0,+inf]> ]?`
	numerator := parser.read_ratio_number_style_value(transaction.consume() or { return none }) or {
		return none
	}

	{
		mut two_value_transaction := transaction.clone()
		two_value_transaction.consume_whitespace()
		solidus := two_value_transaction.consume() or {
			tokens = transaction
			return StyleValue(RatioStyleValue.create_from_style_values(numerator, StyleValue(NumberStyleValue.create(1))))
		}
		two_value_transaction.consume_whitespace()
		denominator := parser.read_ratio_number_style_value(two_value_transaction.consume() or {
			tokens = transaction
			return StyleValue(RatioStyleValue.create_from_style_values(numerator, StyleValue(NumberStyleValue.create(1))))
		}) or {
			tokens = transaction
			return StyleValue(RatioStyleValue.create_from_style_values(numerator, StyleValue(NumberStyleValue.create(1))))
		}

		if solidus.is_delim(u32(`/`)) {
			// Two-value ratio
			tokens = two_value_transaction
			return StyleValue(RatioStyleValue.create_from_style_values(numerator, denominator))
		}
	}

	// Single-value ratio
	tokens = transaction
	return StyleValue(RatioStyleValue.create_from_style_values(numerator, StyleValue(NumberStyleValue.create(1))))
}

fn (mut parser Parser) read_ratio_number_style_value(component_value ComponentValue) ?StyleValue {
	if component_value.is(.number) {
		value := component_value.token().number_value()
		if value < 0 {
			return none
		}
		return StyleValue(NumberStyleValue.create(value))
	}
	if component_value.is_function() {
		mut stream := ComponentValueStream.new([component_value])
		mut context := parser.calculation_context()
		context.accepted_type_ranges[.number] = accepted_calculation_range(0, math.max_f32)
		calculated := parser.parse_calculated_value_with_context(mut stream, context, parser.context_allows_tree_counting_functions()) or { return none }
		if calculated is NumberStyleValue {
			if calculated.number() < 0 {
				return none
			}
			return calculated
		}
		if calculated is CalculatedStyleValue && calculated.resolves_to_number() {
			return calculated
		}
	}
	return none
}

fn style_value_from_css_image_source_for_value_logic(value CSSImageSourceStyleValue) StyleValue {
	return match value {
		ConicGradientStyleValue { StyleValue(value) }
		ImageSetStyleValue { StyleValue(value) }
		ImageStyleValue { StyleValue(value) }
		LinearGradientStyleValue { StyleValue(value) }
		RadialGradientStyleValue { StyleValue(value) }
		StyleValue { value }
	}
}

fn image_set_image_from_css_image_source(value CSSImageSourceStyleValue) ?ImageSetImageStyleValue {
	return match value {
		ConicGradientStyleValue { ImageSetImageStyleValue(value) }
		ImageStyleValue { ImageSetImageStyleValue(value) }
		LinearGradientStyleValue { ImageSetImageStyleValue(value) }
		RadialGradientStyleValue { ImageSetImageStyleValue(value) }
		ImageSetStyleValue { none }
		StyleValue { if value.is_abstract_image() { ImageSetImageStyleValue(value) } else { none } }
	}
}

fn image_set_resolution_from_style_value(value StyleValue) ?ImageSetResolutionStyleValue {
	return match value {
		CalculatedStyleValue { ImageSetResolutionStyleValue(value) }
		ResolutionStyleValue { ImageSetResolutionStyleValue(value) }
		else { none }
	}
}

fn (mut parser Parser) parse_image_or_none_value(mut tokens ComponentValueStream) ?StyleValue {
	if none_value := parser.parse_all_as_single_keyword_value(mut tokens, .none_) {
		return none_value
	}

	// Do not reject trailing tokens: this is used as a component parser (e.g. the
	// image in a `background` layer, or border-image source). Whole-value callers
	// rely on the top-level leftover-token check.
	mut transaction := tokens.clone()
	image := parser.parse_image_value(mut transaction) or { return none }

	tokens = transaction
	return style_value_from_css_image_source_for_value_logic(image)
}

fn (mut parser Parser) parse_image_or_none_list_value(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	values := parse_a_comma_separated_list_of_component_values_for_value_logic(transaction.consume_remaining_component_values())

	mut images := []StyleValue{}
	for value in values {
		mut item_tokens := ComponentValueStream.new(value)
		image := parser.parse_image_or_none_value(mut item_tokens) or { return none }
		item_tokens.consume_whitespace()
		if item_tokens.has_more_tokens() {
			return none
		}
		images << image
	}

	if images.len == 0 {
		return none
	}

	tokens = transaction
	return StyleValue(StyleValueList.create(images, .comma, .yes))
}

fn (mut parser Parser) parse_image_value(mut tokens ComponentValueStream) ?CSSImageSourceStyleValue {
	return parser.parse_image_value_allowing_image_set(mut tokens, true)
}

fn (mut parser Parser) parse_image_value_allowing_image_set(mut tokens ComponentValueStream, allow_image_set bool) ?CSSImageSourceStyleValue {
	tokens.consume_whitespace()
	component_value := tokens.consume() or { return none }
	if component_value.is_function_named('light-dark') {
		return CSSImageSourceStyleValue(parser.parse_light_dark_image_function(component_value, allow_image_set)?)
	}
	if component_value.is_function_named('-webkit-cross-fade') {
		return CSSImageSourceStyleValue(parser.parse_webkit_cross_fade_image(component_value,allow_image_set)?)
	}
	if component_value.is_function_named('image') {
		mut inner := ComponentValueStream.new(component_value.function().value)
		color := parser.parse_color_value(mut inner) or { return none }
		inner.consume_whitespace()
		if inner.has_more_tokens() { return none }
		return CSSImageSourceStyleValue(StyleValue(FunctionStyleValue.create('image',color)))
	}
	if component_value.is(.url) {
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(component_value.token().url()))
	}
	if component_value.is_function_named('url') {
		// url( <string> <url-modifier>* ): use the string's parsed value (unquoted),
		// not the joined source text (which would keep the quotes).
		mut url_tokens := ComponentValueStream.new(component_value.function().value)
		url_tokens.consume_whitespace()
		url_arg := url_tokens.consume() or { return none }
		url_string := if url_arg.is(.string) {
			url_arg.token().string_value()
		} else {
			component_value.function().value.map(it.to_string()).join('')
		}
		return CSSImageSourceStyleValue(ImageStyleValue.create_from_url_string(url_string))
	}
	if allow_image_set && (component_value.is_function_named('image-set')
		|| component_value.is_function_named('-webkit-image-set')) {
		options_tokens := parse_a_comma_separated_list_of_component_values_for_value_logic(component_value.function().value)
		mut options := []ImageSetOption{cap: options_tokens.len}
		for option_values in options_tokens {
			if contains_attr_tainted_value(option_values) {
				return none
			}
			mut option_tokens := ComponentValueStream.new(option_values)
			option_tokens.consume_whitespace()
			first := option_tokens.peek() or { return none }
			mut image := ImageSetImageStyleValue(ImageStyleValue{})
			if first.is(.string) {
				option_tokens.consume()
				image = ImageSetImageStyleValue(ImageStyleValue.create_from_url_string(first.token().string_value()))
			} else {
				parsed_image := parser.parse_image_value_allowing_image_set(mut option_tokens, false) or { return none }
				image = image_set_image_from_css_image_source(parsed_image) or { return none }
			}

			mut resolution := ?ImageSetResolutionStyleValue(none)
			mut type_ := ?string(none)
			for option_tokens.has_more_tokens() {
				if resolution == none {
					mut resolution_tokens := option_tokens.clone()
					if parsed_resolution := parser.parse_resolution_value(mut resolution_tokens) {
						resolution = image_set_resolution_from_style_value(parsed_resolution) or {
							return none
						}
						option_tokens = resolution_tokens
						continue
					}
				}

				option_tokens.consume_whitespace()
				next := option_tokens.peek() or { break }
				if type_ == none && next.is_function_named('type') {
					option_tokens.consume()
					mut type_tokens := ComponentValueStream.new(next.function().value)
					type_tokens.consume_whitespace()
					type_token := type_tokens.consume() or { return none }
					if !type_token.is(.string) || type_tokens.has_more_tokens() {
						return none
					}
					type_ = type_token.token().string_value()
					continue
				}
				return none
			}

			options << ImageSetOption{
				image: image
				resolution: resolution or {
					ImageSetResolutionStyleValue(ResolutionStyleValue.create(Resolution.new(1, .x)))
				}
				type_: type_
			}
		}
		if options.len == 0 {
			return none
		}
		return CSSImageSourceStyleValue(ImageSetStyleValue.create(options))
	}
	if component_value.is_function_named('linear-gradient') || component_value.is_function_named('repeating-linear-gradient') || component_value.is_function_named('-webkit-linear-gradient') || component_value.is_function_named('-webkit-repeating-linear-gradient') {
		parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
			name: component_value.function().name
		}))
		defer {
			parser.pop_temporary_value_parsing_context()
		}
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_linear_gradient_function(component_value.function().name, mut inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('radial-gradient') || component_value.is_function_named('repeating-radial-gradient') || component_value.is_function_named('-webkit-radial-gradient') || component_value.is_function_named('-webkit-repeating-radial-gradient') {
		parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
			name: component_value.function().name
		}))
		defer {
			parser.pop_temporary_value_parsing_context()
		}
		mut inner := ComponentValueStream.new(component_value.function().value)
		gradient := parser.parse_radial_gradient_function(to_ascii_lowercase(component_value.function().name), mut inner) or { return none }
		return CSSImageSourceStyleValue(gradient)
	}
	if component_value.is_function_named('conic-gradient') || component_value.is_function_named('repeating-conic-gradient') {
		parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
			name: component_value.function().name
		}))
		defer {
			parser.pop_temporary_value_parsing_context()
		}
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
	parser.push_temporary_value_parsing_context(ValueParsingContext(FunctionContext{
		name: part.function().name
	}))
	defer {
		parser.pop_temporary_value_parsing_context()
	}

	function_metadata := transform_function_metadata(function)
	mut call_arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(part.function().value)

	if call_arguments.len > function_metadata.parameters.len {
		return none
	}

	if call_arguments.len < function_metadata.parameters.len && function_metadata.parameters[call_arguments.len].required {
		return none
	}

	mut values := StyleValueVector{}
	for argument_index in 0 .. call_arguments.len {
		mut argument_tokens := ComponentValueStream.new(call_arguments[argument_index])
		argument_tokens.consume_whitespace()
		value := parser.parse_transform_parameter_value(function_metadata.parameters[argument_index], mut argument_tokens) or { return none }
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

// https://www.w3.org/TR/css-transforms-1/#transform-property
fn (mut parser Parser) parse_transform_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <transform-list>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	value := parser.parse_transform_list_value(mut transaction) or { return none }
	tokens = transaction
	return value
}

enum TransformOriginAxisForValueLogic {
	none_
	x
	y
}

struct TransformOriginAxisOffsetForValueLogic {
mut:
	axis   TransformOriginAxisForValueLogic
	offset StyleValue
}

fn transform_origin_axis_offset_from_style_value_for_value_logic(value StyleValue) ?TransformOriginAxisOffsetForValueLogic {
	if value is PercentageStyleValue || value is LengthStyleValue {
		return TransformOriginAxisOffsetForValueLogic{
			axis: .none_
			offset: value
		}
	}
	if value.is_keyword() {
		return match value.to_keyword() {
			.top {
				TransformOriginAxisOffsetForValueLogic{
					axis: .y
					offset: value
				}
			}
			.left {
				TransformOriginAxisOffsetForValueLogic{
					axis: .x
					offset: value
				}
			}
			.center {
				TransformOriginAxisOffsetForValueLogic{
					axis: .none_
					offset: value
				}
			}
			.bottom {
				TransformOriginAxisOffsetForValueLogic{
					axis: .y
					offset: value
				}
			}
			.right {
				TransformOriginAxisOffsetForValueLogic{
					axis: .x
					offset: value
				}
			}
			else {
				none
			}
		}
	}
	if value is CalculatedStyleValue {
		return TransformOriginAxisOffsetForValueLogic{
			axis: .none_
			offset: value
		}
	}
	return none
}

fn (mut parser Parser) parse_transform_origin_component_value_for_value_logic(mut tokens ComponentValueStream) ?StyleValue {
	if keyword := parse_single_keyword_from_set_for_value_logic(mut tokens, [
		'bottom',
		'center',
		'left',
		'right',
		'top',
	]) {
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	return parser.parse_length_percentage_value(mut tokens)
}

// https://www.w3.org/TR/css-transforms-1/#propdef-transform-origin
fn (mut parser Parser) parse_transform_origin_value(mut tokens ComponentValueStream) ?StyleValue {
	//   [ left | center | right | top | bottom | <length-percentage> ]
	// |
	//   [ left | center | right | <length-percentage> ]
	//   [ top | center | bottom | <length-percentage> ] <length>?
	// |
	//   [[ center | left | right ] && [ center | top | bottom ]] <length>?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()

	zero_value := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	first_component := parser.parse_transform_origin_component_value_for_value_logic(mut transaction) or {
		return none
	}
	first_value := transform_origin_axis_offset_from_style_value_for_value_logic(first_component) or {
		return none
	}
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return match first_value.axis {
			.none_, .x {
				StyleValue(StyleValueList.create([
					first_value.offset,
					StyleValue(KeywordStyleValue.create(.center)),
					zero_value,
				], .space, .no))
			}
			.y {
				StyleValue(StyleValueList.create([
					StyleValue(KeywordStyleValue.create(.center)),
					first_value.offset,
					zero_value,
				], .space, .no))
			}
		}
	}

	second_component := parser.parse_transform_origin_component_value_for_value_logic(mut transaction) or {
		return none
	}
	second_value := transform_origin_axis_offset_from_style_value_for_value_logic(second_component) or {
		return none
	}
	mut third_value := zero_value
	mut third_transaction := transaction.clone()
	if maybe_third := parser.parse_length_value(mut third_transaction) {
		third_value = maybe_third
		transaction = third_transaction
	}

	if (first_value.offset is LengthStyleValue || first_value.offset is PercentageStyleValue) && second_value.axis == .x {
		return none
	}
	if (second_value.offset is LengthStyleValue || second_value.offset is PercentageStyleValue) && first_value.axis == .y {
		return none
	}

	mut x_value := ?StyleValue(none)
	mut y_value := ?StyleValue(none)
	mut has_x_value := false
	mut has_y_value := false

	if first_value.axis == .x {
		x_value = first_value.offset
		has_x_value = true
	} else if first_value.axis == .y {
		y_value = first_value.offset
		has_y_value = true
	}

	if second_value.axis == .x {
		if has_x_value {
			return none
		}
		x_value = second_value.offset
		has_x_value = true
		// Put the other in Y since its axis can't have been X.
		y_value = first_value.offset
		has_y_value = true
	} else if second_value.axis == .y {
		if has_y_value {
			return none
		}
		y_value = second_value.offset
		has_y_value = true
		// Put the other in X since its axis can't have been Y.
		x_value = first_value.offset
		has_x_value = true
	} else {
		if has_x_value {
			y_value = second_value.offset
			has_y_value = true
		} else {
			x_value = second_value.offset
			has_x_value = true
		}
	}

	// If two or more values are defined and either no value is a keyword, or the only used keyword is center,
	// then the first value represents the horizontal position (or offset) and the second represents the vertical position (or offset).
	// A third value always represents the Z position (or offset) and must be of type <length>.
	if first_value.axis == .none_ && second_value.axis == .none_ {
		x_value = first_value.offset
		y_value = second_value.offset
		has_x_value = true
		has_y_value = true
	}

	if !has_x_value || !has_y_value {
		return none
	}
	x := x_value or { return none }
	y := y_value or { return none }
	tokens = transaction
	return StyleValue(StyleValueList.create([x, y, third_value], .space, .no))
}

fn (mut parser Parser) parse_optional_angle_value_without_consuming_on_failure(mut tokens ComponentValueStream) ?StyleValue {
	mut transaction := tokens.clone()
	value := parser.parse_angle_value(mut transaction) or { return none }
	tokens = transaction
	return value
}

// https://drafts.csswg.org/css-transforms-2/#propdef-rotate
fn (mut parser Parser) parse_rotate_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <angle> | [ x | y | z ] && <angle> | <number>{3} && <angle>
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	mut angle := ?StyleValue(none)
	if angle_value := parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction) {
		angle = angle_value
	}
	transaction.consume_whitespace()

	// <angle>
	if angle_value := angle {
		if !transaction.has_more_tokens() {
			tokens = transaction
			return StyleValue(TransformationStyleValue.create(.rotate, .rotate, [
				angle_value,
			]))
		}
	}

	parse_one_of_xyz := fn (mut input ComponentValueStream) ?string {
		mut axis_transaction := input.clone()
		axis_transaction.consume_whitespace()
		axis := axis_transaction.consume() or { return none }
		if axis.is(.ident) {
			ident := axis.token().ident()
			if equals_ignoring_ascii_case(ident, 'x') || equals_ignoring_ascii_case(ident, 'y') || equals_ignoring_ascii_case(ident, 'z') {
				input = axis_transaction
				return to_ascii_lowercase(ident)
			}
		}
		return none
	}

	// [ x | y | z ] && <angle>
	if axis := parse_one_of_xyz(mut transaction) {
		transaction.consume_whitespace()
		if angle == none {
			angle = parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction)
		}
		if angle_value := angle {
			tokens = transaction
			transform_function := match axis {
				'x' { TransformFunction.rotate_x }
				'y' { TransformFunction.rotate_y }
				else { TransformFunction.rotate_z }
			}

			return StyleValue(TransformationStyleValue.create(.rotate, transform_function, [
				angle_value,
			]))
		}
		return none
	}

	parse_three_numbers := fn [mut parser] (mut input ComponentValueStream) ?StyleValueVector {
		mut numbers_transaction := input.clone()
		mut numbers := StyleValueVector{}
		for _ in 0 .. 3 {
			number := parser.parse_number_value(mut numbers_transaction) or { return none }
			numbers << number
		}
		input = numbers_transaction
		return numbers
	}

	// <number>{3} && <angle>
	if mut numbers := parse_three_numbers(mut transaction) {
		transaction.consume_whitespace()
		if angle == none {
			angle = parser.parse_optional_angle_value_without_consuming_on_failure(mut transaction)
		}
		if angle_value := angle {
			numbers << angle_value
			tokens = transaction
			return StyleValue(TransformationStyleValue.create(.rotate, .rotate3d, numbers))
		}
	}

	return none
}

// https://drafts.csswg.org/css-transforms-2/#propdef-translate
fn (mut parser Parser) parse_translate_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | <length-percentage> [ <length-percentage> <length>? ]?
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	maybe_x := parser.parse_length_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.translate, .translate, [
			maybe_x,
			StyleValue(LengthStyleValue.create(Length.make_px(0))),
		]))
	}

	maybe_y := parser.parse_length_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.translate, .translate, [
			maybe_x,
			maybe_y,
		]))
	}

	parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.translate_z_argument))
	maybe_z_value := parser.parse_length_value(mut transaction)
	parser.pop_temporary_value_parsing_context()
	maybe_z := maybe_z_value or { return none }
	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.translate, .translate3d, [
		maybe_x,
		maybe_y,
		maybe_z,
	]))
}

// https://drafts.csswg.org/css-transforms-2/#propdef-scale
fn (mut parser Parser) parse_scale_value(mut tokens ComponentValueStream) ?StyleValue {
	// none | [ <number> | <percentage> ]{1,3}
	mut transaction := tokens.clone()
	transaction.consume_whitespace()
	if component_value := transaction.peek() {
		if component_value.is(.ident) && equals_ignoring_ascii_case(component_value.token().ident(), 'none') {
			transaction.consume()
			tokens = transaction
			return StyleValue(KeywordStyleValue.create(.none_))
		}
	}

	transaction = tokens.clone()
	maybe_x := parser.parse_number_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.scale, .scale, [maybe_x, maybe_x]))
	}

	maybe_y := parser.parse_number_percentage_value(mut transaction) or { return none }
	transaction.consume_whitespace()
	if !transaction.has_more_tokens() {
		tokens = transaction
		return StyleValue(TransformationStyleValue.create(.scale, .scale, [
			maybe_x,
			maybe_y,
		]))
	}

	maybe_z := parser.parse_number_percentage_value(mut transaction) or { return none }
	tokens = transaction
	return StyleValue(TransformationStyleValue.create(.scale, .scale3d, [
		maybe_x,
		maybe_y,
		maybe_z,
	]))
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
	mut has_direction := false
	mut interpolation_method := parser.parse_color_interpolation_method_value(mut tokens)
	tokens.consume_whitespace()

	mut probe := tokens.clone()
	if angle := parser.parse_angle_value(mut probe) {
		direction = LinearGradientDirection(angle)
		has_direction = true
		tokens = probe
	} else {
		probe = tokens.clone()
		probe.consume_whitespace()
		if first := probe.peek() {
			if first.is(.number) && first.token().number_value() == 0 {
				probe.consume()
				direction = LinearGradientDirection(StyleValue(AngleStyleValue.create(Angle.make_degrees(0))))
				has_direction = true
				tokens = probe
			} else if first.is(.ident)
				&& ((gradient_type == .standard
					&& equals_ignoring_ascii_case(first.token().ident(), 'to'))
					|| (gradient_type == .webkit
						&& to_ascii_lowercase(first.token().ident()) in ['top', 'bottom', 'left',
							'right'])) {
				if gradient_type == .standard {
					probe.consume()
				}
				side := parser.parse_linear_gradient_side_or_corner(mut probe) or { return none }
				direction = LinearGradientDirection(side)
				has_direction = true
				tokens = probe
			}
		}
	}

	if interpolation_method == none {
		interpolation_method = parser.parse_color_interpolation_method_value(mut tokens)
	}
	tokens.consume_whitespace()
	if (has_direction || interpolation_method != none) && !tokens.consume_a_comma() {
		return none
	}

	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return LinearGradientStyleValue.create(direction, color_stops, gradient_type, repeating, interpolation_method)
}

fn (mut parser Parser) parse_linear_gradient_side_or_corner(mut tokens ComponentValueStream) ?LinearGradientSideOrCorner {
	tokens.consume_whitespace()
	first := tokens.consume() or { return none }
	if !first.is(.ident) {
		return none
	}
	first_ident := first.token().ident().to_lower()
	mut second_ident := ''
	mut working_copy := tokens
	working_copy.consume_whitespace()
	if second := working_copy.consume() {
		if second.is(.ident) {
			second_ident = second.token().ident().to_lower()
			tokens = working_copy
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
	parser.push_temporary_value_parsing_context(ValueParsingContext(SpecialContext.angular_color_stop_list))
	defer {
		parser.pop_temporary_value_parsing_context()
	}
	return parser.parse_color_stop_list(mut tokens, true)
}

enum ParsedColorStopElementType {
	color_stop
	color_hint
}

struct ParsedColorStopElement {
mut:
	kind    ParsedColorStopElementType
	element ColorStopListElement
}

fn (mut parser Parser) parse_color_stop_list_element(mut tokens ComponentValueStream,
	angular bool) ?ParsedColorStopElement {
	tokens.consume_whitespace()
	if !tokens.has_more_tokens() {
		return none
	}

	mut position := ?StyleValue(none)
	mut second_position := ?StyleValue(none)
	mut color := ?StyleValue(none)
	mut position_probe := tokens.clone()
	if leading_position := parser.parse_color_stop_position(mut position_probe, angular) {
		tokens = position_probe
		position = leading_position
		tokens.consume_whitespace()
		if next := tokens.peek() {
			if next.is(.comma) {
				return ParsedColorStopElement{
					kind: .color_hint
					element: ColorStopListElement{
						transition_hint: leading_position
					}
				}
			}
		} else {
			return ParsedColorStopElement{
				kind: .color_hint
				element: ColorStopListElement{
					transition_hint: leading_position
				}
			}
		}
		color = parser.parse_color_value(mut tokens) or { return none }
	} else {
		color = parser.parse_color_value(mut tokens) or { return none }
		tokens.consume_whitespace()
		for position_index in 0 .. 2 {
			if next := tokens.peek() {
				if next.is(.comma) {
					break
				}
				parsed_position := parser.parse_color_stop_position(mut tokens, angular) or {
					return none
				}
				if position_index == 0 {
					position = parsed_position
				} else {
					second_position = parsed_position
				}
				tokens.consume_whitespace()
			} else {
				break
			}
		}
	}

	return ParsedColorStopElement{
		kind: .color_stop
		element: ColorStopListElement{
			color_stop: ColorStop{
				color: color or { return none }
				position: position
				second_position: second_position
			}
		}
	}
}

fn (mut parser Parser) parse_color_stop_list(mut tokens ComponentValueStream, angular bool) ?[]ColorStopListElement {
	// GradientParsing.cpp keeps a transition hint and its following color stop
	// in the same ColorStopListElement.
	first := parser.parse_color_stop_list_element(mut tokens, angular) or { return none }
	if first.kind != .color_stop {
		return none
	}
	mut elements := [first.element]
	for tokens.has_more_tokens() {
		if !tokens.consume_a_comma() {
			return none
		}
		mut parsed := parser.parse_color_stop_list_element(mut tokens, angular) or { return none }
		if parsed.kind == .color_hint {
			if !tokens.consume_a_comma() {
				return none
			}
			following := parser.parse_color_stop_list_element(mut tokens, angular) or { return none }
			if following.kind != .color_stop {
				return none
			}
			parsed.element.color_stop = following.element.color_stop
		}
		elements << parsed.element
	}
	if elements.len < 2 {
		return none
	}
	return elements
}

fn (mut parser Parser) parse_color_stop_position(mut tokens ComponentValueStream, angular bool) ?StyleValue {
	mut working_copy := tokens.clone()
	if angular {
		working_copy.consume_whitespace()
		if zero := working_copy.peek() {
			if zero.is(.number) && zero.token().number_value() == 0 {
				working_copy.consume()
				tokens = working_copy
				return StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
			}
		}
		working_copy = tokens.clone()
		if value := parser.parse_angle_value(mut working_copy) {
			tokens = working_copy
			return value
		}
	} else {
		if value := parser.parse_length_percentage_value(mut working_copy) {
			tokens = working_copy
			return value
		}
	}
	working_copy = tokens.clone()
	if value := parser.parse_percentage_value(mut working_copy) {
		tokens = working_copy
		return value
	}
	return none
}

fn (mut parser Parser) parse_radial_gradient_function(function_name string, mut tokens ComponentValueStream) ?RadialGradientStyleValue {
	if function_name.starts_with('-webkit-') {
		return parser.parse_webkit_radial_gradient_function(function_name, mut tokens)
	}
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	// GradientParsing.cpp: <radial-size> is retained as a
	// RadialSizeStyleValue. Storing an extent keyword or a loose value list here
	// loses the shape-derivation and size-resolution semantics used by painting.
	mut ending_shape := RadialGradientEndingShape.circle
	mut size := StyleValue(RadialSizeStyleValue.create([
		RadialSizeStyleValueComponent(RadialExtentComponent{
			extent: .farthest_corner
		}),
	]))
	mut position := PositionStyleValue.create_center()
	mut interpolation_method := parser.parse_color_interpolation_method_value(mut tokens)
	mut probe := tokens.clone()
	mut has_prefix := false
	mut shape_set := false
	probe.consume_whitespace()
	if next := probe.peek() {
		if next.is(.ident) && to_ascii_lowercase(next.token().ident()) in ['circle', 'ellipse'] {
			ending_shape = if equals_ignoring_ascii_case(next.token().ident(), 'circle') {
				RadialGradientEndingShape.circle
			} else {
				RadialGradientEndingShape.ellipse
			}
			probe.consume()
			shape_set = true
			has_prefix = true
		}
	}
	mut size_attempt := probe.clone()
	if parsed_size := parser.parse_radial_size(mut size_attempt) {
		size = StyleValue(parsed_size)
		probe = size_attempt
		has_prefix = true
	}
	if !shape_set {
		probe.consume_whitespace()
		if next := probe.peek() {
			if next.is(.ident) && to_ascii_lowercase(next.token().ident()) in ['circle', 'ellipse'] {
				ending_shape = if equals_ignoring_ascii_case(next.token().ident(), 'circle') {
					RadialGradientEndingShape.circle
				} else {
					RadialGradientEndingShape.ellipse
				}
				probe.consume()
				shape_set = true
				has_prefix = true
			}
		}
	}
	radial_size := size.as_radial_size() or { return none }
	components := radial_size.components()
	if shape_set {
		if ending_shape == .circle && components.len != 1 {
			return none
		}
		if ending_shape == .ellipse && components.len != 2
			&& !(components.len > 0 && components[0] is RadialExtentComponent) {
			return none
		}
	} else {
		// If the shape is omitted, a single explicit length-percentage is a
		// circle; extent and two-component sizes are ellipses.
		ending_shape = if components.len == 1 && components[0] is StyleValue {
			RadialGradientEndingShape.circle
		} else {
			RadialGradientEndingShape.ellipse
		}
	}
	probe.consume_whitespace()
	if next := probe.peek() {
		if next.is(.ident) && equals_ignoring_ascii_case(next.token().ident(), 'at') {
			probe.consume()
			position = (parser.parse_css_position_value(mut probe, .normal) or { return none }) as PositionStyleValue
			has_prefix = true
		}
	}
	probe.consume_whitespace()
	if interpolation_method == none {
		interpolation_method = parser.parse_color_interpolation_method_value(mut probe)
		if interpolation_method != none {
			has_prefix = true
		}
	}
	if interpolation_method != none {
		has_prefix = true
	}
	if has_prefix {
		if !probe.consume_a_comma() {
			return none
		}
		tokens = probe
	}
	color_stops := parser.parse_linear_color_stop_list(mut tokens) or { return none }
	return RadialGradientStyleValue.create(ending_shape, size, position, color_stops, repeating, interpolation_method)
}

// Blink's prefixed radial grammar puts the optional one/two-value position
// before a comma, then shape/extent or two explicit radii. It is not the
// standard grammar with an alias: `at`, a single radius and color hints differ.
fn (mut parser Parser) parse_webkit_radial_gradient_function(function_name string, mut tokens ComponentValueStream) ?RadialGradientStyleValue {
	mut position := PositionStyleValue.create_center()
	mut probe := tokens.clone()
	if parsed_position := parser.parse_css_position_value(mut probe, .normal) {
		mut component_count := 0
		for component in tokens.values[tokens.index..probe.index] {
			if !component.is(.whitespace) { component_count++ }
		}
		if component_count > 2 || !probe.consume_a_comma() { return none }
		position = parsed_position as PositionStyleValue
		tokens = probe
	}
	mut shape := RadialGradientEndingShape.ellipse
	mut shape_specified := false
	mut extent_keyword := ''
	mut extent := RadialExtent.farthest_corner
	for _ in 0 .. 2 {
		tokens.consume_whitespace()
		next := tokens.peek() or { break }
		if !next.is(.ident) { break }
		ident := to_ascii_lowercase(next.token().ident())
		if ident in ['circle', 'ellipse'] && !shape_specified {
			shape = if ident == 'circle' { RadialGradientEndingShape.circle } else { RadialGradientEndingShape.ellipse }
			shape_specified = true
		} else if extent_keyword == '' && ident in ['closest-side', 'closest-corner', 'farthest-side', 'farthest-corner', 'contain', 'cover'] {
			extent_keyword = ident
			extent = match ident {
				'contain' { .closest_side }
				'cover' { .farthest_corner }
				else { radial_extent_from_string(ident) or { return none } }
			}
		} else { break }
		tokens.consume()
	}
	mut size := StyleValue(RadialSizeStyleValue.create([
		RadialSizeStyleValueComponent(RadialExtentComponent{ extent: extent }),
	]))
	if shape_specified || extent_keyword != '' {
		tokens.consume_a_comma()
	} else {
		mut sizes := tokens.clone()
		if horizontal := parser.parse_nonnegative_length_percentage_value(mut sizes) {
			vertical := parser.parse_nonnegative_length_percentage_value(mut sizes) or { return none }
			size = StyleValue(RadialSizeStyleValue.create([
				RadialSizeStyleValueComponent(horizontal),
				RadialSizeStyleValueComponent(vertical),
			]))
			sizes.consume_a_comma()
			tokens = sizes
		}
	}
	mut stops := []ColorStopListElement{}
	for {
		color := parser.parse_color_value(mut tokens) or { return none }
		mut stop := ColorStop{ color: color }
		mut offsets := tokens.clone()
		if offset := parser.parse_color_stop_position(mut offsets, false) {
			stop.position = offset
			tokens = offsets
			if second := parser.parse_color_stop_position(mut offsets, false) {
				stop.second_position = second
				tokens = offsets
			}
		}
		stops << ColorStopListElement{ color_stop: stop }
		if !tokens.has_more_tokens() { break }
		if !tokens.consume_a_comma() { return none }
	}
	mut gradient := RadialGradientStyleValue.create(shape, size, position, stops,
		if function_name.contains('repeating') { GradientRepeating.yes } else { GradientRepeating.no }, none)
	gradient.webkit_ = true
	gradient.webkit_shape_specified_ = shape_specified
	gradient.webkit_extent_keyword_ = extent_keyword
	return gradient
}

fn (mut parser Parser) parse_conic_gradient_function(function_name string, mut tokens ComponentValueStream) ?ConicGradientStyleValue {
	repeating := if function_name.contains('repeating') {
		GradientRepeating.yes
	} else {
		GradientRepeating.no
	}
	// [ [ [ from [ <angle> | <zero> ] ]? [ at <position> ]? ] ||
	// <color-interpolation-method> ]? , <angular-color-stop-list>
	mut from_angle := ?StyleValue(none)
	mut position := PositionStyleValue.create_center()
	mut position_set := false
	mut interpolation_method := ?ColorInterpolationMethodStyleValue(none)
	mut probe := tokens.clone()
	mut has_prefix := false
	for {
		probe.consume_whitespace()
		next := probe.peek() or { break }
		if !next.is(.ident) {
			break
		}
		identifier := to_ascii_lowercase(next.token().ident())
		if identifier == 'from' {
			if from_angle != none || position_set {
				return none
			}
			probe.consume()
			probe.consume_whitespace()
			if angle := parser.parse_angle_value(mut probe) {
				from_angle = angle
			} else if zero := probe.peek() {
				if !zero.is(.number) || zero.token().number_value() != 0 {
					return none
				}
				probe.consume()
				from_angle = StyleValue(AngleStyleValue.create(Angle.make_degrees(0)))
			} else {
				return none
			}
			has_prefix = true
		} else if identifier == 'at' {
			if position_set {
				return none
			}
			probe.consume()
			position = (parser.parse_css_position_value(mut probe, .normal) or { return none }) as PositionStyleValue
			position_set = true
			has_prefix = true
		} else if identifier == 'in' {
			if interpolation_method != none {
				return none
			}
			interpolation_method = parser.parse_color_interpolation_method_value(mut probe) or {
				return none
			}
			has_prefix = true
		} else {
			break
		}
	}
	if has_prefix {
		if !probe.consume_a_comma() {
			return none
		}
		tokens = probe
	}
	color_stops := parser.parse_angular_color_stop_list(mut tokens) or { return none }
	return ConicGradientStyleValue.create(from_angle, position, color_stops, repeating, interpolation_method)
}

// Parsing a declared value is a context-free pure function of the property and
// its text: the same (property_id, text) always yields the same StyleValue, and
// var()/env() resolution happens later against the produced Unresolved value.
// The cascade re-parses the same declared values for every element that matches
// a rule, so a per-traversal cache (enabled around a layout pass, mirroring the
// selector parse cache) collapses that repeated work to once per distinct value.
// The cache is nested (property id -> value text -> parsed value) so a hit reuses
// the caller's existing text string as the inner key without allocating a
// composite key on every one of the hundreds of thousands of cascade lookups.
__global (
	css_parsed_value_cache         = map[int]map[string]StyleValue{}
	css_parsed_value_cache_enabled bool
)

fn begin_parsed_value_cache() {
	// map.clear() leaves values in its scanned backing storage. Detach the
	// previous traversal's parsed values, including any retained image owners.
	css_parsed_value_cache = map[int]map[string]StyleValue{}
	css_parsed_value_cache_enabled = true
}

fn end_parsed_value_cache() {
	css_parsed_value_cache_enabled = false
	css_parsed_value_cache = map[int]map[string]StyleValue{}
}

pub fn parse_css_value_logic(property_id PropertyID, text string) ?StyleValue {
	if css_parsed_value_cache_enabled {
		key := int(property_id)
		if cached := css_parsed_value_cache[key][text] {
			return cached
		}
		// The process-wide cache keeps the parsed value and its text.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		owned_text := text.clone()
		value := parse_css_value_in_workspace(ParsingParams{}, property_id, owned_text)?
		if key !in css_parsed_value_cache {
			css_parsed_value_cache[key] = map[string]StyleValue{}
		}
		css_parsed_value_cache[key][owned_text] = value
		return value
	}
	return parse_css_value_in_workspace(ParsingParams{}, property_id, text)
}

// A transform list for the DOMMatrix string constructor, parsed in its value
// context, which rejects tree-counting functions.
pub fn parse_dom_matrix_init_string_value_logic(text string) ?StyleValue {
	return parse_css_value_in_workspace(ParsingParams{
		value_context: [ValueParsingContext(SpecialContext.dom_matrix_init_string)]
	}, .transform, text)
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

@[heap]
struct TypedStyleValueBox {
mut:
	value StyleValue
}

fn set_style_sheet_on_dom_style_value(value &dom.StyleValue, style_sheet ?&CSSStyleSheet) {
	if value.css_value_handle == unsafe { nil } {
		return
	}
	mut typed_value := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	typed_value.value.set_style_sheet(style_sheet)
}

fn dom_style_value_from_value_logic(value StyleValue) &dom.StyleValue {
	if entry := reusable_scalar_dom_box(&value) {
		return &dom.StyleValue{css_text: entry.value.css_text, css_value_handle: entry.value.css_value_handle}
	}
	return dom_style_value_from_value_logic_uncached(value)
}

fn dom_style_value_from_value_logic_uncached(value StyleValue) &dom.StyleValue {
	typed_value := &TypedStyleValueBox{
		value: value
	}
	return &dom.StyleValue{
		// Pending-substitution values are deliberately not author-serializable,
		// but the DOM-side opaque value must retain the original shorthand text
		// so the longhand can resolve var()/env()/attr() during the cascade.
		css_text: if value is PendingSubstitutionStyleValue {
			serialize_dom_style_value(value.original_shorthand_value_ref())
		} else {
			serialize_dom_style_value(value)
		}
		css_value_handle: voidptr(typed_value)
	}
}

// The common computed integer length needs just one owned string. Build its
// digits and unit on the stack instead of opening a scratch arena, allocating
// intermediate number text, and copying the final serialization back out.
fn serialize_dom_integer_length(value LengthStyleValue) ?string {
	raw := value.raw_value()
	if raw != raw || raw < -2147483648.0 || raw > 2147483647.0 { return none }
	integer := i64(raw)
	if raw != f64(integer) { return none }
	unit := value.unit_name()
	mut buffer := [32]u8{}
	if unit.len > buffer.len - 11 { return none }
	mut start := buffer.len - unit.len
	for index in 0 .. unit.len { buffer[start + index] = unit[index] }
	mut magnitude := u64(if integer < 0 { -integer } else { integer })
	for {
		start--
		buffer[start] = u8(magnitude % 10) + `0`
		magnitude /= 10
		if magnitude == 0 { break }
	}
	if integer < 0 {
		start--
		buffer[start] = `-`
	}
	return unsafe { tos(&buffer[start], buffer.len - start).clone() }
}

fn serialize_dom_style_value(value StyleValue) string {
	// Keyword serialization returns a static spelling. It already outlives
	// the DOM value and needs neither temporary storage nor an owned copy.
	if value is KeywordStyleValue {
		return value.serialize(.normal)
	}
	if value is LengthStyleValue {
		if text := serialize_dom_integer_length(value) { return text }
	}
	if !disable_dom_scalar_serialization {
		match value {
			ColorStyleValue { return serialize_dom_color(value.color_) }
			NumberStyleValue { if text := serialize_dom_exact_integer(value.value_, '') { return text } }
			IntegerStyleValue { if text := serialize_dom_exact_integer(f64(value.value_), '') { return text } }
			PercentageStyleValue { if text := serialize_dom_exact_integer(value.percentage_.value(), '%') { return text } }
			else {}
		}
	}
	$if prealloc {
		// Only the final text belongs to the opaque DOM value. Builders,
		// escaped components and shorthand probes can retire immediately.
		scratch := platform.begin_thread_scratch('CSS style serialization')
		serialized := value.serialize(.normal)
		scratch.leave()
		owned := serialized.clone()
		scratch.finish()
		return owned
	}
	return value.serialize(.normal)
}

// Recover the typed value retained by dom_style_value_from_value_logic(). DOM
// deliberately treats this pointer as opaque to avoid a dom -> css import
// cycle. Hand-authored DOM bridge values have no handle, so retain the old
// parse-from-text fallback for those boundary cases.
fn typed_style_value_logic_from_dom(value &dom.StyleValue) ?StyleValue {
	if value.css_value_handle != unsafe { nil } {
		return unsafe { (&TypedStyleValueBox(value.css_value_handle)).value }
	}
	return none
}

fn style_value_logic_from_dom(property_id PropertyID, value &dom.StyleValue) ?StyleValue {
	if value.css_value_handle != unsafe { nil } {
		return unsafe { (&TypedStyleValueBox(value.css_value_handle)).value }
	}
	return parse_css_value_logic(property_id, value.css_text)
}
