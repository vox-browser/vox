module css

import strings

pub enum SyntaxNodeType {
	universal
	ident
	type_
	multiplier
	comma_separated_multiplier
	alternatives
}

// Translated from LibWeb/CSS/Parser/Syntax.h.
pub struct SyntaxNode {
pub mut:
	type_      SyntaxNodeType
	ident_     string
	type_name_ string
	value_type ?ValueType
	children   []SyntaxNode
}

pub fn SyntaxNode.create_universal() SyntaxNode {
	return SyntaxNode{
		type_: .universal
	}
}

pub fn SyntaxNode.create_ident(ident string) SyntaxNode {
	return SyntaxNode{
		type_:  .ident
		ident_: ident
	}
}

pub fn SyntaxNode.create_type(type_name string) SyntaxNode {
	value_type := value_type_from_string(type_name)
	return SyntaxNode{
		type_:      .type_
		type_name_: type_name
		value_type: value_type
	}
}

pub fn SyntaxNode.create_multiplier(child SyntaxNode) SyntaxNode {
	return SyntaxNode{
		type_:    .multiplier
		children: [child]
	}
}

pub fn SyntaxNode.create_comma_separated_multiplier(child SyntaxNode) SyntaxNode {
	return SyntaxNode{
		type_:    .comma_separated_multiplier
		children: [child]
	}
}

pub fn SyntaxNode.create_alternatives(children []SyntaxNode) SyntaxNode {
	return SyntaxNode{
		type_:    .alternatives
		children: children
	}
}

pub fn (node SyntaxNode) type() SyntaxNodeType {
	return node.type_
}

pub fn (node SyntaxNode) ident() string {
	assert node.type_ == .ident
	return node.ident_
}

pub fn (node SyntaxNode) type_name() string {
	assert node.type_ == .type_
	return node.type_name_
}

pub fn (node SyntaxNode) child() SyntaxNode {
	assert node.type_ == .multiplier || node.type_ == .comma_separated_multiplier
	assert node.children.len == 1
	return node.children[0]
}

pub fn (node SyntaxNode) to_string() string {
	return match node.type_ {
		.universal {
			'*'
		}
		.ident {
			serialize_an_identifier(node.ident_)
		}
		.type_ {
			'<${node.type_name_}>'
		}
		.multiplier {
			'${node.child().to_string()}+'
		}
		.comma_separated_multiplier {
			'${node.child().to_string()}#'
		}
		.alternatives {
			mut parts := []string{cap: node.children.len}
			for child in node.children {
				parts << child.to_string()
			}
			parts.join(' | ')
		}
	}
}

pub fn (node SyntaxNode) dump() string {
	mut builder := strings.new_builder(64)
	node.dump_into(mut builder, 0)
	return builder.str()
}

fn (node SyntaxNode) dump_into(mut builder strings.Builder, indent int) {
	padding := ' '.repeat(indent)
	match node.type_ {
		.universal {
			builder.write_string('${padding}Universal\n')
		}
		.ident {
			builder.write_string('${padding}Ident: ${node.ident_}\n')
		}
		.type_ {
			builder.write_string('${padding}Type: ${node.type_name_}\n')
		}
		.multiplier {
			builder.write_string('${padding}Multiplier:\n')
			node.child().dump_into(mut builder, indent + 2)
		}
		.comma_separated_multiplier {
			builder.write_string('${padding}CommaSeparatedMultiplier:\n')
			node.child().dump_into(mut builder, indent + 2)
		}
		.alternatives {
			builder.write_string('${padding}Alternatives:\n')
			for child in node.children {
				child.dump_into(mut builder, indent + 2)
			}
		}
	}
}

struct ComponentValueTokenStream {
mut:
	tokens []ComponentValue
	index  int
}

fn ComponentValueTokenStream.new(tokens []ComponentValue) ComponentValueTokenStream {
	return ComponentValueTokenStream{
		tokens: tokens
	}
}

fn (stream ComponentValueTokenStream) has_next_token() bool {
	return stream.index < stream.tokens.len
}

fn (stream ComponentValueTokenStream) next_token() ComponentValue {
	if stream.index >= stream.tokens.len {
		return ComponentValue.from_token(Tokenizer.create_eof_token())
	}
	return stream.tokens[stream.index]
}

