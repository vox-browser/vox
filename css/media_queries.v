module css

import dom
import strings

// Translated media/support CSSOM logic formerly hosted as stubs in cssom_rules.v.

@[heap]
pub struct Supports {
pub mut:
	condition &BooleanExpression = unsafe { nil }
	matches   bool
}

pub fn Supports.create(condition &BooleanExpression) &Supports {
	return &Supports{
		condition: condition
		matches:   condition.evaluate_to_boolean(none)
	}
}

pub fn (supports &Supports) to_string() string {
	return supports.condition.to_string()
}

pub fn (supports &Supports) matches_condition() bool {
	return supports.matches
}

pub fn (supports &Supports) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Supports condition: (matches = ${supports.matches})\n${supports.condition.dump(
		indent_levels + 1)}'
}

pub fn parse_css_supports(context ParsingParams, condition_text string) ?&Supports {
	_ = context
	mut tokens :=
		SupportsTokenStream.from_values(parse_component_values_for_value_logic(condition_text))
	condition := parse_supports_condition(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return Supports.create(condition)
}

fn parse_css_supports_stub(condition_text string) ?&Supports {
	trimmed := condition_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return Supports.create(BooleanExpression.create_general_enclosed(trimmed, .true_))
}

struct SupportsTokenStream {
mut:
	values []ComponentValue
	index  int
}

fn SupportsTokenStream.from_values(values []ComponentValue) SupportsTokenStream {
	return SupportsTokenStream{
		values: values.clone()
	}
}

fn (tokens SupportsTokenStream) has_next_token() bool {
	return tokens.index < tokens.values.len
}

fn (tokens SupportsTokenStream) next_token() ?ComponentValue {
	if !tokens.has_next_token() {
		return none
	}
	return tokens.values[tokens.index]
}

fn (mut tokens SupportsTokenStream) consume_a_token() ?ComponentValue {
	token := tokens.next_token() or { return none }
	tokens.index++
	return token
}

fn (mut tokens SupportsTokenStream) discard_a_token() {
	if tokens.has_next_token() {
		tokens.index++
	}
}

fn (mut tokens SupportsTokenStream) discard_whitespace() {
	for {
		token := tokens.next_token() or { return }
		if !token.is(.whitespace) {
			return
		}
		tokens.index++
	}
}

// https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition
fn parse_supports_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	// RuleContext::SupportsCondition is represented by calling the declaration
	// parser with supports-condition validation below.
	return parse_supports_boolean_expression(mut tokens, .false_)
}

// https://drafts.csswg.org/css-values-5/#typedef-boolean-expr
fn parse_supports_boolean_expression(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	// `not <boolean-expr-group>`
	if peeked_token := transaction.next_token() {
		if peeked_token.is_ident('not') {
			transaction.discard_a_token()
			transaction.discard_whitespace()
			child := parse_supports_boolean_expression_group(mut transaction,
				result_for_general_enclosed) or { return none }
			transaction.discard_whitespace()
			tokens = transaction
			return BooleanExpression.create_not(child)
		}
	}

	mut children := []&BooleanExpression{}
	mut combinator := ?string(none)
	for transaction.has_next_token() {
		if children.len != 0 {
			token := transaction.consume_a_token() or { return none }
			if !token.is(.ident) {
				return none
			}
			maybe_combinator := token.token().ident().to_lower()
			if maybe_combinator != 'and' && maybe_combinator != 'or' {
				return none
			}
			if existing := combinator {
				if existing != maybe_combinator {
					return none
				}
			} else {
				combinator = maybe_combinator
			}
		}

		transaction.discard_whitespace()
		child := parse_supports_boolean_expression_group(mut transaction,
			result_for_general_enclosed) or { return none }
		children << child
		transaction.discard_whitespace()
	}

	if children.len == 0 {
		return none
	}

	tokens = transaction
	if children.len == 1 {
		return children[0]
	}

	if combinator_value := combinator {
		if combinator_value == 'and' {
			return BooleanExpression.create_and(children)
		}
		if combinator_value == 'or' {
			return BooleanExpression.create_or(children)
		}
	}
	return none
}