fn (mut stream ComponentValueTokenStream) consume_a_token() ComponentValue {
	if stream.index >= stream.tokens.len {
		return ComponentValue.from_token(Tokenizer.create_eof_token())
	}
	token := stream.tokens[stream.index]
	stream.index++
	return token
}

fn (mut stream ComponentValueTokenStream) discard_a_token() {
	if stream.index < stream.tokens.len {
		stream.index++
	}
}

fn (mut stream ComponentValueTokenStream) discard_whitespace() {
	for stream.has_next_token() && stream.next_token().is(.whitespace) {
		stream.discard_a_token()
	}
}

fn syntax_component_values_from_string(value string) []ComponentValue {
	mut component_values := []ComponentValue{}
	for token in Tokenizer.tokenize(value, 'UTF-8') {
		if token.is(.end_of_file) {
			continue
		}
		component_values << ComponentValue.from_token(token)
	}
	return component_values
}

fn is_supported_syntax_type_name(type_name string) bool {
	return to_ascii_lowercase(type_name) in [
		'angle',
		'color',
		'custom-ident',
		'image',
		'integer',
		'length',
		'length-percentage',
		'number',
		'percentage',
		'resolution',
		'string',
		'time',
		'url',
		'transform-function',
	]
}

fn parse_syntax_single_component(mut tokens ComponentValueTokenStream) ?SyntaxNode {
	// <syntax-single-component> = '<' <syntax-type-name> '>' | <ident>
	// <syntax-type-name> = angle | color | custom-ident | image | integer
	//                    | length | length-percentage | number
	//                    | percentage | resolution | string | time
	//                    | url | transform-function
	transaction_index := tokens.index
	tokens.discard_whitespace()

	// <ident>
	if tokens.next_token().is(.ident) {
		ident := tokens.consume_a_token().token().ident()
		return SyntaxNode.create_ident(ident)
	}

	// '<' <syntax-type-name> '>'
	if tokens.next_token().is_delim(u32(`<`)) {
		tokens.discard_a_token() // '<'
		type_name := tokens.consume_a_token()
		end_token := tokens.consume_a_token()

		if end_token.is_delim(u32(`>`)) && type_name.is(.ident)
			&& is_supported_syntax_type_name(type_name.token().ident()) {
			return SyntaxNode.create_type(type_name.token().ident())
		}
	}

	tokens.index = transaction_index
	return none
}

fn parse_syntax_multiplier(mut tokens ComponentValueTokenStream) ?u32 {
	// <syntax-multiplier> = [ '#' | '+' ]
	transaction_index := tokens.index

	delim := tokens.consume_a_token()
	if delim.is_delim(u32(`#`)) || delim.is_delim(u32(`+`)) {
		return delim.token().delim()
	}

	tokens.index = transaction_index
	return none
}

fn parse_syntax_component(mut tokens ComponentValueTokenStream) ?SyntaxNode {
	// <syntax-component> = <syntax-single-component> <syntax-multiplier>?
	//                    | '<' transform-list '>'
	transaction_index := tokens.index

	tokens.discard_whitespace()

	// '<' transform-list '>'
	if tokens.next_token().is_delim(u32(`<`)) {
		transform_list_index := tokens.index
		tokens.discard_a_token() // '<'
		ident_token := tokens.consume_a_token()
		end_token := tokens.consume_a_token()

		if ident_token.is_ident('transform-list') && end_token.is_delim(u32(`>`)) {
			return SyntaxNode.create_type('transform-list')
		}
		tokens.index = transform_list_index
	}

	// <syntax-single-component> <syntax-multiplier>?
	syntax_single_component := parse_syntax_single_component(mut tokens) or {
		tokens.index = transaction_index
		return none
	}

	multiplier := parse_syntax_multiplier(mut tokens) or { return syntax_single_component }

	match multiplier {
		u32(`#`) {
			return SyntaxNode.create_comma_separated_multiplier(syntax_single_component)
		}
		u32(`+`) {
			return SyntaxNode.create_multiplier(syntax_single_component)
		}
		else {
			tokens.index = transaction_index
			return none
		}
	}
}

fn parse_syntax_combinator(mut tokens ComponentValueTokenStream) ?u32 {
	// <syntax-combinator> = '|'
	transaction_index := tokens.index
	tokens.discard_whitespace()

	delim := tokens.consume_a_token()
	if delim.is_delim(u32(`|`)) {
		return delim.token().delim()
	}

	tokens.index = transaction_index
	return none
}

// https://drafts.csswg.org/css-values-5/#typedef-syntax
pub fn parse_as_syntax(component_values []ComponentValue) ?SyntaxNode {
	// <syntax> = '*' | <syntax-component> [ <syntax-combinator> <syntax-component> ]* | <syntax-string>
	// <syntax-component> = <syntax-single-component> <syntax-multiplier>?
	//                    | '<' transform-list '>'
	// <syntax-single-component> = '<' <syntax-type-name> '>' | <ident>
	// <syntax-type-name> = angle | color | custom-ident | image | integer
	//                    | length | length-percentage | number
	//                    | percentage | resolution | string | time
	//                    | url | transform-function
	// <syntax-combinator> = '|'
	// <syntax-multiplier> = [ '#' | '+' ]
	//
	// <syntax-string> = <string>
	// FIXME: Eventually, extend this to also parse *any* CSS grammar, not just for the <syntax> type.
	mut tokens := ComponentValueTokenStream.new(component_values)
	tokens.discard_whitespace()

	// '*'
	if tokens.next_token().is_delim(u32(`*`)) {
		tokens.discard_a_token() // '*'
		tokens.discard_whitespace()
		if tokens.has_next_token() {
			return none
		}
		return SyntaxNode.create_universal()
	}

	// <syntax-string> = <string>
	// A <syntax-string> is a <string> whose value successfully parses as a <syntax>, and represents the same value as
	// that <syntax> would.
	// NB: For now, this is the only time a string is allowed in a <syntax>.
	if tokens.next_token().is(.string) {
		syntax_string := tokens.consume_a_token().token().string_value()
		tokens.discard_whitespace()
		if tokens.has_next_token() {
			return none
		}

		child_component_values := syntax_component_values_from_string(syntax_string)
		return parse_as_syntax(child_component_values)
	}

	// <syntax-component> [ <syntax-combinator> <syntax-component> ]*
	first := parse_syntax_component(mut tokens) or { return none }
	mut syntax_components := [first]

	tokens.discard_whitespace()
	for tokens.has_next_token() {
		combinator := parse_syntax_combinator(mut tokens) or { return none }
		tokens.discard_whitespace()
		component := parse_syntax_component(mut tokens) or { return none }
		tokens.discard_whitespace()

		// FIXME: Make this logic smarter once we have more than one type of combinator.
		// For now, assume we're always making an AlternativesSyntaxNode.
		assert combinator == u32(`|`)

		syntax_components << component
	}

	if syntax_components.len == 1 {
		return syntax_components[0]
	}
	return SyntaxNode.create_alternatives(syntax_components)
}

pub type Dimension = Angle | Flex | Frequency | Length | Percentage | Resolution | Time

pub fn (dimension Dimension) is_angle() bool {
	return dimension is Angle
}