fn parse_supports_boolean_expression_group(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	// <boolean-expr-group> = <test> | ( <boolean-expr[ <test> ]> ) | <general-enclosed>
	if first_token := tokens.next_token() {
		if first_token.is_block() && first_token.block().is_paren() {
			mut transaction := tokens
			transaction.discard_a_token()
			mut child_tokens := SupportsTokenStream.from_values(first_token.block().value)
			if expression := parse_supports_boolean_expression(mut child_tokens,
				result_for_general_enclosed)
			{
				child_tokens.discard_whitespace()
				if !child_tokens.has_next_token() {
					tokens = transaction
					return BooleanExpression.create_in_parens(expression)
				}
			}
		}
	}

	if test := parse_supports_feature(mut tokens) {
		return test
	}

	if general_enclosed := parse_supports_general_enclosed(mut tokens, result_for_general_enclosed) {
		return general_enclosed
	}

	return none
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-feature
fn parse_supports_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }

	// `<supports-decl> = ( <declaration> )`
	if first_token.is_block() && first_token.block().is_paren() {
		mut block_tokens := ParserTokenStream.from_values(first_token.block().value)
		if declaration := parse_supports_declaration_from_parser_tokens(mut block_tokens) {
			transaction.discard_whitespace()
			tokens = transaction
			return BooleanExpression.create_in_parens(declaration)
		}
	}

	// `<supports-selector-fn> = selector( <complex-selector> )`
	if first_token.is_function_named('selector') {
		selector := supports_component_values_to_string(first_token.function().value)
		matches := parse_selector_with_parser(selector, map[string]bool{}) != none
			&& !supports_selector_contains_unknown_webkit_pseudo_element_stub(selector)
		tokens = transaction
		return BooleanExpression.create_supports_selector(selector, matches)
	}

	// `<supports-font-tech-fn> = font-tech( <font-tech> )`
	if first_token.is_function_named('font-tech') {
		mut tech_tokens := SupportsTokenStream.from_values(first_token.function().value)
		tech_tokens.discard_whitespace()
		tech_token := tech_tokens.consume_a_token() or { return none }
		tech_tokens.discard_whitespace()
		if tech_tokens.has_next_token() || !tech_token.is(.ident) {
			return none
		}
		tech_name := tech_token.token().ident()
		tokens = transaction
		return BooleanExpression.create_supports_font_tech(tech_name,
			font_tech_is_supported_name(tech_name))
	}

	// `<supports-font-format-fn> = font-format( <font-format> )`
	if first_token.is_function_named('font-format') {
		mut format_tokens := SupportsTokenStream.from_values(first_token.function().value)
		format_tokens.discard_whitespace()
		format_token := format_tokens.consume_a_token() or { return none }
		format_tokens.discard_whitespace()
		if format_tokens.has_next_token() || !format_token.is(.ident) {
			return none
		}
		format_name := format_token.token().ident()
		tokens = transaction
		return BooleanExpression.create_supports_font_format(format_name,
			font_format_is_supported(format_name))
	}

	return none
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-decl
fn parse_supports_declaration_from_parser_tokens(mut tokens ParserTokenStream) ?&BooleanExpression {
	mut parser := RuleSelectorParser.create(ParsingParams{}, '', 'utf-8')
	declaration := parser.consume_a_declaration(mut tokens, .no, .yes) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}

	property := PropertyNameAndID.from_name(declaration.name) or { return none }
	if property.is_custom_property() {
		original := declaration.original_full_text or {
			supports_component_values_to_string(declaration.value)
		}

		return BooleanExpression.create_supports_declaration(original, true)
	}
	property_id := property.id() or { return none }
	value_text := supports_component_values_to_string(declaration.value).trim_space()
	matches := parse_css_value(ParsingParams{}, value_text, property_id) != none
	original := declaration.original_full_text or { '${declaration.name}: ${value_text}' }
	return BooleanExpression.create_supports_declaration(original, matches)
}

// https://www.w3.org/TR/mediaqueries-4/#typedef-general-enclosed
fn parse_supports_general_enclosed(mut tokens SupportsTokenStream, result MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }
	if first_token.is_function() {
		tokens = transaction
		return BooleanExpression.create_general_enclosed(first_token.to_string(), result)
	}
	if first_token.is_block() && first_token.block().is_paren() {
		tokens = transaction
		return BooleanExpression.create_general_enclosed(first_token.to_string(), result)
	}
	return none
}

fn supports_component_values_to_string(values []ComponentValue) string {
	mut builder := strings.new_builder(32)
	for value in values {
		builder.write_string(value.to_string())
	}
	return builder.str()
}

fn supports_selector_contains_unknown_webkit_pseudo_element_stub(selector string) bool {
	_ = selector
	// Stub for Selector::contains_unknown_webkit_pseudo_element().
	return false
}

pub enum MediaQueryKnownMediaType {
	all
	print
	screen
}

pub fn media_type_from_string(name string) ?MediaQueryKnownMediaType {
	return match name.to_lower() {
		'all' { MediaQueryKnownMediaType.all }
		'print' { MediaQueryKnownMediaType.print }
		'screen' { MediaQueryKnownMediaType.screen }
		else { none }
	}
}

pub fn media_query_known_media_type_to_string(media_type MediaQueryKnownMediaType) string {
	return match media_type {
		.all { 'all' }
		.print { 'print' }
		.screen { 'screen' }
	}
}

@[heap]
pub struct MediaQuery {
pub mut:
	text    string = 'all'
	matches bool   = true
}

pub fn parse_media_query(context ParsingParams, text string) ?&MediaQuery {
	queries := parse_css_media_query_list_value_logic(text)
	if queries.len != 1 {
		return none
	}
	_ = context
	return queries[0]
}

pub fn (media_query &MediaQuery) evaluate(doc &dom.Document) bool {
	_ = doc
	return media_query.matches
}

pub fn (media_query &MediaQuery) to_string() string {
	return media_query.text
}

pub fn (media_query &MediaQuery) matches() bool {
	return media_query.matches
}

pub fn (media_query &MediaQuery) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Media condition: ${media_query.text} (matches = ${media_query.matches})\n'
}

pub struct MediaQueryListEntry {
pub mut:
	text    string
	matches bool
}

@[heap]
pub struct MediaList {
pub mut:
	media                  []MediaQueryListEntry
	associated_style_sheet ?&CSSStyleSheet
}

pub fn MediaList.create(media []MediaQueryListEntry) &MediaList {
	return &MediaList{
		media: media
	}
}

pub fn MediaList.create_empty() &MediaList {
	return MediaList.create([]MediaQueryListEntry{})
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (media_list &MediaList) media_text() string {
	return serialize_a_media_query_list_entries(media_list.media)
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (mut media_list MediaList) set_media_text(text string) {
	media_list.media.clear()
	if text.trim_space().len != 0 {
		media_list.media =
			media_query_entries_from_queries(parse_css_media_query_list_value_logic(text))
	}
	media_list.invalidate_associated_style_sheet()
}

pub fn (media_list &MediaList) length() int {
	return media_list.media.len
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-item
pub fn (media_list &MediaList) item(index u32) ?string {
	if int(index) >= media_list.media.len {
		return none
	}
	return media_list.media[index].text
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-appendmedium
pub fn (mut media_list MediaList) append_medium(medium string) {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry_stub(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

	// 3. If comparing m with any of the media queries in the collection of media queries returns true, then return.
	for existing_medium in media_list.media {
		if existing_medium.text == serialized {
			return
		}
	}

	// 4. Append m to the collection of media queries.
	media_list.media << parsed
	media_list.invalidate_associated_style_sheet()
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-deletemedium
pub fn (mut media_list MediaList) delete_medium(medium string) ! {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry_stub(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

	// 3. Remove any media query from the collection of media queries for which comparing the media query with m
	//    returns true. If nothing was removed, then throw a NotFoundError exception.
	mut was_removed := false
	mut kept := []MediaQueryListEntry{}
	for existing in media_list.media {
		if existing.text == serialized {
			was_removed = true
			continue
		}
		kept << existing
	}
	if !was_removed {
		return error('NotFoundError: Media query not found in list')
	}

	media_list.media = kept
	media_list.invalidate_associated_style_sheet()
}

pub fn (mut media_list MediaList) evaluate(document &dom.Document) bool {
	for i in 0 .. media_list.media.len {
		media_list.media[i].matches = evaluate_media_query_entry_stub(media_list.media[i], document)
	}
	return media_list.matches()
}

pub fn (media_list &MediaList) matches() bool {
	if media_list.media.len == 0 {
		return true
	}

	for media in media_list.media {
		if media.matches {
			return true
		}
	}
	return false
}

pub fn (mut media_list MediaList) set_associated_style_sheet(style_sheet &CSSStyleSheet) {
	unsafe {
		media_list.associated_style_sheet = style_sheet
	}
}

fn (media_list &MediaList) invalidate_associated_style_sheet() {
	if sheet := media_list.associated_style_sheet {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		mutable_sheet.invalidate_owners(dom.StyleInvalidationReason.style_change)
	}
}

pub fn (media_list &MediaList) dump(indent_levels int) string {
	mut builder := strings.new_builder(64)
	builder.write_string('${cssom_indent(indent_levels)}Media list (${media_list.media.len}):\n')
	for media in media_list.media {
		builder.write_string('${cssom_indent(indent_levels + 1)}${media.text} (matches = ${media.matches})\n')
	}
	return builder.str()
}

pub fn serialize_a_media_query_list(media_queries []&MediaQuery) string {
	// 1. If the media query list is empty, then return the empty string.
	if media_queries.len == 0 {
		return ''
	}

	// 2. Serialize each media query in the list of media queries, in the same order as they
	// appear in the media query list, and then serialize the list.
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.to_string()
	}
	return serialized.join(', ')
}

pub fn serialize_a_media_query_list_entries(media_queries []MediaQueryListEntry) string {
	if media_queries.len == 0 {
		return ''
	}
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.text
	}
	return serialized.join(', ')
}

fn media_query_text_matches_stub(text string) bool {
	lower := text.to_lower().trim_space()
	if lower == 'not all' {
		return false
	}
	if lower == 'all' || lower == 'screen' {
		return true
	}
	if lower == 'print' {
		return false
	}
	return true
}

fn parse_media_query_entry_stub(medium string) ?MediaQueryListEntry {
	trimmed := medium.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return MediaQueryListEntry{
		text:    trimmed
		matches: media_query_text_matches_stub(trimmed)
	}
}

fn parse_media_query_list_stub(text string) []MediaQueryListEntry {
	return media_query_entries_from_queries(parse_css_media_query_list_value_logic(text))
}

fn evaluate_media_query_entry_stub(entry MediaQueryListEntry, document &dom.Document) bool {
	_ = document
	return media_query_text_matches_stub(entry.text)
}

fn media_query_entries_from_queries(queries []&MediaQuery) []MediaQueryListEntry {
	mut entries := []MediaQueryListEntry{cap: queries.len}
	for query in queries {
		entries << MediaQueryListEntry{
			text:    query.to_string()
			matches: query.matches()
		}
	}
	return entries
}