pub fn (dimension Dimension) angle() Angle {
	if dimension is Angle {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_angle_percentage() bool {
	return dimension.is_angle() || dimension.is_percentage()
}

pub fn (dimension Dimension) angle_percentage() AnglePercentage {
	if dimension.is_angle() {
		return AnglePercentage.from_angle(dimension.angle())
	}
	return AnglePercentage.from_percentage(dimension.percentage())
}

pub fn (dimension Dimension) is_flex() bool {
	return dimension is Flex
}

pub fn (dimension Dimension) flex() Flex {
	if dimension is Flex {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_frequency() bool {
	return dimension is Frequency
}

pub fn (dimension Dimension) frequency() Frequency {
	if dimension is Frequency {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_frequency_percentage() bool {
	return dimension.is_frequency() || dimension.is_percentage()
}

pub fn (dimension Dimension) frequency_percentage() FrequencyPercentage {
	if dimension.is_frequency() {
		return FrequencyPercentage.from_frequency(dimension.frequency())
	}
	return FrequencyPercentage.from_percentage(dimension.percentage())
}

pub fn (dimension Dimension) is_length() bool {
	return dimension is Length
}

pub fn (dimension Dimension) length() Length {
	if dimension is Length {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_length_percentage() bool {
	return dimension.is_length() || dimension.is_percentage()
}

pub fn (dimension Dimension) length_percentage() LengthPercentage {
	if dimension.is_length() {
		return LengthPercentage.from_length(dimension.length())
	}
	return LengthPercentage.from_percentage(dimension.percentage())
}

pub fn (dimension Dimension) is_percentage() bool {
	return dimension is Percentage
}

pub fn (dimension Dimension) percentage() Percentage {
	if dimension is Percentage {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_resolution() bool {
	return dimension is Resolution
}

pub fn (dimension Dimension) resolution() Resolution {
	if dimension is Resolution {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_time() bool {
	return dimension is Time
}

pub fn (dimension Dimension) time() Time {
	if dimension is Time {
		return dimension
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (dimension Dimension) is_time_percentage() bool {
	return dimension.is_time() || dimension.is_percentage()
}

pub fn (dimension Dimension) time_percentage() TimePercentage {
	if dimension.is_time() {
		return TimePercentage.from_time(dimension.time())
	}
	return TimePercentage.from_percentage(dimension.percentage())
}

pub fn (dimension Dimension) to_string() string {
	return match dimension {
		Angle { dimension.to_string() }
		Flex { dimension.to_string() }
		Frequency { dimension.to_string() }
		Length { dimension.to_string() }
		Percentage { dimension.to_string() }
		Resolution { dimension.to_string() }
		Time { dimension.to_string() }
	}
}

fn guaranteed_invalid_style_value() StyleValue {
	return StyleValue(StubStyleValue.create(.guaranteed_invalid, ''))
}

fn parse_declaration_value_from_remaining(mut tokens ComponentValueTokenStream) ?[]ComponentValue {
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return none
	}

	mut value := []ComponentValue{}
	for tokens.has_next_token() {
		value << tokens.consume_a_token()
	}
	return value
}

fn parse_dimension_value(type_ ValueType, mut tokens ComponentValueTokenStream) ?StyleValue {
	tokens.discard_whitespace()
	token := tokens.consume_a_token()
	if token.is(.percentage) {
		if type_ in [.angle_percentage, .frequency_percentage, .length_percentage, .percentage,
			.time_percentage] {
			return StyleValue(PercentageStyleValue.create(Percentage.new(token.token().percentage())))
		}
		return none
	}
	if !token.is(.dimension) {
		return none
	}

	value := token.token().dimension_value()
	unit := token.token().dimension_unit()
	if type_ in [.angle, .angle_percentage] {
		if angle_unit := string_to_angle_unit(unit) {
			return StyleValue(AngleStyleValue.create(Angle.new(value, angle_unit)))
		}
	}
	if type_ == .flex {
		if flex_unit := string_to_flex_unit(unit) {
			return StyleValue(FlexStyleValue.create(Flex.new(value, flex_unit)))
		}
	}
	if type_ in [.frequency, .frequency_percentage] {
		if frequency_unit := string_to_frequency_unit(unit) {
			return StyleValue(FrequencyStyleValue.create(Frequency.new(value, frequency_unit)))
		}
	}
	if type_ in [.length, .length_percentage] {
		if length_unit := string_to_length_unit(unit) {
			return StyleValue(LengthStyleValue.create(Length.new(value, length_unit)))
		}
	}
	if type_ == .resolution {
		if resolution_unit := string_to_resolution_unit(unit) {
			return StyleValue(ResolutionStyleValue.create(Resolution.new(value, resolution_unit)))
		}
	}
	if type_ in [.time, .time_percentage] {
		if time_unit := string_to_time_unit(unit) {
			return StyleValue(TimeStyleValue.create(Time.new(value, time_unit)))
		}
	}
	return none
}

fn parse_value_for_syntax_type(type_ ValueType, mut tokens ComponentValueTokenStream) ?StyleValue {
	transaction_index := tokens.index
	tokens.discard_whitespace()
	token := tokens.next_token()

	match type_ {
		.custom_ident {
			if token.is(.ident) {
				ident := tokens.consume_a_token().token().ident()
				return StyleValue(CustomIdentStyleValue.create(ident))
			}
		}
		.integer {
			if token.is(.number) && token.token().number().is_integer() {
				return StyleValue(IntegerStyleValue.create(token.token().to_integer()))
			}
		}
		.number {
			if token.is(.number) {
				return StyleValue(NumberStyleValue.create(tokens.consume_a_token().token().number_value()))
			}
		}
		.percentage {
			if token.is(.percentage) {
				return StyleValue(PercentageStyleValue.create(Percentage.new(tokens.consume_a_token().token().percentage())))
			}
		}
		.string {
			if token.is(.string) {
				return StyleValue(StringStyleValue.create(tokens.consume_a_token().token().string_value()))
			}
		}
		.angle, .angle_percentage, .flex, .frequency, .frequency_percentage, .length,
		.length_percentage, .resolution, .time, .time_percentage {
			return parse_dimension_value(type_, mut tokens)
		}
		else {}
	}

	tokens.index = transaction_index
	return none
}

fn parse_comma_separated_syntax_value_list(mut tokens ComponentValueTokenStream, child SyntaxNode) ?StyleValue {
	mut values := []StyleValue{}
	tokens.discard_whitespace()
	for {
		value := parse_according_to_syntax_node(mut tokens, child) or { return none }
		values << value
		tokens.discard_whitespace()
		if !tokens.has_next_token() {
			break
		}
		if !tokens.next_token().is(.comma) {
			return none
		}
		tokens.discard_a_token()
		tokens.discard_whitespace()
		if !tokens.has_next_token() {
			return none
		}
	}
	if values.len == 0 {
		return none
	}
	return StyleValue(StyleValueList.create_collapsible(values, .comma))
}

fn parse_according_to_syntax_node(mut tokens ComponentValueTokenStream, syntax_node SyntaxNode) ?StyleValue {
	transaction_index := tokens.index

	match syntax_node.type() {
		.universal {
			if declaration_value := parse_declaration_value_from_remaining(mut tokens) {
				return StyleValue(UnresolvedStyleValue.create(declaration_value))
			}
			tokens.index = transaction_index
			return none
		}
		.ident {
			tokens.discard_whitespace()
			if tokens.consume_a_token().is_ident(syntax_node.ident()) {
				if keyword := keyword_from_string(syntax_node.ident()) {
					return StyleValue(KeywordStyleValue.create(keyword))
				}
				return StyleValue(CustomIdentStyleValue.create(syntax_node.ident()))
			}
			tokens.index = transaction_index
			return none
		}
		.type_ {
			if value_type := syntax_node.value_type {
				result := parse_value_for_syntax_type(value_type, mut tokens) or {
					tokens.index = transaction_index
					return none
				}
				return result
			}

			tokens.index = transaction_index
			return none
		}
		.multiplier {
			child := syntax_node.child()
			mut values := []StyleValue{}
			tokens.discard_whitespace()
			for tokens.has_next_token() {
				parsed_child := parse_according_to_syntax_node(mut tokens, child) or { break }
				values << parsed_child
				tokens.discard_whitespace()
			}
			if values.len == 0 {
				tokens.index = transaction_index
				return none
			}
			return StyleValue(StyleValueList.create_collapsible(values, .space))
		}
		.comma_separated_multiplier {
			result := parse_comma_separated_syntax_value_list(mut tokens, syntax_node.child()) or {
				tokens.index = transaction_index
				return none
			}
			return result
		}
		.alternatives {
			for child in syntax_node.children {
				result := parse_according_to_syntax_node(mut tokens, child) or {
					tokens.index = transaction_index
					continue
				}
				return result
			}
			tokens.index = transaction_index
			return none
		}
	}
}

// https://drafts.csswg.org/css-values-5/#parse-with-a-syntax
pub fn parse_with_a_syntax(input []ComponentValue, syntax SyntaxNode) StyleValue {
	// 1. Parse a list of component values from values, and let raw parse be the result.
	// NB: Already done before this point.

	// FIXME: 2. If el was given, substitute arbitrary substitution functions in raw parse, and set raw parse to that result.

	// 3. parse values according to syntax, with a * value treated as <declaration-value>?, and let parsed result be
	//    the result.
	//    If syntax used a | combinator, let parsed result be the parse result from the first matching clause.
	mut tokens := ComponentValueTokenStream.new(input)
	parsed_result := parse_according_to_syntax_node(mut tokens, syntax) or {
		return guaranteed_invalid_style_value()
	}
	tokens.discard_whitespace()

	// 4. If parsed result is failure, return the guaranteed-invalid value.
	if tokens.has_next_token() {
		return guaranteed_invalid_style_value()
	}

	// 5. Assert: parsed result is now a well-defined list of one or more CSS values, since each branch of a <syntax>
	//    defines an unambiguous parse result (or the * syntax is unambiguous on its own).
	// NB: Nothing to do.

	// 6. Return parsed result.
	return parsed_result
}
